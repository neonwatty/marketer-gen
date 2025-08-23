class ContentAbTestVariant < ApplicationRecord
  # Associations
  belongs_to :content_ab_test
  belongs_to :generated_content
  has_many :content_ab_test_results, dependent: :destroy

  # Constants
  STATUSES = %w[
    draft
    active
    paused
    completed
    stopped
  ].freeze

  # Validations
  validates :variant_name, presence: true, length: { maximum: 255 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :traffic_split, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :sample_size, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Custom validations
  validate :generated_content_belongs_to_same_campaign
  validate :variant_name_unique_within_test
  validate :traffic_split_reasonable
  validate :content_not_already_in_test

  # JSON serialization
  serialize :metadata, coder: JSON

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :draft, -> { where(status: "draft") }
  scope :by_test, ->(test_id) { where(content_ab_test_id: test_id) }
  scope :with_results, -> { joins(:content_ab_test_results).distinct }
  scope :high_traffic, -> { where("traffic_split > ?", 20) }

  # Callbacks
  before_validation :set_default_metadata, on: :create
  before_validation :set_default_sample_size, on: :create
  after_create :log_variant_creation
  after_update :handle_status_changes, if: :saved_change_to_status?

  # Status methods
  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def paused?
    status == "paused"
  end

  def completed?
    status == "completed"
  end

  def stopped?
    status == "stopped"
  end

  # Performance tracking
  def record_result!(metric_name, metric_value, sample_size = 1, date = Date.current)
    content_ab_test_results.create!(
      metric_name: metric_name,
      metric_value: metric_value,
      sample_size: sample_size,
      recorded_date: date,
      metadata: {
        recorded_at: Time.current,
        variant_name: variant_name
      }
    )

    # Update cumulative sample size
    increment!(:sample_size, sample_size) if sample_size > 0
  end

  def batch_record_results!(results_data)
    return false if results_data.blank?

    transaction do
      total_samples = 0

      results_data.each do |result|
        content_ab_test_results.create!(
          metric_name: result[:metric_name],
          metric_value: result[:metric_value],
          sample_size: result[:sample_size] || 1,
          recorded_date: result[:date] || Date.current,
          metadata: (result[:metadata] || {}).merge(
            variant_name: variant_name,
            batch_recorded_at: Time.current
          )
        )

        total_samples += (result[:sample_size] || 1)
      end

      increment!(:sample_size, total_samples) if total_samples > 0
    end
  end

  # Analytics methods
  def performance_metrics
    return {} if content_ab_test_results.empty?

    metrics = {}

    # Group by metric name and calculate statistics
    content_ab_test_results.group(:metric_name).pluck(:metric_name).each do |metric_name|
      metric_results = content_ab_test_results.where(metric_name: metric_name)
      values = metric_results.pluck(:metric_value)

      metrics[metric_name] = {
        average: values.sum.to_f / values.count,
        total: values.sum,
        count: values.count,
        min: values.min,
        max: values.max,
        standard_deviation: calculate_standard_deviation(values),
        latest_value: metric_results.order(:recorded_date).last&.metric_value
      }
    end

    metrics
  end

  def daily_performance(metric_name)
    content_ab_test_results
      .where(metric_name: metric_name)
      .group(:recorded_date)
      .group_by_day(:recorded_date)
      .average(:metric_value)
  end

  def conversion_rate(impression_metric = "impressions", conversion_metric = "conversions")
    impressions = total_metric_value(impression_metric)
    conversions = total_metric_value(conversion_metric)

    return 0.0 if impressions.zero?

    (conversions / impressions * 100).round(4)
  end

  def total_metric_value(metric_name)
    content_ab_test_results
      .where(metric_name: metric_name)
      .sum(:metric_value)
      .to_f
  end

  def average_metric_value(metric_name)
    content_ab_test_results
      .where(metric_name: metric_name)
      .average(:metric_value)
      &.to_f || 0.0
  end

  # Comparison methods
  def compare_with_control
    return {} unless content_ab_test.control_content.present?

    control_variant = content_ab_test.content_ab_test_variants
                        .joins(:generated_content)
                        .find_by(generated_content: content_ab_test.control_content)

    return {} unless control_variant

    comparison = {}
    my_metrics = performance_metrics
    control_metrics = control_variant.performance_metrics

    my_metrics.each do |metric_name, my_stats|
      control_stats = control_metrics[metric_name]
      next unless control_stats

      improvement = calculate_improvement(my_stats[:average], control_stats[:average])

      comparison[metric_name] = {
        variant_value: my_stats[:average],
        control_value: control_stats[:average],
        improvement_percent: improvement,
        is_better: improvement > 0,
        statistical_significance: calculate_significance(my_stats, control_stats)
      }
    end

    comparison
  end

  def performance_trend(metric_name, days = 7)
    end_date = Date.current
    start_date = end_date - days.days

    content_ab_test_results
      .where(metric_name: metric_name, recorded_date: start_date..end_date)
      .group(:recorded_date)
      .order(:recorded_date)
      .average(:metric_value)
  end

  # Variant management
  def activate!
    return false unless can_activate?

    transaction do
      update!(
        status: "active",
        metadata: (metadata || {}).merge(
          activated_at: Time.current
        )
      )
    end
  end

  def pause!
    return false unless active?

    transaction do
      update!(
        status: "paused",
        metadata: (metadata || {}).merge(
          paused_at: Time.current
        )
      )
    end
  end

  def stop!(reason = nil)
    return false unless %w[active paused].include?(status)

    transaction do
      update!(
        status: "stopped",
        metadata: (metadata || {}).merge(
          stopped_at: Time.current,
          stop_reason: reason
        )
      )
    end
  end

  def complete!
    return false unless can_complete?

    transaction do
      update!(
        status: "completed",
        metadata: (metadata || {}).merge(
          completed_at: Time.current,
          final_sample_size: sample_size
        )
      )
    end
  end

  # Status checks
  def can_activate?
    draft? && content_ab_test.draft?
  end

  def can_complete?
    active? && sample_size.to_i >= minimum_sample_size_for_variant
  end

  def has_sufficient_data?
    sample_size.to_i >= minimum_sample_size_for_variant
  end

  def minimum_sample_size_for_variant
    # Calculate minimum sample size based on traffic split
    total_minimum = content_ab_test.minimum_sample_size
    (total_minimum * (traffic_split / 100.0)).ceil
  end

  # Summary methods
  def variant_summary
    {
      id: id,
      variant_name: variant_name,
      status: status,
      traffic_split: traffic_split,
      sample_size: sample_size || 0,
      content_title: generated_content.title,
      content_id: generated_content.id,
      test_name: content_ab_test.test_name,
      performance_summary: performance_metrics.transform_values { |v| v[:average] },
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def detailed_analytics
    {
      basic_info: variant_summary,
      performance_metrics: performance_metrics,
      daily_trends: content_ab_test_results.group(:metric_name, :recorded_date).average(:metric_value),
      comparison_with_control: compare_with_control,
      traffic_allocation: {
        allocated_percentage: traffic_split,
        actual_sample_size: sample_size || 0,
        expected_sample_size: minimum_sample_size_for_variant
      },
      content_details: {
        content_type: generated_content.content_type,
        format_variant: generated_content.format_variant,
        word_count: generated_content.word_count,
        character_count: generated_content.character_count
      }
    }
  end

  # Utility methods
  def is_control_variant?
    generated_content_id == content_ab_test.control_content_id
  end

  def traffic_allocation_percentage
    "#{traffic_split}%"
  end

  def expected_daily_traffic
    return 0 unless content_ab_test.active?

    # Estimate based on campaign plan's expected reach
    # Use a default audience size if target_audience_size method doesn't exist
    audience_size = content_ab_test.campaign_plan.respond_to?(:target_audience_size) ? 
                      content_ab_test.campaign_plan.target_audience_size.to_f : 
                      10000.0 # default audience size
    daily_reach = audience_size / content_ab_test.test_duration_days
    (daily_reach * (traffic_split / 100.0)).round
  end

  private

  def set_default_metadata
    self.metadata ||= {
      creation_method: "manual",
      performance_baseline: {},
      optimization_notes: []
    }
  end

  def set_default_sample_size
    self.sample_size ||= 0
  end

  def generated_content_belongs_to_same_campaign
    return unless generated_content.present? && content_ab_test.present?

    unless generated_content.campaign_plan_id == content_ab_test.campaign_plan_id
      errors.add(:generated_content, "must belong to the same campaign as the test")
    end
  end

  def variant_name_unique_within_test
    return unless variant_name.present? && content_ab_test.present?

    existing_variant = content_ab_test.content_ab_test_variants
                         .where(variant_name: variant_name)
                         .where.not(id: id)
                         .first

    if existing_variant
      errors.add(:variant_name, "must be unique within the test")
    end
  end

  def traffic_split_reasonable
    return unless traffic_split.present?

    if traffic_split < 5
      errors.add(:traffic_split, "should be at least 5% for meaningful results")
    elsif traffic_split > 95
      errors.add(:traffic_split, "should not exceed 95% to allow for control group")
    end
  end

  def content_not_already_in_test
    return unless generated_content.present? && content_ab_test.present?

    # Check if this content is already used in another active test
    existing_test = ContentAbTestVariant
                      .joins(:content_ab_test)
                      .where(generated_content: generated_content)
                      .where(content_ab_tests: { status: %w[active paused] })
                      .where.not(content_ab_test_id: content_ab_test_id)
                      .first

    if existing_test
      errors.add(:generated_content, "is already being tested in another active A/B test")
    end
  end

  def log_variant_creation
    Rails.logger.info "A/B Test Variant created: #{variant_name} for test #{content_ab_test.test_name}"
  end

  def handle_status_changes
    case status
    when "active"
      Rails.logger.info "Variant #{variant_name} activated in test #{content_ab_test.test_name}"
    when "completed"
      Rails.logger.info "Variant #{variant_name} completed in test #{content_ab_test.test_name}"
    when "stopped"
      Rails.logger.info "Variant #{variant_name} stopped in test #{content_ab_test.test_name}"
    end
  end

  def calculate_improvement(variant_value, control_value)
    return 0.0 if control_value.zero?

    ((variant_value - control_value) / control_value * 100).round(2)
  end

  def calculate_significance(variant_stats, control_stats)
    # Simplified significance calculation
    # In production, use proper statistical tests
    variant_n = variant_stats[:count]
    control_n = control_stats[:count]

    return { significant: false, p_value: nil } if variant_n < 30 || control_n < 30

    # Placeholder for actual statistical test
    {
      significant: variant_n > 100 && control_n > 100,
      p_value: 0.05, # Placeholder
      test_type: "simplified"
    }
  end

  def calculate_standard_deviation(values)
    return 0.0 if values.empty?

    mean = values.sum.to_f / values.count
    variance = values.map { |v| (v - mean) ** 2 }.sum / values.count
    Math.sqrt(variance).round(4)
  end
end
