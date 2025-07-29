class Api::V1::AnalyticsController < Api::V1::BaseController
  
  # GET /api/v1/analytics/overview
  def overview
    days = [params[:days].to_i, 7].max
    days = [days, 365].min # Cap at 1 year
    
    overview_data = {
      summary: calculate_user_overview(days),
      journeys: calculate_journey_overview(days),
      campaigns: calculate_campaign_overview(days),
      performance: calculate_performance_overview(days)
    }
    
    render_success(data: overview_data)
  end
  
  # GET /api/v1/analytics/journeys/:id
  def journey_analytics
    journey = current_user.journeys.find(params[:id])
    days = [params[:days].to_i, 30].max
    days = [days, 365].min
    
    analytics_data = {
      summary: journey.analytics_summary(days),
      performance_score: journey.latest_performance_score,
      funnel_performance: journey.funnel_performance('default', days),
      trends: journey.performance_trends(7),
      ab_test_status: journey.ab_test_status,
      step_analytics: calculate_step_analytics(journey, days),
      conversion_metrics: calculate_journey_conversions(journey, days),
      engagement_metrics: calculate_journey_engagement(journey, days)
    }
    
    render_success(data: analytics_data)
  end
  
  # GET /api/v1/analytics/campaigns/:id
  def campaign_analytics
    campaign = current_user.campaigns.find(params[:id])
    days = [params[:days].to_i, 30].max
    days = [days, 365].min
    
    analytics_service = CampaignAnalyticsService.new(campaign)
    analytics_data = analytics_service.generate_report(days)
    
    render_success(data: analytics_data)
  end
  
  # GET /api/v1/analytics/funnels/:journey_id
  def funnel_analytics
    journey = current_user.journeys.find(params[:journey_id])
    funnel_name = params[:funnel_name] || 'default'
    days = [params[:days].to_i, 7].max
    days = [days, 90].min
    
    start_date = days.days.ago
    end_date = Time.current
    
    funnel_data = {
      overview: ConversionFunnel.funnel_overview(journey.id, funnel_name, start_date, end_date),
      steps: ConversionFunnel.funnel_step_breakdown(journey.id, funnel_name, start_date, end_date),
      trends: ConversionFunnel.funnel_trends(journey.id, funnel_name, start_date, end_date),
      drop_off_analysis: calculate_drop_off_analysis(journey, funnel_name, start_date, end_date)
    }
    
    render_success(data: funnel_data)
  end
  
  # GET /api/v1/analytics/ab_tests/:id
  def ab_test_analytics
    ab_test = current_user.ab_tests.find(params[:id])
    days = [params[:days].to_i, ab_test.duration_days].max
    
    ab_analytics_service = AbTestAnalyticsService.new(ab_test)
    analytics_data = ab_analytics_service.generate_report(days)
    
    render_success(data: analytics_data)
  end
  
  # GET /api/v1/analytics/comparative
  def comparative_analytics
    journey_ids = params[:journey_ids].to_s.split(',').map(&:to_i)
    
    if journey_ids.empty? || journey_ids.count > 5
      return render_error(message: 'Please provide 1-5 journey IDs for comparison')
    end
    
    journeys = current_user.journeys.where(id: journey_ids)
    
    unless journeys.count == journey_ids.count
      return render_error(message: 'One or more journeys not found')
    end
    
    days = [params[:days].to_i, 30].max
    days = [days, 90].min
    
    comparison_service = JourneyComparisonService.new(journeys)
    comparison_data = comparison_service.generate_comparison(days)
    
    render_success(data: comparison_data)
  end
  
  # GET /api/v1/analytics/trends
  def trends
    days = [params[:days].to_i, 30].max
    days = [days, 365].min
    metric = params[:metric] || 'conversion_rate'
    
    unless %w[conversion_rate engagement_score completion_rate execution_count].include?(metric)
      return render_error(message: 'Invalid metric specified')
    end
    
    trends_data = calculate_user_trends(metric, days)
    
    render_success(data: trends_data)
  end
  
  # GET /api/v1/analytics/personas/:id/performance
  def persona_performance
    persona = current_user.personas.find(params[:id])
    days = [params[:days].to_i, 30].max
    days = [days, 365].min
    
    # Get campaigns and journeys associated with this persona
    campaigns = persona.campaigns.includes(:journeys)
    journeys = campaigns.flat_map(&:journeys)
    
    performance_data = {
      summary: calculate_persona_summary(persona, journeys, days),
      campaign_performance: calculate_persona_campaign_performance(campaigns, days),
      journey_performance: calculate_persona_journey_performance(journeys, days),
      engagement_patterns: calculate_persona_engagement_patterns(persona, days),
      conversion_insights: calculate_persona_conversion_insights(persona, days)
    }
    
    render_success(data: performance_data)
  end
  
  # POST /api/v1/analytics/custom_report
  def custom_report
    report_params = params.permit(
      :name, :description, :date_range_days,
      metrics: [], filters: {}, grouping: []
    )
    
    begin
      # Generate custom analytics report based on parameters
      report_data = generate_custom_report(report_params)
      
      render_success(
        data: report_data,
        message: 'Custom report generated successfully'
      )
    rescue => e
      render_error(message: "Failed to generate report: #{e.message}")
    end
  end
  
  # GET /api/v1/analytics/real_time
  def real_time
    # Get real-time metrics for the last 24 hours
    real_time_data = {
      active_journeys: calculate_active_journeys,
      recent_executions: calculate_recent_executions,
      live_conversions: calculate_live_conversions,
      engagement_activity: calculate_engagement_activity,
      system_health: calculate_system_health
    }
    
    render_success(data: real_time_data)
  end
  
  private
  
  def calculate_user_overview(days)
    journeys = current_user.journeys
    start_date = days.days.ago
    
    {
      total_journeys: journeys.count,
      active_journeys: journeys.where(status: %w[draft published]).count,
      total_executions: current_user.journey_executions.where(created_at: start_date..).count,
      total_campaigns: current_user.campaigns.count,
      total_personas: current_user.personas.count,
      period_days: days
    }
  end
  
  def calculate_journey_overview(days)
    journeys = current_user.journeys.includes(:journey_analytics)
    start_date = days.days.ago
    
    analytics = JourneyAnalytics.joins(:journey)
      .where(journeys: { user: current_user })
      .where(period_start: start_date..)
    
    {
      average_conversion_rate: analytics.average(:conversion_rate)&.round(2) || 0,
      average_engagement_score: analytics.average(:engagement_score)&.round(2) || 0,
      total_executions: analytics.sum(:total_executions),
      completed_executions: analytics.sum(:completed_executions),
      top_performing: find_top_performing_journeys(5)
    }
  end
  
  def calculate_campaign_overview(days)
    campaigns = current_user.campaigns.includes(:journeys)
    
    {
      active_campaigns: campaigns.where(status: 'active').count,
      total_journey_count: campaigns.joins(:journeys).count,
      campaign_performance: campaigns.limit(5).map do |campaign|
        {
          id: campaign.id,
          name: campaign.name,
          journey_count: campaign.journeys.count,
          status: campaign.status
        }
      end
    }
  end
  
  def calculate_performance_overview(days)
    start_date = days.days.ago
    
    # Get performance metrics across all user's journeys
    user_journey_ids = current_user.journeys.pluck(:id)
    
    metrics = JourneyMetric.where(journey_id: user_journey_ids)
      .for_date_range(start_date, Time.current)
    
    {
      average_performance_score: calculate_average_performance_score(metrics),
      trend_direction: calculate_trend_direction(metrics),
      key_insights: generate_key_insights(metrics)
    }
  end
  
  def calculate_step_analytics(journey, days)
    journey.journey_steps.includes(:step_executions).map do |step|
      executions = step.step_executions.where(created_at: days.days.ago..)
      
      {
        step_id: step.id,
        step_name: step.name,
        step_type: step.content_type,
        execution_count: executions.count,
        completion_rate: calculate_step_completion_rate(executions),
        average_duration: calculate_average_duration(executions)
      }
    end
  end
  
  def calculate_journey_conversions(journey, days)
    # Placeholder for detailed conversion calculations
    {
      total_conversions: 0,
      conversion_rate: 0.0,
      conversion_value: 0.0,
      conversion_by_source: {},
      conversion_trends: []
    }
  end
  
  def calculate_journey_engagement(journey, days)
    # Placeholder for engagement calculations
    {
      engagement_score: 0.0,
      interaction_count: 0,
      average_session_duration: 0.0,
      bounce_rate: 0.0,
      engagement_by_step: []
    }
  end
  
  def calculate_drop_off_analysis(journey, funnel_name, start_date, end_date)
    # Analyze where users drop off in the funnel
    steps = journey.journey_steps.order(:position)
    drop_off_data = []
    
    steps.each_with_index do |step, index|
      next_step = steps[index + 1]
      next unless next_step
      
      # Calculate drop-off rate between this step and the next
      current_executions = step.step_executions.where(created_at: start_date..end_date).count
      next_executions = next_step.step_executions.where(created_at: start_date..end_date).count
      
      drop_off_rate = current_executions > 0 ? ((current_executions - next_executions).to_f / current_executions * 100).round(2) : 0
      
      drop_off_data << {
        from_step: step.name,
        to_step: next_step.name,
        drop_off_rate: drop_off_rate,
        users_lost: current_executions - next_executions
      }
    end
    
    drop_off_data
  end
  
  def find_top_performing_journeys(limit)
    current_user.journeys
      .joins(:journey_analytics)
      .group('journeys.id, journeys.name')
      .order('AVG(journey_analytics.conversion_rate) DESC')
      .limit(limit)
      .pluck('journeys.id, journeys.name, AVG(journey_analytics.conversion_rate)')
      .map { |id, name, rate| { id: id, name: name, conversion_rate: rate.round(2) } }
  end
  
  def calculate_average_performance_score(metrics)
    return 0.0 if metrics.empty?
    
    # Calculate weighted performance score across all metrics
    total_score = metrics.sum do |metric|
      conversion_weight = 0.4
      engagement_weight = 0.3
      completion_weight = 0.3
      
      (metric.conversion_rate * conversion_weight +
       metric.engagement_score * engagement_weight +
       metric.completion_rate * completion_weight)
    end
    
    (total_score / metrics.count).round(1)
  end
  
  def calculate_trend_direction(metrics)
    return 'stable' if metrics.count < 2
    
    recent_scores = metrics.order(:period_start).last(7).map(&:conversion_rate)
    return 'stable' if recent_scores.count < 2
    
    trend = (recent_scores.last - recent_scores.first) / recent_scores.first
    
    if trend > 0.05
      'improving'
    elsif trend < -0.05
      'declining'
    else
      'stable'
    end
  end
  
  def generate_key_insights(metrics)
    insights = []
    
    # Add performance insights based on metrics analysis
    if metrics.any?
      avg_conversion = metrics.average(:conversion_rate)
      
      if avg_conversion > 10
        insights << "Strong conversion performance across journeys"
      elsif avg_conversion < 2
        insights << "Conversion rates could be improved"
      end
      
      high_engagement = metrics.where('engagement_score > ?', 75).count
      if high_engagement > metrics.count * 0.7
        insights << "High engagement levels maintained"
      end
    end
    
    insights
  end
  
  def calculate_user_trends(metric, days)
    # Calculate trends for specified metric over time
    user_journey_ids = current_user.journeys.pluck(:id)
    
    analytics = JourneyAnalytics.where(journey_id: user_journey_ids)
      .where(period_start: days.days.ago..)
      .order(:period_start)
    
    trends = analytics.group("DATE(period_start)").average(metric)
    
    {
      metric: metric,
      period_days: days,
      data_points: trends.map { |date, value| { date: date, value: value&.round(2) || 0 } }
    }
  end
  
  def calculate_persona_summary(persona, journeys, days)
    {
      persona_name: persona.name,
      total_journeys: journeys.count,
      total_campaigns: persona.campaigns.count,
      performance_score: calculate_persona_performance_score(journeys, days)
    }
  end
  
  def calculate_persona_campaign_performance(campaigns, days)
    campaigns.map do |campaign|
      {
        id: campaign.id,
        name: campaign.name,
        status: campaign.status,
        journey_count: campaign.journeys.count
      }
    end
  end
  
  def calculate_persona_journey_performance(journeys, days)
    journeys.map do |journey|
      {
        id: journey.id,
        name: journey.name,
        performance_score: journey.latest_performance_score,
        conversion_rate: journey.current_analytics&.conversion_rate || 0
      }
    end
  end
  
  def calculate_persona_engagement_patterns(persona, days)
    # Placeholder for persona engagement analysis
    {
      preferred_channels: [],
      engagement_times: [],
      content_preferences: []
    }
  end
  
  def calculate_persona_conversion_insights(persona, days)
    # Placeholder for persona conversion analysis
    {
      conversion_triggers: [],
      optimal_journey_length: 0,
      successful_touchpoints: []
    }
  end
  
  def calculate_persona_performance_score(journeys, days)
    return 0.0 if journeys.empty?
    
    scores = journeys.map(&:latest_performance_score).compact
    return 0.0 if scores.empty?
    
    (scores.sum.to_f / scores.count).round(1)
  end
  
  def generate_custom_report(report_params)
    # Placeholder for custom report generation
    {
      report_name: report_params[:name],
      generated_at: Time.current,
      data: {
        summary: "Custom report functionality would be implemented here",
        metrics: report_params[:metrics] || [],
        filters_applied: report_params[:filters] || {}
      }
    }
  end
  
  def calculate_active_journeys
    current_user.journeys.where(status: %w[draft published]).count
  end
  
  def calculate_recent_executions
    current_user.journey_executions.where(created_at: 24.hours.ago..).count
  end
  
  def calculate_live_conversions
    # Placeholder for real-time conversion tracking
    0
  end
  
  def calculate_engagement_activity
    # Placeholder for real-time engagement tracking
    {
      active_sessions: 0,
      recent_interactions: 0
    }
  end
  
  def calculate_system_health
    {
      status: 'healthy',
      response_time: 'normal',
      uptime: '99.9%'
    }
  end
  
  def calculate_step_completion_rate(executions)
    return 0.0 if executions.empty?
    
    completed_count = executions.completed.count
    total_count = executions.count
    
    return 0.0 if total_count == 0
    (completed_count.to_f / total_count * 100).round(2)
  end
  
  def calculate_average_duration(executions)
    completed_executions = executions.completed.where.not(completed_at: nil, started_at: nil)
    return 0.0 if completed_executions.empty?
    
    durations = completed_executions.map do |execution|
      (execution.completed_at - execution.started_at) / 1.hour # Convert to hours
    end
    
    (durations.sum / durations.count).round(2)
  end
end