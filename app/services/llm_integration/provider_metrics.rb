module LlmIntegration
  class ProviderMetrics
    include ActiveModel::Model

    def initialize
      @request_history = {}
      @error_history = {}
    end

    def record_request(provider, duration:, tokens:, success:, error: nil)
      @request_history[provider] ||= []
      @request_history[provider] << {
        timestamp: Time.current,
        duration: duration,
        tokens: tokens,
        success: success,
        error: error
      }

      # Keep only last 1000 requests per provider
      @request_history[provider] = @request_history[provider].last(1000)

      if error
        @error_history[provider] ||= []
        @error_history[provider] << {
          timestamp: Time.current,
          error: error,
          duration: duration
        }
        @error_history[provider] = @error_history[provider].last(100)
      end
    end

    def provider_stats(provider)
      requests = @request_history[provider] || []
      return default_stats if requests.empty?

      successful_requests = requests.select { |r| r[:success] }

      {
        total_requests: requests.length,
        successful_requests: successful_requests.length,
        failed_requests: requests.length - successful_requests.length,
        success_rate: (successful_requests.length.to_f / requests.length * 100).round(2),
        avg_response_time: successful_requests.map { |r| r[:duration] }.sum.to_f / successful_requests.length,
        total_tokens_used: requests.map { |r| r[:tokens] }.sum,
        avg_tokens_per_request: requests.map { |r| r[:tokens] }.sum.to_f / requests.length,
        last_request_at: requests.last[:timestamp],
        requests_last_hour: requests.count { |r| r[:timestamp] > 1.hour.ago },
        requests_last_24h: requests.count { |r| r[:timestamp] > 24.hours.ago }
      }
    end

    def recent_errors(provider, limit = 10)
      errors = @error_history[provider] || []
      errors.last(limit).reverse
    end

    def success_rate(provider, timeframe = 24.hours)
      requests = @request_history[provider] || []
      recent_requests = requests.select { |r| r[:timestamp] > timeframe.ago }

      return 100.0 if recent_requests.empty?

      successful = recent_requests.count { |r| r[:success] }
      (successful.to_f / recent_requests.length * 100).round(2)
    end

    def average_response_time(provider, timeframe = 24.hours)
      requests = @request_history[provider] || []
      recent_requests = requests.select { |r| r[:timestamp] > timeframe.ago && r[:success] }

      return 0.0 if recent_requests.empty?

      total_time = recent_requests.map { |r| r[:duration] }.sum
      (total_time / recent_requests.length).round(3)
    end

    def tokens_used(provider, timeframe = 24.hours)
      requests = @request_history[provider] || []
      recent_requests = requests.select { |r| r[:timestamp] > timeframe.ago }

      recent_requests.map { |r| r[:tokens] }.sum
    end

    def estimated_cost(provider, timeframe = 24.hours)
      tokens = tokens_used(provider, timeframe)

      # Rough cost estimates per 1K tokens
      cost_per_1k = case provider.to_sym
      when :openai then 0.03
      when :anthropic then 0.015
      when :cohere then 0.002
      when :huggingface then 0.0
      else 0.01
      end

      (tokens / 1000.0) * cost_per_1k
    end

    def provider_comparison(timeframe = 24.hours)
      providers = @request_history.keys

      providers.each_with_object({}) do |provider, comparison|
        comparison[provider] = {
          success_rate: success_rate(provider, timeframe),
          avg_response_time: average_response_time(provider, timeframe),
          tokens_used: tokens_used(provider, timeframe),
          estimated_cost: estimated_cost(provider, timeframe),
          request_count: (@request_history[provider] || []).count { |r| r[:timestamp] > timeframe.ago }
        }
      end
    end

    def performance_trend(provider, timeframe = 7.days)
      requests = @request_history[provider] || []
      recent_requests = requests.select { |r| r[:timestamp] > timeframe.ago }

      return [] if recent_requests.empty?

      # Group by hour for trend analysis
      hourly_data = recent_requests.group_by { |r| r[:timestamp].beginning_of_hour }

      hourly_data.map do |hour, hour_requests|
        successful = hour_requests.count { |r| r[:success] }
        {
          timestamp: hour,
          request_count: hour_requests.length,
          success_rate: (successful.to_f / hour_requests.length * 100).round(2),
          avg_response_time: hour_requests.select { |r| r[:success] }.map { |r| r[:duration] }.sum.to_f / successful,
          tokens_used: hour_requests.map { |r| r[:tokens] }.sum
        }
      end.sort_by { |data| data[:timestamp] }
    end

    def health_score(provider)
      stats = provider_stats(provider)
      return 0 if stats[:total_requests] == 0

      # Calculate health score based on multiple factors
      success_score = stats[:success_rate] / 100.0 * 40 # 40% weight

      # Response time score (faster is better, normalize to 0-30)
      response_time_score = if stats[:avg_response_time] <= 1.0
        30
      elsif stats[:avg_response_time] <= 3.0
        20
      elsif stats[:avg_response_time] <= 5.0
        10
      else
        5
      end

      # Recent activity score (more recent activity is better)
      recency_score = if stats[:last_request_at] > 1.hour.ago
        20
      elsif stats[:last_request_at] > 6.hours.ago
        15
      elsif stats[:last_request_at] > 24.hours.ago
        10
      else
        5
      end

      # Error rate score
      error_rate = 100 - stats[:success_rate]
      error_score = if error_rate <= 5
        10
      elsif error_rate <= 15
        5
      else
        0
      end

      (success_score + response_time_score + recency_score + error_score).round(2)
    end

    def reset_metrics!(provider = nil)
      if provider
        @request_history[provider] = []
        @error_history[provider] = []
      else
        @request_history.clear
        @error_history.clear
      end
    end

    def export_metrics(provider = nil, format = :json)
      data = if provider
        { provider => provider_stats(provider) }
      else
        @request_history.keys.each_with_object({}) do |p, hash|
          hash[p] = provider_stats(p)
        end
      end

      case format
      when :json
        data.to_json
      when :csv
        # Basic CSV export implementation
        export_to_csv(data)
      else
        data
      end
    end

    private

    def default_stats
      {
        total_requests: 0,
        successful_requests: 0,
        failed_requests: 0,
        success_rate: 0.0,
        avg_response_time: 0.0,
        total_tokens_used: 0,
        avg_tokens_per_request: 0.0,
        last_request_at: nil,
        requests_last_hour: 0,
        requests_last_24h: 0
      }
    end

    def export_to_csv(data)
      return "" if data.empty?

      headers = data.values.first.keys
      csv_content = headers.join(",") + "\n"

      data.each do |provider, stats|
        row = [ provider ] + headers.map { |h| stats[h] }
        csv_content += row.join(",") + "\n"
      end

      csv_content
    end
  end
end
