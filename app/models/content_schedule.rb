class ContentSchedule < ApplicationRecord
  include AASM

  # Associations
  belongs_to :content_item, polymorphic: true
  belongs_to :campaign
  has_many :publishing_queues, dependent: :destroy

  # Validations
  validates :channel, presence: true
  validates :platform, presence: true
  validates :scheduled_at, presence: true
  validates :status, presence: true
  validates :priority, presence: true, numericality: { in: 1..5 }
  validates :time_zone, presence: true
  validate :scheduled_at_in_future, if: :scheduled_at_changed?
  validate :valid_recurrence_data, if: :recurrence_data_present?

  # Enums
  enum :status, {
    draft: 0,
    scheduled: 1,
    published: 2,
    failed: 3,
    cancelled: 4,
    paused: 5
  }

  enum :frequency, {
    once: 'once',
    daily: 'daily',
    weekly: 'weekly',
    monthly: 'monthly',
    yearly: 'yearly',
    custom: 'custom'
  }

  # Serialized attributes
  serialize :metadata, coder: JSON
  serialize :recurrence_data, coder: JSON

  # Scopes
  scope :upcoming, -> { where('scheduled_at > ?', Time.current) }
  scope :past_due, -> { where('scheduled_at < ? AND status IN (?)', Time.current, [statuses[:scheduled]]) }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :by_campaign, ->(campaign) { where(campaign: campaign) }
  scope :auto_publishable, -> { where(auto_publish: true, status: statuses[:scheduled]) }
  scope :ready_for_publishing, -> { where('scheduled_at <= ? AND status = ?', Time.current, statuses[:scheduled]) }
  scope :by_date_range, ->(start_date, end_date) { where(scheduled_at: start_date..end_date) }
  scope :high_priority, -> { where(priority: [4, 5]) }
  scope :recurring, -> { where.not(frequency: frequencies[:once]) }

  # Callbacks
  before_validation :set_defaults
  after_create :create_publishing_queue_entry
  after_update :handle_schedule_changes

  # AASM State Machine
  aasm column: :status, enum: true do
    state :draft, initial: true
    state :scheduled
    state :published
    state :failed
    state :cancelled
    state :paused

    event :schedule do
      transitions from: [:draft, :paused], to: :scheduled
      before do
        self.publishing_queues.pending.update_all(processing_status: 'scheduled')
      end
    end

    event :publish do
      transitions from: :scheduled, to: :published
      before do
        self.published_at = Time.current
      end
    end

    event :fail_publishing do
      transitions from: :scheduled, to: :failed
    end

    event :cancel do
      transitions from: [:draft, :scheduled, :paused], to: :cancelled
      before do
        self.publishing_queues.pending.update_all(processing_status: 'cancelled')
      end
    end

    event :pause do
      transitions from: :scheduled, to: :paused
      before do
        self.publishing_queues.pending.update_all(processing_status: 'paused')
      end
    end

    event :resume do
      transitions from: :paused, to: :scheduled
      before do
        self.publishing_queues.paused.update_all(processing_status: 'scheduled')
      end
    end
  end

  # Instance methods
  def content_preview
    case content_item_type
    when 'ContentVariant'
      content_item&.content&.truncate(100)
    when 'ContentAsset'
      content_item&.title || content_item&.content&.truncate(100)
    else
      'Content preview unavailable'
    end
  end

  def scheduled_at_in_timezone
    return scheduled_at unless time_zone.present?
    
    scheduled_at.in_time_zone(time_zone)
  end

  def is_overdue?
    scheduled? && scheduled_at < Time.current
  end

  def is_upcoming?
    scheduled? && scheduled_at > Time.current
  end

  def can_auto_publish?
    auto_publish? && scheduled? && scheduled_at <= Time.current
  end

  def time_until_publish
    return nil unless scheduled?
    
    time_diff = scheduled_at - Time.current
    return nil if time_diff <= 0
    
    if time_diff > 1.day
      "#{(time_diff / 1.day).floor} days"
    elsif time_diff > 1.hour
      "#{(time_diff / 1.hour).floor} hours"
    else
      "#{(time_diff / 1.minute).floor} minutes"
    end
  end

  def next_occurrence
    return nil unless recurring?
    return nil unless recurrence_data.present?

    case frequency
    when 'daily'
      scheduled_at + recurrence_data['interval'].to_i.days
    when 'weekly'
      scheduled_at + recurrence_data['interval'].to_i.weeks
    when 'monthly'
      scheduled_at + recurrence_data['interval'].to_i.months
    when 'yearly'
      scheduled_at + recurrence_data['interval'].to_i.years
    when 'custom'
      calculate_custom_next_occurrence
    else
      nil
    end
  end

  def duplicate_for_next_occurrence
    return nil unless next_occurrence

    new_schedule = self.dup
    new_schedule.scheduled_at = next_occurrence
    new_schedule.status = 'draft'
    new_schedule.published_at = nil
    new_schedule.created_at = nil
    new_schedule.updated_at = nil
    
    new_schedule
  end

  def conflicts_with?(other_schedule)
    return false unless other_schedule.is_a?(ContentSchedule)
    return false if other_schedule == self
    
    # Check for same platform and overlapping time windows
    same_platform = platform == other_schedule.platform
    time_overlap = time_windows_overlap?(self, other_schedule)
    
    same_platform && time_overlap
  end

  def platform_constraints
    return { max_posts_per_hour: 5, max_posts_per_day: 20, min_interval_minutes: 60 } unless platform.present?
    
    case platform.downcase
    when 'twitter'
      { max_posts_per_hour: 25, max_posts_per_day: 100, min_interval_minutes: 5 }
    when 'instagram'
      { max_posts_per_hour: 5, max_posts_per_day: 25, min_interval_minutes: 30 }
    when 'linkedin'
      { max_posts_per_hour: 10, max_posts_per_day: 50, min_interval_minutes: 15 }
    when 'facebook'
      { max_posts_per_hour: 10, max_posts_per_day: 50, min_interval_minutes: 10 }
    else
      { max_posts_per_hour: 5, max_posts_per_day: 20, min_interval_minutes: 60 }
    end
  end

  def validate_platform_constraints
    constraints = platform_constraints
    validation_errors = []

    # Check hourly limits
    hour_start = scheduled_at.beginning_of_hour
    hour_end = scheduled_at.end_of_hour
    hourly_count = ContentSchedule.where(
      platform: platform,
      scheduled_at: hour_start..hour_end,
      status: ['scheduled', 'published']
    ).where.not(id: id).count

    if hourly_count >= constraints[:max_posts_per_hour]
      validation_errors << "Exceeds hourly posting limit for #{platform} (#{constraints[:max_posts_per_hour]} posts/hour)"
    end

    # Check daily limits
    day_start = scheduled_at.beginning_of_day
    day_end = scheduled_at.end_of_day
    daily_count = ContentSchedule.where(
      platform: platform,
      scheduled_at: day_start..day_end,
      status: ['scheduled', 'published']
    ).where.not(id: id).count

    if daily_count >= constraints[:max_posts_per_day]
      validation_errors << "Exceeds daily posting limit for #{platform} (#{constraints[:max_posts_per_day]} posts/day)"
    end

    validation_errors
  end

  # Class methods
  class << self
    def schedule_content(content_item, options = {})
      campaign = options[:campaign] || (options[:campaign_id] ? Campaign.find(options[:campaign_id]) : nil)
      schedule = new(
        content_item: content_item,
        campaign: campaign,
        channel: options[:channel] || 'social_media',
        platform: options[:platform],
        scheduled_at: options[:scheduled_at],
        priority: options[:priority] || 3,
        auto_publish: options[:auto_publish] || false,
        time_zone: options[:time_zone] || 'UTC',
        frequency: options[:frequency] || 'once',
        recurrence_data: options[:recurrence_data],
        metadata: options[:metadata] || {}
      )

      if schedule.save
        schedule.schedule! if options[:auto_schedule]
        schedule
      else
        schedule
      end
    end

    def bulk_schedule(content_items, base_options = {})
      results = []
      
      content_items.each_with_index do |content_item, index|
        options = base_options.dup
        
        # Stagger scheduling times to avoid conflicts
        if options[:scheduled_at] && options[:stagger_minutes]
          scheduled_time = options[:scheduled_at].is_a?(String) ? Time.parse(options[:scheduled_at]) : options[:scheduled_at]
          options[:scheduled_at] = scheduled_time + (index * options[:stagger_minutes].to_i).minutes
        end
        
        results << schedule_content(content_item, options)
      end
      
      results
    end

    def find_conflicts(start_time, end_time, platform, exclude_id = nil)
      query = where(
        platform: platform,
        status: ['scheduled', 'published']
      ).where('scheduled_at BETWEEN ? AND ?', start_time, end_time)
      
      query = query.where.not(id: exclude_id) if exclude_id
      query
    end

    def available_time_slots(platform, date, duration_minutes = 5)
      constraints = new.platform_constraints
      min_interval = constraints[:min_interval_minutes]
      
      day_start = date.beginning_of_day
      day_end = date.end_of_day
      
      existing_schedules = where(
        platform: platform,
        scheduled_at: day_start..day_end,
        status: ['scheduled', 'published']
      ).order(:scheduled_at)
      
      available_slots = []
      current_time = day_start
      
      existing_schedules.each do |schedule|
        if current_time < schedule.scheduled_at - min_interval.minutes
          available_slots << {
            start_time: current_time,
            end_time: schedule.scheduled_at - min_interval.minutes,
            duration: ((schedule.scheduled_at - min_interval.minutes) - current_time) / 1.minute
          }
        end
        current_time = schedule.scheduled_at + duration_minutes.minutes
      end
      
      # Add remaining time until end of day
      if current_time < day_end
        available_slots << {
          start_time: current_time,
          end_time: day_end,
          duration: (day_end - current_time) / 1.minute
        }
      end
      
      available_slots
    end

    def generate_optimal_schedule(content_items, platform, start_date, options = {})
      constraints = new.platform_constraints
      optimal_schedules = []
      current_date = start_date.to_date
      
      content_items.each_with_index do |content_item, index|
        # Keep trying until we find a slot (within reason)
        max_days_ahead = 30
        days_searched = 0
        
        loop do
          available_slots = available_time_slots(platform, current_date)
          
          if available_slots.any?
            best_slot = find_best_time_slot(available_slots, options)
            
            optimal_schedules << {
              content_item: content_item,
              scheduled_at: best_slot[:start_time],
              platform: platform,
              estimated_engagement: calculate_engagement_score(best_slot[:start_time], platform)
            }
            break
          else
            # Move to next day if no slots available
            current_date += 1.day
            days_searched += 1
            
            # Prevent infinite loop
            if days_searched >= max_days_ahead
              Rails.logger.warn "Could not find available slot for content item #{content_item.id} within #{max_days_ahead} days"
              break
            end
          end
        end
        
        # Move to next day after certain number of posts
        if (index + 1) % (constraints[:max_posts_per_day] / 2) == 0
          current_date += 1.day
        end
      end
      
      optimal_schedules
    end

    private

    def find_best_time_slot(available_slots, options = {})
      # Prioritize slots based on engagement patterns
      best_times = options[:best_times] || {
        'twitter' => [9, 12, 15, 18], # Hours of day
        'instagram' => [8, 12, 17, 20],
        'linkedin' => [8, 12, 13, 17],
        'facebook' => [9, 13, 15, 18]
      }
      
      platform_best_times = best_times[options[:platform]&.downcase] || [9, 12, 15, 18]
      
      scored_slots = available_slots.map do |slot|
        hour = slot[:start_time].hour
        engagement_score = platform_best_times.include?(hour) ? 10 : 5
        
        {
          slot: slot,
          score: engagement_score + (slot[:duration] > 60 ? 2 : 0)
        }
      end
      
      scored_slots.max_by { |scored_slot| scored_slot[:score] }[:slot]
    end

    def calculate_engagement_score(time, platform)
      # Simple engagement scoring based on time and platform
      hour = time.hour
      day_of_week = time.wday
      
      base_score = 50
      
      # Time-based scoring
      case platform.downcase
      when 'twitter'
        base_score += 20 if [9, 12, 15, 18].include?(hour)
        base_score += 10 if [1, 2, 3, 4, 5].include?(day_of_week) # Weekdays
      when 'instagram'
        base_score += 20 if [8, 12, 17, 20].include?(hour)
        base_score += 15 if [6, 0].include?(day_of_week) # Weekends
      when 'linkedin'
        base_score += 25 if [8, 12, 13, 17].include?(hour)
        base_score += 20 if [1, 2, 3, 4, 5].include?(day_of_week) # Weekdays
      end
      
      base_score
    end
  end

  private

  def set_defaults
    self.time_zone ||= 'UTC'
    self.priority ||= 3
    self.frequency ||= 'once'
    self.metadata ||= {}
    self.auto_publish ||= false
  end

  def scheduled_at_in_future
    return unless scheduled_at.present?
    
    if scheduled_at <= Time.current
      errors.add(:scheduled_at, 'must be in the future')
    end
  end

  def recurrence_data_present?
    recurrence_data.present? && recurring?
  end

  def valid_recurrence_data
    return unless recurrence_data.is_a?(Hash)
    
    case frequency
    when 'daily', 'weekly', 'monthly', 'yearly'
      unless recurrence_data['interval'].present? && recurrence_data['interval'].to_i > 0
        errors.add(:recurrence_data, 'must include valid interval')
      end
    when 'custom'
      unless recurrence_data['pattern'].present?
        errors.add(:recurrence_data, 'must include custom pattern')
      end
    end
  end

  def create_publishing_queue_entry
    return unless scheduled?
    
    publishing_queues.create!(
      scheduled_for: scheduled_at,
      processing_status: 'pending',
      max_retries: 3
    )
  end

  def handle_schedule_changes
    if saved_change_to_scheduled_at? && scheduled?
      publishing_queues.pending.update_all(scheduled_for: scheduled_at)
    end
    
    if saved_change_to_status? && cancelled?
      publishing_queues.pending.update_all(processing_status: 'cancelled')
    end
  end

  def calculate_custom_next_occurrence
    return nil unless recurrence_data['pattern'].present?
    
    # Implement custom recurrence pattern logic
    # This is a simplified version - could be expanded based on needs
    pattern = recurrence_data['pattern']
    
    case pattern
    when 'weekdays'
      next_weekday = scheduled_at
      loop do
        next_weekday += 1.day
        break if next_weekday.weekday?
      end
      next_weekday
    when 'weekends'
      next_weekend = scheduled_at
      loop do
        next_weekend += 1.day
        break if next_weekend.weekend?
      end
      next_weekend
    else
      scheduled_at + 1.week # Default fallback
    end
  end

  def time_windows_overlap?(schedule1, schedule2)
    duration_minutes = 5 # Assume 5-minute window per post
    
    start1 = schedule1.scheduled_at
    end1 = start1 + duration_minutes.minutes
    
    start2 = schedule2.scheduled_at
    end2 = start2 + duration_minutes.minutes
    
    # Check if time windows overlap
    start1 < end2 && start2 < end1
  end
end