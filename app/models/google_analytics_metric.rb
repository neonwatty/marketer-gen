# frozen_string_literal: true

class GoogleAnalyticsMetric < ApplicationRecord
  validates :date, presence: true
  validates :pipeline_id, presence: true
  validates :processed_at, presence: true
  validates :sessions, numericality: { greater_than_or_equal_to: 0 }
  validates :users, numericality: { greater_than_or_equal_to: 0 }
  validates :bounce_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :recent, -> { order(date: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :with_sessions, -> { where('sessions > 0') }
  scope :with_revenue, -> { where('transaction_revenue > 0') }

  # Aggregate metrics for reporting
  def self.daily_summary(date)
    where(date: date).select(
      'SUM(sessions) as total_sessions',
      'SUM(users) as total_users',
      'SUM(new_users) as total_new_users',
      'SUM(page_views) as total_page_views',
      'AVG(bounce_rate) as avg_bounce_rate',
      'AVG(avg_session_duration) as avg_session_duration',
      'SUM(goal_completions) as total_conversions',
      'SUM(transaction_revenue) as total_revenue'
    ).first
  end

  # Period comparison metrics
  def self.period_comparison(start_date, end_date, comparison_start, comparison_end)
    current_period = for_date_range(start_date, end_date)
    comparison_period = for_date_range(comparison_start, comparison_end)

    {
      current: {
        sessions: current_period.sum(:sessions),
        users: current_period.sum(:users),
        revenue: current_period.sum(:transaction_revenue),
        conversions: current_period.sum(:goal_completions)
      },
      comparison: {
        sessions: comparison_period.sum(:sessions),
        users: comparison_period.sum(:users),
        revenue: comparison_period.sum(:transaction_revenue),
        conversions: comparison_period.sum(:goal_completions)
      }
    }
  end

  # Performance trends
  def self.performance_trends(days = 30)
    end_date = Date.current
    start_date = end_date - days.days

    for_date_range(start_date, end_date)
      .group(:date)
      .order(:date)
      .select(
        'date',
        'SUM(sessions) as sessions',
        'SUM(users) as users',
        'SUM(transaction_revenue) as revenue',
        'SUM(goal_completions) as conversions'
      )
  end

  # Data quality metrics
  def self.data_quality_report(date_range = 7.days.ago..Date.current)
    metrics = for_date_range(date_range.begin, date_range.end)
    total_records = metrics.count

    return { total_records: 0, quality_score: 0.0 } if total_records == 0

    # Calculate completeness
    complete_records = metrics.where.not(
      sessions: nil,
      users: nil,
      page_views: nil
    ).count

    # Calculate consistency (e.g., users should not exceed sessions)
    consistent_records = metrics.where('users <= sessions OR sessions = 0').count

    # Calculate freshness (data processed within expected timeframe)
    fresh_records = metrics.where(
      'processed_at <= created_at + INTERVAL 1 HOUR'
    ).count

    {
      total_records: total_records,
      complete_records: complete_records,
      consistent_records: consistent_records,
      fresh_records: fresh_records,
      completeness_rate: (complete_records.to_f / total_records * 100).round(2),
      consistency_rate: (consistent_records.to_f / total_records * 100).round(2),
      freshness_rate: (fresh_records.to_f / total_records * 100).round(2),
      quality_score: calculate_quality_score(complete_records, consistent_records, fresh_records, total_records)
    }
  end

  # Calculate conversion rate
  def conversion_rate
    return 0.0 if sessions == 0
    (goal_completions.to_f / sessions * 100).round(2)
  end

  # Calculate revenue per session
  def revenue_per_session
    return 0.0 if sessions == 0
    (transaction_revenue.to_f / sessions).round(2)
  end

  # Calculate pages per session
  def pages_per_session
    return 0.0 if sessions == 0
    (page_views.to_f / sessions).round(2)
  end

  # Check if this record indicates high performance
  def high_performance?
    bounce_rate < 50 && conversion_rate > 2.0 && pages_per_session > 2.0
  end

  # Format for API response
  def to_analytics_hash
    {
      date: date,
      sessions: sessions,
      users: users,
      new_users: new_users,
      page_views: page_views,
      bounce_rate: bounce_rate.round(2),
      avg_session_duration: avg_session_duration.round(1),
      goal_completions: goal_completions,
      transaction_revenue: transaction_revenue.to_f,
      conversion_rate: conversion_rate,
      revenue_per_session: revenue_per_session,
      pages_per_session: pages_per_session,
      dimension_data: dimension_data || {},
      processed_at: processed_at
    }
  end

  private

  def self.calculate_quality_score(complete, consistent, fresh, total)
    return 0.0 if total == 0

    weights = { completeness: 0.4, consistency: 0.4, freshness: 0.2 }
    
    completeness_score = complete.to_f / total
    consistency_score = consistent.to_f / total
    freshness_score = fresh.to_f / total

    overall_score = (
      completeness_score * weights[:completeness] +
      consistency_score * weights[:consistency] +
      freshness_score * weights[:freshness]
    ) * 100

    overall_score.round(2)
  end
end