# frozen_string_literal: true

require "google/analytics/data"

module Analytics
  # Google Analytics 4 (GA4) API integration service for website behavior analytics,
  # user journey tracking, and conversion analysis with real-time capabilities
  class GoogleAnalyticsService
    include Analytics::RateLimitingService

    STANDARD_METRICS = %w[
      screenPageViews sessions users newUsers sessionDuration bounceRate
      conversions totalRevenue purchaseRevenue averagePurchaseRevenue
      eventCount userEngagementDuration engagementRate
    ].freeze

    STANDARD_DIMENSIONS = %w[
      date country city deviceCategory operatingSystem browser
      sessionSource sessionMedium sessionCampaign landingPage exitPage
      eventName customEvent pagePath pageTitle userType
    ].freeze

    CONVERSION_EVENTS = %w[
      purchase sign_up login download contact form_submit
      video_play newsletter_signup add_to_cart begin_checkout
    ].freeze

    class GoogleAnalyticsApiError < StandardError
      attr_reader :error_code, :error_type, :retry_after

      def initialize(message, error_code: nil, error_type: nil, retry_after: nil)
        super(message)
        @error_code = error_code
        @error_type = error_type
        @retry_after = retry_after
      end
    end

    def initialize(user_id:, property_id:)
      @user_id = user_id
      @property_id = property_id
      @oauth_service = GoogleOauthService.new(user_id: user_id, integration_type: :google_analytics)
      @client = build_analytics_client
    end

    # Get accessible GA4 properties for the authenticated user
    def accessible_properties
      with_rate_limiting("ga4_properties", user_id: @user_id) do
        admin_client = Google::Analytics::Admin.account_provisioning_service do |config|
          config.credentials = build_credentials
        end

        accounts_response = admin_client.list_accounts

        properties = []
        accounts_response.accounts.each do |account|
          account_properties = admin_client.list_properties(
            parent: account.name,
            filter: "parent:#{account.name}"
          )

          account_properties.properties.each do |property|
            properties << {
              property_id: property.name.split("/").last,
              display_name: property.display_name,
              account_name: account.display_name,
              currency_code: property.currency_code,
              time_zone: property.time_zone,
              industry_category: property.industry_category.to_s,
              property_type: property.property_type.to_s
            }
          end
        end

        cache_accessible_properties(properties)
        properties
      end
    rescue Google::Cloud::Error => e
      handle_analytics_error(e, "Failed to fetch accessible properties")
    end

    # Get standard website analytics report
    def website_analytics(start_date:, end_date:, metrics: STANDARD_METRICS, dimensions: STANDARD_DIMENSIONS)
      validate_date_range!(start_date, end_date)
      validate_inputs!(metrics, dimensions)

      with_rate_limiting("ga4_website_analytics", user_id: @user_id) do
        request = build_analytics_request(
          start_date: start_date,
          end_date: end_date,
          metrics: metrics,
          dimensions: dimensions
        )

        response = @client.run_report(request)

        {
          property_id: @property_id,
          date_range: { start_date: start_date, end_date: end_date },
          summary: extract_summary_metrics(response),
          data: extract_detailed_data(response),
          metadata: extract_metadata(response),
          generated_at: Time.current
        }
      end
    rescue Google::Cloud::Error => e
      handle_analytics_error(e, "Failed to fetch website analytics")
    end

    # Get user journey and funnel analysis
    def user_journey_analysis(start_date:, end_date:, conversion_events: CONVERSION_EVENTS)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("ga4_user_journey", user_id: @user_id) do
        # Funnel analysis
        funnel_data = analyze_conversion_funnel(start_date, end_date, conversion_events)

        # Path analysis
        path_data = analyze_user_paths(start_date, end_date)

        # Attribution analysis
        attribution_data = analyze_attribution(start_date, end_date, conversion_events)

        {
          property_id: @property_id,
          date_range: { start_date: start_date, end_date: end_date },
          funnel_analysis: funnel_data,
          path_analysis: path_data,
          attribution_analysis: attribution_data,
          generated_at: Time.current
        }
      end
    rescue Google::Cloud::Error => e
      handle_analytics_error(e, "Failed to fetch user journey analysis")
    end

    # Get audience insights and demographics
    def audience_insights(start_date:, end_date:)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("ga4_audience", user_id: @user_id) do
        demographic_data = fetch_demographic_data(start_date, end_date)
        technology_data = fetch_technology_data(start_date, end_date)
        geographic_data = fetch_geographic_data(start_date, end_date)
        behavior_data = fetch_behavior_data(start_date, end_date)

        {
          property_id: @property_id,
          date_range: { start_date: start_date, end_date: end_date },
          demographics: demographic_data,
          technology: technology_data,
          geography: geographic_data,
          behavior: behavior_data,
          generated_at: Time.current
        }
      end
    rescue Google::Cloud::Error => e
      handle_analytics_error(e, "Failed to fetch audience insights")
    end

    # Get real-time analytics data
    def real_time_analytics(metrics: %w[screenPageViews users], dimensions: %w[country deviceCategory])
      with_rate_limiting("ga4_realtime", user_id: @user_id) do
        request = Google::Analytics::Data::V1beta::RunRealtimeReportRequest.new(
          property: "properties/#{@property_id}",
          metrics: metrics.map { |m| { name: m } },
          dimensions: dimensions.map { |d| { name: d } }
        )

        response = @client.run_realtime_report(request)

        {
          property_id: @property_id,
          real_time_data: extract_realtime_data(response),
          active_users: response.row_count,
          generated_at: Time.current
        }
      end
    rescue Google::Cloud::Error => e
      handle_analytics_error(e, "Failed to fetch real-time analytics")
    end

    # Get ecommerce analytics
    def ecommerce_analytics(start_date:, end_date:)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("ga4_ecommerce", user_id: @user_id) do
        ecommerce_metrics = %w[
          purchaseRevenue totalRevenue averagePurchaseRevenue
          transactions itemsPurchased addToCarts
        ]

        ecommerce_dimensions = %w[
          date itemName itemCategory transactionId
          country deviceCategory sessionSource
        ]

        request = build_analytics_request(
          start_date: start_date,
          end_date: end_date,
          metrics: ecommerce_metrics,
          dimensions: ecommerce_dimensions
        )

        response = @client.run_report(request)

        {
          property_id: @property_id,
          date_range: { start_date: start_date, end_date: end_date },
          ecommerce_summary: extract_ecommerce_summary(response),
          product_performance: extract_product_data(response),
          transaction_data: extract_transaction_data(response),
          generated_at: Time.current
        }
      end
    rescue Google::Cloud::Error => e
      handle_analytics_error(e, "Failed to fetch ecommerce analytics")
    end

    # Get custom event tracking
    def custom_event_analytics(start_date:, end_date:, event_names: [])
      validate_date_range!(start_date, end_date)

      with_rate_limiting("ga4_custom_events", user_id: @user_id) do
        event_metrics = %w[eventCount userEngagementDuration]
        event_dimensions = %w[eventName customEvent date]
        event_dimensions += [ "customParameter1", "customParameter2" ] if event_names.any?

        request = build_analytics_request(
          start_date: start_date,
          end_date: end_date,
          metrics: event_metrics,
          dimensions: event_dimensions
        )

        # Add event name filter if specific events requested
        if event_names.any?
          request.dimension_filter = build_event_filter(event_names)
        end

        response = @client.run_report(request)

        {
          property_id: @property_id,
          date_range: { start_date: start_date, end_date: end_date },
          custom_events: extract_custom_event_data(response),
          event_summary: extract_event_summary(response),
          generated_at: Time.current
        }
      end
    rescue Google::Cloud::Error => e
      handle_analytics_error(e, "Failed to fetch custom event analytics")
    end

    # Get cohort analysis
    def cohort_analysis(start_date:, end_date:, cohort_spec: "WEEKLY")
      validate_date_range!(start_date, end_date)

      with_rate_limiting("ga4_cohort", user_id: @user_id) do
        request = Google::Analytics::Data::V1beta::RunReportRequest.new(
          property: "properties/#{@property_id}",
          date_ranges: [
            {
              start_date: start_date,
              end_date: end_date
            }
          ],
          metrics: [
            { name: "cohortActiveUsers" },
            { name: "cohortTotalUsers" },
            { name: "userRetentionRate" }
          ],
          dimensions: [
            { name: "cohort" },
            { name: "cohortNthWeek" }
          ],
          cohort_spec: {
            cohorts: [
              {
                name: "cohort",
                date_range: {
                  start_date: start_date,
                  end_date: end_date
                }
              }
            ],
            cohorts_range: {
              granularity: cohort_spec,
              start_offset: 0,
              end_offset: 4
            }
          }
        )

        response = @client.run_report(request)

        {
          property_id: @property_id,
          date_range: { start_date: start_date, end_date: end_date },
          cohort_data: extract_cohort_data(response),
          retention_analysis: calculate_retention_rates(response),
          generated_at: Time.current
        }
      end
    rescue Google::Cloud::Error => e
      handle_analytics_error(e, "Failed to fetch cohort analysis")
    end

    private

    attr_reader :user_id, :property_id, :oauth_service, :client

    def build_analytics_client
      Google::Analytics::Data.analytics_data do |config|
        config.credentials = build_credentials
      end
    end

    def build_credentials
      token = @oauth_service.access_token
      raise GoogleAnalyticsApiError.new("No valid access token", error_type: :auth_error) unless token

      Google::Auth::UserRefreshCredentials.new(
        client_id: google_client_id,
        client_secret: google_client_secret,
        refresh_token: token,
        scope: [ "https://www.googleapis.com/auth/analytics.readonly" ]
      )
    end

    def build_analytics_request(start_date:, end_date:, metrics:, dimensions:)
      Google::Analytics::Data::V1beta::RunReportRequest.new(
        property: "properties/#{@property_id}",
        date_ranges: [
          {
            start_date: start_date,
            end_date: end_date
          }
        ],
        metrics: metrics.map { |metric| { name: metric } },
        dimensions: dimensions.map { |dimension| { name: dimension } },
        keep_empty_rows: false,
        return_property_quota: true
      )
    end

    def analyze_conversion_funnel(start_date, end_date, conversion_events)
      funnel_steps = conversion_events.map.with_index do |event, index|
        {
          name: event,
          order_id: index
        }
      end

      request = Google::Analytics::Data::V1beta::RunFunnelReportRequest.new(
        property: "properties/#{@property_id}",
        date_ranges: [
          {
            start_date: start_date,
            end_date: end_date
          }
        ],
        funnel: {
          steps: funnel_steps.map do |step|
            {
              name: step[:name],
              filter_expression: {
                filter: {
                  field_name: "eventName",
                  string_filter: {
                    match_type: "EXACT",
                    value: step[:name]
                  }
                }
              }
            }
          end
        },
        funnel_breakdown: {
          breakdown_dimension: {
            name: "deviceCategory"
          }
        }
      )

      response = @client.run_funnel_report(request)
      extract_funnel_data(response)
    end

    def analyze_user_paths(start_date, end_date)
      request = build_analytics_request(
        start_date: start_date,
        end_date: end_date,
        metrics: %w[screenPageViews users sessions],
        dimensions: %w[landingPage exitPage sessionSource]
      )

      response = @client.run_report(request)
      extract_path_data(response)
    end

    def analyze_attribution(start_date, end_date, conversion_events)
      attribution_data = {}

      conversion_events.each do |event|
        request = build_analytics_request(
          start_date: start_date,
          end_date: end_date,
          metrics: %w[conversions totalRevenue],
          dimensions: %w[sessionSource sessionMedium sessionCampaign]
        )

        # Add event filter
        request.dimension_filter = {
          filter: {
            field_name: "eventName",
            string_filter: {
              match_type: "EXACT",
              value: event
            }
          }
        }

        response = @client.run_report(request)
        attribution_data[event] = extract_attribution_data(response)
      end

      attribution_data
    end

    def fetch_demographic_data(start_date, end_date)
      request = build_analytics_request(
        start_date: start_date,
        end_date: end_date,
        metrics: %w[users sessions screenPageViews],
        dimensions: %w[userAgeBracket userGender]
      )

      response = @client.run_report(request)
      extract_demographic_insights(response)
    end

    def fetch_technology_data(start_date, end_date)
      request = build_analytics_request(
        start_date: start_date,
        end_date: end_date,
        metrics: %w[users sessions],
        dimensions: %w[deviceCategory operatingSystem browser]
      )

      response = @client.run_report(request)
      extract_technology_insights(response)
    end

    def fetch_geographic_data(start_date, end_date)
      request = build_analytics_request(
        start_date: start_date,
        end_date: end_date,
        metrics: %w[users sessions screenPageViews],
        dimensions: %w[country city region]
      )

      response = @client.run_report(request)
      extract_geographic_insights(response)
    end

    def fetch_behavior_data(start_date, end_date)
      request = build_analytics_request(
        start_date: start_date,
        end_date: end_date,
        metrics: %w[userEngagementDuration bounceRate engagementRate sessionDuration],
        dimensions: %w[userType landingPage]
      )

      response = @client.run_report(request)
      extract_behavior_insights(response)
    end

    def extract_summary_metrics(response)
      return {} unless response.totals.any?

      total_row = response.totals.first
      response.metric_headers.map.with_index do |header, index|
        [ header.name, parse_metric_value(total_row.metric_values[index]) ]
      end.to_h
    end

    def extract_detailed_data(response)
      response.rows.map do |row|
        row_data = {}

        # Extract dimensions
        response.dimension_headers.each_with_index do |header, index|
          row_data[header.name] = row.dimension_values[index].value
        end

        # Extract metrics
        response.metric_headers.each_with_index do |header, index|
          row_data[header.name] = parse_metric_value(row.metric_values[index])
        end

        row_data
      end
    end

    def extract_metadata(response)
      {
        row_count: response.row_count,
        sampling_metadatas: response.metadata&.sampling_metadatas&.map(&:to_h),
        data_loss_from_other_row: response.metadata&.data_loss_from_other_row,
        schema_restriction_response: response.metadata&.schema_restriction_response&.to_h
      }
    end

    def extract_realtime_data(response)
      response.rows.map do |row|
        row_data = {}

        response.dimension_headers.each_with_index do |header, index|
          row_data[header.name] = row.dimension_values[index].value
        end

        response.metric_headers.each_with_index do |header, index|
          row_data[header.name] = parse_metric_value(row.metric_values[index])
        end

        row_data
      end
    end

    def extract_funnel_data(response)
      response.funnel_table.funnel_visualizations.map do |viz|
        {
          steps: viz.steps.map do |step|
            {
              name: step.name,
              users: step.users,
              completion_rate: step.completion_rate
            }
          end,
          breakdown: viz.breakdown&.to_h
        }
      end
    end

    def parse_metric_value(metric_value)
      case metric_value.value
      when /^\d+$/
        metric_value.value.to_i
      when /^\d*\.\d+$/
        metric_value.value.to_f
      else
        metric_value.value
      end
    end

    def validate_date_range!(start_date, end_date)
      start_date_obj = Date.parse(start_date)
      end_date_obj = Date.parse(end_date)

      raise ArgumentError, "Start date must be before end date" if start_date_obj > end_date_obj
      raise ArgumentError, "Date range cannot exceed 90 days" if (end_date_obj - start_date_obj).to_i > 90
    rescue Date::Error
      raise ArgumentError, "Invalid date format. Use YYYY-MM-DD"
    end

    def validate_inputs!(metrics, dimensions)
      invalid_metrics = metrics - STANDARD_METRICS
      invalid_dimensions = dimensions - STANDARD_DIMENSIONS

      if invalid_metrics.any?
        raise ArgumentError, "Unsupported metrics: #{invalid_metrics.join(', ')}"
      end

      if invalid_dimensions.any?
        raise ArgumentError, "Unsupported dimensions: #{invalid_dimensions.join(', ')}"
      end
    end

    def cache_accessible_properties(properties)
      cache_key = "ga4_properties:#{@user_id}"
      Rails.cache.write(cache_key, properties, expires_in: 1.hour)
    end

    def handle_analytics_error(error, context)
      Rails.logger.error "Google Analytics API Error - #{context}: #{error.message}"

      case error.class.name
      when "Google::Cloud::PermissionDeniedError"
        raise GoogleAnalyticsApiError.new(
          "Access denied. Please ensure your account has proper Analytics permissions.",
          error_code: "PERMISSION_DENIED",
          error_type: :permission_error
        )
      when "Google::Cloud::UnauthenticatedError"
        @oauth_service.invalidate_stored_tokens
        raise GoogleAnalyticsApiError.new(
          "Authentication failed. Please reconnect your Google Analytics account.",
          error_code: "UNAUTHENTICATED",
          error_type: :auth_error
        )
      when "Google::Cloud::ResourceExhaustedError"
        raise GoogleAnalyticsApiError.new(
          "API quota exceeded. Please try again later.",
          error_code: "QUOTA_EXCEEDED",
          error_type: :rate_limit,
          retry_after: 3600
        )
      else
        raise GoogleAnalyticsApiError.new(
          "Google Analytics API error: #{error.message}",
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
  end
end
