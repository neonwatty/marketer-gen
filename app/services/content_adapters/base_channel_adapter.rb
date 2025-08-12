# Abstract base class for channel-specific content generation adapters
# Each channel type (social media, email, ads, etc.) implements this interface
class ContentAdapters::BaseChannelAdapter
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Configuration attributes
  attribute :ai_service
  attribute :brand_context, default: -> { {} }
  attribute :configuration, default: -> { {} }

  # Channel metadata
  attr_reader :channel_type, :supported_content_types, :constraints

  def initialize(attributes = {})
    super(attributes)
    validate_configuration!
    setup_channel_metadata
  end

  # Abstract methods that must be implemented by subclasses
  def generate_content(request)
    raise NotImplementedError, "Subclasses must implement #generate_content"
  end

  def optimize_content(content, performance_data = {})
    raise NotImplementedError, "Subclasses must implement #optimize_content"
  end

  def validate_content(content, request)
    raise NotImplementedError, "Subclasses must implement #validate_content"
  end

  # Channel capability checks
  def supports_content_type?(content_type)
    supported_content_types.include?(content_type.to_s)
  end

  def supports_variants?
    true
  end

  def supports_optimization?
    true
  end

  def max_content_length
    constraints[:max_length] || 1000
  end

  def min_content_length
    constraints[:min_length] || 10
  end

  # Common content generation workflow
  def generate_content_with_validation(request)
    validate_request!(request)
    
    # Pre-process request
    processed_request = preprocess_request(request)
    
    # Generate content
    response = generate_content(processed_request)
    
    # Post-process response
    processed_response = postprocess_response(response, processed_request)
    
    # Validate generated content
    validate_content(processed_response.content, processed_request)
    
    processed_response
  end

  # Content adaptation for channel-specific requirements
  def adapt_content_for_channel(base_content, request)
    adapted_content = base_content.dup
    
    # Apply channel-specific formatting
    adapted_content = apply_channel_formatting(adapted_content, request)
    
    # Apply length constraints
    adapted_content = apply_length_constraints(adapted_content, request)
    
    # Apply channel-specific enhancements
    adapted_content = apply_channel_enhancements(adapted_content, request)
    
    adapted_content
  end

  # A/B variant generation
  def generate_variants(request, count: 3)
    variants = []
    
    count.times do |index|
      variant_request = request.dup
      variant_request.variant_context = {
        variant_index: index + 1,
        total_variants: count,
        strategy: variant_strategies[index % variant_strategies.length]
      }
      
      variants << generate_content_with_validation(variant_request)
    end
    
    variants
  end

  protected

  # Template method for setting up channel-specific metadata
  def setup_channel_metadata
    @channel_type = self.class.name.demodulize.gsub(/Adapter$/, '').underscore
    @supported_content_types = default_supported_content_types
    @constraints = default_constraints.merge(configuration[:constraints] || {})
  end

  # Default implementations that can be overridden
  def default_supported_content_types
    %w[post article announcement promotional educational]
  end

  def default_constraints
    {
      max_length: 1000,
      min_length: 10,
      max_hashtags: 5,
      max_mentions: 3
    }
  end

  def variant_strategies
    [:tone_variation, :structure_variation, :cta_variation, :length_variation]
  end

  # Request/Response processing hooks
  def preprocess_request(request)
    processed_request = request.dup
    
    # Add channel-specific context
    processed_request.channel_metadata = processed_request.channel_metadata.merge({
      adapter_type: self.class.name,
      generation_timestamp: Time.current.iso8601,
      constraints: constraints
    })
    
    # Apply brand context specific to this channel
    processed_request.brand_context = enhance_brand_context(processed_request.brand_context)
    
    processed_request
  end

  def postprocess_response(response, request)
    return response unless response.is_a?(ContentResponse)
    
    # Set channel-specific metadata
    response.channel_type = channel_type
    response.channel_specific_data = build_channel_specific_data(response, request)
    
    # Calculate channel-specific metrics
    response.quality_score = calculate_quality_score(response, request)
    response.engagement_prediction = predict_engagement(response, request)
    
    response
  end

  # Channel-specific formatting methods
  def apply_channel_formatting(content, request)
    content # Base implementation returns unchanged content
  end

  def apply_length_constraints(content, request)
    max_len = request.constraints[:max_length] || max_content_length
    min_len = request.constraints[:min_length] || min_content_length
    
    # Truncate if too long
    if content.length > max_len
      content = truncate_content(content, max_len)
    end
    
    # Expand if too short
    if content.length < min_len
      content = expand_content(content, min_len, request)
    end
    
    content
  end

  def apply_channel_enhancements(content, request)
    enhanced_content = content.dup
    
    # Add call-to-action if missing and required
    if requires_call_to_action?(request) && !has_call_to_action?(enhanced_content)
      enhanced_content = add_call_to_action(enhanced_content, request)
    end
    
    # Add channel-specific elements
    enhanced_content = add_channel_specific_elements(enhanced_content, request)
    
    enhanced_content
  end

  # Content manipulation utilities
  def truncate_content(content, max_length)
    return content if content.length <= max_length
    
    # Try to truncate at sentence boundary
    truncated = content[0...max_length]
    last_sentence_end = truncated.rindex(/[.!?]/)
    
    if last_sentence_end && last_sentence_end > max_length * 0.7
      truncated[0..last_sentence_end]
    else
      "#{content[0...max_length-3]}..."
    end
  end

  def expand_content(content, min_length, request)
    return content if content.length >= min_length
    
    # Add relevant expansion based on content type and brand context
    expansion_context = {
      brand_name: brand_context[:name],
      industry: brand_context[:industry],
      target_audience: request.target_audience
    }
    
    expansion = generate_content_expansion(expansion_context, min_length - content.length)
    "#{content} #{expansion}"
  end

  def generate_content_expansion(context, target_length)
    # Simple expansion - in a real implementation, this would use AI
    if target_length < 20
      "Learn more today!"
    elsif target_length < 50
      "Discover how #{context[:brand_name]} can help you achieve your goals."
    else
      "Join thousands of satisfied customers who trust #{context[:brand_name]} for #{context[:industry]} solutions. Contact us today to get started!"
    end
  end

  # Call-to-action utilities
  def requires_call_to_action?(request)
    promotional_types = %w[promotional advertisement marketing_campaign]
    promotional_types.include?(request.content_type) || 
    request.optimization_goals.include?('conversion') ||
    request.campaign_context[:requires_cta]
  end

  def has_call_to_action?(content)
    cta_patterns = [
      /\b(learn more|get started|sign up|contact us|buy now|shop now|discover|try now)\b/i,
      /\b(call|click|visit|download|subscribe|join)\b/i
    ]
    
    cta_patterns.any? { |pattern| content.match?(pattern) }
  end

  def add_call_to_action(content, request)
    cta = generate_call_to_action(request)
    "#{content} #{cta}"
  end

  def generate_call_to_action(request)
    case request.optimization_goals.first&.to_s
    when 'conversion'
      "Get started today!"
    when 'engagement'
      "What do you think? Let us know!"
    when 'awareness'
      "Learn more about our solutions!"
    else
      "Contact us to learn more!"
    end
  end

  def add_channel_specific_elements(content, request)
    content # Base implementation returns unchanged content
  end

  # Quality and engagement calculation
  def calculate_quality_score(response, request)
    score = 0.5 # Base score
    
    # Length appropriateness
    if response.character_count >= min_content_length && response.character_count <= max_content_length
      score += 0.2
    end
    
    # Keyword relevance (simplified)
    brand_keywords = extract_brand_keywords(brand_context)
    keyword_score = calculate_keyword_relevance(response.content, brand_keywords)
    score += keyword_score * 0.3
    
    [score, 1.0].min
  end

  def predict_engagement(response, request)
    # Simple engagement prediction based on content characteristics
    base_score = 0.4
    
    # Boost for questions
    base_score += 0.1 if response.content.include?('?')
    
    # Boost for call-to-action
    base_score += 0.15 if has_call_to_action?(response.content)
    
    # Boost for optimal length
    if response.character_count >= min_content_length && response.character_count <= max_content_length
      base_score += 0.1
    end
    
    # Channel-specific engagement factors
    base_score += calculate_channel_engagement_factors(response, request)
    
    [base_score, 1.0].min
  end

  # Helper methods
  def enhance_brand_context(original_context)
    enhanced_context = original_context.dup
    
    # Add channel-specific brand guidelines if available
    if brand_context.dig(:channels, channel_type.to_sym)
      enhanced_context.merge!(brand_context[:channels][channel_type.to_sym])
    end
    
    enhanced_context
  end

  def build_channel_specific_data(response, request)
    {
      channel_type: channel_type,
      adapter_version: "1.0",
      generation_metadata: {
        constraints_applied: constraints,
        enhancements_applied: []
      }
    }
  end

  def extract_brand_keywords(context)
    keywords = []
    keywords << context[:name] if context[:name]
    keywords << context[:industry] if context[:industry]
    keywords += context[:keywords] if context[:keywords].is_a?(Array)
    keywords.compact.uniq
  end

  def calculate_keyword_relevance(content, keywords)
    return 0.0 if keywords.empty?
    
    content_words = content.downcase.split(/\W+/)
    keyword_matches = keywords.count { |keyword| content_words.include?(keyword.downcase) }
    
    keyword_matches.to_f / keywords.length
  end

  def calculate_channel_engagement_factors(response, request)
    0.0 # Base implementation - override in subclasses
  end

  private

  def validate_configuration!
    raise ArgumentError, "AI service is required" unless ai_service
    raise ArgumentError, "Brand context is required" if brand_context.blank?
  end

  def validate_request!(request)
    raise ArgumentError, "Request must be a ContentRequest" unless request.is_a?(ContentRequest)
    raise ArgumentError, "Unsupported content type: #{request.content_type}" unless supports_content_type?(request.content_type)
  end
end