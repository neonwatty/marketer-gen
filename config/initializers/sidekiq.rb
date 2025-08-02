# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-cron'
require 'sidekiq/web'

Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }

  # Configure queue priorities and concurrency
  config.options[:queues] = %w[critical high default low]
  config.options[:concurrency] = ENV.fetch('SIDEKIQ_CONCURRENCY', 10).to_i
  
  # ETL-specific queues with different priorities
  config.options[:queues] = %w[
    etl_critical
    etl_high_priority
    etl_transformations
    etl_data_pulls
    etl_monitoring
    etl_cleanup
    default
    low_priority
  ]

  # Configure scheduled jobs for ETL pipeline
  schedule_file = Rails.root.join("config", "schedule.yml")
  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash(YAML.load_file(schedule_file))
  end

  # Performance monitoring for ETL workloads
  config.average_scheduled_poll_interval = 2
  config.poll_interval_average = 5
  config.max_retries = 3
  config.default_retry_attempts = 2
  
  # ETL-specific error handling
  config.death_handlers << lambda do |job, ex|
    Rails.logger.error("[ETL] Job #{job['class']} died: #{ex.message}")
    
    # Record ETL job failures
    if job['class']&.include?('Etl::')
      pipeline_id = job.dig('args', 0, 'pipeline_id') || 'unknown'
      source = job.dig('args', 0, 'source') || job['class']
      
      EtlPipelineRun.create!(
        pipeline_id: pipeline_id,
        source: source,
        status: 'failed',
        started_at: Time.current,
        completed_at: Time.current,
        error_message: ex.message,
        error_backtrace: ex.backtrace&.first(10)
      )
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
end

# ETL Pipeline Configuration
module EtlPipeline
  module Config
    # Data processing batch sizes
    BATCH_SIZES = {
      small: 100,
      medium: 500,
      large: 1000,
      xl: 5000
    }.freeze

    # Retry configuration with exponential backoff
    RETRY_CONFIG = {
      initial_delay: 2,
      max_delay: 300,
      multiplier: 2,
      max_attempts: 5
    }.freeze

    # Data source configurations
    DATA_SOURCES = {
      google_analytics: {
        max_daily_requests: 100_000,
        batch_size: :medium,
        retry_attempts: 3
      },
      social_media: {
        max_daily_requests: 50_000,
        batch_size: :small,
        retry_attempts: 5
      },
      email_platforms: {
        max_daily_requests: 25_000,
        batch_size: :medium,
        retry_attempts: 3
      },
      crm_systems: {
        max_daily_requests: 10_000,
        batch_size: :large,
        retry_attempts: 2
      }
    }.freeze

    # Compression settings for large datasets
    COMPRESSION_CONFIG = {
      threshold_size: 1.megabyte,
      algorithm: :snappy,
      level: 6
    }.freeze

    # Monitoring thresholds
    MONITORING_THRESHOLDS = {
      error_rate: 0.05,
      processing_delay: 300.seconds,
      queue_depth: 1000,
      memory_usage: 80
    }.freeze
  end
end