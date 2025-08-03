# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class SocialMediaPlatformIntegrationTest < ActionDispatch::IntegrationTest
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
  # FACEBOOK INTEGRATION TESTS
  # =============================================================================

  test "facebook oauth flow complete integration" do
    # Test authorization URL generation
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    auth_url = service.connect_facebook_api
    assert_not_nil auth_url
    assert_includes auth_url, "facebook.com"
    
    # Mock Facebook OAuth response
    stub_facebook_oauth_success
    
    # Test callback handling
    result = service.handle_oauth_callback("facebook", "test_auth_code", "test_state")
    
    assert result.success?
    assert_equal "Facebook integration connected successfully", result.message
    
    # Verify integration was created
    integration = @brand.social_media_integrations.find_by(platform: "facebook")
    assert_not_nil integration
    assert_equal "active", integration.status
    assert_not_nil integration.access_token
  end

  test "facebook metrics collection integration" do
    integration = create_facebook_integration
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock Facebook Graph API responses
    stub_facebook_insights_api
    
    result = service.collect_facebook_metrics
    
    assert result.success?
    
    # Verify metrics were stored
    metrics = integration.social_media_metrics.where(platform: "facebook")
    assert metrics.exists?
    
    # Verify specific metrics
    reach_metric = metrics.find_by(metric_type: "reach")
    assert_not_nil reach_metric
    assert reach_metric.value > 0
  end

  test "facebook page insights integration" do
    integration = create_facebook_integration
    
    # Mock Facebook Page Insights API
    stub_facebook_page_insights
    
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    result = service.collect_facebook_metrics(date_range: 7.days.ago..Time.current)
    
    assert result.success?
    
    # Verify page-specific metrics
    page_metrics = integration.social_media_metrics.where(
      platform: "facebook",
      metric_type: ["page_views", "page_likes", "page_engagement"]
    )
    assert page_metrics.exists?
  end

  test "facebook ads integration" do
    integration = create_facebook_integration
    
    # Mock Facebook Ads API
    stub_facebook_ads_api
    
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Test ads data collection (would be implemented in service)
    result = service.collect_facebook_ads_metrics
    
    assert result.success?
    
    # Verify ads metrics
    ads_metrics = integration.social_media_metrics.where(
      platform: "facebook",
      metric_type: ["ad_impressions", "ad_clicks", "ad_spend"]
    )
    assert ads_metrics.exists?
  end

  test "facebook webhook integration" do
    integration = create_facebook_integration
    
    # Test Facebook webhook handling
    webhook_payload = {
      object: "page",
      entry: [{
        id: "page_123",
        time: Time.current.to_i,
        changes: [{
          field: "feed",
          value: {
            item: "post",
            post_id: "post_123",
            verb: "add"
          }
        }]
      }]
    }
    
    post "/webhooks/social_media/facebook", 
         params: webhook_payload, 
         headers: { "Content-Type" => "application/json" }
    
    assert_response :success
    
    # Verify webhook was processed
    assert_performed_jobs 1
  end

  # =============================================================================
  # INSTAGRAM INTEGRATION TESTS
  # =============================================================================

  test "instagram oauth flow integration" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Test Instagram authorization
    auth_url = service.connect_instagram_api
    assert_not_nil auth_url
    assert_includes auth_url, "instagram.com"
    
    # Mock Instagram OAuth
    stub_instagram_oauth_success
    
    result = service.handle_oauth_callback("instagram", "ig_auth_code", "ig_state")
    
    assert result.success?
    
    integration = @brand.social_media_integrations.find_by(platform: "instagram")
    assert_not_nil integration
    assert_equal "active", integration.status
  end

  test "instagram business account metrics" do
    integration = create_instagram_integration
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock Instagram Business API
    stub_instagram_business_api
    
    result = service.collect_instagram_metrics
    
    assert result.success?
    
    # Verify Instagram business metrics
    metrics = integration.social_media_metrics.where(platform: "instagram")
    assert metrics.exists?
    
    # Check for Instagram-specific metrics
    follower_metric = metrics.find_by(metric_type: "followers")
    assert_not_nil follower_metric
    
    reach_metric = metrics.find_by(metric_type: "reach")
    assert_not_nil reach_metric
  end

  test "instagram story metrics integration" do
    integration = create_instagram_integration
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock Instagram Stories API
    stub_instagram_stories_api
    
    result = service.collect_instagram_story_metrics
    
    assert result.success?
    
    # Verify story metrics
    story_metrics = integration.social_media_metrics.where(
      platform: "instagram",
      metric_type: ["story_views", "story_interactions", "story_exits"]
    )
    assert story_metrics.exists?
  end

  test "instagram media insights integration" do
    integration = create_instagram_integration
    
    # Mock Instagram Media Insights
    stub_instagram_media_insights
    
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Test media-specific insights collection
    result = service.collect_instagram_media_insights("media_123")
    
    assert result.success?
    
    # Verify media insights
    media_metrics = integration.social_media_metrics.where(
      platform: "instagram",
      metric_type: ["media_reach", "media_impressions", "media_engagement"]
    )
    assert media_metrics.exists?
  end

  # =============================================================================
  # LINKEDIN INTEGRATION TESTS
  # =============================================================================

  test "linkedin oauth flow integration" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    auth_url = service.connect_linkedin_api
    assert_not_nil auth_url
    assert_includes auth_url, "linkedin.com"
    
    # Mock LinkedIn OAuth
    stub_linkedin_oauth_success
    
    result = service.handle_oauth_callback("linkedin", "li_auth_code", "li_state")
    
    assert result.success?
    
    integration = @brand.social_media_integrations.find_by(platform: "linkedin")
    assert_not_nil integration
    assert_equal "active", integration.status
  end

  test "linkedin company page analytics" do
    integration = create_linkedin_integration
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock LinkedIn Analytics API
    stub_linkedin_analytics_api
    
    result = service.collect_linkedin_metrics
    
    assert result.success?
    
    # Verify LinkedIn metrics
    metrics = integration.social_media_metrics.where(platform: "linkedin")
    assert metrics.exists?
    
    # Check LinkedIn-specific metrics
    clicks_metric = metrics.find_by(metric_type: "clicks")
    assert_not_nil clicks_metric
    
    engagements_metric = metrics.find_by(metric_type: "engagements")
    assert_not_nil engagements_metric
  end

  test "linkedin marketing api integration" do
    integration = create_linkedin_integration
    
    # Mock LinkedIn Marketing API
    stub_linkedin_marketing_api
    
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    result = service.collect_linkedin_campaign_metrics
    
    assert result.success?
    
    # Verify campaign metrics
    campaign_metrics = integration.social_media_metrics.where(
      platform: "linkedin",
      metric_type: ["campaign_impressions", "campaign_clicks", "campaign_conversions"]
    )
    assert campaign_metrics.exists?
  end

  # =============================================================================
  # TWITTER/X INTEGRATION TESTS
  # =============================================================================

  test "twitter oauth flow integration" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    auth_url = service.connect_twitter_api
    assert_not_nil auth_url
    assert_includes auth_url, "twitter.com"
    
    # Mock Twitter OAuth 2.0
    stub_twitter_oauth_success
    
    result = service.handle_oauth_callback("twitter", "tw_auth_code", "tw_state")
    
    assert result.success?
    
    integration = @brand.social_media_integrations.find_by(platform: "twitter")
    assert_not_nil integration
    assert_equal "active", integration.status
  end

  test "twitter analytics api integration" do
    integration = create_twitter_integration
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock Twitter Analytics API
    stub_twitter_analytics_api
    
    result = service.collect_twitter_metrics
    
    assert result.success?
    
    # Verify Twitter metrics
    metrics = integration.social_media_metrics.where(platform: "twitter")
    assert metrics.exists?
    
    # Check Twitter-specific metrics
    impressions_metric = metrics.find_by(metric_type: "impressions")
    assert_not_nil impressions_metric
    
    engagements_metric = metrics.find_by(metric_type: "engagements")
    assert_not_nil engagements_metric
    
    retweets_metric = metrics.find_by(metric_type: "retweets")
    assert_not_nil retweets_metric
  end

  test "twitter v2 api integration" do
    integration = create_twitter_integration
    
    # Mock Twitter API v2
    stub_twitter_v2_api
    
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    result = service.collect_twitter_v2_metrics
    
    assert result.success?
    
    # Verify v2 API metrics
    v2_metrics = integration.social_media_metrics.where(
      platform: "twitter",
      metric_type: ["tweet_impressions", "profile_visits", "mentions"]
    )
    assert v2_metrics.exists?
  end

  # =============================================================================
  # TIKTOK INTEGRATION TESTS
  # =============================================================================

  test "tiktok oauth flow integration" do
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    auth_url = service.connect_tiktok_api
    assert_not_nil auth_url
    assert_includes auth_url, "tiktok.com"
    
    # Mock TikTok OAuth
    stub_tiktok_oauth_success
    
    result = service.handle_oauth_callback("tiktok", "tt_auth_code", "tt_state")
    
    assert result.success?
    
    integration = @brand.social_media_integrations.find_by(platform: "tiktok")
    assert_not_nil integration
    assert_equal "active", integration.status
  end

  test "tiktok analytics api integration" do
    integration = create_tiktok_integration
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock TikTok Analytics API
    stub_tiktok_analytics_api
    
    result = service.collect_tiktok_metrics
    
    assert result.success?
    
    # Verify TikTok metrics
    metrics = integration.social_media_metrics.where(platform: "tiktok")
    assert metrics.exists?
    
    # Check TikTok-specific metrics
    video_views_metric = metrics.find_by(metric_type: "video_views")
    assert_not_nil video_views_metric
    
    likes_metric = metrics.find_by(metric_type: "likes")
    assert_not_nil likes_metric
  end

  test "tiktok audience insights integration" do
    integration = create_tiktok_integration
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock TikTok Audience Insights
    stub_tiktok_audience_insights
    
    result = service.collect_tiktok_audience_insights
    
    assert result.success?
    
    # Verify audience insights
    audience_data = result.data
    assert_includes audience_data.keys, :age_groups
    assert_includes audience_data.keys, :gender_distribution
    assert_includes audience_data.keys, :geographic_data
  end

  # =============================================================================
  # CROSS-PLATFORM INTEGRATION TESTS
  # =============================================================================

  test "cross platform aggregation integration" do
    # Create integrations for all platforms
    platforms = %w[facebook instagram linkedin twitter tiktok]
    platforms.each { |platform| create_integration_for_platform(platform) }
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Mock all platform APIs
    stub_all_social_media_apis
    
    result = service.aggregate_all_platforms
    
    assert result.success?
    
    data = result.data
    assert_equal platforms.count, data[:platform_breakdown].keys.count
    assert data[:total_reach] > 0
    assert data[:total_engagement] > 0
    
    # Verify aggregated data structure
    assert_includes data.keys, :total_reach
    assert_includes data.keys, :total_engagement
    assert_includes data.keys, :platform_breakdown
    assert_includes data.keys, :date_range
  end

  test "social media rate limiting integration" do
    integration = create_facebook_integration
    
    # Mock rate-limited responses
    stub_facebook_rate_limited_then_success
    
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    rate_limiter = Analytics::RateLimitingService.new(
      platform: "facebook",
      integration_id: integration.id,
      endpoint: "insights"
    )
    
    result = rate_limiter.execute_with_rate_limiting do
      service.collect_facebook_metrics
    end
    
    assert result.success?
    
    # Verify rate limiting was handled
    assert integration.social_media_metrics.exists?
  end

  test "social media token refresh integration" do
    integration = create_facebook_integration
    
    # Expire the token
    integration.update!(expires_at: 1.hour.ago)
    
    # Mock token refresh
    stub_facebook_token_refresh
    
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    result = service.refresh_all_tokens
    
    assert result.success?
    
    # Verify token was refreshed
    assert integration.reload.token_valid?
    assert integration.status == "active"
  end

  test "social media error handling and recovery" do
    integration = create_facebook_integration
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock API error followed by success
    stub_facebook_error_then_success
    
    # First attempt should fail
    result = service.collect_facebook_metrics
    assert_not result.success?
    
    # Second attempt should succeed
    result = service.collect_facebook_metrics
    assert result.success?
    
    # Verify metrics were eventually collected
    assert integration.social_media_metrics.exists?
  end

  test "real time social media updates integration" do
    integration = create_facebook_integration
    
    # Test real-time job processing
    perform_enqueued_jobs do
      Etl::SocialMediaRealTimeJob.perform_now(integration.id)
    end
    
    # Verify WebSocket broadcast for real-time updates
    assert_broadcasts "analytics_dashboard_#{@brand.id}", 1
    
    # Verify metrics were updated
    assert integration.social_media_metrics.where("created_at > ?", 1.minute.ago).exists?
  end

  test "social media webhook processing integration" do
    %w[facebook instagram linkedin twitter tiktok].each do |platform|
      integration = create_integration_for_platform(platform)
      webhook_data = generate_webhook_payload_for_platform(platform)
      
      post "/webhooks/social_media/#{platform}", 
           params: webhook_data,
           headers: { "Content-Type" => "application/json" }
      
      assert_response :success
      
      # Verify webhook processing job was enqueued
      assert_performed_jobs 1
      
      clear_performed_jobs
    end
  end

  test "social media data consistency checks" do
    # Create test data with potential inconsistencies
    integration = create_facebook_integration
    
    # Create metrics with inconsistent values
    SocialMediaMetric.create!(
      social_media_integration: integration,
      platform: "facebook",
      metric_type: "reach",
      value: 1000,
      date: Date.current
    )
    
    SocialMediaMetric.create!(
      social_media_integration: integration,
      platform: "facebook",
      metric_type: "engagement",
      value: 2000, # More engagement than reach (inconsistent)
      date: Date.current
    )
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.validate_data_consistency
    
    assert result.success?
    assert result.data[:inconsistencies].any?
  end

  private

  # =============================================================================
  # HELPER METHODS FOR CREATING TEST INTEGRATIONS
  # =============================================================================

  def create_facebook_integration
    SocialMediaIntegration.create!(
      brand: @brand,
      platform: "facebook",
      access_token: "fb_test_token",
      refresh_token: "fb_refresh_token",
      expires_at: 1.hour.from_now,
      status: "active",
      platform_account_id: "fb_account_123",
      configuration: { page_id: "page_123", page_access_token: "page_token" }
    )
  end

  def create_instagram_integration
    SocialMediaIntegration.create!(
      brand: @brand,
      platform: "instagram",
      access_token: "ig_test_token",
      status: "active",
      platform_account_id: "ig_account_123",
      configuration: { business_account_id: "business_123" }
    )
  end

  def create_linkedin_integration
    SocialMediaIntegration.create!(
      brand: @brand,
      platform: "linkedin",
      access_token: "li_test_token",
      refresh_token: "li_refresh_token",
      expires_at: 60.days.from_now,
      status: "active",
      platform_account_id: "li_company_123"
    )
  end

  def create_twitter_integration
    SocialMediaIntegration.create!(
      brand: @brand,
      platform: "twitter",
      access_token: "tw_test_token",
      status: "active",
      platform_account_id: "tw_user_123"
    )
  end

  def create_tiktok_integration
    SocialMediaIntegration.create!(
      brand: @brand,
      platform: "tiktok",
      access_token: "tt_test_token",
      refresh_token: "tt_refresh_token",
      expires_at: 1.day.from_now,
      status: "active",
      platform_account_id: "tt_user_123"
    )
  end

  def create_integration_for_platform(platform)
    case platform
    when "facebook" then create_facebook_integration
    when "instagram" then create_instagram_integration
    when "linkedin" then create_linkedin_integration
    when "twitter" then create_twitter_integration
    when "tiktok" then create_tiktok_integration
    end
  end

  # =============================================================================
  # API STUBBING METHODS
  # =============================================================================

  def stub_facebook_oauth_success
    stub_request(:post, "https://graph.facebook.com/v18.0/oauth/access_token")
      .to_return(status: 200, body: {
        access_token: "fb_access_token_123",
        token_type: "bearer",
        expires_in: 3600
      }.to_json)
  end

  def stub_facebook_insights_api
    stub_request(:get, /graph\.facebook\.com.*insights/)
      .to_return(status: 200, body: {
        data: [
          {
            name: "page_impressions",
            period: "day",
            values: [{ value: 10000, end_time: Time.current.iso8601 }]
          },
          {
            name: "page_engaged_users",
            period: "day", 
            values: [{ value: 500, end_time: Time.current.iso8601 }]
          }
        ]
      }.to_json)
  end

  def stub_facebook_page_insights
    stub_request(:get, /graph\.facebook\.com.*insights/)
      .to_return(status: 200, body: {
        data: [
          {
            name: "page_views_total",
            period: "day",
            values: [{ value: 1500, end_time: Time.current.iso8601 }]
          },
          {
            name: "page_likes",
            period: "lifetime",
            values: [{ value: 5000, end_time: Time.current.iso8601 }]
          }
        ]
      }.to_json)
  end

  def stub_facebook_ads_api
    stub_request(:get, /graph\.facebook\.com.*campaigns/)
      .to_return(status: 200, body: {
        data: [
          {
            id: "campaign_123",
            name: "Test Campaign",
            insights: {
              data: [
                {
                  impressions: "15000",
                  clicks: "300",
                  spend: "100.00",
                  date_start: Date.current.to_s,
                  date_stop: Date.current.to_s
                }
              ]
            }
          }
        ]
      }.to_json)
  end

  def stub_facebook_rate_limited_then_success
    stub_request(:get, /graph\.facebook\.com/)
      .to_return(status: 429, headers: { "Retry-After" => "60" })
      .then
      .to_return(status: 200, body: {
        data: [
          {
            name: "page_impressions",
            values: [{ value: 5000 }]
          }
        ]
      }.to_json)
  end

  def stub_facebook_token_refresh
    stub_request(:post, "https://graph.facebook.com/v18.0/oauth/access_token")
      .with(body: hash_including(grant_type: "refresh_token"))
      .to_return(status: 200, body: {
        access_token: "new_fb_token",
        expires_in: 3600
      }.to_json)
  end

  def stub_facebook_error_then_success
    stub_request(:get, /graph\.facebook\.com/)
      .to_return(status: 500, body: { error: { message: "Internal Server Error" } }.to_json)
      .then
      .to_return(status: 200, body: {
        data: [
          {
            name: "page_impressions",
            values: [{ value: 8000 }]
          }
        ]
      }.to_json)
  end

  def stub_instagram_oauth_success
    stub_request(:post, "https://api.instagram.com/oauth/access_token")
      .to_return(status: 200, body: {
        access_token: "ig_access_token_123",
        user_id: "ig_user_123"
      }.to_json)
  end

  def stub_instagram_business_api
    stub_request(:get, /graph\.instagram\.com.*insights/)
      .to_return(status: 200, body: {
        data: [
          {
            name: "reach",
            period: "day",
            values: [{ value: 5000, end_time: Time.current.iso8601 }]
          },
          {
            name: "impressions",
            period: "day",
            values: [{ value: 8000, end_time: Time.current.iso8601 }]
          }
        ]
      }.to_json)
  end

  def stub_instagram_stories_api
    stub_request(:get, /graph\.instagram\.com.*stories/)
      .to_return(status: 200, body: {
        data: [
          {
            id: "story_123",
            insights: {
              data: [
                { name: "impressions", values: [{ value: 2000 }] },
                { name: "reach", values: [{ value: 1500 }] },
                { name: "taps_forward", values: [{ value: 100 }] },
                { name: "taps_back", values: [{ value: 50 }] },
                { name: "exits", values: [{ value: 25 }] }
              ]
            }
          }
        ]
      }.to_json)
  end

  def stub_instagram_media_insights
    stub_request(:get, /graph\.instagram\.com.*media_123\/insights/)
      .to_return(status: 200, body: {
        data: [
          { name: "reach", values: [{ value: 3000 }] },
          { name: "impressions", values: [{ value: 4500 }] },
          { name: "engagement", values: [{ value: 200 }] }
        ]
      }.to_json)
  end

  def stub_linkedin_oauth_success
    stub_request(:post, "https://www.linkedin.com/oauth/v2/accessToken")
      .to_return(status: 200, body: {
        access_token: "li_access_token_123",
        expires_in: 5184000,
        refresh_token: "li_refresh_token_123"
      }.to_json)
  end

  def stub_linkedin_analytics_api
    stub_request(:get, /api\.linkedin\.com.*analytics/)
      .to_return(status: 200, body: {
        elements: [
          {
            totalShareStatistics: {
              clickCount: 150,
              likeCount: 75,
              commentCount: 25,
              shareCount: 10,
              impressionCount: 5000
            }
          }
        ]
      }.to_json)
  end

  def stub_linkedin_marketing_api
    stub_request(:get, /api\.linkedin\.com.*campaigns/)
      .to_return(status: 200, body: {
        elements: [
          {
            id: "campaign_123",
            name: "LinkedIn Campaign",
            statistics: {
              impressions: 10000,
              clicks: 200,
              conversions: 15,
              spend: { amount: "250.00", currencyCode: "USD" }
            }
          }
        ]
      }.to_json)
  end

  def stub_twitter_oauth_success
    stub_request(:post, "https://api.twitter.com/2/oauth2/token")
      .to_return(status: 200, body: {
        access_token: "tw_access_token_123",
        token_type: "bearer",
        expires_in: 7200
      }.to_json)
  end

  def stub_twitter_analytics_api
    stub_request(:get, /api\.twitter\.com.*analytics/)
      .to_return(status: 200, body: {
        data: [
          {
            id: "tweet_123",
            public_metrics: {
              retweet_count: 25,
              like_count: 100,
              reply_count: 15,
              quote_count: 5
            },
            non_public_metrics: {
              impression_count: 5000,
              url_link_clicks: 50,
              user_profile_clicks: 20
            }
          }
        ]
      }.to_json)
  end

  def stub_twitter_v2_api
    stub_request(:get, /api\.twitter\.com\/2\/tweets/)
      .to_return(status: 200, body: {
        data: [
          {
            id: "tweet_456",
            text: "Sample tweet",
            public_metrics: {
              retweet_count: 30,
              like_count: 120,
              reply_count: 18,
              quote_count: 8
            }
          }
        ],
        meta: {
          result_count: 1
        }
      }.to_json)
  end

  def stub_tiktok_oauth_success
    stub_request(:post, "https://open-api.tiktok.com/oauth/access_token/")
      .to_return(status: 200, body: {
        data: {
          access_token: "tt_access_token_123",
          expires_in: 86400,
          refresh_token: "tt_refresh_token_123",
          scope: "user.info.basic,video.list"
        }
      }.to_json)
  end

  def stub_tiktok_analytics_api
    stub_request(:post, /open-api\.tiktok\.com.*analytics/)
      .to_return(status: 200, body: {
        data: {
          metrics: [
            {
              metric_name: "VIDEO_VIEWS",
              value: 50000
            },
            {
              metric_name: "LIKES",
              value: 2500
            },
            {
              metric_name: "SHARES",
              value: 150
            },
            {
              metric_name: "COMMENTS",
              value: 300
            }
          ]
        }
      }.to_json)
  end

  def stub_tiktok_audience_insights
    stub_request(:post, /open-api\.tiktok\.com.*audience/)
      .to_return(status: 200, body: {
        data: {
          audience_insight: {
            age_distribution: {
              "18-24" => 35,
              "25-34" => 40,
              "35-44" => 20,
              "45+" => 5
            },
            gender_distribution: {
              "MALE" => 45,
              "FEMALE" => 55
            },
            geography_distribution: {
              "US" => 60,
              "UK" => 15,
              "CA" => 10,
              "OTHER" => 15
            }
          }
        }
      }.to_json)
  end

  def stub_all_social_media_apis
    stub_facebook_insights_api
    stub_instagram_business_api
    stub_linkedin_analytics_api
    stub_twitter_analytics_api
    stub_tiktok_analytics_api
  end

  def generate_webhook_payload_for_platform(platform)
    case platform
    when "facebook"
      {
        object: "page",
        entry: [{
          id: "page_123",
          time: Time.current.to_i,
          changes: [{
            field: "feed",
            value: { item: "post", post_id: "post_123", verb: "add" }
          }]
        }]
      }
    when "instagram"
      {
        object: "instagram",
        entry: [{
          id: "ig_account_123", 
          time: Time.current.to_i,
          changes: [{
            field: "media",
            value: { media_id: "media_123", verb: "create" }
          }]
        }]
      }
    when "linkedin"
      {
        event_type: "SHARE_EVENT",
        share_id: "share_123",
        timestamp: Time.current.to_i
      }
    when "twitter"
      {
        tweet_create_events: [{
          id: "tweet_123",
          text: "New tweet",
          user: { id: "user_123" },
          timestamp_ms: (Time.current.to_f * 1000).to_i.to_s
        }]
      }
    when "tiktok"
      {
        type: "VIDEO_PUBLISH",
        video_id: "video_123",
        user_id: "user_123",
        timestamp: Time.current.to_i
      }
    end
  end
end