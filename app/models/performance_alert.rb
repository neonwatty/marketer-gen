# frozen_string_literal: true

# == Schema Information
#
# Table name: performance_alerts
#
#  id                         :integer          not null, primary key
#  alert_type                 :string           not null
#  anomaly_sensitivity        :decimal(3, 2)    default(0.95)
#  baseline_period_days       :integer          default(30)
#  conditions                 :json
#  cooldown_minutes           :integer          default(60)
#  description                :text
#  filters                    :json
#  last_checked_at            :datetime
#  last_triggered_at          :datetime
#  max_alerts_per_hour        :integer          default(5)
#  metadata                   :json
#  metric_source              :string           not null
#  metric_type                :string           not null
#  ml_model_config            :json
#  name                       :string           not null
#  notification_channels      :json
#  notification_settings      :json
#  severity                   :string           default("medium"), not null
#  status                     :string           default("active"), not null
#  threshold_duration_minutes :integer          default(5)
#  threshold_operator         :string
#  threshold_value            :decimal(15, 6)
#  trigger_count              :integer          default(0)
#  use_ml_thresholds          :boolean          default(FALSE)
#  user_roles                 :json
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  campaign_id                :integer
#  journey_id                 :integer
#  user_id                    :integer          not null
#
# Indexes
#
#  index_performance_alerts_on_campaign_id               (campaign_id)
#  index_performance_alerts_on_journey_id                (journey_id)
#  index_performance_alerts_on_metric_type_and_metric_source  (metric_type,metric_source)
#  index_performance_alerts_on_severity                  (severity)
#  index_performance_alerts_on_status_and_last_checked_at     (status,last_checked_at)
#  index_performance_alerts_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (journey_id => journeys.id)
#  fk_rails_...  (user_id => users.id)
#

class PerformanceAlert < ApplicationRecord
  belongs_to :user
  belongs_to :campaign, optional: true
  belongs_to :journey, optional: true

  has_many :alert_instances, dependent: :destroy
  has_many :performance_thresholds, ->(alert) {
    where(metric_type: alert.metric_type, metric_source: alert.metric_source)
  }, class_name: "PerformanceThreshold"

  # Enums
  enum :alert_type, {
    threshold: "threshold",
    anomaly: "anomaly",
    trend: "trend",
    comparison: "comparison"
  }

  enum :severity, {
    critical: "critical",
    high: "high",
    medium: "medium",
    low: "low"
  }

  enum :status, {
    active: "active",
    paused: "paused",
    disabled: "disabled"
  }

  THRESHOLD_OPERATORS = %w[greater_than less_than equals not_equals greater_than_or_equal less_than_or_equal].freeze
  METRIC_TYPES = %w[
    conversion_rate click_rate open_rate cost_per_acquisition cost_per_click
    bounce_rate engagement_rate reach impressions revenue profit_margin
    lead_conversion_rate customer_lifetime_value churn_rate retention_rate
  ].freeze
  METRIC_SOURCES = %w[
    google_ads facebook instagram linkedin twitter email_marketing
    salesforce hubspot mailchimp sendgrid social_media web_analytics
  ].freeze
  NOTIFICATION_CHANNELS = %w[email in_app sms slack teams webhook].freeze

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :metric_type, presence: true, inclusion: { in: METRIC_TYPES }
  validates :metric_source, presence: true, inclusion: { in: METRIC_SOURCES }
  validates :alert_type, presence: true
  validates :severity, presence: true
  validates :status, presence: true
  validates :threshold_operator, inclusion: { in: THRESHOLD_OPERATORS }, allow_blank: true
  validates :threshold_value, presence: true, if: :threshold_alert?
  validates :threshold_duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :anomaly_sensitivity,
            numericality: { greater_than: 0.5, less_than_or_equal_to: 1.0 },
            if: :anomaly_alert?
  validates :baseline_period_days,
            numericality: { greater_than: 0, less_than_or_equal_to: 365 },
            if: :use_ml_thresholds?
  validates :cooldown_minutes, numericality: { greater_than: 0 }
  validates :max_alerts_per_hour, numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  validate :validate_notification_channels
  validate :validate_ml_configuration
  validate :validate_threshold_configuration
  validate :validate_conditions_format

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :for_metric, ->(type, source) { where(metric_type: type, metric_source: source) }
  scope :critical_severity, -> { where(severity: [ "critical", "high" ]) }
  scope :ready_for_check, -> {
    where(status: "active")
      .where("last_checked_at IS NULL OR last_checked_at < ?", 5.minutes.ago)
  }
  scope :recently_triggered, -> {
    where("last_triggered_at > ?", 1.hour.ago)
  }
  scope :within_rate_limit, -> {
    where("trigger_count < max_alerts_per_hour OR last_triggered_at < ?", 1.hour.ago)
  }

  # Callbacks
  before_validation :set_defaults
  after_create :initialize_ml_thresholds
  after_update :update_ml_thresholds, if: :saved_change_to_ml_model_config?

  # Instance Methods
  def threshold_alert?
    alert_type == "threshold"
  end

  def anomaly_alert?
    alert_type == "anomaly"
  end

  def trend_alert?
    alert_type == "trend"
  end

  def comparison_alert?
    alert_type == "comparison"
  end

  def active?
    status == "active"
  end

  def can_trigger?
    active? && within_cooldown? && within_rate_limit?
  end

  def within_cooldown?
    return true if last_triggered_at.nil?
    last_triggered_at < cooldown_minutes.minutes.ago
  end

  def within_rate_limit?
    return true if last_triggered_at.nil? || last_triggered_at < 1.hour.ago

    recent_triggers = alert_instances
      .where("triggered_at > ?", 1.hour.ago)
      .count

    recent_triggers < max_alerts_per_hour
  end

  def notification_channels_list
    notification_channels&.map(&:to_s) || [ "email" ]
  end

  def should_use_ml_thresholds?
    use_ml_thresholds && (anomaly_alert? || trend_alert?)
  end

  def current_threshold
    return threshold_value unless should_use_ml_thresholds?

    # Get ML-calculated threshold
    threshold = performance_thresholds
      .where(metric_type: metric_type, metric_source: metric_source)
      .order(:last_recalculated_at)
      .last

    case threshold_operator
    when "greater_than", "greater_than_or_equal"
      threshold&.upper_threshold || threshold_value
    when "less_than", "less_than_or_equal"
      threshold&.lower_threshold || threshold_value
    else
      threshold&.anomaly_threshold || threshold_value
    end
  end

  def evaluate_conditions(metric_data)
    return true if conditions.blank?

    begin
      # Simple condition evaluation - in production, use a proper expression evaluator
      conditions.all? do |condition|
        field = condition["field"]
        operator = condition["operator"]
        value = condition["value"]
        metric_value = metric_data[field]

        next false if metric_value.nil?

        case operator
        when "greater_than"
          metric_value.to_f > value.to_f
        when "less_than"
          metric_value.to_f < value.to_f
        when "equals"
          metric_value.to_s == value.to_s
        when "contains"
          metric_value.to_s.include?(value.to_s)
        else
          true
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error evaluating alert conditions for alert #{id}: #{e.message}"
      false
    end
  end

  def apply_filters(base_query)
    return base_query if filters.blank?

    filtered_query = base_query

    filters.each do |filter|
      field = filter["field"]
      operator = filter["operator"]
      value = filter["value"]

      case operator
      when "equals"
        filtered_query = filtered_query.where(field => value)
      when "not_equals"
        filtered_query = filtered_query.where.not(field => value)
      when "greater_than"
        filtered_query = filtered_query.where("#{field} > ?", value)
      when "less_than"
        filtered_query = filtered_query.where("#{field} < ?", value)
      when "in"
        filtered_query = filtered_query.where(field => value)
      when "not_in"
        filtered_query = filtered_query.where.not(field => value)
      end
    end

    filtered_query
  rescue StandardError => e
    Rails.logger.error "Error applying filters for alert #{id}: #{e.message}"
    base_query
  end

  def trigger_alert!(metric_value, context = {})
    return false unless can_trigger?

    # Create alert instance
    alert_instance = alert_instances.create!(
      severity: severity,
      triggered_value: metric_value,
      threshold_value: current_threshold,
      trigger_context: context,
      metric_data: context[:metric_data] || {},
      triggered_at: Time.current
    )

    # Update alert statistics
    update!(
      last_triggered_at: Time.current,
      trigger_count: trigger_count + 1,
      last_checked_at: Time.current
    )

    # Queue notifications
    queue_notifications(alert_instance)

    # Log alert
    Rails.logger.info "Alert triggered: #{name} (ID: #{id}) - Value: #{metric_value}, Threshold: #{current_threshold}"

    alert_instance
  rescue StandardError => e
    Rails.logger.error "Error triggering alert #{id}: #{e.message}"
    false
  end

  def update_last_checked!
    update!(last_checked_at: Time.current)
  end

  private

  def set_defaults
    self.notification_channels ||= [ "email" ]
    self.notification_settings ||= {}
    self.metadata ||= {}
    self.conditions ||= []
    self.filters ||= []
  end

  def validate_notification_channels
    return if notification_channels.blank?

    invalid_channels = notification_channels - NOTIFICATION_CHANNELS
    if invalid_channels.any?
      errors.add(:notification_channels, "contains invalid channels: #{invalid_channels.join(', ')}")
    end
  end

  def validate_ml_configuration
    return unless use_ml_thresholds

    unless anomaly_alert? || trend_alert?
      errors.add(:use_ml_thresholds, "can only be used with anomaly or trend alerts")
    end

    if ml_model_config.present? && !ml_model_config.is_a?(Hash)
      errors.add(:ml_model_config, "must be a valid JSON object")
    end
  end

  def validate_threshold_configuration
    return unless threshold_alert?

    if threshold_value.blank?
      errors.add(:threshold_value, "is required for threshold alerts")
    end

    if threshold_operator.blank?
      errors.add(:threshold_operator, "is required for threshold alerts")
    end
  end

  def validate_conditions_format
    return if conditions.blank?

    unless conditions.is_a?(Array)
      errors.add(:conditions, "must be an array")
      return
    end

    conditions.each_with_index do |condition, index|
      unless condition.is_a?(Hash) && condition.key?("field") && condition.key?("operator")
        errors.add(:conditions, "condition #{index + 1} must have 'field' and 'operator' keys")
      end
    end
  end

  def initialize_ml_thresholds
    return unless should_use_ml_thresholds?

    # Initialize ML threshold calculation in background
    Analytics::Alerts::ThresholdCalculatorJob.perform_later(self)
  end

  def update_ml_thresholds
    return unless should_use_ml_thresholds?

    # Recalculate ML thresholds in background
    Analytics::Alerts::ThresholdCalculatorJob.perform_later(self)
  end

  def queue_notifications(alert_instance)
    notification_channels_list.each do |channel|
      # Get target users based on user_roles or default to alert creator
      target_users = determine_target_users

      target_users.each do |target_user|
        NotificationQueue.create!(
          alert_instance: alert_instance,
          user: target_user,
          channel: channel,
          priority: severity_to_priority,
          subject: notification_subject,
          message: notification_message(alert_instance),
          template_data: notification_template_data(alert_instance),
          template_name: "performance_alert_#{alert_type}",
          recipient_address: get_recipient_address(target_user, channel),
          channel_config: notification_settings[channel] || {},
          scheduled_for: Time.current
        )
      end
    end
  end

  def determine_target_users
    if user_roles.present?
      User.where(role: user_roles)
    else
      [ user ]
    end
  end

  def severity_to_priority
    case severity
    when "critical" then "critical"
    when "high" then "high"
    when "medium" then "medium"
    when "low" then "low"
    else "medium"
    end
  end

  def notification_subject
    "Performance Alert: #{name}"
  end

  def notification_message(alert_instance)
    "Alert '#{name}' has been triggered. " \
    "#{metric_type.humanize} (#{metric_source.humanize}) is #{alert_instance.triggered_value}, " \
    "which is #{threshold_operator.humanize.downcase} the threshold of #{alert_instance.threshold_value}."
  end

  def notification_template_data(alert_instance)
    {
      alert_name: name,
      alert_type: alert_type,
      metric_type: metric_type,
      metric_source: metric_source,
      triggered_value: alert_instance.triggered_value,
      threshold_value: alert_instance.threshold_value,
      threshold_operator: threshold_operator,
      severity: severity,
      triggered_at: alert_instance.triggered_at,
      context: alert_instance.trigger_context,
      campaign_name: campaign&.name,
      journey_name: journey&.name
    }
  end

  def get_recipient_address(user, channel)
    case channel
    when "email"
      user.email_address
    when "sms"
      user.phone_number
    else
      user.email_address
    end
  end
end
