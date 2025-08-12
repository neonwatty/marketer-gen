# Advanced retry strategies and fallback mechanisms for AI services
# Provides sophisticated retry logic with exponential backoff, jitter, and provider fallbacks
module AiRetryStrategies
  extend ActiveSupport::Concern

  class FallbackExhaustedError < StandardError; end
  class DegradedModeError < StandardError; end
  class ManualOverrideError < StandardError; end

  included do
    # Retry strategy configuration
    attribute :retry_strategy, :string, default: "exponential_backoff_with_jitter"
    attribute :max_retry_attempts, :integer, default: 3
    attribute :base_retry_delay, :float, default: 1.0
    attribute :max_retry_delay, :float, default: 60.0
    attribute :jitter_factor, :float, default: 0.25
    attribute :backoff_multiplier, :float, default: 2.0

    # Fallback configuration  
    attribute :enable_provider_fallback, :boolean, default: true
    attribute :fallback_providers, :string, default: ""
    attribute :fallback_model_mapping, :string, default: ""
    
    # Degraded mode configuration
    attribute :enable_degraded_mode, :boolean, default: true
    attribute :degraded_mode_providers, :string, default: ""
    attribute :degraded_mode_response_quality, :string, default: "reduced"
    
    # Manual override configuration
    attribute :manual_override_enabled, :boolean, default: false
    attribute :override_reason, :string
    attribute :override_expires_at, :datetime

    # Request tracking for smart fallbacks
    attr_reader :fallback_attempts, :degraded_mode_active, :last_fallback_error
  end

  def initialize(attributes = {})
    super(attributes)
    @fallback_attempts = []
    @degraded_mode_active = false
    @last_fallback_error = nil
  end

  # Enhanced request with comprehensive retry and fallback strategies
  def make_enhanced_request_with_fallbacks(request_proc, cache_options = {})
    check_manual_override!

    # Primary provider attempt with retries
    begin
      return attempt_request_with_strategy(request_proc, cache_options)
    rescue CircuitBreakerOpenError, ProviderUnavailableError, RateLimitError => e
      Rails.logger.warn "Primary provider failed: #{e.message}"
      @last_fallback_error = e
      
      return attempt_fallback_providers(request_proc, cache_options) if enable_provider_fallback
      
      # If no fallback providers or all failed, try degraded mode
      return attempt_degraded_mode(request_proc, cache_options) if enable_degraded_mode
      
      raise e
    end
  end

  # Attempt request with configured retry strategy
  def attempt_request_with_strategy(request_proc, cache_options = {})
    case retry_strategy
    when "exponential_backoff_with_jitter"
      exponential_backoff_with_jitter_retry(request_proc, cache_options)
    when "linear_backoff"
      linear_backoff_retry(request_proc, cache_options)
    when "fibonacci_backoff"
      fibonacci_backoff_retry(request_proc, cache_options)
    when "adaptive_backoff"
      adaptive_backoff_retry(request_proc, cache_options)
    else
      # Fall back to base implementation
      make_request_with_retries(request_proc, cache_options)
    end
  end

  # Exponential backoff with jitter retry strategy
  def exponential_backoff_with_jitter_retry(request_proc, cache_options = {})
    attempt = 0
    last_error = nil

    while attempt < max_retry_attempts
      begin
        return execute_request_with_monitoring(request_proc, cache_options, attempt)
      rescue RateLimitError, ProviderUnavailableError, CircuitBreakerOpenError => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        delay = calculate_exponential_backoff_with_jitter(attempt)
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      rescue AuthenticationError, InvalidRequestError, ContextTooLongError => e
        # Don't retry these errors
        raise e
      rescue => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        delay = calculate_exponential_backoff_with_jitter(attempt)
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      end

      attempt += 1
    end

    raise last_error
  end

  # Attempt fallback providers in order
  def attempt_fallback_providers(request_proc, cache_options = {})
    fallback_list = parsed_fallback_providers
    return nil if fallback_list.empty?

    fallback_list.each do |fallback_config|
      begin
        Rails.logger.info "Attempting fallback provider: #{fallback_config[:provider]}"
        @fallback_attempts << {
          provider: fallback_config[:provider],
          model: fallback_config[:model],
          attempted_at: Time.current
        }

        # Create fallback service instance
        fallback_service = create_fallback_service(fallback_config)
        
        # Execute request with fallback service
        result = fallback_service.attempt_request_with_strategy(request_proc, cache_options)
        
        Rails.logger.info "Fallback provider succeeded: #{fallback_config[:provider]}"
        return result

      rescue => e
        Rails.logger.warn "Fallback provider failed: #{fallback_config[:provider]} - #{e.message}"
        @fallback_attempts.last[:error] = e.message
        @last_fallback_error = e
        continue
      end
    end

    # Send alert for fallback exhaustion
    AiAlertingService.send_alert(:fallback_exhausted, {
      provider: provider_name,
      model: attributes['model_name'],
      attempted_fallbacks: @fallback_attempts,
      last_error: @last_fallback_error&.message
    })
    
    raise FallbackExhaustedError, "All fallback providers exhausted. Last error: #{@last_fallback_error&.message}"
  end

  # Attempt degraded mode operation
  def attempt_degraded_mode(request_proc, cache_options = {})
    return nil unless enable_degraded_mode

    @degraded_mode_active = true
    Rails.logger.warn "Entering degraded mode for AI service"
    
    # Send degraded mode alert
    AiAlertingService.send_alert(:degraded_mode_active, {
      provider: provider_name,
      model: attributes['model_name'],
      reason: "Primary and fallback providers unavailable"
    })

    degraded_providers = parsed_degraded_mode_providers
    return attempt_degraded_providers(request_proc, cache_options, degraded_providers) unless degraded_providers.empty?

    # If no specific degraded providers, try with reduced parameters
    degraded_cache_options = cache_options.merge(
      max_tokens: [cache_options[:max_tokens] || 1000, 500].min,
      temperature: [cache_options[:temperature] || 0.7, 0.3].min,
      degraded_mode: true
    )

    begin
      result = attempt_request_with_strategy(request_proc, degraded_cache_options)
      Rails.logger.info "Degraded mode request succeeded"
      return result
    rescue => e
      Rails.logger.error "Degraded mode failed: #{e.message}"
      raise DegradedModeError, "Service temporarily unavailable in degraded mode: #{e.message}"
    end
  end

  # Execute request with comprehensive monitoring
  def execute_request_with_monitoring(request_proc, cache_options, attempt)
    start_time = Time.current
    
    begin
      # Check circuit breaker state
      check_circuit_breaker!
      
      # Check rate limits
      estimated_tokens = cache_options[:estimated_tokens] || 0
      check_rate_limits!(estimated_tokens) if respond_to?(:check_rate_limits!)

      # Execute request
      response = request_proc.call
      
      # Record success metrics
      record_success_metrics(start_time, attempt, cache_options)
      
      return response

    rescue => e
      # Record failure metrics
      record_failure_metrics(start_time, attempt, e)
      raise e
    end
  end

  # Check for manual override conditions
  def check_manual_override!
    return unless manual_override_enabled

    if override_expires_at && Time.current > override_expires_at
      # Override expired, reset
      self.manual_override_enabled = false
      self.override_reason = nil
      self.override_expires_at = nil
      return
    end

    if manual_override_enabled && override_reason.present?
      raise ManualOverrideError, "Service manually disabled: #{override_reason}"
    end
  end

  # Set manual override with reason and expiration
  def set_manual_override!(reason, expires_in: 1.hour)
    self.manual_override_enabled = true
    self.override_reason = reason
    self.override_expires_at = Time.current + expires_in
    
    Rails.logger.error "Manual override activated for #{provider_name}: #{reason} (expires: #{override_expires_at})"
    
    # Trigger alert
    AiAlertingService.send_alert(:manual_override, {
      provider: provider_name,
      reason: reason,
      expires_at: override_expires_at
    })
  end

  # Clear manual override
  def clear_manual_override!
    self.manual_override_enabled = false
    self.override_reason = nil
    self.override_expires_at = nil
    
    Rails.logger.info "Manual override cleared for #{provider_name}"
  end

  # Retry strategy implementations
  private

  def calculate_exponential_backoff_with_jitter(attempt)
    # Base exponential backoff: base_delay * (multiplier ^ attempt)
    exponential_delay = base_retry_delay * (backoff_multiplier ** attempt)
    
    # Apply maximum delay cap
    capped_delay = [exponential_delay, max_retry_delay].min
    
    # Add jitter: random factor to prevent thundering herd
    jitter = rand(0.0..(capped_delay * jitter_factor))
    
    capped_delay + jitter
  end

  def linear_backoff_retry(request_proc, cache_options)
    attempt = 0
    last_error = nil

    while attempt < max_retry_attempts
      begin
        return execute_request_with_monitoring(request_proc, cache_options, attempt)
      rescue RateLimitError, ProviderUnavailableError, CircuitBreakerOpenError => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        delay = base_retry_delay * (attempt + 1) + rand(0.0..jitter_factor)
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      rescue AuthenticationError, InvalidRequestError, ContextTooLongError => e
        raise e
      rescue => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        delay = base_retry_delay * (attempt + 1) + rand(0.0..jitter_factor)
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      end

      attempt += 1
    end

    raise last_error
  end

  def fibonacci_backoff_retry(request_proc, cache_options)
    attempt = 0
    last_error = nil
    fibonacci_sequence = [1, 1]

    while attempt < max_retry_attempts
      begin
        return execute_request_with_monitoring(request_proc, cache_options, attempt)
      rescue RateLimitError, ProviderUnavailableError, CircuitBreakerOpenError => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        # Generate next fibonacci number if needed
        if attempt >= fibonacci_sequence.length - 1
          fibonacci_sequence << fibonacci_sequence[-1] + fibonacci_sequence[-2]
        end
        
        delay = base_retry_delay * fibonacci_sequence[attempt] + rand(0.0..jitter_factor)
        delay = [delay, max_retry_delay].min
        
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      rescue AuthenticationError, InvalidRequestError, ContextTooLongError => e
        raise e
      rescue => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        if attempt >= fibonacci_sequence.length - 1
          fibonacci_sequence << fibonacci_sequence[-1] + fibonacci_sequence[-2]
        end
        
        delay = base_retry_delay * fibonacci_sequence[attempt] + rand(0.0..jitter_factor)
        delay = [delay, max_retry_delay].min
        
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      end

      attempt += 1
    end

    raise last_error
  end

  def adaptive_backoff_retry(request_proc, cache_options)
    # Adaptive strategy based on recent failure patterns and response times
    attempt = 0
    last_error = nil
    recent_response_times = get_recent_response_times

    while attempt < max_retry_attempts
      begin
        return execute_request_with_monitoring(request_proc, cache_options, attempt)
      rescue RateLimitError => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        # For rate limits, use longer delays
        delay = calculate_adaptive_delay(attempt, :rate_limit, recent_response_times)
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      rescue ProviderUnavailableError, CircuitBreakerOpenError => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        # For availability issues, use longer delays with more jitter
        delay = calculate_adaptive_delay(attempt, :availability, recent_response_times)
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      rescue AuthenticationError, InvalidRequestError, ContextTooLongError => e
        raise e
      rescue => e
        last_error = e
        break if attempt >= max_retry_attempts - 1
        
        delay = calculate_adaptive_delay(attempt, :general, recent_response_times)
        log_retry_attempt(attempt, e, delay)
        sleep(delay)
      end

      attempt += 1
    end

    raise last_error
  end

  def calculate_adaptive_delay(attempt, error_type, recent_response_times)
    # Base delay calculation
    base_delay = case error_type
                when :rate_limit
                  base_retry_delay * 3 # Longer for rate limits
                when :availability
                  base_retry_delay * 2 # Longer for availability issues
                else
                  base_retry_delay
                end

    # Adjust based on recent performance
    avg_response_time = recent_response_times.any? ? recent_response_times.sum / recent_response_times.size : 1.0
    performance_multiplier = [avg_response_time / 2.0, 0.5].max # Don't go below 0.5x

    # Exponential component with performance adjustment
    exponential_delay = base_delay * performance_multiplier * (backoff_multiplier ** attempt)
    
    # Apply caps and jitter
    capped_delay = [exponential_delay, max_retry_delay].min
    jitter = rand(0.0..(capped_delay * jitter_factor * 1.5)) # More jitter for adaptive
    
    capped_delay + jitter
  end

  # Provider fallback utilities
  def parsed_fallback_providers
    return [] if fallback_providers.blank?
    
    # Parse fallback_providers string: "openai:gpt-4o,anthropic:claude-3-haiku"
    fallback_providers.split(",").map do |provider_config|
      provider, model = provider_config.strip.split(":")
      { provider: provider.to_sym, model: model || get_default_model_for_provider(provider) }
    end
  end

  def parsed_degraded_mode_providers
    return [] if degraded_mode_providers.blank?
    
    degraded_mode_providers.split(",").map do |provider_config|
      provider, model = provider_config.strip.split(":")
      { provider: provider.to_sym, model: model || get_default_model_for_provider(provider) }
    end
  end

  def create_fallback_service(fallback_config)
    AiServiceFactory.create(
      provider: fallback_config[:provider],
      model: fallback_config[:model],
      timeout_seconds: timeout_seconds,
      max_retries: 1 # Reduce retries for fallbacks to fail faster
    )
  end

  def get_default_model_for_provider(provider)
    case provider.to_sym
    when :openai
      "gpt-4o-mini"
    when :anthropic
      "claude-3-5-haiku-20241022"
    when :gemini
      "gemini-1.5-flash"
    else
      nil
    end
  end

  def attempt_degraded_providers(request_proc, cache_options, degraded_providers)
    degraded_providers.each do |degraded_config|
      begin
        Rails.logger.info "Attempting degraded mode provider: #{degraded_config[:provider]}"
        
        degraded_service = create_fallback_service(degraded_config)
        result = degraded_service.attempt_request_with_strategy(request_proc, cache_options)
        
        Rails.logger.info "Degraded mode provider succeeded: #{degraded_config[:provider]}"
        return result

      rescue => e
        Rails.logger.warn "Degraded mode provider failed: #{degraded_config[:provider]} - #{e.message}"
        continue
      end
    end

    nil
  end

  # Monitoring and metrics
  def record_success_metrics(start_time, attempt, options)
    duration = Time.current - start_time
    
    # Log success
    Rails.logger.info "AI request succeeded on attempt #{attempt + 1} in #{duration.round(2)}s"
    
    # Record metrics (could integrate with monitoring service)
    record_request_metric(:success, {
      provider: provider_name,
      model: attributes['model_name'],
      attempt: attempt + 1,
      duration: duration,
      degraded_mode: @degraded_mode_active
    })
  end

  def record_failure_metrics(start_time, attempt, error)
    duration = Time.current - start_time
    
    # Log failure
    Rails.logger.warn "AI request failed on attempt #{attempt + 1} after #{duration.round(2)}s: #{error.message}"
    
    # Record metrics
    record_request_metric(:failure, {
      provider: provider_name,
      model: attributes['model_name'],
      attempt: attempt + 1,
      duration: duration,
      error_type: error.class.name,
      degraded_mode: @degraded_mode_active
    })
  end

  def record_request_metric(status, data)
    # This would integrate with your monitoring system (Prometheus, DataDog, etc.)
    # For now, just store in Rails cache for basic metrics
    metric_key = "ai_metrics:#{provider_name}:#{Date.current}"
    metrics = Rails.cache.read(metric_key) || { successes: 0, failures: 0, total_duration: 0.0 }
    
    case status
    when :success
      metrics[:successes] += 1
      metrics[:total_duration] += data[:duration]
    when :failure
      metrics[:failures] += 1
    end
    
    Rails.cache.write(metric_key, metrics, expires_in: 7.days)
  end

  def get_recent_response_times
    # Get recent response times for adaptive backoff
    # This is a simplified implementation - in production you'd want proper time series data
    metric_keys = (0..2).map { |days_ago| "ai_metrics:#{provider_name}:#{Date.current - days_ago}" }
    
    response_times = []
    metric_keys.each do |key|
      metrics = Rails.cache.read(key)
      if metrics && metrics[:successes] > 0
        avg_time = metrics[:total_duration] / metrics[:successes]
        response_times << avg_time
      end
    end
    
    response_times
  end

  def log_retry_attempt(attempt, error, delay)
    Rails.logger.warn "AI request retry #{attempt + 1}/#{max_retry_attempts} after #{error.class.name}: #{error.message} (waiting #{delay.round(2)}s)"
  end

end