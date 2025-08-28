class Touchpoint < ApplicationRecord
  belongs_to :user
  belongs_to :journey
  belongs_to :journey_step, optional: true
  has_many :attribution_models, dependent: :destroy

  CHANNELS = %w[email social_media website blog video podcast webinar event sms push_notification display_ad search_ad direct_visit referral organic_search paid_search].freeze
  TOUCHPOINT_TYPES = %w[impression click conversion engagement interaction view download signup purchase].freeze
  ATTRIBUTION_WEIGHTS = %w[high medium low none].freeze

  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validates :touchpoint_type, presence: true, inclusion: { in: TOUCHPOINT_TYPES }
  validates :occurred_at, presence: true
  validates :attribution_weight, inclusion: { in: ATTRIBUTION_WEIGHTS }, allow_blank: true

  serialize :metadata, coder: JSON
  serialize :tracking_data, coder: JSON

  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :by_type, ->(type) { where(touchpoint_type: type) }
  scope :in_date_range, ->(start_date, end_date) { where(occurred_at: start_date..end_date) }
  scope :chronological, -> { order(:occurred_at) }
  scope :reverse_chronological, -> { order(occurred_at: :desc) }
  scope :conversions, -> { where(touchpoint_type: "conversion") }
  scope :interactions, -> { where(touchpoint_type: %w[click engagement interaction]) }

  before_validation :set_default_weight, on: :create
  after_create :update_journey_analytics

  def conversion?
    touchpoint_type == "conversion"
  end

  def interaction?
    %w[click engagement interaction].include?(touchpoint_type)
  end

  def impression?
    touchpoint_type == "impression"
  end

  def time_since_previous_touchpoint
    previous = user.touchpoints.where("occurred_at < ?", occurred_at).order(:occurred_at).last
    return nil unless previous

    ((occurred_at - previous.occurred_at) / 1.hour).round(2)
  end

  def days_since_first_touchpoint
    first_touchpoint = user.touchpoints.order(:occurred_at).first
    return 0 unless first_touchpoint

    ((occurred_at - first_touchpoint.occurred_at) / 1.day).round(1)
  end

  def channel_attribution_score
    case attribution_weight
    when "high" then 1.0
    when "medium" then 0.6
    when "low" then 0.3
    else 0.0
    end
  end

  def journey_position
    journey.touchpoints.where("occurred_at <= ?", occurred_at).count
  end

  def touchpoint_sequence
    user.touchpoints.where("occurred_at <= ?", occurred_at).order(:occurred_at).pluck(:channel)
  end

  def conversion_path
    return [] unless conversion?

    journey.touchpoints
           .where("occurred_at <= ?", occurred_at)
           .order(:occurred_at)
           .pluck(:channel, :touchpoint_type)
           .map { |channel, type| "#{channel}:#{type}" }
  end

  private

  def set_default_weight
    self.attribution_weight ||= determine_default_weight
  end

  def determine_default_weight
    case touchpoint_type
    when "conversion", "purchase" then "high"
    when "click", "engagement", "signup" then "medium"
    when "view", "impression" then "low"
    else "none"
    end
  end

  def update_journey_analytics
    # Trigger journey analytics update after touchpoint creation
    # This could be moved to a background job for performance
  end
end
