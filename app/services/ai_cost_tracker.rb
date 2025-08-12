# AI Cost Tracking and Budget Management Service
# Tracks costs across providers, models, operations, and users
class AiCostTracker
  include Singleton

  # Detailed pricing for all supported providers and models
  PRICING_TIERS = {
    'anthropic' => {
      'claude-3-5-sonnet-20241022' => {
        input: 0.003, output: 0.015, # per 1K tokens
        batch_discount: 0.5, # 50% discount for batch API
        context_caching: { hit: 0.0003, miss: 0.003 }
      },
      'claude-3-5-haiku-20241022' => {
        input: 0.0008, output: 0.004,
        batch_discount: 0.5,
        context_caching: { hit: 0.00008, miss: 0.0008 }
      },
      'claude-3-opus-20240229' => {
        input: 0.015, output: 0.075,
        batch_discount: 0.5,
        context_caching: { hit: 0.0015, miss: 0.015 }
      }
    },
    'openai' => {
      'gpt-4o' => {
        input: 0.005, output: 0.015,
        batch_discount: 0.5,
        cached_prompt: 0.0025 # 50% discount for cached prompts
      },
      'gpt-4o-mini' => {
        input: 0.00015, output: 0.0006,
        batch_discount: 0.5,
        cached_prompt: 0.000075
      },
      'gpt-4-turbo' => {
        input: 0.01, output: 0.03,
        batch_discount: 0.5
      },
      'gpt-3.5-turbo' => {
        input: 0.0005, output: 0.0015,
        batch_discount: 0.5
      }
    },
    'gemini' => {
      'gemini-2.0-flash-exp' => {
        input: 0.00001875, output: 0.000075, # Free tier: 2M tokens/min
        free_tier_limit: 2_000_000 # tokens per minute
      },
      'gemini-1.5-pro' => {
        input: 0.00125, output: 0.005,
        free_tier_limit: 32_000 # tokens per minute
      },
      'gemini-1.5-flash' => {
        input: 0.000075, output: 0.0003,
        free_tier_limit: 1_000_000 # tokens per minute
      }
    }
  }.freeze

  # Budget configuration
  DEFAULT_BUDGETS = {
    daily: 100.0,    # $100/day
    monthly: 2000.0, # $2000/month
    per_user: 50.0,  # $50/user/month
    per_operation: {
      'content_generation' => 5.0,
      'campaign_planning' => 10.0,
      'brand_analysis' => 3.0
    }
  }.freeze

  attr_reader :cost_store, :budget_alerts_sent

  def initialize
    @cost_store = {}
    @budget_alerts_sent = Set.new
    load_budget_configuration
  end

  # Main cost tracking entry point
  def self.track_cost(provider, model, usage_data, context = {})
    instance.track_cost(provider, model, usage_data, context)
  end

  def track_cost(provider, model, usage_data, context = {})
    cost_calculation = calculate_detailed_cost(provider, model, usage_data)
    
    # Create cost record
    cost_record = {
      id: SecureRandom.uuid,
      timestamp: Time.current,
      provider: provider.to_s,
      model: model.to_s,
      operation_type: context[:operation_type],
      operation_id: context[:operation_id],
      user_id: context[:user_id],
      session_id: context[:session_id],
      usage: usage_data,
      costs: cost_calculation,
      context: context.except(:usage_data)
    }
    
    # Store the record
    store_cost_record(cost_record)
    
    # Check budget thresholds
    check_budget_alerts(cost_record)
    
    # Log cost information
    log_cost_tracking(cost_record)
    
    cost_calculation
  end

  # Get comprehensive cost analysis
  def self.cost_analysis(timeframe = 24.hours, filters = {})
    instance.cost_analysis(timeframe, filters)
  end

  def cost_analysis(timeframe = 24.hours, filters = {})
    cutoff_time = Time.current - timeframe
    records = filter_cost_records(cutoff_time, filters)
    
    {
      summary: build_cost_summary(records),
      by_provider: build_provider_breakdown(records),
      by_operation: build_operation_breakdown(records),
      by_user: build_user_breakdown(records),
      by_time: build_temporal_breakdown(records, timeframe),
      efficiency_metrics: calculate_efficiency_metrics(records),
      budget_status: check_budget_status(records, timeframe),
      cost_optimization: generate_optimization_recommendations(records),
      projections: calculate_cost_projections(records, timeframe)
    }
  end

  # Budget management
  def self.set_budget(budget_type, amount, scope = :global)
    instance.set_budget(budget_type, amount, scope)
  end

  def set_budget(budget_type, amount, scope = :global)
    @budgets ||= {}
    @budgets[scope] ||= {}
    @budgets[scope][budget_type] = amount.to_f
    
    Rails.logger.info "[AI_COST] Budget set: #{budget_type} = $#{amount} (scope: #{scope})"
  end

  def self.check_budget_status(timeframe = 24.hours, scope = :global)
    instance.check_budget_status_for_scope(timeframe, scope)
  end

  def check_budget_status_for_scope(timeframe = 24.hours, scope = :global)
    records = filter_cost_records(Time.current - timeframe, { scope: scope })
    total_cost = records.sum { |r| r[:costs][:total] }
    
    budget = get_budget_for_timeframe(timeframe, scope)
    usage_percentage = budget > 0 ? (total_cost / budget * 100).round(2) : 0
    
    {
      period: timeframe_to_string(timeframe),
      budget: budget,
      spent: total_cost.round(4),
      remaining: (budget - total_cost).round(4),
      usage_percentage: usage_percentage,
      status: determine_budget_status(usage_percentage),
      daily_burn_rate: calculate_daily_burn_rate(records),
      projected_monthly: project_monthly_cost(records)
    }
  end

  # Cost optimization recommendations
  def self.optimization_recommendations(timeframe = 7.days)
    instance.optimization_recommendations(timeframe)
  end

  def optimization_recommendations(timeframe = 7.days)
    records = filter_cost_records(Time.current - timeframe, {})
    
    recommendations = []
    
    # Model efficiency analysis
    model_efficiency = analyze_model_efficiency(records)
    if model_efficiency[:recommendations].any?
      recommendations.concat(model_efficiency[:recommendations])
    end
    
    # Cache optimization
    cache_analysis = analyze_cache_efficiency(records)
    if cache_analysis[:recommendations].any?
      recommendations.concat(cache_analysis[:recommendations])
    end
    
    # Usage pattern analysis
    usage_patterns = analyze_usage_patterns(records)
    if usage_patterns[:recommendations].any?
      recommendations.concat(usage_patterns[:recommendations])
    end
    
    # Provider cost comparison
    provider_comparison = compare_provider_costs(records)
    if provider_comparison[:recommendations].any?
      recommendations.concat(provider_comparison[:recommendations])
    end
    
    {
      total_recommendations: recommendations.size,
      potential_savings: calculate_potential_savings(recommendations),
      recommendations: recommendations.sort_by { |r| -r[:potential_savings] }
    }
  end

  # Real-time cost monitoring
  def self.real_time_costs
    instance.real_time_costs
  end

  def real_time_costs
    current_hour = Time.current.beginning_of_hour
    recent_records = filter_cost_records(current_hour, {})
    
    {
      current_hour_cost: recent_records.sum { |r| r[:costs][:total] }.round(4),
      requests_this_hour: recent_records.size,
      average_cost_per_request: calculate_average_cost_per_request(recent_records),
      cost_rate_per_minute: calculate_cost_rate_per_minute(recent_records),
      top_cost_operations: get_top_cost_operations(recent_records, 5),
      cost_by_provider: build_provider_breakdown(recent_records)[:costs],
      burn_rate_trend: calculate_burn_rate_trend
    }
  end

  # Export functionality
  def self.export_cost_data(timeframe = 30.days, format = :csv)
    instance.export_cost_data(timeframe, format)
  end

  def export_cost_data(timeframe = 30.days, format = :csv)
    records = filter_cost_records(Time.current - timeframe, {})
    
    case format
    when :csv
      generate_csv_export(records)
    when :json
      records.to_json
    when :xlsx
      generate_excel_export(records)
    else
      records
    end
  end

  private

  def calculate_detailed_cost(provider, model, usage_data)
    pricing = PRICING_TIERS.dig(provider.to_s, model.to_s)
    return { total: 0.0, breakdown: {} } unless pricing
    
    input_tokens = usage_data[:input_tokens] || 0
    output_tokens = usage_data[:output_tokens] || 0
    cached_tokens = usage_data[:cached_tokens] || 0
    
    costs = {}
    
    # Base input cost
    if cached_tokens > 0 && pricing[:cached_prompt]
      # Some tokens were cached
      regular_input = input_tokens - cached_tokens
      costs[:input_regular] = (regular_input / 1000.0) * pricing[:input]
      costs[:input_cached] = (cached_tokens / 1000.0) * pricing[:cached_prompt]
      costs[:input_total] = costs[:input_regular] + costs[:input_cached]
    elsif cached_tokens > 0 && pricing[:context_caching]
      # Context caching (Anthropic style)
      cache_hits = usage_data[:cache_hits] || 0
      cache_misses = input_tokens - cache_hits
      costs[:input_cache_hits] = (cache_hits / 1000.0) * pricing[:context_caching][:hit]
      costs[:input_cache_misses] = (cache_misses / 1000.0) * pricing[:context_caching][:miss]
      costs[:input_total] = costs[:input_cache_hits] + costs[:input_cache_misses]
    else
      # Standard input cost
      costs[:input_total] = (input_tokens / 1000.0) * pricing[:input]
    end
    
    # Output cost
    costs[:output_total] = (output_tokens / 1000.0) * pricing[:output]
    
    # Apply batch discount if applicable
    if usage_data[:batch_mode] && pricing[:batch_discount]
      discount_factor = pricing[:batch_discount]
      costs[:batch_discount] = -(costs[:input_total] + costs[:output_total]) * (1 - discount_factor)
    end
    
    # Calculate total
    total_cost = costs.values.select { |v| v.is_a?(Numeric) }.sum
    
    # Apply free tier limits
    if pricing[:free_tier_limit] && !exceeded_free_tier?(provider, model, usage_data)
      total_cost = 0.0
      costs[:free_tier_applied] = true
    end
    
    {
      total: total_cost.round(6),
      currency: 'USD',
      breakdown: costs.transform_values { |v| v.is_a?(Numeric) ? v.round(6) : v },
      pricing_model: pricing,
      tokens_used: {
        input: input_tokens,
        output: output_tokens,
        cached: cached_tokens,
        total: input_tokens + output_tokens
      }
    }
  end

  def store_cost_record(record)
    # Store in memory with time-based partitioning
    date_key = record[:timestamp].to_date.to_s
    @cost_store[date_key] ||= []
    @cost_store[date_key] << record
    
    # Keep only last 30 days in memory
    cleanup_old_records
    
    # In production, this would also persist to database
    persist_to_database(record) if Rails.env.production?
  end

  def filter_cost_records(cutoff_time, filters = {})
    records = []
    
    @cost_store.each do |date, date_records|
      date_records.each do |record|
        next if record[:timestamp] < cutoff_time
        
        # Apply filters
        next if filters[:provider] && record[:provider] != filters[:provider].to_s
        next if filters[:operation_type] && record[:operation_type] != filters[:operation_type].to_s
        next if filters[:user_id] && record[:user_id] != filters[:user_id]
        
        records << record
      end
    end
    
    records.sort_by { |r| r[:timestamp] }
  end

  def build_cost_summary(records)
    total_cost = records.sum { |r| r[:costs][:total] }
    total_requests = records.size
    total_tokens = records.sum { |r| r[:costs][:tokens_used][:total] }
    
    {
      total_cost: total_cost.round(4),
      total_requests: total_requests,
      total_tokens: total_tokens,
      average_cost_per_request: total_requests > 0 ? (total_cost / total_requests).round(4) : 0,
      average_cost_per_token: total_tokens > 0 ? (total_cost / total_tokens * 1000).round(6) : 0,
      date_range: {
        start: records.first&.dig(:timestamp),
        end: records.last&.dig(:timestamp)
      }
    }
  end

  def build_provider_breakdown(records)
    breakdown = Hash.new { |h, k| h[k] = { cost: 0.0, requests: 0, tokens: 0 } }
    
    records.each do |record|
      provider = record[:provider]
      breakdown[provider][:cost] += record[:costs][:total]
      breakdown[provider][:requests] += 1
      breakdown[provider][:tokens] += record[:costs][:tokens_used][:total]
    end
    
    {
      costs: breakdown.transform_values { |v| v[:cost].round(4) },
      requests: breakdown.transform_values { |v| v[:requests] },
      tokens: breakdown.transform_values { |v| v[:tokens] },
      efficiency: breakdown.transform_values do |v|
        {
          cost_per_request: v[:requests] > 0 ? (v[:cost] / v[:requests]).round(4) : 0,
          cost_per_token: v[:tokens] > 0 ? (v[:cost] / v[:tokens] * 1000).round(6) : 0
        }
      end
    }
  end

  def build_operation_breakdown(records)
    breakdown = Hash.new { |h, k| h[k] = { cost: 0.0, requests: 0 } }
    
    records.each do |record|
      operation = record[:operation_type] || 'unknown'
      breakdown[operation][:cost] += record[:costs][:total]
      breakdown[operation][:requests] += 1
    end
    
    breakdown.transform_values do |v|
      {
        total_cost: v[:cost].round(4),
        requests: v[:requests],
        average_cost: v[:requests] > 0 ? (v[:cost] / v[:requests]).round(4) : 0
      }
    end
  end

  def build_user_breakdown(records)
    user_records = records.reject { |r| r[:user_id].nil? }
    breakdown = Hash.new { |h, k| h[k] = { cost: 0.0, requests: 0 } }
    
    user_records.each do |record|
      user_id = record[:user_id]
      breakdown[user_id][:cost] += record[:costs][:total]
      breakdown[user_id][:requests] += 1
    end
    
    breakdown.transform_values do |v|
      {
        total_cost: v[:cost].round(4),
        requests: v[:requests],
        average_cost: v[:requests] > 0 ? (v[:cost] / v[:requests]).round(4) : 0
      }
    end
  end

  def build_temporal_breakdown(records, timeframe)
    # Group by appropriate time intervals based on timeframe
    interval = case timeframe
               when 0..6.hours then :hour
               when 6.hours..7.days then :day
               when 7.days..90.days then :week
               else :month
               end
    
    breakdown = Hash.new(0.0)
    
    records.each do |record|
      time_key = case interval
                 when :hour then record[:timestamp].beginning_of_hour
                 when :day then record[:timestamp].beginning_of_day
                 when :week then record[:timestamp].beginning_of_week
                 when :month then record[:timestamp].beginning_of_month
                 end
      
      breakdown[time_key.to_s] += record[:costs][:total]
    end
    
    {
      interval: interval,
      data: breakdown.transform_values { |v| v.round(4) }
    }
  end

  def calculate_efficiency_metrics(records)
    return {} if records.empty?
    
    # Token efficiency
    total_tokens = records.sum { |r| r[:costs][:tokens_used][:total] }
    total_cost = records.sum { |r| r[:costs][:total] }
    
    # Response time efficiency (if available)
    records_with_duration = records.select { |r| r[:context][:duration] }
    avg_duration = if records_with_duration.any?
                    records_with_duration.sum { |r| r[:context][:duration] } / records_with_duration.size
                   else
                    nil
                   end
    
    {
      tokens_per_dollar: total_cost > 0 ? (total_tokens / total_cost).round(2) : 0,
      cost_per_1k_tokens: total_tokens > 0 ? (total_cost / total_tokens * 1000).round(4) : 0,
      average_response_time: avg_duration&.round(3),
      cost_per_second: avg_duration && total_cost > 0 ? (total_cost / (avg_duration * records.size)).round(4) : nil
    }
  end

  def check_budget_alerts(cost_record)
    # Check various budget thresholds
    check_daily_budget(cost_record)
    check_monthly_budget(cost_record)
    check_user_budget(cost_record) if cost_record[:user_id]
    check_operation_budget(cost_record) if cost_record[:operation_type]
  end

  def check_daily_budget(cost_record)
    today = Date.current
    daily_cost = get_daily_cost(today)
    daily_budget = get_budget(:daily)
    
    usage_percentage = (daily_cost / daily_budget * 100).round(2)
    
    send_budget_alert(:daily, usage_percentage, daily_cost, daily_budget) if should_send_alert?(:daily, usage_percentage)
  end

  def check_monthly_budget(cost_record)
    current_month = Date.current.beginning_of_month
    monthly_cost = get_monthly_cost(current_month)
    monthly_budget = get_budget(:monthly)
    
    usage_percentage = (monthly_cost / monthly_budget * 100).round(2)
    
    send_budget_alert(:monthly, usage_percentage, monthly_cost, monthly_budget) if should_send_alert?(:monthly, usage_percentage)
  end

  def should_send_alert?(budget_type, usage_percentage)
    alert_key = "#{budget_type}_#{Date.current}_#{(usage_percentage / 10).to_i * 10}"
    
    return false if @budget_alerts_sent.include?(alert_key)
    
    # Send alerts at 75%, 90%, 100%, 110% thresholds
    threshold_hit = [75, 90, 100, 110].any? { |t| usage_percentage >= t && usage_percentage < t + 10 }
    
    if threshold_hit
      @budget_alerts_sent << alert_key
      true
    else
      false
    end
  end

  def send_budget_alert(budget_type, usage_percentage, current_cost, budget)
    severity = case usage_percentage
               when 0..75 then :info
               when 75..90 then :warn
               when 90..100 then :error
               else :critical
               end

    AiAlertingService.send_alert(:budget_threshold, {
      budget_type: budget_type,
      usage_percentage: usage_percentage,
      current_cost: current_cost,
      budget: budget,
      severity: severity,
      remaining: budget - current_cost
    })
  end

  def load_budget_configuration
    @budgets = DEFAULT_BUDGETS.dup
    
    # Load from environment variables
    @budgets[:daily] = ENV.fetch('AI_DAILY_BUDGET', @budgets[:daily]).to_f
    @budgets[:monthly] = ENV.fetch('AI_MONTHLY_BUDGET', @budgets[:monthly]).to_f
    @budgets[:per_user] = ENV.fetch('AI_PER_USER_BUDGET', @budgets[:per_user]).to_f
  end

  def get_budget(budget_type, scope = :global)
    @budgets.dig(scope, budget_type) || @budgets[budget_type] || 0.0
  end

  def get_budget_for_timeframe(timeframe, scope = :global)
    case timeframe
    when 0..24.hours
      get_budget(:daily, scope)
    when 24.hours..30.days
      daily_budget = get_budget(:daily, scope)
      days = (timeframe / 1.day).ceil
      daily_budget * days
    else
      get_budget(:monthly, scope)
    end
  end

  def get_daily_cost(date)
    date_key = date.to_s
    return 0.0 unless @cost_store[date_key]
    
    @cost_store[date_key].sum { |r| r[:costs][:total] }
  end

  def get_monthly_cost(month_start)
    month_end = month_start.end_of_month
    records = filter_cost_records(month_start.beginning_of_day, {})
    records.select { |r| r[:timestamp] <= month_end.end_of_day }.sum { |r| r[:costs][:total] }
  end

  def cleanup_old_records
    cutoff_date = 30.days.ago.to_date
    @cost_store.reject! { |date_key, _| Date.parse(date_key) < cutoff_date }
  end

  def persist_to_database(record)
    # In production, persist to database for long-term storage
    # This would integrate with a proper database table
    Rails.logger.debug "[AI_COST] Would persist to database: #{record[:id]}"
  end

  def log_cost_tracking(record)
    Rails.logger.info "[AI_COST] #{record[:provider]}/#{record[:model]}: $#{record[:costs][:total]} (#{record[:costs][:tokens_used][:total]} tokens)"
  end

  def exceeded_free_tier?(provider, model, usage_data)
    # Implement free tier tracking logic
    # This would track usage per minute/hour for providers with free tiers
    false # Simplified for now
  end

  def determine_budget_status(usage_percentage)
    case usage_percentage
    when 0..75 then :healthy
    when 75..90 then :warning
    when 90..100 then :critical
    else :exceeded
    end
  end

  def calculate_daily_burn_rate(records)
    return 0.0 if records.empty?
    
    # Calculate cost per day based on recent records
    timespan_days = (records.last[:timestamp] - records.first[:timestamp]) / 1.day
    return 0.0 if timespan_days <= 0
    
    total_cost = records.sum { |r| r[:costs][:total] }
    (total_cost / timespan_days).round(4)
  end

  def project_monthly_cost(records)
    daily_burn_rate = calculate_daily_burn_rate(records)
    (daily_burn_rate * 30).round(2)
  end

  def timeframe_to_string(timeframe)
    case timeframe
    when 0..1.hour then "#{(timeframe / 1.minute).to_i} minutes"
    when 1.hour..24.hours then "#{(timeframe / 1.hour).to_i} hours"
    when 1.day..7.days then "#{(timeframe / 1.day).to_i} days"
    else "#{(timeframe / 1.week).to_i} weeks"
    end
  end

  # Additional helper methods for optimization and analysis would go here
  def analyze_model_efficiency(records)
    # Analyze which models provide best value for money
    { recommendations: [] }
  end

  def analyze_cache_efficiency(records)
    # Analyze cache hit rates and potential savings
    { recommendations: [] }
  end

  def analyze_usage_patterns(records)
    # Analyze usage patterns for optimization opportunities
    { recommendations: [] }
  end

  def compare_provider_costs(records)
    # Compare costs across providers for similar operations
    { recommendations: [] }
  end

  def calculate_potential_savings(recommendations)
    recommendations.sum { |r| r[:potential_savings] || 0.0 }
  end

  def calculate_average_cost_per_request(records)
    return 0.0 if records.empty?
    total_cost = records.sum { |r| r[:costs][:total] }
    (total_cost / records.size).round(4)
  end

  def calculate_cost_rate_per_minute(records)
    return 0.0 if records.empty?
    
    timespan = records.last[:timestamp] - records.first[:timestamp]
    return 0.0 if timespan <= 0
    
    total_cost = records.sum { |r| r[:costs][:total] }
    minutes = timespan / 1.minute
    (total_cost / minutes).round(4)
  end

  def get_top_cost_operations(records, limit)
    operation_costs = Hash.new(0.0)
    
    records.each do |record|
      operation = record[:operation_type] || 'unknown'
      operation_costs[operation] += record[:costs][:total]
    end
    
    operation_costs.sort_by { |_, cost| -cost }.first(limit).to_h
  end

  def calculate_burn_rate_trend
    # Calculate cost trends over recent periods
    # This would analyze spending velocity changes
    { trend: 'stable', change_percentage: 0.0 }
  end

  def generate_csv_export(records)
    require 'csv'
    
    CSV.generate do |csv|
      csv << ['Timestamp', 'Provider', 'Model', 'Operation', 'User ID', 'Cost', 'Input Tokens', 'Output Tokens', 'Total Tokens']
      
      records.each do |record|
        csv << [
          record[:timestamp].iso8601,
          record[:provider],
          record[:model],
          record[:operation_type],
          record[:user_id],
          record[:costs][:total],
          record[:costs][:tokens_used][:input],
          record[:costs][:tokens_used][:output],
          record[:costs][:tokens_used][:total]
        ]
      end
    end
  end

  def generate_excel_export(records)
    # Would generate Excel file with multiple sheets for different analyses
    "Excel export functionality would be implemented here"
  end
end