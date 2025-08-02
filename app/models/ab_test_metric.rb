class AbTestMetric < ApplicationRecord
  belongs_to :ab_test

  validates :metric_name, presence: true
  validates :value, presence: true, numericality: true
  validates :timestamp, presence: true

  scope :by_metric, ->(name) { where(metric_name: name) }
  scope :recent, -> { order(timestamp: :desc) }
  scope :for_timeframe, ->(start_time, end_time) { where(timestamp: start_time..end_time) }

  def self.record_metric(ab_test, metric_name, value, timestamp = Time.current, metadata = {})
    create!(
      ab_test: ab_test,
      metric_name: metric_name,
      value: value,
      timestamp: timestamp,
      metadata: metadata
    )
  end

  def formatted_value
    case metric_name
    when "conversion_rate", "bounce_rate"
      "#{value.round(2)}%"
    when "revenue"
      "$#{value.round(2)}"
    when "duration"
      "#{value.round(1)}s"
    else
      value.to_s
    end
  end

  def self.aggregate_for_period(ab_test, metric_name, period_start, period_end)
    metrics = where(
      ab_test: ab_test,
      metric_name: metric_name,
      timestamp: period_start..period_end
    )

    {
      average: metrics.average(:value) || 0,
      sum: metrics.sum(:value) || 0,
      count: metrics.count,
      min: metrics.minimum(:value) || 0,
      max: metrics.maximum(:value) || 0
    }
  end
end
