# frozen_string_literal: true

# CustomReport model for the custom reporting system
# Represents user-created reports with configurable metrics and visualizations
class CustomReport < ApplicationRecord
  belongs_to :user
  belongs_to :brand

  has_many :report_metrics, dependent: :destroy
  has_many :report_schedules, dependent: :destroy
  has_many :report_exports, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :report_type, presence: true, inclusion: { in: %w[standard dashboard summary detailed custom] }
  validates :status, presence: true, inclusion: { in: %w[draft active archived] }
  validates :configuration, presence: true

  scope :active, -> { where(status: "active") }
  scope :templates, -> { where(is_template: true) }
  scope :public_templates, -> { where(is_template: true, is_public: true) }
  scope :by_type, ->(type) { where(report_type: type) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :by_generation_time, -> { order(generation_time_ms: :asc) }

  before_validation :set_defaults
  after_create :create_default_metrics

  # Check if report can be generated quickly (< 30 seconds)
  def fast_generation?
    generation_time_ms.nil? || generation_time_ms < 30_000
  end

  # Get the estimated generation time
  def estimated_generation_time
    return "Unknown" if generation_time_ms.nil?

    case generation_time_ms
    when 0...5_000
      "Very Fast (< 5s)"
    when 5_000...15_000
      "Fast (5-15s)"
    when 15_000...30_000
      "Moderate (15-30s)"
    else
      "Slow (> 30s)"
    end
  end

  # Create a copy of this report
  def duplicate(new_name: nil)
    dup.tap do |copy|
      copy.name = new_name || "#{name} (Copy)"
      copy.status = "draft"
      copy.is_template = false
      copy.last_generated_at = nil
      copy.generation_time_ms = nil
      copy.save!

      # Copy metrics
      report_metrics.each do |metric|
        copy.report_metrics.create!(metric.attributes.except("id", "custom_report_id", "created_at", "updated_at"))
      end
    end
  end

  # Convert to template
  def convert_to_template(template_name: nil, make_public: false)
    update!(
      is_template: true,
      is_public: make_public,
      name: template_name || "#{name} Template"
    )
  end

  # Get available data sources
  def self.available_data_sources
    %w[
      google_analytics
      google_ads
      social_media
      email_marketing
      crm
      campaigns
      journeys
      ab_tests
      conversion_funnels
    ]
  end

  # Get available visualization types
  def self.visualization_types
    %w[
      line_chart
      bar_chart
      pie_chart
      donut_chart
      area_chart
      table
      metric_card
      gauge
      heatmap
      funnel
    ]
  end

  private

  def set_defaults
    self.configuration ||= default_configuration
    self.status ||= "draft"
    self.report_type ||= "standard"
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
      }
    }
  end

  def create_default_metrics
    return if is_template? || report_metrics.any?

    # Create some default metrics based on report type
    case report_type
    when "dashboard"
      create_dashboard_metrics
    when "summary"
      create_summary_metrics
    else
      create_standard_metrics
    end
  end

  def create_dashboard_metrics
    report_metrics.create!([
      {
        metric_name: "total_visitors",
        display_name: "Total Visitors",
        data_source: "google_analytics",
        aggregation_type: "sum",
        sort_order: 1
      },
      {
        metric_name: "conversion_rate",
        display_name: "Conversion Rate",
        data_source: "google_analytics",
        aggregation_type: "average",
        sort_order: 2
      },
      {
        metric_name: "revenue",
        display_name: "Revenue",
        data_source: "crm",
        aggregation_type: "sum",
        sort_order: 3
      }
    ])
  end

  def create_summary_metrics
    report_metrics.create!([
      {
        metric_name: "campaign_performance",
        display_name: "Campaign Performance",
        data_source: "campaigns",
        aggregation_type: "average",
        sort_order: 1
      },
      {
        metric_name: "total_leads",
        display_name: "Total Leads",
        data_source: "crm",
        aggregation_type: "count",
        sort_order: 2
      }
    ])
  end

  def create_standard_metrics
    report_metrics.create!([
      {
        metric_name: "page_views",
        display_name: "Page Views",
        data_source: "google_analytics",
        aggregation_type: "sum",
        sort_order: 1
      }
    ])
  end
end
