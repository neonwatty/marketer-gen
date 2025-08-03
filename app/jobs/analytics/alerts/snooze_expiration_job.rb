# frozen_string_literal: true

module Analytics
  module Alerts
    # Job to reactivate snoozed alert instances when snooze period expires
    class SnoozeExpirationJob < ApplicationJob
      queue_as :alerts

      retry_on StandardError, wait: 1.minute, attempts: 2
      discard_on ActiveJob::DeserializationError

      def perform(alert_instance)
        return unless alert_instance.snooze_expired?

        Rails.logger.info "Reactivating snoozed alert instance #{alert_instance.id}"

        # Reactivate the snoozed alert
        if alert_instance.reactivate_from_snooze!
          Rails.logger.info "Alert instance #{alert_instance.id} reactivated from snooze"
        else
          Rails.logger.error "Failed to reactivate alert instance #{alert_instance.id}"
        end
      end
    end
  end
end
