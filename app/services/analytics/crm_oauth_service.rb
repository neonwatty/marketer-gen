# frozen_string_literal: true

module Analytics
  class CrmOauthService
    include ActiveModel::Model
    include ActiveModel::Attributes
    include RateLimitingService

    attr_accessor :platform, :brand, :integration, :callback_url, :code, :state

    # CRM-specific OAuth configurations
    PLATFORM_CONFIGS = {
      "salesforce" => {
        auth_url: "https://login.salesforce.com/services/oauth2/authorize",
        token_url: "https://login.salesforce.com/services/oauth2/token",
        sandbox_auth_url: "https://test.salesforce.com/services/oauth2/authorize",
        sandbox_token_url: "https://test.salesforce.com/services/oauth2/token",
        scope: "api refresh_token offline_access",
        response_type: "code"
      },
      "hubspot" => {
        auth_url: "https://app.hubspot.com/oauth/authorize",
        token_url: "https://api.hubapi.com/oauth/v1/token",
        scope: "contacts content forms timeline files oauth crm.objects.contacts.read crm.objects.contacts.write crm.objects.companies.read crm.objects.companies.write crm.objects.deals.read crm.objects.deals.write crm.lists.read crm.lists.write",
        response_type: "code"
      },
      "marketo" => {
        auth_url: "https://{munchkin_id}.mktorest.com/identity/oauth/authorize",
        token_url: "https://{munchkin_id}.mktorest.com/identity/oauth/token",
        scope: "api_user",
        response_type: "authorization_code"
      },
      "pardot" => {
        auth_url: "https://login.salesforce.com/services/oauth2/authorize",
        token_url: "https://login.salesforce.com/services/oauth2/token",
        scope: "pardot_api api refresh_token offline_access",
        response_type: "code"
      },
      "pipedrive" => {
        auth_url: "https://oauth.pipedrive.com/oauth/authorize",
        token_url: "https://oauth.pipedrive.com/oauth/token",
        scope: "deals:read deals:write persons:read persons:write organizations:read organizations:write pipelines:read activities:read",
        response_type: "code"
      },
      "zoho" => {
        auth_url: "https://accounts.zoho.com/oauth/v2/auth",
        token_url: "https://accounts.zoho.com/oauth/v2/token",
        scope: "ZohoCRM.modules.ALL ZohoCRM.settings.ALL ZohoCRM.users.READ",
        response_type: "code"
      }
    }.freeze

    validates :platform, presence: true, inclusion: { in: CrmIntegration::PLATFORMS }
    validates :brand, presence: true

    def initialize(attributes = {})
      super
      @client_configs = load_client_configs
    end

    def authorization_url
      with_rate_limiting("#{platform}_oauth_authorize", user_id: brand&.user_id) do
        client = oauth_client

        unless client
          if Rails.env.test? || Rails.env.development?
            state_token = generate_state_token
            store_state_token(state_token)
            mock_url = "https://#{platform}.com/oauth/authorize?state=#{state_token}"
            return ServiceResult.success(data: { authorization_url: mock_url, state: state_token })
          else
            return ServiceResult.failure("OAuth client configuration not found for #{platform}")
          end
        end

        state_token = generate_state_token
        store_state_token(state_token)

        auth_params = {
          client_id: client.id,
          redirect_uri: callback_url,
          scope: platform_config[:scope],
          state: state_token,
          response_type: platform_config[:response_type]
        }

        # Platform-specific authorization parameters
        case platform
        when "salesforce", "pardot"
          # Add custom parameters for Salesforce
          auth_params[:prompt] = "login"
        when "hubspot"
          # HubSpot specific parameters
          auth_params[:optional_scope] = "automation"
        when "marketo"
          # Marketo needs the client_id as client_id
          auth_params[:client_id] = client.id
        when "zoho"
          # Zoho specific parameters
          auth_params[:access_type] = "offline"
          auth_params[:prompt] = "consent"
        end

        url = build_authorization_url(auth_params)
        ServiceResult.success(data: { authorization_url: url, state: state_token })
      end
    rescue => e
      Rails.logger.error "CRM OAuth authorization URL generation failed for #{platform}: #{e.message}"
      ServiceResult.failure("Authorization URL generation failed: #{e.message}")
    end

    def exchange_code_for_token
      return ServiceResult.failure("Authorization code is required") if code.blank?
      return ServiceResult.failure("State parameter is required") if state.blank?

      unless validate_state_token(state)
        return ServiceResult.failure("Invalid state parameter - possible CSRF attack")
      end

      with_rate_limiting("#{platform}_oauth_token", user_id: brand&.user_id) do
        client = oauth_client
        return ServiceResult.failure("OAuth client configuration not found") unless client

        token_params = build_token_params(client)

        response = Faraday.post(platform_config[:token_url]) do |req|
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.headers["Accept"] = "application/json"
          req.body = URI.encode_www_form(token_params)
        end

        if response.success?
          token_data = JSON.parse(response.body)
          process_token_response(token_data)
        else
          error_message = extract_error_from_response(response)
          ServiceResult.failure("Token exchange failed: #{error_message}")
        end
      end
    rescue => e
      Rails.logger.error "CRM OAuth token exchange failed for #{platform}: #{e.message}"
      ServiceResult.failure("Token exchange failed: #{e.message}")
    end

    def refresh_access_token(refresh_token)
      return ServiceResult.failure("Refresh token is required") if refresh_token.blank?

      with_rate_limiting("#{platform}_oauth_refresh", user_id: brand&.user_id) do
        client = oauth_client
        return ServiceResult.failure("OAuth client configuration not found") unless client

        refresh_params = build_refresh_params(client, refresh_token)

        response = Faraday.post(platform_config[:token_url]) do |req|
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.headers["Accept"] = "application/json"
          req.body = URI.encode_www_form(refresh_params)
        end

        if response.success?
          token_data = JSON.parse(response.body)
          process_token_response(token_data, is_refresh: true)
        else
          error_message = extract_error_from_response(response)
          ServiceResult.failure("Token refresh failed: #{error_message}")
        end
      end
    rescue => e
      Rails.logger.error "CRM OAuth token refresh failed for #{platform}: #{e.message}"
      ServiceResult.failure("Token refresh failed: #{e.message}")
    end

    def revoke_access_token(access_token)
      return ServiceResult.failure("Access token is required") if access_token.blank?

      with_rate_limiting("#{platform}_oauth_revoke", user_id: brand&.user_id) do
        case platform
        when "salesforce", "pardot"
          revoke_salesforce_token(access_token)
        when "hubspot"
          revoke_hubspot_token(access_token)
        when "marketo"
          revoke_marketo_token(access_token)
        when "pipedrive"
          revoke_pipedrive_token(access_token)
        when "zoho"
          revoke_zoho_token(access_token)
        else
          ServiceResult.failure("Token revocation not supported for #{platform}")
        end
      end
    rescue => e
      Rails.logger.error "CRM token revocation failed for #{platform}: #{e.message}"
      ServiceResult.failure("Token revocation failed: #{e.message}")
    end

    def validate_token(access_token)
      return ServiceResult.failure("Access token is required") if access_token.blank?

      with_rate_limiting("#{platform}_oauth_validate", user_id: brand&.user_id) do
        case platform
        when "salesforce", "pardot"
          validate_salesforce_token(access_token)
        when "hubspot"
          validate_hubspot_token(access_token)
        when "marketo"
          validate_marketo_token(access_token)
        when "pipedrive"
          validate_pipedrive_token(access_token)
        when "zoho"
          validate_zoho_token(access_token)
        else
          ServiceResult.failure("Token validation not supported for #{platform}")
        end
      end
    rescue => e
      Rails.logger.error "CRM token validation failed for #{platform}: #{e.message}"
      ServiceResult.failure("Token validation failed: #{e.message}")
    end

    private

    def oauth_client
      config = platform_config
      return nil unless config

      client_id = @client_configs.dig(platform, "client_id")
      client_secret = @client_configs.dig(platform, "client_secret")

      return nil unless client_id && client_secret

      # For platforms that need dynamic URLs (like Marketo), replace placeholders
      if platform == "marketo" && integration&.instance_url.present?
        munchkin_id = extract_munchkin_id(integration.instance_url)
        config = config.transform_values { |v| v.gsub("{munchkin_id}", munchkin_id) }
      end

      OpenStruct.new(
        id: client_id,
        secret: client_secret,
        site: extract_site_from_auth_url(config[:auth_url]),
        authorize_url: config[:auth_url],
        token_url: config[:token_url]
      )
    end

    def platform_config
      config = PLATFORM_CONFIGS[platform]
      return config unless config

      # Use sandbox URLs for Salesforce if specified
      if [ "salesforce", "pardot" ].include?(platform) && integration&.sandbox_mode?
        config = config.merge(
          auth_url: config[:sandbox_auth_url],
          token_url: config[:sandbox_token_url]
        )
      end

      config
    end

    def load_client_configs
      {
        "salesforce" => {
          "client_id" => Rails.application.credentials.dig(:salesforce, :client_id),
          "client_secret" => Rails.application.credentials.dig(:salesforce, :client_secret)
        },
        "hubspot" => {
          "client_id" => Rails.application.credentials.dig(:hubspot, :client_id),
          "client_secret" => Rails.application.credentials.dig(:hubspot, :client_secret)
        },
        "marketo" => {
          "client_id" => Rails.application.credentials.dig(:marketo, :client_id),
          "client_secret" => Rails.application.credentials.dig(:marketo, :client_secret)
        },
        "pardot" => {
          "client_id" => Rails.application.credentials.dig(:pardot, :client_id),
          "client_secret" => Rails.application.credentials.dig(:pardot, :client_secret)
        },
        "pipedrive" => {
          "client_id" => Rails.application.credentials.dig(:pipedrive, :client_id),
          "client_secret" => Rails.application.credentials.dig(:pipedrive, :client_secret)
        },
        "zoho" => {
          "client_id" => Rails.application.credentials.dig(:zoho, :client_id),
          "client_secret" => Rails.application.credentials.dig(:zoho, :client_secret)
        }
      }
    end

    def generate_state_token
      SecureRandom.hex(32)
    end

    def store_state_token(token)
      redis = Redis.new
      redis.setex("crm_oauth_state:#{brand.id}:#{platform}", 600, token)
    rescue Redis::CannotConnectError
      Rails.logger.warn "Redis not available for storing CRM OAuth state token"
    end

    def validate_state_token(token)
      redis = Redis.new
      stored_token = redis.get("crm_oauth_state:#{brand.id}:#{platform}")
      stored_token == token
    rescue Redis::CannotConnectError
      Rails.logger.warn "Redis not available for validating CRM OAuth state token"
      true
    end

    def build_authorization_url(params)
      uri = URI.parse(platform_config[:auth_url])
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def build_token_params(client)
      params = {
        grant_type: "authorization_code",
        client_id: client.id,
        client_secret: client.secret,
        code: code,
        redirect_uri: callback_url
      }

      # Platform-specific token parameters
      case platform
      when "hubspot"
        params.delete(:client_secret) # HubSpot uses client_secret in headers
      when "zoho"
        params[:access_type] = "offline"
      end

      params
    end

    def build_refresh_params(client, refresh_token)
      params = {
        grant_type: "refresh_token",
        client_id: client.id,
        client_secret: client.secret,
        refresh_token: refresh_token
      }

      # Platform-specific refresh parameters
      case platform
      when "hubspot"
        params.delete(:client_secret) # HubSpot uses client_secret in headers
      end

      params
    end

    def process_token_response(token_data, is_refresh: false)
      processed_data = {
        access_token: token_data["access_token"],
        refresh_token: token_data["refresh_token"],
        token_type: token_data["token_type"] || "Bearer",
        scope: token_data["scope"]
      }

      # Calculate expires_at
      if token_data["expires_in"]
        processed_data[:expires_at] = Time.current + token_data["expires_in"].to_i.seconds
      end

      # Platform-specific token processing
      case platform
      when "salesforce", "pardot"
        processed_data[:instance_url] = token_data["instance_url"]
        processed_data[:id] = token_data["id"]
      when "hubspot"
        processed_data[:hub_domain] = token_data["hub_domain"]
        processed_data[:hub_id] = token_data["hub_id"]
      when "marketo"
        processed_data[:instance_url] = token_data["instance_url"]
      when "zoho"
        processed_data[:api_domain] = token_data["api_domain"]
      end

      # Fetch account information if this is initial token exchange
      unless is_refresh
        account_info = fetch_account_information(processed_data[:access_token])
        if account_info.success?
          processed_data.merge!(account_info.data)
        end
      end

      ServiceResult.success(data: processed_data)
    end

    def fetch_account_information(access_token)
      case platform
      when "salesforce", "pardot"
        fetch_salesforce_account_info(access_token)
      when "hubspot"
        fetch_hubspot_account_info(access_token)
      when "marketo"
        fetch_marketo_account_info(access_token)
      when "pipedrive"
        fetch_pipedrive_account_info(access_token)
      when "zoho"
        fetch_zoho_account_info(access_token)
      else
        ServiceResult.failure("Account info not supported for #{platform}")
      end
    end

    def fetch_salesforce_account_info(access_token)
      instance_url = integration&.instance_url || "https://login.salesforce.com"

      response = Faraday.get("#{instance_url}/services/data/v58.0/sobjects/User/#{user_id}/") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
        req.headers["Accept"] = "application/json"
      end

      if response.success?
        data = JSON.parse(response.body)
        ServiceResult.success(data: {
          platform_user_id: data["Id"],
          user_name: data["Name"],
          user_email: data["Email"],
          organization_id: data["CompanyName"]
        })
      else
        ServiceResult.failure("Failed to fetch Salesforce account information")
      end
    rescue => e
      ServiceResult.failure("Error fetching Salesforce account info: #{e.message}")
    end

    def fetch_hubspot_account_info(access_token)
      response = Faraday.get("https://api.hubapi.com/oauth/v1/access-tokens/#{access_token}") do |req|
        req.headers["Accept"] = "application/json"
      end

      if response.success?
        data = JSON.parse(response.body)
        ServiceResult.success(data: {
          platform_user_id: data["user_id"],
          user_email: data["user"],
          hub_domain: data["hub_domain"],
          hub_id: data["hub_id"],
          organization_id: data["hub_id"]
        })
      else
        ServiceResult.failure("Failed to fetch HubSpot account information")
      end
    rescue => e
      ServiceResult.failure("Error fetching HubSpot account info: #{e.message}")
    end

    def fetch_marketo_account_info(access_token)
      instance_url = integration&.instance_url
      return ServiceResult.failure("Instance URL required for Marketo") unless instance_url

      response = Faraday.get("#{instance_url}/identity/oauth/token?access_token=#{access_token}") do |req|
        req.headers["Accept"] = "application/json"
      end

      if response.success?
        data = JSON.parse(response.body)
        ServiceResult.success(data: {
          platform_user_id: data["userId"],
          user_email: data["userEmail"],
          organization_id: data["munchkinId"]
        })
      else
        ServiceResult.failure("Failed to fetch Marketo account information")
      end
    rescue => e
      ServiceResult.failure("Error fetching Marketo account info: #{e.message}")
    end

    def fetch_pipedrive_account_info(access_token)
      response = Faraday.get("https://api.pipedrive.com/v1/users/me") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
        req.headers["Accept"] = "application/json"
      end

      if response.success?
        data = JSON.parse(response.body)
        user_data = data["data"]
        ServiceResult.success(data: {
          platform_user_id: user_data["id"],
          user_name: user_data["name"],
          user_email: user_data["email"],
          organization_id: user_data["company_id"]
        })
      else
        ServiceResult.failure("Failed to fetch Pipedrive account information")
      end
    rescue => e
      ServiceResult.failure("Error fetching Pipedrive account info: #{e.message}")
    end

    def fetch_zoho_account_info(access_token)
      response = Faraday.get("https://www.zohoapis.com/crm/v2/users?type=CurrentUser") do |req|
        req.headers["Authorization"] = "Zoho-oauthtoken #{access_token}"
        req.headers["Accept"] = "application/json"
      end

      if response.success?
        data = JSON.parse(response.body)
        if data["users"]&.any?
          user_data = data["users"].first
          ServiceResult.success(data: {
            platform_user_id: user_data["id"],
            user_name: user_data["full_name"],
            user_email: user_data["email"],
            organization_id: user_data["org_id"]
          })
        else
          ServiceResult.failure("No user data found in Zoho response")
        end
      else
        ServiceResult.failure("Failed to fetch Zoho account information")
      end
    rescue => e
      ServiceResult.failure("Error fetching Zoho account info: #{e.message}")
    end

    def extract_error_from_response(response)
      begin
        error_data = JSON.parse(response.body)
        error_data["error_description"] || error_data["error"] || error_data["message"] || "Unknown error"
      rescue JSON::ParserError
        response.body.presence || "HTTP #{response.status}"
      end
    end

    def extract_site_from_auth_url(auth_url)
      uri = URI.parse(auth_url)
      "#{uri.scheme}://#{uri.host}"
    end

    def extract_munchkin_id(instance_url)
      # Extract Munchkin ID from Marketo instance URL
      # e.g., "https://123-ABC-456.mktorest.com" -> "123-ABC-456"
      uri = URI.parse(instance_url)
      uri.host.split(".").first
    end

    # Token revocation methods
    def revoke_salesforce_token(access_token)
      revoke_url = integration&.sandbox_mode? ?
        "https://test.salesforce.com/services/oauth2/revoke" :
        "https://login.salesforce.com/services/oauth2/revoke"

      response = Faraday.post(revoke_url) do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = "token=#{access_token}"
      end

      if response.success?
        ServiceResult.success(data: { message: "Salesforce token revoked successfully" })
      else
        ServiceResult.failure("Failed to revoke Salesforce token")
      end
    end

    def revoke_hubspot_token(access_token)
      client = oauth_client
      response = Faraday.delete("https://api.hubapi.com/oauth/v1/refresh-tokens/#{access_token}") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      if response.success?
        ServiceResult.success(data: { message: "HubSpot token revoked successfully" })
      else
        ServiceResult.failure("Failed to revoke HubSpot token")
      end
    end

    def revoke_marketo_token(access_token)
      # Marketo tokens expire automatically, no revocation endpoint
      ServiceResult.success(data: { message: "Marketo token will expire automatically" })
    end

    def revoke_pipedrive_token(access_token)
      # Pipedrive doesn't provide a standard revocation endpoint
      ServiceResult.success(data: { message: "Pipedrive token will expire automatically" })
    end

    def revoke_zoho_token(access_token)
      response = Faraday.post("https://accounts.zoho.com/oauth/v2/token/revoke") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = "token=#{access_token}"
      end

      if response.success?
        ServiceResult.success(data: { message: "Zoho token revoked successfully" })
      else
        ServiceResult.failure("Failed to revoke Zoho token")
      end
    end

    # Token validation methods (simplified versions of revocation)
    def validate_salesforce_token(access_token)
      instance_url = integration&.instance_url || (integration&.sandbox_mode? ? "https://test.salesforce.com" : "https://login.salesforce.com")

      response = Faraday.get("#{instance_url}/services/data/") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      ServiceResult.success(data: { valid: response.success? })
    end

    def validate_hubspot_token(access_token)
      response = Faraday.get("https://api.hubapi.com/oauth/v1/access-tokens/#{access_token}")
      ServiceResult.success(data: { valid: response.success? })
    end

    def validate_marketo_token(access_token)
      instance_url = integration&.instance_url
      return ServiceResult.failure("Instance URL required") unless instance_url

      response = Faraday.get("#{instance_url}/identity/oauth/token?access_token=#{access_token}")
      ServiceResult.success(data: { valid: response.success? })
    end

    def validate_pipedrive_token(access_token)
      response = Faraday.get("https://api.pipedrive.com/v1/users/me") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end
      ServiceResult.success(data: { valid: response.success? })
    end

    def validate_zoho_token(access_token)
      response = Faraday.get("https://www.zohoapis.com/crm/v2/users?type=CurrentUser") do |req|
        req.headers["Authorization"] = "Zoho-oauthtoken #{access_token}"
      end
      ServiceResult.success(data: { valid: response.success? })
    end
  end
end
