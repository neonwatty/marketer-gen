class ResourceAllocationService < ApplicationService
  attr_reader :user, :campaign_plan, :allocation_params

  def initialize(user:, campaign_plan: nil, allocation_params: {})
    @user = user
    @campaign_plan = campaign_plan
    @allocation_params = allocation_params
  end

  def call
    log_service_call('ResourceAllocationService', allocation_params)
    
    case allocation_params[:action]
    when 'optimize'
      optimize_allocations
    when 'predict'
      predict_performance
    when 'rebalance'
      rebalance_budget
    when 'create'
      create_allocation
    else
      handle_service_error(StandardError.new("Unknown action: #{allocation_params[:action]}"))
    end
  rescue StandardError => e
    handle_service_error(e, { user_id: user&.id, campaign_plan_id: campaign_plan&.id })
  end

  private

  # Helper method for logging service calls - duplicated due to Rails autoloading issues
  def log_service_call(service_name, params = {})
    Rails.logger.info "Service Call: #{service_name} with params: #{params.inspect}"
  end

  # Helper method for successful service responses - duplicated due to Rails autoloading issues
  def success_response(data = {})
    {
      success: true,
      data: data
    }
  end

  # Helper method for handling service errors - duplicated due to Rails autoloading issues
  def handle_service_error(error, context = {})
    Rails.logger.error "Service Error in #{self.class}: #{error.message}"
    Rails.logger.error "Context: #{context.inspect}" if context.any?
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    {
      success: false,
      error: error.message,
      context: context
    }
  end

  def optimize_allocations
    total_budget = allocation_params[:total_budget].to_f
    channels = allocation_params[:channels] || default_channels
    objectives = allocation_params[:objectives] || ['conversions']
    time_period = allocation_params[:time_period] || default_time_period
    
    return handle_service_error(StandardError.new("Invalid budget amount")) if total_budget <= 0
    
    optimized_allocations = calculate_optimal_distribution(total_budget, channels, objectives, time_period)
    performance_predictions = generate_performance_predictions(optimized_allocations)
    
    success_response({
      allocations: optimized_allocations,
      predictions: performance_predictions,
      optimization_score: calculate_optimization_score(optimized_allocations),
      recommendations: generate_recommendations(optimized_allocations)
    })
  end

  def predict_performance(allocations = nil)
    allocations ||= user.budget_allocations.active
    
    predictions = allocations.map do |allocation|
      {
        allocation_id: allocation.id,
        predicted_metrics: calculate_predicted_metrics(allocation),
        confidence_score: calculate_confidence_score(allocation),
        risk_assessment: assess_risk_factors(allocation)
      }
    end
    
    success_response({
      predictions: predictions,
      aggregate_forecast: calculate_aggregate_forecast(predictions)
    })
  end

  def rebalance_budget
    current_allocations = user.budget_allocations.active
    performance_data = collect_real_time_performance(current_allocations)
    
    rebalanced_allocations = apply_rebalancing_algorithm(current_allocations, performance_data)
    
    success_response({
      original_allocations: current_allocations.map(&:attributes),
      rebalanced_allocations: rebalanced_allocations,
      rebalancing_rationale: generate_rebalancing_rationale(performance_data)
    })
  end

  def create_allocation
    allocation = user.budget_allocations.build(allocation_creation_params)
    
    if allocation_params[:enable_predictive_modeling]
      allocation.predictive_model_data = generate_predictive_model_data(allocation)
    end
    
    if allocation.save
      success_response({ allocation: allocation, optimization_suggestions: suggest_optimizations(allocation) })
    else
      handle_service_error(StandardError.new("Allocation creation failed: #{allocation.errors.full_messages.join(', ')}"))
    end
  end

  def calculate_optimal_distribution(total_budget, channels, objectives, time_period)
    base_allocations = initialize_base_allocations(total_budget, channels)
    
    # Apply optimization factors
    optimized_allocations = channels.map.with_index do |channel, index|
      base_amount = base_allocations[index]
      
      {
        channel_type: channel,
        allocated_amount: apply_optimization_factors(base_amount, channel, objectives, time_period),
        optimization_factors: get_channel_optimization_factors(channel, objectives),
        time_period_start: time_period[:start],
        time_period_end: time_period[:end]
      }
    end
    
    # Normalize to ensure total equals the original budget
    actual_total = optimized_allocations.sum { |a| a[:allocated_amount] }
    if actual_total != total_budget && actual_total > 0
      normalization_factor = total_budget / actual_total
      optimized_allocations.each do |allocation|
        allocation[:allocated_amount] = (allocation[:allocated_amount] * normalization_factor).round(2)
      end
    end
    
    optimized_allocations
  end

  def initialize_base_allocations(total_budget, channels)
    equal_split = total_budget / channels.length
    
    channels.map do |channel|
      channel_weight = get_channel_base_weight(channel)
      equal_split * channel_weight
    end
  end

  def apply_optimization_factors(base_amount, channel, objectives, time_period)
    objective_multiplier = calculate_objective_multiplier(channel, objectives)
    seasonal_multiplier = calculate_seasonal_multiplier(channel, time_period)
    performance_multiplier = calculate_historical_performance_multiplier(channel)
    
    optimized_amount = base_amount * objective_multiplier * seasonal_multiplier * performance_multiplier
    optimized_amount.round(2)
  end

  def get_channel_base_weight(channel)
    channel_weights = {
      'social_media' => 1.0,
      'search' => 1.2,
      'email' => 0.8,
      'display' => 0.9,
      'video' => 1.1,
      'content_marketing' => 1.0
    }
    
    channel_weights[channel] || 1.0
  end

  def calculate_objective_multiplier(channel, objectives)
    objective_channel_affinity = {
      'awareness' => {
        'social_media' => 1.3,
        'display' => 1.2,
        'video' => 1.4,
        'content_marketing' => 1.1
      },
      'engagement' => {
        'social_media' => 1.4,
        'email' => 1.3,
        'content_marketing' => 1.2
      },
      'conversions' => {
        'search' => 1.4,
        'email' => 1.3,
        'display' => 1.1
      },
      'revenue' => {
        'search' => 1.3,
        'email' => 1.2,
        'display' => 1.1
      }
    }
    
    total_multiplier = objectives.sum do |objective|
      objective_channel_affinity.dig(objective, channel) || 1.0
    end
    
    total_multiplier / objectives.length
  end

  def calculate_seasonal_multiplier(channel, time_period)
    start_month = Date.parse(time_period[:start]).month
    
    seasonal_adjustments = {
      'social_media' => { 12 => 1.2, 1 => 1.1, 11 => 1.1 },
      'search' => { 11 => 1.3, 12 => 1.4, 1 => 1.1 },
      'email' => { 11 => 1.2, 12 => 1.3, 1 => 1.1 }
    }
    
    seasonal_adjustments.dig(channel, start_month) || 1.0
  end

  def calculate_historical_performance_multiplier(channel)
    recent_allocations = user.budget_allocations.where(channel_type: channel)
                            .where('created_at > ?', 3.months.ago)
    
    return 1.0 if recent_allocations.empty?
    
    avg_efficiency = recent_allocations.average(:efficiency_score) || 0
    
    case avg_efficiency
    when 80..Float::INFINITY then 1.2
    when 60..79 then 1.1
    when 40..59 then 1.0
    when 20..39 then 0.9
    else 0.8
    end
  end

  def generate_performance_predictions(allocations)
    allocations.map do |allocation|
      {
        channel_type: allocation[:channel_type],
        predicted_reach: calculate_predicted_reach(allocation),
        predicted_engagement: calculate_predicted_engagement(allocation),
        predicted_conversions: calculate_predicted_conversions(allocation),
        predicted_roi: calculate_predicted_roi(allocation),
        confidence_interval: calculate_confidence_interval(allocation)
      }
    end
  end

  def calculate_predicted_metrics(allocation)
    base_cpm = get_channel_base_cpm(allocation.channel_type)
    budget = allocation.allocated_amount
    duration = allocation.duration_days
    
    {
      estimated_impressions: (budget / base_cpm * 1000).round,
      estimated_clicks: ((budget / base_cpm * 1000) * get_channel_ctr(allocation.channel_type)).round,
      estimated_conversions: ((budget / base_cpm * 1000) * get_channel_ctr(allocation.channel_type) * get_channel_cvr(allocation.channel_type)).round,
      estimated_revenue: calculate_estimated_revenue(allocation),
      daily_budget: allocation.daily_allocation
    }
  end

  def calculate_confidence_score(allocation)
    factors = []
    
    factors << (allocation.allocated_amount > 1000 ? 0.9 : 0.7)
    factors << (allocation.duration_days > 30 ? 0.9 : 0.8)
    factors << get_channel_prediction_confidence(allocation.channel_type)
    factors << (user.budget_allocations.where(channel_type: allocation.channel_type).count > 0 ? 0.9 : 0.7)
    
    (factors.sum / factors.length).round(2)
  end

  def assess_risk_factors(allocation)
    risks = []
    
    risks << 'high_budget_concentration' if allocation.allocation_percentage > 50
    risks << 'short_duration' if allocation.duration_days < 14
    risks << 'new_channel' if user.budget_allocations.where(channel_type: allocation.channel_type).count == 0
    risks << 'competitive_period' if is_competitive_period?(allocation.time_period_start)
    
    {
      risk_level: calculate_overall_risk_level(risks),
      risk_factors: risks,
      mitigation_suggestions: generate_risk_mitigation_suggestions(risks)
    }
  end

  def collect_real_time_performance(allocations)
    allocations.map do |allocation|
      {
        allocation_id: allocation.id,
        current_spend: allocation.performance_metrics&.dig('spent_to_date') || 0,
        current_performance: allocation.performance_metrics&.dig('current_metrics') || {},
        burn_rate: allocation.performance_metrics&.dig('burn_rate') || 0,
        days_remaining: (allocation.time_period_end - Date.current).to_i
      }
    end
  end

  def apply_rebalancing_algorithm(current_allocations, performance_data)
    performance_data.map do |data|
      allocation = current_allocations.find(data[:allocation_id])
      performance_score = calculate_performance_score(data)
      
      adjustment_factor = calculate_adjustment_factor(performance_score, data[:days_remaining])
      new_amount = [allocation.allocated_amount * adjustment_factor, allocation.total_budget * 0.1].max
      
      {
        allocation_id: allocation.id,
        original_amount: allocation.allocated_amount,
        recommended_amount: new_amount.round(2),
        adjustment_reason: determine_adjustment_reason(performance_score, data)
      }
    end
  end

  def generate_predictive_model_data(allocation)
    {
      model_version: '1.0',
      confidence_score: calculate_confidence_score(allocation),
      predicted_performance: calculate_predicted_metrics(allocation),
      generated_at: Time.current.iso8601,
      factors_considered: [
        'historical_performance',
        'seasonal_trends',
        'channel_efficiency',
        'budget_size',
        'campaign_duration'
      ]
    }
  end

  def suggest_optimizations(allocation)
    suggestions = []
    
    if allocation.allocation_percentage > 70
      suggestions << { type: 'budget_distribution', message: 'Consider diversifying across multiple channels' }
    end
    
    if allocation.duration_days < 14
      suggestions << { type: 'duration', message: 'Longer campaigns typically perform better' }
    end
    
    if allocation.daily_allocation < 50
      suggestions << { type: 'daily_budget', message: 'Consider increasing daily budget for better reach' }
    end
    
    suggestions
  end

  def default_channels
    %w[social_media search email display]
  end

  def default_time_period
    {
      start: Date.current.to_s,
      end: (Date.current + 30.days).to_s
    }
  end

  def allocation_creation_params
    allocation_params.except(:action, :enable_predictive_modeling).merge(
      campaign_plan: campaign_plan
    )
  end

  def get_channel_base_cpm(channel)
    base_cpms = {
      'social_media' => 5.0,
      'search' => 2.5,
      'email' => 0.1,
      'display' => 3.0,
      'video' => 8.0,
      'content_marketing' => 4.0
    }
    
    base_cpms[channel] || 4.0
  end

  def get_channel_ctr(channel)
    ctrs = {
      'social_media' => 0.02,
      'search' => 0.03,
      'email' => 0.25,
      'display' => 0.015,
      'video' => 0.018,
      'content_marketing' => 0.022
    }
    
    ctrs[channel] || 0.02
  end

  def get_channel_cvr(channel)
    cvrs = {
      'social_media' => 0.08,
      'search' => 0.12,
      'email' => 0.15,
      'display' => 0.06,
      'video' => 0.09,
      'content_marketing' => 0.10
    }
    
    cvrs[channel] || 0.08
  end

  def calculate_optimization_score(allocations)
    total_budget = allocations.sum { |a| a[:allocated_amount] }
    return 0 if total_budget.zero?
    
    weighted_score = allocations.sum do |allocation|
      channel_efficiency = get_channel_base_weight(allocation[:channel_type])
      allocation_weight = allocation[:allocated_amount] / total_budget
      channel_efficiency * allocation_weight * 100
    end
    
    weighted_score.round(2)
  end

  def generate_recommendations(allocations)
    recommendations = []
    
    total_budget = allocations.sum { |a| a[:allocated_amount] }
    high_performing_channels = allocations.select { |a| get_channel_base_weight(a[:channel_type]) > 1.1 }
    
    if high_performing_channels.sum { |a| a[:allocated_amount] } / total_budget < 0.6
      recommendations << "Consider increasing allocation to high-performing channels like search and video"
    end
    
    if allocations.length < 3
      recommendations << "Diversifying across more channels can improve overall campaign resilience"
    end
    
    recommendations
  end

  def calculate_predicted_reach(allocation)
    base_cpm = get_channel_base_cpm(allocation[:channel_type])
    (allocation[:allocated_amount] / base_cpm * 1000).round
  end

  def calculate_predicted_engagement(allocation)
    reach = calculate_predicted_reach(allocation)
    engagement_rate = get_channel_ctr(allocation[:channel_type])
    (reach * engagement_rate).round
  end

  def calculate_predicted_conversions(allocation)
    engagements = calculate_predicted_engagement(allocation)
    conversion_rate = get_channel_cvr(allocation[:channel_type])
    (engagements * conversion_rate).round
  end

  def calculate_predicted_roi(allocation)
    conversions = calculate_predicted_conversions(allocation)
    avg_order_value = 150 # This should be configurable or pulled from user data
    revenue = conversions * avg_order_value
    
    return 0 if allocation[:allocated_amount].zero?
    ((revenue - allocation[:allocated_amount]) / allocation[:allocated_amount] * 100).round(2)
  end

  def calculate_confidence_interval(allocation)
    base_confidence = 0.8
    budget_factor = [allocation[:allocated_amount] / 1000, 1.5].min
    
    confidence = base_confidence * budget_factor
    margin = (1 - confidence) * 0.5
    
    {
      lower_bound: (confidence - margin).round(2),
      upper_bound: [confidence + margin, 0.95].min.round(2)
    }
  end

  def get_channel_prediction_confidence(channel)
    confidence_scores = {
      'search' => 0.9,
      'email' => 0.85,
      'social_media' => 0.75,
      'display' => 0.7,
      'video' => 0.8,
      'content_marketing' => 0.8
    }
    
    confidence_scores[channel] || 0.75
  end

  def calculate_estimated_revenue(allocation)
    conversions = calculate_predicted_conversions(allocation)
    avg_order_value = 150 # Should be configurable
    conversions * avg_order_value
  end

  def is_competitive_period?(date)
    # Check if date falls during competitive periods (holidays, etc.)
    month = Date.parse(date.to_s).month
    [11, 12].include?(month) # November and December are competitive
  end

  def calculate_overall_risk_level(risks)
    case risks.length
    when 0 then 'low'
    when 1..2 then 'medium'
    else 'high'
    end
  end

  def generate_risk_mitigation_suggestions(risks)
    suggestions = []
    
    risks.each do |risk|
      case risk
      when 'high_budget_concentration'
        suggestions << 'Diversify budget across multiple channels'
      when 'short_duration'
        suggestions << 'Extend campaign duration for better optimization'
      when 'new_channel'
        suggestions << 'Start with lower budget to test channel performance'
      when 'competitive_period'
        suggestions << 'Increase budget to compete effectively during peak periods'
      end
    end
    
    suggestions
  end

  def calculate_performance_score(performance_data)
    current_metrics = performance_data[:current_performance] || {}
    efficiency = current_metrics[:efficiency] || 50
    
    # Normalize to 0-1 scale
    efficiency / 100.0
  end

  def calculate_adjustment_factor(performance_score, days_remaining)
    base_factor = 1.0
    
    # Adjust based on performance
    if performance_score > 0.8
      performance_adjustment = 1.2 # Increase budget for high performers
    elsif performance_score < 0.4
      performance_adjustment = 0.8 # Decrease budget for poor performers
    else
      performance_adjustment = 1.0
    end
    
    # Adjust based on remaining time
    time_factor = days_remaining > 7 ? 1.0 : 0.9 # Be more conservative near end
    
    base_factor * performance_adjustment * time_factor
  end

  def determine_adjustment_reason(performance_score, data)
    if performance_score > 0.8
      'High performance - increasing allocation'
    elsif performance_score < 0.4
      'Poor performance - reducing allocation'
    elsif data[:days_remaining] < 7
      'Campaign ending soon - conservative adjustment'
    else
      'Performance-based rebalancing'
    end
  end

  def calculate_aggregate_forecast(predictions)
    return {} if predictions.empty?
    
    total_budget = predictions.sum { |p| p.dig(:predicted_metrics, :daily_budget) || 0 }
    avg_confidence = predictions.sum { |p| p[:confidence_score] || 0 } / predictions.length
    
    {
      total_predicted_budget: total_budget,
      average_confidence: avg_confidence.round(2),
      risk_distribution: predictions.group_by { |p| p.dig(:risk_assessment, :risk_level) }.transform_values(&:count)
    }
  end

  def generate_rebalancing_rationale(performance_data)
    high_performers = performance_data.select { |d| calculate_performance_score(d) > 0.8 }
    poor_performers = performance_data.select { |d| calculate_performance_score(d) < 0.4 }
    
    rationale = []
    rationale << "#{high_performers.length} allocations performing well - increased budget recommended" if high_performers.any?
    rationale << "#{poor_performers.length} allocations underperforming - budget reduction recommended" if poor_performers.any?
    
    rationale.empty? ? ['Balanced performance across allocations'] : rationale
  end

  def suggest_optimizations(allocation)
    suggestions = []
    
    if allocation.allocation_percentage > 70
      suggestions << { type: 'budget_distribution', message: 'Consider diversifying across multiple channels' }
    end
    
    if allocation.duration_days < 14
      suggestions << { type: 'duration', message: 'Longer campaigns typically perform better' }
    end
    
    if allocation.daily_allocation < 50
      suggestions << { type: 'daily_budget', message: 'Consider increasing daily budget for better reach' }
    end
    
    suggestions
  end

  def get_channel_optimization_factors(channel, objectives)
    {
      base_weight: get_channel_base_weight(channel),
      objective_multiplier: calculate_objective_multiplier(channel, objectives),
      seasonal_multiplier: calculate_seasonal_multiplier(channel, { start: Date.current.to_s }),
      performance_multiplier: calculate_historical_performance_multiplier(channel)
    }
  end
end