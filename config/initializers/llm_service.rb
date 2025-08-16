# frozen_string_literal: true

# LLM Service Dependency Injection Configuration
# This initializer sets up the dependency injection container for LLM services,
# allowing easy switching between mock and real implementations

module LlmServiceContainer
  extend self

  # Container for service instances
  @services = {}

  # Register a service implementation
  # @param [Symbol] name - service name
  # @param [Class] service_class - service class
  def register(name, service_class)
    @services[name] = service_class
  end

  # Get a service instance
  # @param [Symbol] name - service name
  # @return [Object] service instance
  def get(name)
    service_class = @services[name]
    raise ArgumentError, "Service #{name} not registered" unless service_class
    
    # Return singleton instance for the service
    @instances ||= {}
    @instances[name] ||= service_class.new
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
  end
end

# Configuration for LLM service selection
Rails.application.configure do
  # Default to mock service in development and test
  # Set to :real in production or when ENV['USE_REAL_LLM'] is true
  config.llm_service_type = if Rails.env.production? && ENV['USE_REAL_LLM'] == 'true'
                              :real
                            else
                              :mock
                            end

  # LLM provider configuration (for real implementations)
  config.llm_providers = {
    openai: {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV['OPENAI_MODEL'] || 'gpt-4',
      enabled: ENV['OPENAI_API_KEY'].present?
    },
    anthropic: {
      api_key: ENV['ANTHROPIC_API_KEY'],
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-sonnet-20240229',
      enabled: ENV['ANTHROPIC_API_KEY'].present?
    },
    # Add more providers as needed
  }

  # Fallback configuration
  config.llm_fallback_enabled = true
  config.llm_timeout = 30.seconds
  config.llm_retry_attempts = 3
end

# Helper method to access LLM service in the application
module LlmServiceHelper
  def llm_service
    service_type = Rails.application.config.llm_service_type
    LlmServiceContainer.get(service_type)
  rescue ArgumentError => e
    Rails.logger.error "LLM Service Error: #{e.message}"
    # Fallback to mock service if configured service is not available
    if service_type != :mock && LlmServiceContainer.registered?(:mock)
      Rails.logger.warn "Falling back to mock LLM service"
      LlmServiceContainer.get(:mock)
    else
      raise e
    end
  end
end

# Include helper in controllers and services
ActiveSupport.on_load(:action_controller) do
  include LlmServiceHelper
end

# Make it available in services too
class ApplicationService
  include LlmServiceHelper
end unless defined?(ApplicationService)

# Register services after application loads
Rails.application.configure do
  config.after_initialize do
    # Register the mock LLM service
    LlmServiceContainer.register(:mock, MockLlmService)
    
    # TODO: Register real LLM services when implemented
    # LlmServiceContainer.register(:real, RealLlmService)
  end
end