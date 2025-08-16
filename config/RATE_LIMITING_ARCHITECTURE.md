# Rate Limiting Architecture for LLM Services

## Overview

This document outlines the comprehensive rate limiting architecture for managing LLM provider API calls, token usage, and cost control. The system implements multiple layers of rate limiting to ensure compliance with provider limits, cost control, and fair usage across the application.

## Rate Limiting Layers

### 1. Provider API Rate Limits
Each LLM provider has specific rate limits that must be respected:

**OpenAI Limits (GPT-4)**
- 500 requests per minute (RPM)
- 80,000 tokens per minute (TPM)
- 200 requests per day (daily limit for free tier)

**Anthropic Limits (Claude)**
- 1,000 requests per minute (RPM)
- 50,000 tokens per minute (TPM)
- Usage-based billing limits

**Google AI Limits (Gemini)**
- 60 requests per minute (RPM)
- 32,000 tokens per minute (TPM)
- Regional variations

### 2. Application-Level Rate Limiting
- Per-user limits
- Per-organization limits
- Feature-specific limits
- Global application limits

### 3. Cost-Based Rate Limiting
- Daily/monthly spending limits
- Per-request cost thresholds
- Budget allocation across features
- User tier-based limits

## Architecture Components

### 1. Rate Limiter Framework

```ruby
# app/services/rate_limiting/rate_limiter.rb
module RateLimiting
  class RateLimiter
    include Redis::Objects
    
    def initialize(identifier, config = {})
      @identifier = identifier
      @config = default_config.merge(config)
      @redis = Redis.current
    end
    
    def check_and_consume(resource_type, amount = 1)
      key = build_key(resource_type)
      window = @config[:window]
      limit = @config[:limits][resource_type]
      
      current_usage = get_current_usage(key, window)
      
      if current_usage + amount > limit
        handle_rate_limit_exceeded(resource_type, current_usage, limit, amount)
      else
        consume_resource(key, amount, window)
        track_usage(resource_type, amount)
        { allowed: true, remaining: limit - current_usage - amount }
      end
    end
    
    def get_remaining(resource_type)
      key = build_key(resource_type)
      window = @config[:window]
      limit = @config[:limits][resource_type]
      current_usage = get_current_usage(key, window)
      
      [limit - current_usage, 0].max
    end
    
    def reset_limits(resource_type = nil)
      if resource_type
        key = build_key(resource_type)
        @redis.del(key)
      else
        pattern = "#{@identifier}:*"
        keys = @redis.keys(pattern)
        @redis.del(*keys) if keys.any?
      end
    end
    
    private
    
    def default_config
      {
        window: 60, # 1 minute window
        limits: {
          requests: 100,
          tokens: 10000,
          cost: 1.00 # $1.00
        }
      }
    end
    
    def build_key(resource_type)
      window_start = (Time.current.to_i / @config[:window]) * @config[:window]
      "rate_limit:#{@identifier}:#{resource_type}:#{window_start}"
    end
    
    def get_current_usage(key, window)
      @redis.get(key).to_i
    end
    
    def consume_resource(key, amount, window)
      @redis.multi do |pipeline|
        pipeline.incrby(key, amount)
        pipeline.expire(key, window * 2) # Keep data for 2 windows for analytics
      end
    end
    
    def handle_rate_limit_exceeded(resource_type, current_usage, limit, requested)
      error = RateLimitExceededError.new(
        identifier: @identifier,
        resource_type: resource_type,
        current_usage: current_usage,
        limit: limit,
        requested: requested,
        reset_time: calculate_reset_time
      )
      
      log_rate_limit_violation(error)
      raise error
    end
    
    def calculate_reset_time
      window = @config[:window]
      current_window_start = (Time.current.to_i / window) * window
      Time.at(current_window_start + window)
    end
    
    def track_usage(resource_type, amount)
      UsageTracker.record(@identifier, resource_type, amount)
    end
    
    def log_rate_limit_violation(error)
      Rails.logger.warn "Rate limit exceeded", {
        identifier: error.identifier,
        resource_type: error.resource_type,
        current_usage: error.current_usage,
        limit: error.limit,
        requested: error.requested
      }
    end
  end
end

# app/services/rate_limiting/rate_limit_exceeded_error.rb
class RateLimitExceededError < StandardError
  attr_reader :identifier, :resource_type, :current_usage, :limit, :requested, :reset_time
  
  def initialize(identifier:, resource_type:, current_usage:, limit:, requested:, reset_time:)
    @identifier = identifier
    @resource_type = resource_type
    @current_usage = current_usage
    @limit = limit
    @requested = requested
    @reset_time = reset_time
    
    super("Rate limit exceeded for #{identifier}: #{resource_type} (#{current_usage + requested}/#{limit})")
  end
  
  def retry_after
    [@reset_time - Time.current, 0].max.ceil
  end
end
```

### 2. Provider-Specific Rate Limiters

```ruby
# app/services/rate_limiting/provider_rate_limiter.rb
module RateLimiting
  class ProviderRateLimiter < RateLimiter
    def initialize(provider, config = {})
      provider_config = load_provider_config(provider)
      super("provider:#{provider}", provider_config.merge(config))
      @provider = provider
    end
    
    def check_request_limit(tokens_requested = 0)
      # Check both request and token limits
      request_result = check_and_consume(:requests, 1)
      
      if tokens_requested > 0
        token_result = check_and_consume(:tokens, tokens_requested)
        return combine_results(request_result, token_result)
      end
      
      request_result
    end
    
    private
    
    def load_provider_config(provider)
      configs = {
        openai: {
          window: 60, # 1 minute
          limits: {
            requests: 500,
            tokens: 80000,
            cost: 10.00
          }
        },
        anthropic: {
          window: 60,
          limits: {
            requests: 1000,
            tokens: 50000,
            cost: 15.00
          }
        },
        google: {
          window: 60,
          limits: {
            requests: 60,
            tokens: 32000,
            cost: 5.00
          }
        }
      }
      
      configs[provider.to_sym] || configs[:openai]
    end
    
    def combine_results(request_result, token_result)
      {
        allowed: request_result[:allowed] && token_result[:allowed],
        remaining_requests: request_result[:remaining],
        remaining_tokens: token_result[:remaining]
      }
    end
  end
end
```

### 3. User and Organization Rate Limiting

```ruby
# app/services/rate_limiting/user_rate_limiter.rb
module RateLimiting
  class UserRateLimiter < RateLimiter
    def initialize(user, config = {})
      user_config = load_user_config(user)
      super("user:#{user.id}", user_config.merge(config))
      @user = user
    end
    
    def check_feature_limit(feature, tokens_requested = 0)
      feature_key = "#{feature}_requests"
      feature_token_key = "#{feature}_tokens"
      
      # Check feature-specific limits
      feature_result = check_and_consume(feature_key.to_sym, 1)
      
      if tokens_requested > 0
        token_result = check_and_consume(feature_token_key.to_sym, tokens_requested)
        return combine_feature_results(feature_result, token_result, feature)
      end
      
      feature_result.merge(feature: feature)
    end
    
    private
    
    def load_user_config(user)
      # Load configuration based on user tier/subscription
      base_config = {
        window: 3600, # 1 hour window for users
        limits: {
          requests: 100,
          tokens: 50000,
          cost: 5.00,
          # Feature-specific limits
          social_media_requests: 50,
          social_media_tokens: 20000,
          email_requests: 30,
          email_tokens: 25000,
          ad_copy_requests: 25,
          ad_copy_tokens: 15000,
          landing_page_requests: 10,
          landing_page_tokens: 30000,
          campaign_plan_requests: 5,
          campaign_plan_tokens: 40000
        }
      }
      
      # Adjust limits based on user tier
      tier_multipliers = {
        'free' => 1.0,
        'pro' => 3.0,
        'enterprise' => 10.0
      }
      
      multiplier = tier_multipliers[user.tier] || 1.0
      
      if multiplier != 1.0
        base_config[:limits].transform_values! { |limit| (limit * multiplier).to_i }
      end
      
      base_config
    end
    
    def combine_feature_results(feature_result, token_result, feature)
      {
        allowed: feature_result[:allowed] && token_result[:allowed],
        feature: feature,
        remaining_requests: feature_result[:remaining],
        remaining_tokens: token_result[:remaining]
      }
    end
  end
end

# app/services/rate_limiting/organization_rate_limiter.rb
module RateLimiting
  class OrganizationRateLimiter < RateLimiter
    def initialize(organization, config = {})
      org_config = load_organization_config(organization)
      super("org:#{organization.id}", org_config.merge(config))
      @organization = organization
    end
    
    private
    
    def load_organization_config(organization)
      {
        window: 3600, # 1 hour
        limits: {
          requests: organization.request_limit || 1000,
          tokens: organization.token_limit || 500000,
          cost: organization.cost_limit || 50.00
        }
      }
    end
  end
end
```

### 4. Cost-Based Rate Limiting

```ruby
# app/services/rate_limiting/cost_rate_limiter.rb
module RateLimiting
  class CostRateLimiter
    def initialize(identifier, budget_config = {})
      @identifier = identifier
      @budget_config = default_budget_config.merge(budget_config)
      @redis = Redis.current
    end
    
    def check_cost_limit(estimated_cost)
      daily_key = build_cost_key(:daily)
      monthly_key = build_cost_key(:monthly)
      
      daily_spent = get_current_cost(daily_key)
      monthly_spent = get_current_cost(monthly_key)
      
      daily_limit = @budget_config[:daily_limit]
      monthly_limit = @budget_config[:monthly_limit]
      
      if daily_spent + estimated_cost > daily_limit
        raise CostLimitExceededError.new(
          identifier: @identifier,
          period: :daily,
          current_cost: daily_spent,
          limit: daily_limit,
          requested_cost: estimated_cost
        )
      end
      
      if monthly_spent + estimated_cost > monthly_limit
        raise CostLimitExceededError.new(
          identifier: @identifier,
          period: :monthly,
          current_cost: monthly_spent,
          limit: monthly_limit,
          requested_cost: estimated_cost
        )
      end
      
      {
        allowed: true,
        daily_remaining: daily_limit - daily_spent,
        monthly_remaining: monthly_limit - monthly_spent
      }
    end
    
    def record_cost(actual_cost)
      daily_key = build_cost_key(:daily)
      monthly_key = build_cost_key(:monthly)
      
      @redis.multi do |pipeline|
        pipeline.incrbyfloat(daily_key, actual_cost)
        pipeline.expire(daily_key, 86400) # 24 hours
        
        pipeline.incrbyfloat(monthly_key, actual_cost)
        pipeline.expire(monthly_key, 2592000) # 30 days
      end
      
      # Record detailed cost tracking
      CostTracker.record(@identifier, actual_cost, Time.current)
    end
    
    private
    
    def default_budget_config
      {
        daily_limit: 10.00,   # $10 per day
        monthly_limit: 200.00 # $200 per month
      }
    end
    
    def build_cost_key(period)
      case period
      when :daily
        date = Date.current.strftime('%Y-%m-%d')
        "cost_limit:#{@identifier}:daily:#{date}"
      when :monthly
        month = Date.current.strftime('%Y-%m')
        "cost_limit:#{@identifier}:monthly:#{month}"
      end
    end
    
    def get_current_cost(key)
      @redis.get(key).to_f
    end
  end
end

# app/services/rate_limiting/cost_limit_exceeded_error.rb
class CostLimitExceededError < StandardError
  attr_reader :identifier, :period, :current_cost, :limit, :requested_cost
  
  def initialize(identifier:, period:, current_cost:, limit:, requested_cost:)
    @identifier = identifier
    @period = period
    @current_cost = current_cost
    @limit = limit
    @requested_cost = requested_cost
    
    super("Cost limit exceeded for #{identifier}: #{period} (#{current_cost + requested_cost}/#{limit})")
  end
end
```

### 5. Adaptive Rate Limiting

```ruby
# app/services/rate_limiting/adaptive_rate_limiter.rb
module RateLimiting
  class AdaptiveRateLimiter < RateLimiter
    def initialize(identifier, config = {})
      super(identifier, config)
      @performance_tracker = PerformanceTracker.new(identifier)
    end
    
    def check_and_consume_adaptive(resource_type, amount = 1)
      # Adjust limits based on current system performance
      adjusted_config = calculate_adaptive_limits(resource_type)
      
      # Temporarily update config
      original_limits = @config[:limits].dup
      @config[:limits].merge!(adjusted_config)
      
      begin
        result = check_and_consume(resource_type, amount)
        
        # Record successful operation
        @performance_tracker.record_success(resource_type, amount)
        
        result
      rescue RateLimitExceededError => e
        # Record rate limit hit for adaptive learning
        @performance_tracker.record_rate_limit(resource_type, amount)
        raise e
      ensure
        # Restore original limits
        @config[:limits] = original_limits
      end
    end
    
    private
    
    def calculate_adaptive_limits(resource_type)
      current_load = SystemLoadMonitor.current_load
      error_rate = @performance_tracker.recent_error_rate(resource_type)
      
      # Base adjustment factors
      load_factor = calculate_load_factor(current_load)
      error_factor = calculate_error_factor(error_rate)
      
      # Calculate adjusted limit
      base_limit = @config[:limits][resource_type]
      adjusted_limit = (base_limit * load_factor * error_factor).to_i
      
      # Ensure minimum and maximum bounds
      min_limit = base_limit * 0.1 # Never go below 10% of base
      max_limit = base_limit * 2.0 # Never go above 200% of base
      
      adjusted_limit = [[adjusted_limit, min_limit].max, max_limit].min
      
      { resource_type => adjusted_limit }
    end
    
    def calculate_load_factor(load)
      case load
      when 0..0.3 then 1.5   # Low load - increase limits
      when 0.3..0.7 then 1.0 # Normal load - keep limits
      when 0.7..0.9 then 0.7 # High load - reduce limits
      else 0.3               # Critical load - severely reduce
      end
    end
    
    def calculate_error_factor(error_rate)
      case error_rate
      when 0..0.01 then 1.2   # Very low errors - slight increase
      when 0.01..0.05 then 1.0 # Normal errors - keep limits
      when 0.05..0.1 then 0.8  # High errors - reduce limits
      else 0.5                 # Very high errors - significant reduction
      end
    end
  end
end
```

### 6. Rate Limiting Middleware

```ruby
# app/middleware/llm_rate_limiting_middleware.rb
class LlmRateLimitingMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Only apply to LLM-related endpoints
    return @app.call(env) unless llm_endpoint?(request)
    
    begin
      check_rate_limits(request)
      
      # Process request and track actual usage
      status, headers, response = @app.call(env)
      
      # Extract actual token usage from response if available
      track_actual_usage(request, headers)
      
      [status, headers, response]
      
    rescue RateLimitExceededError => e
      handle_rate_limit_error(e)
    rescue CostLimitExceededError => e
      handle_cost_limit_error(e)
    end
  end
  
  private
  
  def llm_endpoint?(request)
    request.path.start_with?('/api/v1/content_generation') ||
    request.path.start_with?('/api/v1/llm')
  end
  
  def check_rate_limits(request)
    user = extract_user(request)
    organization = user&.organization
    
    # Estimate token usage based on request parameters
    estimated_tokens = estimate_token_usage(request)
    estimated_cost = estimate_cost(request, estimated_tokens)
    
    # Check multiple rate limiting layers
    check_user_limits(user, request, estimated_tokens) if user
    check_organization_limits(organization, estimated_tokens) if organization
    check_provider_limits(request, estimated_tokens)
    check_cost_limits(user || request.ip, estimated_cost)
  end
  
  def check_user_limits(user, request, estimated_tokens)
    limiter = RateLimiting::UserRateLimiter.new(user)
    feature = extract_feature(request)
    
    result = limiter.check_feature_limit(feature, estimated_tokens)
    
    unless result[:allowed]
      raise RateLimitExceededError.new(
        identifier: "user:#{user.id}",
        resource_type: feature,
        current_usage: 0, # Will be calculated in the error handler
        limit: 0,
        requested: 1,
        reset_time: 1.hour.from_now
      )
    end
  end
  
  def check_provider_limits(request, estimated_tokens)
    provider = extract_provider(request)
    limiter = RateLimiting::ProviderRateLimiter.new(provider)
    
    result = limiter.check_request_limit(estimated_tokens)
    
    unless result[:allowed]
      raise RateLimitExceededError.new(
        identifier: "provider:#{provider}",
        resource_type: :requests,
        current_usage: 0,
        limit: 0,
        requested: 1,
        reset_time: 1.minute.from_now
      )
    end
  end
  
  def estimate_token_usage(request)
    # Estimate based on request parameters
    params = request.request_parameters
    
    # Base token estimate
    base_tokens = 100
    
    # Add tokens for content length
    content_length = params.values.join(' ').length
    content_tokens = (content_length / 4).to_i # Rough estimate: 4 chars per token
    
    # Add tokens for complexity
    complexity_multiplier = case extract_feature(request)
    when 'social_media' then 1.0
    when 'email' then 1.5
    when 'ad_copy' then 1.2
    when 'landing_page' then 2.0
    when 'campaign_plan' then 3.0
    else 1.0
    end
    
    (base_tokens + content_tokens) * complexity_multiplier
  end
  
  def estimate_cost(request, estimated_tokens)
    provider = extract_provider(request)
    
    # Provider-specific pricing (per 1000 tokens)
    pricing = {
      'openai' => 0.03,
      'anthropic' => 0.015,
      'google' => 0.01
    }
    
    price_per_1k_tokens = pricing[provider] || 0.02
    (estimated_tokens / 1000.0) * price_per_1k_tokens
  end
  
  def handle_rate_limit_error(error)
    [
      429,
      {
        'Content-Type' => 'application/json',
        'X-RateLimit-Limit' => error.limit.to_s,
        'X-RateLimit-Remaining' => '0',
        'X-RateLimit-Reset' => error.reset_time.to_i.to_s,
        'Retry-After' => error.retry_after.to_s
      },
      [
        {
          error: 'Rate limit exceeded',
          message: error.message,
          retry_after: error.retry_after
        }.to_json
      ]
    ]
  end
  
  def handle_cost_limit_error(error)
    [
      402,
      { 'Content-Type' => 'application/json' },
      [
        {
          error: 'Cost limit exceeded',
          message: error.message,
          current_cost: error.current_cost,
          limit: error.limit
        }.to_json
      ]
    ]
  end
end
```

### 7. Usage Analytics and Monitoring

```ruby
# app/services/rate_limiting/usage_analytics.rb
module RateLimiting
  class UsageAnalytics
    def self.generate_report(identifier, period = :daily)
      case period
      when :daily
        generate_daily_report(identifier)
      when :weekly
        generate_weekly_report(identifier)
      when :monthly
        generate_monthly_report(identifier)
      end
    end
    
    def self.get_top_users(limit = 10, period = :daily)
      # Get users with highest usage in the specified period
      redis = Redis.current
      
      pattern = case period
      when :daily
        date = Date.current.strftime('%Y-%m-%d')
        "usage:user:*:#{date}"
      when :weekly
        # Implementation for weekly
      when :monthly
        # Implementation for monthly
      end
      
      usage_data = {}
      redis.scan_each(match: pattern) do |key|
        user_id = extract_user_id_from_key(key)
        usage = redis.hgetall(key)
        usage_data[user_id] = calculate_total_usage(usage)
      end
      
      usage_data.sort_by { |_, usage| -usage }.first(limit)
    end
    
    def self.predict_limit_breach(identifier, resource_type)
      # Use recent usage patterns to predict when limits might be breached
      recent_usage = get_recent_usage_pattern(identifier, resource_type)
      current_usage = get_current_usage(identifier, resource_type)
      limit = get_limit(identifier, resource_type)
      
      if recent_usage.any?
        avg_usage_rate = recent_usage.sum / recent_usage.length
        remaining_capacity = limit - current_usage
        
        if avg_usage_rate > 0
          predicted_breach_time = remaining_capacity / avg_usage_rate
          {
            will_breach: predicted_breach_time < 3600, # Within 1 hour
            predicted_breach_time: Time.current + predicted_breach_time.seconds,
            confidence: calculate_prediction_confidence(recent_usage)
          }
        else
          { will_breach: false }
        end
      else
        { will_breach: false, reason: 'insufficient_data' }
      end
    end
    
    private
    
    def self.generate_daily_report(identifier)
      date = Date.current
      
      {
        identifier: identifier,
        date: date,
        requests: get_usage_count(identifier, :requests, date),
        tokens: get_usage_count(identifier, :tokens, date),
        cost: get_usage_cost(identifier, date),
        rate_limit_hits: get_rate_limit_hits(identifier, date),
        top_features: get_top_features(identifier, date)
      }
    end
    
    def self.get_recent_usage_pattern(identifier, resource_type, hours = 24)
      # Get hourly usage for the last N hours
      redis = Redis.current
      pattern = []
      
      hours.times do |i|
        hour_start = (Time.current - i.hours).beginning_of_hour
        key = "usage_pattern:#{identifier}:#{resource_type}:#{hour_start.to_i}"
        usage = redis.get(key).to_i
        pattern << usage
      end
      
      pattern.reverse
    end
  end
end
```

## Implementation Strategy

### Phase 1: Core Rate Limiting (Week 1)
1. Implement basic RateLimiter class
2. Create provider-specific rate limiters
3. Add rate limiting middleware
4. Basic error handling

### Phase 2: User and Cost Limits (Week 2)
1. Implement user rate limiting
2. Add organization rate limiting
3. Create cost-based rate limiting
4. Integration with billing system

### Phase 3: Advanced Features (Week 3)
1. Implement adaptive rate limiting
2. Add usage analytics
3. Create monitoring dashboard
4. Predictive breach detection

### Phase 4: Optimization (Week 4)
1. Performance optimization
2. Advanced caching strategies
3. Load balancing integration
4. Comprehensive testing

## Configuration

### Environment Variables

```bash
# Global rate limiting
RATE_LIMITING_ENABLED=true
RATE_LIMITING_REDIS_URL=redis://localhost:6379/2

# Provider-specific limits
OPENAI_RPM_LIMIT=500
OPENAI_TPM_LIMIT=80000
ANTHROPIC_RPM_LIMIT=1000
ANTHROPIC_TPM_LIMIT=50000

# Cost limits
DEFAULT_DAILY_COST_LIMIT=10.00
DEFAULT_MONTHLY_COST_LIMIT=200.00

# User tier multipliers
FREE_TIER_MULTIPLIER=1.0
PRO_TIER_MULTIPLIER=3.0
ENTERPRISE_TIER_MULTIPLIER=10.0

# Adaptive limiting
ADAPTIVE_RATE_LIMITING_ENABLED=true
SYSTEM_LOAD_THRESHOLD=0.8
```

### Database Configuration

```ruby
# Migration for rate limiting data
class CreateRateLimitingTables < ActiveRecord::Migration[7.1]
  def change
    create_table :usage_records do |t|
      t.string :identifier, null: false
      t.string :resource_type, null: false
      t.integer :amount, null: false
      t.decimal :cost, precision: 10, scale: 4
      t.datetime :recorded_at, null: false
      t.json :metadata
      
      t.index [:identifier, :recorded_at]
      t.index [:resource_type, :recorded_at]
    end
    
    create_table :rate_limit_violations do |t|
      t.string :identifier, null: false
      t.string :resource_type, null: false
      t.integer :attempted_amount
      t.integer :current_usage
      t.integer :limit_value
      t.datetime :occurred_at, null: false
      t.json :context
      
      t.index [:identifier, :occurred_at]
    end
  end
end
```

This comprehensive rate limiting architecture provides robust control over LLM API usage while ensuring compliance with provider limits and cost management requirements.