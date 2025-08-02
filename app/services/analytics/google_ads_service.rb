# frozen_string_literal: true

require "google/ads/google_ads"

module Analytics
  # Google Ads API integration service for campaign performance, conversion tracking,
  # and budget monitoring with comprehensive error handling and rate limiting
  class GoogleAdsService
    include Analytics::RateLimitingService

    SUPPORTED_METRICS = %w[
      impressions clicks cost conversions conversion_rate cost_per_conversion
      click_through_rate cost_per_click average_position search_impression_share
      search_lost_impression_share_budget search_lost_impression_share_rank
    ].freeze

    CONVERSION_ACTIONS = %w[
      purchase lead signup download app_install phone_call
    ].freeze

    class GoogleAdsApiError < StandardError
      attr_reader :error_code, :error_type, :retry_after

      def initialize(message, error_code: nil, error_type: nil, retry_after: nil)
        super(message)
        @error_code = error_code
        @error_type = error_type
        @retry_after = retry_after
      end
    end

    def initialize(user_id:, customer_id: nil)
      @user_id = user_id
      @customer_id = customer_id
      @oauth_service = GoogleOauthService.new(user_id: user_id, integration_type: :google_ads)
      @client = build_google_ads_client
    end

    # Get all accessible Google Ads accounts for the authenticated user
    def accessible_accounts
      with_rate_limiting("google_ads_accounts", user_id: @user_id) do
        query = build_accounts_query
        response = execute_search_request(query, customer_id: "0")

        accounts = response.map do |row|
          customer = row.customer
          {
            id: customer.id.to_s,
            name: customer.descriptive_name,
            currency_code: customer.currency_code,
            time_zone: customer.time_zone,
            status: customer.status.to_s,
            test_account: customer.test_account,
            manager: customer.manager,
            auto_tagging_enabled: customer.auto_tagging_enabled
          }
        end

        cache_accessible_accounts(accounts)
        accounts
      end
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      handle_google_ads_error(e, "Failed to fetch accessible accounts")
    end

    # Get campaign performance metrics for a specific date range
    def campaign_performance(start_date:, end_date:, metrics: SUPPORTED_METRICS)
      validate_date_range!(start_date, end_date)
      validate_metrics!(metrics)

      with_rate_limiting("google_ads_campaigns", user_id: @user_id) do
        query = build_campaign_performance_query(start_date, end_date, metrics)
        response = execute_search_request(query)

        campaigns = response.map do |row|
          campaign = row.campaign
          campaign_metrics = row.metrics

          build_campaign_performance_data(campaign, campaign_metrics, metrics)
        end

        {
          customer_id: @customer_id,
          date_range: { start_date: start_date, end_date: end_date },
          campaigns: campaigns,
          generated_at: Time.current
        }
      end
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      handle_google_ads_error(e, "Failed to fetch campaign performance")
    end

    # Get ad group performance with detailed metrics
    def ad_group_performance(campaign_id: nil, start_date:, end_date:, metrics: SUPPORTED_METRICS)
      validate_date_range!(start_date, end_date)
      validate_metrics!(metrics)

      with_rate_limiting("google_ads_ad_groups", user_id: @user_id) do
        query = build_ad_group_performance_query(campaign_id, start_date, end_date, metrics)
        response = execute_search_request(query)

        ad_groups = response.map do |row|
          ad_group = row.ad_group
          campaign = row.campaign
          ad_group_metrics = row.metrics

          {
            id: ad_group.id.to_s,
            name: ad_group.name,
            status: ad_group.status.to_s,
            campaign: {
              id: campaign.id.to_s,
              name: campaign.name
            },
            metrics: extract_metrics_data(ad_group_metrics, metrics)
          }
        end

        {
          customer_id: @customer_id,
          date_range: { start_date: start_date, end_date: end_date },
          ad_groups: ad_groups,
          generated_at: Time.current
        }
      end
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      handle_google_ads_error(e, "Failed to fetch ad group performance")
    end

    # Get conversion tracking data with attribution modeling
    def conversion_data(start_date:, end_date:, conversion_actions: CONVERSION_ACTIONS)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("google_ads_conversions", user_id: @user_id) do
        query = build_conversion_query(start_date, end_date, conversion_actions)
        response = execute_search_request(query)

        conversions = response.map do |row|
          campaign = row.campaign
          conversion_action = row.conversion_action
          metrics = row.metrics

          {
            campaign: {
              id: campaign.id.to_s,
              name: campaign.name
            },
            conversion_action: {
              id: conversion_action.id.to_s,
              name: conversion_action.name,
              category: conversion_action.category.to_s,
              type: conversion_action.type.to_s
            },
            conversions: metrics.conversions,
            conversion_value: metrics.conversion_value,
            cost_per_conversion: metrics.cost_per_conversion,
            conversion_rate: metrics.conversion_rate,
            view_through_conversions: metrics.view_through_conversions
          }
        end

        {
          customer_id: @customer_id,
          date_range: { start_date: start_date, end_date: end_date },
          conversions: conversions,
          attribution_model: "last_click", # Default attribution model
          generated_at: Time.current
        }
      end
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      handle_google_ads_error(e, "Failed to fetch conversion data")
    end

    # Monitor budget utilization and pacing
    def budget_monitoring(start_date:, end_date:)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("google_ads_budgets", user_id: @user_id) do
        query = build_budget_monitoring_query(start_date, end_date)
        response = execute_search_request(query)

        budgets = response.map do |row|
          campaign = row.campaign
          budget = row.campaign_budget
          metrics = row.metrics

          daily_budget = budget.amount_micros / 1_000_000.0
          total_cost = metrics.cost / 1_000_000.0

          days_in_period = (Date.parse(end_date) - Date.parse(start_date)).to_i + 1
          expected_budget = daily_budget * days_in_period
          budget_utilization = expected_budget > 0 ? (total_cost / expected_budget) * 100 : 0

          {
            campaign: {
              id: campaign.id.to_s,
              name: campaign.name,
              status: campaign.status.to_s
            },
            budget: {
              id: budget.id.to_s,
              name: budget.name,
              daily_amount: daily_budget,
              total_amount: budget.total_amount&.fdiv(1_000_000.0),
              delivery_method: budget.delivery_method.to_s
            },
            performance: {
              total_cost: total_cost,
              expected_budget: expected_budget,
              budget_utilization_percent: budget_utilization.round(2),
              impressions: metrics.impressions,
              clicks: metrics.clicks,
              average_cpc: metrics.average_cpc / 1_000_000.0
            }
          }
        end

        {
          customer_id: @customer_id,
          date_range: { start_date: start_date, end_date: end_date },
          budgets: budgets,
          generated_at: Time.current
        }
      end
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      handle_google_ads_error(e, "Failed to fetch budget monitoring data")
    end

    # Get keyword performance data
    def keyword_performance(campaign_id: nil, start_date:, end_date:, limit: 100)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("google_ads_keywords", user_id: @user_id) do
        query = build_keyword_performance_query(campaign_id, start_date, end_date, limit)
        response = execute_search_request(query)

        keywords = response.map do |row|
          campaign = row.campaign
          ad_group = row.ad_group
          keyword = row.ad_group_criterion.keyword
          metrics = row.metrics

          {
            campaign: {
              id: campaign.id.to_s,
              name: campaign.name
            },
            ad_group: {
              id: ad_group.id.to_s,
              name: ad_group.name
            },
            keyword: {
              text: keyword.text,
              match_type: keyword.match_type.to_s
            },
            metrics: {
              impressions: metrics.impressions,
              clicks: metrics.clicks,
              cost: metrics.cost / 1_000_000.0,
              ctr: metrics.ctr,
              average_cpc: metrics.average_cpc / 1_000_000.0,
              conversions: metrics.conversions,
              conversion_rate: metrics.conversion_rate,
              quality_score: row.ad_group_criterion.quality_info&.quality_score || 0
            }
          }
        end

        {
          customer_id: @customer_id,
          date_range: { start_date: start_date, end_date: end_date },
          keywords: keywords,
          generated_at: Time.current
        }
      end
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      handle_google_ads_error(e, "Failed to fetch keyword performance")
    end

    # Get audience insights and demographics
    def audience_insights(start_date:, end_date:)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("google_ads_audience", user_id: @user_id) do
        demographic_data = fetch_demographic_performance(start_date, end_date)
        geographic_data = fetch_geographic_performance(start_date, end_date)
        device_data = fetch_device_performance(start_date, end_date)

        {
          customer_id: @customer_id,
          date_range: { start_date: start_date, end_date: end_date },
          demographics: demographic_data,
          geography: geographic_data,
          devices: device_data,
          generated_at: Time.current
        }
      end
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      handle_google_ads_error(e, "Failed to fetch audience insights")
    end

    private

    attr_reader :user_id, :customer_id, :oauth_service, :client

    def build_google_ads_client
      Google::Ads::GoogleAds::GoogleAdsClient.new do |config|
        config.client_id = google_client_id
        config.client_secret = google_client_secret
        config.refresh_token = oauth_service.access_token
        config.developer_token = google_ads_developer_token
        config.login_customer_id = @customer_id
      end
    end

    def execute_search_request(query, customer_id: @customer_id)
      service = @client.service.google_ads
      request = @client.resource.search_google_ads_request do |req|
        req.customer_id = customer_id
        req.query = query
        req.page_size = 10_000
      end

      response = service.search(request)
      response.results
    end

    def build_accounts_query
      <<~QUERY
        SELECT
          customer.id,
          customer.descriptive_name,
          customer.currency_code,
          customer.time_zone,
          customer.status,
          customer.test_account,
          customer.manager,
          customer.auto_tagging_enabled
        FROM customer
        WHERE customer.status != 'CLOSED'
      QUERY
    end

    def build_campaign_performance_query(start_date, end_date, metrics)
      metric_fields = metrics.map { |m| "metrics.#{m}" }.join(", ")

      <<~QUERY
        SELECT
          campaign.id,
          campaign.name,
          campaign.status,
          campaign.advertising_channel_type,
          campaign.bidding_strategy_type,
          #{metric_fields}
        FROM campaign
        WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
          AND campaign.status != 'REMOVED'
      QUERY
    end

    def build_ad_group_performance_query(campaign_id, start_date, end_date, metrics)
      metric_fields = metrics.map { |m| "metrics.#{m}" }.join(", ")
      campaign_filter = campaign_id ? "AND campaign.id = #{campaign_id}" : ""

      <<~QUERY
        SELECT
          campaign.id,
          campaign.name,
          ad_group.id,
          ad_group.name,
          ad_group.status,
          #{metric_fields}
        FROM ad_group
        WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
          AND ad_group.status != 'REMOVED'
          #{campaign_filter}
      QUERY
    end

    def build_conversion_query(start_date, end_date, conversion_actions)
      <<~QUERY
        SELECT
          campaign.id,
          campaign.name,
          conversion_action.id,
          conversion_action.name,
          conversion_action.category,
          conversion_action.type,
          metrics.conversions,
          metrics.conversion_value,
          metrics.cost_per_conversion,
          metrics.conversion_rate,
          metrics.view_through_conversions
        FROM conversion_action
        WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
          AND conversion_action.status != 'REMOVED'
      QUERY
    end

    def build_budget_monitoring_query(start_date, end_date)
      <<~QUERY
        SELECT
          campaign.id,
          campaign.name,
          campaign.status,
          campaign_budget.id,
          campaign_budget.name,
          campaign_budget.amount_micros,
          campaign_budget.total_amount_micros,
          campaign_budget.delivery_method,
          metrics.cost,
          metrics.impressions,
          metrics.clicks,
          metrics.average_cpc
        FROM campaign
        WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
          AND campaign.status != 'REMOVED'
      QUERY
    end

    def build_keyword_performance_query(campaign_id, start_date, end_date, limit)
      campaign_filter = campaign_id ? "AND campaign.id = #{campaign_id}" : ""

      <<~QUERY
        SELECT
          campaign.id,
          campaign.name,
          ad_group.id,
          ad_group.name,
          ad_group_criterion.keyword.text,
          ad_group_criterion.keyword.match_type,
          ad_group_criterion.quality_info.quality_score,
          metrics.impressions,
          metrics.clicks,
          metrics.cost,
          metrics.ctr,
          metrics.average_cpc,
          metrics.conversions,
          metrics.conversion_rate
        FROM keyword_view
        WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
          AND ad_group_criterion.status != 'REMOVED'
          #{campaign_filter}
        ORDER BY metrics.impressions DESC
        LIMIT #{limit}
      QUERY
    end

    def fetch_demographic_performance(start_date, end_date)
      query = <<~QUERY
        SELECT
          campaign.id,
          campaign.name,
          ad_group.id,
          ad_group.name,
          segments.age_range,
          segments.gender,
          metrics.impressions,
          metrics.clicks,
          metrics.cost,
          metrics.conversions
        FROM age_range_view
        WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
      QUERY

      response = execute_search_request(query)

      response.group_by { |row| [ row.segments.age_range, row.segments.gender ] }
             .transform_values do |rows|
               {
                 impressions: rows.sum { |r| r.metrics.impressions },
                 clicks: rows.sum { |r| r.metrics.clicks },
                 cost: rows.sum { |r| r.metrics.cost } / 1_000_000.0,
                 conversions: rows.sum { |r| r.metrics.conversions }
               }
             end
    end

    def fetch_geographic_performance(start_date, end_date)
      query = <<~QUERY
        SELECT
          campaign.id,
          campaign.name,
          segments.geo_target_region,
          metrics.impressions,
          metrics.clicks,
          metrics.cost,
          metrics.conversions
        FROM geographic_view
        WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
        ORDER BY metrics.impressions DESC
        LIMIT 50
      QUERY

      response = execute_search_request(query)

      response.map do |row|
        {
          region: row.segments.geo_target_region,
          metrics: {
            impressions: row.metrics.impressions,
            clicks: row.metrics.clicks,
            cost: row.metrics.cost / 1_000_000.0,
            conversions: row.metrics.conversions
          }
        }
      end
    end

    def fetch_device_performance(start_date, end_date)
      query = <<~QUERY
        SELECT
          campaign.id,
          campaign.name,
          segments.device,
          metrics.impressions,
          metrics.clicks,
          metrics.cost,
          metrics.conversions
        FROM campaign
        WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
          AND campaign.status != 'REMOVED'
      QUERY

      response = execute_search_request(query)

      response.group_by { |row| row.segments.device }
             .transform_values do |rows|
               {
                 impressions: rows.sum { |r| r.metrics.impressions },
                 clicks: rows.sum { |r| r.metrics.clicks },
                 cost: rows.sum { |r| r.metrics.cost } / 1_000_000.0,
                 conversions: rows.sum { |r| r.metrics.conversions }
               }
             end
    end

    def build_campaign_performance_data(campaign, metrics, metric_names)
      {
        id: campaign.id.to_s,
        name: campaign.name,
        status: campaign.status.to_s,
        advertising_channel_type: campaign.advertising_channel_type.to_s,
        bidding_strategy_type: campaign.bidding_strategy_type.to_s,
        metrics: extract_metrics_data(metrics, metric_names)
      }
    end

    def extract_metrics_data(metrics, metric_names)
      metric_names.index_with do |metric|
        value = metrics.send(metric)

        # Convert cost metrics from micros to currency units
        if metric.include?("cost") && value.is_a?(Numeric)
          value / 1_000_000.0
        else
          value
        end
      end
    end

    def validate_date_range!(start_date, end_date)
      start_date_obj = Date.parse(start_date)
      end_date_obj = Date.parse(end_date)

      raise ArgumentError, "Start date must be before end date" if start_date_obj > end_date_obj
      raise ArgumentError, "Date range cannot exceed 90 days" if (end_date_obj - start_date_obj).to_i > 90
      raise ArgumentError, "End date cannot be in the future" if end_date_obj > Date.current
    rescue Date::Error
      raise ArgumentError, "Invalid date format. Use YYYY-MM-DD"
    end

    def validate_metrics!(metrics)
      invalid_metrics = metrics - SUPPORTED_METRICS
      return if invalid_metrics.empty?

      raise ArgumentError, "Unsupported metrics: #{invalid_metrics.join(', ')}"
    end

    def cache_accessible_accounts(accounts)
      cache_key = "google_ads_accounts:#{@user_id}"
      Rails.cache.write(cache_key, accounts, expires_in: 1.hour)
    end

    def handle_google_ads_error(error, context)
      error_details = error.failure&.errors&.first

      Rails.logger.error "Google Ads API Error - #{context}: #{error.message}"
      Rails.logger.error "Error details: #{error_details&.message}" if error_details

      case error_details&.error_code&.name
      when "QUOTA_EXCEEDED"
        raise GoogleAdsApiError.new(
          "API quota exceeded. Please try again later.",
          error_code: "QUOTA_EXCEEDED",
          error_type: :rate_limit,
          retry_after: 3600
        )
      when "AUTHENTICATION_ERROR"
        oauth_service.invalidate_stored_tokens
        raise GoogleAdsApiError.new(
          "Authentication failed. Please reconnect your Google Ads account.",
          error_code: "AUTHENTICATION_ERROR",
          error_type: :auth_error
        )
      when "AUTHORIZATION_ERROR"
        raise GoogleAdsApiError.new(
          "Access denied. Please ensure your account has proper permissions.",
          error_code: "AUTHORIZATION_ERROR",
          error_type: :permission_error
        )
      else
        raise GoogleAdsApiError.new(
          "Google Ads API error: #{error.message}",
          error_code: error_details&.error_code&.name,
          error_type: :api_error
        )
      end
    end

    def google_client_id
      Rails.application.credentials.dig(:google, :client_id) ||
        ENV["GOOGLE_CLIENT_ID"]
    end

    def google_client_secret
      Rails.application.credentials.dig(:google, :client_secret) ||
        ENV["GOOGLE_CLIENT_SECRET"]
    end

    def google_ads_developer_token
      Rails.application.credentials.dig(:google, :ads_developer_token) ||
        ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
    end
  end
end
