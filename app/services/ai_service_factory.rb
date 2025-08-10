# Factory for creating AI service instances based on provider configuration
# Supports multiple providers: OpenAI, Anthropic, etc.
class AIServiceFactory
  include Singleton

  # Provider configuration
  SUPPORTED_PROVIDERS = {
    openai: {
      class_name: "OpenAIService",
      models: {
        "gpt-4o" => { max_tokens: 128000, supports_images: true, supports_functions: true },
        "gpt-4o-mini" => { max_tokens: 128000, supports_images: true, supports_functions: true },
        "gpt-4-turbo" => { max_tokens: 128000, supports_images: true, supports_functions: true },
        "gpt-3.5-turbo" => { max_tokens: 16385, supports_images: false, supports_functions: true }
      }
    },
    anthropic: {
      class_name: "AnthropicService", 
      models: {
        "claude-3-5-sonnet-20241022" => { max_tokens: 200000, supports_images: true, supports_functions: true },
        "claude-3-5-haiku-20241022" => { max_tokens: 200000, supports_images: true, supports_functions: true },
        "claude-3-opus-20240229" => { max_tokens: 200000, supports_images: true, supports_functions: true }
      }
    },
    gemini: {
      class_name: "GeminiService",
      models: {
        "gemini-2.0-flash-exp" => { max_tokens: 2000000, supports_images: true, supports_functions: true },
        "gemini-1.5-pro" => { max_tokens: 2000000, supports_images: true, supports_functions: true },
        "gemini-1.5-flash" => { max_tokens: 1000000, supports_images: true, supports_functions: true }
      }
    }
  }.freeze

  class ProviderNotSupportedError < StandardError; end
  class ModelNotSupportedError < StandardError; end
  class ConfigurationError < StandardError; end

  # Create AI service instance for the given provider and model
  def self.create(provider: nil, model: nil, **options)
    instance.create_service(provider: provider, model: model, **options)
  end

  # Get the default provider/model configuration
  def self.default_config
    {
      provider: Rails.application.config.ai_service&.dig(:default_provider) || :anthropic,
      model: Rails.application.config.ai_service&.dig(:default_model) || "claude-3-5-sonnet-20241022"
    }
  end

  # Check if provider/model combination is supported
  def self.supported?(provider:, model:)
    return false unless SUPPORTED_PROVIDERS.key?(provider.to_sym)
    SUPPORTED_PROVIDERS[provider.to_sym][:models].key?(model.to_s)
  end

  # Get available providers and their models
  def self.available_providers
    SUPPORTED_PROVIDERS.transform_values { |config| config[:models].keys }
  end

  # Get model capabilities
  def self.model_capabilities(provider:, model:)
    provider_config = SUPPORTED_PROVIDERS[provider.to_sym]
    return nil unless provider_config
    
    provider_config[:models][model.to_s]
  end

  def create_service(provider: nil, model: nil, **options)
    # Use defaults if not specified
    config = self.class.default_config
    provider ||= config[:provider]
    model ||= config[:model]

    # Validate provider and model
    provider_sym = provider.to_sym
    raise ProviderNotSupportedError, "Provider '#{provider}' is not supported" unless SUPPORTED_PROVIDERS.key?(provider_sym)
    raise ModelNotSupportedError, "Model '#{model}' is not supported for provider '#{provider}'" unless SUPPORTED_PROVIDERS[provider_sym][:models].key?(model.to_s)

    # Get provider configuration
    provider_config = SUPPORTED_PROVIDERS[provider_sym]
    model_config = provider_config[:models][model.to_s]
    service_class_name = provider_config[:class_name]

    # Build service options
    service_options = {
      provider_name: provider.to_s,
      model_name: model.to_s,
      max_context_tokens: model_config[:max_tokens],
      **options
    }

    # Add provider-specific configuration
    case provider_sym
    when :openai
      service_options[:api_key] = get_api_key(:openai)
      service_options[:api_base_url] = "https://api.openai.com/v1"
    when :anthropic
      service_options[:api_key] = get_api_key(:anthropic)
      service_options[:api_base_url] = "https://api.anthropic.com"
    when :gemini
      service_options[:api_key] = get_api_key(:gemini)
      service_options[:api_base_url] = "https://generativelanguage.googleapis.com/v1beta"
    end

    # Create the service instance
    service_class = service_class_name.constantize
    service_instance = service_class.new(service_options)
    
    # Validate configuration
    service_instance.validate_configuration
    
    service_instance
  rescue NameError => e
    raise ConfigurationError, "Service class '#{service_class_name}' not found: #{e.message}"
  end

  private

  def get_api_key(provider)
    case provider
    when :openai
      Rails.application.credentials.openai&.api_key || 
      ENV["OPENAI_API_KEY"] ||
      raise(ConfigurationError, "OpenAI API key not configured")
    when :anthropic
      Rails.application.credentials.anthropic&.api_key || 
      ENV["ANTHROPIC_API_KEY"] ||
      raise(ConfigurationError, "Anthropic API key not configured")
    when :gemini
      Rails.application.credentials.google&.api_key || 
      ENV["GOOGLE_API_KEY"] ||
      raise(ConfigurationError, "Google API key not configured")
    else
      raise ConfigurationError, "Unknown provider: #{provider}"
    end
  end
end