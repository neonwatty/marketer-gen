# frozen_string_literal: true

class CrmAnalytics < ApplicationRecord
  # Metric types for analytics
  METRIC_TYPES = %w[
    daily
    weekly
    monthly
    quarterly
    yearly
    campaign_specific
    pipeline_snapshot
    conversion_funnel
    attribution_analysis
    velocity_analysis
  ].freeze

  # Lifecycle stages for progression analysis
  LIFECYCLE_STAGES = %w[subscriber lead marketing_qualified_lead sales_qualified_lead opportunity customer].freeze

  # Associations
  belongs_to :crm_integration
  belongs_to :brand

  # Validations
  validates :analytics_date, presence: true
  validates :metric_type, presence: true, inclusion: { in: METRIC_TYPES }
  validates :analytics_date, uniqueness: { scope: [ :crm_integration_id, :metric_type ] }

  # Scopes
  scope :by_metric_type, ->(type) { where(metric_type: type) }
  scope :by_date_range, ->(start_date, end_date) { where(analytics_date: start_date..end_date) }
  scope :recent, -> { where("analytics_date > ?", 30.days.ago) }
  scope :current_month, -> { where(analytics_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :current_quarter, -> { where(analytics_date: Date.current.beginning_of_quarter..Date.current.end_of_quarter) }
  scope :current_year, -> { where(analytics_date: Date.current.beginning_of_year..Date.current.end_of_year) }

  # Lead performance metrics
  def lead_performance_summary
    {
      total_leads: total_leads || 0,
      new_leads: new_leads || 0,
      mql_count: marketing_qualified_leads || 0,
      sql_count: sales_qualified_leads || 0,
      converted_leads: converted_leads || 0,
      lead_conversion_rate: lead_conversion_rate || 0.0,
      mql_conversion_rate: mql_conversion_rate || 0.0,
      sql_conversion_rate: sql_conversion_rate || 0.0
    }
  end

  # Opportunity performance metrics
  def opportunity_performance_summary
    {
      total_opportunities: total_opportunities || 0,
      new_opportunities: new_opportunities || 0,
      closed_opportunities: closed_opportunities || 0,
      won_opportunities: won_opportunities || 0,
      lost_opportunities: lost_opportunities || 0,
      win_rate: opportunity_win_rate || 0.0,
      total_value: total_opportunity_value || 0.0,
      won_value: won_opportunity_value || 0.0,
      average_deal_size: average_deal_size || 0.0
    }
  end

  # Pipeline performance metrics
  def pipeline_performance_summary
    {
      pipeline_velocity: pipeline_velocity || 0.0,
      average_sales_cycle: average_sales_cycle_days || 0.0,
      pipeline_value: pipeline_value || 0.0,
      pipeline_count: pipeline_count || 0,
      weighted_pipeline_value: weighted_pipeline_value || 0.0
    }
  end

  # Conversion funnel metrics
  def conversion_funnel_summary
    {
      marketing_to_sales_rate: marketing_to_sales_conversion_rate || 0.0,
      lead_to_opportunity_rate: lead_to_opportunity_conversion_rate || 0.0,
      opportunity_to_customer_rate: opportunity_to_customer_conversion_rate || 0.0,
      overall_conversion_rate: overall_conversion_rate || 0.0
    }
  end

  # Time-based performance metrics
  def time_based_metrics_summary
    {
      time_to_mql_hours: time_to_mql_hours || 0.0,
      time_to_sql_hours: time_to_sql_hours || 0.0,
      time_to_opportunity_hours: time_to_opportunity_hours || 0.0,
      time_to_close_hours: time_to_close_hours || 0.0
    }
  end

  # Attribution performance
  def attribution_performance_summary
    {
      top_campaign: top_performing_campaign,
      campaign_revenue: campaign_attributed_revenue || 0.0,
      campaign_leads: campaign_attributed_leads || 0,
      campaign_opportunities: campaign_attributed_opportunities || 0,
      attribution_breakdown: attribution_breakdown || {}
    }
  end

  # ROI calculations
  def calculate_roi_metrics
    return {} unless campaign_attributed_revenue.present? && campaign_attributed_revenue > 0

    # Estimate marketing spend (this would ideally come from campaign data)
    estimated_spend = campaign_attributed_revenue * 0.2  # Assume 20% marketing cost ratio

    {
      estimated_marketing_spend: estimated_spend,
      marketing_roi: ((campaign_attributed_revenue - estimated_spend) / estimated_spend * 100).round(2),
      revenue_per_lead: campaign_attributed_leads > 0 ? (campaign_attributed_revenue / campaign_attributed_leads).round(2) : 0,
      revenue_per_opportunity: campaign_attributed_opportunities > 0 ? (campaign_attributed_revenue / campaign_attributed_opportunities).round(2) : 0
    }
  end

  # Performance scoring
  def performance_score
    score = 0
    max_score = 100

    # Lead performance (25% of total score)
    if total_leads && total_leads > 0
      lead_score = [ lead_conversion_rate || 0, 25 ].min
      score += lead_score
    end

    # Opportunity performance (35% of total score)
    if total_opportunities && total_opportunities > 0
      opp_score = [ (opportunity_win_rate || 0) * 0.35, 35 ].min
      score += opp_score
    end

    # Pipeline efficiency (25% of total score)
    if pipeline_velocity && pipeline_velocity > 0
      # Normalize pipeline velocity to 0-25 scale
      velocity_score = [ pipeline_velocity / 1000 * 25, 25 ].min
      score += velocity_score
    end

    # Conversion efficiency (15% of total score)
    if overall_conversion_rate && overall_conversion_rate > 0
      conversion_score = [ overall_conversion_rate * 0.15, 15 ].min
      score += conversion_score
    end

    [ score, max_score ].min.round(2)
  end

  # Trend analysis
  def trend_comparison(previous_period)
    return {} unless previous_period.is_a?(CrmAnalytics)

    {
      leads_trend: calculate_percentage_change(total_leads, previous_period.total_leads),
      opportunities_trend: calculate_percentage_change(total_opportunities, previous_period.total_opportunities),
      revenue_trend: calculate_percentage_change(won_opportunity_value, previous_period.won_opportunity_value),
      conversion_rate_trend: calculate_percentage_change(overall_conversion_rate, previous_period.overall_conversion_rate),
      pipeline_velocity_trend: calculate_percentage_change(pipeline_velocity, previous_period.pipeline_velocity),
      win_rate_trend: calculate_percentage_change(opportunity_win_rate, previous_period.opportunity_win_rate)
    }
  end

  # Health scoring
  def crm_health_score
    health_factors = []

    # Data freshness (0-25 points)
    days_since_calculation = (Time.current - calculated_at) / 1.day
    freshness_score = case days_since_calculation
    when 0..1 then 25
    when 1..3 then 20
    when 3..7 then 15
    when 7..14 then 10
    else 0
    end
    health_factors << freshness_score

    # Lead volume health (0-25 points)
    lead_volume_score = case total_leads || 0
    when 0 then 0
    when 1..10 then 10
    when 11..50 then 20
    else 25
    end
    health_factors << lead_volume_score

    # Conversion rate health (0-25 points)
    conversion_score = case overall_conversion_rate || 0
    when 0 then 0
    when 0.1..2 then 10
    when 2.1..5 then 20
    else 25
    end
    health_factors << conversion_score

    # Pipeline health (0-25 points)
    pipeline_score = case pipeline_count || 0
    when 0 then 0
    when 1..5 then 10
    when 6..20 then 20
    else 25
    end
    health_factors << pipeline_score

    health_factors.sum
  end

  # Channel performance breakdown
  def channel_performance_analysis
    performance = channel_performance || {}

    performance.map do |channel, metrics|
      {
        channel: channel,
        leads: metrics["leads"] || 0,
        opportunities: metrics["opportunities"] || 0,
        revenue: metrics["revenue"] || 0.0,
        conversion_rate: metrics["conversion_rate"] || 0.0,
        roi: metrics["roi"] || 0.0
      }
    end.sort_by { |channel| -channel[:revenue] }
  end

  # Campaign performance ranking
  def top_performing_campaigns(limit = 5)
    campaigns = campaign_performance || {}

    campaigns.map do |campaign_id, metrics|
      {
        campaign_id: campaign_id,
        leads: metrics["leads"] || 0,
        opportunities: metrics["opportunities"] || 0,
        revenue: metrics["revenue"] || 0.0,
        conversion_rate: metrics["conversion_rate"] || 0.0,
        cost_per_lead: metrics["cost_per_lead"] || 0.0,
        roi: metrics["roi"] || 0.0
      }
    end.sort_by { |campaign| -campaign[:revenue] }.first(limit)
  end

  # Lifecycle stage efficiency
  def lifecycle_stage_efficiency
    stages = lifecycle_stage_breakdown || {}
    progression = stage_progression_metrics || {}

    LIFECYCLE_STAGES.map.with_index do |stage, index|
      next_stage = LIFECYCLE_STAGES[index + 1]

      current_count = stages[stage] || 0
      next_count = next_stage ? stages[next_stage] || 0 : 0

      progression_rate = current_count > 0 ? (next_count.to_f / current_count * 100).round(2) : 0
      avg_time = progression.dig(stage, "average_time_hours") || 0

      {
        stage: stage,
        count: current_count,
        progression_rate: progression_rate,
        average_time_hours: avg_time,
        next_stage: next_stage
      }
    end.compact
  end

  # Export summary for reporting
  def export_summary
    {
      integration: crm_integration.name,
      platform: crm_integration.platform,
      brand: brand.name,
      date: analytics_date,
      metric_type: metric_type,
      lead_metrics: lead_performance_summary,
      opportunity_metrics: opportunity_performance_summary,
      pipeline_metrics: pipeline_performance_summary,
      conversion_metrics: conversion_funnel_summary,
      time_metrics: time_based_metrics_summary,
      attribution_metrics: attribution_performance_summary,
      performance_score: performance_score,
      health_score: crm_health_score,
      calculated_at: calculated_at
    }
  end

  private

  def calculate_percentage_change(current_value, previous_value)
    return 0 if previous_value.blank? || previous_value == 0
    return 0 if current_value.blank?

    ((current_value - previous_value) / previous_value.to_f * 100).round(2)
  end
end
