# frozen_string_literal: true

require 'test_helper'

class ExternalPlatforms::GoogleAdsApiClientTest < ActiveSupport::TestCase
  def setup
    @client = ExternalPlatforms::GoogleAdsApiClient.new(
      'test_access_token',
      'test_developer_token',
      '1234567890',
      'test_refresh_token'
    )
  end

  test "initializes with correct attributes" do
    assert_equal 'Google Ads', @client.platform_name
    assert_includes @client.base_url, 'googleads.googleapis.com'
    assert_includes @client.base_url, 'v16'
  end

  test "default headers include Google Ads specific headers" do
    headers = @client.send(:default_headers)
    assert_equal 'Bearer test_access_token', headers['Authorization']
    assert_equal 'test_developer_token', headers['developer-token']
    assert_equal '1234567890', headers['login-customer-id']
    assert_equal 'application/json', headers['Content-Type']
  end

  test "health_check_path returns correct path" do
    expected_path = "/customers/1234567890/googleAds:search"
    assert_equal expected_path, @client.send(:health_check_path)
  end

  test "get_customer_info makes correct search request" do
    customer_id = '1234567890'
    expected_query = "SELECT customer.id, customer.descriptive_name, customer.currency_code, customer.time_zone FROM customer WHERE customer.id = #{customer_id}"
    
    @client.expects(:search_request).with(customer_id, expected_query)
    @client.get_customer_info(customer_id)
  end

  test "get_customer_info uses default customer_id when none provided" do
    expected_query = "SELECT customer.id, customer.descriptive_name, customer.currency_code, customer.time_zone FROM customer WHERE customer.id = 1234567890"
    
    @client.expects(:search_request).with('1234567890', expected_query)
    @client.get_customer_info
  end

  test "get_accessible_customers makes correct API call" do
    @client.expects(:get_request).with('/customers:listAccessibleCustomers')
    @client.get_accessible_customers
  end

  test "get_campaigns builds correct GAQL query" do
    customer_id = '1234567890'
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, 'SELECT'
      assert_includes query, 'campaign.id'
      assert_includes query, 'campaign.name'
      assert_includes query, 'FROM campaign'
      assert_includes query, "campaign.status != 'REMOVED'"
      assert_includes query, 'ORDER BY campaign.name'
      true
    end
    
    @client.get_campaigns(customer_id)
  end

  test "get_campaigns accepts options" do
    customer_id = '1234567890'
    options = { include_removed: true, limit: 50 }
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_not_includes query, "campaign.status != 'REMOVED'"
      assert_includes query, 'LIMIT 50'
      true
    end
    
    @client.get_campaigns(customer_id, options)
  end

  test "get_campaign_performance includes date range in query" do
    customer_id = '1234567890'
    campaign_id = '98765'
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, "campaign.id = #{campaign_id}"
      assert_includes query, "segments.date BETWEEN '2024-01-01' AND '2024-01-31'"
      assert_includes query, 'ORDER BY segments.date DESC'
      true
    end
    
    @client.get_campaign_performance(customer_id, campaign_id, date_range)
  end

  test "get_ad_groups filters by campaign_id when provided" do
    customer_id = '1234567890'
    campaign_id = '98765'
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, 'FROM ad_group'
      assert_includes query, "campaign.id = #{campaign_id}"
      assert_includes query, "ad_group.status != 'REMOVED'"
      true
    end
    
    @client.get_ad_groups(customer_id, campaign_id)
  end

  test "get_keywords includes quality score and metrics" do
    customer_id = '1234567890'
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, 'FROM keyword_view'
      assert_includes query, 'ad_group_criterion.keyword.text'
      assert_includes query, 'ad_group_criterion.quality_info.quality_score'
      assert_includes query, 'metrics.impressions'
      assert_includes query, 'LIMIT 1000'
      true
    end
    
    @client.get_keywords(customer_id)
  end

  test "get_keywords filters by ad_group_id when provided" do
    customer_id = '1234567890'
    ad_group_id = '55555'
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, "ad_group.id = #{ad_group_id}"
      true
    end
    
    @client.get_keywords(customer_id, ad_group_id)
  end

  test "get_demographic_performance uses age_range_view" do
    customer_id = '1234567890'
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, 'FROM age_range_view'
      assert_includes query, 'segments.age_range'
      assert_includes query, 'segments.gender'
      assert_includes query, "segments.date BETWEEN '2024-01-01' AND '2024-01-31'"
      true
    end
    
    @client.get_demographic_performance(customer_id, date_range)
  end

  test "get_geographic_performance limits results" do
    customer_id = '1234567890'
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, 'FROM geographic_view'
      assert_includes query, 'segments.geo_target_region'
      assert_includes query, 'LIMIT 100'
      true
    end
    
    @client.get_geographic_performance(customer_id)
  end

  test "get_search_terms filters by status" do
    customer_id = '1234567890'
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, 'FROM search_term_view'
      assert_includes query, 'search_term_view.search_term'
      assert_includes query, "search_term_view.status != 'NONE'"
      true
    end
    
    @client.get_search_terms(customer_id)
  end

  test "get_conversions filters for conversions greater than zero" do
    customer_id = '1234567890'
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, 'segments.conversion_action_name'
      assert_includes query, 'metrics.conversions > 0'
      assert_includes query, 'ORDER BY metrics.conversions DESC'
      true
    end
    
    @client.get_conversions(customer_id)
  end

  test "get_account_budget excludes cancelled budgets" do
    customer_id = '1234567890'
    
    @client.expects(:search_request).with(customer_id, anything) do |customer_id, query|
      assert_includes query, 'FROM account_budget'
      assert_includes query, "account_budget.status != 'CANCELLED'"
      assert_includes query, 'account_budget.approved_spending_limit_micros'
      true
    end
    
    @client.get_account_budget(customer_id)
  end

  test "search_request makes correct POST request" do
    customer_id = '1234567890'
    query = 'SELECT campaign.id FROM campaign'
    
    expected_body = {
      query: query,
      validateOnly: false,
      returnTotalResultsCount: true
    }
    
    @client.expects(:post_request).with("/customers/#{customer_id}/googleAds:search", expected_body)
    @client.send(:search_request, customer_id, query)
  end

  test "format_date handles various date types" do
    # Date object
    date_obj = Date.new(2024, 1, 1)
    assert_equal '2024-01-01', @client.send(:format_date, date_obj)
    
    # Time object
    time_obj = Time.new(2024, 1, 1)
    assert_equal '2024-01-01', @client.send(:format_date, time_obj)
    
    # DateTime object
    datetime_obj = DateTime.new(2024, 1, 1)
    assert_equal '2024-01-01', @client.send(:format_date, datetime_obj)
    
    # String
    assert_equal '2024-01-01', @client.send(:format_date, '2024-01-01')
    
    # Other types default to current date
    result = @client.send(:format_date, 12345)
    assert_match(/\d{4}-\d{2}-\d{2}/, result)
  end

  test "extract_error_message handles Google Ads specific error format" do
    error_body = {
      'error' => {
        'message' => 'Request contains an invalid argument.',
        'code' => 3,
        'details' => [
          {
            'errors' => [
              { 'message' => 'Invalid customer ID format.' },
              { 'message' => 'Missing required field.' }
            ]
          }
        ]
      }
    }
    
    message = @client.send(:extract_error_message, error_body)
    
    assert_includes message, 'Request contains an invalid argument.'
    assert_includes message, '(Code: 3)'
    assert_includes message, 'Invalid customer ID format.'
    assert_includes message, 'Missing required field.'
  end

  test "extract_error_message handles simple error format" do
    error_body = {
      'error' => {
        'message' => 'Simple error message',
        'code' => 1
      }
    }
    
    message = @client.send(:extract_error_message, error_body)
    
    assert_includes message, 'Simple error message'
    assert_includes message, '(Code: 1)'
  end

  test "retriable_request? handles Google Ads specific retry logic" do
    # Auth errors should not be retried
    auth_env = Struct.new(:status, :method, :body).new(401, :get, {})
    assert_not @client.send(:retriable_request?, auth_env)
    
    # Rate limit status should be retried
    rate_limit_env = Struct.new(:status, :method, :body).new(429, :get, {})
    assert @client.send(:retriable_request?, rate_limit_env)
    
    # Specific Google Ads error codes should be retried
    quota_error_env = Struct.new(:status, :method, :body).new(
      400,
      :get,
      { 'error' => { 'code' => 'RATE_LIMIT_EXCEEDED' } }
    )
    assert @client.send(:retriable_request?, quota_error_env)
  end

  test "handle_client_response_error handles quota exceeded errors" do
    # Status 429 error
    mock_response = Struct.new(:status, :headers, :body).new(
      429,
      { 'Retry-After' => '120' },
      { 'error' => { 'message' => 'Quota exceeded' } }
    )
    
    result = @client.send(:handle_client_response_error, mock_response)
    
    assert_not result[:success]
    assert_equal 'quota_exceeded', result[:error]
    assert_equal 120, result[:retry_after]
    
    # Error code based quota exceeded
    mock_response_code = Struct.new(:status, :headers, :body).new(
      400,
      {},
      { 'error' => { 'code' => 'QUOTA_EXCEEDED' } }
    )
    
    result = @client.send(:handle_client_response_error, mock_response_code)
    
    assert_not result[:success]
    assert_equal 'quota_exceeded', result[:error]
  end

  test "handle_client_response_error falls back to parent for other errors" do
    mock_response = Struct.new(:status, :headers, :body).new(
      400,
      {},
      { 'error' => { 'message' => 'Bad request' } }
    )
    
    # Mock the parent method
    @client.expects(:handle_client_response_error).with(mock_response).returns({
      success: false,
      error: 'client_response_error'
    })
    
    result = @client.send(:handle_client_response_error, mock_response)
    
    assert_not result[:success]
    assert_equal 'client_response_error', result[:error]
  end

  test "all query methods handle date range options" do
    customer_id = '1234567890'
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    # Test methods that support date ranges
    methods_with_date_range = [
      [:get_campaign_performance, [customer_id, nil, date_range]],
      [:get_keywords, [customer_id, nil, { date_range: date_range }]],
      [:get_demographic_performance, [customer_id, date_range]],
      [:get_geographic_performance, [customer_id, date_range]],
      [:get_search_terms, [customer_id, date_range]],
      [:get_conversions, [customer_id, date_range]]
    ]
    
    methods_with_date_range.each do |method, args|
      @client.expects(:search_request).with(anything, anything) do |cid, query|
        assert_includes query, "segments.date BETWEEN '2024-01-01' AND '2024-01-31'"
        true
      end
      
      @client.send(method, *args)
    end
  end
end