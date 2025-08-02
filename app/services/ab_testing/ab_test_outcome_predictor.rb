module AbTesting
  class AbTestOutcomePredictor
    def predict_test_outcome(test_parameters)
      campaign_context = test_parameters[:campaign_context] || {}
      test_design = test_parameters[:test_design] || {}
      baseline_metrics = test_parameters[:baseline_metrics] || {}

      # Calculate success probability
      success_probability = calculate_success_probability(test_parameters)

      # Generate predicted results
      predicted_results = generate_predicted_results(test_parameters, success_probability)

      # Identify risk factors
      risk_factors = identify_risk_factors(test_parameters)

      # Suggest optimization opportunities
      optimization_opportunities = suggest_optimization_opportunities(test_parameters)

      {
        success_probability: success_probability,
        predicted_results: predicted_results,
        risk_factors: risk_factors,
        optimization_opportunities: optimization_opportunities,
        recommendation_confidence: calculate_prediction_confidence(test_parameters),
        model_inputs: summarize_model_inputs(test_parameters)
      }
    end

    def calculate_success_probability(test_parameters)
      # Base probability factors
      industry_factor = calculate_industry_factor(test_parameters.dig(:campaign_context, :industry))
      budget_factor = calculate_budget_factor(test_parameters.dig(:campaign_context, :budget))
      audience_factor = calculate_audience_factor(test_parameters.dig(:campaign_context, :target_audience_size))

      # Test design factors
      variant_factor = calculate_variant_factor(test_parameters.dig(:test_design, :variant_count))
      duration_factor = calculate_duration_factor(test_parameters.dig(:test_design, :planned_duration))
      mde_factor = calculate_mde_factor(test_parameters.dig(:test_design, :minimum_detectable_effect))

      # Baseline performance factors
      baseline_factor = calculate_baseline_factor(test_parameters.dig(:baseline_metrics, :current_conversion_rate))
      traffic_factor = calculate_traffic_factor(test_parameters.dig(:baseline_metrics, :current_traffic_volume))
      seasonal_factor = calculate_seasonal_factor(test_parameters.dig(:baseline_metrics, :seasonal_factors))

      # Combine factors using weighted average
      success_probability = (
        industry_factor * 0.15 +
        budget_factor * 0.10 +
        audience_factor * 0.10 +
        variant_factor * 0.15 +
        duration_factor * 0.15 +
        mde_factor * 0.10 +
        baseline_factor * 0.15 +
        traffic_factor * 0.10
      ) * seasonal_factor

      # Ensure probability is between 0 and 1
      [ [ success_probability, 0.05 ].max, 0.95 ].min.round(3)
    end

    def identify_risk_factors(test_parameters)
      risks = []

      # Traffic volume risk
      traffic = test_parameters.dig(:baseline_metrics, :current_traffic_volume) || 0
      if traffic < 1000
        risks << {
          factor: "Low traffic volume",
          impact_level: traffic < 500 ? "high" : "medium",
          mitigation_suggestion: "Consider extending test duration or using external traffic sources",
          probability_impact: -0.15
        }
      end

      # High baseline conversion rate risk
      baseline_rate = test_parameters.dig(:baseline_metrics, :current_conversion_rate) || 0
      if baseline_rate > 0.1
        risks << {
          factor: "High baseline conversion rate",
          impact_level: "medium",
          mitigation_suggestion: "Focus on incremental improvements and ensure adequate sample sizes",
          probability_impact: -0.10
        }
      end

      # Short test duration risk
      duration = test_parameters.dig(:test_design, :planned_duration) || 0
      if duration < 7
        risks << {
          factor: "Short test duration",
          impact_level: "high",
          mitigation_suggestion: "Extend test to at least 7-14 days to account for weekly patterns",
          probability_impact: -0.20
        }
      end

      # Too many variants risk
      variant_count = test_parameters.dig(:test_design, :variant_count) || 2
      if variant_count > 4
        risks << {
          factor: "Too many test variants",
          impact_level: "medium",
          mitigation_suggestion: "Consider reducing variants or using sequential testing",
          probability_impact: -0.12
        }
      end

      # Small audience risk
      audience_size = test_parameters.dig(:campaign_context, :target_audience_size) || 10000
      if audience_size < 5000
        risks << {
          factor: "Small target audience",
          impact_level: "medium",
          mitigation_suggestion: "Expand targeting criteria or focus on higher-impact changes",
          probability_impact: -0.08
        }
      end

      # Seasonal timing risk
      seasonal_impact = test_parameters.dig(:baseline_metrics, :seasonal_factors, :holiday_impact) || 1.0
      if seasonal_impact < 0.8 || seasonal_impact > 1.3
        risks << {
          factor: "Seasonal timing effects",
          impact_level: "low",
          mitigation_suggestion: "Account for seasonal variations in analysis or adjust timing",
          probability_impact: -0.05
        }
      end

      risks
    end

    def suggest_optimization_opportunities(test_parameters)
      opportunities = []

      # Sample size optimization
      current_traffic = test_parameters.dig(:baseline_metrics, :current_traffic_volume) || 0
      if current_traffic > 2000
        opportunities << "Leverage high traffic volume for faster results or testing multiple variants"
      end

      # MDE optimization
      mde = test_parameters.dig(:test_design, :minimum_detectable_effect) || 0.15
      if mde > 0.2
        opportunities << "Consider lowering MDE threshold to detect smaller but meaningful improvements"
      end

      # Duration optimization
      duration = test_parameters.dig(:test_design, :planned_duration) || 14
      baseline_rate = test_parameters.dig(:baseline_metrics, :current_conversion_rate) || 0.025

      if duration > 21 && baseline_rate < 0.05
        opportunities << "Test duration could be optimized based on expected effect size and traffic"
      end

      # Budget optimization
      budget = test_parameters.dig(:campaign_context, :budget) || 0
      if budget > 20000
        opportunities << "High budget allows for comprehensive testing including design and copy variations"
      end

      # Audience segmentation opportunity
      audience_size = test_parameters.dig(:campaign_context, :target_audience_size) || 0
      if audience_size > 50000
        opportunities << "Large audience allows for audience-specific testing and personalization"
      end

      opportunities
    end

    private

    def calculate_industry_factor(industry)
      industry_success_rates = {
        "technology" => 0.45,
        "ecommerce" => 0.52,
        "saas" => 0.38,
        "finance" => 0.41,
        "healthcare" => 0.35,
        "education" => 0.48
      }

      industry_success_rates[industry] || 0.42
    end

    def calculate_budget_factor(budget)
      return 0.8 unless budget

      case budget
      when 0..5000 then 0.8
      when 5001..15000 then 0.9
      when 15001..30000 then 1.0
      when 30001..50000 then 1.1
      else 1.15
      end
    end

    def calculate_audience_factor(audience_size)
      return 0.9 unless audience_size

      case audience_size
      when 0..1000 then 0.7
      when 1001..5000 then 0.8
      when 5001..20000 then 0.9
      when 20001..50000 then 1.0
      when 50001..100000 then 1.05
      else 1.1
      end
    end

    def calculate_variant_factor(variant_count)
      return 1.0 unless variant_count

      case variant_count
      when 2 then 1.0
      when 3 then 0.95
      when 4 then 0.9
      when 5..6 then 0.85
      else 0.8
      end
    end

    def calculate_duration_factor(duration)
      return 0.9 unless duration

      case duration
      when 1..6 then 0.7
      when 7..14 then 1.0
      when 15..21 then 1.05
      when 22..30 then 1.0
      else 0.95  # Very long tests may have external validity issues
      end
    end

    def calculate_mde_factor(mde)
      return 1.0 unless mde

      # Lower MDE (more sensitive test) = higher success probability
      case mde
      when 0..0.05 then 1.2
      when 0.051..0.10 then 1.1
      when 0.101..0.15 then 1.0
      when 0.151..0.25 then 0.9
      else 0.8
      end
    end

    def calculate_baseline_factor(baseline_rate)
      return 0.95 unless baseline_rate

      # Higher baseline rates are harder to improve
      case baseline_rate
      when 0..0.01 then 1.1
      when 0.011..0.025 then 1.0
      when 0.026..0.05 then 0.95
      when 0.051..0.10 then 0.85
      else 0.75
      end
    end

    def calculate_traffic_factor(traffic_volume)
      return 0.8 unless traffic_volume

      case traffic_volume
      when 0..500 then 0.8
      when 501..1000 then 0.9
      when 1001..2000 then 1.0
      when 2001..5000 then 1.05
      else 1.1
      end
    end

    def calculate_seasonal_factor(seasonal_factors)
      return 1.0 unless seasonal_factors

      holiday_impact = seasonal_factors[:holiday_impact] || 1.0
      day_variance = seasonal_factors[:day_of_week_variance] || 0.05

      # Adjust for seasonal stability
      seasonal_stability = 1.0 - (day_variance * 2)  # High variance = lower stability
      holiday_adjustment = holiday_impact > 1.2 || holiday_impact < 0.8 ? 0.95 : 1.0

      seasonal_stability * holiday_adjustment
    end

    def generate_predicted_results(test_parameters, success_probability)
      baseline_rate = test_parameters.dig(:baseline_metrics, :current_conversion_rate) || 0.025

      # Predict lift range based on success probability
      if success_probability > 0.7
        lift_range = { min: 12.0, max: 30.0 }
        confidence_range = [ 88, 96 ]
        power_range = [ 0.85, 0.95 ]
      elsif success_probability > 0.5
        lift_range = { min: 6.0, max: 20.0 }
        confidence_range = [ 82, 92 ]
        power_range = [ 0.75, 0.88 ]
      elsif success_probability > 0.3
        lift_range = { min: 2.0, max: 12.0 }
        confidence_range = [ 75, 85 ]
        power_range = [ 0.65, 0.80 ]
      else
        lift_range = { min: 0.0, max: 8.0 }
        confidence_range = [ 65, 80 ]
        power_range = [ 0.50, 0.70 ]
      end

      {
        expected_lift_range: lift_range,
        confidence_interval: confidence_range,
        expected_statistical_power: power_range[1],
        predicted_winner_rate: baseline_rate * (1 + lift_range[:max] / 100.0),
        time_to_significance: estimate_time_to_significance(test_parameters, success_probability)
      }
    end

    def estimate_time_to_significance(test_parameters, success_probability)
      planned_duration = test_parameters.dig(:test_design, :planned_duration) || 14
      traffic = test_parameters.dig(:baseline_metrics, :current_traffic_volume) || 1000

      # Adjust based on success probability
      if success_probability > 0.8
        (planned_duration * 0.7).ceil
      elsif success_probability > 0.6
        (planned_duration * 0.85).ceil
      elsif success_probability > 0.4
        planned_duration
      else
        (planned_duration * 1.3).ceil
      end
    end

    def calculate_prediction_confidence(test_parameters)
      confidence_factors = []

      # Historical data availability (simulated)
      confidence_factors << 0.7  # Assume moderate historical data

      # Parameter completeness
      required_params = [ :campaign_context, :test_design, :baseline_metrics ]
      provided_params = required_params.count { |param| test_parameters[param].present? }
      param_completeness = provided_params.to_f / required_params.length
      confidence_factors << param_completeness

      # Traffic volume confidence
      traffic = test_parameters.dig(:baseline_metrics, :current_traffic_volume) || 0
      traffic_confidence = case traffic
      when 0..500 then 0.5
      when 501..2000 then 0.7
      when 2001..5000 then 0.8
      else 0.9
      end
      confidence_factors << traffic_confidence

      # Industry knowledge confidence
      industry = test_parameters.dig(:campaign_context, :industry)
      industry_confidence = industry ? 0.8 : 0.6
      confidence_factors << industry_confidence

      # Calculate weighted average confidence
      (confidence_factors.sum / confidence_factors.length).round(2)
    end

    def summarize_model_inputs(test_parameters)
      {
        campaign_factors: {
          industry: test_parameters.dig(:campaign_context, :industry) || "unknown",
          budget: test_parameters.dig(:campaign_context, :budget) || 0,
          audience_size: test_parameters.dig(:campaign_context, :target_audience_size) || 0
        },
        test_design_factors: {
          variant_count: test_parameters.dig(:test_design, :variant_count) || 2,
          duration: test_parameters.dig(:test_design, :planned_duration) || 14,
          mde: test_parameters.dig(:test_design, :minimum_detectable_effect) || 0.15
        },
        baseline_factors: {
          conversion_rate: test_parameters.dig(:baseline_metrics, :current_conversion_rate) || 0.025,
          traffic_volume: test_parameters.dig(:baseline_metrics, :current_traffic_volume) || 1000,
          seasonal_adjustment: test_parameters.dig(:baseline_metrics, :seasonal_factors) || {}
        }
      }
    end
  end
end
