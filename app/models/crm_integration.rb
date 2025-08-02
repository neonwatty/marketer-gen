# frozen_string_literal: true

class CrmIntegration < ApplicationRecord
  # Supported CRM platforms
  PLATFORMS = %w[
    salesforce
    hubspot
    marketo
    pardot
    pipedrive
    zoho
  ].freeze

  STATUSES = %w[
    pending
    connecting
    connected
    active
    error
    disconnected
    suspended
  ].freeze

  # Associations
  belongs_to :brand
  belongs_to :user
  has_many :crm_leads, dependent: :destroy
  has_many :crm_opportunities, dependent: :destroy
  has_many :crm_analytics, dependent: :destroy

  # Validations
  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :name, presence: true, length: { maximum: 255 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :platform, uniqueness: { scope: :brand_id, message: "integration already exists for this brand" }

  # Encrypted attributes (skip in test environment)
  unless Rails.env.test?
    encrypts :access_token
    encrypts :refresh_token
    encrypts :client_id
    encrypts :client_secret
    encrypts :additional_credentials
  end

  # Scopes
  scope :active, -> { where(active: true, status: %w[connected active]) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :needs_token_refresh, -> { where("token_expires_at < ?", 1.hour.from_now) }
  scope :rate_limited, -> { where("rate_limit_reset_at > ?", Time.current) }
  scope :sync_enabled, -> { where(active: true) }

  # Callbacks
  before_validation :set_default_status, on: :create
  before_save :update_sync_metrics
  after_create :initialize_sync_configuration

  # Status management
  def connected?
    %w[connected active].include?(status)
  end

  def disconnected?
    %w[error disconnected suspended].include?(status)
  end

  def needs_token_refresh?
    token_expires_at.present? && token_expires_at < 1.hour.from_now
  end

  def rate_limited?
    rate_limit_reset_at.present? && rate_limit_reset_at > Time.current
  end

  # Error handling
  def increment_error_count!
    update!(
      consecutive_error_count: consecutive_error_count + 1,
      status: consecutive_error_count >= 5 ? "error" : status
    )
  end

  def reset_error_count!
    update!(consecutive_error_count: 0) if consecutive_error_count > 0
  end

  def update_last_error!(error_message)
    update!(
      last_error_message: error_message,
      last_attempted_sync_at: Time.current
    )
    increment_error_count!
  end

  def mark_successful_sync!
    update!(
      last_successful_sync_at: Time.current,
      last_attempted_sync_at: Time.current,
      consecutive_error_count: 0,
      status: "active"
    )
  end

  # Token management
  def token_valid?
    access_token.present? && (token_expires_at.blank? || token_expires_at > Time.current)
  end

  def refresh_token_if_needed!
    return true if token_valid?
    return false unless refresh_token.present?

    service = Analytics::CrmOauthService.new(
      platform: platform,
      integration: self
    )

    result = service.refresh_access_token(refresh_token)
    if result.success?
      update_tokens!(result.data)
      true
    else
      update_last_error!("Token refresh failed: #{result.message}")
      false
    end
  end

  def update_tokens!(token_data)
    update!(
      access_token: token_data[:access_token],
      refresh_token: token_data[:refresh_token] || refresh_token,
      token_expires_at: token_data[:expires_at],
      last_token_refresh_at: Time.current
    )
  end

  # Sync configuration management
  def sync_configuration_with_defaults
    default_config = {
      "leads" => { "enabled" => sync_leads, "frequency" => "hourly" },
      "opportunities" => { "enabled" => sync_opportunities, "frequency" => "hourly" },
      "contacts" => { "enabled" => sync_contacts, "frequency" => "daily" },
      "accounts" => { "enabled" => sync_accounts, "frequency" => "daily" },
      "campaigns" => { "enabled" => sync_campaigns, "frequency" => "daily" }
    }

    (sync_configuration || {}).reverse_merge(default_config)
  end

  def field_mappings_with_defaults
    platform_defaults = case platform
    when "salesforce"
      {
        "lead" => {
          "first_name" => "FirstName",
          "last_name" => "LastName",
          "email" => "Email",
          "company" => "Company",
          "status" => "Status"
        }
      }
    when "hubspot"
      {
        "lead" => {
          "first_name" => "firstname",
          "last_name" => "lastname",
          "email" => "email",
          "company" => "company",
          "lifecycle_stage" => "lifecyclestage"
        }
      }
    else
      {}
    end

    (field_mappings || {}).reverse_merge(platform_defaults)
  end

  # API configuration
  def api_configuration_with_defaults
    platform_defaults = case platform
    when "salesforce"
      {
        "api_version" => "v58.0",
        "environment" => sandbox_mode ? "sandbox" : "production"
      }
    when "hubspot"
      {
        "api_version" => "v3"
      }
    when "marketo"
      {
        "api_version" => "v1"
      }
    when "pardot"
      {
        "api_version" => "v5"
      }
    when "pipedrive"
      {
        "api_version" => "v1"
      }
    when "zoho"
      {
        "api_version" => "v2"
      }
    else
      {}
    end

    (api_configuration || {}).reverse_merge(platform_defaults)
  end

  # Metrics and reporting
  def sync_health_score
    return 0 if last_successful_sync_at.blank?

    days_since_last_sync = (Time.current - last_successful_sync_at) / 1.day
    error_penalty = consecutive_error_count * 10

    base_score = case
    when days_since_last_sync < 1
      100
    when days_since_last_sync < 7
      80
    when days_since_last_sync < 30
      60
    else
      20
    end

    [ base_score - error_penalty, 0 ].max
  end

  def daily_sync_stats
    {
      leads_synced: crm_leads.where(last_synced_at: 1.day.ago..Time.current).count,
      opportunities_synced: crm_opportunities.where(last_synced_at: 1.day.ago..Time.current).count,
      api_calls_made: daily_api_calls,
      errors_encountered: consecutive_error_count
    }
  end

  # Platform-specific helpers
  def salesforce?
    platform == "salesforce"
  end

  def hubspot?
    platform == "hubspot"
  end

  def marketo?
    platform == "marketo"
  end

  def pardot?
    platform == "pardot"
  end

  def pipedrive?
    platform == "pipedrive"
  end

  def zoho?
    platform == "zoho"
  end

  private

  def set_default_status
    self.status ||= "pending"
  end

  def update_sync_metrics
    if last_successful_sync_at_changed? && last_successful_sync_at.present?
      # Reset daily counters if it's a new day
      reset_daily_counters! if last_successful_sync_at.to_date != Date.current
    end
  end

  def reset_daily_counters!
    update_columns(daily_api_calls: 0) if daily_api_calls > 0
  end

  def initialize_sync_configuration
    return if sync_configuration.present?

    update!(
      sync_configuration: sync_configuration_with_defaults,
      field_mappings: field_mappings_with_defaults,
      api_configuration: api_configuration_with_defaults
    )
  end
end
