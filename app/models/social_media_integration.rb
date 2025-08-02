# frozen_string_literal: true

class SocialMediaIntegration < ApplicationRecord
  belongs_to :brand
  has_many :social_media_metrics, dependent: :destroy

  # Platform constants
  PLATFORMS = %w[facebook instagram linkedin twitter tiktok].freeze

  # Status constants
  STATUSES = %w[pending active expired error disconnected].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :platform, uniqueness: { scope: :brand_id }

  scope :active, -> { where(status: "active") }
  scope :expired, -> { where(status: "expired") }
  scope :for_platform, ->(platform) { where(platform: platform) }

  before_validation :set_default_status, if: :new_record?

  # Serialize configuration as JSON
  serialize :configuration, coder: JSON

  def active?
    status == "active"
  end

  def expired?
    status == "expired" || (expires_at && expires_at < Time.current)
  end

  def needs_refresh?
    expired? || (expires_at && expires_at < 1.hour.from_now)
  end

  def rate_limited?
    rate_limit_reset_at && rate_limit_reset_at > Time.current
  end

  def time_until_rate_limit_reset
    return 0 unless rate_limited?

    (rate_limit_reset_at - Time.current).to_i
  end

  def increment_error_count!
    increment!(:error_count)
    update!(status: "error") if error_count >= 5
  end

  def reset_error_count!
    update!(error_count: 0, status: "active") if error_count > 0
  end

  def update_last_sync!
    touch(:last_sync_at)
  end

  def configuration_value(key)
    configuration&.dig(key.to_s)
  end

  def set_configuration_value(key, value)
    self.configuration ||= {}
    self.configuration[key.to_s] = value
  end

  # OAuth token management
  def token_valid?
    access_token.present? && !expired?
  end

  def refresh_token_if_needed!
    return false unless needs_refresh? && refresh_token.present?

    case platform
    when "facebook", "instagram"
      refresh_facebook_token!
    when "linkedin"
      refresh_linkedin_token!
    when "twitter"
      # Twitter uses bearer tokens that don't typically refresh
      false
    when "tiktok"
      refresh_tiktok_token!
    else
      false
    end
  end

  def disconnect!
    update!(
      status: "disconnected",
      access_token: nil,
      refresh_token: nil,
      expires_at: nil,
      platform_account_id: nil,
      error_count: 0
    )
  end

  private

  def set_default_status
    self.status ||= "pending"
  end

  def refresh_facebook_token!
    # Implement Facebook token refresh logic
    # This would typically involve calling Facebook's OAuth refresh endpoint
    false
  end

  def refresh_linkedin_token!
    # Implement LinkedIn token refresh logic
    false
  end

  def refresh_tiktok_token!
    # Implement TikTok token refresh logic
    false
  end
end
