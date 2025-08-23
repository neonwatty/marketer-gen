class ContentAbTestResult < ApplicationRecord
  # Associations
  belongs_to :content_ab_test_variant
  has_one :content_ab_test, through: :content_ab_test_variant
  has_one :generated_content, through: :content_ab_test_variant

  # Constants
  METRIC_TYPES = %w[
    click_rate
    conversion_rate
    engagement_rate
    open_rate
    response_rate
    share_rate
    bounce_rate
    time_on_page
    impressions
    clicks
    conversions
    shares
    likes
    comments
    views
    downloads
    signups
    purchases
    revenue
    cost_per_click
    cost_per_conversion
    return_on_ad_spend
    custom_metric
  ].freeze

  DATA_SOURCES = %w[
    manual
    google_analytics
    facebook_ads
    google_ads
    linkedin_ads
    twitter_ads
    email_platform
    website_tracking
    mobile_app
    api_integration
    webhook
    csv_import
    automated_tracking
  ].freeze

  # Validations
  validates :metric_name, presence: true, inclusion: { in: METRIC_TYPES }
  validates :metric_value, presence: true, numericality: true
  validates :sample_size, presence: true, numericality: { greater_than: 0 }
  validates :recorded_date, presence: true
  validates :data_source, inclusion: { in: DATA_SOURCES }, allow_blank: true

  # Custom validations
  validate :recorded_date_not_in_future
  validate :metric_value_reasonable_for_type
  validate :variant_belongs_to_active_test

  # JSON serialization
  serialize :metadata, coder: JSON

  # Scopes
  scope :by_metric, ->(metric_name) { where(metric_name: metric_name) }
  scope :by_variant, ->(variant_id) { where(content_ab_test_variant_id: variant_id) }
  scope :by_date_range, ->(start_date, end_date) { where(recorded_date: start_date..end_date) }
  scope :recent, -> { order(recorded_date: :desc) }
  scope :by_data_source, ->(source) { where(data_source: source) }
  scope :conversion_metrics, -> { where(metric_name: %w[conversion_rate conversions signups purchases revenue]) }
  scope :engagement_metrics, -> { where(metric_name: %w[engagement_rate clicks shares likes comments]) }
  scope :traffic_metrics, -> { where(metric_name: %w[impressions views click_rate]) }
  scope :today, -> { where(recorded_date: Date.current) }
  scope :this_week, -> { where(recorded_date: 1.week.ago..Date.current) }
  scope :this_month, -> { where(recorded_date: 1.month.ago..Date.current) }

  # Callbacks
  before_validation :set_default_metadata, on: :create
  before_validation :set_default_data_source, on: :create
  after_create :update_variant_sample_size
  after_create :trigger_significance_check

  # Analytics methods
  def conversion_value
    return 0.0 unless %w[revenue purchases].include?(metric_name)

    metric_value * sample_size
  end

  def cost_efficiency
    return nil unless metric_name.include?("cost_per")

    case metric_name
    when "cost_per_click"
      sample_size / metric_value if metric_value > 0
    when "cost_per_conversion"
      (sample_size / metric_value) if metric_value > 0
    else
      nil
    end
  end

  def performance_rating
    # Simple performance rating based on metric type and value
    case metric_name
    when "click_rate", "conversion_rate", "engagement_rate", "open_rate", "response_rate"
      case metric_value
      when 0..1 then "poor"
      when 1..3 then "fair"
      when 3..5 then "good"
      when 5..10 then "very_good"
      else "excellent"
      end
    when "bounce_rate"
      # Lower is better for bounce rate
      case metric_value
      when 0..20 then "excellent"
      when 20..40 then "very_good"
      when 40..60 then "good"
      when 60..80 then "fair"
      else "poor"
      end
    else
      "unrated"
    end
  end

  def is_conversion_metric?
    %w[conversion_rate conversions signups purchases revenue].include?(metric_name)
  end

  def is_engagement_metric?
    %w[engagement_rate clicks shares likes comments views].include?(metric_name)
  end

  def is_traffic_metric?
    %w[impressions click_rate views].include?(metric_name)
  end

  def is_cost_metric?
    metric_name.include?("cost_per") || metric_name == "return_on_ad_spend"
  end

  # Data quality methods
  def data_quality_score
    score = 100

    # Deduct points for missing metadata
    score -= 10 if metadata.blank?
    score -= 5 if data_source.blank?

    # Deduct points for unusual values
    score -= 15 if metric_value_unusual?
    score -= 10 if sample_size < expected_minimum_sample_size

    # Deduct points for late recording
    score -= 5 if recorded_date < Date.current - 7.days

    [ score, 0 ].max
  end

  def has_high_confidence?
    sample_size >= expected_minimum_sample_size && data_quality_score >= 80
  end

  def expected_minimum_sample_size
    case metric_name
    when "conversion_rate", "click_rate"
      100
    when "engagement_rate", "response_rate"
      50
    when "revenue", "purchases"
      30
    else
      20
    end
  end

  # Comparison methods
  def compare_with_previous_period(days_back = 7)
    previous_date = recorded_date - days_back.days

    previous_result = ContentAbTestResult
                        .where(content_ab_test_variant: content_ab_test_variant)
                        .where(metric_name: metric_name)
                        .where(recorded_date: previous_date)
                        .first

    return nil unless previous_result

    improvement = ((metric_value - previous_result.metric_value) / previous_result.metric_value * 100).round(2)

    {
      current_value: metric_value,
      previous_value: previous_result.metric_value,
      improvement_percent: improvement,
      is_better: improvement > 0,
      previous_date: previous_date
    }
  end

  def daily_trend(days = 7)
    end_date = recorded_date
    start_date = end_date - days.days

    ContentAbTestResult
      .where(content_ab_test_variant: content_ab_test_variant)
      .where(metric_name: metric_name)
      .where(recorded_date: start_date..end_date)
      .group(:recorded_date)
      .order(:recorded_date)
      .average(:metric_value)
  end

  # Export and reporting
  def to_analytics_hash
    {
      test_id: content_ab_test.id,
      test_name: content_ab_test.test_name,
      variant_id: content_ab_test_variant.id,
      variant_name: content_ab_test_variant.variant_name,
      content_id: generated_content.id,
      content_title: generated_content.title,
      metric_name: metric_name,
      metric_value: metric_value,
      sample_size: sample_size,
      recorded_date: recorded_date,
      data_source: data_source,
      performance_rating: performance_rating,
      conversion_value: conversion_value,
      data_quality_score: data_quality_score,
      metadata: metadata
    }
  end

  def formatted_metric_value
    case metric_name
    when "click_rate", "conversion_rate", "engagement_rate", "open_rate", "response_rate", "bounce_rate"
      "#{metric_value.round(2)}%"
    when "revenue"
      "$#{metric_value.round(2)}"
    when "cost_per_click", "cost_per_conversion"
      "$#{metric_value.round(2)}"
    when "time_on_page"
      "#{metric_value.round(0)} seconds"
    else
      # Format numbers appropriately - show as integer if it's a whole number
      if metric_value == metric_value.to_i
        metric_value.to_i.to_s
      else
        metric_value.to_s
      end
    end
  end

  # Batch operations
  def self.bulk_create_results(results_data)
    return [] if results_data.blank?

    results = []

    transaction do
      results_data.each do |result_data|
        result = create!(
          content_ab_test_variant_id: result_data[:variant_id],
          metric_name: result_data[:metric_name],
          metric_value: result_data[:metric_value],
          sample_size: result_data[:sample_size] || 1,
          recorded_date: result_data[:date] || Date.current,
          data_source: result_data[:data_source] || "api_integration",
          metadata: result_data[:metadata] || {}
        )

        results << result
      end
    end

    results
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to bulk create A/B test results: #{e.message}"
    []
  end

  def self.aggregate_by_metric(metric_name, variant_ids = nil, date_range = nil)
    query = where(metric_name: metric_name)
    query = query.where(content_ab_test_variant_id: variant_ids) if variant_ids.present?
    query = query.where(recorded_date: date_range) if date_range.present?

    {
      total_value: query.sum(:metric_value),
      average_value: query.average(:metric_value)&.round(4) || 0.0,
      total_sample_size: query.sum(:sample_size),
      count: query.count,
      date_range: date_range || (query.minimum(:recorded_date)..query.maximum(:recorded_date))
    }
  end

  def self.performance_summary_by_variant(variant_id, date_range = nil)
    query = where(content_ab_test_variant_id: variant_id)
    query = query.where(recorded_date: date_range) if date_range.present?

    summary = {}

    # Group by metric_name and process each group
    metrics = query.distinct.pluck(:metric_name)
    
    metrics.each do |metric_name|
      metric_results = query.where(metric_name: metric_name)
      values = metric_results.pluck(:metric_value)
      sample_sizes = metric_results.pluck(:sample_size)

      summary[metric_name] = {
        average: values.sum.to_f / values.count,
        total: values.sum,
        total_sample_size: sample_sizes.sum,
        count: values.count,
        min: values.min,
        max: values.max,
        latest_date: metric_results.maximum(:recorded_date)
      }
    end

    summary
  end

  # Search and filtering
  def self.search_results(query)
    return all if query.blank?

    joins(:content_ab_test_variant, :content_ab_test)
      .where(
        "LOWER(content_ab_tests.test_name) LIKE LOWER(?) OR LOWER(content_ab_test_variants.variant_name) LIKE LOWER(?) OR LOWER(metric_name) LIKE LOWER(?)",
        "%#{query}%", "%#{query}%", "%#{query}%"
      )
  end

  private

  def set_default_metadata
    self.metadata ||= {
      recorded_by: "system",
      data_quality_checked: false,
      anomaly_detected: false
    }
  end

  def set_default_data_source
    self.data_source ||= "manual"
  end

  def recorded_date_not_in_future
    return unless recorded_date.present?

    if recorded_date > Date.current
      errors.add(:recorded_date, "cannot be in the future")
    end
  end

  def metric_value_reasonable_for_type
    return unless metric_value.present? && metric_name.present?

    case metric_name
    when "click_rate", "conversion_rate", "engagement_rate", "open_rate", "response_rate", "bounce_rate"
      if metric_value < 0 || metric_value > 100
        errors.add(:metric_value, "for #{metric_name} should be between 0 and 100")
      end
    when "time_on_page"
      if metric_value < 0 || metric_value > 86400 # 24 hours in seconds
        errors.add(:metric_value, "for time on page should be reasonable (0-86400 seconds)")
      end
    when "revenue", "cost_per_click", "cost_per_conversion"
      if metric_value < 0
        errors.add(:metric_value, "for #{metric_name} cannot be negative")
      end
    end
  end

  def variant_belongs_to_active_test
    return unless content_ab_test_variant.present?

    test = content_ab_test_variant.content_ab_test

    unless %w[active paused completed].include?(test.status)
      errors.add(:content_ab_test_variant, "must belong to an active, paused, or completed test")
    end
  end

  def update_variant_sample_size
    # This is handled in the variant model's record_result! method
    # But we could add additional logic here if needed
  end

  def trigger_significance_check
    # Trigger significance check if certain conditions are met
    variant = content_ab_test_variant
    test = variant.content_ab_test

    return unless test.active?

    # Check if we should evaluate statistical significance
    if variant.sample_size >= variant.minimum_sample_size_for_variant
      # This could trigger a background job to calculate significance
      Rails.logger.info "Significance check triggered for test #{test.id}, variant #{variant.id}"
    end
  end

  def metric_value_unusual?
    # Simple anomaly detection
    case metric_name
    when "click_rate", "conversion_rate", "engagement_rate"
      metric_value > 50 || metric_value < 0
    when "bounce_rate"
      metric_value > 95 || metric_value < 0
    when "time_on_page"
      metric_value > 3600 || metric_value < 1 # More than 1 hour or less than 1 second
    else
      false
    end
  end
end
