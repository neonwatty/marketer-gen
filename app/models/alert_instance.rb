# frozen_string_literal: true

# == Schema Information
#
# Table name: alert_instances
#
#  id                    :integer          not null, primary key
#  acknowledgment_note   :text
#  anomaly_score         :decimal(5, 4)
#  escalated             :boolean          default(FALSE)
#  escalation_sent_at    :datetime
#  false_positive        :boolean          default(FALSE)
#  metric_data           :json
#  ml_prediction_data    :json
#  notification_failures :json
#  notifications_sent    :json
#  resolution_note       :text
#  severity              :string           not null
#  status                :string           default("active"), not null
#  threshold_value       :decimal(15, 6)
#  trigger_context       :json
#  triggered_value       :decimal(15, 6)
#  acknowledged_at       :datetime
#  created_at            :datetime         not null
#  escalation_sent_at    :datetime
#  resolved_at           :datetime
#  snoozed_until         :datetime
#  triggered_at          :datetime         not null
#  updated_at            :datetime         not null
#  acknowledged_by_id    :integer
#  performance_alert_id  :integer          not null
#  resolved_by_id        :integer
#
# Indexes
#
#  index_alert_instances_on_acknowledged_by_id        (acknowledged_by_id)
#  index_alert_instances_on_escalated_and_severity    (escalated,severity)
#  index_alert_instances_on_performance_alert_id      (performance_alert_id)
#  index_alert_instances_on_resolved_by_id            (resolved_by_id)
#  index_alert_instances_on_snoozed_until_and_status  (snoozed_until,status)
#  index_alert_instances_on_status_and_severity       (status,severity)
#  index_alert_instances_on_triggered_at              (triggered_at)
#
# Foreign Keys
#
#  fk_rails_...  (acknowledged_by_id => users.id)
#  fk_rails_...  (performance_alert_id => performance_alerts.id)
#  fk_rails_...  (resolved_by_id => users.id)
#

class AlertInstance < ApplicationRecord
  belongs_to :performance_alert
  belongs_to :acknowledged_by, class_name: "User", optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  has_many :notification_queues, dependent: :destroy

  # Enums
  enum :status, {
    active: "active",
    acknowledged: "acknowledged",
    resolved: "resolved",
    snoozed: "snoozed"
  }

  enum :severity, {
    critical: "critical",
    high: "high",
    medium: "medium",
    low: "low"
  }

  # Validations
  validates :triggered_at, presence: true
  validates :triggered_value, presence: true
  validates :threshold_value, presence: true
  validates :severity, presence: true
  validates :status, presence: true
  validates :acknowledgment_note, presence: true, if: :acknowledged?
  validates :resolution_note, presence: true, if: :resolved?
  validates :snoozed_until, presence: true, if: :snoozed?
  validates :anomaly_score,
            numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 },
            allow_blank: true

  validate :acknowledged_by_present_when_acknowledged
  validate :resolved_by_present_when_resolved
  validate :snooze_until_future_date

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :acknowledged, -> { where(status: "acknowledged") }
  scope :resolved, -> { where(status: "resolved") }
  scope :snoozed, -> { where(status: "snoozed") }
  scope :unresolved, -> { where.not(status: "resolved") }
  scope :critical_severity, -> { where(severity: [ "critical", "high" ]) }
  scope :recent, -> { where("triggered_at > ?", 24.hours.ago) }
  scope :escalated, -> { where(escalated: true) }
  scope :ready_for_escalation, -> {
    where(status: "active", escalated: false)
      .where(severity: [ "critical", "high" ])
      .where("triggered_at < ?", 30.minutes.ago)
  }
  scope :snoozed_expired, -> {
    where(status: "snoozed")
      .where("snoozed_until <= ?", Time.current)
  }
  scope :false_positives, -> { where(false_positive: true) }

  # Callbacks
  before_validation :set_defaults
  after_update :update_performance_alert_last_triggered
  after_create :schedule_escalation_check

  # Instance Methods
  def age_in_minutes
    ((Time.current - triggered_at) / 1.minute).round(2)
  end

  def age_in_hours
    ((Time.current - triggered_at) / 1.hour).round(2)
  end

  def duration_to_acknowledge
    return nil unless acknowledged_at
    ((acknowledged_at - triggered_at) / 1.minute).round(2)
  end

  def duration_to_resolve
    return nil unless resolved_at
    ((resolved_at - triggered_at) / 1.minute).round(2)
  end

  def breach_percentage
    return 0 if threshold_value.nil? || threshold_value.zero?

    case performance_alert.threshold_operator
    when "greater_than", "greater_than_or_equal"
      ((triggered_value - threshold_value) / threshold_value * 100).round(2)
    when "less_than", "less_than_or_equal"
      ((threshold_value - triggered_value) / threshold_value * 100).round(2)
    else
      0
    end
  end

  def can_be_acknowledged?
    active? && !acknowledged?
  end

  def can_be_resolved?
    (active? || acknowledged?) && !resolved?
  end

  def can_be_snoozed?
    active? && !snoozed?
  end

  def snooze_expired?
    snoozed? && snoozed_until && snoozed_until <= Time.current
  end

  def should_escalate?
    active? && !escalated? && critical_severity? && age_in_minutes > 30
  end

  def acknowledge!(user, note = nil)
    return false unless can_be_acknowledged?

    update!(
      status: "acknowledged",
      acknowledged_by: user,
      acknowledged_at: Time.current,
      acknowledgment_note: note
    )

    # Log acknowledgment
    Rails.logger.info "Alert instance #{id} acknowledged by user #{user.id}"

    true
  rescue StandardError => e
    Rails.logger.error "Error acknowledging alert instance #{id}: #{e.message}"
    false
  end

  def resolve!(user, note = nil)
    return false unless can_be_resolved?

    update!(
      status: "resolved",
      resolved_by: user,
      resolved_at: Time.current,
      resolution_note: note
    )

    # Cancel any pending notifications
    notification_queues.pending.update_all(
      status: "cancelled",
      failure_reason: "Alert resolved"
    )

    # Log resolution
    Rails.logger.info "Alert instance #{id} resolved by user #{user.id}"

    true
  rescue StandardError => e
    Rails.logger.error "Error resolving alert instance #{id}: #{e.message}"
    false
  end

  def snooze!(duration_minutes, user = nil)
    return false unless can_be_snoozed?

    snooze_until = Time.current + duration_minutes.minutes

    update!(
      status: "snoozed",
      snoozed_until: snooze_until
    )

    # Schedule job to reactivate when snooze expires
    Analytics::Alerts::SnoozeExpirationJob.set(wait: duration_minutes.minutes).perform_later(self)

    # Log snooze
    Rails.logger.info "Alert instance #{id} snoozed until #{snooze_until} by user #{user&.id}"

    true
  rescue StandardError => e
    Rails.logger.error "Error snoozing alert instance #{id}: #{e.message}"
    false
  end

  def reactivate_from_snooze!
    return false unless snoozed? && snooze_expired?

    update!(
      status: "active",
      snoozed_until: nil
    )

    # Requeue notifications if alert is still relevant
    if performance_alert.active?
      performance_alert.send(:queue_notifications, self)
    end

    Rails.logger.info "Alert instance #{id} reactivated from snooze"

    true
  rescue StandardError => e
    Rails.logger.error "Error reactivating alert instance #{id}: #{e.message}"
    false
  end

  def escalate!
    return false if escalated? || resolved?

    update!(
      escalated: true,
      escalation_sent_at: Time.current,
      severity: escalate_severity
    )

    # Send escalation notifications
    send_escalation_notifications

    Rails.logger.warn "Alert instance #{id} escalated to #{severity}"

    true
  rescue StandardError => e
    Rails.logger.error "Error escalating alert instance #{id}: #{e.message}"
    false
  end

  def mark_false_positive!(user, note = nil)
    return false if resolved?

    update!(
      false_positive: true,
      status: "resolved",
      resolved_by: user,
      resolved_at: Time.current,
      resolution_note: note || "Marked as false positive"
    )

    # Update ML model training data
    update_ml_training_data

    Rails.logger.info "Alert instance #{id} marked as false positive by user #{user.id}"

    true
  rescue StandardError => e
    Rails.logger.error "Error marking alert instance #{id} as false positive: #{e.message}"
    false
  end

  def notification_summary
    sent = notifications_sent || {}
    failures = notification_failures || {}

    {
      total_notifications: notification_queues.count,
      sent_notifications: notification_queues.sent.count,
      failed_notifications: notification_queues.failed.count,
      pending_notifications: notification_queues.pending.count,
      channels_used: notification_queues.distinct.pluck(:channel),
      last_notification_sent: notification_queues.sent.maximum(:sent_at),
      failure_summary: failures
    }
  end

  def related_instances
    performance_alert.alert_instances
      .where.not(id: id)
      .where("triggered_at > ?", triggered_at - 1.hour)
      .where("triggered_at < ?", triggered_at + 1.hour)
      .order(:triggered_at)
  end

  private

  def set_defaults
    self.trigger_context ||= {}
    self.metric_data ||= {}
    self.notifications_sent ||= {}
    self.notification_failures ||= {}
    self.ml_prediction_data ||= {}
  end

  def acknowledged_by_present_when_acknowledged
    if acknowledged? && acknowledged_by.nil?
      errors.add(:acknowledged_by, "must be present when status is acknowledged")
    end
  end

  def resolved_by_present_when_resolved
    if resolved? && resolved_by.nil?
      errors.add(:resolved_by, "must be present when status is resolved")
    end
  end

  def snooze_until_future_date
    if snoozed? && snoozed_until && snoozed_until <= Time.current
      errors.add(:snoozed_until, "must be in the future")
    end
  end

  def update_performance_alert_last_triggered
    if saved_change_to_status? || saved_change_to_acknowledged_at?
      performance_alert.touch(:last_triggered_at)
    end
  end

  def schedule_escalation_check
    if critical_severity? || high_severity?
      # Schedule escalation check in 30 minutes
      Analytics::Alerts::EscalationCheckJob.set(wait: 30.minutes).perform_later(self)
    end
  end

  def escalate_severity
    case severity
    when "high" then "critical"
    when "medium" then "high"
    when "low" then "medium"
    else severity
    end
  end

  def send_escalation_notifications
    # Send escalation notifications to higher-level users
    escalation_users = User.where(role: [ "admin", "manager" ])

    escalation_users.each do |user|
      NotificationQueue.create!(
        alert_instance: self,
        user: user,
        channel: "email",
        priority: "critical",
        subject: "ESCALATED: #{performance_alert.name}",
        message: escalation_message,
        template_name: "alert_escalation",
        recipient_address: user.email_address,
        scheduled_for: Time.current
      )
    end
  end

  def escalation_message
    "Alert '#{performance_alert.name}' has been ESCALATED due to lack of response. " \
    "This alert has been active for #{age_in_minutes} minutes and requires immediate attention."
  end

  def update_ml_training_data
    return unless performance_alert.should_use_ml_thresholds?

    # Queue job to update ML model with false positive data
    Analytics::Alerts::MlTrainingJob.perform_later(performance_alert, self)
  end

  def critical_severity?
    severity == "critical"
  end

  def high_severity?
    severity == "high"
  end
end
