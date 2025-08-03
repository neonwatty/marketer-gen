# frozen_string_literal: true

module Analytics
  module Notifications
    # Background job for delivering notifications
    class DeliveryJob < ApplicationJob
      queue_as :notifications

      retry_on StandardError, wait: :exponentially_longer, attempts: 3
      retry_on Net::TimeoutError, wait: 30.seconds, attempts: 5
      discard_on ActiveJob::DeserializationError

      # Deliver a single notification
      def perform(notification)
        return unless notification.pending?
        return if notification.scheduled_for > Time.current

        delivery_service = Analytics::Notifications::DeliveryService.new
        result = delivery_service.deliver_notification(notification)

        if result.success?
          Rails.logger.info "Notification #{notification.id} delivered successfully"

          # Update delivery metrics
          update_delivery_metrics(notification, "success")
        else
          Rails.logger.error "Notification #{notification.id} delivery failed: #{result.error_message}"

          # Update delivery metrics
          update_delivery_metrics(notification, "failure")

          # Don't re-raise as the service handles retries
        end
      end

      # Process notification queue for all channels
      def self.process_all_queues(limit_per_channel = 100)
        NotificationQueue.channel.values.each do |channel|
          ProcessChannelQueueJob.perform_later(channel, limit_per_channel)
        end
      end

      # Process queue for specific channel
      def self.process_channel_queue(channel, limit = 100)
        ProcessChannelQueueJob.perform_later(channel, limit)
      end

      private

      def update_delivery_metrics(notification, status)
        # Update delivery metrics for monitoring
        cache_key = "notifications:metrics:#{Date.current}:#{notification.channel}:#{status}"
        Rails.cache.increment(cache_key, 1, expires_in: 7.days)

        # Log metrics
        Rails.logger.info "[METRICS] notification.delivery.#{status}=1 " \
                          "channel=#{notification.channel} " \
                          "priority=#{notification.priority} " \
                          "delivery_time_ms=#{notification.processing_time_seconds&.* 1000}"
      end
    end

    # Job for processing notification queue by channel
    class ProcessChannelQueueJob < ApplicationJob
      queue_as :notifications

      def perform(channel, limit = 100)
        delivery_service = Analytics::Notifications::DeliveryService.new
        result = delivery_service.process_channel_queue(channel, limit)

        if result.success?
          Rails.logger.info "Processed #{channel} queue: #{result.data}"
        else
          Rails.logger.error "Failed to process #{channel} queue: #{result.error_message}"
          raise StandardError, result.error_message
        end
      end
    end

    # Job for retrying failed notifications
    class RetryJob < ApplicationJob
      queue_as :notifications

      def perform(notification)
        return unless notification.should_retry?

        delivery_service = Analytics::Notifications::DeliveryService.new
        result = delivery_service.deliver_notification(notification)

        if result.success?
          Rails.logger.info "Notification #{notification.id} retry successful"
        else
          Rails.logger.warn "Notification #{notification.id} retry failed: #{result.error_message}"
        end
      end
    end

    # Job for checking delivery status with external providers
    class StatusCheckJob < ApplicationJob
      queue_as :notifications

      def perform(notification)
        return unless notification.sent? && notification.external_id.present?

        delivery_service = Analytics::Notifications::DeliveryService.new
        result = delivery_service.check_delivery_status(notification)

        if result.success?
          # Update notification with delivery status
          notification.update!(
            delivery_status: result.data.merge(last_checked_at: Time.current)
          )

          Rails.logger.debug "Updated delivery status for notification #{notification.id}: #{result.data}"
        else
          Rails.logger.warn "Failed to check delivery status for notification #{notification.id}: #{result.error_message}"
        end
      end
    end

    # Job for updating notification metrics
    class MetricsJob < ApplicationJob
      queue_as :low_priority

      def perform(notification)
        # Calculate and store delivery metrics
        metrics = {
          notification_id: notification.id,
          channel: notification.channel,
          priority: notification.priority,
          delivery_time_seconds: notification.delivery_time_seconds,
          processing_time_seconds: notification.processing_time_seconds,
          retry_count: notification.retry_count,
          cost: notification.estimated_delivery_cost,
          timestamp: Time.current
        }

        # Store metrics (could be to database, time-series DB, or analytics service)
        Rails.cache.write(
          "notification_metrics:#{notification.id}",
          metrics,
          expires_in: 30.days
        )

        # Update aggregate metrics
        update_aggregate_metrics(notification)
      end

      private

      def update_aggregate_metrics(notification)
        date_key = Date.current.strftime("%Y-%m-%d")

        # Channel metrics
        channel_key = "metrics:notifications:#{date_key}:#{notification.channel}"
        Rails.cache.increment("#{channel_key}:total", 1, expires_in: 7.days)

        if notification.sent?
          Rails.cache.increment("#{channel_key}:sent", 1, expires_in: 7.days)

          if notification.delivery_time_seconds
            # Update average delivery time
            current_avg = Rails.cache.read("#{channel_key}:avg_delivery_time") || 0
            current_count = Rails.cache.read("#{channel_key}:delivery_time_count") || 0

            new_count = current_count + 1
            new_avg = ((current_avg * current_count) + notification.delivery_time_seconds) / new_count

            Rails.cache.write("#{channel_key}:avg_delivery_time", new_avg, expires_in: 7.days)
            Rails.cache.write("#{channel_key}:delivery_time_count", new_count, expires_in: 7.days)
          end
        elsif notification.failed?
          Rails.cache.increment("#{channel_key}:failed", 1, expires_in: 7.days)
        end

        # Priority metrics
        priority_key = "metrics:notifications:#{date_key}:priority:#{notification.priority}"
        Rails.cache.increment("#{priority_key}:total", 1, expires_in: 7.days)

        if notification.sent?
          Rails.cache.increment("#{priority_key}:sent", 1, expires_in: 7.days)
        end
      end
    end
  end
end
