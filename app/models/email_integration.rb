# frozen_string_literal: true

class EmailIntegration < ApplicationRecord
  belongs_to :brand
  has_many :email_campaigns, dependent: :destroy
  has_many :email_metrics, dependent: :destroy
  has_many :email_subscribers, dependent: :destroy
  has_many :email_automations, dependent: :destroy

  # Platform constants
  PLATFORMS = %w[mailchimp sendgrid constant_contact campaign_monitor activecampaign klaviyo].freeze

  # Status constants
  STATUSES = %w[pending active expired error disconnected].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :platform, uniqueness: { scope: :brand_id }

  scope :active, -> { where(status: "active") }
  scope :expired, -> { where(status: "expired") }
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :needs_sync, -> { where("last_sync_at IS NULL OR last_sync_at < ?", 1.hour.ago) }

  before_validation :set_default_status, if: :new_record?
  before_validation :set_default_error_count, if: :new_record?

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
    save!
  end

  def token_valid?
    access_token.present? && !expired?
  end

  def api_headers
    case platform
    when "mailchimp"
      { "Authorization" => "Bearer #{access_token}" }
    when "sendgrid"
      { "Authorization" => "Bearer #{access_token}" }
    when "constant_contact"
      { "Authorization" => "Bearer #{access_token}" }
    when "campaign_monitor"
      { "Authorization" => "Bearer #{access_token}" }
    when "activecampaign"
      { "Authorization" => "Bearer #{access_token}" }
    when "klaviyo"
      {
        "Authorization" => "Klaviyo-API-Key #{access_token}",
        "Accept" => "application/json",
        "Revision" => "2024-10-15"
      }
    else
      { "Authorization" => "Bearer #{access_token}" }
    end
  end

  def api_base_url
    case platform
    when "mailchimp"
      api_endpoint || "https://us1.api.mailchimp.com/3.0"
    when "sendgrid"
      "https://api.sendgrid.com/v3"
    when "constant_contact"
      "https://api.cc.email/v3"
    when "campaign_monitor"
      "https://api.createsend.com/api/v3.3"
    when "activecampaign"
      configuration_value("api_url") || "https://youraccount.api-us1.com/api/3"
    when "klaviyo"
      "https://a.klaviyo.com/api"
    else
      raise ArgumentError, "Unknown platform: #{platform}"
    end
  end

  def refresh_token_if_needed!
    return false unless needs_refresh? && refresh_token.present?

    oauth_service = Analytics::EmailProviderOauthService.new(
      platform: platform,
      brand: brand
    )

    result = oauth_service.refresh_access_token(refresh_token)

    if result.success?
      update!(
        access_token: result.data[:access_token],
        refresh_token: result.data[:refresh_token],
        expires_at: result.data[:expires_at],
        status: "active",
        error_count: 0
      )
      true
    else
      increment_error_count!
      Rails.logger.error "Failed to refresh token for #{platform}: #{result.error_message}"
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
      error_count: 0,
      webhook_secret: nil
    )
  end

  def webhook_endpoint_url
    Rails.application.routes.url_helpers.webhooks_email_platform_url(
      platform: platform,
      integration_id: id,
      host: Rails.application.config.action_mailer.default_url_options[:host]
    )
  end

  def generate_webhook_secret!
    self.webhook_secret = SecureRandom.hex(32)
    save!
  end

  def verify_webhook_signature(payload, signature, timestamp = nil)
    case platform
    when "mailchimp"
      verify_mailchimp_webhook(payload, signature)
    when "sendgrid"
      verify_sendgrid_webhook(payload, signature, timestamp)
    when "constant_contact"
      verify_constant_contact_webhook(payload, signature)
    when "campaign_monitor"
      verify_campaign_monitor_webhook(payload, signature)
    when "activecampaign"
      verify_activecampaign_webhook(payload, signature, timestamp)
    when "klaviyo"
      verify_klaviyo_webhook(payload, signature, timestamp)
    else
      false
    end
  end

  # Platform-specific webhook verification methods
  def verify_mailchimp_webhook(payload, signature)
    return false unless webhook_secret

    expected_signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest("sha1", webhook_secret, payload)
    )
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  def verify_sendgrid_webhook(payload, signature, timestamp)
    return false unless webhook_secret || timestamp

    # SendGrid uses ECDSA verification
    # This is a simplified implementation - in production, use proper ECDSA verification
    expected_signature = OpenSSL::HMAC.hexdigest("sha256", webhook_secret, timestamp + payload)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  def verify_constant_contact_webhook(payload, signature)
    return false unless webhook_secret

    expected_signature = OpenSSL::HMAC.hexdigest("sha256", webhook_secret, payload)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  def verify_campaign_monitor_webhook(payload, signature)
    return false unless webhook_secret

    expected_signature = OpenSSL::HMAC.hexdigest("sha256", webhook_secret, payload)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  def verify_activecampaign_webhook(payload, signature, timestamp)
    return false unless webhook_secret

    expected_signature = OpenSSL::HMAC.hexdigest("sha256", webhook_secret, timestamp + payload)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  def verify_klaviyo_webhook(payload, signature, timestamp)
    return false unless webhook_secret

    expected_signature = OpenSSL::HMAC.hexdigest("sha256", webhook_secret, timestamp + payload)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  private

  def set_default_status
    self.status ||= "pending"
  end

  def set_default_error_count
    self.error_count ||= 0
  end
end
