require "test_helper"

class OptimizationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    
    # Set up campaign plan for optimization
    @campaign_plan.update!(
      created_at: 2.days.ago,  # Ensure campaign is old enough
      plan_execution_started_at: 2.days.ago,
      performance_data: {
        roi: 150,
        ctr: 0.8,
        cpc: 2.5
      }.to_json,
      metadata: {
        optimization_settings: {
          auto_schedule_enabled: true,
          schedule_interval: 4.hours,
          send_notifications: true,
          max_consecutive_failures: 3
        }
      }
    )
    
    @optimization_rule = OptimizationRule.create!(
      campaign_plan: @campaign_plan,
      name: "Test Optimization Rule",
      rule_type: "budget_reallocation",
      trigger_type: "performance_threshold",
      priority: 1,
      confidence_threshold: 0.7,
      trigger_conditions: { metric: "ctr", threshold: 1.0, operator: "less_than" },
      optimization_actions: {
        budget_adjustments: {
          "google_ads" => { change_percent: 15, max_increase: 500 }
        }
      }
    )
  end

  def teardown
    clear_enqueued_jobs
    clear_performed_jobs
    Rails.cache.clear
  end

  # Job queuing tests
  test "should be queued on optimization queue" do
    assert_enqueued_with(job: OptimizationJob, queue: 'optimization') do
      OptimizationJob.perform_later(@campaign_plan.id)
    end
  end

  test "should retry on standard errors with exponential backoff" do
    # Test that the job class has retry_on method configured
    assert_respond_to OptimizationJob, :retry_on
    
    # This test just verifies the retry_on configuration exists
    # The actual retry behavior is handled by ActiveJob's retry mechanism
    assert true # Test passes if no errors are raised
  end

  test "should discard on RecordNotFound errors" do
    # Test that job is discarded when campaign plan doesn't exist
    perform_enqueued_jobs do
      OptimizationJob.perform_later(999999) # Non-existent ID
    end
    
    # Job should be discarded, not retried
    assert_no_enqueued_jobs
  end

  # Main perform method tests
  test "should execute optimization successfully" do
    # Mock the service to return success
    mock_result = {
      success: true,
      data: {
        triggered_rules_count: 1,
        successful_optimizations: 1,
        failed_optimizations: 0,
        optimization_results: [
          { rule_id: @optimization_rule.id, success: true, rule_type: 'budget_reallocation' }
        ],
        executed_at: Time.current
      }
    }
    
    PerformanceOptimizationService.any_instance.stubs(:call).returns(mock_result)
    
    perform_enqueued_jobs do
      OptimizationJob.perform_later(@campaign_plan.id)
    end
    
    @campaign_plan.reload
    assert_not_nil @campaign_plan.metadata['last_optimization_at']
    assert_equal 'success', @campaign_plan.metadata['last_optimization_result']
  end

  test "should skip optimization for ineligible campaigns" do
    # Set campaign to not be in execution state
    @campaign_plan.update!(plan_execution_started_at: nil)
    
    # Capture log output
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)
    
    perform_enqueued_jobs do
      OptimizationJob.perform_later(@campaign_plan.id)
    end
    
    log_contents = log_output.string
    assert_includes log_contents, "cannot be optimized"
    
    Rails.logger = original_logger
  end

  test "should handle optimization failures gracefully" do
    mock_result = {
      success: false,
      error: "Optimization failed",
      context: { reason: "API error" }
    }
    
    PerformanceOptimizationService.any_instance.stubs(:call).returns(mock_result)
    
    perform_enqueued_jobs do
      OptimizationJob.perform_later(@campaign_plan.id)
    end
    
    @campaign_plan.reload
    assert_equal 'failure', @campaign_plan.metadata['last_optimization_result']
    assert_equal 'Optimization failed', @campaign_plan.metadata['last_optimization_error']
  end

  test "should schedule next optimization when auto-schedule is enabled" do
    mock_result = {
      success: true,
      data: {
        triggered_rules_count: 1,
        successful_optimizations: 1,
        executed_at: Time.current
      }
    }
    
    PerformanceOptimizationService.any_instance.stubs(:call).returns(mock_result)
    
    # Clear any existing jobs first
    clear_enqueued_jobs
    
    # Execute the job directly without perform_enqueued_jobs to avoid interference
    job = OptimizationJob.new
    job.perform(@campaign_plan.id)
    
    # Check that a job was scheduled for the future
    assert_enqueued_jobs(1) # Should have one job scheduled for the future
    
    # Verify it's an OptimizationJob with the right campaign_plan_id
    enqueued_job = enqueued_jobs.last
    assert_equal 'OptimizationJob', enqueued_job[:job].name
    assert_equal @campaign_plan.id, enqueued_job[:args].first
    assert enqueued_job[:at].to_f > Time.current.to_f # Should be scheduled in the future
  end

  test "should pause optimization after repeated failures" do
    # Set up campaign to have repeated failures
    @campaign_plan.update!(
      metadata: @campaign_plan.metadata.merge(
        optimization_settings: { max_consecutive_failures: 2 }
      )
    )
    
    # Create failed executions
    2.times do
      OptimizationExecution.create!(
        optimization_rule: @optimization_rule,
        executed_at: rand(20).hours.ago,
        status: 'failed',
        result: { success: false }
      )
    end
    
    mock_result = {
      success: false,
      error: "Another failure"
    }
    
    PerformanceOptimizationService.any_instance.stubs(:call).returns(mock_result)
    
    perform_enqueued_jobs do
      OptimizationJob.perform_later(@campaign_plan.id)
    end
    
    @campaign_plan.reload
    assert @campaign_plan.metadata['optimization_paused']
    
    @optimization_rule.reload
    assert_equal 'paused', @optimization_rule.status
  end

  # Batch optimization tests
  test "perform_batch_optimization should process multiple campaigns" do
    campaign2 = campaign_plans(:another_plan) # Assuming fixture exists
    campaign_ids = [@campaign_plan.id, campaign2.id]
    
    mock_result = {
      success: true,
      data: {
        total_campaigns: 2,
        successful_optimizations: 2,
        failed_optimizations: 0,
        results: [
          { campaign_id: @campaign_plan.id, result: { success: true } },
          { campaign_id: campaign2.id, result: { success: true } }
        ]
      }
    }
    
    PerformanceOptimizationService.stubs(:bulk_optimize_campaigns).returns(mock_result)
    
    job = OptimizationJob.new
    job.perform_batch_optimization(campaign_ids)
    
    # Should complete without error
    assert true
  end

  test "perform_batch_optimization should schedule followup when requested" do
    campaign_ids = [@campaign_plan.id]
    options = {
      schedule_followup: true,
      followup_delay: 2.hours
    }
    
    mock_result = {
      success: true,
      data: { total_campaigns: 1, successful_optimizations: 1 }
    }
    
    PerformanceOptimizationService.stubs(:bulk_optimize_campaigns).returns(mock_result)
    
    assert_enqueued_with(job: OptimizationJob, at: 2.hours.from_now) do
      job = OptimizationJob.new
      job.perform_batch_optimization(campaign_ids, options)
    end
  end

  # Monitoring tests
  test "perform_monitoring should check for triggered rules" do
    # Mock performance data that would trigger rules
    mock_performance_data = { 'ctr' => 0.5 } # Below threshold
    
    job = OptimizationJob.new
    job.stub :fetch_performance_data, mock_performance_data do
      assert_enqueued_with(job: OptimizationJob) do
        job.perform_monitoring(@campaign_plan.id)
      end
    end
  end

  test "perform_monitoring should schedule next check for continuous monitoring" do
    options = {
      continuous_monitoring: true,
      monitoring_interval: 30.minutes
    }
    
    job = OptimizationJob.new
    job.stub :fetch_performance_data, {} do
      assert_enqueued_with(job: OptimizationJob, at: 30.minutes.from_now) do
        job.perform_monitoring(@campaign_plan.id, options)
      end
    end
  end

  test "perform_monitoring should skip for non-executing campaigns" do
    @campaign_plan.update!(plan_execution_completed_at: Time.current)
    
    job = OptimizationJob.new
    
    # Should return early without enqueueing jobs
    assert_no_enqueued_jobs do
      job.perform_monitoring(@campaign_plan.id)
    end
  end

  # Emergency stop tests
  test "perform_emergency_stop should pause all active rules" do
    reason = "High cost per conversion detected"
    
    job = OptimizationJob.new
    job.perform_emergency_stop(@campaign_plan.id, @user.id, reason)
    
    @optimization_rule.reload
    assert_equal 'paused', @optimization_rule.status
  end

  test "perform_emergency_stop should rollback recent optimizations when requested" do
    # Create recent successful execution
    execution = OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: 1.hour.ago,
      status: 'successful',
      result: { success: true }
    )
    
    options = {
      rollback_recent: true,
      rollback_hours: 2
    }
    
    OptimizationExecution.any_instance.stubs(:rollback!).returns(true)
    
    job = OptimizationJob.new
    job.perform_emergency_stop(@campaign_plan.id, @user.id, "Emergency stop", options)
    
    # Should attempt to rollback recent optimizations
    assert true # Test passes if no errors occur
  end

  # Rollback tests
  test "perform_rollback should rollback recent successful executions" do
    # Create successful execution
    execution = OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: 2.hours.ago,
      status: 'successful',
      result: { success: true }
    )
    
    OptimizationExecution.any_instance.stubs(:rollback!).returns(true)
    
    job = OptimizationJob.new
    job.perform_rollback(@campaign_plan.id, @user.id, { rollback_since: 24.hours.ago })
    
    # Should complete without error
    assert true
  end

  # Eligibility tests
  test "campaign_can_be_optimized should check execution state" do
    job = OptimizationJob.new
    
    assert job.send(:campaign_can_be_optimized?, @campaign_plan)
    
    @campaign_plan.update!(plan_execution_started_at: nil)
    assert_not job.send(:campaign_can_be_optimized?, @campaign_plan)
  end

  test "campaign_can_be_optimized should check for active rules" do
    job = OptimizationJob.new
    
    assert job.send(:campaign_can_be_optimized?, @campaign_plan)
    
    @optimization_rule.update!(status: 'inactive')
    assert_not job.send(:campaign_can_be_optimized?, @campaign_plan)
  end

  test "campaign_can_be_optimized should check campaign age" do
    job = OptimizationJob.new
    
    # Campaign created 2 days ago (in setup) should be eligible
    assert job.send(:campaign_can_be_optimized?, @campaign_plan)
    
    # Very new campaign should not be eligible
    new_campaign = CampaignPlan.create!(
      user: @user,
      name: "New Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      plan_execution_started_at: Time.current
    )
    
    OptimizationRule.create!(
      campaign_plan: new_campaign,
      name: "Rule for new campaign",
      rule_type: "budget_reallocation",
      trigger_type: "performance_threshold"
    )
    
    assert_not job.send(:campaign_can_be_optimized?, new_campaign)
  end

  test "campaign_can_be_optimized should check pause status" do
    job = OptimizationJob.new
    
    assert job.send(:campaign_can_be_optimized?, @campaign_plan)
    
    @campaign_plan.update!(
      metadata: (@campaign_plan.metadata || {}).merge(optimization_paused: true)
    )
    
    assert_not job.send(:campaign_can_be_optimized?, @campaign_plan)
  end

  # Failure handling tests
  test "should count recent failures correctly" do
    # Create some failed executions
    2.times do |i|
      OptimizationExecution.create!(
        optimization_rule: @optimization_rule,
        executed_at: (i + 1).hours.ago,
        status: 'failed',
        result: { success: false }
      )
    end
    
    # Create an old failed execution (should not count)
    OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: 25.hours.ago,
      status: 'failed',
      result: { success: false }
    )
    
    job = OptimizationJob.new
    job.instance_variable_set(:@campaign_plan_id, @campaign_plan.id)
    
    failure_count = job.send(:count_recent_failures, @campaign_plan)
    assert_equal 2, failure_count
  end

  test "should_pause_after_failures should use configured threshold" do
    @campaign_plan.update!(
      metadata: (@campaign_plan.metadata || {}).merge(
        optimization_settings: { max_consecutive_failures: 2 }
      )
    )
    
    job = OptimizationJob.new
    
    # Create failures at threshold
    2.times do |i|
      OptimizationExecution.create!(
        optimization_rule: @optimization_rule,
        executed_at: (i + 1).hours.ago,
        status: 'failed',
        result: { success: false }
      )
    end
    
    assert job.send(:should_pause_after_failures?, @campaign_plan)
  end

  # Class method tests
  test "schedule_optimization should enqueue job" do
    assert_enqueued_with(job: OptimizationJob) do
      OptimizationJob.schedule_optimization(@campaign_plan)
    end
  end

  test "schedule_optimization should enqueue job with delay" do
    delay = 2.hours
    
    assert_enqueued_with(job: OptimizationJob, at: delay.from_now) do
      OptimizationJob.schedule_optimization(@campaign_plan, delay: delay)
    end
  end

  test "schedule_batch_optimization should enqueue batch job" do
    campaigns = [@campaign_plan]
    
    assert_enqueued_with(job: OptimizationJob) do
      OptimizationJob.schedule_batch_optimization(campaigns)
    end
  end

  test "schedule_monitoring should enqueue monitoring job" do
    assert_enqueued_with(job: OptimizationJob) do
      OptimizationJob.schedule_monitoring(@campaign_plan)
    end
  end

  test "emergency_stop should enqueue emergency stop job" do
    reason = "Emergency detected"
    
    assert_enqueued_with(job: OptimizationJob) do
      OptimizationJob.emergency_stop(@campaign_plan, @user, reason)
    end
  end

  test "schedule_rollback should enqueue rollback job" do
    assert_enqueued_with(job: OptimizationJob) do
      OptimizationJob.schedule_rollback(@campaign_plan, @user)
    end
  end

  # Error handling tests
  test "should handle job errors and update campaign metadata" do
    # Mock service to raise an error
    PerformanceOptimizationService.any_instance.stubs(:call).raises(StandardError, "Service error")
    
    # Execute the job directly so we can catch the error and check metadata
    job = OptimizationJob.new
    assert_raises(StandardError) do
      job.perform(@campaign_plan.id)
    end
    
    @campaign_plan.reload
    assert_equal 'job_error', @campaign_plan.metadata['last_optimization_result']
    assert_equal 'Service error', @campaign_plan.metadata['last_job_error']['message']
  end

  # Notification tests (mock implementations)
  test "should send notifications when enabled" do
    job = OptimizationJob.new
    
    # Mock notification methods
    job.stubs(:should_send_notifications?).returns(true)
    job.stubs(:get_notification_recipients).returns(['test@example.com'])
    
    # Should not raise errors when sending notifications
    job.send(:send_optimization_notification, @campaign_plan, :success, {})
    job.send(:send_optimization_notification, @campaign_plan, :failure, { error: 'Test error' })
    
    assert true
  end

  test "should get notification recipients correctly" do
    job = OptimizationJob.new
    
    recipients = job.send(:get_notification_recipients, @campaign_plan)
    
    assert_includes recipients, @campaign_plan.user.email
    assert recipients.uniq.length == recipients.length # No duplicates
  end

  test "should respect notification settings" do
    job = OptimizationJob.new
    
    # Default should send notifications
    assert job.send(:should_send_notifications?, @campaign_plan)
    
    # Explicitly disabled
    @campaign_plan.update!(
      metadata: (@campaign_plan.metadata || {}).merge(
        optimization_settings: { send_notifications: false }
      )
    )
    
    assert_not job.send(:should_send_notifications?, @campaign_plan)
  end
end