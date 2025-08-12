# Base service for generating marketing content across different channels
# Uses adapter pattern to support multiple content types and channels
class ContentGeneratorBase
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Content generation error classes
  class ContentGenerationError < StandardError; end
  class ChannelNotSupportedError < ContentGenerationError; end
  class AdapterNotFoundError < ContentGenerationError; end
  class InvalidContentRequestError < ContentGenerationError; end
  class ContentValidationError < ContentGenerationError; end

  # Configuration attributes
  attribute :ai_service
  attribute :brand_context, default: -> { {} }
  attribute :default_options, default: -> { {} }

  # Channel adapters registry
  @channel_adapters = {}
  @adapter_configurations = {}

  class << self
    attr_reader :channel_adapters, :adapter_configurations

    # Register a channel adapter
    def register_adapter(channel_type, adapter_class, configuration = {})
      @channel_adapters[channel_type.to_sym] = adapter_class
      @adapter_configurations[channel_type.to_sym] = configuration
    end

    # Get available channel types
    def supported_channels
      @channel_adapters.keys
    end

    # Check if channel is supported
    def supports_channel?(channel_type)
      @channel_adapters.key?(channel_type.to_sym)
    end

    # Get adapter for channel
    def adapter_for_channel(channel_type)
      @channel_adapters[channel_type.to_sym]
    end

    # Get configuration for channel
    def configuration_for_channel(channel_type)
      @adapter_configurations[channel_type.to_sym] || {}
    end
  end

  def initialize(attributes = {})
    super(attributes)
    @ai_service ||= AiServiceFactory.create
    validate_configuration!
  end

  # Main content generation interface
  def generate_content(request)
    validate_request!(request)
    
    channel_type = request.channel_type.to_sym
    raise ChannelNotSupportedError, "Channel '#{channel_type}' is not supported" unless self.class.supports_channel?(channel_type)

    adapter_class = self.class.adapter_for_channel(channel_type)
    adapter_config = self.class.configuration_for_channel(channel_type)
    
    adapter = adapter_class.new(
      ai_service: @ai_service,
      brand_context: brand_context,
      configuration: adapter_config.merge(default_options)
    )

    # Generate content using the adapter
    response = adapter.generate_content(request)
    
    # Validate generated content
    validate_content_response!(response, request)
    
    response
  end

  # Generate multiple content variants (A/B testing)
  def generate_variants(request, variant_count: 3)
    validate_request!(request)
    
    variants = []
    variant_count.times do |index|
      variant_request = request.dup
      variant_request.variant_context = {
        variant_index: index + 1,
        total_variants: variant_count,
        variant_strategy: determine_variant_strategy(request, index)
      }
      
      variants << generate_content(variant_request)
    end
    
    variants
  end

  # Batch content generation for multiple channels
  def generate_multi_channel_content(base_request, channel_types)
    results = {}
    
    channel_types.each do |channel_type|
      begin
        channel_request = adapt_request_for_channel(base_request, channel_type)
        results[channel_type] = generate_content(channel_request)
      rescue => e
        results[channel_type] = { error: e.message, channel: channel_type }
      end
    end
    
    results
  end

  # Content optimization suggestions
  def optimize_content(content, channel_type, performance_data = {})
    adapter_class = self.class.adapter_for_channel(channel_type.to_sym)
    adapter = adapter_class.new(
      ai_service: @ai_service,
      brand_context: brand_context
    )
    
    adapter.optimize_content(content, performance_data)
  end

  private

  def validate_configuration!
    raise ContentGenerationError, "AI service is required" unless @ai_service
    raise ContentGenerationError, "AI service must respond to generate_content_for_channel" unless @ai_service.respond_to?(:generate_content_for_channel)
  end

  def validate_request!(request)
    raise InvalidContentRequestError, "Request must be a ContentRequest object" unless request.is_a?(ContentRequest)
    raise InvalidContentRequestError, "Channel type is required" if request.channel_type.blank?
    raise InvalidContentRequestError, "Content type is required" if request.content_type.blank?
    raise InvalidContentRequestError, "Brand context is required" if request.brand_context.blank?
  end

  def validate_content_response!(response, request)
    raise ContentValidationError, "Response must be a ContentResponse object" unless response.is_a?(ContentResponse)
    raise ContentValidationError, "Generated content is empty" if response.content.blank?
    raise ContentValidationError, "Response channel type mismatch" unless response.channel_type == request.channel_type
  end

  def determine_variant_strategy(request, index)
    strategies = [:tone_variation, :structure_variation, :cta_variation, :length_variation]
    strategies[index % strategies.length]
  end

  def adapt_request_for_channel(base_request, channel_type)
    adapted_request = base_request.dup
    adapted_request.channel_type = channel_type
    
    # Apply channel-specific adaptations
    channel_config = self.class.configuration_for_channel(channel_type)
    if channel_config[:max_length]
      adapted_request.constraints[:max_length] = channel_config[:max_length]
    end
    
    adapted_request
  end
end