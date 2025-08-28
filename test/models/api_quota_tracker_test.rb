# frozen_string_literal: true

require 'test_helper'

class ApiQuotaTrackerTest < ActiveSupport::TestCase
  def setup
    @customer_id = 'test_customer_123'
    @platform = 'google_ads'
    @endpoint = 'search'
  end

  test "should create quota tracker with valid attributes" do
    tracker = ApiQuotaTracker.new(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      quota_limit: 1000,
      current_usage: 0,
      reset_interval: 86400
    )
    
    assert tracker.valid?
    assert tracker.save!
  end

  test "should validate presence of required fields" do
    tracker = ApiQuotaTracker.new
    
    assert_not tracker.valid?
    assert_includes tracker.errors[:platform], "can't be blank"
    assert_includes tracker.errors[:customer_id], "can't be blank"
    assert_includes tracker.errors[:endpoint], "can't be blank"
    assert_includes tracker.errors[:reset_interval], "can't be blank"
    
    # quota_limit and current_usage have default values in the database
    # so they won't fail presence validation, but they need to be present
    tracker.quota_limit = nil
    tracker.current_usage = nil
    assert_not tracker.valid?
    assert_includes tracker.errors[:quota_limit], "can't be blank"
    assert_includes tracker.errors[:current_usage], "can't be blank"
  end

  test "should validate uniqueness of platform, customer_id, and endpoint combination" do
    ApiQuotaTracker.create!(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      quota_limit: 1000,
      current_usage: 0,
      reset_interval: 86400
    )

    duplicate_tracker = ApiQuotaTracker.new(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      quota_limit: 500,
      current_usage: 0,
      reset_interval: 3600
    )

    assert_not duplicate_tracker.valid?
    assert_includes duplicate_tracker.errors[:platform], "has already been taken"
  end

  test "should validate numerical values are non-negative" do
    tracker = ApiQuotaTracker.new(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      quota_limit: -100,
      current_usage: -50,
      reset_interval: -3600
    )

    assert_not tracker.valid?
    assert_includes tracker.errors[:quota_limit], "must be greater than or equal to 0"
    assert_includes tracker.errors[:current_usage], "must be greater than or equal to 0"
    assert_includes tracker.errors[:reset_interval], "must be greater than or equal to 0"
  end

  test "should automatically calculate reset_time before save" do
    tracker = ApiQuotaTracker.new(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      quota_limit: 1000,
      current_usage: 0,
      reset_interval: 3600
    )

    assert_nil tracker.reset_time
    tracker.save!
    assert_not_nil tracker.reset_time
    assert_in_delta Time.current + 3600, tracker.reset_time, 5.seconds
  end

  test "should check quota availability correctly" do
    tracker = create_tracker(quota_limit: 1000, current_usage: 900)
    
    assert tracker.quota_available?(50)
    assert tracker.quota_available?(100)
    assert_not tracker.quota_available?(150)
  end

  test "should consume quota successfully when available" do
    tracker = create_tracker(quota_limit: 1000, current_usage: 900)
    
    assert tracker.consume_quota!(50)
    assert_equal 950, tracker.reload.current_usage
  end

  test "should not consume quota when not available" do
    tracker = create_tracker(quota_limit: 1000, current_usage: 950)
    
    assert_not tracker.consume_quota!(100)
    assert_equal 950, tracker.reload.current_usage
  end

  test "should calculate remaining quota correctly" do
    tracker = create_tracker(quota_limit: 1000, current_usage: 300)
    
    assert_equal 700, tracker.remaining_quota
  end

  test "should calculate usage percentage correctly" do
    tracker = create_tracker(quota_limit: 1000, current_usage: 250)
    
    assert_equal 25.0, tracker.usage_percentage
  end

  test "should detect when near limit" do
    tracker = create_tracker(quota_limit: 1000, current_usage: 920)
    
    assert tracker.near_limit?
    
    tracker.update!(current_usage: 850)
    assert_not tracker.near_limit?
  end

  test "should calculate time until reset" do
    future_time = Time.current + 3600
    tracker = create_tracker(reset_time: future_time)
    
    assert_in_delta 3600, tracker.time_until_reset, 1.second
    
    # Test expired reset time
    past_time = Time.current - 3600
    tracker.update!(reset_time: past_time)
    assert_equal 0, tracker.time_until_reset
  end

  test "should reset quota when expired" do
    past_time = Time.current - 3600
    tracker = create_tracker(
      current_usage: 500,
      reset_time: past_time,
      reset_interval: 86400
    )
    
    tracker.reset_if_expired!
    tracker.reload
    
    assert_equal 0, tracker.current_usage
    assert_in_delta Time.current + 86400, tracker.reset_time, 5.seconds
  end

  test "should get or create tracker for platform/endpoint" do
    # Test creation of new tracker
    tracker = ApiQuotaTracker.get_or_create_for(
      platform: 'linkedin',
      endpoint: 'profile',
      customer_id: @customer_id
    )
    
    assert tracker.persisted?
    assert_equal 'linkedin', tracker.platform
    assert_equal 'profile', tracker.endpoint
    assert_equal @customer_id, tracker.customer_id
    assert_equal 1000, tracker.quota_limit # From PLATFORM_QUOTAS
    assert_equal 86400, tracker.reset_interval
    
    # Test retrieval of existing tracker
    existing_tracker = ApiQuotaTracker.get_or_create_for(
      platform: 'linkedin',
      endpoint: 'profile',
      customer_id: @customer_id
    )
    
    assert_equal tracker.id, existing_tracker.id
  end

  test "should get quota status summary" do
    create_tracker(platform: 'google_ads', endpoint: 'search', current_usage: 5000)
    create_tracker(platform: 'linkedin', endpoint: 'profile', current_usage: 200)
    
    status = ApiQuotaTracker.quota_status_summary(@customer_id)
    
    assert_includes status, 'google_ads'
    assert_includes status, 'linkedin'
    assert_includes status['google_ads'], 'search'
    assert_includes status['linkedin'], 'profile'
    
    google_search_status = status['google_ads']['search']
    assert_equal 15000, google_search_status[:quota_limit]
    assert_equal 5000, google_search_status[:current_usage]
    assert_equal 10000, google_search_status[:remaining]
    assert_equal 33.33, google_search_status[:usage_percentage]
  end

  test "should reset expired quotas in bulk" do
    past_time = Time.current - 7200
    
    tracker1 = create_tracker(current_usage: 500, reset_time: past_time)
    tracker2 = create_tracker(platform: 'linkedin', current_usage: 300, reset_time: past_time)
    tracker3 = create_tracker(platform: 'meta', current_usage: 100, reset_time: Time.current + 3600)
    
    reset_count = ApiQuotaTracker.reset_expired_quotas!
    
    assert_equal 2, reset_count
    
    tracker1.reload
    tracker2.reload
    tracker3.reload
    
    assert_equal 0, tracker1.current_usage
    assert_equal 0, tracker2.current_usage
    assert_equal 100, tracker3.current_usage # Not expired
  end

  test "should identify platforms near limit" do
    create_tracker(current_usage: 950, quota_limit: 1000) # 95% - near limit
    create_tracker(platform: 'linkedin', current_usage: 500, quota_limit: 1000) # 50% - not near limit
    create_tracker(platform: 'meta', current_usage: 920, quota_limit: 1000) # 92% - near limit
    
    near_limit_platforms = ApiQuotaTracker.platforms_near_limit(@customer_id)
    
    assert_equal 2, near_limit_platforms.count
    assert_includes near_limit_platforms, ['google_ads', 'search']
    assert_includes near_limit_platforms, ['meta', 'search']
  end

  test "should handle unknown platform/endpoint combinations" do
    tracker = ApiQuotaTracker.get_or_create_for(
      platform: 'unknown_platform',
      endpoint: 'unknown_endpoint',
      customer_id: @customer_id
    )
    
    assert tracker.persisted?
    assert_equal 1000, tracker.quota_limit # Default quota
    assert_equal 86400, tracker.reset_interval # Default interval
  end

  test "should handle scopes correctly" do
    future_time = Time.current + 3600
    past_time = Time.current - 3600
    
    active_tracker = create_tracker(reset_time: future_time)
    expired_tracker = create_tracker(platform: 'linkedin', reset_time: past_time)
    
    assert_includes ApiQuotaTracker.active, active_tracker
    assert_not_includes ApiQuotaTracker.active, expired_tracker
    
    assert_includes ApiQuotaTracker.expired, expired_tracker
    assert_not_includes ApiQuotaTracker.expired, active_tracker
    
    assert_includes ApiQuotaTracker.for_platform('google_ads'), active_tracker
    assert_not_includes ApiQuotaTracker.for_platform('google_ads'), expired_tracker
  end

  private

  def create_tracker(attributes = {})
    default_attributes = {
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      quota_limit: 15000,
      current_usage: 0,
      reset_interval: 86400,
      reset_time: Time.current + 86400
    }
    
    ApiQuotaTracker.create!(default_attributes.merge(attributes))
  end
end