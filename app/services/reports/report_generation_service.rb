# frozen_string_literal: true

module Reports
  # ReportGenerationService handles the core logic for generating reports
  # Coordinates data collection, processing, and output generation
  class ReportGenerationService
    include ServiceResult

    attr_reader :custom_report, :user, :options

    def initialize(custom_report, user: nil, options: {})
      @custom_report = custom_report
      @user = user || custom_report.user
      @options = options
    end

    # Generate the complete report data
    def generate
      start_time = Time.current

      begin
        # Validate report configuration
        validation_result = validate_report
        return validation_result unless validation_result.success?

        # Collect data from all metrics
        data_collection_result = collect_all_data
        return data_collection_result unless data_collection_result.success?

        # Process and format data
        processed_data = process_data(data_collection_result.data)

        # Update generation statistics
        generation_time = ((Time.current - start_time) * 1000).round
        custom_report.update!(
          last_generated_at: Time.current,
          generation_time_ms: generation_time
        )

        success(processed_data)
      rescue StandardError => e
        Rails.logger.error "Report generation failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        failure("Report generation failed: #{e.message}")
      end
    end

    # Generate a preview version (limited data for speed)
    def generate_preview
      @options[:preview] = true
      @options[:limit] = 100 # Limit data for preview

      generate
    end

    private

    def validate_report
      errors = []

      errors << "Report has no metrics defined" if custom_report.report_metrics.active.empty?
      errors << "Report configuration is invalid" unless valid_configuration?
      errors << "Required integrations are not connected" unless required_integrations_connected?

      if errors.any?
        failure("Validation failed: #{errors.join(', ')}")
      else
        success(nil)
      end
    end

    def collect_all_data
      metrics_data = {}
      errors = []

      custom_report.report_metrics.active.ordered.each do |metric|
        begin
          collector = data_collector_for(metric.data_source)
          result = collector.collect_metric_data(metric, options)

          if result.success?
            metrics_data[metric.id] = {
              metric: metric,
              data: result.data,
              metadata: result.metadata || {}
            }
          else
            errors << "Failed to collect #{metric.display_name_or_default}: #{result.error_message}"
          end
        rescue StandardError => e
          Rails.logger.error "Data collection failed for metric #{metric.id}: #{e.message}"
          errors << "Failed to collect #{metric.display_name_or_default}: #{e.message}"
        end
      end

      if errors.any? && metrics_data.empty?
        failure("Data collection failed: #{errors.join(', ')}")
      else
        success(metrics_data, { errors: errors })
      end
    end

    def process_data(raw_data)
      {
        report_info: {
          id: custom_report.id,
          name: custom_report.name,
          description: custom_report.description,
          generated_at: Time.current,
          generation_time_ms: custom_report.generation_time_ms,
          user: user.as_json(only: [ :id, :email, :first_name, :last_name ])
        },
        configuration: custom_report.configuration,
        metrics: process_metrics_data(raw_data),
        summary: generate_summary(raw_data),
        visualizations: generate_visualizations(raw_data)
      }
    end

    def process_metrics_data(raw_data)
      raw_data.transform_values do |metric_data|
        metric = metric_data[:metric]
        data = metric_data[:data]

        {
          id: metric.id,
          name: metric.metric_name,
          display_name: metric.display_name_or_default,
          data_source: metric.data_source,
          aggregation_type: metric.aggregation_type,
          value: calculate_aggregated_value(data, metric.aggregation_type),
          trend: calculate_trend(data, metric),
          data_points: format_data_points(data, metric),
          visualization: generate_metric_visualization(data, metric),
          metadata: metric_data[:metadata]
        }
      end
    end

    def generate_summary(raw_data)
      total_metrics = raw_data.count
      successful_metrics = raw_data.count { |_, data| data[:data].present? }

      {
        total_metrics: total_metrics,
        successful_metrics: successful_metrics,
        failed_metrics: total_metrics - successful_metrics,
        data_freshness: calculate_data_freshness(raw_data),
        key_insights: generate_key_insights(raw_data)
      }
    end

    def generate_visualizations(raw_data)
      visualizations = []

      # Generate visualizations based on report configuration
      custom_report.configuration[:visualizations]&.each do |viz_config|
        visualization = create_visualization(viz_config, raw_data)
        visualizations << visualization if visualization
      end

      # Generate default visualizations if none configured
      if visualizations.empty?
        visualizations = generate_default_visualizations(raw_data)
      end

      visualizations
    end

    def data_collector_for(data_source)
      case data_source
      when "google_analytics"
        Reports::DataCollectors::GoogleAnalyticsCollector.new(custom_report.brand, user)
      when "google_ads"
        Reports::DataCollectors::GoogleAdsCollector.new(custom_report.brand, user)
      when "social_media"
        Reports::DataCollectors::SocialMediaCollector.new(custom_report.brand, user)
      when "email_marketing"
        Reports::DataCollectors::EmailMarketingCollector.new(custom_report.brand, user)
      when "crm"
        Reports::DataCollectors::CrmCollector.new(custom_report.brand, user)
      when "campaigns"
        Reports::DataCollectors::CampaignsCollector.new(custom_report.brand, user)
      when "journeys"
        Reports::DataCollectors::JourneysCollector.new(custom_report.brand, user)
      when "ab_tests"
        Reports::DataCollectors::AbTestsCollector.new(custom_report.brand, user)
      when "conversion_funnels"
        Reports::DataCollectors::ConversionFunnelsCollector.new(custom_report.brand, user)
      else
        Reports::DataCollectors::BaseCollector.new(custom_report.brand, user)
      end
    end

    def valid_configuration?
      config = custom_report.configuration
      return false unless config.is_a?(Hash)

      # Basic configuration validation
      config.key?(:date_range) && config[:date_range].is_a?(Hash)
    end

    def required_integrations_connected?
      required_sources = custom_report.report_metrics.active.pluck(:data_source).uniq
      brand = custom_report.brand

      required_sources.all? do |source|
        case source
        when "google_analytics"
          brand.respond_to?(:google_analytics_connected?) ? brand.google_analytics_connected? : true
        when "google_ads"
          brand.respond_to?(:google_ads_connected?) ? brand.google_ads_connected? : true
        when "social_media"
          brand.social_media_integrations.active.any?
        else
          true # Assume other sources are always available
        end
      end
    end

    def calculate_aggregated_value(data, aggregation_type)
      return nil if data.blank?

      values = data.is_a?(Array) ? data.map { |d| d[:value] }.compact : [ data[:value] ].compact
      return nil if values.empty?

      case aggregation_type
      when "sum"
        values.sum
      when "count"
        values.count
      when "average"
        values.sum / values.count.to_f
      when "min"
        values.min
      when "max"
        values.max
      when "median"
        sorted = values.sort
        mid = sorted.length / 2
        sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
      else
        values.first
      end
    end

    def calculate_trend(data, metric)
      return nil unless data.is_a?(Array) && data.length >= 2

      # Simple trend calculation - compare first half to second half
      mid = data.length / 2
      first_half = data[0...mid].map { |d| d[:value] }.compact
      second_half = data[mid..-1].map { |d| d[:value] }.compact

      return nil if first_half.empty? || second_half.empty?

      first_avg = first_half.sum / first_half.count.to_f
      second_avg = second_half.sum / second_half.count.to_f

      change_percent = ((second_avg - first_avg) / first_avg * 100).round(2)

      {
        direction: change_percent > 0 ? "up" : change_percent < 0 ? "down" : "flat",
        change_percent: change_percent.abs,
        previous_value: first_avg,
        current_value: second_avg
      }
    end

    def format_data_points(data, metric)
      return [] unless data.is_a?(Array)

      data.map do |point|
        {
          date: point[:date] || point[:timestamp],
          value: point[:value],
          label: point[:label] || point[:value].to_s,
          metadata: point.except(:date, :timestamp, :value, :label)
        }
      end
    end

    def generate_metric_visualization(data, metric)
      viz_type = metric.visualization_type

      {
        type: viz_type,
        config: metric.visualization_config,
        data: format_visualization_data(data, viz_type)
      }
    end

    def format_visualization_data(data, viz_type)
      case viz_type
      when "line_chart", "area_chart"
        format_time_series_data(data)
      when "bar_chart"
        format_categorical_data(data)
      when "pie_chart", "donut_chart"
        format_proportional_data(data)
      else
        data
      end
    end

    def format_time_series_data(data)
      return [] unless data.is_a?(Array)

      data.map { |point| [ point[:date] || point[:timestamp], point[:value] ] }
    end

    def format_categorical_data(data)
      return [] unless data.is_a?(Array)

      data.map { |point| { label: point[:label] || point[:date], value: point[:value] } }
    end

    def format_proportional_data(data)
      return [] unless data.is_a?(Array)

      total = data.sum { |point| point[:value] || 0 }
      return [] if total.zero?

      data.map do |point|
        {
          label: point[:label] || point[:date],
          value: point[:value],
          percentage: ((point[:value] / total.to_f) * 100).round(2)
        }
      end
    end

    def calculate_data_freshness(raw_data)
      freshness_scores = raw_data.values.map do |metric_data|
        data = metric_data[:data]
        next 0 unless data.is_a?(Array) && data.any?

        latest_date = data.map { |d| d[:date] || d[:timestamp] }.compact.max
        next 0 unless latest_date

        # Calculate freshness score (0-100)
        days_old = (Time.current.to_date - latest_date.to_date).to_i
        [ 100 - (days_old * 5), 0 ].max # Decrease 5 points per day
      end.compact

      freshness_scores.any? ? (freshness_scores.sum / freshness_scores.count.to_f).round : 0
    end

    def generate_key_insights(raw_data)
      insights = []

      # Find top performing metrics
      top_metrics = raw_data.values.select { |data| data[:data].present? }
                           .sort_by { |data| calculate_aggregated_value(data[:data], "sum") || 0 }
                           .reverse
                           .first(3)

      top_metrics.each do |metric_data|
        metric = metric_data[:metric]
        value = calculate_aggregated_value(metric_data[:data], metric.aggregation_type)

        insights << {
          type: "top_performer",
          metric: metric.display_name_or_default,
          value: value,
          description: "#{metric.display_name_or_default} shows strong performance with #{value}"
        }
      end

      # Add trend insights
      raw_data.values.each do |metric_data|
        trend = calculate_trend(metric_data[:data], metric_data[:metric])
        next unless trend && trend[:change_percent] > 10

        insights << {
          type: "trend",
          metric: metric_data[:metric].display_name_or_default,
          direction: trend[:direction],
          change: trend[:change_percent],
          description: "#{metric_data[:metric].display_name_or_default} is trending #{trend[:direction]} by #{trend[:change_percent]}%"
        }
      end

      insights.first(5) # Limit to top 5 insights
    end

    def create_visualization(viz_config, raw_data)
      # Implementation for custom visualization creation
      # This would be expanded based on specific visualization requirements
      {
        id: SecureRandom.uuid,
        type: viz_config[:type],
        title: viz_config[:title],
        config: viz_config,
        data: []
      }
    end

    def generate_default_visualizations(raw_data)
      visualizations = []

      # Create a summary table
      visualizations << {
        id: "summary_table",
        type: "table",
        title: "Metrics Summary",
        data: raw_data.values.map do |metric_data|
          metric = metric_data[:metric]
          value = calculate_aggregated_value(metric_data[:data], metric.aggregation_type)

          {
            metric: metric.display_name_or_default,
            value: value,
            source: metric.data_source.humanize,
            aggregation: metric.aggregation_type.humanize
          }
        end
      }

      visualizations
    end
  end
end
