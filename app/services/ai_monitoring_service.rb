# AI Operations Monitoring and Metrics Collection Service
# Provides comprehensive monitoring, logging, and metrics for AI service operations
class AiMonitoringService
  include Singleton

  # Metric types for AI operations
  METRIC_TYPES = {
    request_count: :counter,
    request_duration: :histogram,
    request_errors: :counter,
    token_usage: :histogram,
    cost_tracking: :gauge,
    cache_performance: :gauge,
    provider_health: :gauge
  }.freeze

  # Cost per token by provider (in USD per 1000 tokens)
  PROVIDER_COSTS = {
    'anthropic' => {
      'claude-3-5-sonnet-20241022' => { input: 0.003, output: 0.015 },
      'claude-3-5-haiku-20241022' => { input: 0.0008, output: 0.004 },
      'claude-3-opus-20240229' => { input: 0.015, output: 0.075 }
    },
    'openai' => {
      'gpt-4o' => { input: 0.005, output: 0.015 },
      'gpt-4o-mini' => { input: 0.00015, output: 0.0006 },
      'gpt-4-turbo' => { input: 0.01, output: 0.03 },
      'gpt-3.5-turbo' => { input: 0.0005, output: 0.0015 }
    },
    'gemini' => {
      'gemini-2.0-flash-exp' => { input: 0.00001875, output: 0.000075 },
      'gemini-1.5-pro' => { input: 0.00125, output: 0.005 },
      'gemini-1.5-flash' => { input: 0.000075, output: 0.0003 }
    }
  }.freeze

  attr_reader :metrics_store, :structured_logger

  def initialize
    @metrics_store = {}
    @structured_logger = setup_structured_logger
    @request_cache = {}
    
    # Initialize metric collections
    reset_daily_metrics if new_day?
    
    Rails.logger.info "[AI_MONITORING] Service initialized"
  end

  # Main entry point for monitoring AI requests
  def self.track_request(operation_type, provider, model, &block)
    instance.track_request(operation_type, provider, model, &block)
  end

  def track_request(operation_type, provider, model, &block)
    request_id = SecureRandom.uuid
    start_time = Time.current
    
    # Log structured request start
    log_request_start(request_id, operation_type, provider, model)
    
    begin
      result = yield
      
      # Calculate metrics
      duration = Time.current - start_time
      success = true
      
      # Extract token usage and cost information
      token_info = extract_token_info(result)
      cost_info = calculate_cost(provider, model, token_info)
      
      # Record all metrics
      record_success_metrics(request_id, operation_type, provider, model, duration, token_info, cost_info)
      
      # Log structured success
      log_request_success(request_id, operation_type, provider, model, duration, token_info, cost_info)
      
      result
      
    rescue => error
      # Calculate duration even on failure
      duration = Time.current - start_time
      
      # Record failure metrics
      record_failure_metrics(request_id, operation_type, provider, model, duration, error)
      
      # Log structured failure
      log_request_failure(request_id, operation_type, provider, model, duration, error)
      
      raise error
    end
  end

  # Get comprehensive metrics for a time period
  def self.get_metrics(timeframe = 24.hours, provider = nil)
    instance.get_metrics(timeframe, provider)
  end

  def get_metrics(timeframe = 24.hours, provider = nil)
    cutoff_time = Time.current - timeframe
    
    metrics = {
      summary: build_summary_metrics(cutoff_time, provider),
      performance: build_performance_metrics(cutoff_time, provider),
      costs: build_cost_metrics(cutoff_time, provider),
      errors: build_error_metrics(cutoff_time, provider),
      providers: build_provider_metrics(cutoff_time, provider),
      cache_performance: get_cache_metrics(cutoff_time),
      trends: build_trend_metrics(cutoff_time, provider)
    }
    
    metrics
  end

  # Real-time health status
  def self.health_status
    instance.health_status
  end

  def health_status
    recent_metrics = get_metrics(5.minutes)
    
    status = {
      overall: :healthy,
      timestamp: Time.current,
      providers: {},
      alerts: [],
      metrics: {
        requests_per_minute: recent_metrics[:summary][:total_requests] / 5.0,
        average_response_time: recent_metrics[:performance][:average_duration],
        error_rate: recent_metrics[:summary][:error_rate],
        total_cost_last_hour: get_metrics(1.hour)[:costs][:total_cost]
      }
    }

    # Check each provider health
    PROVIDER_COSTS.keys.each do |provider|
      provider_metrics = get_metrics(10.minutes, provider)
      provider_status = assess_provider_health(provider, provider_metrics)
      status[:providers][provider] = provider_status
      
      if provider_status[:status] == :unhealthy
        status[:overall] = :degraded
        status[:alerts] << "Provider #{provider} is unhealthy: #{provider_status[:reason]}"
      end
    end

    # Overall system health assessment
    if recent_metrics[:summary][:error_rate] > 50
      status[:overall] = :critical
      status[:alerts] << "High error rate: #{recent_metrics[:summary][:error_rate]}%"
    elsif recent_metrics[:performance][:average_duration] > 30
      status[:overall] = :degraded
      status[:alerts] << "High response times: #{recent_metrics[:performance][:average_duration]}s avg"
    end

    status
  end

  # Export metrics for external monitoring systems (Prometheus, DataDog, etc.)
  def self.export_metrics(format = :prometheus)
    instance.export_metrics(format)
  end

  def export_metrics(format = :prometheus)
    metrics = get_metrics(24.hours)
    
    case format
    when :prometheus
      format_prometheus_metrics(metrics)
    when :json
      metrics.to_json
    when :csv
      format_csv_metrics(metrics)
    else
      metrics
    end
  end

  # Cost tracking and budgeting
  def self.cost_analysis(timeframe = 24.hours)
    instance.cost_analysis(timeframe)
  end

  def cost_analysis(timeframe = 24.hours)
    metrics = get_metrics(timeframe)
    costs = metrics[:costs]
    
    {
      total_cost: costs[:total_cost],
      cost_by_provider: costs[:by_provider],
      cost_by_operation: costs[:by_operation_type],
      cost_trends: costs[:hourly_breakdown],
      budget_status: calculate_budget_status(costs[:total_cost], timeframe),
      cost_efficiency: calculate_cost_efficiency(metrics),
      recommendations: generate_cost_recommendations(costs)
    }
  end

  # Performance analysis and recommendations
  def self.performance_analysis(timeframe = 24.hours)
    instance.performance_analysis(timeframe)
  end

  def performance_analysis(timeframe = 24.hours)
    metrics = get_metrics(timeframe)
    
    {
      response_time_analysis: analyze_response_times(metrics[:performance]),
      throughput_analysis: analyze_throughput(metrics[:summary]),
      error_analysis: analyze_errors(metrics[:errors]),
      cache_efficiency: analyze_cache_performance(metrics[:cache_performance]),
      bottlenecks: identify_bottlenecks(metrics),
      recommendations: generate_performance_recommendations(metrics)
    }
  end

  # Cleanup old metrics data
  def self.cleanup_metrics(older_than = 7.days)
    instance.cleanup_metrics(older_than)
  end

  def cleanup_metrics(older_than = 7.days)
    cutoff_time = Time.current - older_than
    initial_count = @metrics_store.size
    
    @metrics_store.reject! { |key, data| data[:timestamp] < cutoff_time }
    
    cleaned_count = initial_count - @metrics_store.size
    Rails.logger.info "[AI_MONITORING] Cleaned up #{cleaned_count} old metric entries"
    
    cleaned_count
  end

  private

  # Structured logging setup
  def setup_structured_logger
    if Rails.env.production?
      # In production, use JSON structured logging
      logger = ActiveSupport::Logger.new(STDOUT)
      logger.formatter = proc do |severity, datetime, progname, msg|
        {
          timestamp: datetime.iso8601,
          level: severity,
          component: 'ai_monitoring',
          message: msg.is_a?(Hash) ? msg : { text: msg }
        }.to_json + "\n"
      end
      logger
    else
      # In development, use readable formatting
      Rails.logger
    end
  end

  # Request lifecycle logging
  def log_request_start(request_id, operation_type, provider, model)
    log_data = {
      event: 'ai_request_start',
      request_id: request_id,
      operation_type: operation_type,
      provider: provider,
      model: model,
      timestamp: Time.current.iso8601
    }
    
    @structured_logger.info(log_data)
  end

  def log_request_success(request_id, operation_type, provider, model, duration, token_info, cost_info)
    log_data = {
      event: 'ai_request_success',
      request_id: request_id,
      operation_type: operation_type,
      provider: provider,
      model: model,
      duration_seconds: duration.round(3),
      tokens_used: token_info[:total],
      input_tokens: token_info[:input],
      output_tokens: token_info[:output],
      estimated_cost: cost_info[:total],
      timestamp: Time.current.iso8601
    }
    
    @structured_logger.info(log_data)
  end

  def log_request_failure(request_id, operation_type, provider, model, duration, error)
    log_data = {
      event: 'ai_request_failure',
      request_id: request_id,
      operation_type: operation_type,
      provider: provider,
      model: model,
      duration_seconds: duration.round(3),
      error_class: error.class.name,
      error_message: error.message,
      timestamp: Time.current.iso8601
    }
    
    @structured_logger.error(log_data)
  end

  # Metrics recording
  def record_success_metrics(request_id, operation_type, provider, model, duration, token_info, cost_info)
    metric_key = generate_metric_key(Time.current)
    
    @metrics_store[metric_key] ||= initialize_metric_entry
    metric_entry = @metrics_store[metric_key]
    
    # Update counters
    metric_entry[:requests][:total] += 1
    metric_entry[:requests][:successful] += 1
    metric_entry[:requests][operation_type.to_sym] += 1
    metric_entry[:providers][provider.to_sym][:requests] += 1
    metric_entry[:providers][provider.to_sym][:successful] += 1
    
    # Update performance metrics
    metric_entry[:performance][:total_duration] += duration
    metric_entry[:performance][:durations] << duration
    
    # Update token metrics
    metric_entry[:tokens][:total] += token_info[:total]
    metric_entry[:tokens][:input] += token_info[:input]
    metric_entry[:tokens][:output] += token_info[:output]
    
    # Update cost metrics
    metric_entry[:costs][:total] += cost_info[:total]
    metric_entry[:costs][:by_provider][provider.to_sym] += cost_info[:total]
    metric_entry[:costs][:by_operation][operation_type.to_sym] += cost_info[:total]
    
    # Store individual request for detailed analysis
    store_individual_request(request_id, {
      timestamp: Time.current,
      operation_type: operation_type,
      provider: provider,
      model: model,
      duration: duration,
      tokens: token_info,
      cost: cost_info,
      success: true
    })
  end

  def record_failure_metrics(request_id, operation_type, provider, model, duration, error)
    metric_key = generate_metric_key(Time.current)
    
    @metrics_store[metric_key] ||= initialize_metric_entry
    metric_entry = @metrics_store[metric_key]
    
    # Update counters
    metric_entry[:requests][:total] += 1
    metric_entry[:requests][:failed] += 1
    metric_entry[:requests][operation_type.to_sym] += 1
    metric_entry[:providers][provider.to_sym][:requests] += 1
    metric_entry[:providers][provider.to_sym][:failed] += 1
    
    # Update error metrics
    error_type = error.class.name
    metric_entry[:errors][error_type.to_sym] += 1
    
    # Still record performance for failed requests
    metric_entry[:performance][:total_duration] += duration
    metric_entry[:performance][:durations] << duration
    
    # Store individual request
    store_individual_request(request_id, {
      timestamp: Time.current,
      operation_type: operation_type,
      provider: provider,
      model: model,
      duration: duration,
      error: {
        type: error_type,
        message: error.message
      },
      success: false
    })
  end

  # Utility methods
  def extract_token_info(result)
    # Try to extract token information from different response formats
    if result.is_a?(Hash)
      if result.key?('usage')
        # Anthropic/OpenAI format
        usage = result['usage']
        {
          input: usage['input_tokens'] || usage['prompt_tokens'] || 0,
          output: usage['output_tokens'] || usage['completion_tokens'] || 0,
          total: usage['total_tokens'] || (usage['input_tokens'] || 0) + (usage['output_tokens'] || 0)
        }
      else
        # Estimate based on content length
        content_length = result.to_s.length
        estimated_tokens = (content_length / 4.0).ceil
        {
          input: estimated_tokens / 2,
          output: estimated_tokens / 2,
          total: estimated_tokens
        }
      end
    else
      # Fallback estimation
      content_length = result.to_s.length
      estimated_tokens = (content_length / 4.0).ceil
      {
        input: estimated_tokens / 2,
        output: estimated_tokens / 2,
        total: estimated_tokens
      }
    end
  end

  def calculate_cost(provider, model, token_info)
    provider_costs = PROVIDER_COSTS[provider.to_s]
    return { total: 0.0, input: 0.0, output: 0.0 } unless provider_costs
    
    model_costs = provider_costs[model.to_s]
    return { total: 0.0, input: 0.0, output: 0.0 } unless model_costs
    
    # Calculate costs (rates are per 1000 tokens)
    input_cost = (token_info[:input] / 1000.0) * model_costs[:input]
    output_cost = (token_info[:output] / 1000.0) * model_costs[:output]
    
    {
      input: input_cost,
      output: output_cost,
      total: input_cost + output_cost
    }
  end

  def generate_metric_key(timestamp)
    # Group metrics by 5-minute intervals
    interval = 5.minutes
    interval_start = timestamp.beginning_of_hour + (timestamp.min / 5) * interval
    "metrics_#{interval_start.to_i}"
  end

  def initialize_metric_entry
    {
      timestamp: Time.current,
      requests: Hash.new(0),
      providers: Hash.new { |h, k| h[k] = Hash.new(0) },
      performance: { total_duration: 0.0, durations: [] },
      tokens: Hash.new(0),
      costs: { total: 0.0, by_provider: Hash.new(0.0), by_operation: Hash.new(0.0) },
      errors: Hash.new(0)
    }
  end

  def store_individual_request(request_id, request_data)
    # Store individual requests for detailed analysis (keep last 1000)
    @request_cache[request_id] = request_data
    
    if @request_cache.size > 1000
      # Remove oldest entries
      oldest_keys = @request_cache.keys.first(100)
      oldest_keys.each { |key| @request_cache.delete(key) }
    end
  end

  def build_summary_metrics(cutoff_time, provider_filter)
    filtered_metrics = filter_metrics_by_time_and_provider(cutoff_time, provider_filter)
    
    total_requests = filtered_metrics.sum { |_, data| data[:requests][:total] }
    successful_requests = filtered_metrics.sum { |_, data| data[:requests][:successful] }
    failed_requests = filtered_metrics.sum { |_, data| data[:requests][:failed] }
    
    {
      total_requests: total_requests,
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      success_rate: total_requests > 0 ? (successful_requests.to_f / total_requests * 100).round(2) : 0,
      error_rate: total_requests > 0 ? (failed_requests.to_f / total_requests * 100).round(2) : 0
    }
  end

  def build_performance_metrics(cutoff_time, provider_filter)
    filtered_metrics = filter_metrics_by_time_and_provider(cutoff_time, provider_filter)
    
    all_durations = filtered_metrics.flat_map { |_, data| data[:performance][:durations] }
    
    return { average_duration: 0, median_duration: 0, p95_duration: 0, p99_duration: 0 } if all_durations.empty?
    
    sorted_durations = all_durations.sort
    
    {
      average_duration: (all_durations.sum / all_durations.size).round(3),
      median_duration: sorted_durations[sorted_durations.size / 2].round(3),
      p95_duration: sorted_durations[(sorted_durations.size * 0.95).to_i].round(3),
      p99_duration: sorted_durations[(sorted_durations.size * 0.99).to_i].round(3),
      min_duration: sorted_durations.first.round(3),
      max_duration: sorted_durations.last.round(3)
    }
  end

  def build_cost_metrics(cutoff_time, provider_filter)
    filtered_metrics = filter_metrics_by_time_and_provider(cutoff_time, provider_filter)
    
    total_cost = filtered_metrics.sum { |_, data| data[:costs][:total] }
    by_provider = Hash.new(0.0)
    by_operation = Hash.new(0.0)
    
    filtered_metrics.each do |_, data|
      data[:costs][:by_provider].each { |provider, cost| by_provider[provider] += cost }
      data[:costs][:by_operation].each { |operation, cost| by_operation[operation] += cost }
    end
    
    {
      total_cost: total_cost.round(4),
      by_provider: by_provider.transform_values { |v| v.round(4) },
      by_operation_type: by_operation.transform_values { |v| v.round(4) },
      hourly_breakdown: build_hourly_cost_breakdown(filtered_metrics)
    }
  end

  def build_error_metrics(cutoff_time, provider_filter)
    filtered_metrics = filter_metrics_by_time_and_provider(cutoff_time, provider_filter)
    
    error_counts = Hash.new(0)
    filtered_metrics.each do |_, data|
      data[:errors].each { |error_type, count| error_counts[error_type] += count }
    end
    
    {
      by_type: error_counts,
      most_common: error_counts.max_by { |_, count| count }&.first,
      total_errors: error_counts.values.sum
    }
  end

  def build_provider_metrics(cutoff_time, provider_filter)
    filtered_metrics = filter_metrics_by_time_and_provider(cutoff_time, provider_filter)
    
    provider_stats = Hash.new { |h, k| h[k] = { requests: 0, successful: 0, failed: 0 } }
    
    filtered_metrics.each do |_, data|
      data[:providers].each do |provider, stats|
        provider_stats[provider][:requests] += stats[:requests]
        provider_stats[provider][:successful] += stats[:successful]
        provider_stats[provider][:failed] += stats[:failed]
      end
    end
    
    provider_stats.transform_values do |stats|
      success_rate = stats[:requests] > 0 ? (stats[:successful].to_f / stats[:requests] * 100).round(2) : 0
      stats.merge(success_rate: success_rate)
    end
  end

  def build_trend_metrics(cutoff_time, provider_filter)
    # Build hourly trends for requests, errors, and costs
    filtered_metrics = filter_metrics_by_time_and_provider(cutoff_time, provider_filter)
    
    hourly_data = Hash.new { |h, k| h[k] = { requests: 0, errors: 0, cost: 0.0 } }
    
    filtered_metrics.each do |key, data|
      hour_key = Time.at(data[:timestamp]).beginning_of_hour.to_i
      hourly_data[hour_key][:requests] += data[:requests][:total]
      hourly_data[hour_key][:errors] += data[:requests][:failed]
      hourly_data[hour_key][:cost] += data[:costs][:total]
    end
    
    {
      hourly: hourly_data.sort.to_h,
      request_trend: calculate_trend(hourly_data.values.map { |d| d[:requests] }),
      error_trend: calculate_trend(hourly_data.values.map { |d| d[:errors] }),
      cost_trend: calculate_trend(hourly_data.values.map { |d| d[:cost] })
    }
  end

  def filter_metrics_by_time_and_provider(cutoff_time, provider_filter)
    filtered = @metrics_store.select { |_, data| data[:timestamp] >= cutoff_time }
    
    if provider_filter
      # Additional provider filtering would be implemented here
      # For now, return all metrics as provider data is embedded within
    end
    
    filtered
  end

  def assess_provider_health(provider, metrics)
    return { status: :unknown, reason: "No data available" } if metrics[:summary][:total_requests] == 0
    
    error_rate = metrics[:summary][:error_rate]
    avg_response_time = metrics[:performance][:average_duration]
    
    if error_rate > 50
      { status: :unhealthy, reason: "High error rate: #{error_rate}%" }
    elsif error_rate > 20
      { status: :degraded, reason: "Elevated error rate: #{error_rate}%" }
    elsif avg_response_time > 30
      { status: :degraded, reason: "Slow response times: #{avg_response_time}s" }
    else
      { status: :healthy, reason: "Operating normally" }
    end
  end

  def new_day?
    @last_day_reset ||= Date.current
    Date.current > @last_day_reset
  end

  def reset_daily_metrics
    @last_day_reset = Date.current
    # Keep metrics but mark the day change for cost tracking
    Rails.logger.info "[AI_MONITORING] Daily metrics reset for #{Date.current}"
  end

  def get_cache_metrics(cutoff_time)
    # This would integrate with the existing AiResponseCache concern
    # For now, return basic cache stats
    {
      hit_rate: 0.0,
      miss_rate: 0.0,
      total_requests: 0,
      cache_size: 0
    }
  end

  def build_hourly_cost_breakdown(filtered_metrics)
    hourly_costs = Hash.new(0.0)
    
    filtered_metrics.each do |_, data|
      hour_key = data[:timestamp].beginning_of_hour.strftime("%Y-%m-%d %H:00")
      hourly_costs[hour_key] += data[:costs][:total]
    end
    
    hourly_costs.transform_values { |cost| cost.round(4) }
  end

  def calculate_budget_status(current_cost, timeframe)
    # This would integrate with budget settings
    daily_budget = ENV.fetch("AI_DAILY_BUDGET", "100.0").to_f
    hourly_budget = daily_budget / 24.0
    
    budget_for_period = case timeframe
                       when 0..1.hour
                         hourly_budget
                       when 1.hour..24.hours
                         daily_budget * (timeframe / 1.day)
                       else
                         daily_budget * (timeframe / 1.day)
                       end
    
    usage_percentage = (current_cost / budget_for_period * 100).round(2)
    
    {
      budget: budget_for_period,
      used: current_cost,
      remaining: budget_for_period - current_cost,
      usage_percentage: usage_percentage,
      status: usage_percentage > 90 ? :critical : (usage_percentage > 75 ? :warning : :healthy)
    }
  end

  def calculate_trend(values)
    return 0.0 if values.size < 2
    
    # Simple linear trend calculation
    n = values.size
    sum_x = (1..n).sum
    sum_y = values.sum
    sum_xy = values.each_with_index.sum { |y, i| y * (i + 1) }
    sum_x2 = (1..n).sum { |x| x * x }
    
    slope = (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x2 - sum_x * sum_x)
    slope.round(4)
  end

  # Format methods for different export formats
  def format_prometheus_metrics(metrics)
    output = []
    
    # Request metrics
    output << "# HELP ai_requests_total Total number of AI requests"
    output << "# TYPE ai_requests_total counter"
    output << "ai_requests_total{status=\"total\"} #{metrics[:summary][:total_requests]}"
    output << "ai_requests_total{status=\"success\"} #{metrics[:summary][:successful_requests]}"
    output << "ai_requests_total{status=\"failed\"} #{metrics[:summary][:failed_requests]}"
    
    # Duration metrics
    output << "# HELP ai_request_duration_seconds AI request duration in seconds"
    output << "# TYPE ai_request_duration_seconds histogram"
    output << "ai_request_duration_seconds_sum #{metrics[:performance][:average_duration] * metrics[:summary][:total_requests]}"
    output << "ai_request_duration_seconds_count #{metrics[:summary][:total_requests]}"
    
    # Cost metrics
    output << "# HELP ai_cost_usd_total Total cost in USD"
    output << "# TYPE ai_cost_usd_total gauge"
    output << "ai_cost_usd_total #{metrics[:costs][:total_cost]}"
    
    output.join("\n")
  end

  def format_csv_metrics(metrics)
    # CSV format for spreadsheet analysis
    require 'csv'
    
    CSV.generate do |csv|
      csv << ["Metric", "Value", "Unit"]
      csv << ["Total Requests", metrics[:summary][:total_requests], "count"]
      csv << ["Success Rate", metrics[:summary][:success_rate], "percentage"]
      csv << ["Average Duration", metrics[:performance][:average_duration], "seconds"]
      csv << ["Total Cost", metrics[:costs][:total_cost], "USD"]
      # Add more metrics as needed
    end
  end
end