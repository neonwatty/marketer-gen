# Abstract base class for AI service implementations
# Provides common interface and error handling for all AI service providers
class AIServiceBase
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Common error classes for AI operations
  class AIServiceError < StandardError; end
  class ProviderError < AIServiceError; end
  class RateLimitError < AIServiceError; end
  class AuthenticationError < AIServiceError; end
  class InvalidRequestError < AIServiceError; end
  class ContextTooLongError < AIServiceError; end
  class InsufficientCreditsError < AIServiceError; end
  class ProviderUnavailableError < AIServiceError; end

  # Configuration attributes
  attribute :provider_name, :string
  attribute :api_key, :string
  attribute :api_base_url, :string
  attribute :model_name, :string
  attribute :timeout_seconds, :integer, default: 30
  attribute :max_retries, :integer, default: 3
  attribute :retry_delay_seconds, :integer, default: 1

  # Request/response tracking
  attr_reader :last_request, :last_response, :errors

  def initialize(attributes = {})
    super(attributes)
    @errors = []
    @last_request = nil
    @last_response = nil
  end

  # Main interface methods - must be implemented by subclasses
  def generate_content(prompt, options = {})
    raise NotImplementedError, "Subclasses must implement #generate_content"
  end

  def generate_campaign_plan(campaign_data, options = {})
    raise NotImplementedError, "Subclasses must implement #generate_campaign_plan"
  end

  def analyze_brand_assets(assets, options = {})
    raise NotImplementedError, "Subclasses must implement #analyze_brand_assets"
  end

  def generate_content_for_channel(channel, brand_context, options = {})
    raise NotImplementedError, "Subclasses must implement #generate_content_for_channel"
  end

  # Provider capability checks
  def supports_function_calling?
    false
  end

  def supports_image_analysis?
    false
  end

  def supports_streaming?
    false
  end

  def max_context_tokens
    4096 # Conservative default
  end

  # Health check and validation
  def healthy?
    validate_configuration
    test_connection
  rescue => e
    @errors << "Health check failed: #{e.message}"
    false
  end

  def validate_configuration
    raise InvalidRequestError, "Provider name is required" if provider_name.blank?
    raise InvalidRequestError, "API key is required" if api_key.blank?
    raise InvalidRequestError, "Model name is required" if model_name.blank?
    true
  end

  def test_connection
    # Subclasses should override with provider-specific health check
    true
  end

  protected

  # Common request handling with retries and error handling
  def make_request_with_retries(request_proc)
    attempt = 0
    last_error = nil

    while attempt < max_retries
      begin
        @last_request = log_request_start(attempt)
        response = request_proc.call
        @last_response = log_request_success(response)
        return response
      rescue RateLimitError => e
        last_error = e
        sleep_duration = calculate_backoff_delay(attempt, retry_delay_seconds)
        Rails.logger.warn "Rate limited on attempt #{attempt + 1}, retrying in #{sleep_duration}s: #{e.message}"
        sleep(sleep_duration)
      rescue ProviderUnavailableError => e
        last_error = e
        sleep_duration = calculate_backoff_delay(attempt, retry_delay_seconds * 2)
        Rails.logger.warn "Provider unavailable on attempt #{attempt + 1}, retrying in #{sleep_duration}s: #{e.message}"
        sleep(sleep_duration)
      rescue AuthenticationError, InvalidRequestError, ContextTooLongError => e
        # These errors shouldn't be retried
        log_request_error(e)
        raise e
      rescue => e
        last_error = e
        Rails.logger.warn "Request failed on attempt #{attempt + 1}: #{e.message}"
      end

      attempt += 1
    end

    log_request_error(last_error)
    raise last_error || AIServiceError.new("Request failed after #{max_retries} attempts")
  end

  # Exponential backoff calculation
  def calculate_backoff_delay(attempt, base_delay)
    base_delay * (2 ** attempt) + rand(0..1.0)
  end

  # Logging methods
  def log_request_start(attempt)
    Rails.logger.info "AI request starting (attempt #{attempt + 1}/#{max_retries}) - Provider: #{provider_name}, Model: #{model_name}"
    {
      timestamp: Time.current,
      provider: provider_name,
      model: model_name,
      attempt: attempt + 1
    }
  end

  def log_request_success(response)
    duration = Time.current - @last_request[:timestamp]
    Rails.logger.info "AI request completed successfully in #{duration.round(2)}s"
    {
      timestamp: Time.current,
      duration: duration,
      success: true,
      response_size: response.to_s.length
    }
  end

  def log_request_error(error)
    duration = @last_request ? Time.current - @last_request[:timestamp] : 0
    Rails.logger.error "AI request failed after #{duration.round(2)}s: #{error.class.name} - #{error.message}"
    @errors << "#{error.class.name}: #{error.message}"
    {
      timestamp: Time.current,
      duration: duration,
      success: false,
      error_class: error.class.name,
      error_message: error.message
    }
  end

  # Content processing utilities
  def sanitize_prompt(prompt)
    return "" if prompt.blank?
    
    # Remove potential injection attempts and clean up
    cleaned = prompt.gsub(/\r\n|\r/, "\n")  # Normalize line endings
                   .gsub(/\n{3,}/, "\n\n")   # Reduce excessive newlines
                   .strip

    # Truncate if too long (leave room for system prompts)
    max_prompt_length = max_context_tokens - 1000
    if cleaned.length > max_prompt_length
      cleaned = cleaned[0..max_prompt_length] + "\n\n[Content truncated due to length limits]"
    end

    cleaned
  end

  def extract_json_from_response(response_text)
    # Try to extract JSON from markdown code blocks or raw text
    json_match = response_text.match(/```(?:json)?\s*(\{.*?\})\s*```/m) ||
                response_text.match(/(\{.*?\})/m)
    
    return nil unless json_match
    
    begin
      JSON.parse(json_match[1])
    rescue JSON::ParserError => e
      Rails.logger.warn "Failed to parse JSON from AI response: #{e.message}"
      nil
    end
  end

  # Token counting estimation (provider-specific implementations should override)
  def estimate_token_count(text)
    # Rough estimation: ~4 characters per token for English text
    (text.to_s.length / 4.0).ceil
  end
end