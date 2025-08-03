# frozen_string_literal: true

module Analytics
  module Alerts
    # Background job for monitoring performance alerts
    class MonitoringJob < ApplicationJob
      queue_as :alerts

      retry_on StandardError, wait: :exponentially_longer, attempts: 3
      discard_on ActiveJob::DeserializationError

      # Monitor all active alerts
      def perform(options = {})
        monitoring_service = Analytics::Alerts::MonitoringService.new(options)

        result = monitoring_service.monitor_all_alerts

        if result.success?
          Rails.logger.info "Alert monitoring completed: #{result.data}"

          # Update metrics
          update_monitoring_metrics(result.data)

          # Schedule next monitoring cycle
          schedule_next_monitoring_cycle
        else
          Rails.logger.error "Alert monitoring failed: #{result.error_message}"
          raise StandardError, result.error_message
        end
      end

      # Monitor specific alert
      def self.monitor_alert(alert_id)
        perform_later({ alert_id: alert_id })
      end

      # Monitor specific metric type
      def self.monitor_metric_type(metric_type, options = {})
        perform_later(options.merge(metric_type: metric_type))
      end

      private

      def update_monitoring_metrics(data)
        # Update monitoring metrics for observability
        Rails.cache.write("alerts:last_monitoring_cycle", {
          timestamp: Time.current,
          checked: data[:checked],
          triggered: data[:triggered],
          errors: data[:errors],
          processing_time_ms: data[:processing_time]
        }, expires_in: 1.hour)

        # Log metrics for external monitoring systems
        Rails.logger.info "[METRICS] alerts.monitoring.checked=#{data[:checked]} " \
                          "alerts.monitoring.triggered=#{data[:triggered]} " \
                          "alerts.monitoring.errors=#{data[:errors]} " \
                          "alerts.monitoring.processing_time_ms=#{data[:processing_time]}"
      end

      def schedule_next_monitoring_cycle
        # Schedule next monitoring cycle in 5 minutes
        self.class.set(wait: 5.minutes).perform_later
      end
    end
  end
end
