class UserActivity < ApplicationRecord
  belongs_to :user

  # Constants for activity types
  ACTIVITY_TYPES = {
    login: 'login',
    logout: 'logout',
    create: 'create',
    update: 'update',
    delete: 'delete',
    view: 'view',
    download: 'download',
    upload: 'upload',
    failed_login: 'failed_login',
    password_reset: 'password_reset',
    profile_update: 'profile_update',
    suspicious_activity: 'suspicious_activity'
  }.freeze

  # Suspicious activity patterns
  SUSPICIOUS_PATTERNS = {
    rapid_requests: { threshold: 100, window: 1.minute },
    failed_logins: { threshold: 5, window: 15.minutes },
    unusual_hours: { start_hour: 2, end_hour: 5 }, # 2 AM - 5 AM
    mass_downloads: { threshold: 50, window: 10.minutes }
  }.freeze

  # Validations
  validates :action, presence: true
  validates :controller_name, presence: true
  validates :action_name, presence: true
  validates :ip_address, presence: true
  validates :performed_at, presence: true

  # Scopes
  scope :recent, -> { order(performed_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_date_range, ->(start_date, end_date) { where(performed_at: start_date..end_date) }
  scope :suspicious, -> { where(action: ACTIVITY_TYPES[:suspicious_activity]) }
  scope :failed_logins, -> { where(action: ACTIVITY_TYPES[:failed_login]) }

  # Callbacks
  before_validation :set_performed_at
  after_create :check_for_suspicious_activity

  # Class methods
  def self.log_activity(user, action, options = {})
    create!(
      user: user,
      action: action,
      controller_name: options[:controller_name] || 'unknown',
      action_name: options[:action_name] || 'unknown',
      resource_type: options[:resource_type],
      resource_id: options[:resource_id],
      ip_address: options[:ip_address] || '0.0.0.0',
      user_agent: options[:user_agent],
      request_params: options[:request_params],
      metadata: options[:metadata] || {},
      performed_at: Time.current
    )
  end

  def self.check_user_suspicious_activity(user)
    suspicious_activities = []
    
    # Check for rapid requests
    recent_count = by_user(user).where(performed_at: SUSPICIOUS_PATTERNS[:rapid_requests][:window].ago..Time.current).count
    if recent_count > SUSPICIOUS_PATTERNS[:rapid_requests][:threshold]
      suspicious_activities << "Rapid requests detected: #{recent_count} requests in #{SUSPICIOUS_PATTERNS[:rapid_requests][:window].inspect}"
    end

    # Check for multiple failed logins
    failed_login_count = by_user(user).failed_logins.where(performed_at: SUSPICIOUS_PATTERNS[:failed_logins][:window].ago..Time.current).count
    if failed_login_count >= SUSPICIOUS_PATTERNS[:failed_logins][:threshold]
      suspicious_activities << "Multiple failed login attempts: #{failed_login_count} attempts"
    end

    # Check for unusual hour activity
    unusual_hour = SUSPICIOUS_PATTERNS[:unusual_hours]
    current_hour = Time.current.hour
    if current_hour >= unusual_hour[:start_hour] && current_hour <= unusual_hour[:end_hour]
      suspicious_activities << "Activity during unusual hours: #{current_hour}:00"
    end

    suspicious_activities
  end

  # Instance methods
  def suspicious?
    action == ACTIVITY_TYPES[:suspicious_activity]
  end

  def resource
    return nil unless resource_type.present? && resource_id.present?
    resource_type.constantize.find_by(id: resource_id)
  rescue NameError
    nil
  end

  def description
    case action
    when ACTIVITY_TYPES[:login]
      "User logged in"
    when ACTIVITY_TYPES[:logout]
      "User logged out"
    when ACTIVITY_TYPES[:failed_login]
      "Failed login attempt"
    when ACTIVITY_TYPES[:password_reset]
      "Password reset requested"
    when ACTIVITY_TYPES[:profile_update]
      "Profile updated"
    else
      "#{action.humanize} #{resource_type}" if resource_type.present?
    end
  end

  private

  def set_performed_at
    self.performed_at ||= Time.current
  end

  def check_for_suspicious_activity
    return unless user.present?
    
    suspicious_activities = self.class.check_user_suspicious_activity(user)
    
    if suspicious_activities.any?
      self.class.log_activity(
        user,
        ACTIVITY_TYPES[:suspicious_activity],
        metadata: { reasons: suspicious_activities },
        ip_address: ip_address,
        user_agent: user_agent
      )
      
      # Trigger alert notification
      UserActivityMailer.suspicious_activity_alert(user, suspicious_activities).deliver_later
    end
  end
end
