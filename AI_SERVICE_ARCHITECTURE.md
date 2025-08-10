# AI Service Architecture Documentation

## Overview

The AI service architecture provides a comprehensive, modular system for integrating Large Language Models (LLMs) and Context7 MCP server into the marketing campaign platform. The architecture supports multiple AI providers, documentation lookup, and sophisticated content generation capabilities.

## Architecture Components

### 1. Core Services

#### AIServiceBase (Abstract Base Class)
- **Location**: `app/services/ai_service_base.rb`
- **Purpose**: Provides common interface and error handling for all AI service providers
- **Key Features**:
  - Standardized error handling with custom exception classes
  - Request retry logic with exponential backoff
  - Request/response logging and monitoring
  - Content sanitization and token estimation
  - Health check capabilities

#### AIServiceFactory (Service Factory)
- **Location**: `app/services/ai_service_factory.rb`
- **Purpose**: Creates and configures AI service instances based on provider
- **Supported Providers**:
  - **Anthropic**: Claude models (Sonnet, Haiku, Opus)
  - **OpenAI**: GPT models (GPT-4, GPT-3.5-turbo)
  - **Google**: Gemini models (Pro, Flash)
- **Key Features**:
  - Provider configuration management
  - Model capability detection
  - API key management
  - Singleton pattern for efficient resource usage

#### AnthropicService (Provider Implementation)
- **Location**: `app/services/anthropic_service.rb`
- **Purpose**: Concrete implementation for Anthropic Claude models
- **Key Features**:
  - Native Anthropic API integration
  - Function calling support
  - Image analysis capabilities
  - Streaming response support
  - Context-aware content generation

### 2. Context7 Integration

#### Context7IntegrationService
- **Location**: `app/services/context7_integration_service.rb`
- **Purpose**: Integrates with Context7 MCP server for documentation lookup
- **Key Features**:
  - Library ID resolution
  - Documentation caching
  - Batch lookup operations
  - Context-aware documentation retrieval
  - Technology stack suggestions

### 3. Main Orchestrator

#### AIService (Main Service)
- **Location**: `app/services/ai_service.rb`
- **Purpose**: High-level orchestrator that coordinates all AI operations
- **Key Capabilities**:
  - Campaign content generation
  - Brand asset analysis
  - Multi-channel content creation
  - Campaign optimization suggestions
  - Service health monitoring

## Data Flow Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Application       │    │    AIService        │    │  Context7Service    │
│   Controllers       │───▶│   (Orchestrator)    │───▶│  (Documentation)    │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
                                      │
                                      ▼
                           ┌─────────────────────┐
                           │ AIServiceFactory    │
                           │   (Provider         │
                           │   Selection)        │
                           └─────────────────────┘
                                      │
                                      ▼
                           ┌─────────────────────┐    ┌─────────────────────┐
                           │  AnthropicService   │    │   OpenAI Service    │
                           │  (Claude Models)    │    │   (GPT Models)      │
                           └─────────────────────┘    └─────────────────────┘
                                      │                         │
                                      ▼                         ▼
                           ┌─────────────────────┐    ┌─────────────────────┐
                           │  Anthropic API      │    │    OpenAI API       │
                           │  (External)         │    │   (External)        │
                           └─────────────────────┘    └─────────────────────┘
```

## Service Boundaries and API Contracts

### AIService Public Interface

```ruby
# Main service initialization
ai_service = AIService.new(
  provider: 'anthropic',
  model: 'claude-3-5-sonnet-20241022',
  enable_context7: true,
  enable_caching: true
)

# Campaign content generation
result = ai_service.generate_campaign_content(campaign, options)
# Returns: {
#   campaign_plan: {...},
#   channel_content: {...},
#   brand_context: "...",
#   generated_at: timestamp,
#   provider: "...",
#   model: "..."
# }

# Brand asset analysis
analysis = ai_service.analyze_brand_assets(assets, options)
# Returns: {
#   brand_voice: "...",
#   key_themes: [...],
#   actionable_insights: [...],
#   compliance_score: integer,
#   ...
# }

# Channel-specific content generation
content = ai_service.generate_channel_content(channel, campaign, options)
# Returns: {
#   channel: "...",
#   content: "...",
#   generated_at: timestamp,
#   model_used: "..."
# }

# Campaign optimization suggestions
suggestions = ai_service.suggest_campaign_optimizations(campaign, performance_data)
# Returns: {
#   suggestions: [...],
#   format: "json|text",
#   generated_at: timestamp
# }

# Service health check
health = ai_service.healthy?
# Returns: {
#   ai_provider: boolean,
#   context7: boolean,
#   overall: boolean
# }
```

### Provider Interface Contract

All AI service providers must implement:

```ruby
class CustomAIService < AIServiceBase
  # Required methods
  def generate_content(prompt, options = {})
  def generate_campaign_plan(campaign_data, options = {})
  def analyze_brand_assets(assets, options = {})
  def generate_content_for_channel(channel, brand_context, options = {})
  
  # Optional capability methods
  def supports_function_calling?; end
  def supports_image_analysis?; end
  def supports_streaming?; end
  def max_context_tokens; end
  def test_connection; end
end
```

### Context7 Integration Interface

```ruby
context7 = Context7IntegrationService.new

# Documentation lookup
docs = context7.lookup_documentation('react', topic: 'hooks')
# Returns: {
#   library_id: "/facebook/react",
#   topic: "hooks", 
#   content: "...",
#   retrieved_at: timestamp,
#   token_count: integer
# }

# Enhanced lookup with context
docs = context7.lookup_with_context('rails', 'how to create models')

# Batch operations
results = context7.batch_lookup(['react', 'rails', 'tailwindcss'])

# Technology suggestions
suggestions = context7.suggest_libraries(['react', 'javascript'])
```

## Configuration

### Environment Variables

```bash
# Provider configuration
AI_DEFAULT_PROVIDER=anthropic
AI_DEFAULT_MODEL=claude-3-5-sonnet-20241022

# API keys
ANTHROPIC_API_KEY=your_anthropic_key
OPENAI_API_KEY=your_openai_key
GOOGLE_API_KEY=your_google_key

# Context7 settings
CONTEXT7_ENABLED=true
CONTEXT7_CACHE_DURATION=3600

# Performance settings
AI_ENABLE_CACHING=true
AI_CACHE_DURATION=1800
AI_TIMEOUT_SECONDS=60
AI_MAX_RETRIES=3

# Token limits
AI_MAX_TOKENS_CONTENT=4000
AI_MAX_TOKENS_CAMPAIGN=3000
AI_MAX_TOKENS_ANALYSIS=2000

# Development settings
AI_DEBUG=false
AI_LOG_REQUESTS=true
AI_RATE_LIMIT=100
```

### Rails Credentials

```yaml
# config/credentials.yml.enc
anthropic:
  api_key: your_encrypted_anthropic_key

openai:
  api_key: your_encrypted_openai_key

google:
  api_key: your_encrypted_google_key
```

## Error Handling

### Error Hierarchy

```
AIServiceError (base)
├── ProviderError
├── RateLimitError
├── AuthenticationError
├── InvalidRequestError
├── ContextTooLongError
├── InsufficientCreditsError
└── ProviderUnavailableError

Context7Error (base)
├── LibraryNotFoundError
└── DocumentationNotFoundError
```

### Error Handling Strategy

1. **Automatic Retry**: Rate limits and temporary provider issues
2. **Graceful Degradation**: Context7 unavailable falls back to basic AI
3. **User Feedback**: Clear error messages for configuration issues
4. **Logging**: Comprehensive error logging for debugging
5. **Fallback Providers**: Automatic provider switching on failure

## Security Considerations

### API Key Management
- Keys stored in Rails credentials (encrypted)
- Environment variable fallbacks for deployment
- No keys in code or version control
- Separate keys per environment

### Input Sanitization
- Prompt sanitization to prevent injection
- Content length limits to prevent abuse
- Token count estimation for cost control
- Input validation for all parameters

### Rate Limiting
- Provider-specific rate limiting
- Application-level request throttling
- User-based quotas (future enhancement)
- Graceful handling of rate limit errors

## Performance Optimization

### Caching Strategy
- Response caching with configurable TTL
- Cache key generation based on inputs
- Memory-based cache with size limits
- Cache warming for common operations

### Token Management
- Dynamic token allocation based on operation type
- Content truncation for large contexts
- Token estimation for cost prediction
- Context window optimization

### Request Optimization
- Connection pooling for HTTP requests
- Timeout configuration per provider
- Batch operations where possible
- Async processing for large operations

## Usage Examples

### Basic Campaign Generation

```ruby
# Initialize service
ai = AIService.new(
  provider: 'anthropic',
  model: 'claude-3-5-sonnet-20241022'
)

# Generate campaign content
campaign = Campaign.find(1)
result = ai.generate_campaign_content(campaign, {
  creativity_level: 0.8,
  include_channels: ['email', 'social_media', 'web'],
  focus_areas: ['engagement', 'conversion']
})

puts result[:campaign_plan]['campaign_overview']
puts result[:channel_content]['email']['content']
```

### Brand Analysis with Documentation Lookup

```ruby
# Analyze brand assets with technical context
assets = campaign.brand_assets
analysis = ai.analyze_brand_assets(assets, {
  focus_areas: ['technical_compliance', 'brand_voice'],
  technologies: ['rails', 'stimulus', 'tailwindcss']
})

puts analysis['brand_voice']
puts analysis['technical_mentions']
puts analysis['actionable_insights']
```

### Multi-Provider Setup

```ruby
# Use different providers for different operations
anthropic_service = AIService.new(provider: 'anthropic')
openai_service = AIService.new(provider: 'openai', model: 'gpt-4o')

# Use Anthropic for analysis (better reasoning)
analysis = anthropic_service.analyze_brand_assets(assets)

# Use OpenAI for creative content (different style)
creative_content = openai_service.generate_channel_content('social_media', campaign)
```

## Future Enhancements

### Planned Features
1. **Streaming Responses**: Real-time content generation
2. **Function Calling**: Structured AI interactions
3. **Image Analysis**: Visual brand asset analysis
4. **Multi-Modal Content**: Text + image generation
5. **Workflow Automation**: AI-driven campaign workflows
6. **A/B Testing**: AI-powered content optimization
7. **Analytics Integration**: Performance-based learning

### Scalability Considerations
1. **Background Jobs**: Async processing with Sidekiq
2. **Database Caching**: Persistent cache for common operations
3. **Load Balancing**: Multiple provider instances
4. **Monitoring**: Comprehensive service monitoring
5. **Cost Tracking**: Usage and cost analytics

## Troubleshooting

### Common Issues

#### Service Initialization Failures
- Check API key configuration
- Verify provider availability
- Review network connectivity
- Validate model names

#### Context7 Integration Issues
- Ensure MCP server is running
- Check library name resolution
- Verify documentation cache
- Review MCP configuration

#### Performance Issues
- Monitor token usage
- Check cache hit rates
- Review timeout settings
- Analyze request patterns

### Debugging Tools

```ruby
# Service health check
health = AIService.new.healthy?
puts health.inspect

# Cache statistics
service = AIService.new
puts service.service_info

# Error logging
Rails.logger.tagged("AI Debug") do
  # AI operations with enhanced logging
end
```

This architecture provides a robust, scalable foundation for AI-powered marketing campaign generation while maintaining flexibility for future enhancements and provider integrations.