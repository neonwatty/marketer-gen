module LlmIntegration
  module Authentication
    class AnthropicAuth
      include ActiveModel::Model

      def initialize(api_key = nil)
        @api_key = api_key || ENV["ANTHROPIC_API_KEY"]
      end

      def build_headers
        validate_api_key!

        {
          "x-api-key" => @api_key,
          "anthropic-version" => "2023-06-01",
          "Content-Type" => "application/json",
          "User-Agent" => user_agent
        }
      end

      def valid_key?
        @api_key.present? && @api_key.length > 20
      end

      def masked_key
        return "Not set" unless @api_key.present?
        "#{@api_key[0..5]}...#{@api_key[-4..-1]}"
      end

      def test_connection
        client = Faraday.new(url: "https://api.anthropic.com") do |faraday|
          faraday.request :json
          faraday.response :json
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = 10
        end

        # Test with a minimal request
        response = client.post("/v1/messages") do |req|
          req.headers.merge!(build_headers)
          req.body = {
            model: "claude-3-haiku-20240307",
            max_tokens: 10,
            messages: [ { role: "user", content: "Hello" } ]
          }.to_json
        end

        {
          success: response.success?,
          status: response.status,
          model_responded: response.success?,
          error: response.success? ? nil : parse_error(response)
        }
      rescue Faraday::Error => e
        {
          success: false,
          status: 0,
          error: "Connection failed: #{e.message}"
        }
      end

      def estimate_cost(tokens_used, model = "claude-3-opus-20240229")
        # Pricing per 1K tokens (as of 2024)
        pricing = {
          "claude-3-opus-20240229" => 0.015,
          "claude-3-sonnet-20240229" => 0.003,
          "claude-3-haiku-20240307" => 0.00025
        }

        rate = pricing[model] || 0.015
        (tokens_used / 1000.0) * rate
      end

      def supported_models
        %w[
          claude-3-opus-20240229
          claude-3-sonnet-20240229
          claude-3-haiku-20240307
        ]
      end

      private

      def validate_api_key!
        unless valid_key?
          raise LlmIntegration::AuthenticationError.new(
            "Invalid Anthropic API key"
          )
        end
      end

      def user_agent
        "MarketerGen/1.0 (LLMIntegration)"
      end

      def parse_error(response)
        return "HTTP #{response.status}" unless response.body.is_a?(Hash)

        error = response.body["error"]
        return "HTTP #{response.status}" unless error

        case error["type"]
        when "authentication_error"
          "Authentication failed. Please check your Anthropic API key."
        when "permission_error"
          "Permission denied. Please check your API key permissions."
        when "rate_limit_error"
          "Rate limit exceeded. Please wait before making more requests."
        when "overloaded_error"
          "Anthropic's servers are overloaded. Please try again later."
        else
          error["message"] || "Unknown error"
        end
      end
    end
  end
end
