require "test_helper"

class ExecutionScheduleTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @another_user = users(:team_member_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @valid_attributes = {
      campaign_plan: @campaign_plan,
      name: "Test Execution Schedule",
      description: "Test execution description",
      scheduled_at: 2.hours.from_now,
      platform_targets: {
        "meta" => {
          "budget" => { "daily_budget" => 100 },
          "targeting" => { "age_range" => { "min" => 25, "max" => 54 } }
        }
      },
      execution_rules: {
        "start_hour" => 9,
        "end_hour" => 17,
        "timezone" => "UTC",
        "days_of_week" => [1, 2, 3, 4, 5]
      },
      priority: 5,
      created_by: @user,
      updated_by: @user
    }
  end

  # Basic validation tests
  test "should be valid with valid attributes" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes)
    assert execution_schedule.valid?, execution_schedule.errors.full_messages.join(", ")
  end

  test "should require name" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.except(:name))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:name], "can't be blank"
  end

  test "should require scheduled_at" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.except(:scheduled_at))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:scheduled_at], "can't be blank"
  end

  test "should require campaign_plan" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.except(:campaign_plan))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:campaign_plan], "must exist"
  end

  test "should require created_by user" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.except(:created_by))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:created_by], "must exist"
  end

  test "should require updated_by user" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.except(:updated_by))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:updated_by], "must exist"
  end

  test "should validate scheduled_at is in future on create" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(scheduled_at: 1.hour.ago))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:scheduled_at], "must be in the future"
  end

  test "should not validate scheduled_at is in future on update" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    execution_schedule.update(description: "Updated description")
    assert execution_schedule.valid?
  end

  test "should validate status inclusion" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(status: "invalid_status"))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:status], "is not included in the list"
  end

  test "should validate priority range" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(priority: 0))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:priority], "must be greater than 0"

    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(priority: 11))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:priority], "must be less than or equal to 10"
  end

  # Platform targets validation tests
  test "should validate platform_targets structure" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(
      platform_targets: "invalid_json"
    ))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:platform_targets], "must be a valid JSON object"
  end

  test "should validate supported platforms in platform_targets" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(
      platform_targets: { "unsupported_platform" => {} }
    ))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:platform_targets], "includes unsupported platform: unsupported_platform"
  end

  test "should validate platform config structure" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(
      platform_targets: { "meta" => "invalid_config" }
    ))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:platform_targets], "configuration for meta must be an object"
  end

  # Execution rules validation tests
  test "should validate execution_rules structure" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(
      execution_rules: "invalid_json"
    ))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:execution_rules], "must be a valid JSON object"
  end

  test "should validate start_hour range" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(
      execution_rules: { "start_hour" => 25 }
    ))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:execution_rules], "start_hour must be between 0 and 23"
  end

  test "should validate end_hour range" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(
      execution_rules: { "end_hour" => -1 }
    ))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:execution_rules], "end_hour must be between 0 and 23"
  end

  test "should validate start_hour before end_hour" do
    execution_schedule = ExecutionSchedule.new(@valid_attributes.merge(
      execution_rules: { "start_hour" => 18, "end_hour" => 9 }
    ))
    assert_not execution_schedule.valid?
    assert_includes execution_schedule.errors[:execution_rules], "start_hour must be before end_hour"
  end

  # Scopes tests
  test "active scope should return active schedules" do
    active_schedule = ExecutionSchedule.create!(@valid_attributes)
    inactive_schedule = ExecutionSchedule.create!(@valid_attributes.merge(
      name: "Inactive Schedule",
      active: false
    ))

    active_schedules = ExecutionSchedule.active
    assert_includes active_schedules, active_schedule
    assert_not_includes active_schedules, inactive_schedule
  end

  test "ready_for_execution scope should return scheduled and due schedules" do
    ready_schedule = ExecutionSchedule.create!(@valid_attributes)
    ready_schedule.update_columns(scheduled_at: 1.hour.ago, status: "scheduled")
    future_schedule = ExecutionSchedule.create!(@valid_attributes.merge(
      name: "Future Schedule",
      scheduled_at: 2.hours.from_now
    ))

    ready_schedules = ExecutionSchedule.ready_for_execution
    assert_includes ready_schedules, ready_schedule
    assert_not_includes ready_schedules, future_schedule
  end

  test "high_priority scope should return schedules with priority <= 3" do
    high_priority = ExecutionSchedule.create!(@valid_attributes.merge(priority: 2))
    low_priority = ExecutionSchedule.create!(@valid_attributes.merge(
      name: "Low Priority",
      priority: 8
    ))

    high_priority_schedules = ExecutionSchedule.high_priority
    assert_includes high_priority_schedules, high_priority
    assert_not_includes high_priority_schedules, low_priority
  end

  test "needs_retry scope should return failed schedules eligible for retry" do
    failed_schedule = ExecutionSchedule.create!(@valid_attributes.merge(status: "failed"))
    failed_schedule.update!(
      metadata: { "retry_count" => 2 },
      created_at: 2.hours.ago
    )
    
    old_failed_schedule = ExecutionSchedule.create!(@valid_attributes.merge(
      name: "Old Failed",
      status: "failed",
      created_at: 2.days.ago
    ))

    retry_eligible = ExecutionSchedule.needs_retry
    assert_includes retry_eligible, failed_schedule
    assert_not_includes retry_eligible, old_failed_schedule
  end

  # Status methods tests
  test "status predicate methods should work correctly" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    
    assert execution_schedule.scheduled?
    assert_not execution_schedule.executing?
    assert_not execution_schedule.completed?
    assert_not execution_schedule.failed?
    
    execution_schedule.update!(status: "executing")
    assert execution_schedule.executing?
    assert_not execution_schedule.scheduled?
  end

  # Execution control methods tests
  test "can_be_executed should return true when schedule is ready" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    execution_schedule.update_column(:scheduled_at, 1.hour.ago)  # Bypass validation
    execution_schedule.update_column(:status, "scheduled")
    
    assert execution_schedule.can_be_executed?
  end

  test "can_be_executed should return false when not ready" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes.merge(
      status: "executing"
    ))
    
    assert_not execution_schedule.can_be_executed?
  end

  test "mark_pending should update status and metadata" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    execution_schedule.mark_pending!(@user)
    
    assert execution_schedule.pending?
    assert_equal @user, execution_schedule.updated_by
    assert execution_schedule.metadata["status_changed_at"].present?
  end

  test "mark_executing should update status and execution time" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    execution_schedule.mark_executing!(@user)
    
    assert execution_schedule.executing?
    assert execution_schedule.last_executed_at.present?
    assert execution_schedule.metadata["execution_started_at"].present?
  end

  test "mark_completed should update status and result" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    result = { "platforms_deployed" => ["meta"], "success" => true }
    execution_schedule.mark_completed!(@user, result)
    
    assert execution_schedule.completed?
    assert_equal result, execution_schedule.metadata["execution_result"]
  end

  test "mark_failed should update status and error info" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    error_message = "Platform connection failed"
    execution_schedule.mark_failed!(@user, error_message)
    
    assert execution_schedule.failed?
    assert_equal error_message, execution_schedule.metadata["error_message"]
    assert_equal 1, execution_schedule.metadata["retry_count"]
  end

  test "cancel should work when cancellation is allowed" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    reason = "User requested cancellation"
    
    assert execution_schedule.can_be_cancelled?
    assert execution_schedule.cancel!(@user, reason)
    assert execution_schedule.cancelled?
    assert_equal reason, execution_schedule.metadata["cancellation_reason"]
  end

  test "cancel should fail when not allowed" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes.merge(status: "completed"))
    
    assert_not execution_schedule.can_be_cancelled?
    assert_not execution_schedule.cancel!(@user)
  end

  test "pause and resume should work correctly" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    
    # Test pause
    assert execution_schedule.can_be_paused?
    assert execution_schedule.pause!(@user, "Temporary pause")
    assert execution_schedule.paused?
    
    # Test resume
    assert execution_schedule.can_be_resumed?
    assert execution_schedule.resume!(@user)
    assert execution_schedule.scheduled?
  end

  test "retry should work for failed schedules" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes.merge(status: "failed"))
    execution_schedule.update!(metadata: { "retry_count" => 1 })
    
    assert execution_schedule.can_be_retried?
    assert execution_schedule.retry!(@user)
    assert execution_schedule.scheduled?
    assert execution_schedule.scheduled_at > Time.current
  end

  test "retry should fail when retry limit exceeded" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes.merge(status: "failed"))
    execution_schedule.update!(metadata: { "retry_count" => 3 })
    
    assert_not execution_schedule.can_be_retried?
    assert_not execution_schedule.retry!(@user)
  end

  # Platform methods tests
  test "target_platforms should return configured platforms" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    # Update with valid platforms only
    execution_schedule.update!(platform_targets: {
      "meta" => {},
      "google_ads" => {}
    })
    
    platforms = execution_schedule.target_platforms
    assert_includes platforms, "meta"
    assert_includes platforms, "google_ads"
    assert_equal 2, platforms.length
  end

  test "platform_config should return config for specific platform" do
    config = { "budget" => { "daily_budget" => 200 } }
    execution_schedule = ExecutionSchedule.create!(@valid_attributes.merge(
      platform_targets: { "meta" => config }
    ))
    
    assert_equal config, execution_schedule.platform_config("meta")
    assert_equal({}, execution_schedule.platform_config("google_ads"))
  end

  test "has_platform should check platform existence" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    
    assert execution_schedule.has_platform?("meta")
    assert_not execution_schedule.has_platform?("google_ads")
  end

  # Execution window tests
  test "execution_window should return configured window" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    window = execution_schedule.execution_window
    
    assert_equal 9, window[:start_hour]
    assert_equal 17, window[:end_hour]
    assert_equal "UTC", window[:timezone]
    assert_equal [1, 2, 3, 4, 5], window[:days_of_week]
  end

  test "in_execution_window should check current time against window" do
    # Test during business hours (Wednesday 10 AM UTC)
    wednesday_10am = Time.zone.parse("2024-01-03 10:00:00 UTC") # Wednesday
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    
    # Test directly with time parameter instead of stubbing Time.current
    assert execution_schedule.in_execution_window?(wednesday_10am)
    
    # Test outside business hours (Wednesday 8 PM UTC)
    wednesday_8pm = Time.zone.parse("2024-01-03 20:00:00 UTC")
    assert_not execution_schedule.in_execution_window?(wednesday_8pm)
    
    # Test weekend (Saturday 10 AM UTC)
    saturday_10am = Time.zone.parse("2024-01-06 10:00:00 UTC") # Saturday
    assert_not execution_schedule.in_execution_window?(saturday_10am)
  end

  test "next_valid_execution_time should find next valid window" do
    # Schedule for Saturday 10 AM (outside window)
    saturday_10am = Time.zone.parse("2024-01-06 10:00:00 UTC")
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    execution_schedule.update_column(:scheduled_at, saturday_10am)
    
    next_time = execution_schedule.next_valid_execution_time
    
    # Should be next available window  
    # Since Saturday is outside window, should find next valid business day
    assert next_time > saturday_10am
    # Check the actual weekday (0 = Sunday, 1-5 = Mon-Fri, 6 = Saturday)
    valid_weekdays = [1, 2, 3, 4, 5]
    assert_includes valid_weekdays, next_time.wday, "Expected weekday 1-5, got #{next_time.wday} for #{next_time}"
  end

  # Metadata helper tests
  test "retry_count should return current retry count" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    assert_equal 0, execution_schedule.retry_count
    
    execution_schedule.update!(metadata: { "retry_count" => 2 })
    assert_equal 2, execution_schedule.retry_count
  end

  test "execution_duration should calculate duration" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    start_time = 1.hour.ago
    end_time = Time.current
    
    execution_schedule.update!(metadata: {
      "execution_started_at" => start_time.iso8601,
      "execution_completed_at" => end_time.iso8601
    })
    
    duration = execution_schedule.execution_duration
    assert_in_delta 3600, duration, 5 # Allow 5 second tolerance
  end

  test "execution_summary should provide comprehensive status" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes.merge(
      status: "executing",
      priority: 3
    ))
    
    summary = execution_schedule.execution_summary
    assert_equal execution_schedule.id, summary[:id]
    assert_equal "Test Execution Schedule", summary[:name]
    assert_equal "executing", summary[:status]
    assert_equal 3, summary[:priority]
    assert_equal ["meta"], summary[:target_platforms]
    assert_equal 0, summary[:retry_count]
  end

  # Rollback capabilities tests
  test "rollback_capabilities should indicate rollback status" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes.merge(status: "completed"))
    
    # Without rollback data
    capabilities = execution_schedule.rollback_capabilities
    assert_not capabilities[:can_rollback]
    assert_empty capabilities[:rollback_platforms]
    
    # With rollback data
    execution_schedule.prepare_rollback_data!({
      platforms: ["meta", "google_ads"],
      campaign_ids: { "meta" => ["123"], "google_ads" => ["456"] },
      user_id: @user.id
    })
    
    capabilities = execution_schedule.rollback_capabilities
    assert capabilities[:can_rollback]
    assert_equal ["meta", "google_ads"], capabilities[:rollback_platforms]
  end

  test "prepare_rollback_data should store rollback information" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    rollback_data = {
      platforms: ["meta"],
      campaign_ids: { "meta" => ["campaign_123"] },
      user_id: @user.id
    }
    
    execution_schedule.prepare_rollback_data!(rollback_data)
    
    stored_data = execution_schedule.metadata["rollback_data"]
    assert_equal ["meta"], stored_data["platforms"]
    assert_equal({ "meta" => ["campaign_123"] }, stored_data["campaign_ids"])
    assert stored_data["prepared_at"].present?
    assert_equal @user.id, stored_data["prepared_by"]
  end

  # Callback tests
  test "should set defaults on create" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes.except(
      :platform_targets, :execution_rules, :metadata, :priority, :status
    ))
    
    assert_equal({}, execution_schedule.platform_targets)
    assert_equal({}, execution_schedule.execution_rules)
    assert_equal({}, execution_schedule.metadata)
    assert_equal 5, execution_schedule.priority
    assert_equal "scheduled", execution_schedule.status
    assert execution_schedule.active?
  end

  test "should calculate next_execution_at on scheduled_at change" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    original_next_execution = execution_schedule.next_execution_at
    
    new_scheduled_time = 3.days.from_now
    execution_schedule.update!(scheduled_at: new_scheduled_time)
    
    assert_not_equal original_next_execution, execution_schedule.next_execution_at
  end

  # Edge cases and error handling
  test "should handle invalid JSON gracefully" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    
    # Simulate corrupted JSON in database
    ExecutionSchedule.where(id: execution_schedule.id)
                    .update_all(platform_targets: 'invalid json')
    execution_schedule.reload
    
    # Should return empty hash instead of raising error
    assert_equal({}, execution_schedule.platform_config("meta"))
  end

  test "should handle missing metadata gracefully" do
    execution_schedule = ExecutionSchedule.create!(@valid_attributes)
    execution_schedule.update_column(:metadata, nil)
    
    assert_equal 0, execution_schedule.retry_count
    assert_nil execution_schedule.execution_duration
  end

  private

  def create_test_user
    User.create!(
      email: "test_user_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User"
    )
  end
end