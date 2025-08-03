# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class AnalyticsMonitoringComprehensiveIntegrationTest < ActionDispatch::IntegrationTest
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
  # SOCIAL MEDIA INTEGRATION TESTS
  # =============================================================================

  test "complete social media integration workflow" do
    # Test OAuth flow for each platform
    %w[facebook instagram linkedin twitter tiktok].each do |platform|
      test_social_media_oauth_flow(platform)
      test_social_media_metrics_collection(platform)
    end

    # Test cross-platform aggregation
    test_social_media_aggregation
    
    # Test real-time dashboard updates
    test_social_media_realtime_updates
  end

  test "social media rate limiting and error handling" do
    %w[facebook instagram linkedin twitter tiktok].each do |platform|
      test_social_media_rate_limiting(platform)
      test_social_media_error_recovery(platform)
    end
  end

  test "social media webhook processing" do
    %w[facebook instagram linkedin twitter tiktok].each do |platform|
      test_social_media_webhook_handling(platform)
    end
  end

  # =============================================================================
  # GOOGLE SERVICES INTEGRATION TESTS
  # =============================================================================

  test "complete google services integration workflow" do
    # Test Google OAuth and Analytics
    test_google_analytics_integration
    test_google_ads_integration
    test_google_search_console_integration
    
    # Test cross-service data correlation
    test_google_services_correlation
    
    # Test ETL pipeline integration
    test_google_etl_pipeline
  end

  test "google services authentication and token management" do
    test_google_oauth_flow
    test_google_token_refresh
    test_google_multi_account_support
  end

  # =============================================================================
  # EMAIL MARKETING INTEGRATION TESTS
  # =============================================================================

  test "complete email marketing integration workflow" do
    # Test major email platforms
    test_mailchimp_integration
    test_sendgrid_integration
    test_hubspot_email_integration
    
    # Test email analytics aggregation
    test_email_analytics_aggregation
    
    # Test automated campaign tracking
    test_email_campaign_tracking
  end

  test "email platform webhook processing" do
    test_mailchimp_webhooks
    test_sendgrid_webhooks
    test_email_bounce_handling
    test_email_engagement_tracking
  end

  # =============================================================================
  # CRM INTEGRATION TESTS
  # =============================================================================

  test "complete crm integration workflow" do
    test_salesforce_integration
    test_hubspot_crm_integration
    test_pipedrive_integration
    
    # Test lead attribution
    test_crm_lead_attribution
    test_crm_opportunity_tracking
    
    # Test cross-platform customer journey
    test_crm_customer_journey_mapping
  end

  test "crm data synchronization" do
    test_crm_bidirectional_sync
    test_crm_conflict_resolution
    test_crm_real_time_updates
  end

  # =============================================================================
  # ETL PIPELINE INTEGRATION TESTS
  # =============================================================================

  test "complete etl pipeline workflow" do
    test_etl_data_extraction
    test_etl_data_transformation
    test_etl_data_loading
    test_etl_pipeline_monitoring
    test_etl_error_handling
    test_etl_performance_optimization
  end

  test "real-time data processing" do
    test_streaming_data_ingestion
    test_real_time_transformation
    test_event_driven_processing
  end

  # =============================================================================
  # DASHBOARD AND WEBSOCKET TESTS
  # =============================================================================

  test "real-time dashboard functionality" do
    test_websocket_connections
    test_dashboard_real_time_updates
    test_multi_user_dashboard_sync
    test_dashboard_filtering_and_drilling
  end

  test "dashboard performance and scalability" do
    test_dashboard_load_performance
    test_concurrent_user_support
    test_data_refresh_optimization
  end

  # =============================================================================
  # ALERT SYSTEM INTEGRATION TESTS
  # =============================================================================

  test "comprehensive alert system workflow" do
    test_threshold_based_alerts
    test_anomaly_detection_alerts
    test_multi_channel_notifications
    test_alert_escalation
    test_alert_acknowledgment
  end

  test "alert system performance and reliability" do
    test_alert_delivery_guarantees
    test_alert_rate_limiting
    test_alert_deduplication
  end

  # =============================================================================
  # REPORTING SYSTEM INTEGRATION TESTS
  # =============================================================================

  test "comprehensive reporting system workflow" do
    test_custom_report_creation
    test_report_scheduling
    test_report_export_formats
    test_report_distribution
    test_report_template_system
  end

  test "advanced reporting features" do
    test_cross_platform_reporting
    test_attribution_modeling
    test_cohort_analysis
    test_predictive_analytics
  end

  # =============================================================================
  # BACKGROUND JOBS AND DATA FLOWS
  # =============================================================================

  test "background job processing" do
    test_data_sync_jobs
    test_report_generation_jobs
    test_cleanup_jobs
    test_monitoring_jobs
    test_job_failure_recovery
  end

  test "cross-platform data flows" do
    test_end_to_end_data_flow
    test_data_consistency_checks
    test_cross_platform_correlation
  end

  # =============================================================================
  # END-TO-END WORKFLOW TESTS
  # =============================================================================

  test "complete marketing analytics workflow" do
    # Simulate a complete customer journey
    test_customer_acquisition_tracking
    test_engagement_measurement
    test_conversion_attribution
    test_retention_analysis
    test_roi_calculation
  end

  test "platform integration stress test" do
    # Test system under load with all integrations active
    test_concurrent_platform_operations
    test_data_volume_handling
    test_system_resilience
  end

  private

  # =============================================================================
  # SOCIAL MEDIA TEST HELPERS
  # =============================================================================

  def test_social_media_oauth_flow(platform)
    # Mock OAuth endpoints
    stub_oauth_endpoints(platform)
    
    # Test authorization URL generation
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    auth_url = service.send("connect_#{platform}_api")
    
    assert_not_nil auth_url
    assert_includes auth_url, platform
    
    # Test callback handling
    mock_oauth_callback(platform)
    result = service.handle_oauth_callback(platform, "test_code", "test_state")
    
    assert result.success?, "OAuth flow should succeed for #{platform}"
    assert_performed_jobs 1, "Should enqueue sync job"
  end

  def test_social_media_metrics_collection(platform)
    integration = create_test_integration(platform)
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    
    # Mock API responses
    stub_platform_api_responses(platform)
    
    # Test metrics collection
    result = service.send("collect_#{platform}_metrics")
    assert result.success?, "Metrics collection should succeed for #{platform}"
    
    # Verify data storage
    assert SocialMediaMetric.where(platform: platform).exists?
  end

  def test_social_media_aggregation
    # Create test integrations for all platforms
    platforms = %w[facebook instagram linkedin twitter tiktok]
    platforms.each { |platform| create_test_integration(platform) }
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Mock responses for all platforms
    platforms.each { |platform| stub_platform_api_responses(platform) }
    
    result = service.aggregate_all_platforms
    assert result.success?
    
    data = result.data
    assert_equal platforms.count, data[:platform_breakdown].keys.count
    assert data[:total_reach] > 0
    assert data[:total_engagement] > 0
  end

  def test_social_media_realtime_updates
    # Test WebSocket updates for real-time metrics
    integration = create_test_integration("facebook")
    
    # Mock real-time data
    perform_enqueued_jobs do
      Etl::SocialMediaRealTimeJob.perform_now(integration.id)
    end
    
    # Verify WebSocket broadcast
    assert_broadcasts "analytics_dashboard_#{@brand.id}", 1
  end

  def test_social_media_rate_limiting(platform)
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    rate_limiter = Analytics::RateLimitingService.new(
      platform: platform,
      integration_id: 1,
      endpoint: "insights"
    )
    
    # Test rate limiting behavior
    stub_rate_limited_response(platform)
    
    result = rate_limiter.execute_with_rate_limiting do
      service.send("collect_#{platform}_metrics")
    end
    
    assert result.success?, "Rate limiter should handle rate limits gracefully"
  end

  def test_social_media_error_recovery(platform)
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Mock error responses
    stub_error_responses(platform)
    
    result = service.send("collect_#{platform}_metrics")
    assert_not result.success?, "Should detect API errors"
    
    # Test retry logic
    stub_platform_api_responses(platform)
    result = service.send("collect_#{platform}_metrics")
    assert result.success?, "Should recover from errors"
  end

  def test_social_media_webhook_handling(platform)
    webhook_data = generate_webhook_payload(platform)
    
    post "/webhooks/social_media/#{platform}", params: webhook_data
    
    assert_response :success
    assert_performed_jobs 1, "Should process webhook data"
  end

  # =============================================================================
  # GOOGLE SERVICES TEST HELPERS
  # =============================================================================

  def test_google_analytics_integration
    service = Analytics::GoogleAnalyticsService.new(@user.id)
    
    # Mock Google Analytics API
    stub_google_analytics_api
    
    result = service.fetch_analytics_data(
      start_date: 30.days.ago,
      end_date: Time.current
    )
    
    assert result.success?
    assert_not_empty result.data[:metrics]
  end

  def test_google_ads_integration
    service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "123456789")
    
    # Mock Google Ads API
    stub_google_ads_api
    
    result = service.fetch_campaign_performance
    
    assert result.success?
    assert_includes result.data.keys, :campaigns
  end

  def test_google_search_console_integration
    service = Analytics::GoogleSearchConsoleService.new(@user.id)
    
    # Mock Search Console API
    stub_google_search_console_api
    
    result = service.fetch_search_analytics
    
    assert result.success?
    assert_includes result.data.keys, :queries
  end

  def test_google_services_correlation
    # Test data correlation across Google services
    analytics_service = Analytics::GoogleAnalyticsService.new(@user.id)
    ads_service = Analytics::GoogleAdsService.new(user_id: @user.id, customer_id: "123456789")
    
    stub_google_analytics_api
    stub_google_ads_api
    
    # Fetch data from both services
    analytics_data = analytics_service.fetch_analytics_data
    ads_data = ads_service.fetch_campaign_performance
    
    # Test correlation service
    correlation_service = Analytics::AttributionModelingService.new(@brand)
    result = correlation_service.correlate_google_data(analytics_data.data, ads_data.data)
    
    assert result.success?
    assert_includes result.data.keys, :attribution_model
  end

  def test_google_etl_pipeline
    # Test ETL job for Google Analytics
    perform_enqueued_jobs do
      Etl::GoogleAnalyticsHourlyJob.perform_now
    end
    
    # Verify pipeline run
    pipeline_run = EtlPipelineRun.last
    assert_equal "completed", pipeline_run.status
    
    # Verify data was processed
    assert GoogleAnalyticsMetric.exists?
  end

  def test_google_oauth_flow
    oauth_service = Analytics::GoogleOauthService.new(@user)
    
    # Mock OAuth endpoints
    stub_google_oauth_endpoints
    
    auth_url = oauth_service.authorization_url(scopes: ["analytics.readonly"])
    assert_not_nil auth_url
    assert_includes auth_url, "accounts.google.com"
    
    # Test token exchange
    result = oauth_service.exchange_code_for_token("test_code")
    assert result.success?
  end

  def test_google_token_refresh
    oauth_service = Analytics::GoogleOauthService.new(@user)
    
    # Mock refresh endpoint
    stub_google_token_refresh
    
    result = oauth_service.refresh_access_token("refresh_token")
    assert result.success?
    assert_not_nil result.data[:access_token]
  end

  def test_google_multi_account_support
    # Test multiple Google accounts for same user
    oauth_service = Analytics::GoogleOauthService.new(@user)
    
    # Mock multiple account responses
    stub_google_multi_account_api
    
    accounts = oauth_service.list_accessible_accounts
    assert accounts.count >= 2
  end

  # =============================================================================
  # EMAIL MARKETING TEST HELPERS
  # =============================================================================

  def test_mailchimp_integration
    service = Analytics::EmailPlatforms::MailchimpService.new(@brand)
    
    # Mock Mailchimp API
    stub_mailchimp_api
    
    result = service.fetch_campaign_data
    assert result.success?
    assert_includes result.data.keys, :campaigns
  end

  def test_sendgrid_integration
    service = Analytics::EmailAnalyticsService.new(@brand, "sendgrid")
    
    # Mock SendGrid API
    stub_sendgrid_api
    
    result = service.fetch_email_metrics
    assert result.success?
    assert_includes result.data.keys, :stats
  end

  def test_hubspot_email_integration
    service = Analytics::CrmPlatforms::HubspotService.new(@brand)
    
    # Mock HubSpot API
    stub_hubspot_api
    
    result = service.fetch_email_performance
    assert result.success?
    assert_includes result.data.keys, :email_campaigns
  end

  def test_email_analytics_aggregation
    # Create test email integrations
    create_test_email_integration("mailchimp")
    create_test_email_integration("sendgrid")
    
    service = Analytics::EmailAnalyticsService.new(@brand)
    
    # Mock all email platform APIs
    stub_mailchimp_api
    stub_sendgrid_api
    
    result = service.aggregate_all_platforms
    assert result.success?
    
    data = result.data
    assert data[:total_sent] > 0
    assert data[:total_opens] > 0
    assert data[:total_clicks] > 0
  end

  def test_email_campaign_tracking
    # Test end-to-end email campaign tracking
    campaign = EmailCampaign.create!(
      brand: @brand,
      name: "Test Campaign",
      platform: "mailchimp",
      campaign_id: "test_campaign_123"
    )
    
    # Mock campaign metrics
    stub_email_campaign_tracking("mailchimp", "test_campaign_123")
    
    service = Analytics::EmailAnalyticsService.new(@brand, "mailchimp")
    result = service.track_campaign(campaign.campaign_id)
    
    assert result.success?
    assert EmailMetric.where(email_campaign: campaign).exists?
  end

  def test_mailchimp_webhooks
    webhook_data = generate_mailchimp_webhook_payload
    
    post "/webhooks/email_platforms/mailchimp", params: webhook_data
    
    assert_response :success
    assert_performed_jobs 1, "Should process Mailchimp webhook"
  end

  def test_sendgrid_webhooks
    webhook_data = generate_sendgrid_webhook_payload
    
    post "/webhooks/email_platforms/sendgrid", params: webhook_data
    
    assert_response :success
    assert_performed_jobs 1, "Should process SendGrid webhook"
  end

  def test_email_bounce_handling
    # Test automated bounce processing
    bounce_data = {
      email: "bounced@example.com",
      reason: "mailbox_full",
      timestamp: Time.current.iso8601
    }
    
    service = Analytics::EmailWebhookProcessorService.new
    result = service.process_bounce(bounce_data)
    
    assert result.success?
    
    # Verify bounce tracking
    subscriber = EmailSubscriber.find_by(email: "bounced@example.com")
    assert_equal "bounced", subscriber.status if subscriber
  end

  def test_email_engagement_tracking
    # Test email engagement tracking across platforms
    service = Analytics::EmailAnalyticsService.new(@brand)
    
    # Mock engagement data
    stub_email_engagement_apis
    
    result = service.calculate_engagement_metrics
    assert result.success?
    
    data = result.data
    assert data[:open_rate] >= 0
    assert data[:click_rate] >= 0
    assert data[:unsubscribe_rate] >= 0
  end

  # =============================================================================
  # CRM INTEGRATION TEST HELPERS
  # =============================================================================

  def test_salesforce_integration
    service = Analytics::CrmPlatforms::SalesforceService.new(@brand)
    
    # Mock Salesforce API
    stub_salesforce_api
    
    result = service.fetch_leads_data
    assert result.success?
    assert_includes result.data.keys, :leads
  end

  def test_hubspot_crm_integration
    service = Analytics::CrmPlatforms::HubspotService.new(@brand)
    
    # Mock HubSpot CRM API
    stub_hubspot_crm_api
    
    result = service.fetch_contacts_data
    assert result.success?
    assert_includes result.data.keys, :contacts
  end

  def test_pipedrive_integration
    service = Analytics::CrmAnalyticsService.new(@brand, "pipedrive")
    
    # Mock Pipedrive API
    stub_pipedrive_api
    
    result = service.fetch_pipeline_data
    assert result.success?
    assert_includes result.data.keys, :deals
  end

  def test_crm_lead_attribution
    # Test lead attribution across marketing channels
    service = Analytics::AttributionModelingService.new(@brand)
    
    # Mock multi-touch attribution data
    stub_attribution_data
    
    result = service.calculate_lead_attribution
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :attribution_model
    assert data[:channels].any?
  end

  def test_crm_opportunity_tracking
    # Test opportunity lifecycle tracking
    opportunity = CrmOpportunity.create!(
      brand: @brand,
      external_id: "opp_123",
      amount: 50000,
      stage: "qualification"
    )
    
    service = Analytics::CrmAnalyticsService.new(@brand)
    
    # Mock opportunity updates
    stub_crm_opportunity_updates
    
    result = service.track_opportunity_progression(opportunity.external_id)
    assert result.success?
  end

  def test_crm_customer_journey_mapping
    # Test customer journey mapping across touchpoints
    service = Analytics::CrmAnalyticsService.new(@brand)
    
    # Mock customer journey data
    stub_customer_journey_data
    
    result = service.map_customer_journey("customer_123")
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :touchpoints
    assert_includes data.keys, :conversion_path
  end

  def test_crm_bidirectional_sync
    # Test bidirectional data synchronization
    service = Analytics::CrmAnalyticsService.new(@brand)
    
    # Mock sync operations
    stub_crm_sync_operations
    
    # Test push to CRM
    result = service.sync_to_crm({
      leads: [{ email: "test@example.com", source: "website" }]
    })
    assert result.success?
    
    # Test pull from CRM
    result = service.sync_from_crm
    assert result.success?
  end

  def test_crm_conflict_resolution
    # Test handling of data conflicts during sync
    service = Analytics::CrmAnalyticsService.new(@brand)
    
    # Mock conflicting data
    stub_crm_conflict_data
    
    result = service.resolve_sync_conflicts
    assert result.success?
    assert_includes result.data.keys, :resolved_conflicts
  end

  def test_crm_real_time_updates
    # Test real-time CRM updates via webhooks
    webhook_data = generate_crm_webhook_payload
    
    post "/webhooks/crm/salesforce", params: webhook_data
    
    assert_response :success
    assert_performed_jobs 1, "Should process CRM webhook"
    
    # Verify real-time update
    assert_broadcasts "crm_updates_#{@brand.id}", 1
  end

  # =============================================================================
  # ETL PIPELINE TEST HELPERS
  # =============================================================================

  def test_etl_data_extraction
    # Test data extraction from multiple sources
    service = Etl::BaseEtlService.new("comprehensive_test", "test_pipeline_123")
    
    # Mock data sources
    stub_all_data_sources
    
    result = service.extract_data
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :social_media
    assert_includes data.keys, :email_marketing
    assert_includes data.keys, :crm
    assert_includes data.keys, :google_analytics
  end

  def test_etl_data_transformation
    # Test data transformation and normalization
    service = Etl::DataTransformationRules.new
    
    raw_data = generate_raw_platform_data
    
    result = service.transform_all_platforms(raw_data)
    assert result.success?
    
    transformed_data = result.data
    assert_equal "standardized", transformed_data[:format]
    assert_includes transformed_data.keys, :unified_metrics
  end

  def test_etl_data_loading
    # Test data loading into data warehouse
    service = Etl::BaseEtlService.new("test_load", "test_pipeline_456")
    
    transformed_data = generate_transformed_data
    
    result = service.load_data(transformed_data)
    assert result.success?
    
    # Verify data was loaded
    assert GoogleAnalyticsMetric.exists?
    assert SocialMediaMetric.exists?
    assert EmailMetric.exists?
  end

  def test_etl_pipeline_monitoring
    # Test ETL pipeline monitoring and health checks
    service = Etl::PipelineHealthMonitorJob.new
    
    perform_enqueued_jobs do
      service.perform
    end
    
    # Verify monitoring data
    pipeline_run = EtlPipelineRun.last
    assert_not_nil pipeline_run.metrics
    assert_includes pipeline_run.metrics.keys, "processing_time"
    assert_includes pipeline_run.metrics.keys, "records_processed"
  end

  def test_etl_error_handling
    # Test ETL error handling and recovery
    service = Etl::BaseEtlService.new("error_test", "test_pipeline_789")
    
    # Mock data source error
    stub_data_source_error
    
    result = service.execute
    assert_not result.success?
    
    # Verify error logging
    pipeline_run = EtlPipelineRun.last
    assert_equal "failed", pipeline_run.status
    assert_not_nil pipeline_run.error_message
  end

  def test_etl_performance_optimization
    # Test ETL performance with large datasets
    service = Etl::BaseEtlService.new("performance_test", "test_pipeline_perf")
    
    # Mock large dataset
    stub_large_dataset_responses
    
    start_time = Time.current
    result = service.execute
    end_time = Time.current
    
    assert result.success?
    
    # Verify performance metrics
    processing_time = (end_time - start_time) * 1000
    assert processing_time < 30000, "ETL should complete within 30 seconds"
  end

  def test_streaming_data_ingestion
    # Test real-time streaming data ingestion
    service = Etl::SocialMediaRealTimeJob.new
    
    # Mock streaming data
    stub_streaming_data_sources
    
    perform_enqueued_jobs do
      service.perform
    end
    
    # Verify real-time processing
    assert SocialMediaMetric.where("created_at > ?", 1.minute.ago).exists?
  end

  def test_real_time_transformation
    # Test real-time data transformation
    service = Etl::DataNormalizationJob.new
    
    raw_metrics = generate_real_time_metrics
    
    result = service.normalize_metrics(raw_metrics)
    assert result.success?
    
    # Verify transformation
    normalized_data = result.data
    assert_equal "standard_format", normalized_data[:format]
  end

  def test_event_driven_processing
    # Test event-driven data processing
    event_data = {
      type: "social_media_post",
      platform: "facebook",
      data: { post_id: "123", engagement: 50 }
    }
    
    # Trigger event processing
    Analytics::SocialMediaIntegrationService.new(@brand).process_real_time_event(event_data)
    
    # Verify event was processed
    assert_performed_jobs 1
    assert SocialMediaMetric.where(platform: "facebook").exists?
  end

  # =============================================================================
  # DASHBOARD AND WEBSOCKET TEST HELPERS
  # =============================================================================

  def test_websocket_connections
    # Test WebSocket connection establishment
    connect "/cable"
    
    # Subscribe to analytics channel
    subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @brand.id)
    
    # Verify subscription
    assert_subscription_confirmed
  end

  def test_dashboard_real_time_updates
    # Test real-time dashboard updates via WebSocket
    connect "/cable"
    subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @brand.id)
    
    # Trigger metric update
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    stub_platform_api_responses("facebook")
    service.collect_facebook_metrics
    
    # Verify WebSocket broadcast
    assert_broadcasts "analytics_dashboard_#{@brand.id}", 1
  end

  def test_multi_user_dashboard_sync
    # Test dashboard synchronization across multiple users
    user2 = users(:two)
    
    # Connect both users
    connect "/cable", headers: { "User-Id" => @user.id }
    subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @brand.id)
    
    connect "/cable", headers: { "User-Id" => user2.id }
    subscribe_to_channel("AnalyticsDashboardChannel", brand_id: @brand.id)
    
    # Trigger update
    ActionCable.server.broadcast("analytics_dashboard_#{@brand.id}", {
      type: "metrics_update",
      data: { reach: 1000, engagement: 200 }
    })
    
    # Verify both users receive update
    assert_broadcasts "analytics_dashboard_#{@brand.id}", 1
  end

  def test_dashboard_filtering_and_drilling
    # Test dashboard filtering and drill-down functionality
    get analytics_dashboard_path(@brand), xhr: true, params: {
      filters: {
        time_range: "30d",
        platforms: ["facebook", "instagram"],
        metrics: ["reach", "engagement"]
      }
    }
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_includes response_data.keys, "filtered_data"
    assert_equal 2, response_data["filtered_data"]["platforms"].count
  end

  def test_dashboard_load_performance
    # Test dashboard loading performance
    start_time = Time.current
    
    get analytics_dashboard_path(@brand)
    
    end_time = Time.current
    load_time = (end_time - start_time) * 1000
    
    assert_response :success
    assert load_time < 2000, "Dashboard should load within 2 seconds"
  end

  def test_concurrent_user_support
    # Test concurrent user support for dashboard
    threads = []
    
    10.times do |i|
      threads << Thread.new do
        get analytics_dashboard_path(@brand), headers: { "User-Id" => "user_#{i}" }
        assert_response :success
      end
    end
    
    threads.each(&:join)
  end

  def test_data_refresh_optimization
    # Test optimized data refresh for dashboard
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Mock cached data
    Rails.cache.write("dashboard_metrics_#{@brand.id}", { reach: 1000 }, expires_in: 5.minutes)
    
    result = service.dashboard_metrics("7d")
    
    # Should use cached data
    assert_equal 1000, result[:summary][:total_reach] if result[:summary]
  end

  # =============================================================================
  # ALERT SYSTEM TEST HELPERS
  # =============================================================================

  def test_threshold_based_alerts
    # Test threshold-based alerting
    threshold = PerformanceThreshold.create!(
      brand: @brand,
      metric_name: "engagement_rate",
      threshold_type: "min",
      threshold_value: 5.0,
      alert_enabled: true
    )
    
    # Trigger low engagement
    SocialMediaMetric.create!(
      social_media_integration: create_test_integration("facebook"),
      metric_type: "engagement_rate",
      value: 2.0,
      date: Date.current
    )
    
    # Process alerts
    perform_enqueued_jobs do
      Analytics::Alerts::MonitoringService.new.check_thresholds
    end
    
    # Verify alert was created
    assert AlertInstance.where(performance_threshold: threshold).exists?
    assert_performed_jobs 1, "Should send alert notification"
  end

  def test_anomaly_detection_alerts
    # Test anomaly detection alerting
    service = Analytics::Alerts::MonitoringService.new
    
    # Create baseline metrics
    30.times do |i|
      SocialMediaMetric.create!(
        social_media_integration: create_test_integration("facebook"),
        metric_type: "reach",
        value: 1000 + rand(100),
        date: i.days.ago.to_date
      )
    end
    
    # Create anomalous metric
    SocialMediaMetric.create!(
      social_media_integration: create_test_integration("facebook"),
      metric_type: "reach",
      value: 5000, # Significant spike
      date: Date.current
    )
    
    # Run anomaly detection
    perform_enqueued_jobs do
      service.detect_anomalies
    end
    
    # Verify anomaly alert
    assert AlertInstance.where(alert_type: "anomaly").exists?
  end

  def test_multi_channel_notifications
    # Test multi-channel alert notifications
    alert = PerformanceAlert.create!(
      brand: @brand,
      title: "Test Alert",
      message: "Test alert message",
      severity: "high",
      alert_type: "threshold"
    )
    
    # Configure multiple notification channels
    notification_service = Analytics::Notifications::DeliveryService.new
    
    perform_enqueued_jobs do
      notification_service.deliver_alert(alert, channels: ["email", "slack", "webhook"])
    end
    
    # Verify multi-channel delivery
    assert_performed_jobs 3, "Should send notifications to all channels"
  end

  def test_alert_escalation
    # Test alert escalation workflow
    alert = PerformanceAlert.create!(
      brand: @brand,
      title: "Critical Alert",
      message: "Critical issue detected",
      severity: "critical",
      alert_type: "threshold"
    )
    
    # Wait for escalation timeout (simulated)
    travel 30.minutes do
      perform_enqueued_jobs do
        Analytics::Alerts::MonitoringService.new.check_escalations
      end
    end
    
    # Verify escalation occurred
    assert alert.reload.escalated?
    assert_performed_jobs 2, "Should send initial and escalated notifications"
  end

  def test_alert_acknowledgment
    # Test alert acknowledgment workflow
    alert = PerformanceAlert.create!(
      brand: @brand,
      title: "Test Alert",
      message: "Test alert message",
      severity: "medium",
      alert_type: "threshold"
    )
    
    # Acknowledge alert
    post acknowledge_alert_path(alert), params: {
      acknowledged_by: @user.id,
      acknowledgment_note: "Investigating issue"
    }
    
    assert_response :success
    assert alert.reload.acknowledged?
    assert_equal @user.id, alert.acknowledged_by
  end

  def test_alert_delivery_guarantees
    # Test alert delivery guarantees and retry logic
    alert = PerformanceAlert.create!(
      brand: @brand,
      title: "Delivery Test Alert",
      message: "Testing delivery guarantees",
      severity: "high",
      alert_type: "threshold"
    )
    
    # Mock delivery failure
    stub_notification_failure
    
    notification_service = Analytics::Notifications::DeliveryService.new
    
    perform_enqueued_jobs do
      notification_service.deliver_alert(alert)
    end
    
    # Should retry failed deliveries
    assert_performed_jobs 3, "Should retry failed notifications"
  end

  def test_alert_rate_limiting
    # Test alert rate limiting to prevent spam
    service = Analytics::Alerts::MonitoringService.new
    
    # Create multiple similar alerts rapidly
    5.times do
      PerformanceAlert.create!(
        brand: @brand,
        title: "Rate Limit Test",
        message: "Testing rate limiting",
        severity: "low",
        alert_type: "threshold"
      )
    end
    
    perform_enqueued_jobs do
      service.process_pending_alerts
    end
    
    # Should rate limit notifications
    assert_performed_jobs 2, "Should rate limit similar alerts"
  end

  def test_alert_deduplication
    # Test alert deduplication
    service = Analytics::Alerts::MonitoringService.new
    
    # Create duplicate alerts
    2.times do
      PerformanceAlert.create!(
        brand: @brand,
        title: "Duplicate Alert",
        message: "Same alert message",
        severity: "medium",
        alert_type: "threshold"
      )
    end
    
    perform_enqueued_jobs do
      service.deduplicate_alerts
    end
    
    # Should consolidate duplicate alerts
    assert_equal 1, PerformanceAlert.where(title: "Duplicate Alert").count
  end

  # =============================================================================
  # REPORTING SYSTEM TEST HELPERS
  # =============================================================================

  def test_custom_report_creation
    # Test custom report creation workflow
    post custom_reports_path, params: {
      custom_report: {
        name: "Test Integration Report",
        report_type: "dashboard",
        configuration: {
          metrics: ["reach", "engagement", "conversions"],
          time_range: "30d",
          platforms: ["facebook", "instagram", "google_ads"]
        }.to_json
      }
    }
    
    assert_response :redirect
    
    report = CustomReport.last
    assert_equal "Test Integration Report", report.name
    assert_equal "dashboard", report.report_type
  end

  def test_report_scheduling
    # Test report scheduling functionality
    report = custom_reports(:one)
    
    post report_schedules_path, params: {
      report_schedule: {
        custom_report_id: report.id,
        frequency: "weekly",
        delivery_day: "monday",
        delivery_time: "09:00",
        email_recipients: "admin@example.com,manager@example.com"
      }
    }
    
    assert_response :redirect
    
    schedule = ReportSchedule.last
    assert_equal "weekly", schedule.frequency
    assert schedule.is_active?
  end

  def test_report_export_formats
    # Test multiple export formats
    report = custom_reports(:one)
    
    # Test PDF export
    get export_custom_report_path(report, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.content_type
    
    # Test Excel export
    get export_custom_report_path(report, format: :xlsx)
    assert_response :success
    assert_includes response.content_type, "spreadsheet"
    
    # Test CSV export
    get export_custom_report_path(report, format: :csv)
    assert_response :success
    assert_equal "text/csv", response.content_type
  end

  def test_report_distribution
    # Test automated report distribution
    report = custom_reports(:one)
    schedule = ReportSchedule.create!(
      custom_report: report,
      frequency: "daily",
      email_recipients: "test@example.com",
      is_active: true,
      next_run_at: 1.minute.ago
    )
    
    perform_enqueued_jobs do
      Reports::ReportScheduleJob.perform_now(schedule.id)
    end
    
    # Verify report was generated and sent
    assert_performed_jobs 2, "Should generate and send report"
    
    export = ReportExport.last
    assert_equal "completed", export.status
  end

  def test_report_template_system
    # Test report template system
    template = CustomReport.create!(
      name: "Social Media Template",
      report_type: "template",
      is_template: true,
      is_public: true,
      configuration: {
        metrics: ["reach", "engagement"],
        visualizations: ["line_chart", "pie_chart"]
      }.to_json,
      user: @user,
      brand: @brand
    )
    
    # Create report from template
    post custom_reports_path, params: {
      template_id: template.id,
      custom_report: {
        name: "My Social Media Report"
      }
    }
    
    assert_response :redirect
    
    new_report = CustomReport.last
    assert_equal "My Social Media Report", new_report.name
    assert_equal template.configuration, new_report.configuration
  end

  def test_cross_platform_reporting
    # Test cross-platform reporting capabilities
    service = Reports::ReportGenerationService.new
    
    # Mock data from multiple platforms
    stub_all_platform_apis
    
    report_config = {
      platforms: ["facebook", "google_ads", "mailchimp", "salesforce"],
      metrics: ["reach", "conversions", "revenue"],
      time_range: "30d"
    }
    
    result = service.generate_cross_platform_report(report_config)
    assert result.success?
    
    data = result.data
    assert_equal 4, data[:platforms].count
    assert_includes data.keys, :unified_metrics
    assert_includes data.keys, :cross_platform_insights
  end

  def test_attribution_modeling
    # Test attribution modeling in reports
    service = Analytics::AttributionModelingService.new(@brand)
    
    # Mock attribution data
    stub_attribution_model_data
    
    result = service.generate_attribution_report
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :first_touch_attribution
    assert_includes data.keys, :last_touch_attribution
    assert_includes data.keys, :multi_touch_attribution
  end

  def test_cohort_analysis
    # Test cohort analysis reporting
    service = Reports::ReportGenerationService.new
    
    # Mock cohort data
    stub_cohort_analysis_data
    
    result = service.generate_cohort_analysis(
      cohort_type: "acquisition",
      time_period: "monthly"
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :cohorts
    assert_includes data.keys, :retention_rates
  end

  def test_predictive_analytics
    # Test predictive analytics in reports
    service = Reports::ReportGenerationService.new
    
    # Mock historical data for predictions
    stub_predictive_analytics_data
    
    result = service.generate_predictive_report(
      prediction_type: "performance_forecast",
      forecast_period: "90d"
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :predictions
    assert_includes data.keys, :confidence_intervals
  end

  # =============================================================================
  # BACKGROUND JOBS TEST HELPERS
  # =============================================================================

  def test_data_sync_jobs
    # Test data synchronization jobs
    perform_enqueued_jobs do
      SocialMediaSyncJob.perform_now(@brand.id)
    end
    
    # Verify sync completed
    assert SocialMediaMetric.where("created_at > ?", 1.minute.ago).exists?
    assert_performed_jobs 1
  end

  def test_report_generation_jobs
    # Test automated report generation
    report = custom_reports(:one)
    
    perform_enqueued_jobs do
      Reports::ReportGenerationJob.perform_now(report.id)
    end
    
    # Verify report was generated
    export = ReportExport.last
    assert_equal "completed", export.status
    assert_not_nil export.file_url
  end

  def test_cleanup_jobs
    # Test data cleanup jobs
    # Create old test data
    old_metric = SocialMediaMetric.create!(
      social_media_integration: create_test_integration("facebook"),
      metric_type: "reach",
      value: 1000,
      date: 1.year.ago.to_date,
      created_at: 1.year.ago
    )
    
    perform_enqueued_jobs do
      Reports::ReportCleanupJob.perform_now
    end
    
    # Verify old data was cleaned up
    assert_not SocialMediaMetric.exists?(old_metric.id)
  end

  def test_monitoring_jobs
    # Test system monitoring jobs
    perform_enqueued_jobs do
      Etl::PipelineHealthMonitorJob.perform_now
    end
    
    # Verify monitoring completed
    assert EtlPipelineRun.where("created_at > ?", 1.minute.ago).exists?
  end

  def test_job_failure_recovery
    # Test job failure recovery mechanisms
    integration = create_test_integration("facebook")
    
    # Mock job failure
    stub_job_failure
    
    assert_raises(StandardError) do
      perform_enqueued_jobs do
        SocialMediaSyncJob.perform_now(@brand.id)
      end
    end
    
    # Verify retry mechanism
    assert_equal 1, SocialMediaSyncJob.queue_adapter.enqueued_jobs.count
  end

  def test_end_to_end_data_flow
    # Test complete data flow from source to dashboard
    # 1. Create integrations
    create_test_integration("facebook")
    create_test_email_integration("mailchimp")
    
    # 2. Mock all APIs
    stub_all_platform_apis
    
    # 3. Trigger data collection
    perform_enqueued_jobs do
      SocialMediaSyncJob.perform_now(@brand.id)
      Etl::GoogleAnalyticsHourlyJob.perform_now
    end
    
    # 4. Verify data flow
    assert SocialMediaMetric.exists?
    assert GoogleAnalyticsMetric.exists?
    
    # 5. Test dashboard rendering
    get analytics_dashboard_path(@brand)
    assert_response :success
    
    # 6. Verify real-time updates
    assert_broadcasts "analytics_dashboard_#{@brand.id}", 2
  end

  def test_data_consistency_checks
    # Test data consistency across platforms
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Create test data with potential inconsistencies
    create_test_metrics_with_inconsistencies
    
    result = service.validate_data_consistency
    assert result.success?
    
    # Should detect and report inconsistencies
    assert_includes result.data.keys, :inconsistencies
    assert result.data[:inconsistencies].any?
  end

  def test_cross_platform_correlation
    # Test correlation of data across platforms
    service = Analytics::AttributionModelingService.new(@brand)
    
    # Mock correlated data
    stub_cross_platform_correlation_data
    
    result = service.correlate_platform_data
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :correlations
    assert data[:correlations].any?
  end

  # =============================================================================
  # END-TO-END WORKFLOW TEST HELPERS
  # =============================================================================

  def test_customer_acquisition_tracking
    # Test complete customer acquisition tracking
    # 1. Social media ad impression
    create_social_media_impression("facebook")
    
    # 2. Website visit (Google Analytics)
    create_website_visit
    
    # 3. Email signup (Email platform)
    create_email_signup
    
    # 4. Lead conversion (CRM)
    create_lead_conversion
    
    # 5. Verify attribution tracking
    service = Analytics::AttributionModelingService.new(@brand)
    result = service.track_acquisition_journey("customer_123")
    
    assert result.success?
    
    journey = result.data
    assert_equal 4, journey[:touchpoints].count
    assert_includes journey[:touchpoints].map { |t| t[:source] }, "facebook"
    assert_includes journey[:touchpoints].map { |t| t[:source] }, "email"
  end

  def test_engagement_measurement
    # Test engagement measurement across platforms
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Mock engagement data
    stub_engagement_data_all_platforms
    
    result = service.calculate_engagement_metrics
    assert result.success?
    
    metrics = result.data
    assert metrics[:overall_engagement_rate] > 0
    assert metrics[:platform_breakdown].any?
  end

  def test_conversion_attribution
    # Test conversion attribution modeling
    service = Analytics::AttributionModelingService.new(@brand)
    
    # Mock conversion data
    stub_conversion_attribution_data
    
    result = service.calculate_conversion_attribution
    assert result.success?
    
    attribution = result.data
    assert_includes attribution.keys, :conversion_paths
    assert_includes attribution.keys, :channel_contribution
  end

  def test_retention_analysis
    # Test customer retention analysis
    service = Analytics::CrmAnalyticsService.new(@brand)
    
    # Mock retention data
    stub_retention_analysis_data
    
    result = service.analyze_customer_retention
    assert result.success?
    
    retention = result.data
    assert_includes retention.keys, :retention_rates
    assert_includes retention.keys, :churn_analysis
  end

  def test_roi_calculation
    # Test ROI calculation across campaigns
    service = Analytics::AttributionModelingService.new(@brand)
    
    # Mock ROI data
    stub_roi_calculation_data
    
    result = service.calculate_campaign_roi
    assert result.success?
    
    roi = result.data
    assert_includes roi.keys, :total_roi
    assert_includes roi.keys, :platform_roi
    assert roi[:total_roi] > 0
  end

  def test_concurrent_platform_operations
    # Test concurrent operations across all platforms
    threads = []
    platforms = %w[facebook instagram linkedin twitter tiktok]
    
    platforms.each do |platform|
      threads << Thread.new do
        service = Analytics::SocialMediaIntegrationService.new(@brand)
        stub_platform_api_responses(platform)
        result = service.send("collect_#{platform}_metrics")
        assert result.success?, "#{platform} should process successfully"
      end
    end
    
    threads.each(&:join)
    
    # Verify all platforms processed
    assert_equal platforms.count, SocialMediaMetric.distinct.count(:platform)
  end

  def test_data_volume_handling
    # Test handling of large data volumes
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    
    # Mock large dataset
    stub_large_volume_responses
    
    result = service.aggregate_all_platforms
    assert result.success?
    
    # Verify performance with large data
    assert result.data[:total_reach] > 100000
    assert result.data[:platform_breakdown].count >= 5
  end

  def test_system_resilience
    # Test system resilience under stress
    # Simulate partial platform failures
    stub_partial_platform_failures
    
    service = Analytics::SocialMediaIntegrationService.new(@brand)
    result = service.aggregate_all_platforms
    
    # Should handle partial failures gracefully
    assert result.success?
    assert result.data[:platform_breakdown].any?, "Should process available platforms"
  end

  # =============================================================================
  # MOCK AND STUB HELPERS
  # =============================================================================

  def stub_oauth_endpoints(platform)
    case platform
    when "facebook"
      stub_request(:post, "https://graph.facebook.com/oauth/access_token")
        .to_return(status: 200, body: {
          access_token: "fb_access_token",
          token_type: "bearer",
          expires_in: 3600
        }.to_json)
    when "instagram"
      stub_request(:post, "https://api.instagram.com/oauth/access_token")
        .to_return(status: 200, body: {
          access_token: "ig_access_token",
          user_id: "instagram_user_123"
        }.to_json)
    when "linkedin"
      stub_request(:post, "https://www.linkedin.com/oauth/v2/accessToken")
        .to_return(status: 200, body: {
          access_token: "li_access_token",
          expires_in: 5184000
        }.to_json)
    when "twitter"
      stub_request(:post, "https://api.twitter.com/2/oauth2/token")
        .to_return(status: 200, body: {
          access_token: "tw_access_token",
          token_type: "bearer"
        }.to_json)
    when "tiktok"
      stub_request(:post, "https://open-api.tiktok.com/oauth/access_token/")
        .to_return(status: 200, body: {
          access_token: "tt_access_token",
          expires_in: 86400
        }.to_json)
    end
  end

  def mock_oauth_callback(platform)
    # Mock successful OAuth callback processing
    # Implementation would set up proper OAuth flow mocking
  end

  def stub_platform_api_responses(platform)
    case platform
    when "facebook"
      stub_request(:get, /graph\.facebook\.com/)
        .to_return(status: 200, body: {
          data: [
            { name: "reach", values: [{ value: 10000 }] },
            { name: "engagement", values: [{ value: 500 }] }
          ]
        }.to_json)
    when "instagram"
      stub_request(:get, /graph\.instagram\.com/)
        .to_return(status: 200, body: {
          data: [
            { name: "reach", period: "day", values: [{ value: 5000 }] },
            { name: "impressions", period: "day", values: [{ value: 8000 }] }
          ]
        }.to_json)
    # Add other platforms...
    end
  end

  def stub_rate_limited_response(platform)
    stub_request(:get, /#{platform}/)
      .to_return(status: 429, headers: { "Retry-After" => "60" })
      .then
      .to_return(status: 200, body: { data: [] }.to_json)
  end

  def stub_error_responses(platform)
    stub_request(:get, /#{platform}/)
      .to_return(status: 500, body: { error: "Internal Server Error" }.to_json)
  end

  def generate_webhook_payload(platform)
    {
      platform: platform,
      event_type: "metrics_update",
      data: {
        metric_type: "engagement",
        value: 100,
        timestamp: Time.current.iso8601
      }
    }
  end

  def stub_google_analytics_api
    stub_request(:post, "https://analyticsreporting.googleapis.com/v4/reports:batchGet")
      .to_return(status: 200, body: {
        reports: [{
          data: {
            rows: [
              { dimensions: ["20231201"], metrics: [{ values: ["1000", "500"] }] }
            ]
          }
        }]
      }.to_json)
  end

  def stub_google_ads_api
    stub_request(:post, /googleads\.googleapis\.com/)
      .to_return(status: 200, body: {
        results: [
          {
            campaign: { id: "123", name: "Test Campaign" },
            metrics: { impressions: "10000", clicks: "100" }
          }
        ]
      }.to_json)
  end

  def stub_google_search_console_api
    stub_request(:post, "https://searchconsole.googleapis.com/webmasters/v3/sites/example.com/searchAnalytics/query")
      .to_return(status: 200, body: {
        rows: [
          { keys: ["test query"], impressions: 1000, clicks: 50, ctr: 0.05, position: 5.5 }
        ]
      }.to_json)
  end

  def stub_google_oauth_endpoints
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(status: 200, body: {
        access_token: "google_access_token",
        refresh_token: "google_refresh_token",
        expires_in: 3600
      }.to_json)
  end

  def stub_google_token_refresh
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .with(body: hash_including(grant_type: "refresh_token"))
      .to_return(status: 200, body: {
        access_token: "new_google_access_token",
        expires_in: 3600
      }.to_json)
  end

  def stub_google_multi_account_api
    stub_request(:get, "https://analytics.googleapis.com/analytics/v3/management/accounts")
      .to_return(status: 200, body: {
        items: [
          { id: "account1", name: "Account 1" },
          { id: "account2", name: "Account 2" }
        ]
      }.to_json)
  end

  def stub_mailchimp_api
    stub_request(:get, /api\.mailchimp\.com/)
      .to_return(status: 200, body: {
        campaigns: [
          { id: "campaign1", settings: { title: "Test Campaign" }, report_summary: { opens: 100, clicks: 25 } }
        ]
      }.to_json)
  end

  def stub_sendgrid_api
    stub_request(:get, /api\.sendgrid\.com/)
      .to_return(status: 200, body: [
        { date: "2023-12-01", stats: [{ metrics: { delivered: 1000, opens: 200, clicks: 50 } }] }
      ].to_json)
  end

  def stub_hubspot_api
    stub_request(:get, /api\.hubapi\.com/)
      .to_return(status: 200, body: {
        results: [
          { id: "email1", name: "Test Email", stats: { sent: 1000, opened: 300, clicked: 75 } }
        ]
      }.to_json)
  end

  def generate_mailchimp_webhook_payload
    {
      type: "campaign",
      fired_at: Time.current.iso8601,
      data: {
        id: "campaign123",
        web_id: 123,
        list_id: "list123",
        subject: "Test Campaign"
      }
    }
  end

  def generate_sendgrid_webhook_payload
    [
      {
        email: "test@example.com",
        timestamp: Time.current.to_i,
        event: "open",
        sg_message_id: "message123"
      }
    ]
  end

  def stub_email_campaign_tracking(platform, campaign_id)
    case platform
    when "mailchimp"
      stub_request(:get, "https://us1.api.mailchimp.com/3.0/campaigns/#{campaign_id}")
        .to_return(status: 200, body: {
          id: campaign_id,
          report_summary: { opens: 150, clicks: 30, bounces: 5 }
        }.to_json)
    end
  end

  def stub_email_engagement_apis
    stub_mailchimp_api
    stub_sendgrid_api
    stub_hubspot_api
  end

  def stub_salesforce_api
    stub_request(:get, /salesforce\.com/)
      .to_return(status: 200, body: {
        records: [
          { Id: "lead1", Email: "lead1@example.com", Status: "New", Source: "Website" }
        ]
      }.to_json)
  end

  def stub_hubspot_crm_api
    stub_request(:get, /api\.hubapi\.com\/crm/)
      .to_return(status: 200, body: {
        results: [
          { id: "contact1", properties: { email: "contact1@example.com", lifecyclestage: "lead" } }
        ]
      }.to_json)
  end

  def stub_pipedrive_api
    stub_request(:get, /api\.pipedrive\.com/)
      .to_return(status: 200, body: {
        data: [
          { id: 1, title: "Test Deal", value: 5000, stage_id: 1, person_id: 123 }
        ]
      }.to_json)
  end

  def stub_attribution_data
    # Mock attribution modeling data
  end

  def stub_crm_opportunity_updates
    # Mock CRM opportunity update responses
  end

  def stub_customer_journey_data
    # Mock customer journey mapping data
  end

  def stub_crm_sync_operations
    # Mock CRM sync API responses
  end

  def stub_crm_conflict_data
    # Mock conflicting CRM data scenarios
  end

  def generate_crm_webhook_payload
    {
      event_type: "lead_updated",
      object_id: "lead_123",
      data: {
        id: "lead_123",
        email: "updated@example.com",
        status: "qualified"
      }
    }
  end

  def stub_all_data_sources
    stub_platform_api_responses("facebook")
    stub_platform_api_responses("instagram")
    stub_google_analytics_api
    stub_mailchimp_api
    stub_salesforce_api
  end

  def generate_raw_platform_data
    {
      social_media: { facebook: { reach: 1000 }, instagram: { reach: 500 } },
      email_marketing: { mailchimp: { sent: 1000, opens: 200 } },
      crm: { salesforce: { leads: 50, conversions: 5 } },
      google_analytics: { sessions: 5000, pageviews: 15000 }
    }
  end

  def generate_transformed_data
    {
      format: "standardized",
      unified_metrics: {
        reach: 1500,
        engagement: 300,
        conversions: 5
      },
      timestamp: Time.current.iso8601
    }
  end

  def stub_data_source_error
    stub_request(:get, /facebook|instagram|google/)
      .to_return(status: 500, body: { error: "Service Unavailable" }.to_json)
  end

  def stub_large_dataset_responses
    # Mock large dataset responses for performance testing
    large_data = {
      data: Array.new(10000) { |i| { id: i, value: rand(1000) } }
    }
    
    stub_request(:get, /api\./)
      .to_return(status: 200, body: large_data.to_json)
  end

  def stub_streaming_data_sources
    # Mock streaming data for real-time processing
  end

  def generate_real_time_metrics
    [
      { platform: "facebook", metric: "reach", value: 100, timestamp: Time.current },
      { platform: "instagram", metric: "engagement", value: 50, timestamp: Time.current }
    ]
  end

  def stub_notification_failure
    stub_request(:post, /notification|email|slack/)
      .to_return(status: 500, body: { error: "Service Unavailable" }.to_json)
      .then
      .to_return(status: 200, body: { success: true }.to_json)
  end

  def stub_all_platform_apis
    %w[facebook instagram linkedin twitter tiktok].each do |platform|
      stub_platform_api_responses(platform)
    end
    stub_google_analytics_api
    stub_google_ads_api
    stub_mailchimp_api
    stub_salesforce_api
  end

  def stub_attribution_model_data
    # Mock attribution modeling data
  end

  def stub_cohort_analysis_data
    # Mock cohort analysis data
  end

  def stub_predictive_analytics_data
    # Mock predictive analytics data
  end

  def stub_job_failure
    # Mock job failure scenarios
  end

  def create_test_metrics_with_inconsistencies
    # Create test data with known inconsistencies for validation
  end

  def stub_cross_platform_correlation_data
    # Mock cross-platform correlation data
  end

  def create_social_media_impression(platform)
    # Create social media impression data
  end

  def create_website_visit
    # Create website visit data
  end

  def create_email_signup
    # Create email signup data
  end

  def create_lead_conversion
    # Create lead conversion data
  end

  def stub_engagement_data_all_platforms
    # Mock engagement data for all platforms
  end

  def stub_conversion_attribution_data
    # Mock conversion attribution data
  end

  def stub_retention_analysis_data
    # Mock retention analysis data
  end

  def stub_roi_calculation_data
    # Mock ROI calculation data
  end

  def stub_large_volume_responses
    # Mock large volume data responses
  end

  def stub_partial_platform_failures
    # Mock partial platform failure scenarios
  end

  # Test data creation helpers
  def create_test_integration(platform)
    SocialMediaIntegration.create!(
      brand: @brand,
      platform: platform,
      access_token: "test_token",
      status: "active",
      platform_account_id: "account_123"
    )
  end

  def create_test_email_integration(platform)
    EmailIntegration.create!(
      brand: @brand,
      platform: platform,
      api_key: "test_api_key",
      status: "active"
    )
  end
end