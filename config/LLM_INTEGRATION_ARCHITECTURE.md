# LLM Integration Architecture for Real Provider Implementation

## Executive Summary

This document outlines the comprehensive architecture for integrating real LLM providers into the marketing content generation platform. The current system provides a solid foundation with mock services, dependency injection, circuit breakers, and multi-provider support. This architecture document details the roadmap for transitioning to production-ready real LLM integrations.

## Current Architecture Analysis

### Strengths of Existing Implementation

1. **Service Interface Abstraction** (`app/services/llm_service_interface.rb`)
   - Well-defined contract with 9 core methods
   - Consistent parameter patterns and return structures
   - Comprehensive content generation coverage (social, email, ads, landing pages, campaigns)

2. **Dependency Injection Container** (`config/initializers/llm_service.rb`)
   - Sophisticated service registration and retrieval
   - Multi-provider support with priority-based selection
   - Circuit breaker pattern implementation
   - Automatic fallback mechanisms

3. **Configuration Management**
   - Environment-variable driven configuration
   - Feature flags for controlled rollouts
   - Provider-specific settings (API keys, models, priorities)
   - Comprehensive monitoring and debugging options

4. **Mock Service Implementation**
   - Realistic response simulation
   - Brand context integration
   - Performance simulation (delays, errors)
   - Comprehensive test coverage

## Real LLM Provider Integration Architecture

### 1. Provider Abstraction Layer

#### Base Provider Class Design

```ruby
# app/services/llm_providers/base_provider.rb
class LlmProviders::BaseProvider
  include LlmServiceInterface
  
  attr_reader :config, :client, :metrics_collector
  
  def initialize(config)
    @config = config
    @client = build_client
    @metrics_collector = MetricsCollector.new(provider_name)
  end
  
  # Template method pattern for consistent request handling
  def make_request(method, params)
    start_time = Time.current
    
    with_timeout_and_retry do
      with_circuit_breaker do
        response = send("#{method}_request", params)
        record_success(start_time)
        transform_response(response, method)
      end
    end
  rescue => error
    record_failure(error, start_time)
    raise
  end
  
  private
  
  def provider_name
    self.class.name.demodulize.underscore.gsub('_provider', '')
  end
  
  def with_timeout_and_retry(&block)
    Timeout.timeout(config[:timeout]) do
      Retries.with_retries(
        max_attempts: config[:retry_attempts],
        delay: config[:retry_delay],
        on: retriable_errors,
        &block
      )
    end
  end
  
  def with_circuit_breaker(&block)
    CircuitBreaker.call(provider_name, &block)
  end
  
  def retriable_errors
    [Net::TimeoutError, Net::ReadTimeout, StandardError]
  end
end
```

#### Provider-Specific Implementations

```ruby
# app/services/llm_providers/openai_provider.rb
class LlmProviders::OpenaiProvider < LlmProviders::BaseProvider
  private
  
  def build_client
    OpenAI::Client.new(
      access_token: config[:api_key],
      uri_base: config[:endpoint] || "https://api.openai.com",
      request_timeout: config[:timeout]
    )
  end
  
  def generate_social_media_content_request(params)
    prompt = build_social_media_prompt(params)
    
    client.chat(
      parameters: {
        model: config[:model],
        messages: [{ role: "user", content: prompt }],
        max_tokens: config[:max_tokens],
        temperature: config[:temperature]
      }
    )
  end
  
  def transform_response(response, method)
    content = response.dig("choices", 0, "message", "content")
    
    case method
    when 'generate_social_media_content'
      parse_social_media_response(content)
    when 'generate_email_content'
      parse_email_response(content)
    # ... other transformations
    end
  end
end

# app/services/llm_providers/anthropic_provider.rb
class LlmProviders::AnthropicProvider < LlmProviders::BaseProvider
  private
  
  def build_client
    Anthropic::Client.new(
      api_key: config[:api_key],
      api_version: "2023-06-01"
    )
  end
  
  def generate_social_media_content_request(params)
    prompt = build_social_media_prompt(params)
    
    client.messages(
      model: config[:model],
      max_tokens: config[:max_tokens],
      temperature: config[:temperature],
      messages: [
        {
          role: "user",
          content: prompt
        }
      ]
    )
  end
end
```

### 2. Prompt Engineering Framework

#### Prompt Template System

```ruby
# app/services/llm_providers/prompt_builder.rb
class LlmProviders::PromptBuilder
  class << self
    def build_social_media_prompt(params)
      template = load_template('social_media')
      
      template
        .gsub('{{PLATFORM}}', params[:platform])
        .gsub('{{TONE}}', params[:tone])
        .gsub('{{TOPIC}}', params[:topic])
        .gsub('{{CHARACTER_LIMIT}}', params[:character_limit].to_s)
        .gsub('{{BRAND_CONTEXT}}', format_brand_context(params[:brand_context]))
    end
    
    def build_email_prompt(params)
      template = load_template('email')
      # Similar template processing...
    end
    
    private
    
    def load_template(type)
      File.read(Rails.root.join('config', 'llm_prompts', "#{type}.txt"))
    end
    
    def format_brand_context(context)
      return "" if context.blank?
      
      sections = []
      sections << "Brand Voice: #{context[:voice]}" if context[:voice]
      sections << "Brand Tone: #{context[:tone]}" if context[:tone]
      sections << "Key Messages: #{context[:keywords]&.join(', ')}" if context[:keywords]
      sections << "Style Guidelines: #{format_style(context[:style])}" if context[:style]
      
      sections.join("\n")
    end
  end
end
```

#### Prompt Templates

```text
# config/llm_prompts/social_media.txt
You are an expert marketing content creator. Generate engaging social media content for {{PLATFORM}}.

Requirements:
- Platform: {{PLATFORM}}
- Tone: {{TONE}}
- Topic: {{TOPIC}}
- Character limit: {{CHARACTER_LIMIT}}

Brand Context:
{{BRAND_CONTEXT}}

Please generate content that:
1. Stays within the character limit
2. Matches the specified tone
3. Incorporates the brand voice and guidelines
4. Is engaging and action-oriented
5. Includes relevant hashtags if appropriate

Return your response as JSON in this exact format:
{
  "content": "Your generated content here",
  "metadata": {
    "character_count": 120,
    "hashtags_used": ["#example"],
    "tone_confidence": 0.95
  }
}
```

### 3. Response Processing and Validation

#### Response Parser System

```ruby
# app/services/llm_providers/response_parser.rb
class LlmProviders::ResponseParser
  class << self
    def parse_social_media_response(raw_response)
      parsed = JSON.parse(extract_json(raw_response))
      
      validate_social_media_response!(parsed)
      
      {
        content: parsed['content'],
        metadata: build_metadata(parsed['metadata'])
      }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse LLM response: #{e.message}"
      fallback_social_media_response(raw_response)
    end
    
    private
    
    def extract_json(response)
      # Extract JSON from response that might contain markdown or explanatory text
      json_match = response.match(/\{.*\}/m)
      json_match ? json_match[0] : response
    end
    
    def validate_social_media_response!(parsed)
      raise ArgumentError, "Missing content" unless parsed['content']
      raise ArgumentError, "Content too long" if parsed['content'].length > 2000
    end
    
    def fallback_social_media_response(raw_response)
      # Create fallback response structure when JSON parsing fails
      content = raw_response.strip.split("\n").first || "Generated content"
      
      {
        content: content,
        metadata: {
          fallback_used: true,
          character_count: content.length,
          generated_at: Time.current
        }
      }
    end
  end
end
```

### 4. API Key Management and Security

#### Secure Credential Management

```ruby
# app/services/llm_providers/credential_manager.rb
class LlmProviders::CredentialManager
  class << self
    def get_api_key(provider)
      key = Rails.application.credentials.dig(:llm_providers, provider, :api_key) ||
            ENV["#{provider.upcase}_API_KEY"]
      
      validate_api_key!(key, provider)
      key
    end
    
    def rotate_api_key(provider, new_key)
      # Implement key rotation logic
      validate_api_key!(new_key, provider)
      
      # Test new key before switching
      test_api_key(provider, new_key)
      
      # Update configuration
      update_provider_key(provider, new_key)
      
      # Log rotation event
      Rails.logger.info "API key rotated for provider: #{provider}"
    end
    
    private
    
    def validate_api_key!(key, provider)
      raise ArgumentError, "API key missing for #{provider}" if key.blank?
      raise ArgumentError, "Invalid API key format for #{provider}" unless valid_format?(key, provider)
    end
    
    def valid_format?(key, provider)
      patterns = {
        openai: /^sk-[a-zA-Z0-9]{48}$/,
        anthropic: /^sk-ant-[a-zA-Z0-9\-_]{95}$/,
        google: /^[A-Za-z0-9\-_]{39}$/
      }
      
      pattern = patterns[provider.to_sym]
      pattern ? key.match?(pattern) : true
    end
    
    def test_api_key(provider, key)
      # Implement API key testing logic
      test_provider = build_test_provider(provider, key)
      test_provider.health_check
    end
  end
end
```

### 5. Rate Limiting and Cost Management

#### Rate Limiting Architecture

```ruby
# app/services/llm_providers/rate_limiter.rb
class LlmProviders::RateLimiter
  def initialize(provider, config)
    @provider = provider
    @config = config
    @redis = Redis.current
  end
  
  def check_and_consume(endpoint, tokens_requested = 1)
    key = rate_limit_key(endpoint)
    
    current_usage = @redis.get(key).to_i
    limit = get_rate_limit(endpoint)
    window = get_time_window(endpoint)
    
    if current_usage + tokens_requested > limit
      wait_time = calculate_wait_time(key, window)
      raise RateLimitExceededError, "Rate limit exceeded. Wait #{wait_time} seconds"
    end
    
    @redis.multi do |pipeline|
      pipeline.incr(key, tokens_requested)
      pipeline.expire(key, window) unless @redis.ttl(key) > 0
    end
  end
  
  private
  
  def rate_limit_key(endpoint)
    "rate_limit:#{@provider}:#{endpoint}:#{Time.current.to_i / get_time_window(endpoint)}"
  end
  
  def get_rate_limit(endpoint)
    @config.dig(:rate_limits, endpoint, :requests_per_minute) || 60
  end
  
  def get_time_window(endpoint)
    60 # 1 minute window
  end
end

# app/services/llm_providers/cost_tracker.rb
class LlmProviders::CostTracker
  def initialize(provider)
    @provider = provider
    @pricing = load_pricing_config(provider)
  end
  
  def calculate_cost(request_type, input_tokens, output_tokens)
    input_cost = input_tokens * @pricing[:input_token_cost]
    output_cost = output_tokens * @pricing[:output_token_cost]
    
    total_cost = input_cost + output_cost
    
    record_usage(request_type, input_tokens, output_tokens, total_cost)
    
    total_cost
  end
  
  def get_daily_spend
    # Calculate daily spending across all endpoints
    Redis.current.get("cost_tracker:#{@provider}:#{Date.current}").to_f
  end
  
  def check_budget_limits
    daily_spend = get_daily_spend
    daily_limit = Rails.application.config.llm_daily_budget_limit
    
    if daily_spend >= daily_limit
      raise BudgetExceededError, "Daily budget limit exceeded: $#{daily_spend}"
    end
  end
  
  private
  
  def load_pricing_config(provider)
    Rails.application.config.llm_pricing.dig(provider) || {
      input_token_cost: 0.0001,
      output_token_cost: 0.0002
    }
  end
  
  def record_usage(request_type, input_tokens, output_tokens, cost)
    data = {
      timestamp: Time.current,
      request_type: request_type,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost: cost
    }
    
    # Store in time-series database or Redis
    key = "usage:#{@provider}:#{Date.current}"
    Redis.current.lpush(key, data.to_json)
    Redis.current.expire(key, 30.days.to_i)
  end
end
```

### 6. Circuit Breaker Enhancement

#### Advanced Circuit Breaker Pattern

```ruby
# app/services/llm_providers/circuit_breaker.rb
class LlmProviders::CircuitBreaker
  class << self
    def call(provider_name, &block)
      state = get_state(provider_name)
      
      case state[:status]
      when :closed
        execute_with_monitoring(provider_name, &block)
      when :open
        if should_attempt_reset?(state)
          transition_to_half_open(provider_name)
          execute_with_monitoring(provider_name, &block)
        else
          raise CircuitOpenError, "Circuit breaker open for #{provider_name}"
        end
      when :half_open
        execute_half_open(provider_name, &block)
      end
    end
    
    private
    
    def execute_with_monitoring(provider_name, &block)
      result = yield
      record_success(provider_name)
      result
    rescue => error
      record_failure(provider_name, error)
      check_failure_threshold(provider_name)
      raise
    end
    
    def execute_half_open(provider_name, &block)
      result = yield
      transition_to_closed(provider_name)
      result
    rescue => error
      transition_to_open(provider_name)
      raise
    end
    
    def get_state(provider_name)
      key = "circuit_breaker:#{provider_name}"
      state = Redis.current.hgetall(key)
      
      return default_state if state.empty?
      
      {
        status: state['status'].to_sym,
        failure_count: state['failure_count'].to_i,
        last_failure_time: Time.parse(state['last_failure_time']),
        success_count: state['success_count'].to_i
      }
    end
    
    def record_failure(provider_name, error)
      key = "circuit_breaker:#{provider_name}"
      
      Redis.current.multi do |pipeline|
        pipeline.hincrby(key, 'failure_count', 1)
        pipeline.hset(key, 'last_failure_time', Time.current.iso8601)
        pipeline.hset(key, 'last_error', error.message)
        pipeline.expire(key, 1.hour.to_i)
      end
      
      Rails.logger.error "Circuit breaker recorded failure for #{provider_name}: #{error.message}"
    end
    
    def check_failure_threshold(provider_name)
      state = get_state(provider_name)
      threshold = Rails.application.config.llm_circuit_breaker_threshold
      
      if state[:failure_count] >= threshold
        transition_to_open(provider_name)
      end
    end
    
    def transition_to_open(provider_name)
      key = "circuit_breaker:#{provider_name}"
      
      Redis.current.multi do |pipeline|
        pipeline.hset(key, 'status', 'open')
        pipeline.hset(key, 'opened_at', Time.current.iso8601)
      end
      
      Rails.logger.warn "Circuit breaker opened for #{provider_name}"
      
      # Notify monitoring systems
      notify_circuit_breaker_opened(provider_name)
    end
  end
end
```

### 7. Monitoring and Observability

#### Metrics Collection

```ruby
# app/services/llm_providers/metrics_collector.rb
class LlmProviders::MetricsCollector
  def initialize(provider_name)
    @provider_name = provider_name
    @statsd = Statsd.new if defined?(Statsd)
  end
  
  def record_request(method, duration, tokens_used, cost)
    metrics = {
      "llm.request.duration" => duration,
      "llm.request.tokens" => tokens_used,
      "llm.request.cost" => cost
    }
    
    tags = {
      provider: @provider_name,
      method: method,
      environment: Rails.env
    }
    
    metrics.each do |metric, value|
      @statsd&.gauge(metric, value, tags: tags)
    end
    
    # Also store in application logs
    Rails.logger.info "LLM Request", {
      provider: @provider_name,
      method: method,
      duration_ms: (duration * 1000).round(2),
      tokens_used: tokens_used,
      cost_usd: cost.round(4)
    }
  end
  
  def record_error(method, error_type, error_message)
    @statsd&.increment("llm.request.error", tags: {
      provider: @provider_name,
      method: method,
      error_type: error_type,
      environment: Rails.env
    })
    
    Rails.logger.error "LLM Request Error", {
      provider: @provider_name,
      method: method,
      error_type: error_type,
      error_message: error_message
    }
  end
  
  def record_circuit_breaker_event(event_type)
    @statsd&.increment("llm.circuit_breaker.#{event_type}", tags: {
      provider: @provider_name,
      environment: Rails.env
    })
  end
end
```

## Migration Strategy from Mock to Real Services

### Phase 1: Foundation (Weeks 1-2)

1. **Provider Implementation**
   - Implement OpenAI provider class
   - Implement Anthropic provider class
   - Add comprehensive error handling

2. **Testing Infrastructure**
   - Create integration tests for real providers
   - Add VCR cassettes for API response recording
   - Implement provider health checks

### Phase 2: Core Features (Weeks 3-4)

1. **Prompt Engineering**
   - Develop and test prompt templates
   - Implement response parsing
   - Add content validation

2. **Configuration Enhancement**
   - Add provider-specific configurations
   - Implement credential rotation
   - Add cost tracking

### Phase 3: Production Readiness (Weeks 5-6)

1. **Monitoring and Observability**
   - Implement comprehensive metrics
   - Add alerting for failures
   - Create dashboards

2. **Performance Optimization**
   - Implement caching strategies
   - Add request queuing
   - Optimize timeout handling

### Phase 4: Rollout (Weeks 7-8)

1. **Gradual Migration**
   - Feature flag-controlled rollout
   - A/B testing between mock and real
   - Performance comparison

2. **Production Deployment**
   - Blue-green deployment strategy
   - Monitoring and alerting setup
   - Documentation updates

## Implementation Priority

### High Priority (Must Have)
1. OpenAI provider implementation
2. Prompt template system
3. Response parsing and validation
4. Basic error handling and retries
5. Configuration management

### Medium Priority (Should Have)
1. Anthropic provider implementation
2. Advanced circuit breaker
3. Cost tracking and budget limits
4. Comprehensive monitoring
5. API key rotation

### Low Priority (Nice to Have)
1. Additional providers (Google, Azure)
2. Advanced caching strategies
3. Request queuing system
4. Machine learning for prompt optimization
5. Advanced analytics and insights

## Testing Strategy

### Unit Tests
- Provider implementations
- Prompt builders
- Response parsers
- Circuit breaker logic

### Integration Tests
- End-to-end API calls
- Provider failover scenarios
- Configuration validation
- Performance benchmarks

### Load Tests
- Rate limiting validation
- Concurrent request handling
- Memory usage monitoring
- Cost calculation accuracy

## Security Considerations

1. **API Key Security**
   - Use Rails credentials or secure vault
   - Implement key rotation
   - Monitor for key exposure

2. **Input Validation**
   - Sanitize user inputs
   - Validate content parameters
   - Prevent prompt injection

3. **Output Filtering**
   - Content moderation
   - PII detection and removal
   - Brand compliance checking

4. **Audit Logging**
   - Request/response logging
   - User action tracking
   - Security event monitoring

## Performance Optimization

1. **Caching Strategies**
   - Response caching for repeated requests
   - Template caching
   - Configuration caching

2. **Request Optimization**
   - Batch processing where possible
   - Async processing for non-critical requests
   - Connection pooling

3. **Resource Management**
   - Memory usage monitoring
   - Connection limits
   - Garbage collection optimization

## Conclusion

This architecture provides a comprehensive foundation for transitioning from mock LLM services to production-ready real provider integrations. The design emphasizes reliability, observability, and cost control while maintaining the flexibility to support multiple providers and use cases.

The phased migration approach ensures minimal risk while providing measurable progress toward full real LLM integration. Regular monitoring and testing throughout the implementation will ensure the system meets performance and reliability requirements in production.