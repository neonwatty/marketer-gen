# frozen_string_literal: true

# LLM Service Dependency Injection Configuration
# This initializer sets up the dependency injection container for LLM services,
# allowing easy switching between mock and real implementations

module LlmServiceContainer
  extend self

  # Container for service instances
  @services = {}
  @circuit_breakers = {}

  # Register a service implementation
  # @param [Symbol] name - service name
  # @param [Class] service_class - service class
  def register(name, service_class)
    @services[name] = service_class
    @circuit_breakers[name] = { failure_count: 0, last_failure: nil, state: :closed }
  end

  # Get a service instance with enhanced fallback logic
  # @param [Symbol] name - service name
  # @return [Object] service instance
  def get(name)
    # Check feature flags first
    config = Rails.application.config
    return get_mock_service unless config.llm_feature_flags[:enabled]
    
    # If requesting real service but not enabled, return mock
    if name == :real && !config.llm_feature_flags[:use_real_service]
      return get_mock_service
    end
    
    # Handle real service with provider selection
    if name == :real
      return get_real_service_with_fallback
    end
    
    # Handle mock or specific service request
    service_class = @services[name]
    raise ArgumentError, "Service #{name} not registered" unless service_class
    
    # Return singleton instance for the service
    @instances ||= {}
    @instances[name] ||= service_class.new
  end

  # Get real service with provider selection and fallback
  def get_real_service_with_fallback
    config = Rails.application.config
    
    # Get available providers sorted by priority
    available_providers = get_available_providers
    
    if available_providers.empty?
      Rails.logger.warn "No LLM providers available, falling back to mock service"
      return get_mock_service if config.llm_fallback_enabled
      raise StandardError, "No LLM providers available and fallback disabled"
    end
    
    # Try providers in priority order
    available_providers.each do |provider_name|
      begin
        return get_provider_service(provider_name) if circuit_breaker_allows?(provider_name)
      rescue StandardError => e
        record_failure(provider_name, e)
        Rails.logger.warn "Provider #{provider_name} failed: #{e.message}"
      end
    end
    
    # All providers failed, fallback to mock if enabled
    if config.llm_fallback_enabled
      Rails.logger.error "All LLM providers failed, falling back to mock service"
      return get_mock_service
    end
    
    raise StandardError, "All LLM providers failed and fallback disabled"
  end

  # Check if service is registered
  # @param [Symbol] name - service name
  # @return [Boolean]
  def registered?(name)
    @services.key?(name)
  end

  # List all registered services
  # @return [Array<Symbol>] service names
  def registered_services
    @services.keys
  end

  # Clear all registrations (primarily for testing)
  def clear!
    @services.clear
    @instances&.clear
    @circuit_breakers.clear
  end

  # Get configuration status for debugging
  def configuration_status
    config = Rails.application.config
    {
      feature_flags: config.llm_feature_flags,
      service_type: config.llm_service_type,
      available_providers: get_available_providers,
      circuit_breaker_states: @circuit_breakers,
      registered_services: registered_services
    }
  end

  private

  def get_mock_service
    @instances ||= {}
    @instances[:mock] ||= @services[:mock]&.new || 
      raise(ArgumentError, "Mock service not registered")
  end

  def get_available_providers
    config = Rails.application.config
    providers = config.llm_providers.select { |name, provider_config| 
      provider_config[:enabled] && provider_config[:api_key].present?
    }
    
    # Sort by priority (lower number = higher priority)
    providers.sort_by { |name, provider_config| provider_config[:priority] }.map(&:first)
  end

  def get_provider_service(provider_name)
    # Get provider-specific service configuration
    provider_config = Rails.application.config.llm_providers[provider_name]
    return nil unless provider_config && provider_config[:enabled]
    
    # Map provider names to service classes
    service_mapping = {
      openai: :openai,
      anthropic: :anthropic
    }
    
    service_key = service_mapping[provider_name]
    return nil unless service_key && @services[service_key]
    
    # Create instance with provider configuration
    @instances ||= {}
    @instances["#{provider_name}_service".to_sym] ||= @services[service_key].new(provider_config)
  end

  def circuit_breaker_allows?(provider_name)
    config = Rails.application.config
    breaker = @circuit_breakers[provider_name]
    return true unless breaker

    case breaker[:state]
    when :closed
      true
    when :open
      # Check if enough time has passed to try again
      if breaker[:last_failure] && 
         (Time.current - breaker[:last_failure]) > config.llm_circuit_breaker_timeout
        @circuit_breakers[provider_name][:state] = :half_open
        true
      else
        false
      end
    when :half_open
      true
    end
  end

  def record_failure(provider_name, error)
    config = Rails.application.config
    breaker = @circuit_breakers[provider_name]
    return unless breaker

    breaker[:failure_count] += 1
    breaker[:last_failure] = Time.current

    # Open circuit breaker if threshold reached
    if breaker[:failure_count] >= config.llm_circuit_breaker_threshold
      breaker[:state] = :open
      Rails.logger.error "Circuit breaker opened for provider #{provider_name}"
    end

    # Log the failure
    Rails.logger.error "LLM Provider #{provider_name} error: #{error.message}" if config.llm_debug_logging
  end

  def record_success(provider_name)
    breaker = @circuit_breakers[provider_name]
    return unless breaker

    # Reset failure count and close circuit breaker
    breaker[:failure_count] = 0
    breaker[:state] = :closed
  end
end

# Configuration for LLM service selection
Rails.application.configure do
  # Feature flags for LLM service control
  config.llm_feature_flags = {
    # Global LLM feature toggle
    enabled: ENV.fetch('LLM_ENABLED', Rails.env.production? ? 'true' : 'false') == 'true',
    
    # Service type selection
    use_real_service: ENV.fetch('USE_REAL_LLM', 'false') == 'true',
    
    # Provider-specific flags
    openai_enabled: ENV['OPENAI_API_KEY'].present? && ENV.fetch('OPENAI_ENABLED', 'true') == 'true',
    anthropic_enabled: ENV['ANTHROPIC_API_KEY'].present? && ENV.fetch('ANTHROPIC_ENABLED', 'true') == 'true',
    
    # Fallback behavior
    fallback_enabled: ENV.fetch('LLM_FALLBACK_ENABLED', 'true') == 'true',
    strict_mode: ENV.fetch('LLM_STRICT_MODE', 'false') == 'true'
  }

  # Service type determination with enhanced logic
  config.llm_service_type = if config.llm_feature_flags[:enabled] && config.llm_feature_flags[:use_real_service]
                              :real
                            else
                              :mock
                            end

  # Enhanced LLM provider configuration
  config.llm_providers = {
    openai: {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV['OPENAI_MODEL'] || 'gpt-4',
      endpoint: ENV['OPENAI_ENDPOINT'],
      enabled: config.llm_feature_flags[:openai_enabled],
      priority: ENV.fetch('OPENAI_PRIORITY', '1').to_i,
      max_tokens: ENV.fetch('OPENAI_MAX_TOKENS', '4000').to_i,
      temperature: ENV.fetch('OPENAI_TEMPERATURE', '0.7').to_f
    },
    anthropic: {
      api_key: ENV['ANTHROPIC_API_KEY'],
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-sonnet-20240229',
      endpoint: ENV['ANTHROPIC_ENDPOINT'],
      enabled: config.llm_feature_flags[:anthropic_enabled],
      priority: ENV.fetch('ANTHROPIC_PRIORITY', '2').to_i,
      max_tokens: ENV.fetch('ANTHROPIC_MAX_TOKENS', '4000').to_i,
      temperature: ENV.fetch('ANTHROPIC_TEMPERATURE', '0.7').to_f
    },
    google: {
      api_key: ENV['GOOGLE_AI_API_KEY'],
      model: ENV['GOOGLE_AI_MODEL'] || 'gemini-pro',
      endpoint: ENV['GOOGLE_AI_ENDPOINT'],
      enabled: ENV['GOOGLE_AI_API_KEY'].present? && ENV.fetch('GOOGLE_AI_ENABLED', 'false') == 'true',
      priority: ENV.fetch('GOOGLE_AI_PRIORITY', '3').to_i,
      max_tokens: ENV.fetch('GOOGLE_AI_MAX_TOKENS', '4000').to_i,
      temperature: ENV.fetch('GOOGLE_AI_TEMPERATURE', '0.7').to_f
    }
  }

  # Enhanced fallback and resilience configuration
  config.llm_fallback_enabled = config.llm_feature_flags[:fallback_enabled]
  config.llm_timeout = ENV.fetch('LLM_TIMEOUT', '30').to_i.seconds
  config.llm_retry_attempts = ENV.fetch('LLM_RETRY_ATTEMPTS', '3').to_i
  config.llm_retry_delay = ENV.fetch('LLM_RETRY_DELAY', '1').to_i.seconds
  config.llm_circuit_breaker_threshold = ENV.fetch('LLM_CIRCUIT_BREAKER_THRESHOLD', '5').to_i
  config.llm_circuit_breaker_timeout = ENV.fetch('LLM_CIRCUIT_BREAKER_TIMEOUT', '60').to_i.seconds

  # Monitoring and debugging
  config.llm_monitoring_enabled = ENV.fetch('LLM_MONITORING_ENABLED', Rails.env.development? ? 'true' : 'false') == 'true'
  config.llm_debug_logging = ENV.fetch('LLM_DEBUG_LOGGING', Rails.env.development? ? 'true' : 'false') == 'true'
  config.llm_performance_tracking = ENV.fetch('LLM_PERFORMANCE_TRACKING', 'true') == 'true'
end

# Include helper in controllers and services
ActiveSupport.on_load(:action_controller) do
  include LlmServiceHelper
end

# Register services after application loads
Rails.application.configure do
  config.after_initialize do
    # Register the mock LLM service
    LlmServiceContainer.register(:mock, MockLlmService)
    
    # Register real LLM provider services
    LlmServiceContainer.register(:openai, LlmProviders::OpenaiProvider)
    # LlmServiceContainer.register(:anthropic, LlmProviders::AnthropicProvider)  # TODO: Implement Anthropic provider
    
    # Register real service as primary OpenAI provider
    LlmServiceContainer.register(:real, LlmProviders::OpenaiProvider)
  end
end