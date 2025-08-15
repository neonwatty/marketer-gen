class Session < ApplicationRecord
  belongs_to :user

  # Session security validations
  validates :ip_address, presence: true
  validates :user_agent, presence: true
  
  # Session timeout configuration
  TIMEOUT_DURATION = 2.weeks.freeze
  IDLE_TIMEOUT = 30.minutes.freeze
  
  # Scopes for session management
  scope :active, -> { where('updated_at > ?', IDLE_TIMEOUT.ago) }
  scope :expired, -> { where('updated_at <= ? OR created_at <= ?', IDLE_TIMEOUT.ago, TIMEOUT_DURATION.ago) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(updated_at: :desc) }
  
  # Session security methods
  def expired?
    updated_at <= IDLE_TIMEOUT.ago || created_at <= TIMEOUT_DURATION.ago
  end
  
  def active?
    !expired?
  end
  
  def touch_activity!
    touch(:updated_at) if active?
  end
  
  def terminate!
    destroy
  end
  
  # Security audit methods
  def suspicious_activity?
    # Check for potential security issues
    return true if user_agent.blank? || ip_address.blank?
    return true if created_at < 6.months.ago # Very old sessions
    
    # Check for unusual user agent patterns
    return true if user_agent.length > 500 # Abnormally long user agent
    
    false
  end
  
  def browser_info
    return 'Unknown' if user_agent.blank?
    
    case user_agent
    when /Chrome/
      'Chrome'
    when /Firefox/
      'Firefox'
    when /Safari/
      'Safari'
    when /Edge/
      'Edge'
    else
      'Other'
    end
  end
  
  # Class methods for session management
  class << self
    def cleanup_expired!
      expired.destroy_all
    end
    
    def cleanup_old_sessions!
      # Keep only the 10 most recent sessions per user
      User.find_each do |user|
        old_sessions = user.sessions.order(updated_at: :desc).offset(10)
        old_sessions.destroy_all if old_sessions.exists?
      end
    end
    
    def suspicious_sessions
      where('LENGTH(user_agent) > 500 OR user_agent IS NULL OR ip_address IS NULL')
    end
  end
  
  # Callbacks
  before_validation :set_defaults, on: :create
  after_create :cleanup_old_user_sessions
  
  private
  
  def set_defaults
    self.ip_address ||= 'unknown'
    self.user_agent ||= 'unknown'
  end
  
  def cleanup_old_user_sessions
    # Automatically clean up old sessions for this user (keep last 5)
    user.sessions.order(created_at: :desc).offset(5).destroy_all
  end
end
