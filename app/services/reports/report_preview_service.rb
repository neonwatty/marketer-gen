# frozen_string_literal: true

module Reports
  # ReportPreviewService generates lightweight preview data for reports
  # Optimized for speed with limited data sets
  class ReportPreviewService
    include ServiceResult

    attr_reader :custom_report

    def initialize(custom_report)
      @custom_report = custom_report
    end

    def generate_preview
      start_time = Time.current

      begin
        # Generate with preview options for speed
        generation_service = ReportGenerationService.new(
          custom_report,
          user: custom_report.user,
          options: {
            preview: true,
            limit: 50,
            cache_duration: 5.minutes,
            skip_complex_calculations: true
          }
        )

        result = generation_service.generate_preview

        if result.success?
          preview_data = enhance_preview_data(result.data)
          generation_time = ((Time.current - start_time) * 1000).round

          preview_data[:meta] = {
            is_preview: true,
            generation_time_ms: generation_time,
            preview_limitations: [
              "Limited to 50 data points per metric",
              "Cached data may be up to 5 minutes old",
              "Complex calculations simplified"
            ]
          }

          success(preview_data)
        else
          failure(result.error_message)
        end
      rescue StandardError => e
        Rails.logger.error "Report preview failed: #{e.message}"
        failure("Preview generation failed: #{e.message}")
      end
    end

    private

    def enhance_preview_data(data)
      data.deep_dup.tap do |preview|
        # Add preview-specific enhancements
        preview[:preview_charts] = generate_preview_charts(data[:metrics])
        preview[:quick_stats] = generate_quick_stats(data[:metrics])
        preview[:sample_insights] = generate_sample_insights(data[:metrics])
      end
    end

    def generate_preview_charts(metrics)
      charts = []

      # Create a simple overview chart
      if metrics.any?
        overview_data = metrics.values.map do |metric|
          {
            name: metric[:display_name],
            value: metric[:value] || 0,
            source: metric[:data_source]
          }
        end

        charts << {
          id: "overview",
          type: "bar_chart",
          title: "Metrics Overview",
          data: overview_data
        }
      end

      # Create trend charts for time-series data
      time_series_metrics = metrics.values.select { |m| m[:data_points]&.any? }

      if time_series_metrics.any?
        trend_data = time_series_metrics.first(3).map do |metric|
          {
            name: metric[:display_name],
            data: metric[:data_points].map { |point| [ point[:date], point[:value] ] }
          }
        end

        charts << {
          id: "trends",
          type: "line_chart",
          title: "Trends Preview",
          data: trend_data
        }
      end

      charts
    end

    def generate_quick_stats(metrics)
      stats = {
        total_metrics: metrics.count,
        metrics_with_data: metrics.count { |_, m| m[:value].present? },
        avg_value: 0,
        trending_up: 0,
        trending_down: 0
      }

      values = metrics.values.map { |m| m[:value] }.compact
      stats[:avg_value] = values.any? ? (values.sum / values.count.to_f).round(2) : 0

      # Count trends
      metrics.values.each do |metric|
        trend = metric[:trend]
        next unless trend

        case trend[:direction]
        when "up"
          stats[:trending_up] += 1
        when "down"
          stats[:trending_down] += 1
        end
      end

      stats
    end

    def generate_sample_insights(metrics)
      insights = []

      # Find highest value metric
      highest_metric = metrics.values.max_by { |m| m[:value] || 0 }
      if highest_metric && highest_metric[:value]
        insights << {
          type: "highlight",
          text: "#{highest_metric[:display_name]} has the highest value at #{highest_metric[:value]}",
          metric_id: highest_metric[:id]
        }
      end

      # Find strongest trend
      strongest_trend = metrics.values
                              .select { |m| m[:trend] }
                              .max_by { |m| m[:trend][:change_percent] || 0 }

      if strongest_trend && strongest_trend[:trend][:change_percent] > 5
        trend = strongest_trend[:trend]
        insights << {
          type: "trend",
          text: "#{strongest_trend[:display_name]} is trending #{trend[:direction]} by #{trend[:change_percent]}%",
          metric_id: strongest_trend[:id]
        }
      end

      # Data quality insight
      metrics_with_no_data = metrics.count { |_, m| m[:value].nil? }
      if metrics_with_no_data > 0
        insights << {
          type: "warning",
          text: "#{metrics_with_no_data} metric(s) have no data available",
          action: "Check data source connections"
        }
      end

      insights
    end
  end
end
