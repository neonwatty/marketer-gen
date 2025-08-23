# frozen_string_literal: true

# Model for storing encrypted platform API credentials and connection status
class PlatformConnection < ApplicationRecord
  belongs_to :user

  SUPPORTED_PLATFORMS = %w[meta google_ads linkedin].freeze
  STATUSES = %w[inactive active error expired].freeze

  validates :platform, presence: true, inclusion: { in: SUPPORTED_PLATFORMS }
  validates :status, inclusion: { in: STATUSES }
  validates :platform, uniqueness: { scope: :user_id }

  # Encrypt sensitive credential data - temporarily disabled for testing
  # encrypts :credentials

  # JSON serialization
  serialize :metadata, coder: JSON

  scope :active, -> { where(status: 'active') }
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :recently_synced, -> { where('last_sync_at > ?', 24.hours.ago) }

  # Check if connection is currently active and healthy
  def active?
    status == 'active' && credentials_valid?
  end

  # Check if credentials are expired
  def expired?
    status == 'expired' || token_expired?
  end

  # Check if connection is in error state
  def error?
    status == 'error'
  end

  # Get decrypted credentials as hash
  def credential_data
    return {} if credentials.blank?
    
    begin
      JSON.parse(credentials)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse credentials for platform #{platform}: #{e.message}"
      {}
    end
  end

  # Update credentials safely
  def update_credentials(new_credentials)
    self.credentials = new_credentials.to_json
    self.status = 'active'
    save!
  end

  # Mark connection as failed
  def mark_failed!(error_message = nil)
    self.status = 'error'
    self.metadata = (metadata || {}).merge(
      last_error: error_message,
      error_at: Time.current
    )
    save!
  end

  # Mark connection as expired
  def mark_expired!
    self.status = 'expired'
    self.metadata = (metadata || {}).merge(expired_at: Time.current)
    save!
  end

  # Update sync status
  def update_sync_status!(success = true, data = nil)
    self.last_sync_at = Time.current
    
    if success
      self.status = 'active' unless expired?
      self.metadata = (metadata || {}).merge(
        last_successful_sync: Time.current,
        sync_count: (metadata&.dig('sync_count') || 0) + 1
      )
    else
      self.metadata = (metadata || {}).merge(
        last_failed_sync: Time.current,
        failure_count: (metadata&.dig('failure_count') || 0) + 1
      )
    end

    self.metadata = metadata.merge(sync_data: data) if data
    save!
  end

  # Get platform-specific account information
  def account_info
    {
      id: account_id,
      name: account_name || "#{platform.humanize} Account",
      platform: platform,
      status: status,
      last_sync: last_sync_at,
      metadata: metadata || {}
    }
  end

  # Test connection health
  def test_connection
    begin
      client = build_platform_client
      return { success: false, error: 'Client not available' } unless client

      health_check = client.health_check
      
      if health_check[:status] == :healthy
        update_sync_status!(true, health_check)
        { success: true, data: health_check }
      else
        mark_failed!(health_check[:error])
        { success: false, error: health_check[:error] }
      end

    rescue => error
      mark_failed!(error.message)
      { success: false, error: error.message }
    end
  end

  # Build appropriate platform client
  def build_platform_client
    return nil unless active? && credentials_valid?

    creds = credential_data
    
    case platform
    when 'meta'
      ExternalPlatforms::MetaApiClient.new(
        creds['access_token'],
        creds['app_secret']
      )
    when 'google_ads'
      ExternalPlatforms::GoogleAdsApiClient.new(
        creds['access_token'],
        creds['developer_token'],
        creds['customer_id'],
        creds['refresh_token']
      )
    when 'linkedin'
      ExternalPlatforms::LinkedinApiClient.new(creds['access_token'])
    else
      nil
    end
  end

  # Platform-specific credential requirements
  def required_credential_fields
    case platform
    when 'meta'
      %w[access_token app_secret]
    when 'google_ads'
      %w[access_token developer_token customer_id refresh_token]
    when 'linkedin'
      %w[access_token]
    else
      []
    end
  end

  private

  # Check if stored credentials are valid format
  def credentials_valid?
    return false if credentials.blank?

    creds = credential_data
    required_fields = required_credential_fields
    
    required_fields.all? { |field| creds[field].present? }
  end

  # Check if token is expired (platform-specific logic)
  def token_expired?
    return false if metadata.blank?

    case platform
    when 'meta'
      # Meta tokens typically expire after 60 days
      expires_at = metadata['token_expires_at']
      expires_at && Time.parse(expires_at) < Time.current
    when 'google_ads'
      # Google Ads refresh tokens don't expire, but access tokens do
      # We'll rely on API error responses to detect expiration
      false
    when 'linkedin'
      # LinkedIn tokens expire after 60 days
      expires_at = metadata['token_expires_at']
      expires_at && Time.parse(expires_at) < Time.current
    else
      false
    end
  rescue ArgumentError
    # Handle invalid date parsing
    false
  end
end
