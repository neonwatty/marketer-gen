# frozen_string_literal: true

require "test_helper"

class EmailIntegrationTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @brand = brands(:acme_corp)
    @brand.update!(user: @user)
  end

  test "should belong to brand" do
    integration = EmailIntegration.new(
      brand: @brand,
      platform: "mailchimp",
      access_token: "test_token"
    )
    
    assert_equal @brand, integration.brand
  end

  test "should validate presence of platform" do
    integration = EmailIntegration.new(brand: @brand)
    assert_not integration.valid?
    assert_includes integration.errors[:platform], "can't be blank"
  end

  test "should validate platform inclusion" do
    integration = EmailIntegration.new(
      brand: @brand,
      platform: "invalid_platform"
    )
    
    assert_not integration.valid?
    assert_includes integration.errors[:platform], "is not included in the list"
  end

  test "should validate uniqueness of platform per brand" do
    EmailIntegration.create!(
      brand: @brand,
      platform: "mailchimp",
      access_token: "token1"
    )

    duplicate = EmailIntegration.new(
      brand: @brand,
      platform: "mailchimp",
      access_token: "token2"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:platform], "has already been taken"
  end

  test "should allow same platform for different brands" do
    other_brand = Brand.create!(
      name: "Other Brand",
      user: @user,
      industry: "technology"
    )

    EmailIntegration.create!(
      brand: @brand,
      platform: "mailchimp",
      access_token: "token1"
    )

    other_integration = EmailIntegration.new(
      brand: other_brand,
      platform: "mailchimp",
      access_token: "token2"
    )

    assert other_integration.valid?
  end

  test "should set default status and error count" do
    integration = EmailIntegration.new(
      brand: @brand,
      platform: "sendgrid"
    )

    integration.valid? # Trigger validations

    assert_equal "pending", integration.status
    assert_equal 0, integration.error_count
  end

  test "active? should return true for active status" do
    integration = EmailIntegration.new(status: "active")
    assert integration.active?

    integration.status = "pending"
    assert_not integration.active?
  end

  test "expired? should check expiration date" do
    integration = EmailIntegration.new(expires_at: 1.hour.ago)
    assert integration.expired?

    integration.expires_at = 1.hour.from_now
    assert_not integration.expired?

    integration.expires_at = nil
    integration.status = "expired"
    assert integration.expired?
  end

  test "needs_refresh? should check if token needs refreshing" do
    integration = EmailIntegration.new(expires_at: 30.minutes.from_now)
    assert integration.needs_refresh?

    integration.expires_at = 2.hours.from_now
    assert_not integration.needs_refresh?
  end

  test "rate_limited? should check rate limit status" do
    integration = EmailIntegration.new(rate_limit_reset_at: 1.hour.from_now)
    assert integration.rate_limited?

    integration.rate_limit_reset_at = 1.hour.ago
    assert_not integration.rate_limited?
  end

  test "time_until_rate_limit_reset should calculate remaining time" do
    future_time = 30.minutes.from_now
    integration = EmailIntegration.new(rate_limit_reset_at: future_time)
    
    time_remaining = integration.time_until_rate_limit_reset
    assert time_remaining > 1700 # Approximately 30 minutes in seconds
    assert time_remaining < 1800
  end

  test "increment_error_count! should increment and update status" do
    integration = EmailIntegration.create!(
      brand: @brand,
      platform: "klaviyo",
      status: "active",
      access_token: "test_token"
    )

    integration.increment_error_count!
    assert_equal 1, integration.error_count
    assert_equal "active", integration.status

    # Increment to threshold
    4.times { integration.increment_error_count! }
    assert_equal 5, integration.error_count
    assert_equal "error", integration.status
  end

  test "reset_error_count! should reset count and status" do
    integration = EmailIntegration.create!(
      brand: @brand,
      platform: "constant_contact",
      status: "error",
      error_count: 5,
      access_token: "test_token"
    )

    integration.reset_error_count!
    assert_equal 0, integration.error_count
    assert_equal "active", integration.status
  end

  test "configuration_value should access nested configuration" do
    integration = EmailIntegration.new(
      configuration: { "api_url" => "https://api.example.com", "lists" => { "main" => "list_123" } }
    )

    assert_equal "https://api.example.com", integration.configuration_value("api_url")
    assert_nil integration.configuration_value("nonexistent")
  end

  test "set_configuration_value should update nested configuration" do
    integration = EmailIntegration.create!(
      brand: @brand,
      platform: "activecampaign",
      access_token: "test_token"
    )

    integration.set_configuration_value("webhook_id", "webhook_123")
    assert_equal "webhook_123", integration.configuration_value("webhook_id")
  end

  test "token_valid? should check token and expiration" do
    integration = EmailIntegration.new(access_token: "valid_token")
    assert integration.token_valid?

    integration.access_token = nil
    assert_not integration.token_valid?

    integration.access_token = "valid_token"
    integration.expires_at = 1.hour.ago
    assert_not integration.token_valid?
  end

  test "api_headers should return platform-specific headers" do
    integration = EmailIntegration.new(
      platform: "mailchimp",
      access_token: "test_token"
    )

    headers = integration.api_headers
    assert_equal "Bearer test_token", headers["Authorization"]

    integration.platform = "klaviyo"
    headers = integration.api_headers
    assert_equal "Klaviyo-API-Key test_token", headers["Authorization"]
    assert_equal "application/json", headers["Accept"]
  end

  test "api_base_url should return platform-specific URLs" do
    integration = EmailIntegration.new(
      platform: "sendgrid"
    )

    assert_equal "https://api.sendgrid.com/v3", integration.api_base_url

    integration.platform = "mailchimp"
    integration.api_endpoint = "https://us10.api.mailchimp.com/3.0"
    assert_equal "https://us10.api.mailchimp.com/3.0", integration.api_base_url
  end

  test "disconnect! should clear sensitive data" do
    integration = EmailIntegration.create!(
      brand: @brand,
      platform: "campaign_monitor",
      status: "active",
      access_token: "secret_token",
      refresh_token: "refresh_secret",
      platform_account_id: "account_123",
      webhook_secret: "webhook_secret"
    )

    integration.disconnect!

    assert_equal "disconnected", integration.status
    assert_nil integration.access_token
    assert_nil integration.refresh_token
    assert_nil integration.platform_account_id
    assert_nil integration.webhook_secret
    assert_equal 0, integration.error_count
  end

  test "webhook_endpoint_url should generate correct URL" do
    integration = EmailIntegration.create!(
      brand: @brand,
      platform: "mailchimp",
      access_token: "test_token"
    )

    url = integration.webhook_endpoint_url
    assert_includes url, "/webhooks/email/mailchimp/#{integration.id}"
  end

  test "generate_webhook_secret! should create secure secret" do
    integration = EmailIntegration.create!(
      brand: @brand,
      platform: "sendgrid",
      access_token: "test_token"
    )

    assert_nil integration.webhook_secret

    integration.generate_webhook_secret!
    assert_not_nil integration.webhook_secret
    assert_equal 64, integration.webhook_secret.length # 32 bytes = 64 hex chars
  end

  test "verify_webhook_signature should validate different platform signatures" do
    integration = EmailIntegration.new(
      platform: "mailchimp",
      webhook_secret: "test_secret"
    )

    payload = '{"type":"subscribe","data":{"email":"test@example.com"}}'
    
    # Mock the verification methods to test the routing
    integration.expects(:verify_mailchimp_webhook).with(payload, "signature").returns(true)
    
    assert integration.verify_webhook_signature(payload, "signature")
  end

  test "scopes should filter integrations correctly" do
    active_integration = EmailIntegration.create!(
      brand: @brand,
      platform: "mailchimp",
      status: "active",
      access_token: "token1"
    )

    expired_integration = EmailIntegration.create!(
      brand: @brand,
      platform: "sendgrid", 
      status: "expired",
      access_token: "token2"
    )

    old_sync = EmailIntegration.create!(
      brand: @brand,
      platform: "klaviyo",
      status: "active",
      access_token: "token3",
      last_sync_at: 2.hours.ago
    )

    assert_includes EmailIntegration.active, active_integration
    assert_not_includes EmailIntegration.active, expired_integration

    assert_includes EmailIntegration.expired, expired_integration
    assert_not_includes EmailIntegration.expired, active_integration

    assert_includes EmailIntegration.for_platform("mailchimp"), active_integration
    assert_not_includes EmailIntegration.for_platform("mailchimp"), expired_integration

    assert_includes EmailIntegration.needs_sync, old_sync
    # Active integration without old sync should not need sync
    active_integration.update!(last_sync_at: 1.minute.ago)
    assert_not_includes EmailIntegration.needs_sync, active_integration
  end
end