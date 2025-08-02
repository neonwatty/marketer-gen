class AbTestAnalyticsService
  def initialize(ab_test)
    @ab_test = ab_test
  end

  def generate_full_analysis
    {
      test_overview: test_overview,
      variant_performance: variant_performance_analysis,
      statistical_analysis: statistical_analysis,
      confidence_intervals: confidence_intervals_analysis,
      power_analysis: power_analysis,
      recommendations: generate_recommendations,
      historical_comparison: historical_comparison,
      segments_analysis: segments_analysis
    }
  end

  def test_overview
    {
      test_id: @ab_test.id,
      test_name: @ab_test.name,
      status: @ab_test.status,
      hypothesis: @ab_test.hypothesis,
      test_type: @ab_test.test_type,
      duration_days: @ab_test.duration_days,
      confidence_level: @ab_test.confidence_level,
      significance_threshold: @ab_test.significance_threshold,
      total_variants: @ab_test.ab_test_variants.count,
      total_visitors: @ab_test.ab_test_variants.sum(:total_visitors),
      total_conversions: @ab_test.ab_test_variants.sum(:conversions),
      overall_conversion_rate: calculate_overall_conversion_rate,
      winner_declared: @ab_test.winner_declared?,
      winner_variant: @ab_test.winner_variant&.name
    }
  end

  def variant_performance_analysis
    variants = @ab_test.ab_test_variants.includes(:journey)

    performance_data = variants.map do |variant|
      {
        variant_id: variant.id,
        variant_name: variant.name,
        is_control: variant.is_control?,
        journey_name: variant.journey.name,
        traffic_percentage: variant.traffic_percentage,
        total_visitors: variant.total_visitors,
        conversions: variant.conversions,
        conversion_rate: variant.conversion_rate,
        confidence_interval: variant.confidence_interval_range,
        lift_vs_control: variant.lift_vs_control,
        significance_vs_control: variant.significance_vs_control,
        sample_size_adequate: variant.sample_size_adequate?,
        statistical_power: variant.statistical_power,
        performance_grade: calculate_variant_grade(variant)
      }
    end

    # Add relative rankings
    performance_data.sort_by! { |v| -v[:conversion_rate] }
    performance_data.each_with_index do |variant_data, index|
      variant_data[:performance_rank] = index + 1
    end

    {
      variants: performance_data,
      best_performer: performance_data.first,
      control_performance: performance_data.find { |v| v[:is_control] },
      performance_spread: calculate_performance_spread(performance_data)
    }
  end

  def statistical_analysis
    return {} unless @ab_test.running? || @ab_test.completed?

    control_variant = @ab_test.ab_test_variants.find_by(is_control: true)
    treatment_variants = @ab_test.ab_test_variants.where(is_control: false)

    return {} unless control_variant

    statistical_results = {}

    treatment_variants.each do |treatment|
      stat_test = perform_statistical_test(control_variant, treatment)

      statistical_results[treatment.name] = {
        z_score: stat_test[:z_score],
        p_value: stat_test[:p_value],
        significance_level: stat_test[:significance_level],
        is_significant: stat_test[:is_significant],
        effect_size: stat_test[:effect_size],
        power_estimate: estimate_statistical_power(control_variant, treatment),
        sample_size_recommendation: recommend_sample_size(control_variant, treatment)
      }
    end

    {
      control_variant: control_variant.name,
      treatment_results: statistical_results,
      overall_test_power: calculate_overall_test_power(statistical_results),
      significance_achieved: @ab_test.statistical_significance_reached?
    }
  end

  def confidence_intervals_analysis
    variants = @ab_test.ab_test_variants

    confidence_data = variants.map do |variant|
      ci_range = variant.confidence_interval_range
      margin_of_error = (ci_range[1] - ci_range[0]) / 2

      {
        variant_name: variant.name,
        conversion_rate: variant.conversion_rate,
        confidence_interval: ci_range,
        margin_of_error: margin_of_error.round(2),
        precision_level: classify_precision(margin_of_error),
        sample_size: variant.total_visitors
      }
    end

    {
      variants_confidence: confidence_data,
      overlapping_intervals: identify_overlapping_intervals(confidence_data),
      precision_assessment: assess_overall_precision(confidence_data)
    }
  end

  def power_analysis
    control_variant = @ab_test.ab_test_variants.find_by(is_control: true)
    return {} unless control_variant

    treatment_variants = @ab_test.ab_test_variants.where(is_control: false)

    power_results = treatment_variants.map do |treatment|
      current_power = estimate_statistical_power(control_variant, treatment)

      # Calculate required sample sizes for different effect sizes
      required_samples = {
        small_effect: calculate_required_sample_size(control_variant, 0.1),
        medium_effect: calculate_required_sample_size(control_variant, 0.2),
        large_effect: calculate_required_sample_size(control_variant, 0.5)
      }

      {
        variant_name: treatment.name,
        current_power: current_power,
        current_sample_size: treatment.total_visitors,
        required_samples_for_power_80: required_samples,
        days_to_adequate_power: estimate_days_to_power(treatment),
        power_assessment: assess_power_level(current_power)
      }
    end

    {
      control_variant: control_variant.name,
      treatment_power_analysis: power_results,
      overall_test_adequacy: assess_overall_test_adequacy(power_results)
    }
  end

  def generate_recommendations
    recommendations = []

    # Sample size recommendations
    if total_sample_size_adequate?
      recommendations << create_recommendation(
        "sample_size",
        "sufficient",
        "Sample Size Adequate",
        "Current sample size is sufficient for reliable results."
      )
    else
      recommendations << create_recommendation(
        "sample_size",
        "insufficient",
        "Increase Sample Size",
        "Current sample size may not be sufficient for reliable statistical conclusions.",
        [ "Continue test to gather more data", "Consider increasing traffic allocation" ]
      )
    end

    # Statistical significance recommendations
    if @ab_test.statistical_significance_reached?
      if @ab_test.winner_declared?
        recommendations << create_recommendation(
          "implementation",
          "ready",
          "Implement Winning Variant",
          "#{@ab_test.winner_variant.name} has shown statistically significant improvement.",
          [ "Deploy winning variant to all traffic", "Monitor performance post-implementation" ]
        )
      else
        recommendations << create_recommendation(
          "analysis",
          "review_needed",
          "Review Statistical Results",
          "Significance reached but no clear winner declared.",
          [ "Review business impact of variants", "Consider practical significance vs statistical significance" ]
        )
      end
    else
      recommendations << create_recommendation(
        "continue_testing",
        "in_progress",
        "Continue Test",
        "More data needed to reach statistical significance.",
        [ "Continue test for more time", "Consider increasing traffic if possible" ]
      )
    end

    # Performance-based recommendations
    variant_analysis = variant_performance_analysis
    control_performance = variant_analysis[:control_performance]
    best_performer = variant_analysis[:best_performer]

    if best_performer && control_performance
      lift = best_performer[:lift_vs_control]

      if lift > 20
        recommendations << create_recommendation(
          "high_impact",
          "significant_improvement",
          "High Impact Variant Identified",
          "#{best_performer[:variant_name]} shows #{lift}% improvement over control.",
          [ "Fast-track implementation if significance is reached", "Analyze successful elements for future tests" ]
        )
      elsif lift < -10
        recommendations << create_recommendation(
          "performance_issue",
          "negative_impact",
          "Negative Performance Detected",
          "Best variant still underperforms control by #{lift.abs}%.",
          [ "Stop test and revert to control", "Analyze failure factors for future tests" ]
        )
      end
    end

    # Duration recommendations
    if @ab_test.duration_days > 30
      recommendations << create_recommendation(
        "duration",
        "long_running",
        "Long-Running Test",
        "Test has been running for over 30 days.",
        [ "Consider concluding test based on current data", "Evaluate if external factors may be affecting results" ]
      )
    end

    recommendations
  end

  def historical_comparison
    # Compare with previous A/B tests in the same campaign
    campaign = @ab_test.campaign
    previous_tests = campaign.ab_tests.completed.where.not(id: @ab_test.id)
                            .order(created_at: :desc)
                            .limit(5)

    return {} if previous_tests.empty?

    historical_data = previous_tests.map do |test|
      {
        test_name: test.name,
        duration_days: test.duration_days,
        winner_conversion_rate: test.winner_variant&.conversion_rate || 0,
        total_participants: test.ab_test_variants.sum(:total_visitors),
        lift_achieved: calculate_historical_lift(test),
        lessons_learned: extract_lessons_learned(test)
      }
    end

    {
      previous_tests: historical_data,
      average_lift: historical_data.map { |t| t[:lift_achieved] }.sum / historical_data.count,
      success_rate: calculate_historical_success_rate(previous_tests),
      patterns: identify_historical_patterns(historical_data)
    }
  end

  def segments_analysis
    # This would analyze performance across different user segments
    # For now, return placeholder data that would integrate with actual segment tracking

    segments = {
      demographic: analyze_demographic_segments,
      behavioral: analyze_behavioral_segments,
      temporal: analyze_temporal_segments,
      acquisition_channel: analyze_channel_segments
    }

    {
      segments_breakdown: segments,
      significant_segments: identify_significant_segments(segments),
      recommendations: generate_segment_recommendations(segments)
    }
  end

  private

  def calculate_overall_conversion_rate
    total_visitors = @ab_test.ab_test_variants.sum(:total_visitors)
    total_conversions = @ab_test.ab_test_variants.sum(:conversions)

    return 0 if total_visitors == 0
    (total_conversions.to_f / total_visitors * 100).round(2)
  end

  def calculate_variant_grade(variant)
    score = variant.conversion_rate

    case score
    when 10..Float::INFINITY then "A"
    when 7..9.99 then "B"
    when 5..6.99 then "C"
    when 3..4.99 then "D"
    else "F"
    end
  end

  def calculate_performance_spread(performance_data)
    conversion_rates = performance_data.map { |v| v[:conversion_rate] }
    max_rate = conversion_rates.max
    min_rate = conversion_rates.min

    {
      max_conversion_rate: max_rate,
      min_conversion_rate: min_rate,
      spread: (max_rate - min_rate).round(2),
      coefficient_of_variation: calculate_coefficient_of_variation(conversion_rates)
    }
  end

  def perform_statistical_test(control, treatment)
    # Z-test for proportions
    p1 = control.conversion_rate / 100.0
    p2 = treatment.conversion_rate / 100.0
    n1 = control.total_visitors
    n2 = treatment.total_visitors

    return default_stat_test if n1 == 0 || n2 == 0

    # Pooled proportion
    p_pool = (control.conversions + treatment.conversions).to_f / (n1 + n2)

    # Standard error
    se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/n1 + 1.0/n2))

    return default_stat_test if se == 0

    # Z-score
    z_score = (p2 - p1) / se

    # P-value (two-tailed test)
    p_value = 2 * (1 - normal_cdf(z_score.abs))

    # Effect size (Cohen's h)
    effect_size = 2 * (Math.asin(Math.sqrt(p2)) - Math.asin(Math.sqrt(p1)))

    {
      z_score: z_score.round(3),
      p_value: p_value.round(4),
      significance_level: classify_significance(p_value),
      is_significant: p_value < 0.05,
      effect_size: effect_size.round(3)
    }
  end

  def default_stat_test
    {
      z_score: 0,
      p_value: 1.0,
      significance_level: "not_significant",
      is_significant: false,
      effect_size: 0
    }
  end

  def estimate_statistical_power(control, treatment)
    # Simplified power calculation
    sample_size = [ control.total_visitors, treatment.total_visitors ].min
    effect_size = (treatment.conversion_rate - control.conversion_rate).abs / 100.0

    case
    when sample_size < 100 then 0.2
    when sample_size < 500 && effect_size > 0.02 then 0.5
    when sample_size < 1000 && effect_size > 0.01 then 0.7
    when sample_size >= 1000 && effect_size > 0.01 then 0.8
    else 0.3
    end
  end

  def recommend_sample_size(control, treatment)
    # Simplified sample size calculation for 80% power
    baseline_rate = control.conversion_rate / 100.0
    effect_size = (treatment.conversion_rate - control.conversion_rate).abs / 100.0

    return 0 if effect_size == 0 || baseline_rate == 0

    # Simplified formula - in practice would use more sophisticated calculation
    estimated_n = (16 * baseline_rate * (1 - baseline_rate)) / (effect_size ** 2)
    estimated_n.round
  end

  def calculate_overall_test_power(statistical_results)
    return 0 if statistical_results.empty?

    powers = statistical_results.values.map { |result| result[:power_estimate] }
    (powers.sum / powers.count).round(2)
  end

  def classify_precision(margin_of_error)
    case margin_of_error
    when 0..1 then "very_high"
    when 1..2 then "high"
    when 2..5 then "medium"
    when 5..10 then "low"
    else "very_low"
    end
  end

  def identify_overlapping_intervals(confidence_data)
    overlaps = []

    confidence_data.combination(2).each do |variant1, variant2|
      ci1 = variant1[:confidence_interval]
      ci2 = variant2[:confidence_interval]

      if intervals_overlap?(ci1, ci2)
        overlaps << {
          variant1: variant1[:variant_name],
          variant2: variant2[:variant_name],
          overlap_size: calculate_overlap_size(ci1, ci2)
        }
      end
    end

    overlaps
  end

  def assess_overall_precision(confidence_data)
    avg_margin = confidence_data.map { |v| v[:margin_of_error] }.sum / confidence_data.count

    case avg_margin
    when 0..2 then "high_precision"
    when 2..5 then "medium_precision"
    else "low_precision"
    end
  end

  def total_sample_size_adequate?
    total_visitors = @ab_test.ab_test_variants.sum(:total_visitors)
    total_visitors >= 1000 # Simplified threshold
  end

  def create_recommendation(type, status, title, description, action_items = [])
    {
      type: type,
      status: status,
      title: title,
      description: description,
      action_items: action_items,
      priority: determine_priority(type, status)
    }
  end

  def determine_priority(type, status)
    case type
    when "implementation", "high_impact" then "high"
    when "performance_issue", "sample_size" then "medium"
    else "low"
    end
  end

  def calculate_historical_lift(test)
    return 0 unless test.winner_variant

    control = test.ab_test_variants.find_by(is_control: true)
    return 0 unless control

    ((test.winner_variant.conversion_rate - control.conversion_rate) / control.conversion_rate * 100).round(1)
  end

  def extract_lessons_learned(test)
    # This would analyze the test results and extract key insights
    # For now, return placeholder insights
    [
      "#{test.test_type} tests typically require #{test.duration_days} days for significance",
      "Winner achieved #{calculate_historical_lift(test)}% lift"
    ]
  end

  def calculate_historical_success_rate(previous_tests)
    successful_tests = previous_tests.count { |test| test.winner_variant&.conversion_rate.to_f > 0 }
    return 0 if previous_tests.empty?

    (successful_tests.to_f / previous_tests.count * 100).round(1)
  end

  def identify_historical_patterns(historical_data)
    return [] if historical_data.empty?

    patterns = []

    avg_duration = historical_data.map { |t| t[:duration_days] }.sum / historical_data.count
    patterns << "Average test duration: #{avg_duration.round} days"

    avg_lift = historical_data.map { |t| t[:lift_achieved] }.sum / historical_data.count
    patterns << "Average lift achieved: #{avg_lift.round(1)}%"

    patterns
  end

  def analyze_demographic_segments
    # Placeholder for demographic segment analysis
    {
      age_groups: {
        "18-25" => { control_cr: 4.2, treatment_cr: 5.1, significance: "not_significant" },
        "26-35" => { control_cr: 5.8, treatment_cr: 7.2, significance: "significant" },
        "36-45" => { control_cr: 6.1, treatment_cr: 6.3, significance: "not_significant" }
      }
    }
  end

  def analyze_behavioral_segments
    # Placeholder for behavioral segment analysis
    {
      engagement_level: {
        "high" => { control_cr: 8.2, treatment_cr: 9.8, significance: "significant" },
        "medium" => { control_cr: 5.1, treatment_cr: 5.9, significance: "marginally_significant" },
        "low" => { control_cr: 2.8, treatment_cr: 3.1, significance: "not_significant" }
      }
    }
  end

  def analyze_temporal_segments
    # Placeholder for temporal segment analysis
    {
      time_of_day: {
        "morning" => { control_cr: 5.5, treatment_cr: 6.8, significance: "significant" },
        "afternoon" => { control_cr: 4.9, treatment_cr: 5.2, significance: "not_significant" },
        "evening" => { control_cr: 6.2, treatment_cr: 7.1, significance: "marginally_significant" }
      }
    }
  end

  def analyze_channel_segments
    # Placeholder for acquisition channel analysis
    {
      acquisition_channel: {
        "organic" => { control_cr: 7.2, treatment_cr: 8.5, significance: "significant" },
        "paid_search" => { control_cr: 4.8, treatment_cr: 5.1, significance: "not_significant" },
        "social" => { control_cr: 3.9, treatment_cr: 4.7, significance: "marginally_significant" }
      }
    }
  end

  def identify_significant_segments(segments)
    significant = []

    segments.each do |segment_type, segment_data|
      segment_data.each do |segment_name, data|
        if data[:significance] == "significant"
          significant << {
            segment_type: segment_type,
            segment_name: segment_name,
            control_cr: data[:control_cr],
            treatment_cr: data[:treatment_cr],
            lift: ((data[:treatment_cr] - data[:control_cr]) / data[:control_cr] * 100).round(1)
          }
        end
      end
    end

    significant
  end

  def generate_segment_recommendations(segments)
    recommendations = []

    significant_segments = identify_significant_segments(segments)

    if significant_segments.any?
      recommendations << "Consider targeting #{significant_segments.first[:segment_name]} segment for maximum impact"
    end

    recommendations
  end

  # Statistical helper methods
  def normal_cdf(x)
    # Simplified normal CDF approximation
    (1 + Math.erf(x / Math.sqrt(2))) / 2
  end

  def classify_significance(p_value)
    case p_value
    when 0..0.001 then "highly_significant"
    when 0.001..0.01 then "very_significant"
    when 0.01..0.05 then "significant"
    when 0.05..0.1 then "marginally_significant"
    else "not_significant"
    end
  end

  def calculate_coefficient_of_variation(values)
    return 0 if values.empty?

    mean = values.sum.to_f / values.count
    return 0 if mean == 0

    variance = values.sum { |v| (v - mean) ** 2 } / values.count
    std_dev = Math.sqrt(variance)

    (std_dev / mean * 100).round(2)
  end

  def intervals_overlap?(ci1, ci2)
    ci1[0] <= ci2[1] && ci2[0] <= ci1[1]
  end

  def calculate_overlap_size(ci1, ci2)
    return 0 unless intervals_overlap?(ci1, ci2)

    overlap_start = [ ci1[0], ci2[0] ].max
    overlap_end = [ ci1[1], ci2[1] ].min

    overlap_end - overlap_start
  end

  def calculate_required_sample_size(control_variant, minimum_detectable_effect)
    baseline_rate = control_variant.conversion_rate / 100.0
    return 0 if baseline_rate == 0

    # Simplified sample size calculation for 80% power, 5% significance
    effect_size = minimum_detectable_effect
    z_alpha = 1.96  # 5% significance level
    z_beta = 0.84   # 80% power

    numerator = (z_alpha + z_beta) ** 2 * 2 * baseline_rate * (1 - baseline_rate)
    denominator = effect_size ** 2

    (numerator / denominator).round
  end

  def estimate_days_to_power(variant)
    return "N/A" unless variant.expected_visitors_per_day > 0

    required_sample = recommend_sample_size(
      @ab_test.ab_test_variants.find_by(is_control: true),
      variant
    )

    additional_visitors_needed = [ required_sample - variant.total_visitors, 0 ].max
    days_needed = (additional_visitors_needed / variant.expected_visitors_per_day).ceil

    days_needed > 0 ? days_needed : 0
  end

  def assess_power_level(power)
    case power
    when 0.8..1.0 then "adequate"
    when 0.6..0.79 then "moderate"
    when 0.4..0.59 then "low"
    else "insufficient"
    end
  end

  def assess_overall_test_adequacy(power_results)
    adequate_variants = power_results.count { |result| result[:power_assessment] == "adequate" }
    total_variants = power_results.count

    case adequate_variants.to_f / total_variants
    when 0.8..1.0 then "test_ready"
    when 0.5..0.79 then "mostly_adequate"
    when 0.2..0.49 then "needs_improvement"
    else "inadequate"
    end
  end
end
