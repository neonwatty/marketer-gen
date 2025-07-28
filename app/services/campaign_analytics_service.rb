class CampaignAnalyticsService
  def initialize(campaign)
    @campaign = campaign
  end
  
  def generate_comprehensive_report(period = 'daily', days = 30)
    start_date = days.days.ago
    end_date = Time.current
    
    {
      campaign_overview: campaign_overview,
      performance_summary: performance_summary(start_date, end_date),
      journey_performance: journey_performance_breakdown(period, days),
      conversion_analysis: conversion_analysis(start_date, end_date),
      persona_insights: persona_insights,
      ab_test_results: ab_test_results,
      recommendations: generate_recommendations,
      period_info: {
        start_date: start_date,
        end_date: end_date,
        period: period,
        days: days
      }
    }
  end
  
  def campaign_overview
    {
      id: @campaign.id,
      name: @campaign.name,
      status: @campaign.status,
      type: @campaign.campaign_type,
      persona: @campaign.persona.name,
      duration_days: @campaign.duration_days,
      total_journeys: @campaign.total_journeys,
      active_journeys: @campaign.active_journeys,
      progress_percentage: @campaign.progress_percentage
    }
  end
  
  def performance_summary(start_date, end_date)
    journeys = @campaign.journeys.published
    total_performance = @campaign.performance_summary
    
    # Aggregate journey analytics
    analytics = JourneyAnalytics.joins(:journey)
                               .where(journeys: { campaign_id: @campaign.id })
                               .where(period_start: start_date..end_date)
    
    return total_performance if analytics.empty?
    
    {
      total_executions: analytics.sum(:total_executions),
      completed_executions: analytics.sum(:completed_executions),
      abandoned_executions: analytics.sum(:abandoned_executions),
      overall_conversion_rate: analytics.average(:conversion_rate)&.round(2) || 0,
      overall_engagement_score: analytics.average(:engagement_score)&.round(2) || 0,
      average_completion_time: analytics.average(:average_completion_time)&.round(2) || 0,
      trends: calculate_performance_trends(analytics)
    }
  end
  
  def journey_performance_breakdown(period = 'daily', days = 30)
    journeys = @campaign.journeys.published.includes(:journey_analytics)
    
    journeys.map do |journey|
      analytics_summary = journey.analytics_summary(days)
      latest_performance = journey.latest_performance_score
      
      {
        journey_id: journey.id,
        journey_name: journey.name,
        status: journey.status,
        performance_score: latest_performance,
        analytics: analytics_summary,
        funnel_data: journey.funnel_performance('default', days),
        ab_test_status: journey.ab_test_status
      }
    end
  end
  
  def conversion_analysis(start_date, end_date)
    funnels = ConversionFunnel.joins(:journey)
                             .where(journeys: { campaign_id: @campaign.id })
                             .where(period_start: start_date..end_date)
                             .group(:funnel_name, :stage)
                             .sum(:conversions)
    
    stage_performance = funnels.group_by { |key, _| key[1] } # Group by stage
                              .transform_values { |stage_data| stage_data.sum { |_, conversions| conversions } }
    
    {
      total_conversions: funnels.values.sum,
      conversions_by_stage: stage_performance,
      funnel_efficiency: calculate_funnel_efficiency(funnels),
      bottlenecks: identify_conversion_bottlenecks(stage_performance)
    }
  end
  
  def persona_insights
    persona = @campaign.persona
    
    return {} unless persona
    
    {
      persona_name: persona.name,
      demographics_summary: persona.demographics_summary,
      behavior_summary: persona.behavior_summary,
      campaign_alignment: analyze_campaign_persona_alignment,
      performance_by_segment: calculate_segment_performance
    }
  end
  
  def ab_test_results
    tests = @campaign.ab_tests.includes(:ab_test_variants)
    
    return [] if tests.empty?
    
    tests.map do |test|
      {
        test_name: test.name,
        status: test.status,
        duration_days: test.duration_days,
        statistical_significance: test.statistical_significance_reached?,
        winner: test.winner_variant&.name,
        results_summary: test.results_summary,
        variant_comparison: test.variant_comparison,
        recommendation: test.recommend_action
      }
    end
  end
  
  def generate_recommendations
    recommendations = []
    
    # Performance-based recommendations
    performance = performance_summary(30.days.ago, Time.current)
    
    if performance[:overall_conversion_rate] < 5.0
      recommendations << {
        type: 'conversion_optimization',
        priority: 'high',
        title: 'Low Conversion Rate Detected',
        description: "Campaign conversion rate (#{performance[:overall_conversion_rate]}%) is below industry average (5%). Consider optimizing journey steps or messaging.",
        action_items: [
          'Review journey flow for friction points',
          'A/B test call-to-action messages',
          'Analyze drop-off points in conversion funnel'
        ]
      }
    end
    
    if performance[:overall_engagement_score] < 60.0
      recommendations << {
        type: 'engagement_improvement',
        priority: 'medium',
        title: 'Engagement Score Below Target',
        description: "Engagement score (#{performance[:overall_engagement_score]}) suggests users are not fully interacting with journey content.",
        action_items: [
          'Review content relevance to persona',
          'Optimize content for mobile devices',
          'Add interactive elements to journey steps'
        ]
      }
    end
    
    # Journey-specific recommendations
    journey_performances = journey_performance_breakdown
    
    low_performing_journeys = journey_performances.select { |j| j[:performance_score] < 50.0 }
    if low_performing_journeys.any?
      recommendations << {
        type: 'journey_optimization',
        priority: 'high',
        title: 'Underperforming Journeys Identified',
        description: "#{low_performing_journeys.count} journey(s) have performance scores below 50%.",
        action_items: [
          'Review underperforming journey content',
          'Consider A/B testing alternative approaches',
          'Analyze persona-journey alignment'
        ],
        affected_journeys: low_performing_journeys.map { |j| j[:journey_name] }
      }
    end
    
    # A/B test recommendations
    ab_results = ab_test_results
    
    completed_tests = ab_results.select { |test| test[:status] == 'completed' }
    if completed_tests.any? { |test| test[:winner] }
      winners = completed_tests.select { |test| test[:winner] }.map { |test| test[:winner] }
      recommendations << {
        type: 'ab_test_implementation',
        priority: 'high',
        title: 'Implement A/B Test Winners',
        description: "#{winners.count} A/B test(s) have identified winning variants ready for implementation.",
        action_items: [
          'Deploy winning variants to all traffic',
          'Monitor performance after implementation',
          'Plan next round of optimization tests'
        ],
        winning_variants: winners
      }
    end
    
    recommendations
  end
  
  def calculate_roi(investment_amount = nil)
    return {} unless investment_amount
    
    performance = performance_summary(30.days.ago, Time.current)
    total_conversions = performance[:completed_executions] || 0
    
    # This would integrate with actual revenue tracking
    # For now, use placeholder calculations
    estimated_revenue_per_conversion = @campaign.target_metrics['revenue_per_conversion'] || 100
    total_revenue = total_conversions * estimated_revenue_per_conversion
    
    roi_percentage = investment_amount > 0 ? ((total_revenue - investment_amount) / investment_amount * 100) : 0
    
    {
      investment: investment_amount,
      estimated_revenue: total_revenue,
      net_profit: total_revenue - investment_amount,
      roi_percentage: roi_percentage.round(1),
      cost_per_conversion: total_conversions > 0 ? (investment_amount / total_conversions).round(2) : 0,
      conversion_value: estimated_revenue_per_conversion
    }
  end
  
  def export_data(format = 'json')
    data = generate_comprehensive_report
    
    case format
    when 'csv'
      export_to_csv(data)
    when 'json'
      data.to_json
    else
      data
    end
  end
  
  private
  
  def calculate_performance_trends(analytics)
    return {} if analytics.count < 2
    
    # Calculate week-over-week trends
    this_week = analytics.where('period_start >= ?', 1.week.ago)
    last_week = analytics.where('period_start >= ? AND period_start < ?', 2.weeks.ago, 1.week.ago)
    
    return {} if this_week.empty? || last_week.empty?
    
    {
      conversion_rate: calculate_trend_change(
        last_week.average(:conversion_rate),
        this_week.average(:conversion_rate)
      ),
      engagement_score: calculate_trend_change(
        last_week.average(:engagement_score),
        this_week.average(:engagement_score)
      ),
      total_executions: calculate_trend_change(
        last_week.sum(:total_executions),
        this_week.sum(:total_executions)
      )
    }
  end
  
  def calculate_trend_change(old_value, new_value)
    return 0 if old_value.nil? || new_value.nil? || old_value == 0
    
    change_percentage = ((new_value - old_value) / old_value * 100).round(1)
    
    {
      previous_value: old_value.round(2),
      current_value: new_value.round(2),
      change_percentage: change_percentage,
      trend: change_percentage > 5 ? 'up' : (change_percentage < -5 ? 'down' : 'stable')
    }
  end
  
  def calculate_funnel_efficiency(funnels)
    return {} if funnels.empty?
    
    stage_totals = funnels.group_by { |key, _| key[1] } # Group by stage
                         .transform_values { |stage_data| stage_data.sum { |_, conversions| conversions } }
    
    stages = Journey::STAGES
    efficiencies = {}
    
    stages.each_with_index do |stage, index|
      next if index == 0 # Skip first stage
      
      previous_stage = stages[index - 1]
      current_conversions = stage_totals[stage] || 0
      previous_conversions = stage_totals[previous_stage] || 0
      
      efficiency = previous_conversions > 0 ? (current_conversions.to_f / previous_conversions * 100).round(1) : 0
      efficiencies["#{previous_stage}_to_#{stage}"] = efficiency
    end
    
    efficiencies
  end
  
  def identify_conversion_bottlenecks(stage_performance)
    return [] if stage_performance.empty?
    
    sorted_stages = stage_performance.sort_by { |_, conversions| conversions }
    lowest_performing = sorted_stages.first(2)
    
    lowest_performing.map do |stage, conversions|
      {
        stage: stage,
        conversions: conversions,
        severity: conversions < (stage_performance.values.sum / stage_performance.count) * 0.5 ? 'high' : 'medium'
      }
    end
  end
  
  def analyze_campaign_persona_alignment
    # Analyze how well the campaign aligns with persona preferences
    persona = @campaign.persona
    journeys = @campaign.journeys
    
    channel_alignment = analyze_channel_alignment(persona, journeys)
    messaging_alignment = analyze_messaging_alignment(persona, journeys)
    
    {
      overall_score: (channel_alignment + messaging_alignment) / 2,
      channel_alignment: channel_alignment,
      messaging_alignment: messaging_alignment,
      suggestions: generate_alignment_suggestions(channel_alignment, messaging_alignment)
    }
  end
  
  def analyze_channel_alignment(persona, journeys)
    preferred_channels = persona.preferences['channel_preferences'] || []
    return 70 if preferred_channels.empty? # Default score if no preferences
    
    used_channels = journeys.flat_map { |j| j.journey_steps.pluck(:channel) }.compact.uniq
    
    matching_channels = (preferred_channels & used_channels).count
    total_preferred = preferred_channels.count
    
    total_preferred > 0 ? (matching_channels.to_f / total_preferred * 100).round : 70
  end
  
  def analyze_messaging_alignment(persona, journeys)
    preferred_tone = persona.preferences['messaging_tone']
    return 70 unless preferred_tone # Default score if no preference
    
    # This would analyze actual journey content for tone
    # For now, return a placeholder score
    75
  end
  
  def generate_alignment_suggestions(channel_score, messaging_score)
    suggestions = []
    
    if channel_score < 60
      suggestions << "Consider incorporating more preferred channels from persona profile"
    end
    
    if messaging_score < 60
      suggestions << "Review messaging tone to better match persona preferences"
    end
    
    if channel_score > 80 && messaging_score > 80
      suggestions << "Strong persona alignment - maintain current approach"
    end
    
    suggestions
  end
  
  def calculate_segment_performance
    # This would break down performance by demographic segments
    # For now, return placeholder data
    {
      age_segments: {
        '18-25' => { conversion_rate: 4.2, engagement_score: 78 },
        '26-35' => { conversion_rate: 6.1, engagement_score: 82 },
        '36-45' => { conversion_rate: 5.8, engagement_score: 75 }
      },
      location_segments: {
        'urban' => { conversion_rate: 5.9, engagement_score: 80 },
        'suburban' => { conversion_rate: 5.2, engagement_score: 76 },
        'rural' => { conversion_rate: 4.8, engagement_score: 72 }
      }
    }
  end
  
  def export_to_csv(data)
    # This would convert the analytics data to CSV format
    # Implementation would depend on specific CSV requirements
    "CSV export functionality would be implemented here"
  end
end