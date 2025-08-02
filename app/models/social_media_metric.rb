# frozen_string_literal: true

class SocialMediaMetric < ApplicationRecord
  belongs_to :social_media_integration

  # Metric type constants by platform
  FACEBOOK_METRICS = %w[
    page_likes page_followers page_reach page_impressions
    post_likes post_comments post_shares post_reach post_impressions
    video_views video_completion_rate link_clicks
  ].freeze

  INSTAGRAM_METRICS = %w[
    followers reach impressions profile_views website_clicks
    post_likes post_comments post_saves post_shares
    story_views story_replies story_exits story_taps_forward story_taps_back
    reel_views reel_likes reel_comments reel_shares
  ].freeze

  LINKEDIN_METRICS = %w[
    followers page_views unique_page_views clicks likes comments shares
    post_impressions post_clicks video_views lead_generation
    company_page_clicks career_page_clicks
  ].freeze

  TWITTER_METRICS = %w[
    followers tweet_impressions profile_visits mentions hashtag_clicks
    retweets likes replies quote_tweets video_views url_clicks
    media_views media_engagements
  ].freeze

  TIKTOK_METRICS = %w[
    followers video_views likes comments shares profile_views
    video_completion_rate average_watch_time hashtag_views
    trending_videos audience_reach
  ].freeze

  ALL_METRICS = (FACEBOOK_METRICS + INSTAGRAM_METRICS + LINKEDIN_METRICS +
                TWITTER_METRICS + TIKTOK_METRICS).uniq.freeze

  validates :metric_type, presence: true, inclusion: { in: ALL_METRICS }
  validates :platform, presence: true, inclusion: { in: SocialMediaIntegration::PLATFORMS }
  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :date, presence: true
  validates :metric_type, uniqueness: {
    scope: [ :social_media_integration_id, :date ],
    message: "already recorded for this date"
  }

  # Serialize raw_data and metadata as JSON
  serialize :raw_data, coder: JSON
  serialize :metadata, coder: JSON

  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :for_metric_type, ->(type) { where(metric_type: type) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, ->(days = 30) { where(date: days.days.ago..Date.current) }
  scope :ordered_by_date, -> { order(:date) }

  delegate :brand, to: :social_media_integration

  def self.metrics_for_platform(platform)
    case platform.to_s
    when "facebook"
      FACEBOOK_METRICS
    when "instagram"
      INSTAGRAM_METRICS
    when "linkedin"
      LINKEDIN_METRICS
    when "twitter"
      TWITTER_METRICS
    when "tiktok"
      TIKTOK_METRICS
    else
      []
    end
  end

  def self.engagement_metrics
    %w[
      post_likes post_comments post_shares likes comments shares
      retweets replies quote_tweets video_views story_replies
    ]
  end

  def self.reach_metrics
    %w[
      page_reach post_reach reach impressions page_impressions post_impressions
      tweet_impressions profile_visits profile_views
    ]
  end

  def self.follower_metrics
    %w[followers page_followers page_likes]
  end

  def self.aggregate_by_platform(start_date:, end_date:)
    joins(:social_media_integration)
      .where(date: start_date..end_date)
      .group("social_media_integrations.platform")
      .group(:metric_type)
      .sum(:value)
  end

  def self.aggregate_by_brand(brand, start_date:, end_date:)
    joins(:social_media_integration)
      .where(social_media_integrations: { brand: brand })
      .where(date: start_date..end_date)
      .group(:metric_type)
      .sum(:value)
  end

  def self.calculate_engagement_rate(platform:, start_date:, end_date:)
    metrics = for_platform(platform).for_date_range(start_date, end_date)

    total_engagements = metrics.where(metric_type: engagement_metrics).sum(:value)
    total_reach = metrics.where(metric_type: reach_metrics).sum(:value)

    return 0.0 if total_reach.zero?

    (total_engagements.to_f / total_reach * 100).round(2)
  end

  def self.growth_rate(metric_type:, platform:, current_period:, previous_period:)
    current_value = for_platform(platform)
                   .for_metric_type(metric_type)
                   .for_date_range(current_period)
                   .sum(:value)

    previous_value = for_platform(platform)
                    .for_metric_type(metric_type)
                    .for_date_range(previous_period)
                    .sum(:value)

    return 0.0 if previous_value.zero?

    ((current_value - previous_value).to_f / previous_value * 100).round(2)
  end

  def engagement_metric?
    self.class.engagement_metrics.include?(metric_type)
  end

  def reach_metric?
    self.class.reach_metrics.include?(metric_type)
  end

  def follower_metric?
    self.class.follower_metrics.include?(metric_type)
  end

  def formatted_value
    case metric_type
    when *reach_metrics, *follower_metrics
      value.to_i.to_s(:delimited)
    else
      value.to_s
    end
  end

  def metadata_value(key)
    metadata&.dig(key.to_s)
  end

  def set_metadata_value(key, val)
    self.metadata ||= {}
    self.metadata[key.to_s] = val
  end
end
