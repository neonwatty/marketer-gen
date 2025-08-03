# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class SimpleAnalyticsIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @user = users(:one)
    @brand = brands(:one)
    
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

  test "social media integration basic functionality" do
    # Create a simple social media integration
    integration = SocialMediaIntegration.create!(
      brand: @brand,
      platform: "facebook",
      access_token: "test_token",
      status: "active",
      platform_account_id: "account_123"
    )
    
    assert_not_nil integration
    assert_equal "facebook", integration.platform
    assert_equal "active", integration.status
    
    # Test service initialization
    service = Analytics::SocialMediaIntegrationService.new(@brand, integration)
    assert_not_nil service
    
    # Mock Facebook API response
    stub_request(:get, /graph\.facebook\.com/)
      .to_return(status: 200, body: {
        data: [
          { name: "reach", values: [{ value: 1000 }] }
        ]
      }.to_json)
    
    # Test metrics collection
    result = service.collect_facebook_metrics
    assert result.success?
    
    # Verify metrics storage
    metric = SocialMediaMetric.create!(
      social_media_integration: integration,
      platform: "facebook",
      metric_type: "reach",
      value: 1000,
      date: Date.current
    )
    
    assert_not_nil metric
    assert_equal 1000, metric.value
  end

  test "email marketing integration basic functionality" do
    # Create a simple email integration
    integration = EmailIntegration.create!(
      brand: @brand,
      platform: "mailchimp",
      api_key: "test_key",
      status: "active"
    )
    
    assert_not_nil integration
    assert_equal "mailchimp", integration.platform
    assert_equal "active", integration.status
    
    # Mock Mailchimp API response
    stub_request(:get, /api\.mailchimp\.com/)
      .to_return(status: 200, body: {
        campaigns: [
          { id: "campaign_123", report_summary: { opens: 100, clicks: 25 } }
        ]
      }.to_json)
    
    # Test service functionality
    service = Analytics::EmailPlatforms::MailchimpService.new(@brand)
    assert_not_nil service
    
    # Verify metric storage
    metric = EmailMetric.create!(
      email_integration: integration,
      platform: "mailchimp",
      metric_type: "opens",
      value: 100,
      date: Date.current
    )
    
    assert_not_nil metric
    assert_equal 100, metric.value
  end

  test "basic etl pipeline functionality" do
    # Create a basic ETL pipeline run
    pipeline_run = EtlPipelineRun.create!(
      pipeline_id: SecureRandom.uuid,
      source: "test_source",
      status: "running",
      started_at: Time.current
    )
    
    assert_not_nil pipeline_run
    assert_equal "running", pipeline_run.status
    
    # Test marking as completed
    pipeline_run.mark_completed!({ records_processed: 100 })
    
    assert_equal "completed", pipeline_run.status
    assert_not_nil pipeline_run.completed_at
    assert_equal 100, pipeline_run.metrics["records_processed"]
  end

  test "custom report creation" do
    # Create a simple custom report
    report = CustomReport.create!(
      name: "Test Report",
      report_type: "standard",
      status: "active",
      configuration: { metrics: ["reach", "engagement"] }.to_json,
      user: @user,
      brand: @brand
    )
    
    assert_not_nil report
    assert_equal "Test Report", report.name
    assert_equal "standard", report.report_type
    assert_equal "active", report.status
  end

  test "performance alert system" do
    # Create a performance threshold
    threshold = PerformanceThreshold.create!(
      brand: @brand,
      metric_name: "engagement_rate",
      threshold_type: "min",
      threshold_value: 5.0,
      alert_enabled: true
    )
    
    assert_not_nil threshold
    assert_equal "engagement_rate", threshold.metric_name
    assert_equal 5.0, threshold.threshold_value
    
    # Create an alert instance
    alert = AlertInstance.create!(
      performance_threshold: threshold,
      triggered_at: Time.current,
      metric_value: 2.0,
      status: "active"
    )
    
    assert_not_nil alert
    assert_equal 2.0, alert.metric_value
    assert_equal "active", alert.status
  end

  test "basic background job processing" do
    # Test job enqueueing
    perform_enqueued_jobs do
      SocialMediaSyncJob.perform_later(@brand.id)
    end
    
    # Verify job was performed
    assert_performed_jobs 1
  end
end