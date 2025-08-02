# frozen_string_literal: true

class EmailCampaign < ApplicationRecord
  belongs_to :email_integration
  has_many :email_metrics, dependent: :destroy

  # Campaign statuses
  STATUSES = %w[draft scheduled sending sent paused canceled error].freeze

  # Campaign types
  CAMPAIGN_TYPES = %w[regular automation a_b_test rss triggered].freeze

  validates :platform_campaign_id, presence: true
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :campaign_type, inclusion: { in: CAMPAIGN_TYPES }, allow_blank: true
  validates :platform_campaign_id, uniqueness: { scope: :email_integration_id }

  scope :active, -> { where(status: %w[scheduled sending sent]) }
  scope :sent, -> { where(status: "sent") }
  scope :scheduled, -> { where(status: "scheduled") }
  scope :draft, -> { where(status: "draft") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(campaign_type: type) }

  serialize :configuration, coder: JSON

  def configuration_value(key)
    configuration&.dig(key.to_s)
  end

  def set_configuration_value(key, value)
    self.configuration ||= {}
    self.configuration[key.to_s] = value
  end

  def sent?
    status == "sent"
  end

  def scheduled?
    status == "scheduled"
  end

  def draft?
    status == "draft"
  end

  def latest_metrics
    email_metrics.order(:metric_date).last
  end

  def total_opens
    email_metrics.sum(:opens)
  end

  def total_clicks
    email_metrics.sum(:clicks)
  end

  def total_bounces
    email_metrics.sum(:bounces)
  end

  def total_unsubscribes
    email_metrics.sum(:unsubscribes)
  end

  def total_complaints
    email_metrics.sum(:complaints)
  end

  def average_open_rate
    return 0 if email_metrics.empty?

    email_metrics.average(:open_rate) || 0
  end

  def average_click_rate
    return 0 if email_metrics.empty?

    email_metrics.average(:click_rate) || 0
  end

  def performance_summary
    {
      total_recipients: total_recipients,
      total_opens: total_opens,
      total_clicks: total_clicks,
      total_bounces: total_bounces,
      total_unsubscribes: total_unsubscribes,
      total_complaints: total_complaints,
      open_rate: average_open_rate,
      click_rate: average_click_rate,
      bounce_rate: email_metrics.average(:bounce_rate) || 0,
      unsubscribe_rate: email_metrics.average(:unsubscribe_rate) || 0,
      complaint_rate: email_metrics.average(:complaint_rate) || 0,
      delivery_rate: email_metrics.average(:delivery_rate) || 0
    }
  end
end
