module AbTesting
  class AbTestWinnerDeclarator
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def declare_winner(final_results)
      variants = final_results[:variants]
      confidence_level = final_results[:confidence_level] || 95.0
      minimum_lift_threshold = final_results[:minimum_lift_threshold] || 0.10

      # Perform comprehensive analysis
      statistical_analysis = perform_statistical_analysis(variants)
      validation_checks = perform_validation_checks(final_results)

      # Determine if we have a clear winner
      winner_analysis = determine_winner(variants, statistical_analysis, minimum_lift_threshold)

      result = {
        has_winner: winner_analysis[:has_winner],
        statistical_significance: statistical_analysis[:is_significant],
        practical_significance: winner_analysis[:practical_significance],
        validation_checks: validation_checks
      }

      if winner_analysis[:has_winner]
        result.merge!({
          winner_variant_id: winner_analysis[:winner][:id],
          winner_variant_name: winner_analysis[:winner][:name] || winner_analysis[:winner][:id],
          lift_percentage: winner_analysis[:lift_percentage],
          confidence_interval: winner_analysis[:confidence_interval],
          winner_conversion_rate: winner_analysis[:winner_conversion_rate],
          control_conversion_rate: winner_analysis[:control_conversion_rate]
        })
      else
        result[:inconclusive_reasons] = winner_analysis[:reasons]
      end

      result
    end

    def validate_winner_criteria(results)
      criteria_checks = {}

      # Statistical significance check
      criteria_checks[:statistical_significance] = {
        passed: results[:statistical_significance] || false,
        description: "Test achieved statistical significance"
      }

      # Practical significance check
      criteria_checks[:practical_significance] = {
        passed: results[:practical_significance] || false,
        description: "Effect size meets minimum practical threshold"
      }

      # Sample size adequacy
      total_visitors = results[:variants]&.sum { |v| v[:visitors] } || 0
      criteria_checks[:sample_size_adequacy] = {
        passed: total_visitors >= 1000,
        description: "Adequate sample size for reliable results",
        actual_value: total_visitors,
        threshold: 1000
      }

      # Test duration
      test_duration = results[:test_duration_days] || 0
      criteria_checks[:test_duration] = {
        passed: test_duration >= 7,
        description: "Test ran for minimum duration",
        actual_value: test_duration,
        threshold: 7
      }

      criteria_checks
    end

    def assess_practical_significance(control_rate, winner_rate, minimum_threshold)
      return false if control_rate == 0

      lift = (winner_rate - control_rate) / control_rate

      {
        has_practical_significance: lift.abs >= minimum_threshold,
        lift_percentage: (lift * 100).round(2),
        minimum_threshold_percentage: (minimum_threshold * 100).round(2),
        meets_threshold: lift.abs >= minimum_threshold
      }
    end

    def evaluate_external_validity(results)
      # Assess how generalizable the results are
      validity_score = 100.0
      validity_issues = []

      # Check sample representativeness
      total_sample = results[:variants]&.sum { |v| v[:visitors] } || 0
      if total_sample < 500
        validity_score -= 20
        validity_issues << "Small sample size may limit generalizability"
      end

      # Check test duration for seasonal effects
      test_duration = results[:test_duration_days] || 0
      if test_duration < 14
        validity_score -= 15
        validity_issues << "Short test duration may not account for weekly patterns"
      end

      # Check for outlier performance
      if results[:variants]
        conversion_rates = results[:variants].map { |v| v[:conversions].to_f / [ v[:visitors], 1 ].max }
        if conversion_rates.any? { |rate| rate > 0.5 }  # Unusually high conversion
          validity_score -= 10
          validity_issues << "Unusually high conversion rates may indicate external factors"
        end
      end

      {
        score: [ validity_score, 0 ].max.round(1),
        issues: validity_issues,
        grade: validity_grade(validity_score)
      }
    end

    private

    def perform_statistical_analysis(variants)
      return { is_significant: false, p_value: 1.0 } if variants.length < 2

      # Find control and best treatment
      control = variants.find { |v| v[:id] == "control" } || variants.first
      treatments = variants.reject { |v| v[:id] == "control" || v == control }

      return { is_significant: false, p_value: 1.0 } if treatments.empty?

      # Test control vs best treatment
      best_treatment = treatments.max_by { |v| v[:conversions].to_f / [ v[:visitors], 1 ].max }

      # Two-proportion z-test
      n1, x1 = control[:visitors], control[:conversions]
      n2, x2 = best_treatment[:visitors], best_treatment[:conversions]

      return { is_significant: false, p_value: 1.0 } if n1 == 0 || n2 == 0

      p1 = x1.to_f / n1
      p2 = x2.to_f / n2
      p_pool = (x1 + x2).to_f / (n1 + n2)

      se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/n1 + 1.0/n2))
      return { is_significant: false, p_value: 1.0 } if se == 0

      z = (p2 - p1) / se
      p_value = 2 * (1 - standard_normal_cdf(z.abs))

      {
        is_significant: p_value < 0.05,
        p_value: p_value.round(6),
        z_score: z.round(4),
        control_rate: (p1 * 100).round(2),
        treatment_rate: (p2 * 100).round(2)
      }
    end

    def perform_validation_checks(results)
      checks = {}

      # Sample size adequacy
      total_visitors = results[:variants]&.sum { |v| v[:visitors] } || 0
      checks[:sample_size_adequate] = total_visitors >= 1000

      # Test duration sufficiency
      test_duration = results[:test_duration_days] || 0
      checks[:test_duration_sufficient] = test_duration >= 7

      # External validity assessment
      external_validity = evaluate_external_validity(results)
      checks[:external_validity_score] = external_validity[:score]

      # Data quality checks
      checks[:data_quality_sufficient] = validate_data_quality(results[:variants])

      checks
    end

    def determine_winner(variants, statistical_analysis, minimum_lift_threshold)
      return { has_winner: false, reasons: [ "Insufficient variants" ] } if variants.length < 2

      # Find control and treatments
      control = variants.find { |v| v[:id] == "control" } || variants.first
      treatments = variants.reject { |v| v[:id] == "control" || v == control }

      return { has_winner: false, reasons: [ "No treatment variants" ] } if treatments.empty?

      # Find best performing treatment
      best_treatment = treatments.max_by { |v| v[:conversions].to_f / [ v[:visitors], 1 ].max }

      control_rate = control[:conversions].to_f / [ control[:visitors], 1 ].max
      winner_rate = best_treatment[:conversions].to_f / [ best_treatment[:visitors], 1 ].max

      # Check practical significance
      practical_sig = assess_practical_significance(control_rate, winner_rate, minimum_lift_threshold)

      # Determine if we have a winner
      reasons = []

      unless statistical_analysis[:is_significant]
        reasons << "No statistical significance achieved"
      end

      unless practical_sig[:has_practical_significance]
        reasons << "Effect size below minimum threshold (#{practical_sig[:minimum_threshold_percentage]}%)"
      end

      if winner_rate <= control_rate
        reasons << "No treatment outperformed control"
      end

      has_winner = reasons.empty?

      result = {
        has_winner: has_winner,
        reasons: reasons,
        practical_significance: practical_sig[:has_practical_significance]
      }

      if has_winner
        # Calculate confidence interval for the lift
        confidence_interval = calculate_lift_confidence_interval(control, best_treatment)

        result.merge!({
          winner: best_treatment,
          lift_percentage: practical_sig[:lift_percentage],
          confidence_interval: confidence_interval,
          winner_conversion_rate: (winner_rate * 100).round(2),
          control_conversion_rate: (control_rate * 100).round(2)
        })
      end

      result
    end

    def calculate_lift_confidence_interval(control, treatment)
      n1, x1 = control[:visitors], control[:conversions]
      n2, x2 = treatment[:visitors], treatment[:conversions]

      return { lower: 0, upper: 0 } if n1 == 0 || n2 == 0

      p1 = x1.to_f / n1
      p2 = x2.to_f / n2

      return { lower: 0, upper: 0 } if p1 == 0

      # Confidence interval for relative risk (lift + 1)
      log_rr = Math.log(p2 / p1) rescue 0
      se_log_rr = Math.sqrt((1 - p1)/(x1 * p1) + (1 - p2)/(x2 * p2)) rescue 0

      margin = 1.96 * se_log_rr
      lower_rr = Math.exp(log_rr - margin)
      upper_rr = Math.exp(log_rr + margin)

      {
        lower: ((lower_rr - 1) * 100).round(2),
        upper: ((upper_rr - 1) * 100).round(2)
      }
    end

    def validate_data_quality(variants)
      return false unless variants&.any?

      variants.all? do |variant|
        visitors = variant[:visitors] || 0
        conversions = variant[:conversions] || 0

        # Basic data quality checks
        visitors >= 0 &&
        conversions >= 0 &&
        conversions <= visitors
      end
    end

    def validity_grade(score)
      case score
      when 90..100 then "A"
      when 80..89 then "B"
      when 70..79 then "C"
      when 60..69 then "D"
      else "F"
      end
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
