# frozen_string_literal: true

class PerformanceOptimizationService < ApplicationService
  attr_reader :campaign_plan, :optimization_rules, :performance_data

  def initialize(campaign_plan, performance_data = :not_provided, options = {})
    @campaign_plan = campaign_plan
    @performance_data = performance_data == :not_provided ? fetch_current_performance_data : performance_data
    @options = options
    @optimization_rules = load_active_optimization_rules
  end

  def call
    if respond_to?(:log_service_call)
      log_service_call('PerformanceOptimizationService', { 
        campaign_id: campaign_plan.id,
        rules_count: optimization_rules.count,
        performance_data_present: performance_data.present?
      })
    else
      Rails.logger.info "PerformanceOptimizationService called for campaign #{campaign_plan.id}"
    end

    unless performance_data.present?
      return {
        success: true,
        data: { message: 'No performance data available' }
      }
    end
    
    unless optimization_rules.any?
      return {
        success: true,
        data: { message: 'No active optimization rules found' }
      }
    end

    begin
      optimization_results = execute_optimization_cycle
      {
        success: true,
        data: optimization_results
      }
    rescue => error
      Rails.logger.error "PerformanceOptimizationService error: #{error.message}"
      {
        success: false,
        error: error.message,
        context: {
          campaign_id: campaign_plan.id,
          rules_evaluated: optimization_rules.count
        }
      }
    end
  end

  def self.optimize_campaign(campaign_plan, options = {})
    service = new(campaign_plan, nil, options)
    service.call
  end

  def self.bulk_optimize_campaigns(campaign_plans, options = {})
    results = []
    
    campaign_plans.each do |campaign_plan|
      begin
        result = optimize_campaign(campaign_plan, options)
        results << { campaign_id: campaign_plan.id, result: result }
      rescue => error
        Rails.logger.error "Bulk optimization failed for campaign #{campaign_plan.id}: #{error.message}"
        results << { campaign_id: campaign_plan.id, result: { success: false, error: error.message } }
      end
    end

    {
      success: true,
      data: {
        total_campaigns: campaign_plans.count,
        successful_optimizations: results.count { |r| r[:result][:success] },
        failed_optimizations: results.count { |r| !r[:result][:success] },
        results: results
      }
    }
  end

  private

  def execute_optimization_cycle
    triggered_rules = []
    optimization_results = []
    safety_violations = []

    optimization_rules.by_priority.each do |rule|
      next unless rule.should_trigger?(performance_data)

      Rails.logger.info "Optimization rule #{rule.id} (#{rule.name}) triggered for campaign #{campaign_plan.id}"
      
      if passes_safety_checks?(rule)
        begin
          result = execute_optimization_rule(rule)
          optimization_results << result
          triggered_rules << rule
          
          # Record the execution
          rule.record_execution!(result)
        rescue => error
          Rails.logger.error "Error executing rule #{rule.id}: #{error.message}"
          failed_result = {
            success: false,
            error: error.message,
            rule_id: rule.id,
            rule_type: rule.rule_type
          }
          optimization_results << failed_result
        end
      else
        safety_violation = {
          rule_id: rule.id,
          rule_name: rule.name,
          safety_check_failures: get_safety_check_failures(rule)
        }
        safety_violations << safety_violation
        Rails.logger.warn "Optimization rule #{rule.id} failed safety checks: #{safety_violation[:safety_check_failures]}"
      end
    end

    {
      triggered_rules_count: triggered_rules.count,
      successful_optimizations: optimization_results.count { |r| r[:success] },
      failed_optimizations: optimization_results.count { |r| !r[:success] },
      safety_violations: safety_violations,
      optimization_results: optimization_results,
      performance_snapshot: create_performance_snapshot,
      executed_at: Time.current
    }
  end

  def execute_optimization_rule(rule)
    Rails.logger.info "Executing optimization rule #{rule.id} (#{rule.rule_type})"
    
    case rule.rule_type
    when 'budget_reallocation'
      execute_budget_reallocation(rule)
    when 'bid_adjustment'
      execute_bid_adjustment(rule)
    when 'audience_expansion'
      execute_audience_expansion(rule)
    when 'audience_refinement'
      execute_audience_refinement(rule)
    when 'creative_rotation'
      execute_creative_rotation(rule)
    when 'schedule_optimization'
      execute_schedule_optimization(rule)
    when 'platform_optimization'
      execute_platform_optimization(rule)
    when 'content_variant_testing'
      execute_content_variant_testing(rule)
    else
      {
        success: false,
        error: "Unknown optimization rule type: #{rule.rule_type}",
        rule_id: rule.id
      }
    end
  end

  def execute_budget_reallocation(rule)
    actions = rule.parsed_optimization_actions
    budget_adjustments = actions['budget_adjustments'] || {}
    
    results = []
    budget_adjustments.each do |platform, adjustment|
      result = adjust_platform_budget(platform, adjustment)
      results << result
    end

    {
      success: results.all? { |r| r[:success] },
      rule_id: rule.id,
      rule_type: rule.rule_type,
      actions_taken: results,
      performance_snapshot: create_performance_snapshot,
      trigger_reason: determine_trigger_reason(rule),
      confidence_score: calculate_confidence_score(rule),
      safety_checks_passed: passes_safety_checks?(rule)
    }
  end

  def execute_bid_adjustment(rule)
    actions = rule.parsed_optimization_actions
    bid_adjustments = actions['bid_adjustments'] || {}
    
    results = []
    bid_adjustments.each do |platform, adjustment|
      result = adjust_platform_bids(platform, adjustment)
      results << result
    end

    {
      success: results.all? { |r| r[:success] },
      rule_id: rule.id,
      rule_type: rule.rule_type,
      actions_taken: results,
      performance_snapshot: create_performance_snapshot,
      trigger_reason: determine_trigger_reason(rule),
      confidence_score: calculate_confidence_score(rule),
      safety_checks_passed: passes_safety_checks?(rule)
    }
  end

  def execute_audience_expansion(rule)
    actions = rule.parsed_optimization_actions
    expansion_settings = actions['audience_expansion'] || {}
    
    results = []
    expansion_settings.each do |platform, settings|
      result = expand_audience(platform, settings)
      results << result
    end

    {
      success: results.all? { |r| r[:success] },
      rule_id: rule.id,
      rule_type: rule.rule_type,
      actions_taken: results,
      performance_snapshot: create_performance_snapshot,
      trigger_reason: determine_trigger_reason(rule),
      confidence_score: calculate_confidence_score(rule),
      safety_checks_passed: passes_safety_checks?(rule)
    }
  end

  def execute_audience_refinement(rule)
    actions = rule.parsed_optimization_actions
    refinement_settings = actions['audience_refinement'] || {}
    
    results = []
    refinement_settings.each do |platform, settings|
      result = refine_audience(platform, settings)
      results << result
    end

    {
      success: results.all? { |r| r[:success] },
      rule_id: rule.id,
      rule_type: rule.rule_type,
      actions_taken: results,
      performance_snapshot: create_performance_snapshot,
      trigger_reason: determine_trigger_reason(rule),
      confidence_score: calculate_confidence_score(rule),
      safety_checks_passed: passes_safety_checks?(rule)
    }
  end

  def execute_creative_rotation(rule)
    actions = rule.parsed_optimization_actions
    rotation_settings = actions['creative_rotation'] || {}
    
    results = []
    rotation_settings.each do |platform, settings|
      result = rotate_creative_assets(platform, settings)
      results << result
    end

    {
      success: results.all? { |r| r[:success] },
      rule_id: rule.id,
      rule_type: rule.rule_type,
      actions_taken: results,
      performance_snapshot: create_performance_snapshot,
      trigger_reason: determine_trigger_reason(rule),
      confidence_score: calculate_confidence_score(rule),
      safety_checks_passed: passes_safety_checks?(rule)
    }
  end

  def execute_schedule_optimization(rule)
    actions = rule.parsed_optimization_actions
    schedule_adjustments = actions['schedule_optimization'] || {}
    
    results = []
    schedule_adjustments.each do |platform, adjustment|
      result = optimize_ad_schedule(platform, adjustment)
      results << result
    end

    {
      success: results.all? { |r| r[:success] },
      rule_id: rule.id,
      rule_type: rule.rule_type,
      actions_taken: results,
      performance_snapshot: create_performance_snapshot,
      trigger_reason: determine_trigger_reason(rule),
      confidence_score: calculate_confidence_score(rule),
      safety_checks_passed: passes_safety_checks?(rule)
    }
  end

  def execute_platform_optimization(rule)
    actions = rule.parsed_optimization_actions
    platform_adjustments = actions['platform_optimization'] || {}
    
    results = []
    platform_adjustments.each do |platform, optimization|
      result = optimize_platform_settings(platform, optimization)
      results << result
    end

    {
      success: results.all? { |r| r[:success] },
      rule_id: rule.id,
      rule_type: rule.rule_type,
      actions_taken: results,
      performance_snapshot: create_performance_snapshot,
      trigger_reason: determine_trigger_reason(rule),
      confidence_score: calculate_confidence_score(rule),
      safety_checks_passed: passes_safety_checks?(rule)
    }
  end

  def execute_content_variant_testing(rule)
    actions = rule.parsed_optimization_actions
    variant_settings = actions['content_variant_testing'] || {}
    
    results = []
    variant_settings.each do |platform, settings|
      result = launch_content_variant_test(platform, settings)
      results << result
    end

    {
      success: results.all? { |r| r[:success] },
      rule_id: rule.id,
      rule_type: rule.rule_type,
      actions_taken: results,
      performance_snapshot: create_performance_snapshot,
      trigger_reason: determine_trigger_reason(rule),
      confidence_score: calculate_confidence_score(rule),
      safety_checks_passed: passes_safety_checks?(rule)
    }
  end

  def passes_safety_checks?(rule)
    safety_checks = rule.parsed_safety_checks
    return true if safety_checks.empty?

    # Check campaign age
    min_age_hours = safety_checks['minimum_campaign_age_hours'] || 24
    return false if campaign_plan.created_at > min_age_hours.hours.ago

    # Check minimum data points
    min_data_points = safety_checks['require_minimum_data_points'] || 100
    return false if get_data_points_count < min_data_points

    # Check maximum daily executions
    max_daily_executions = safety_checks['maximum_daily_executions'] || 3
    daily_executions = rule.optimization_executions
                          .where('executed_at >= ?', 24.hours.ago)
                          .count
    return false if daily_executions >= max_daily_executions

    # Check budget change limits
    if performance_data.dig('budget_metrics')
      max_budget_change = safety_checks['max_budget_change_percent'] || 20
      proposed_change = calculate_proposed_budget_change(rule)
      return false if proposed_change.abs > max_budget_change
    end

    # Check bid change limits
    if performance_data.dig('bid_metrics')
      max_bid_change = safety_checks['max_bid_change_percent'] || 50
      proposed_change = calculate_proposed_bid_change(rule)
      return false if proposed_change.abs > max_bid_change
    end

    true
  end

  def get_safety_check_failures(rule)
    failures = []
    safety_checks = rule.parsed_safety_checks
    
    min_age_hours = safety_checks['minimum_campaign_age_hours'] || 24
    if campaign_plan.created_at > min_age_hours.hours.ago
      failures << "Campaign too young (< #{min_age_hours} hours)"
    end

    min_data_points = safety_checks['require_minimum_data_points'] || 100
    data_points = get_data_points_count
    if data_points < min_data_points
      failures << "Insufficient data points (#{data_points} < #{min_data_points})"
    end

    max_daily_executions = safety_checks['maximum_daily_executions'] || 3
    daily_executions = rule.optimization_executions
                          .where('executed_at >= ?', 24.hours.ago)
                          .count
    if daily_executions >= max_daily_executions
      failures << "Daily execution limit reached (#{daily_executions}/#{max_daily_executions})"
    end

    failures
  end

  def load_active_optimization_rules
    campaign_plan.optimization_rules.active.includes(:optimization_executions)
  end

  def fetch_current_performance_data
    # Return nil if campaign plan has no performance data
    return nil unless campaign_plan.performance_data.present?
    
    # In a real implementation, this would fetch data from various platform APIs
    # For now, we'll use mock data based on the campaign plan's performance data
    parsed_data = campaign_plan.parsed_performance_data
    
    {
      'roi' => parsed_data.dig('roi') || campaign_plan.current_roi || 0,
      'cpc' => extract_metric_from_performance_data('cpc') || 0,
      'cpm' => extract_metric_from_performance_data('cpm') || 0,
      'ctr' => extract_metric_from_performance_data('ctr') || 0,
      'conversion_rate' => extract_metric_from_performance_data('conversion_rate') || 0,
      'engagement_rate' => extract_metric_from_performance_data('engagement_rate') || 0,
      'cost_metrics' => extract_cost_metrics,
      'budget_metrics' => extract_budget_metrics,
      'bid_metrics' => extract_bid_metrics,
      'data_freshness' => Time.current,
      'platform_breakdown' => extract_platform_breakdown
    }
  end

  def create_performance_snapshot
    {
      'before' => performance_data,
      'timestamp' => Time.current,
      'campaign_id' => campaign_plan.id,
      'data_source' => 'performance_optimization_service'
    }
  end

  def determine_trigger_reason(rule)
    conditions = rule.parsed_trigger_conditions
    trigger_type = rule.trigger_type

    case trigger_type
    when 'performance_threshold'
      metric = conditions['metric']
      threshold = conditions['threshold']
      current_value = performance_data[metric]
      "#{metric} (#{current_value}) below threshold (#{threshold})"
    when 'cost_efficiency'
      "Cost efficiency optimization triggered"
    when 'schedule_based'
      "Scheduled optimization execution"
    else
      "#{trigger_type} trigger activated"
    end
  end

  def calculate_confidence_score(rule)
    # Base confidence from rule settings
    base_confidence = rule.confidence_threshold.to_f

    # Adjust based on data quality
    data_quality_factor = calculate_data_quality_factor.to_f
    
    # Adjust based on rule execution history
    history_factor = calculate_rule_history_factor(rule).to_f

    # Combine factors
    final_confidence = base_confidence * data_quality_factor * history_factor
    [final_confidence, 1.0].min.to_f
  end

  def calculate_data_quality_factor
    data_points = get_data_points_count
    data_age = get_data_age_hours

    # More data points = higher confidence
    points_factor = [data_points / 1000.0, 1.0].min

    # Fresher data = higher confidence
    age_factor = data_age <= 1 ? 1.0 : [1.0 / (data_age / 24.0), 0.5].max

    (points_factor + age_factor) / 2.0
  end

  def calculate_rule_history_factor(rule)
    return 0.8 if rule.execution_count.zero? # Default for new rules

    success_rate = rule.optimization_executions.successful.count.to_f / rule.execution_count
    [success_rate, 1.0].min
  end

  def get_data_points_count
    # Mock calculation - would analyze actual data volume
    performance_data.dig('data_points_count') || 500
  end

  def get_data_age_hours
    data_freshness = performance_data.dig('data_freshness')
    return 1 unless data_freshness

    if data_freshness.is_a?(Time)
      ((Time.current - data_freshness) / 1.hour).ceil
    else
      1 # Assume fresh if we can't determine age
    end
  end

  def calculate_proposed_budget_change(rule)
    # Mock calculation of proposed budget change percentage
    actions = rule.parsed_optimization_actions
    budget_adjustments = actions['budget_adjustments'] || {}
    
    return 0 if budget_adjustments.empty?
    
    # Calculate average proposed change
    changes = budget_adjustments.values.map { |adj| adj.dig('change_percent') || 0 }
    changes.sum.to_f / changes.length
  end

  def calculate_proposed_bid_change(rule)
    # Mock calculation of proposed bid change percentage
    actions = rule.parsed_optimization_actions
    bid_adjustments = actions['bid_adjustments'] || {}
    
    return 0 if bid_adjustments.empty?
    
    # Calculate average proposed change
    changes = bid_adjustments.values.map { |adj| adj.dig('change_percent') || 0 }
    changes.sum.to_f / changes.length
  end

  # Platform-specific optimization methods
  # These would integrate with actual platform APIs in a real implementation

  def adjust_platform_budget(platform, adjustment)
    Rails.logger.info "Adjusting #{platform} budget by #{adjustment}"
    
    # Mock implementation - would call platform API
    {
      success: true,
      platform: platform,
      action: 'budget_adjustment',
      adjustment: adjustment,
      executed_at: Time.current
    }
  end

  def adjust_platform_bids(platform, adjustment)
    Rails.logger.info "Adjusting #{platform} bids by #{adjustment}"
    
    # Mock implementation - would call platform API
    {
      success: true,
      platform: platform,
      action: 'bid_adjustment',
      adjustment: adjustment,
      executed_at: Time.current
    }
  end

  def expand_audience(platform, settings)
    Rails.logger.info "Expanding #{platform} audience with settings: #{settings}"
    
    # Mock implementation - would call platform API
    {
      success: true,
      platform: platform,
      action: 'audience_expansion',
      settings: settings,
      executed_at: Time.current
    }
  end

  def refine_audience(platform, settings)
    Rails.logger.info "Refining #{platform} audience with settings: #{settings}"
    
    # Mock implementation - would call platform API
    {
      success: true,
      platform: platform,
      action: 'audience_refinement',
      settings: settings,
      executed_at: Time.current
    }
  end

  def rotate_creative_assets(platform, settings)
    Rails.logger.info "Rotating #{platform} creative assets with settings: #{settings}"
    
    # Mock implementation - would call platform API
    {
      success: true,
      platform: platform,
      action: 'creative_rotation',
      settings: settings,
      executed_at: Time.current
    }
  end

  def optimize_ad_schedule(platform, adjustment)
    Rails.logger.info "Optimizing #{platform} ad schedule with adjustment: #{adjustment}"
    
    # Mock implementation - would call platform API
    {
      success: true,
      platform: platform,
      action: 'schedule_optimization',
      adjustment: adjustment,
      executed_at: Time.current
    }
  end

  def optimize_platform_settings(platform, optimization)
    Rails.logger.info "Optimizing #{platform} settings: #{optimization}"
    
    # Mock implementation - would call platform API
    {
      success: true,
      platform: platform,
      action: 'platform_optimization',
      optimization: optimization,
      executed_at: Time.current
    }
  end

  def launch_content_variant_test(platform, settings)
    Rails.logger.info "Launching #{platform} content variant test with settings: #{settings}"
    
    # Mock implementation - would call platform API and A/B testing system
    {
      success: true,
      platform: platform,
      action: 'content_variant_testing',
      settings: settings,
      executed_at: Time.current
    }
  end

  # Helper methods for extracting performance metrics

  def extract_metric_from_performance_data(metric)
    campaign_plan.parsed_performance_data.dig(metric) ||
    campaign_plan.parsed_performance_data.dig('metrics', metric) ||
    campaign_plan.parsed_performance_data.dig('platform_metrics', 'aggregate', metric)
  end

  def extract_cost_metrics
    {
      'cpc' => extract_metric_from_performance_data('cpc') || 0,
      'cpm' => extract_metric_from_performance_data('cpm') || 0,
      'total_spend' => extract_metric_from_performance_data('total_spend') || 0
    }
  end

  def extract_budget_metrics
    {
      'daily_budget' => extract_metric_from_performance_data('daily_budget') || 0,
      'total_budget' => extract_metric_from_performance_data('total_budget') || 0,
      'budget_utilization' => extract_metric_from_performance_data('budget_utilization') || 0
    }
  end

  def extract_bid_metrics
    {
      'average_bid' => extract_metric_from_performance_data('average_bid') || 0,
      'max_bid' => extract_metric_from_performance_data('max_bid') || 0,
      'bid_strategy' => extract_metric_from_performance_data('bid_strategy') || 'automatic'
    }
  end

  def extract_platform_breakdown
    campaign_plan.parsed_performance_data.dig('platform_breakdown') || {}
  end
end