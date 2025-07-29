class JourneyComparisonService
  def initialize(journey_ids)
    @journey_ids = Array(journey_ids)
    @journeys = Journey.where(id: @journey_ids).includes(:journey_analytics, :journey_metrics, :campaign, :persona)
  end
  
  def compare_performance(period = 'daily', days = 30)
    return { error: 'Need at least 2 journeys to compare' } if @journeys.count < 2
    
    {
      comparison_overview: comparison_overview,
      performance_metrics: compare_performance_metrics(period, days),
      conversion_funnels: compare_conversion_funnels(days),
      engagement_analysis: compare_engagement_metrics(period, days),
      recommendations: generate_comparison_recommendations,
      statistical_analysis: statistical_significance_analysis,
      period_info: {
        period: period,
        days: days,
        start_date: days.days.ago,
        end_date: Time.current
      }
    }
  end
  
  def comparison_overview
    @journeys.map do |journey|
      {
        id: journey.id,
        name: journey.name,
        status: journey.status,
        campaign: journey.campaign&.name,
        persona: journey.campaign&.persona&.name,
        total_steps: journey.total_steps,
        created_at: journey.created_at,
        performance_score: journey.latest_performance_score
      }
    end
  end
  
  def compare_performance_metrics(period = 'daily', days = 30)
    start_date = days.days.ago
    end_date = Time.current
    
    metrics_comparison = {}
    
    @journeys.each do |journey|
      analytics = journey.journey_analytics
                        .where(period_start: start_date..end_date)
                        .where(aggregation_period: period)
      
      if analytics.any?
        metrics_comparison[journey.id] = {
          journey_name: journey.name,
          total_executions: analytics.sum(:total_executions),
          completed_executions: analytics.sum(:completed_executions),
          abandoned_executions: analytics.sum(:abandoned_executions),
          average_conversion_rate: analytics.average(:conversion_rate)&.round(2) || 0,
          average_engagement_score: analytics.average(:engagement_score)&.round(2) || 0,
          average_completion_time: analytics.average(:average_completion_time)&.round(2) || 0,
          completion_rate: calculate_completion_rate(analytics),
          abandonment_rate: calculate_abandonment_rate(analytics)
        }
      else
        metrics_comparison[journey.id] = default_metrics(journey)
      end
    end
    
    # Add relative performance rankings
    add_performance_rankings(metrics_comparison)
  end
  
  def compare_conversion_funnels(days = 30)
    start_date = days.days.ago
    end_date = Time.current
    
    funnel_comparison = {}
    
    @journeys.each do |journey|
      funnel_data = journey.funnel_performance('default', days)
      
      if funnel_data.any?
        funnel_comparison[journey.id] = {
          journey_name: journey.name,
          funnel_overview: funnel_data,
          stage_breakdown: analyze_funnel_stages(funnel_data),
          bottlenecks: identify_journey_bottlenecks(funnel_data)
        }
      else
        funnel_comparison[journey.id] = {
          journey_name: journey.name,
          funnel_overview: {},
          stage_breakdown: {},
          bottlenecks: []
        }
      end
    end
    
    # Compare funnel efficiency across journeys
    funnel_comparison[:cross_journey_analysis] = analyze_cross_journey_funnels(funnel_comparison)
    
    funnel_comparison
  end
  
  def compare_engagement_metrics(period = 'daily', days = 30)
    engagement_comparison = {}
    
    @journeys.each do |journey|
      metrics = JourneyMetric.get_journey_dashboard_metrics(journey.id, period)
      
      engagement_metrics = metrics.select { |metric_name, _| 
        JourneyMetric::ENGAGEMENT_METRICS.include?(metric_name) 
      }
      
      engagement_comparison[journey.id] = {
        journey_name: journey.name,
        engagement_metrics: engagement_metrics,
        engagement_score: calculate_overall_engagement_score(engagement_metrics),
        engagement_trends: JourneyMetric.get_metric_trend(journey.id, 'engagement_score', 7, period)
      }
    end
    
    # Rank journeys by engagement
    engagement_comparison[:rankings] = rank_by_engagement(engagement_comparison)
    
    engagement_comparison
  end
  
  def statistical_significance_analysis
    return {} if @journeys.count != 2
    
    journey1, journey2 = @journeys
    
    # Get recent analytics for both journeys
    analytics1 = journey1.journey_analytics.recent.limit(10)
    analytics2 = journey2.journey_analytics.recent.limit(10)
    
    return {} if analytics1.empty? || analytics2.empty?
    
    {
      conversion_rate_significance: calculate_metric_significance(
        analytics1.pluck(:conversion_rate),
        analytics2.pluck(:conversion_rate),
        'conversion_rate'
      ),
      engagement_score_significance: calculate_metric_significance(
        analytics1.pluck(:engagement_score),
        analytics2.pluck(:engagement_score),
        'engagement_score'
      ),
      execution_volume_significance: calculate_metric_significance(
        analytics1.pluck(:total_executions),
        analytics2.pluck(:total_executions),
        'total_executions'
      ),
      overall_assessment: generate_significance_assessment(analytics1, analytics2)
    }
  end
  
  def generate_comparison_recommendations
    return [] if @journeys.count < 2
    
    recommendations = []
    performance_metrics = compare_performance_metrics
    
    # Find best and worst performers
    best_performer = performance_metrics.max_by { |_, metrics| metrics[:average_conversion_rate] }
    worst_performer = performance_metrics.min_by { |_, metrics| metrics[:average_conversion_rate] }
    
    if best_performer && worst_performer && best_performer[0] != worst_performer[0]
      best_journey = @journeys.find(best_performer[0])
      worst_journey = @journeys.find(worst_performer[0])
      
      conversion_diff = best_performer[1][:average_conversion_rate] - worst_performer[1][:average_conversion_rate]
      
      if conversion_diff > 2.0
        recommendations << {
          type: 'optimization_opportunity',
          priority: 'high',
          title: 'Significant Performance Gap Identified',
          description: "#{best_journey.name} outperforms #{worst_journey.name} by #{conversion_diff.round(1)}% conversion rate.",
          action_items: [
            "Analyze successful elements from #{best_journey.name}",
            "Consider A/B testing best practices from high-performer",
            "Review journey flow differences for optimization opportunities"
          ],
          best_performer: best_journey.name,
          worst_performer: worst_journey.name
        }
      end
    end
    
    # Engagement analysis recommendations
    engagement_comparison = compare_engagement_metrics
    low_engagement_journeys = engagement_comparison.select do |journey_id, data|
      next false if journey_id == :rankings
      data[:engagement_score] < 60
    end
    
    if low_engagement_journeys.any?
      recommendations << {
        type: 'engagement_improvement',
        priority: 'medium',
        title: 'Low Engagement Detected',
        description: "#{low_engagement_journeys.count} journey(s) have engagement scores below 60%.",
        action_items: [
          'Review content relevance and quality',
          'Analyze user interaction patterns',
          'Consider personalizing content based on persona'
        ],
        affected_journeys: low_engagement_journeys.map { |_, data| data[:journey_name] }
      }
    end
    
    # Funnel analysis recommendations
    funnel_comparison = compare_conversion_funnels
    journeys_with_bottlenecks = funnel_comparison.select do |journey_id, data|
      next false if journey_id == :cross_journey_analysis
      data[:bottlenecks].any?
    end
    
    if journeys_with_bottlenecks.any?
      recommendations << {
        type: 'funnel_optimization',
        priority: 'high',
        title: 'Conversion Bottlenecks Identified',
        description: "Multiple journeys have identified conversion bottlenecks that may be limiting performance.",
        action_items: [
          'Focus on optimizing identified bottleneck stages',
          'Consider alternative approaches for problematic steps',
          'Implement progressive disclosure for complex steps'
        ],
        bottleneck_details: journeys_with_bottlenecks.map do |journey_id, data|
          {
            journey: data[:journey_name],
            bottlenecks: data[:bottlenecks]
          }
        end
      }
    end
    
    recommendations
  end
  
  def self.benchmark_against_industry(journey, industry_metrics = {})
    # This would compare journey metrics against industry benchmarks
    # For now, use default benchmarks
    default_benchmarks = {
      conversion_rate: 5.0,
      engagement_score: 70.0,
      completion_rate: 65.0,
      abandonment_rate: 35.0
    }
    
    benchmarks = industry_metrics.empty? ? default_benchmarks : industry_metrics
    journey_metrics = journey.analytics_summary(30)
    
    return {} if journey_metrics.empty?
    
    comparison = {}
    
    benchmarks.each do |metric, benchmark_value|
      journey_value = case metric
                     when :conversion_rate
                       journey_metrics[:average_conversion_rate]
                     when :completion_rate
                       journey_metrics[:completed_executions].to_f / 
                       [journey_metrics[:total_executions], 1].max * 100
                     when :abandonment_rate
                       journey_metrics[:abandoned_executions].to_f / 
                       [journey_metrics[:total_executions], 1].max * 100
                     else
                       journey_metrics[metric] || 0
                     end
      
      performance_rating = if journey_value >= benchmark_value * 1.2
                            'excellent'
                          elsif journey_value >= benchmark_value
                            'above_average'
                          elsif journey_value >= benchmark_value * 0.8
                            'average'
                          else
                            'below_average'
                          end
      
      comparison[metric] = {
        journey_value: journey_value.round(2),
        benchmark_value: benchmark_value,
        difference: (journey_value - benchmark_value).round(2),
        performance_rating: performance_rating
      }
    end
    
    comparison
  end
  
  private
  
  def calculate_completion_rate(analytics)
    total_executions = analytics.sum(:total_executions)
    completed_executions = analytics.sum(:completed_executions)
    
    return 0 if total_executions == 0
    (completed_executions.to_f / total_executions * 100).round(2)
  end
  
  def calculate_abandonment_rate(analytics)
    total_executions = analytics.sum(:total_executions)
    abandoned_executions = analytics.sum(:abandoned_executions)
    
    return 0 if total_executions == 0
    (abandoned_executions.to_f / total_executions * 100).round(2)
  end
  
  def default_metrics(journey)
    {
      journey_name: journey.name,
      total_executions: 0,
      completed_executions: 0,
      abandoned_executions: 0,
      average_conversion_rate: 0,
      average_engagement_score: 0,
      average_completion_time: 0,
      completion_rate: 0,
      abandonment_rate: 0
    }
  end
  
  def add_performance_rankings(metrics_comparison)
    # Rank journeys by conversion rate
    sorted_by_conversion = metrics_comparison.sort_by { |_, metrics| -metrics[:average_conversion_rate] }
    
    sorted_by_conversion.each_with_index do |(journey_id, metrics), index|
      metrics[:conversion_rate_rank] = index + 1
    end
    
    # Rank by engagement score
    sorted_by_engagement = metrics_comparison.sort_by { |_, metrics| -metrics[:average_engagement_score] }
    
    sorted_by_engagement.each_with_index do |(journey_id, metrics), index|
      metrics[:engagement_score_rank] = index + 1
    end
    
    # Calculate overall performance rank
    metrics_comparison.each do |journey_id, metrics|
      overall_score = (metrics[:average_conversion_rate] * 0.4 + 
                      metrics[:average_engagement_score] * 0.3 + 
                      metrics[:completion_rate] * 0.3)
      metrics[:overall_performance_score] = overall_score.round(2)
    end
    
    sorted_by_overall = metrics_comparison.sort_by { |_, metrics| -metrics[:overall_performance_score] }
    sorted_by_overall.each_with_index do |(journey_id, metrics), index|
      metrics[:overall_rank] = index + 1
    end
    
    metrics_comparison
  end
  
  def analyze_funnel_stages(funnel_data)
    return {} unless funnel_data[:stages]
    
    stages = funnel_data[:stages]
    stage_analysis = {}
    
    stages.each_with_index do |stage, index|
      next_stage = stages[index + 1]
      
      stage_analysis[stage[:stage]] = {
        conversion_rate: stage[:conversion_rate],
        drop_off_rate: stage[:drop_off_rate],
        visitors: stage[:visitors],
        conversions: stage[:conversions],
        efficiency: next_stage ? 
          (next_stage[:visitors].to_f / stage[:conversions] * 100).round(1) : 100
      }
    end
    
    stage_analysis
  end
  
  def identify_journey_bottlenecks(funnel_data)
    return [] unless funnel_data[:stages]
    
    stages = funnel_data[:stages]
    bottlenecks = []
    
    stages.each do |stage|
      if stage[:drop_off_rate] > 50
        bottlenecks << {
          stage: stage[:stage],
          drop_off_rate: stage[:drop_off_rate],
          severity: stage[:drop_off_rate] > 70 ? 'high' : 'medium'
        }
      end
    end
    
    bottlenecks
  end
  
  def analyze_cross_journey_funnels(funnel_comparison)
    return {} if funnel_comparison.empty?
    
    stage_performance = {}
    
    Journey::STAGES.each do |stage|
      stage_data = []
      
      funnel_comparison.each do |journey_id, data|
        next if journey_id == :cross_journey_analysis
        
        stage_breakdown = data[:stage_breakdown][stage]
        if stage_breakdown
          stage_data << {
            journey_id: journey_id,
            journey_name: data[:journey_name],
            conversion_rate: stage_breakdown[:conversion_rate],
            drop_off_rate: stage_breakdown[:drop_off_rate]
          }
        end
      end
      
      next if stage_data.empty?
      
      best_performer = stage_data.max_by { |d| d[:conversion_rate] }
      worst_performer = stage_data.min_by { |d| d[:conversion_rate] }
      
      stage_performance[stage] = {
        average_conversion_rate: (stage_data.sum { |d| d[:conversion_rate] } / stage_data.count).round(2),
        best_performer: best_performer,
        worst_performer: worst_performer,
        performance_spread: (best_performer[:conversion_rate] - worst_performer[:conversion_rate]).round(2)
      }
    end
    
    stage_performance
  end
  
  def calculate_overall_engagement_score(engagement_metrics)
    return 0 if engagement_metrics.empty?
    
    scores = engagement_metrics.values.map { |metric| metric[:value] || 0 }
    (scores.sum / scores.count).round(2)
  end
  
  def rank_by_engagement(engagement_comparison)
    engagement_scores = engagement_comparison.reject { |k, _| k == :rankings }
                                           .map { |journey_id, data| [journey_id, data[:engagement_score]] }
                                           .sort_by { |_, score| -score }
    
    rankings = {}
    engagement_scores.each_with_index do |(journey_id, score), index|
      journey_name = engagement_comparison[journey_id][:journey_name]
      rankings[index + 1] = {
        journey_id: journey_id,
        journey_name: journey_name,
        engagement_score: score
      }
    end
    
    rankings
  end
  
  def calculate_metric_significance(values1, values2, metric_name)
    return {} if values1.empty? || values2.empty?
    
    mean1 = values1.sum.to_f / values1.count
    mean2 = values2.sum.to_f / values2.count
    
    # Simple t-test approximation
    variance1 = values1.sum { |x| (x - mean1) ** 2 } / [values1.count - 1, 1].max
    variance2 = values2.sum { |x| (x - mean2) ** 2 } / [values2.count - 1, 1].max
    
    pooled_se = Math.sqrt(variance1 / values1.count + variance2 / values2.count)
    
    return {} if pooled_se == 0
    
    t_stat = (mean1 - mean2).abs / pooled_se
    
    # Simplified significance determination
    significance_level = if t_stat > 2.58
                          'highly_significant'
                        elsif t_stat > 1.96
                          'significant'
                        elsif t_stat > 1.64
                          'marginally_significant'
                        else
                          'not_significant'
                        end
    
    {
      metric_name: metric_name,
      mean1: mean1.round(2),
      mean2: mean2.round(2),
      difference: (mean1 - mean2).round(2),
      t_statistic: t_stat.round(3),
      significance_level: significance_level,
      sample_sizes: [values1.count, values2.count]
    }
  end
  
  def generate_significance_assessment(analytics1, analytics2)
    journey1_name = @journeys.first.name
    journey2_name = @journeys.last.name
    
    mean_conversion1 = analytics1.average(:conversion_rate) || 0
    mean_conversion2 = analytics2.average(:conversion_rate) || 0
    
    if (mean_conversion1 - mean_conversion2).abs < 1.0
      "Performance between #{journey1_name} and #{journey2_name} is statistically similar"
    elsif mean_conversion1 > mean_conversion2
      "#{journey1_name} shows significantly better conversion performance than #{journey2_name}"
    else
      "#{journey2_name} shows significantly better conversion performance than #{journey1_name}"
    end
  end
end