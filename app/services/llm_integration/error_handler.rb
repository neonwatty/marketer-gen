module LlmIntegration
  class ErrorHandler
    include ActiveModel::Model

    # Error type hierarchy
    class ProviderError < StandardError; end
    class AuthenticationError < ProviderError; end
    class RateLimitError < ProviderError; end
    class ServerError < ProviderError; end
    class TimeoutError < ProviderError; end
    class QuotaExceededError < ProviderError; end
    class UnsupportedProviderError < ProviderError; end
    class AllProvidersFailedError < ProviderError; end

    def initialize
      @retry_strategies = {
        RateLimitError => :wait_and_retry,
        ServerError => :retry_with_backoff,
        TimeoutError => :retry_with_backoff,
        QuotaExceededError => :switch_provider,
        AuthenticationError => :no_retry
      }
    end

    def retryable?(error)
      retryable_errors = [
        RateLimitError,
        ServerError,
        TimeoutError,
        QuotaExceededError
      ]

      retryable_errors.any? { |error_class| error.is_a?(error_class) }
    end

    def suggest_recovery(error)
      error_class = error.class
      strategy = @retry_strategies[error_class] || :no_retry

      case strategy
      when :wait_and_retry
        {
          strategy: :wait_and_retry,
          wait_time: extract_wait_time(error),
          max_retries: 3,
          description: "Wait for the specified time and retry the request"
        }
      when :retry_with_backoff
        {
          strategy: :retry_with_backoff,
          initial_wait: 1,
          backoff_multiplier: 2,
          max_retries: 3,
          description: "Retry with exponential backoff"
        }
      when :switch_provider
        {
          strategy: :switch_provider,
          suggested_providers: suggest_alternative_providers,
          description: "Switch to an alternative provider"
        }
      when :no_retry
        {
          strategy: :no_retry,
          description: "Error is not retryable, manual intervention required",
          suggested_actions: suggest_manual_actions(error)
        }
      else
        {
          strategy: :unknown,
          description: "Unknown error type, manual investigation required"
        }
      end
    end

    def classify_error(error_response)
      status = error_response[:status] || 0
      message = error_response[:message] || error_response[:details] || ""

      case status
      when 401, 403
        AuthenticationError.new("Authentication failed: #{message}")
      when 429
        RateLimitError.new("Rate limit exceeded: #{message}")
      when 402, 409
        QuotaExceededError.new("Quota exceeded: #{message}")
      when 500, 502, 503, 504
        ServerError.new("Server error: #{message}")
      when 408, 524
        TimeoutError.new("Request timeout: #{message}")
      else
        ProviderError.new("Provider error (#{status}): #{message}")
      end
    end

    def handle_error(error, context = {})
      classified_error = if error.is_a?(StandardError) && !error.is_a?(ProviderError)
        classify_error(
          status: context[:status] || 0,
          message: error.message
        )
      else
        error
      end

      recovery_plan = suggest_recovery(classified_error)

      # Log the error with context
      log_error(classified_error, context, recovery_plan)

      {
        error: classified_error,
        recovery_plan: recovery_plan,
        retryable: retryable?(classified_error),
        context: context
      }
    end

    def execute_recovery_strategy(strategy, context = {})
      case strategy[:strategy]
      when :wait_and_retry
        sleep(strategy[:wait_time])
        { action: :retry, wait_time: strategy[:wait_time] }

      when :retry_with_backoff
        attempt = context[:attempt] || 1
        wait_time = strategy[:initial_wait] * (strategy[:backoff_multiplier] ** (attempt - 1))
        sleep(wait_time)
        { action: :retry, wait_time: wait_time, next_attempt: attempt + 1 }

      when :switch_provider
        next_provider = strategy[:suggested_providers]&.first
        { action: :switch_provider, provider: next_provider }

      when :no_retry
        { action: :abort, reason: strategy[:description] }

      else
        { action: :unknown, strategy: strategy }
      end
    end

    def error_metrics(timeframe = 24.hours)
      # This would typically integrate with your logging/metrics system
      # For now, return a placeholder structure
      {
        total_errors: 0,
        error_breakdown: {},
        most_common_errors: [],
        provider_error_rates: {},
        recovery_success_rates: {}
      }
    end

    def is_critical_error?(error)
      critical_errors = [
        AuthenticationError,
        AllProvidersFailedError
      ]

      critical_errors.any? { |error_class| error.is_a?(error_class) }
    end

    def format_error_for_user(error)
      case error
      when AuthenticationError
        "Authentication failed. Please check your API credentials."
      when RateLimitError
        "Request rate limit exceeded. Please wait a moment before trying again."
      when QuotaExceededError
        "Usage quota exceeded. Please check your account limits."
      when ServerError
        "Service temporarily unavailable. Please try again in a few minutes."
      when TimeoutError
        "Request timed out. Please try again with a shorter request."
      when AllProvidersFailedError
        "All AI services are currently unavailable. Please try again later."
      else
        "An unexpected error occurred. Please try again or contact support."
      end
    end

    private

    def extract_wait_time(error)
      # Try to extract wait time from rate limit headers or error message
      message = error.message.to_s

      # Look for "retry after X seconds" patterns
      if match = message.match(/retry.*?(\d+).*?seconds?/i)
        match[1].to_i
      elsif match = message.match(/wait.*?(\d+).*?seconds?/i)
        match[1].to_i
      else
        60 # Default to 60 seconds
      end
    end

    def suggest_alternative_providers
      # Return available providers in order of preference
      [ :anthropic, :cohere, :openai, :huggingface ]
    end

    def suggest_manual_actions(error)
      case error
      when AuthenticationError
        [
          "Verify your API key is correct",
          "Check if your API key has the required permissions",
          "Ensure your account is in good standing"
        ]
      when QuotaExceededError
        [
          "Upgrade your plan for higher limits",
          "Wait for your quota to reset",
          "Optimize your requests to use fewer tokens"
        ]
      else
        [
          "Contact support if the issue persists",
          "Check the service status page",
          "Try again later"
        ]
      end
    end

    def log_error(error, context, recovery_plan)
      log_level = is_critical_error?(error) ? :error : :warn

      Rails.logger.send(log_level, {
        message: "LLM Integration Error",
        error_class: error.class.name,
        error_message: error.message,
        context: context,
        recovery_plan: recovery_plan[:strategy],
        retryable: retryable?(error),
        timestamp: Time.current.iso8601
      }.to_json)
    end
  end
end
