class CampaignIntakeSession < ApplicationRecord
  belongs_to :user
  belongs_to :campaign, optional: true
  
  STATUSES = %w[in_progress completed abandoned].freeze
  
  validates :thread_id, presence: true, uniqueness: { scope: :user_id }
  validates :status, inclusion: { in: STATUSES }
  
  serialize :context, JSON
  serialize :messages, JSON
  
  scope :active, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(updated_at: :desc) }
  
  before_create :set_defaults
  
  def active?
    status == 'in_progress'
  end
  
  def completed?
    status == 'completed'
  end
  
  def abandoned?
    status == 'abandoned'
  end
  
  def progress_percentage
    return 0 unless context.present?
    
    context.dig('progress') || 0
  end
  
  def current_step
    context.dig('currentStep') || 'welcome'
  end
  
  def completed_steps
    context.dig('completedSteps') || []
  end
  
  def estimated_time_remaining
    # Base estimation on typical completion patterns
    total_steps = 8 # Typical number of steps in campaign intake
    completed = completed_steps.count
    remaining = total_steps - completed
    
    # Estimate 1.5 minutes per step
    [remaining * 1.5, 0].max
  end
  
  def actual_duration_minutes
    return 0 unless started_at && completed_at
    
    ((completed_at - started_at) / 1.minute).round(1)
  end
  
  def efficiency_score
    return 0 unless completed? && estimated_completion_time > 0 && actual_completion_time > 0
    
    # Score based on how close actual time was to estimated
    efficiency = (estimated_completion_time.to_f / actual_completion_time.to_f) * 100
    [efficiency, 200].min.round(1) # Cap at 200% efficiency
  end
  
  def conversation_length
    messages&.count || 0
  end
  
  def last_activity
    updated_at
  end
  
  def time_since_last_activity
    Time.current - last_activity
  end
  
  def should_be_abandoned?
    # Consider abandoning if inactive for more than 24 hours
    active? && time_since_last_activity > 24.hours
  end
  
  def mark_abandoned!
    return false unless active?
    
    update!(
      status: 'abandoned',
      completed_at: Time.current
    )
  end
  
  def complete_with_campaign!(campaign)
    update!(
      status: 'completed',
      campaign: campaign,
      completed_at: Time.current,
      actual_completion_time: actual_duration_minutes
    )
  end
  
  def add_message(message_data)
    self.messages ||= []
    self.messages << message_data.with_indifferent_access
    self.updated_at = Time.current
    save!
  end
  
  def update_context(context_updates)
    self.context ||= {}
    self.context.merge!(context_updates.with_indifferent_access)
    self.updated_at = Time.current
    save!
  end
  
  def to_thread_format
    {
      id: thread_id,
      messages: messages || [],
      context: context || {},
      status: status,
      currentQuestionId: context&.dig('currentQuestionId'),
      createdAt: created_at,
      updatedAt: updated_at
    }
  end
  
  # Analytics methods
  def self.average_completion_time
    completed.where.not(actual_completion_time: nil)
             .average(:actual_completion_time)
             &.round(1) || 0
  end
  
  def self.completion_rate
    total = count
    return 0 if total == 0
    
    completed_count = completed.count
    (completed_count.to_f / total * 100).round(1)
  end
  
  def self.average_efficiency
    completed.where.not(actual_completion_time: nil, estimated_completion_time: nil)
             .map(&:efficiency_score)
             .sum / completed.count.to_f
             rescue 0
  end
  
  def self.cleanup_abandoned_sessions
    # Mark old active sessions as abandoned
    active.where('updated_at < ?', 24.hours.ago).find_each do |session|
      session.mark_abandoned!
    end
  end
  
  private
  
  def set_defaults
    self.started_at ||= Time.current
    self.context ||= {}
    self.messages ||= []
    self.status ||= 'in_progress'
    self.estimated_completion_time ||= 15 # 15 minutes default estimate
  end
end