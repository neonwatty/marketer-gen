# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class Analytics::GoogleAdsServiceTest < ActiveSupport::TestCase

  def setup
    @user = users(:one)
    @customer_id = "1234567890"
    @service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: @customer_id)
    
    # Mock OAuth service
    @mock_oauth_service = Minitest::Mock.new
    @mock_oauth_service.expect :access_token, "valid_access_token"
    
    @service.instance_variable_set(:@oauth_service, @mock_oauth_service)
  end

  test "should initialize with correct parameters" do
    assert_equal @user.id, @service.instance_variable_get(:@user_id)
    assert_equal @customer_id, @service.instance_variable_get(:@customer_id)
  end

  test "should validate date range correctly" do
    start_date = "2025-01-01"
    end_date = "2025-01-31"
    
    # Valid date range should not raise error
    assert_nothing_raised do
      @service.send(:validate_date_range!, start_date, end_date)
    end
    
    # Invalid date range should raise error
    assert_raises ArgumentError do
      @service.send(:validate_date_range!, "2025-01-31", "2025-01-01")
    end
    
    # Date range too long should raise error
    assert_raises ArgumentError do
      @service.send(:validate_date_range!, "2025-01-01", "2025-04-01")
    end
    
    # Future end date should raise error
    assert_raises ArgumentError do
      @service.send(:validate_date_range!, "2025-01-01", "2026-01-01")
    end
    
    # Invalid date format should raise error
    assert_raises ArgumentError do
      @service.send(:validate_date_range!, "invalid-date", "2025-01-31")
    end
  end

  test "should validate metrics correctly" do
    valid_metrics = %w[impressions clicks cost]
    invalid_metrics = %w[impressions invalid_metric]
    
    # Valid metrics should not raise error
    assert_nothing_raised do
      @service.send(:validate_metrics!, valid_metrics)
    end
    
    # Invalid metrics should raise error
    assert_raises ArgumentError do
      @service.send(:validate_metrics!, invalid_metrics)
    end
  end

  test "should get accessible accounts" do
    # Mock Google Ads client and response
    mock_client = Minitest::Mock.new
    mock_service = Minitest::Mock.new
    mock_response = create_mock_accounts_response
    
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, mock_response, [Object]
    
    @service.instance_variable_set(:@client, mock_client)
    
    Rails.cache.stub :write, true do
      result = @service.accessible_accounts
      
      assert result.is_a?(Array)
      assert_equal 2, result.count
      assert_equal "1234567890", result.first[:id]
      assert_equal "Test Account", result.first[:name]
    end
    
    mock_client.verify
    mock_service.verify
  end

  test "should get campaign performance data" do
    # Mock Google Ads client and response
    mock_client = Minitest::Mock.new
    mock_service = Minitest::Mock.new
    mock_response = create_mock_campaign_response
    
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, mock_response, [Object]
    
    @service.instance_variable_set(:@client, mock_client)
    
    result = @service.campaign_performance(
      start_date: "2025-01-01",
      end_date: "2025-01-31",
      metrics: %w[impressions clicks cost]
    )
    
    assert result.is_a?(Hash)
    assert_equal @customer_id, result[:customer_id]
    assert result[:campaigns].is_a?(Array)
    assert_equal 2, result[:campaigns].count
    
    campaign = result[:campaigns].first
    assert_equal "12345", campaign[:id]
    assert_equal "Test Campaign 1", campaign[:name]
    assert campaign[:metrics].is_a?(Hash)
    assert_equal 1000, campaign[:metrics]["impressions"]
    
    mock_client.verify
    mock_service.verify
  end

  test "should get ad group performance data" do
    mock_client = Minitest::Mock.new
    mock_service = Minitest::Mock.new
    mock_response = create_mock_ad_group_response
    
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, mock_response, [Object]
    
    @service.instance_variable_set(:@client, mock_client)
    
    result = @service.ad_group_performance(
      start_date: "2025-01-01",
      end_date: "2025-01-31"
    )
    
    assert result.is_a?(Hash)
    assert result[:ad_groups].is_a?(Array)
    
    ad_group = result[:ad_groups].first
    assert_equal "67890", ad_group[:id]
    assert_equal "Test Ad Group", ad_group[:name]
    assert ad_group[:campaign].is_a?(Hash)
    assert ad_group[:metrics].is_a?(Hash)
    
    mock_client.verify
    mock_service.verify
  end

  test "should get conversion data with attribution" do
    mock_client = Minitest::Mock.new
    mock_service = Minitest::Mock.new
    mock_response = create_mock_conversion_response
    
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, mock_response, [Object]
    
    @service.instance_variable_set(:@client, mock_client)
    
    result = @service.conversion_data(
      start_date: "2025-01-01",
      end_date: "2025-01-31"
    )
    
    assert result.is_a?(Hash)
    assert result[:conversions].is_a?(Array)
    assert_equal "last_click", result[:attribution_model]
    
    conversion = result[:conversions].first
    assert conversion[:campaign].is_a?(Hash)
    assert conversion[:conversion_action].is_a?(Hash)
    assert conversion[:conversions].is_a?(Numeric)
    
    mock_client.verify
    mock_service.verify
  end

  test "should monitor budget utilization" do
    mock_client = Minitest::Mock.new
    mock_service = Minitest::Mock.new
    mock_response = create_mock_budget_response
    
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, mock_response, [Object]
    
    @service.instance_variable_set(:@client, mock_client)
    
    result = @service.budget_monitoring(
      start_date: "2025-01-01",
      end_date: "2025-01-31"
    )
    
    assert result.is_a?(Hash)
    assert result[:budgets].is_a?(Array)
    
    budget = result[:budgets].first
    assert budget[:campaign].is_a?(Hash)
    assert budget[:budget].is_a?(Hash)
    assert budget[:performance].is_a?(Hash)
    assert budget[:performance][:budget_utilization_percent].is_a?(Numeric)
    
    mock_client.verify
    mock_service.verify
  end

  test "should get keyword performance" do
    mock_client = Minitest::Mock.new
    mock_service = Minitest::Mock.new
    mock_response = create_mock_keyword_response
    
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, mock_response, [Object]
    
    @service.instance_variable_set(:@client, mock_client)
    
    result = @service.keyword_performance(
      start_date: "2025-01-01",
      end_date: "2025-01-31"
    )
    
    assert result.is_a?(Hash)
    assert result[:keywords].is_a?(Array)
    
    keyword = result[:keywords].first
    assert keyword[:campaign].is_a?(Hash)
    assert keyword[:ad_group].is_a?(Hash)
    assert keyword[:keyword].is_a?(Hash)
    assert keyword[:metrics].is_a?(Hash)
    
    mock_client.verify
    mock_service.verify
  end

  test "should get audience insights" do
    mock_client = Minitest::Mock.new
    mock_service = Minitest::Mock.new
    
    # Mock multiple calls for different data types
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, create_mock_demographic_response, [Object]
    
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, create_mock_geographic_response, [Object]
    
    mock_client.expect :service, mock_service
    mock_service.expect :google_ads, mock_service
    mock_service.expect :search, create_mock_device_response, [Object]
    
    @service.instance_variable_set(:@client, mock_client)
    
    result = @service.audience_insights(
      start_date: "2025-01-01",
      end_date: "2025-01-31"
    )
    
    assert result.is_a?(Hash)
    assert result[:demographics].is_a?(Hash)
    assert result[:geography].is_a?(Array)
    assert result[:devices].is_a?(Hash)
    
    mock_client.verify
    mock_service.verify
  end

  test "should handle Google Ads API errors gracefully" do
    # Test authentication error
    auth_error = Google::Ads::GoogleAds::Errors::GoogleAdsError.new("Auth failed")
    failure = double("failure", errors: [double("error", error_code: double("code", name: "AUTHENTICATION_ERROR"))])
    auth_error.stub :failure, failure do
      @mock_oauth_service.expect :invalidate_stored_tokens, true
      
      error = assert_raises Analytics::GoogleAdsService::GoogleAdsApiError do
        @service.send(:handle_google_ads_error, auth_error, "Test context")
      end
      
      assert_equal :auth_error, error.error_type
    end
    
    # Test quota exceeded error
    quota_error = Google::Ads::GoogleAds::Errors::GoogleAdsError.new("Quota exceeded")
    quota_failure = double("failure", errors: [double("error", error_code: double("code", name: "QUOTA_EXCEEDED"))])
    quota_error.stub :failure, quota_failure do
      error = assert_raises Analytics::GoogleAdsService::GoogleAdsApiError do
        @service.send(:handle_google_ads_error, quota_error, "Test context")
      end
      
      assert_equal :rate_limit, error.error_type
      assert_equal 3600, error.retry_after
    end
    
    @mock_oauth_service.verify
  end

  test "should extract metrics data correctly" do
    mock_metrics = double("metrics", 
      impressions: 1000,
      clicks: 50,
      cost: 25_000_000, # Cost in micros
      ctr: 0.05,
      average_cpc: 500_000 # CPC in micros
    )
    
    metric_names = %w[impressions clicks cost ctr average_cpc]
    result = @service.send(:extract_metrics_data, mock_metrics, metric_names)
    
    assert_equal 1000, result["impressions"]
    assert_equal 50, result["clicks"]
    assert_equal 25.0, result["cost"] # Converted from micros
    assert_equal 0.05, result["ctr"]
    assert_equal 0.5, result["average_cpc"] # Converted from micros
  end

  private

  def create_mock_accounts_response
    mock_response = Minitest::Mock.new
    
    mock_customer1 = double("customer",
      id: 1234567890,
      descriptive_name: "Test Account",
      currency_code: "USD",
      time_zone: "America/New_York",
      status: "ENABLED",
      test_account: false,
      manager: false,
      auto_tagging_enabled: true
    )
    
    mock_customer2 = double("customer",
      id: 9876543210,
      descriptive_name: "Test Account 2",
      currency_code: "EUR",
      time_zone: "Europe/London",
      status: "ENABLED",
      test_account: false,
      manager: true,
      auto_tagging_enabled: true
    )
    
    mock_row1 = double("row", customer: mock_customer1)
    mock_row2 = double("row", customer: mock_customer2)
    
    [mock_row1, mock_row2]
  end

  def create_mock_campaign_response
    mock_metrics = double("metrics",
      impressions: 1000,
      clicks: 50,
      cost: 25_000_000
    )
    
    mock_campaign1 = double("campaign",
      id: 12345,
      name: "Test Campaign 1",
      status: "ENABLED",
      advertising_channel_type: "SEARCH",
      bidding_strategy_type: "MANUAL_CPC"
    )
    
    mock_campaign2 = double("campaign",
      id: 67890,
      name: "Test Campaign 2",
      status: "ENABLED",
      advertising_channel_type: "DISPLAY",
      bidding_strategy_type: "TARGET_CPA"
    )
    
    mock_row1 = double("row", campaign: mock_campaign1, metrics: mock_metrics)
    mock_row2 = double("row", campaign: mock_campaign2, metrics: mock_metrics)
    
    [mock_row1, mock_row2]
  end

  def create_mock_ad_group_response
    mock_metrics = double("metrics",
      impressions: 500,
      clicks: 25,
      cost: 12_500_000
    )
    
    mock_campaign = double("campaign", id: 12345, name: "Test Campaign")
    mock_ad_group = double("ad_group", id: 67890, name: "Test Ad Group", status: "ENABLED")
    
    mock_row = double("row", campaign: mock_campaign, ad_group: mock_ad_group, metrics: mock_metrics)
    
    [mock_row]
  end

  def create_mock_conversion_response
    mock_campaign = double("campaign", id: 12345, name: "Test Campaign")
    mock_conversion_action = double("conversion_action",
      id: 98765,
      name: "Purchase",
      category: "PURCHASE",
      type: "WEBPAGE"
    )
    mock_metrics = double("metrics",
      conversions: 10.0,
      conversion_value: 1000.0,
      cost_per_conversion: 25.0,
      conversion_rate: 0.2,
      view_through_conversions: 5.0
    )
    
    mock_row = double("row",
      campaign: mock_campaign,
      conversion_action: mock_conversion_action,
      metrics: mock_metrics
    )
    
    [mock_row]
  end

  def create_mock_budget_response
    mock_campaign = double("campaign", id: 12345, name: "Test Campaign", status: "ENABLED")
    mock_budget = double("campaign_budget",
      id: 54321,
      name: "Test Budget",
      amount_micros: 100_000_000, # $100 in micros
      total_amount: nil,
      delivery_method: "STANDARD"
    )
    mock_metrics = double("metrics",
      cost: 75_000_000, # $75 in micros
      impressions: 1000,
      clicks: 50,
      average_cpc: 1_500_000 # $1.50 in micros
    )
    
    mock_row = double("row",
      campaign: mock_campaign,
      campaign_budget: mock_budget,
      metrics: mock_metrics
    )
    
    [mock_row]
  end

  def create_mock_keyword_response
    mock_campaign = double("campaign", id: 12345, name: "Test Campaign")
    mock_ad_group = double("ad_group", id: 67890, name: "Test Ad Group")
    mock_keyword = double("keyword", text: "test keyword", match_type: "EXACT")
    mock_quality_info = double("quality_info", quality_score: 8)
    mock_criterion = double("ad_group_criterion", keyword: mock_keyword, quality_info: mock_quality_info)
    mock_metrics = double("metrics",
      impressions: 500,
      clicks: 25,
      cost: 12_500_000,
      ctr: 0.05,
      average_cpc: 500_000,
      conversions: 2.0,
      conversion_rate: 0.08
    )
    
    mock_row = double("row",
      campaign: mock_campaign,
      ad_group: mock_ad_group,
      ad_group_criterion: mock_criterion,
      metrics: mock_metrics
    )
    
    [mock_row]
  end

  def create_mock_demographic_response
    mock_segments = double("segments", age_range: "25_34", gender: "MALE")
    mock_metrics = double("metrics", impressions: 500, clicks: 25, cost: 12_500_000, conversions: 2.0)
    
    mock_row = double("row", segments: mock_segments, metrics: mock_metrics)
    
    [mock_row]
  end

  def create_mock_geographic_response
    mock_segments = double("segments", geo_target_region: "United States")
    mock_metrics = double("metrics", impressions: 1000, clicks: 50, cost: 25_000_000, conversions: 5.0)
    
    mock_row = double("row", segments: mock_segments, metrics: mock_metrics)
    
    [mock_row]
  end

  def create_mock_device_response
    mock_segments = double("segments", device: "MOBILE")
    mock_metrics = double("metrics", impressions: 750, clicks: 40, cost: 20_000_000, conversions: 4.0)
    
    mock_row = double("row", segments: mock_segments, metrics: mock_metrics)
    
    [mock_row]
  end

  def double(name, attributes = {})
    mock = Minitest::Mock.new
    attributes.each do |key, value|
      mock.expect key, value, []
    end
    mock
  end
end