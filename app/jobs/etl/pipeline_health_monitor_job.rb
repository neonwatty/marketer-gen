# frozen_string_literal: true

module Etl
  class PipelineHealthMonitorJob < ApplicationJob
    queue_as :etl_monitoring
    
    def perform
      Rails.logger.info("[ETL] Running pipeline health monitoring")
      
      health_report = generate_health_report
      check_alert_conditions(health_report)
      store_health_metrics(health_report)
      
      Rails.logger.info("[ETL] Pipeline health monitoring completed")
    end

    private

    def generate_health_report
      {
        timestamp: Time.current,
        overall_health: calculate_overall_health,
        pipeline_status: check_pipeline_status,
        data_freshness: check_data_freshness,
        error_rates: calculate_error_rates,
        performance_metrics: calculate_performance_metrics,
        queue_depths: check_queue_depths,
        alerts: []
      }
    end

    def calculate_overall_health
      # Overall health score (0-100)
      health_factors = {
        pipeline_success_rate: pipeline_success_rate_score,
        data_freshness_score: data_freshness_score,
        error_rate_score: error_rate_score,
        performance_score: performance_score
      }
      
      weights = {
        pipeline_success_rate: 0.4,
        data_freshness_score: 0.3,
        error_rate_score: 0.2,
        performance_score: 0.1
      }
      
      overall_score = health_factors.sum { |factor, score| score * weights[factor] }
      overall_score.round(1)
    end

    def check_pipeline_status
      sources = %w[
        google_analytics_hourly
        google_analytics_daily
        social_media_facebook
        social_media_instagram
        social_media_twitter
        email_platforms
        crm_systems
      ]
      
      status = {}
      sources.each do |source|
        status[source] = {
          last_successful_run: last_successful_run(source),
          last_failed_run: last_failed_run(source),
          is_healthy: pipeline_healthy?(source),
          recent_success_rate: recent_success_rate(source)
        }
      end
      
      status
    end

    def check_data_freshness
      freshness = {}
      
      # Check each data source for freshness
      %w[google_analytics social_media email_platforms crm_systems].each do |source|
        last_data = get_last_data_timestamp(source)
        expected_interval = get_expected_interval(source)
        
        freshness[source] = {
          last_data_timestamp: last_data,
          expected_interval_minutes: expected_interval,
          is_fresh: last_data && last_data > expected_interval.minutes.ago,
          staleness_minutes: last_data ? ((Time.current - last_data) / 60).round(1) : nil
        }
      end
      
      freshness
    end

    def calculate_error_rates
      period = 24.hours.ago..Time.current
      
      {
        overall_error_rate: EtlPipelineRun.within_period(period).count > 0 ?
          (EtlPipelineRun.within_period(period).failed.count.to_f / 
           EtlPipelineRun.within_period(period).count * 100).round(2) : 0.0,
        by_source: calculate_source_error_rates(period),
        recent_errors: EtlPipelineRun.recent_errors(nil, 5)
      }
    end

    def calculate_performance_metrics
      period = 24.hours.ago..Time.current
      
      {
        average_duration: EtlPipelineRun.average_duration(period),
        slowest_pipelines: find_slowest_pipelines(period),
        throughput_per_hour: calculate_throughput(period),
        queue_processing_times: estimate_queue_times
      }
    end

    def check_queue_depths
      begin
        require 'sidekiq/api'
        
        stats = Sidekiq::Stats.new
        queue_stats = {}
        
        %w[etl_critical etl_high_priority etl_data_pulls etl_transformations etl_monitoring etl_cleanup].each do |queue_name|
          queue = Sidekiq::Queue.new(queue_name)
          queue_stats[queue_name] = {
            size: queue.size,
            latency: queue.latency.round(2),
            is_backed_up: queue.size > 100
          }
        end
        
        queue_stats.merge(
          total_enqueued: stats.enqueued,
          total_failed: stats.failed,
          total_processed: stats.processed
        )
      rescue => error
        Rails.logger.error("[ETL] Failed to get queue stats: #{error.message}")
        { error: "Queue stats unavailable" }
      end
    end

    def check_alert_conditions(health_report)
      alerts = []
      
      # Overall health alerts
      if health_report[:overall_health] < 70
        alerts << {
          level: :critical,
          message: "Overall ETL pipeline health is poor (#{health_report[:overall_health]}%)",
          timestamp: Time.current
        }
      elsif health_report[:overall_health] < 85
        alerts << {
          level: :warning,
          message: "ETL pipeline health is degraded (#{health_report[:overall_health]}%)",
          timestamp: Time.current
        }
      end
      
      # Error rate alerts
      if health_report[:error_rates][:overall_error_rate] > 10
        alerts << {
          level: :critical,
          message: "High error rate detected (#{health_report[:error_rates][:overall_error_rate]}%)",
          timestamp: Time.current
        }
      end
      
      # Data freshness alerts
      health_report[:data_freshness].each do |source, freshness|
        unless freshness[:is_fresh]
          staleness = freshness[:staleness_minutes] || 'unknown'
          alerts << {
            level: :warning,
            message: "Stale data detected for #{source} (#{staleness} minutes old)",
            timestamp: Time.current
          }
        end
      end
      
      # Queue depth alerts
      if health_report[:queue_depths].is_a?(Hash)
        health_report[:queue_depths].each do |queue, stats|
          next unless stats.is_a?(Hash) && stats[:is_backed_up]
          
          alerts << {
            level: :warning,
            message: "Queue #{queue} is backed up (#{stats[:size]} jobs)",
            timestamp: Time.current
          }
        end
      end
      
      health_report[:alerts] = alerts
      send_alerts(alerts) if alerts.any?
    end

    def store_health_metrics(health_report)
      # Store health metrics for trending and historical analysis
      # This could be stored in a separate monitoring table or external system
      Rails.logger.info("[ETL] Health Report: #{health_report.except(:alerts).to_json}")
    end

    # Helper methods
    def pipeline_success_rate_score
      rate = EtlPipelineRun.success_rate(24.hours.ago..Time.current)
      rate # Already 0-100
    end

    def data_freshness_score
      # Calculate based on how fresh the data is across all sources
      100.0 # Simplified for now
    end

    def error_rate_score
      error_rate = EtlPipelineRun.within_period(24.hours.ago..Time.current).count > 0 ?
        (EtlPipelineRun.within_period(24.hours.ago..Time.current).failed.count.to_f / 
         EtlPipelineRun.within_period(24.hours.ago..Time.current).count * 100) : 0.0
      
      [100 - (error_rate * 2), 0].max # Convert error rate to health score
    end

    def performance_score
      avg_duration = EtlPipelineRun.average_duration(24.hours.ago..Time.current)
      return 100.0 if avg_duration == 0.0
      
      # Score based on average duration (lower is better)
      target_duration = 300.0 # 5 minutes target
      [100 - ((avg_duration - target_duration) / target_duration * 100), 0].max
    end

    def last_successful_run(source)
      EtlPipelineRun.for_source(source).completed.recent.first&.started_at
    end

    def last_failed_run(source)
      EtlPipelineRun.for_source(source).failed.recent.first&.started_at
    end

    def pipeline_healthy?(source)
      EtlPipelineRun.pipeline_healthy?(source, 60)
    end

    def recent_success_rate(source)
      runs = EtlPipelineRun.for_source(source).within_period(24.hours.ago..Time.current)
      return 100.0 if runs.empty?
      
      (runs.completed.count.to_f / runs.count * 100).round(1)
    end

    def get_last_data_timestamp(source)
      # This would check the actual data tables for the latest timestamp
      # Simplified for now
      last_run = EtlPipelineRun.for_source(source).completed.recent.first
      last_run&.started_at
    end

    def get_expected_interval(source)
      # Return expected interval in minutes
      case source
      when 'google_analytics' then 60  # Hourly
      when 'social_media' then 5       # Every 5 minutes
      when 'email_platforms' then 60   # Hourly
      when 'crm_systems' then 1440     # Daily
      else 60
      end
    end

    def calculate_source_error_rates(period)
      sources = EtlPipelineRun.within_period(period).distinct.pluck(:source)
      rates = {}
      
      sources.each do |source|
        source_runs = EtlPipelineRun.for_source(source).within_period(period)
        rates[source] = source_runs.count > 0 ?
          (source_runs.failed.count.to_f / source_runs.count * 100).round(2) : 0.0
      end
      
      rates
    end

    def find_slowest_pipelines(period)
      EtlPipelineRun.within_period(period)
                   .completed
                   .order(duration: :desc)
                   .limit(5)
                   .pluck(:source, :duration, :started_at)
                   .map { |source, duration, started_at| 
                     { 
                       source: source, 
                       duration: duration.round(2), 
                       started_at: started_at 
                     } 
                   }
    end

    def calculate_throughput(period)
      completed_runs = EtlPipelineRun.within_period(period).completed.count
      hours = (period.end - period.begin) / 1.hour
      (completed_runs.to_f / hours).round(2)
    end

    def estimate_queue_times
      # Estimate processing times based on recent history
      {}
    end

    def send_alerts(alerts)
      alerts.each do |alert|
        case alert[:level]
        when :critical
          Rails.logger.error("[ETL ALERT] CRITICAL: #{alert[:message]}")
          # Could send to external alerting system, Slack, email, etc.
        when :warning
          Rails.logger.warn("[ETL ALERT] WARNING: #{alert[:message]}")
        end
      end
    end
  end
end