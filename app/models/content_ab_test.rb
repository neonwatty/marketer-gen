class ContentAbTest < ApplicationRecord
  # Associations
  belongs_to :campaign_plan
  belongs_to :created_by, class_name: "User"
  belongs_to :control_content, class_name: "GeneratedContent"
  has_many :content_ab_test_variants, dependent: :destroy
  has_many :test_contents, through: :content_ab_test_variants, source: :generated_content
  has_many :content_ab_test_results, through: :content_ab_test_variants

  # Constants
  STATUSES = %w[
    draft
    active
    paused
    completed
    stopped
    archived
  ].freeze

  GOALS = %w[
    click_rate
    conversion_rate
    engagement_rate
    open_rate
    response_rate
    share_rate
    bounce_rate
    time_on_page
    custom_metric
  ].freeze

  CONFIDENCE_LEVELS = %w[
    95
    99
    99.5
  ].freeze

  # Validations
  validates :test_name, presence: true, length: { maximum: 255 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :primary_goal, presence: true, inclusion: { in: GOALS }
  validates :confidence_level, presence: true, inclusion: { in: CONFIDENCE_LEVELS }
  validates :traffic_allocation, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :minimum_sample_size, presence: true, numericality: { greater_than: 0 }
  validates :test_duration_days, presence: true, numericality: { greater_than: 0 }

  # Custom validations
  validate :start_date_not_in_past, if: :should_validate_start_date?
  validate :end_date_after_start_date, if: [ :start_date?, :end_date? ]
  validate :control_content_belongs_to_campaign
  validate :test_duration_reasonable

  # JSON serialization
  serialize :secondary_goals, coder: JSON
  serialize :audience_segments, coder: JSON
  serialize :metadata, coder: JSON

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_campaign, ->(campaign_id) { where(campaign_plan_id: campaign_id) }
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :draft, -> { where(status: "draft") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_goal, ->(goal) { where(primary_goal: goal) }
  scope :running, -> { where(status: "active", start_date: ..Time.current) }
  scope :scheduled, -> { where(status: "active", start_date: Time.current..) }
  scope :expired, -> { where(status: "active").where("end_date < ?", Time.current) }

  # Callbacks
  before_validation :set_default_metadata, on: :create
  before_validation :calculate_end_date, if: :should_calculate_end_date?
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

  def archived?
    status == "archived"
  end

  def running?
    active? && start_date.present? && start_date <= Time.current &&
      (end_date.nil? || end_date > Time.current)
  end

  def scheduled?
    active? && start_date.present? && start_date > Time.current
  end

  def expired?
    active? && end_date.present? && end_date <= Time.current
  end

  # Test management methods
  def start_test!(start_date = nil)
    return false unless can_start?

    start_date ||= Time.current

    transaction do
      update!(
        status: "active",
        start_date: start_date,
        metadata: (metadata || {}).merge(
          started_at: Time.current,
          started_by: created_by.id
        )
      )

      # Initialize variant tracking
      content_ab_test_variants.each do |variant|
        variant.update!(
          status: "active",
          metadata: (variant.metadata || {}).merge(started_at: Time.current)
        )
      end
    end
  end

  def pause_test!
    return false unless active?

    transaction do
      update!(
        status: "paused",
        metadata: (metadata || {}).merge(
          paused_at: Time.current,
          paused_by: created_by.id
        )
      )
    end
  end

  def resume_test!
    return false unless paused?

    transaction do
      update!(
        status: "active",
        metadata: (metadata || {}).merge(
          resumed_at: Time.current,
          resumed_by: created_by.id
        )
      )
    end
  end

  def stop_test!(reason = nil)
    return false unless %w[active paused].include?(status)

    transaction do
      update!(
        status: "stopped",
        end_date: Time.current,
        metadata: (metadata || {}).merge(
          stopped_at: Time.current,
          stopped_by: created_by.id,
          stop_reason: reason
        )
      )

      # Finalize results
      finalize_test_results!
    end
  end

  def complete_test!
    return false unless can_complete?

    transaction do
      update!(
        status: "completed",
        end_date: Time.current,
        metadata: (metadata || {}).merge(
          completed_at: Time.current,
          completed_by: created_by.id
        )
      )

      # Complete all variants
      content_ab_test_variants.each do |variant|
        variant.update!(
          status: "completed",
          metadata: (variant.metadata || {}).merge(
            completed_at: Time.current
          )
        )
      end

      # Calculate final results and determine winner
      finalize_test_results!
      determine_winner!
      
      true
    end
  end

  # Variant management
  def add_variant!(content, variant_name: nil, traffic_split: nil)
    if active? || completed?
      raise RuntimeError, "Cannot add variants to an #{status} test"
    end

    transaction do
      variant = content_ab_test_variants.build(
        generated_content: content,
        variant_name: variant_name || "Variant #{content_ab_test_variants.count + 1}",
        traffic_split: traffic_split || calculate_default_traffic_split,
        status: "draft"
      )

      variant.save!

      # Rebalance traffic splits if needed
      rebalance_traffic_splits! if traffic_split.nil?

      variant
    end
  end

  def remove_variant!(variant)
    return false if active? || completed?

    transaction do
      variant.destroy!
      rebalance_traffic_splits!
    end
  end

  # Results and analysis
  def current_results
    return {} unless active? || completed? || stopped?

    results = {}

    # Control results
    control_results = content_ab_test_results.joins(:content_ab_test_variant)
                        .where(content_ab_test_variants: { generated_content: control_content })
                        .group(:metric_name)
                        .average(:metric_value)

    results[:control] = {
      content_id: control_content.id,
      content_title: control_content.title,
      metrics: control_results
    }

    # Variant results
    results[:variants] = content_ab_test_variants.includes(:generated_content, :content_ab_test_results).map do |variant|
      variant_results = variant.content_ab_test_results
                          .group(:metric_name)
                          .average(:metric_value)

      {
        variant_id: variant.id,
        variant_name: variant.variant_name,
        content_id: variant.generated_content.id,
        content_title: variant.generated_content.title,
        traffic_split: variant.traffic_split,
        status: variant.status,
        sample_size: variant.sample_size,
        metrics: variant_results
      }
    end

    # Statistical significance
    results[:statistical_analysis] = calculate_statistical_significance

    results
  end

  def winner_variant
    return nil unless completed? && winner_variant_id.present?

    if winner_variant_id == "control"
      control_content
    else
      content_ab_test_variants.find_by(id: winner_variant_id)&.generated_content
    end
  end

  def test_summary
    {
      id: id,
      test_name: test_name,
      status: status,
      primary_goal: primary_goal,
      confidence_level: confidence_level,
      traffic_allocation: traffic_allocation,
      start_date: start_date,
      end_date: end_date,
      duration_days: test_duration_days,
      variants_count: content_ab_test_variants.count,
      total_sample_size: content_ab_test_results.sum(:sample_size),
      winner: winner_variant&.title,
      statistical_significance: statistical_significance_achieved?,
      campaign_name: campaign_plan.name,
      created_by: created_by.full_name,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def can_start?
    draft? && content_ab_test_variants.exists?
  end

  def can_complete?
    active? && minimum_sample_size_reached?
  end

  def minimum_sample_size_reached?
    content_ab_test_results.sum(:sample_size) >= minimum_sample_size
  end

  def test_duration_reached?
    return false unless start_date.present?

    Date.current >= start_date.to_date + test_duration_days.days
  end

  def statistical_significance_achieved?
    significance_data = calculate_statistical_significance
    significance_data[:significant] == true
  end

  # Analytics and reporting
  def daily_performance_data
    content_ab_test_results
      .group(:recorded_date, :metric_name)
      .group("content_ab_test_variants.variant_name")
      .joins(:content_ab_test_variant)
      .average(:metric_value)
  end

  def conversion_funnel_data
    funnel_metrics = %w[impression click conversion]

    content_ab_test_variants.includes(:content_ab_test_results).map do |variant|
      funnel_data = {}

      funnel_metrics.each do |metric|
        funnel_data[metric] = variant.content_ab_test_results
                                .where(metric_name: metric)
                                .sum(:metric_value)
      end

      {
        variant_name: variant.variant_name,
        funnel: funnel_data,
        conversion_rate: calculate_conversion_rate(funnel_data)
      }
    end
  end

  # Search and filtering
  def self.search_tests(query)
    return all if query.blank?

    where(
      "LOWER(test_name) LIKE LOWER(?) OR LOWER(description) LIKE LOWER(?)",
      "%#{query}%", "%#{query}%"
    )
  end

  def self.for_campaign_and_goal(campaign_id, goal)
    by_campaign(campaign_id).by_goal(goal)
  end

  def self.analytics_summary
    {
      total_tests: count,
      by_status: group(:status).count,
      by_goal: group(:primary_goal).count,
      active_tests: active.count,
      completed_tests: completed.count,
      average_duration: completed.average(:test_duration_days),
      total_variants_tested: joins(:content_ab_test_variants).count,
      tests_with_significant_results: completed.where(statistical_significance: true).count
    }
  end

  private

  def set_default_metadata
    self.metadata ||= {
      creation_method: "manual",
      test_type: "content_variant",
      auto_stop_enabled: true,
      notifications_enabled: true
    }

    self.secondary_goals ||= []
    self.audience_segments ||= [ "all_users" ]
  end

  def should_calculate_end_date?
    start_date.present? && test_duration_days.present? && end_date.blank?
  end

  def should_validate_start_date?
    # Only validate start_date for new records and only during validation (not save)
    start_date.present? && new_record? && id.nil?
  end

  def calculate_end_date
    self.end_date = start_date + test_duration_days.days
  end

  def start_date_not_in_past
    if start_date < Time.current.beginning_of_day
      errors.add(:start_date, "cannot be in the past")
    end
  end

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?

    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def control_content_belongs_to_campaign
    return unless control_content.present? && campaign_plan.present?

    unless control_content.campaign_plan_id == campaign_plan_id
      errors.add(:control_content, "must belong to the same campaign")
    end
  end

  def test_duration_reasonable
    return unless test_duration_days.present?

    if test_duration_days > 365
      errors.add(:test_duration_days, "cannot exceed 365 days")
    elsif test_duration_days < 1
      errors.add(:test_duration_days, "must be at least 1 day")
    end
  end

  def handle_status_changes
    case status
    when "active"
      handle_test_activation
    when "completed"
      handle_test_completion
    when "stopped"
      handle_test_stop
    end
  end

  def handle_test_activation
    # Notify relevant parties about test start
    # This could trigger emails, webhooks, etc.
    Rails.logger.info "A/B Test #{id} (#{test_name}) has been activated"
  end

  def handle_test_completion
    # Handle test completion logic
    Rails.logger.info "A/B Test #{id} (#{test_name}) has been completed"
  end

  def handle_test_stop
    # Handle test stop logic
    Rails.logger.info "A/B Test #{id} (#{test_name}) has been stopped"
  end

  def calculate_default_traffic_split
    variant_count = content_ab_test_variants.count + 1 # +1 for the new variant
    (100.0 / variant_count).round(2)
  end

  def rebalance_traffic_splits!
    variants = content_ab_test_variants.reload.to_a
    return if variants.empty?

    equal_split = (100.0 / variants.count).round(2)

    variants.each do |variant|
      variant.reload.update!(traffic_split: equal_split)
    end
  end

  def finalize_test_results!
    # Calculate final metrics and statistical significance
    self.update!(
      statistical_significance: statistical_significance_achieved?,
      metadata: (metadata || {}).merge(
        final_sample_size: content_ab_test_results.sum(:sample_size),
        finalized_at: Time.current
      )
    )
  end

  def determine_winner!
    return unless statistical_significance_achieved?

    best_performance = nil
    winner_id = nil

    # Compare control vs variants
    control_performance = get_performance_metric(control_content)
    best_performance = control_performance
    winner_id = "control"

    content_ab_test_variants.each do |variant|
      variant_performance = get_performance_metric(variant.generated_content)

      if variant_performance > best_performance
        best_performance = variant_performance
        winner_id = variant.id
      end
    end

    update!(winner_variant_id: winner_id)
  end

  def get_performance_metric(content)
    # Get the primary goal metric for the given content
    content_ab_test_results
      .joins(:content_ab_test_variant)
      .where(
        content_ab_test_variants: { generated_content: content },
        metric_name: primary_goal
      )
      .average(:metric_value) || 0.0
  end

  def calculate_statistical_significance
    # Simplified statistical significance calculation
    # In a real implementation, you'd use proper statistical tests
    # like Chi-square, T-test, or Z-test depending on the metric type

    return { significant: false, confidence: 0 } unless active? || completed?

    sample_sizes = content_ab_test_results.group(:content_ab_test_variant_id).sum(:sample_size)
    return { significant: false, confidence: 0 } if sample_sizes.values.min.to_i < 100

    # Placeholder calculation - implement proper statistical tests
    confidence = [ confidence_level.to_f, 95.0 ].min
    significant = minimum_sample_size_reached? && test_duration_reached?

    {
      significant: significant,
      confidence: confidence,
      sample_sizes: sample_sizes,
      calculation_method: "simplified"
    }
  end

  def calculate_conversion_rate(funnel_data)
    impressions = funnel_data["impression"].to_f
    conversions = funnel_data["conversion"].to_f

    return 0.0 if impressions.zero?

    (conversions / impressions * 100).round(2)
  end
end
