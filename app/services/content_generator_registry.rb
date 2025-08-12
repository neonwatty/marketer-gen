# Registry service for managing content generator adapters and their configurations
# Provides dependency injection and factory pattern for creating channel adapters
class ContentGeneratorRegistry
  include Singleton

  # Configuration and registry storage
  @adapters = {}
  @configurations = {}
  @default_ai_service_config = {}

  class << self
    attr_accessor :adapters, :configurations, :default_ai_service_config
  end

  class AdapterNotRegisteredError < StandardError; end
  class ConfigurationError < StandardError; end
  class AdapterLoadError < StandardError; end

  def initialize
    setup_default_configurations
    register_default_adapters
  end

  # Register a content adapter for a specific channel
  def self.register_adapter(channel_type, adapter_class, configuration = {})
    instance.register_adapter(channel_type, adapter_class, configuration)
  end

  def register_adapter(channel_type, adapter_class, configuration = {})
    channel_key = channel_type.to_sym
    
    # Validate adapter class
    unless adapter_class.ancestors.include?(ContentAdapters::BaseChannelAdapter)
      raise AdapterLoadError, "Adapter class must inherit from ContentAdapters::BaseChannelAdapter"
    end
    
    # Store adapter and configuration
    self.class.adapters[channel_key] = adapter_class
    self.class.configurations[channel_key] = configuration.deep_merge(
      default_configuration_for_channel(channel_key)
    )
    
    Rails.logger.info "Registered content adapter: #{channel_key} -> #{adapter_class.name}"
  end

  # Get an adapter instance for a channel
  def self.adapter_for(channel_type, options = {})
    instance.adapter_for(channel_type, options)
  end

  def adapter_for(channel_type, options = {})
    channel_key = channel_type.to_sym
    
    # Check if adapter is registered
    adapter_class = self.class.adapters[channel_key]
    raise AdapterNotRegisteredError, "No adapter registered for channel: #{channel_type}" unless adapter_class
    
    # Get configuration
    base_config = self.class.configurations[channel_key] || {}
    merged_config = base_config.deep_merge(options)
    
    # Create AI service if not provided
    ai_service = merged_config.delete(:ai_service) || create_ai_service(merged_config[:ai_service_config] || {})
    
    # Create adapter instance
    adapter_class.new(
      ai_service: ai_service,
      brand_context: merged_config[:brand_context] || {},
      configuration: merged_config
    )
  end

  # Get all supported channel types
  def self.supported_channels
    instance.supported_channels
  end

  def supported_channels
    self.class.adapters.keys
  end

  # Check if a channel is supported
  def self.supports_channel?(channel_type)
    instance.supports_channel?(channel_type)
  end

  def supports_channel?(channel_type)
    self.class.adapters.key?(channel_type.to_sym)
  end

  # Get configuration for a channel
  def self.configuration_for(channel_type)
    instance.configuration_for(channel_type)
  end

  def configuration_for(channel_type)
    self.class.configurations[channel_type.to_sym] || {}
  end

  # Update configuration for a channel
  def self.update_configuration(channel_type, new_config)
    instance.update_configuration(channel_type, new_config)
  end

  def update_configuration(channel_type, new_config)
    channel_key = channel_type.to_sym
    existing_config = self.class.configurations[channel_key] || {}
    self.class.configurations[channel_key] = existing_config.deep_merge(new_config)
  end

  # Get adapter capabilities
  def self.adapter_capabilities(channel_type)
    instance.adapter_capabilities(channel_type)
  end

  def adapter_capabilities(channel_type)
    adapter_class = self.class.adapters[channel_type.to_sym]
    return {} unless adapter_class
    
    # Create a temporary instance to query capabilities
    temp_adapter = adapter_class.allocate
    temp_adapter.send(:setup_channel_metadata)
    
    {
      channel_type: temp_adapter.channel_type,
      supported_content_types: temp_adapter.supported_content_types,
      constraints: temp_adapter.constraints,
      supports_variants: temp_adapter.supports_variants?,
      supports_optimization: temp_adapter.supports_optimization?,
      max_content_length: temp_adapter.max_content_length,
      min_content_length: temp_adapter.min_content_length
    }
  end

  # Set default AI service configuration
  def self.configure_ai_service(config)
    instance.configure_ai_service(config)
  end

  def configure_ai_service(config)
    self.class.default_ai_service_config = config
  end

  # Health check for all registered adapters
  def self.health_check
    instance.health_check
  end

  def health_check
    results = {}
    
    self.class.adapters.each do |channel_type, adapter_class|
      begin
        adapter = adapter_for(channel_type)
        results[channel_type] = {
          status: :healthy,
          adapter_class: adapter_class.name,
          ai_service_healthy: adapter.ai_service&.healthy? || false
        }
      rescue => e
        results[channel_type] = {
          status: :error,
          error: e.message,
          adapter_class: adapter_class.name
        }
      end
    end
    
    results
  end

  # Load adapters from configuration
  def self.load_from_config(config_hash)
    instance.load_from_config(config_hash)
  end

  def load_from_config(config_hash)
    config_hash.each do |channel_type, adapter_config|
      adapter_class_name = adapter_config[:adapter_class] || "ContentAdapters::#{channel_type.to_s.classify}Adapter"
      
      begin
        adapter_class = adapter_class_name.constantize
        configuration = adapter_config.except(:adapter_class)
        register_adapter(channel_type, adapter_class, configuration)
      rescue NameError => e
        Rails.logger.error "Failed to load adapter for #{channel_type}: #{e.message}"
      end
    end
  end

  # Export current configuration
  def self.export_config
    instance.export_config
  end

  def export_config
    {
      adapters: self.class.adapters.transform_values(&:name),
      configurations: self.class.configurations,
      ai_service_config: self.class.default_ai_service_config
    }
  end

  private

  def setup_default_configurations
    self.class.default_ai_service_config = {
      provider: :anthropic,
      model: "claude-3-5-sonnet-20241022",
      temperature: 0.7,
      max_tokens: 2000
    }
  end

  def register_default_adapters
    # Register built-in adapters
    default_adapters = {
      social_media: {
        adapter_class: 'ContentAdapters::SocialMediaAdapter',
        max_length: 280,
        supports_hashtags: true,
        supports_mentions: true
      },
      email: {
        adapter_class: 'ContentAdapters::EmailAdapter',
        max_subject_length: 50,
        supports_personalization: true,
        supports_html: true
      },
      ads: {
        adapter_class: 'ContentAdapters::AdsAdapter',
        headline_max_length: 30,
        description_max_length: 90,
        requires_cta: true
      },
      landing_page: {
        adapter_class: 'ContentAdapters::LandingPageAdapter',
        supports_sections: true,
        supports_media: true,
        min_length: 300
      },
      video_script: {
        adapter_class: 'ContentAdapters::VideoScriptAdapter',
        supports_scene_breaks: true,
        supports_timing: true
      },
      blog: {
        adapter_class: 'ContentAdapters::BlogAdapter',
        min_length: 800,
        supports_seo: true,
        supports_tags: true
      }
    }

    # Only register adapters that have actual implementation classes
    default_adapters.each do |channel_type, config|
      begin
        adapter_class = config[:adapter_class].constantize
        configuration = config.except(:adapter_class)
        register_adapter(channel_type, adapter_class, configuration)
      rescue NameError
        # Skip adapters that don't have implementation yet
        Rails.logger.debug "Skipping registration of #{channel_type} adapter - class not found: #{config[:adapter_class]}"
      end
    end
  end

  def default_configuration_for_channel(channel_type)
    case channel_type.to_sym
    when :social_media
      {
        max_length: 280,
        supports_hashtags: true,
        supports_mentions: true,
        optimal_hashtag_count: 3,
        engagement_optimization: true
      }
    when :email
      {
        max_subject_length: 50,
        max_body_length: 2000,
        supports_personalization: true,
        supports_html: true,
        conversion_optimization: true
      }
    when :ads
      {
        headline_max_length: 30,
        description_max_length: 90,
        requires_cta: true,
        supports_targeting: true,
        conversion_focused: true
      }
    when :landing_page
      {
        min_length: 300,
        max_length: 2000,
        supports_sections: true,
        supports_media: true,
        seo_optimization: true
      }
    when :video_script
      {
        min_length: 100,
        max_length: 500,
        supports_scene_breaks: true,
        supports_timing: true,
        target_duration: 60
      }
    when :blog
      {
        min_length: 800,
        max_length: 3000,
        supports_seo: true,
        supports_tags: true,
        readability_optimization: true
      }
    else
      {}
    end
  end

  def create_ai_service(service_config = {})
    merged_config = self.class.default_ai_service_config.merge(service_config)
    
    AiServiceFactory.create(
      provider: merged_config[:provider],
      model: merged_config[:model],
      temperature: merged_config[:temperature],
      max_tokens: merged_config[:max_tokens]
    )
  rescue => e
    raise ConfigurationError, "Failed to create AI service: #{e.message}"
  end
end