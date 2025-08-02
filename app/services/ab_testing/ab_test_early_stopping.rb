module AbTesting
  class AbTestEarlyStopping
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def evaluate_stopping_condition(stopping_rules, current_data)
      analysis_stage = determine_analysis_stage(stopping_rules, current_data)
      efficacy_boundary = calculate_efficacy_boundary(stopping_rules, analysis_stage)
      futility_boundary = calculate_futility_boundary(stopping_rules, analysis_stage)

      # Calculate current test statistic
      test_statistic = calculate_current_test_statistic(current_data)

      decision = determine_stopping_decision(test_statistic, efficacy_boundary, futility_boundary)

      result = {
        decision: decision,
        analysis_stage: analysis_stage,
        efficacy_boundary: efficacy_boundary,
        futility_boundary: futility_boundary,
        current_test_statistic: test_statistic
      }

      if decision == "stop_for_efficacy"
        result[:winner] = determine_winner(current_data)
        result[:final_p_value] = calculate_final_p_value(test_statistic)
      end

      result
    end

    def calculate_efficacy_boundary(stopping_rules, analysis_stage)
      function_type = stopping_rules[:alpha_spending_function] || "obrien_fleming"

      case function_type
      when "obrien_fleming"
        calculate_obrien_fleming_boundary(analysis_stage)
      when "pocock"
        calculate_pocock_boundary(analysis_stage)
      else
        2.5 # Default boundary
      end
    end

    def calculate_futility_boundary(stopping_rules, analysis_stage)
      boundary_type = stopping_rules[:futility_boundary] || "stochastic_curtailment"

      case boundary_type
      when "stochastic_curtailment"
        calculate_stochastic_curtailment_boundary(analysis_stage)
      when "conditional_power"
        calculate_conditional_power_boundary(analysis_stage)
      else
        0.5 # Default boundary
      end
    end

    def determine_analysis_stage(stopping_rules, current_data)
      total_sample_size = current_data.values.sum { |v| v[:visitors] }
      max_sample_size = stopping_rules[:maximum_sample_size] || 10000

      progress = total_sample_size.to_f / max_sample_size

      # Find which interim analysis stage we're in
      schedule = stopping_rules[:interim_analysis_schedule] || [ 0.25, 0.5, 0.75, 1.0 ]

      schedule.each_with_index do |fraction, index|
        return index + 1 if progress <= fraction
      end

      schedule.length # Final analysis
    end

    private

    def calculate_current_test_statistic(current_data)
      return 0 if current_data.keys.length < 2

      control_key = current_data.keys.first
      treatment_key = current_data.keys.last

      control = current_data[control_key]
      treatment = current_data[treatment_key]

      # Calculate z-statistic for proportion difference
      n1, x1 = control[:visitors], control[:conversions]
      n2, x2 = treatment[:visitors], treatment[:conversions]

      return 0 if n1 == 0 || n2 == 0

      p1 = x1.to_f / n1
      p2 = x2.to_f / n2
      p_pool = (x1 + x2).to_f / (n1 + n2)

      se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/n1 + 1.0/n2))
      return 0 if se == 0

      (p2 - p1) / se
    end

    def calculate_obrien_fleming_boundary(stage)
      # O'Brien-Fleming spending function creates conservative early boundaries
      case stage
      when 1 then 4.56  # Very high boundary for early stopping
      when 2 then 3.23
      when 3 then 2.63
      when 4 then 2.28
      else 1.96  # Final analysis
      end
    end

    def calculate_pocock_boundary(stage)
      # Pocock boundaries are constant across stages
      2.50  # Constant boundary
    end

    def calculate_stochastic_curtailment_boundary(stage)
      # Futility boundary that increases over time
      case stage
      when 1 then -0.5
      when 2 then -0.3
      when 3 then -0.1
      else 0.0
      end
    end

    def calculate_conditional_power_boundary(stage)
      # Conditional power-based futility boundary
      case stage
      when 1 then -1.0
      when 2 then -0.7
      when 3 then -0.3
      else 0.0
      end
    end

    def determine_stopping_decision(test_statistic, efficacy_boundary, futility_boundary)
      if test_statistic.abs >= efficacy_boundary
        "stop_for_efficacy"
      elsif test_statistic <= futility_boundary
        "stop_for_futility"
      else
        "continue"
      end
    end

    def determine_winner(current_data)
      return nil if current_data.keys.length < 2

      # Find variant with highest conversion rate
      best_variant = current_data.max_by do |variant_key, data|
        data[:conversions].to_f / [ data[:visitors], 1 ].max
      end

      best_variant[0] if best_variant
    end

    def calculate_final_p_value(test_statistic)
      # Two-sided p-value
      2 * (1 - standard_normal_cdf(test_statistic.abs))
    end

    def standard_normal_cdf(x)
      0.5 * (1 + erf(x / Math.sqrt(2)))
    end

    def erf(x)
      # Error function approximation
      a1 =  0.254829592
      a2 = -0.284496736
      a3 =  1.421413741
      a4 = -1.453152027
      a5 =  1.061405429
      p  =  0.3275911

      sign = x >= 0 ? 1 : -1
      x = x.abs

      t = 1.0 / (1.0 + p * x)
      y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-x * x)

      sign * y
    end
  end
end
