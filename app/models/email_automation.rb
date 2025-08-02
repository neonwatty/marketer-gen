# frozen_string_literal: true

class EmailAutomation < ApplicationRecord
  belongs_to :email_integration

  # Automation statuses
  STATUSES = %w[draft active paused completed archived error].freeze

  # Automation types
  AUTOMATION_TYPES = %w[welcome drip abandoned_cart re_engagement birthday anniversary custom].freeze

  # Trigger types
  TRIGGER_TYPES = %w[subscription purchase behavior date api webhook custom].freeze

  validates :platform_automation_id, presence: true
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :automation_type, inclusion: { in: AUTOMATION_TYPES }, allow_blank: true
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }, allow_blank: true
  validates :platform_automation_id, uniqueness: { scope: :email_integration_id }

  scope :active, -> { where(status: "active") }
  scope :paused, -> { where(status: "paused") }
  scope :draft, -> { where(status: "draft") }
  scope :completed, -> { where(status: "completed") }
  scope :by_type, ->(type) { where(automation_type: type) }
  scope :by_trigger, ->(trigger) { where(trigger_type: trigger) }
  scope :recent, -> { order(created_at: :desc) }

  serialize :trigger_configuration, coder: JSON
  serialize :configuration, coder: JSON

  def active?
    status == "active"
  end

  def paused?
    status == "paused"
  end

  def draft?
    status == "draft"
  end

  def completed?
    status == "completed"
  end

  def trigger_config_value(key)
    trigger_configuration&.dig(key.to_s)
  end

  def set_trigger_config_value(key, value)
    self.trigger_configuration ||= {}
    self.trigger_configuration[key.to_s] = value
  end

  def configuration_value(key)
    configuration&.dig(key.to_s)
  end

  def set_configuration_value(key, value)
    self.configuration ||= {}
    self.configuration[key.to_s] = value
  end

  def subscriber_conversion_rate
    return 0 if total_subscribers.zero?

    completed_subscribers = configuration_value("completed_subscribers") || 0
    (completed_subscribers.to_f / total_subscribers * 100).round(2)
  end

  def completion_rate
    return 0 if total_subscribers.zero?

    active_rate = (active_subscribers.to_f / total_subscribers * 100).round(2)
    100 - active_rate # Assuming subscribers who are no longer active have completed
  end

  def engagement_metrics
    {
      total_subscribers: total_subscribers,
      active_subscribers: active_subscribers,
      completion_rate: completion_rate,
      conversion_rate: subscriber_conversion_rate,
      avg_time_to_complete: configuration_value("avg_time_to_complete"),
      total_emails_sent: configuration_value("total_emails_sent") || 0,
      total_opens: configuration_value("total_opens") || 0,
      total_clicks: configuration_value("total_clicks") || 0
    }
  end

  def performance_summary
    metrics = engagement_metrics
    return {} if metrics[:total_emails_sent].zero?

    {
      open_rate: (metrics[:total_opens].to_f / metrics[:total_emails_sent] * 100).round(2),
      click_rate: (metrics[:total_clicks].to_f / metrics[:total_emails_sent] * 100).round(2),
      engagement_score: calculate_engagement_score(metrics),
      performance_grade: performance_grade(metrics)
    }.merge(metrics)
  end

  def trigger_description
    case trigger_type
    when "subscription"
      "Triggered when someone subscribes to #{trigger_config_value('list_name') || 'the list'}"
    when "purchase"
      "Triggered when a customer makes a purchase"
    when "behavior"
      "Triggered by specific user behavior: #{trigger_config_value('behavior_description')}"
    when "date"
      "Triggered on specific dates: #{trigger_config_value('date_description')}"
    when "api"
      "Triggered via API call"
    when "webhook"
      "Triggered by webhook events"
    else
      "Custom trigger configuration"
    end
  end

  def automation_description
    case automation_type
    when "welcome"
      "Welcome series for new subscribers"
    when "drip"
      "Educational drip campaign"
    when "abandoned_cart"
      "Recover abandoned shopping carts"
    when "re_engagement"
      "Re-engage inactive subscribers"
    when "birthday"
      "Birthday celebration emails"
    when "anniversary"
      "Anniversary milestone emails"
    else
      "Custom automation workflow"
    end
  end

  def next_scheduled_send
    return nil unless active?

    # This would typically be calculated based on the automation's schedule
    # For now, return a placeholder
    case automation_type
    when "welcome"
      # Welcome series typically sends immediately and then follows a schedule
      Time.current + configuration_value("next_send_delay_hours")&.hours
    when "drip"
      # Drip campaigns send on regular intervals
      Time.current + configuration_value("send_interval_days")&.days
    else
      # Other automations depend on triggers
      nil
    end
  end

  def estimated_monthly_sends
    return 0 unless active?

    case automation_type
    when "welcome"
      # Based on subscription rate and number of emails in series
      monthly_subs = configuration_value("estimated_monthly_subscriptions") || 100
      emails_in_series = configuration_value("emails_in_series") || 3
      monthly_subs * emails_in_series
    when "drip"
      # Based on active subscribers and send frequency
      send_frequency_days = configuration_value("send_interval_days") || 7
      (active_subscribers * 30 / send_frequency_days).round
    when "abandoned_cart"
      # Based on abandonment rate and recovery sequence length
      monthly_abandons = configuration_value("estimated_monthly_abandons") || 50
      emails_in_sequence = configuration_value("emails_in_sequence") || 3
      monthly_abandons * emails_in_sequence
    else
      configuration_value("estimated_monthly_sends") || 0
    end
  end

  def health_status
    return "draft" if draft?
    return "paused" if paused?
    return "completed" if completed?

    metrics = performance_summary

    if metrics[:open_rate] && metrics[:click_rate]
      if metrics[:open_rate] > 25 && metrics[:click_rate] > 3
        "healthy"
      elsif metrics[:open_rate] > 15 && metrics[:click_rate] > 1
        "fair"
      else
        "needs_attention"
      end
    else
      "insufficient_data"
    end
  end

  private

  def calculate_engagement_score(metrics)
    return 0 if metrics[:total_emails_sent].zero?

    open_weight = 0.4
    click_weight = 0.6

    open_rate = metrics[:total_opens].to_f / metrics[:total_emails_sent] * 100
    click_rate = metrics[:total_clicks].to_f / metrics[:total_emails_sent] * 100

    (open_rate * open_weight + click_rate * click_weight).round(2)
  end

  def performance_grade(metrics)
    score = calculate_engagement_score(metrics)
    case score
    when 0..10 then "F"
    when 11..20 then "D"
    when 21..30 then "C"
    when 31..40 then "B"
    when 41..Float::INFINITY then "A"
    else "N/A"
    end
  end
end
