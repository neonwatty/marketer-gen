module AbTesting
  class AbTestConfidenceCalculator
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def calculate_with_corrections(test_data)
      confidence_level = test_data[:confidence_level] || 0.95
      correction_methods = test_data[:correction_methods] || [ "bonferroni" ]
      variants = test_data[:variants] || []

      results = {}

      correction_methods.each do |method|
        results[method.to_sym] = case method
        when "bonferroni"
          apply_bonferroni_correction(variants, confidence_level)
        when "benjamini_hochberg"
          apply_benjamini_hochberg_correction(variants, confidence_level)
        when "holm"
          apply_holm_correction(variants, confidence_level)
        else
          { error: "Unknown correction method: #{method}" }
        end
      end

      results
    end

    def apply_bonferroni_correction(variants, confidence_level)
      return { pairwise_comparisons: [] } if variants.length < 2

      pairwise_comparisons = []
      control = variants.find { |v| v[:name] == "control" } || variants.first

      # Calculate number of comparisons
      num_comparisons = variants.length - 1
      adjusted_alpha = (1 - confidence_level) / num_comparisons

      variants.each do |variant|
        next if variant == control

        comparison = perform_pairwise_comparison(control, variant)
        adjusted_p_value = comparison[:p_value]

        pairwise_comparisons << {
          variant_a: control[:name],
          variant_b: variant[:name],
          p_value: comparison[:p_value],
          adjusted_p_value: adjusted_p_value,
          adjusted_alpha: adjusted_alpha,
          is_significant: adjusted_p_value < adjusted_alpha,
          confidence_interval: comparison[:confidence_interval],
          effect_size: comparison[:effect_size]
        }
      end

      { pairwise_comparisons: pairwise_comparisons, method: "bonferroni" }
    end

    def apply_benjamini_hochberg_correction(variants, confidence_level)
      return { pairwise_comparisons: [] } if variants.length < 2

      control = variants.find { |v| v[:name] == "control" } || variants.first
      comparisons = []

      # Perform all pairwise comparisons
      variants.each do |variant|
        next if variant == control
        comparisons << {
          variant: variant,
          comparison: perform_pairwise_comparison(control, variant)
        }
      end

      # Sort by p-value
      comparisons.sort_by! { |c| c[:comparison][:p_value] }

      # Apply BH procedure
      alpha = 1 - confidence_level
      pairwise_comparisons = []

      comparisons.each_with_index do |comp, index|
        rank = index + 1
        total_tests = comparisons.length
        bh_threshold = (rank.to_f / total_tests) * alpha

        p_value = comp[:comparison][:p_value]
        is_significant = p_value <= bh_threshold

        pairwise_comparisons << {
          variant_a: control[:name],
          variant_b: comp[:variant][:name],
          p_value: p_value,
          adjusted_p_value: [ p_value * total_tests / rank, 1.0 ].min,
          bh_threshold: bh_threshold,
          rank: rank,
          is_significant: is_significant,
          confidence_interval: comp[:comparison][:confidence_interval],
          effect_size: comp[:comparison][:effect_size]
        }
      end

      { pairwise_comparisons: pairwise_comparisons, method: "benjamini_hochberg" }
    end

    def apply_holm_correction(variants, confidence_level)
      return { pairwise_comparisons: [] } if variants.length < 2

      control = variants.find { |v| v[:name] == "control" } || variants.first
      comparisons = []

      # Perform all pairwise comparisons
      variants.each do |variant|
        next if variant == control
        comparisons << {
          variant: variant,
          comparison: perform_pairwise_comparison(control, variant)
        }
      end

      # Sort by p-value (ascending)
      comparisons.sort_by! { |c| c[:comparison][:p_value] }

      # Apply Holm procedure
      alpha = 1 - confidence_level
      pairwise_comparisons = []

      comparisons.each_with_index do |comp, index|
        remaining_tests = comparisons.length - index
        holm_alpha = alpha / remaining_tests

        p_value = comp[:comparison][:p_value]
        is_significant = p_value <= holm_alpha

        pairwise_comparisons << {
          variant_a: control[:name],
          variant_b: comp[:variant][:name],
          p_value: p_value,
          adjusted_p_value: [ p_value * remaining_tests, 1.0 ].min,
          holm_alpha: holm_alpha,
          step: index + 1,
          is_significant: is_significant,
          confidence_interval: comp[:comparison][:confidence_interval],
          effect_size: comp[:comparison][:effect_size]
        }

        # In Holm procedure, if we fail to reject, stop testing
        break unless is_significant
      end

      { pairwise_comparisons: pairwise_comparisons, method: "holm" }
    end

    private

    def perform_pairwise_comparison(variant_a, variant_b)
      # Extract data
      n1, x1 = variant_a[:visitors], variant_a[:conversions]
      n2, x2 = variant_b[:visitors], variant_b[:conversions]

      return default_comparison_result if n1 == 0 || n2 == 0

      # Calculate proportions
      p1 = x1.to_f / n1
      p2 = x2.to_f / n2

      # Two-proportion z-test
      p_pool = (x1 + x2).to_f / (n1 + n2)
      se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/n1 + 1.0/n2))

      return default_comparison_result if se == 0

      z = (p2 - p1) / se
      p_value = 2 * (1 - standard_normal_cdf(z.abs))

      # Confidence interval for difference in proportions
      diff = p2 - p1
      diff_se = Math.sqrt((p1 * (1 - p1) / n1) + (p2 * (1 - p2) / n2))
      margin_error = 1.96 * diff_se

      {
        p_value: p_value.round(6),
        z_score: z.round(4),
        effect_size: diff.round(4),
        confidence_interval: {
          lower: (diff - margin_error).round(4),
          upper: (diff + margin_error).round(4),
          difference: diff.round(4)
        }
      }
    end

    def default_comparison_result
      {
        p_value: 1.0,
        z_score: 0.0,
        effect_size: 0.0,
        confidence_interval: { lower: 0.0, upper: 0.0, difference: 0.0 }
      }
    end

    def standard_normal_cdf(x)
      # Approximation of standard normal CDF
      0.5 * (1 + erf(x / Math.sqrt(2)))
    end

    def erf(x)
      # Error function approximation (Abramowitz and Stegun)
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
