module LlmIntegration
  class CircuitBreaker
    include ActiveModel::Model

    STATES = %i[closed open half_open].freeze

    attr_accessor :failure_threshold, :timeout_duration, :retry_timeout

    def initialize(options = {})
      @failure_threshold = options[:failure_threshold] || 3
      @timeout_duration = options[:timeout_duration] || 60 # seconds
      @retry_timeout = options[:retry_timeout] || 300 # seconds
      @failure_counts = {}
      @last_failure_times = {}
      @states = {}
      @last_success_times = {}
    end

    def state(provider = :default)
      @states[provider] ||= :closed
    end

    def call(provider = :default, &block)
      case state(provider)
      when :open
        if should_attempt_reset?(provider)
          transition_to_half_open(provider)
        else
          raise CircuitBreakerOpenError.new("Circuit breaker is open for provider: #{provider}")
        end
      when :half_open
        # Allow one request to test if service is back
      when :closed
        # Normal operation
      end

      begin
        result = block.call
        record_success(provider)
        result
      rescue => e
        record_failure(provider)
        raise e
      end
    end

    def record_failure(provider = :default)
      @failure_counts[provider] = (@failure_counts[provider] || 0) + 1
      @last_failure_times[provider] = Time.current

      if @failure_counts[provider] >= @failure_threshold
        transition_to_open(provider)
      end
    end

    def record_success(provider = :default)
      reset_failure_count(provider)
      @last_success_times[provider] = Time.current

      if state(provider) == :half_open
        transition_to_closed(provider)
      end
    end

    def available?(provider = :default)
      state(provider) != :open || should_attempt_reset?(provider)
    end

    def reset!(provider = :default)
      reset_failure_count(provider)
      transition_to_closed(provider)
    end

    def failure_count(provider = :default)
      @failure_counts[provider] || 0
    end

    def last_failure_time(provider = :default)
      @last_failure_times[provider]
    end

    def time_since_last_failure(provider = :default)
      return nil unless @last_failure_times[provider]
      Time.current - @last_failure_times[provider]
    end

    def status(provider = :default)
      {
        state: state(provider),
        failure_count: failure_count(provider),
        last_failure: last_failure_time(provider),
        time_since_last_failure: time_since_last_failure(provider),
        available: available?(provider),
        next_retry_at: next_retry_time(provider)
      }
    end

    def all_statuses
      providers = (@failure_counts.keys + @states.keys).uniq
      providers.each_with_object({}) do |provider, statuses|
        statuses[provider] = status(provider)
      end
    end

    private

    def should_attempt_reset?(provider)
      return false unless @last_failure_times[provider]
      time_since_last_failure(provider) >= @retry_timeout
    end

    def transition_to_open(provider)
      @states[provider] = :open
      Rails.logger.warn "Circuit breaker opened for provider: #{provider}"
    end

    def transition_to_half_open(provider)
      @states[provider] = :half_open
      Rails.logger.info "Circuit breaker half-open for provider: #{provider}"
    end

    def transition_to_closed(provider)
      @states[provider] = :closed
      Rails.logger.info "Circuit breaker closed for provider: #{provider}"
    end

    def reset_failure_count(provider)
      @failure_counts[provider] = 0
    end

    def next_retry_time(provider)
      return nil unless @last_failure_times[provider]
      return nil unless state(provider) == :open

      @last_failure_times[provider] + @retry_timeout
    end
  end

  class CircuitBreakerOpenError < StandardError; end
end
