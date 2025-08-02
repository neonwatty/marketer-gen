module LlmIntegration
  class RateLimiter
    include ActiveModel::Model

    BACKOFF_STRATEGIES = %i[linear exponential].freeze

    attr_accessor :requests_per_minute, :requests_per_hour, :backoff_strategy

    def initialize(options = {})
      @requests_per_minute = options[:requests_per_minute] || 60
      @requests_per_hour = options[:requests_per_hour] || 3000
      @backoff_strategy = options[:backoff_strategy] || :exponential
      @request_times = {}
      @attempt_counts = {}
    end

    def can_make_request?(provider = :default)
      !rate_limited?(provider)
    end

    def rate_limited?(provider = :default)
      requests_in_last_minute(provider) >= @requests_per_minute ||
        requests_in_last_hour(provider) >= @requests_per_hour
    end

    def record_request(provider = :default)
      @request_times[provider] ||= []
      @request_times[provider] << Time.current
      cleanup_old_requests(provider)
    end

    def requests_in_last_minute(provider = :default)
      return 0 unless @request_times[provider]

      one_minute_ago = Time.current - 1.minute
      @request_times[provider].count { |time| time > one_minute_ago }
    end

    def requests_in_last_hour(provider = :default)
      return 0 unless @request_times[provider]

      one_hour_ago = Time.current - 1.hour
      @request_times[provider].count { |time| time > one_hour_ago }
    end

    def time_until_next_request(provider = :default)
      return 0 unless rate_limited?(provider)

      if requests_in_last_minute(provider) >= @requests_per_minute
        time_until_minute_window_resets(provider)
      elsif requests_in_last_hour(provider) >= @requests_per_hour
        time_until_hour_window_resets(provider)
      else
        0
      end
    end

    def calculate_backoff(attempt:, provider: :default)
      @attempt_counts[provider] = attempt

      case @backoff_strategy
      when :linear
        attempt * 2.0 # 2, 4, 6, 8 seconds
      when :exponential
        2.0 ** attempt # 2, 4, 8, 16 seconds
      else
        2.0 ** attempt
      end
    end

    def reset_attempts!(provider = :default)
      @attempt_counts[provider] = 0
    end

    def wait_if_needed(provider = :default)
      wait_time = time_until_next_request(provider)
      if wait_time > 0
        Rails.logger.info "Rate limited for provider #{provider}, waiting #{wait_time} seconds"
        sleep(wait_time)
      end
    end

    def status(provider = :default)
      {
        requests_per_minute: {
          current: requests_in_last_minute(provider),
          limit: @requests_per_minute,
          remaining: [ @requests_per_minute - requests_in_last_minute(provider), 0 ].max
        },
        requests_per_hour: {
          current: requests_in_last_hour(provider),
          limit: @requests_per_hour,
          remaining: [ @requests_per_hour - requests_in_last_hour(provider), 0 ].max
        },
        rate_limited: rate_limited?(provider),
        time_until_next_request: time_until_next_request(provider),
        current_attempt: @attempt_counts[provider] || 0
      }
    end

    def all_statuses
      providers = @request_times.keys
      providers.each_with_object({}) do |provider, statuses|
        statuses[provider] = status(provider)
      end
    end

    def configure_limits(requests_per_minute: nil, requests_per_hour: nil)
      @requests_per_minute = requests_per_minute if requests_per_minute
      @requests_per_hour = requests_per_hour if requests_per_hour
    end

    def reset_all!
      @request_times.clear
      @attempt_counts.clear
    end

    def reset!(provider = :default)
      @request_times[provider] = []
      @attempt_counts[provider] = 0
    end

    private

    def cleanup_old_requests(provider)
      return unless @request_times[provider]

      one_hour_ago = Time.current - 1.hour
      @request_times[provider].reject! { |time| time < one_hour_ago }
    end

    def time_until_minute_window_resets(provider)
      return 0 unless @request_times[provider] && @request_times[provider].any?

      oldest_request_in_window = @request_times[provider]
        .select { |time| time > Time.current - 1.minute }
        .min

      return 0 unless oldest_request_in_window

      time_until_reset = (oldest_request_in_window + 1.minute) - Time.current
      [ time_until_reset, 0 ].max
    end

    def time_until_hour_window_resets(provider)
      return 0 unless @request_times[provider] && @request_times[provider].any?

      oldest_request_in_window = @request_times[provider]
        .select { |time| time > Time.current - 1.hour }
        .min

      return 0 unless oldest_request_in_window

      time_until_reset = (oldest_request_in_window + 1.hour) - Time.current
      [ time_until_reset, 0 ].max
    end
  end
end
