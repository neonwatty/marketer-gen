# frozen_string_literal: true

module Analytics
  module Alerts
    # Background job for calculating ML-based performance thresholds
    class ThresholdCalculatorJob < ApplicationJob
      queue_as :low_priority

      retry_on StandardError, wait: :exponentially_longer, attempts: 3
      discard_on ActiveJob::DeserializationError

      def perform(threshold_or_alert)
        case threshold_or_alert
        when PerformanceThreshold
          calculate_threshold(threshold_or_alert)
        when PerformanceAlert
          calculate_alert_thresholds(threshold_or_alert)
        else
          raise ArgumentError, "Invalid argument: #{threshold_or_alert.class}"
        end
      end

      private

      def calculate_threshold(threshold)
        Rails.logger.info "Calculating ML threshold for #{threshold.metric_type}/#{threshold.metric_source}"

        begin
          # Fetch historical data for baseline calculation
          historical_data = fetch_historical_data(threshold)

          if historical_data.length < PerformanceThreshold::MIN_SAMPLE_SIZE
            Rails.logger.warn "Insufficient data for threshold calculation: #{historical_data.length} samples"
            return
          end

          # Extract metric values
          metric_values = extract_metric_values(historical_data, threshold.metric_type)

          if metric_values.length < PerformanceThreshold::MIN_SAMPLE_SIZE
            Rails.logger.warn "Insufficient valid metric values: #{metric_values.length}"
            return
          end

          # Update baseline statistics
          success = threshold.update_baseline_statistics!(metric_values)

          if success
            Rails.logger.info "Successfully updated threshold #{threshold.id} with #{metric_values.length} samples"

            # If we have enough data, also update model performance
            if metric_values.length > 200
              update_model_performance(threshold, metric_values)
            end
          else
            Rails.logger.error "Failed to update threshold #{threshold.id}"
          end

        rescue StandardError => e
          Rails.logger.error "Error calculating threshold #{threshold.id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          raise
        end
      end

      def calculate_alert_thresholds(alert)
        Rails.logger.info "Calculating thresholds for alert #{alert.id} (#{alert.name})"

        # Find or create threshold record
        context = {
          campaign_id: alert.campaign_id,
          journey_id: alert.journey_id
        }

        threshold = PerformanceThreshold.find_or_create_for_context(
          alert.metric_type,
          alert.metric_source,
          context
        )

        # Calculate the threshold
        calculate_threshold(threshold)
      end

      def fetch_historical_data(threshold)
        # Determine the baseline period
        end_date = Time.current
        start_date = threshold.baseline_period_days.days.ago

        case threshold.metric_source
        when "google_ads", "web_analytics"
          fetch_google_analytics_data(threshold, start_date, end_date)
        when "facebook", "instagram"
          fetch_social_media_data(threshold, start_date, end_date, [ "facebook", "instagram" ])
        when "linkedin"
          fetch_social_media_data(threshold, start_date, end_date, [ "linkedin" ])
        when "twitter"
          fetch_social_media_data(threshold, start_date, end_date, [ "twitter" ])
        when "email_marketing"
          fetch_email_data(threshold, start_date, end_date)
        when "social_media"
          fetch_social_media_data(threshold, start_date, end_date)
        else
          Rails.logger.warn "Unknown metric source: #{threshold.metric_source}"
          []
        end
      end

      def fetch_google_analytics_data(threshold, start_date, end_date)
        scope = GoogleAnalyticsMetric.where(date: start_date.to_date..end_date.to_date)

        # Apply context filters
        if threshold.campaign_id.present?
          # This would need campaign-specific filtering logic
          # For now, return all data
        end

        scope.order(:date).to_a
      end

      def fetch_social_media_data(threshold, start_date, end_date, platforms = nil)
        scope = SocialMediaMetric.where(date: start_date.to_date..end_date.to_date)

        if platforms.present?
          scope = scope.where(platform: platforms)
        end

        if threshold.campaign_id.present?
          scope = scope.joins(:social_media_integration)
                       .where(social_media_integrations: {
                         brand_id: Campaign.find(threshold.campaign_id).brand_id
                       })
        end

        scope.order(:date).to_a
      end

      def fetch_email_data(threshold, start_date, end_date)
        scope = EmailMetric.where(metric_date: start_date.to_date..end_date.to_date)

        if threshold.campaign_id.present?
          scope = scope.joins(email_integration: :brand)
                       .where(brands: {
                         id: Campaign.find(threshold.campaign_id).brand_id
                       })
        end

        scope.order(:metric_date).to_a
      end

      def extract_metric_values(data_points, metric_type)
        values = []

        data_points.each do |data_point|
          value = case metric_type
          when "conversion_rate"
                    extract_conversion_rate(data_point)
          when "click_rate", "click_through_rate"
                    extract_click_rate(data_point)
          when "open_rate"
                    extract_open_rate(data_point)
          when "bounce_rate"
                    extract_bounce_rate(data_point)
          when "engagement_rate"
                    extract_engagement_rate(data_point)
          when "cost_per_acquisition"
                    extract_cost_per_acquisition(data_point)
          when "cost_per_click"
                    extract_cost_per_click(data_point)
          when "reach"
                    extract_reach(data_point)
          when "impressions"
                    extract_impressions(data_point)
          when "revenue"
                    extract_revenue(data_point)
          else
                    Rails.logger.warn "Unknown metric type: #{metric_type}"
                    nil
          end

          values << value if value.present? && value.finite?
        end

        # Remove outliers (values beyond 3 standard deviations)
        remove_outliers(values)
      end

      def extract_conversion_rate(data_point)
        case data_point
        when GoogleAnalyticsMetric
          return 0.0 if data_point.sessions.zero?
          (data_point.goal_completions.to_f / data_point.sessions * 100).round(4)
        when SocialMediaMetric
          data_point.value.to_f
        when EmailMetric
          data_point.click_rate.to_f
        else
          0.0
        end
      end

      def extract_click_rate(data_point)
        case data_point
        when EmailMetric
          data_point.click_rate.to_f
        when SocialMediaMetric
          data_point.value.to_f
        else
          0.0
        end
      end

      def extract_open_rate(data_point)
        case data_point
        when EmailMetric
          data_point.open_rate.to_f
        else
          0.0
        end
      end

      def extract_bounce_rate(data_point)
        case data_point
        when GoogleAnalyticsMetric
          data_point.bounce_rate.to_f
        else
          0.0
        end
      end

      def extract_engagement_rate(data_point)
        case data_point
        when SocialMediaMetric
          data_point.value.to_f
        else
          0.0
        end
      end

      def extract_cost_per_acquisition(data_point)
        # This would need cost and acquisition data
        # For now, return 0 as placeholder
        0.0
      end

      def extract_cost_per_click(data_point)
        # This would need cost and click data
        # For now, return 0 as placeholder
        0.0
      end

      def extract_reach(data_point)
        case data_point
        when SocialMediaMetric
          data_point.value.to_f
        when GoogleAnalyticsMetric
          data_point.users.to_f
        else
          0.0
        end
      end

      def extract_impressions(data_point)
        case data_point
        when SocialMediaMetric
          data_point.value.to_f
        when GoogleAnalyticsMetric
          data_point.page_views.to_f
        else
          0.0
        end
      end

      def extract_revenue(data_point)
        case data_point
        when GoogleAnalyticsMetric
          data_point.transaction_revenue.to_f
        else
          0.0
        end
      end

      def remove_outliers(values)
        return values if values.length < 4

        mean = values.sum / values.length
        std_dev = Math.sqrt(values.sum { |v| (v - mean) ** 2 } / (values.length - 1))

        # Remove values beyond 3 standard deviations
        threshold = 3 * std_dev
        filtered_values = values.select { |v| (v - mean).abs <= threshold }

        Rails.logger.debug "Removed #{values.length - filtered_values.length} outliers from #{values.length} values"

        filtered_values
      end

      def update_model_performance(threshold, metric_values)
        # Simulate prediction performance for ML model validation
        # In a real implementation, this would use actual ML predictions

        # Split data into training and validation sets
        training_size = (metric_values.length * 0.8).to_i
        training_data = metric_values[0...training_size]
        validation_data = metric_values[training_size..-1]

        return if validation_data.empty?

        # Calculate baseline mean and std from training data
        training_mean = training_data.sum / training_data.length
        training_std = Math.sqrt(training_data.sum { |v| (v - training_mean) ** 2 } / (training_data.length - 1))

        # Use current threshold as prediction threshold
        prediction_threshold = threshold.upper_threshold || (training_mean + (2 * training_std))

        # Generate predictions (simulate anomaly detection)
        predictions = validation_data.map do |value|
          # Simulate prediction confidence based on distance from mean
          z_score = (value - training_mean) / training_std
          prediction_value = training_mean + (z_score * training_std * 0.9) # Add some noise

          prediction_value
        end

        # Update model performance metrics
        threshold.update_model_performance!(predictions, validation_data, prediction_threshold)

        Rails.logger.info "Updated model performance for threshold #{threshold.id}: " \
                          "accuracy=#{threshold.accuracy_score}, " \
                          "precision=#{threshold.precision_score}, " \
                          "recall=#{threshold.recall_score}"
      end
    end
  end
end
