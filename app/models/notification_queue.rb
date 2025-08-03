# frozen_string_literal: true

# == Schema Information
#
# Table name: notification_queues
#
#  id                     :integer          not null, primary key
#  batch_window_minutes   :integer          default(5)
#  can_batch              :boolean          default(TRUE)
#  channel                :string           not null
#  channel_config         :json
#  delivery_metadata      :json
#  delivery_status        :json
#  failure_reason         :text
#  max_retries            :integer          default(3)
#  message                :text             not null
#  priority               :string           default("medium"), not null
#  recipient_address      :string
#  retry_count            :integer          default(0)
#  retry_schedule         :json
#  status                 :string           default("pending"), not null
#  subject                :string           not null
#  template_data          :json
#  template_name          :string
#  batch_id               :string
#  external_id            :string
#  created_at             :datetime         not null
#  next_retry_at          :datetime
#  scheduled_for          :datetime         not null
#  sent_at                :datetime
#  updated_at             :datetime         not null
#  alert_instance_id      :integer          not null
#  user_id                :integer          not null
#
# Indexes
#
#  index_notification_queues_on_alert_instance_id           (alert_instance_id)
#  index_notification_queues_on_batch_id                    (batch_id)
#  index_notification_queues_on_channel_and_status          (channel,status)
#  index_notification_queues_on_external_id                 (external_id)
#  index_notification_queues_on_next_retry_at_and_status    (next_retry_at,status)
#  index_notification_queues_on_priority_and_scheduled_for  (priority,scheduled_for)
#  index_notification_queues_on_status_and_scheduled_for    (status,scheduled_for)
#  index_notification_queues_on_user_id                     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (alert_instance_id => alert_instances.id)
#  fk_rails_...  (user_id => users.id)
#

class NotificationQueue < ApplicationRecord
  belongs_to :alert_instance
  belongs_to :user

  # Enums
  enum :status, {
    pending: "pending",
    processing: "processing",
    sent: "sent",
    failed: "failed",
    cancelled: "cancelled"
  }

  enum :priority, {
    critical: "critical",
    high: "high",
    medium: "medium",
    low: "low"
  }

  enum :channel, {
    email: "email",
    in_app: "in_app",
    sms: "sms",
    slack: "slack",
    teams: "teams",
    webhook: "webhook"
  }

  # Validations
  validates :subject, presence: true, length: { maximum: 255 }
  validates :message, presence: true
  validates :scheduled_for, presence: true
  validates :recipient_address, presence: true, unless: :in_app?
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }
  validates :max_retries, numericality: { greater_than_or_equal_to: 0 }
  validates :batch_window_minutes, numericality: { greater_than: 0 }

  validate :scheduled_for_not_too_far_future
  validate :next_retry_at_after_now, if: :next_retry_at?
  validate :validate_channel_config
  validate :validate_template_data

  # Scopes
  scope :ready_to_send, -> {
    where(status: "pending")
      .where("scheduled_for <= ?", Time.current)
  }
  scope :ready_for_retry, -> {
    where(status: "failed")
      .where("next_retry_at <= ? AND retry_count < max_retries", Time.current)
  }
  scope :high_priority, -> { where(priority: [ "critical", "high" ]) }
  scope :critical_only, -> { where(priority: "critical") }
  scope :for_channel, ->(channel_name) { where(channel: channel_name) }
  scope :batchable, -> { where(can_batch: true) }
  scope :recent, -> { where("created_at > ?", 24.hours.ago) }
  scope :stale, -> {
    where(status: "pending")
      .where("scheduled_for < ?", 1.hour.ago)
  }
  scope :failed_permanently, -> {
    where(status: "failed")
      .where("retry_count >= max_retries")
  }

  # Callbacks
  before_validation :set_defaults
  before_create :assign_batch_id, if: :can_batch?
  after_create :schedule_delivery
  after_update :update_delivery_tracking

  # Constants
  RETRY_DELAYS = [ 1.minute, 5.minutes, 15.minutes, 1.hour ].freeze
  BATCH_SIZE_LIMITS = {
    "email" => 50,
    "sms" => 20,
    "slack" => 10,
    "teams" => 10,
    "webhook" => 100
  }.freeze

  # Instance Methods
  def can_retry?
    failed? && retry_count < max_retries
  end

  def should_retry?
    can_retry? && (next_retry_at.nil? || next_retry_at <= Time.current)
  end

  def retries_exhausted?
    retry_count >= max_retries
  end

  def delivery_deadline
    case priority
    when "critical"
      scheduled_for + 1.minute
    when "high"
      scheduled_for + 5.minutes
    when "medium"
      scheduled_for + 15.minutes
    when "low"
      scheduled_for + 1.hour
    end
  end

  def delivery_overdue?
    pending? && Time.current > delivery_deadline
  end

  def delivery_time_seconds
    return nil unless sent_at && scheduled_for
    (sent_at - scheduled_for).to_i
  end

  def processing_time_seconds
    return nil unless sent_at

    if processing_started_at = delivery_metadata&.dig("processing_started_at")
      (sent_at - Time.parse(processing_started_at)).to_i
    end
  rescue ArgumentError
    nil
  end

  def mark_processing!
    return false unless pending?

    update!(
      status: "processing",
      delivery_metadata: (delivery_metadata || {}).merge(
        processing_started_at: Time.current.iso8601
      )
    )
  end

  def mark_sent!(external_id = nil, metadata = {})
    return false unless processing?

    update!(
      status: "sent",
      sent_at: Time.current,
      external_id: external_id,
      delivery_metadata: (delivery_metadata || {}).merge(metadata),
      delivery_status: { delivered: true, delivered_at: Time.current }
    )

    # Update alert instance notification tracking
    update_alert_instance_notifications

    Rails.logger.info "Notification #{id} sent successfully via #{channel} to #{recipient_address}"

    true
  rescue StandardError => e
    Rails.logger.error "Error marking notification #{id} as sent: #{e.message}"
    false
  end

  def mark_failed!(reason, metadata = {})
    return false if sent?

    self.retry_count += 1
    self.failure_reason = reason
    self.delivery_metadata = (delivery_metadata || {}).merge(metadata)

    if can_retry?
      self.status = "failed"
      self.next_retry_at = calculate_next_retry_time
      Rails.logger.warn "Notification #{id} failed (attempt #{retry_count}/#{max_retries}): #{reason}. Retry at #{next_retry_at}"
    else
      self.status = "failed"
      self.next_retry_at = nil
      Rails.logger.error "Notification #{id} permanently failed after #{retry_count} attempts: #{reason}"

      # Update alert instance with permanent failure
      update_alert_instance_failures
    end

    save!

    true
  rescue StandardError => e
    Rails.logger.error "Error marking notification #{id} as failed: #{e.message}"
    false
  end

  def cancel!(reason = "Cancelled by system")
    return false if sent?

    update!(
      status: "cancelled",
      failure_reason: reason
    )

    Rails.logger.info "Notification #{id} cancelled: #{reason}"

    true
  rescue StandardError => e
    Rails.logger.error "Error cancelling notification #{id}: #{e.message}"
    false
  end

  def retry!
    return false unless should_retry?

    update!(
      status: "pending",
      scheduled_for: Time.current,
      failure_reason: nil
    )

    # Reschedule delivery
    schedule_delivery

    Rails.logger.info "Notification #{id} scheduled for retry (attempt #{retry_count + 1}/#{max_retries})"

    true
  rescue StandardError => e
    Rails.logger.error "Error retrying notification #{id}: #{e.message}"
    false
  end

  def render_content
    return { subject: subject, message: message } if template_name.blank? || template_data.blank?

    begin
      # Render templates with data
      rendered_subject = render_template(subject, template_data)
      rendered_message = render_template(message, template_data)

      {
        subject: rendered_subject,
        message: rendered_message,
        template_data: template_data
      }
    rescue StandardError => e
      Rails.logger.error "Error rendering notification template for #{id}: #{e.message}"
      { subject: subject, message: message }
    end
  end

  def estimated_delivery_cost
    case channel
    when "email"
      0.001  # $0.001 per email
    when "sms"
      0.05   # $0.05 per SMS
    when "slack", "teams", "webhook"
      0.0001 # Minimal cost for API calls
    else
      0.0
    end
  end

  def self.batch_ready_notifications(channel, limit = nil)
    limit ||= BATCH_SIZE_LIMITS[channel.to_s] || 10

    ready_to_send
      .for_channel(channel)
      .batchable
      .high_priority
      .order(:priority, :scheduled_for)
      .limit(limit)
  end

  def self.cleanup_old_notifications(older_than = 30.days)
    where("created_at < ? AND status IN (?)", older_than.ago, [ "sent", "cancelled" ])
      .delete_all
  end

  def self.delivery_stats(timeframe = 24.hours)
    scope = where("created_at > ?", timeframe.ago)

    {
      total: scope.count,
      sent: scope.sent.count,
      failed: scope.failed.count,
      pending: scope.pending.count,
      cancelled: scope.cancelled.count,
      by_channel: scope.group(:channel).group(:status).count,
      by_priority: scope.group(:priority).group(:status).count,
      average_delivery_time: scope.sent.average("CAST((julianday(sent_at) - julianday(scheduled_for)) * 86400 AS INTEGER)"),
      delivery_success_rate: scope.where.not(status: "pending").count > 0 ?
        (scope.sent.count.to_f / scope.where.not(status: "pending").count * 100).round(2) : 0
    }
  end

  private

  def set_defaults
    self.template_data ||= {}
    self.channel_config ||= {}
    self.delivery_metadata ||= {}
    self.delivery_status ||= {}
    self.retry_schedule ||= []
    self.scheduled_for ||= Time.current
  end

  def scheduled_for_not_too_far_future
    if scheduled_for && scheduled_for > 24.hours.from_now
      errors.add(:scheduled_for, "cannot be more than 24 hours in the future")
    end
  end

  def next_retry_at_after_now
    if next_retry_at && next_retry_at <= Time.current
      errors.add(:next_retry_at, "must be in the future")
    end
  end

  def validate_channel_config
    return if channel_config.blank?

    unless channel_config.is_a?(Hash)
      errors.add(:channel_config, "must be a valid JSON object")
    end
  end

  def validate_template_data
    return if template_data.blank?

    unless template_data.is_a?(Hash)
      errors.add(:template_data, "must be a valid JSON object")
    end
  end

  def assign_batch_id
    return unless can_batch?

    # Find existing batch for same channel, user, and time window
    window_start = scheduled_for - batch_window_minutes.minutes
    window_end = scheduled_for + batch_window_minutes.minutes

    existing_batch = self.class
      .where(user: user, channel: channel)
      .where(scheduled_for: window_start..window_end)
      .where.not(batch_id: nil)
      .where(can_batch: true)
      .order(:created_at)
      .first

    if existing_batch
      self.batch_id = existing_batch.batch_id
    else
      self.batch_id = SecureRandom.uuid
    end
  end

  def schedule_delivery
    return unless pending?

    case priority
    when "critical"
      Analytics::Notifications::DeliveryJob.perform_now(self)
    when "high"
      Analytics::Notifications::DeliveryJob.set(wait: 30.seconds).perform_later(self)
    else
      Analytics::Notifications::DeliveryJob.set(wait_until: scheduled_for).perform_later(self)
    end
  end

  def update_delivery_tracking
    return unless saved_change_to_status?

    # Update metrics and monitoring
    Analytics::Notifications::MetricsJob.perform_later(self) if sent? || failed?
  end

  def calculate_next_retry_time
    if retry_schedule.present? && retry_schedule[retry_count - 1]
      Time.current + retry_schedule[retry_count - 1].seconds
    elsif retry_count <= RETRY_DELAYS.length
      Time.current + RETRY_DELAYS[retry_count - 1]
    else
      # Exponential backoff for retries beyond predefined delays
      Time.current + (2 ** retry_count).minutes
    end
  end

  def update_alert_instance_notifications
    alert_instance.update!(
      notifications_sent: (alert_instance.notifications_sent || {}).merge(
        id.to_s => {
          channel: channel,
          sent_at: sent_at,
          external_id: external_id,
          delivery_time_seconds: delivery_time_seconds
        }
      )
    )
  end

  def update_alert_instance_failures
    alert_instance.update!(
      notification_failures: (alert_instance.notification_failures || {}).merge(
        id.to_s => {
          channel: channel,
          failed_at: Time.current,
          failure_reason: failure_reason,
          retry_count: retry_count
        }
      )
    )
  end

  def render_template(template_string, data)
    # Simple template rendering - in production, use a proper template engine
    rendered = template_string.dup

    data.each do |key, value|
      placeholder = "{{#{key}}}"
      rendered.gsub!(placeholder, value.to_s) if rendered.include?(placeholder)
    end

    rendered
  end
end
