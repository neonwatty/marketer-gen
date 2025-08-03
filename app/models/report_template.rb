# frozen_string_literal: true

# ReportTemplate model for predefined report configurations
# Provides templates that users can use to create reports quickly
class ReportTemplate < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, length: { maximum: 100 }
  validates :category, presence: true, inclusion: {
    in: %w[marketing sales analytics performance social_media email_marketing general]
  }
  validates :template_type, presence: true, inclusion: {
    in: %w[standard dashboard summary detailed custom]
  }
  validates :configuration, presence: true
  validates :rating, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 5
  }
  validates :usage_count, numericality: { greater_than_or_equal_to: 0 }
  validates :rating_count, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :public_templates, -> { where(is_public: true, is_active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :popular, -> { where("usage_count > ?", 10).order(usage_count: :desc) }
  scope :highly_rated, -> { where("rating >= ? AND rating_count >= ?", 4.0, 5) }
  scope :recent, -> { order(created_at: :desc) }

  before_validation :set_defaults

  # Create a custom report from this template
  def instantiate_for(user:, brand:, report_name: nil)
    CustomReport.create!(
      user: user,
      brand: brand,
      name: report_name || name,
      description: description,
      report_type: template_type,
      configuration: configuration.deep_dup,
      status: "draft"
    ).tap do |report|
      # Copy template metrics if they exist in configuration
      create_metrics_from_template(report)
      increment_usage!
    end
  end

  # Rate this template
  def add_rating(new_rating)
    return false unless new_rating.between?(1, 5)

    transaction do
      total_points = (rating * rating_count) + new_rating
      self.rating_count += 1
      self.rating = (total_points / rating_count.to_f).round(2)
      save!
    end
    true
  end

  # Increment usage count
  def increment_usage!
    increment!(:usage_count)
  end

  # Get template categories with counts
  def self.categories_with_counts
    group(:category).count
  end

  # Get popular templates by category
  def self.popular_by_category(category)
    by_category(category).popular.limit(5)
  end

  # Search templates
  def self.search(query)
    return all if query.blank?

    where(
      "name ILIKE ? OR description ILIKE ? OR category ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end

  # Get template with default metrics configuration
  def self.create_with_metrics(attributes, metrics_config = [])
    template = create!(attributes)

    # Store metrics configuration in the template
    if metrics_config.any?
      config = template.configuration.deep_dup
      config[:default_metrics] = metrics_config
      template.update!(configuration: config)
    end

    template
  end

  private

  def set_defaults
    self.configuration ||= default_configuration
    self.is_active = true if is_active.nil?
    self.is_public = false if is_public.nil?
    self.usage_count ||= 0
    self.rating ||= 0.0
    self.rating_count ||= 0
  end

  def default_configuration
    {
      date_range: { type: "last_30_days" },
      visualizations: [],
      layout: { columns: 2, responsive: true },
      filters: {},
      styling: {
        theme: "default",
        colors: [ "#3B82F6", "#10B981", "#F59E0B", "#EF4444" ],
        font_size: "medium"
      },
      default_metrics: []
    }
  end

  def create_metrics_from_template(report)
    return unless configuration[:default_metrics]&.any?

    configuration[:default_metrics].each_with_index do |metric_config, index|
      report.report_metrics.create!(
        metric_name: metric_config[:metric_name],
        display_name: metric_config[:display_name] || metric_config[:metric_name].humanize,
        data_source: metric_config[:data_source],
        aggregation_type: metric_config[:aggregation_type] || "sum",
        filters: metric_config[:filters] || {},
        visualization_config: metric_config[:visualization_config] || {},
        sort_order: index + 1
      )
    end
  end
end
