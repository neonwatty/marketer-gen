# frozen_string_literal: true

module Etl
  class DataNormalizationJob < ApplicationJob
    queue_as :etl_transformations
    
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(date_range: 1.day.ago..Time.current)
      Rails.logger.info("[ETL] Starting daily data normalization across all platforms")
      
      pipeline_run = EtlPipelineRun.create!(
        pipeline_id: SecureRandom.uuid,
        source: 'data_normalization',
        status: 'running',
        started_at: Time.current
      )

      begin
        # Collect raw data from all sources
        raw_data = collect_raw_data(date_range)
        
        # Transform and normalize using our transformation rules
        normalized_data = normalize_platform_data(raw_data)
        
        # Store normalized data
        store_normalized_data(normalized_data)
        
        # Update metrics
        metrics = calculate_normalization_metrics(raw_data, normalized_data)
        pipeline_run.mark_completed!(metrics)
        
        Rails.logger.info("[ETL] Data normalization completed successfully")
      rescue => error
        pipeline_run.mark_failed!(error)
        Rails.logger.error("[ETL] Data normalization failed: #{error.message}")
        raise
      end
    end

    private

    def collect_raw_data(date_range)
      data = {}
      
      # Collect from Google Analytics
      if analytics_data = fetch_analytics_data(date_range)
        data[:google_analytics] = analytics_data
      end
      
      # Collect from social media platforms
      if social_data = fetch_social_media_data(date_range)
        data[:social_media] = social_data
      end
      
      # Collect from email platforms
      if email_data = fetch_email_data(date_range)
        data[:email_platforms] = email_data
      end
      
      # Collect from CRM systems
      if crm_data = fetch_crm_data(date_range)
        data[:crm_systems] = crm_data
      end
      
      data
    end

    def normalize_platform_data(raw_data)
      transformer = DataTransformationRules
      transformer.transform_batch(raw_data)
    end

    def store_normalized_data(normalized_data)
      normalized_data.each do |platform, records|
        records.each do |record|
          # Store in analytics data warehouse table
          AnalyticsDataPoint.create!(
            platform: platform.to_s,
            raw_data: record,
            processed_at: Time.current,
            date: record['timestamp']&.to_date || Date.current
          )
        end
      end
    end

    def calculate_normalization_metrics(raw_data, normalized_data)
      total_raw_records = raw_data.values.sum(&:size)
      total_normalized_records = normalized_data.values.sum(&:size)
      
      {
        raw_records_count: total_raw_records,
        normalized_records_count: total_normalized_records,
        normalization_success_rate: total_raw_records > 0 ? 
          (total_normalized_records.to_f / total_raw_records * 100).round(2) : 0.0,
        platforms_processed: normalized_data.keys.size,
        quality_scores: calculate_quality_scores(normalized_data)
      }
    end

    def calculate_quality_scores(normalized_data)
      scores = {}
      
      normalized_data.each do |platform, records|
        quality_scores = records.map { |r| r['data_quality_score'] }.compact
        scores[platform] = quality_scores.empty? ? 0.0 : 
          (quality_scores.sum / quality_scores.size).round(3)
      end
      
      scores
    end

    # Data fetching methods (simplified - would integrate with actual services)
    def fetch_analytics_data(date_range)
      # This would call the actual Google Analytics service
      []
    end

    def fetch_social_media_data(date_range)
      # This would call social media integration services
      []
    end

    def fetch_email_data(date_range)
      # This would call email platform services
      []
    end

    def fetch_crm_data(date_range)
      # This would call CRM integration services
      []
    end
  end
end