module AbTesting
  class AbTestAiRecommender
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def generate_recommendations(historical_context)
      # Analyze historical patterns
      patterns = analyze_historical_patterns(historical_context)

      # Generate variant suggestions
      suggested_variations = generate_variation_suggestions(historical_context, patterns)

      # Calculate statistical recommendations
      statistical_recs = generate_statistical_recommendations(historical_context)

      # Predict success probability
      success_prob = predict_success_probability(historical_context, patterns)

      {
        suggested_variations: suggested_variations,
        statistical_recommendations: statistical_recs,
        success_probability: success_prob,
        confidence_score: calculate_recommendation_confidence(patterns),
        historical_insights: patterns
      }
    end

    def analyze_historical_patterns(context)
      previous_results = context[:previous_test_results] || []

      patterns = {
        successful_variation_types: [],
        average_lift_by_type: {},
        confidence_trends: {},
        industry_benchmarks: calculate_industry_benchmarks(context[:industry])
      }

      # Analyze previous test results
      variation_performance = {}
      previous_results.each do |result|
        type = result[:variation_type]
        lift = result[:winner_lift] || 0
        confidence = result[:confidence] || 0

        variation_performance[type] ||= { lifts: [], confidences: [] }
        variation_performance[type][:lifts] << lift
        variation_performance[type][:confidences] << confidence
      end

      # Calculate averages and identify successful patterns
      variation_performance.each do |type, data|
        avg_lift = data[:lifts].sum / data[:lifts].length
        avg_confidence = data[:confidences].sum / data[:confidences].length

        patterns[:average_lift_by_type][type] = avg_lift.round(2)
        patterns[:confidence_trends][type] = avg_confidence.round(2)

        # Consider successful if average lift > 10% and confidence > 80%
        if avg_lift > 10 && avg_confidence > 80
          patterns[:successful_variation_types] << type
        end
      end

      patterns
    end

    def predict_test_outcomes(test_parameters)
      campaign_context = test_parameters[:campaign_context] || {}
      test_design = test_parameters[:test_design] || {}
      baseline_metrics = test_parameters[:baseline_metrics] || {}

      # Calculate success probability based on context
      base_probability = calculate_base_success_probability(campaign_context)

      # Adjust for test design factors
      design_adjustment = calculate_design_adjustment(test_design)

      # Adjust for baseline metrics
      baseline_adjustment = calculate_baseline_adjustment(baseline_metrics)

      final_probability = [ base_probability * design_adjustment * baseline_adjustment, 0.95 ].min

      {
        success_probability: final_probability.round(3),
        predicted_results: generate_predicted_results(test_parameters, final_probability),
        risk_factors: identify_risk_factors(test_parameters),
        optimization_opportunities: identify_optimization_opportunities(test_parameters)
      }
    end

    def suggest_optimal_configurations(context)
      industry = context[:industry] || "technology"
      campaign_type = context[:campaign_type] || "conversion"

      configurations = {
        recommended_sample_size: calculate_optimal_sample_size(context),
        recommended_duration: calculate_optimal_duration(context),
        recommended_confidence_level: 95.0,
        recommended_traffic_split: calculate_optimal_traffic_split(context),
        early_stopping_rules: generate_early_stopping_recommendations(context)
      }

      configurations
    end

    private

    def generate_variation_suggestions(context, patterns)
      suggestions = []

      # Based on successful historical patterns
      patterns[:successful_variation_types].each do |type|
        avg_lift = patterns[:average_lift_by_type][type] || 0
        confidence = patterns[:confidence_trends][type] || 0

        suggestions << {
          type: type,
          description: generate_variation_description(type),
          predicted_lift: avg_lift,
          confidence_score: (confidence / 100.0).round(2),
          implementation_difficulty: assess_implementation_difficulty(type),
          historical_success_rate: calculate_historical_success_rate(type, patterns)
        }
      end

      # Add industry-standard variations if none from history
      if suggestions.empty?
        suggestions = generate_default_variations(context)
      end

      suggestions.sort_by { |s| -s[:confidence_score] }.take(5)
    end

    def generate_statistical_recommendations(context)
      baseline_rate = context[:baseline_conversion_rate] || 0.03
      traffic_volume = context[:expected_daily_traffic] || 1000

      {
        recommended_sample_size: calculate_sample_size_recommendation(baseline_rate),
        estimated_test_duration: calculate_duration_recommendation(baseline_rate, traffic_volume),
        minimum_detectable_effect: calculate_mde_recommendation(baseline_rate),
        statistical_power: 0.8,
        recommended_confidence_level: 95.0
      }
    end

    def predict_success_probability(context, patterns)
      # Base probability from industry/campaign type
      base_prob = 0.4

      # Adjust based on historical success rate
      if patterns[:successful_variation_types].any?
        historical_success_rate = patterns[:successful_variation_types].length / 5.0  # Assume max 5 types
        base_prob += (historical_success_rate * 0.3)
      end

      # Adjust based on campaign maturity
      if context[:previous_test_results]&.length&.> 3
        base_prob += 0.2  # More experience = higher success probability
      end

      [ base_prob, 0.9 ].min.round(3)
    end

    def calculate_recommendation_confidence(patterns)
      # Confidence based on amount of historical data
      historical_tests = patterns[:successful_variation_types].length

      case historical_tests
      when 0 then 0.3
      when 1..2 then 0.5
      when 3..5 then 0.7
      else 0.9
      end
    end

    def calculate_industry_benchmarks(industry)
      benchmarks = {
        "technology" => { avg_conversion_rate: 0.025, typical_lift: 0.15 },
        "ecommerce" => { avg_conversion_rate: 0.032, typical_lift: 0.12 },
        "saas" => { avg_conversion_rate: 0.018, typical_lift: 0.20 },
        "finance" => { avg_conversion_rate: 0.015, typical_lift: 0.18 }
      }

      benchmarks[industry] || benchmarks["technology"]
    end

    def generate_variation_description(type)
      descriptions = {
        "headline" => "Test different headline approaches focusing on benefits vs features",
        "cta_color" => "Experiment with call-to-action button colors and contrast",
        "social_proof" => "Add testimonials, reviews, or usage statistics",
        "urgency_messaging" => "Include time-sensitive language and scarcity indicators",
        "visual_design" => "Test different layouts, images, and visual hierarchy",
        "value_proposition" => "Clarify and strengthen the main value proposition"
      }

      descriptions[type] || "Test #{type.humanize.downcase} variations"
    end

    def assess_implementation_difficulty(type)
      difficulty_map = {
        "headline" => "low",
        "cta_color" => "low",
        "social_proof" => "medium",
        "urgency_messaging" => "low",
        "visual_design" => "high",
        "value_proposition" => "medium"
      }

      difficulty_map[type] || "medium"
    end

    def calculate_historical_success_rate(type, patterns)
      # Simplified success rate calculation
      if patterns[:average_lift_by_type][type] && patterns[:average_lift_by_type][type] > 10
        0.75
      else
        0.45
      end
    end

    def generate_default_variations(context)
      [
        {
          type: "headline",
          description: "Test benefit-focused vs feature-focused headlines",
          predicted_lift: 12.0,
          confidence_score: 0.6,
          implementation_difficulty: "low",
          historical_success_rate: 0.65
        },
        {
          type: "cta_color",
          description: "Test high-contrast button colors",
          predicted_lift: 8.0,
          confidence_score: 0.7,
          implementation_difficulty: "low",
          historical_success_rate: 0.55
        },
        {
          type: "social_proof",
          description: "Add customer testimonials or usage stats",
          predicted_lift: 15.0,
          confidence_score: 0.8,
          implementation_difficulty: "medium",
          historical_success_rate: 0.72
        }
      ]
    end

    def calculate_base_success_probability(context)
      industry = context[:type] || "technology"
      budget = context[:budget] || 10000

      base_prob = case industry
      when "technology" then 0.45
      when "ecommerce" then 0.52
      when "saas" then 0.38
      else 0.42
      end

      # Adjust for budget (more budget = better implementation)
      budget_multiplier = case budget
      when 0..5000 then 0.9
      when 5001..15000 then 1.0
      when 15001..50000 then 1.1
      else 1.2
      end

      base_prob * budget_multiplier
    end

    def calculate_design_adjustment(test_design)
      variant_count = test_design[:variant_count] || 2
      duration = test_design[:planned_duration] || 14

      # More variants = slightly lower success probability due to complexity
      variant_adjustment = case variant_count
      when 2 then 1.0
      when 3 then 0.95
      when 4..5 then 0.9
      else 0.85
      end

      # Longer tests = higher success probability
      duration_adjustment = case duration
      when 1..7 then 0.8
      when 8..14 then 1.0
      when 15..30 then 1.1
      else 1.0
      end

      variant_adjustment * duration_adjustment
    end

    def calculate_baseline_adjustment(baseline_metrics)
      current_rate = baseline_metrics[:current_conversion_rate] || 0.025
      traffic = baseline_metrics[:current_traffic_volume] || 1000

      # Higher baseline rates are harder to improve significantly
      rate_adjustment = case current_rate
      when 0..0.01 then 1.2
      when 0.011..0.025 then 1.0
      when 0.026..0.05 then 0.9
      else 0.8
      end

      # Higher traffic = more reliable results
      traffic_adjustment = case traffic
      when 0..500 then 0.9
      when 501..2000 then 1.0
      when 2001..10000 then 1.1
      else 1.2
      end

      rate_adjustment * traffic_adjustment
    end

    def generate_predicted_results(test_parameters, success_probability)
      baseline_rate = test_parameters.dig(:baseline_metrics, :current_conversion_rate) || 0.025

      if success_probability > 0.7
        expected_lift = (0.15..0.25)
      elsif success_probability > 0.5
        expected_lift = (0.08..0.18)
      else
        expected_lift = (0.02..0.12)
      end

      {
        expected_lift_range: {
          min: (expected_lift.min * 100).round(1),
          max: (expected_lift.max * 100).round(1)
        },
        confidence_interval: [ 85, 95 ],
        expected_statistical_power: 0.8
      }
    end

    def identify_risk_factors(test_parameters)
      risks = []

      traffic = test_parameters.dig(:baseline_metrics, :current_traffic_volume) || 0
      if traffic < 500
        risks << {
          factor: "Low traffic volume",
          impact_level: "high",
          mitigation_suggestion: "Consider extending test duration or increasing traffic sources"
        }
      end

      baseline_rate = test_parameters.dig(:baseline_metrics, :current_conversion_rate) || 0
      if baseline_rate > 0.1
        risks << {
          factor: "High baseline conversion rate",
          impact_level: "medium",
          mitigation_suggestion: "Focus on incremental improvements and larger sample sizes"
        }
      end

      risks
    end

    def identify_optimization_opportunities(test_parameters)
      opportunities = []

      variant_count = test_parameters.dig(:test_design, :variant_count) || 2
      if variant_count == 2
        opportunities << "Consider testing multiple treatments simultaneously"
      end

      mde = test_parameters.dig(:test_design, :minimum_detectable_effect) || 0.2
      if mde > 0.15
        opportunities << "Lower MDE threshold to detect smaller but meaningful effects"
      end

      opportunities
    end

    def calculate_optimal_sample_size(context)
      baseline_rate = context[:baseline_conversion_rate] || 0.025
      mde = 0.15  # 15% relative improvement

      # Simplified sample size calculation
      effect_size = baseline_rate * mde
      sample_per_variant = (2 * (1.96 + 0.84)**2 * baseline_rate * (1 - baseline_rate)) / (effect_size**2)

      (sample_per_variant * 2).round
    end

    def calculate_optimal_duration(context)
      traffic = context[:expected_daily_traffic] || 1000
      sample_size = calculate_optimal_sample_size(context)

      (sample_size / traffic).ceil
    end

    def calculate_optimal_traffic_split(context)
      variant_count = context[:variant_count] || 2
      equal_split = 100.0 / variant_count

      # For now, recommend equal split
      (1..variant_count).map { |i| { "variant_#{i}" => equal_split.round(1) } }
    end

    def generate_early_stopping_recommendations(context)
      {
        enable_early_stopping: true,
        minimum_sample_size: 1000,
        futility_threshold: 0.1,
        efficacy_threshold: 0.001
      }
    end

    def calculate_sample_size_recommendation(baseline_rate)
      # Rule of thumb: need enough sample to detect 15% relative improvement
      effect_size = baseline_rate * 0.15
      (16 * baseline_rate * (1 - baseline_rate) / (effect_size**2)).round
    end

    def calculate_duration_recommendation(baseline_rate, traffic)
      sample_size = calculate_sample_size_recommendation(baseline_rate)
      (sample_size / traffic).ceil
    end

    def calculate_mde_recommendation(baseline_rate)
      # Recommend detecting 10-20% relative improvements
      relative_mde = 0.15
      (baseline_rate * relative_mde * 100).round(1)
    end
  end
end
