# frozen_string_literal: true

module Analytics
  # Attribution modeling service that correlates data across Google Ads, Analytics,
  # and Search Console to provide unified customer journey insights and conversion attribution
  class AttributionModelingService
    include Analytics::RateLimitingService

    ATTRIBUTION_MODELS = %w[
      first_click last_click linear time_decay position_based data_driven
    ].freeze

    TOUCHPOINT_TYPES = %w[
      paid_search organic_search social_media email direct display
      referral affiliate video shopping
    ].freeze

    CONVERSION_EVENTS = %w[
      purchase lead_generation signup download app_install phone_call
      form_submission newsletter_signup add_to_cart
    ].freeze

    class AttributionError < StandardError
      attr_reader :error_code, :error_type

      def initialize(message, error_code: nil, error_type: nil)
        super(message)
        @error_code = error_code
        @error_type = error_type
      end
    end

    def initialize(user_id:, google_ads_customer_id: nil, ga4_property_id: nil, search_console_site: nil)
      @user_id = user_id
      @google_ads_customer_id = google_ads_customer_id
      @ga4_property_id = ga4_property_id
      @search_console_site = search_console_site

      initialize_service_clients
    end

    # Generate comprehensive attribution analysis across all Google platforms
    def cross_platform_attribution(start_date:, end_date:, attribution_model: "last_click", conversion_events: CONVERSION_EVENTS)
      validate_date_range!(start_date, end_date)
      validate_attribution_model!(attribution_model)

      with_rate_limiting("attribution_analysis", user_id: @user_id) do
        # Collect data from all platforms
        google_ads_data = fetch_google_ads_attribution_data(start_date, end_date, conversion_events)
        ga4_data = fetch_ga4_attribution_data(start_date, end_date, conversion_events)
        search_console_data = fetch_search_console_attribution_data(start_date, end_date)

        # Correlate and model attribution
        unified_touchpoints = unify_touchpoint_data(google_ads_data, ga4_data, search_console_data)
        attribution_analysis = apply_attribution_model(unified_touchpoints, attribution_model)
        journey_insights = analyze_customer_journeys(unified_touchpoints)

        {
          date_range: { start_date: start_date, end_date: end_date },
          attribution_model: attribution_model,
          platform_data: {
            google_ads: google_ads_data[:summary],
            google_analytics: ga4_data[:summary],
            search_console: search_console_data[:summary]
          },
          unified_attribution: attribution_analysis,
          customer_journey_insights: journey_insights,
          cross_platform_metrics: calculate_cross_platform_metrics(attribution_analysis),
          generated_at: Time.current
        }
      end
    rescue Google::Cloud::Error, Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      handle_attribution_error(e, "Cross-platform attribution analysis failed")
    end

    # Analyze customer journey paths and conversion funnels
    def customer_journey_analysis(start_date:, end_date:, lookback_window: 30)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("customer_journey", user_id: @user_id) do
        # Collect touchpoint sequences
        touchpoint_sequences = collect_touchpoint_sequences(start_date, end_date, lookback_window)

        # Analyze journey patterns
        journey_patterns = identify_journey_patterns(touchpoint_sequences)
        conversion_paths = analyze_conversion_paths(touchpoint_sequences)
        drop_off_analysis = analyze_journey_drop_offs(touchpoint_sequences)

        {
          date_range: { start_date: start_date, end_date: end_date },
          lookback_window_days: lookback_window,
          journey_patterns: journey_patterns,
          top_conversion_paths: conversion_paths[:top_paths],
          conversion_funnel: conversion_paths[:funnel_analysis],
          drop_off_points: drop_off_analysis,
          journey_insights: generate_journey_insights(journey_patterns, conversion_paths),
          generated_at: Time.current
        }
      end
    rescue StandardError => e
      handle_attribution_error(e, "Customer journey analysis failed")
    end

    # Calculate return on ad spend (ROAS) across platforms
    def cross_platform_roas(start_date:, end_date:, attribution_model: "last_click")
      validate_date_range!(start_date, end_date)
      validate_attribution_model!(attribution_model)

      with_rate_limiting("cross_platform_roas", user_id: @user_id) do
        # Get spend data from Google Ads
        ads_spend_data = fetch_google_ads_spend_data(start_date, end_date)

        # Get revenue data from GA4
        ga4_revenue_data = fetch_ga4_revenue_data(start_date, end_date)

        # Apply attribution modeling to revenue
        attributed_revenue = apply_revenue_attribution(ga4_revenue_data, attribution_model)

        # Calculate ROAS by channel
        roas_by_channel = calculate_roas_by_channel(ads_spend_data, attributed_revenue)

        # Generate efficiency insights
        efficiency_insights = generate_efficiency_insights(roas_by_channel, ads_spend_data)

        {
          date_range: { start_date: start_date, end_date: end_date },
          attribution_model: attribution_model,
          total_spend: ads_spend_data[:total_spend],
          total_attributed_revenue: attributed_revenue[:total_revenue],
          overall_roas: calculate_overall_roas(ads_spend_data[:total_spend], attributed_revenue[:total_revenue]),
          roas_by_channel: roas_by_channel,
          efficiency_insights: efficiency_insights,
          recommendations: generate_roas_recommendations(roas_by_channel),
          generated_at: Time.current
        }
      end
    rescue StandardError => e
      handle_attribution_error(e, "Cross-platform ROAS analysis failed")
    end

    # Analyze channel interaction and synergy effects
    def channel_interaction_analysis(start_date:, end_date:)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("channel_interaction", user_id: @user_id) do
        # Get touchpoint interaction data
        interaction_data = fetch_channel_interaction_data(start_date, end_date)

        # Analyze channel combinations
        channel_combinations = analyze_channel_combinations(interaction_data)
        synergy_effects = calculate_synergy_effects(channel_combinations)
        interaction_matrix = build_interaction_matrix(interaction_data)

        {
          date_range: { start_date: start_date, end_date: end_date },
          channel_interactions: interaction_data,
          top_channel_combinations: channel_combinations[:top_combinations],
          synergy_effects: synergy_effects,
          interaction_matrix: interaction_matrix,
          insights: generate_interaction_insights(synergy_effects, channel_combinations),
          generated_at: Time.current
        }
      end
    rescue StandardError => e
      handle_attribution_error(e, "Channel interaction analysis failed")
    end

    # Generate attribution comparison across different models
    def attribution_model_comparison(start_date:, end_date:, conversion_events: CONVERSION_EVENTS)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("attribution_comparison", user_id: @user_id) do
        # Collect unified touchpoint data
        google_ads_data = fetch_google_ads_attribution_data(start_date, end_date, conversion_events)
        ga4_data = fetch_ga4_attribution_data(start_date, end_date, conversion_events)
        search_console_data = fetch_search_console_attribution_data(start_date, end_date)

        unified_touchpoints = unify_touchpoint_data(google_ads_data, ga4_data, search_console_data)

        # Apply different attribution models
        model_comparisons = {}
        ATTRIBUTION_MODELS.each do |model|
          model_comparisons[model] = apply_attribution_model(unified_touchpoints, model)
        end

        # Calculate differences and insights
        model_differences = calculate_model_differences(model_comparisons)
        channel_impact = analyze_channel_impact_across_models(model_comparisons)

        {
          date_range: { start_date: start_date, end_date: end_date },
          attribution_models: model_comparisons,
          model_differences: model_differences,
          channel_impact_analysis: channel_impact,
          recommendations: recommend_optimal_attribution_model(model_comparisons, model_differences),
          generated_at: Time.current
        }
      end
    rescue StandardError => e
      handle_attribution_error(e, "Attribution model comparison failed")
    end

    private

    attr_reader :user_id, :google_ads_customer_id, :ga4_property_id, :search_console_site
    attr_reader :google_ads_service, :ga4_service, :search_console_service

    def initialize_service_clients
      @google_ads_service = GoogleAdsService.new(
        user_id: @user_id,
        customer_id: @google_ads_customer_id
      ) if @google_ads_customer_id

      @ga4_service = GoogleAnalyticsService.new(
        user_id: @user_id,
        property_id: @ga4_property_id
      ) if @ga4_property_id

      @search_console_service = GoogleSearchConsoleService.new(
        user_id: @user_id,
        site_url: @search_console_site
      ) if @search_console_site
    end

    def fetch_google_ads_attribution_data(start_date, end_date, conversion_events)
      return { data: [], summary: {} } unless @google_ads_service

      conversion_data = @google_ads_service.conversion_data(
        start_date: start_date,
        end_date: end_date,
        conversion_actions: conversion_events
      )

      {
        data: conversion_data[:conversions],
        summary: {
          total_conversions: conversion_data[:conversions].sum { |c| c[:conversions] },
          total_conversion_value: conversion_data[:conversions].sum { |c| c[:conversion_value] },
          platform: "google_ads"
        }
      }
    end

    def fetch_ga4_attribution_data(start_date, end_date, conversion_events)
      return { data: [], summary: {} } unless @ga4_service

      journey_data = @ga4_service.user_journey_analysis(
        start_date: start_date,
        end_date: end_date,
        conversion_events: conversion_events
      )

      {
        data: journey_data[:attribution_analysis],
        summary: {
          total_conversions: extract_ga4_total_conversions(journey_data),
          total_revenue: extract_ga4_total_revenue(journey_data),
          platform: "google_analytics"
        }
      }
    end

    def fetch_search_console_attribution_data(start_date, end_date)
      return { data: [], summary: {} } unless @search_console_service

      search_data = @search_console_service.search_analytics(
        start_date: start_date,
        end_date: end_date,
        dimensions: %w[query page]
      )

      {
        data: search_data[:data],
        summary: {
          total_clicks: search_data[:summary][:total_clicks],
          total_impressions: search_data[:summary][:total_impressions],
          platform: "search_console"
        }
      }
    end

    def unify_touchpoint_data(google_ads_data, ga4_data, search_console_data)
      touchpoints = []

      # Process Google Ads touchpoints
      google_ads_data[:data].each do |conversion|
        touchpoints << {
          platform: "google_ads",
          channel: "paid_search",
          campaign: conversion[:campaign][:name],
          timestamp: Time.current, # Would need actual timestamp from API
          conversion_value: conversion[:conversion_value],
          conversion_type: conversion[:conversion_action][:name],
          touchpoint_type: "paid_search"
        }
      end

      # Process GA4 touchpoints
      ga4_data[:data].each do |attribution|
        touchpoints << {
          platform: "google_analytics",
          channel: map_ga4_channel(attribution),
          source: attribution[:source],
          medium: attribution[:medium],
          timestamp: Time.current, # Would need actual timestamp
          conversion_value: attribution[:revenue] || 0,
          touchpoint_type: classify_touchpoint_type(attribution)
        }
      end

      # Process Search Console touchpoints
      search_console_data[:data].each do |search_item|
        touchpoints << {
          platform: "search_console",
          channel: "organic_search",
          query: search_item[:query],
          page: search_item[:page],
          clicks: search_item[:clicks],
          impressions: search_item[:impressions],
          position: search_item[:position],
          touchpoint_type: "organic_search"
        }
      end

      touchpoints.sort_by { |t| t[:timestamp] || Time.current }
    end

    def apply_attribution_model(touchpoints, model)
      case model
      when "first_click"
        apply_first_click_attribution(touchpoints)
      when "last_click"
        apply_last_click_attribution(touchpoints)
      when "linear"
        apply_linear_attribution(touchpoints)
      when "time_decay"
        apply_time_decay_attribution(touchpoints)
      when "position_based"
        apply_position_based_attribution(touchpoints)
      when "data_driven"
        apply_data_driven_attribution(touchpoints)
      else
        apply_last_click_attribution(touchpoints) # Default fallback
      end
    end

    def apply_last_click_attribution(touchpoints)
      # Group touchpoints by conversion event
      conversions = group_touchpoints_by_conversion(touchpoints)

      attribution_results = conversions.map do |conversion_id, conversion_touchpoints|
        last_touchpoint = conversion_touchpoints.last

        {
          conversion_id: conversion_id,
          attributed_channel: last_touchpoint[:channel],
          attributed_platform: last_touchpoint[:platform],
          attribution_weight: 1.0,
          conversion_value: last_touchpoint[:conversion_value] || 0,
          touchpoint_count: conversion_touchpoints.count
        }
      end

      summarize_attribution_results(attribution_results)
    end

    def apply_linear_attribution(touchpoints)
      conversions = group_touchpoints_by_conversion(touchpoints)

      attribution_results = conversions.flat_map do |conversion_id, conversion_touchpoints|
        weight_per_touchpoint = 1.0 / conversion_touchpoints.count

        conversion_touchpoints.map do |touchpoint|
          {
            conversion_id: conversion_id,
            attributed_channel: touchpoint[:channel],
            attributed_platform: touchpoint[:platform],
            attribution_weight: weight_per_touchpoint,
            conversion_value: (touchpoint[:conversion_value] || 0) * weight_per_touchpoint,
            touchpoint_count: conversion_touchpoints.count
          }
        end
      end

      summarize_attribution_results(attribution_results)
    end

    def apply_time_decay_attribution(touchpoints)
      conversions = group_touchpoints_by_conversion(touchpoints)

      attribution_results = conversions.flat_map do |conversion_id, conversion_touchpoints|
        # Calculate time decay weights (more recent touchpoints get higher weight)
        weights = calculate_time_decay_weights(conversion_touchpoints)

        conversion_touchpoints.map.with_index do |touchpoint, index|
          {
            conversion_id: conversion_id,
            attributed_channel: touchpoint[:channel],
            attributed_platform: touchpoint[:platform],
            attribution_weight: weights[index],
            conversion_value: (touchpoint[:conversion_value] || 0) * weights[index],
            touchpoint_count: conversion_touchpoints.count
          }
        end
      end

      summarize_attribution_results(attribution_results)
    end

    def calculate_time_decay_weights(touchpoints)
      # Exponential decay with half-life of 7 days
      half_life = 7.days

      weights = touchpoints.map.with_index do |touchpoint, index|
        days_from_conversion = touchpoints.count - index - 1
        Math.exp(-0.693 * days_from_conversion / half_life.in_days)
      end

      # Normalize weights to sum to 1
      total_weight = weights.sum
      weights.map { |w| w / total_weight }
    end

    def group_touchpoints_by_conversion(touchpoints)
      # In a real implementation, this would group by actual conversion events
      # For now, we'll simulate groupings
      touchpoints.group_by { |tp| tp[:conversion_type] || "default_conversion" }
    end

    def summarize_attribution_results(attribution_results)
      # Group by channel and calculate totals
      channel_attribution = attribution_results.group_by { |ar| ar[:attributed_channel] }
                                              .transform_values do |results|
                                                {
                                                  total_attributed_conversions: results.sum { |r| r[:attribution_weight] },
                                                  total_attributed_value: results.sum { |r| r[:conversion_value] },
                                                  touchpoint_participation: results.count
                                                }
                                              end

      # Group by platform
      platform_attribution = attribution_results.group_by { |ar| ar[:attributed_platform] }
                                                .transform_values do |results|
                                                  {
                                                    total_attributed_conversions: results.sum { |r| r[:attribution_weight] },
                                                    total_attributed_value: results.sum { |r| r[:conversion_value] },
                                                    touchpoint_participation: results.count
                                                  }
                                                end

      {
        channel_attribution: channel_attribution,
        platform_attribution: platform_attribution,
        total_conversions: attribution_results.sum { |r| r[:attribution_weight] },
        total_attributed_value: attribution_results.sum { |r| r[:conversion_value] }
      }
    end

    def analyze_customer_journeys(touchpoints)
      # Analyze common journey patterns
      journey_patterns = identify_common_journey_patterns(touchpoints)

      # Calculate journey lengths and complexity
      journey_metrics = calculate_journey_metrics(touchpoints)

      # Identify high-value journey paths
      high_value_journeys = identify_high_value_journeys(touchpoints)

      {
        common_patterns: journey_patterns,
        journey_metrics: journey_metrics,
        high_value_paths: high_value_journeys,
        average_touchpoints: calculate_average_touchpoints(touchpoints),
        conversion_velocity: calculate_conversion_velocity(touchpoints)
      }
    end

    def calculate_cross_platform_metrics(attribution_analysis)
      channel_attribution = attribution_analysis[:channel_attribution]
      platform_attribution = attribution_analysis[:platform_attribution]

      {
        channel_diversity: channel_attribution.keys.count,
        platform_diversity: platform_attribution.keys.count,
        cross_platform_synergy: calculate_synergy_score(platform_attribution),
        dominant_channel: find_dominant_channel(channel_attribution),
        attribution_concentration: calculate_attribution_concentration(channel_attribution)
      }
    end

    def validate_date_range!(start_date, end_date)
      start_date_obj = Date.parse(start_date)
      end_date_obj = Date.parse(end_date)

      raise ArgumentError, "Start date must be before end date" if start_date_obj > end_date_obj
      raise ArgumentError, "Date range cannot exceed 90 days" if (end_date_obj - start_date_obj).to_i > 90
    rescue Date::Error
      raise ArgumentError, "Invalid date format. Use YYYY-MM-DD"
    end

    def validate_attribution_model!(model)
      return if ATTRIBUTION_MODELS.include?(model)

      raise ArgumentError, "Unsupported attribution model: #{model}. Use: #{ATTRIBUTION_MODELS.join(', ')}"
    end

    def handle_attribution_error(error, context)
      Rails.logger.error "Attribution Modeling Error - #{context}: #{error.message}"

      raise AttributionError.new(
        "Attribution analysis failed: #{error.message}",
        error_code: error.respond_to?(:error_code) ? error.error_code : nil,
        error_type: :attribution_error
      )
    end

    # Helper methods for data extraction and mapping
    def map_ga4_channel(attribution_data)
      source = attribution_data[:source] || ""
      medium = attribution_data[:medium] || ""

      case medium.downcase
      when "cpc", "ppc"
        "paid_search"
      when "organic"
        "organic_search"
      when "social"
        "social_media"
      when "email"
        "email"
      when "referral"
        "referral"
      when "display"
        "display"
      else
        source.include?("google") ? "organic_search" : "direct"
      end
    end

    def classify_touchpoint_type(attribution_data)
      medium = attribution_data[:medium] || ""

      case medium.downcase
      when "cpc", "ppc" then "paid_search"
      when "organic" then "organic_search"
      when "social" then "social_media"
      when "email" then "email"
      when "referral" then "referral"
      when "display" then "display"
      else "direct"
      end
    end

    def extract_ga4_total_conversions(journey_data)
      journey_data.dig(:attribution_analysis, :total_conversions) || 0
    end

    def extract_ga4_total_revenue(journey_data)
      journey_data.dig(:attribution_analysis, :total_revenue) || 0
    end
  end
end
