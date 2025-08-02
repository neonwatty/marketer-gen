class CampaignPlan < ApplicationRecord
  belongs_to :campaign
  belongs_to :user
  has_many :plan_revisions, dependent: :destroy
  has_many :plan_comments, dependent: :destroy
  
  STATUSES = %w[draft in_review approved rejected archived].freeze
  PLAN_TYPES = %w[comprehensive quick_launch strategic tactical].freeze
  
  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :plan_type, inclusion: { in: PLAN_TYPES }
  validates :strategic_rationale, presence: true
  validates :target_audience, presence: true
  validates :messaging_framework, presence: true
  validates :channel_strategy, presence: true
  validates :timeline_phases, presence: true
  validates :success_metrics, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  
  # JSON serialization for complex fields
  serialize :strategic_rationale, JSON
  serialize :target_audience, JSON
  serialize :messaging_framework, JSON
  serialize :channel_strategy, JSON
  serialize :timeline_phases, JSON
  serialize :success_metrics, JSON
  serialize :budget_allocation, JSON
  serialize :creative_approach, JSON
  serialize :market_analysis, JSON
  serialize :metadata, JSON
  
  scope :approved, -> { where(status: 'approved') }
  scope :draft, -> { where(status: 'draft') }
  scope :in_review, -> { where(status: 'in_review') }
  scope :latest_version, -> { order(version: :desc) }
  scope :by_campaign, ->(campaign_id) { where(campaign_id: campaign_id) }
  
  before_validation :set_defaults, on: :create
  after_create :create_initial_revision
  
  def approve!
    update!(status: 'approved', approved_at: Time.current, approved_by: Current.user&.id)
  end
  
  def reject!(reason = nil)
    update!(status: 'rejected', rejected_at: Time.current, rejected_by: Current.user&.id, rejection_reason: reason)
  end
  
  def submit_for_review!
    update!(status: 'in_review', submitted_at: Time.current)
  end
  
  def archive!
    update!(status: 'archived', archived_at: Time.current)
  end
  
  def approved?
    status == 'approved'
  end
  
  def in_review?
    status == 'in_review'
  end
  
  def draft?
    status == 'draft'
  end
  
  def rejected?
    status == 'rejected'
  end
  
  def current_version?
    campaign.campaign_plans.where('version > ?', version).empty?
  end
  
  def next_version
    (version + 0.1).round(1)
  end
  
  def phase_count
    timeline_phases&.length || 0
  end
  
  def total_budget
    budget_allocation&.dig('total_budget') || 0
  end
  
  def estimated_duration_weeks
    return 0 unless timeline_phases&.any?
    
    timeline_phases.sum { |phase| phase['duration_weeks'] || 0 }
  end
  
  def channel_count
    channel_strategy&.length || 0
  end
  
  def has_creative_approach?
    creative_approach.present? && creative_approach.any?
  end
  
  def completion_percentage
    required_fields = %w[strategic_rationale target_audience messaging_framework 
                        channel_strategy timeline_phases success_metrics]
    completed_fields = required_fields.count { |field| send(field).present? }
    
    (completed_fields.to_f / required_fields.length * 100).round
  end
  
  def to_export_hash
    {
      id: id,
      name: name,
      version: version,
      status: status,
      plan_type: plan_type,
      campaign: campaign.name,
      strategic_rationale: strategic_rationale,
      target_audience: target_audience,
      messaging_framework: messaging_framework,
      channel_strategy: channel_strategy,
      timeline_phases: timeline_phases,
      success_metrics: success_metrics,
      budget_allocation: budget_allocation,
      creative_approach: creative_approach,
      market_analysis: market_analysis,
      created_at: created_at,
      updated_at: updated_at,
      user: user.name
    }
  end
  
  private
  
  def set_defaults
    self.version ||= 1.0
    self.status ||= 'draft'
    self.plan_type ||= 'comprehensive'
    self.metadata ||= {}
  end
  
  def create_initial_revision
    plan_revisions.create!(
      revision_number: version,
      plan_data: to_export_hash,
      user: user,
      change_summary: 'Initial plan creation'
    )
  end
end