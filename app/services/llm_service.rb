class LlmService
  include Rails.application.routes.url_helpers

  DEFAULT_MODEL = "gpt-4-turbo-preview"
  DEFAULT_TEMPERATURE = 0.7
  DEFAULT_MAX_TOKENS = 2000

  def initialize(model: DEFAULT_MODEL, temperature: DEFAULT_TEMPERATURE)
    @model = model
    @temperature = temperature
    @client = build_client
  end

  def analyze(prompt, options = {})
    response = @client.post do |req|
      req.url completion_endpoint
      req.headers['Content-Type'] = 'application/json'
      req.body = build_request_body(prompt, options).to_json
    end

    parse_response(response)
  rescue Faraday::Error => e
    Rails.logger.error "LLM API Error: #{e.message}"
    handle_api_error(e)
  end

  def generate_suggestions(context, options = {})
    prompt = build_suggestion_prompt(context)
    analyze(prompt, options.merge(temperature: 0.8))
  end

  def validate_content(content, brand_guidelines, options = {})
    prompt = build_validation_prompt(content, brand_guidelines)
    analyze(prompt, options.merge(temperature: 0.3))
  end

  private

  def build_client
    Faraday.new(url: api_base_url) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      faraday.headers['Authorization'] = "Bearer #{api_key}"
      
      # Add retry logic
      faraday.request :retry, {
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2
      }
    end
  end

  def api_base_url
    case @model
    when /^gpt/
      "https://api.openai.com"
    when /^claude/
      "https://api.anthropic.com"
    else
      ENV['LLM_API_BASE_URL'] || "https://api.openai.com"
    end
  end

  def api_key
    case @model
    when /^gpt/
      ENV['OPENAI_API_KEY']
    when /^claude/
      ENV['ANTHROPIC_API_KEY']
    else
      ENV['LLM_API_KEY']
    end
  end

  def completion_endpoint
    case @model
    when /^gpt/
      "/v1/chat/completions"
    when /^claude/
      "/v1/messages"
    else
      "/v1/chat/completions"
    end
  end

  def build_request_body(prompt, options)
    max_tokens = options[:max_tokens] || DEFAULT_MAX_TOKENS
    temperature = options[:temperature] || @temperature

    case @model
    when /^gpt/
      {
        model: @model,
        messages: [
          {
            role: "system",
            content: "You are a brand analysis and marketing expert. Provide detailed, actionable insights."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: temperature,
        max_tokens: max_tokens,
        response_format: { type: "json_object" } if options[:json_response]
      }
    when /^claude/
      {
        model: @model,
        messages: [
          {
            role: "user",
            content: prompt
          }
        ],
        max_tokens: max_tokens,
        temperature: temperature
      }
    else
      {
        model: @model,
        messages: [
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: temperature,
        max_tokens: max_tokens
      }
    end
  end

  def parse_response(response)
    return nil unless response.success?

    case @model
    when /^gpt/
      response.body.dig("choices", 0, "message", "content")
    when /^claude/
      response.body.dig("content", 0, "text")
    else
      response.body.dig("choices", 0, "message", "content") ||
        response.body.dig("content")
    end
  end

  def handle_api_error(error)
    case error
    when Faraday::ResourceNotFound
      { error: "API endpoint not found", details: error.message }
    when Faraday::UnauthorizedError
      { error: "Invalid API key", details: error.message }
    when Faraday::TooManyRequestsError
      { error: "Rate limit exceeded", details: error.message }
    else
      { error: "API request failed", details: error.message }
    end
  end

  def build_suggestion_prompt(context)
    <<~PROMPT
      Based on the following context, generate content suggestions:
      
      Brand: #{context[:brand_name]}
      Content Type: #{context[:content_type]}
      Campaign Goal: #{context[:campaign_goal]}
      Target Audience: #{context[:target_audience]}
      
      Brand Guidelines Summary:
      #{context[:guidelines_summary]}
      
      Please provide 3-5 specific content suggestions that align with the brand voice and campaign objectives.
      Include for each suggestion:
      1. Content idea/topic
      2. Key messaging points
      3. Recommended format/channel
      4. Expected outcome
      
      Format as JSON.
    PROMPT
  end

  def build_validation_prompt(content, brand_guidelines)
    <<~PROMPT
      Validate the following content against brand guidelines:
      
      Content:
      #{content}
      
      Brand Guidelines:
      #{brand_guidelines}
      
      Please analyze:
      1. Brand voice compliance
      2. Messaging alignment
      3. Tone consistency
      4. Guideline violations
      5. Improvement suggestions
      
      Provide a compliance score (0-100) and detailed feedback.
      Format as JSON.
    PROMPT
  end
end