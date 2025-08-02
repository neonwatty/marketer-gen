module AbTesting
  class AdaptiveTrafficAllocator
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def adjust_traffic_allocation(performance_data)
      begin
        # Validate performance data
        validate_performance_data(performance_data)

        # Calculate optimal allocation based on performance
        optimal_allocation = calculate_optimal_allocation(performance_data)

        # Apply constraints and safety checks
        constrained_allocation = apply_allocation_constraints(optimal_allocation)

        # Check if adjustments are significant enough to warrant changes
        if should_make_adjustments?(constrained_allocation)
          # Apply the new allocation
          apply_allocation_adjustments(constrained_allocation)

          {
            adjustments_made: true,
            new_allocations: constrained_allocation,
            adjustment_reason: determine_adjustment_reason(performance_data),
            performance_summary: calculate_performance_summary(performance_data),
            expected_impact: predict_adjustment_impact(constrained_allocation)
          }
        else
          {
            adjustments_made: false,
            current_allocations: get_current_allocations,
            reason: "No significant performance differences detected",
            performance_summary: calculate_performance_summary(performance_data)
          }
        end
      rescue => e
        {
          adjustments_made: false,
          error: e.message
        }
      end
    end

    def calculate_optimal_allocation(performance_data)
      # Use Thompson Sampling (Bayesian bandit) approach for optimal allocation
      allocation_scores = calculate_thompson_sampling_scores(performance_data)

      # Convert scores to traffic percentages
      total_score = allocation_scores.values.sum
      return equal_allocation if total_score == 0

      optimal_allocations = []
      allocation_scores.each do |variant_id, score|
        traffic_percentage = (score / total_score) * 100.0

        optimal_allocations << {
          variant_id: variant_id,
          traffic_percentage: traffic_percentage.round(2),
          allocation_score: score,
          allocation_method: "thompson_sampling"
        }
      end

      # Ensure minimum allocation for statistical validity
      ensure_minimum_allocations(optimal_allocations)
    end

    def evaluate_performance_trends(performance_data)
      trends = {}

      performance_data.each do |variant_id, data|
        variant = find_variant(variant_id)
        next unless variant

        # Calculate performance trend metrics
        current_rate = data[:conversion_rate] || 0
        confidence = data[:confidence] || 0
        sample_size = data[:sample_size] || 0

        # Calculate trend direction
        trend_direction = calculate_trend_direction(variant, current_rate)
        trend_strength = calculate_trend_strength(variant, current_rate, confidence)

        trends[variant_id] = {
          trend_direction: trend_direction,  # 'improving', 'declining', 'stable'
          trend_strength: trend_strength,    # 0.0 to 1.0
          performance_velocity: calculate_performance_velocity(variant, current_rate),
          confidence_trend: calculate_confidence_trend(variant, confidence),
          sample_adequacy: assess_sample_adequacy(sample_size),
          recommendation: generate_trend_recommendation(trend_direction, trend_strength)
        }
      end

      trends
    end

    def predict_allocation_impact(new_allocation)
      current_allocation = get_current_allocations
      impact_analysis = {}

      new_allocation.each do |allocation|
        variant_id = allocation[:variant_id]
        current_traffic = current_allocation.find { |c| c[:variant_id] == variant_id }&.dig(:traffic_percentage) || 0
        new_traffic = allocation[:traffic_percentage]

        traffic_change = new_traffic - current_traffic
        next if traffic_change.abs < 1.0  # Ignore tiny changes

        variant = find_variant(variant_id)
        next unless variant

        # Predict impact based on traffic change and variant performance
        predicted_visitor_change = calculate_predicted_visitor_change(traffic_change)
        predicted_conversion_change = calculate_predicted_conversion_change(variant, predicted_visitor_change)

        impact_analysis[variant_id] = {
          traffic_change_percentage: traffic_change.round(1),
          predicted_visitor_change: predicted_visitor_change,
          predicted_conversion_change: predicted_conversion_change,
          impact_confidence: calculate_impact_confidence(variant, traffic_change),
          risk_level: assess_allocation_risk(variant, traffic_change)
        }
      end

      # Calculate overall test impact
      overall_impact = calculate_overall_test_impact(impact_analysis)

      {
        variant_impacts: impact_analysis,
        overall_test_impact: overall_impact,
        recommendation: generate_impact_recommendation(overall_impact)
      }
    end

    private

    def validate_performance_data(data)
      if data.empty?
        raise ArgumentError, "Performance data cannot be empty"
      end

      data.each do |variant_id, performance|
        unless performance.is_a?(Hash)
          raise ArgumentError, "Performance data for variant #{variant_id} must be a hash"
        end

        required_fields = [ :conversion_rate, :confidence, :sample_size ]
        missing_fields = required_fields - performance.keys

        if missing_fields.any?
          raise ArgumentError, "Missing performance fields for variant #{variant_id}: #{missing_fields.join(', ')}"
        end
      end
    end

    def calculate_thompson_sampling_scores(performance_data)
      scores = {}

      performance_data.each do |variant_id, data|
        # Extract performance metrics
        conversion_rate = data[:conversion_rate] / 100.0  # Convert percentage to decimal
        sample_size = data[:sample_size]
        conversions = (conversion_rate * sample_size).round

        # Beta distribution parameters for Thompson Sampling
        alpha = conversions + 1  # Prior alpha = 1
        beta = sample_size - conversions + 1  # Prior beta = 1

        # Sample from Beta distribution (simplified using expected value + exploration)
        expected_value = alpha / (alpha + beta).to_f
        exploration_bonus = calculate_exploration_bonus(alpha, beta)

        scores[variant_id] = expected_value + exploration_bonus
      end

      scores
    end

    def calculate_exploration_bonus(alpha, beta)
      # Upper confidence bound for exploration
      total_samples = alpha + beta - 2  # Subtract priors
      return 0.1 if total_samples == 0  # High exploration for new variants

      # Confidence interval width as exploration bonus
      confidence_width = 1.96 * Math.sqrt((alpha * beta) / ((alpha + beta)**2 * (alpha + beta + 1)))
      [ confidence_width * 0.5, 0.05 ].min  # Cap exploration bonus
    end

    def equal_allocation
      variant_count = @ab_test.ab_test_variants.count
      equal_percentage = (100.0 / variant_count).round(2)

      @ab_test.ab_test_variants.map do |variant|
        {
          variant_id: variant.id,
          traffic_percentage: equal_percentage,
          allocation_score: 1.0,
          allocation_method: "equal_fallback"
        }
      end
    end

    def ensure_minimum_allocations(allocations)
      min_allocation = 5.0  # Minimum 5% for statistical validity

      # Ensure each variant gets at least minimum allocation
      allocations.each do |allocation|
        if allocation[:traffic_percentage] < min_allocation
          allocation[:traffic_percentage] = min_allocation
          allocation[:allocation_method] = "minimum_enforced"
        end
      end

      # Renormalize to 100%
      total_allocation = allocations.sum { |a| a[:traffic_percentage] }
      if total_allocation > 100
        scale_factor = 100.0 / total_allocation
        allocations.each do |allocation|
          allocation[:traffic_percentage] = (allocation[:traffic_percentage] * scale_factor).round(2)
        end
      end

      allocations
    end

    def apply_allocation_constraints(optimal_allocation)
      # Apply any test-specific constraints
      configuration = get_allocation_configuration
      return optimal_allocation unless configuration

      constrained_allocation = optimal_allocation.map do |allocation|
        variant_id = allocation[:variant_id]
        constraints = find_variant_constraints(variant_id, configuration)

        if constraints
          # Apply min/max constraints
          constrained_traffic = [
            [ allocation[:traffic_percentage], constraints[:min_traffic] || 0 ].max,
            constraints[:max_traffic] || 100
          ].min

          allocation.merge(
            traffic_percentage: constrained_traffic,
            constraints_applied: constraints,
            allocation_method: "#{allocation[:allocation_method]}_constrained"
          )
        else
          allocation
        end
      end

      # Renormalize after applying constraints
      renormalize_allocations(constrained_allocation)
    end

    def should_make_adjustments?(new_allocation)
      current_allocation = get_current_allocations

      # Calculate total adjustment magnitude
      total_change = 0
      new_allocation.each do |new_alloc|
        current_traffic = current_allocation.find { |c| c[:variant_id] == new_alloc[:variant_id] }&.dig(:traffic_percentage) || 0
        total_change += (new_alloc[:traffic_percentage] - current_traffic).abs
      end

      # Only adjust if changes are significant (> 5% total change)
      total_change > 5.0
    end

    def apply_allocation_adjustments(new_allocation)
      new_allocation.each do |allocation|
        variant = find_variant(allocation[:variant_id])
        next unless variant

        variant.update!(
          traffic_percentage: allocation[:traffic_percentage],
          metadata: variant.metadata.merge(
            last_adaptive_adjustment: Time.current,
            allocation_method: allocation[:allocation_method],
            allocation_score: allocation[:allocation_score],
            constraints_applied: allocation[:constraints_applied]
          )
        )
      end

      # Log the adjustment
      log_adaptive_adjustment(new_allocation)
    end

    def calculate_trend_direction(variant, current_rate)
      # Compare with historical performance (simplified)
      historical_rate = variant.metadata["average_conversion_rate"] || variant.conversion_rate

      if current_rate > historical_rate * 1.05
        "improving"
      elsif current_rate < historical_rate * 0.95
        "declining"
      else
        "stable"
      end
    end

    def calculate_trend_strength(variant, current_rate, confidence)
      # Trend strength based on rate change and confidence
      historical_rate = variant.metadata["average_conversion_rate"] || variant.conversion_rate
      return 0 if historical_rate == 0

      rate_change_magnitude = (current_rate - historical_rate).abs / historical_rate
      confidence_factor = confidence / 100.0

      [ rate_change_magnitude * confidence_factor, 1.0 ].min
    end

    def calculate_performance_velocity(variant, current_rate)
      # Rate of change in performance (simplified)
      previous_rate = variant.metadata["previous_conversion_rate"] || current_rate
      time_diff = variant.metadata["last_rate_update"] ?
                    (Time.current - Time.parse(variant.metadata["last_rate_update"])) / 1.day : 1

      return 0 if time_diff == 0

      (current_rate - previous_rate) / time_diff
    end

    def calculate_confidence_trend(variant, current_confidence)
      previous_confidence = variant.metadata["previous_confidence"] || current_confidence
      current_confidence - previous_confidence
    end

    def assess_sample_adequacy(sample_size)
      case sample_size
      when 0..99 then "insufficient"
      when 100..499 then "minimal"
      when 500..999 then "adequate"
      when 1000..4999 then "good"
      else "excellent"
      end
    end

    def generate_trend_recommendation(direction, strength)
      case direction
      when "improving"
        strength > 0.7 ? "increase_traffic" : "monitor_closely"
      when "declining"
        strength > 0.7 ? "decrease_traffic" : "investigate_causes"
      else
        "maintain_current_allocation"
      end
    end

    def find_variant(variant_id)
      @ab_test.ab_test_variants.find_by(id: variant_id)
    end

    def get_current_allocations
      @ab_test.ab_test_variants.map do |variant|
        {
          variant_id: variant.id,
          traffic_percentage: variant.traffic_percentage
        }
      end
    end

    def get_allocation_configuration
      @ab_test.ab_test_configurations
              .where(configuration_type: "traffic_allocation", is_active: true)
              .first&.settings
    end

    def find_variant_constraints(variant_id, configuration)
      configuration["variants"]&.find { |v| v["variant_id"] == variant_id }
    end

    def renormalize_allocations(allocations)
      total = allocations.sum { |a| a[:traffic_percentage] }
      return allocations if (99.0..101.0).cover?(total)

      scale_factor = 100.0 / total
      allocations.each do |allocation|
        allocation[:traffic_percentage] = (allocation[:traffic_percentage] * scale_factor).round(2)
      end

      allocations
    end

    def log_adaptive_adjustment(new_allocation)
      adjustment_log = {
        timestamp: Time.current,
        adjustment_type: "adaptive_reallocation",
        new_allocation: new_allocation,
        adjustment_reason: "performance_optimization"
      }

      @ab_test.update!(
        metadata: @ab_test.metadata.merge(
          adaptive_adjustment_history: (@ab_test.metadata["adaptive_adjustment_history"] || []) + [ adjustment_log ]
        )
      )
    end

    def determine_adjustment_reason(performance_data)
      # Determine primary reason for adjustment
      best_performer = performance_data.max_by { |_, data| data[:conversion_rate] || 0 }
      worst_performer = performance_data.min_by { |_, data| data[:conversion_rate] || 0 }

      if best_performer && worst_performer
        best_rate = best_performer[1][:conversion_rate] || 0
        worst_rate = worst_performer[1][:conversion_rate] || 0

        if best_rate > worst_rate * 1.5
          "significant_performance_difference"
        elsif best_performer[1][:confidence] > 90
          "high_confidence_winner"
        else
          "optimization_opportunity"
        end
      else
        "routine_optimization"
      end
    end

    def calculate_performance_summary(performance_data)
      summary = {
        total_variants: performance_data.keys.length,
        best_conversion_rate: performance_data.values.map { |d| d[:conversion_rate] || 0 }.max,
        worst_conversion_rate: performance_data.values.map { |d| d[:conversion_rate] || 0 }.min,
        average_confidence: performance_data.values.map { |d| d[:confidence] || 0 }.sum / performance_data.values.length,
        total_sample_size: performance_data.values.map { |d| d[:sample_size] || 0 }.sum
      }

      summary[:performance_spread] = summary[:best_conversion_rate] - summary[:worst_conversion_rate]
      summary
    end

    def calculate_predicted_visitor_change(traffic_change_percentage)
      # Estimate visitor change based on traffic percentage change
      current_daily_visitors = @ab_test.ab_test_variants.sum(:total_visitors) / [ @ab_test.duration_days, 1 ].max
      (current_daily_visitors * traffic_change_percentage / 100.0).round
    end

    def calculate_predicted_conversion_change(variant, visitor_change)
      conversion_rate = variant.conversion_rate / 100.0
      (visitor_change * conversion_rate).round
    end

    def calculate_impact_confidence(variant, traffic_change)
      # Confidence in impact prediction based on variant stability and traffic change magnitude
      stability_score = [ variant.total_visitors / 1000.0, 1.0 ].min  # More visitors = more stability
      magnitude_score = [ traffic_change.abs / 50.0, 1.0 ].min  # Larger changes = more predictable impact

      (stability_score * 0.7 + magnitude_score * 0.3) * 100
    end

    def assess_allocation_risk(variant, traffic_change)
      if traffic_change > 0
        # Increasing traffic to variant
        variant.conversion_rate > 0 ? "low" : "medium"
      else
        # Decreasing traffic from variant
        variant.is_control? ? "high" : "low"
      end
    end

    def calculate_overall_test_impact(variant_impacts)
      return {} if variant_impacts.empty?

      total_predicted_conversions = variant_impacts.values.sum { |impact| impact[:predicted_conversion_change] }
      average_confidence = variant_impacts.values.map { |impact| impact[:impact_confidence] }.sum / variant_impacts.values.length
      max_risk_level = variant_impacts.values.map { |impact| impact[:risk_level] }.max_by { |risk| risk_level_score(risk) }

      {
        predicted_total_conversion_change: total_predicted_conversions,
        average_impact_confidence: average_confidence.round(1),
        overall_risk_level: max_risk_level,
        significant_changes: variant_impacts.count { |_, impact| impact[:traffic_change_percentage].abs > 10 }
      }
    end

    def generate_impact_recommendation(overall_impact)
      confidence = overall_impact[:average_impact_confidence] || 0
      risk = overall_impact[:overall_risk_level]

      if confidence > 80 && risk != "high"
        "recommended"
      elsif confidence > 60 && risk == "low"
        "proceed_with_caution"
      else
        "not_recommended"
      end
    end

    def risk_level_score(risk_level)
      case risk_level
      when "low" then 1
      when "medium" then 2
      when "high" then 3
      else 0
      end
    end
  end
end
