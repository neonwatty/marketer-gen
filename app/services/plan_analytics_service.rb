# frozen_string_literal: true

# Service for handling campaign plan analytics and performance tracking
class PlanAnalyticsService < ApplicationService

  def initialize(campaign_plan)
    @campaign_plan = campaign_plan
    @user = campaign_plan.user
  end

  def call
    gather_and_process_analytics
  end

  # Gather analytics data from various sources
  def gather_analytics_data
    return handle_service_error(StandardError.new("Campaign plan is required"), {}) if @campaign_plan.nil?
    
    log_service_call('PlanAnalyticsService#gather_analytics_data', { plan_id: @campaign_plan.id })

    begin
      analytics_data = {
        engagement_metrics: gather_engagement_metrics,
        performance_data: gather_performance_data,
        roi_tracking: calculate_roi_metrics,
        execution_progress: calculate_execution_progress,
        content_performance: analyze_content_performance,
        timeline_adherence: analyze_timeline_adherence
      }

      update_analytics_timestamp
      success_response(analytics_data)

    rescue StandardError => e
      handle_service_error(e, { plan_id: @campaign_plan.id })
    end
  end

  # Process and store analytics data
  def gather_and_process_analytics
    result = gather_analytics_data
    return result unless result[:success]

    begin
      analytics_data = result[:data]
      
      # Store analytics data in the database
      @campaign_plan.update!(
        engagement_metrics: analytics_data[:engagement_metrics].to_json,
        performance_data: analytics_data[:performance_data].to_json,
        roi_tracking: analytics_data[:roi_tracking].to_json,
        analytics_last_updated_at: Time.current
      )

      success_response(analytics_data)

    rescue StandardError => e
      handle_service_error(e, { plan_id: @campaign_plan.id })
    end
  end

  # Calculate ROI metrics
  def calculate_roi_metrics
    return {} unless @campaign_plan.budget_constraints.present?

    budget_data = parse_budget_constraints
    performance_metrics = current_performance_metrics

    {
      total_investment: budget_data[:total_budget] || 0,
      cost_per_engagement: calculate_cost_per_engagement(budget_data, performance_metrics),
      projected_roi: calculate_projected_roi(budget_data, performance_metrics),
      actual_roi: calculate_actual_roi(budget_data, performance_metrics),
      cost_efficiency: calculate_cost_efficiency(budget_data, performance_metrics),
      budget_utilization: calculate_budget_utilization(budget_data),
      last_calculated: Time.current
    }
  end

  # Analyze content performance across different channels
  def analyze_content_performance
    content_strategy = safe_parse_json(@campaign_plan.content_strategy)
    content_mapping = safe_parse_json(@campaign_plan.content_mapping)

    return {} if content_strategy.blank? && content_mapping.blank?

    {
      content_pieces_count: count_content_pieces(content_strategy, content_mapping),
      channel_performance: analyze_channel_performance(content_mapping),
      content_engagement_rates: calculate_content_engagement_rates,
      best_performing_content: identify_best_performing_content,
      content_completion_rate: calculate_content_completion_rate(content_strategy),
      last_analyzed: Time.current
    }
  end

  # Calculate execution progress against timeline
  def calculate_execution_progress
    timeline_data = safe_parse_json(@campaign_plan.generated_timeline)
    return {} if timeline_data.blank?

    {
      overall_progress: calculate_overall_progress(timeline_data),
      milestone_completion: calculate_milestone_completion(timeline_data),
      timeline_adherence: calculate_timeline_adherence_percentage(timeline_data),
      upcoming_milestones: identify_upcoming_milestones(timeline_data),
      overdue_items: identify_overdue_items(timeline_data),
      estimated_completion: estimate_completion_date(timeline_data),
      last_updated: Time.current
    }
  end

  # Generate comprehensive analytics report
  def generate_analytics_report
    analytics_data = gather_analytics_data
    return analytics_data unless analytics_data[:success]

    data = analytics_data[:data]
    
    report = {
      plan_overview: generate_plan_overview,
      performance_summary: generate_performance_summary(data),
      engagement_analysis: generate_engagement_analysis(data),
      roi_analysis: generate_roi_analysis(data),
      content_analysis: generate_content_analysis(data),
      timeline_analysis: generate_timeline_analysis(data),
      recommendations: generate_recommendations(data),
      generated_at: Time.current
    }

    success_response(report)
  end

  # Integration points for external analytics platforms
  def sync_with_external_platforms
    return success_response({ message: 'Analytics disabled' }) unless @campaign_plan.analytics_enabled?

    results = {}

    # Google Analytics integration (mock for now)
    if google_analytics_enabled?
      results[:google_analytics] = sync_google_analytics
    end

    # Social media APIs integration (mock for now)
    if social_media_tracking_enabled?
      results[:social_media] = sync_social_media_metrics
    end

    # Email marketing platform integration (mock for now)
    if email_marketing_enabled?
      results[:email_marketing] = sync_email_metrics
    end

    success_response(results)
  end

  private

  # Helper method for logging service calls (ensuring availability)
  def log_service_call(service_name, params = {})
    Rails.logger.info "Service Call: #{service_name} with params: #{params.inspect}"
  end

  # Helper method for handling service errors (ensuring availability)
  def handle_service_error(error, context = {})
    Rails.logger.error "Service Error in #{self.class}: #{error.message}"
    Rails.logger.error "Context: #{context.inspect}" if context.any?
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Return a structured error response
    {
      success: false,
      error: error.message,
      context: context
    }
  end

  # Helper method for successful service responses (ensuring availability)
  def success_response(data = {})
    {
      success: true,
      data: data
    }
  end

  # Gather engagement metrics from various sources
  def gather_engagement_metrics
    base_metrics = {
      views: calculate_plan_views,
      shares: calculate_plan_shares,
      feedback_engagement: calculate_feedback_engagement,
      collaboration_score: calculate_collaboration_score,
      last_updated: Time.current
    }

    # Add external platform metrics if available
    external_metrics = gather_external_engagement_metrics
    base_metrics.merge(external_metrics)
  end

  # Gather performance data
  def gather_performance_data
    {
      generation_metrics: analyze_generation_performance,
      approval_metrics: analyze_approval_performance,
      execution_metrics: analyze_execution_performance,
      quality_metrics: analyze_quality_metrics,
      efficiency_metrics: analyze_efficiency_metrics,
      last_updated: Time.current
    }
  end

  # Parse budget constraints safely
  def parse_budget_constraints
    return {} unless @campaign_plan.budget_constraints.present?

    budget_data = safe_parse_json(@campaign_plan.budget_constraints)
    return {} if budget_data.blank?

    {
      total_budget: extract_total_budget(budget_data),
      allocated_budget: extract_allocated_budget(budget_data),
      spent_budget: extract_spent_budget(budget_data),
      remaining_budget: extract_remaining_budget(budget_data)
    }
  end

  # Calculate current performance metrics
  def current_performance_metrics
    {
      total_engagements: calculate_total_engagements,
      conversion_rate: calculate_conversion_rate,
      reach: calculate_reach,
      impressions: calculate_impressions
    }
  end

  # Helper methods for calculations
  def calculate_cost_per_engagement(budget_data, performance_metrics)
    engagements = performance_metrics[:total_engagements]
    spent_budget = budget_data[:spent_budget]
    
    # Safe conversion to numeric values
    engagements_num = engagements.is_a?(Numeric) ? engagements.to_f : 0.0
    spent_budget_num = spent_budget.is_a?(Numeric) ? spent_budget.to_f : 0.0
    
    return 0 if engagements_num.zero?
    (spent_budget_num / engagements_num).round(2)
  end

  def calculate_projected_roi(budget_data, performance_metrics)
    # Mock calculation - in real implementation, this would use historical data
    conversion_rate = performance_metrics[:conversion_rate]
    base_roi = (conversion_rate.is_a?(Numeric) ? conversion_rate.to_f : 0.05) * 100
    base_roi * (1 + rand(0.1..0.3)) # Add some variance
  end

  def calculate_actual_roi(budget_data, performance_metrics)
    total_budget = budget_data[:total_budget].is_a?(Numeric) ? budget_data[:total_budget].to_f : 0.0
    spent_budget = budget_data[:spent_budget].is_a?(Numeric) ? budget_data[:spent_budget].to_f : 0.0
    conversion_rate = performance_metrics[:conversion_rate].is_a?(Numeric) ? performance_metrics[:conversion_rate].to_f : 0.05
    
    return 0 if total_budget.zero?
    
    revenue_generated = conversion_rate * total_budget * 2
    return 0 if spent_budget.zero?
    ((revenue_generated - spent_budget) / spent_budget * 100).round(2)
  end

  def calculate_cost_efficiency(budget_data, performance_metrics)
    total_budget = budget_data[:total_budget].is_a?(Numeric) ? budget_data[:total_budget].to_f : 0.0
    spent_budget = budget_data[:spent_budget].is_a?(Numeric) ? budget_data[:spent_budget].to_f : 0.0
    total_engagements = performance_metrics[:total_engagements].is_a?(Numeric) ? performance_metrics[:total_engagements].to_f : 0.0
    
    return 0 if total_budget.zero? || spent_budget.zero?
    
    efficiency_score = total_engagements / spent_budget * 1000
    [efficiency_score.round(2), 100].min # Cap at 100
  end

  def calculate_budget_utilization(budget_data)
    total_budget = budget_data[:total_budget].is_a?(Numeric) ? budget_data[:total_budget].to_f : 0.0
    spent_budget = budget_data[:spent_budget].is_a?(Numeric) ? budget_data[:spent_budget].to_f : 0.0
    
    return 0 if total_budget.zero?
    (spent_budget / total_budget * 100).round(2)
  end

  # Timeline analysis methods
  def analyze_timeline_adherence
    timeline_data = safe_parse_json(@campaign_plan.generated_timeline)
    return {} if timeline_data.blank?

    {
      on_schedule_percentage: calculate_on_schedule_percentage(timeline_data),
      delayed_tasks: count_delayed_tasks(timeline_data),
      completed_milestones: count_completed_milestones(timeline_data),
      upcoming_deadlines: get_upcoming_deadlines(timeline_data),
      average_completion_time: calculate_average_completion_time(timeline_data)
    }
  end

  # Content analysis methods
  def count_content_pieces(content_strategy, content_mapping)
    pieces = 0
    pieces += content_strategy.is_a?(Hash) ? (content_strategy['content_pieces'] || []).length : 0
    pieces += content_mapping.is_a?(Hash) ? (content_mapping['mapped_content'] || []).length : 0
    pieces
  end

  def analyze_channel_performance(content_mapping)
    return {} unless content_mapping.is_a?(Hash)

    channels = content_mapping['channels'] || []
    channels.map do |channel|
      {
        channel_name: channel['name'],
        content_count: (channel['content'] || []).length,
        engagement_rate: rand(0.01..0.15).round(3), # Mock data
        performance_score: rand(60..95)
      }
    end
  end

  # External platform integration methods (mock implementations)
  def google_analytics_enabled?
    # In real implementation, check for GA credentials/configuration
    true
  end

  def social_media_tracking_enabled?
    # In real implementation, check for social media API credentials
    true
  end

  def email_marketing_enabled?
    # In real implementation, check for email marketing platform integration
    true
  end

  def sync_google_analytics
    # Mock Google Analytics data
    {
      page_views: rand(1000..10000),
      unique_visitors: rand(500..5000),
      bounce_rate: rand(0.2..0.6).round(2),
      avg_session_duration: rand(60..300),
      conversion_rate: rand(0.01..0.05).round(3),
      last_synced: Time.current
    }
  end

  def sync_social_media_metrics
    # Mock social media metrics
    platforms = ['facebook', 'twitter', 'instagram', 'linkedin']
    platforms.map do |platform|
      {
        platform: platform,
        followers: rand(100..10000),
        engagement_rate: rand(0.01..0.08).round(3),
        reach: rand(1000..50000),
        impressions: rand(5000..100000),
        last_synced: Time.current
      }
    end
  end

  def sync_email_metrics
    # Mock email marketing metrics
    {
      subscribers: rand(100..5000),
      open_rate: rand(0.15..0.35).round(3),
      click_rate: rand(0.02..0.08).round(3),
      unsubscribe_rate: rand(0.001..0.01).round(4),
      bounce_rate: rand(0.01..0.05).round(3),
      last_synced: Time.current
    }
  end

  # Utility methods
  def safe_parse_json(field)
    return {} if field.blank?
    
    if field.is_a?(String)
      JSON.parse(field)
    else
      field
    end
  rescue JSON::ParserError
    {}
  end

  def update_analytics_timestamp
    @campaign_plan.update_column(:analytics_last_updated_at, Time.current)
  end

  # Plan overview generation
  def generate_plan_overview
    {
      plan_id: @campaign_plan.id,
      plan_name: @campaign_plan.name,
      campaign_type: @campaign_plan.campaign_type,
      objective: @campaign_plan.objective,
      status: @campaign_plan.status,
      created_at: @campaign_plan.created_at,
      days_active: (@campaign_plan.created_at ? ((Time.current - @campaign_plan.created_at) / 1.day).round(1) : 0),
      completion_percentage: @campaign_plan.generation_progress
    }
  end

  # Mock implementations for missing methods (to be implemented based on actual requirements)
  def calculate_plan_views
    # Mock implementation - in reality, this would track actual view counts
    rand(10..1000)
  end

  def calculate_plan_shares
    @campaign_plan.plan_share_tokens.count
  end

  def calculate_feedback_engagement
    @campaign_plan.feedback_comments.count
  end

  def calculate_collaboration_score
    # Mock scoring based on feedback and collaboration activities
    base_score = [@campaign_plan.feedback_comments.count * 10, 100].min
    base_score += [@campaign_plan.plan_versions.count * 5, 50].min
    [base_score, 100].min
  end

  def gather_external_engagement_metrics
    # Placeholder for external platform metrics
    {}
  end

  def analyze_generation_performance
    metadata = @campaign_plan.metadata || {}
    {
      generation_duration: metadata['generation_duration'] || 0,
      success_rate: @campaign_plan.completed? ? 1.0 : 0.0,
      retry_count: metadata['retry_count'] || 0
    }
  end

  def analyze_approval_performance
    {
      approval_status: @campaign_plan.approval_status,
      approval_duration: calculate_approval_duration,
      feedback_cycles: @campaign_plan.plan_versions.count
    }
  end

  def analyze_execution_performance
    {
      execution_started: @campaign_plan.plan_execution_started_at.present?,
      execution_completed: @campaign_plan.plan_execution_completed_at.present?,
      execution_duration: calculate_execution_duration
    }
  end

  def analyze_quality_metrics
    {
      content_completeness: calculate_content_completeness_score,
      strategic_alignment: calculate_strategic_alignment_score,
      brand_compliance: calculate_brand_compliance_score
    }
  end

  def analyze_efficiency_metrics
    {
      time_to_completion: calculate_time_to_completion,
      resource_utilization: calculate_resource_utilization,
      stakeholder_satisfaction: calculate_stakeholder_satisfaction
    }
  end

  # Additional helper methods with mock implementations
  def calculate_approval_duration
    return 0 unless @campaign_plan.submitted_for_approval_at && @campaign_plan.approved_at
    
    (@campaign_plan.approved_at - @campaign_plan.submitted_for_approval_at) / 1.hour
  end

  def calculate_execution_duration
    return 0 unless @campaign_plan.plan_execution_started_at
    
    end_time = @campaign_plan.plan_execution_completed_at || Time.current
    (end_time - @campaign_plan.plan_execution_started_at) / 1.day
  end

  def calculate_content_completeness_score
    total_sections = 8.0 # Based on the sections in plan_analytics method
    completed_sections = [
      @campaign_plan.generated_summary.present?,
      @campaign_plan.generated_strategy.present?,
      @campaign_plan.generated_timeline.present?,
      @campaign_plan.generated_assets.present?,
      @campaign_plan.content_strategy.present?,
      @campaign_plan.creative_approach.present?,
      @campaign_plan.strategic_rationale.present?,
      @campaign_plan.content_mapping.present?
    ].count(true)
    
    (completed_sections / total_sections * 100).round(1)
  end

  def calculate_strategic_alignment_score
    # Mock scoring based on plan completeness and coherence
    base_score = calculate_content_completeness_score
    alignment_bonus = @campaign_plan.has_generated_content? ? 20 : 0
    [(base_score + alignment_bonus), 100].min
  end

  def calculate_brand_compliance_score
    # Mock scoring - in reality would check against brand guidelines
    @campaign_plan.brand_context.present? ? rand(80..95) : rand(50..70)
  end

  def calculate_time_to_completion
    return 0 unless @campaign_plan.created_at
    
    if @campaign_plan.completed?
      (@campaign_plan.updated_at - @campaign_plan.created_at) / 1.hour
    else
      (Time.current - @campaign_plan.created_at) / 1.hour
    end
  end

  def calculate_resource_utilization
    # Mock calculation based on plan complexity and completion
    complexity_score = calculate_content_completeness_score
    time_efficiency = calculate_time_to_completion < 24 ? 1.2 : 1.0
    (complexity_score * time_efficiency).round(1)
  end

  def calculate_stakeholder_satisfaction
    # Mock calculation based on approval status and feedback
    case @campaign_plan.approval_status
    when 'approved' then rand(85..100)
    when 'pending_approval' then rand(70..85)
    when 'changes_requested' then rand(50..70)
    when 'rejected' then rand(20..50)
    else rand(60..80)
    end
  end

  # Performance summary generation methods
  def generate_performance_summary(data)
    {
      overall_score: calculate_overall_performance_score(data),
      key_metrics: extract_key_performance_metrics(data),
      trends: analyze_performance_trends(data),
      benchmarks: compare_to_benchmarks(data)
    }
  end

  def generate_engagement_analysis(data)
    engagement_data = data[:engagement_metrics] || {}
    {
      total_engagement: calculate_total_engagement_score(engagement_data),
      engagement_breakdown: break_down_engagement_sources(engagement_data),
      engagement_trends: analyze_engagement_trends(engagement_data),
      top_engagement_drivers: identify_top_engagement_drivers(engagement_data)
    }
  end

  def generate_roi_analysis(data)
    roi_data = data[:roi_tracking] || {}
    {
      current_roi: roi_data[:actual_roi] || 0,
      projected_roi: roi_data[:projected_roi] || 0,
      cost_analysis: analyze_cost_breakdown(roi_data),
      roi_trends: analyze_roi_trends(roi_data),
      optimization_opportunities: identify_roi_optimization_opportunities(roi_data)
    }
  end

  def generate_content_analysis(data)
    content_data = data[:content_performance] || {}
    {
      content_effectiveness: calculate_content_effectiveness_score(content_data),
      channel_performance: content_data[:channel_performance] || [],
      content_gaps: identify_content_gaps(content_data),
      content_recommendations: generate_content_recommendations(content_data)
    }
  end

  def generate_timeline_analysis(data)
    timeline_data = data[:execution_progress] || {}
    {
      schedule_adherence: timeline_data[:timeline_adherence] || 0,
      milestone_progress: timeline_data[:milestone_completion] || {},
      critical_path_analysis: analyze_critical_path(timeline_data),
      timeline_recommendations: generate_timeline_recommendations(timeline_data)
    }
  end

  def generate_recommendations(data)
    recommendations = []

    # Performance recommendations
    performance_data = data[:performance_data] || {}
    if performance_data.dig(:efficiency_metrics, :resource_utilization).to_f < 70
      recommendations << {
        type: 'performance',
        priority: 'high',
        title: 'Improve Resource Utilization',
        description: 'Consider optimizing workflow processes to improve resource efficiency.',
        impact: 'high'
      }
    end

    # ROI recommendations
    roi_data = data[:roi_tracking] || {}
    if roi_data[:actual_roi].to_f < roi_data[:projected_roi].to_f
      recommendations << {
        type: 'roi',
        priority: 'medium',
        title: 'ROI Optimization',
        description: 'Actual ROI is below projections. Review budget allocation and engagement strategies.',
        impact: 'medium'
      }
    end

    # Content recommendations
    content_data = data[:content_performance] || {}
    if content_data[:content_completion_rate].to_f < 80
      recommendations << {
        type: 'content',
        priority: 'medium',
        title: 'Content Strategy Review',
        description: 'Content completion rate is below optimal. Consider streamlining content creation process.',
        impact: 'medium'
      }
    end

    recommendations
  end

  # Mock implementations for additional analysis methods
  def calculate_overall_performance_score(data)
    scores = []
    
    # Helper method to safely convert to float
    safe_to_f = ->(value) { value.is_a?(Numeric) ? value.to_f : 0.0 }
    
    scores << safe_to_f.call(data.dig(:engagement_metrics, :collaboration_score))
    scores << safe_to_f.call(data.dig(:performance_data, :quality_metrics, :content_completeness))
    scores << safe_to_f.call(data.dig(:roi_tracking, :cost_efficiency))
    scores << safe_to_f.call(data.dig(:execution_progress, :overall_progress))
    
    scores.any? ? (scores.sum / scores.length).round(1) : 0
  end

  def extract_key_performance_metrics(data)
    {
      engagement_score: data.dig(:engagement_metrics, :collaboration_score) || 0,
      completion_rate: data.dig(:execution_progress, :overall_progress) || 0,
      roi_efficiency: data.dig(:roi_tracking, :cost_efficiency) || 0,
      quality_score: data.dig(:performance_data, :quality_metrics, :content_completeness) || 0
    }
  end

  def analyze_performance_trends(data)
    # Mock trend analysis - in reality would compare with historical data
    {
      engagement_trend: 'increasing',
      roi_trend: 'stable',
      quality_trend: 'improving',
      efficiency_trend: 'stable'
    }
  end

  def compare_to_benchmarks(data)
    # Mock benchmark comparison
    {
      industry_average_engagement: 65,
      industry_average_roi: 250,
      industry_average_completion_time: 72, # hours
      your_performance_percentile: rand(60..90)
    }
  end

  # Additional mock methods to complete the implementation
  [:calculate_total_engagement_score, :break_down_engagement_sources, :analyze_engagement_trends,
   :identify_top_engagement_drivers, :analyze_cost_breakdown, :analyze_roi_trends,
   :identify_roi_optimization_opportunities, :calculate_content_effectiveness_score,
   :identify_content_gaps, :generate_content_recommendations, :analyze_critical_path,
   :generate_timeline_recommendations, :calculate_overall_progress, :calculate_milestone_completion,
   :calculate_timeline_adherence_percentage, :identify_upcoming_milestones, :identify_overdue_items,
   :estimate_completion_date, :calculate_content_engagement_rates, :identify_best_performing_content,
   :calculate_content_completion_rate, :extract_total_budget, :extract_allocated_budget,
   :extract_spent_budget, :extract_remaining_budget, :calculate_total_engagements,
   :calculate_conversion_rate, :calculate_reach, :calculate_impressions, :calculate_on_schedule_percentage,
   :count_delayed_tasks, :count_completed_milestones, :get_upcoming_deadlines,
   :calculate_average_completion_time].each do |method_name|
    
    define_method(method_name) do |*args|
      # Mock implementation returning appropriate data structure
      case method_name.to_s
      when /percentage|rate|score|efficiency/
        rand(50..95).round(1)
      when /count|total|number/
        rand(1..50)
      when /trend/
        ['increasing', 'decreasing', 'stable'].sample
      when /time|duration/
        rand(1..100)
      when /gaps|recommendations|opportunities/
        []
      else
        {}
      end
    end
  end
end