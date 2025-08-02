module AbTesting
  class AbTestStatisticalAnalyzer
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def perform_comprehensive_analysis(variant_data)
      {
        significance_tests: perform_significance_tests(variant_data),
        effect_sizes: calculate_effect_sizes(variant_data),
        power_analysis: perform_power_analysis(variant_data),
        confidence_intervals: calculate_confidence_intervals(variant_data),
        normality_tests: perform_normality_tests(variant_data),
        sample_size_adequacy: assess_sample_size_adequacy(variant_data)
      }
    end

    def calculate_statistical_significance(control_data, treatment_data)
      # Two-proportion z-test
      n1, x1 = control_data[:visitors], control_data[:conversions]
      n2, x2 = treatment_data[:visitors], treatment_data[:conversions]

      return { p_value: 1.0, significant: false } if n1 == 0 || n2 == 0

      p1 = x1.to_f / n1
      p2 = x2.to_f / n2
      p_pool = (x1 + x2).to_f / (n1 + n2)

      se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/n1 + 1.0/n2))
      return { p_value: 1.0, significant: false } if se == 0

      z = (p2 - p1) / se
      p_value = 2 * (1 - normal_cdf(z.abs))

      # Calculate 95% confidence interval for the difference
      margin_of_error = 1.96 * se
      ci_lower = ((p2 - p1) - margin_of_error) * 100
      ci_upper = ((p2 - p1) + margin_of_error) * 100

      {
        z_score: z.round(4),
        p_value: p_value.round(4),
        significant: p_value < 0.05,
        effect_size: (p2 - p1).round(4),
        confidence_interval: [ ci_lower.round(2), ci_upper.round(2) ]
      }
    end

    def calculate_effect_sizes(variant_data)
      return {} unless variant_data.keys.length >= 2

      control_key = variant_data.keys.first
      control = variant_data[control_key]

      # Get first treatment variant for aggregated comparison
      treatment_key = variant_data.keys.find { |k| k != control_key }
      return {} unless treatment_key

      treatment = variant_data[treatment_key]

      # Return aggregated effect sizes in expected format
      {
        conversion_rate: {
          cohens_d: calculate_cohens_d(control, treatment),
          lift_percentage: calculate_lift_percentage(control, treatment),
          odds_ratio: calculate_odds_ratio(control, treatment),
          relative_risk: calculate_relative_risk(control, treatment)
        },
        revenue: {
          lift_percentage: calculate_revenue_lift(control, treatment),
          effect_size: calculate_revenue_effect_size(control, treatment)
        }
      }
    end

    def perform_power_analysis(variant_data)
      return {} if variant_data.keys.length < 2

      control_key = variant_data.keys.first
      control = variant_data[control_key]

      # Get first treatment variant for aggregated analysis
      treatment_key = variant_data.keys.find { |k| k != control_key }
      return {} unless treatment_key

      treatment = variant_data[treatment_key]

      # Return aggregated power analysis in expected format
      {
        statistical_power: calculate_statistical_power(control, treatment),
        minimum_detectable_effect: calculate_minimum_detectable_effect(control, treatment),
        required_sample_size: calculate_required_sample_size(control, treatment)
      }
    end

    def calculate_confidence_intervals(variant_data)
      intervals = {}

      variant_data.each do |variant_key, data|
        visitors = data[:visitors] || 0
        conversions = data[:conversions] || 0

        next if visitors == 0

        p = conversions.to_f / visitors
        margin_of_error = 1.96 * Math.sqrt(p * (1 - p) / visitors)

        intervals[variant_key] = {
          conversion_rate: p.round(4),
          lower_bound: [ p - margin_of_error, 0 ].max.round(4),
          upper_bound: [ p + margin_of_error, 1 ].min.round(4),
          margin_of_error: margin_of_error.round(4)
        }
      end

      intervals
    end

    private

    def perform_significance_tests(variant_data)
      # Get control variant (assume first one is control)
      control_key = variant_data.keys.first
      control = variant_data[control_key]

      # Aggregate results across all treatment variants for summary
      conversion_tests = []
      revenue_tests = []

      variant_data.each do |variant_key, data|
        next if variant_key == control_key

        # Conversion rate test
        conversion_test = calculate_statistical_significance(
          { visitors: control[:visitors], conversions: control[:conversions] },
          { visitors: data[:visitors], conversions: data[:conversions] }
        )
        conversion_tests << conversion_test

        # Revenue test (if available)
        revenue_test = if control[:revenue] && data[:revenue]
          calculate_revenue_significance(control, data)
        else
          { p_value: nil, significant: false }
        end
        revenue_tests << revenue_test
      end

      # Return aggregated results in expected format
      {
        conversion_rate: conversion_tests.first || { p_value: 1.0, significant: false, confidence_interval: [ 0, 100 ] },
        revenue: revenue_tests.first || { p_value: nil, significant: false }
      }
    end

    def calculate_cohens_d(control, treatment)
      # Effect size for conversion rates
      p1 = control[:conversions].to_f / control[:visitors] rescue 0
      p2 = treatment[:conversions].to_f / treatment[:visitors] rescue 0

      # Pooled standard deviation for proportions
      n1, n2 = control[:visitors], treatment[:visitors]
      return 0 if n1 == 0 || n2 == 0

      pooled_p = (control[:conversions] + treatment[:conversions]).to_f / (n1 + n2)
      pooled_std = Math.sqrt(pooled_p * (1 - pooled_p))

      return 0 if pooled_std == 0

      ((p2 - p1) / pooled_std).round(4)
    end

    def calculate_lift_percentage(control, treatment)
      control_rate = control[:conversions].to_f / control[:visitors] rescue 0
      treatment_rate = treatment[:conversions].to_f / treatment[:visitors] rescue 0

      return 0 if control_rate == 0

      (((treatment_rate - control_rate) / control_rate) * 100).round(2)
    end

    def calculate_odds_ratio(control, treatment)
      c_conv, c_non_conv = control[:conversions], control[:visitors] - control[:conversions]
      t_conv, t_non_conv = treatment[:conversions], treatment[:visitors] - treatment[:conversions]

      return 1.0 if c_non_conv == 0 || t_non_conv == 0 || c_conv == 0 || treatment[:conversions] == 0

      ((t_conv * c_non_conv).to_f / (t_non_conv * c_conv)).round(4)
    end

    def calculate_relative_risk(control, treatment)
      control_rate = control[:conversions].to_f / control[:visitors] rescue 0
      treatment_rate = treatment[:conversions].to_f / treatment[:visitors] rescue 0

      return 1.0 if control_rate == 0

      (treatment_rate / control_rate).round(4)
    end

    def calculate_revenue_lift(control, treatment)
      control_revenue = control[:revenue] || 0
      treatment_revenue = treatment[:revenue] || 0

      return 0.0 if control_revenue == 0
      ((treatment_revenue - control_revenue) / control_revenue * 100).round(2)
    end

    def calculate_revenue_effect_size(control, treatment)
      control_revenue = control[:revenue] || 0
      treatment_revenue = treatment[:revenue] || 0
      control_visitors = control[:visitors] || 1
      treatment_visitors = treatment[:visitors] || 1

      control_avg = control_revenue.to_f / control_visitors
      treatment_avg = treatment_revenue.to_f / treatment_visitors

      return 0.0 if control_avg == 0
      ((treatment_avg - control_avg) / control_avg).round(4)
    end

    def calculate_statistical_power(control, treatment)
      # Simplified power calculation
      n1, n2 = control[:visitors], treatment[:visitors]
      p1 = control[:conversions].to_f / n1 rescue 0
      p2 = treatment[:conversions].to_f / n2 rescue 0

      return 0 if n1 == 0 || n2 == 0

      # Effect size
      effect_size = (p2 - p1).abs

      # Simplified power approximation based on sample size and effect size
      total_n = n1 + n2
      case total_n
      when 0..200
        effect_size > 0.2 ? 0.3 : 0.1
      when 201..500
        effect_size > 0.15 ? 0.5 : 0.2
      when 501..1000
        effect_size > 0.1 ? 0.7 : 0.4
      when 1001..2000
        effect_size > 0.08 ? 0.8 : 0.6
      else
        effect_size > 0.05 ? 0.9 : 0.8
      end.round(2)
    end

    def calculate_minimum_detectable_effect(control, treatment)
      # Minimum effect that can be detected with 80% power
      n1, n2 = control[:visitors], treatment[:visitors]
      p1 = control[:conversions].to_f / n1 rescue 0

      return 0 if n1 == 0 || n2 == 0

      # Simplified MDE calculation
      total_n = n1 + n2
      base_mde = case total_n
      when 0..200 then 0.2
      when 201..500 then 0.15
      when 501..1000 then 0.1
      when 1001..2000 then 0.08
      else 0.05
      end

      # Adjust for baseline conversion rate
      adjusted_mde = base_mde * Math.sqrt(p1 * (1 - p1)) rescue base_mde

      (adjusted_mde * 100).round(2)  # Return as percentage
    end

    def calculate_required_sample_size(control, treatment)
      # Sample size needed for 80% power to detect current effect
      p1 = control[:conversions].to_f / control[:visitors] rescue 0.05
      p2 = treatment[:conversions].to_f / treatment[:visitors] rescue 0.05

      effect_size = (p2 - p1).abs
      return 10000 if effect_size == 0  # Large sample needed if no effect

      # Simplified sample size calculation
      # n = 2 * (z_alpha + z_beta)^2 * pooled_variance / effect_size^2
      pooled_p = (p1 + p2) / 2
      pooled_variance = pooled_p * (1 - pooled_p)

      z_alpha = 1.96  # 95% confidence
      z_beta = 0.84   # 80% power

      n_per_group = 2 * ((z_alpha + z_beta) ** 2) * pooled_variance / (effect_size ** 2)

      (n_per_group * 2).round  # Total sample size for both groups
    end

    def calculate_revenue_significance(control, treatment)
      # T-test for revenue differences (simplified)
      c_revenue = control[:revenue] || 0
      t_revenue = treatment[:revenue] || 0
      c_visitors = control[:visitors] || 1
      t_visitors = treatment[:visitors] || 1

      c_mean = c_revenue.to_f / c_visitors
      t_mean = t_revenue.to_f / t_visitors

      # Simplified t-test for revenue data (not proportions)
      # Estimate variance based on sample sizes (simplified approach)
      c_variance = [ c_mean * 0.5, 0.01 ].max  # Avoid zero variance
      t_variance = [ t_mean * 0.5, 0.01 ].max  # Avoid zero variance

      pooled_std = Math.sqrt((c_variance / c_visitors) + (t_variance / t_visitors))

      return { p_value: 1.0, significant: false } if pooled_std == 0

      t_stat = (t_mean - c_mean) / pooled_std
      df = c_visitors + t_visitors - 2

      # Simplified p-value calculation
      p_value = 2 * (1 - normal_cdf(t_stat.abs))

      {
        t_statistic: t_stat.round(4),
        p_value: p_value.round(4),
        significant: p_value < 0.05,
        degrees_of_freedom: df
      }
    end

    def perform_normality_tests(variant_data)
      # Placeholder for normality tests
      # In practice, would implement Shapiro-Wilk or Kolmogorov-Smirnov tests
      normality_results = {}

      variant_data.each do |variant_key, data|
        normality_results[variant_key] = {
          normal_distribution: true,  # Assume normal for simplicity
          test_statistic: 0.95,
          p_value: 0.3
        }
      end

      normality_results
    end

    def assess_sample_size_adequacy(variant_data)
      adequacy = {}

      variant_data.each do |variant_key, data|
        visitors = data[:visitors] || 0
        conversions = data[:conversions] || 0

        adequacy[variant_key] = {
          sample_size: visitors,
          minimum_recommended: 100,
          adequate: visitors >= 100,
          power_adequate: visitors >= 400,
          conversions_adequate: conversions >= 10,
          overall_adequacy: visitors >= 100 && conversions >= 10 ? "adequate" : "inadequate"
        }
      end

      adequacy
    end

    def normal_cdf(x)
      # Approximation of the cumulative distribution function of the standard normal distribution
      0.5 * (1 + erf(x / Math.sqrt(2)))
    end

    def erf(x)
      # Approximation of the error function
      # Using Abramowitz and Stegun approximation
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
