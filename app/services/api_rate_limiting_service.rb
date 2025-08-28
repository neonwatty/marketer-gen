# frozen_string_literal: true

# Sophisticated API rate limiting service that manages request queuing, 
# optimization, and platform-specific quota enforcement
class ApiRateLimitingService < ApplicationService
  class RateLimitExceeded < StandardError; end
  class QuotaExceeded < StandardError; end

  # Rate limiting strategies
  STRATEGIES = {
    aggressive: { burst_multiplier: 1.0, delay_factor: 1.0 },
    conservative: { burst_multiplier: 0.7, delay_factor: 1.5 },
    balanced: { burst_multiplier: 0.85, delay_factor: 1.2 }
  }.freeze

  # Platform-specific rate limits (requests per second)
  RATE_LIMITS = {
    'google_ads' => { 
      'search' => 5,
      'mutate' => 2,
      'reporting' => 10
    },
    'linkedin' => {
      'profile' => 2,
      'campaigns' => 1,
      'insights' => 3
    },
    'meta' => {
      'graph_api' => 200,
      'marketing_api' => 5,
      'insights' => 10
    }
  }.freeze

  def initialize(platform:, endpoint:, customer_id:, strategy: :balanced)
    super()
    @platform = platform
    @endpoint = endpoint
    @customer_id = customer_id
    @strategy = STRATEGIES[strategy] || STRATEGIES[:balanced]
    @quota_tracker = ApiQuotaTracker.get_or_create_for(
      platform: platform,
      endpoint: endpoint,
      customer_id: customer_id
    )
    @rate_limiter = initialize_rate_limiter
  end

  # Execute API request with rate limiting and quota management
  def execute_request(&block)
    # Check quota availability
    unless @quota_tracker.quota_available?
      raise QuotaExceeded, "API quota exceeded for #{@platform}/#{@endpoint}. " \
                           "Resets in #{@quota_tracker.time_until_reset.round} seconds"
    end

    # Apply rate limiting
    wait_time = calculate_wait_time
    sleep(wait_time) if wait_time > 0

    # Execute the actual API request
    result = nil
    request_successful = false
    
    begin
      result = yield if block_given?
      request_successful = true
      
      # Consume quota on successful request
      @quota_tracker.consume_quota!
      record_request_success
      
      result
    rescue => error
      record_request_failure(error)
      
      # Handle rate limiting errors specifically
      if rate_limit_error?(error)
        handle_rate_limit_error(error)
        raise RateLimitExceeded, "Rate limit exceeded: #{error.message}"
      else
        # Don't consume quota for failed requests (unless it's a rate limit)
        raise error
      end
    end
  end

  # Batch execute multiple requests with intelligent queuing
  def execute_batch_requests(requests, &block)
    results = []
    failed_requests = []
    
    requests.each_with_index do |request, index|
      begin
        result = execute_request do
          yield(request, index) if block_given?
        end
        results << { index: index, result: result, success: true }
      rescue RateLimitExceeded, QuotaExceeded => error
        failed_requests << { index: index, request: request, error: error.message }
        results << { index: index, result: nil, success: false, error: error.message }
        
        # Stop processing if quota is exceeded
        break if error.is_a?(QuotaExceeded)
      rescue => error
        # Handle other errors gracefully
        failed_requests << { index: index, request: request, error: error.message }
        results << { index: index, result: nil, success: false, error: error.message }
      end
    end
    
    {
      results: results,
      successful: results.count { |r| r[:success] },
      failed: results.count { |r| !r[:success] },
      failed_requests: failed_requests
    }
  end

  # Get current rate limiting status
  def status
    {
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      strategy: @strategy,
      quota: {
        limit: @quota_tracker.quota_limit,
        used: @quota_tracker.current_usage,
        remaining: @quota_tracker.remaining_quota,
        usage_percentage: @quota_tracker.usage_percentage,
        time_until_reset: @quota_tracker.time_until_reset
      },
      rate_limit: {
        requests_per_second: current_rate_limit,
        current_window_usage: current_window_usage,
        estimated_wait_time: calculate_wait_time
      }
    }
  end

  # Optimize request timing based on quota and rate limits
  def optimize_request_timing(request_count)
    return { can_proceed: false, reason: 'quota_exceeded' } unless @quota_tracker.quota_available?(request_count)
    
    rate_limit = current_rate_limit
    time_required = request_count / rate_limit.to_f
    quota_percentage = @quota_tracker.usage_percentage
    
    # Adjust timing based on quota usage
    if quota_percentage > 90
      time_required *= 2.0  # Slow down when near quota limit
    elsif quota_percentage > 75
      time_required *= 1.5
    end
    
    {
      can_proceed: true,
      estimated_duration: time_required,
      recommended_batch_size: optimal_batch_size,
      wait_time: calculate_wait_time,
      strategy_recommendation: recommend_strategy(quota_percentage)
    }
  end

  # Class methods for global quota management
  def self.quota_status_for_customer(customer_id)
    ApiQuotaTracker.quota_status_summary(customer_id)
  end

  def self.reset_expired_quotas!
    ApiQuotaTracker.reset_expired_quotas!
  end

  def self.platforms_near_limit(customer_id)
    ApiQuotaTracker.platforms_near_limit(customer_id)
  end

  private

  def initialize_rate_limiter
    # Use in-memory rate limiting with Redis-style key patterns
    @request_times = []
    @window_size = 1.0 # 1 second window
  end

  def current_rate_limit
    base_limit = RATE_LIMITS.dig(@platform, @endpoint) || 1
    (base_limit * @strategy[:burst_multiplier]).round
  end

  def calculate_wait_time
    now = Time.current
    window_start = now - @window_size
    
    # Clean old requests
    @request_times.reject! { |time| time < window_start }
    
    rate_limit = current_rate_limit
    
    if @request_times.length >= rate_limit
      # Need to wait until the oldest request is outside the window
      wait_time = (@request_times.first + @window_size - now) * @strategy[:delay_factor]
      [wait_time, 0].max
    else
      0
    end
  end

  def current_window_usage
    now = Time.current
    window_start = now - @window_size
    @request_times.count { |time| time >= window_start }
  end

  def record_request_success
    @request_times << Time.current
    
    Rails.logger.info "API request successful: #{@platform}/#{@endpoint} " \
                     "(quota: #{@quota_tracker.current_usage}/#{@quota_tracker.quota_limit})"
  end

  def record_request_failure(error)
    Rails.logger.warn "API request failed: #{@platform}/#{@endpoint} - #{error.message}"
  end

  def rate_limit_error?(error)
    case error
    when StandardError
      message = error.message.downcase
      message.include?('rate limit') ||
      message.include?('rate_limit') ||
      message.include?('too many requests') ||
      message.include?('quota exceeded')
    else
      false
    end
  end

  def handle_rate_limit_error(error)
    # Extract retry-after information if available
    retry_after = extract_retry_after(error)
    
    Rails.logger.warn "Rate limit hit for #{@platform}/#{@endpoint}. " \
                     "Retry after: #{retry_after} seconds"
    
    # Could implement exponential backoff here
    sleep([retry_after, 60].min) if retry_after > 0
  end

  def extract_retry_after(error)
    # Try to extract retry-after from error message or response
    message = error.message
    
    if message =~ /retry\s*after\s*(\d+)/i
      $1.to_i
    elsif message =~ /wait\s*(\d+)/i
      $1.to_i
    elsif message =~ /after\s*(\d+)/i
      $1.to_i
    else
      60 # Default wait time
    end
  end

  def optimal_batch_size
    quota_remaining = @quota_tracker.remaining_quota
    rate_limit = current_rate_limit
    
    # Don't exceed 10% of remaining quota in a single batch
    quota_based_limit = (quota_remaining * 0.1).ceil
    
    # Don't exceed 5 seconds worth of requests at current rate
    time_based_limit = (rate_limit * 5).ceil
    
    [quota_based_limit, time_based_limit, 1].max
  end

  def recommend_strategy(quota_percentage)
    case quota_percentage
    when 0...50
      :aggressive
    when 50...80
      :balanced
    else
      :conservative
    end
  end
end