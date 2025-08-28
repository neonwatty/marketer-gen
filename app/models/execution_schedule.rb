# frozen_string_literal: true

# Model for scheduling and managing automated campaign execution
# Handles platform deployment, performance monitoring, and optimization
class ExecutionSchedule < ApplicationRecord
  belongs_to :campaign_plan
  belongs_to :created_by, class_name: 'User'
  belongs_to :updated_by, class_name: 'User'

  STATUSES = %w[scheduled pending executing completed failed cancelled paused].freeze
  PLATFORM_TYPES = %w[meta google_ads linkedin twitter].freeze
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :scheduled_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, presence: true, numericality: { 
    greater_than: 0, 
    less_than_or_equal_to: 10 
  }
  
  validate :scheduled_at_in_future, on: :create
  validate :platform_targets_structure
  validate :execution_rules_structure
  
# JSON columns are automatically serialized in Rails 8
  # No need for explicit serialize statements
  
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_status, ->(status) { where(status: status) }
  scope :scheduled, -> { where(status: 'scheduled') }
  scope :pending, -> { where(status: 'pending') }
  scope :executing, -> { where(status: 'executing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :paused, -> { where(status: 'paused') }
  scope :ready_for_execution, -> { 
    active.where(status: 'scheduled').where('scheduled_at <= ?', Time.current) 
  }
  scope :by_priority, -> { order(:priority, :scheduled_at) }
  scope :high_priority, -> { where('priority <= ?', 3) }
  scope :needs_retry, -> { 
    failed.where('created_at > ?', 24.hours.ago).where(
      "(metadata->>'retry_count' IS NULL OR CAST(metadata->>'retry_count' AS INTEGER) < 3)"
    )
  }
  scope :overdue, -> { 
    scheduled.where('scheduled_at < ?', 1.hour.ago) 
  }
  scope :recent, -> { order(created_at: :desc) }
  
  before_validation :set_defaults, on: :create
  before_validation :calculate_next_execution
  after_create :schedule_execution_job
  after_update :handle_status_change, if: :saved_change_to_status?
  
  # Status check methods
  STATUSES.each do |status_name|
    define_method "#{status_name}?" do
      status == status_name
    end
  end
  
  def can_be_executed?
    scheduled? && active? && scheduled_at <= Time.current
  end
  
  def can_be_cancelled?
    %w[scheduled pending].include?(status)
  end
  
  def can_be_paused?
    %w[scheduled pending].include?(status)
  end
  
  def can_be_resumed?
    paused?
  end
  
  def can_be_retried?
    failed? && retry_count < 3
  end
  
  # Execution control methods
  def mark_pending!(user = nil)
    update!(
      status: 'pending',
      updated_by: user || updated_by,
      metadata: metadata.merge(
        status_changed_at: Time.current,
        status_changed_by: user&.id
      )
    )
  end
  
  def mark_executing!(user = nil)
    update!(
      status: 'executing',
      updated_by: user || updated_by,
      last_executed_at: Time.current,
      metadata: metadata.merge(
        execution_started_at: Time.current,
        status_changed_at: Time.current,
        status_changed_by: user&.id
      )
    )
  end
  
  def mark_completed!(user = nil, execution_result = {})
    update!(
      status: 'completed',
      updated_by: user || updated_by,
      metadata: metadata.merge(
        execution_completed_at: Time.current,
        execution_result: execution_result,
        status_changed_at: Time.current,
        status_changed_by: user&.id
      )
    )
  end
  
  def mark_failed!(user = nil, error_message = nil, execution_result = {})
    new_metadata = metadata.merge(
      execution_failed_at: Time.current,
      error_message: error_message,
      execution_result: execution_result,
      status_changed_at: Time.current,
      status_changed_by: user&.id,
      retry_count: retry_count + 1
    )
    
    update!(
      status: 'failed',
      updated_by: user || updated_by,
      metadata: new_metadata
    )
  end
  
  def cancel!(user = nil, reason = nil)
    return false unless can_be_cancelled?
    
    update!(
      status: 'cancelled',
      updated_by: user || updated_by,
      metadata: metadata.merge(
        cancelled_at: Time.current,
        cancelled_by: user&.id,
        cancellation_reason: reason,
        status_changed_at: Time.current
      )
    )
  end
  
  def pause!(user = nil, reason = nil)
    return false unless can_be_paused?
    
    update!(
      status: 'paused',
      updated_by: user || updated_by,
      metadata: metadata.merge(
        paused_at: Time.current,
        paused_by: user&.id,
        pause_reason: reason,
        status_changed_at: Time.current
      )
    )
  end
  
  def resume!(user = nil)
    return false unless can_be_resumed?
    
    update!(
      status: 'scheduled',
      updated_by: user || updated_by,
      metadata: metadata.merge(
        resumed_at: Time.current,
        resumed_by: user&.id,
        status_changed_at: Time.current
      )
    )
    
    schedule_execution_job
    true
  end
  
  def retry!(user = nil)
    return false unless can_be_retried?
    
    update!(
      status: 'scheduled',
      updated_by: user || updated_by,
      scheduled_at: calculate_retry_time,
      metadata: metadata.merge(
        retried_at: Time.current,
        retried_by: user&.id,
        status_changed_at: Time.current
      )
    )
    
    schedule_execution_job
    true
  end
  
  # Platform and execution methods
  def target_platforms
    return [] unless platform_targets.is_a?(Hash)
    platform_targets.keys.select { |platform| PLATFORM_TYPES.include?(platform) }
  end
  
  def platform_config(platform)
    return {} unless platform_targets.is_a?(Hash)
    platform_targets[platform] || {}
  end
  
  def has_platform?(platform)
    target_platforms.include?(platform.to_s)
  end
  
  def execution_window
    rules = execution_rules || {}
    {
      start_hour: rules['start_hour'] || 9,
      end_hour: rules['end_hour'] || 17,
      timezone: rules['timezone'] || 'UTC',
      days_of_week: rules['days_of_week'] || (1..5).to_a
    }
  end
  
  def in_execution_window?(time = Time.current)
    window = execution_window
    time_in_zone = time.in_time_zone(window[:timezone])
    
    # Check day of week (1 = Monday, 7 = Sunday)
    return false unless window[:days_of_week].include?(time_in_zone.wday == 0 ? 7 : time_in_zone.wday)
    
    # Check hour range
    current_hour = time_in_zone.hour
    current_hour >= window[:start_hour] && current_hour < window[:end_hour]
  end
  
  def next_valid_execution_time
    return scheduled_at if in_execution_window?(scheduled_at)
    
    window = execution_window
    base_time = scheduled_at.in_time_zone(window[:timezone])
    reference_time = [scheduled_at, Time.current].max
    
    # Find next valid day and time
    (0..14).each do |days_ahead|
      candidate_time = base_time.beginning_of_day + days_ahead.days + window[:start_hour].hours
      
      if window[:days_of_week].include?(candidate_time.wday == 0 ? 7 : candidate_time.wday) &&
         candidate_time > reference_time
        return candidate_time.utc
      end
    end
    
    # Fallback to next Monday at start hour
    days_until_monday = (8 - base_time.wday) % 7
    days_until_monday = 7 if days_until_monday == 0
    next_monday = base_time.beginning_of_day + days_until_monday.days + window[:start_hour].hours
    next_monday.utc
  end
  
  # Metadata helpers
  def retry_count
    return 0 unless metadata.present?
    metadata.dig('retry_count') || 0
  end
  
  def execution_duration
    return nil unless metadata.present? && 
                      metadata.dig('execution_started_at') && 
                      metadata.dig('execution_completed_at')
    
    start_time = Time.parse(metadata['execution_started_at'])
    end_time = Time.parse(metadata['execution_completed_at'])
    end_time - start_time
  end
  
  def execution_summary
    {
      id: id,
      name: name,
      status: status,
      priority: priority,
      scheduled_at: scheduled_at,
      target_platforms: target_platforms,
      retry_count: retry_count,
      execution_duration: execution_duration,
      can_execute: can_be_executed?,
      in_execution_window: in_execution_window?,
      next_execution_at: next_execution_at
    }
  end
  
  def rollback_capabilities
    {
      can_rollback: completed? && metadata.dig('rollback_data').present?,
      rollback_platforms: metadata.dig('rollback_data', 'platforms') || [],
      rollback_prepared_at: metadata.dig('rollback_data', 'prepared_at')
    }
  end
  
  def prepare_rollback_data!(rollback_data)
    update!(
      metadata: metadata.merge(
        rollback_data: {
          platforms: rollback_data[:platforms] || [],
          campaign_ids: rollback_data[:campaign_ids] || {},
          prepared_at: Time.current,
          prepared_by: rollback_data[:user_id]
        }
      )
    )
  end
  
  private
  
  def set_defaults
    self.platform_targets ||= {}
    self.execution_rules ||= {}
    self.metadata ||= {}
    self.priority ||= 5
    self.status ||= 'scheduled'
    self.active = true if active.nil?
  end
  
  def scheduled_at_in_future
    return unless scheduled_at.present?
    
    if scheduled_at <= Time.current
      errors.add(:scheduled_at, 'must be in the future')
    end
  end
  
  def platform_targets_structure
    return if platform_targets.blank?
    
    unless platform_targets.is_a?(Hash)
      errors.add(:platform_targets, 'must be a valid JSON object')
      return
    end
    
    platform_targets.each do |platform, config|
      unless PLATFORM_TYPES.include?(platform.to_s)
        errors.add(:platform_targets, "includes unsupported platform: #{platform}")
      end
      
      unless config.is_a?(Hash)
        errors.add(:platform_targets, "configuration for #{platform} must be an object")
      end
    end
  end
  
  def execution_rules_structure
    return if execution_rules.blank?
    
    unless execution_rules.is_a?(Hash)
      errors.add(:execution_rules, 'must be a valid JSON object')
      return
    end
    
    rules = execution_rules
    
    if rules['start_hour'].present? && (!rules['start_hour'].is_a?(Integer) || rules['start_hour'] < 0 || rules['start_hour'] > 23)
      errors.add(:execution_rules, 'start_hour must be between 0 and 23')
    end
    
    if rules['end_hour'].present? && (!rules['end_hour'].is_a?(Integer) || rules['end_hour'] < 0 || rules['end_hour'] > 23)
      errors.add(:execution_rules, 'end_hour must be between 0 and 23')
    end
    
    if rules['start_hour'].present? && rules['end_hour'].present? && rules['start_hour'] >= rules['end_hour']
      errors.add(:execution_rules, 'start_hour must be before end_hour')
    end
  end
  
  def calculate_next_execution
    return unless scheduled_at.present?
    
    if scheduled_at_changed? && scheduled_at > Time.current
      self.next_execution_at = next_valid_execution_time
    end
  end
  
  def schedule_execution_job
    return unless scheduled? && active?
    
    CampaignExecutionJob.set(wait_until: next_execution_at || scheduled_at)
                       .perform_later(id)
  end
  
  def handle_status_change
    case status
    when 'scheduled'
      schedule_execution_job if active?
    when 'completed'
      calculate_next_recurring_execution
    end
  end
  
  def calculate_retry_time
    base_delay = [2 ** retry_count, 60].min.minutes
    scheduled_at + base_delay + rand(5.minutes)
  end
  
  def calculate_next_recurring_execution
    return unless execution_rules.dig('recurring')
    
    interval = execution_rules.dig('recurring_interval') || 'weekly'
    case interval
    when 'daily'
      self.scheduled_at = scheduled_at + 1.day
    when 'weekly' 
      self.scheduled_at = scheduled_at + 1.week
    when 'monthly'
      self.scheduled_at = scheduled_at + 1.month
    end
    
    self.status = 'scheduled'
    self.next_execution_at = next_valid_execution_time
    save!
    
    schedule_execution_job
  end
end