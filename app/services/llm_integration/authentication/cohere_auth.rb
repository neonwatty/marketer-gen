module LlmIntegration
  module Authentication
    class CohereAuth
      include ActiveModel::Model

      def initialize(api_key = nil)
        @api_key = api_key || ENV["COHERE_API_KEY"]
      end

      def build_headers
        validate_api_key!

        {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json",
          "User-Agent" => user_agent,
          "Cohere-Version" => "2023-05-15"
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
        client = Faraday.new(url: "https://api.cohere.ai") do |faraday|
          faraday.request :json
          faraday.response :json
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = 10
        end

        # Test with models endpoint
        response = client.get("/v1/models") do |req|
          req.headers.merge!(build_headers)
        end

        {
          success: response.success?,
          status: response.status,
          models_count: response.success? ? response.body["models"]&.length : 0,
          error: response.success? ? nil : parse_error(response)
        }
      rescue Faraday::Error => e
        {
          success: false,
          status: 0,
          error: "Connection failed: #{e.message}"
        }
      end

      def estimate_cost(tokens_used, model = "command-r-plus")
        # Pricing per 1K tokens (as of 2024)
        pricing = {
          "command-r-plus" => 0.003,
          "command-r" => 0.0015,
          "command" => 0.002,
          "command-nightly" => 0.002
        }

        rate = pricing[model] || 0.002
        (tokens_used / 1000.0) * rate
      end

      def supported_models
        %w[
          command-r-plus
          command-r
          command
          command-nightly
        ]
      end

      private

      def validate_api_key!
        unless valid_key?
          raise LlmIntegration::AuthenticationError.new(
            "Invalid Cohere API key"
          )
        end
      end

      def user_agent
        "MarketerGen/1.0 (LLMIntegration)"
      end

      def parse_error(response)
        return "HTTP #{response.status}" unless response.body.is_a?(Hash)

        error = response.body["error"] || response.body["message"]
        return "HTTP #{response.status}" unless error

        case response.status
        when 401
          "Authentication failed. Please check your Cohere API key."
        when 429
          "Rate limit exceeded. Please wait before making more requests."
        when 400
          "Bad request: #{error}"
        when 500, 502, 503
          "Cohere service error. Please try again later."
        else
          error.is_a?(String) ? error : "Unknown error"
        end
      end
    end
  end
end
