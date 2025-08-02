module LlmIntegration
  class ProviderError < StandardError
    attr_reader :provider, :error_code, :retry_after

    def initialize(message, provider: nil, error_code: nil, retry_after: nil)
      super(message)
      @provider = provider
      @error_code = error_code
      @retry_after = retry_after
    end

    def retryable?
      case error_code
      when "rate_limit", "temporary_unavailable", "server_error"
        true
      else
        false
      end
    end

    def to_h
      {
        message: message,
        provider: provider,
        error_code: error_code,
        retry_after: retry_after,
        retryable: retryable?
      }
    end
  end

  class AuthenticationError < ProviderError
    def initialize(message, provider: nil)
      super(message, provider: provider, error_code: "authentication_error")
    end

    def retryable?
      false
    end
  end

  class RateLimitError < ProviderError
    def initialize(message, provider: nil, retry_after: nil)
      super(message, provider: provider, error_code: "rate_limit", retry_after: retry_after)
    end

    def retryable?
      true
    end
  end

  class QuotaExceededError < ProviderError
    def initialize(message, provider: nil)
      super(message, provider: provider, error_code: "quota_exceeded")
    end

    def retryable?
      false
    end
  end

  class ModelNotAvailableError < ProviderError
    def initialize(message, provider: nil, model: nil)
      super("#{message}#{model ? " (Model: #{model})" : ""}",
            provider: provider, error_code: "model_not_available")
      @model = model
    end

    def retryable?
      false
    end
  end

  class ContentPolicyViolationError < ProviderError
    def initialize(message, provider: nil)
      super(message, provider: provider, error_code: "content_policy_violation")
    end

    def retryable?
      false
    end
  end

  class ServiceUnavailableError < ProviderError
    def initialize(message, provider: nil, retry_after: nil)
      super(message, provider: provider, error_code: "service_unavailable", retry_after: retry_after)
    end

    def retryable?
      true
    end
  end
end
