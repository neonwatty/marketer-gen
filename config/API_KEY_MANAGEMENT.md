# API Key Management Strategy for LLM Providers

## Overview

This document outlines the comprehensive strategy for managing API keys across multiple LLM providers in a secure, scalable, and maintainable way. The strategy covers key storage, rotation, validation, monitoring, and security best practices.

## Current State

The application currently supports configuration for multiple LLM providers through environment variables:
- OpenAI (`OPENAI_API_KEY`)
- Anthropic (`ANTHROPIC_API_KEY`) 
- Google AI (`GOOGLE_AI_API_KEY`)

## Secure Storage Architecture

### 1. Primary Storage: Rails Credentials

```yaml
# config/credentials.yml.enc (encrypted)
llm_providers:
  openai:
    api_key: "sk-..."
    organization: "org-..."
    project: "proj_..."
  anthropic:
    api_key: "sk-ant-..."
    workspace: "workspace_..."
  google:
    api_key: "AIza..."
    project_id: "project-123"
```

### 2. Environment Variable Fallback

```bash
# For development/staging environments
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_AI_API_KEY=AIza...

# Additional security variables
LLM_KEY_ROTATION_SCHEDULE=weekly
LLM_KEY_VALIDATION_ENABLED=true
LLM_KEY_EXPIRY_WARNING_DAYS=7
```

### 3. External Secret Management Integration

```ruby
# config/initializers/secret_manager.rb
class SecretManager
  def self.get_llm_key(provider)
    case Rails.env
    when 'production'
      # AWS Secrets Manager, Azure Key Vault, or HashiCorp Vault
      get_from_vault(provider)
    when 'staging'
      # Staging-specific secret store
      get_from_staging_vault(provider)
    else
      # Development: use Rails credentials or env vars
      get_from_credentials_or_env(provider)
    end
  end
  
  private
  
  def self.get_from_vault(provider)
    # Implementation for production vault integration
    vault_client = initialize_vault_client
    secret_path = "llm-providers/#{provider}/api-key"
    vault_client.read(secret_path)
  end
  
  def self.get_from_credentials_or_env(provider)
    Rails.application.credentials.dig(:llm_providers, provider.to_sym, :api_key) ||
      ENV["#{provider.upcase}_API_KEY"]
  end
end
```

## API Key Validation Framework

### 1. Format Validation

```ruby
# app/services/llm_providers/key_validator.rb
class LlmProviders::KeyValidator
  class << self
    def validate_format(provider, key)
      pattern = key_patterns[provider.to_sym]
      return { valid: false, error: "Unknown provider" } unless pattern
      
      if key.match?(pattern)
        { valid: true }
      else
        { valid: false, error: "Invalid key format for #{provider}" }
      end
    end
    
    def validate_functional(provider, key)
      begin
        test_provider = build_test_provider(provider, key)
        response = test_provider.health_check
        
        if response[:status] == 'healthy'
          { valid: true, response_time: response[:response_time] }
        else
          { valid: false, error: "Health check failed" }
        end
      rescue => error
        { valid: false, error: error.message }
      end
    end
    
    private
    
    def key_patterns
      {
        openai: /^sk-[a-zA-Z0-9]{48}$/,
        anthropic: /^sk-ant-[a-zA-Z0-9\-_]{95}$/,
        google: /^[A-Za-z0-9\-_]{39}$/
      }
    end
    
    def build_test_provider(provider, key)
      config = {
        api_key: key,
        model: default_models[provider.to_sym],
        timeout: 10,
        max_tokens: 10
      }
      
      "LlmProviders::#{provider.classify}Provider".constantize.new(config)
    end
    
    def default_models
      {
        openai: 'gpt-3.5-turbo',
        anthropic: 'claude-3-haiku-20240307',
        google: 'gemini-pro'
      }
    end
  end
end
```

### 2. Key Health Monitoring

```ruby
# app/services/llm_providers/key_health_monitor.rb
class LlmProviders::KeyHealthMonitor
  def self.check_all_keys
    results = {}
    
    Rails.application.config.llm_providers.each do |provider, config|
      next unless config[:enabled] && config[:api_key].present?
      
      results[provider] = check_key_health(provider, config[:api_key])
    end
    
    results
  end
  
  def self.check_key_health(provider, key)
    start_time = Time.current
    
    validation = LlmProviders::KeyValidator.validate_functional(provider, key)
    
    health_data = {
      provider: provider,
      valid: validation[:valid],
      response_time: validation[:response_time],
      checked_at: Time.current,
      check_duration: Time.current - start_time
    }
    
    if validation[:valid]
      health_data[:status] = 'healthy'
      record_healthy_check(provider)
    else
      health_data[:status] = 'unhealthy'
      health_data[:error] = validation[:error]
      record_unhealthy_check(provider, validation[:error])
    end
    
    health_data
  end
  
  private
  
  def self.record_healthy_check(provider)
    Rails.cache.write("llm_key_health:#{provider}", 'healthy', expires_in: 1.hour)
    Rails.logger.info "API key health check passed for #{provider}"
  end
  
  def self.record_unhealthy_check(provider, error)
    Rails.cache.write("llm_key_health:#{provider}", 'unhealthy', expires_in: 5.minutes)
    Rails.logger.error "API key health check failed for #{provider}: #{error}"
    
    # Trigger alerts if configured
    alert_unhealthy_key(provider, error) if should_alert?(provider)
  end
  
  def self.alert_unhealthy_key(provider, error)
    # Integration with alerting systems (Slack, PagerDuty, etc.)
    AlertingService.send_alert(
      type: 'llm_key_health_failure',
      provider: provider,
      error: error,
      severity: 'high'
    )
  end
end
```

## Key Rotation Strategy

### 1. Automated Rotation Framework

```ruby
# app/services/llm_providers/key_rotator.rb
class LlmProviders::KeyRotator
  def self.rotate_key(provider, new_key)
    old_key = get_current_key(provider)
    
    # Validate new key
    validation = LlmProviders::KeyValidator.validate_functional(provider, new_key)
    raise "New key validation failed: #{validation[:error]}" unless validation[:valid]
    
    # Test new key with actual request
    test_new_key(provider, new_key)
    
    # Update key storage
    update_key_storage(provider, new_key)
    
    # Gradual transition
    perform_gradual_transition(provider, old_key, new_key)
    
    # Cleanup old key
    cleanup_old_key(provider, old_key)
    
    # Record rotation event
    record_rotation_event(provider, old_key, new_key)
  end
  
  def self.schedule_rotation(provider, rotation_date)
    # Schedule rotation job
    RotateKeyJob.set(wait_until: rotation_date).perform_later(provider)
  end
  
  private
  
  def self.test_new_key(provider, new_key)
    test_provider = build_test_provider(provider, new_key)
    
    # Test with minimal request
    result = test_provider.generate_social_media_content({
      platform: 'twitter',
      topic: 'test',
      tone: 'professional'
    })
    
    raise "New key test failed" unless result[:content].present?
  end
  
  def self.perform_gradual_transition(provider, old_key, new_key)
    # Implement blue-green deployment pattern for API keys
    transition_periods = [
      { duration: 5.minutes, new_key_percentage: 10 },
      { duration: 15.minutes, new_key_percentage: 50 },
      { duration: 30.minutes, new_key_percentage: 100 }
    ]
    
    transition_periods.each do |period|
      set_key_distribution(provider, old_key, new_key, period[:new_key_percentage])
      sleep(period[:duration])
      
      # Monitor for errors during transition
      check_transition_health(provider)
    end
  end
  
  def self.record_rotation_event(provider, old_key, new_key)
    event = {
      provider: provider,
      old_key_suffix: old_key[-8..-1], # Store only last 8 characters for security
      new_key_suffix: new_key[-8..-1],
      rotated_at: Time.current,
      rotated_by: 'automated_system'
    }
    
    Rails.logger.info "API key rotated", event
    
    # Store in audit log
    ApiKeyAuditLog.create!(event)
  end
end

# app/jobs/rotate_key_job.rb
class RotateKeyJob < ApplicationJob
  queue_as :default
  
  def perform(provider)
    # Get new key from secure generation service or manual input
    new_key = generate_or_retrieve_new_key(provider)
    
    LlmProviders::KeyRotator.rotate_key(provider, new_key)
  rescue => error
    Rails.logger.error "Key rotation failed for #{provider}: #{error.message}"
    
    # Alert operations team
    AlertingService.send_alert(
      type: 'key_rotation_failure',
      provider: provider,
      error: error.message,
      severity: 'critical'
    )
    
    raise error
  end
  
  private
  
  def generate_or_retrieve_new_key(provider)
    # Integration with provider-specific key generation APIs
    # or retrieve from secure key management service
    case provider
    when 'openai'
      OpenaiKeyGenerator.generate_new_key
    when 'anthropic'
      AnthropicKeyGenerator.generate_new_key
    else
      raise "Key generation not supported for #{provider}"
    end
  end
end
```

### 2. Rotation Monitoring and Alerts

```ruby
# app/services/llm_providers/rotation_monitor.rb
class LlmProviders::RotationMonitor
  def self.check_rotation_schedule
    providers_needing_rotation.each do |provider|
      schedule_rotation(provider)
    end
  end
  
  def self.providers_needing_rotation
    Rails.application.config.llm_providers.select do |provider, config|
      next false unless config[:enabled] && config[:api_key].present?
      
      last_rotation = get_last_rotation_date(provider)
      rotation_interval = get_rotation_interval(provider)
      
      last_rotation.nil? || (Time.current - last_rotation) >= rotation_interval
    end.keys
  end
  
  def self.get_rotation_interval(provider)
    env_var = "#{provider.upcase}_KEY_ROTATION_INTERVAL"
    interval_days = ENV.fetch(env_var, '30').to_i
    interval_days.days
  end
  
  def self.schedule_rotation(provider)
    Rails.logger.info "Scheduling key rotation for #{provider}"
    
    # Schedule with some randomization to avoid all keys rotating at once
    rotation_time = Time.current + rand(1..24).hours
    
    LlmProviders::KeyRotator.schedule_rotation(provider, rotation_time)
  end
end
```

## Security Best Practices

### 1. Key Access Control

```ruby
# app/models/api_key_access_log.rb
class ApiKeyAccessLog < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :provider, presence: true
  validates :action, presence: true
  validates :ip_address, presence: true
  
  scope :recent, -> { where('created_at > ?', 24.hours.ago) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  
  def self.log_access(provider, action, user: nil, ip_address: nil, metadata: {})
    create!(
      provider: provider,
      action: action,
      user: user,
      ip_address: ip_address || 'unknown',
      metadata: metadata,
      created_at: Time.current
    )
  end
end

# Migration
class CreateApiKeyAccessLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :api_key_access_logs do |t|
      t.string :provider, null: false
      t.string :action, null: false
      t.references :user, foreign_key: true, null: true
      t.string :ip_address
      t.json :metadata
      t.timestamps
    end
    
    add_index :api_key_access_logs, [:provider, :created_at]
    add_index :api_key_access_logs, :created_at
  end
end
```

### 2. Key Exposure Prevention

```ruby
# app/services/llm_providers/key_sanitizer.rb
class LlmProviders::KeySanitizer
  class << self
    def sanitize_for_logging(text)
      return text if text.blank?
      
      # Replace all API key patterns with masked versions
      sanitized = text.dup
      
      key_patterns.each do |provider, pattern|
        sanitized.gsub!(pattern) do |match|
          mask_key(match, provider)
        end
      end
      
      sanitized
    end
    
    def sanitize_hash(hash)
      return hash unless hash.is_a?(Hash)
      
      hash.deep_transform_values do |value|
        if value.is_a?(String)
          sanitize_for_logging(value)
        else
          value
        end
      end
    end
    
    private
    
    def key_patterns
      {
        openai: /sk-[a-zA-Z0-9]{48}/,
        anthropic: /sk-ant-[a-zA-Z0-9\-_]{95}/,
        google: /[A-Za-z0-9\-_]{39}/
      }
    end
    
    def mask_key(key, provider)
      return key if key.length < 8
      
      prefix = key[0..7]
      suffix = key[-4..-1]
      "#{prefix}***#{suffix}"
    end
  end
end

# Override Rails logger to automatically sanitize logs
module SanitizedLogging
  def add(severity, message = nil, progname = nil, &block)
    if message.is_a?(String)
      message = LlmProviders::KeySanitizer.sanitize_for_logging(message)
    elsif message.is_a?(Hash)
      message = LlmProviders::KeySanitizer.sanitize_hash(message)
    end
    
    super(severity, message, progname, &block)
  end
end

Rails.logger.extend(SanitizedLogging)
```

## Monitoring and Alerting

### 1. Key Health Dashboard

```ruby
# app/controllers/admin/llm_keys_controller.rb
class Admin::LlmKeysController < AdminController
  def index
    @key_health = LlmProviders::KeyHealthMonitor.check_all_keys
    @rotation_schedule = calculate_rotation_schedule
    @usage_statistics = calculate_usage_statistics
  end
  
  def health_check
    provider = params[:provider]
    key = get_key_for_provider(provider)
    
    health = LlmProviders::KeyHealthMonitor.check_key_health(provider, key)
    
    render json: health
  end
  
  def rotate
    provider = params[:provider]
    new_key = params[:new_key]
    
    LlmProviders::KeyRotator.rotate_key(provider, new_key)
    
    redirect_to admin_llm_keys_path, notice: "Key rotated successfully for #{provider}"
  rescue => error
    redirect_to admin_llm_keys_path, alert: "Key rotation failed: #{error.message}"
  end
  
  private
  
  def calculate_rotation_schedule
    Rails.application.config.llm_providers.map do |provider, config|
      next unless config[:enabled]
      
      last_rotation = get_last_rotation_date(provider)
      interval = get_rotation_interval(provider)
      next_rotation = last_rotation ? last_rotation + interval : Time.current
      
      {
        provider: provider,
        last_rotation: last_rotation,
        next_rotation: next_rotation,
        overdue: next_rotation < Time.current
      }
    end.compact
  end
end
```

### 2. Automated Alerts

```ruby
# config/initializers/key_monitoring.rb
if Rails.env.production?
  # Schedule regular health checks
  cron '0 */6 * * *' do # Every 6 hours
    HealthCheckJob.perform_later('llm_keys')
  end
  
  # Daily rotation check
  cron '0 2 * * *' do # 2 AM daily
    KeyRotationCheckJob.perform_later
  end
end

# app/jobs/health_check_job.rb
class HealthCheckJob < ApplicationJob
  def perform(check_type)
    case check_type
    when 'llm_keys'
      check_llm_key_health
    end
  end
  
  private
  
  def check_llm_key_health
    health_results = LlmProviders::KeyHealthMonitor.check_all_keys
    
    unhealthy_providers = health_results.select { |_, health| health[:status] == 'unhealthy' }
    
    if unhealthy_providers.any?
      AlertingService.send_alert(
        type: 'llm_key_health_failure',
        unhealthy_providers: unhealthy_providers.keys,
        severity: 'high',
        details: unhealthy_providers
      )
    end
  end
end
```

## Implementation Checklist

### Phase 1: Core Security (Week 1)
- [ ] Implement Rails credentials storage
- [ ] Add environment variable fallback
- [ ] Create key format validation
- [ ] Implement basic sanitization

### Phase 2: Health Monitoring (Week 2)
- [ ] Build key health monitoring
- [ ] Create functional validation
- [ ] Add basic alerting
- [ ] Implement audit logging

### Phase 3: Rotation Framework (Week 3)
- [ ] Design rotation strategy
- [ ] Implement gradual transition
- [ ] Add rotation scheduling
- [ ] Create rotation jobs

### Phase 4: Advanced Features (Week 4)
- [ ] External secret manager integration
- [ ] Advanced monitoring dashboard
- [ ] Automated rotation triggers
- [ ] Comprehensive alerting

### Phase 5: Production Readiness (Week 5)
- [ ] Security review and testing
- [ ] Performance optimization
- [ ] Documentation completion
- [ ] Operations team training

## Security Audit Requirements

1. **Regular Security Reviews**
   - Monthly key access audits
   - Quarterly security assessments
   - Annual penetration testing

2. **Compliance Requirements**
   - SOC 2 compliance for key storage
   - GDPR compliance for access logging
   - Industry-specific requirements

3. **Incident Response Plan**
   - Key compromise procedures
   - Emergency rotation protocols
   - Communication plans

This comprehensive API key management strategy ensures secure, scalable, and maintainable handling of LLM provider credentials while providing robust monitoring and rotation capabilities.