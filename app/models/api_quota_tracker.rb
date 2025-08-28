# frozen_string_literal: true

# Model for tracking API quotas and rate limits across different platforms
# Provides quota management, consumption tracking, and limit enforcement
class ApiQuotaTracker < ApplicationRecord
  validates :platform, :customer_id, :endpoint, presence: true
  validates :platform, uniqueness: { scope: [:customer_id, :endpoint] }
  validates :quota_limit, :current_usage, :reset_interval, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_save :calculate_reset_time

  # Platform API configurations with default quotas (requests per day)
  PLATFORM_QUOTAS = {
    'google_ads' => {
      'search' => { limit: 15000, reset_interval: 86400 },
      'mutate' => { limit: 5000, reset_interval: 86400 },
      'reporting' => { limit: 50000, reset_interval: 86400 }
    },
    'linkedin' => {
      'profile' => { limit: 1000, reset_interval: 86400 },
      'campaigns' => { limit: 500, reset_interval: 86400 },
      'insights' => { limit: 2000, reset_interval: 86400 }
    },
    'meta' => {
      'graph_api' => { limit: 200, reset_interval: 3600 },
      'marketing_api' => { limit: 25000, reset_interval: 86400 },
      'insights' => { limit: 5000, reset_interval: 86400 }
    }
  }.freeze

  scope :active, -> { where('reset_time > ?', Time.current) }
  scope :expired, -> { where('reset_time <= ?', Time.current) }
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :near_limit, -> { where('current_usage >= quota_limit * 0.9') }

  # Check if quota is available for a request
  def quota_available?(request_count = 1)
    reset_if_expired!
    (current_usage + request_count) <= quota_limit
  end

  # Consume quota for API requests
  def consume_quota!(request_count = 1)
    reset_if_expired!
    
    if quota_available?(request_count)
      increment!(:current_usage, request_count)
      true
    else
      false
    end
  end

  # Calculate remaining quota
  def remaining_quota
    reset_if_expired!
    [quota_limit - current_usage, 0].max
  end

  # Calculate quota usage percentage
  def usage_percentage
    return 0 if quota_limit.zero?
    
    reset_if_expired!
    (current_usage.to_f / quota_limit * 100).round(2)
  end

  # Check if quota is near the limit (90% or more)
  def near_limit?
    usage_percentage >= 90.0
  end

  # Time until quota reset
  def time_until_reset
    return 0 if reset_time <= Time.current
    
    reset_time - Time.current
  end

  # Reset quota if the reset time has passed
  def reset_if_expired!
    if reset_time <= Time.current
      update!(current_usage: 0, reset_time: Time.current + reset_interval.seconds)
    end
  end

  # Get or create quota tracker for platform/endpoint
  def self.get_or_create_for(platform:, endpoint:, customer_id:)
    tracker = find_or_initialize_by(
      platform: platform,
      endpoint: endpoint,
      customer_id: customer_id
    )

    if tracker.new_record?
      config = PLATFORM_QUOTAS.dig(platform, endpoint)
      if config
        tracker.assign_attributes(
          quota_limit: config[:limit],
          reset_interval: config[:reset_interval],
          current_usage: 0
        )
        tracker.save!
      else
        # Default quota for unknown endpoints
        tracker.assign_attributes(
          quota_limit: 1000,
          reset_interval: 86400,
          current_usage: 0
        )
        tracker.save!
      end
    end

    tracker
  end

  # Get quota status for all platforms
  def self.quota_status_summary(customer_id)
    trackers = where(customer_id: customer_id)
    
    status = {}
    PLATFORM_QUOTAS.each do |platform, endpoints|
      status[platform] = {}
      
      endpoints.each do |endpoint, config|
        tracker = trackers.find { |t| t.platform == platform && t.endpoint == endpoint }
        if tracker
          tracker.reset_if_expired!
          status[platform][endpoint] = {
            quota_limit: tracker.quota_limit,
            current_usage: tracker.current_usage,
            remaining: tracker.remaining_quota,
            usage_percentage: tracker.usage_percentage,
            time_until_reset: tracker.time_until_reset,
            near_limit: tracker.near_limit?
          }
        else
          status[platform][endpoint] = {
            quota_limit: config[:limit],
            current_usage: 0,
            remaining: config[:limit],
            usage_percentage: 0.0,
            time_until_reset: 0,
            near_limit: false
          }
        end
      end
    end
    
    status
  end

  # Bulk reset expired quotas
  def self.reset_expired_quotas!
    expired_trackers = expired.to_a
    
    expired_trackers.each do |tracker|
      tracker.update!(
        current_usage: 0,
        reset_time: Time.current + tracker.reset_interval.seconds
      )
    end
    
    expired_trackers.length
  end

  # Find platforms near quota limits
  def self.platforms_near_limit(customer_id)
    near_limit.where(customer_id: customer_id).pluck(:platform, :endpoint).uniq
  end

  private

  def calculate_reset_time
    self.reset_time ||= Time.current + reset_interval.seconds
  end
end