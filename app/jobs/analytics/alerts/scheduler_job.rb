# frozen_string_literal: true

module Analytics
  module Alerts
    # Main scheduler job for coordinating all alert system operations
    class SchedulerJob < ApplicationJob
      queue_as :alerts

      # Schedule the main monitoring cycle
      def perform
        Rails.logger.info "Starting alert system scheduler cycle"

        begin
          # Start main monitoring
          MonitoringJob.perform_later

          # Process notification queues
          process_notification_queues

          # Handle snoozed alerts
          check_snoozed_alerts

          # Check for escalations
          check_escalation_candidates

          # Cleanup old data
          cleanup_old_data

          # Update ML thresholds
          update_ml_thresholds

          # Schedule next cycle
          schedule_next_cycle

          Rails.logger.info "Alert system scheduler cycle completed successfully"

        rescue StandardError => e
          Rails.logger.error "Error in alert scheduler: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")

          # Still schedule next cycle even if this one failed
          schedule_next_cycle

          raise
        end
      end

      private

      def process_notification_queues
        # Process high-priority notifications immediately
        Analytics::Notifications::DeliveryJob.process_channel_queue("email", 50)
        Analytics::Notifications::DeliveryJob.process_channel_queue("sms", 20)
        Analytics::Notifications::DeliveryJob.process_channel_queue("slack", 25)
        Analytics::Notifications::DeliveryJob.process_channel_queue("teams", 25)

        # Process in-app notifications
        Analytics::Notifications::DeliveryJob.process_channel_queue("in_app", 100)
      end

      def check_snoozed_alerts
        # Reactivate expired snoozed alerts
        expired_alerts = AlertInstance.snoozed_expired

        expired_alerts.find_each do |alert_instance|
          alert_instance.reactivate_from_snooze!
        end

        Rails.logger.info "Reactivated #{expired_alerts.count} snoozed alerts" if expired_alerts.count > 0
      end

      def check_escalation_candidates
        # Find alerts that need escalation
        escalation_candidates = AlertInstance.ready_for_escalation

        escalation_candidates.find_each do |alert_instance|
          alert_instance.escalate!
        end

        Rails.logger.info "Escalated #{escalation_candidates.count} alerts" if escalation_candidates.count > 0
      end

      def cleanup_old_data
        # Cleanup old notification queue entries
        NotificationQueue.cleanup_old_notifications(30.days)

        # Cleanup old performance thresholds
        PerformanceThreshold.cleanup_old_thresholds(90.days)

        Rails.logger.debug "Completed data cleanup"
      end

      def update_ml_thresholds
        # Find thresholds that need recalculation
        thresholds_to_update = PerformanceThreshold.need_recalculation.limit(10)

        thresholds_to_update.each do |threshold|
          ThresholdCalculatorJob.perform_later(threshold)
        end

        Rails.logger.info "Queued #{thresholds_to_update.count} threshold updates" if thresholds_to_update.count > 0
      end

      def schedule_next_cycle
        # Schedule next scheduler cycle in 5 minutes
        self.class.set(wait: 5.minutes).perform_later
      end
    end
  end
end
