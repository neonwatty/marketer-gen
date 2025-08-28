# frozen_string_literal: true

class WebhooksController < ApplicationController
  # Skip CSRF protection for webhook endpoints (they use signature verification instead)
  skip_before_action :verify_authenticity_token
  
  # Skip authentication for webhooks (they authenticate via signatures)
  skip_before_action :require_authentication, if: :webhook_endpoint?
  
  # Apply webhook-specific rate limiting
  before_action :webhook_rate_limit
  before_action :log_webhook_request
  before_action :validate_content_type
  
  # Webhook endpoints for different platforms
  def meta_webhook
    process_platform_webhook('meta')
  end

  def facebook_webhook
    process_platform_webhook('facebook')
  end

  def instagram_webhook
    process_platform_webhook('instagram')
  end

  def linkedin_webhook
    process_platform_webhook('linkedin')
  end

  def google_ads_webhook
    process_platform_webhook('google_ads')
  end

  def generic_webhook
    process_platform_webhook(params[:platform] || 'generic')
  end

  # Webhook verification endpoints (for platform setup)
  def verify
    platform = params[:platform]&.downcase
    
    case platform
    when 'meta', 'facebook', 'instagram'
      verify_meta_webhook
    when 'linkedin'
      verify_linkedin_webhook
    when 'google_ads'
      verify_google_ads_webhook
    else
      render json: { error: 'Unsupported platform' }, status: :unprocessable_entity
    end
  end

  private

  def process_platform_webhook(platform)
    begin
      # Extract payload and headers
      payload = extract_webhook_payload
      headers = extract_webhook_headers
      
      # Basic validation
      if payload.blank?
        Rails.logger.warn "Empty webhook payload received from #{platform}"
        return render json: { error: 'Empty payload' }, status: :bad_request
      end

      # Log webhook reception
      Rails.logger.info "Webhook received from #{platform}: #{payload.keys.join(', ')}"
      
      # Enqueue processing job for background handling
      WebhookProcessingJob.perform_later(payload, headers, platform)
      
      # Return immediate success response
      render json: { status: 'received', platform: platform }, status: :ok
      
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in webhook from #{platform}: #{e.message}"
      render json: { error: 'Invalid JSON payload' }, status: :bad_request
      
    rescue => e
      Rails.logger.error "Webhook processing error for #{platform}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  def extract_webhook_payload
    case request.content_type
    when /application\/json/
      JSON.parse(request.body.read)
    when /application\/x-www-form-urlencoded/
      params.except(:action, :controller, :platform).to_unsafe_h
    else
      # Attempt JSON parsing as fallback
      request.body.rewind
      JSON.parse(request.body.read)
    end
  end

  def extract_webhook_headers
    relevant_headers = {}
    
    request.headers.each do |key, value|
      # Capture signature and authentication headers
      if key.match?(/signature|authorization|x-hub|linkedin|google/i)
        relevant_headers[key.downcase] = value
      end
    end
    
    relevant_headers
  end

  def verify_meta_webhook
    # Facebook/Meta webhook verification
    hub_mode = params['hub.mode']
    hub_challenge = params['hub.challenge']
    hub_verify_token = params['hub.verify_token']
    
    expected_token = Rails.application.credentials.dig(:webhooks, :meta_verify_token) || 
                     ENV['META_WEBHOOK_VERIFY_TOKEN']
    
    if hub_mode == 'subscribe' && hub_verify_token == expected_token
      Rails.logger.info "Meta webhook verification successful"
      render plain: hub_challenge, status: :ok
    else
      Rails.logger.warn "Meta webhook verification failed"
      render plain: 'Forbidden', status: :forbidden
    end
  end

  def verify_linkedin_webhook
    # LinkedIn webhook verification (basic implementation)
    challenge = params[:challenge]
    
    if challenge.present?
      Rails.logger.info "LinkedIn webhook verification successful"
      render plain: challenge, status: :ok
    else
      render json: { error: 'Missing challenge parameter' }, status: :bad_request
    end
  end

  def verify_google_ads_webhook
    # Google Ads webhook verification
    verification_token = request.headers['Authorization']
    expected_token = Rails.application.credentials.dig(:webhooks, :google_ads_verify_token) || 
                     ENV['GOOGLE_ADS_WEBHOOK_VERIFY_TOKEN']
    
    if verification_token == "Bearer #{expected_token}"
      Rails.logger.info "Google Ads webhook verification successful"
      render json: { status: 'verified' }, status: :ok
    else
      Rails.logger.warn "Google Ads webhook verification failed"
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def webhook_endpoint?
    action_name.include?('webhook') || action_name == 'verify'
  end

  def webhook_rate_limit
    # Skip rate limiting in test environment
    return if Rails.env.test?
    
    # More permissive rate limiting for webhooks
    client_ip = request.remote_ip
    cache_key = "webhook_rate_limit:#{client_ip}"
    
    # Allow 500 webhook requests per minute per IP (higher than regular endpoints)
    current_count = Rails.cache.read(cache_key) || 0
    
    if current_count >= 500
      Rails.logger.warn "Webhook rate limit exceeded for IP: #{client_ip}"
      render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
      return
    end
    
    # Increment counter with 1-minute expiry
    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
  end

  def log_webhook_request
    Rails.logger.info "Webhook request: #{request.method} #{request.path}"
    Rails.logger.debug "Headers: #{request.headers.to_h.select { |k, _| k.match?(/signature|authorization|content-type|user-agent/i) }}"
    Rails.logger.debug "IP: #{request.remote_ip}"
    Rails.logger.debug "User-Agent: #{request.user_agent}"
  end

  def validate_content_type
    return if action_name == 'verify' # Skip validation for verification endpoints
    
    unless request.content_type&.match?(/application\/(json|x-www-form-urlencoded)/)
      Rails.logger.warn "Invalid content type for webhook: #{request.content_type}"
      render json: { error: 'Unsupported content type' }, status: :unsupported_media_type
    end
  end
end