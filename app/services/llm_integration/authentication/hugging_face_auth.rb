module LlmIntegration
  module Authentication
    class HuggingFaceAuth
      include ActiveModel::Model

      def initialize(api_key = nil)
        @api_key = api_key || ENV["HUGGINGFACE_API_KEY"]
      end

      def build_headers
        headers = {
          "Content-Type" => "application/json",
          "User-Agent" => user_agent
        }

        if @api_key.present?
          headers["Authorization"] = "Bearer #{@api_key}"
        end

        headers
      end

      def valid_key?
        # HuggingFace API key is optional for some models
        @api_key.blank? || (@api_key.present? && @api_key.start_with?("hf_"))
      end

      def masked_key
        return "Not set (using free tier)" unless @api_key.present?
        "#{@api_key[0..5]}...#{@api_key[-4..-1]}"
      end

      def test_connection
        client = Faraday.new(url: "https://api-inference.huggingface.co") do |faraday|
          faraday.request :json
          faraday.response :json
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = 30 # HF can be slower
        end

        # Test with a simple model
        test_model = "microsoft/DialoGPT-medium"
        response = client.post("/models/#{test_model}") do |req|
          req.headers.merge!(build_headers)
          req.body = {
            inputs: "Hello",
            parameters: { max_new_tokens: 5 }
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

      def estimate_cost(tokens_used, model = nil)
        # HuggingFace Inference API is often free for many models
        # Paid plans vary by model and usage
        return 0.0 unless @api_key.present?

        # Rough estimate for paid plans
        (tokens_used / 1000.0) * 0.001 # Very low cost estimate
      end

      def supported_models
        %w[
          meta-llama/Llama-2-7b-chat-hf
          meta-llama/Llama-2-13b-chat-hf
          mistralai/Mistral-7B-Instruct-v0.1
          microsoft/DialoGPT-medium
          facebook/blenderbot-400M-distill
          HuggingFaceH4/zephyr-7b-beta
        ]
      end

      def is_free_tier?
        @api_key.blank?
      end

      def requires_api_key_for_model?(model)
        # Some models require API keys, others don't
        premium_models = [
          "meta-llama/Llama-2-70b-chat-hf",
          "codellama/CodeLlama-34b-Instruct-hf"
        ]

        premium_models.include?(model)
      end

      private

      def validate_api_key!
        unless valid_key?
          raise LlmIntegration::AuthenticationError.new(
            "Invalid HuggingFace API key. Expected format: hf_..."
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

        case response.status
        when 401
          "Authentication failed. Please check your HuggingFace API key."
        when 403
          "Access forbidden. This model may require special permissions."
        when 429
          "Rate limit exceeded. Please wait before making more requests."
        when 503
          "Model is loading. Please wait a moment and try again."
        when 400
          "Bad request: #{error}"
        else
          error.is_a?(String) ? error : "Unknown error"
        end
      end
    end
  end
end
