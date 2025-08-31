# frozen_string_literal: true

# Base provider class for LLM integrations
# Provides common functionality for all LLM providers including error handling,
# retries, circuit breakers, and response normalization
class LlmProviders::BaseProvider
  include LlmServiceInterface

  attr_reader :config, :client, :provider_name

  def initialize(config)
    @config = config
    @provider_name = self.class.name.demodulize.underscore.gsub('_provider', '')
    @client = build_client
    validate_configuration!
  end

  # Template method pattern for consistent request handling
  def make_request(method, params)
    start_time = Time.current
    
    begin
      with_timeout_and_retry do
        response = send("#{method}_request", params)
        record_success(start_time)
        transform_response(response, method)
      end
    rescue => error
      record_failure(error, start_time)
      raise
    end
  end

  # Health check for provider availability
  def health_check
    start_time = Time.current
    
    begin
      with_timeout_and_retry do
        response = health_check_request
        {
          status: 'healthy',
          provider: provider_name,
          response_time: (Time.current - start_time).round(3),
          metadata: {
            checked_at: Time.current,
            service: provider_name
          }
        }
      end
    rescue => error
      {
        status: 'unhealthy',
        provider: provider_name,
        error: error.message,
        response_time: (Time.current - start_time).round(3),
        metadata: {
          checked_at: Time.current,
          service: provider_name
        }
      }
    end
  end

  private

  # Must be implemented by subclasses
  def build_client
    raise NotImplementedError, "Subclasses must implement #build_client"
  end

  def health_check_request
    raise NotImplementedError, "Subclasses must implement #health_check_request"
  end

  def transform_response(response, method)
    raise NotImplementedError, "Subclasses must implement #transform_response"
  end

  # Timeout and retry wrapper
  def with_timeout_and_retry(&block)
    retry_count = 0
    max_retries = config[:retry_attempts] || 3
    
    begin
      Timeout.timeout(config[:timeout] || 30) do
        block.call
      end
    rescue *retriable_errors => error
      retry_count += 1
      if retry_count <= max_retries
        sleep_duration = (config[:retry_delay] || 1) * retry_count
        Rails.logger.warn "#{provider_name} request failed (attempt #{retry_count}/#{max_retries}), retrying in #{sleep_duration}s: #{error.message}"
        sleep(sleep_duration)
        retry
      else
        Rails.logger.error "#{provider_name} request failed after #{max_retries} retries: #{error.message}"
        raise
      end
    end
  end

  def retriable_errors
    [
      Timeout::Error,
      Faraday::TimeoutError,
      Faraday::ConnectionFailed,
      JSON::ParserError
    ]
  end

  def validate_configuration!
    raise ArgumentError, "API key missing for #{provider_name}" if config[:api_key].blank?
    raise ArgumentError, "Invalid timeout value" if config[:timeout] && config[:timeout] <= 0
    raise ArgumentError, "Invalid max_tokens value" if config[:max_tokens] && config[:max_tokens] <= 0
  end

  def record_success(start_time)
    duration = Time.current - start_time
    Rails.logger.info "#{provider_name} request successful - duration: #{(duration * 1000).round(2)}ms"
  end

  def record_failure(error, start_time)
    duration = Time.current - start_time
    Rails.logger.error "#{provider_name} request failed: #{error.class.name}: #{error.message} (duration: #{(duration * 1000).round(2)}ms)"
  end

  # Helper method to extract JSON from response text
  def extract_json(response_text)
    # Try to find JSON in the response (handles cases where LLM adds explanation)
    json_match = response_text.match(/\{.*\}/m)
    json_match ? json_match[0] : response_text
  end

  # Fallback response generator when LLM fails
  def generate_fallback_response(content_type, params = {})
    {
      content: "Generated #{content_type} content",
      metadata: {
        fallback_used: true,
        provider: provider_name,
        generated_at: Time.current,
        reason: "llm_service_unavailable"
      }
    }
  end

  # Build brand context string for prompts
  def build_brand_context(brand_context)
    return "" if brand_context.blank?

    sections = []
    sections << "Brand Voice: #{brand_context[:voice]}" if brand_context[:voice]
    sections << "Brand Tone: #{brand_context[:tone]}" if brand_context[:tone]
    sections << "Key Messages: #{brand_context[:keywords]&.join(', ')}" if brand_context[:keywords]&.any?
    sections << "Style Guidelines: #{format_style_guidelines(brand_context[:style])}" if brand_context[:style]

    sections.any? ? "Brand Context:\n#{sections.join("\n")}\n" : ""
  end

  def format_style_guidelines(style)
    return "" if style.blank?

    guidelines = []
    guidelines << "Emoji usage: #{style[:emoji] || 'allowed'}"
    guidelines << "Capitalization: #{style[:capitalization] || 'standard'}"
    guidelines << "Tone formality: #{style[:formality] || 'professional'}"

    guidelines.join(", ")
  end
end