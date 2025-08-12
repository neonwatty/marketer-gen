# Rate limiting functionality for AI services
# Provides configurable rate limiting with multiple strategies
module AiRateLimiter
  extend ActiveSupport::Concern

  class RateLimitExceededError < StandardError
    attr_reader :retry_after, :limit, :remaining

    def initialize(message, retry_after: nil, limit: nil, remaining: nil)
      super(message)
      @retry_after = retry_after
      @limit = limit
      @remaining = remaining
    end
  end

  included do
    # Rate limiting configuration
    attribute :rate_limit_requests_per_minute, :integer, default: 60
    attribute :rate_limit_requests_per_hour, :integer, default: 1000
    attribute :rate_limit_requests_per_day, :integer, default: 10000
    attribute :rate_limit_tokens_per_minute, :integer, default: 150000
    attribute :rate_limit_enabled, :boolean, default: true
    attribute :rate_limit_key_prefix, :string
  end

  # Check all rate limits before making a request
  def check_rate_limits!(estimated_tokens = 0)
    return unless rate_limit_enabled

    # Check requests per minute
    check_request_rate_limit!(:minute, rate_limit_requests_per_minute, 60)
    
    # Check requests per hour
    check_request_rate_limit!(:hour, rate_limit_requests_per_hour, 3600)
    
    # Check requests per day
    check_request_rate_limit!(:day, rate_limit_requests_per_day, 86400)
    
    # Check tokens per minute if estimated tokens provided
    if estimated_tokens > 0
      check_token_rate_limit!(:minute, rate_limit_tokens_per_minute, 60, estimated_tokens)
    end
  end

  # Record a successful request for rate limiting
  def record_rate_limit_usage(tokens_used = 0)
    return unless rate_limit_enabled

    current_time = Time.current

    # Increment request counters
    increment_rate_limit_counter("requests:minute", current_time.beginning_of_minute, 60)
    increment_rate_limit_counter("requests:hour", current_time.beginning_of_hour, 3600)
    increment_rate_limit_counter("requests:day", current_time.beginning_of_day, 86400)

    # Increment token counter if tokens used
    if tokens_used > 0
      increment_rate_limit_counter("tokens:minute", current_time.beginning_of_minute, 60, tokens_used)
    end
  end

  # Get current rate limit status
  def rate_limit_status
    return { enabled: false } unless rate_limit_enabled

    current_time = Time.current
    
    {
      enabled: true,
      requests: {
        minute: get_rate_limit_usage("requests:minute", current_time.beginning_of_minute),
        hour: get_rate_limit_usage("requests:hour", current_time.beginning_of_hour),
        day: get_rate_limit_usage("requests:day", current_time.beginning_of_day)
      },
      tokens: {
        minute: get_rate_limit_usage("tokens:minute", current_time.beginning_of_minute)
      },
      limits: {
        requests_per_minute: rate_limit_requests_per_minute,
        requests_per_hour: rate_limit_requests_per_hour,
        requests_per_day: rate_limit_requests_per_day,
        tokens_per_minute: rate_limit_tokens_per_minute
      }
    }
  end

  private

  def check_request_rate_limit!(period, limit, ttl_seconds)
    return if limit <= 0

    current_time = Time.current
    window_start = case period
                  when :minute then current_time.beginning_of_minute
                  when :hour then current_time.beginning_of_hour
                  when :day then current_time.beginning_of_day
                  end

    current_usage = get_rate_limit_usage("requests:#{period}", window_start)
    
    if current_usage >= limit
      retry_after = window_start + ttl_seconds - current_time.to_i
      
      # Send rate limit alert
      AiAlertingService.send_alert(:rate_limit_exceeded, {
        provider: provider_name,
        model: attributes['model_name'],
        period: period,
        limit: limit,
        current_usage: current_usage,
        retry_after: retry_after
      })
      
      raise RateLimitExceededError.new(
        "Rate limit exceeded: #{current_usage}/#{limit} requests per #{period}",
        retry_after: retry_after,
        limit: limit,
        remaining: 0
      )
    end
  end

  def check_token_rate_limit!(period, limit, ttl_seconds, estimated_tokens)
    return if limit <= 0

    current_time = Time.current
    window_start = current_time.beginning_of_minute

    current_usage = get_rate_limit_usage("tokens:#{period}", window_start)
    
    if current_usage + estimated_tokens > limit
      retry_after = window_start + ttl_seconds - current_time.to_i
      remaining_tokens = [limit - current_usage, 0].max
      
      # Send token rate limit alert
      AiAlertingService.send_alert(:rate_limit_exceeded, {
        provider: provider_name,
        model: attributes['model_name'],
        period: period,
        limit: limit,
        current_usage: current_usage,
        estimated_tokens: estimated_tokens,
        limit_type: "tokens",
        retry_after: retry_after
      })
      
      raise RateLimitExceededError.new(
        "Token rate limit exceeded: #{current_usage + estimated_tokens}/#{limit} tokens per #{period}",
        retry_after: retry_after,
        limit: limit,
        remaining: remaining_tokens
      )
    end
  end

  def increment_rate_limit_counter(counter_type, window_start, ttl_seconds, increment = 1)
    cache_key = rate_limit_cache_key(counter_type, window_start)
    
    # Use Rails cache with expiration
    current_value = Rails.cache.read(cache_key) || 0
    new_value = current_value + increment
    Rails.cache.write(cache_key, new_value, expires_in: ttl_seconds.seconds)
    
    new_value
  end

  def get_rate_limit_usage(counter_type, window_start)
    cache_key = rate_limit_cache_key(counter_type, window_start)
    Rails.cache.read(cache_key) || 0
  end

  def rate_limit_cache_key(counter_type, window_start)
    prefix = rate_limit_key_prefix || "ai_rate_limit:#{provider_name}:#{attributes['model_name']}"
    timestamp = window_start.to_i
    "#{prefix}:#{counter_type}:#{timestamp}"
  end
end