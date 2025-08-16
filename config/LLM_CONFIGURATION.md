# LLM Service Configuration Management

This document describes the configuration options for managing LLM (Large Language Model) services in the application.

## Overview

The application supports both mock and real LLM implementations with automatic fallback mechanisms, circuit breakers, and provider selection. Configuration is managed through environment variables and feature flags.

## Environment Variables

### Core Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_ENABLED` | `false` (dev/test), `true` (prod) | Global toggle for LLM functionality |
| `USE_REAL_LLM` | `false` | Enable real LLM providers vs mock service |
| `LLM_FALLBACK_ENABLED` | `true` | Allow fallback to mock service on provider failures |
| `LLM_STRICT_MODE` | `false` | Disable all fallbacks (fail fast) |

### Provider Configuration

#### OpenAI
| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | - | OpenAI API key (required for OpenAI) |
| `OPENAI_MODEL` | `gpt-4` | Model to use |
| `OPENAI_ENDPOINT` | - | Custom API endpoint (optional) |
| `OPENAI_ENABLED` | `true` | Enable OpenAI provider |
| `OPENAI_PRIORITY` | `1` | Provider priority (lower = higher priority) |
| `OPENAI_MAX_TOKENS` | `4000` | Maximum tokens per request |
| `OPENAI_TEMPERATURE` | `0.7` | Model temperature |

#### Anthropic
| Variable | Default | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | - | Anthropic API key (required for Anthropic) |
| `ANTHROPIC_MODEL` | `claude-3-sonnet-20240229` | Model to use |
| `ANTHROPIC_ENDPOINT` | - | Custom API endpoint (optional) |
| `ANTHROPIC_ENABLED` | `true` | Enable Anthropic provider |
| `ANTHROPIC_PRIORITY` | `2` | Provider priority |
| `ANTHROPIC_MAX_TOKENS` | `4000` | Maximum tokens per request |
| `ANTHROPIC_TEMPERATURE` | `0.7` | Model temperature |

#### Google AI
| Variable | Default | Description |
|----------|---------|-------------|
| `GOOGLE_AI_API_KEY` | - | Google AI API key |
| `GOOGLE_AI_MODEL` | `gemini-pro` | Model to use |
| `GOOGLE_AI_ENDPOINT` | - | Custom API endpoint (optional) |
| `GOOGLE_AI_ENABLED` | `false` | Enable Google AI provider |
| `GOOGLE_AI_PRIORITY` | `3` | Provider priority |
| `GOOGLE_AI_MAX_TOKENS` | `4000` | Maximum tokens per request |
| `GOOGLE_AI_TEMPERATURE` | `0.7` | Model temperature |

### Resilience & Performance

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_TIMEOUT` | `30` | Request timeout in seconds |
| `LLM_RETRY_ATTEMPTS` | `3` | Number of retry attempts on failure |
| `LLM_RETRY_DELAY` | `1` | Delay between retries in seconds |
| `LLM_CIRCUIT_BREAKER_THRESHOLD` | `5` | Failures before opening circuit breaker |
| `LLM_CIRCUIT_BREAKER_TIMEOUT` | `60` | Seconds before trying failed provider again |

### Monitoring & Debugging

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_MONITORING_ENABLED` | `true` (dev), `false` (prod) | Enable monitoring |
| `LLM_DEBUG_LOGGING` | `true` (dev), `false` (prod) | Verbose logging |
| `LLM_PERFORMANCE_TRACKING` | `true` | Track performance metrics |

## Configuration Examples

### Development Environment
```bash
# Use mock service for development
LLM_ENABLED=true
USE_REAL_LLM=false
LLM_DEBUG_LOGGING=true
LLM_MONITORING_ENABLED=true
```

### Staging Environment
```bash
# Test with real providers but with fallback
LLM_ENABLED=true
USE_REAL_LLM=true
LLM_FALLBACK_ENABLED=true
OPENAI_API_KEY=sk-test-...
ANTHROPIC_API_KEY=sk-ant-...
LLM_DEBUG_LOGGING=true
```

### Production Environment
```bash
# Production with multiple providers
LLM_ENABLED=true
USE_REAL_LLM=true
LLM_FALLBACK_ENABLED=true

# Primary provider (highest priority)
OPENAI_API_KEY=sk-...
OPENAI_PRIORITY=1
OPENAI_ENABLED=true

# Secondary provider
ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_PRIORITY=2
ANTHROPIC_ENABLED=true

# Resilience settings
LLM_TIMEOUT=45
LLM_CIRCUIT_BREAKER_THRESHOLD=3
LLM_RETRY_ATTEMPTS=2

# Monitoring
LLM_PERFORMANCE_TRACKING=true
LLM_DEBUG_LOGGING=false
```

### High-Availability Setup
```bash
# Multiple providers with aggressive failover
LLM_ENABLED=true
USE_REAL_LLM=true
LLM_STRICT_MODE=false
LLM_FALLBACK_ENABLED=true

# All providers enabled
OPENAI_API_KEY=sk-...
OPENAI_PRIORITY=1
ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_PRIORITY=2
GOOGLE_AI_API_KEY=...
GOOGLE_AI_ENABLED=true
GOOGLE_AI_PRIORITY=3

# Fast failover
LLM_TIMEOUT=20
LLM_CIRCUIT_BREAKER_THRESHOLD=2
LLM_CIRCUIT_BREAKER_TIMEOUT=30
```

## Service Selection Logic

1. **Feature Flag Check**: If `LLM_ENABLED=false`, always use mock service
2. **Service Type Check**: If `USE_REAL_LLM=false`, use mock service
3. **Provider Selection**: 
   - Get all enabled providers with valid API keys
   - Sort by priority (lower number = higher priority)
   - Try providers in order until one succeeds
4. **Circuit Breaker**: Skip providers with open circuit breakers
5. **Fallback**: If all providers fail and `LLM_FALLBACK_ENABLED=true`, use mock service

## Monitoring and Debugging

### Configuration Status
Access current configuration in Rails console:
```ruby
LlmServiceContainer.configuration_status
```

### Circuit Breaker States
Monitor circuit breaker states:
```ruby
config = Rails.application.config
puts config.llm_feature_flags
puts LlmServiceContainer.configuration_status[:circuit_breaker_states]
```

### Testing Provider Switching
```ruby
# Force service type
Rails.application.config.llm_service_type = :mock
service = LlmServiceContainer.get(:mock)

# Test real service (will use provider selection)
Rails.application.config.llm_service_type = :real
service = LlmServiceContainer.get(:real)
```

## Deployment Recommendations

### Development
- Use mock service (`USE_REAL_LLM=false`)
- Enable debug logging
- Enable monitoring

### Staging/Testing
- Use real providers for integration testing
- Enable fallback to mock
- Monitor all metrics
- Test failover scenarios

### Production
- Use multiple providers for redundancy
- Set appropriate timeouts and retry counts
- Enable monitoring but disable debug logging
- Configure circuit breakers for fast failover
- Monitor provider costs and usage

## Security Considerations

1. **API Keys**: Store in secure environment variables, never in code
2. **Endpoints**: Use HTTPS for all provider endpoints
3. **Timeouts**: Set reasonable timeouts to prevent resource exhaustion
4. **Rate Limiting**: Be aware of provider rate limits
5. **Logging**: Don't log sensitive data (API keys, user content)

## Troubleshooting

### Common Issues

1. **"No LLM providers available"**
   - Check that provider API keys are set
   - Verify providers are enabled
   - Check network connectivity

2. **"Service not registered"**
   - Ensure Rails application has initialized
   - Check that services are registered in initializer

3. **Circuit breaker always open**
   - Check provider API keys and endpoints
   - Verify network connectivity
   - Review error logs for failure causes
   - Consider adjusting circuit breaker thresholds

4. **Slow responses**
   - Adjust timeout settings
   - Check provider status pages
   - Consider using faster models
   - Monitor network latency

### Debug Steps

1. Check configuration status:
   ```ruby
   LlmServiceContainer.configuration_status
   ```

2. Test mock service:
   ```ruby
   service = LlmServiceContainer.get(:mock)
   result = service.health_check
   ```

3. Check provider availability:
   ```ruby
   config = Rails.application.config
   config.llm_providers.each do |name, provider|
     puts "#{name}: enabled=#{provider[:enabled]}, key_present=#{provider[:api_key].present?}"
   end
   ```

4. Review logs for LLM-related errors and circuit breaker events