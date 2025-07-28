class LlmService
  include Rails.application.routes.url_helpers

  DEFAULT_MODEL = "gpt-4-turbo-preview"
  DEFAULT_TEMPERATURE = 0.7
  DEFAULT_MAX_TOKENS = 2000
  
  # Model capabilities
  JSON_CAPABLE_MODELS = %w[
    gpt-4-turbo-preview gpt-4-1106-preview gpt-3.5-turbo-1106
    claude-3-opus-20240229 claude-3-sonnet-20240229 claude-3-haiku-20240307
  ].freeze
  
  # Provider-specific settings
  PROVIDER_CONFIGS = {
    openai: {
      base_url: "https://api.openai.com",
      models: /^(gpt|text-davinci|babbage|curie|ada)/,
      json_mode: true
    },
    anthropic: {
      base_url: "https://api.anthropic.com",
      models: /^claude/,
      json_mode: false  # Claude doesn't have native JSON mode
    },
    cohere: {
      base_url: "https://api.cohere.ai",
      models: /^command/,
      json_mode: false
    },
    huggingface: {
      base_url: "https://api-inference.huggingface.co",
      models: /^(meta-llama|mistral|falcon)/,
      json_mode: false
    }
  }.freeze

  def initialize(model: DEFAULT_MODEL, temperature: DEFAULT_TEMPERATURE)
    @model = model
    @temperature = temperature
    @provider = detect_provider
    @client = build_client
  end

  def analyze(prompt, options = {})
    # Add JSON formatting instructions if requested
    formatted_prompt = if options[:json_response]
      ensure_json_response(prompt)
    else
      prompt
    end
    
    # Build request with retries for rate limits
    response = nil
    retries = 0
    max_retries = 3
    
    begin
      response = @client.post do |req|
        req.url completion_endpoint
        req.headers.merge!(provider_headers)
        req.body = build_request_body(formatted_prompt, options).to_json
      end
      
      parsed = parse_response(response)
      
      # If JSON was requested, validate and clean the response
      if options[:json_response]
        parsed = ensure_valid_json(parsed)
      end
      
      parsed
    rescue Faraday::TooManyRequestsError => e
      retries += 1
      if retries < max_retries
        wait_time = extract_retry_after(e) || (2 ** retries)
        Rails.logger.warn "Rate limited, waiting #{wait_time}s before retry #{retries}/#{max_retries}"
        sleep(wait_time)
        retry
      else
        handle_api_error(e)
      end
    rescue Faraday::Error => e
      Rails.logger.error "LLM API Error: #{e.message}"
      handle_api_error(e)
    end
  end
  
  def ensure_json_response(prompt)
    json_instruction = "\n\nIMPORTANT: You must respond with valid JSON only. Do not include any text before or after the JSON. Do not use markdown formatting. The response should be a raw JSON object that can be parsed directly."
    
    # Add JSON schema hint if the prompt mentions a structure
    if prompt.include?("JSON structure:")
      prompt + json_instruction
    else
      prompt + "\n\nProvide your response as a valid JSON object." + json_instruction
    end
  end
  
  def ensure_valid_json(response)
    return nil if response.nil? || response.empty?
    
    # Try to extract JSON from the response
    json_match = response.match(/\{.*\}/m) || response.match(/\[.*\]/m)
    
    if json_match
      begin
        JSON.parse(json_match[0])
        json_match[0]  # Return the matched JSON string
      rescue JSON::ParserError => e
        Rails.logger.error "Invalid JSON in LLM response: #{e.message}"
        Rails.logger.debug "Attempted to parse: #{json_match[0][0..500]}..."
        response  # Return original response as fallback
      end
    else
      Rails.logger.warn "No JSON found in LLM response"
      response
    end
  end
  
  def extract_retry_after(error)
    # Extract retry-after header if available
    if error.response && error.response[:headers]['retry-after']
      error.response[:headers]['retry-after'].to_i
    elsif error.response && error.response[:headers]['x-ratelimit-reset']
      [error.response[:headers]['x-ratelimit-reset'].to_i - Time.now.to_i, 1].max
    else
      nil
    end
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
  
  def detect_provider
    PROVIDER_CONFIGS.find { |_, config| @model.match?(config[:models]) }&.first || :openai
  end

  def build_client
    Faraday.new(url: api_base_url) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      
      # Add retry logic for network errors
      faraday.request :retry, {
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError]
      }
      
      # Add timeout settings
      faraday.options.timeout = 120  # 2 minutes
      faraday.options.open_timeout = 30
    end
  end
  
  def provider_headers
    headers = { 'Content-Type' => 'application/json' }
    
    case @provider
    when :openai
      headers['Authorization'] = "Bearer #{api_key}"
    when :anthropic
      headers['x-api-key'] = api_key
      headers['anthropic-version'] = '2023-06-01'
    when :cohere
      headers['Authorization'] = "Bearer #{api_key}"
    when :huggingface
      headers['Authorization'] = "Bearer #{api_key}"
    else
      headers['Authorization'] = "Bearer #{api_key}"
    end
    
    headers
  end

  def api_base_url
    PROVIDER_CONFIGS[@provider][:base_url] || ENV['LLM_API_BASE_URL'] || "https://api.openai.com"
  end

  def api_key
    case @provider
    when :openai
      ENV['OPENAI_API_KEY']
    when :anthropic
      ENV['ANTHROPIC_API_KEY']
    when :cohere
      ENV['COHERE_API_KEY']
    when :huggingface
      ENV['HUGGINGFACE_API_KEY']
    else
      ENV['LLM_API_KEY'] || ENV['OPENAI_API_KEY']
    end
  end

  def completion_endpoint
    case @provider
    when :openai
      "/v1/chat/completions"
    when :anthropic
      "/v1/messages"
    when :cohere
      "/v1/generate"
    when :huggingface
      "/models/#{@model}"
    else
      "/v1/chat/completions"
    end
  end

  def build_request_body(prompt, options)
    max_tokens = options[:max_tokens] || DEFAULT_MAX_TOKENS
    temperature = options[:temperature] || @temperature
    system_message = options[:system_message] || "You are a brand analysis and marketing expert. Provide detailed, actionable insights."

    case @provider
    when :openai
      body = {
        model: @model,
        messages: [
          {
            role: "system",
            content: system_message
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: temperature,
        max_tokens: max_tokens
      }
      
      # Add JSON mode if supported and requested
      if options[:json_response] && JSON_CAPABLE_MODELS.include?(@model)
        body[:response_format] = { type: "json_object" }
      end
      
      body
    when :anthropic
      {
        model: @model,
        messages: [
          {
            role: "user",
            content: "#{system_message}\n\n#{prompt}"
          }
        ],
        max_tokens: max_tokens,
        temperature: temperature
      }
    when :cohere
      {
        model: @model,
        prompt: "#{system_message}\n\n#{prompt}",
        max_tokens: max_tokens,
        temperature: temperature,
        return_likelihoods: "NONE"
      }
    when :huggingface
      {
        inputs: prompt,
        parameters: {
          max_new_tokens: max_tokens,
          temperature: temperature,
          return_full_text: false
        }
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

    case @provider
    when :openai
      response.body.dig("choices", 0, "message", "content")
    when :anthropic
      response.body.dig("content", 0, "text")
    when :cohere
      response.body.dig("generations", 0, "text") || response.body.dig("text")
    when :huggingface
      if response.body.is_a?(Array)
        response.body.first["generated_text"]
      else
        response.body["generated_text"]
      end
    else
      # Generic fallback
      response.body.dig("choices", 0, "message", "content") ||
        response.body.dig("content", 0, "text") ||
        response.body.dig("generations", 0, "text") ||
        response.body.dig("text") ||
        response.body["generated_text"]
    end
  end

  def handle_api_error(error)
    error_info = case error
    when Faraday::ResourceNotFound
      { error: "API endpoint not found", details: error.message, status: 404 }
    when Faraday::UnauthorizedError
      { error: "Invalid API key", details: error.message, status: 401 }
    when Faraday::TooManyRequestsError
      { error: "Rate limit exceeded", details: error.message, status: 429 }
    when Faraday::BadRequestError
      { error: "Invalid request", details: parse_error_details(error), status: 400 }
    when Faraday::ServerError
      { error: "Server error", details: error.message, status: 500 }
    when Faraday::TimeoutError
      { error: "Request timeout", details: "The request took too long to complete", status: 408 }
    else
      { error: "API request failed", details: error.message, status: 0 }
    end
    
    Rails.logger.error "LLM API Error: #{error_info[:error]} - #{error_info[:details]}"
    error_info
  end
  
  def parse_error_details(error)
    if error.response && error.response[:body]
      body = error.response[:body]
      
      if body.is_a?(Hash)
        body['error']&.[]('message') || body['message'] || error.message
      else
        error.message
      end
    else
      error.message
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