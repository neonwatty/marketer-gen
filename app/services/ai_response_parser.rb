# AI Response Parser for different provider formats
# Handles parsing and normalizing responses from various AI providers
class AiResponseParser
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Supported provider response formats
  SUPPORTED_PROVIDERS = %w[anthropic openai google azure].freeze
  
  # Response content types
  CONTENT_TYPES = %w[
    text 
    json 
    structured_data 
    campaign_plan 
    brand_analysis 
    content_generation
    optimization_suggestions
  ].freeze

  class ParseError < StandardError; end
  class UnsupportedProviderError < ParseError; end
  class InvalidResponseError < ParseError; end
  class StructureValidationError < ParseError; end

  attribute :provider, :string
  attribute :response_type, :string, default: 'text'
  attribute :strict_validation, :boolean, default: false

  def initialize(attributes = {})
    super(attributes)
    validate_configuration!
  end

  # Parse response based on provider and expected type
  def parse(raw_response, options = {})
    return nil if raw_response.blank?
    
    parsed_response = case provider&.downcase
    when 'anthropic', 'claude'
      parse_anthropic_response(raw_response)
    when 'openai', 'gpt'
      parse_openai_response(raw_response)
    when 'google', 'gemini', 'palm'
      parse_google_response(raw_response)
    when 'azure'
      parse_azure_response(raw_response)
    else
      parse_generic_response(raw_response)
    end

    # Extract content based on response type
    extracted_content = extract_content_by_type(parsed_response, options)
    
    # Validate structure if strict validation is enabled
    validate_extracted_content!(extracted_content, options) if strict_validation
    
    # Return normalized response
    {
      provider: provider,
      response_type: response_type,
      content: extracted_content,
      metadata: extract_metadata(parsed_response),
      parsed_at: Time.current,
      original_format: detect_original_format(raw_response)
    }
  rescue => error
    Rails.logger.error "AI response parsing failed: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if error.respond_to?(:backtrace)
    
    # Return error response
    {
      provider: provider,
      response_type: 'error',
      content: nil,
      error: {
        type: error.class.name,
        message: error.message,
        occurred_at: Time.current
      },
      metadata: { parsing_failed: true },
      parsed_at: Time.current
    }
  end

  # Parse multiple responses in batch
  def parse_batch(responses, options = {})
    responses.map.with_index do |response, index|
      begin
        parse(response, options.merge(batch_index: index))
      rescue => error
        Rails.logger.error "Batch parsing failed for item #{index}: #{error.message}"
        {
          provider: provider,
          response_type: 'error',
          content: nil,
          error: { type: error.class.name, message: error.message },
          batch_index: index,
          parsed_at: Time.current
        }
      end
    end
  end

  # Check if response can be parsed by this parser
  def can_parse?(raw_response)
    return false if raw_response.blank?
    
    case provider&.downcase
    when 'anthropic', 'claude'
      anthropic_response?(raw_response)
    when 'openai', 'gpt'
      openai_response?(raw_response)
    when 'google', 'gemini', 'palm'
      google_response?(raw_response)
    when 'azure'
      azure_response?(raw_response)
    else
      true # Generic parser accepts anything
    end
  rescue
    false
  end

  private

  def validate_configuration!
    if provider.present? && !SUPPORTED_PROVIDERS.include?(provider.downcase)
      raise UnsupportedProviderError, "Unsupported provider: #{provider}"
    end
    
    if response_type.present? && !CONTENT_TYPES.include?(response_type.downcase)
      raise InvalidResponseError, "Unsupported response type: #{response_type}"
    end
  end

  # Provider-specific parsing methods

  def parse_anthropic_response(raw_response)
    if raw_response.is_a?(Hash)
      # Anthropic API response format
      if raw_response.dig('content')&.is_a?(Array)
        # Messages API format
        {
          content: raw_response['content'].map { |block| block['text'] }.compact.join("\n"),
          usage: raw_response['usage'],
          model: raw_response['model'],
          role: raw_response['role'],
          stop_reason: raw_response['stop_reason'],
          stop_sequence: raw_response['stop_sequence']
        }
      elsif raw_response.dig('completion')
        # Legacy completions format
        {
          content: raw_response['completion'],
          model: raw_response['model'],
          stop_reason: raw_response['stop_reason']
        }
      else
        # Unknown Anthropic format
        raw_response
      end
    else
      # Plain text response
      { content: raw_response.to_s }
    end
  end

  def parse_openai_response(raw_response)
    if raw_response.is_a?(Hash)
      # OpenAI API response format
      if raw_response.dig('choices')&.is_a?(Array)
        choice = raw_response['choices'].first
        {
          content: choice.dig('message', 'content') || choice.dig('text'),
          usage: raw_response['usage'],
          model: raw_response['model'],
          finish_reason: choice['finish_reason'],
          role: choice.dig('message', 'role'),
          function_call: choice.dig('message', 'function_call'),
          tool_calls: choice.dig('message', 'tool_calls')
        }
      else
        # Direct response format
        raw_response
      end
    else
      # Plain text response
      { content: raw_response.to_s }
    end
  end

  def parse_google_response(raw_response)
    if raw_response.is_a?(Hash)
      # Google AI response format
      if raw_response.dig('candidates')&.is_a?(Array)
        candidate = raw_response['candidates'].first
        {
          content: candidate.dig('content', 'parts')&.first&.dig('text'),
          usage: raw_response['usageMetadata'],
          model: raw_response['model'],
          finish_reason: candidate['finishReason'],
          safety_ratings: candidate['safetyRatings'],
          citation_metadata: candidate['citationMetadata']
        }
      else
        raw_response
      end
    else
      { content: raw_response.to_s }
    end
  end

  def parse_azure_response(raw_response)
    # Azure OpenAI typically follows OpenAI format
    parse_openai_response(raw_response)
  end

  def parse_generic_response(raw_response)
    if raw_response.is_a?(Hash)
      # Try to find content in common fields
      content = raw_response['content'] || 
                raw_response['text'] || 
                raw_response['response'] || 
                raw_response['output'] ||
                raw_response.to_s
      
      { content: content, metadata: raw_response.except('content', 'text', 'response', 'output') }
    else
      { content: raw_response.to_s }
    end
  end

  # Content extraction by type

  def extract_content_by_type(parsed_response, options = {})
    content = parsed_response[:content] || parsed_response['content']
    return content unless response_type && response_type != 'text'

    case response_type.downcase
    when 'json'
      extract_json_content(content)
    when 'structured_data'
      extract_structured_data(content, options)
    when 'campaign_plan'
      extract_campaign_plan(content, options)
    when 'brand_analysis'
      extract_brand_analysis(content, options)
    when 'content_generation'
      extract_content_generation(content, options)
    when 'optimization_suggestions'
      extract_optimization_suggestions(content, options)
    else
      content
    end
  end

  def extract_json_content(content)
    return content if content.is_a?(Hash) || content.is_a?(Array)
    
    # Try to extract JSON from text
    json_match = content.to_s.match(/```(?:json)?\s*(\{.*?\}|\[.*?\])\s*```/m) ||
                 content.to_s.match(/(\{.*?\}|\[.*?\])/m)
    
    return content unless json_match
    
    begin
      JSON.parse(json_match[1])
    rescue JSON::ParserError
      Rails.logger.warn "Failed to parse JSON from content: #{json_match[1][0..100]}..."
      content
    end
  end

  def extract_structured_data(content, options = {})
    structure_type = options[:structure_type] || 'auto'
    
    case structure_type
    when 'auto'
      # Try to detect structure automatically
      detect_and_extract_structure(content)
    when 'key_value'
      extract_key_value_pairs(content)
    when 'list'
      extract_list_items(content)
    when 'sections'
      extract_sections(content)
    else
      content
    end
  end

  def extract_campaign_plan(content, options = {})
    # Extract campaign plan structure
    plan_structure = {
      title: extract_field(content, %w[title name campaign_name]),
      objective: extract_field(content, %w[objective goal purpose]),
      target_audience: extract_field(content, %w[target_audience audience demographic]),
      budget_allocation: extract_budget_info(content),
      timeline: extract_timeline_info(content),
      channels: extract_channels_info(content),
      key_messages: extract_messages_info(content),
      success_metrics: extract_metrics_info(content),
      content_strategy: extract_content_strategy(content)
    }
    
    # Remove nil values
    plan_structure.compact
  end

  def extract_brand_analysis(content, options = {})
    {
      brand_voice: extract_field(content, %w[brand_voice voice tone]),
      brand_values: extract_field(content, %w[brand_values values core_values]),
      competitive_advantages: extract_list_field(content, %w[advantages competitive_edge strengths]),
      brand_guidelines: extract_guidelines_info(content),
      content_opportunities: extract_list_field(content, %w[opportunities recommendations suggestions]),
      compliance_considerations: extract_compliance_info(content),
      sentiment_analysis: extract_sentiment_info(content)
    }.compact
  end

  def extract_content_generation(content, options = {})
    content_type = options[:content_type] || 'general'
    
    case content_type
    when 'social_media'
      extract_social_media_content(content)
    when 'email'
      extract_email_content(content)
    when 'ad_copy'
      extract_ad_copy_content(content)
    when 'blog_post'
      extract_blog_content(content)
    else
      # Generic content extraction
      {
        headline: extract_field(content, %w[headline title subject]),
        body: extract_field(content, %w[body content text message]),
        call_to_action: extract_field(content, %w[cta call_to_action action]),
        hashtags: extract_hashtags(content),
        mentions: extract_mentions(content)
      }.compact
    end
  end

  def extract_optimization_suggestions(content, options = {})
    {
      priority_recommendations: extract_priority_items(content),
      performance_insights: extract_performance_data(content),
      action_items: extract_action_items(content),
      success_probability: extract_probability_score(content),
      implementation_timeline: extract_implementation_info(content)
    }.compact
  end

  # Helper methods for content extraction

  def extract_field(content, field_names)
    text = content.to_s.downcase
    
    field_names.each do |field|
      # Look for field followed by colon and value
      match = text.match(/#{Regexp.escape(field)}[:\-\s]*([^\n\r]+)/i)
      return match[1].strip if match
      
      # Look for field in structured format
      if content.is_a?(Hash)
        value = content.dig(field) || content.dig(field.to_sym)
        return value if value.present?
      end
    end
    
    nil
  end

  def extract_list_field(content, field_names)
    text = content.to_s
    
    field_names.each do |field|
      # Look for bulleted or numbered lists after field name
      pattern = /#{Regexp.escape(field)}[:\-\s]*\n?((?:\s*[-*•]\s*.+\n?)+)/i
      match = text.match(pattern)
      
      if match
        items = match[1].scan(/^\s*[-*•]\s*(.+)$/m).flatten.map(&:strip)
        return items if items.any?
      end
    end
    
    nil
  end

  # Format detection methods

  def detect_original_format(raw_response)
    if raw_response.is_a?(Hash)
      'json'
    elsif raw_response.to_s.strip.start_with?('{', '[')
      'json_string'
    elsif raw_response.to_s.include?('```')
      'markdown'
    else
      'text'
    end
  end

  def detect_and_extract_structure(content)
    text = content.to_s
    
    # Try different structure patterns
    if text.match?(/^\s*\d+\.\s+/m) || text.match?(/^\s*-\s+/m) || text.match?(/^\s*\*\s+/m)
      extract_list_items(content)
    elsif text.match?(/^[A-Z][^:]*:\s*/m)
      extract_key_value_pairs(content)
    elsif text.match?(/^#+\s+/m)
      extract_sections(content)
    else
      content
    end
  end

  def extract_list_items(content)
    text = content.to_s
    items = []
    
    # Match numbered lists
    text.scan(/^\s*\d+\.\s*(.+)$/m) { items << $1.strip }
    
    # Match bulleted lists if no numbered items found
    if items.empty?
      text.scan(/^\s*[-*•]\s*(.+)$/m) { items << $1.strip }
    end
    
    items.any? ? items : content
  end

  def extract_key_value_pairs(content)
    text = content.to_s
    pairs = {}
    
    text.scan(/^([^:\n]+):\s*(.+)$/m) do |key, value|
      clean_key = key.strip.downcase.gsub(/\s+/, '_')
      pairs[clean_key] = value.strip
    end
    
    pairs.any? ? pairs : content
  end

  def extract_sections(content)
    text = content.to_s
    sections = {}
    current_section = nil
    current_content = []
    
    text.split("\n").each do |line|
      if line.match?(/^#+\s+/)
        # Save previous section
        if current_section
          sections[current_section] = current_content.join("\n").strip
        end
        
        # Start new section
        current_section = line.gsub(/^#+\s+/, '').strip.downcase.gsub(/\s+/, '_')
        current_content = []
      else
        current_content << line if current_section
      end
    end
    
    # Save last section
    if current_section
      sections[current_section] = current_content.join("\n").strip
    end
    
    sections.any? ? sections : content
  end

  # Validation methods

  def validate_extracted_content!(content, options = {})
    case response_type.downcase
    when 'json'
      validate_json_structure!(content, options)
    when 'campaign_plan'
      validate_campaign_plan_structure!(content, options)
    when 'brand_analysis'
      validate_brand_analysis_structure!(content, options)
    end
  end

  def validate_json_structure!(content, options = {})
    unless content.is_a?(Hash) || content.is_a?(Array)
      raise StructureValidationError, "Expected JSON object or array, got #{content.class}"
    end
    
    if required_fields = options[:required_fields]
      missing_fields = required_fields - content.keys
      if missing_fields.any?
        raise StructureValidationError, "Missing required fields: #{missing_fields.join(', ')}"
      end
    end
  end

  def validate_campaign_plan_structure!(content, options = {})
    unless content.is_a?(Hash)
      raise StructureValidationError, "Campaign plan must be a hash structure"
    end
    
    required_fields = %w[objective target_audience]
    missing_fields = required_fields.select { |field| content[field].blank? }
    
    if missing_fields.any?
      raise StructureValidationError, "Campaign plan missing required fields: #{missing_fields.join(', ')}"
    end
  end

  def validate_brand_analysis_structure!(content, options = {})
    unless content.is_a?(Hash)
      raise StructureValidationError, "Brand analysis must be a hash structure"
    end
    
    if content.keys.empty?
      raise StructureValidationError, "Brand analysis cannot be empty"
    end
  end

  # Provider detection methods

  def anthropic_response?(raw_response)
    return true if raw_response.is_a?(Hash) && (
      raw_response.key?('content') || 
      raw_response.key?('completion') || 
      raw_response.key?('stop_reason')
    )
    false
  end

  def openai_response?(raw_response)
    return true if raw_response.is_a?(Hash) && (
      raw_response.key?('choices') || 
      raw_response.key?('usage') ||
      raw_response.dig('choices', 0, 'message')
    )
    false
  end

  def google_response?(raw_response)
    return true if raw_response.is_a?(Hash) && (
      raw_response.key?('candidates') ||
      raw_response.key?('usageMetadata')
    )
    false
  end

  def azure_response?(raw_response)
    # Azure typically follows OpenAI format but may have Azure-specific fields
    openai_response?(raw_response)
  end

  # Metadata extraction
  
  def extract_metadata(parsed_response)
    metadata = {}
    
    # Common metadata fields across providers
    metadata[:usage] = parsed_response[:usage] || parsed_response['usage']
    metadata[:model] = parsed_response[:model] || parsed_response['model']
    metadata[:finish_reason] = parsed_response[:finish_reason] || 
                               parsed_response[:stop_reason] ||
                               parsed_response['finish_reason'] ||
                               parsed_response['stop_reason']
    
    # Provider-specific metadata
    metadata[:safety_ratings] = parsed_response[:safety_ratings] if parsed_response[:safety_ratings]
    metadata[:function_call] = parsed_response[:function_call] if parsed_response[:function_call]
    metadata[:tool_calls] = parsed_response[:tool_calls] if parsed_response[:tool_calls]
    
    metadata.compact
  end

  # Additional helper methods for specific content types
  
  def extract_social_media_content(content)
    {
      post_text: extract_field(content, %w[post text content message]),
      hashtags: extract_hashtags(content),
      mentions: extract_mentions(content),
      image_description: extract_field(content, %w[image_description visual_description image]),
      platform_specific: extract_platform_specific_content(content)
    }.compact
  end

  def extract_email_content(content)
    {
      subject: extract_field(content, %w[subject subject_line title]),
      preheader: extract_field(content, %w[preheader preview_text]),
      body: extract_field(content, %w[body content message text]),
      call_to_action: extract_field(content, %w[cta call_to_action action button_text]),
      signature: extract_field(content, %w[signature sign_off closing])
    }.compact
  end

  def extract_hashtags(content)
    content.to_s.scan(/#\w+/).uniq
  end

  def extract_mentions(content)
    content.to_s.scan(/@\w+/).uniq
  end

  # Placeholder methods for complex extraction (to be implemented as needed)
  def extract_budget_info(content); extract_field(content, %w[budget allocation funding]); end
  def extract_timeline_info(content); extract_field(content, %w[timeline schedule duration]); end
  def extract_channels_info(content); extract_list_field(content, %w[channels platforms media]); end
  def extract_messages_info(content); extract_list_field(content, %w[messages messaging key_messages]); end
  def extract_metrics_info(content); extract_list_field(content, %w[metrics kpis measurements success_criteria]); end
  def extract_content_strategy(content); extract_field(content, %w[content_strategy strategy approach]); end
  def extract_guidelines_info(content); extract_field(content, %w[guidelines rules standards]); end
  def extract_compliance_info(content); extract_list_field(content, %w[compliance regulations requirements]); end
  def extract_sentiment_info(content); extract_field(content, %w[sentiment tone mood]); end
  def extract_ad_copy_content(content); extract_field(content, %w[headline copy text message]); end
  def extract_blog_content(content); extract_sections(content); end
  def extract_platform_specific_content(content); {}; end
  def extract_priority_items(content); extract_list_field(content, %w[priority recommendations high_impact]); end
  def extract_performance_data(content); extract_field(content, %w[performance metrics data insights]); end
  def extract_action_items(content); extract_list_field(content, %w[actions action_items tasks next_steps]); end
  def extract_probability_score(content); extract_field(content, %w[probability confidence score success_rate]); end
  def extract_implementation_info(content); extract_field(content, %w[implementation timeline execution plan]); end
end