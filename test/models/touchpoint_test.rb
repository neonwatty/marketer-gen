require 'test_helper'

class TouchpointTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
    @journey_step = journey_steps(:awareness_step_one)
    
    @touchpoint = Touchpoint.new(
      user: @user,
      journey: @journey,
      journey_step: @journey_step,
      channel: 'email',
      touchpoint_type: 'click',
      occurred_at: 2.hours.ago
    )
  end

  test "should be valid with valid attributes" do
    assert @touchpoint.valid?
  end

  test "should require channel" do
    @touchpoint.channel = nil
    assert_not @touchpoint.valid?
    assert_includes @touchpoint.errors[:channel], "can't be blank"
  end

  test "should validate channel inclusion" do
    @touchpoint.channel = 'invalid_channel'
    assert_not @touchpoint.valid?
    assert_includes @touchpoint.errors[:channel], "is not included in the list"
  end

  test "should require touchpoint_type" do
    @touchpoint.touchpoint_type = nil
    assert_not @touchpoint.valid?
    assert_includes @touchpoint.errors[:touchpoint_type], "can't be blank"
  end

  test "should validate touchpoint_type inclusion" do
    @touchpoint.touchpoint_type = 'invalid_type'
    assert_not @touchpoint.valid?
    assert_includes @touchpoint.errors[:touchpoint_type], "is not included in the list"
  end

  test "should require occurred_at" do
    @touchpoint.occurred_at = nil
    assert_not @touchpoint.valid?
    assert_includes @touchpoint.errors[:occurred_at], "can't be blank"
  end

  test "should validate attribution_weight inclusion" do
    @touchpoint.attribution_weight = 'invalid_weight'
    assert_not @touchpoint.valid?
    assert_includes @touchpoint.errors[:attribution_weight], "is not included in the list"
  end

  test "should set default attribution weight based on touchpoint type" do
    conversion_touchpoint = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'website',
      touchpoint_type: 'conversion',
      occurred_at: 1.hour.ago
    )
    assert_equal 'high', conversion_touchpoint.attribution_weight

    impression_touchpoint = Touchpoint.create!(
      user: @user,
      journey: @journey, 
      channel: 'display_ad',
      touchpoint_type: 'impression',
      occurred_at: 3.hours.ago
    )
    assert_equal 'low', impression_touchpoint.attribution_weight
  end

  test "conversion? should return true for conversion touchpoints" do
    @touchpoint.touchpoint_type = 'conversion'
    assert @touchpoint.conversion?
  end

  test "interaction? should return true for interaction touchpoints" do
    @touchpoint.touchpoint_type = 'click'
    assert @touchpoint.interaction?
    
    @touchpoint.touchpoint_type = 'engagement'
    assert @touchpoint.interaction?
  end

  test "impression? should return true for impression touchpoints" do
    @touchpoint.touchpoint_type = 'impression'
    assert @touchpoint.impression?
  end

  test "channel_attribution_score should return correct scores" do
    @touchpoint.attribution_weight = 'high'
    assert_equal 1.0, @touchpoint.channel_attribution_score

    @touchpoint.attribution_weight = 'medium'
    assert_equal 0.6, @touchpoint.channel_attribution_score

    @touchpoint.attribution_weight = 'low'
    assert_equal 0.3, @touchpoint.channel_attribution_score

    @touchpoint.attribution_weight = 'none'
    assert_equal 0.0, @touchpoint.channel_attribution_score
  end

  test "time_since_previous_touchpoint should calculate correctly" do
    @touchpoint.save!
    
    later_touchpoint = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'social_media',
      touchpoint_type: 'click',
      occurred_at: 1.hour.ago
    )
    
    time_diff = later_touchpoint.time_since_previous_touchpoint
    assert_not_nil time_diff
    assert time_diff > 0
  end

  test "days_since_first_touchpoint should calculate correctly" do
    @touchpoint.save!
    
    later_touchpoint = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'website',
      touchpoint_type: 'view',
      occurred_at: 1.day.from_now
    )
    
    days = later_touchpoint.days_since_first_touchpoint
    assert days > 0
  end

  test "journey_position should return correct position" do
    @touchpoint.save!
    
    later_touchpoint = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'website',
      touchpoint_type: 'view', 
      occurred_at: 1.hour.ago
    )
    
    assert_equal 1, @touchpoint.journey_position
    assert_equal 2, later_touchpoint.journey_position
  end

  test "touchpoint_sequence should return channel sequence" do
    @touchpoint.save!
    
    Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'social_media',
      touchpoint_type: 'click',
      occurred_at: 1.hour.ago
    )
    
    sequence = @touchpoint.reload.touchpoint_sequence
    assert_includes sequence, 'email'
  end

  test "conversion_path should return path for conversions" do
    @touchpoint.touchpoint_type = 'conversion'
    @touchpoint.save!
    
    path = @touchpoint.conversion_path
    assert_not_empty path
    assert path.all? { |step| step.include?(':') }
  end

  test "should create attribution models after creation" do
    assert_difference 'Touchpoint.count', 1 do
      @touchpoint.save!
    end
  end

  # Scope tests
  test "by_channel scope should filter correctly" do
    @touchpoint.save!
    
    Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'social_media',
      touchpoint_type: 'click',
      occurred_at: 1.hour.ago
    )
    
    email_touchpoints = Touchpoint.by_channel('email')
    assert_includes email_touchpoints, @touchpoint
    assert_equal 1, email_touchpoints.count
  end

  test "by_type scope should filter correctly" do
    @touchpoint.save!
    
    click_touchpoints = Touchpoint.by_type('click') 
    assert_includes click_touchpoints, @touchpoint
  end

  test "in_date_range scope should filter correctly" do
    @touchpoint.save!
    
    touchpoints_in_range = Touchpoint.in_date_range(3.hours.ago, 1.hour.ago)
    assert_includes touchpoints_in_range, @touchpoint
  end

  test "conversions scope should filter conversion touchpoints" do
    conversion_touchpoint = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'website',
      touchpoint_type: 'conversion',
      occurred_at: 1.hour.ago
    )
    
    conversions = Touchpoint.conversions
    assert_includes conversions, conversion_touchpoint
    assert_not_includes conversions, @touchpoint
  end

  test "interactions scope should filter interaction touchpoints" do
    @touchpoint.save!
    
    interactions = Touchpoint.interactions
    assert_includes interactions, @touchpoint
  end

  test "should serialize metadata and tracking_data" do
    metadata = { 'campaign_id' => 123, 'source' => 'newsletter' }
    tracking_data = { 'utm_source' => 'email', 'utm_campaign' => 'welcome' }
    
    @touchpoint.metadata = metadata
    @touchpoint.tracking_data = tracking_data
    @touchpoint.save!
    
    @touchpoint.reload
    assert_equal metadata, @touchpoint.metadata
    assert_equal tracking_data, @touchpoint.tracking_data
  end
end