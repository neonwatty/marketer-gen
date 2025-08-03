# frozen_string_literal: true

# ReportMetric model for individual metrics within reports
# Defines what data to collect and how to aggregate it
class ReportMetric < ApplicationRecord
  belongs_to :custom_report

  validates :metric_name, presence: true
  validates :data_source, presence: true, inclusion: {
    in: CustomReport.available_data_sources
  }
  validates :aggregation_type, presence: true, inclusion: {
    in: %w[sum count average min max median first last distinct]
  }
  validates :sort_order, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(is_active: true) }
  scope :by_data_source, ->(source) { where(data_source: source) }
  scope :ordered, -> { order(:sort_order) }

  before_validation :set_defaults

  # Get the friendly display name
  def display_name_or_default
    display_name.presence || metric_name.humanize
  end

  # Check if metric has custom visualization
  def has_custom_visualization?
    visualization_config.present? && visualization_config.any?
  end

  # Get visualization type for this metric
  def visualization_type
    visualization_config[:type] || "metric_card"
  end

  # Get the data query configuration
  def query_config
    {
      metric: metric_name,
      aggregation: aggregation_type,
      source: data_source,
      filters: filters || {},
      time_dimension: time_dimension
    }
  end

  # Available metrics by data source
  def self.available_metrics_for(data_source)
    case data_source
    when "google_analytics"
      %w[
        page_views sessions users bounce_rate session_duration
        new_users returning_users goal_completions conversion_rate
      ]
    when "google_ads"
      %w[
        impressions clicks ctr cost conversions conversion_rate
        cost_per_click cost_per_conversion quality_score
      ]
    when "social_media"
      %w[
        followers engagement_rate likes shares comments reach
        impressions clicks profile_visits
      ]
    when "email_marketing"
      %w[
        sent_emails delivered_emails open_rate click_rate
        unsubscribe_rate bounce_rate revenue_per_email
      ]
    when "crm"
      %w[
        leads opportunities revenue deals_won deals_lost
        conversion_rate pipeline_value average_deal_size
      ]
    when "campaigns"
      %w[
        active_campaigns campaign_performance total_spend
        campaign_roi campaign_reach campaign_frequency
      ]
    when "journeys"
      %w[
        journey_completions completion_rate step_conversion_rate
        average_journey_time drop_off_rate engagement_score
      ]
    when "ab_tests"
      %w[
        test_participants conversion_rate_lift confidence_level
        statistical_significance winner_revenue_impact
      ]
    when "conversion_funnels"
      %w[
        funnel_conversion_rate step_completion_rate drop_off_rate
        time_to_convert average_funnel_time
      ]
    else
      []
    end
  end

  # Get appropriate aggregation types for metric
  def self.aggregation_types_for(metric_name)
    rate_metrics = %w[
      bounce_rate conversion_rate ctr open_rate click_rate
      unsubscribe_rate completion_rate engagement_rate
    ]

    if rate_metrics.include?(metric_name)
      %w[average median]
    elsif metric_name.include?("count") || metric_name.include?("total")
      %w[sum count]
    else
      %w[sum count average min max median]
    end
  end

  private

  def set_defaults
    self.filters ||= {}
    self.visualization_config ||= {}
    self.is_active = true if is_active.nil?
    self.sort_order ||= (custom_report&.report_metrics&.maximum(:sort_order) || 0) + 1
    self.display_name ||= metric_name&.humanize if metric_name
  end

  def time_dimension
    case data_source
    when "google_analytics", "google_ads"
      "date"
    when "crm"
      "created_at"
    when "campaigns", "journeys"
      "created_at"
    else
      "created_at"
    end
  end
end
