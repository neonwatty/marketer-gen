module AbTesting
  class AbTestOptimizationAi
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def generate_optimization_suggestions(current_test_state)
      # Analyze current performance
      performance_analysis = analyze_current_performance(current_test_state)

      # Generate traffic allocation suggestions
      traffic_suggestions = analyze_traffic_allocation(current_test_state)

      # Generate duration recommendations
      duration_recommendations = analyze_test_duration(current_test_state)

      # Generate performance insights
      performance_insights = generate_performance_insights(current_test_state, performance_analysis)

      {
        traffic_allocation_changes: traffic_suggestions,
        duration_recommendations: duration_recommendations,
        performance_insights: performance_insights,
        optimization_score: calculate_optimization_score(current_test_state),
        next_actions: generate_next_actions(current_test_state, performance_analysis)
      }
    end

    def analyze_performance_trends(test_state)
      trends = {}

      test_state[:variants].each do |variant|
        variant_id = variant[:id]
        conversion_rate = variant[:conversion_rate] || 0

        trends[variant_id] = {
          current_performance: conversion_rate,
          trend_direction: calculate_trend_direction(variant),
          performance_stability: calculate_performance_stability(variant),
          confidence_level: calculate_confidence_level(variant),
          sample_adequacy: assess_sample_adequacy(variant),
          projected_final_rate: project_final_conversion_rate(variant)
        }
      end

      trends
    end

    def suggest_traffic_adjustments(current_state)
      adjustments = {}

      # Identify best and worst performing variants
      variants = current_state[:variants] || []
      return adjustments if variants.length < 2

      sorted_variants = variants.sort_by { |v| v[:conversion_rate] || 0 }.reverse
      best_variant = sorted_variants.first
      worst_variant = sorted_variants.last

      # Calculate performance gap
      performance_gap = (best_variant[:conversion_rate] || 0) - (worst_variant[:conversion_rate] || 0)

      if performance_gap > 0.5  # Significant performance difference
        # Suggest increasing traffic to better performers
        adjustments[:reasoning] = "Significant performance difference detected (#{performance_gap.round(2)}%)"

        new_allocation = calculate_performance_weighted_allocation(variants)
        adjustments[:new_allocation] = new_allocation
        adjustments[:expected_improvement] = estimate_improvement_from_reallocation(variants, new_allocation)
      end

      adjustments
    end

    def recommend_duration_changes(test_state)
      days_running = test_state[:days_running] || 0
      statistical_power = test_state[:statistical_power] || 0

      recommendation = {
        recommended_action: "continue",
        reasoning: "Test is progressing normally",
        additional_days_needed: 0,
        confidence_in_recommendation: 0.8
      }

      # Check if test has sufficient power
      if statistical_power < 0.8
        if days_running < 14
          recommendation[:recommended_action] = "continue"
          recommendation[:reasoning] = "Test needs more time to reach adequate statistical power"
          recommendation[:additional_days_needed] = estimate_days_to_power(test_state)
        else
          recommendation[:recommended_action] = "extend"
          recommendation[:reasoning] = "Test duration should be extended to achieve statistical significance"
          recommendation[:additional_days_needed] = estimate_days_to_power(test_state)
        end
      elsif statistical_power > 0.9 && days_running > 7
        # Check if we have a clear winner
        if has_clear_winner?(test_state)
          recommendation[:recommended_action] = "stop_early"
          recommendation[:reasoning] = "Test has achieved statistical significance with clear winner"
          recommendation[:confidence_in_recommendation] = 0.9
        end
      end

      recommendation
    end

    private

    def analyze_current_performance(test_state)
      variants = test_state[:variants] || []

      analysis = {
        total_traffic: variants.sum { |v| v[:visitors] || 0 },
        conversion_rates: variants.map { |v| v[:conversion_rate] || 0 },
        best_performer: variants.max_by { |v| v[:conversion_rate] || 0 },
        worst_performer: variants.min_by { |v| v[:conversion_rate] || 0 },
        performance_spread: calculate_performance_spread(variants),
        statistical_significance: assess_statistical_significance(variants)
      }

      analysis
    end

    def analyze_traffic_allocation(test_state)
      current_allocation = test_state[:traffic_allocation] || {}
      variants = test_state[:variants] || []

      # Check if allocation matches performance
      performance_ranking = variants.sort_by { |v| v[:conversion_rate] || 0 }.reverse

      suggestions = nil

      # If best performer doesn't have highest traffic allocation
      best_variant_id = performance_ranking.first[:id]
      best_traffic = current_allocation[best_variant_id] || 0

      max_traffic = current_allocation.values.max || 0

      if best_traffic < max_traffic
        suggestions = {
          reasoning: "Best performing variant (#{best_variant_id}) should receive more traffic",
          recommended_changes: calculate_optimal_allocation(variants),
          expected_benefit: "Increase overall conversion rate by routing more traffic to better performers"
        }
      end

      suggestions
    end

    def analyze_test_duration(test_state)
      days_running = test_state[:days_running] || 0
      statistical_power = test_state[:statistical_power] || 0

      {
        recommended_action: determine_duration_action(days_running, statistical_power),
        reasoning: generate_duration_reasoning(days_running, statistical_power),
        optimal_duration: calculate_optimal_duration(test_state),
        early_stopping_criteria_met: check_early_stopping_criteria(test_state)
      }
    end

    def generate_performance_insights(test_state, performance_analysis)
      insights = []

      # Performance spread insight
      spread = performance_analysis[:performance_spread]
      if spread > 1.0
        insights << {
          type: "performance_variation",
          description: "High performance variation detected (#{spread.round(2)}% spread)",
          actionable_advice: "Consider reallocating traffic to better performing variants",
          priority: "high"
        }
      end

      # Sample size insights
      total_traffic = performance_analysis[:total_traffic]
      if total_traffic < 1000
        insights << {
          type: "sample_size",
          description: "Low sample size may affect result reliability",
          actionable_advice: "Consider extending test duration or increasing traffic",
          priority: "medium"
        }
      end

      # Statistical significance insight
      if !performance_analysis[:statistical_significance]
        insights << {
          type: "statistical_significance",
          description: "Test has not yet reached statistical significance",
          actionable_advice: "Continue test or consider increasing effect size",
          priority: "medium"
        }
      end

      insights
    end

    def calculate_performance_spread(variants)
      rates = variants.map { |v| v[:conversion_rate] || 0 }
      return 0 if rates.empty?

      rates.max - rates.min
    end

    def assess_statistical_significance(variants)
      # Simplified significance check
      return false if variants.length < 2

      rates = variants.map { |v| v[:conversion_rate] || 0 }
      visitors = variants.map { |v| v[:visitors] || 0 }

      # Check if sample sizes are adequate and there's meaningful difference
      min_visitors = visitors.min
      rate_difference = rates.max - rates.min

      min_visitors >= 100 && rate_difference >= 1.0
    end

    def calculate_performance_weighted_allocation(variants)
      total_performance = variants.sum { |v| v[:conversion_rate] || 0 }
      return {} if total_performance == 0

      allocation = {}
      variants.each do |variant|
        performance_weight = (variant[:conversion_rate] || 0) / total_performance
        allocation[variant[:id]] = (performance_weight * 100).round(1)
      end

      allocation
    end

    def estimate_improvement_from_reallocation(variants, new_allocation)
      current_weighted_rate = variants.sum do |variant|
        current_traffic = 100.0 / variants.length  # Assume equal allocation currently
        (variant[:conversion_rate] || 0) * (current_traffic / 100.0)
      end

      new_weighted_rate = variants.sum do |variant|
        new_traffic = new_allocation[variant[:id]] || 0
        (variant[:conversion_rate] || 0) * (new_traffic / 100.0)
      end

      improvement = ((new_weighted_rate - current_weighted_rate) / current_weighted_rate * 100).round(2)
      [ improvement, 0 ].max
    end

    def estimate_days_to_power(test_state)
      current_power = test_state[:statistical_power] || 0
      target_power = 0.8

      return 0 if current_power >= target_power

      days_running = test_state[:days_running] || 1

      # Estimate additional days needed (simplified)
      power_ratio = target_power / [ current_power, 0.1 ].max
      additional_days = (days_running * (power_ratio - 1)).ceil

      [ additional_days, 0 ].max
    end

    def has_clear_winner?(test_state)
      variants = test_state[:variants] || []
      return false if variants.length < 2

      sorted_variants = variants.sort_by { |v| v[:conversion_rate] || 0 }.reverse
      best = sorted_variants.first
      second_best = sorted_variants[1]

      # Consider clear winner if best is significantly better than second best
      best_rate = best[:conversion_rate] || 0
      second_rate = second_best[:conversion_rate] || 0

      return false if second_rate == 0

      improvement = (best_rate - second_rate) / second_rate
      improvement > 0.15  # 15% improvement threshold
    end

    def calculate_trend_direction(variant)
      # Simplified trend calculation
      current_rate = variant[:conversion_rate] || 0

      if current_rate > 3.0
        "improving"
      elsif current_rate < 1.0
        "declining"
      else
        "stable"
      end
    end

    def calculate_performance_stability(variant)
      # Simplified stability assessment
      visitors = variant[:visitors] || 0

      case visitors
      when 0..100 then "low"
      when 101..500 then "medium"
      else "high"
      end
    end

    def calculate_confidence_level(variant)
      visitors = variant[:visitors] || 0
      conversions = variant[:conversions] || 0

      return 0 if visitors == 0

      # Simplified confidence calculation
      sample_confidence = [ visitors / 1000.0, 1.0 ].min
      conversion_adequacy = conversions >= 10 ? 1.0 : conversions / 10.0

      (sample_confidence * conversion_adequacy * 100).round(1)
    end

    def assess_sample_adequacy(variant)
      visitors = variant[:visitors] || 0
      conversions = variant[:conversions] || 0

      if visitors >= 1000 && conversions >= 20
        "adequate"
      elsif visitors >= 500 && conversions >= 10
        "marginal"
      else
        "inadequate"
      end
    end

    def project_final_conversion_rate(variant)
      current_rate = variant[:conversion_rate] || 0
      visitors = variant[:visitors] || 0

      # Simple projection based on current performance and sample size
      if visitors < 100
        # High uncertainty
        current_rate * (0.8..1.2).to_a.sample
      else
        # More stable projection
        current_rate * (0.95..1.05).to_a.sample
      end
    end

    def calculate_optimal_allocation(variants)
      # Thompson Sampling-like allocation
      total_score = variants.sum do |variant|
        rate = variant[:conversion_rate] || 0
        visitors = variant[:visitors] || 1
        # Higher rate and more confidence (visitors) = higher score
        rate * Math.sqrt(visitors)
      end

      return {} if total_score == 0

      allocation = {}
      variants.each do |variant|
        rate = variant[:conversion_rate] || 0
        visitors = variant[:visitors] || 1
        score = rate * Math.sqrt(visitors)
        allocation[variant[:id]] = (score / total_score * 100).round(1)
      end

      allocation
    end

    def calculate_optimization_score(test_state)
      score = 100.0

      # Penalize for poor traffic allocation
      if test_state[:traffic_allocation]
        allocation_efficiency = assess_allocation_efficiency(test_state)
        score -= (1 - allocation_efficiency) * 30
      end

      # Penalize for inadequate sample size
      total_visitors = test_state[:variants]&.sum { |v| v[:visitors] || 0 } || 0
      if total_visitors < 1000
        score -= 20
      end

      # Penalize for low statistical power
      power = test_state[:statistical_power] || 0
      if power < 0.8
        score -= (0.8 - power) * 50
      end

      [ score, 0 ].max.round(1)
    end

    def generate_next_actions(test_state, performance_analysis)
      actions = []

      # Sample size action
      if performance_analysis[:total_traffic] < 1000
        actions << "Increase traffic to reach minimum sample size"
      end

      # Statistical significance action
      unless performance_analysis[:statistical_significance]
        actions << "Continue test to achieve statistical significance"
      end

      # Traffic reallocation action
      if performance_analysis[:performance_spread] > 1.0
        actions << "Consider reallocating traffic to better performing variants"
      end

      actions
    end

    def determine_duration_action(days_running, statistical_power)
      if statistical_power >= 0.9
        "consider_stopping"
      elsif statistical_power >= 0.8 && days_running >= 14
        "continue_monitoring"
      elsif days_running >= 30
        "extend_or_redesign"
      else
        "continue"
      end
    end

    def generate_duration_reasoning(days_running, statistical_power)
      if statistical_power >= 0.9
        "Test has achieved high statistical power"
      elsif statistical_power < 0.6
        "Test needs more time to reach adequate statistical power"
      elsif days_running < 7
        "Test is still in early stages"
      else
        "Test is progressing normally"
      end
    end

    def calculate_optimal_duration(test_state)
      current_visitors_per_day = calculate_daily_visitor_rate(test_state)
      required_sample_size = 2000  # Target sample size

      return 14 if current_visitors_per_day == 0

      optimal_days = (required_sample_size / current_visitors_per_day).ceil
      [ optimal_days, 7 ].max  # Minimum 7 days
    end

    def check_early_stopping_criteria(test_state)
      statistical_power = test_state[:statistical_power] || 0
      days_running = test_state[:days_running] || 0

      {
        power_threshold_met: statistical_power >= 0.9,
        minimum_duration_met: days_running >= 7,
        clear_winner_exists: has_clear_winner?(test_state),
        early_stop_recommended: statistical_power >= 0.9 && days_running >= 7 && has_clear_winner?(test_state)
      }
    end

    def assess_allocation_efficiency(test_state)
      # Measure how well traffic allocation matches performance
      variants = test_state[:variants] || []
      allocation = test_state[:traffic_allocation] || {}

      return 1.0 if variants.empty?

      # Calculate correlation between performance and allocation
      performances = variants.map { |v| v[:conversion_rate] || 0 }
      allocations = variants.map { |v| allocation[v[:id]] || 0 }

      # Simplified correlation (positive = good allocation)
      performance_rank = performances.each_with_index.sort_by(&:first).map(&:last)
      allocation_rank = allocations.each_with_index.sort_by(&:first).map(&:last)

      # Calculate rank correlation (simplified)
      rank_diff = performance_rank.zip(allocation_rank).map { |p, a| (p - a).abs }
      avg_rank_diff = rank_diff.sum.to_f / rank_diff.length
      max_possible_diff = variants.length - 1

      return 1.0 if max_possible_diff == 0

      1.0 - (avg_rank_diff / max_possible_diff)
    end

    def calculate_daily_visitor_rate(test_state)
      total_visitors = test_state[:variants]&.sum { |v| v[:visitors] || 0 } || 0
      days_running = test_state[:days_running] || 1

      total_visitors.to_f / days_running
    end
  end
end
