# frozen_string_literal: true

class SocialMediaSyncJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for rate limiting and temporary failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # Don't retry on authentication errors
  discard_on OAuth2::Error

  def perform(brand_id, platform = nil, date_range = nil)
    brand = Brand.find(brand_id)
    date_range ||= 7.days.ago..Time.current

    Rails.logger.info "Starting social media sync for brand #{brand.name} (#{brand_id})"

    if platform.present?
      sync_single_platform(brand, platform, date_range)
    else
      sync_all_platforms(brand, date_range)
    end

    Rails.logger.info "Completed social media sync for brand #{brand.name}"
  rescue => e
    Rails.logger.error "Social media sync failed for brand #{brand_id}: #{e.message}"
    raise
  end

  private

  def sync_single_platform(brand, platform, date_range)
    integration_service = Analytics::SocialMediaIntegrationService.new(brand)

    case platform
    when "facebook"
      sync_facebook_metrics(integration_service, date_range)
    when "instagram"
      sync_instagram_metrics(integration_service, date_range)
    when "linkedin"
      sync_linkedin_metrics(integration_service, date_range)
    when "twitter"
      sync_twitter_metrics(integration_service, date_range)
    when "tiktok"
      sync_tiktok_metrics(integration_service, date_range)
    else
      Rails.logger.warn "Unknown platform for sync: #{platform}"
    end
  end

  def sync_all_platforms(brand, date_range)
    integration_service = Analytics::SocialMediaIntegrationService.new(brand)

    brand.social_media_integrations.active.each do |integration|
      begin
        sync_single_platform(brand, integration.platform, date_range)
        integration.update_last_sync!
      rescue => e
        Rails.logger.error "Failed to sync #{integration.platform} for brand #{brand.id}: #{e.message}"
        integration.increment_error_count!
      end
    end
  end

  def sync_facebook_metrics(service, date_range)
    result = service.collect_facebook_metrics(date_range: date_range)

    if result.success?
      store_platform_metrics("facebook", result.data, date_range)
      Rails.logger.info "Successfully synced Facebook metrics"
    else
      Rails.logger.error "Failed to collect Facebook metrics: #{result.message}"
    end
  end

  def sync_instagram_metrics(service, date_range)
    # Sync regular Instagram metrics
    result = service.collect_instagram_metrics(date_range: date_range)

    if result.success?
      store_platform_metrics("instagram", result.data, date_range)
    end

    # Sync Instagram story metrics
    story_result = service.collect_instagram_story_metrics

    if story_result.success?
      store_platform_metrics("instagram", story_result.data, Date.current..Date.current, "story")
    end

    Rails.logger.info "Successfully synced Instagram metrics"
  end

  def sync_linkedin_metrics(service, date_range)
    result = service.collect_linkedin_metrics(date_range: date_range)

    if result.success?
      store_platform_metrics("linkedin", result.data, date_range)
      Rails.logger.info "Successfully synced LinkedIn metrics"
    else
      Rails.logger.error "Failed to collect LinkedIn metrics: #{result.message}"
    end
  end

  def sync_twitter_metrics(service, date_range)
    result = service.collect_twitter_metrics(date_range: date_range)

    if result.success?
      store_platform_metrics("twitter", result.data, date_range)
      Rails.logger.info "Successfully synced Twitter metrics"
    else
      Rails.logger.error "Failed to collect Twitter metrics: #{result.message}"
    end
  end

  def sync_tiktok_metrics(service, date_range)
    # Sync regular TikTok metrics
    result = service.collect_tiktok_metrics(date_range: date_range)

    if result.success?
      store_platform_metrics("tiktok", result.data, date_range)
    end

    # Sync TikTok audience insights
    audience_result = service.collect_tiktok_audience_insights

    if audience_result.success?
      store_platform_metrics("tiktok", audience_result.data, Date.current..Date.current, "audience")
    end

    Rails.logger.info "Successfully synced TikTok metrics"
  end

  def store_platform_metrics(platform, metrics_data, date_range, metric_prefix = nil)
    return unless metrics_data.is_a?(Hash)

    metrics_batch = []

    # Create date array from range
    dates = date_range.is_a?(Range) ? date_range.to_a.map(&:to_date).uniq : [ Date.current ]

    dates.each do |date|
      metrics_data.each do |metric_key, value|
        metric_type = metric_prefix ? "#{metric_prefix}_#{metric_key}" : metric_key.to_s

        metrics_batch << {
          platform: platform,
          metric_type: metric_type,
          value: value.is_a?(Hash) ? value.values.sum : value.to_f,
          date: date,
          raw_data: value.is_a?(Hash) ? value : nil,
          metadata: {
            collected_at: Time.current,
            date_range: date_range.to_s,
            metric_prefix: metric_prefix
          }
        }
      end
    end

    # Store the metrics batch
    integration_service = Analytics::SocialMediaIntegrationService.new(Brand.joins(:social_media_integrations).where(social_media_integrations: { platform: platform }).first)
    result = integration_service.store_metrics_batch(metrics_batch)

    unless result.success?
      Rails.logger.error "Failed to store #{platform} metrics: #{result.message}"
    end
  end
end
