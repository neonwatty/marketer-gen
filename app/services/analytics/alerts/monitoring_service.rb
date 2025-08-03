# frozen_string_literal: true

module Analytics
  module Alerts
    # Main service for monitoring performance metrics and triggering alerts
    class MonitoringService
      def initialize(options = {})
        @batch_size = options[:batch_size] || 100
        @parallel_processing = options[:parallel_processing] || false
        @logger = Rails.logger
      end

      # Main monitoring loop - checks all active alerts
      def monitor_all_alerts
        @logger.info "Starting performance alert monitoring cycle"

        results = {
          checked: 0,
          triggered: 0,
          errors: 0,
          processing_time: 0
        }

        start_time = Time.current

        begin
          alerts = PerformanceAlert.ready_for_check
                                   .includes(:user, :campaign, :journey)
                                   .order(:severity, :last_checked_at)

          @logger.info "Found #{alerts.count} alerts ready for checking"

          if @parallel_processing && alerts.count > @batch_size
            results = process_alerts_in_parallel(alerts)
          else
            results = process_alerts_sequentially(alerts)
          end

          results[:processing_time] = ((Time.current - start_time) * 1000).round(2)

          @logger.info "Alert monitoring completed: #{results}"

          success(results)
        rescue StandardError => e
          @logger.error "Error in alert monitoring: #{e.message}"
          @logger.error e.backtrace.join("\n")

          error("Alert monitoring failed: #{e.message}")
        end
      end

      # Monitor specific alert
      def monitor_alert(alert)
        return error("Alert is not active") unless alert.active?

        @logger.debug "Checking alert: #{alert.name} (ID: #{alert.id})"

        begin
          # Get latest metric data
          metric_data = fetch_metric_data(alert)
          return success({ checked: true, triggered: false, message: "No metric data available" }) if metric_data.empty?

          # Apply filters to metric data
          filtered_data = apply_alert_filters(alert, metric_data)
          return success({ checked: true, triggered: false, message: "No data after applying filters" }) if filtered_data.empty?

          # Get current metric value
          current_value = extract_metric_value(filtered_data, alert.metric_type)
          return success({ checked: true, triggered: false, message: "Could not extract metric value" }) unless current_value

          # Update last checked timestamp
          alert.update_last_checked!

          # Check if alert should trigger
          trigger_result = check_alert_conditions(alert, current_value, filtered_data)

          if trigger_result[:should_trigger]
            alert_instance = alert.trigger_alert!(current_value, trigger_result[:context])

            if alert_instance
              @logger.info "Alert triggered: #{alert.name} - Value: #{current_value}"
              success({
                checked: true,
                triggered: true,
                alert_instance_id: alert_instance.id,
                current_value: current_value,
                threshold_value: alert.current_threshold
              })
            else
              error("Failed to trigger alert")
            end
          else
            @logger.debug "Alert conditions not met for #{alert.name}: #{trigger_result[:reason]}"
            success({
              checked: true,
              triggered: false,
              reason: trigger_result[:reason],
              current_value: current_value,
              threshold_value: alert.current_threshold
            })
          end

        rescue StandardError => e
          @logger.error "Error monitoring alert #{alert.id}: #{e.message}"
          error("Failed to monitor alert: #{e.message}")
        end
      end

      # Monitor specific metric type across all sources
      def monitor_metric_type(metric_type, options = {})
        @logger.info "Monitoring all alerts for metric type: #{metric_type}"

        alerts = PerformanceAlert.active
                                 .where(metric_type: metric_type)
                                 .includes(:user, :campaign, :journey)

        if options[:source]
          alerts = alerts.where(metric_source: options[:source])
        end

        results = process_alerts_sequentially(alerts)

        success(results.merge(metric_type: metric_type))
      end

      # Check if metric value should trigger alert
      def should_trigger_alert?(alert, current_value, context = {})
        result = check_alert_conditions(alert, current_value, context)
        result[:should_trigger]
      end

      # Get current metric value for alert
      def get_current_metric_value(alert)
        metric_data = fetch_metric_data(alert)
        return nil if metric_data.empty?

        filtered_data = apply_alert_filters(alert, metric_data)
        return nil if filtered_data.empty?

        extract_metric_value(filtered_data, alert.metric_type)
      end

      private

      def process_alerts_sequentially(alerts)
        results = { checked: 0, triggered: 0, errors: 0 }

        alerts.find_each(batch_size: @batch_size) do |alert|
          begin
            result = monitor_alert(alert)

            results[:checked] += 1
            results[:triggered] += 1 if result.success? && result.data[:triggered]

          rescue StandardError => e
            @logger.error "Error processing alert #{alert.id}: #{e.message}"
            results[:errors] += 1
          end
        end

        results
      end

      def process_alerts_in_parallel(alerts)
        require "parallel"

        results = { checked: 0, triggered: 0, errors: 0 }

        # Process in parallel batches
        alert_batches = alerts.each_slice(@batch_size).to_a

        batch_results = Parallel.map(alert_batches, in_processes: 4) do |batch|
          batch_result = { checked: 0, triggered: 0, errors: 0 }

          batch.each do |alert|
            begin
              result = monitor_alert(alert)

              batch_result[:checked] += 1
              batch_result[:triggered] += 1 if result.success? && result.data[:triggered]

            rescue StandardError => e
              Rails.logger.error "Error processing alert #{alert.id}: #{e.message}"
              batch_result[:errors] += 1
            end
          end

          batch_result
        end

        # Aggregate results
        batch_results.each do |batch_result|
          results[:checked] += batch_result[:checked]
          results[:triggered] += batch_result[:triggered]
          results[:errors] += batch_result[:errors]
        end

        results
      end

      def fetch_metric_data(alert)
        case alert.metric_source
        when "google_ads"
          fetch_google_ads_data(alert)
        when "facebook", "instagram"
          fetch_facebook_data(alert)
        when "email_marketing"
          fetch_email_data(alert)
        when "social_media"
          fetch_social_media_data(alert)
        when "web_analytics"
          fetch_web_analytics_data(alert)
        else
          @logger.warn "Unknown metric source: #{alert.metric_source}"
          []
        end
      rescue StandardError => e
        @logger.error "Error fetching metric data for #{alert.metric_source}: #{e.message}"
        []
      end

      def fetch_google_ads_data(alert)
        # Fetch from Google Analytics metrics or Google Ads API
        scope = GoogleAnalyticsMetric.where("date >= ?", 24.hours.ago)

        if alert.campaign_id
          # Filter by campaign if specified
          scope = scope.joins(:campaign).where(campaigns: { id: alert.campaign_id })
        end

        scope.order(:date).limit(100).to_a
      end

      def fetch_facebook_data(alert)
        # Fetch from social media metrics
        scope = SocialMediaMetric.where(platform: [ "facebook", "instagram" ])
                                 .where("date >= ?", 24.hours.ago)

        if alert.campaign_id
          scope = scope.joins(:social_media_integration)
                       .where(social_media_integrations: { brand_id: alert.campaign.brand_id })
        end

        scope.order(:date).limit(100).to_a
      end

      def fetch_email_data(alert)
        # Fetch from email metrics
        scope = EmailMetric.where("metric_date >= ?", 24.hours.ago)

        if alert.campaign_id
          scope = scope.joins(email_integration: :brand)
                       .where(brands: { id: alert.campaign.brand_id })
        end

        scope.order(:metric_date).limit(100).to_a
      end

      def fetch_social_media_data(alert)
        # Fetch from social media metrics
        scope = SocialMediaMetric.where("date >= ?", 24.hours.ago)

        if alert.campaign_id
          scope = scope.joins(:social_media_integration)
                       .where(social_media_integrations: { brand_id: alert.campaign.brand_id })
        end

        scope.order(:date).limit(100).to_a
      end

      def fetch_web_analytics_data(alert)
        # Fetch from Google Analytics or other web analytics
        scope = GoogleAnalyticsMetric.where("date >= ?", 24.hours.ago)
        scope.order(:date).limit(100).to_a
      end

      def apply_alert_filters(alert, metric_data)
        return metric_data if alert.filters.blank?

        filtered_data = metric_data.select do |data_point|
          alert.filters.all? do |filter|
            field = filter["field"]
            operator = filter["operator"]
            value = filter["value"]

            data_value = extract_field_value(data_point, field)
            next false if data_value.nil?

            case operator
            when "equals"
              data_value.to_s == value.to_s
            when "not_equals"
              data_value.to_s != value.to_s
            when "greater_than"
              data_value.to_f > value.to_f
            when "less_than"
              data_value.to_f < value.to_f
            when "contains"
              data_value.to_s.include?(value.to_s)
            when "in"
              Array(value).include?(data_value.to_s)
            else
              true
            end
          end
        end

        filtered_data
      rescue StandardError => e
        @logger.error "Error applying filters for alert #{alert.id}: #{e.message}"
        metric_data
      end

      def extract_metric_value(metric_data, metric_type)
        return nil if metric_data.empty?

        latest_data = metric_data.last

        case metric_type
        when "conversion_rate"
          extract_conversion_rate(latest_data)
        when "click_rate", "click_through_rate"
          extract_click_rate(latest_data)
        when "open_rate"
          extract_open_rate(latest_data)
        when "cost_per_acquisition"
          extract_cost_per_acquisition(latest_data)
        when "cost_per_click"
          extract_cost_per_click(latest_data)
        when "bounce_rate"
          extract_bounce_rate(latest_data)
        when "engagement_rate"
          extract_engagement_rate(latest_data)
        when "reach"
          extract_reach(latest_data)
        when "impressions"
          extract_impressions(latest_data)
        when "revenue"
          extract_revenue(latest_data)
        else
          @logger.warn "Unknown metric type: #{metric_type}"
          nil
        end
      rescue StandardError => e
        @logger.error "Error extracting metric value for #{metric_type}: #{e.message}"
        nil
      end

      def extract_field_value(data_point, field)
        case data_point
        when GoogleAnalyticsMetric
          data_point.send(field) if data_point.respond_to?(field)
        when SocialMediaMetric
          data_point.send(field) if data_point.respond_to?(field)
        when EmailMetric
          data_point.send(field) if data_point.respond_to?(field)
        when Hash
          data_point[field] || data_point[field.to_sym]
        else
          data_point.try(field)
        end
      end

      def extract_conversion_rate(data)
        case data
        when GoogleAnalyticsMetric
          return 0.0 if data.sessions.zero?
          (data.goal_completions.to_f / data.sessions * 100).round(2)
        when SocialMediaMetric
          # Calculate conversion rate from social media data
          data.try(:value) || 0.0
        when EmailMetric
          data.try(:click_rate) || 0.0
        else
          0.0
        end
      end

      def extract_click_rate(data)
        case data
        when EmailMetric
          data.click_rate || 0.0
        when SocialMediaMetric
          # Calculate CTR for social media
          data.try(:value) || 0.0
        else
          0.0
        end
      end

      def extract_open_rate(data)
        case data
        when EmailMetric
          data.open_rate || 0.0
        else
          0.0
        end
      end

      def extract_cost_per_acquisition(data)
        case data
        when GoogleAnalyticsMetric
          return 0.0 if data.goal_completions.zero?
          # This would need to be calculated with cost data
          0.0
        else
          0.0
        end
      end

      def extract_cost_per_click(data)
        # This would need cost and click data from advertising platforms
        0.0
      end

      def extract_bounce_rate(data)
        case data
        when GoogleAnalyticsMetric
          data.bounce_rate || 0.0
        else
          0.0
        end
      end

      def extract_engagement_rate(data)
        case data
        when SocialMediaMetric
          data.try(:value) || 0.0
        else
          0.0
        end
      end

      def extract_reach(data)
        case data
        when SocialMediaMetric
          data.try(:value) || 0
        when GoogleAnalyticsMetric
          data.users || 0
        else
          0
        end
      end

      def extract_impressions(data)
        case data
        when SocialMediaMetric
          data.try(:value) || 0
        when GoogleAnalyticsMetric
          data.page_views || 0
        else
          0
        end
      end

      def extract_revenue(data)
        case data
        when GoogleAnalyticsMetric
          data.transaction_revenue || 0.0
        else
          0.0
        end
      end

      def check_alert_conditions(alert, current_value, metric_data)
        context = {
          metric_data: metric_data.is_a?(Array) ? metric_data.last : metric_data,
          timestamp: Time.current,
          alert_id: alert.id
        }

        # First check if custom conditions are met
        unless alert.evaluate_conditions(context[:metric_data] || {})
          return {
            should_trigger: false,
            reason: "Custom conditions not met",
            context: context
          }
        end

        # Check alert type specific conditions
        case alert.alert_type
        when "threshold"
          check_threshold_conditions(alert, current_value, context)
        when "anomaly"
          check_anomaly_conditions(alert, current_value, context)
        when "trend"
          check_trend_conditions(alert, current_value, metric_data, context)
        when "comparison"
          check_comparison_conditions(alert, current_value, metric_data, context)
        else
          {
            should_trigger: false,
            reason: "Unknown alert type: #{alert.alert_type}",
            context: context
          }
        end
      end

      def check_threshold_conditions(alert, current_value, context)
        threshold = alert.current_threshold

        return {
          should_trigger: false,
          reason: "No threshold defined",
          context: context
        } unless threshold

        breached = case alert.threshold_operator
        when "greater_than"
                     current_value > threshold
        when "greater_than_or_equal"
                     current_value >= threshold
        when "less_than"
                     current_value < threshold
        when "less_than_or_equal"
                     current_value <= threshold
        when "equals"
                     current_value == threshold
        when "not_equals"
                     current_value != threshold
        else
                     false
        end

        if breached
          # Check if threshold has been breached for required duration
          if alert.threshold_duration_minutes > 0
            # This would require storing historical breach data
            # For now, we'll assume immediate triggering
            context[:breach_duration] = 0
          end

          {
            should_trigger: true,
            reason: "Threshold breached: #{current_value} #{alert.threshold_operator} #{threshold}",
            context: context
          }
        else
          {
            should_trigger: false,
            reason: "Threshold not breached: #{current_value} vs #{threshold}",
            context: context
          }
        end
      end

      def check_anomaly_conditions(alert, current_value, context)
        if alert.should_use_ml_thresholds?
          # Use ML-based anomaly detection
          threshold_record = PerformanceThreshold.find_or_create_for_context(
            alert.metric_type,
            alert.metric_source,
            campaign_id: alert.campaign_id,
            journey_id: alert.journey_id
          )

          is_anomaly = threshold_record.is_anomaly?(current_value, context)
          anomaly_score = threshold_record.calculate_anomaly_score(current_value)

          context[:anomaly_score] = anomaly_score
          context[:threshold_record_id] = threshold_record.id

          if is_anomaly
            {
              should_trigger: true,
              reason: "Anomaly detected (score: #{anomaly_score.round(3)})",
              context: context
            }
          else
            {
              should_trigger: false,
              reason: "No anomaly detected (score: #{anomaly_score.round(3)})",
              context: context
            }
          end
        else
          # Use simple threshold-based anomaly detection
          check_threshold_conditions(alert, current_value, context)
        end
      end

      def check_trend_conditions(alert, current_value, metric_data, context)
        return {
          should_trigger: false,
          reason: "Insufficient data for trend analysis",
          context: context
        } if metric_data.length < 2

        # Calculate trend (simple slope)
        values = metric_data.map { |d| extract_metric_value([ d ], alert.metric_type) }.compact
        return {
          should_trigger: false,
          reason: "No valid metric values for trend analysis",
          context: context
        } if values.length < 2

        trend_slope = calculate_trend_slope(values)

        context[:trend_slope] = trend_slope
        context[:trend_direction] = trend_slope > 0 ? "increasing" : "decreasing"

        # Check if trend meets alert criteria
        threshold = alert.current_threshold || 0.1
        significant_trend = trend_slope.abs > threshold

        if significant_trend
          {
            should_trigger: true,
            reason: "Significant trend detected: #{context[:trend_direction]} (slope: #{trend_slope.round(4)})",
            context: context
          }
        else
          {
            should_trigger: false,
            reason: "No significant trend detected (slope: #{trend_slope.round(4)})",
            context: context
          }
        end
      end

      def check_comparison_conditions(alert, current_value, metric_data, context)
        # Compare with historical data (e.g., same time last week)
        comparison_period = 7.days.ago

        historical_data = fetch_historical_data(alert, comparison_period)
        return {
          should_trigger: false,
          reason: "No historical data for comparison",
          context: context
        } if historical_data.empty?

        historical_value = extract_metric_value(historical_data, alert.metric_type)
        return {
          should_trigger: false,
          reason: "Could not extract historical metric value",
          context: context
        } unless historical_value

        percentage_change = ((current_value - historical_value) / historical_value * 100).round(2)

        context[:historical_value] = historical_value
        context[:percentage_change] = percentage_change

        threshold = alert.current_threshold || 10.0 # 10% change threshold
        significant_change = percentage_change.abs > threshold

        if significant_change
          {
            should_trigger: true,
            reason: "Significant change detected: #{percentage_change}% vs historical",
            context: context
          }
        else
          {
            should_trigger: false,
            reason: "No significant change detected: #{percentage_change}% vs historical",
            context: context
          }
        end
      end

      def calculate_trend_slope(values)
        n = values.length
        return 0.0 if n < 2

        # Calculate linear regression slope
        x_values = (0...n).to_a
        sum_x = x_values.sum
        sum_y = values.sum
        sum_xy = x_values.zip(values).map { |x, y| x * y }.sum
        sum_x_squared = x_values.map { |x| x * x }.sum

        denominator = n * sum_x_squared - sum_x * sum_x
        return 0.0 if denominator.zero?

        (n * sum_xy - sum_x * sum_y).to_f / denominator
      end

      def fetch_historical_data(alert, date)
        case alert.metric_source
        when "google_ads"
          GoogleAnalyticsMetric.where(date: date.to_date).limit(1)
        when "facebook", "instagram"
          SocialMediaMetric.where(platform: alert.metric_source, date: date.to_date).limit(1)
        when "email_marketing"
          EmailMetric.where(metric_date: date.to_date).limit(1)
        else
          []
        end
      end
    end
  end
end
