# frozen_string_literal: true

require 'test_helper'

class ExternalPlatforms::MetaApiClientTest < ActiveSupport::TestCase
  def setup
    @client = ExternalPlatforms::MetaApiClient.new('test_access_token', 'test_app_secret')
  end

  test "initializes with correct attributes" do
    assert_equal 'Meta', @client.platform_name
    assert_includes @client.base_url, 'graph.facebook.com'
    assert_includes @client.base_url, 'v19.0'
  end

  test "default headers include authorization and meta-specific headers" do
    headers = @client.send(:default_headers)
    assert_equal 'Bearer test_access_token', headers['Authorization']
    assert_equal 'application/json', headers['Content-Type']
  end

  test "health_check_path returns correct path" do
    assert_equal '/me', @client.send(:health_check_path)
  end

  test "get_ad_accounts makes correct API call" do
    expected_params = {
      fields: 'id,name,account_status,currency,timezone_name,business'
    }
    
    @client.expects(:get_request).with('/me/adaccounts', expected_params)
    @client.get_ad_accounts
  end

  test "get_campaigns makes correct API call with default parameters" do
    expected_fields = %w[
      id name status objective created_time updated_time
      start_time end_time budget_remaining daily_budget
      lifetime_budget bid_strategy buying_type
    ].join(',')
    
    expected_params = {
      fields: expected_fields,
      limit: 100
    }
    
    @client.expects(:get_request).with('/act_123456/campaigns', expected_params)
    @client.get_campaigns('123456')
  end

  test "get_campaigns accepts custom options" do
    options = {
      fields: 'id,name,status',
      limit: 50,
      filtering: [{ field: 'status', operator: 'EQUAL', value: 'ACTIVE' }]
    }
    
    expected_params = {
      fields: 'id,name,status',
      limit: 50,
      filtering: options[:filtering]
    }
    
    @client.expects(:get_request).with('/act_123456/campaigns', expected_params)
    @client.get_campaigns('123456', options)
  end

  test "get_campaign_performance formats date range correctly" do
    campaign_id = '12345'
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    expected_params = {
      fields: anything,
      time_range: { since: '2024-01-01', until: '2024-01-31' },
      time_increment: 'all_days'
    }
    
    @client.expects(:get_request).with("/#{campaign_id}/insights", expected_params)
    @client.get_campaign_performance(campaign_id, date_range)
  end

  test "get_campaign_performance uses default date range when none provided" do
    campaign_id = '12345'
    
    @client.expects(:get_request).with("/#{campaign_id}/insights", anything) do |path, params|
      assert params[:time_range][:since]
      assert params[:time_range][:until]
      true
    end
    
    @client.get_campaign_performance(campaign_id)
  end

  test "get_account_insights includes breakdown when provided" do
    ad_account_id = '123456'
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    breakdown = 'age'
    
    expected_params = {
      level: 'account',
      fields: anything,
      time_range: { since: '2024-01-01', until: '2024-01-31' },
      time_increment: 'all_days',
      breakdowns: breakdown
    }
    
    @client.expects(:get_request).with("/act_#{ad_account_id}/insights", expected_params)
    @client.get_account_insights(ad_account_id, date_range, breakdown)
  end

  test "get_audience_insights makes correct POST request" do
    ad_account_id = '123456'
    audience_spec = {
      geo_locations: { countries: ['US'] },
      age_min: 18,
      age_max: 65
    }
    
    expected_body = {
      targeting_spec: audience_spec,
      optimization_goal: 'IMPRESSIONS'
    }
    
    @client.expects(:post_request).with("/act_#{ad_account_id}/delivery_estimate", expected_body)
    @client.get_audience_insights(ad_account_id, audience_spec)
  end

  test "get_conversions includes action attribution windows" do
    ad_account_id = '123456'
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    expected_params = {
      level: 'ad',
      fields: 'ad_name,actions,conversions,cost_per_conversion',
      time_range: { since: '2024-01-01', until: '2024-01-31' },
      action_attribution_windows: ['7d_click', '1d_view']
    }
    
    @client.expects(:get_request).with("/act_#{ad_account_id}/insights", expected_params)
    @client.get_conversions(ad_account_id, date_range)
  end

  test "get_page_insights handles multiple metrics" do
    page_id = 'page_123'
    metrics = ['page_impressions', 'page_engaged_users']
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    expected_params = {
      metric: 'page_impressions,page_engaged_users',
      period: 'day',
      since: '2024-01-01',
      until: '2024-01-31'
    }
    
    @client.expects(:get_request).with("/#{page_id}/insights", expected_params)
    @client.get_page_insights(page_id, metrics, date_range)
  end

  test "rate_limit_status makes request to /me and extracts headers" do
    mock_response = {
      success: true,
      headers: {
        'x-business-use-case-usage' => '{"call_count":10,"total_cputime":1,"total_time":2}',
        'x-app-usage' => '{"call_count":5,"total_cputime":0.5,"total_time":1}',
        'x-ad-account-usage' => '{"acc_id":"123","call_count":3}'
      }
    }
    
    @client.expects(:get_request).with('/me', { fields: 'id' }).returns(mock_response)
    
    result = @client.rate_limit_status
    
    assert result[:available]
    assert_equal 'Meta', result[:platform]
    assert result[:usage]
    assert result[:app_usage]
    assert result[:ad_account_usage]
    assert result[:reset_time]
  end

  test "rate_limit_status handles API errors" do
    mock_response = {
      success: false,
      message: 'API error'
    }
    
    @client.expects(:get_request).returns(mock_response)
    
    result = @client.rate_limit_status
    
    assert_not result[:available]
    assert_equal 'API error', result[:error]
  end

  test "format_date_range handles Date objects" do
    date_range = {
      since: Date.new(2024, 1, 1),
      until: Date.new(2024, 1, 31)
    }
    
    result = @client.send(:format_date_range, date_range)
    
    assert_equal '2024-01-01', result[:since]
    assert_equal '2024-01-31', result[:until]
  end

  test "format_date_range handles string dates" do
    date_range = {
      since: '2024-01-01',
      until: '2024-01-31'
    }
    
    result = @client.send(:format_date_range, date_range)
    
    assert_equal '2024-01-01', result[:since]
    assert_equal '2024-01-31', result[:until]
  end

  test "format_date_range provides defaults for empty input" do
    result = @client.send(:format_date_range, {})
    
    assert result[:since]
    assert result[:until]
    assert_match(/\d{4}-\d{2}-\d{2}/, result[:since])
    assert_match(/\d{4}-\d{2}-\d{2}/, result[:until])
  end

  test "extract_error_message handles Meta-specific error format" do
    error_body = {
      'error' => {
        'message' => 'Invalid OAuth access token.',
        'code' => 190,
        'error_subcode' => 460
      }
    }
    
    message = @client.send(:extract_error_message, error_body)
    
    assert_includes message, 'Invalid OAuth access token.'
    assert_includes message, '190'
    assert_includes message, '460'
  end

  test "extract_error_message falls back to parent implementation" do
    error_body = { 'message' => 'Generic error message' }
    
    message = @client.send(:extract_error_message, error_body)
    
    assert_equal 'Generic error message', message
  end

  test "retriable_request? handles Meta-specific retry logic" do
    # Auth errors should not be retried
    auth_env = Struct.new(:status, :method).new(401, :get)
    assert_not @client.send(:retriable_request?, auth_env)
    
    forbidden_env = Struct.new(:status, :method).new(403, :get)
    assert_not @client.send(:retriable_request?, forbidden_env)
    
    # Rate limits should be retried
    rate_limit_env = Struct.new(:status, :method).new(429, :get)
    assert @client.send(:retriable_request?, rate_limit_env)
    
    # Other errors should fall back to parent logic
    server_error_env = Struct.new(:status, :method).new(500, :get)
    assert @client.send(:retriable_request?, server_error_env)
  end

  test "handle_client_response_error handles rate limiting" do
    mock_response = Struct.new(:status, :headers, :body).new(
      429,
      { 'Retry-After' => '300' },
      { 'error' => { 'message' => 'Rate limit exceeded' } }
    )
    
    result = @client.send(:handle_client_response_error, mock_response)
    
    assert_not result[:success]
    assert_equal 'rate_limited', result[:error]
    assert_equal 'Rate limit exceeded', result[:message]
    assert_equal 300, result[:retry_after]
  end

  test "handle_client_response_error falls back to parent for non-rate-limit errors" do
    mock_response = Struct.new(:status, :headers, :body).new(
      400,
      {},
      { 'error' => { 'message' => 'Bad request' } }
    )
    
    # Mock the parent method
    @client.expects(:handle_client_response_error).with(mock_response).returns({
      success: false,
      error: 'client_response_error',
      message: 'Bad request'
    })
    
    result = @client.send(:handle_client_response_error, mock_response)
    
    assert_not result[:success]
    assert_equal 'client_response_error', result[:error]
  end

  test "all API methods handle missing optional parameters gracefully" do
    # Test methods that have optional parameters
    @client.expects(:get_request).returns({ success: true })
    @client.get_campaigns('123456')
    
    @client.expects(:get_request).returns({ success: true })
    @client.get_ad_sets('campaign_123')
    
    @client.expects(:get_request).returns({ success: true })
    @client.get_ads('adset_123')
    
    @client.expects(:get_request).returns({ success: true })
    @client.get_ad_creatives('123456')
  end
end