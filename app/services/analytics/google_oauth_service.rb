# frozen_string_literal: true

require "googleauth"
require "oauth2"

module Analytics
  # Handles Google OAuth 2.0 authentication for all Google API integrations
  # Provides secure token management, refresh handling, and scope validation
  class GoogleOauthService
    include Analytics::RateLimitingService

    GOOGLE_OAUTH_SCOPES = [
      "https://www.googleapis.com/auth/adwords",
      "https://www.googleapis.com/auth/analytics.readonly",
      "https://www.googleapis.com/auth/webmasters.readonly",
      "https://www.googleapis.com/auth/cloud-platform"
    ].freeze

    GOOGLE_API_ENDPOINTS = {
      authorize: "https://accounts.google.com/o/oauth2/auth",
      token: "https://oauth2.googleapis.com/token",
      revoke: "https://oauth2.googleapis.com/revoke"
    }.freeze

    class GoogleApiError < StandardError
      attr_reader :error_code, :error_type, :retry_after

      def initialize(message, error_code: nil, error_type: nil, retry_after: nil)
        super(message)
        @error_code = error_code
        @error_type = error_type
        @retry_after = retry_after
      end
    end

    def initialize(user_id:, integration_type: :google_ads)
      @user_id = user_id
      @integration_type = integration_type
      @redis_client = Redis.new
      validate_integration_type!
    end

    # Generate OAuth authorization URL for user consent
    def authorization_url(state: nil)
      client = build_oauth_client
      state_token = generate_secure_state(state)

      client.auth_code.authorize_url(
        redirect_uri: redirect_uri,
        scope: required_scopes.join(" "),
        state: state_token,
        access_type: "offline",
        prompt: "consent"
      )
    end

    # Exchange authorization code for access and refresh tokens
    def exchange_code_for_tokens(code, state)
      validate_state_token!(state)

      with_rate_limiting("google_oauth_token", user_id: @user_id) do
        client = build_oauth_client
        token = client.auth_code.get_token(code, redirect_uri: redirect_uri)

        store_tokens(token)

        {
          access_token: token.token,
          refresh_token: token.refresh_token,
          expires_at: Time.zone.at(token.expires_at),
          scope: token.params["scope"]
        }
      end
    rescue OAuth2::Error => e
      raise GoogleApiError.new(
        "OAuth token exchange failed: #{e.description}",
        error_code: e.code,
        error_type: :oauth_error
      )
    end

    # Get valid access token (refreshes if needed)
    def access_token
      with_rate_limiting("google_oauth_refresh", user_id: @user_id) do
        stored_token = fetch_stored_token
        return nil unless stored_token

        if token_expired?(stored_token)
          refresh_access_token(stored_token)
        else
          stored_token[:access_token]
        end
      end
    end

    # Refresh access token using refresh token
    def refresh_access_token(stored_token = nil)
      stored_token ||= fetch_stored_token
      return nil unless stored_token&.dig(:refresh_token)

      client = build_oauth_client
      token = OAuth2::AccessToken.new(
        client,
        stored_token[:access_token],
        refresh_token: stored_token[:refresh_token]
      )

      refreshed_token = token.refresh!
      store_tokens(refreshed_token)

      refreshed_token.token
    rescue OAuth2::Error => e
      Rails.logger.error "Google OAuth refresh failed for user #{@user_id}: #{e.description}"
      invalidate_stored_tokens
      raise GoogleApiError.new(
        "Token refresh failed: #{e.description}",
        error_code: e.code,
        error_type: :token_refresh_error
      )
    end

    # Revoke OAuth tokens and clear storage
    def revoke_access
      stored_token = fetch_stored_token
      return true unless stored_token

      with_rate_limiting("google_oauth_revoke", user_id: @user_id) do
        client = build_oauth_client

        # Revoke refresh token (this invalidates all associated tokens)
        if stored_token[:refresh_token]
          revoke_url = "#{GOOGLE_API_ENDPOINTS[:revoke]}?token=#{stored_token[:refresh_token]}"
          client.request(:post, revoke_url)
        end

        invalidate_stored_tokens
        true
      end
    rescue OAuth2::Error => e
      Rails.logger.warn "Failed to revoke Google tokens for user #{@user_id}: #{e.description}"
      invalidate_stored_tokens # Clear locally even if remote revocation failed
      true
    end

    # Check if user has valid OAuth tokens
    def authenticated?
      token = fetch_stored_token
      token.present? && (token[:refresh_token].present? || !token_expired?(token))
    end

    # Get Google user info for verification
    def user_info
      token = access_token
      return nil unless token

      response = Faraday.get(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        {},
        { "Authorization" => "Bearer #{token}" }
      )

      if response.success?
        JSON.parse(response.body)
      else
        Rails.logger.error "Failed to fetch Google user info: #{response.status}"
        nil
      end
    end

    private

    attr_reader :user_id, :integration_type, :redis_client

    def validate_integration_type!
      valid_types = %i[google_ads google_analytics search_console]
      return if valid_types.include?(@integration_type)

      raise ArgumentError, "Invalid integration type: #{@integration_type}"
    end

    def build_oauth_client
      OAuth2::Client.new(
        google_client_id,
        google_client_secret,
        site: "https://accounts.google.com",
        authorize_url: "/o/oauth2/auth",
        token_url: "/o/oauth2/token"
      )
    end

    def required_scopes
      case @integration_type
      when :google_ads
        [
          "https://www.googleapis.com/auth/adwords",
          "https://www.googleapis.com/auth/analytics.readonly"
        ]
      when :google_analytics
        [ "https://www.googleapis.com/auth/analytics.readonly" ]
      when :search_console
        [ "https://www.googleapis.com/auth/webmasters.readonly" ]
      else
        GOOGLE_OAUTH_SCOPES
      end
    end

    def redirect_uri
      Rails.application.routes.url_helpers.analytics_google_oauth_callback_url(
        integration: @integration_type
      )
    end

    def generate_secure_state(custom_state)
      state_data = {
        user_id: @user_id,
        integration_type: @integration_type,
        custom: custom_state,
        timestamp: Time.current.to_i,
        nonce: SecureRandom.hex(16)
      }

      encoded_state = Base64.strict_encode64(state_data.to_json)

      # Store state in Redis with short expiration for validation
      @redis_client.setex(
        "google_oauth_state:#{encoded_state}",
        300, # 5 minutes
        state_data.to_json
      )

      encoded_state
    end

    def validate_state_token!(state)
      return false unless state

      stored_data = @redis_client.get("google_oauth_state:#{state}")
      return false unless stored_data

      state_data = JSON.parse(stored_data)

      # Validate state belongs to current user and is recent
      state_data["user_id"] == @user_id &&
        state_data["integration_type"] == @integration_type.to_s &&
        (Time.current.to_i - state_data["timestamp"]) < 300

    rescue JSON::ParserError
      false
    end

    def store_tokens(token)
      token_data = {
        access_token: token.token,
        refresh_token: token.refresh_token,
        expires_at: token.expires_at,
        scope: token.params["scope"],
        updated_at: Time.current.to_i
      }

      # Store in Redis with longer expiration (30 days)
      @redis_client.setex(
        token_cache_key,
        30.days.to_i,
        token_data.to_json
      )

      # Also store in database for persistence
      store_tokens_in_database(token_data)
    end

    def fetch_stored_token
      # Try Redis first for speed
      cached_token = @redis_client.get(token_cache_key)
      if cached_token
        return JSON.parse(cached_token, symbolize_names: true)
      end

      # Fallback to database
      db_token = fetch_tokens_from_database
      if db_token
        # Refresh cache
        @redis_client.setex(token_cache_key, 30.days.to_i, db_token.to_json)
        db_token
      end
    rescue JSON::ParserError
      nil
    end

    def token_expired?(token)
      return true unless token[:expires_at]

      Time.current.to_i >= (token[:expires_at] - 300) # 5 minute buffer
    end

    def invalidate_stored_tokens
      @redis_client.del(token_cache_key)
      clear_tokens_from_database
    end

    def token_cache_key
      "google_oauth_tokens:#{@user_id}:#{@integration_type}"
    end

    def store_tokens_in_database(token_data)
      # This would typically be stored in a GoogleIntegration model
      # For now, using a simple JSON field approach
      integration = find_or_create_integration
      integration.update!(
        access_token: encrypt_token(token_data[:access_token]),
        refresh_token: encrypt_token(token_data[:refresh_token]),
        expires_at: Time.zone.at(token_data[:expires_at]),
        scope: token_data[:scope],
        last_refreshed_at: Time.current
      )
    end

    def fetch_tokens_from_database
      integration = find_integration
      return nil unless integration&.refresh_token

      {
        access_token: decrypt_token(integration.access_token),
        refresh_token: decrypt_token(integration.refresh_token),
        expires_at: integration.expires_at&.to_i,
        scope: integration.scope
      }
    end

    def clear_tokens_from_database
      integration = find_integration
      integration&.update!(
        access_token: nil,
        refresh_token: nil,
        expires_at: nil,
        scope: nil
      )
    end

    def find_or_create_integration
      # This assumes a GoogleIntegration model exists
      # In a real implementation, you'd want to create this model
      user = User.find(@user_id)
      user.google_integrations.find_or_create_by(
        integration_type: @integration_type
      )
    end

    def find_integration
      user = User.find(@user_id)
      user.google_integrations.find_by(integration_type: @integration_type)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def encrypt_token(token)
      return nil unless token

      # Use Rails credentials for encryption key
      key = Rails.application.credentials.google_token_encryption_key
      crypt = ActiveSupport::MessageEncryptor.new(key)
      crypt.encrypt_and_sign(token)
    end

    def decrypt_token(encrypted_token)
      return nil unless encrypted_token

      key = Rails.application.credentials.google_token_encryption_key
      crypt = ActiveSupport::MessageEncryptor.new(key)
      crypt.decrypt_and_verify(encrypted_token)
    rescue ActiveSupport::MessageVerifier::InvalidSignature,
           ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    def google_client_id
      Rails.application.credentials.dig(:google, :client_id) ||
        ENV["GOOGLE_CLIENT_ID"]
    end

    def google_client_secret
      Rails.application.credentials.dig(:google, :client_secret) ||
        ENV["GOOGLE_CLIENT_SECRET"]
    end
  end
end
