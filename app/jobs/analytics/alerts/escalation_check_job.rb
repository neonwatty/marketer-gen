# frozen_string_literal: true

module Analytics
  module Alerts
    # Job to check if alert instances need escalation
    class EscalationCheckJob < ApplicationJob
      queue_as :alerts

      retry_on StandardError, wait: 5.minutes, attempts: 2
      discard_on ActiveJob::DeserializationError

      def perform(alert_instance)
        return unless alert_instance.should_escalate?

        Rails.logger.info "Checking escalation for alert instance #{alert_instance.id}"

        # Escalate the alert
        if alert_instance.escalate!
          Rails.logger.warn "Alert instance #{alert_instance.id} was escalated"
        else
          Rails.logger.error "Failed to escalate alert instance #{alert_instance.id}"
        end
      end
    end
  end
end
