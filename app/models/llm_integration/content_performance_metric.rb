module LlmIntegration
  class ContentPerformanceMetric < ApplicationRecord
    self.table_name = "content_performance_metrics"

    # Constants
    METRIC_TYPES = %i[
      email_open_rate click_through_rate conversion_rate engagement_rate
      bounce_rate time_on_page social_shares comment_rate like_rate
      impression_count reach_count video_completion_rate
    ].freeze

    CHANNELS = %i[
      email social_media website blog landing_page
      advertisement video podcast newsletter
    ].freeze

    # Associations
    belongs_to :generated_content, class_name: "LlmIntegration::GeneratedContent"
    belongs_to :content_variant, class_name: "LlmIntegration::ContentVariant", optional: true

    # Validations
    validates :metric_type, presence: true, inclusion: {
      in: METRIC_TYPES.map(&:to_s),
      message: "%{value} is not a valid metric type"
    }
    validates :metric_value, presence: true, numericality: true
    validates :sample_size, presence: true,
              numericality: { greater_than: 0, message: "must be greater than 0" }
    validates :measurement_period, presence: true,
              numericality: { greater_than: 0 }
    validates :channel, presence: true, inclusion: {
      in: CHANNELS.map(&:to_s),
      message: "%{value} is not a valid channel"
    }
    validates :recorded_at, presence: true
    validate :metric_value_range_for_rates

    # Enums
    enum metric_type: METRIC_TYPES.each_with_object({}) { |type, hash| hash[type] = type.to_s }
    enum channel: CHANNELS.each_with_object({}) { |channel, hash| hash[channel] = channel.to_s }

    # Scopes
    scope :for_content, ->(content) { where(generated_content: content) }
    scope :by_metric_type, ->(type) { where(metric_type: type) }
    scope :by_channel, ->(channel) { where(channel: channel) }
    scope :recent, -> { order(recorded_at: :desc) }
    scope :within_period, ->(start_date, end_date) { where(recorded_at: start_date..end_date) }
    scope :high_performance, -> { where("metric_value > ?", 0.1) }

    # Callbacks
    after_create :update_content_performance_cache

    # Instance methods
    def metric_value_percentage
      case metric_type.to_sym
      when :email_open_rate, :click_through_rate, :conversion_rate,
           :engagement_rate, :bounce_rate, :video_completion_rate
        (metric_value * 100).round(2)
      else
        metric_value
      end
    end

    def is_rate_metric?
      %w[email_open_rate click_through_rate conversion_rate engagement_rate bounce_rate video_completion_rate].include?(metric_type)
    end

    def is_count_metric?
      %w[impression_count reach_count social_shares comment_rate like_rate].include?(metric_type)
    end

    def benchmark_comparison
      # Compare against industry benchmarks (placeholder implementation)
      benchmark = industry_benchmark
      return nil unless benchmark

      {
        actual: metric_value,
        benchmark: benchmark,
        difference: metric_value - benchmark,
        percentage_diff: ((metric_value - benchmark) / benchmark * 100).round(2),
        performance: metric_value > benchmark ? "above" : "below"
      }
    end

    def confidence_interval
      # Calculate 95% confidence interval for the metric
      return nil if sample_size < 30

      z_score = 1.96 # 95% confidence
      standard_error = Math.sqrt((metric_value * (1 - metric_value)) / sample_size)
      margin_of_error = z_score * standard_error

      {
        lower_bound: [ metric_value - margin_of_error, 0 ].max,
        upper_bound: [ metric_value + margin_of_error, 1 ].min,
        margin_of_error: margin_of_error
      }
    end

    def statistical_significance(other_metric)
      return nil unless other_metric.is_a?(ContentPerformanceMetric)
      return nil unless metric_type == other_metric.metric_type

      # Simplified statistical significance test
      p1 = metric_value
      p2 = other_metric.metric_value
      n1 = sample_size
      n2 = other_metric.sample_size

      pooled_p = ((p1 * n1) + (p2 * n2)) / (n1 + n2)
      standard_error = Math.sqrt(pooled_p * (1 - pooled_p) * ((1.0/n1) + (1.0/n2)))

      return nil if standard_error.zero?

      z_score = (p1 - p2) / standard_error
      p_value = 2 * (1 - normal_cdf(z_score.abs))

      {
        z_score: z_score,
        p_value: p_value,
        significant: p_value < 0.05,
        confidence_level: (1 - p_value) * 100
      }
    end

    def trend_direction
      # Compare with previous metrics of the same type
      previous_metric = ContentPerformanceMetric
        .where(generated_content: generated_content, metric_type: metric_type)
        .where("recorded_at < ?", recorded_at)
        .order(recorded_at: :desc)
        .first

      return :no_data unless previous_metric

      if metric_value > previous_metric.metric_value
        :improving
      elsif metric_value < previous_metric.metric_value
        :declining
      else
        :stable
      end
    end

    def performance_grade
      benchmark = industry_benchmark
      return "N/A" unless benchmark

      ratio = metric_value / benchmark
      case ratio
      when 1.5.. then "A+"
      when 1.25...1.5 then "A"
      when 1.1...1.25 then "B+"
      when 0.9...1.1 then "B"
      when 0.75...0.9 then "C+"
      when 0.5...0.75 then "C"
      else "D"
      end
    end

    def measurement_period_in_words
      days = measurement_period / 1.day
      if days >= 30
        months = (days / 30).round
        "#{months} month#{'s' if months != 1}"
      elsif days >= 7
        weeks = (days / 7).round
        "#{weeks} week#{'s' if weeks != 1}"
      else
        "#{days.round} day#{'s' if days.round != 1}"
      end
    end

    def export_data
      {
        metric_type: metric_type,
        metric_value: metric_value,
        metric_value_percentage: metric_value_percentage,
        sample_size: sample_size,
        channel: channel,
        audience_segment: audience_segment,
        measurement_period: measurement_period_in_words,
        recorded_at: recorded_at.iso8601,
        benchmark_comparison: benchmark_comparison,
        confidence_interval: confidence_interval,
        performance_grade: performance_grade
      }
    end

    private

    def metric_value_range_for_rates
      return unless is_rate_metric?

      unless metric_value.between?(0, 1)
        errors.add(:metric_value, "must be between 0 and 1 for rate metrics")
      end
    end

    def industry_benchmark
      # Industry benchmarks (placeholder - would come from external data)
      benchmarks = {
        "email_open_rate" => {
          "default" => 0.21,
          "b2b" => 0.18,
          "b2c" => 0.24
        },
        "click_through_rate" => {
          "default" => 0.025,
          "email" => 0.028,
          "social_media" => 0.015
        },
        "conversion_rate" => {
          "default" => 0.02,
          "landing_page" => 0.025,
          "email" => 0.015
        }
      }

      segment = audience_segment.presence || "default"
      benchmarks.dig(metric_type, segment) || benchmarks.dig(metric_type, "default")
    end

    def normal_cdf(value)
      # Simplified normal cumulative distribution function
      0.5 * (1 + Math.erf(value / Math.sqrt(2)))
    end

    def update_content_performance_cache
      # Update cached performance metrics on the content
      ContentPerformanceCacheUpdateJob.perform_later(generated_content) if defined?(ContentPerformanceCacheUpdateJob)
    end
  end
end
