require 'net/http'
require 'json'

class LlmService
  class LlmError < StandardError; end
  class RateLimitError < LlmError; end
  class ApiError < LlmError; end

  def initialize(provider: nil, api_key: nil, model: nil)
    @provider = provider || ENV.fetch('LLM_PROVIDER', 'openai')
    @api_key = api_key || ENV.fetch("#{@provider.upcase}_API_KEY", nil)
    @model = model || default_model_for_provider
    
    validate_configuration!
  end

  # Check if the service is configured and ready
  def healthy?
    return false if @api_key.nil?
    
    # Could add a simple health check API call here if needed
    true
  rescue StandardError => e
    Rails.logger.error "LLM Service health check failed: #{e.message}"
    false
  end

  # Generate journey suggestions with brand awareness
  def generate_journey_suggestions(params)
    prompt = params[:prompt]
    context = params[:context]
    limit = params[:limit] || 5
    temperature = params[:temperature] || 0.7

    system_prompt = build_journey_system_prompt(context)
    user_prompt = build_journey_user_prompt(prompt, context, limit)

    response = make_api_request(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      temperature: temperature,
      max_tokens: 2000
    )

    parse_journey_suggestions(response)
  rescue StandardError => e
    Rails.logger.error "LLM Service Error: #{e.message}"
    handle_error(e)
  end

  # Generate content with brand compliance
  def generate_content(params)
    content_type = params[:content_type]
    brand_context = params[:brand_context]
    requirements = params[:requirements]
    temperature = params[:temperature] || 0.8

    system_prompt = build_content_system_prompt(brand_context)
    user_prompt = build_content_user_prompt(content_type, requirements, brand_context)

    response = make_api_request(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      temperature: temperature,
      max_tokens: 1500
    )

    parse_content_response(response)
  rescue StandardError => e
    Rails.logger.error "LLM Service Error: #{e.message}"
    handle_error(e)
  end

  # Analyze content for brand compliance
  def analyze_brand_compliance(content, brand_guidelines)
    system_prompt = "You are a brand compliance expert. Analyze content against brand guidelines and provide a compliance score."
    
    user_prompt = <<~PROMPT
      Analyze the following content for brand compliance:
      
      Content: #{content}
      
      Brand Guidelines:
      #{brand_guidelines.to_json}
      
      Provide:
      1. Compliance score (0-100)
      2. Specific compliance issues
      3. Suggestions for improvement
      
      Return as JSON.
    PROMPT

    response = make_api_request(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      temperature: 0.3,
      max_tokens: 500
    )

    parse_compliance_response(response)
  rescue StandardError => e
    Rails.logger.error "Brand Compliance Analysis Error: #{e.message}"
    { score: 75, issues: [], suggestions: [] } # Default fallback
  end

  # Natural language to journey steps
  def parse_natural_language_journey(description, journey_context)
    system_prompt = "You are an expert marketing journey designer. Convert natural language descriptions into structured journey steps."
    
    user_prompt = <<~PROMPT
      Convert this journey description into structured steps:
      
      Description: #{description}
      
      Journey Context:
      #{journey_context.to_json}
      
      Return a JSON array of journey steps with: title, description, step_type, channels, timing, estimated_effort.
    PROMPT

    response = make_api_request(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      temperature: 0.6,
      max_tokens: 1500
    )

    parse_journey_steps(response)
  rescue StandardError => e
    Rails.logger.error "Natural Language Parsing Error: #{e.message}"
    []
  end

  private

  def validate_configuration!
    raise LlmError, "No API key configured for #{@provider}" if @api_key.nil?
    raise LlmError, "Unsupported provider: #{@provider}" unless %w[openai anthropic].include?(@provider)
  end

  def default_model_for_provider
    case @provider
    when 'openai'
      'gpt-4-turbo-preview'
    when 'anthropic'
      'claude-3-opus-20240229'
    else
      'gpt-4-turbo-preview'
    end
  end

  def make_api_request(system_prompt:, user_prompt:, temperature:, max_tokens:)
    case @provider
    when 'openai'
      make_openai_request(system_prompt, user_prompt, temperature, max_tokens)
    when 'anthropic'
      make_anthropic_request(system_prompt, user_prompt, temperature, max_tokens)
    else
      raise LlmError, "Unsupported provider: #{@provider}"
    end
  end

  def make_openai_request(system_prompt, user_prompt, temperature, max_tokens)
    uri = URI('https://api.openai.com/v1/chat/completions')
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: @model,
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_prompt }
      ],
      temperature: temperature,
      max_tokens: max_tokens,
      response_format: { type: "json_object" }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    handle_api_response(response)
  end

  def make_anthropic_request(system_prompt, user_prompt, temperature, max_tokens)
    uri = URI('https://api.anthropic.com/v1/messages')
    
    request = Net::HTTP::Post.new(uri)
    request['x-api-key'] = @api_key
    request['anthropic-version'] = '2023-06-01'
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: @model,
      system: system_prompt,
      messages: [
        { role: 'user', content: user_prompt }
      ],
      temperature: temperature,
      max_tokens: max_tokens
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    handle_api_response(response)
  end

  def handle_api_response(response)
    case response.code.to_i
    when 200, 201
      parse_response_body(response.body)
    when 429
      raise RateLimitError, "Rate limit exceeded. Please try again later."
    when 401
      raise ApiError, "Authentication failed. Check your API key."
    when 400
      raise ApiError, "Bad request: #{response.body}"
    else
      raise ApiError, "API request failed with code #{response.code}: #{response.body}"
    end
  end

  def parse_response_body(body)
    data = JSON.parse(body)
    
    if @provider == 'openai'
      content = data.dig('choices', 0, 'message', 'content')
    elsif @provider == 'anthropic'
      content = data.dig('content', 0, 'text')
    else
      content = nil
    end

    return {} if content.nil?

    # Try to parse as JSON if possible
    begin
      JSON.parse(content)
    rescue JSON::ParserError
      content
    end
  end

  def build_journey_system_prompt(context)
    <<~PROMPT
      You are an expert marketing journey designer with deep knowledge of customer engagement strategies.
      You specialize in creating personalized, brand-aligned journey steps that drive results.
      
      Brand Context:
      #{context[:brand]&.to_json if context[:brand]}
      
      Always ensure suggestions are:
      1. Aligned with brand voice and guidelines
      2. Appropriate for the campaign type and stage
      3. Actionable and specific
      4. Include timing and channel recommendations
      5. Consider existing steps to avoid duplication
      
      Return suggestions as JSON with the following structure:
      {
        "suggestions": [
          {
            "title": "Step title",
            "description": "Detailed description",
            "step_type": "email|social|content|ad|event|nurture",
            "priority": "high|medium|low",
            "estimated_effort": "low|medium|high",
            "timing": "immediate|1_day|3_days|1_week|custom",
            "channels": ["email", "social", "web"],
            "brand_compliance_score": 85,
            "reasoning": "Why this step is recommended"
          }
        ]
      }
    PROMPT
  end

  def build_journey_user_prompt(prompt, context, limit)
    existing_steps = context[:existing_steps]&.map { |s| s[:title] }&.join(', ') || 'none'
    
    <<~PROMPT
      Generate #{limit} journey step suggestions for:
      
      Campaign Type: #{context[:campaign_type]}
      Current Stage: #{context[:current_stage]}
      Industry: #{context[:industry]}
      Target Audience: #{context[:target_audience]}
      
      Existing Steps: #{existing_steps}
      
      Specific Requirements:
      #{prompt}
      
      Ensure suggestions are unique, complementary to existing steps, and optimized for the current stage.
      Include specific implementation details and expected outcomes.
    PROMPT
  end

  def build_content_system_prompt(brand_context)
    <<~PROMPT
      You are a creative content strategist who specializes in brand-aligned marketing content.
      You create compelling, on-brand content that drives engagement and conversions.
      
      Brand Guidelines:
      - Voice: #{brand_context[:tone_of_voice]}
      - Key Messages: #{brand_context[:key_messages]&.join(', ')}
      - Style: #{brand_context[:style_notes]}
      
      Always ensure content:
      1. Matches brand voice and tone perfectly
      2. Incorporates key brand messages naturally
      3. Is appropriate for the target channel and audience
      4. Includes clear calls-to-action
      5. Is optimized for the specific content format
    PROMPT
  end

  def build_content_user_prompt(content_type, requirements, brand_context)
    <<~PROMPT
      Create #{content_type} content with these requirements:
      
      Channel: #{requirements[:channel]}
      Goal: #{requirements[:goal]}
      Target Audience: #{requirements[:audience]}
      Length: #{requirements[:length]}
      
      Brand Context:
      Company: #{brand_context[:company_name]}
      Product/Service: #{brand_context[:product_description]}
      Unique Value: #{brand_context[:value_proposition]}
      
      Additional Requirements:
      #{requirements[:additional_notes]}
      
      Return as JSON with:
      {
        "content": "The actual content",
        "variations": ["variation 1", "variation 2"],
        "subject_lines": ["subject 1", "subject 2"] (if applicable),
        "hashtags": ["#hashtag1", "#hashtag2"] (if applicable),
        "cta": "Call to action text",
        "notes": "Implementation notes"
      }
    PROMPT
  end

  def parse_journey_suggestions(response)
    return [] unless response.is_a?(Hash)
    
    suggestions = response['suggestions'] || []
    
    suggestions.map do |suggestion|
      {
        title: suggestion['title'],
        description: suggestion['description'],
        step_type: suggestion['step_type'] || 'content',
        priority: suggestion['priority'] || 'medium',
        estimated_effort: suggestion['estimated_effort'] || 'medium',
        timing: suggestion['timing'] || 'immediate',
        suggested_channels: suggestion['channels'] || [],
        brand_compliance_score: suggestion['brand_compliance_score'] || 85,
        reasoning: suggestion['reasoning'],
        ai_generated: true
      }
    end
  rescue StandardError => e
    Rails.logger.error "Error parsing suggestions: #{e.message}"
    []
  end

  def parse_content_response(response)
    return {} unless response.is_a?(Hash)
    
    {
      content: response['content'],
      variations: response['variations'] || [],
      subject_lines: response['subject_lines'] || [],
      hashtags: response['hashtags'] || [],
      cta: response['cta'],
      notes: response['notes'],
      ai_generated: true
    }
  rescue StandardError => e
    Rails.logger.error "Error parsing content: #{e.message}"
    {}
  end

  def parse_compliance_response(response)
    return { score: 75, issues: [], suggestions: [] } unless response.is_a?(Hash)
    
    {
      score: response['compliance_score'] || response['score'] || 75,
      issues: response['issues'] || [],
      suggestions: response['suggestions'] || []
    }
  rescue StandardError => e
    Rails.logger.error "Error parsing compliance: #{e.message}"
    { score: 75, issues: [], suggestions: [] }
  end

  def parse_journey_steps(response)
    return [] unless response.is_a?(Array) || response.is_a?(Hash)
    
    steps = response.is_a?(Array) ? response : (response['steps'] || [])
    
    steps.map do |step|
      {
        title: step['title'],
        description: step['description'],
        step_type: step['step_type'] || 'content',
        channels: step['channels'] || [],
        timing: step['timing'] || 'immediate',
        estimated_effort: step['estimated_effort'] || 'medium'
      }
    end
  rescue StandardError => e
    Rails.logger.error "Error parsing journey steps: #{e.message}"
    []
  end

  def handle_error(error)
    case error
    when RateLimitError
      # Return cached or fallback suggestions
      Rails.cache.fetch('llm_fallback_suggestions', expires_in: 1.hour) do
        generate_fallback_suggestions
      end
    when ApiError
      # Log and return empty/default response
      Rails.logger.error "LLM API Error: #{error.message}"
      []
    else
      # Re-raise unexpected errors
      raise error
    end
  end

  def generate_fallback_suggestions
    # Basic fallback suggestions when API is unavailable
    [
      {
        title: "Welcome Email Sequence",
        description: "Send a personalized welcome email to new subscribers",
        step_type: "email",
        priority: "high",
        estimated_effort: "low",
        timing: "immediate",
        suggested_channels: ["email"],
        brand_compliance_score: 80,
        reasoning: "Essential for onboarding new contacts"
      },
      {
        title: "Educational Content Series",
        description: "Share valuable content that addresses customer pain points",
        step_type: "content",
        priority: "medium",
        estimated_effort: "medium",
        timing: "3_days",
        suggested_channels: ["email", "blog"],
        brand_compliance_score: 85,
        reasoning: "Builds trust and demonstrates expertise"
      }
    ]
  end
end