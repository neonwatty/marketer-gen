class PlanShareToken < ApplicationRecord
  belongs_to :campaign_plan

  validates :token, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :expires_at, presence: true

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  def expired?
    expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def access!
    return false if expired?
    
    update!(
      accessed_at: Time.current,
      access_count: access_count + 1
    )
    true
  end

  def expires_in_hours
    return 0 if expired?
    ((expires_at - Time.current) / 1.hour).round(1)
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at = 7.days.from_now
  end
end
