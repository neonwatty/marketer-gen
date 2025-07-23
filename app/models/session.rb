class Session < ApplicationRecord
  belongs_to :user
  
  # Constants
  SESSION_TIMEOUT = 24.hours
  INACTIVE_TIMEOUT = 2.hours
  
  # Scopes
  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  
  # Callbacks
  before_create :set_expiration
  
  # Instance methods
  def expired?
    expires_at <= Time.current
  end
  
  def inactive?
    last_active_at && last_active_at < INACTIVE_TIMEOUT.ago
  end
  
  def touch_activity!
    update!(last_active_at: Time.current)
  end
  
  def extend_session!
    update!(expires_at: SESSION_TIMEOUT.from_now)
  end
  
  private
  
  def set_expiration
    self.expires_at ||= SESSION_TIMEOUT.from_now
    self.last_active_at ||= Time.current
  end
end
