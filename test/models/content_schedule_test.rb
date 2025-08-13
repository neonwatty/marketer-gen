require "test_helper"

class ContentScheduleTest < ActiveSupport::TestCase
  self.use_transactional_tests = true
  
  # Disable fixtures for content_schedules to avoid foreign key issues
  fixtures :campaigns, :brand_identities
  def setup
    @campaign = campaigns(:summer_launch)
    @content_schedule = ContentSchedule.new(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 1,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: 1.hour.from_now,
      priority: 3,
      auto_publish: true
    )
  end

  test "should be valid with required attributes" do
    assert @content_schedule.valid?
  end

  test "should require platform" do
    @content_schedule.platform = nil
    assert_not @content_schedule.valid?
    assert_includes @content_schedule.errors[:platform], "can't be blank"
  end

  test "should require scheduled_at" do
    @content_schedule.scheduled_at = nil
    assert_not @content_schedule.valid?
    assert_includes @content_schedule.errors[:scheduled_at], "can't be blank"
  end

  test "should validate platform inclusion" do
    @content_schedule.platform = 'invalid_platform'
    assert_not @content_schedule.valid?
    assert_includes @content_schedule.errors[:platform], "is not included in the list"
  end

  test "should validate priority range" do
    @content_schedule.priority = 0
    assert_not @content_schedule.valid?
    
    @content_schedule.priority = 6
    assert_not @content_schedule.valid?
    
    @content_schedule.priority = 3
    assert @content_schedule.valid?
  end

  test "should not allow scheduling in the past" do
    @content_schedule.scheduled_at = 1.hour.ago
    assert_not @content_schedule.valid?
    assert_includes @content_schedule.errors[:scheduled_at], "cannot be in the past"
  end

  test "should detect conflicts with overlapping schedules" do
    # Create first schedule
    schedule1 = ContentSchedule.create!(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 1,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: Time.current + 1.hour,
      priority: 3
    )

    # Create overlapping schedule
    schedule2 = ContentSchedule.new(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 2,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: Time.current + 1.hour + 2.minutes,
      priority: 3
    )

    assert schedule2.conflicts_with?(schedule1)
  end

  test "should not detect conflicts on different platforms" do
    schedule1 = ContentSchedule.create!(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 1,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: Time.current + 1.hour,
      priority: 3
    )

    schedule2 = ContentSchedule.new(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 2,
      platform: 'instagram',
      channel: 'social_media',
      scheduled_at: Time.current + 1.hour + 2.minutes,
      priority: 3
    )

    assert_not schedule2.conflicts_with?(schedule1)
  end

  test "should generate content preview" do
    # Mock content item with content
    content_mock = Minitest::Mock.new
    content_mock.expect :respond_to?, true, [:content]
    content_mock.expect :content, "This is test content for preview"
    
    @content_schedule.define_singleton_method(:content_item) { content_mock }
    
    preview = @content_schedule.content_preview
    assert_equal "This is test content for preview", preview
    
    content_mock.verify
  end

  test "should check if schedule is overdue" do
    @content_schedule.scheduled_at = 1.hour.ago
    @content_schedule.status = 'scheduled'
    assert @content_schedule.is_overdue?

    @content_schedule.scheduled_at = 1.hour.from_now
    assert_not @content_schedule.is_overdue?
  end

  test "should check if schedule is upcoming" do
    @content_schedule.scheduled_at = 1.hour.from_now
    @content_schedule.status = 'scheduled'
    assert @content_schedule.is_upcoming?

    @content_schedule.scheduled_at = 1.hour.ago
    assert_not @content_schedule.is_upcoming?
  end

  test "should calculate time until publish" do
    future_time = 2.hours.from_now
    @content_schedule.scheduled_at = future_time
    @content_schedule.status = 'scheduled'
    
    time_until = @content_schedule.time_until_publish
    assert time_until.include?("hour")
  end

  test "should validate platform constraints for Twitter" do
    @content_schedule.platform = 'twitter'
    
    # Mock content with long text
    content_mock = Minitest::Mock.new
    content_mock.expect :respond_to?, true, [:content]
    content_mock.expect :content, "a" * 300  # Exceeds Twitter limit
    
    @content_schedule.define_singleton_method(:content_item) { content_mock }
    
    violations = @content_schedule.validate_platform_constraints
    assert violations.any? { |v| v.include?("character limit") }
    
    content_mock.verify
  end

  test "should validate platform constraints for Instagram" do
    @content_schedule.platform = 'instagram'
    
    # Mock content without image
    content_mock = Minitest::Mock.new
    content_mock.expect :respond_to?, true, [:has_image?]
    content_mock.expect :has_image?, false
    
    @content_schedule.define_singleton_method(:content_item) { content_mock }
    
    violations = @content_schedule.validate_platform_constraints
    assert violations.any? { |v| v.include?("requires at least one image") }
    
    content_mock.verify
  end

  test "should transition from draft to scheduled" do
    @content_schedule.status = 'draft'
    @content_schedule.save!
    
    assert @content_schedule.may_schedule?
    @content_schedule.schedule!
    assert_equal 'scheduled', @content_schedule.status
  end

  test "should transition from scheduled to published" do
    @content_schedule.status = 'scheduled'
    @content_schedule.save!
    
    assert @content_schedule.may_publish?
    @content_schedule.publish!
    assert_equal 'published', @content_schedule.status
    assert_not_nil @content_schedule.published_at
  end

  test "should transition to cancelled" do
    @content_schedule.status = 'scheduled'
    @content_schedule.save!
    
    assert @content_schedule.may_cancel?
    @content_schedule.cancel!
    assert_equal 'cancelled', @content_schedule.status
  end

  test "should pause and resume" do
    @content_schedule.status = 'scheduled'
    @content_schedule.save!
    
    assert @content_schedule.may_pause?
    @content_schedule.pause!
    assert_equal 'paused', @content_schedule.status
    
    assert @content_schedule.may_resume?
    @content_schedule.resume!
    assert_equal 'scheduled', @content_schedule.status
  end

  test "should find conflicts within time window" do
    # Create a schedule
    existing_schedule = ContentSchedule.create!(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 1,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: Time.current + 1.hour,
      priority: 3
    )

    start_time = Time.current + 1.hour + 2.minutes
    end_time = start_time + 5.minutes
    
    conflicts = ContentSchedule.find_conflicts(start_time, end_time, 'twitter')
    assert_includes conflicts, existing_schedule
  end

  test "should generate available time slots" do
    date = Date.current
    slots = ContentSchedule.available_time_slots('twitter', date, 5)
    
    assert slots.is_a?(Array)
    assert slots.length > 0
    
    # Check that slots are in correct format
    first_slot = slots.first
    assert first_slot.is_a?(Hash)
    assert first_slot.key?(:start)
    assert first_slot.key?(:end)
    assert first_slot.key?(:available)
  end

  test "should handle recurrence patterns" do
    @content_schedule.frequency = 'daily'
    @content_schedule.recurrence_data = { 
      days: 7, 
      end_date: 1.week.from_now.to_date 
    }
    @content_schedule.save!
    
    recurring_schedules = @content_schedule.generate_recurring_schedules
    assert recurring_schedules.length == 7
    
    # Check that each schedule is spaced correctly
    recurring_schedules.each_with_index do |schedule, index|
      expected_time = @content_schedule.scheduled_at + index.days
      assert_equal expected_time.to_date, schedule[:scheduled_at].to_date
    end
  end
end