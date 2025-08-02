class AbTestRecommendation < ApplicationRecord
  belongs_to :ab_test

  RECOMMENDATION_TYPES = %w[
    variant_optimization traffic_allocation duration_adjustment
    early_stopping statistical_significance winner_declaration
    follow_up_test personalization_opportunity sample_size_increase
  ].freeze

  STATUSES = %w[pending reviewed implemented dismissed].freeze

  validates :recommendation_type, presence: true, inclusion: { in: RECOMMENDATION_TYPES }
  validates :content, presence: true
  validates :confidence_score, presence: true, numericality: { in: 0..100 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :high_confidence, -> { where("confidence_score >= ?", 80.0) }
  scope :by_type, ->(type) { where(recommendation_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  def high_confidence?
    confidence_score >= 80.0
  end

  def actionable?
    pending? && high_confidence?
  end

  def mark_as_reviewed!
    update!(status: "reviewed")
  end

  def mark_as_implemented!
    update!(status: "implemented", metadata: metadata.merge(implemented_at: Time.current))
  end

  def dismiss!(reason = nil)
    dismissal_metadata = metadata.merge(
      dismissed_at: Time.current,
      dismissal_reason: reason
    )
    update!(status: "dismissed", metadata: dismissal_metadata)
  end

  def priority_level
    case confidence_score
    when 90..100
      "critical"
    when 80..89
      "high"
    when 60..79
      "medium"
    else
      "low"
    end
  end

  def estimated_impact
    metadata["estimated_impact"] || "unknown"
  end

  def implementation_complexity
    metadata["implementation_complexity"] || "medium"
  end

  def expected_improvement
    metadata["expected_improvement"] || 0
  end

  def risk_level
    metadata["risk_level"] || "low"
  end

  def supporting_data
    metadata["supporting_data"] || {}
  end

  def self.generate_recommendation(ab_test, type, content, confidence, metadata = {})
    create!(
      ab_test: ab_test,
      recommendation_type: type,
      content: content,
      confidence_score: confidence,
      status: "pending",
      metadata: metadata
    )
  end

  def self.generate_winner_recommendation(ab_test, winner_variant, confidence)
    content = "Declare #{winner_variant.name} as the winner with #{winner_variant.conversion_rate}% conversion rate"

    metadata = {
      winner_variant_id: winner_variant.id,
      lift_percentage: winner_variant.lift_vs_control,
      statistical_significance: winner_variant.significance_vs_control,
      sample_size: winner_variant.total_visitors,
      estimated_impact: "high",
      implementation_complexity: "low",
      risk_level: "low"
    }

    generate_recommendation(ab_test, "winner_declaration", content, confidence, metadata)
  end

  def self.generate_traffic_reallocation_recommendation(ab_test, new_allocation, confidence)
    content = "Reallocate traffic to improve test efficiency: #{new_allocation.map { |k, v| "#{k}: #{v}%" }.join(', ')}"

    metadata = {
      current_allocation: ab_test.ab_test_variants.pluck(:name, :traffic_percentage).to_h,
      recommended_allocation: new_allocation,
      expected_improvement: calculate_expected_improvement(ab_test, new_allocation),
      estimated_impact: "medium",
      implementation_complexity: "low",
      risk_level: "low"
    }

    generate_recommendation(ab_test, "traffic_allocation", content, confidence, metadata)
  end

  def self.generate_early_stopping_recommendation(ab_test, reason, confidence)
    content = "Consider stopping test early: #{reason}"

    metadata = {
      stopping_reason: reason,
      current_significance: ab_test.calculate_statistical_significance,
      days_running: ab_test.duration_days,
      estimated_impact: "high",
      implementation_complexity: "medium",
      risk_level: determine_early_stopping_risk(ab_test)
    }

    generate_recommendation(ab_test, "early_stopping", content, confidence, metadata)
  end

  def self.generate_sample_size_recommendation(ab_test, required_sample_size, confidence)
    current_sample_size = ab_test.ab_test_variants.sum(:total_visitors)
    additional_needed = required_sample_size - current_sample_size

    content = "Increase sample size by #{additional_needed} visitors to achieve statistical power"

    metadata = {
      current_sample_size: current_sample_size,
      required_sample_size: required_sample_size,
      additional_visitors_needed: additional_needed,
      estimated_duration_increase: calculate_duration_increase(ab_test, additional_needed),
      estimated_impact: "medium",
      implementation_complexity: "medium",
      risk_level: "low"
    }

    generate_recommendation(ab_test, "sample_size_increase", content, confidence, metadata)
  end

  private

  def self.calculate_expected_improvement(ab_test, new_allocation)
    # Simplified calculation - in practice would use more sophisticated modeling
    current_best_rate = ab_test.ab_test_variants.maximum(:conversion_rate) || 0
    baseline_rate = ab_test.ab_test_variants.find_by(is_control: true)&.conversion_rate || 0

    return 0 if baseline_rate == 0 || current_best_rate <= baseline_rate

    ((current_best_rate - baseline_rate) / baseline_rate * 100).round(1)
  end

  def self.determine_early_stopping_risk(ab_test)
    days_running = ab_test.duration_days
    significance = ab_test.statistical_significance_reached?
    sample_size = ab_test.ab_test_variants.sum(:total_visitors)

    if significance && sample_size >= 1000 && days_running >= 7
      "low"
    elsif significance && sample_size >= 500
      "medium"
    else
      "high"
    end
  end

  def self.calculate_duration_increase(ab_test, additional_visitors)
    return 0 unless ab_test.duration_days > 0

    current_visitors = ab_test.ab_test_variants.sum(:total_visitors)
    return 0 if current_visitors == 0

    visitors_per_day = current_visitors / ab_test.duration_days
    return "unknown" if visitors_per_day == 0

    (additional_visitors / visitors_per_day).ceil
  end
end
