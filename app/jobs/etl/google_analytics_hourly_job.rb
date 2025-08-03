# frozen_string_literal: true

module Etl
  class GoogleAnalyticsHourlyJob < ApplicationJob
    queue_as :etl_data_pulls

    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(date_range: 1.hour.ago..Time.current)
      Rails.logger.info("[ETL] Starting Google Analytics hourly data pull")

      pipeline_run = EtlPipelineRun.create!(
        pipeline_id: SecureRandom.uuid,
        source: "google_analytics_hourly",
        status: "running",
        started_at: Time.current
      )

      begin
        service = GoogleAnalyticsEtlService.new(
          source: "google_analytics_hourly",
          pipeline_id: pipeline_run.pipeline_id,
          date_range: date_range
        )

        service.execute
        pipeline_run.mark_completed!(service.metrics)

        Rails.logger.info("[ETL] Google Analytics hourly pull completed successfully")
      rescue => error
        pipeline_run.mark_failed!(error, service&.metrics || {})
        Rails.logger.error("[ETL] Google Analytics hourly pull failed: #{error.message}")
        raise
      end
    end
  end
end
