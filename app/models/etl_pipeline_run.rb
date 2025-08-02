# frozen_string_literal: true

class EtlPipelineRun < ApplicationRecord
  validates :pipeline_id, presence: true
  validates :source, presence: true
  validates :status, presence: true, inclusion: { in: %w[running completed failed retrying] }
  validates :started_at, presence: true

  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :retrying, -> { where(status: 'retrying') }
  scope :recent, -> { order(started_at: :desc) }
  scope :for_source, ->(source) { where(source: source) }
  scope :within_period, ->(period) { where(started_at: period) }

  # Calculate success rate for monitoring
  def self.success_rate(period = 24.hours.ago..Time.current)
    runs = within_period(period)
    return 0.0 if runs.empty?
    
    completed_count = runs.completed.count
    total_count = runs.count
    
    (completed_count.to_f / total_count * 100).round(2)
  end

  # Average processing time
  def self.average_duration(period = 24.hours.ago..Time.current)
    within_period(period).completed.average(:duration) || 0.0
  end

  # Pipeline health metrics
  def self.health_metrics(period = 24.hours.ago..Time.current)
    runs = within_period(period)
    
    {
      total_runs: runs.count,
      successful_runs: runs.completed.count,
      failed_runs: runs.failed.count,
      running_runs: runs.running.count,
      success_rate: success_rate(period),
      average_duration: average_duration(period),
      error_rate: (runs.failed.count.to_f / [runs.count, 1].max * 100).round(2)
    }
  end

  # Source-specific metrics
  def self.source_metrics(source, period = 24.hours.ago..Time.current)
    runs = for_source(source).within_period(period)
    
    {
      source: source,
      total_runs: runs.count,
      successful_runs: runs.completed.count,
      failed_runs: runs.failed.count,
      success_rate: runs.empty? ? 0.0 : (runs.completed.count.to_f / runs.count * 100).round(2),
      average_duration: runs.completed.average(:duration) || 0.0,
      last_successful_run: runs.completed.first&.started_at,
      last_failed_run: runs.failed.first&.started_at
    }
  end

  # Check if pipeline is healthy
  def self.pipeline_healthy?(source, threshold_minutes = 60)
    last_successful = for_source(source).completed.recent.first
    return false unless last_successful
    
    last_successful.started_at > threshold_minutes.minutes.ago
  end

  # Get recent errors for troubleshooting
  def self.recent_errors(source = nil, limit = 10)
    scope = failed.recent.limit(limit)
    scope = scope.for_source(source) if source
    
    scope.select(:pipeline_id, :source, :started_at, :error_message, :duration)
  end

  # Mark as completed
  def mark_completed!(metrics = {})
    update!(
      status: 'completed',
      completed_at: Time.current,
      duration: Time.current - started_at,
      metrics: metrics
    )
  end

  # Mark as failed
  def mark_failed!(error, metrics = {})
    update!(
      status: 'failed',
      completed_at: Time.current,
      duration: Time.current - started_at,
      error_message: error.message,
      error_backtrace: error.backtrace&.first(10),
      metrics: metrics
    )
  end

  # Mark as retrying
  def mark_retrying!
    update!(status: 'retrying')
  end

  # Check if run took too long
  def too_slow?(threshold_minutes = 30)
    return false unless completed_at
    
    duration_minutes = (completed_at - started_at) / 60.0
    duration_minutes > threshold_minutes
  end

  # Format metrics for display
  def formatted_metrics
    return {} unless metrics.present?
    
    metrics.transform_keys(&:humanize)
  end

  # Human-readable duration
  def formatted_duration
    return 'N/A' unless duration
    
    if duration < 60
      "#{duration.round(1)}s"
    elsif duration < 3600
      "#{(duration / 60).round(1)}m"
    else
      "#{(duration / 3600).round(1)}h"
    end
  end
end