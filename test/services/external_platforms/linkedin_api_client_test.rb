# frozen_string_literal: true

require 'test_helper'

class ExternalPlatforms::LinkedinApiClientTest < ActiveSupport::TestCase
  def setup
    @client = ExternalPlatforms::LinkedinApiClient.new('test_access_token')
  end

  test "initializes with correct attributes" do
    assert_equal 'LinkedIn', @client.platform_name
    assert_includes @client.base_url, 'api.linkedin.com'
    assert_includes @client.base_url, 'v2'
  end

  test "default headers include LinkedIn specific headers" do
    headers = @client.send(:default_headers)
    assert_equal 'Bearer test_access_token', headers['Authorization']
    assert_equal '202401', headers['LinkedIn-Version']
    assert_equal '2.0.0', headers['X-Restli-Protocol-Version']
    assert_equal 'application/json', headers['Content-Type']
  end

  test "health_check_path returns correct path" do
    assert_equal '/people/~', @client.send(:health_check_path)
  end

  test "get_profile makes correct API call" do
    expected_params = {
      projection: '(id,firstName,lastName,profilePicture(displayImage~:playableStreams))'
    }
    
    @client.expects(:get_request).with('/people/~', expected_params)
    @client.get_profile
  end

  test "get_organizations makes correct API call with role filter" do
    expected_params = {
      q: 'roleAssignee',
      role: 'ADMINISTRATOR',
      projection: '(elements*(organization~(id,name,localizedName,description,logoV2(original~:playableStreams)),organizationalTarget~(id,name),role))'
    }
    
    @client.expects(:get_request).with('/organizationAcls', expected_params)
    @client.get_organizations('ADMINISTRATOR')
  end

  test "get_organizations makes correct API call without role filter" do
    expected_params = {
      q: 'roleAssignee',
      projection: '(elements*(organization~(id,name,localizedName,description,logoV2(original~:playableStreams)),organizationalTarget~(id,name),role))'
    }
    
    @client.expects(:get_request).with('/organizationAcls', expected_params)
    @client.get_organizations
  end

  test "get_organization_info includes comprehensive projection" do
    organization_id = '12345'
    expected_params = {
      projection: '(id,name,localizedName,description,logoV2,website,industries,specialties,locations)'
    }
    
    @client.expects(:get_request).with("/organizations/#{organization_id}", expected_params)
    @client.get_organization_info(organization_id)
  end

  test "get_ad_accounts searches with organization filter" do
    organization_id = '12345'
    expected_params = {
      q: 'search',
      search: {
        status: { values: ['ACTIVE', 'DRAFT'] },
        reference: "urn:li:organization:#{organization_id}"
      }
    }
    
    @client.expects(:get_request).with('/adAccountsV2', expected_params)
    @client.get_ad_accounts(organization_id)
  end

  test "get_ad_accounts searches without organization filter" do
    expected_params = {
      q: 'search',
      search: {
        status: { values: ['ACTIVE', 'DRAFT'] }
      }
    }
    
    @client.expects(:get_request).with('/adAccountsV2', expected_params)
    @client.get_ad_accounts
  end

  test "get_campaigns includes comprehensive search parameters" do
    ad_account_id = '67890'
    
    expected_params = {
      q: 'search',
      search: {
        account: { values: ["urn:li:sponsoredAccount:#{ad_account_id}"] },
        status: { values: ['ACTIVE', 'PAUSED', 'DRAFT'] }
      },
      projection: anything,
      count: 50
    }
    
    @client.expects(:get_request).with('/adCampaignsV2', expected_params)
    @client.get_campaigns(ad_account_id)
  end

  test "get_campaigns accepts custom options" do
    ad_account_id = '67890'
    options = { status: ['ACTIVE'], limit: 100 }
    
    expected_params = {
      q: 'search',
      search: {
        account: { values: ["urn:li:sponsoredAccount:#{ad_account_id}"] },
        status: { values: ['ACTIVE'] }
      },
      projection: anything,
      count: 100
    }
    
    @client.expects(:get_request).with('/adCampaignsV2', expected_params)
    @client.get_campaigns(ad_account_id, options)
  end

  test "get_campaign_groups searches by account" do
    ad_account_id = '67890'
    
    expected_params = {
      q: 'search',
      search: {
        account: { values: ["urn:li:sponsoredAccount:#{ad_account_id}"] },
        status: { values: ['ACTIVE', 'PAUSED'] }
      },
      projection: anything,
      count: 50
    }
    
    @client.expects(:get_request).with('/adCampaignGroupsV2', expected_params)
    @client.get_campaign_groups(ad_account_id)
  end

  test "get_creatives searches by campaign" do
    campaign_id = '11111'
    
    expected_params = {
      q: 'search',
      search: {
        campaigns: { values: ["urn:li:sponsoredCampaign:#{campaign_id}"] },
        status: { values: ['ACTIVE', 'PAUSED'] }
      },
      projection: anything,
      count: 50
    }
    
    @client.expects(:get_request).with('/adCreativesV2', expected_params)
    @client.get_creatives(campaign_id)
  end

  test "get_campaign_analytics includes correct parameters" do
    campaign_id = '11111'
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    expected_params = {
      q: 'analytics',
      pivot: 'CAMPAIGN',
      dateRange: anything,
      campaigns: ["urn:li:sponsoredCampaign:#{campaign_id}"],
      fields: anything
    }
    
    @client.expects(:get_request).with('/adAnalyticsV2', expected_params) do |path, params|
      assert_includes params[:fields], 'impressions'
      assert_includes params[:fields], 'clicks'
      assert_includes params[:fields], 'costInUsd'
      true
    end
    
    @client.get_campaign_analytics(campaign_id, date_range)
  end

  test "get_account_analytics uses account pivot" do
    ad_account_id = '67890'
    
    expected_params = {
      q: 'analytics',
      pivot: 'ACCOUNT',
      dateRange: anything,
      accounts: ["urn:li:sponsoredAccount:#{ad_account_id}"],
      fields: anything
    }
    
    @client.expects(:get_request).with('/adAnalyticsV2', expected_params)
    @client.get_account_analytics(ad_account_id)
  end

  test "get_demographic_analytics uses member company size pivot" do
    campaign_id = '11111'
    
    expected_params = {
      q: 'analytics',
      pivot: 'MEMBER_COMPANY_SIZE',
      dateRange: anything,
      campaigns: ["urn:li:sponsoredCampaign:#{campaign_id}"],
      fields: 'dateRange,pivot,pivotValue,impressions,clicks,costInUsd,externalWebsiteConversions'
    }
    
    @client.expects(:get_request).with('/adAnalyticsV2', expected_params)
    @client.get_demographic_analytics(campaign_id)
  end

  test "get_targeting_facets includes locale parameter" do
    facet_type = 'INDUSTRIES'
    locale = 'en_US'
    
    expected_params = {
      facetType: facet_type,
      locale: locale
    }
    
    @client.expects(:get_request).with('/targetingFacetsV2', expected_params)
    @client.get_targeting_facets(facet_type, locale)
  end

  test "get_audience_counts makes POST request" do
    targeting_criteria = {
      include: {
        and: [
          { or: { 'urn:li:adTargetingFacet:industries' => [1, 2, 3] } }
        ]
      }
    }
    
    expected_body = {
      targetingCriteria: targeting_criteria
    }
    
    @client.expects(:post_request).with('/audienceCountsV2', expected_body)
    @client.get_audience_counts(targeting_criteria)
  end

  test "get_conversions uses conversion pivot" do
    ad_account_id = '67890'
    
    expected_params = {
      q: 'analytics',
      pivot: 'CONVERSION',
      dateRange: anything,
      accounts: ["urn:li:sponsoredAccount:#{ad_account_id}"],
      fields: 'dateRange,pivot,pivotValue,externalWebsiteConversions,oneClickLeads,follows'
    }
    
    @client.expects(:get_request).with('/adAnalyticsV2', expected_params)
    @client.get_conversions(ad_account_id)
  end

  test "get_conversion_tracking includes projection" do
    conversion_id = '22222'
    expected_params = {
      projection: '(id,name,account,rules,attribution)'
    }
    
    @client.expects(:get_request).with("/conversions/#{conversion_id}", expected_params)
    @client.get_conversion_tracking(conversion_id)
  end

  test "get_organization_posts searches by author" do
    organization_id = '12345'
    options = { limit: 25, start: 10 }
    
    expected_params = {
      q: 'author',
      author: "urn:li:organization:#{organization_id}",
      count: 25,
      start: 10,
      projection: anything
    }
    
    @client.expects(:get_request).with('/shares', expected_params)
    @client.get_organization_posts(organization_id, options)
  end

  test "get_post_analytics includes comprehensive projection" do
    post_id = 'post_12345'
    expected_params = {
      projection: '(totalShareStatistics,clickCount,commentCount,engagement,impressionCount,likeCount,shareCount)'
    }
    
    @client.expects(:get_request).with("/organizationalEntityShareStatistics/#{post_id}", expected_params)
    @client.get_post_analytics(post_id)
  end

  test "get_follower_statistics includes time intervals when date range provided" do
    organization_id = '12345'
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    @client.expects(:get_request).with('/networkSizes', anything) do |path, params|
      assert_equal 'organizationalEntity', params[:q]
      assert_equal "urn:li:organization:#{organization_id}", params[:organizationalEntity]
      assert params[:timeIntervals]
      true
    end
    
    @client.get_follower_statistics(organization_id, date_range)
  end

  test "get_lead_gen_forms searches by account" do
    ad_account_id = '67890'
    
    expected_params = {
      q: 'account',
      account: "urn:li:sponsoredAccount:#{ad_account_id}",
      projection: '(elements*(id,name,locale,status,content))'
    }
    
    @client.expects(:get_request).with('/leadGenForms', expected_params)
    @client.get_lead_gen_forms(ad_account_id)
  end

  test "get_form_responses searches by form" do
    form_id = '33333'
    options = { limit: 50, start: 20 }
    
    expected_params = {
      q: 'leadGenForm',
      leadGenForm: "urn:li:leadGenForm:#{form_id}",
      projection: '(elements*(id,submittedAt,formResponse))',
      count: 50,
      start: 20
    }
    
    @client.expects(:get_request).with('/leadFormResponses', expected_params)
    @client.get_form_responses(form_id, options)
  end

  test "format_date_range handles Date objects" do
    date_range = {
      since: Date.new(2024, 1, 1),
      until: Date.new(2024, 1, 31)
    }
    
    result = @client.send(:format_date_range, date_range)
    
    assert_equal 1, result[:start][:day]
    assert_equal 1, result[:start][:month]
    assert_equal 2024, result[:start][:year]
    assert_equal 31, result[:end][:day]
    assert_equal 1, result[:end][:month]
    assert_equal 2024, result[:end][:year]
  end

  test "format_date_range handles string dates" do
    date_range = {
      since: '2024-01-01',
      until: '2024-01-31'
    }
    
    result = @client.send(:format_date_range, date_range)
    
    assert_equal 1, result[:start][:day]
    assert_equal 1, result[:start][:month]
    assert_equal 2024, result[:start][:year]
  end

  test "format_date_range provides defaults for empty input" do
    result = @client.send(:format_date_range, {})
    
    assert result[:start][:day]
    assert result[:start][:month]
    assert result[:start][:year]
    assert result[:end][:day]
    assert result[:end][:month]
    assert result[:end][:year]
  end

  test "format_time_intervals converts to milliseconds" do
    date_range = {
      since: Date.new(2024, 1, 1),
      until: Date.new(2024, 1, 31)
    }
    
    result = @client.send(:format_time_intervals, date_range)
    
    assert result[:timeIntervals][:start]
    assert result[:timeIntervals][:end]
    # Verify it's in milliseconds (should be a large number)
    assert result[:timeIntervals][:start] > 1000000000000
    assert result[:timeIntervals][:end] > 1000000000000
  end

  test "extract_error_message handles LinkedIn message format" do
    error_body = {
      'message' => 'Access token is invalid',
      'status' => 401,
      'serviceErrorCode' => 65600
    }
    
    message = @client.send(:extract_error_message, error_body)
    
    assert_includes message, 'Access token is invalid'
    assert_includes message, '(Status: 401)'
    assert_includes message, '(Service Error Code: 65600)'
  end

  test "extract_error_message handles errorDetails format" do
    error_body = {
      'errorDetails' => [
        { 'message' => 'Invalid request parameter' }
      ]
    }
    
    message = @client.send(:extract_error_message, error_body)
    
    assert_equal 'Invalid request parameter', message
  end

  test "extract_error_message falls back to parent implementation" do
    error_body = { 'error_description' => 'Generic error' }
    
    message = @client.send(:extract_error_message, error_body)
    
    assert_equal 'Generic error', message
  end

  test "retriable_request? handles LinkedIn specific retry logic" do
    # Auth errors should not be retried
    auth_env = Struct.new(:status, :method, :body).new(401, :get, {})
    assert_not @client.send(:retriable_request?, auth_env)
    
    forbidden_env = Struct.new(:status, :method, :body).new(403, :get, {})
    assert_not @client.send(:retriable_request?, forbidden_env)
    
    # Rate limits should be retried
    rate_limit_env = Struct.new(:status, :method, :body).new(429, :get, {})
    assert @client.send(:retriable_request?, rate_limit_env)
    
    # LinkedIn status in body should be retried
    linkedin_throttle_env = Struct.new(:status, :method, :body).new(
      400,
      :get,
      { 'status' => 429 }
    )
    assert @client.send(:retriable_request?, linkedin_throttle_env)
  end

  test "handle_client_response_error handles LinkedIn rate limiting" do
    # Status 429 error
    mock_response = Struct.new(:status, :headers, :body).new(
      429,
      { 'Retry-After' => '300' },
      { 'message' => 'Rate limit exceeded' }
    )
    
    result = @client.send(:handle_client_response_error, mock_response)
    
    assert_not result[:success]
    assert_equal 'rate_limited', result[:error]
    assert_equal 'LinkedIn API rate limit exceeded', result[:message]
    assert_equal 300, result[:retry_after]
    
    # LinkedIn status in body
    mock_response_linkedin = Struct.new(:status, :headers, :body).new(
      400,
      {},
      { 'status' => 429, 'message' => 'Throttled' }
    )
    
    result = @client.send(:handle_client_response_error, mock_response_linkedin)
    
    assert_not result[:success]
    assert_equal 'rate_limited', result[:error]
  end

  test "all projection methods return correct field strings" do
    assert_includes @client.send(:campaign_projection), 'id'
    assert_includes @client.send(:campaign_projection), 'targetingCriteria'
    
    assert_includes @client.send(:campaign_group_projection), 'totalBudget'
    assert_includes @client.send(:campaign_group_projection), 'runSchedule'
    
    assert_includes @client.send(:creative_projection), 'content'
    assert_includes @client.send(:creative_projection), 'intendedStatus'
    
    assert_includes @client.send(:post_projection), 'distribution'
    assert_includes @client.send(:post_projection), 'commentary'
  end

  test "analytics_fields includes all necessary metrics" do
    fields = @client.send(:analytics_fields)
    
    expected_fields = %w[
      impressions clicks shares follows costInUsd
      externalWebsiteConversions oneClickLeads totalEngagements
    ]
    
    expected_fields.each do |field|
      assert_includes fields, field
    end
  end
end