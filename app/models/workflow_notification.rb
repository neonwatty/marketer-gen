# WorkflowNotification model - Stores in-app notifications for workflow events
# Manages notification delivery, read status, and user interaction tracking
class WorkflowNotification < ApplicationRecord
  belongs_to :workflow, class_name: 'ContentWorkflow', foreign_key: 'workflow_id', optional: true
  # User tracking - can be extended when User model is added
  # belongs_to :user
  
  validates :user_id, presence: true
  validates :notification_type, presence: true, inclusion: { 
    in: WorkflowNotificationService::NOTIFICATION_TYPES,
    message: 'must be a valid notification type'
  }
  validates :title, presence: true, length: { minimum: 1, maximum: 200 }
  validates :message, presence: true, length: { minimum: 1, maximum: 1000 }
  validates :priority, presence: true, inclusion: { 
    in: %w[low normal high urgent critical],
    message: 'must be a valid priority level'
  }
  
  # Priority levels (enum)
  enum :priority, {
    low: 1,
    normal: 2,
    high: 3,
    urgent: 4,
    critical: 5
  }
  
  # Notification status
  enum :status, {
    pending: 0,
    delivered: 1,
    read: 2,
    dismissed: 3,
    archived: 4,
    failed: 5
  }
  
  serialize :metadata, coder: JSON
  
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :by_priority, ->(priority_level) { where(priority: priority_level) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_workflow, ->(workflow_id) { where(workflow_id: workflow_id) }
  scope :high_priority, -> { where(priority: [:urgent, :critical]) }
  scope :active, -> { where.not(status: [:dismissed, :archived]) }
  scope :recent_days, ->(days = 7) { where('created_at >= ?', days.days.ago) }
  
  before_validation :set_defaults, on: :create
  after_create :mark_as_delivered
  
  def initialize(attributes = {})
    super(attributes)
    self.metadata ||= {}
  end
  
  # Notification state management
  def mark_as_read!(read_by = nil)
    return if read?
    
    update!(
      read_at: Time.current,
      status: :read,
      metadata: metadata.merge({
        read_by: read_by&.id,
        read_timestamp: Time.current.iso8601
      })
    )
    
    log_interaction('read')
  end
  
  def mark_as_dismissed!(dismissed_by = nil)
    update!(
      dismissed_at: Time.current,
      status: :dismissed,
      metadata: metadata.merge({
        dismissed_by: dismissed_by&.id,
        dismissed_timestamp: Time.current.iso8601
      })
    )
    
    log_interaction('dismissed')
  end
  
  def mark_as_archived!(archived_by = nil)
    update!(
      archived_at: Time.current,
      status: :archived,
      metadata: metadata.merge({
        archived_by: archived_by&.id,
        archived_timestamp: Time.current.iso8601
      })
    )
    
    log_interaction('archived')
  end
  
  def clicked!(click_target = nil)
    self.clicked_at = Time.current
    self.click_count = (click_count || 0) + 1
    
    self.metadata = metadata.merge({
      last_click_timestamp: Time.current.iso8601,
      click_target: click_target,
      total_clicks: click_count
    })
    
    save!
    log_interaction('clicked', click_target)
    
    # Auto-mark as read when clicked
    mark_as_read! unless read?
  end
  
  # Notification properties
  def is_read?
    read_at.present?
  end
  
  def is_unread?
    !is_read?
  end
  
  def is_dismissed?
    dismissed_at.present?
  end
  
  def is_high_priority?
    urgent? || critical?
  end
  
  def is_recent?(hours = 24)
    created_at > hours.hours.ago
  end
  
  def is_stale?(days = 30)
    created_at < days.days.ago
  end
  
  def has_been_clicked?
    clicked_at.present?
  end
  
  def time_since_created
    Time.current - created_at
  end
  
  def time_until_read
    return nil unless read_at
    read_at - created_at
  end
  
  def engagement_score
    score = 0
    
    # Base score for delivery
    score += 10
    
    # Points for reading
    score += 30 if is_read?
    
    # Points for clicking
    score += 50 if has_been_clicked?
    
    # Bonus for quick engagement
    if time_until_read && time_until_read < 1.hour
      score += 20
    end
    
    # Penalty for dismissal without reading
    score -= 20 if is_dismissed? && is_unread?
    
    score
  end
  
  # Content and formatting
  def notification_icon
    case notification_type
    when 'workflow_started'
      'play-circle'
    when 'stage_transitioned'
      'arrow-right'
    when 'assignment_created'
      'user-plus'
    when 'assignment_expiring'
      'clock'
    when 'workflow_overdue'
      'alert-triangle'
    when 'approval_requested'
      'check-circle'
    when 'content_rejected'
      'x-circle'
    when 'content_approved'
      'check'
    when 'content_published'
      'globe'
    when 'workflow_completed'
      'check-circle'
    when 'workflow_cancelled'
      'x'
    else
      'bell'
    end
  end
  
  def priority_color
    case priority
    when 'critical'
      '#dc3545' # Red
    when 'urgent'
      '#fd7e14' # Orange
    when 'high'
      '#ffc107' # Yellow
    when 'normal'
      '#0d6efd' # Blue
    when 'low'
      '#6c757d' # Gray
    end
  end
  
  def priority_badge
    case priority
    when 'critical', 'urgent'
      'danger'
    when 'high'
      'warning'
    when 'normal'
      'primary'
    when 'low'
      'secondary'
    end
  end
  
  def action_url
    return nil unless workflow_id
    
    # Generate appropriate action URL based on notification type
    case notification_type
    when 'assignment_created', 'approval_requested', 'stage_transitioned'
      "/workflows/#{workflow_id}"
    when 'content_published'
      "/workflows/#{workflow_id}/published"
    when 'workflow_completed'
      "/workflows/#{workflow_id}/summary"
    else
      "/workflows/#{workflow_id}"
    end
  end
  
  def call_to_action
    case notification_type
    when 'assignment_created'
      'View Assignment'
    when 'approval_requested'
      'Review Content'
    when 'stage_transitioned'
      'View Workflow'
    when 'content_rejected'
      'Make Changes'
    when 'content_approved'
      'Prepare for Publishing'
    when 'workflow_overdue'
      'Take Action'
    when 'assignment_expiring'
      'Extend Assignment'
    when 'content_published'
      'View Published Content'
    else
      'View Details'
    end
  end
  
  def display_time
    if created_at > 1.hour.ago
      "#{((Time.current - created_at) / 60).round}m ago"
    elsif created_at > 1.day.ago
      "#{((Time.current - created_at) / 1.hour).round}h ago"
    elsif created_at > 1.week.ago
      "#{((Time.current - created_at) / 1.day).round}d ago"
    else
      created_at.strftime('%b %d')
    end
  end
  
  # Export and API
  def to_notification_hash
    {
      id: id,
      type: notification_type,
      title: title,
      message: message,
      priority: priority,
      priority_color: priority_color,
      icon: notification_icon,
      workflow_id: workflow_id,
      created_at: created_at,
      read_at: read_at,
      clicked_at: clicked_at,
      display_time: display_time,
      action_url: action_url,
      call_to_action: call_to_action,
      is_read: is_read?,
      is_high_priority: is_high_priority?,
      engagement_score: engagement_score,
      metadata: metadata
    }
  end
  
  def to_json_api
    {
      id: id.to_s,
      type: 'workflow_notification',
      attributes: {
        notification_type: notification_type,
        title: title,
        message: message,
        priority: priority,
        status: status,
        workflow_id: workflow_id,
        created_at: created_at.iso8601,
        read_at: read_at&.iso8601,
        clicked_at: clicked_at&.iso8601,
        dismissed_at: dismissed_at&.iso8601,
        is_read: is_read?,
        is_dismissed: is_dismissed?,
        engagement_score: engagement_score,
        action_url: action_url,
        call_to_action: call_to_action,
        display_time: display_time,
        metadata: metadata
      },
      relationships: {
        workflow: {
          data: workflow_id ? { id: workflow_id.to_s, type: 'content_workflow' } : nil
        }
      }
    }
  end
  
  # Class methods for management and analytics
  def self.mark_all_as_read_for_user(user_id)
    unread.for_user(user_id).update_all(
      read_at: Time.current,
      status: :read,
      updated_at: Time.current
    )
  end
  
  def self.cleanup_old_notifications(days = 90)
    old_notifications = where('created_at < ?', days.days.ago)
                       .where(status: [:read, :dismissed, :archived])
    
    cleanup_count = old_notifications.count
    old_notifications.delete_all
    
    cleanup_count
  end
  
  def self.user_notification_summary(user_id, days = 30)
    notifications = for_user(user_id).where('created_at >= ?', days.days.ago)
    
    {
      total_notifications: notifications.count,
      unread_count: notifications.unread.count,
      high_priority_count: notifications.high_priority.count,
      read_rate: calculate_read_rate(notifications),
      average_engagement_score: notifications.average(:engagement_score)&.round(2) || 0,
      most_common_types: notifications.group(:notification_type).count.sort_by { |_type, count| -count }.first(5).to_h,
      notification_frequency: calculate_notification_frequency(notifications, days)
    }
  end
  
  def self.notification_analytics(start_date: 1.month.ago, end_date: Time.current)
    notifications = where(created_at: start_date..end_date)
    
    {
      total_sent: notifications.count,
      delivery_rate: (notifications.delivered.count.to_f / notifications.count * 100).round(2),
      read_rate: calculate_read_rate(notifications),
      click_rate: calculate_click_rate(notifications),
      engagement_by_type: calculate_engagement_by_type(notifications),
      engagement_by_priority: calculate_engagement_by_priority(notifications),
      peak_notification_hours: calculate_peak_hours(notifications),
      user_engagement_distribution: calculate_user_engagement_distribution(notifications)
    }
  end
  
  def self.bulk_mark_as_read(notification_ids, user_id = nil)
    scope = where(id: notification_ids)
    scope = scope.where(user_id: user_id) if user_id
    
    scope.unread.update_all(
      read_at: Time.current,
      status: :read,
      updated_at: Time.current
    )
  end
  
  def self.bulk_dismiss(notification_ids, user_id = nil)
    scope = where(id: notification_ids)
    scope = scope.where(user_id: user_id) if user_id
    
    scope.where.not(status: :dismissed).update_all(
      dismissed_at: Time.current,
      status: :dismissed,
      updated_at: Time.current
    )
  end
  
  private
  
  def set_defaults
    self.status ||= :pending
    self.priority ||= :normal
    self.click_count ||= 0
    self.metadata ||= {}
  end
  
  def mark_as_delivered
    update_column(:status, :delivered) if pending?
  end
  
  def log_interaction(interaction_type, target = nil)
    interaction_data = {
      interaction_type: interaction_type,
      timestamp: Time.current.iso8601,
      target: target
    }.compact
    
    interactions = metadata['interactions'] || []
    interactions << interaction_data
    
    update_column(:metadata, metadata.merge('interactions' => interactions))
  end
  
  def self.calculate_read_rate(notifications)
    return 0 if notifications.empty?
    
    read_count = notifications.read.count
    (read_count.to_f / notifications.count * 100).round(2)
  end
  
  def self.calculate_click_rate(notifications)
    return 0 if notifications.empty?
    
    clicked_count = notifications.where.not(clicked_at: nil).count
    (clicked_count.to_f / notifications.count * 100).round(2)
  end
  
  def self.calculate_engagement_by_type(notifications)
    notifications.group(:notification_type).average(:engagement_score)
                .sort_by { |_type, score| -score }
                .to_h
  end
  
  def self.calculate_engagement_by_priority(notifications)
    notifications.group(:priority).average(:engagement_score)
                .sort_by { |_priority, score| -score }
                .to_h
  end
  
  def self.calculate_peak_hours(notifications)
    notifications.group("EXTRACT(hour FROM created_at)").count
                .sort_by { |_hour, count| -count }
                .first(5)
                .to_h
  end
  
  def self.calculate_user_engagement_distribution(notifications)
    user_scores = notifications.group(:user_id).average(:engagement_score)
    
    {
      high_engagement: user_scores.count { |_user, score| score >= 80 },
      medium_engagement: user_scores.count { |_user, score| score >= 50 && score < 80 },
      low_engagement: user_scores.count { |_user, score| score < 50 }
    }
  end
  
  def self.calculate_notification_frequency(notifications, days)
    (notifications.count.to_f / days).round(2)
  end
end