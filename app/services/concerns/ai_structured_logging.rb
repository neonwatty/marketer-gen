# Structured logging concern for AI services
# Provides consistent, structured logging across all AI operations
module AiStructuredLogging
  extend ActiveSupport::Concern

  # Log levels specifically for AI operations
  LOG_LEVELS = {
    trace: 0,
    debug: 1,
    info: 2,
    warn: 3,
    error: 4,
    fatal: 5
  }.freeze

  included do
    attr_reader :operation_id, :request_context
  end

  def initialize(*args)
    super(*args)
    @operation_id = SecureRandom.uuid
    @request_context = build_base_context
  end

  private

  # Enhanced logging methods with structured data
  def log_ai_operation(level, event_type, data = {})
    timestamp = Time.current
    
    log_entry = {
      timestamp: timestamp.iso8601,
      operation_id: @operation_id,
      event_type: event_type.to_s,
      component: 'ai_service',
      provider: respond_to?(:provider_name) ? provider_name : 'unknown',
      model: respond_to?(:model_name) ? attributes['model_name'] : 'unknown',
      level: level.to_s.upcase,
      **@request_context,
      **data
    }

    # Add performance context if available
    if @performance_context
      log_entry[:performance] = @performance_context
    end

    # Add error context if this is an error log
    if level == :error && data[:error]
      log_entry[:error] = format_error_context(data[:error])
    end

    # Route to appropriate logger based on environment and level
    case level
    when :trace, :debug
      Rails.logger.debug(format_log_entry(log_entry)) if Rails.env.development?
    when :info
      Rails.logger.info(format_log_entry(log_entry))
    when :warn
      Rails.logger.warn(format_log_entry(log_entry))
    when :error, :fatal
      Rails.logger.error(format_log_entry(log_entry))
      
      # Also send to monitoring service for error tracking
      if defined?(AiMonitoringService)
        AiMonitoringService.instance.record_error_event(log_entry)
      end
    end

    # Send to external logging services if configured
    send_to_external_loggers(level, log_entry) if should_send_external?(level)

    log_entry
  end

  def log_request_start(operation_type, prompt_info = {})
    @performance_context = {
      start_time: Time.current,
      operation_type: operation_type.to_s
    }

    log_ai_operation(:info, :request_start, {
      operation_type: operation_type,
      prompt_length: prompt_info[:length] || 0,
      estimated_tokens: prompt_info[:estimated_tokens] || 0,
      cache_enabled: respond_to?(:cache_enabled) ? cache_enabled : false,
      rate_limit_enabled: respond_to?(:rate_limit_enabled) ? rate_limit_enabled : false
    })
  end

  def log_request_success(operation_type, response_info = {})
    duration = Time.current - @performance_context[:start_time] if @performance_context
    
    @performance_context&.merge!({
      end_time: Time.current,
      duration: duration,
      success: true
    })

    log_ai_operation(:info, :request_success, {
      operation_type: operation_type,
      duration: duration&.round(3),
      response_length: response_info[:length] || 0,
      tokens_used: response_info[:tokens] || 0,
      cached: response_info[:cached] || false,
      **extract_response_metadata(response_info)
    })
  end

  def log_request_failure(operation_type, error, duration = nil)
    duration ||= Time.current - @performance_context[:start_time] if @performance_context
    
    @performance_context&.merge!({
      end_time: Time.current,
      duration: duration,
      success: false,
      error_type: error.class.name
    })

    log_ai_operation(:error, :request_failure, {
      operation_type: operation_type,
      duration: duration&.round(3),
      error: error,
      retry_attempt: current_retry_attempt,
      circuit_breaker_state: respond_to?(:circuit_breaker_state) ? circuit_breaker_state : nil
    })
  end

  def log_cache_event(event_type, cache_info = {})
    log_ai_operation(:debug, "cache_#{event_type}", {
      cache_key: cache_info[:key],
      cache_hit: cache_info[:hit],
      cache_ttl: cache_info[:ttl],
      tokens_saved: cache_info[:tokens_saved] || 0,
      similarity_score: cache_info[:similarity]
    })
  end

  def log_rate_limit_event(limit_type, limit_info = {})
    log_ai_operation(:warn, :rate_limit_hit, {
      limit_type: limit_type,
      current_usage: limit_info[:current],
      limit: limit_info[:limit],
      retry_after: limit_info[:retry_after],
      period: limit_info[:period]
    })
  end

  def log_provider_fallback(from_provider, to_provider, reason)
    log_ai_operation(:warn, :provider_fallback, {
      from_provider: from_provider,
      to_provider: to_provider,
      fallback_reason: reason,
      fallback_attempt: current_fallback_attempt
    })
  end

  def log_circuit_breaker_event(event_type, circuit_info = {})
    level = case event_type
            when :opened then :error
            when :closed then :info
            when :half_open then :warn
            else :info
            end

    log_ai_operation(level, "circuit_breaker_#{event_type}", {
      previous_state: circuit_info[:previous_state],
      failure_count: circuit_info[:failure_count],
      success_count: circuit_info[:success_count],
      threshold: circuit_info[:threshold]
    })
  end

  def log_cost_tracking(cost_info = {})
    log_ai_operation(:info, :cost_tracking, {
      estimated_cost: cost_info[:estimated_cost],
      input_tokens: cost_info[:input_tokens],
      output_tokens: cost_info[:output_tokens],
      cost_per_token: cost_info[:cost_per_token],
      currency: 'USD'
    })
  end

  def log_performance_warning(metric_type, current_value, threshold)
    log_ai_operation(:warn, :performance_warning, {
      metric: metric_type,
      current_value: current_value,
      threshold: threshold,
      severity: calculate_severity(current_value, threshold)
    })
  end

  def log_security_event(event_type, security_info = {})
    log_ai_operation(:warn, "security_#{event_type}", {
      content_flagged: security_info[:flagged],
      flag_reasons: security_info[:reasons],
      confidence_score: security_info[:confidence],
      action_taken: security_info[:action]
    })
  end

  # Context building methods
  def build_base_context
    {
      environment: Rails.env,
      application: Rails.application.class.module_parent_name.underscore,
      host: Socket.gethostname,
      process_id: Process.pid,
      thread_id: Thread.current.object_id,
      request_id: extract_request_id,
      user_id: extract_user_id,
      session_id: extract_session_id
    }
  end

  def extract_request_id
    # Try to extract from current request context
    if defined?(Current) && Current.respond_to?(:request_id)
      Current.request_id
    elsif Thread.current[:request_id]
      Thread.current[:request_id]
    else
      'background'
    end
  end

  def extract_user_id
    if defined?(Current) && Current.respond_to?(:user)
      Current.user&.id
    elsif Thread.current[:user_id]
      Thread.current[:user_id]
    else
      nil
    end
  end

  def extract_session_id
    if defined?(Current) && Current.respond_to?(:session_id)
      Current.session_id
    elsif Thread.current[:session_id]
      Thread.current[:session_id]
    else
      nil
    end
  end

  def extract_response_metadata(response_info)
    metadata = {}
    
    if response_info[:response].is_a?(Hash)
      response = response_info[:response]
      
      # Extract usage information
      if response['usage']
        metadata[:input_tokens] = response['usage']['input_tokens']
        metadata[:output_tokens] = response['usage']['output_tokens']
        metadata[:total_tokens] = response['usage']['total_tokens']
      end
      
      # Extract model information
      metadata[:model_used] = response['model'] if response['model']
      
      # Extract finish reason
      metadata[:finish_reason] = response.dig('choices', 0, 'finish_reason')
      
      # Extract any safety/content filtering results
      if response['content_filter_results']
        metadata[:content_filtered] = true
        metadata[:filter_results] = response['content_filter_results']
      end
    end
    
    metadata
  end

  def format_error_context(error)
    {
      class: error.class.name,
      message: error.message,
      backtrace: error.respond_to?(:backtrace) ? error.backtrace&.first(5) : nil,
      caused_by: error.respond_to?(:cause) && error.cause ? format_error_context(error.cause) : nil
    }
  end

  def current_retry_attempt
    respond_to?(:current_attempt) ? current_attempt : 0
  end

  def current_fallback_attempt
    if respond_to?(:fallback_attempts)
      fallback_attempts&.size || 0
    else
      0
    end
  end

  def calculate_severity(current, threshold)
    ratio = current.to_f / threshold.to_f
    case ratio
    when 0..1.0 then 'normal'
    when 1.0..1.5 then 'moderate'
    when 1.5..2.0 then 'high'
    else 'critical'
    end
  end

  # Log formatting
  def format_log_entry(entry)
    if Rails.env.production?
      # JSON format for production log aggregation
      entry.to_json
    else
      # Human-readable format for development
      timestamp = entry[:timestamp]
      level = entry[:level]
      event = entry[:event_type]
      provider = entry[:provider]
      operation = entry[:operation_id][0..7] # Short operation ID
      
      base = "[#{timestamp}] #{level} [AI:#{provider}:#{operation}] #{event}"
      
      # Add key details based on event type
      details = []
      case event
      when 'request_start'
        details << "op=#{entry[:operation_type]}"
        details << "tokens~#{entry[:estimated_tokens]}" if entry[:estimated_tokens]
      when 'request_success'
        details << "#{entry[:duration]}s"
        details << "#{entry[:tokens_used]}t" if entry[:tokens_used]
        details << "cached" if entry[:cached]
      when 'request_failure'
        details << "#{entry[:duration]}s" if entry[:duration]
        details << "error=#{entry[:error][:class]}" if entry[:error]
      when 'rate_limit_hit'
        details << "#{entry[:current_usage]}/#{entry[:limit]} #{entry[:limit_type]}"
      when 'provider_fallback'
        details << "#{entry[:from_provider]}→#{entry[:to_provider]}"
      end
      
      details_str = details.any? ? " (#{details.join(', ')})" : ""
      "#{base}#{details_str}"
    end
  end

  def should_send_external?(level)
    return false unless Rails.env.production?
    
    # Send warn and above to external services
    LOG_LEVELS[level] >= LOG_LEVELS[:warn]
  end

  def send_to_external_loggers(level, log_entry)
    # Integration points for external logging services
    
    # Datadog
    if ENV['DATADOG_API_KEY'].present?
      send_to_datadog(level, log_entry)
    end
    
    # New Relic
    if defined?(NewRelic) && NewRelic::Agent.config[:license_key]
      send_to_new_relic(level, log_entry)
    end
    
    # Sentry (for errors)
    if level >= :error && defined?(Sentry)
      send_to_sentry(log_entry)
    end
  end

  def send_to_datadog(level, log_entry)
    # Would integrate with Datadog logging API
    Rails.logger.debug "[EXTERNAL_LOG] Would send to Datadog: #{log_entry[:event_type]}"
  end

  def send_to_new_relic(level, log_entry)
    # Would integrate with New Relic logging
    Rails.logger.debug "[EXTERNAL_LOG] Would send to New Relic: #{log_entry[:event_type]}"
  end

  def send_to_sentry(log_entry)
    # Would send error context to Sentry
    Rails.logger.debug "[EXTERNAL_LOG] Would send to Sentry: #{log_entry[:event_type]}"
  end

  # Performance tracking helpers
  def with_performance_tracking(operation_type, &block)
    start_time = Time.current
    log_request_start(operation_type)
    
    begin
      result = yield
      duration = Time.current - start_time
      
      response_info = extract_response_info(result)
      log_request_success(operation_type, response_info.merge(duration: duration))
      
      result
    rescue => error
      duration = Time.current - start_time
      log_request_failure(operation_type, error, duration)
      raise
    end
  end

  def extract_response_info(result)
    {
      length: result.to_s.length,
      tokens: extract_token_count(result),
      cached: false, # Would be set by caching layer
      response: result
    }
  end

  def extract_token_count(result)
    if result.is_a?(Hash) && result['usage']
      result['usage']['total_tokens'] || 0
    else
      # Estimate based on character count
      (result.to_s.length / 4.0).ceil
    end
  end
end