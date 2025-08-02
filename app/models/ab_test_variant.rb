class AbTestVariant < ApplicationRecord
  belongs_to :ab_test
  belongs_to :journey
  has_one :campaign, through: :ab_test
  has_one :user, through: :ab_test

  VARIANT_TYPES = %w[control treatment variation].freeze

  validates :name, presence: true, uniqueness: { scope: :ab_test_id }
  validates :variant_type, inclusion: { in: VARIANT_TYPES }
  validates :traffic_percentage, presence: true, numericality: {
    greater_than: 0, less_than_or_equal_to: 100
  }
  validates :total_visitors, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :conversions, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :conversion_rate, presence: true, numericality: {
    greater_than_or_equal_to: 0, less_than_or_equal_to: 100
  }

  validate :conversions_not_exceed_visitors
  validate :only_one_control_per_test

  scope :control, -> { where(is_control: true) }
  scope :treatments, -> { where(is_control: false) }
  scope :by_conversion_rate, -> { order(conversion_rate: :desc) }
  scope :significant, -> { where("confidence_interval > ?", 95.0) }

  before_save :calculate_conversion_rate

  def control?
    is_control
  end

  def treatment?
    !is_control
  end

  def reset_metrics!
    update!(
      total_visitors: 0,
      conversions: 0,
      conversion_rate: 0.0,
      confidence_interval: 0.0
    )
  end

  def record_visitor!
    increment!(:total_visitors)
    calculate_and_update_conversion_rate
  end

  def record_conversion!
    increment!(:conversions)
    calculate_and_update_conversion_rate
  end

  def performance_summary
    {
      name: name,
      variant_type: variant_type,
      is_control: is_control,
      traffic_percentage: traffic_percentage,
      total_visitors: total_visitors,
      conversions: conversions,
      conversion_rate: conversion_rate,
      confidence_interval: confidence_interval,
      journey_name: journey.name
    }
  end

  def sample_size_adequate?
    # Rule of thumb: at least 100 visitors and 10 conversions for meaningful results
    total_visitors >= 100 && conversions >= 10
  end

  def statistical_power
    return 0 if total_visitors == 0

    # Simplified power calculation based on sample size
    # In practice, this would use more sophisticated statistical methods
    case total_visitors
    when 0..99 then "Low"
    when 100..499 then "Medium"
    when 500..999 then "High"
    else "Very High"
    end
  end

  def lift_vs_control
    return 0 unless ab_test && ab_test.ab_test_variants.any?

    control_variant = ab_test.ab_test_variants.find_by(is_control: true)
    return 0 unless control_variant && control_variant != self
    return 0 if control_variant.conversion_rate == 0

    ((conversion_rate - control_variant.conversion_rate) / control_variant.conversion_rate * 100).round(1)
  end

  # Alias for backward compatibility
  def calculate_lift
    lift_vs_control
  end

  def significance_vs_control
    return 0 unless ab_test && ab_test.ab_test_variants.any?

    control_variant = ab_test.ab_test_variants.find_by(is_control: true)
    return 0 unless control_variant && control_variant != self

    calculate_significance_against(control_variant)
  end

  def confidence_interval_range
    return [ 0, 0 ] if total_visitors == 0

    p = conversion_rate / 100.0
    n = total_visitors

    # Calculate 95% confidence interval
    margin_of_error = 1.96 * Math.sqrt(p * (1 - p) / n)

    lower = [ (p - margin_of_error) * 100, 0 ].max
    upper = [ (p + margin_of_error) * 100, 100 ].min

    [ lower.round(1), upper.round(1) ]
  end

  def expected_visitors_per_day
    return 0 unless ab_test.start_date && ab_test.running?

    days_running = [ (Time.current - ab_test.start_date) / 1.day, 1 ].max
    (total_visitors / days_running).round
  end

  def days_to_significance(target_significance = 95.0)
    return "N/A" unless ab_test.running? && expected_visitors_per_day > 0

    # Simplified calculation - in practice would use power analysis
    control_variant = ab_test.ab_test_variants.find_by(is_control: true)
    return "N/A" unless control_variant

    current_significance = significance_vs_control
    return "Already significant" if current_significance >= target_significance

    # Estimate additional visitors needed (simplified)
    additional_visitors_needed = [ 500 - total_visitors, 0 ].max
    days_needed = (additional_visitors_needed / expected_visitors_per_day).ceil

    "~#{days_needed} days"
  end

  def journey_performance_context
    {
      journey_name: journey.name,
      journey_status: journey.status,
      total_steps: journey.total_steps,
      completion_rate: journey_completion_rate,
      average_journey_time: average_journey_completion_time
    }
  end

  def detailed_metrics
    base_metrics = performance_summary

    base_metrics.merge({
      lift_vs_control: lift_vs_control,
      significance_vs_control: significance_vs_control,
      confidence_interval_range: confidence_interval_range,
      sample_size_adequate: sample_size_adequate?,
      statistical_power: statistical_power,
      expected_visitors_per_day: expected_visitors_per_day,
      days_to_significance: days_to_significance,
      journey_context: journey_performance_context
    })
  end

  def calculate_required_sample_size(desired_lift = 20, power = 0.8, alpha = 0.05)
    # Simplified sample size calculation for A/B test
    # In practice, would use more sophisticated statistical methods

    baseline_rate = is_control ? (conversion_rate / 100.0) : 0.05  # Default 5% if not control
    effect_size = baseline_rate * (desired_lift / 100.0)

    # Simplified formula - actual calculation would be more complex
    estimated_sample_size = (2 * (1.96 + 0.84)**2 * baseline_rate * (1 - baseline_rate)) / (effect_size**2)

    estimated_sample_size.round
  end

  private

  def conversions_not_exceed_visitors
    return unless total_visitors && conversions

    errors.add(:conversions, "cannot exceed total visitors") if conversions > total_visitors
  end

  def only_one_control_per_test
    return unless is_control? && ab_test

    existing_control = ab_test.ab_test_variants.where(is_control: true).where.not(id: id).exists?
    errors.add(:is_control, "only one control variant allowed per test") if existing_control
  end

  def calculate_conversion_rate
    self.conversion_rate = if total_visitors > 0
                            (conversions.to_f / total_visitors * 100).round(2)
    else
                            0.0
    end
  end

  def calculate_and_update_conversion_rate
    calculate_conversion_rate
    save! if changed?
  end

  def calculate_significance_against(other_variant)
    return 0 if total_visitors == 0 || other_variant.total_visitors == 0

    # Z-test for proportions
    p1 = conversion_rate / 100.0
    p2 = other_variant.conversion_rate / 100.0
    n1 = total_visitors
    n2 = other_variant.total_visitors

    # Pooled proportion
    p_pool = (conversions + other_variant.conversions).to_f / (n1 + n2)

    # Standard error
    se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/n1 + 1.0/n2))

    return 0 if se == 0

    # Z-score
    z = (p1 - p2).abs / se

    # Convert to confidence level (simplified)
    confidence = [ (1 - Math.exp(-z * z / 2)) * 100, 99.9 ].min
    confidence.round(1)
  end

  def journey_completion_rate
    # This would integrate with actual journey execution data
    # For now, return conversion rate as a proxy
    conversion_rate
  end

  def average_journey_completion_time
    # This would integrate with actual journey execution timing data
    # For now, return a placeholder
    journey.journey_steps.sum(:duration_days)
  end
end
