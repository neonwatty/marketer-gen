class ProjectMilestone < ApplicationRecord
  belongs_to :campaign_plan
  belongs_to :created_by, class_name: 'User'
  belongs_to :assigned_to, class_name: 'User', optional: true
  belongs_to :completed_by, class_name: 'User', optional: true

  STATUSES = %w[pending in_progress completed overdue cancelled].freeze
  PRIORITIES = %w[low medium high critical].freeze
  MILESTONE_TYPES = %w[planning design development review approval launch].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 2000 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }
  validates :milestone_type, presence: true, inclusion: { in: MILESTONE_TYPES }
  validates :due_date, presence: true
  validates :estimated_hours, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1000 }, allow_nil: true
  validates :actual_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :completion_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  validate :due_date_not_in_past, on: :create
  validate :completion_date_after_creation
  validate :assigned_user_exists_when_assigned

  serialize :resources_required, coder: JSON
  serialize :deliverables, coder: JSON
  serialize :dependencies, coder: JSON
  serialize :risk_factors, coder: JSON

  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_milestone_type, ->(type) { where(milestone_type: type) }
  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :overdue, -> { where(status: 'overdue') }
  scope :high_priority, -> { where(priority: %w[high critical]) }
  scope :due_soon, -> { where(due_date: Date.current..1.week.from_now) }
  scope :overdue_items, -> { where('due_date < ? AND status NOT IN (?)', Date.current, %w[completed cancelled]) }
  scope :for_campaign, ->(campaign_plan) { where(campaign_plan: campaign_plan) }
  scope :assigned_to_user, ->(user) { where(assigned_to: user) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_due_date, -> { order(:due_date) }

  before_validation :set_default_completion_percentage, on: :create
  before_validation :calculate_overdue_status
  after_update :track_completion_metrics, if: :saved_change_to_status?
  after_create :create_project_activity_log
  after_update :create_project_activity_log, if: :saved_changes?

  def pending?
    status == 'pending'
  end

  def in_progress?
    status == 'in_progress'
  end

  def completed?
    status == 'completed'
  end

  def overdue?
    status == 'overdue' || (due_date < Date.current && !completed?)
  end

  def cancelled?
    status == 'cancelled'
  end

  def high_priority?
    %w[high critical].include?(priority)
  end

  def can_be_started?
    pending? && dependencies_met?
  end

  def can_be_completed?
    in_progress? && completion_percentage == 100
  end

  def can_be_deleted?
    pending? || cancelled?
  end

  def start!(user)
    return false unless can_be_started?
    
    update!(
      status: 'in_progress',
      started_at: Time.current,
      assigned_to: user
    )
  end

  def complete!(user)
    return false unless can_be_completed?
    
    update!(
      status: 'completed',
      completed_at: Time.current,
      completed_by: user,
      completion_percentage: 100
    )
  end

  def cancel!(reason = nil)
    return false if completed?
    
    update!(
      status: 'cancelled',
      completion_percentage: 0,
      notes: [notes, "Cancelled: #{reason}"].compact.join("\n")
    )
  end

  def days_until_due
    return 0 if completed?
    (due_date - Date.current).to_i
  end

  def duration_days
    return 0 unless completed_at && started_at
    ((completed_at - started_at) / 1.day).ceil
  end

  def resource_allocation_summary
    return {} unless resources_required.present?
    
    begin
      resources = JSON.parse(resources_required.to_s)
      {
        total_resources: resources.count,
        resource_types: resources.group_by { |r| r['type'] }.keys,
        estimated_cost: resources.sum { |r| r['cost'].to_f }
      }
    rescue JSON::ParserError
      {}
    end
  end

  def deliverable_summary
    return {} unless deliverables.present?
    
    begin
      items = JSON.parse(deliverables.to_s)
      {
        total_deliverables: items.count,
        completed_deliverables: items.count { |d| d['completed'] },
        pending_deliverables: items.count { |d| !d['completed'] }
      }
    rescue JSON::ParserError
      {}
    end
  end

  def dependency_status
    return { met: true, blocking: [] } unless dependencies.present?
    
    begin
      deps = JSON.parse(dependencies.to_s)
      blocking_deps = deps.select { |d| !d['completed'] }
      
      {
        met: blocking_deps.empty?,
        total: deps.count,
        completed: deps.count - blocking_deps.count,
        blocking: blocking_deps.map { |d| d['name'] }
      }
    rescue JSON::ParserError
      { met: true, blocking: [] }
    end
  end

  def risk_assessment
    return { level: 'low', factors: [] } unless risk_factors.present?
    
    begin
      risks = JSON.parse(risk_factors.to_s)
      high_risks = risks.select { |r| %w[high critical].include?(r['level']) }
      
      risk_level = if high_risks.any?
        high_risks.any? { |r| r['level'] == 'critical' } ? 'critical' : 'high'
      elsif risks.any? { |r| r['level'] == 'medium' }
        'medium'
      else
        'low'
      end
      
      {
        level: risk_level,
        total_risks: risks.count,
        high_priority_risks: high_risks.count,
        factors: risks.map { |r| { name: r['name'], level: r['level'] } }
      }
    rescue JSON::ParserError
      { level: 'low', factors: [] }
    end
  end

  def project_analytics
    {
      milestone_id: id,
      name: name,
      status: status,
      priority: priority,
      type: milestone_type,
      progress: completion_percentage,
      due_date: due_date,
      days_until_due: days_until_due,
      overdue: overdue?,
      estimated_hours: estimated_hours,
      actual_hours: actual_hours,
      resource_summary: resource_allocation_summary,
      deliverable_summary: deliverable_summary,
      dependency_status: dependency_status,
      risk_assessment: risk_assessment
    }
  end

  private

  def set_default_completion_percentage
    self.completion_percentage ||= 0
  end

  def calculate_overdue_status
    if due_date && due_date < Date.current && !%w[completed cancelled].include?(status)
      self.status = 'overdue'
    end
  end

  def due_date_not_in_past
    return unless due_date.present?
    
    if due_date < Date.current
      errors.add(:due_date, 'cannot be in the past')
    end
  end

  def completion_date_after_creation
    return unless completed_at.present? && created_at.present?
    
    if completed_at < created_at
      errors.add(:completed_at, 'cannot be before creation date')
    end
  end

  def assigned_user_exists_when_assigned
    return unless assigned_to_id.present?
    
    unless User.exists?(assigned_to_id)
      errors.add(:assigned_to, 'must be a valid user')
    end
  end

  def dependencies_met?
    dependency_status[:met]
  end

  def track_completion_metrics
    return unless completed?
    
    # Update campaign plan with milestone completion
    campaign_plan.touch(:updated_at) if campaign_plan
  end

  def create_project_activity_log
    # Log project milestone activities for audit trail
    Rails.logger.info "ProjectMilestone #{action_name}: #{name} (ID: #{id}) for Campaign: #{campaign_plan.name}"
  rescue => e
    Rails.logger.error "Failed to create project activity log: #{e.message}"
  end

  def action_name
    if new_record?
      'created'
    elsif saved_change_to_status?
      "status_changed_to_#{status}"
    else
      'updated'
    end
  end
end