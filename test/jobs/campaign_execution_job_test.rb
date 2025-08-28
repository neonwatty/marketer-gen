# frozen_string_literal: true

require 'test_helper'

class CampaignExecutionJobTest < ActiveJob::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    
    # Set up approved campaign plan
    @campaign_plan.update!(
      approval_status: 'approved',
      status: 'completed',
      generated_summary: 'Test summary',
      generated_strategy: { 'key' => 'value' }.to_json
    )
    
    @execution_schedule = ExecutionSchedule.create!(
      campaign_plan: @campaign_plan,
      name: "Test Execution Job",
      scheduled_at: 1.hour.from_now, # Future time as required by validation
      platform_targets: {
        "meta" => { "budget" => { "daily_budget" => 100 } }
      },
      execution_rules: {
        "start_hour" => 0,
        "end_hour" => 23,
        "timezone" => "UTC",
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7],
        "send_notifications" => false
      },
      status: 'scheduled',
      active: true,
      priority: 5,
      created_by: @user,
      updated_by: @user
    )
    
    setup_platform_connections
  end

  # Job enqueueing tests
  test "should enqueue job with correct arguments" do
    assert_enqueued_with(job: CampaignExecutionJob, args: [@execution_schedule.id]) do
      CampaignExecutionJob.perform_later(@execution_schedule.id)
    end
  end

  test "should enqueue job with options" do
    options = { 'retry' => true, 'priority' => 'high' }
    assert_enqueued_with(job: CampaignExecutionJob, args: [@execution_schedule.id, options]) do
      CampaignExecutionJob.perform_later(@execution_schedule.id, options)
    end
  end

  test "should schedule execution for future time" do
    future_schedule = ExecutionSchedule.create!(
      campaign_plan: @campaign_plan,
      name: "Future Execution",
      scheduled_at: 2.hours.from_now,
      platform_targets: { "meta" => {} },
      execution_rules: {
        "start_hour" => 0,
        "end_hour" => 23,
        "timezone" => "UTC",
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7]
      },
      created_by: @user,
      updated_by: @user
    )
    
    # The job should be scheduled at next_execution_at, not scheduled_at
    expected_time = future_schedule.next_execution_at || future_schedule.scheduled_at
    assert_enqueued_with(job: CampaignExecutionJob, at: expected_time) do
      CampaignExecutionJob.schedule_execution(future_schedule)
    end
  end

  # Job performance tests
  test "perform executes campaign successfully" do
    # Ensure schedule can be executed
    @execution_schedule.update!(scheduled_at: 5.minutes.ago)
    
    # Mock successful execution
    mock_service = Minitest::Mock.new
    mock_service.expect :call, { success: true, data: { platforms_deployed: ['meta'] } }
    
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      CampaignExecutionJob.perform_now(@execution_schedule.id)
    end
    
    mock_service.verify
    
    @execution_schedule.reload
    assert @execution_schedule.completed?
  end

  test "perform handles execution failure" do
    # Ensure schedule can be executed and has high retry count so it won't retry
    @execution_schedule.update!(
      scheduled_at: 5.minutes.ago,
      metadata: { 'retry_count' => 3 }
    )
    
    # Mock failed execution
    mock_service = Minitest::Mock.new
    mock_service.expect :call, { 
      success: false, 
      error: "Platform connection failed",
      context: { platform: 'meta' }
    }
    
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      CampaignExecutionJob.perform_now(@execution_schedule.id)
    end
    
    mock_service.verify
    
    @execution_schedule.reload
    assert @execution_schedule.failed?
  end

  test "perform skips execution when schedule cannot be executed" do
    @execution_schedule.update!(status: 'completed')
    
    # Should not create service when execution is skipped
    CampaignExecutionService.stub :new, ->(*) { raise "Should not be called" } do
      perform_enqueued_jobs do
        CampaignExecutionJob.perform_later(@execution_schedule.id)
      end
    end
    
    # Status should remain unchanged
    @execution_schedule.reload
    assert @execution_schedule.completed?
  end

  test "perform reschedules when outside execution window" do
    mocked_time = Time.zone.parse("2024-01-06 10:00:00 UTC")
    
    # Set execution schedule to be outside the window and schedulable
    @execution_schedule.update!(
      scheduled_at: mocked_time - 5.minutes,
      execution_rules: {
        "start_hour" => 1,
        "end_hour" => 2,
        "timezone" => "UTC",
        "days_of_week" => [1] # Only Monday
      }
    )
    
    original_scheduled_at = @execution_schedule.scheduled_at
    
    # Mock current time to Saturday (outside window)
    mocked_time = Time.zone.parse("2024-01-06 10:00:00 UTC")
    puts "Mocked time: #{mocked_time}, wday: #{mocked_time.wday}"
    puts "Execution rules: #{@execution_schedule.execution_rules}"
    puts "In execution window? #{@execution_schedule.in_execution_window?(mocked_time)}"
    
    Time.stub :current, mocked_time do
      puts "Time.current in stub: #{Time.current}"
      CampaignExecutionJob.perform_now(@execution_schedule.id)
    end
    
    @execution_schedule.reload
    puts "Original scheduled_at: #{original_scheduled_at}"
    puts "New scheduled_at: #{@execution_schedule.scheduled_at}"
    puts "Metadata: #{@execution_schedule.metadata}"
    puts "Status: #{@execution_schedule.status}"
    assert @execution_schedule.scheduled_at > original_scheduled_at
    assert_equal 'outside_execution_window', @execution_schedule.metadata['rescheduled_reason']
  end

  test "perform handles ActiveRecord::RecordNotFound" do
    non_existent_id = ExecutionSchedule.maximum(:id).to_i + 1
    
    # Should not raise error, just log and exit
    assert_nothing_raised do
      perform_enqueued_jobs do
        CampaignExecutionJob.perform_later(non_existent_id)
      end
    end
  end

  test "perform handles exceptions and marks schedule as failed" do
    # Ensure schedule can be executed - set to past time and active
    @execution_schedule.update!(scheduled_at: 5.minutes.ago, active: true, status: 'scheduled')
    
    # Verify conditions are met for execution
    assert @execution_schedule.can_be_executed?, "Schedule should be executable: status=#{@execution_schedule.status}, active=#{@execution_schedule.active}, scheduled_at=#{@execution_schedule.scheduled_at}"
    
    # Mock service to raise exception
    CampaignExecutionService.stub :new, ->(*) { raise StandardError, "Unexpected error" } do
      # The job should handle the exception internally and re-raise it for retry mechanism
      assert_raises StandardError do
        CampaignExecutionJob.perform_now(@execution_schedule.id)
      end
    end
    
    @execution_schedule.reload
    assert @execution_schedule.failed?
    assert_equal "Unexpected error", @execution_schedule.metadata['error_message']
  end

  # Rollback tests
  test "perform_rollback executes rollback successfully" do
    @execution_schedule.update!(
      status: 'completed',
      metadata: {
        'rollback_data' => {
          'platforms' => ['meta'],
          'campaign_ids' => { 'meta' => ['campaign_123'] }
        }
      }
    )
    
    mock_service = Minitest::Mock.new
    mock_service.expect :rollback_execution, {
      success: true,
      data: { rollback_successful: true }
    }
    
    job = CampaignExecutionJob.new
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      job.perform_rollback(@execution_schedule.id, @user.id, {})
    end
    
    mock_service.verify
    assert true # Test completed successfully
  end

  test "perform_rollback handles rollback failure" do
    @execution_schedule.update!(
      status: 'completed',
      metadata: { 'rollback_data' => { 'platforms' => ['meta'] } }
    )
    
    mock_service = Minitest::Mock.new
    mock_service.expect :rollback_execution, {
      success: false,
      error: "Rollback failed"
    }
    
    job = CampaignExecutionJob.new
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      job.perform_rollback(@execution_schedule.id, @user.id, {})
    end
    
    mock_service.verify
    assert true # Test completed successfully
  end

  # Monitoring tests
  test "perform_monitoring monitors executing schedule" do
    @execution_schedule.update!(status: 'executing')
    
    mock_service = Minitest::Mock.new
    mock_service.expect :execution_status, {
      performance_metrics: {
        'meta' => { 'ctr' => 1.5, 'cpc' => 3.0 }
      }
    }
    
    job = CampaignExecutionJob.new
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      # Mock scheduling next monitoring job
      CampaignExecutionJob.stub :perform_later, nil do
        job.perform_monitoring(@execution_schedule.id, {})
      end
    end
    
    mock_service.verify
    assert @execution_schedule.executing?
  end

  test "perform_monitoring skips non-executing schedules" do
    @execution_schedule.update!(status: 'completed')
    
    job = CampaignExecutionJob.new
    
    # Should not create service for non-executing schedules
    CampaignExecutionService.stub :new, ->(*) { raise "Should not be called" } do
      job.perform_monitoring(@execution_schedule.id, {})
    end
    
    assert @execution_schedule.completed?
  end

  test "perform_monitoring applies optimizations when needed" do
    @execution_schedule.update!(status: 'executing')
    
    # Mock poor performance that triggers optimization
    mock_service = Minitest::Mock.new
    mock_service.expect :execution_status, {
      performance_metrics: {
        'meta' => { 'ctr' => 0.3, 'cpc' => 6.0 } # Poor performance
      }
    }
    
    job = CampaignExecutionJob.new
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      CampaignExecutionJob.stub :perform_later, nil do
        job.perform_monitoring(@execution_schedule.id, {})
      end
    end
    
    mock_service.verify
    
    # Check that optimization was logged
    @execution_schedule.reload
    assert @execution_schedule.metadata['optimization_history'].present?
  end

  # Success handling tests
  test "handle_successful_execution updates campaign plan" do
    # Ensure schedule can be executed
    @execution_schedule.update!(scheduled_at: 5.minutes.ago)
    
    mock_service = Minitest::Mock.new
    mock_service.expect :call, { 
      success: true, 
      data: { platforms_deployed: ['meta'], execution_id: 'exec_123' }
    }
    
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      CampaignExecutionJob.perform_now(@execution_schedule.id)
    end
    
    mock_service.verify
    
    @campaign_plan.reload
    assert @campaign_plan.plan_execution_started_at.present?
  end

  test "handle_successful_execution schedules monitoring when enabled" do
    @execution_schedule.update!(
      scheduled_at: 5.minutes.ago,
      execution_rules: @execution_schedule.execution_rules.merge(
        "auto_monitor" => true,
        "monitoring_interval" => 1800 # 30 minutes in seconds
      )
    )
    
    mock_service = Minitest::Mock.new
    mock_service.expect :call, { success: true, data: {} }
    
    # Clear the queue first
    clear_enqueued_jobs
    
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      CampaignExecutionJob.perform_now(@execution_schedule.id)
    end
    
    mock_service.verify
    
    # Check that a monitoring job was enqueued
    assert_enqueued_jobs 1, only: CampaignExecutionJob
  end

  test "handle_successful_execution schedules optimization when enabled" do
    @execution_schedule.update!(
      scheduled_at: 5.minutes.ago,
      execution_rules: @execution_schedule.execution_rules.merge(
        "auto_optimize" => true,
        "optimization_delay" => 7200 # 2 hours in seconds
      )
    )
    
    mock_service = Minitest::Mock.new
    mock_service.expect :call, { success: true, data: {} }
    
    # Clear the queue first
    clear_enqueued_jobs
    
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      CampaignExecutionJob.perform_now(@execution_schedule.id)
    end
    
    mock_service.verify
    
    # Check that an optimization job was enqueued
    assert_enqueued_jobs 1, only: CampaignExecutionJob
  end

  # Retry logic tests
  test "handle_failed_execution schedules retry for eligible schedules" do
    # Ensure schedule can be executed and is eligible for retry
    @execution_schedule.update!(
      scheduled_at: 5.minutes.ago,
      metadata: { 'retry_count' => 1 }
    )
    
    mock_service = Minitest::Mock.new
    mock_service.expect :call, { 
      success: false, 
      error: "Temporary API error",
      context: { platform: 'meta' }
    }
    
    # Clear the queue first
    clear_enqueued_jobs
    
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      CampaignExecutionJob.perform_now(@execution_schedule.id)
    end
    
    mock_service.verify
    
    @execution_schedule.reload
    assert @execution_schedule.scheduled?
    
    # Check that a retry job was enqueued
    assert_enqueued_jobs 1, only: CampaignExecutionJob
  end

  test "handle_failed_execution does not retry when limit exceeded" do
    # Set high retry count to exceed limit and make schedulable  
    @execution_schedule.update!(
      metadata: { 'retry_count' => 3 },
      scheduled_at: 5.minutes.ago
    )
    
    mock_service = Minitest::Mock.new
    mock_service.expect :call, { 
      success: false, 
      error: "Permanent failure"
    }
    
    CampaignExecutionService.stub :new, ->(_) { mock_service } do
      CampaignExecutionJob.perform_now(@execution_schedule.id)
    end
    
    mock_service.verify
    
    @execution_schedule.reload
    assert @execution_schedule.failed?
  end

  test "should_retry_execution correctly evaluates retry eligibility" do
    job = CampaignExecutionJob.new
    
    # Fresh schedule with low retry count should be retryable
    @execution_schedule.update!(
      metadata: { 'retry_count' => 1 },
      created_at: 2.hours.ago
    )
    assert job.send(:should_retry_execution?, @execution_schedule)
    
    # High retry count should not be retryable
    @execution_schedule.update!(metadata: { 'retry_count' => 3 })
    assert_not job.send(:should_retry_execution?, @execution_schedule)
    
    # Old schedule should not be retryable
    @execution_schedule.update!(
      metadata: { 'retry_count' => 1 },
      created_at: 2.days.ago
    )
    assert_not job.send(:should_retry_execution?, @execution_schedule)
  end

  # Class method tests
  test "schedule_execution schedules job at correct time" do
    future_time = 2.hours.from_now
    @execution_schedule.update!(next_execution_at: future_time)
    
    assert_enqueued_with(job: CampaignExecutionJob, at: future_time) do
      CampaignExecutionJob.schedule_execution(@execution_schedule)
    end
  end

  test "schedule_rollback schedules rollback job" do
    options = { notify_completion: true }
    expected_args = [@execution_schedule.id, @user.id, options.merge(operation: 'rollback')]
    
    assert_enqueued_with(job: CampaignExecutionJob, args: expected_args) do
      CampaignExecutionJob.schedule_rollback(@execution_schedule, @user, options: options)
    end
  end

  test "schedule_monitoring schedules monitoring job" do
    options = { monitoring_interval: 1800 }
    expected_args = [@execution_schedule.id, options.merge(operation: 'monitor')]
    
    assert_enqueued_with(job: CampaignExecutionJob, args: expected_args) do
      CampaignExecutionJob.schedule_monitoring(@execution_schedule, options: options)
    end
  end

  test "bulk_schedule_executions schedules multiple jobs" do
    schedule2 = ExecutionSchedule.create!(
      campaign_plan: @campaign_plan,
      name: "Second Execution",
      scheduled_at: 2.hours.from_now,
      platform_targets: { "meta" => {} },
      execution_rules: {
        "start_hour" => 0,
        "end_hour" => 23,
        "timezone" => "UTC",
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7]
      },
      created_by: @user,
      updated_by: @user
    )
    
    schedules = [@execution_schedule, schedule2]
    
    assert_enqueued_jobs 2, only: CampaignExecutionJob do
      CampaignExecutionJob.bulk_schedule_executions(schedules)
    end
  end

  # Notification tests
  test "get_notification_recipients includes creator and plan owner" do
    job = CampaignExecutionJob.new
    recipients = job.send(:get_notification_recipients, @execution_schedule)
    
    assert_includes recipients, @user.email
    assert_includes recipients, @campaign_plan.user.email
  end

  test "get_notification_recipients includes additional emails from rules" do
    @execution_schedule.update!(
      execution_rules: @execution_schedule.execution_rules.merge(
        "notification_emails" => ["extra1@example.com", "extra2@example.com"]
      )
    )
    
    job = CampaignExecutionJob.new
    recipients = job.send(:get_notification_recipients, @execution_schedule)
    
    assert_includes recipients, "extra1@example.com"
    assert_includes recipients, "extra2@example.com"
  end

  test "should_send_notifications respects execution rules" do
    job = CampaignExecutionJob.new
    
    # First test with execution rules that don't have send_notifications (should default to true)
    @execution_schedule.update!(
      execution_rules: @execution_schedule.execution_rules.except("send_notifications")
    )
    assert job.send(:should_send_notifications?, @execution_schedule)
    
    # When explicitly disabled
    @execution_schedule.update!(
      execution_rules: @execution_schedule.execution_rules.merge(
        "send_notifications" => false
      )
    )
    assert_not job.send(:should_send_notifications?, @execution_schedule)
  end

  # Retry time calculation tests
  test "calculate_retry_time increases exponentially" do
    job = CampaignExecutionJob.new
    
    current_time = Time.current
    
    # Test multiple times to account for randomness
    retry_1_times = []
    retry_2_times = []
    
    10.times do
      retry_1_times << job.send(:calculate_retry_time, 1)
      retry_2_times << job.send(:calculate_retry_time, 2)
    end
    
    # All should be in the future
    retry_1_times.each { |time| assert time > current_time }
    retry_2_times.each { |time| assert time > current_time }
    
    # Average retry time for count 2 should be greater than for count 1
    avg_retry_1 = retry_1_times.sum(&:to_f) / retry_1_times.length
    avg_retry_2 = retry_2_times.sum(&:to_f) / retry_2_times.length
    
    assert avg_retry_2 > avg_retry_1, "Average retry time for count 2 should be greater than count 1"
  end

  test "calculate_retry_time caps at maximum delay" do
    job = CampaignExecutionJob.new
    
    # Very high retry count should still be capped
    retry_time = job.send(:calculate_retry_time, 10)
    max_expected_time = Time.current + 65.minutes # 60 + 5 minute random
    
    assert retry_time < max_expected_time
  end

  private

  def setup_platform_connections
    @user.platform_connections.destroy_all
    
    PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: "{\"access_token\":\"test_token\"}",
      status: 'active',
      account_id: 'test_account_meta',
      account_name: 'Test Meta Account',
      metadata: "{\"test\":\"data\"}"
    )
  end
end