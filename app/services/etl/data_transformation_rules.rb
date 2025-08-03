# frozen_string_literal: true

module Etl
  # Data transformation rules for normalizing data across different platforms
  class DataTransformationRules
    # Universal field mappings across all platforms
    UNIVERSAL_FIELDS = {
      # Timestamp normalization
      timestamp: %w[timestamp date created_at time date_time datetime],

      # Metric names normalization
      impressions: %w[impressions views reach displays],
      clicks: %w[clicks taps hits clicks_all],
      conversions: %w[conversions goals purchases completions],
      cost: %w[cost spend amount cost_micros],
      revenue: %w[revenue income earnings value],

      # Engagement metrics
      engagement_rate: %w[engagement_rate ctr click_through_rate interaction_rate],
      bounce_rate: %w[bounce_rate exit_rate],
      time_on_page: %w[time_on_page session_duration avg_session_duration],

      # Audience metrics
      unique_users: %w[unique_users unique_visitors users distinct_users],
      new_users: %w[new_users new_visitors first_time_users],
      returning_users: %w[returning_users repeat_visitors],

      # Campaign identifiers
      campaign_id: %w[campaign_id campaign_name adgroup_id ad_id],
      campaign_name: %w[campaign_name campaign_title ad_name],

      # Platform identifiers
      platform: %w[platform source channel medium],
      platform_id: %w[platform_id source_id account_id]
    }.freeze

    # Platform-specific transformation rules
    PLATFORM_TRANSFORMATIONS = {
      google_analytics: {
        field_mappings: {
          "ga:sessions" => "sessions",
          "ga:users" => "unique_users",
          "ga:newUsers" => "new_users",
          "ga:pageviews" => "page_views",
          "ga:bounceRate" => "bounce_rate",
          "ga:avgSessionDuration" => "time_on_page",
          "ga:goalCompletionsAll" => "conversions",
          "ga:transactionRevenue" => "revenue"
        },
        data_types: {
          "bounce_rate" => :percentage,
          "time_on_page" => :duration_seconds,
          "revenue" => :currency_cents,
          "cost" => :currency_cents
        }
      },

      facebook_ads: {
        field_mappings: {
          "impressions" => "impressions",
          "clicks" => "clicks",
          "spend" => "cost",
          "actions" => "conversions",
          "ctr" => "engagement_rate",
          "campaign_name" => "campaign_name",
          "adset_name" => "adset_name",
          "ad_name" => "ad_name"
        },
        data_types: {
          "cost" => :currency_cents,
          "engagement_rate" => :percentage
        }
      },

      google_ads: {
        field_mappings: {
          "metrics.impressions" => "impressions",
          "metrics.clicks" => "clicks",
          "metrics.cost_micros" => "cost",
          "metrics.conversions" => "conversions",
          "metrics.ctr" => "engagement_rate",
          "campaign.name" => "campaign_name",
          "ad_group.name" => "adgroup_name"
        },
        data_types: {
          "cost" => :micros_to_cents,
          "engagement_rate" => :percentage
        }
      },

      email_platforms: {
        field_mappings: {
          "opens" => "impressions",
          "clicks" => "clicks",
          "bounces" => "bounced",
          "unsubscribes" => "unsubscribed",
          "complaints" => "spam_complaints",
          "open_rate" => "open_rate",
          "click_rate" => "click_rate",
          "campaign_id" => "campaign_id",
          "subject" => "campaign_name"
        },
        data_types: {
          "open_rate" => :percentage,
          "click_rate" => :percentage,
          "bounce_rate" => :percentage
        }
      },

      social_media: {
        field_mappings: {
          "reach" => "impressions",
          "engagement" => "clicks",
          "likes" => "likes",
          "shares" => "shares",
          "comments" => "comments",
          "followers" => "followers",
          "engagement_rate" => "engagement_rate",
          "post_id" => "content_id",
          "post_type" => "content_type"
        },
        data_types: {
          "engagement_rate" => :percentage
        }
      },

      crm_systems: {
        field_mappings: {
          "lead_id" => "lead_id",
          "contact_id" => "contact_id",
          "opportunity_value" => "revenue",
          "stage" => "funnel_stage",
          "created_date" => "timestamp",
          "close_date" => "converted_at",
          "source" => "lead_source"
        },
        data_types: {
          "revenue" => :currency_cents,
          "timestamp" => :datetime,
          "converted_at" => :datetime
        }
      }
    }.freeze

    # Initialize with platform and raw data
    def initialize(platform, raw_data)
      @platform = platform.to_sym
      @raw_data = raw_data
      @transformations = PLATFORM_TRANSFORMATIONS[@platform] || {}
    end

    # Main transformation method
    def transform
      normalized_data = normalize_fields
      typed_data = apply_data_types(normalized_data)
      enriched_data = enrich_with_metadata(typed_data)

      validate_transformed_data(enriched_data)
    end

    private

    # Step 1: Normalize field names
    def normalize_fields
      field_mappings = @transformations[:field_mappings] || {}

      @raw_data.map do |record|
        normalized_record = {}

        record.each do |key, value|
          # Try exact match first
          normalized_key = field_mappings[key] || find_universal_mapping(key) || key
          normalized_record[normalized_key] = value
        end

        normalized_record
      end
    end

    # Find universal field mapping
    def find_universal_mapping(field_name)
      UNIVERSAL_FIELDS.each do |universal_key, variations|
        return universal_key.to_s if variations.include?(field_name.to_s.downcase)
      end
      nil
    end

    # Step 2: Apply data type transformations
    def apply_data_types(data)
      data_types = @transformations[:data_types] || {}

      data.map do |record|
        transformed_record = record.dup

        data_types.each do |field, type|
          next unless transformed_record.key?(field)

          transformed_record[field] = transform_data_type(
            transformed_record[field],
            type
          )
        end

        transformed_record
      end
    end

    # Transform individual data types
    def transform_data_type(value, type)
      return nil if value.nil? || value == ""

      case type
      when :percentage
        # Convert percentage to decimal (e.g., 5.5% -> 0.055)
        value.to_f / 100.0
      when :currency_cents
        # Convert to cents (e.g., $10.50 -> 1050)
        (value.to_f * 100).to_i
      when :micros_to_cents
        # Google Ads uses micros (e.g., 1000000 micros = $1.00 = 100 cents)
        (value.to_f / 10000).to_i
      when :duration_seconds
        # Ensure duration is in seconds
        value.to_f
      when :datetime
        # Parse datetime consistently
        parse_datetime(value)
      when :integer
        value.to_i
      when :float
        value.to_f
      when :string
        value.to_s.strip
      else
        value
      end
    rescue => error
      Rails.logger.warn("[ETL] Data type transformation failed for #{value} (#{type}): #{error.message}")
      value # Return original value if transformation fails
    end

    # Step 3: Enrich with metadata
    def enrich_with_metadata(data)
      timestamp = Time.current

      data.map do |record|
        record.merge(
          "platform" => @platform.to_s,
          "etl_processed_at" => timestamp,
          "etl_version" => "1.0",
          "data_quality_score" => calculate_quality_score(record)
        )
      end
    end

    # Calculate data quality score (0-1)
    def calculate_quality_score(record)
      total_fields = record.size
      return 0.0 if total_fields == 0

      complete_fields = record.values.count { |v| !v.nil? && v != "" }
      completeness_score = complete_fields.to_f / total_fields

      # Additional quality checks
      has_timestamp = record.key?("timestamp") || record.key?("date")
      has_metrics = %w[impressions clicks conversions revenue].any? { |m| record.key?(m) }

      quality_bonus = 0.0
      quality_bonus += 0.1 if has_timestamp
      quality_bonus += 0.1 if has_metrics

      [ (completeness_score + quality_bonus), 1.0 ].min.round(3)
    end

    # Parse datetime consistently
    def parse_datetime(value)
      return value if value.is_a?(Time) || value.is_a?(DateTime)

      # Handle various datetime formats
      case value.to_s
      when /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/ # ISO 8601
        Time.parse(value.to_s)
      when /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/ # SQL datetime
        Time.parse(value.to_s)
      when /^\d{4}-\d{2}-\d{2}/ # Date only
        Date.parse(value.to_s).beginning_of_day
      when /^\d{10}$/ # Unix timestamp
        Time.at(value.to_i)
      when /^\d{13}$/ # Unix timestamp in milliseconds
        Time.at(value.to_i / 1000.0)
      else
        Time.parse(value.to_s)
      end
    rescue => error
      Rails.logger.warn("[ETL] DateTime parsing failed for #{value}: #{error.message}")
      Time.current
    end

    # Step 4: Validate transformed data
    def validate_transformed_data(data)
      data.select do |record|
        # Basic validation rules
        next false if record.empty?
        next false unless record["platform"]
        next false unless record["etl_processed_at"]

        # Platform-specific validation
        case @platform
        when :google_analytics, :google_ads
          record.key?("timestamp") && numeric_field_valid?(record, "impressions")
        when :facebook_ads
          record.key?("campaign_name") && numeric_field_valid?(record, "impressions")
        when :email_platforms
          record.key?("campaign_id") && numeric_field_valid?(record, "impressions")
        when :social_media
          record.key?("content_id") || record.key?("timestamp")
        when :crm_systems
          record.key?("lead_id") || record.key?("contact_id")
        else
          true # Allow unknown platforms
        end
      end
    end

    # Check if numeric field has valid value
    def numeric_field_valid?(record, field)
      value = record[field]
      return false if value.nil?

      case value
      when Numeric
        value >= 0
      when String
        value.match?(/^\d+\.?\d*$/) && value.to_f >= 0
      else
        false
      end
    end

    # Class methods for batch processing
    class << self
      # Transform data from multiple platforms
      def transform_batch(platform_data_map)
        results = {}

        platform_data_map.each do |platform, data|
          transformer = new(platform, data)
          results[platform] = transformer.transform
        end

        results
      end

      # Get available platforms
      def supported_platforms
        PLATFORM_TRANSFORMATIONS.keys
      end

      # Get field mappings for a platform
      def field_mappings_for(platform)
        PLATFORM_TRANSFORMATIONS[platform.to_sym]&.dig(:field_mappings) || {}
      end
    end
  end
end
