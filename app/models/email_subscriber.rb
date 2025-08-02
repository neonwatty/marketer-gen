# frozen_string_literal: true

class EmailSubscriber < ApplicationRecord
  belongs_to :email_integration

  # Subscriber statuses
  STATUSES = %w[subscribed unsubscribed pending bounced cleaned].freeze

  validates :platform_subscriber_id, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :platform_subscriber_id, uniqueness: { scope: :email_integration_id }

  scope :subscribed, -> { where(status: "subscribed") }
  scope :unsubscribed, -> { where(status: "unsubscribed") }
  scope :pending, -> { where(status: "pending") }
  scope :bounced, -> { where(status: "bounced") }
  scope :cleaned, -> { where(status: "cleaned") }
  scope :active, -> { where(status: %w[subscribed pending]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_source, ->(source) { where(source: source) }

  serialize :tags, coder: JSON
  serialize :segments, coder: JSON
  serialize :location, coder: JSON

  def subscribed?
    status == "subscribed"
  end

  def unsubscribed?
    status == "unsubscribed"
  end

  def pending?
    status == "pending"
  end

  def bounced?
    status == "bounced"
  end

  def active?
    %w[subscribed pending].include?(status)
  end

  def full_name
    [ first_name, last_name ].compact.join(" ").presence || email
  end

  def add_tag(tag)
    self.tags ||= []
    self.tags << tag unless self.tags.include?(tag)
    save!
  end

  def remove_tag(tag)
    self.tags ||= []
    self.tags.delete(tag)
    save!
  end

  def has_tag?(tag)
    tags&.include?(tag) || false
  end

  def add_to_segment(segment)
    self.segments ||= []
    self.segments << segment unless self.segments.include?(segment)
    save!
  end

  def remove_from_segment(segment)
    self.segments ||= []
    self.segments.delete(segment)
    save!
  end

  def in_segment?(segment)
    segments&.include?(segment) || false
  end

  def location_data
    return {} unless location.is_a?(Hash)

    location
  end

  def country
    location_data["country"]
  end

  def state
    location_data["state"] || location_data["region"]
  end

  def city
    location_data["city"]
  end

  def timezone
    location_data["timezone"]
  end

  def subscription_duration
    return 0 unless subscribed_at

    if unsubscribed_at
      (unsubscribed_at - subscribed_at).to_i / 1.day
    else
      (Time.current - subscribed_at).to_i / 1.day
    end
  end

  def long_term_subscriber?
    subscription_duration > 365 # More than 1 year
  end

  def recent_subscriber?
    subscription_duration < 30 # Less than 30 days
  end

  # Engagement scoring (would typically be calculated from email metrics)
  def engagement_score
    # This would ideally be calculated from actual email engagement data
    # For now, return a placeholder based on status and subscription duration
    case status
    when "subscribed"
      if recent_subscriber?
        70 + rand(20) # 70-90 for new subscribers
      elsif long_term_subscriber?
        60 + rand(30) # 60-90 for long-term subscribers
      else
        50 + rand(40) # 50-90 for regular subscribers
      end
    when "pending"
      30 + rand(20) # 30-50 for pending
    else
      0 # Unsubscribed, bounced, or cleaned
    end
  end

  def high_engagement?
    engagement_score > 70
  end

  def low_engagement?
    engagement_score < 30
  end

  # Lifecycle stage based on subscription duration and engagement
  def lifecycle_stage
    return "churned" unless active?

    if recent_subscriber?
      "new"
    elsif long_term_subscriber?
      high_engagement? ? "champion" : "at_risk"
    else
      case engagement_score
      when 0..30 then "at_risk"
      when 31..60 then "regular"
      when 61..80 then "engaged"
      when 81..100 then "champion"
      end
    end
  end

  def self.engagement_summary
    {
      total: count,
      subscribed: subscribed.count,
      unsubscribed: unsubscribed.count,
      pending: pending.count,
      bounced: bounced.count,
      cleaned: cleaned.count,
      active: active.count,
      high_engagement: active.select(&:high_engagement?).count,
      low_engagement: active.select(&:low_engagement?).count
    }
  end

  def self.lifecycle_distribution
    active_subscribers = active.includes(:email_integration)
    {
      new: active_subscribers.select(&:recent_subscriber?).count,
      regular: active_subscribers.select { |s| s.lifecycle_stage == "regular" }.count,
      engaged: active_subscribers.select { |s| s.lifecycle_stage == "engaged" }.count,
      champion: active_subscribers.select { |s| s.lifecycle_stage == "champion" }.count,
      at_risk: active_subscribers.select { |s| s.lifecycle_stage == "at_risk" }.count
    }
  end
end
