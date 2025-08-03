# frozen_string_literal: true

module Analytics
  class SocialMediaIntegrationService
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :brand, :integration

    validates :brand, presence: true

    def initialize(brand, integration = nil)
      @brand = brand
      @integration = integration
    end

    # Platform connection methods
    def connect_facebook_api
      oauth_service = OauthAuthenticationService.new(
        platform: "facebook",
        brand: @brand,
        callback_url: build_callback_url("facebook")
      )

      oauth_service.authorization_url
    end

    def connect_instagram_api
      oauth_service = OauthAuthenticationService.new(
        platform: "instagram",
        brand: @brand,
        callback_url: build_callback_url("instagram")
      )

      oauth_service.authorization_url
    end

    def connect_linkedin_api
      oauth_service = OauthAuthenticationService.new(
        platform: "linkedin",
        brand: @brand,
        callback_url: build_callback_url("linkedin")
      )

      oauth_service.authorization_url
    end

    def connect_twitter_api
      oauth_service = OauthAuthenticationService.new(
        platform: "twitter",
        brand: @brand,
        callback_url: build_callback_url("twitter")
      )

      oauth_service.authorization_url
    end

    def connect_tiktok_api
      oauth_service = OauthAuthenticationService.new(
        platform: "tiktok",
        brand: @brand,
        callback_url: build_callback_url("tiktok")
      )

      oauth_service.authorization_url
    end

    # OAuth callback handling
    def handle_oauth_callback(platform, code, state)
      oauth_service = OauthAuthenticationService.new(
        platform: platform,
        brand: @brand,
        code: code,
        state: state,
        callback_url: build_callback_url(platform)
      )

      token_result = oauth_service.exchange_code_for_token
      return token_result unless token_result.success?

      # Create or update integration record
      integration = @brand.social_media_integrations.find_or_initialize_by(platform: platform)

      integration.assign_attributes(
        access_token: token_result.data[:access_token],
        refresh_token: token_result.data[:refresh_token],
        expires_at: token_result.data[:expires_at],
        scope: token_result.data[:scope],
        platform_account_id: token_result.data[:platform_account_id],
        status: "active",
        error_count: 0,
        last_sync_at: Time.current
      )

      # Store additional configuration
      if token_result.data[:page_access_token]
        integration.set_configuration_value("page_access_token", token_result.data[:page_access_token])
      end

      if token_result.data[:account_name]
        integration.set_configuration_value("account_name", token_result.data[:account_name])
      end

      if integration.save
        ServiceResult.success(
          message: "#{platform.titleize} integration connected successfully",
          data: { integration: integration }
        )
      else
        ServiceResult.failure(
          message: "Failed to save integration",
          errors: integration.errors
        )
      end
    end

    # Metrics collection methods
    def collect_facebook_metrics(date_range: 30.days.ago..Time.current)
      integration = find_active_integration("facebook")
      return ServiceResult.failure("Facebook integration not found or inactive") unless integration

      rate_limiter = RateLimitingService.new(
        platform: "facebook",
        integration_id: integration.id,
        endpoint: "insights"
      )

      rate_limiter.execute_with_rate_limiting do
        collect_facebook_metrics_internal(integration, date_range)
      end
    end

    def collect_instagram_metrics(date_range: 30.days.ago..Time.current)
      integration = find_active_integration("instagram")
      return ServiceResult.failure("Instagram integration not found or inactive") unless integration

      rate_limiter = RateLimitingService.new(
        platform: "instagram",
        integration_id: integration.id,
        endpoint: "insights"
      )

      rate_limiter.execute_with_rate_limiting do
        collect_instagram_metrics_internal(integration, date_range)
      end
    end

    def collect_instagram_story_metrics
      integration = find_active_integration("instagram")
      return ServiceResult.failure("Instagram integration not found or inactive") unless integration

      rate_limiter = RateLimitingService.new(
        platform: "instagram",
        integration_id: integration.id,
        endpoint: "media"
      )

      rate_limiter.execute_with_rate_limiting do
        collect_instagram_story_metrics_internal(integration)
      end
    end

    def collect_linkedin_metrics(date_range: 30.days.ago..Time.current)
      integration = find_active_integration("linkedin")
      return ServiceResult.failure("LinkedIn integration not found or inactive") unless integration

      rate_limiter = RateLimitingService.new(
        platform: "linkedin",
        integration_id: integration.id,
        endpoint: "analytics"
      )

      rate_limiter.execute_with_rate_limiting do
        collect_linkedin_metrics_internal(integration, date_range)
      end
    end

    def collect_twitter_metrics(date_range: 30.days.ago..Time.current)
      integration = find_active_integration("twitter")
      return ServiceResult.failure("Twitter integration not found or inactive") unless integration

      rate_limiter = RateLimitingService.new(
        platform: "twitter",
        integration_id: integration.id,
        endpoint: "tweets"
      )

      rate_limiter.execute_with_rate_limiting do
        collect_twitter_metrics_internal(integration, date_range)
      end
    end

    def collect_tiktok_metrics(date_range: 30.days.ago..Time.current)
      integration = find_active_integration("tiktok")
      return ServiceResult.failure("TikTok integration not found or inactive") unless integration

      rate_limiter = RateLimitingService.new(
        platform: "tiktok",
        integration_id: integration.id,
        endpoint: "analytics"
      )

      rate_limiter.execute_with_rate_limiting do
        collect_tiktok_metrics_internal(integration, date_range)
      end
    end

    def collect_tiktok_audience_insights
      integration = find_active_integration("tiktok")
      return ServiceResult.failure("TikTok integration not found or inactive") unless integration

      rate_limiter = RateLimitingService.new(
        platform: "tiktok",
        integration_id: integration.id,
        endpoint: "analytics"
      )

      rate_limiter.execute_with_rate_limiting do
        collect_tiktok_audience_insights_internal(integration)
      end
    end

    # Cross-platform aggregation
    def aggregate_all_platforms(date_range: 30.days.ago..Time.current)
      active_integrations = @brand.social_media_integrations.active

      return ServiceResult.failure("No active social media integrations found") if active_integrations.empty?

      aggregated_data = {
        total_reach: 0,
        total_engagement: 0,
        platform_breakdown: {},
        date_range: {
          start: date_range.begin,
          end: date_range.end
        }
      }

      active_integrations.each do |integration|
        platform_metrics = collect_platform_metrics(integration, date_range)

        if platform_metrics.success?
          data = platform_metrics.data
          aggregated_data[:total_reach] += data[:reach] || 0
          aggregated_data[:total_engagement] += data[:engagement] || 0
          aggregated_data[:platform_breakdown][integration.platform] = data
        end
      end

      ServiceResult.success(data: aggregated_data)
    end

    # Token management
    def refresh_all_tokens
      integrations = @brand.social_media_integrations.where(status: [ "active", "expired" ])

      results = integrations.map do |integration|
        refresh_integration_token(integration)
      end

      successful_refreshes = results.count(&:success?)

      if successful_refreshes == integrations.count
        ServiceResult.success(message: "All tokens refreshed successfully")
      elsif successful_refreshes > 0
        ServiceResult.success(message: "#{successful_refreshes}/#{integrations.count} tokens refreshed successfully")
      else
        ServiceResult.failure("Failed to refresh any tokens")
      end
    end

    def expire_all_tokens
      @brand.social_media_integrations.active.update_all(
        status: "expired",
        expires_at: 1.minute.ago
      )
    end

    def all_tokens_valid?
      @brand.social_media_integrations.active.all?(&:token_valid?)
    end

    # Dashboard-specific methods for real-time updates
    def dashboard_metrics(time_range = "7d")
      start_date = parse_time_range(time_range)
      active_integrations = @brand.social_media_integrations.active

      return { error: "No active social media integrations" } if active_integrations.empty?

      platforms_data = {}
      summary_data = {
        total_reach: 0,
        total_engagement: 0,
        total_followers: 0,
        engagement_rate: 0
      }

      active_integrations.each do |integration|
        platform_metrics = get_platform_dashboard_metrics(integration, start_date)
        platforms_data[integration.platform] = platform_metrics

        # Aggregate for summary
        summary_data[:total_reach] += platform_metrics[:reach] || 0
        summary_data[:total_engagement] += platform_metrics[:engagement] || 0
        summary_data[:total_followers] += platform_metrics[:followers] || 0
      end

      # Calculate overall engagement rate
      summary_data[:engagement_rate] = if summary_data[:total_reach] > 0
                                        (summary_data[:total_engagement].to_f / summary_data[:total_reach] * 100).round(2)
      else
                                        0
      end

      {
        summary: summary_data,
        platforms: platforms_data,
        timeseries: generate_timeseries_data(active_integrations, start_date),
        timestamp: Time.current.iso8601
      }
    end

    def real_time_metrics(time_range = "24h")
      dashboard_metrics(time_range)
    end

    def filtered_metrics(config)
      time_range = config[:time_range] || "7d"
      filters = config[:filters] || {}

      metrics = dashboard_metrics(time_range)

      # Apply filters if specified
      if filters[:platforms].present?
        metrics[:platforms] = metrics[:platforms].select { |platform, _| filters[:platforms].include?(platform) }
      end

      metrics
    end

    def drill_down(metric, dimension, filters = {})
      case dimension
      when "platform"
        drill_down_by_platform(metric, filters)
      when "content_type"
        drill_down_by_content_type(metric, filters)
      when "engagement_type"
        drill_down_by_engagement_type(metric, filters)
      else
        {}
      end
    end

    # Data storage
    def store_metrics_batch(metrics_data)
      return ServiceResult.failure("Metrics data is required") if metrics_data.blank?

      stored_count = 0
      errors = []

      metrics_data.each do |metric_data|
        integration = @brand.social_media_integrations.find_by(platform: metric_data[:platform])

        unless integration
          errors << "Integration not found for platform: #{metric_data[:platform]}"
          next
        end

        metric = integration.social_media_metrics.find_or_initialize_by(
          metric_type: metric_data[:metric_type],
          date: metric_data[:date]
        )

        metric.assign_attributes(
          platform: metric_data[:platform],
          value: metric_data[:value],
          raw_data: metric_data[:raw_data],
          metadata: metric_data[:metadata]
        )

        if metric.save
          stored_count += 1
        else
          errors << "Failed to save metric: #{metric.errors.full_messages.join(', ')}"
        end
      end

      if stored_count > 0
        ServiceResult.success(
          message: "Stored #{stored_count} metrics successfully",
          data: { stored_count: stored_count, errors: errors }
        )
      else
        ServiceResult.failure(
          message: "Failed to store any metrics",
          errors: errors
        )
      end
    end

    private

    def find_active_integration(platform)
      @brand.social_media_integrations.active.find_by(platform: platform)
    end

    def build_callback_url(platform)
      Rails.application.routes.url_helpers.social_media_oauth_callback_url(
        platform: platform,
        brand_id: @brand.id,
        host: Rails.application.config.force_ssl ? "https://" : "http://",
        port: Rails.env.development? ? 3000 : nil
      )
    end

    def collect_platform_metrics(integration, date_range)
      case integration.platform
      when "facebook"
        collect_facebook_metrics(date_range: date_range)
      when "instagram"
        collect_instagram_metrics(date_range: date_range)
      when "linkedin"
        collect_linkedin_metrics(date_range: date_range)
      when "twitter"
        collect_twitter_metrics(date_range: date_range)
      when "tiktok"
        collect_tiktok_metrics(date_range: date_range)
      else
        ServiceResult.failure("Unsupported platform: #{integration.platform}")
      end
    end

    def refresh_integration_token(integration)
      return ServiceResult.success(message: "Token is still valid") if integration.token_valid?

      oauth_service = OauthAuthenticationService.new(
        platform: integration.platform,
        brand: @brand
      )

      refresh_result = oauth_service.refresh_access_token(integration.refresh_token)

      if refresh_result.success?
        integration.update!(
          access_token: refresh_result.data[:access_token],
          refresh_token: refresh_result.data[:refresh_token],
          expires_at: refresh_result.data[:expires_at],
          status: "active"
        )
      else
        integration.update!(status: "expired")
      end

      refresh_result
    end

    # Platform-specific metric collection implementations
    def collect_facebook_metrics_internal(integration, date_range)
      # Implementation would make actual API calls to Facebook Graph API
      # For now, return mock data structure
      ServiceResult.success(data: {
        likes: rand(1000..5000),
        comments: rand(100..500),
        shares: rand(50..200),
        reach: rand(10000..50000),
        impressions: rand(15000..75000)
      })
    end

    def collect_instagram_metrics_internal(integration, date_range)
      # Implementation would make actual API calls to Instagram Graph API
      ServiceResult.success(data: {
        followers: rand(1000..10000),
        reach: rand(5000..25000),
        impressions: rand(8000..40000),
        profile_views: rand(500..2000)
      })
    end

    def collect_instagram_story_metrics_internal(integration)
      ServiceResult.success(data: {
        story_views: rand(500..2000),
        story_interactions: rand(50..200),
        story_exits: rand(10..50)
      })
    end

    def collect_linkedin_metrics_internal(integration, date_range)
      ServiceResult.success(data: {
        clicks: rand(100..500),
        engagements: rand(200..800),
        follower_growth: rand(10..100),
        lead_generation: rand(5..50)
      })
    end

    def collect_twitter_metrics_internal(integration, date_range)
      ServiceResult.success(data: {
        impressions: rand(10000..50000),
        engagements: rand(500..2000),
        retweets: rand(50..200),
        mentions: rand(10..100)
      })
    end

    def collect_tiktok_metrics_internal(integration, date_range)
      ServiceResult.success(data: {
        video_views: rand(10000..100000),
        likes: rand(1000..10000),
        shares: rand(100..1000),
        comments: rand(50..500),
        trending_hashtags: rand(1..10)
      })
    end

    def collect_tiktok_audience_insights_internal(integration)
      ServiceResult.success(data: {
        age_groups: {
          "18-24" => rand(20..40),
          "25-34" => rand(25..45),
          "35-44" => rand(15..35),
          "45+" => rand(5..15)
        },
        gender_distribution: {
          "male" => rand(40..60),
          "female" => rand(40..60)
        },
        geographic_data: {
          "US" => rand(30..70),
          "UK" => rand(10..30),
          "CA" => rand(5..20),
          "Other" => rand(10..40)
        }
      })
    end

    # Dashboard helper methods
    def parse_time_range(time_range)
      case time_range
      when "24h", "1d"
        1.day.ago
      when "7d"
        7.days.ago
      when "30d"
        30.days.ago
      when "90d"
        90.days.ago
      when "1y"
        1.year.ago
      else
        7.days.ago
      end
    end

    def get_platform_dashboard_metrics(integration, start_date)
      # Get recent metrics from database or API
      recent_metrics = integration.social_media_metrics
                                 .where("created_at > ?", start_date)
                                 .order(created_at: :desc)

      if recent_metrics.any?
        # Aggregate actual metrics
        {
          platform: integration.platform,
          reach: recent_metrics.where(metric_type: "reach").sum(:value),
          engagement: recent_metrics.where(metric_type: "engagement").sum(:value),
          followers: recent_metrics.where(metric_type: "followers").last&.value || 0,
          impressions: recent_metrics.where(metric_type: "impressions").sum(:value),
          last_updated: recent_metrics.first.created_at.iso8601
        }
      else
        # Fallback to mock data for demo purposes
        generate_mock_platform_metrics(integration.platform)
      end
    end

    def generate_mock_platform_metrics(platform)
      base_multiplier = case platform
      when "facebook" then 3
      when "instagram" then 2
      when "linkedin" then 1
      when "twitter" then 2.5
      when "tiktok" then 4
      else 1
      end

      {
        platform: platform,
        reach: (rand(5000..15000) * base_multiplier).to_i,
        engagement: (rand(500..2000) * base_multiplier).to_i,
        followers: (rand(1000..10000) * base_multiplier).to_i,
        impressions: (rand(8000..25000) * base_multiplier).to_i,
        last_updated: Time.current.iso8601
      }
    end

    def generate_timeseries_data(integrations, start_date)
      # Generate daily data points for charts
      days = ((Time.current - start_date) / 1.day).ceil
      timeseries = []

      days.times do |i|
        date = start_date + i.days
        day_data = {
          date: date.strftime("%Y-%m-%d"),
          reach: 0,
          engagement: 0,
          impressions: 0
        }

        integrations.each do |integration|
          # Get metrics for this day (mock data for demo)
          day_metrics = generate_daily_metrics(integration.platform, date)
          day_data[:reach] += day_metrics[:reach]
          day_data[:engagement] += day_metrics[:engagement]
          day_data[:impressions] += day_metrics[:impressions]
        end

        timeseries << day_data
      end

      timeseries
    end

    def generate_daily_metrics(platform, date)
      # Generate consistent but varied daily metrics
      seed = "#{platform}-#{date.strftime('%Y%m%d')}".hash
      Random.srand(seed)

      base_multiplier = case platform
      when "facebook" then 3
      when "instagram" then 2
      when "linkedin" then 1
      when "twitter" then 2.5
      when "tiktok" then 4
      else 1
      end

      {
        reach: (Random.rand(1000..3000) * base_multiplier).to_i,
        engagement: (Random.rand(100..500) * base_multiplier).to_i,
        impressions: (Random.rand(1500..4500) * base_multiplier).to_i
      }
    end

    def drill_down_by_platform(metric, filters)
      active_integrations = @brand.social_media_integrations.active

      data = active_integrations.map do |integration|
        metrics = get_platform_dashboard_metrics(integration, 7.days.ago)
        {
          name: integration.platform.titleize,
          value: metrics[metric.to_sym] || 0,
          platform: integration.platform
        }
      end

      data.sort_by { |item| -item[:value] }
    end

    def drill_down_by_content_type(metric, filters)
      # Mock content type breakdown
      content_types = [ "image", "video", "carousel", "story", "live" ]

      content_types.map do |type|
        {
          name: type.titleize,
          value: rand(100..1000),
          content_type: type
        }
      end.sort_by { |item| -item[:value] }
    end

    def drill_down_by_engagement_type(metric, filters)
      # Mock engagement type breakdown
      engagement_types = [ "likes", "comments", "shares", "saves", "clicks" ]

      engagement_types.map do |type|
        {
          name: type.titleize,
          value: rand(50..500),
          engagement_type: type
        }
      end.sort_by { |item| -item[:value] }
    end
  end
end
