# frozen_string_literal: true

module Analytics
  class EmailAnalyticsService
    include Analytics::RateLimitingService

    attr_accessor :integration

    def initialize(integration)
      @integration = integration
      @platform_service = build_platform_service
    end

    def full_sync
      return ServiceResult.failure("Integration not active") unless @integration.active?

      results = {}

      # Refresh token if needed
      if @integration.needs_refresh?
        refresh_result = @integration.refresh_token_if_needed!
        unless refresh_result
          return ServiceResult.failure("Failed to refresh access token")
        end
      end

      # Test connection first
      connection_test = test_connection
      return connection_test unless connection_test.success?

      # Sync campaigns
      campaigns_result = sync_campaigns
      results[:campaigns] = campaigns_result.success? ? campaigns_result.data : { error: campaigns_result.error_message }

      # Sync subscribers
      subscribers_result = sync_subscribers
      results[:subscribers] = subscribers_result.success? ? subscribers_result.data : { error: subscribers_result.error_message }

      # Sync automations
      automations_result = sync_automations
      results[:automations] = automations_result.success? ? automations_result.data : { error: automations_result.error_message }

      # Update last sync timestamp
      @integration.update_last_sync!

      ServiceResult.success(data: results)
    rescue StandardError => e
      Rails.logger.error "Email analytics full sync error for #{@integration.platform}: #{e.message}"
      ServiceResult.failure("Full sync failed: #{e.message}")
    end

    def sync_campaigns(limit: 100)
      with_rate_limiting("#{@integration.platform}_campaigns", user_id: @integration.brand.id) do
        @platform_service.sync_campaigns(limit: limit)
      end
    end

    def sync_subscribers(limit: 1000)
      with_rate_limiting("#{@integration.platform}_subscribers", user_id: @integration.brand.id) do
        @platform_service.sync_subscribers(limit: limit)
      end
    end

    def sync_automations(limit: 100)
      with_rate_limiting("#{@integration.platform}_automations", user_id: @integration.brand.id) do
        @platform_service.sync_automations(limit: limit)
      end
    end

    def setup_webhooks
      return ServiceResult.failure("Platform service doesn't support webhooks") unless @platform_service.respond_to?(:create_webhook)

      @platform_service.create_webhook
    end

    def remove_webhooks
      return ServiceResult.failure("Platform service doesn't support webhooks") unless @platform_service.respond_to?(:delete_webhook)

      @platform_service.delete_webhook
    end

    def test_connection
      @platform_service.test_connection
    end

    def campaign_performance_report(date_range: 30.days.ago..Time.current)
      campaigns = @integration.email_campaigns
                             .joins(:email_metrics)
                             .where(email_metrics: { metric_date: date_range })
                             .includes(:email_metrics)

      campaign_data = campaigns.map do |campaign|
        {
          id: campaign.id,
          name: campaign.name,
          subject: campaign.subject,
          send_time: campaign.send_time,
          performance: campaign.performance_summary
        }
      end

      aggregate_metrics = calculate_aggregate_metrics(campaigns)

      ServiceResult.success(data: {
        campaigns: campaign_data,
        aggregate_metrics: aggregate_metrics,
        date_range: {
          start: date_range.begin,
          end: date_range.end
        }
      })
    end

    def subscriber_analytics_report
      subscribers = @integration.email_subscribers

      analytics = {
        total_subscribers: subscribers.count,
        active_subscribers: subscribers.active.count,
        status_breakdown: subscribers.group(:status).count,
        source_breakdown: subscribers.group(:source).count,
        lifecycle_distribution: EmailSubscriber.where(id: subscribers.select(:id)).lifecycle_distribution,
        engagement_summary: EmailSubscriber.where(id: subscribers.select(:id)).engagement_summary,
        growth_metrics: calculate_subscriber_growth_metrics,
        geographic_distribution: calculate_geographic_distribution
      }

      ServiceResult.success(data: analytics)
    end

    def automation_performance_report
      automations = @integration.email_automations.includes(:email_integration)

      automation_data = automations.map do |automation|
        {
          id: automation.id,
          name: automation.name,
          type: automation.automation_type,
          status: automation.status,
          performance: automation.performance_summary,
          health_status: automation.health_status,
          estimated_monthly_sends: automation.estimated_monthly_sends
        }
      end

      ServiceResult.success(data: {
        automations: automation_data,
        total_active: automations.active.count,
        total_subscribers: automations.sum(:total_subscribers),
        performance_overview: calculate_automation_performance_overview(automations)
      })
    end

    def deliverability_report(date_range: 30.days.ago..Time.current)
      metrics = @integration.email_metrics
                           .where(metric_date: date_range)
                           .includes(:email_campaign)

      deliverability_data = {
        delivery_rate: calculate_average_rate(metrics, :delivery_rate),
        bounce_rate: calculate_average_rate(metrics, :bounce_rate),
        complaint_rate: calculate_average_rate(metrics, :complaint_rate),
        unsubscribe_rate: calculate_average_rate(metrics, :unsubscribe_rate),
        engagement_metrics: {
          open_rate: calculate_average_rate(metrics, :open_rate),
          click_rate: calculate_average_rate(metrics, :click_rate)
        },
        health_score: calculate_deliverability_health_score(metrics),
        recommendations: generate_deliverability_recommendations(metrics)
      }

      ServiceResult.success(data: deliverability_data)
    end

    def engagement_trends_report(date_range: 30.days.ago..Time.current)
      daily_metrics = @integration.email_metrics
                                 .where(metric_type: "daily", metric_date: date_range)
                                 .order(:metric_date)
                                 .group(:metric_date)

      trends = {
        daily_open_rates: daily_metrics.average(:open_rate),
        daily_click_rates: daily_metrics.average(:click_rate),
        daily_bounce_rates: daily_metrics.average(:bounce_rate),
        daily_unsubscribe_rates: daily_metrics.average(:unsubscribe_rate),
        volume_trends: daily_metrics.sum(:sent),
        engagement_score_trend: calculate_daily_engagement_scores(daily_metrics)
      }

      ServiceResult.success(data: trends)
    end

    private

    def build_platform_service
      case @integration.platform
      when "mailchimp"
        EmailPlatforms::MailchimpService.new(@integration)
      when "sendgrid"
        EmailPlatforms::SendgridService.new(@integration)
      when "constant_contact"
        EmailPlatforms::ConstantContactService.new(@integration)
      when "campaign_monitor"
        EmailPlatforms::CampaignMonitorService.new(@integration)
      when "activecampaign"
        EmailPlatforms::ActiveCampaignService.new(@integration)
      when "klaviyo"
        EmailPlatforms::KlaviyoService.new(@integration)
      else
        raise ArgumentError, "Unsupported email platform: #{@integration.platform}"
      end
    end

    def calculate_aggregate_metrics(campaigns)
      all_metrics = campaigns.flat_map(&:email_metrics)

      {
        total_campaigns: campaigns.count,
        total_sent: all_metrics.sum(&:sent),
        total_delivered: all_metrics.sum(&:delivered),
        total_opens: all_metrics.sum(&:opens),
        total_clicks: all_metrics.sum(&:clicks),
        total_bounces: all_metrics.sum(&:bounces),
        total_unsubscribes: all_metrics.sum(&:unsubscribes),
        total_complaints: all_metrics.sum(&:complaints),
        average_open_rate: all_metrics.sum(&:open_rate) / all_metrics.length.to_f,
        average_click_rate: all_metrics.sum(&:click_rate) / all_metrics.length.to_f,
        average_bounce_rate: all_metrics.sum(&:bounce_rate) / all_metrics.length.to_f
      }
    end

    def calculate_subscriber_growth_metrics
      subscribers = @integration.email_subscribers
      thirty_days_ago = 30.days.ago
      seven_days_ago = 7.days.ago

      {
        growth_last_30_days: subscribers.where("created_at > ?", thirty_days_ago).count,
        growth_last_7_days: subscribers.where("created_at > ?", seven_days_ago).count,
        churn_last_30_days: subscribers.where("unsubscribed_at > ?", thirty_days_ago).count,
        churn_last_7_days: subscribers.where("unsubscribed_at > ?", seven_days_ago).count,
        net_growth_30_days: subscribers.where("created_at > ?", thirty_days_ago).count -
                           subscribers.where("unsubscribed_at > ?", thirty_days_ago).count
      }
    end

    def calculate_geographic_distribution
      location_data = @integration.email_subscribers
                                 .where.not(location: nil)
                                 .pluck(:location)
                                 .map { |loc| JSON.parse(loc) rescue {} }

      country_counts = location_data
                       .map { |loc| loc["country"] }
                       .compact
                       .tally

      {
        by_country: country_counts,
        total_with_location: location_data.length,
        total_without_location: @integration.email_subscribers.where(location: nil).count
      }
    end

    def calculate_automation_performance_overview(automations)
      active_automations = automations.active

      {
        total_active_automations: active_automations.count,
        total_active_subscribers: active_automations.sum(:active_subscribers),
        average_completion_rate: active_automations.map(&:completion_rate).sum / active_automations.count.to_f,
        estimated_monthly_volume: active_automations.sum(&:estimated_monthly_sends)
      }
    end

    def calculate_average_rate(metrics, field)
      return 0 if metrics.empty?

      metrics.average(field) || 0
    end

    def calculate_deliverability_health_score(metrics)
      return 0 if metrics.empty?

      delivery_rate = calculate_average_rate(metrics, :delivery_rate)
      bounce_rate = calculate_average_rate(metrics, :bounce_rate)
      complaint_rate = calculate_average_rate(metrics, :complaint_rate)

      # Health score calculation (0-100)
      base_score = delivery_rate
      bounce_penalty = bounce_rate * 2 # Bounces are more serious
      complaint_penalty = complaint_rate * 5 # Complaints are very serious

      score = [ base_score - bounce_penalty - complaint_penalty, 0 ].max
      score.round(2)
    end

    def generate_deliverability_recommendations(metrics)
      return [] if metrics.empty?

      recommendations = []
      bounce_rate = calculate_average_rate(metrics, :bounce_rate)
      complaint_rate = calculate_average_rate(metrics, :complaint_rate)
      delivery_rate = calculate_average_rate(metrics, :delivery_rate)

      if bounce_rate > 5.0
        recommendations << {
          type: "high_bounce_rate",
          severity: "high",
          message: "High bounce rate detected (#{bounce_rate.round(2)}%). Consider list cleaning.",
          action: "Clean your email list and implement double opt-in"
        }
      end

      if complaint_rate > 0.5
        recommendations << {
          type: "high_complaint_rate",
          severity: "critical",
          message: "High spam complaint rate (#{complaint_rate.round(2)}%). Review email content and frequency.",
          action: "Review email content, subject lines, and sending frequency"
        }
      end

      if delivery_rate < 95.0
        recommendations << {
          type: "low_delivery_rate",
          severity: "medium",
          message: "Low delivery rate (#{delivery_rate.round(2)}%). Check sender reputation.",
          action: "Verify sender domain authentication and monitor IP reputation"
        }
      end

      recommendations
    end

    def calculate_daily_engagement_scores(daily_metrics)
      daily_metrics.map do |date, metrics|
        next [ date, 0 ] if metrics.empty?

        avg_open_rate = metrics.average(:open_rate) || 0
        avg_click_rate = metrics.average(:click_rate) || 0

        engagement_score = (avg_open_rate * 0.4 + avg_click_rate * 0.6).round(2)
        [ date, engagement_score ]
      end.to_h
    end
  end
end
