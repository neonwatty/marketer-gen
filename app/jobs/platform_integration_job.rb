# frozen_string_literal: true

# Background job for handling platform integration and data synchronization
# Supports async processing of Meta, Google Ads, and LinkedIn API calls
class PlatformIntegrationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Sync performance data from all connected platforms for a campaign plan
  def perform(user_id, campaign_plan_id = nil, options = {})
    user = User.find(user_id)
    campaign_plan = campaign_plan_id ? CampaignPlan.find(campaign_plan_id) : nil

    Rails.logger.info "Starting platform integration sync for user #{user_id}, campaign #{campaign_plan_id}"

    service = PlatformIntegrationService.new(user, campaign_plan)
    date_range = parse_date_range(options["date_range"])

    case options["operation"]
    when "sync_all"
      sync_all_platforms(service, date_range, options)
    when "sync_platform"
      sync_single_platform(service, options["platform"], date_range, options)
    when "test_connections"
      test_platform_connections(service, options)
    else
      # Default to sync all platforms
      sync_all_platforms(service, date_range, options)
    end

  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Platform integration job failed - record not found: #{e.message}"
    raise # Don't retry for missing records
  rescue => e
    Rails.logger.error "Platform integration job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    raise # Let retry logic handle other errors
  end

  private

  def sync_all_platforms(service, date_range, options)
    result = service.sync_all_platforms(date_range)

    if result[:success]
      Rails.logger.info "Successfully synced all platforms. Platforms: #{result[:data][:platforms_synced].join(', ')}"

      # Optionally trigger additional processing
      if options["trigger_analytics_refresh"] && service.campaign_plan
        service.campaign_plan.refresh_analytics! if service.campaign_plan.analytics_enabled?
      end

      # Send notification if requested
      if options["send_notification"] && options["notification_email"]
        PlatformSyncMailer.sync_completed(
          options["notification_email"],
          service.user,
          service.campaign_plan,
          result[:data]
        ).deliver_now
      end
    else
      Rails.logger.error "Platform sync failed: #{result[:error]}"

      # Send error notification if requested
      if options["send_notification"] && options["notification_email"]
        PlatformSyncMailer.sync_failed(
          options["notification_email"],
          service.user,
          service.campaign_plan,
          result[:error]
        ).deliver_now
      end
    end

    result
  end

  def sync_single_platform(service, platform, date_range, options)
    result = service.sync_platform(platform, date_range)

    if result[:success]
      Rails.logger.info "Successfully synced #{platform} platform"

      # Update platform connection status
      connection = service.user.platform_connections.for_platform(platform).first
      connection&.update_sync_status!(true, result[:data])
    else
      Rails.logger.error "Platform sync failed for #{platform}: #{result[:error]}"

      # Update platform connection with error
      connection = service.user.platform_connections.for_platform(platform).first
      connection&.mark_failed!(result[:error])
    end

    result
  end

  def test_platform_connections(service, options)
    result = service.test_platform_connections

    Rails.logger.info "Platform connection test completed. Results: #{result[:data][:connection_tests].transform_values { |v| v[:connected] }}"

    # Update connection statuses based on test results
    result[:data][:connection_tests].each do |platform, test_result|
      connection = service.user.platform_connections.for_platform(platform).first
      next unless connection

      if test_result[:connected]
        connection.update_sync_status!(true, test_result)
      else
        connection.mark_failed!(test_result[:error])
      end
    end

    result
  end

  def parse_date_range(date_range_options)
    return {} unless date_range_options.is_a?(Hash)

    parsed = {}
    parsed[:since] = Date.parse(date_range_options["since"]) if date_range_options["since"]
    parsed[:until] = Date.parse(date_range_options["until"]) if date_range_options["until"]
    parsed[:time_increment] = date_range_options["time_increment"] if date_range_options["time_increment"]

    parsed
  rescue Date::Error => e
    Rails.logger.warn "Invalid date range in platform integration job: #{e.message}"
    {}
  end

  # Class methods for easy job scheduling
  class << self
    # Schedule sync for all platforms
    def sync_all_platforms(user, campaign_plan = nil, date_range: {}, **options)
      perform_later(
        user.id,
        campaign_plan&.id,
        {
          "operation" => "sync_all",
          "date_range" => serialize_date_range(date_range)
        }.merge(stringify_options(options))
      )
    end

    # Schedule sync for specific platform
    def sync_platform(user, platform, campaign_plan = nil, date_range: {}, **options)
      perform_later(
        user.id,
        campaign_plan&.id,
        {
          "operation" => "sync_platform",
          "platform" => platform,
          "date_range" => serialize_date_range(date_range)
        }.merge(stringify_options(options))
      )
    end

    # Schedule connection test
    def test_connections(user, **options)
      perform_later(
        user.id,
        nil,
        {
          "operation" => "test_connections"
        }.merge(stringify_options(options))
      )
    end

    private

    def serialize_date_range(date_range)
      return {} unless date_range.is_a?(Hash)

      serialized = {}
      serialized["since"] = date_range[:since]&.strftime("%Y-%m-%d") if date_range[:since]
      serialized["until"] = date_range[:until]&.strftime("%Y-%m-%d") if date_range[:until]
      serialized["time_increment"] = date_range[:time_increment] if date_range[:time_increment]

      serialized
    end

    def stringify_options(options)
      options.transform_keys(&:to_s).transform_values(&:to_s)
    end
  end
end
