# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class EmailMarketingIntegrationTest < ActionDispatch::IntegrationTest
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
  # MAILCHIMP INTEGRATION TESTS
  # =============================================================================

  test "mailchimp oauth and api integration" do
    # Test Mailchimp OAuth flow
    oauth_service = Analytics::EmailProviderOauthService.new(@brand, "mailchimp")
    
    # Mock OAuth URL generation
    auth_url = oauth_service.authorization_url
    assert_not_nil auth_url
    assert_includes auth_url, "mailchimp.com"
    
    # Mock OAuth callback
    stub_mailchimp_oauth_success
    
    result = oauth_service.handle_callback("test_auth_code", "test_state")
    assert result.success?
    
    # Verify integration was created
    integration = @brand.email_integrations.find_by(platform: "mailchimp")
    assert_not_nil integration
    assert_equal "active", integration.status
  end

  test "mailchimp campaigns data integration" do
    integration = create_mailchimp_integration
    service = Analytics::EmailPlatforms::MailchimpService.new(@brand)
    
    # Mock Mailchimp Campaigns API
    stub_mailchimp_campaigns_api
    
    result = service.fetch_campaign_data(
      start_date: 30.days.ago,
      end_date: Time.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :campaigns
    assert data[:campaigns].any?
    
    # Verify campaign metrics
    campaign = data[:campaigns].first
    assert_includes campaign.keys, :sends
    assert_includes campaign.keys, :opens
    assert_includes campaign.keys, :clicks
    assert_includes campaign.keys, :bounces
    
    # Verify data was stored
    assert EmailCampaign.where(platform: "mailchimp").exists?
    assert EmailMetric.exists?
  end

  test "mailchimp audience insights integration" do
    integration = create_mailchimp_integration
    service = Analytics::EmailPlatforms::MailchimpService.new(@brand)
    
    # Mock Mailchimp Audience API
    stub_mailchimp_audience_api
    
    result = service.fetch_audience_data
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :total_subscribers
    assert_includes data.keys, :growth_rate
    assert_includes data.keys, :demographics
    
    # Verify subscriber data
    assert data[:total_subscribers] > 0
    assert data[:demographics].key?(:age_groups)
    assert data[:demographics].key?(:geographic_distribution)
  end

  test "mailchimp automation workflows integration" do
    integration = create_mailchimp_integration
    service = Analytics::EmailPlatforms::MailchimpService.new(@brand)
    
    # Mock Mailchimp Automations API
    stub_mailchimp_automations_api
    
    result = service.fetch_automation_data
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :automations
    assert data[:automations].any?
    
    # Verify automation metrics
    automation = data[:automations].first
    assert_includes automation.keys, :emails_sent
    assert_includes automation.keys, :revenue
    assert_includes automation.keys, :subscribers_entered
    
    # Verify automation data storage
    assert EmailAutomation.where(platform: "mailchimp").exists?
  end

  test "mailchimp webhook integration" do
    integration = create_mailchimp_integration
    
    # Test various Mailchimp webhook events
    webhook_events = [
      {
        type: "subscribe",
        fired_at: Time.current.iso8601,
        data: {
          id: "subscriber_123",
          email: "test@example.com",
          list_id: "list_123"
        }
      },
      {
        type: "campaign",
        fired_at: Time.current.iso8601,
        data: {
          id: "campaign_123",
          subject: "Test Campaign",
          list_id: "list_123"
        }
      }
    ]
    
    webhook_events.each do |event|
      post "/webhooks/email_platforms/mailchimp",
           params: event,
           headers: { "Content-Type" => "application/json" }
      
      assert_response :success
      assert_performed_jobs 1
      clear_performed_jobs
    end
  end

  test "mailchimp segmentation and targeting integration" do
    integration = create_mailchimp_integration
    service = Analytics::EmailPlatforms::MailchimpService.new(@brand)
    
    # Mock Mailchimp Segments API
    stub_mailchimp_segments_api
    
    result = service.fetch_segment_performance
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :segments
    assert data[:segments].any?
    
    # Verify segment metrics
    segment = data[:segments].first
    assert_includes segment.keys, :member_count
    assert_includes segment.keys, :open_rate
    assert_includes segment.keys, :click_rate
  end

  # =============================================================================
  # SENDGRID INTEGRATION TESTS
  # =============================================================================

  test "sendgrid api integration" do
    integration = create_sendgrid_integration
    service = Analytics::EmailAnalyticsService.new(@brand, "sendgrid")
    
    # Mock SendGrid Stats API
    stub_sendgrid_stats_api
    
    result = service.fetch_email_metrics(
      start_date: 7.days.ago.to_date,
      end_date: Date.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :stats
    assert data[:stats].any?
    
    # Verify SendGrid metrics
    stat = data[:stats].first
    assert_includes stat.keys, :delivered
    assert_includes stat.keys, :opens
    assert_includes stat.keys, :clicks
    assert_includes stat.keys, :bounces
    assert_includes stat.keys, :spam_reports
  end

  test "sendgrid template performance integration" do
    integration = create_sendgrid_integration
    service = Analytics::EmailAnalyticsService.new(@brand, "sendgrid")
    
    # Mock SendGrid Templates API
    stub_sendgrid_templates_api
    
    result = service.fetch_template_performance
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :templates
    assert data[:templates].any?
    
    # Verify template metrics
    template = data[:templates].first
    assert_includes template.keys, :template_id
    assert_includes template.keys, :sends
    assert_includes template.keys, :opens
    assert_includes template.keys, :clicks
  end

  test "sendgrid webhook events integration" do
    integration = create_sendgrid_integration
    
    # Test SendGrid webhook events
    webhook_events = [
      {
        email: "test@example.com",
        timestamp: Time.current.to_i,
        event: "delivered",
        smtp_id: "message_123",
        sg_message_id: "sendgrid_123"
      },
      {
        email: "test@example.com",
        timestamp: Time.current.to_i,
        event: "open",
        smtp_id: "message_123",
        sg_message_id: "sendgrid_123"
      },
      {
        email: "test@example.com",
        timestamp: Time.current.to_i,
        event: "click",
        smtp_id: "message_123",
        sg_message_id: "sendgrid_123",
        url: "https://example.com/link"
      }
    ]
    
    post "/webhooks/email_platforms/sendgrid",
         params: webhook_events,
         headers: { "Content-Type" => "application/json" }
    
    assert_response :success
    assert_performed_jobs 1
    
    # Verify webhook processing
    webhook_processor = Analytics::EmailWebhookProcessorService.new
    result = webhook_processor.process_sendgrid_events(webhook_events)
    
    assert result.success?
    assert EmailMetric.where(platform: "sendgrid").exists?
  end

  test "sendgrid suppression management integration" do
    integration = create_sendgrid_integration
    service = Analytics::EmailAnalyticsService.new(@brand, "sendgrid")
    
    # Mock SendGrid Suppressions API
    stub_sendgrid_suppressions_api
    
    result = service.fetch_suppression_data
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :bounces
    assert_includes data.keys, :blocks
    assert_includes data.keys, :spam_reports
    assert_includes data.keys, :unsubscribes
    
    # Verify suppression tracking
    assert EmailSubscriber.where(status: "bounced").exists?
    assert EmailSubscriber.where(status: "unsubscribed").exists?
  end

  # =============================================================================
  # HUBSPOT EMAIL INTEGRATION TESTS
  # =============================================================================

  test "hubspot email marketing integration" do
    integration = create_hubspot_email_integration
    service = Analytics::CrmPlatforms::HubspotService.new(@brand)
    
    # Mock HubSpot Email API
    stub_hubspot_email_api
    
    result = service.fetch_email_performance
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :email_campaigns
    assert data[:email_campaigns].any?
    
    # Verify HubSpot email metrics
    campaign = data[:email_campaigns].first
    assert_includes campaign.keys, :sent
    assert_includes campaign.keys, :delivered
    assert_includes campaign.keys, :opens
    assert_includes campaign.keys, :clicks
    assert_includes campaign.keys, :replies
  end

  test "hubspot email automation integration" do
    integration = create_hubspot_email_integration
    service = Analytics::CrmPlatforms::HubspotService.new(@brand)
    
    # Mock HubSpot Workflows API
    stub_hubspot_workflows_api
    
    result = service.fetch_email_workflows
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :workflows
    assert data[:workflows].any?
    
    # Verify workflow metrics
    workflow = data[:workflows].first
    assert_includes workflow.keys, :enrolled
    assert_includes workflow.keys, :completed
    assert_includes workflow.keys, :emails_sent
  end

  # =============================================================================
  # CROSS-PLATFORM EMAIL INTEGRATION TESTS
  # =============================================================================

  test "email platform aggregation integration" do
    # Create integrations for multiple platforms
    create_mailchimp_integration
    create_sendgrid_integration
    create_hubspot_email_integration
    
    service = Analytics::EmailAnalyticsService.new(@brand)
    
    # Mock all email platform APIs
    stub_all_email_platform_apis
    
    result = service.aggregate_all_platforms(
      start_date: 30.days.ago,
      end_date: Time.current
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :total_sent
    assert_includes data.keys, :total_opens
    assert_includes data.keys, :total_clicks
    assert_includes data.keys, :platform_breakdown
    
    # Verify aggregated metrics
    assert data[:total_sent] > 0
    assert data[:total_opens] > 0
    assert data[:total_clicks] > 0
    assert_equal 3, data[:platform_breakdown].keys.count
  end

  test "email deliverability analysis integration" do
    # Create test data across platforms
    create_email_metrics_for_deliverability_test
    
    service = Analytics::EmailAnalyticsService.new(@brand)
    result = service.analyze_deliverability
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :delivery_rate
    assert_includes data.keys, :bounce_rate
    assert_includes data.keys, :spam_rate
    assert_includes data.keys, :reputation_score
    
    # Verify deliverability insights
    assert data[:delivery_rate] >= 0
    assert data[:delivery_rate] <= 100
    assert data[:bounce_rate] >= 0
    assert data[:reputation_score] >= 0
  end

  test "email engagement tracking integration" do
    service = Analytics::EmailAnalyticsService.new(@brand)
    
    # Mock engagement data
    stub_email_engagement_apis
    
    result = service.calculate_engagement_metrics(
      time_period: "30d"
    )
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :open_rate
    assert_includes data.keys, :click_rate
    assert_includes data.keys, :unsubscribe_rate
    assert_includes data.keys, :engagement_trends
    
    # Verify engagement calculations
    assert data[:open_rate] >= 0
    assert data[:click_rate] >= 0
    assert data[:unsubscribe_rate] >= 0
  end

  test "email campaign attribution integration" do
    # Create campaign data with attribution tracking
    campaign = EmailCampaign.create!(
      brand: @brand,
      name: "Test Attribution Campaign",
      platform: "mailchimp",
      campaign_id: "campaign_attribution_123",
      utm_source: "email",
      utm_medium: "campaign",
      utm_campaign: "test_attribution"
    )
    
    service = Analytics::AttributionModelingService.new(@brand)
    
    # Mock attribution data
    stub_email_attribution_tracking
    
    result = service.track_email_attribution(campaign.id)
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :conversions
    assert_includes data.keys, :revenue
    assert_includes data.keys, :customer_journey
    
    # Verify attribution tracking
    assert data[:conversions] >= 0
    assert data[:revenue] >= 0
  end

  test "email list health monitoring integration" do
    service = Analytics::EmailAnalyticsService.new(@brand)
    
    # Create test subscriber data
    create_email_subscriber_test_data
    
    result = service.monitor_list_health
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :list_growth_rate
    assert_includes data.keys, :churn_rate
    assert_includes data.keys, :engagement_score
    assert_includes data.keys, :hygiene_issues
    
    # Verify health metrics
    assert data[:list_growth_rate].is_a?(Numeric)
    assert data[:churn_rate] >= 0
    assert data[:engagement_score] >= 0
  end

  test "email a_b test integration" do
    # Create A/B test campaign
    ab_test = AbTest.create!(
      brand: @brand,
      name: "Email Subject Line Test",
      test_type: "email_subject",
      status: "running"
    )
    
    # Create variants
    variant_a = AbTestVariant.create!(
      ab_test: ab_test,
      name: "Subject A",
      configuration: { subject: "Special Offer Inside!" },
      traffic_percentage: 50
    )
    
    variant_b = AbTestVariant.create!(
      ab_test: ab_test,
      name: "Subject B", 
      configuration: { subject: "Don't Miss This Deal" },
      traffic_percentage: 50
    )
    
    service = Analytics::EmailAnalyticsService.new(@brand)
    
    # Mock A/B test results
    stub_email_ab_test_results
    
    result = service.analyze_ab_test_results(ab_test.id)
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :variant_performance
    assert_includes data.keys, :statistical_significance
    assert_includes data.keys, :winner
    
    # Verify A/B test analysis
    assert_equal 2, data[:variant_performance].count
    assert data[:statistical_significance].key?(:p_value)
  end

  test "email automation workflow integration" do
    # Create automation workflow
    automation = EmailAutomation.create!(
      brand: @brand,
      name: "Welcome Series",
      platform: "mailchimp",
      trigger_type: "signup",
      status: "active"
    )
    
    service = Analytics::EmailAnalyticsService.new(@brand)
    
    # Mock automation performance data
    stub_email_automation_performance
    
    result = service.track_automation_performance(automation.id)
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :subscribers_entered
    assert_includes data.keys, :completion_rate
    assert_includes data.keys, :email_performance
    assert_includes data.keys, :revenue_generated
    
    # Verify automation tracking
    assert data[:subscribers_entered] >= 0
    assert data[:completion_rate] >= 0
    assert data[:completion_rate] <= 100
  end

  test "email real time analytics integration" do
    service = Analytics::EmailAnalyticsService.new(@brand)
    
    # Mock real-time data
    stub_email_realtime_apis
    
    result = service.fetch_realtime_metrics
    
    assert result.success?
    
    data = result.data
    assert_includes data.keys, :current_sends
    assert_includes data.keys, :live_opens
    assert_includes data.keys, :live_clicks
    assert_includes data.keys, :delivery_status
    
    # Test WebSocket updates
    perform_enqueued_jobs do
      Analytics::EmailAnalyticsService.new(@brand).broadcast_realtime_update
    end
    
    # Verify real-time broadcast
    assert_broadcasts "email_analytics_#{@brand.id}", 1
  end

  private

  # =============================================================================
  # HELPER METHODS FOR CREATING TEST INTEGRATIONS
  # =============================================================================

  def create_mailchimp_integration
    EmailIntegration.create!(
      brand: @brand,
      platform: "mailchimp",
      api_key: "mc_test_key",
      status: "active",
      configuration: {
        data_center: "us1",
        account_id: "mailchimp_123"
      }
    )
  end

  def create_sendgrid_integration
    EmailIntegration.create!(
      brand: @brand,
      platform: "sendgrid",
      api_key: "sg_test_key",
      status: "active",
      configuration: {
        username: "sendgrid_user",
        subuser: "test_subuser"
      }
    )
  end

  def create_hubspot_email_integration
    EmailIntegration.create!(
      brand: @brand,
      platform: "hubspot",
      api_key: "hs_test_key",
      status: "active",
      configuration: {
        portal_id: "hubspot_123",
        account_type: "marketing_hub"
      }
    )
  end

  def create_email_metrics_for_deliverability_test
    integration = create_mailchimp_integration
    
    # Create various delivery outcomes
    EmailMetric.create!(
      email_integration: integration,
      platform: "mailchimp",
      metric_type: "delivered",
      value: 950,
      date: Date.current
    )
    
    EmailMetric.create!(
      email_integration: integration,
      platform: "mailchimp", 
      metric_type: "bounced",
      value: 30,
      date: Date.current
    )
    
    EmailMetric.create!(
      email_integration: integration,
      platform: "mailchimp",
      metric_type: "spam_reports",
      value: 20,
      date: Date.current
    )
  end

  def create_email_subscriber_test_data
    integration = create_mailchimp_integration
    
    # Create subscriber records
    EmailSubscriber.create!(
      email_integration: integration,
      email: "active@example.com",
      status: "subscribed",
      subscribed_at: 30.days.ago
    )
    
    EmailSubscriber.create!(
      email_integration: integration,
      email: "churned@example.com",
      status: "unsubscribed",
      subscribed_at: 60.days.ago,
      unsubscribed_at: 5.days.ago
    )
    
    EmailSubscriber.create!(
      email_integration: integration,
      email: "bounced@example.com",
      status: "bounced",
      subscribed_at: 45.days.ago
    )
  end

  # =============================================================================
  # API STUBBING METHODS
  # =============================================================================

  def stub_mailchimp_oauth_success
    stub_request(:post, "https://login.mailchimp.com/oauth2/token")
      .to_return(status: 200, body: {
        access_token: "mc_access_token_123",
        token_type: "bearer",
        expires_in: 3600,
        scope: "read write"
      }.to_json)
  end

  def stub_mailchimp_campaigns_api
    stub_request(:get, /api\.mailchimp\.com\/3\.0\/campaigns/)
      .to_return(status: 200, body: {
        campaigns: [
          {
            id: "campaign_123",
            web_id: 123,
            type: "regular",
            create_time: Time.current.iso8601,
            archive_url: "https://example.com/archive",
            status: "sent",
            emails_sent: 1000,
            abuse_reports: 2,
            unsubscribed: 15,
            send_time: Time.current.iso8601,
            content_type: "html",
            recipients: {
              list_id: "list_123",
              segment_text: "All subscribers"
            },
            settings: {
              subject_line: "Monthly Newsletter",
              title: "December Newsletter",
              from_name: "Test Company",
              reply_to: "noreply@example.com"
            },
            report_summary: {
              opens: 450,
              unique_opens: 380,
              open_rate: 0.38,
              clicks: 120,
              subscriber_clicks: 95,
              click_rate: 0.095,
              ecommerce: {
                total_orders: 25,
                total_spent: 1250.00,
                total_revenue: 1100.00
              }
            }
          },
          {
            id: "campaign_456",
            web_id: 456,
            type: "automation",
            create_time: (Time.current - 7.days).iso8601,
            status: "sent",
            emails_sent: 2500,
            report_summary: {
              opens: 1200,
              unique_opens: 1000,
              open_rate: 0.40,
              clicks: 300,
              subscriber_clicks: 250,
              click_rate: 0.10
            }
          }
        ],
        total_items: 2
      }.to_json)
  end

  def stub_mailchimp_audience_api
    stub_request(:get, /api\.mailchimp\.com\/3\.0\/lists/)
      .to_return(status: 200, body: {
        lists: [
          {
            id: "list_123",
            web_id: 123,
            name: "Main Newsletter",
            stats: {
              member_count: 5000,
              unsubscribe_count: 250,
              cleaned_count: 75,
              member_count_since_send: 4900,
              unsubscribe_count_since_send: 25,
              cleaned_count_since_send: 10,
              campaign_count: 24,
              campaign_last_sent: Time.current.iso8601,
              merge_field_count: 5,
              avg_sub_rate: 15.5,
              avg_unsub_rate: 2.1,
              target_sub_rate: 20.0,
              open_rate: 35.2,
              click_rate: 8.7,
              last_sub_date: Time.current.iso8601,
              last_unsub_date: (Time.current - 2.days).iso8601
            }
          }
        ]
      }.to_json)
  end

  def stub_mailchimp_automations_api
    stub_request(:get, /api\.mailchimp\.com\/3\.0\/automations/)
      .to_return(status: 200, body: {
        automations: [
          {
            id: "automation_123",
            create_time: (Time.current - 30.days).iso8601,
            start_time: (Time.current - 29.days).iso8601,
            status: "sending",
            emails_sent: 1500,
            recipients: {
              list_id: "list_123",
              store_id: "store_123"
            },
            settings: {
              title: "Welcome Series",
              from_name: "Test Company",
              reply_to: "support@example.com",
              use_conversation: false,
              to_name: "*|FNAME|*",
              folder_id: "folder_123",
              authenticate: true,
              auto_footer: false,
              inline_css: false
            },
            tracking: {
              opens: true,
              html_clicks: true,
              text_clicks: false,
              goal_tracking: true,
              ecomm360: true,
              google_analytics: "google_analytics_key",
              clicktale: "clicktale_key"
            },
            report_summary: {
              opens: 850,
              unique_opens: 700,
              open_rate: 0.467,
              clicks: 180,
              subscriber_clicks: 150,
              click_rate: 0.10,
              ecommerce: {
                total_orders: 35,
                total_spent: 1750.00,
                total_revenue: 1575.00
              }
            }
          }
        ]
      }.to_json)
  end

  def stub_mailchimp_segments_api
    stub_request(:get, /api\.mailchimp\.com\/3\.0\/lists\/.*\/segments/)
      .to_return(status: 200, body: {
        segments: [
          {
            id: "segment_123",
            name: "High Engagement",
            member_count: 1200,
            type: "static",
            created_at: (Time.current - 60.days).iso8601,
            updated_at: Time.current.iso8601,
            options: {
              match: "all",
              conditions: [
                {
                  condition_type: "EmailAddress",
                  field: "EMAIL",
                  op: "contains",
                  value: "@gmail.com"
                }
              ]
            }
          }
        ]
      }.to_json)
  end

  def stub_sendgrid_stats_api
    stub_request(:get, /api\.sendgrid\.com\/v3\/stats/)
      .to_return(status: 200, body: [
        {
          date: Date.current.to_s,
          stats: [
            {
              metrics: {
                blocks: 5,
                bounce_drops: 3,
                bounces: 25,
                clicks: 180,
                deferred: 15,
                delivered: 950,
                invalid_emails: 8,
                opens: 420,
                processed: 1000,
                requests: 1000,
                spam_report_drops: 2,
                spam_reports: 12,
                unique_clicks: 150,
                unique_opens: 380,
                unsubscribe_drops: 1,
                unsubscribes: 18
              }
            }
          ]
        },
        {
          date: (Date.current - 1.day).to_s,
          stats: [
            {
              metrics: {
                blocks: 3,
                bounce_drops: 2,
                bounces: 18,
                clicks: 165,
                deferred: 12,
                delivered: 975,
                invalid_emails: 5,
                opens: 445,
                processed: 1000,
                requests: 1000,
                spam_report_drops: 1,
                spam_reports: 8,
                unique_clicks: 140,
                unique_opens: 395,
                unsubscribe_drops: 0,
                unsubscribes: 12
              }
            }
          ]
        }
      ].to_json)
  end

  def stub_sendgrid_templates_api
    stub_request(:get, /api\.sendgrid\.com\/v3\/templates/)
      .to_return(status: 200, body: {
        result: [
          {
            id: "template_123",
            name: "Welcome Email",
            generation: "dynamic",
            updated_at: Time.current.iso8601,
            versions: [
              {
                id: "version_123",
                template_id: "template_123",
                active: 1,
                name: "Version 1",
                html_content: "<html><body>Welcome!</body></html>",
                plain_content: "Welcome!",
                generate_plain_content: true,
                subject: "Welcome to our service!",
                updated_at: Time.current.iso8601,
                editor: "code"
              }
            ]
          }
        ]
      }.to_json)
  end

  def stub_sendgrid_suppressions_api
    stub_request(:get, /api\.sendgrid\.com\/v3\/suppression/)
      .to_return(status: 200, body: [
        {
          email: "bounced@example.com",
          created: Time.current.to_i,
          reason: "Mail is sent to an invalid email address",
          status: "4.0.0"
        },
        {
          email: "blocked@example.com",
          created: (Time.current - 1.day).to_i,
          reason: "IP address reputation",
          status: "5.1.1"
        }
      ].to_json)
  end

  def stub_hubspot_email_api
    stub_request(:get, /api\.hubapi\.com\/email\/public\/v1\/campaigns/)
      .to_return(status: 200, body: {
        objects: [
          {
            id: "hs_campaign_123",
            appId: 123,
            appName: "Marketing Hub",
            contentId: 456,
            campaignType: "AB_EMAIL",
            name: "Monthly Newsletter",
            subject: "Your Monthly Update",
            fromName: "Test Company",
            replyTo: "noreply@example.com",
            domain: "example.com",
            created: (Time.current - 7.days).to_i * 1000,
            updated: Time.current.to_i * 1000,
            publishedAt: (Time.current - 6.days).to_i * 1000,
            publishedBy: "user_123",
            counters: {
              sent: 2500,
              delivered: 2400,
              opens: 960,
              clicks: 240,
              replies: 15,
              forwards: 8,
              unsubscribes: 18,
              bounces: 75,
              spamreports: 5
            },
            stats: {
              deliveredPct: 96.0,
              openPct: 40.0,
              clickPct: 10.0,
              replyPct: 0.6,
              forwardPct: 0.32,
              unsubscribePct: 0.75,
              bouncePct: 3.0,
              spamreportPct: 0.2
            }
          }
        ],
        hasMore: false,
        offset: 0
      }.to_json)
  end

  def stub_hubspot_workflows_api
    stub_request(:get, /api\.hubapi\.com\/automation\/v3\/workflows/)
      .to_return(status: 200, body: {
        results: [
          {
            id: "workflow_123",
            name: "Lead Nurturing Workflow",
            type: "DRIP_DELAY",
            enabled: true,
            insertedAt: (Time.current - 30.days).to_i * 1000,
            updatedAt: Time.current.to_i * 1000,
            actions: [
              {
                id: "action_123",
                type: "SEND_EMAIL",
                delayMillis: 0,
                actionMeta: {
                  emailId: "email_123"
                }
              }
            ],
            enrollmentCriteria: {
              filterGroups: [
                {
                  filters: [
                    {
                      filterType: "PROPERTY",
                      property: "lifecyclestage",
                      operation: {
                        operator: "EQ",
                        operationType: "ENUMERATION"
                      },
                      value: "lead"
                    }
                  ]
                }
              ]
            },
            statistics: {
              enrolled: 450,
              active: 120,
              completed: 330,
              emails_sent: 1200
            }
          }
        ],
        total: 1
      }.to_json)
  end

  def stub_all_email_platform_apis
    stub_mailchimp_campaigns_api
    stub_sendgrid_stats_api
    stub_hubspot_email_api
  end

  def stub_email_engagement_apis
    stub_all_email_platform_apis
  end

  def stub_email_attribution_tracking
    # Mock attribution tracking API responses
    stub_request(:get, /analytics|attribution/)
      .to_return(status: 200, body: {
        conversions: 15,
        revenue: 750.00,
        customer_journey: [
          { touchpoint: "email_open", timestamp: Time.current.iso8601 },
          { touchpoint: "email_click", timestamp: Time.current.iso8601 },
          { touchpoint: "website_visit", timestamp: Time.current.iso8601 },
          { touchpoint: "purchase", timestamp: Time.current.iso8601 }
        ]
      }.to_json)
  end

  def stub_email_ab_test_results
    # Mock A/B test results
    stub_request(:get, /ab_test|split_test/)
      .to_return(status: 200, body: {
        variant_performance: [
          {
            variant: "A",
            opens: 200,
            clicks: 40,
            conversions: 8,
            open_rate: 40.0,
            click_rate: 8.0,
            conversion_rate: 1.6
          },
          {
            variant: "B",
            opens: 250,
            clicks: 60,
            conversions: 15,
            open_rate: 50.0,
            click_rate: 12.0,
            conversion_rate: 3.0
          }
        ],
        statistical_significance: {
          p_value: 0.02,
          confidence_level: 98.0,
          significant: true
        },
        winner: "B"
      }.to_json)
  end

  def stub_email_automation_performance
    # Mock automation performance data
    stub_request(:get, /automation|workflow/)
      .to_return(status: 200, body: {
        subscribers_entered: 500,
        completion_rate: 75.0,
        email_performance: [
          {
            email_id: "welcome_1",
            sends: 500,
            opens: 400,
            clicks: 100,
            conversions: 25
          },
          {
            email_id: "welcome_2", 
            sends: 450,
            opens: 350,
            clicks: 85,
            conversions: 20
          }
        ],
        revenue_generated: 2250.00
      }.to_json)
  end

  def stub_email_realtime_apis
    # Mock real-time email analytics
    stub_request(:get, /realtime|live/)
      .to_return(status: 200, body: {
        current_sends: 125,
        live_opens: 45,
        live_clicks: 12,
        delivery_status: {
          delivered: 118,
          pending: 7,
          bounced: 0,
          failed: 0
        }
      }.to_json)
  end
end