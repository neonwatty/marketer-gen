# frozen_string_literal: true

module Etl
  class GoogleAnalyticsEtlService < BaseEtlService
    def initialize(source:, pipeline_id: SecureRandom.uuid, date_range: 1.hour.ago..Time.current)
      super(source: source, pipeline_id: pipeline_id)
      @date_range = date_range
      @analytics_service = Analytics::GoogleAnalyticsService.new
    end

    private

    # Extract data from Google Analytics
    def extract
      Rails.logger.info("[ETL] Extracting Google Analytics data for #{@date_range}")

      with_retry(max_attempts: 3, base_delay: 5) do
        data = []

        # Extract different report types
        data.concat(extract_traffic_data)
        data.concat(extract_conversion_data)
        data.concat(extract_ecommerce_data) if ecommerce_enabled?

        update_metrics(:records_extracted, data.size)
        data
      end
    end

    # Build validation schema specific to Google Analytics
    def build_validation_schema
      Dry::Validation.Contract do
        params do
          required(:timestamp).filled(:date_time)
          required(:source).filled(:string)
          optional(:sessions).filled(:integer)
          optional(:users).filled(:integer)
          optional(:pageviews).filled(:integer)
          optional(:bounce_rate).filled(:float)
          optional(:avg_session_duration).filled(:float)
          optional(:goal_completions).filled(:integer)
          optional(:transaction_revenue).filled(:float)
          optional(:dimension_values).hash
        end

        rule(:bounce_rate) do
          key.failure("must be between 0 and 100") if value && (value < 0 || value > 100)
        end

        rule(:avg_session_duration) do
          key.failure("must be positive") if value && value < 0
        end
      end
    end

    # Apply Google Analytics specific transformations
    def apply_transformations(data)
      transformer = DataTransformationRules.new(:google_analytics, data)
      transformed_data = transformer.transform

      # Additional GA-specific enrichments
      transformed_data.map do |record|
        record.merge(
          "data_source" => "google_analytics",
          "report_type" => determine_report_type(record),
          "calculated_metrics" => calculate_derived_metrics(record)
        )
      end
    end

    # Store records in the appropriate analytics tables
    def store_record(record)
      # Store in Google Analytics specific table
      GoogleAnalyticsMetric.create!(
        date: record["timestamp"]&.to_date || Date.current,
        sessions: record["sessions"],
        users: record["unique_users"],
        new_users: record["new_users"],
        page_views: record["page_views"],
        bounce_rate: record["bounce_rate"],
        avg_session_duration: record["time_on_page"],
        goal_completions: record["conversions"],
        transaction_revenue: record["revenue"],
        dimension_data: record["dimension_values"] || {},
        raw_data: record,
        pipeline_id: pipeline_id,
        processed_at: Time.current
      )
    end

    # Extract traffic and engagement data
    def extract_traffic_data
      dimensions = %w[ga:date ga:hour ga:sourceMedium ga:deviceCategory]
      metrics = %w[
        ga:sessions
        ga:users
        ga:newUsers
        ga:pageviews
        ga:bounceRate
        ga:avgSessionDuration
      ]

      reports = @analytics_service.get_reports(
        start_date: @date_range.begin.strftime("%Y-%m-%d"),
        end_date: @date_range.end.strftime("%Y-%m-%d"),
        dimensions: dimensions,
        metrics: metrics
      )

      process_ga_reports(reports, "traffic")
    rescue => error
      Rails.logger.error("[ETL] Failed to extract GA traffic data: #{error.message}")
      []
    end

    # Extract conversion and goal data
    def extract_conversion_data
      dimensions = %w[ga:date ga:hour ga:goalCompletionLocation]
      metrics = %w[
        ga:goalCompletionsAll
        ga:goalConversionRateAll
        ga:goalValueAll
      ]

      reports = @analytics_service.get_reports(
        start_date: @date_range.begin.strftime("%Y-%m-%d"),
        end_date: @date_range.end.strftime("%Y-%m-%d"),
        dimensions: dimensions,
        metrics: metrics
      )

      process_ga_reports(reports, "conversions")
    rescue => error
      Rails.logger.error("[ETL] Failed to extract GA conversion data: #{error.message}")
      []
    end

    # Extract ecommerce data if enabled
    def extract_ecommerce_data
      dimensions = %w[ga:date ga:hour ga:transactionId ga:productName]
      metrics = %w[
        ga:transactions
        ga:transactionRevenue
        ga:itemQuantity
        ga:uniquePurchases
      ]

      reports = @analytics_service.get_reports(
        start_date: @date_range.begin.strftime("%Y-%m-%d"),
        end_date: @date_range.end.strftime("%Y-%m-%d"),
        dimensions: dimensions,
        metrics: metrics
      )

      process_ga_reports(reports, "ecommerce")
    rescue => error
      Rails.logger.error("[ETL] Failed to extract GA ecommerce data: #{error.message}")
      []
    end

    # Process Google Analytics API response into normalized format
    def process_ga_reports(reports, report_type)
      data = []

      reports&.dig("reports")&.each do |report|
        report.dig("data", "rows")&.each do |row|
          dimensions = row["dimensions"] || []
          metrics = row.dig("metrics", 0, "values") || []

          # Parse date and hour from dimensions
          date_str = dimensions[0] # ga:date format: YYYYMMDD
          hour_str = dimensions[1] || "00" # ga:hour format: HH

          timestamp = parse_ga_timestamp(date_str, hour_str)

          record = {
            "timestamp" => timestamp,
            "source" => source,
            "report_type" => report_type,
            "dimension_values" => build_dimension_hash(dimensions, report_type)
          }

          # Map metrics based on report type
          case report_type
          when "traffic"
            record.merge!(map_traffic_metrics(metrics))
          when "conversions"
            record.merge!(map_conversion_metrics(metrics))
          when "ecommerce"
            record.merge!(map_ecommerce_metrics(metrics))
          end

          data << record
        end
      end

      data
    end

    # Parse Google Analytics timestamp format
    def parse_ga_timestamp(date_str, hour_str)
      return Time.current unless date_str

      year = date_str[0..3].to_i
      month = date_str[4..5].to_i
      day = date_str[6..7].to_i
      hour = hour_str.to_i

      Time.new(year, month, day, hour, 0, 0)
    rescue => error
      Rails.logger.warn("[ETL] Failed to parse GA timestamp #{date_str}#{hour_str}: #{error.message}")
      Time.current
    end

    # Build dimension hash for different report types
    def build_dimension_hash(dimensions, report_type)
      case report_type
      when "traffic"
        {
          "source_medium" => dimensions[2],
          "device_category" => dimensions[3]
        }
      when "conversions"
        {
          "goal_completion_location" => dimensions[2]
        }
      when "ecommerce"
        {
          "transaction_id" => dimensions[2],
          "product_name" => dimensions[3]
        }
      else
        {}
      end
    end

    # Map traffic metrics from GA API response
    def map_traffic_metrics(metrics)
      return {} unless metrics.size >= 6

      {
        "ga:sessions" => metrics[0].to_i,
        "ga:users" => metrics[1].to_i,
        "ga:newUsers" => metrics[2].to_i,
        "ga:pageviews" => metrics[3].to_i,
        "ga:bounceRate" => metrics[4].to_f,
        "ga:avgSessionDuration" => metrics[5].to_f
      }
    end

    # Map conversion metrics from GA API response
    def map_conversion_metrics(metrics)
      return {} unless metrics.size >= 3

      {
        "ga:goalCompletionsAll" => metrics[0].to_i,
        "ga:goalConversionRateAll" => metrics[1].to_f,
        "ga:goalValueAll" => metrics[2].to_f
      }
    end

    # Map ecommerce metrics from GA API response
    def map_ecommerce_metrics(metrics)
      return {} unless metrics.size >= 4

      {
        "ga:transactions" => metrics[0].to_i,
        "ga:transactionRevenue" => metrics[1].to_f,
        "ga:itemQuantity" => metrics[2].to_i,
        "ga:uniquePurchases" => metrics[3].to_i
      }
    end

    # Determine the report type from record data
    def determine_report_type(record)
      return "ecommerce" if record.key?("transactions") || record.key?("transaction_revenue")
      return "conversions" if record.key?("conversions") || record.key?("goal_completions")
      "traffic"
    end

    # Calculate derived metrics
    def calculate_derived_metrics(record)
      derived = {}

      # Calculate conversion rate if we have sessions and conversions
      if record["sessions"] && record["conversions"] && record["sessions"] > 0
        derived["conversion_rate"] = (record["conversions"].to_f / record["sessions"] * 100).round(4)
      end

      # Calculate revenue per session
      if record["sessions"] && record["revenue"] && record["sessions"] > 0
        derived["revenue_per_session"] = (record["revenue"].to_f / record["sessions"]).round(2)
      end

      # Calculate pages per session
      if record["sessions"] && record["page_views"] && record["sessions"] > 0
        derived["pages_per_session"] = (record["page_views"].to_f / record["sessions"]).round(2)
      end

      derived
    end

    # Check if ecommerce tracking is enabled
    def ecommerce_enabled?
      # This could check account configuration or previous data presence
      true # Simplified for now
    end
  end
end
