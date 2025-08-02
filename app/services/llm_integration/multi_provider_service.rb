module LlmIntegration
  class MultiProviderService
    include ActiveModel::Model

    attr_accessor :primary, :fallback, :timeout, :circuit_breaker

    def initialize(options = {})
      @primary = options[:primary] || :openai
      @fallback = Array(options[:fallback] || [ :anthropic, :cohere ])
      @timeout = options[:timeout] || 30
      @circuit_breaker = options[:circuit_breaker] || CircuitBreaker.new
      @rate_limiter = RateLimiter.new
      @provider_metrics = ProviderMetrics.new
    end

    def available_providers
      [ :openai, :anthropic, :cohere, :huggingface ]
    end

    def detect_provider(model_name)
      case model_name.to_s
      when /^gpt/, /^text-davinci/, /^babbage/, /^curie/, /^ada/
        :openai
      when /^claude/
        :anthropic
      when /^command/
        :cohere
      when /^meta-llama/, /^mistral/, /^falcon/
        :huggingface
      else
        :openai # Default fallback
      end
    end

    def configure(options = {})
      @primary = options[:primary] if options[:primary]
      @fallback = Array(options[:fallback]) if options[:fallback]
      @timeout = options[:timeout] if options[:timeout]
    end

    def generate_content(prompt, options = {})
      provider_order = [ @primary ] + @fallback
      last_error = nil
      failover_occurred = false

      provider_order.each do |provider|
        next unless @rate_limiter.can_make_request?(provider)

        begin
          start_time = Time.current

          # Check circuit breaker
          result = @circuit_breaker.call(provider) do
            call_provider(provider, prompt, options)
          end

          duration = Time.current - start_time

          # Record successful request
          @provider_metrics.record_request(
            provider,
            duration: duration,
            tokens: estimate_tokens(result),
            success: true
          )

          return {
            content: result,
            provider_used: provider,
            failover_occurred: failover_occurred,
            generation_time: duration
          }

        rescue LlmIntegration::ProviderError => e
          last_error = e
          failover_occurred = true if provider != @primary

          duration = Time.current - start_time rescue 0
          @provider_metrics.record_request(
            provider,
            duration: duration,
            tokens: 0,
            success: false,
            error: e.message
          )

          Rails.logger.warn "Provider #{provider} failed: #{e.message}"

          # Continue to next provider
          next
        end
      end

      # All providers failed
      raise LlmIntegration::AllProvidersFailedError.new(
        "All providers failed. Last error: #{last_error&.message}"
      )
    end

    def call_provider(provider, prompt, options = {})
      case provider
      when :openai
        call_openai(prompt, options)
      when :anthropic
        call_anthropic(prompt, options)
      when :cohere
        call_cohere(prompt, options)
      when :huggingface
        call_huggingface(prompt, options)
      else
        raise LlmIntegration::UnsupportedProviderError.new("Unsupported provider: #{provider}")
      end
    end

    def provider_status(provider)
      {
        available: @circuit_breaker.available?(provider),
        rate_limited: !@rate_limiter.can_make_request?(provider),
        circuit_breaker_state: @circuit_breaker.state(provider),
        recent_errors: @provider_metrics.recent_errors(provider),
        success_rate: @provider_metrics.success_rate(provider)
      }
    end

    def system_health
      available_providers.each_with_object({}) do |provider, health|
        health[provider] = provider_status(provider)
      end
    end

    private

    def call_openai(prompt, options)
      auth = Authentication::OpenAIAuth.new
      client = build_http_client("https://api.openai.com")

      response = client.post("/v1/chat/completions") do |req|
        req.headers.merge!(auth.build_headers)
        req.body = {
          model: options[:model] || "gpt-4-turbo-preview",
          messages: [
            { role: "system", content: options[:system_message] || "You are a helpful assistant." },
            { role: "user", content: prompt }
          ],
          temperature: options[:temperature] || 0.7,
          max_tokens: options[:max_tokens] || 2000
        }.to_json
      end

      unless response.success?
        raise LlmIntegration::ProviderError.new("OpenAI API error: #{response.status}")
      end

      response.body.dig("choices", 0, "message", "content")
    end

    def call_anthropic(prompt, options)
      auth = Authentication::AnthropicAuth.new
      client = build_http_client("https://api.anthropic.com")

      response = client.post("/v1/messages") do |req|
        req.headers.merge!(auth.build_headers)
        req.body = {
          model: options[:model] || "claude-3-opus-20240229",
          messages: [ { role: "user", content: prompt } ],
          max_tokens: options[:max_tokens] || 2000,
          temperature: options[:temperature] || 0.7
        }.to_json
      end

      unless response.success?
        raise LlmIntegration::ProviderError.new("Anthropic API error: #{response.status}")
      end

      response.body.dig("content", 0, "text")
    end

    def call_cohere(prompt, options)
      auth = Authentication::CohereAuth.new
      client = build_http_client("https://api.cohere.ai")

      response = client.post("/v1/generate") do |req|
        req.headers.merge!(auth.build_headers)
        req.body = {
          model: options[:model] || "command-r-plus",
          prompt: prompt,
          max_tokens: options[:max_tokens] || 2000,
          temperature: options[:temperature] || 0.7
        }.to_json
      end

      unless response.success?
        raise LlmIntegration::ProviderError.new("Cohere API error: #{response.status}")
      end

      response.body.dig("generations", 0, "text")
    end

    def call_huggingface(prompt, options)
      auth = Authentication::HuggingFaceAuth.new
      model = options[:model] || "meta-llama/Llama-2-7b-chat-hf"
      client = build_http_client("https://api-inference.huggingface.co")

      response = client.post("/models/#{model}") do |req|
        req.headers.merge!(auth.build_headers)
        req.body = {
          inputs: prompt,
          parameters: {
            max_new_tokens: options[:max_tokens] || 2000,
            temperature: options[:temperature] || 0.7,
            return_full_text: false
          }
        }.to_json
      end

      unless response.success?
        raise LlmIntegration::ProviderError.new("HuggingFace API error: #{response.status}")
      end

      if response.body.is_a?(Array)
        response.body.first["generated_text"]
      else
        response.body["generated_text"]
      end
    end

    def build_http_client(base_url)
      Faraday.new(url: base_url) do |faraday|
        faraday.request :json
        faraday.response :json
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = @timeout
        faraday.options.open_timeout = 10
      end
    end

    def estimate_tokens(content)
      # Rough estimation: 1 token ≈ 4 characters for English text
      return 0 unless content.is_a?(String)
      (content.length / 4.0).ceil
    end
  end
end
