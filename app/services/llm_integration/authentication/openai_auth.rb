module LlmIntegration
  module Authentication
    class OpenAIAuth
      include ActiveModel::Model

      def initialize(api_key = nil)
        @api_key = api_key || ENV["OPENAI_API_KEY"]
      end

      def build_headers
        validate_api_key!

        {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json",
          "User-Agent" => user_agent
        }
      end

      def valid_key?
        @api_key.present? && @api_key.start_with?("sk-")
      end

      def masked_key
        return "Not set" unless @api_key.present?
        "#{@api_key[0..5]}...#{@api_key[-4..-1]}"
      end

      def test_connection
        client = Faraday.new(url: "https://api.openai.com") do |faraday|
          faraday.request :json
          faraday.response :json
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = 10
        end

        response = client.get("/v1/models") do |req|
          req.headers.merge!(build_headers)
        end

        {
          success: response.success?,
          status: response.status,
          models_count: response.success? ? response.body["data"]&.length : 0,
          error: response.success? ? nil : parse_error(response)
        }
      rescue Faraday::Error => e
        {
          success: false,
          status: 0,
          error: "Connection failed: #{e.message}"
        }
      end

      def estimate_cost(tokens_used, model = "gpt-4-turbo-preview")
        # Pricing per 1K tokens (as of 2024)
        pricing = {
          "gpt-4-turbo-preview" => 0.03,
          "gpt-4" => 0.06,
          "gpt-3.5-turbo" => 0.002,
          "gpt-3.5-turbo-16k" => 0.004
        }

        rate = pricing[model] || 0.03
        (tokens_used / 1000.0) * rate
      end

      private

      def validate_api_key!
        unless valid_key?
          raise LlmIntegration::AuthenticationError.new(
            "Invalid OpenAI API key. Expected format: sk-..."
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
        when "insufficient_quota"
          "Insufficient quota. Please check your OpenAI billing."
        when "invalid_api_key"
          "Invalid API key. Please check your OpenAI API key."
        when "rate_limit_exceeded"
          "Rate limit exceeded. Please wait before making more requests."
        else
          error["message"] || "Unknown error"
        end
      end
    end
  end
end
