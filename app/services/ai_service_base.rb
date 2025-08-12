# Abstract base class for AI service implementations
# Provides common interface and error handling for all AI service providers
class AiServiceBase
  include ActiveModel::Model
  include ActiveModel::Attributes
  include AiRateLimiter
  include AiResponseCache
  include AiRetryStrategies
  include AiStructuredLogging

  # Common error classes for AI operations
  class AIServiceError < StandardError; end
  class ProviderError < AIServiceError; end
  class RateLimitError < AIServiceError; end
  class AuthenticationError < AIServiceError; end
  class InvalidRequestError < AIServiceError; end
  class ContextTooLongError < AIServiceError; end
  class InsufficientCreditsError < AIServiceError; end
  class ProviderUnavailableError < AIServiceError; end
  class CircuitBreakerOpenError < AIServiceError; end

  # Configuration attributes
  attribute :provider_name, :string
  attribute :api_key, :string
  attribute :api_base_url, :string
  attribute :model_name, :string
  attribute :timeout_seconds, :integer, default: 30
  attribute :max_retries, :integer, default: 3
  attribute :retry_delay_seconds, :integer, default: 1

  # Circuit breaker configuration
  attribute :circuit_breaker_failure_threshold, :integer, default: 5
  attribute :circuit_breaker_recovery_timeout, :integer, default: 60
  attribute :circuit_breaker_success_threshold, :integer, default: 3

  # Request/response tracking
  attr_reader :last_request, :last_response, :errors, :circuit_breaker_state

  def initialize(attributes = {})
    super(attributes)
    @errors = []
    @last_request = nil
    @last_response = nil
    
    # Circuit breaker state
    @circuit_breaker_state = :closed  # :closed, :open, :half_open
    @failure_count = 0
    @last_failure_time = nil
    @success_count = 0
  end

  # Main interface methods - must be implemented by subclasses
  def generate_content(prompt, options = {})
    raise NotImplementedError, "Subclasses must implement #generate_content"
  end

  def generate_campaign_plan(campaign_data, options = {})
    raise NotImplementedError, "Subclasses must implement #generate_campaign_plan"
  end

  def analyze_brand_assets(assets, options = {})
    raise NotImplementedError, "Subclasses must implement #analyze_brand_assets"
  end

  def generate_content_for_channel(channel, brand_context, options = {})
    raise NotImplementedError, "Subclasses must implement #generate_content_for_channel"
  end

  # Provider capability checks
  def supports_function_calling?
    false
  end

  def supports_image_analysis?
    false
  end

  def supports_streaming?
    false
  end

  def max_context_tokens
    4096 # Conservative default
  end

  # Health check and validation
  def healthy?
    validate_configuration
    test_connection
  rescue => e
    @errors << "Health check failed: #{e.message}"
    false
  end

  def validate_configuration
    raise InvalidRequestError, "Provider name is required" if provider_name.blank?
    raise InvalidRequestError, "API key is required" if api_key.blank?
    raise InvalidRequestError, "Model name is required" if attributes['model_name'].blank?
    true
  end

  def test_connection
    # Subclasses should override with provider-specific health check
    true
  end

  protected

  # Common request handling with retries, error handling, circuit breaker, rate limiting, and caching
  def make_request_with_retries(request_proc, cache_options = {})
    # Check circuit breaker state first
    check_circuit_breaker!
    
    # Check for cached response if caching is enabled and prompt is provided
    if cache_options[:prompt] && cache_enabled
      cached_response = get_cached_response(cache_options[:prompt], cache_options)
      if cached_response
        return cached_response[:response]
      end
      
      # Try similar cached responses if enabled
      if cache_similar_prompts
        similar_response = find_similar_cached_response(cache_options[:prompt], cache_options)
        if similar_response
          return similar_response[:response]
        end
      end
    end
    
    # Estimate tokens for rate limiting
    estimated_tokens = cache_options[:estimated_tokens] || 
                      (cache_options[:prompt] ? estimate_token_count(cache_options[:prompt]) : 0)
    
    # Check rate limits before making request
    begin
      check_rate_limits!(estimated_tokens)
    rescue AiRateLimiter::RateLimitExceededError => e
      # Convert to our standard RateLimitError
      raise RateLimitError, e.message
    end
    
    attempt = 0
    last_error = nil

    while attempt < max_retries
      begin
        @last_request = log_request_start(attempt)
        response = request_proc.call
        @last_response = log_request_success(response)
        
        # Record successful request for rate limiting
        actual_tokens = cache_options[:response_tokens] || estimate_token_count(response.to_s)
        record_rate_limit_usage(actual_tokens)
        
        # Cache the response if caching is enabled
        if cache_options[:prompt] && cache_enabled
          cache_response(cache_options[:prompt], response, cache_options.merge(estimated_tokens: actual_tokens))
        end
        
        # Record successful request for circuit breaker
        record_success
        
        return response
      rescue RateLimitError => e
        last_error = e
        sleep_duration = calculate_backoff_delay(attempt, retry_delay_seconds)
        Rails.logger.warn "Rate limited on attempt #{attempt + 1}, retrying in #{sleep_duration}s: #{e.message}"
        sleep(sleep_duration)
      rescue AiRateLimiter::RateLimitExceededError => e
        # Convert internal rate limit error to standard RateLimitError and retry
        last_error = RateLimitError.new(e.message)
        sleep_duration = e.retry_after || calculate_backoff_delay(attempt, retry_delay_seconds)
        Rails.logger.warn "Rate limit exceeded on attempt #{attempt + 1}, retrying in #{sleep_duration}s: #{e.message}"
        sleep(sleep_duration)
      rescue ProviderUnavailableError => e
        last_error = e
        sleep_duration = calculate_backoff_delay(attempt, retry_delay_seconds * 2)
        Rails.logger.warn "Provider unavailable on attempt #{attempt + 1}, retrying in #{sleep_duration}s: #{e.message}"
        sleep(sleep_duration)
        
        # Record failure for circuit breaker
        record_failure
        
      rescue AuthenticationError, InvalidRequestError, ContextTooLongError => e
        # These errors shouldn't be retried
        log_request_error(e)
        raise e
      rescue => e
        last_error = e
        Rails.logger.warn "Request failed on attempt #{attempt + 1}: #{e.message}"
        
        # Record failure for circuit breaker
        record_failure
      end

      attempt += 1
    end

    log_request_error(last_error)
    raise last_error || AIServiceError.new("Request failed after #{max_retries} attempts")
  end

  # Exponential backoff calculation
  def calculate_backoff_delay(attempt, base_delay)
    base_delay * (2 ** attempt) + rand(0..1.0)
  end

  # Logging methods
  def log_request_start(attempt)
    Rails.logger.info "AI request starting (attempt #{attempt + 1}/#{max_retries}) - Provider: #{provider_name}, Model: #{attributes['model_name']}"
    {
      timestamp: Time.current,
      provider: provider_name,
      model: attributes['model_name'],
      attempt: attempt + 1
    }
  end

  def log_request_success(response)
    duration = Time.current - @last_request[:timestamp]
    Rails.logger.info "AI request completed successfully in #{duration.round(2)}s"
    {
      timestamp: Time.current,
      duration: duration,
      success: true,
      response_size: response.to_s.length
    }
  end

  def log_request_error(error)
    duration = @last_request ? Time.current - @last_request[:timestamp] : 0
    Rails.logger.error "AI request failed after #{duration.round(2)}s: #{error.class.name} - #{error.message}"
    @errors << "#{error.class.name}: #{error.message}"
    {
      timestamp: Time.current,
      duration: duration,
      success: false,
      error_class: error.class.name,
      error_message: error.message
    }
  end

  # Content processing utilities
  def sanitize_prompt(prompt)
    return "" if prompt.blank?
    
    # Remove potential injection attempts and clean up
    cleaned = prompt.gsub(/\r\n|\r/, "\n")  # Normalize line endings
                   .gsub(/\n{3,}/, "\n\n")   # Reduce excessive newlines
                   .strip

    # Truncate if too long (leave room for system prompts)
    max_prompt_length = max_context_tokens - 1000
    if cleaned.length > max_prompt_length
      cleaned = cleaned[0..max_prompt_length] + "\n\n[Content truncated due to length limits]"
    end

    cleaned
  end

  def extract_json_from_response(response_text)
    # Try to extract JSON from markdown code blocks or raw text
    json_match = response_text.match(/```(?:json)?\s*(\{.*?\})\s*```/m) ||
                response_text.match(/(\{.*?\})/m)
    
    return nil unless json_match
    
    begin
      JSON.parse(json_match[1])
    rescue JSON::ParserError => e
      Rails.logger.warn "Failed to parse JSON from AI response: #{e.message}"
      nil
    end
  end

  # Token counting estimation (provider-specific implementations should override)
  def estimate_token_count(text)
    # Rough estimation: ~4 characters per token for English text
    (text.to_s.length / 4.0).ceil
  end

  # Circuit breaker implementation
  def check_circuit_breaker!
    case @circuit_breaker_state
    when :open
      if Time.current.to_i - @last_failure_time > circuit_breaker_recovery_timeout
        # Move to half-open state
        @circuit_breaker_state = :half_open
        @success_count = 0
        Rails.logger.info "Circuit breaker moved to half-open state for #{provider_name}"
      else
        raise CircuitBreakerOpenError, "Circuit breaker is open for #{provider_name}. Provider temporarily unavailable."
      end
    when :half_open
      # Allow request to proceed, but monitor closely
      nil
    when :closed
      # Normal operation
      nil
    end
  end

  def record_failure
    @failure_count += 1
    @last_failure_time = Time.current.to_i
    
    if @circuit_breaker_state == :closed && @failure_count >= circuit_breaker_failure_threshold
      @circuit_breaker_state = :open
      Rails.logger.error "Circuit breaker opened for #{provider_name} after #{@failure_count} failures"
      
      # Send alert for circuit breaker opening
      AiAlertingService.send_alert(:circuit_breaker_open, {
        provider: provider_name,
        model: attributes['model_name'],
        failure_count: @failure_count,
        threshold: circuit_breaker_failure_threshold
      })
    elsif @circuit_breaker_state == :half_open
      @circuit_breaker_state = :open
      Rails.logger.error "Circuit breaker reopened for #{provider_name} - failure in half-open state"
      
      # Send alert for circuit breaker reopening
      AiAlertingService.send_alert(:circuit_breaker_open, {
        provider: provider_name,
        model: attributes['model_name'],
        failure_count: @failure_count,
        state_change: "half_open_to_open"
      })
    end
  end

  def record_success
    if @circuit_breaker_state == :half_open
      @success_count += 1
      if @success_count >= circuit_breaker_success_threshold
        @circuit_breaker_state = :closed
        @failure_count = 0
        Rails.logger.info "Circuit breaker closed for #{provider_name} after #{@success_count} successful requests"
        
        # Send recovery alert
        AiAlertingService.send_recovery_alert(provider_name, {
          model: attributes['model_name'],
          success_count: @success_count,
          recovery_method: "circuit_breaker_closed"
        })
      end
    elsif @circuit_breaker_state == :closed
      # Reset failure count on successful request
      @failure_count = 0
    end
  end
end