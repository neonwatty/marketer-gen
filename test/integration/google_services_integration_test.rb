# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class GoogleServicesIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @user = users(:one)
    @brand = brands(:one)
    
    # Setup authentication
    post login_path, params: {
      email: @user.email,
      password: "password123"
    }
    
    # Disable actual HTTP requests
    WebMock.disable_net_connect!(allow_localhost: true)
    
    # Clear any existing jobs
    clear_enqueued_jobs
    clear_performed_jobs
  end

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  # =============================================================================
  # GOOGLE OAUTH INTEGRATION TESTS
  # =============================================================================

  test "google oauth flow complete integration" do
    oauth_service = Analytics::GoogleOauthService.new(@user)
    
    # Test authorization URL generation
    auth_url = oauth_service.authorization_url(scopes: ["analytics.readonly", "adwords"])
    
    assert_not_nil auth_url
    assert_includes auth_url, "accounts.google.com"
    assert_includes auth_url, "analytics.readonly"
    assert_includes auth_url, "adwords"
    
    # Mock OAuth token exchange
    stub_google_oauth_token_exchange
    
    result = oauth_service.exchange_code_for_token("test_auth_code")
    
    assert result.success?
    assert_not_nil result.data[:access_token]
    assert_not_nil result.data[:refresh_token]
  end

  test "google token refresh integration" do
    oauth_service = Analytics::GoogleOauthService.new(@user)
    
    # Mock token refresh
    stub_google_token_refresh_success
    
    result = oauth_service.refresh_access_token("refresh_token_123")
    
    assert result.success?
    assert_not_nil result.data[:access_token]
    assert result.data[:expires_in] > 0
  end

  test "google multi account support integration" do
    oauth_service = Analytics::GoogleOauthService.new(@user)
    
    # Mock multiple Google accounts
    stub_google_accounts_list
    
    accounts = oauth_service.list_accessible_accounts
    
    assert accounts.count >= 2
    assert accounts.first.key?("id")
    assert accounts.first.key?("name")
  end

  # =============================================================================
  # GOOGLE ANALYTICS INTEGRATION TESTS
  # =============================================================================

  test "google analytics basic integration" do
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock Google Analytics API
    stub_google_analytics_reporting_api
    
    result = service.fetch_analytics_data(
      start_date: 30.days.ago,
      end_date: Time.current,
      metrics: ["sessions", "pageviews", "users"],
      dimensions: ["date", "source"]
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :metrics
    assert_includes data.keys, :dimensions
    assert data[:metrics].any?
    
    # Verify specific metrics
    sessions_data = data[:metrics].find { |m| m[:name] == "sessions" }
    assert_not_nil sessions_data
    assert sessions_data[:values].any?
  end

  test "google analytics real time api integration" do
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock Real Time API
    stub_google_analytics_realtime_api
    
    result = service.fetch_realtime_data
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :active_users
    assert_includes data.keys, :top_pages
    assert data[:active_users] >= 0
  end

  test "google analytics goals and conversions integration" do
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock Goals API
    stub_google_analytics_goals_api
    
    result = service.fetch_goal_data(
      start_date: 30.days.ago,
      end_date: Time.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :goals
    assert_includes data.keys, :conversions
    assert data[:goals].any?
  end

  test "google analytics enhanced ecommerce integration" do
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock Enhanced Ecommerce API
    stub_google_analytics_ecommerce_api
    
    result = service.fetch_ecommerce_data(
      start_date: 30.days.ago,
      end_date: Time.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :transactions
    assert_includes data.keys, :revenue
    assert_includes data.keys, :products
  end

  test "google analytics custom dimensions integration" do
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock Custom Dimensions API
    stub_google_analytics_custom_dimensions_api
    
    result = service.fetch_custom_dimension_data(
      dimension: "customDimension1",
      start_date: 7.days.ago,
      end_date: Time.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :custom_dimension_values
    assert data[:custom_dimension_values].any?
  end

  # =============================================================================
  # GOOGLE ADS INTEGRATION TESTS
  # =============================================================================

  test "google ads basic integration" do
    service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "1234567890")
    
    # Mock Google Ads API
    stub_google_ads_campaigns_api
    
    result = service.fetch_campaign_performance(
      start_date: 30.days.ago.to_date,
      end_date: Date.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :campaigns
    assert data[:campaigns].any?
    
    # Verify campaign metrics
    campaign = data[:campaigns].first
    assert_includes campaign.keys, :impressions
    assert_includes campaign.keys, :clicks
    assert_includes campaign.keys, :cost
  end

  test "google ads keywords integration" do
    service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "1234567890")
    
    # Mock Keywords API
    stub_google_ads_keywords_api
    
    result = service.fetch_keywords_performance
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :keywords
    assert data[:keywords].any?
    
    # Verify keyword metrics
    keyword = data[:keywords].first
    assert_includes keyword.keys, :keyword_text
    assert_includes keyword.keys, :impressions
    assert_includes keyword.keys, :clicks
    assert_includes keyword.keys, :quality_score
  end

  test "google ads ad groups integration" do
    service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "1234567890")
    
    # Mock Ad Groups API
    stub_google_ads_adgroups_api
    
    result = service.fetch_adgroup_performance
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :ad_groups
    assert data[:ad_groups].any?
  end

  test "google ads conversion tracking integration" do
    service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "1234567890")
    
    # Mock Conversion Tracking API
    stub_google_ads_conversions_api
    
    result = service.fetch_conversion_data
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :conversions
    assert_includes data.keys, :conversion_value
    assert data[:conversions] >= 0
  end

  test "google ads audience insights integration" do
    service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "1234567890")
    
    # Mock Audience Insights API
    stub_google_ads_audience_api
    
    result = service.fetch_audience_insights
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :demographics
    assert_includes data.keys, :interests
    assert_includes data.keys, :geographic_performance
  end

  # =============================================================================
  # GOOGLE SEARCH CONSOLE INTEGRATION TESTS
  # =============================================================================

  test "google search console basic integration" do
    service = Analytics::GoogleSearchConsoleService.new(@user.id)
    
    # Mock Search Console API
    stub_google_search_console_api
    
    result = service.fetch_search_analytics(
      site_url: "https://example.com",
      start_date: 30.days.ago.to_date,
      end_date: Date.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :queries
    assert_includes data.keys, :pages
    assert data[:queries].any?
    
    # Verify query metrics
    query = data[:queries].first
    assert_includes query.keys, :query
    assert_includes query.keys, :impressions
    assert_includes query.keys, :clicks
    assert_includes query.keys, :ctr
    assert_includes query.keys, :position
  end

  test "google search console performance by page integration" do
    service = Analytics::GoogleSearchConsoleService.new(@user.id)
    
    # Mock Search Performance by Page
    stub_google_search_console_pages_api
    
    result = service.fetch_page_performance(
      site_url: "https://example.com",
      start_date: 7.days.ago.to_date,
      end_date: Date.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :pages
    assert data[:pages].any?
    
    # Verify page metrics
    page = data[:pages].first
    assert_includes page.keys, :page
    assert_includes page.keys, :impressions
    assert_includes page.keys, :clicks
  end

  test "google search console mobile usability integration" do
    service = Analytics::GoogleSearchConsoleService.new(@user.id)
    
    # Mock Mobile Usability API
    stub_google_search_console_mobile_api
    
    result = service.fetch_mobile_usability(site_url: "https://example.com")
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :mobile_usability_issues
    assert data[:mobile_usability_issues].is_a?(Array)
  end

  test "google search console crawl errors integration" do
    service = Analytics::GoogleSearchConsoleService.new(@user.id)
    
    # Mock Crawl Errors API
    stub_google_search_console_crawl_errors_api
    
    result = service.fetch_crawl_errors(site_url: "https://example.com")
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :crawl_errors
    assert data[:crawl_errors].is_a?(Array)
  end

  # =============================================================================
  # CROSS-SERVICE INTEGRATION TESTS
  # =============================================================================

  test "google services data correlation integration" do
    analytics_service = Analytics::GoogleAnalyticsService.new(@user.id)
    ads_service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "1234567890")
    search_service = Analytics::GoogleSearchConsoleService.new(@user.id)
    
    # Mock all APIs
    stub_google_analytics_reporting_api
    stub_google_ads_campaigns_api
    stub_google_search_console_api
    
    # Fetch data from all services
    analytics_data = analytics_service.fetch_analytics_data
    ads_data = ads_service.fetch_campaign_performance
    search_data = search_service.fetch_search_analytics(site_url: "https://example.com")
    
    assert analytics_data.success?
    assert ads_data.success?
    assert search_data.success?
    
    # Test correlation service
    correlation_service = Analytics::AttributionModelingService.new(@brand)
    result = correlation_service.correlate_google_data(
      analytics_data.data,
      ads_data.data,
      search_data.data
    )
    
    assert result.success?
    
    correlation = result.data
    assert_includes correlation.keys, :attribution_model
    assert_includes correlation.keys, :channel_performance
    assert_includes correlation.keys, :funnel_analysis
  end

  test "google services etl pipeline integration" do
    # Test ETL job for Google Analytics
    perform_enqueued_jobs do
      Etl::GoogleAnalyticsHourlyJob.perform_now(date_range: 1.hour.ago..Time.current)
    end
    
    # Verify pipeline run was created
    pipeline_run = EtlPipelineRun.where(source: "google_analytics_hourly").last
    assert_not_nil pipeline_run
    assert_equal "completed", pipeline_run.status
    
    # Verify data was processed and stored
    assert GoogleAnalyticsMetric.where("created_at > ?", 1.minute.ago).exists?
  end

  test "google services rate limiting integration" do
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock rate-limited response followed by success
    stub_google_analytics_rate_limited_then_success
    
    rate_limiter = Analytics::RateLimitingService.new(
      platform: "google_analytics",
      integration_id: @user.id,
      endpoint: "reports"
    )
    
    result = rate_limiter.execute_with_rate_limiting do
      service.fetch_analytics_data
    end
    
    assert result.success?
  end

  test "google services authentication error handling" do
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock authentication error
    stub_google_analytics_auth_error
    
    result = service.fetch_analytics_data
    
    assert_not result.success?
    assert_includes result.message.downcase, "authentication"
    
    # Mock successful retry after token refresh
    stub_google_analytics_reporting_api
    
    result = service.fetch_analytics_data
    assert result.success?
  end

  test "google services quota management integration" do
    service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "1234567890")
    
    # Mock quota exceeded response
    stub_google_ads_quota_exceeded
    
    result = service.fetch_campaign_performance
    
    assert_not result.success?
    assert_includes result.message.downcase, "quota"
    
    # Verify quota tracking
    assert service.quota_exceeded?
  end

  test "google analytics data export integration" do
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock Analytics data
    stub_google_analytics_reporting_api
    
    # Test data export to various formats
    result = service.export_analytics_data(
      format: "csv",
      start_date: 7.days.ago,
      end_date: Date.current
    )
    
    assert result.success?
    assert_includes result.data.keys, :export_url
    assert_includes result.data.keys, :file_size
  end

  # =============================================================================
  # PERFORMANCE AND MONITORING TESTS
  # =============================================================================

  test "google services performance monitoring integration" do
    # Test performance monitoring for Google services
    analytics_service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock slow API response
    stub_google_analytics_slow_response
    
    start_time = Time.current
    result = analytics_service.fetch_analytics_data
    end_time = Time.current
    
    response_time = (end_time - start_time) * 1000
    
    assert result.success?
    
    # Verify performance metrics are tracked
    assert response_time > 1000 # Should be slow due to mock
    
    # Performance should be logged
    assert analytics_service.last_response_time > 1000
  end

  test "google services health check integration" do
    health_service = Analytics::GoogleOauthService.new(@user)
    
    # Mock health check endpoints
    stub_google_services_health_check
    
    result = health_service.check_service_health
    
    assert result.success?
    
    health_data = result.data
    assert_includes health_data.keys, :analytics_status
    assert_includes health_data.keys, :ads_status
    assert_includes health_data.keys, :search_console_status
    
    assert_equal "healthy", health_data[:analytics_status]
    assert_equal "healthy", health_data[:ads_status]
    assert_equal "healthy", health_data[:search_console_status]
  end

  private

  # =============================================================================
  # GOOGLE OAUTH STUBS
  # =============================================================================

  def stub_google_oauth_token_exchange
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .with(body: hash_including(grant_type: "authorization_code"))
      .to_return(status: 200, body: {
        access_token: "google_access_token_123",
        refresh_token: "google_refresh_token_123",
        expires_in: 3600,
        token_type: "Bearer",
        scope: "https://www.googleapis.com/auth/analytics.readonly https://www.googleapis.com/auth/adwords"
      }.to_json)
  end

  def stub_google_token_refresh_success
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .with(body: hash_including(grant_type: "refresh_token"))
      .to_return(status: 200, body: {
        access_token: "new_google_access_token",
        expires_in: 3600,
        token_type: "Bearer"
      }.to_json)
  end

  def stub_google_accounts_list
    stub_request(:get, "https://analytics.googleapis.com/analytics/v3/management/accounts")
      .to_return(status: 200, body: {
        items: [
          { id: "12345", name: "Account 1", permissions: { effective: ["READ_AND_ANALYZE"] } },
          { id: "67890", name: "Account 2", permissions: { effective: ["READ_AND_ANALYZE"] } }
        ]
      }.to_json)
  end

  # =============================================================================
  # GOOGLE ANALYTICS STUBS
  # =============================================================================

  def stub_google_analytics_reporting_api
    stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
      .to_return(status: 200, body: {
        reports: [{
          columnHeader: {
            dimensions: ["ga:date", "ga:source"],
            metricHeader: {
              metricHeaderEntries: [
                { name: "ga:sessions", type: "INTEGER" },
                { name: "ga:pageviews", type: "INTEGER" },
                { name: "ga:users", type: "INTEGER" }
              ]
            }
          },
          data: {
            rows: [
              {
                dimensions: ["20231201", "google"],
                metrics: [{ values: ["1000", "2500", "800"] }]
              },
              {
                dimensions: ["20231202", "facebook"], 
                metrics: [{ values: ["1200", "3000", "950"] }]
              }
            ],
            totals: [{ values: ["2200", "5500", "1750"] }]
          }
        }]
      }.to_json)
  end

  def stub_google_analytics_realtime_api
    stub_request(:get, /analyticsreporting\.googleapis\.com\/v4\/reports:batchGet/)
      .to_return(status: 200, body: {
        reports: [{
          data: {
            rows: [
              {
                dimensions: ["(not set)"],
                metrics: [{ values: ["45"] }]
              }
            ],
            totals: [{ values: ["45"] }]
          }
        }]
      }.to_json)
  end

  def stub_google_analytics_goals_api
    stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
      .to_return(status: 200, body: {
        reports: [{
          data: {
            rows: [
              {
                dimensions: ["Goal 1 Conversion"],
                metrics: [{ values: ["25", "1250.00"] }]
              },
              {
                dimensions: ["Goal 2 Conversion"],
                metrics: [{ values: ["15", "750.00"] }]
              }
            ]
          }
        }]
      }.to_json)
  end

  def stub_google_analytics_ecommerce_api
    stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
      .to_return(status: 200, body: {
        reports: [{
          data: {
            rows: [
              {
                dimensions: ["Product A"],
                metrics: [{ values: ["50", "2500.00", "25"] }]
              },
              {
                dimensions: ["Product B"],
                metrics: [{ values: ["30", "1800.00", "15"] }]
              }
            ]
          }
        }]
      }.to_json)
  end

  def stub_google_analytics_custom_dimensions_api
    stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
      .to_return(status: 200, body: {
        reports: [{
          data: {
            rows: [
              {
                dimensions: ["Premium User"],
                metrics: [{ values: ["500"] }]
              },
              {
                dimensions: ["Free User"],
                metrics: [{ values: ["1500"] }]
              }
            ]
          }
        }]
      }.to_json)
  end

  def stub_google_analytics_rate_limited_then_success
    stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
      .to_return(status: 429, body: { error: { message: "Quota exceeded" } }.to_json)
      .then
      .to_return(status: 200, body: {
        reports: [{
          data: {
            rows: [{ dimensions: ["20231201"], metrics: [{ values: ["1000"] }] }]
          }
        }]
      }.to_json)
  end

  def stub_google_analytics_auth_error
    stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
      .to_return(status: 401, body: {
        error: {
          code: 401,
          message: "Request is missing required authentication credential"
        }
      }.to_json)
  end

  def stub_google_analytics_slow_response
    stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
      .to_return(status: 200, body: {
        reports: [{ data: { rows: [] } }]
      }.to_json)
      .to_timeout.then # First request times out
      .to_return(status: 200, body: {
        reports: [{
          data: {
            rows: [{ dimensions: ["20231201"], metrics: [{ values: ["1000"] }] }]
          }
        }]
      }.to_json)
  end

  # =============================================================================
  # GOOGLE ADS STUBS
  # =============================================================================

  def stub_google_ads_campaigns_api
    stub_request(:post, /googleads\.googleapis\.com\/v14\/customers\/\d+\/googleAds:searchStream/)
      .to_return(status: 200, body: [
        {
          results: [
            {
              campaign: {
                id: "123456789",
                name: "Test Campaign 1",
                status: "ENABLED"
              },
              metrics: {
                impressions: "15000",
                clicks: "300",
                cost_micros: "5000000",
                conversions: "15.0",
                conversion_value: "750.00"
              }
            },
            {
              campaign: {
                id: "987654321",
                name: "Test Campaign 2", 
                status: "ENABLED"
              },
              metrics: {
                impressions: "22000",
                clicks: "450",
                cost_micros: "7500000",
                conversions: "22.0",
                conversion_value: "1100.00"
              }
            }
          ]
        }
      ].map(&:to_json).join("\n"))
  end

  def stub_google_ads_keywords_api
    stub_request(:post, /googleads\.googleapis\.com.*keywords/)
      .to_return(status: 200, body: [
        {
          results: [
            {
              ad_group_criterion: {
                keyword: {
                  text: "marketing automation",
                  match_type: "BROAD"
                }
              },
              metrics: {
                impressions: "5000",
                clicks: "100",
                cost_micros: "2000000"
              },
              quality_score: {
                quality_score: 7
              }
            }
          ]
        }
      ].map(&:to_json).join("\n"))
  end

  def stub_google_ads_adgroups_api
    stub_request(:post, /googleads\.googleapis\.com.*adGroups/)
      .to_return(status: 200, body: [
        {
          results: [
            {
              ad_group: {
                id: "111111",
                name: "Ad Group 1",
                status: "ENABLED"
              },
              metrics: {
                impressions: "8000",
                clicks: "160",
                cost_micros: "3200000"
              }
            }
          ]
        }
      ].map(&:to_json).join("\n"))
  end

  def stub_google_ads_conversions_api
    stub_request(:post, /googleads\.googleapis\.com.*conversions/)
      .to_return(status: 200, body: [
        {
          results: [
            {
              conversion_action: {
                id: "222222",
                name: "Purchase"
              },
              metrics: {
                conversions: "25.0",
                conversion_value: "1250.00",
                cost_per_conversion: "50.00"
              }
            }
          ]
        }
      ].map(&:to_json).join("\n"))
  end

  def stub_google_ads_audience_api
    stub_request(:post, /googleads\.googleapis\.com.*audience/)
      .to_return(status: 200, body: [
        {
          results: [
            {
              user_list: {
                id: "333333",
                name: "Website Visitors"
              },
              metrics: {
                impressions: "12000",
                clicks: "240"
              }
            }
          ]
        }
      ].map(&:to_json).join("\n"))
  end

  def stub_google_ads_quota_exceeded
    stub_request(:post, /googleads\.googleapis\.com/)
      .to_return(status: 429, body: {
        error: {
          code: 429,
          message: "Quota exceeded",
          status: "RESOURCE_EXHAUSTED"
        }
      }.to_json)
  end

  # =============================================================================
  # GOOGLE SEARCH CONSOLE STUBS
  # =============================================================================

  def stub_google_search_console_api
    stub_request(:post, "https://searchconsole.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fexample.com/searchAnalytics/query")
      .to_return(status: 200, body: {
        rows: [
          {
            keys: ["marketing automation"],
            impressions: 1500,
            clicks: 75,
            ctr: 0.05,
            position: 8.2
          },
          {
            keys: ["email marketing"],
            impressions: 2200,
            clicks: 110,
            ctr: 0.05,
            position: 6.8
          },
          {
            keys: ["social media management"],
            impressions: 1800,
            clicks: 90,
            ctr: 0.05,
            position: 7.5
          }
        ]
      }.to_json)
  end

  def stub_google_search_console_pages_api
    stub_request(:post, "https://searchconsole.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fexample.com/searchAnalytics/query")
      .to_return(status: 200, body: {
        rows: [
          {
            keys: ["https://example.com/blog/marketing-tips"],
            impressions: 3000,
            clicks: 150,
            ctr: 0.05,
            position: 5.2
          },
          {
            keys: ["https://example.com/products/email-tool"],
            impressions: 2500,
            clicks: 125,
            ctr: 0.05,
            position: 6.8
          }
        ]
      }.to_json)
  end

  def stub_google_search_console_mobile_api
    stub_request(:get, "https://searchconsole.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fexample.com/mobileFriendlyTest")
      .to_return(status: 200, body: {
        mobileFriendliness: "MOBILE_FRIENDLY",
        mobileFriendlyIssues: []
      }.to_json)
  end

  def stub_google_search_console_crawl_errors_api
    stub_request(:get, "https://searchconsole.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fexample.com/urlCrawlErrorsCounts/query")
      .to_return(status: 200, body: {
        countPerTypes: [
          {
            platform: "web",
            category: "serverError", 
            entries: [
              { count: 5, timestamp: Time.current.iso8601 }
            ]
          }
        ]
      }.to_json)
  end

  def stub_google_services_health_check
    # Mock health check for each service
    stub_request(:get, "https://analyticsreporting.googleapis.com/v4/metadata")
      .to_return(status: 200, body: { status: "healthy" }.to_json)
      
    stub_request(:get, /googleads\.googleapis\.com.*health/)
      .to_return(status: 200, body: { status: "healthy" }.to_json)
      
    stub_request(:get, "https://searchconsole.googleapis.com/webmasters/v3/sites")
      .to_return(status: 200, body: { status: "healthy" }.to_json)
  end
end