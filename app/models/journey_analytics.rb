class JourneyAnalytics < ApplicationRecord
  belongs_to :journey
  belongs_to :campaign
  belongs_to :user
  
  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :total_executions, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :completed_executions, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :abandoned_executions, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :conversion_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :engagement_score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  validate :period_end_after_start
  validate :executions_consistency
  
  scope :for_period, ->(start_date, end_date) { where(period_start: start_date..end_date) }
  scope :recent, -> { order(period_start: :desc) }
  scope :high_conversion, -> { where('conversion_rate > ?', 10.0) }
  scope :low_engagement, -> { where('engagement_score < ?', 50.0) }
  
  # Time period scopes
  scope :daily, -> { where('julianday(period_end) - julianday(period_start) <= ?', 1.0) }
  scope :weekly, -> { where('julianday(period_end) - julianday(period_start) <= ?', 7.0) }
  scope :monthly, -> { where('julianday(period_end) - julianday(period_start) <= ?', 30.0) }
  
  def period_duration_days
    ((period_end - period_start) / 1.day).round(1)
  end
  
  def completion_rate
    return 0.0 if total_executions == 0
    (completed_executions.to_f / total_executions * 100).round(2)
  end
  
  def abandonment_rate
    return 0.0 if total_executions == 0
    (abandoned_executions.to_f / total_executions * 100).round(2)
  end
  
  def average_completion_time_formatted
    return 'N/A' if average_completion_time == 0
    
    hours = (average_completion_time / 1.hour).to_i
    minutes = ((average_completion_time % 1.hour) / 1.minute).to_i
    
    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end
  
  def performance_grade
    score = (conversion_rate + engagement_score) / 2
    
    case score
    when 80..100 then 'A'
    when 65..79 then 'B'
    when 50..64 then 'C'
    when 35..49 then 'D'
    else 'F'
    end
  end
  
  def self.aggregate_for_period(journey_id, start_date, end_date)
    analytics = where(journey_id: journey_id)
                .where(period_start: start_date..end_date)
    
    return nil if analytics.empty?
    
    {
      total_executions: analytics.sum(:total_executions),
      completed_executions: analytics.sum(:completed_executions),
      abandoned_executions: analytics.sum(:abandoned_executions),
      average_conversion_rate: analytics.average(:conversion_rate)&.round(2) || 0,
      average_engagement_score: analytics.average(:engagement_score)&.round(2) || 0,
      total_period_days: ((end_date - start_date) / 1.day).round,
      data_points: analytics.count
    }
  end
  
  def self.calculate_trends(journey_id, periods = 4)
    recent_analytics = where(journey_id: journey_id)
                      .order(period_start: :desc)
                      .limit(periods)
    
    return {} if recent_analytics.count < 2
    
    conversion_trend = calculate_trend(recent_analytics.pluck(:conversion_rate))
    engagement_trend = calculate_trend(recent_analytics.pluck(:engagement_score))
    execution_trend = calculate_trend(recent_analytics.pluck(:total_executions))
    
    {
      conversion_rate: {
        trend: conversion_trend[:direction],
        change_percentage: conversion_trend[:change_percentage]
      },
      engagement_score: {
        trend: engagement_trend[:direction],
        change_percentage: engagement_trend[:change_percentage]
      },
      total_executions: {
        trend: execution_trend[:direction],
        change_percentage: execution_trend[:change_percentage]
      }
    }
  end
  
  def compare_with_previous_period
    previous_analytics = self.class.where(journey_id: journey_id)
                                  .where('period_end <= ?', period_start)
                                  .order(period_end: :desc)
                                  .first
    
    return nil unless previous_analytics
    
    {
      conversion_rate_change: conversion_rate - previous_analytics.conversion_rate,
      engagement_score_change: engagement_score - previous_analytics.engagement_score,
      execution_change: total_executions - previous_analytics.total_executions,
      completion_rate_change: completion_rate - previous_analytics.completion_rate
    }
  end
  
  def to_chart_data
    {
      period: period_start.strftime('%Y-%m-%d'),
      conversion_rate: conversion_rate,
      engagement_score: engagement_score,
      total_executions: total_executions,
      completion_rate: completion_rate,
      abandonment_rate: abandonment_rate
    }
  end
  
  private
  
  def period_end_after_start
    return unless period_start && period_end
    
    errors.add(:period_end, 'must be after period start') if period_end <= period_start
  end
  
  def executions_consistency
    return unless total_executions && completed_executions && abandoned_executions
    
    if completed_executions + abandoned_executions > total_executions
      errors.add(:base, 'Completed and abandoned executions cannot exceed total executions')
    end
  end
  
  def self.calculate_trend(values)
    return { direction: :stable, change_percentage: 0 } if values.length < 2
    
    # Simple linear trend calculation
    first_value = values.last.to_f  # oldest value
    last_value = values.first.to_f  # newest value
    
    return { direction: :stable, change_percentage: 0 } if first_value == 0
    
    change_percentage = ((last_value - first_value) / first_value * 100).round(1)
    
    direction = if change_percentage > 5
                  :up
                elsif change_percentage < -5
                  :down
                else
                  :stable
                end
    
    {
      direction: direction,
      change_percentage: change_percentage.abs
    }
  end
end