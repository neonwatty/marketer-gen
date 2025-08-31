# AI Implementation Guide

Technical guide for understanding and maintaining the AI integration within the marketing platform.

---

## 🏗️ **Architecture Overview**

### **AI Service Architecture**
```
User Request
    ↓
Rails Controller
    ↓
LlmServiceContainer (Dependency Injection)
    ↓
Provider Selection (OpenAI/Anthropic/Mock)
    ↓
Brand Context Application
    ↓
Content Generation
    ↓
Response Processing
    ↓
User Interface
```

### **Core Components**

#### **1. Service Container** (`config/initializers/llm_service.rb`)
```ruby
# Manages LLM provider registration and selection
LlmServiceContainer.register(:openai, LlmProviders::OpenaiProvider)
LlmServiceContainer.register(:anthropic, LlmProviders::AnthropicProvider)
LlmServiceContainer.register(:mock, LlmProviders::MockProvider)
```

#### **2. Base Provider** (`app/services/llm_providers/base_provider.rb`)
- Circuit breaker pattern for API resilience
- Retry logic with exponential backoff
- Request/response logging
- Error handling and fallback mechanisms

#### **3. OpenAI Provider** (`app/services/llm_providers/openai_provider.rb`)
- Full OpenAI API integration
- Content generation for all types
- Brand context application
- Response parsing and validation

---

## 🔧 **Configuration and Setup**

### **Environment Variables** (`.env`)
```bash
# API Keys
OPENAI_API_KEY=sk-your-openai-key-here
ANTHROPIC_API_KEY=your-anthropic-key-here

# Feature Flags
LLM_ENABLED=true
USE_REAL_LLM=true
DEFAULT_LLM_PROVIDER=openai

# Circuit Breaker Settings
LLM_CIRCUIT_BREAKER_THRESHOLD=5
LLM_CIRCUIT_BREAKER_TIMEOUT=60

# Request Settings
LLM_REQUEST_TIMEOUT=30
LLM_MAX_RETRIES=3
```

### **Gemfile Dependencies**
```ruby
# LLM Integration
gem 'ruby-openai', '~> 7.0'
gem 'anthropic', '~> 0.1.0'
gem 'dotenv-rails', groups: [:development, :test]

# Circuit Breaker
gem 'circuit_breaker', '~> 1.1'

# HTTP Client
gem 'faraday', '~> 2.0'
gem 'faraday-retry', '~> 2.0'
```

### **Service Registration**
```ruby
# config/initializers/llm_service.rb
Rails.application.config.after_initialize do
  # Register providers
  LlmServiceContainer.register(:openai, LlmProviders::OpenaiProvider)
  LlmServiceContainer.register(:mock, LlmProviders::MockProvider)
  
  # Set default provider
  LlmServiceContainer.default_provider = Rails.env.production? ? :openai : :mock
end
```

---

## 🎯 **Implementation Details**

### **1. Content Generation Flow**

#### **Controller Integration**
```ruby
# app/controllers/generated_contents_controller.rb
def create
  @generated_content = @campaign_plan.generated_contents.build(generated_content_params)
  
  if @generated_content.save
    # Trigger AI content generation
    GenerateContentJob.perform_async(@generated_content.id)
    redirect_to success_path
  else
    render :new, status: :unprocessable_entity
  end
end
```

#### **Service Layer**
```ruby
# app/services/content_generation_service.rb
class ContentGenerationService < ApplicationService
  def initialize(generated_content)
    @content = generated_content
    @llm_service = LlmServiceContainer.get_service
  end

  def call
    response = @llm_service.generate_social_media_content(
      campaign_context: @content.campaign_plan&.to_context,
      content_type: @content.content_type,
      brand_context: current_brand_context
    )
    
    @content.update!(body_content: response[:content])
  end
end
```

### **2. Brand Context Integration**

#### **Brand Context Builder**
```ruby
# app/services/brand_context_service.rb
class BrandContextService
  def self.build_context(user_or_brand_identity)
    brand = extract_brand_identity(user_or_brand_identity)
    
    {
      voice_tone: brand&.voice_tone || 'professional',
      key_messages: brand&.key_messages || [],
      style_guidelines: brand&.style_guidelines || {},
      industry_context: brand&.industry || 'general',
      target_audience: brand&.target_audience || 'general'
    }
  end
end
```

#### **Brand Application in Prompts**
```ruby
def build_social_media_prompt(params)
  brand_context = params[:brand_context] || {}
  
  prompt = "Create a social media post with the following requirements:\n"
  prompt += "Brand Voice: #{brand_context[:voice_tone]}\n"
  prompt += "Key Messages: #{brand_context[:key_messages].join(', ')}\n"
  prompt += "Target Audience: #{brand_context[:target_audience]}\n"
  prompt += "Campaign Context: #{params[:campaign_context]}\n"
  prompt += "Platform: #{params[:platform]}\n"
  
  prompt
end
```

### **3. Error Handling and Resilience**

#### **Circuit Breaker Implementation**
```ruby
# app/services/llm_providers/base_provider.rb
class BaseProvider
  include CircuitBreaker
  
  circuit_breaker :api_request, 
                  exceptions: [StandardError],
                  threshold: 5,
                  timeout: 60
  
  def make_request(method, params)
    api_request do
      perform_llm_request(method, params)
    end
  rescue CircuitBreaker::CircuitOpen
    handle_circuit_open_fallback(method, params)
  end
end
```

#### **Retry Logic with Backoff**
```ruby
def perform_llm_request(method, params)
  retries = 0
  max_retries = ENV.fetch('LLM_MAX_RETRIES', 3).to_i
  
  begin
    send("#{method}_implementation", params)
  rescue StandardError => e
    retries += 1
    if retries <= max_retries
      sleep(2 ** retries) # Exponential backoff
      retry
    else
      raise e
    end
  end
end
```

### **4. Response Processing**

#### **Response Parser**
```ruby
def parse_openai_response(response, content_type)
  content = response.dig('choices', 0, 'message', 'content')
  
  {
    content: content,
    metadata: {
      model: response['model'],
      usage: response['usage'],
      service: 'openai',
      generated_at: Time.current,
      content_type: content_type
    }
  }
rescue StandardError => e
  Rails.logger.error "Response parsing failed: #{e.message}"
  fallback_response(content_type)
end
```

---

## 🔄 **API Integration Details**

### **OpenAI API Integration**

#### **Client Configuration**
```ruby
# app/services/llm_providers/openai_provider.rb
def openai_client
  @openai_client ||= OpenAI::Client.new(
    access_token: ENV['OPENAI_API_KEY'],
    log_errors: Rails.env.development?,
    request_timeout: ENV.fetch('LLM_REQUEST_TIMEOUT', 30).to_i
  )
end
```

#### **Content Generation Methods**
```ruby
def generate_social_media_content(params)
  prompt = build_social_media_prompt(params)
  
  response = openai_client.chat(
    parameters: {
      model: 'gpt-4',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 500,
      temperature: 0.7
    }
  )
  
  parse_openai_response(response, 'social_media')
end
```

### **API Endpoints**

#### **Content Generation API**
```ruby
# app/controllers/api/v1/content_generation_controller.rb
class Api::V1::ContentGenerationController < ApplicationController
  def social_media
    response = llm_service.generate_social_media_content(
      platform: params[:platform],
      tone: params[:tone],
      topic: params[:topic],
      brand_context: current_brand_context
    )
    
    render json: { success: true, data: response }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: 422
  end
end
```

#### **Health Check Endpoint**
```ruby
def health
  status = {
    llm_enabled: ENV['LLM_ENABLED'] == 'true',
    provider: LlmServiceContainer.current_provider,
    circuit_breaker_status: circuit_breaker_status,
    last_successful_request: last_successful_request_time
  }
  
  render json: status
end
```

---

## 🧪 **Testing Strategy**

### **Unit Tests**

#### **Provider Testing**
```ruby
# test/services/llm_providers/openai_provider_test.rb
class OpenaiProviderTest < ActiveSupport::TestCase
  def setup
    @provider = LlmProviders::OpenaiProvider.new
    @mock_response = build_mock_openai_response
  end
  
  test "generates social media content successfully" do
    stub_openai_request(@mock_response)
    
    result = @provider.generate_social_media_content(
      platform: 'twitter',
      topic: 'AI marketing'
    )
    
    assert_not_nil result[:content]
    assert_equal 'openai', result[:metadata][:service]
  end
end
```

#### **Integration Testing**
```ruby
# test/integration/ai_content_generation_test.rb
class AiContentGenerationTest < ActionDispatch::IntegrationTest
  test "user can generate AI content for campaign" do
    post login_path, params: { email: users(:one).email, password: 'password' }
    
    post campaign_plan_generated_contents_path(@campaign_plan), 
         params: { 
           generated_content: { 
             title: 'Test Content',
             content_type: 'social_post'
           }
         }
    
    assert_redirected_to campaign_plan_path(@campaign_plan)
    assert GeneratedContent.last.body_content.present?
  end
end
```

### **Mock Provider for Testing**
```ruby
# app/services/llm_providers/mock_provider.rb
class LlmProviders::MockProvider < LlmProviders::BaseProvider
  def generate_social_media_content(params)
    {
      content: "Mock social media content for #{params[:platform]}",
      metadata: {
        service: 'mock',
        generated_at: Time.current
      }
    }
  end
end
```

---

## 📊 **Monitoring and Logging**

### **Request Logging**
```ruby
# app/services/llm_providers/base_provider.rb
def log_request(method, params, duration, success)
  Rails.logger.info({
    event: 'llm_request',
    method: method,
    provider: self.class.name,
    duration: duration,
    success: success,
    timestamp: Time.current
  }.to_json)
end
```

### **Performance Monitoring**
```ruby
def track_performance(method, &block)
  start_time = Time.current
  result = yield
  duration = Time.current - start_time
  
  # Log performance metrics
  log_request(method, {}, duration, true)
  
  # Track metrics (if using metrics service)
  MetricsService.record('llm_request_duration', duration, tags: { 
    method: method, 
    provider: self.class.name 
  })
  
  result
rescue StandardError => e
  log_request(method, {}, Time.current - start_time, false)
  raise e
end
```

### **Health Monitoring**
```ruby
# app/services/health_check_service.rb
class HealthCheckService
  def self.llm_health_status
    {
      enabled: ENV['LLM_ENABLED'] == 'true',
      provider: LlmServiceContainer.current_provider,
      api_connectivity: test_api_connectivity,
      circuit_breaker: circuit_breaker_status,
      recent_errors: recent_error_count
    }
  end
end
```

---

## 🚀 **Deployment and Scaling**

### **Environment Configuration**

#### **Production Settings**
```ruby
# config/environments/production.rb
Rails.application.configure do
  # LLM Configuration
  config.llm_enabled = ENV['LLM_ENABLED'] == 'true'
  config.default_llm_provider = :openai
  
  # Performance Settings
  config.llm_timeout = 30
  config.llm_retries = 3
  config.circuit_breaker_threshold = 5
end
```

#### **Background Job Processing**
```ruby
# app/jobs/generate_content_job.rb
class GenerateContentJob < ApplicationJob
  queue_as :ai_processing
  
  def perform(generated_content_id)
    content = GeneratedContent.find(generated_content_id)
    ContentGenerationService.new(content).call
  rescue StandardError => e
    Rails.logger.error "Content generation failed: #{e.message}"
    # Handle error notification
  end
end
```

### **Scaling Considerations**

#### **Rate Limiting**
```ruby
# config/initializers/rate_limiting.rb
Rails.application.config.middleware.use Rack::Attack

Rack::Attack.throttle('ai_requests', limit: 100, period: 1.hour) do |req|
  req.ip if req.path.start_with?('/api/v1/content_generation')
end
```

#### **Caching Strategy**
```ruby
def generate_with_cache(method, params)
  cache_key = "llm_#{method}_#{Digest::MD5.hexdigest(params.to_json)}"
  
  Rails.cache.fetch(cache_key, expires_in: 1.hour) do
    make_request(method, params)
  end
end
```

---

## 🔧 **Troubleshooting Guide**

### **Common Issues**

#### **1. API Key Issues**
```
Error: "Incorrect API key provided"
Solution: Check OPENAI_API_KEY in .env file
Command: echo $OPENAI_API_KEY
```

#### **2. Rate Limiting**
```
Error: "Rate limit exceeded"
Solution: Implement exponential backoff and caching
Check: API usage in OpenAI dashboard
```

#### **3. Circuit Breaker Tripped**
```
Error: "Circuit breaker is open"
Solution: Check LLM service health
Command: curl /api/v1/content_generation/health
```

#### **4. Timeout Issues**
```
Error: "Request timeout"
Solution: Increase LLM_REQUEST_TIMEOUT
Current: ENV.fetch('LLM_REQUEST_TIMEOUT', 30)
```

### **Debug Commands**
```bash
# Test AI integration
rails runner "puts LlmServiceContainer.get_service.class.name"

# Check health status
curl http://localhost:3000/api/v1/content_generation/health

# Test content generation
rails runner "p LlmServiceContainer.get_service.generate_social_media_content(platform: 'twitter')"
```

---

## 📈 **Performance Optimization**

### **Request Optimization**
```ruby
# Batch similar requests
def generate_content_batch(contents)
  contents.group_by(&:content_type).map do |type, group|
    generate_multiple_content(type, group)
  end.flatten
end

# Async processing for long operations
def generate_async(params)
  GenerateContentJob.perform_async(params)
end
```

### **Memory Management**
```ruby
# Clear large objects after use
def cleanup_after_generation
  @large_context_data = nil
  GC.start if Rails.env.development?
end
```

---

**This implementation guide provides the technical foundation for understanding, maintaining, and extending the AI integration within the marketing platform.**