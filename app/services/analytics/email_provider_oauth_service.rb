# frozen_string_literal: true

module Analytics
  class EmailProviderOauthService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :platform, :brand, :callback_url, :code, :state

    # Email marketing platform OAuth configurations
    PLATFORM_CONFIGS = {
      "mailchimp" => {
        auth_url: "https://login.mailchimp.com/oauth2/authorize",
        token_url: "https://login.mailchimp.com/oauth2/token",
        scope: "read write",
        metadata_url: "https://login.mailchimp.com/oauth2/metadata"
      },
      "sendgrid" => {
        auth_url: "https://app.sendgrid.com/oauth/authorize",
        token_url: "https://api.sendgrid.com/v3/oauth/token",
        scope: "mail.send read_user_profile",
        revoke_url: "https://api.sendgrid.com/v3/oauth/revoke"
      },
      "constant_contact" => {
        auth_url: "https://authz.constantcontact.com/oauth2/default/v1/authorize",
        token_url: "https://authz.constantcontact.com/oauth2/default/v1/token",
        scope: "campaign_data contact_data offline_access",
        revoke_url: "https://authz.constantcontact.com/oauth2/default/v1/revoke"
      },
      "campaign_monitor" => {
        auth_url: "https://api.createsend.com/oauth",
        token_url: "https://api.createsend.com/oauth/token",
        scope: "ViewReports,CreateCampaigns,ManageLists,ViewSubscribers,SendCampaigns",
        revoke_url: "https://api.createsend.com/oauth/revoke"
      },
      "activecampaign" => {
        auth_url: "https://oauth.activecampaign.com/oauth/authorize",
        token_url: "https://oauth.activecampaign.com/oauth/token",
        scope: "list:read campaign:read automation:read contact:read tag:read",
        api_base_url: "api_url" # ActiveCampaign requires custom API URL per account
      },
      "klaviyo" => {
        auth_url: "https://www.klaviyo.com/oauth/authorize",
        token_url: "https://www.klaviyo.com/oauth/token",
        scope: "campaigns:read profiles:read metrics:read flows:read lists:read",
        revoke_url: "https://www.klaviyo.com/oauth/revoke"
      }
    }.freeze

    # Supported email marketing platforms
    EMAIL_PLATFORMS = %w[mailchimp sendgrid constant_contact campaign_monitor activecampaign klaviyo].freeze

    validates :platform, presence: true, inclusion: { in: EMAIL_PLATFORMS }
    validates :brand, presence: true

    def initialize(attributes = {})
      super
      @client_configs = load_client_configs
    end

    def authorization_url
      client = oauth_client

      unless client
        return mock_authorization_url if Rails.env.test? || Rails.env.development?

        return ServiceResult.failure("OAuth client configuration not found for #{platform}")
      end

      state_token = generate_state_token
      store_state_token(state_token)

      url = build_authorization_url(client, state_token)

      ServiceResult.success(data: { authorization_url: url, state: state_token })
    rescue StandardError => e
      Rails.logger.error "OAuth authorization URL generation failed for #{platform}: #{e.message}"
      ServiceResult.failure("Authorization URL generation failed: #{e.message}")
    end

    def exchange_code_for_token
      return ServiceResult.failure("Authorization code is required") if code.blank?
      return ServiceResult.failure("State parameter is required") if state.blank?

      unless validate_state_token(state)
        return ServiceResult.failure("Invalid state parameter - possible CSRF attack")
      end

      token_data = fetch_access_token
      return token_data unless token_data.success?

      # Get platform-specific account information
      account_info = fetch_account_information(token_data.data[:access_token])
      token_data.data.merge!(account_info.data) if account_info.success?

      ServiceResult.success(data: token_data.data)
    rescue OAuth2::Error => e
      Rails.logger.error "OAuth token exchange failed for #{platform}: #{e.message}"
      ServiceResult.failure("Token exchange failed: #{e.description}")
    rescue StandardError => e
      Rails.logger.error "Unexpected error during token exchange for #{platform}: #{e.message}"
      ServiceResult.failure("Token exchange failed: #{e.message}")
    end

    def refresh_access_token(refresh_token)
      return ServiceResult.failure("Refresh token is required") if refresh_token.blank?

      client = oauth_client
      return ServiceResult.failure("OAuth client configuration not found") unless client

      token = OAuth2::AccessToken.new(client, "", refresh_token: refresh_token)
      new_token = token.refresh!

      token_data = {
        access_token: new_token.token,
        refresh_token: new_token.refresh_token,
        expires_at: calculate_expires_at(new_token),
        scope: new_token.params["scope"]
      }

      ServiceResult.success(data: token_data)
    rescue OAuth2::Error => e
      Rails.logger.error "OAuth token refresh failed for #{platform}: #{e.message}"
      ServiceResult.failure("Token refresh failed: #{e.description}")
    rescue StandardError => e
      Rails.logger.error "Unexpected error during token refresh for #{platform}: #{e.message}"
      ServiceResult.failure("Token refresh failed: #{e.message}")
    end

    def revoke_access_token(access_token)
      config = platform_config
      return ServiceResult.failure("Token revocation not supported for this platform") unless config[:revoke_url]

      response = make_revocation_request(config[:revoke_url], access_token)

      if response.success?
        ServiceResult.success(data: { message: "#{platform.humanize} token revoked successfully" })
      else
        ServiceResult.failure("Failed to revoke #{platform} token")
      end
    rescue StandardError => e
      Rails.logger.error "Token revocation failed for #{platform}: #{e.message}"
      ServiceResult.failure("Token revocation failed: #{e.message}")
    end

    private

    def oauth_client
      config = platform_config
      return nil unless config

      client_id = @client_configs.dig(platform, "client_id")
      client_secret = @client_configs.dig(platform, "client_secret")

      return nil unless client_id && client_secret

      OAuth2::Client.new(
        client_id,
        client_secret,
        site: extract_site_from_url(config[:auth_url]),
        authorize_url: config[:auth_url],
        token_url: config[:token_url]
      )
    end

    def platform_config
      PLATFORM_CONFIGS[platform]
    end

    def load_client_configs
      {
        "mailchimp" => {
          "client_id" => Rails.application.credentials.dig(:mailchimp, :client_id),
          "client_secret" => Rails.application.credentials.dig(:mailchimp, :client_secret)
        },
        "sendgrid" => {
          "client_id" => Rails.application.credentials.dig(:sendgrid, :client_id),
          "client_secret" => Rails.application.credentials.dig(:sendgrid, :client_secret)
        },
        "constant_contact" => {
          "client_id" => Rails.application.credentials.dig(:constant_contact, :client_id),
          "client_secret" => Rails.application.credentials.dig(:constant_contact, :client_secret)
        },
        "campaign_monitor" => {
          "client_id" => Rails.application.credentials.dig(:campaign_monitor, :client_id),
          "client_secret" => Rails.application.credentials.dig(:campaign_monitor, :client_secret)
        },
        "activecampaign" => {
          "client_id" => Rails.application.credentials.dig(:activecampaign, :client_id),
          "client_secret" => Rails.application.credentials.dig(:activecampaign, :client_secret)
        },
        "klaviyo" => {
          "client_id" => Rails.application.credentials.dig(:klaviyo, :client_id),
          "client_secret" => Rails.application.credentials.dig(:klaviyo, :client_secret)
        }
      }
    end

    def build_authorization_url(client, state_token)
      params = {
        redirect_uri: callback_url,
        scope: platform_config[:scope],
        state: state_token,
        response_type: "code"
      }

      # Add platform-specific parameters
      case platform
      when "mailchimp"
        params[:response_type] = "code"
      when "activecampaign"
        params[:approval_prompt] = "auto"
      when "klaviyo"
        params[:code_challenge_method] = "S256" if Rails.env.production?
      end

      client.auth_code.authorize_url(params)
    end

    def fetch_access_token
      client = oauth_client
      return ServiceResult.failure("OAuth client configuration not found") unless client

      access_token = client.auth_code.get_token(
        code,
        redirect_uri: callback_url
      )

      token_data = {
        access_token: access_token.token,
        refresh_token: access_token.refresh_token,
        expires_at: calculate_expires_at(access_token),
        scope: access_token.params["scope"]
      }

      # Handle platform-specific token data
      handle_platform_specific_token_data(access_token, token_data)

      ServiceResult.success(data: token_data)
    end

    def handle_platform_specific_token_data(access_token, token_data)
      case platform
      when "mailchimp"
        # Mailchimp provides additional metadata URL
        metadata = fetch_mailchimp_metadata(access_token.token)
        token_data[:api_endpoint] = metadata["api_endpoint"] if metadata
        token_data[:login_url] = metadata["login_url"] if metadata
      when "activecampaign"
        # ActiveCampaign requires API URL from account info
        account_info = fetch_activecampaign_account_info(access_token.token)
        token_data[:api_url] = account_info["account_url"] if account_info
      end
    end

    def fetch_account_information(access_token)
      case platform
      when "mailchimp"
        fetch_mailchimp_account_info(access_token)
      when "sendgrid"
        fetch_sendgrid_account_info(access_token)
      when "constant_contact"
        fetch_constant_contact_account_info(access_token)
      when "campaign_monitor"
        fetch_campaign_monitor_account_info(access_token)
      when "activecampaign"
        fetch_activecampaign_account_info(access_token)
      when "klaviyo"
        fetch_klaviyo_account_info(access_token)
      else
        ServiceResult.failure("Platform not supported")
      end
    end

    def fetch_mailchimp_metadata(access_token)
      response = Faraday.get(platform_config[:metadata_url]) do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      JSON.parse(response.body) if response.success?
    rescue StandardError => e
      Rails.logger.error "Failed to fetch Mailchimp metadata: #{e.message}"
      nil
    end

    def fetch_mailchimp_account_info(access_token)
      metadata = fetch_mailchimp_metadata(access_token)
      return ServiceResult.failure("Failed to fetch Mailchimp metadata") unless metadata

      response = Faraday.get("#{metadata['api_endpoint']}/3.0/") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      if response.success?
        data = JSON.parse(response.body)
        ServiceResult.success(data: {
          platform_account_id: data["account_id"],
          account_name: data["account_name"],
          api_endpoint: metadata["api_endpoint"]
        })
      else
        ServiceResult.failure("Failed to fetch Mailchimp account information")
      end
    rescue StandardError => e
      ServiceResult.failure("Error fetching Mailchimp account info: #{e.message}")
    end

    def fetch_sendgrid_account_info(access_token)
      response = Faraday.get("https://api.sendgrid.com/v3/user/profile") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      if response.success?
        data = JSON.parse(response.body)
        ServiceResult.success(data: {
          platform_account_id: data["username"],
          account_name: "#{data['first_name']} #{data['last_name']}",
          email: data["email"]
        })
      else
        ServiceResult.failure("Failed to fetch SendGrid account information")
      end
    rescue StandardError => e
      ServiceResult.failure("Error fetching SendGrid account info: #{e.message}")
    end

    def fetch_constant_contact_account_info(access_token)
      response = Faraday.get("https://api.cc.email/v3/account/summary") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      if response.success?
        data = JSON.parse(response.body)
        ServiceResult.success(data: {
          platform_account_id: data["encoded_account_id"],
          account_name: data["organization_name"],
          contact_email: data["contact_email"]
        })
      else
        ServiceResult.failure("Failed to fetch Constant Contact account information")
      end
    rescue StandardError => e
      ServiceResult.failure("Error fetching Constant Contact account info: #{e.message}")
    end

    def fetch_campaign_monitor_account_info(access_token)
      response = Faraday.get("https://api.createsend.com/api/v3.3/account.json") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      if response.success?
        data = JSON.parse(response.body)
        ServiceResult.success(data: {
          platform_account_id: data["AccountID"],
          account_name: data["CompanyName"],
          contact_email: data["ContactEmail"]
        })
      else
        ServiceResult.failure("Failed to fetch Campaign Monitor account information")
      end
    rescue StandardError => e
      ServiceResult.failure("Error fetching Campaign Monitor account info: #{e.message}")
    end

    def fetch_activecampaign_account_info(access_token)
      # ActiveCampaign requires account-specific API URL
      # This would typically be stored during initial setup
      api_url = @client_configs.dig(platform, "api_url") || "https://youraccount.api-us1.com"

      response = Faraday.get("#{api_url}/api/3/users/me") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      if response.success?
        data = JSON.parse(response.body)
        user = data["user"]
        ServiceResult.success(data: {
          platform_account_id: user["id"],
          account_name: "#{user['firstName']} #{user['lastName']}",
          email: user["email"],
          api_url: api_url
        })
      else
        ServiceResult.failure("Failed to fetch ActiveCampaign account information")
      end
    rescue StandardError => e
      ServiceResult.failure("Error fetching ActiveCampaign account info: #{e.message}")
    end

    def fetch_klaviyo_account_info(access_token)
      response = Faraday.get("https://a.klaviyo.com/api/accounts/") do |req|
        req.headers["Authorization"] = "Klaviyo-API-Key #{access_token}"
        req.headers["Accept"] = "application/json"
        req.headers["Revision"] = "2024-10-15"
      end

      if response.success?
        data = JSON.parse(response.body)
        account = data["data"].first
        ServiceResult.success(data: {
          platform_account_id: account["id"],
          account_name: account["attributes"]["test_account"] ? "Test Account" : "Production Account",
          contact_email: account["attributes"]["contact_information"]["default_sender_email"]
        })
      else
        ServiceResult.failure("Failed to fetch Klaviyo account information")
      end
    rescue StandardError => e
      ServiceResult.failure("Error fetching Klaviyo account info: #{e.message}")
    end

    def mock_authorization_url
      state_token = generate_state_token
      store_state_token(state_token)
      mock_url = "https://#{platform}.com/oauth/authorize?state=#{state_token}"
      ServiceResult.success(data: { authorization_url: mock_url, state: state_token })
    end

    def generate_state_token
      SecureRandom.hex(32)
    end

    def store_state_token(token)
      Redis.new.setex("email_oauth_state:#{brand.id}:#{platform}", 600, token)
    rescue Redis::CannotConnectError
      Rails.logger.warn "Redis not available for storing OAuth state token"
    end

    def validate_state_token(token)
      Redis.new.get("email_oauth_state:#{brand.id}:#{platform}") == token
    rescue Redis::CannotConnectError
      Rails.logger.warn "Redis not available for validating OAuth state token"
      true
    end

    def calculate_expires_at(access_token)
      return nil unless access_token.expires?

      Time.current + access_token.expires_in.seconds
    end

    def extract_site_from_url(url)
      uri = URI.parse(url)
      "#{uri.scheme}://#{uri.host}"
    end

    def make_revocation_request(revoke_url, access_token)
      case platform
      when "sendgrid", "constant_contact"
        Faraday.delete(revoke_url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
        end
      when "campaign_monitor"
        Faraday.post(revoke_url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
        end
      when "klaviyo"
        Faraday.post(revoke_url) do |req|
          req.headers["Authorization"] = "Klaviyo-API-Key #{access_token}"
          req.headers["Content-Type"] = "application/json"
        end
      else
        # Default POST request
        Faraday.post(revoke_url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
        end
      end
    end
  end
end
