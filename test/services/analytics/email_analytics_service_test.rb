# frozen_string_literal: true

require "test_helper"

class Analytics::EmailAnalyticsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @brand = brands(:acme_corp)
    @brand.update!(user: @user)
    
    @email_integration = EmailIntegration.create!(
      brand: @brand,
      platform: "mailchimp",
      status: "active",
      access_token: "test_access_token",
      platform_account_id: "test_account_123",
      account_name: "Test Account",
      api_endpoint: "https://us1.api.mailchimp.com/3.0"
    )
    
    @analytics_service = Analytics::EmailAnalyticsService.new(@email_integration)
  end

  test "initializes with integration" do
    assert_equal @email_integration, @analytics_service.integration
  end

  test "campaign performance report returns structured data" do
    # Create test campaign with metrics
    campaign = @email_integration.email_campaigns.create!(
      platform_campaign_id: "campaign_123",
      name: "Test Campaign",
      status: "sent",
      total_recipients: 1000
    )

    campaign.email_metrics.create!(
      metric_type: "daily",
      metric_date: Date.current,
      opens: 250,
      clicks: 50,
      bounces: 10,
      unsubscribes: 5,
      sent: 1000,
      delivered: 990
    )

    result = @analytics_service.campaign_performance_report

    assert result.success?
    assert_includes result.data.keys, :campaigns
    assert_includes result.data.keys, :aggregate_metrics
    assert_includes result.data.keys, :date_range

    campaign_data = result.data[:campaigns].first
    assert_equal campaign.name, campaign_data[:name]
    assert_includes campaign_data.keys, :performance
  end

  test "subscriber analytics report calculates engagement metrics" do
    # Create test subscribers
    @email_integration.email_subscribers.create!(
      platform_subscriber_id: "sub_1",
      email: "test1@example.com",
      status: "subscribed",
      subscribed_at: 1.week.ago
    )

    @email_integration.email_subscribers.create!(
      platform_subscriber_id: "sub_2",
      email: "test2@example.com", 
      status: "unsubscribed",
      subscribed_at: 1.month.ago,
      unsubscribed_at: 1.week.ago
    )

    result = @analytics_service.subscriber_analytics_report

    assert result.success?
    assert_equal 2, result.data[:total_subscribers]
    assert_equal 1, result.data[:active_subscribers]
    assert_includes result.data.keys, :status_breakdown
    assert_includes result.data.keys, :lifecycle_distribution
  end

  test "automation performance report includes health status" do
    automation = @email_integration.email_automations.create!(
      platform_automation_id: "auto_123",
      name: "Welcome Series",
      status: "active",
      automation_type: "welcome",
      total_subscribers: 500,
      active_subscribers: 450
    )

    result = @analytics_service.automation_performance_report

    assert result.success?
    assert_equal 1, result.data[:total_active]
    assert_equal 500, result.data[:total_subscribers]

    automation_data = result.data[:automations].first
    assert_equal automation.name, automation_data[:name]
    assert_includes automation_data.keys, :health_status
  end

  test "deliverability report calculates health score" do
    campaign = @email_integration.email_campaigns.create!(
      platform_campaign_id: "campaign_456",
      name: "Deliverability Test",
      status: "sent"
    )

    # Good deliverability metrics
    campaign.email_metrics.create!(
      metric_type: "daily",
      metric_date: Date.current,
      delivery_rate: 98.5,
      bounce_rate: 1.2,
      complaint_rate: 0.1,
      sent: 1000,
      delivered: 985
    )

    result = @analytics_service.deliverability_report

    assert result.success?
    assert result.data[:delivery_rate] > 95.0
    assert result.data[:health_score] > 90.0
    assert_includes result.data.keys, :recommendations
  end

  test "engagement trends report tracks daily patterns" do
    campaign = @email_integration.email_campaigns.create!(
      platform_campaign_id: "campaign_789",
      name: "Trends Test",
      status: "sent"
    )

    # Create metrics for multiple days
    3.times do |i|
      campaign.email_metrics.create!(
        metric_type: "daily",
        metric_date: i.days.ago.to_date,
        open_rate: 20.0 + i,
        click_rate: 3.0 + (i * 0.5),
        sent: 100
      )
    end

    result = @analytics_service.engagement_trends_report

    assert result.success?
    assert_includes result.data.keys, :daily_open_rates
    assert_includes result.data.keys, :daily_click_rates
    assert_includes result.data.keys, :engagement_score_trend
  end

  test "handles rate limiting gracefully" do
    # Mock rate limiting to fail
    @analytics_service.stubs(:with_rate_limiting).returns(
      ServiceResult.failure("Rate limit exceeded")
    )

    result = @analytics_service.sync_campaigns

    assert_not result.success?
    assert_includes result.error_message, "Rate limit exceeded"
  end

  test "test_connection validates integration status" do
    # Mock the platform service test_connection method
    platform_service = mock("MailchimpService")
    platform_service.expects(:test_connection).returns(
      ServiceResult.success(data: { connected: true, health_status: "Everything's Chimpy!" })
    )
    
    @analytics_service.stubs(:build_platform_service).returns(platform_service)

    result = @analytics_service.test_connection

    assert result.success?
    assert result.data[:connected]
  end

  test "full_sync orchestrates all sync operations" do
    # Mock all sync operations
    platform_service = mock("MailchimpService")
    platform_service.expects(:test_connection).returns(
      ServiceResult.success(data: { connected: true })
    )
    
    @analytics_service.stubs(:build_platform_service).returns(platform_service)
    @analytics_service.stubs(:sync_campaigns).returns(
      ServiceResult.success(data: { synced_campaigns: 5 })
    )
    @analytics_service.stubs(:sync_subscribers).returns(
      ServiceResult.success(data: { synced_subscribers: 100 })
    )
    @analytics_service.stubs(:sync_automations).returns(
      ServiceResult.success(data: { synced_automations: 3 })
    )

    result = @analytics_service.full_sync

    assert result.success?
    assert_includes result.data.keys, :campaigns
    assert_includes result.data.keys, :subscribers
    assert_includes result.data.keys, :automations
  end

  test "handles expired token refresh" do
    # Set integration to need refresh
    @email_integration.update!(
      expires_at: 1.hour.ago,
      refresh_token: "refresh_token_123"
    )

    # Mock successful token refresh
    @email_integration.expects(:refresh_token_if_needed!).returns(true)

    platform_service = mock("MailchimpService")
    platform_service.expects(:test_connection).returns(
      ServiceResult.success(data: { connected: true })
    )
    
    @analytics_service.stubs(:build_platform_service).returns(platform_service)
    @analytics_service.stubs(:sync_campaigns).returns(ServiceResult.success(data: {}))
    @analytics_service.stubs(:sync_subscribers).returns(ServiceResult.success(data: {}))
    @analytics_service.stubs(:sync_automations).returns(ServiceResult.success(data: {}))

    result = @analytics_service.full_sync

    assert result.success?
  end

  test "fails when integration is not active" do
    @email_integration.update!(status: "error")

    result = @analytics_service.full_sync

    assert_not result.success?
    assert_includes result.error_message, "Integration not active"
  end

  private

  def mock_redis_for_rate_limiting
    redis_mock = mock("Redis")
    redis_mock.stubs(:get).returns("0")
    redis_mock.stubs(:incr).returns(1)
    redis_mock.stubs(:expire).returns(true)
    redis_mock.stubs(:ttl).returns(3600)
    Redis.stubs(:new).returns(redis_mock)
  end
end