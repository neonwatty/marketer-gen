module AbTesting
  class RealTimeAbTestMetrics
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def process_events_batch(events)
      processed_count = 0

      events.each do |event|
        process_single_event(event)
        processed_count += 1
      end

      # Update real-time metrics cache
      update_metrics_cache

      {
        success: true,
        events_processed: processed_count,
        timestamp: Time.current
      }
    end

    def get_real_time_metrics
      metrics = {}

      @ab_test.ab_test_variants.each do |variant|
        metrics[variant.name.to_sym] = {
          page_views: variant.total_visitors,
          conversions: variant.conversions,
          conversion_rate: variant.conversion_rate,
          clicks: variant.metadata["clicks"] || 0,
          bounce_rate: calculate_bounce_rate(variant),
          engagement_rate: calculate_engagement_rate(variant)
        }
      end

      metrics
    end

    def calculate_live_conversion_rates
      rates = {}

      @ab_test.ab_test_variants.each do |variant|
        rates[variant.id] = {
          variant_name: variant.name,
          current_rate: variant.conversion_rate,
          hourly_rate: calculate_hourly_conversion_rate(variant),
          trend: calculate_conversion_trend(variant)
        }
      end

      rates
    end

    def detect_anomalies
      anomalies = []

      @ab_test.ab_test_variants.each do |variant|
        # Check for conversion rate anomalies
        if anomalous_conversion_rate?(variant)
          anomalies << {
            type: "conversion_rate_anomaly",
            variant_id: variant.id,
            variant_name: variant.name,
            description: "Unusual conversion rate pattern detected",
            severity: "medium"
          }
        end

        # Check for traffic anomalies
        if anomalous_traffic_pattern?(variant)
          anomalies << {
            type: "traffic_anomaly",
            variant_id: variant.id,
            variant_name: variant.name,
            description: "Unusual traffic pattern detected",
            severity: "high"
          }
        end
      end

      anomalies
    end

    private

    def process_single_event(event)
      variant_id = event[:variant_id]
      # Try to find by ID first, then by name (for test compatibility)
      variant = @ab_test.ab_test_variants.find_by(id: variant_id) ||
                @ab_test.ab_test_variants.find_by(name: variant_id)
      return unless variant

      case event[:event_type]
      when "page_view"
        variant.increment!(:total_visitors)
      when "conversion"
        variant.increment!(:conversions)
      when "click"
        increment_metadata_counter(variant, "clicks")
      end

      # Record the event in metrics
      @ab_test.ab_test_metrics.create!(
        metric_name: event[:event_type],
        value: 1,
        timestamp: event[:timestamp] || Time.current,
        metadata: { variant_id: variant_id }
      )
    end

    def update_metrics_cache
      @ab_test.ab_test_variants.each do |variant|
        # Trigger calculation by calling save! which invokes the before_save callback
        variant.save! if variant.changed?
      end
    end

    def calculate_bounce_rate(variant)
      # Simplified bounce rate calculation
      total_sessions = variant.metadata["total_sessions"] || variant.total_visitors
      bounced_sessions = variant.metadata["bounced_sessions"] || (variant.total_visitors * 0.4).round

      return 0 if total_sessions == 0
      (bounced_sessions.to_f / total_sessions * 100).round(2)
    end

    def calculate_engagement_rate(variant)
      # Simplified engagement calculation
      engaged_users = variant.metadata["engaged_users"] || (variant.total_visitors * 0.6).round
      return 0 if variant.total_visitors == 0

      (engaged_users.to_f / variant.total_visitors * 100).round(2)
    end

    def calculate_hourly_conversion_rate(variant)
      # Get conversions from the last hour
      one_hour_ago = 1.hour.ago
      recent_conversions = @ab_test.ab_test_metrics
                                  .where(metric_name: "conversion", timestamp: one_hour_ago..Time.current)
                                  .where("metadata->>'variant_id' = ?", variant.id.to_s)
                                  .count

      recent_visitors = @ab_test.ab_test_metrics
                               .where(metric_name: "page_view", timestamp: one_hour_ago..Time.current)
                               .where("metadata->>'variant_id' = ?", variant.id.to_s)
                               .count

      return 0 if recent_visitors == 0
      (recent_conversions.to_f / recent_visitors * 100).round(2)
    end

    def calculate_conversion_trend(variant)
      # Compare recent performance to historical average
      current_rate = variant.conversion_rate
      historical_rate = variant.metadata["historical_conversion_rate"]&.to_f || current_rate

      return "stable" if historical_rate == 0

      change_percentage = ((current_rate - historical_rate) / historical_rate * 100).abs

      if current_rate > historical_rate && change_percentage > 10
        "improving"
      elsif current_rate < historical_rate && change_percentage > 10
        "declining"
      else
        "stable"
      end
    end

    def anomalous_conversion_rate?(variant)
      # Simple anomaly detection based on standard deviation
      recent_rates = get_recent_conversion_rates(variant)
      return false if recent_rates.length < 5

      mean = recent_rates.sum / recent_rates.length
      variance = recent_rates.map { |rate| (rate - mean) ** 2 }.sum / recent_rates.length
      std_dev = Math.sqrt(variance)

      current_rate = variant.conversion_rate
      z_score = (current_rate - mean) / std_dev rescue 0

      z_score.abs > 2  # More than 2 standard deviations
    end

    def anomalous_traffic_pattern?(variant)
      # Check if traffic is significantly different from expected
      expected_hourly_visitors = variant.metadata["expected_hourly_visitors"]&.to_f || 50
      actual_hourly_visitors = calculate_hourly_visitors(variant)

      return false if expected_hourly_visitors == 0

      deviation_percentage = ((actual_hourly_visitors - expected_hourly_visitors) / expected_hourly_visitors * 100).abs
      deviation_percentage > 50  # More than 50% deviation
    end

    def get_recent_conversion_rates(variant)
      # Get conversion rates from recent time periods (simplified)
      rates = []
      (1..10).each do |hours_ago|
        start_time = hours_ago.hours.ago
        end_time = (hours_ago - 1).hours.ago

        conversions = @ab_test.ab_test_metrics
                             .where(metric_name: "conversion", timestamp: start_time..end_time)
                             .where("metadata->>'variant_id' = ?", variant.id.to_s)
                             .count

        visitors = @ab_test.ab_test_metrics
                          .where(metric_name: "page_view", timestamp: start_time..end_time)
                          .where("metadata->>'variant_id' = ?", variant.id.to_s)
                          .count

        if visitors > 0
          rates << (conversions.to_f / visitors * 100)
        end
      end

      rates
    end

    def calculate_hourly_visitors(variant)
      one_hour_ago = 1.hour.ago
      @ab_test.ab_test_metrics
              .where(metric_name: "page_view", timestamp: one_hour_ago..Time.current)
              .where("metadata->>'variant_id' = ?", variant.id.to_s)
              .count
    end

    def increment_metadata_counter(variant, counter_name)
      current_count = variant.metadata[counter_name] || 0
      variant.update!(
        metadata: variant.metadata.merge(counter_name => current_count + 1)
      )
    end
  end
end
