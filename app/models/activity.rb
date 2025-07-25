class Activity < ApplicationRecord
  belongs_to :user

  # Validations
  validates :action, presence: true
  validates :controller, presence: true
  validates :occurred_at, presence: true

  # Scopes
  scope :recent, -> { order(occurred_at: :desc) }
  scope :suspicious, -> { where(suspicious: true) }
  scope :normal, -> { where(suspicious: false) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_controller, ->(controller) { where(controller: controller) }
  scope :today, -> { where(occurred_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(occurred_at: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :this_month, -> { where(occurred_at: Time.current.beginning_of_month..Time.current.end_of_month) }
  scope :failed_requests, -> { where("response_status >= ?", 400) }
  scope :successful_requests, -> { where("response_status < ?", 400) }

  # Callbacks
  before_validation :set_occurred_at, on: :create

  # Serialize metadata
  serialize :metadata, coder: JSON

  # Class methods
  def self.log_activity(user:, action:, controller:, request:, response: nil, metadata: {})
    create!(
      user: user,
      action: action,
      controller: controller,
      request_path: request.path,
      request_method: request.method,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      session_id: request.session.id,
      referrer: request.referrer,
      response_status: response&.status,
      response_time: metadata[:response_time],
      metadata: metadata,
      device_type: parse_device_type(request.user_agent),
      browser_name: parse_browser_name(request.user_agent),
      os_name: parse_os_name(request.user_agent),
      occurred_at: Time.current
    )
  end

  def self.parse_device_type(user_agent)
    return nil unless user_agent
    case user_agent
    when /tablet|ipad/i
      "tablet"
    when /mobile|android|iphone|phone/i
      "mobile"
    else
      "desktop"
    end
  end

  def self.parse_browser_name(user_agent)
    return nil unless user_agent
    case user_agent
    when /chrome/i
      "Chrome"
    when /safari/i
      "Safari"
    when /firefox/i
      "Firefox"
    when /edge/i
      "Edge"
    when /opera/i
      "Opera"
    else
      "Other"
    end
  end

  def self.parse_os_name(user_agent)
    return nil unless user_agent
    case user_agent
    when /windows/i
      "Windows"
    when /mac|darwin/i
      "macOS"
    when /android/i
      "Android"
    when /ios|iphone|ipad/i
      "iOS"
    when /linux/i
      "Linux"
    else
      "Other"
    end
  end

  # Instance methods
  def suspicious?
    suspicious
  end

  def failed?
    response_status && response_status >= 400
  end

  def successful?
    response_status && response_status < 400
  end

  def full_action
    "#{controller}##{action}"
  end

  def duration_in_ms
    response_time ? (response_time * 1000).round(2) : nil
  end

  private

  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end
