class JourneyMetric < ApplicationRecord
  belongs_to :journey
  belongs_to :campaign
  belongs_to :user

  validates :metric_name, presence: true
  validates :metric_value, presence: true, numericality: true
  validates :metric_type, presence: true, inclusion: {
    in: %w[count rate percentage duration score index]
  }
  validates :aggregation_period, presence: true, inclusion: {
    in: %w[hourly daily weekly monthly quarterly yearly]
  }
  validates :calculated_at, presence: true

  # Ensure uniqueness of metrics per journey/period combination
  validates :metric_name, uniqueness: {
    scope: [ :journey_id, :aggregation_period, :calculated_at ]
  }

  scope :by_metric, ->(metric_name) { where(metric_name: metric_name) }
  scope :by_type, ->(metric_type) { where(metric_type: metric_type) }
  scope :by_period, ->(period) { where(aggregation_period: period) }
  scope :recent, -> { order(calculated_at: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(calculated_at: start_date..end_date) }

  # Common metric names
  CORE_METRICS = %w[
    total_executions completed_executions abandoned_executions
    conversion_rate completion_rate engagement_score
    average_completion_time bounce_rate click_through_rate
    cost_per_acquisition return_on_investment
  ].freeze

  ENGAGEMENT_METRICS = %w[
    page_views time_on_page scroll_depth interaction_rate
    social_shares comments likes video_completion_rate
  ].freeze

  CONVERSION_METRICS = %w[
    form_submissions downloads purchases signups
    trial_conversions subscription_rate upsell_rate
  ].freeze

  RETENTION_METRICS = %w[
    repeat_visits customer_lifetime_value churn_rate
    retention_rate loyalty_score net_promoter_score
  ].freeze

  ALL_METRICS = (CORE_METRICS + ENGAGEMENT_METRICS +
                 CONVERSION_METRICS + RETENTION_METRICS).freeze

  def self.calculate_and_store_metrics(journey, period = "daily")
    calculation_time = Time.current

    # Calculate core metrics
    calculate_core_metrics(journey, period, calculation_time)

    # Calculate engagement metrics
    calculate_engagement_metrics(journey, period, calculation_time)

    # Calculate conversion metrics
    calculate_conversion_metrics(journey, period, calculation_time)

    # Calculate retention metrics
    calculate_retention_metrics(journey, period, calculation_time)
  end

  def self.get_metric_trend(journey_id, metric_name, periods = 7, aggregation_period = "daily")
    metrics = where(journey_id: journey_id, metric_name: metric_name, aggregation_period: aggregation_period)
             .order(calculated_at: :desc)
             .limit(periods)

    return [] if metrics.empty?

    values = metrics.reverse.pluck(:metric_value, :calculated_at)

    {
      metric_name: metric_name,
      values: values.map { |value, date| { value: value, date: date } },
      trend: calculate_trend_direction(values.map(&:first)),
      latest_value: values.last&.first,
      change_percentage: calculate_percentage_change(values.map(&:first))
    }
  end

  def self.get_journey_dashboard_metrics(journey_id, period = "daily")
    latest_metrics = where(journey_id: journey_id, aggregation_period: period)
                    .group(:metric_name)
                    .maximum(:calculated_at)

    dashboard_data = {}

    latest_metrics.each do |metric_name, latest_date|
      metric = find_by(
        journey_id: journey_id,
        metric_name: metric_name,
        aggregation_period: period,
        calculated_at: latest_date
      )

      next unless metric

      dashboard_data[metric_name] = {
        value: metric.metric_value,
        type: metric.metric_type,
        calculated_at: metric.calculated_at,
        trend: get_metric_trend(journey_id, metric_name, 7, period)[:trend],
        metadata: metric.metadata
      }
    end

    dashboard_data
  end

  def self.compare_journey_metrics(journey1_id, journey2_id, metric_names = CORE_METRICS, period = "daily")
    comparison = {}

    metric_names.each do |metric_name|
      journey1_metric = where(journey_id: journey1_id, metric_name: metric_name, aggregation_period: period)
                       .order(calculated_at: :desc)
                       .first

      journey2_metric = where(journey_id: journey2_id, metric_name: metric_name, aggregation_period: period)
                       .order(calculated_at: :desc)
                       .first

      next unless journey1_metric && journey2_metric

      comparison[metric_name] = {
        journey1_value: journey1_metric.metric_value,
        journey2_value: journey2_metric.metric_value,
        difference: journey2_metric.metric_value - journey1_metric.metric_value,
        percentage_change: calculate_percentage_change([ journey1_metric.metric_value, journey2_metric.metric_value ]),
        better_performer: journey1_metric.metric_value > journey2_metric.metric_value ? "journey1" : "journey2"
      }
    end

    comparison
  end

  def self.get_campaign_rollup_metrics(campaign_id, period = "daily")
    campaign_journeys = Journey.where(campaign_id: campaign_id)
    return {} if campaign_journeys.empty?

    rollup_metrics = {}

    CORE_METRICS.each do |metric_name|
      journey_metrics = where(
        journey_id: campaign_journeys.pluck(:id),
        metric_name: metric_name,
        aggregation_period: period
      ).group(:journey_id)
       .maximum(:calculated_at)

      total_value = 0
      metric_count = 0

      journey_metrics.each do |journey_id, latest_date|
        metric = find_by(
          journey_id: journey_id,
          metric_name: metric_name,
          aggregation_period: period,
          calculated_at: latest_date
        )

        if metric
          if %w[count duration].include?(metric.metric_type)
            total_value += metric.metric_value
          else
            total_value += metric.metric_value
          end
          metric_count += 1
        end
      end

      next if metric_count == 0

      rollup_metrics[metric_name] = if %w[rate percentage score].include?(get_metric_type(metric_name))
                                     total_value / metric_count  # Average for rates/percentages
      else
                                     total_value  # Sum for counts
      end
    end

    rollup_metrics
  end

  def formatted_value
    case metric_type
    when "percentage", "rate"
      "#{metric_value.round(1)}%"
    when "duration"
      format_duration(metric_value)
    when "count"
      metric_value.to_i.to_s
    else
      metric_value.round(2).to_s
    end
  end

  def self.metric_definition(metric_name)
    definitions = {
      "total_executions" => "Total number of journey executions started",
      "completed_executions" => "Number of journeys completed successfully",
      "abandoned_executions" => "Number of journeys abandoned before completion",
      "conversion_rate" => "Percentage of executions that resulted in conversion",
      "completion_rate" => "Percentage of executions that were completed",
      "engagement_score" => "Overall engagement score based on interactions",
      "average_completion_time" => "Average time to complete the journey",
      "bounce_rate" => "Percentage of visitors who left after viewing only one step",
      "click_through_rate" => "Percentage of users who clicked through to next step"
    }

    definitions[metric_name] || "Custom metric"
  end

  private

  def self.calculate_core_metrics(journey, period, calculation_time)
    period_start = get_period_start(calculation_time, period)

    executions = journey.journey_executions.where(created_at: period_start..calculation_time)

    # Total executions
    create_metric(journey, "total_executions", executions.count, "count", period, calculation_time)

    # Completed executions
    completed = executions.where(status: "completed").count
    create_metric(journey, "completed_executions", completed, "count", period, calculation_time)

    # Abandoned executions
    abandoned = executions.where(status: "abandoned").count
    create_metric(journey, "abandoned_executions", abandoned, "count", period, calculation_time)

    # Completion rate
    completion_rate = executions.count > 0 ? (completed.to_f / executions.count * 100) : 0
    create_metric(journey, "completion_rate", completion_rate, "percentage", period, calculation_time)

    # Average completion time
    completed_executions = executions.where(status: "completed").where.not(completed_at: nil)
    avg_time = if completed_executions.any?
                 completed_executions.average("completed_at - started_at") || 0
    else
                 0
    end
    create_metric(journey, "average_completion_time", avg_time, "duration", period, calculation_time)
  end

  def self.calculate_engagement_metrics(journey, period, calculation_time)
    # Placeholder for engagement metrics calculation
    # This would integrate with actual user interaction data

    # For now, create sample metrics
    create_metric(journey, "engagement_score", rand(70..95), "score", period, calculation_time)
    create_metric(journey, "interaction_rate", rand(40..80), "percentage", period, calculation_time)
  end

  def self.calculate_conversion_metrics(journey, period, calculation_time)
    # Placeholder for conversion metrics calculation
    # This would integrate with actual conversion tracking

    period_start = get_period_start(calculation_time, period)
    executions = journey.journey_executions.where(created_at: period_start..calculation_time)

    # Simple conversion rate based on completed journeys
    conversion_rate = if executions.count > 0
                       (executions.where(status: "completed").count.to_f / executions.count * 100)
    else
                       0
    end

    create_metric(journey, "conversion_rate", conversion_rate, "percentage", period, calculation_time)
  end

  def self.calculate_retention_metrics(journey, period, calculation_time)
    # Placeholder for retention metrics calculation
    # This would integrate with actual user behavior tracking

    create_metric(journey, "retention_rate", rand(60..85), "percentage", period, calculation_time)
  end

  def self.create_metric(journey, metric_name, value, type, period, calculation_time)
    create!(
      journey: journey,
      campaign: journey.campaign,
      user: journey.user,
      metric_name: metric_name,
      metric_value: value,
      metric_type: type,
      aggregation_period: period,
      calculated_at: calculation_time
    )
  rescue ActiveRecord::RecordNotUnique
    # Metric already exists for this period, update it
    existing = find_by(
      journey: journey,
      metric_name: metric_name,
      aggregation_period: period,
      calculated_at: calculation_time
    )
    existing&.update!(metric_value: value)
  end

  def self.get_period_start(calculation_time, period)
    case period
    when "hourly" then calculation_time.beginning_of_hour
    when "daily" then calculation_time.beginning_of_day
    when "weekly" then calculation_time.beginning_of_week
    when "monthly" then calculation_time.beginning_of_month
    when "quarterly" then calculation_time.beginning_of_quarter
    when "yearly" then calculation_time.beginning_of_year
    else calculation_time.beginning_of_day
    end
  end

  def self.calculate_trend_direction(values)
    return :stable if values.length < 2

    first_half = values[0...(values.length / 2)]
    second_half = values[(values.length / 2)..-1]

    first_avg = first_half.sum.to_f / first_half.length
    second_avg = second_half.sum.to_f / second_half.length

    change_percentage = ((second_avg - first_avg) / first_avg * 100) rescue 0

    if change_percentage > 5
      :up
    elsif change_percentage < -5
      :down
    else
      :stable
    end
  end

  def self.calculate_percentage_change(values)
    return 0 if values.length < 2 || values.first == 0

    ((values.last - values.first) / values.first * 100).round(1)
  end

  def self.get_metric_type(metric_name)
    case metric_name
    when *%w[total_executions completed_executions abandoned_executions]
      "count"
    when *%w[conversion_rate completion_rate bounce_rate]
      "percentage"
    when "average_completion_time"
      "duration"
    when "engagement_score"
      "score"
    else
      "rate"
    end
  end

  def format_duration(seconds)
    return "0s" if seconds == 0

    if seconds >= 1.hour
      hours = (seconds / 1.hour).to_i
      minutes = ((seconds % 1.hour) / 1.minute).to_i
      "#{hours}h #{minutes}m"
    elsif seconds >= 1.minute
      minutes = (seconds / 1.minute).to_i
      "#{minutes}m"
    else
      "#{seconds.to_i}s"
    end
  end
end
