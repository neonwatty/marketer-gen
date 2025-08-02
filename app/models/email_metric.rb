# frozen_string_literal: true

class EmailMetric < ApplicationRecord
  belongs_to :email_integration
  belongs_to :email_campaign

  # Metric types
  METRIC_TYPES = %w[daily weekly monthly campaign summary].freeze

  validates :metric_type, presence: true, inclusion: { in: METRIC_TYPES }
  validates :metric_date, presence: true
  validates :metric_date, uniqueness: { scope: :email_campaign_id }

  scope :daily, -> { where(metric_type: "daily") }
  scope :weekly, -> { where(metric_type: "weekly") }
  scope :monthly, -> { where(metric_type: "monthly") }
  scope :campaign, -> { where(metric_type: "campaign") }
  scope :for_date_range, ->(start_date, end_date) { where(metric_date: start_date..end_date) }
  scope :recent, -> { order(metric_date: :desc) }

  before_save :calculate_rates

  def calculate_rates
    return unless sent&.positive?

    self.open_rate = (opens.to_f / sent * 100).round(4)
    self.click_rate = (clicks.to_f / sent * 100).round(4)
    self.bounce_rate = (bounces.to_f / sent * 100).round(4)
    self.unsubscribe_rate = (unsubscribes.to_f / sent * 100).round(4)
    self.complaint_rate = (complaints.to_f / sent * 100).round(4)
    self.delivery_rate = (delivered.to_f / sent * 100).round(4)
  end

  def engagement_score
    # Calculate a composite engagement score (0-100)
    return 0 unless sent&.positive?

    open_weight = 0.4
    click_weight = 0.6

    (open_rate * open_weight + click_rate * click_weight).round(2)
  end

  def deliverability_score
    # Calculate deliverability score (0-100)
    return 100 unless sent&.positive?

    penalty_rate = bounce_rate + complaint_rate
    [ 100 - penalty_rate, 0 ].max.round(2)
  end

  def performance_grade
    score = engagement_score
    case score
    when 0..10 then "F"
    when 11..20 then "D"
    when 21..30 then "C"
    when 31..40 then "B"
    when 41..Float::INFINITY then "A"
    else "N/A"
    end
  end

  def healthy?
    bounce_rate < 5.0 && complaint_rate < 0.5 && delivery_rate > 95.0
  end

  def needs_attention?
    bounce_rate > 10.0 || complaint_rate > 1.0 || delivery_rate < 90.0
  end

  # Industry benchmark comparisons
  def above_industry_average_open_rate?
    open_rate > industry_average_open_rate
  end

  def above_industry_average_click_rate?
    click_rate > industry_average_click_rate
  end

  private

  def industry_average_open_rate
    # These are general industry averages - could be made configurable
    case email_campaign.campaign_type
    when "automation" then 25.0
    when "newsletter" then 22.0
    when "promotional" then 18.0
    else 21.0
    end
  end

  def industry_average_click_rate
    case email_campaign.campaign_type
    when "automation" then 4.0
    when "newsletter" then 3.5
    when "promotional" then 2.5
    else 3.0
    end
  end
end
