# frozen_string_literal: true

module Etl
  class SocialMediaRealTimeJob < ApplicationJob
    queue_as :etl_high_priority
    
    retry_on StandardError, wait: :exponentially_longer, attempts: 5

    def perform(platforms: %w[facebook instagram twitter linkedin])
      Rails.logger.info("[ETL] Starting social media real-time data pull")
      
      platforms.each do |platform|
        process_platform(platform)
      end
    end

    private

    def process_platform(platform)
      pipeline_run = EtlPipelineRun.create!(
        pipeline_id: SecureRandom.uuid,
        source: "social_media_#{platform}",
        status: 'running',
        started_at: Time.current
      )

      begin
        service = SocialMediaEtlService.new(
          source: "social_media_#{platform}",
          pipeline_id: pipeline_run.pipeline_id,
          platform: platform
        )
        
        service.execute
        pipeline_run.mark_completed!(service.metrics)
        
        Rails.logger.info("[ETL] #{platform.capitalize} real-time pull completed")
      rescue => error
        pipeline_run.mark_failed!(error, service&.metrics || {})
        Rails.logger.error("[ETL] #{platform.capitalize} real-time pull failed: #{error.message}")
        # Don't re-raise to allow other platforms to continue
      end
    end
  end
end