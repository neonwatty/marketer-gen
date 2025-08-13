class PublishingQueue < ApplicationRecord
  include AASM

  # Associations
  belongs_to :content_schedule

  # Validations
  validates :processing_status, presence: true
  validates :scheduled_for, presence: true
  validates :retry_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_retries, presence: true, numericality: { greater_than_or_equal_to: 1 }

  # Enums
  enum :processing_status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3,
    cancelled: 4,
    paused: 5,
    scheduled: 6
  }

  # Serialized attributes
  serialize :processing_metadata, coder: JSON

  # Scopes
  scope :ready_for_processing, -> { where('scheduled_for <= ? AND processing_status IN (?)', Time.current, [processing_statuses[:pending], processing_statuses[:scheduled]]) }
  scope :overdue, -> { where('scheduled_for < ? AND processing_status = ?', Time.current, processing_statuses[:pending]) }
  scope :failed_retryable, -> { where(processing_status: processing_statuses[:failed]).where('retry_count < max_retries') }
  scope :by_batch, ->(batch_id) { where(batch_id: batch_id) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :set_defaults
  after_create :set_batch_id
  before_update :track_status_changes

  # AASM State Machine
  aasm column: :processing_status, enum: true do
    state :pending, initial: true
    state :scheduled
    state :processing
    state :completed
    state :failed
    state :cancelled
    state :paused

    event :start_processing do
      transitions from: [:pending, :scheduled], to: :processing
      before do
        self.attempted_at = Time.current
        update_processing_metadata('processing_started_at', Time.current)
      end
    end

    event :complete_processing do
      transitions from: :processing, to: :completed
      before do
        self.completed_at = Time.current
        self.content_schedule.publish! if self.content_schedule.may_publish?
        update_processing_metadata('completed_at', Time.current)
      end
    end

    event :fail_processing do
      transitions from: :processing, to: :failed
      before do
        self.retry_count += 1
        update_processing_metadata('failed_at', Time.current)
        update_processing_metadata('failure_count', (processing_metadata['failure_count'] || 0) + 1)
      end
    end

    event :cancel_processing do
      transitions from: [:pending, :scheduled, :processing, :failed], to: :cancelled
    end

    event :pause_processing do
      transitions from: [:pending, :scheduled], to: :paused
    end

    event :resume_processing do
      transitions from: :paused, to: :pending
    end

    event :retry_processing do
      transitions from: :failed, to: :pending, guard: :can_retry?
      before do
        update_processing_metadata('retry_attempted_at', Time.current)
      end
    end
  end

  # Instance methods
  def can_retry?
    retry_count < max_retries
  end

  def retries_remaining
    [max_retries - retry_count, 0].max
  end

  def is_overdue?
    pending? && scheduled_for < Time.current
  end

  def time_until_processing
    return nil unless pending? || scheduled?
    
    time_diff = scheduled_for - Time.current
    return nil if time_diff <= 0
    
    if time_diff > 1.day
      "#{(time_diff / 1.day).floor} days"
    elsif time_diff > 1.hour
      "#{(time_diff / 1.hour).floor} hours"
    else
      "#{(time_diff / 1.minute).floor} minutes"
    end
  end

  def processing_duration
    return nil unless attempted_at && completed_at
    
    ((completed_at - attempted_at) / 1.second).round(2)
  end

  def total_processing_time
    return nil unless processing_metadata['processing_started_at'] && completed_at
    
    start_time = Time.parse(processing_metadata['processing_started_at'])
    ((completed_at - start_time) / 1.second).round(2)
  end

  def next_retry_at
    return nil unless failed? && can_retry?
    
    # Exponential backoff: 1 min, 5 min, 15 min, 30 min, 1 hour
    backoff_minutes = case retry_count
                     when 0
                       1
                     when 1
                       5
                     when 2
                       15
                     when 3
                       30
                     else
                       60
                     end
    
    (attempted_at || created_at) + backoff_minutes.minutes
  end

  def should_retry_now?
    failed? && can_retry? && (next_retry_at <= Time.current)
  end

  def failure_reason
    error_message.presence || processing_metadata['last_error'] || 'Unknown error'
  end

  def processing_summary
    {
      status: processing_status,
      scheduled_for: scheduled_for,
      attempted_at: attempted_at,
      completed_at: completed_at,
      retry_count: retry_count,
      retries_remaining: retries_remaining,
      processing_duration: processing_duration,
      failure_reason: failed? ? failure_reason : nil,
      next_retry_at: failed? ? next_retry_at : nil
    }
  end

  def update_processing_metadata(key, value)
    self.processing_metadata ||= {}
    self.processing_metadata[key.to_s] = value
    save if persisted?
  end

  def add_processing_log(message, level: 'info')
    self.processing_metadata ||= {}
    self.processing_metadata['logs'] ||= []
    
    log_entry = {
      timestamp: Time.current.iso8601,
      level: level,
      message: message
    }
    
    self.processing_metadata['logs'] << log_entry
    
    # Keep only last 50 log entries to prevent unbounded growth
    if self.processing_metadata['logs'].length > 50
      self.processing_metadata['logs'] = self.processing_metadata['logs'].last(50)
    end
    
    save if persisted?
  end

  def processing_logs
    processing_metadata.dig('logs') || []
  end

  def latest_log
    processing_logs.last
  end

  # Class methods
  class << self
    def process_ready_items(limit = 10)
      ready_items = ready_for_processing.limit(limit)
      results = []

      ready_items.find_each do |queue_item|
        begin
          if queue_item.start_processing!
            result = process_queue_item(queue_item)
            results << { queue_item: queue_item, result: result }
          end
        rescue => e
          queue_item.update(error_message: e.message)
          queue_item.fail_processing! if queue_item.may_fail_processing?
          results << { queue_item: queue_item, result: { success: false, error: e.message } }
        end
      end

      results
    end

    def retry_failed_items
      failed_retryable.where('retry_count < max_retries').find_each do |queue_item|
        if queue_item.should_retry_now?
          queue_item.retry_processing!
        end
      end
    end

    def cleanup_old_completed(days_old = 7)
      where(processing_status: :completed)
        .where('completed_at < ?', days_old.days.ago)
        .delete_all
    end

    def batch_statistics(batch_id)
      batch_items = by_batch(batch_id)
      
      {
        total: batch_items.count,
        pending: batch_items.pending.count,
        processing: batch_items.processing.count,
        completed: batch_items.completed.count,
        failed: batch_items.failed.count,
        cancelled: batch_items.cancelled.count,
        success_rate: calculate_success_rate(batch_items),
        average_processing_time: calculate_average_processing_time(batch_items)
      }
    end

    def processing_statistics(time_range = 24.hours)
      items_in_range = where('created_at >= ?', time_range.ago)
      
      {
        total_processed: items_in_range.count,
        completed: items_in_range.completed.count,
        failed: items_in_range.failed.count,
        success_rate: calculate_success_rate(items_in_range),
        average_processing_time: calculate_average_processing_time(items_in_range),
        most_common_failures: most_common_failure_reasons(items_in_range)
      }
    end

    private

    def process_queue_item(queue_item)
      content_schedule = queue_item.content_schedule
      
      queue_item.add_processing_log("Starting processing for content schedule #{content_schedule.id}")
      
      # Simulate content publishing logic
      # In a real implementation, this would integrate with actual publishing APIs
      case content_schedule.platform.downcase
      when 'twitter'
        result = publish_to_twitter(content_schedule)
      when 'instagram'
        result = publish_to_instagram(content_schedule)
      when 'linkedin'
        result = publish_to_linkedin(content_schedule)
      when 'facebook'
        result = publish_to_facebook(content_schedule)
      else
        result = { success: false, error: "Unsupported platform: #{content_schedule.platform}" }
      end

      if result[:success]
        queue_item.add_processing_log("Successfully published to #{content_schedule.platform}")
        queue_item.update_processing_metadata('published_post_id', result[:post_id]) if result[:post_id]
        queue_item.complete_processing!
      else
        queue_item.add_processing_log("Failed to publish: #{result[:error]}", level: 'error')
        queue_item.update(error_message: result[:error])
        queue_item.fail_processing!
      end

      result
    end

    def publish_to_twitter(content_schedule)
      # Mock Twitter publishing
      content = content_schedule.content_preview
      
      if content.length > 280
        { success: false, error: "Content exceeds Twitter character limit" }
      else
        { success: true, post_id: "twitter_#{SecureRandom.hex(8)}" }
      end
    end

    def publish_to_instagram(content_schedule)
      # Mock Instagram publishing
      { success: true, post_id: "instagram_#{SecureRandom.hex(8)}" }
    end

    def publish_to_linkedin(content_schedule)
      # Mock LinkedIn publishing
      { success: true, post_id: "linkedin_#{SecureRandom.hex(8)}" }
    end

    def publish_to_facebook(content_schedule)
      # Mock Facebook publishing
      { success: true, post_id: "facebook_#{SecureRandom.hex(8)}" }
    end

    def calculate_success_rate(items)
      return 0 if items.count == 0
      
      completed_count = items.completed.count
      total_processed = items.where(processing_status: [:completed, :failed]).count
      
      return 0 if total_processed == 0
      
      ((completed_count.to_f / total_processed) * 100).round(2)
    end

    def calculate_average_processing_time(items)
      completed_items = items.completed.where.not(attempted_at: nil, completed_at: nil)
      return 0 if completed_items.count == 0
      
      total_time = completed_items.sum { |item| item.processing_duration || 0 }
      (total_time / completed_items.count).round(2)
    end

    def most_common_failure_reasons(items)
      failed_items = items.failed.where.not(error_message: nil)
      
      failure_counts = failed_items.group(:error_message).count
      failure_counts.sort_by { |_, count| -count }.first(5).to_h
    end
  end

  private

  def set_defaults
    self.retry_count ||= 0
    self.max_retries ||= 3
    self.processing_metadata ||= {}
  end

  def set_batch_id
    if batch_id.blank?
      self.update_column(:batch_id, "batch_#{Time.current.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(4)}")
    end
  end

  def track_status_changes
    if processing_status_changed?
      add_processing_log("Status changed from #{processing_status_was} to #{processing_status}")
    end
  end
end