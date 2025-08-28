# frozen_string_literal: true

class WebhookProcessingService < ApplicationService
  SUPPORTED_PLATFORMS = %w[meta facebook instagram linkedin google_ads].freeze
  SIGNATURE_ALGORITHMS = {
    'meta' => 'sha256',
    'facebook' => 'sha256',
    'instagram' => 'sha256',
    'linkedin' => 'sha1',
    'google_ads' => 'sha256'
  }.freeze

  def initialize(payload:, headers: {}, source_platform: nil)
    @payload = payload
    @headers = headers.with_indifferent_access
    @source_platform = source_platform&.to_s&.downcase
    log_service_call('WebhookProcessingService', platform: @source_platform)
  end

  def call
    return handle_service_error(ArgumentError.new("Invalid payload"), platform: @source_platform) if @payload.blank?
    
    begin
      # Step 1: Verify webhook signature
      signature_result = verify_signature
      return signature_result unless signature_result[:success]

      # Step 2: Validate payload structure
      validation_result = validate_payload
      return validation_result unless validation_result[:success]

      # Step 3: Process webhook based on platform and event type
      processing_result = process_webhook_event
      return processing_result unless processing_result[:success]

      success_response({
        platform: @source_platform,
        event_type: extract_event_type,
        processed_at: Time.current,
        payload_hash: generate_payload_hash
      })

    rescue => error
      handle_service_error(error, platform: @source_platform, payload_hash: generate_payload_hash)
    end
  end

  private

  def verify_signature
    return success_response(message: "Signature verification skipped") if Rails.env.test?
    return handle_service_error(ArgumentError.new("Unsupported platform: #{@source_platform}")) unless platform_supported?

    signature_header = extract_signature_header
    return handle_service_error(ArgumentError.new("Missing signature header")) if signature_header.blank?

    expected_signature = calculate_expected_signature
    provided_signature = extract_provided_signature(signature_header)

    if secure_compare(expected_signature, provided_signature)
      success_response(message: "Signature verified")
    else
      handle_service_error(SecurityError.new("Invalid webhook signature"))
    end
  end

  def validate_payload
    case @source_platform
    when 'meta', 'facebook', 'instagram'
      validate_meta_payload
    when 'linkedin'
      validate_linkedin_payload
    when 'google_ads'
      validate_google_ads_payload
    else
      validate_generic_payload
    end
  end

  def process_webhook_event
    event_type = extract_event_type
    
    case event_type
    when 'campaign_update', 'ad_performance'
      process_campaign_event
    when 'lead_generation', 'conversion'
      process_lead_event
    when 'account_update', 'permission_change'
      process_account_event
    else
      process_generic_event
    end
  end

  def platform_supported?
    SUPPORTED_PLATFORMS.include?(@source_platform)
  end

  def extract_signature_header
    case @source_platform
    when 'meta', 'facebook', 'instagram'
      @headers['x-hub-signature-256']
    when 'linkedin'
      @headers['linkedin-signature']
    when 'google_ads'
      @headers['google-webhook-signature']
    end
  end

  def calculate_expected_signature
    secret = webhook_secret_for_platform
    algorithm = SIGNATURE_ALGORITHMS[@source_platform] || 'sha256'
    
    case algorithm
    when 'sha256'
      "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, @payload.to_json)
    when 'sha1'
      "sha1=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, @payload.to_json)
    end
  end

  def extract_provided_signature(signature_header)
    signature_header.to_s.strip
  end

  def secure_compare(expected, provided)
    return false if expected.blank? || provided.blank?
    ActiveSupport::SecurityUtils.secure_compare(expected, provided)
  end

  def webhook_secret_for_platform
    case @source_platform
    when 'meta', 'facebook', 'instagram'
      Rails.application.credentials.dig(:webhooks, :meta_app_secret) || ENV['META_APP_SECRET']
    when 'linkedin'
      Rails.application.credentials.dig(:webhooks, :linkedin_client_secret) || ENV['LINKEDIN_CLIENT_SECRET']
    when 'google_ads'
      Rails.application.credentials.dig(:webhooks, :google_ads_secret) || ENV['GOOGLE_ADS_WEBHOOK_SECRET']
    else
      Rails.application.credentials.dig(:webhooks, :default_secret) || ENV['DEFAULT_WEBHOOK_SECRET']
    end
  end

  def validate_meta_payload
    required_fields = %w[object entry]
    missing_fields = required_fields.reject { |field| @payload.key?(field) }
    
    if missing_fields.empty?
      success_response(message: "Meta payload validated")
    else
      handle_service_error(ArgumentError.new("Missing required fields: #{missing_fields.join(', ')}"))
    end
  end

  def validate_linkedin_payload
    if @payload.key?('eventType') && @payload.key?('data')
      success_response(message: "LinkedIn payload validated")
    else
      handle_service_error(ArgumentError.new("Invalid LinkedIn webhook payload structure"))
    end
  end

  def validate_google_ads_payload
    if @payload.key?('eventType') && @payload.key?('customerId')
      success_response(message: "Google Ads payload validated")
    else
      handle_service_error(ArgumentError.new("Invalid Google Ads webhook payload structure"))
    end
  end

  def validate_generic_payload
    if @payload.is_a?(Hash) && @payload.any?
      success_response(message: "Generic payload validated")
    else
      handle_service_error(ArgumentError.new("Invalid payload structure"))
    end
  end

  def extract_event_type
    case @source_platform
    when 'meta', 'facebook', 'instagram'
      @payload.dig('entry', 0, 'messaging', 0, 'type') || 'meta_event'
    when 'linkedin'
      @payload['eventType']
    when 'google_ads'
      @payload['eventType']
    else
      @payload['event_type'] || @payload['type'] || 'unknown'
    end
  end

  def process_campaign_event
    Rails.logger.info "Processing campaign event for #{@source_platform}"
    # Integration with campaign management systems would go here
    success_response(message: "Campaign event processed")
  end

  def process_lead_event
    Rails.logger.info "Processing lead event for #{@source_platform}"
    # Integration with lead management systems would go here
    success_response(message: "Lead event processed")
  end

  def process_account_event
    Rails.logger.info "Processing account event for #{@source_platform}"
    # Integration with account management systems would go here
    success_response(message: "Account event processed")
  end

  def process_generic_event
    Rails.logger.info "Processing generic event for #{@source_platform}"
    success_response(message: "Generic event processed")
  end

  def generate_payload_hash
    Digest::SHA256.hexdigest(@payload.to_json)
  end
end