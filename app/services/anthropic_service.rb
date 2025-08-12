# Anthropic Claude AI service implementation
# Handles content generation using Claude models via Anthropic API
class AnthropicService < AiServiceBase
  require "net/http"
  require "json"

  # Anthropic-specific configuration
  DEFAULT_API_VERSION = "2023-06-01".freeze
  DEFAULT_MAX_TOKENS = 4096

  attribute :api_version, :string, default: DEFAULT_API_VERSION
  attribute :max_tokens_output, :integer, default: DEFAULT_MAX_TOKENS
  attribute :temperature, :float, default: 0.7
  attribute :top_p, :float, default: 0.9

  def supports_function_calling?
    true
  end

  def supports_image_analysis?
    true
  end

  def supports_streaming?
    true
  end

  def max_context_tokens
    case model_name
    when /claude-3-5-sonnet/, /claude-3-5-haiku/, /claude-3-opus/
      200_000
    else
      super
    end
  end

  # Generate content using Claude
  def generate_content(prompt, options = {})
    operation_type = options[:operation_type] || 'content_generation'
    
    AiMonitoringService.track_request(operation_type, provider_name, model_name) do
      sanitized_prompt = sanitize_prompt(prompt)
      temperature = options[:temperature] || self.temperature
      max_tokens = options[:max_tokens] || max_tokens_output

      messages = [
        {
          role: "user",
          content: sanitized_prompt
        }
      ]

      # Add system message if provided
      system_message = options[:system_message] || build_default_system_message
      
      request_payload = {
        model: model_name,
        max_tokens: max_tokens,
        temperature: temperature,
        top_p: top_p,
        messages: messages
      }

      request_payload[:system] = system_message if system_message.present?

      # Include cache options for rate limiting and caching
      cache_options = {
        prompt: sanitized_prompt,
        estimated_tokens: estimate_token_count(sanitized_prompt),
        system_prompt: system_message,
        temperature: temperature,
        max_tokens: max_tokens,
        cache_ttl: options[:cache_ttl]
      }

      result = make_enhanced_request_with_fallbacks(
        -> { send_anthropic_request("/messages", request_payload) },
        cache_options
      )

      # Track cost if monitoring is enabled
      if result && result.is_a?(Hash) && result['usage']
        usage_data = {
          input_tokens: result['usage']['input_tokens'] || 0,
          output_tokens: result['usage']['output_tokens'] || 0,
          total_tokens: result['usage']['total_tokens'] || 0
        }

        AiCostTracker.track_cost(provider_name, model_name, usage_data, {
          operation_type: operation_type,
          operation_id: @operation_id,
          user_id: extract_user_id,
          session_id: extract_session_id
        })
      end

      result
    end
  end

  # Generate comprehensive campaign plan
  def generate_campaign_plan(campaign_data, options = {})
    prompt = build_campaign_planning_prompt(campaign_data, options)
    system_message = build_campaign_system_message
    
    response = generate_content(prompt, {
      system_message: system_message,
      temperature: 0.3, # Lower temperature for more structured output
      max_tokens: 3000,
      operation_type: 'campaign_planning',
      **options
    })

    parse_campaign_plan_response(response)
  end

  # Analyze brand assets and extract insights
  def analyze_brand_assets(assets, options = {})
    prompt = build_brand_analysis_prompt(assets, options)
    system_message = build_brand_analysis_system_message
    
    response = generate_content(prompt, {
      system_message: system_message,
      temperature: 0.4,
      max_tokens: 2000,
      operation_type: 'brand_analysis',
      **options
    })

    parse_brand_analysis_response(response)
  end

  # Generate content for specific marketing channels
  def generate_content_for_channel(channel, brand_context, options = {})
    prompt = build_channel_content_prompt(channel, brand_context, options)
    system_message = build_channel_system_message(channel)
    
    response = generate_content(prompt, {
      system_message: system_message,
      temperature: options[:creativity_level] || 0.8,
      max_tokens: calculate_channel_max_tokens(channel),
      **options
    })

    parse_channel_content_response(response, channel)
  end

  def test_connection
    test_payload = {
      model: model_name,
      max_tokens: 10,
      messages: [{ role: "user", content: "Hello" }]
    }

    response = send_anthropic_request("/messages", test_payload)
    response.is_a?(Hash) && response["content"]&.any?
  rescue => e
    Rails.logger.error "Anthropic connection test failed: #{e.message}"
    false
  end

  private

  def send_anthropic_request(endpoint, payload)
    uri = URI("#{api_base_url}#{endpoint}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = timeout_seconds
    http.write_timeout = timeout_seconds

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = api_key
    request["anthropic-version"] = api_version
    request.body = payload.to_json

    response = http.request(request)
    
    case response.code.to_i
    when 200..299
      JSON.parse(response.body)
    when 400
      error_data = JSON.parse(response.body) rescue { "error" => { "message" => "Invalid request" } }
      raise InvalidRequestError, error_data.dig("error", "message") || "Invalid request"
    when 401
      raise AuthenticationError, "Invalid API key or authentication failed"
    when 413
      raise ContextTooLongError, "Request too large - reduce context size"
    when 429
      raise RateLimitError, "Rate limit exceeded - please wait before retrying"
    when 500..599
      raise ProviderUnavailableError, "Anthropic API is temporarily unavailable"
    else
      error_body = response.body rescue "Unknown error"
      raise ProviderError, "Unexpected response: #{response.code} - #{error_body}"
    end
  end

  def build_default_system_message
    "You are an AI assistant specialized in marketing and campaign creation. Provide helpful, creative, and professional responses focused on marketing strategy, content creation, and campaign optimization."
  end

  def build_campaign_system_message
    <<~SYSTEM
      You are a marketing strategist AI that creates comprehensive campaign plans. 

      Your responses should be well-structured JSON with the following format:
      {
        "campaign_overview": "Brief description of the campaign strategy",
        "target_audience": "Primary audience description",
        "key_messages": ["message 1", "message 2", "message 3"],
        "channels": {
          "email": { "strategy": "...", "content_ideas": [...] },
          "social_media": { "strategy": "...", "content_ideas": [...] },
          "web": { "strategy": "...", "content_ideas": [...] }
        },
        "timeline": {
          "planning_phase": "timeframe",
          "execution_phase": "timeframe", 
          "analysis_phase": "timeframe"
        },
        "success_metrics": ["metric 1", "metric 2", "metric 3"],
        "budget_recommendations": {
          "channel_allocation": {...},
          "priority_areas": [...]
        }
      }

      Focus on practical, actionable strategies that align with modern marketing best practices.
    SYSTEM
  end

  def build_brand_analysis_system_message
    <<~SYSTEM
      You are a brand analysis AI that extracts insights from brand assets and documents.

      Analyze the provided brand materials and return structured JSON with:
      {
        "brand_voice": "Description of brand personality and tone",
        "key_themes": ["theme 1", "theme 2", "theme 3"],
        "target_demographics": "Inferred target audience",
        "competitive_advantages": ["advantage 1", "advantage 2"],
        "brand_guidelines": {
          "tone_of_voice": "...",
          "messaging_style": "...",
          "content_restrictions": [...]
        },
        "content_opportunities": ["opportunity 1", "opportunity 2"],
        "compliance_considerations": ["consideration 1", "consideration 2"]
      }

      Base your analysis strictly on the provided materials without making assumptions.
    SYSTEM
  end

  def build_channel_system_message(channel)
    case channel.to_s
    when "email"
      "You are an email marketing specialist. Create compelling email content that drives engagement and conversions while following email marketing best practices."
    when "social_media"
      "You are a social media content creator. Generate engaging, shareable content optimized for social media platforms with appropriate hashtags and calls-to-action."
    when "web"
      "You are a web content strategist. Create website content that is SEO-friendly, user-focused, and drives conversions."
    else
      "You are a marketing content specialist. Create high-quality marketing content tailored to the specified channel and audience."
    end
  end

  def build_campaign_planning_prompt(campaign_data, options)
    context_parts = []
    
    context_parts << "Campaign Name: #{campaign_data[:name]}" if campaign_data[:name]
    context_parts << "Purpose: #{campaign_data[:purpose]}" if campaign_data[:purpose]
    context_parts << "Budget: $#{campaign_data[:budget]}" if campaign_data[:budget]
    context_parts << "Duration: #{campaign_data[:start_date]} to #{campaign_data[:end_date]}" if campaign_data[:start_date] && campaign_data[:end_date]
    context_parts << "Target Audience: #{campaign_data[:target_audience]}" if campaign_data[:target_audience]
    context_parts << "Brand Context: #{campaign_data[:brand_context]}" if campaign_data[:brand_context]

    additional_requirements = options[:requirements] || []
    context_parts.concat(additional_requirements) if additional_requirements.any?

    prompt = <<~PROMPT
      Create a comprehensive marketing campaign plan based on the following information:

      #{context_parts.join("\n")}

      Please provide a detailed campaign strategy that includes target audience analysis, key messaging, channel recommendations, timeline, success metrics, and budget allocation suggestions.
      
      Focus on actionable strategies that can be implemented effectively within the given constraints.
    PROMPT

    prompt
  end

  def build_brand_analysis_prompt(assets, options)
    asset_content = assets.map do |asset|
      content = []
      content << "Asset: #{asset.filename}" if asset.respond_to?(:filename)
      content << "Type: #{asset.content_type}" if asset.respond_to?(:content_type)
      content << "Text Content: #{asset.extracted_text}" if asset.respond_to?(:extracted_text) && asset.extracted_text.present?
      content.join("\n")
    end.join("\n\n---\n\n")

    focus_areas = options[:focus_areas] || ["brand voice", "messaging", "target audience", "compliance"]

    <<~PROMPT
      Analyze the following brand assets and extract key insights:

      #{asset_content}

      Focus your analysis on: #{focus_areas.join(", ")}

      Provide insights that can inform content creation and marketing strategy decisions.
    PROMPT
  end

  def build_channel_content_prompt(channel, brand_context, options)
    content_type = options[:content_type] || "general marketing content"
    target_audience = options[:target_audience] || "primary target audience"
    campaign_goal = options[:campaign_goal] || "engagement and conversions"

    <<~PROMPT
      Generate #{content_type} for #{channel} marketing channel.

      Brand Context:
      #{brand_context}

      Requirements:
      - Target Audience: #{target_audience}
      - Campaign Goal: #{campaign_goal}
      - Content Length: #{options[:content_length] || "appropriate for channel"}
      - Tone: #{options[:tone] || "professional yet engaging"}
      
      #{options[:additional_requirements] if options[:additional_requirements]}

      Please create content that is optimized for #{channel} and aligns with the brand voice while achieving the campaign objectives.
    PROMPT
  end

  def calculate_channel_max_tokens(channel)
    case channel.to_s
    when "email"
      1500 # Longer form content for email
    when "social_media"
      500  # Shorter, punchier content
    when "web"
      2000 # Comprehensive web content
    else
      1000 # Default
    end
  end

  def parse_campaign_plan_response(response)
    content_text = extract_content_from_response(response)
    json_data = extract_json_from_response(content_text)
    
    if json_data
      json_data
    else
      # Fallback: return structured text response
      {
        "campaign_overview" => content_text,
        "raw_response" => content_text,
        "format" => "text"
      }
    end
  end

  def parse_brand_analysis_response(response)
    content_text = extract_content_from_response(response)
    json_data = extract_json_from_response(content_text)
    
    if json_data
      json_data
    else
      {
        "analysis" => content_text,
        "raw_response" => content_text,
        "format" => "text"
      }
    end
  end

  def parse_channel_content_response(response, channel)
    content_text = extract_content_from_response(response)
    
    {
      "channel" => channel,
      "content" => content_text,
      "generated_at" => Time.current.iso8601,
      "model_used" => model_name
    }
  end

  def extract_content_from_response(response)
    if response.is_a?(Hash)
      # Handle Anthropic's response format
      content_blocks = response.dig("content") || []
      content_blocks.map { |block| block["text"] }.compact.join("\n")
    else
      response.to_s
    end
  end
end