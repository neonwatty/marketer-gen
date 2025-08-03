# frozen_string_literal: true

module Analytics
  module Alerts
    # Job to update ML models with false positive/negative feedback
    class MlTrainingJob < ApplicationJob
      queue_as :low_priority

      retry_on StandardError, wait: :exponentially_longer, attempts: 3
      discard_on ActiveJob::DeserializationError

      def perform(performance_alert, alert_instance)
        Rails.logger.info "Updating ML training data for alert #{performance_alert.id}"

        begin
          # Find the corresponding threshold record
          threshold = PerformanceThreshold.find_or_create_for_context(
            performance_alert.metric_type,
            performance_alert.metric_source,
            campaign_id: performance_alert.campaign_id,
            journey_id: performance_alert.journey_id
          )

          # Update threshold based on false positive/negative feedback
          if alert_instance.false_positive?
            threshold.mark_false_positive!
            Rails.logger.info "Marked false positive for threshold #{threshold.id}"
          else
            # This was a true positive, which helps model accuracy
            threshold.true_positives += 1
            threshold.save!
            Rails.logger.info "Recorded true positive for threshold #{threshold.id}"
          end

          # If we have enough feedback, recalculate thresholds
          total_feedback = threshold.true_positives + threshold.false_positives +
                          threshold.true_negatives + threshold.false_negatives

          if total_feedback >= 50 && threshold.auto_adjust?
            ThresholdCalculatorJob.perform_later(threshold)
            Rails.logger.info "Queued threshold recalculation for threshold #{threshold.id}"
          end

        rescue StandardError => e
          Rails.logger.error "Error updating ML training data: #{e.message}"
          raise
        end
      end
    end
  end
end
