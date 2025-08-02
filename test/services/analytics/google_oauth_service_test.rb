# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class Analytics::GoogleOauthServiceTest < ActiveSupport::TestCase

  def setup
    @user = users(:one)
    @service = Analytics::GoogleOauthService.new(user_id: @user.id, integration_type: :google_ads)
    @mock_redis = Minitest::Mock.new
    
    # Mock Redis for testing
    Redis.stub :new, @mock_redis do
      # Tests will run here
    end

    # Mock credentials
    Rails.application.credentials.stub :dig, "test_client_id" do
      ENV["GOOGLE_CLIENT_ID"] = "test_client_id"
      ENV["GOOGLE_CLIENT_SECRET"] = "test_client_secret"
    end
  end

  test "should initialize with correct parameters" do
    assert_equal @user.id, @service.instance_variable_get(:@user_id)
    assert_equal :google_ads, @service.instance_variable_get(:@integration_type)
  end

  test "should raise error for invalid integration type" do
    assert_raises ArgumentError do
      Analytics::GoogleOauthService.new(user_id: @user.id, integration_type: :invalid_type)
    end
  end

  test "should generate authorization URL with correct parameters" do
    # Mock Redis operations for state generation
    @mock_redis.expect :setex, "OK", [String, Integer, String]
    
    Redis.stub :new, @mock_redis do
      authorization_url = @service.authorization_url
      
      assert authorization_url.include?("https://accounts.google.com/o/oauth2/auth")
      assert authorization_url.include?("client_id=test_client_id")
      assert authorization_url.include?("scope=")
      assert authorization_url.include?("access_type=offline")
      assert authorization_url.include?("prompt=consent")
    end
    
    @mock_redis.verify
  end

  test "should include correct scopes for google_ads integration" do
    # Mock Redis for state generation
    @mock_redis.expect :setex, "OK", [String, Integer, String]
    
    Redis.stub :new, @mock_redis do
      authorization_url = @service.authorization_url
      
      assert authorization_url.include?("adwords")
      assert authorization_url.include?("analytics.readonly")
    end
    
    @mock_redis.verify
  end

  test "should exchange authorization code for tokens" do
    # Mock successful token exchange
    mock_token = Minitest::Mock.new
    mock_token.expect :token, "access_token_123"
    mock_token.expect :refresh_token, "refresh_token_123"
    mock_token.expect :expires_at, Time.current.to_i + 3600
    mock_token.expect :params, { "scope" => "test_scope" }

    mock_client = Minitest::Mock.new
    mock_auth_code = Minitest::Mock.new
    mock_auth_code.expect :get_token, mock_token, ["auth_code_123", Hash]

    mock_client.expect :auth_code, mock_auth_code

    # Mock Redis operations
    @mock_redis.expect :get, '{"user_id": 1, "integration_type": "google_ads", "timestamp": ' + (Time.current.to_i - 100).to_s + '}', [String]
    @mock_redis.expect :setex, "OK", [String, Integer, String]
    
    Redis.stub :new, @mock_redis do
      @service.stub :build_oauth_client, mock_client do
        @service.stub :store_tokens_in_database, true do
          result = @service.exchange_code_for_tokens("auth_code_123", "valid_state")
          
          assert_equal "access_token_123", result[:access_token]
          assert_equal "refresh_token_123", result[:refresh_token]
          assert result[:expires_at].is_a?(Time)
        end
      end
    end
    
    @mock_redis.verify
    mock_client.verify
    mock_auth_code.verify
    mock_token.verify
  end

  test "should raise error for invalid state token" do
    # Mock Redis returning nil for invalid state
    @mock_redis.expect :get, nil, [String]
    
    Redis.stub :new, @mock_redis do
      assert_raises Analytics::GoogleOauthService::GoogleApiError do
        @service.exchange_code_for_tokens("auth_code_123", "invalid_state")
      end
    end
    
    @mock_redis.verify
  end

  test "should refresh access token when expired" do
    # Mock stored token data
    stored_token = {
      access_token: "old_access_token",
      refresh_token: "refresh_token_123",
      expires_at: Time.current.to_i - 3600 # Expired
    }

    # Mock refreshed token
    mock_refreshed_token = Minitest::Mock.new
    mock_refreshed_token.expect :token, "new_access_token"
    mock_refreshed_token.expect :refresh_token, "refresh_token_123"
    mock_refreshed_token.expect :expires_at, Time.current.to_i + 3600
    mock_refreshed_token.expect :params, { "scope" => "test_scope" }

    mock_oauth_token = Minitest::Mock.new
    mock_oauth_token.expect :refresh!, mock_refreshed_token

    # Mock Redis operations
    @mock_redis.expect :get, stored_token.to_json, [String]
    @mock_redis.expect :setex, "OK", [String, Integer, String]
    
    Redis.stub :new, @mock_redis do
      OAuth2::AccessToken.stub :new, mock_oauth_token do
        @service.stub :build_oauth_client, nil do
          @service.stub :store_tokens_in_database, true do
            result = @service.access_token
            assert_equal "new_access_token", result
          end
        end
      end
    end
    
    @mock_redis.verify
    mock_oauth_token.verify
    mock_refreshed_token.verify
  end

  test "should return valid access token when not expired" do
    # Mock valid stored token
    stored_token = {
      access_token: "valid_access_token",
      refresh_token: "refresh_token_123",
      expires_at: Time.current.to_i + 3600 # Not expired
    }

    @mock_redis.expect :get, stored_token.to_json, [String]
    
    Redis.stub :new, @mock_redis do
      result = @service.access_token
      assert_equal "valid_access_token", result
    end
    
    @mock_redis.verify
  end

  test "should revoke access tokens" do
    # Mock stored token
    stored_token = {
      access_token: "access_token_123",
      refresh_token: "refresh_token_123",
      expires_at: Time.current.to_i + 3600
    }

    # Mock successful HTTP response for revocation
    stub_request(:post, "https://oauth2.googleapis.com/revoke")
      .to_return(status: 200, body: "", headers: {})

    @mock_redis.expect :get, stored_token.to_json, [String]
    @mock_redis.expect :del, 1, [String]
    
    Redis.stub :new, @mock_redis do
      @service.stub :clear_tokens_from_database, true do
        result = @service.revoke_access
        assert result
      end
    end
    
    @mock_redis.verify
  end

  test "should check authentication status correctly" do
    # Test with valid token
    valid_token = {
      access_token: "valid_token",
      refresh_token: "refresh_token",
      expires_at: Time.current.to_i + 3600
    }

    @mock_redis.expect :get, valid_token.to_json, [String]
    
    Redis.stub :new, @mock_redis do
      assert @service.authenticated?
    end

    # Test with expired token but valid refresh token
    expired_token = {
      access_token: "expired_token",
      refresh_token: "refresh_token",
      expires_at: Time.current.to_i - 3600
    }

    @mock_redis.expect :get, expired_token.to_json, [String]
    
    Redis.stub :new, @mock_redis do
      assert @service.authenticated?
    end

    # Test with no token
    @mock_redis.expect :get, nil, [String]
    @mock_redis.expect :get, nil, [String] # Fallback to database
    
    Redis.stub :new, @mock_redis do
      @service.stub :fetch_tokens_from_database, nil do
        refute @service.authenticated?
      end
    end
    
    @mock_redis.verify
  end

  test "should get user info with valid token" do
    # Mock successful user info response
    user_info_response = {
      id: "123456789",
      email: "test@example.com",
      name: "Test User"
    }

    stub_request(:get, "https://www.googleapis.com/oauth2/v2/userinfo")
      .with(headers: { "Authorization" => "Bearer valid_access_token" })
      .to_return(
        status: 200,
        body: user_info_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @service.stub :access_token, "valid_access_token" do
      result = @service.user_info
      
      assert_equal "123456789", result["id"]
      assert_equal "test@example.com", result["email"]
      assert_equal "Test User", result["name"]
    end
  end

  test "should handle OAuth errors gracefully" do
    mock_client = Minitest::Mock.new
    mock_auth_code = Minitest::Mock.new
    
    oauth_error = OAuth2::Error.new(double("response", parsed: { "error" => "invalid_grant" }))
    mock_auth_code.expect :get_token, -> { raise oauth_error }, ["invalid_code", Hash]
    mock_client.expect :auth_code, mock_auth_code

    # Mock valid state
    @mock_redis.expect :get, '{"user_id": 1, "integration_type": "google_ads", "timestamp": ' + (Time.current.to_i - 100).to_s + '}', [String]
    
    Redis.stub :new, @mock_redis do
      @service.stub :build_oauth_client, mock_client do
        assert_raises Analytics::GoogleOauthService::GoogleApiError do
          @service.exchange_code_for_tokens("invalid_code", "valid_state")
        end
      end
    end
    
    @mock_redis.verify
    mock_client.verify
    mock_auth_code.verify
  end

  test "should encrypt and decrypt tokens securely" do
    test_token = "sensitive_token_123"
    
    # Mock credentials
    Rails.application.credentials.stub :google_token_encryption_key, "a" * 32 do
      encrypted = @service.send(:encrypt_token, test_token)
      decrypted = @service.send(:decrypt_token, encrypted)
      
      assert_equal test_token, decrypted
      refute_equal test_token, encrypted
    end
  end

  test "should handle different integration types with correct scopes" do
    # Test Google Analytics integration
    ga_service = Analytics::GoogleOauthService.new(user_id: @user.id, integration_type: :google_analytics)
    @mock_redis.expect :setex, "OK", [String, Integer, String]
    
    Redis.stub :new, @mock_redis do
      auth_url = ga_service.authorization_url
      assert auth_url.include?("analytics.readonly")
      refute auth_url.include?("adwords")
    end

    # Test Search Console integration
    sc_service = Analytics::GoogleOauthService.new(user_id: @user.id, integration_type: :search_console)
    @mock_redis.expect :setex, "OK", [String, Integer, String]
    
    Redis.stub :new, @mock_redis do
      auth_url = sc_service.authorization_url
      assert auth_url.include?("webmasters.readonly")
    end
    
    @mock_redis.verify
  end

  private

  def double(name, attributes = {})
    mock = Minitest::Mock.new
    attributes.each do |key, value|
      mock.expect key, value
    end
    mock
  end
end