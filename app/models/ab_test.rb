class AbTest < ApplicationRecord
  belongs_to :campaign
  belongs_to :user
  has_many :ab_test_variants, dependent: :destroy
  has_many :journeys, through: :ab_test_variants
  belongs_to :winner_variant, class_name: "AbTestVariant", optional: true
  has_many :ab_test_results, dependent: :destroy
  has_many :ab_test_metrics, dependent: :destroy
  has_many :ab_test_configurations, dependent: :destroy
  has_many :ab_test_recommendations, dependent: :destroy

  STATUSES = %w[draft running paused completed cancelled].freeze
  TEST_TYPES = %w[
    conversion engagement retention click_through
    bounce_rate time_on_page form_completion
    email_open email_click purchase revenue
  ].freeze

  validates :name, presence: true, uniqueness: { scope: :campaign_id }
  validates :status, inclusion: { in: STATUSES }
  validates :test_type, inclusion: { in: TEST_TYPES }
  validates :confidence_level, presence: true, numericality: {
    greater_than: 50, less_than_or_equal_to: 99.9
  }
  validates :significance_threshold, presence: true, numericality: {
    greater_than: 0, less_than_or_equal_to: 20
  }

  validate :end_date_after_start_date
  validate :variants_traffic_percentage_sum

  # Use settings JSON for additional attributes
  store_accessor :settings, :minimum_sample_size

  scope :active, -> { where(status: [ "running", "paused" ]) }
  scope :completed, -> { where(status: "completed") }
  scope :by_type, ->(type) { where(test_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :running, -> { where(status: "running") }

  def start!
    return false unless can_start?

    update!(status: "running", start_date: Time.current)

    # Start tracking for all variants
    ab_test_variants.each(&:reset_metrics!)

    true
  end

  def pause!
    update!(status: "paused")
  end

  def resume!
    return false unless paused?

    update!(status: "running")
  end

  def complete!
    return false unless running?

    determine_winner!
    update!(status: "completed", end_date: Time.current)
  end

  def cancel!
    update!(status: "cancelled", end_date: Time.current)
  end

  def running?
    status == "running"
  end

  def paused?
    status == "paused"
  end

  def completed?
    status == "completed"
  end

  def can_start?
    draft? && ab_test_variants.count >= 2 && valid_traffic_allocation?
  end

  def draft?
    status == "draft"
  end

  def duration_days
    return 0 unless start_date

    end_time = end_date || Time.current
    ((end_time - start_date) / 1.day).round(1)
  end

  def progress_percentage
    return 0 unless start_date && end_date

    # Calculate how much time has elapsed vs planned duration
    elapsed_time = Time.current - start_date
    planned_time = end_date - start_date

    return 100 if elapsed_time >= planned_time

    elapsed_days = elapsed_time / 1.day
    planned_days = planned_time / 1.day

    [ (elapsed_days / planned_days * 100).round, 100 ].min
  end

  def planned_duration_days
    return 0 unless start_date && end_date

    ((end_date - start_date) / 1.day).round(1)
  end

  def statistical_significance_reached?
    return false unless running? || completed?

    control_variant = ab_test_variants.find_by(is_control: true)
    return false unless control_variant

    treatment_variants = ab_test_variants.where(is_control: false)

    treatment_variants.any? do |variant|
      calculate_statistical_significance_between(control_variant, variant) >= significance_threshold
    end
  end

  def determine_winner!
    return if ab_test_variants.count < 2

    # Find the variant with the highest conversion rate that is statistically significant
    control_variant = ab_test_variants.find_by(is_control: true)
    return unless control_variant

    significant_variants = ab_test_variants.select do |variant|
      next true if variant.is_control?  # Control is always included

      calculate_statistical_significance_between(control_variant, variant) >= significance_threshold
    end

    return if significant_variants.empty?

    winner = significant_variants.max_by(&:conversion_rate)
    update!(winner_variant: winner) if winner
  end

  def winner_declared?
    winner_variant.present?
  end

  def assign_visitor(visitor_id)
    return nil unless can_start?

    # Use consistent hashing to assign visitors to variants
    hash_value = Digest::MD5.hexdigest("#{id}-#{visitor_id}").to_i(16)
    percentage = hash_value % 100

    cumulative_percentage = 0
    ab_test_variants.order(:id).each do |variant|
      cumulative_percentage += variant.traffic_percentage
      if percentage < cumulative_percentage
        variant.record_visitor!
        return variant
      end
    end

    # Fallback to last variant if rounding errors occur
    ab_test_variants.last
  end

  def performance_report
    {
      test_name: name,
      status: status,
      start_date: start_date,
      end_date: end_date,
      progress_percentage: progress_percentage,
      variants: ab_test_variants.map(&:detailed_metrics),
      winner: winner_variant&.name,
      statistical_significance_reached: statistical_significance_reached?
    }
  end

  def generate_insights
    insights_array = []

    if running?
      insights_array << "Test has been running for #{((Time.current - start_date) / 1.day).round} days"
      insights_array << "#{progress_percentage}% of planned duration completed"

      if statistical_significance_reached?
        insights_array << "Statistical significance has been reached"
      else
        insights_array << "More data needed to reach statistical significance"
      end
    end

    if completed?
      if winner_variant
        insights_array << "Winner: #{winner_variant.name} with #{winner_variant.conversion_rate}% conversion rate"
        control = ab_test_variants.find_by(is_control: true)
        if control && control != winner_variant
          lift = winner_variant.lift_vs_control
          insights_array << "Lift vs control: #{lift}%"
        end
      else
        insights_array << "No clear winner could be determined"
      end
    end

    # Return hash format expected by test
    {
      performance_summary: performance_report,
      statistical_summary: calculate_statistical_summary,
      recommendations: insights_array,
      next_steps: generate_next_steps
    }
  end

  def calculate_statistical_significance
    control = ab_test_variants.find_by(is_control: true)
    return {} unless control

    best_treatment = ab_test_variants.where(is_control: false)
                                    .order(conversion_rate: :desc)
                                    .first

    return {} unless best_treatment

    significance_value = calculate_statistical_significance_between(control, best_treatment)

    {
      p_value: (1 - significance_value / 100.0).round(4),
      is_significant: significance_value >= significance_threshold,
      confidence_interval: significance_value.round(2)
    }
  end

  def complete_test!
    return false unless can_complete?

    transaction do
      determine_winner!
      update!(
        status: "completed",
        end_date: Time.current
      )
    end

    true
  end

  def meets_minimum_sample_size?
    return true unless minimum_sample_size.present?

    total_visitors = ab_test_variants.sum(:total_visitors)
    total_visitors >= minimum_sample_size.to_i
  end

  def can_complete?
    running? && (
      end_date.present? && Time.current >= end_date ||
      statistical_significance_reached? ||
      meets_minimum_sample_size?
    )
  end

  def calculate_statistical_summary
    {
      control_conversion_rate: ab_test_variants.control.first&.conversion_rate || 0,
      best_variant_conversion_rate: ab_test_variants.order(conversion_rate: :desc).first&.conversion_rate || 0,
      sample_size: ab_test_variants.sum(:total_visitors),
      total_conversions: ab_test_variants.sum(:conversions)
    }
  end

  def generate_next_steps
    steps = []

    if draft?
      steps << "Configure test variants and traffic allocation"
      steps << "Set start and end dates"
      steps << "Review and launch test"
    elsif running?
      if !meets_minimum_sample_size?
        steps << "Continue running test to reach minimum sample size"
      elsif !statistical_significance_reached?
        steps << "Continue test to achieve statistical significance"
      else
        steps << "Consider ending test and declaring winner"
      end
    elsif completed?
      steps << "Implement winning variant across all traffic"
      steps << "Document learnings and insights"
      steps << "Plan follow-up tests based on results"
    end

    steps
  end

  def results_summary
    return {} unless ab_test_variants.any?

    control = ab_test_variants.find_by(is_control: true)
    treatments = ab_test_variants.where(is_control: false)

    {
      test_name: name,
      status: status,
      duration_days: duration_days,
      statistical_significance: statistical_significance_reached?,
      winner: winner_variant&.name,
      control_performance: control&.performance_summary,
      treatment_performances: treatments.map(&:performance_summary),
      confidence_level: confidence_level,
      total_visitors: ab_test_variants.sum(:total_visitors),
      overall_conversion_rate: calculate_overall_conversion_rate
    }
  end

  def variant_comparison
    return [] unless ab_test_variants.count >= 2

    control = ab_test_variants.find_by(is_control: true)
    return [] unless control

    treatments = ab_test_variants.where(is_control: false)

    treatments.map do |treatment|
      significance = calculate_statistical_significance(control, treatment)
      lift = calculate_lift(control, treatment)

      {
        variant_name: treatment.name,
        control_conversion_rate: control.conversion_rate,
        treatment_conversion_rate: treatment.conversion_rate,
        lift_percentage: lift,
        statistical_significance: significance,
        is_significant: significance >= significance_threshold,
        confidence_interval: calculate_confidence_interval(treatment),
        sample_size: treatment.total_visitors
      }
    end
  end

  def recommend_action
    return "Test not yet started" unless running? || completed?
    return "Insufficient data" if ab_test_variants.sum(:total_visitors) < 100

    if statistical_significance_reached?
      if winner_declared?
        "Implement #{winner_variant.name} variant (statistically significant winner)"
      else
        "Continue test - significance reached but no clear winner"
      end
    else
      if duration_days > 14
        "Consider extending test duration or increasing traffic"
      else
        "Continue test - more data needed for statistical significance"
      end
    end
  end

  def self.create_basic_ab_test(campaign, name, control_journey, treatment_journey, test_type = "conversion")
    test = create!(
      campaign: campaign,
      user: campaign.user,
      name: name,
      test_type: test_type,
      hypothesis: "Treatment journey will outperform control journey for #{test_type}"
    )

    # Create control variant
    test.ab_test_variants.create!(
      journey: control_journey,
      name: "Control",
      is_control: true,
      traffic_percentage: 50.0
    )

    # Create treatment variant
    test.ab_test_variants.create!(
      journey: treatment_journey,
      name: "Treatment",
      is_control: false,
      traffic_percentage: 50.0
    )

    test
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, "must be after start date") if end_date <= start_date
  end

  def variants_traffic_percentage_sum
    return unless ab_test_variants.any?

    total_percentage = ab_test_variants.sum(:traffic_percentage)
    unless (99.0..101.0).cover?(total_percentage)
      errors.add(:base, "Variant traffic percentages must sum to 100%")
    end
  end

  def valid_traffic_allocation?
    return false unless ab_test_variants.any?

    total_percentage = ab_test_variants.sum(:traffic_percentage)
    (99.0..101.0).cover?(total_percentage)
  end

  def calculate_statistical_significance_between(control, treatment)
    return 0 if control.total_visitors == 0 || treatment.total_visitors == 0

    # Simplified z-test calculation for conversion rates
    p1 = control.conversion_rate / 100.0
    p2 = treatment.conversion_rate / 100.0
    n1 = control.total_visitors
    n2 = treatment.total_visitors

    # Pooled proportion
    p_pool = (control.conversions + treatment.conversions).to_f / (n1 + n2)

    # Standard error
    se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/n1 + 1.0/n2))

    return 0 if se == 0

    # Z-score
    z = (p2 - p1).abs / se

    # Convert to significance percentage (simplified)
    significance = [ (1 - Math.exp(-z * z / 2)) * 100, 99.9 ].min
    significance.round(1)
  end

  def calculate_lift(control, treatment)
    return 0 if control.conversion_rate == 0

    ((treatment.conversion_rate - control.conversion_rate) / control.conversion_rate * 100).round(1)
  end

  def calculate_confidence_interval(variant)
    return [ 0, 0 ] if variant.total_visitors == 0

    p = variant.conversion_rate / 100.0
    n = variant.total_visitors

    # 95% confidence interval for proportion
    margin_of_error = 1.96 * Math.sqrt(p * (1 - p) / n)

    lower = [ (p - margin_of_error) * 100, 0 ].max
    upper = [ (p + margin_of_error) * 100, 100 ].min

    [ lower.round(1), upper.round(1) ]
  end

  def calculate_overall_conversion_rate
    total_visitors = ab_test_variants.sum(:total_visitors)
    return 0 if total_visitors == 0

    total_conversions = ab_test_variants.sum(:conversions)
    (total_conversions.to_f / total_visitors * 100).round(2)
  end
end
