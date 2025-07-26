require "test_helper"

class JourneyExecutionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "journey_execution_test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    @journey = Journey.create!(
      user: @user,
      name: "Test Journey",
      status: "published"
    )
    
    @step1 = JourneyStep.create!(
      journey: @journey,
      name: "Welcome Email",
      stage: "awareness",
      position: 0,
      is_entry_point: true
    )
    
    @step2 = JourneyStep.create!(
      journey: @journey,
      name: "Follow-up Email",
      stage: "consideration",
      position: 1
    )
    
    @step3 = JourneyStep.create!(
      journey: @journey,
      name: "Final CTA",
      stage: "conversion",
      position: 2,
      is_exit_point: true
    )
    
    @execution = JourneyExecution.create!(
      journey: @journey,
      user: @user
    )
  end
  
  test "should be valid with valid attributes" do
    assert @execution.valid?
  end
  
  test "should enforce unique user per journey" do
    duplicate = JourneyExecution.new(journey: @journey, user: @user)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "can only have one execution per journey"
  end
  
  test "should have initial state" do
    assert @execution.initialized?
    assert_equal "initialized", @execution.status
  end
  
  test "should start journey" do
    @execution.start!
    
    assert @execution.running?
    assert_not_nil @execution.started_at
    assert @execution.started_at <= Time.current
  end
  
  test "should not start if journey is not published" do
    @journey.update!(status: "draft")
    
    assert_not @execution.may_start?
  end
  
  test "should pause and resume" do
    @execution.start!
    
    @execution.pause!
    assert @execution.paused?
    assert_not_nil @execution.paused_at
    
    @execution.resume!
    assert @execution.running?
    assert_nil @execution.paused_at
  end
  
  test "should complete journey" do
    @execution.start!
    @execution.complete!
    
    assert @execution.completed?
    assert_not_nil @execution.completed_at
    assert_nil @execution.paused_at
  end
  
  test "should fail journey" do
    @execution.start!
    @execution.fail!
    
    assert @execution.failed?
    assert_not_nil @execution.get_context('failure_time')
  end
  
  test "should reset execution state" do
    @execution.update!(current_step: @step1)
    @execution.start!
    @execution.complete!
    @execution.add_context('test', 'value')
    
    @execution.reset!
    
    assert @execution.initialized?
    assert_nil @execution.current_step
    assert_nil @execution.started_at
    assert_nil @execution.completed_at
    assert_equal({}, @execution.execution_context)
  end
  
  test "should find next step for entry point" do
    next_step = @execution.next_step
    assert_equal @step1, next_step
  end
  
  test "should find sequential next step" do
    @execution.update!(current_step: @step1)
    next_step = @execution.next_step
    assert_equal @step2, next_step
  end
  
  test "should advance to next step" do
    @execution.update!(current_step: @step1, status: "running")
    
    @execution.advance_to_next_step!
    
    assert_equal @step2, @execution.current_step
    assert @execution.step_executions.where(journey_step: @step2).exists?
  end
  
  test "should complete when reaching exit point" do
    @execution.update!(current_step: @step2, status: "running")
    
    @execution.advance_to_next_step!
    
    assert_equal @step3, @execution.current_step
    assert @execution.completed?
  end
  
  test "should calculate progress percentage" do
    assert_equal 0, @execution.progress_percentage
    
    @execution.update!(current_step: @step2)
    progress = @execution.progress_percentage
    expected = (1.0 / 3 * 100).round(1)
    assert_equal expected, progress
    
    @execution.start!
    @execution.complete!
    assert_equal 100, @execution.progress_percentage
  end
  
  test "should track elapsed time" do
    assert_equal 0, @execution.elapsed_time
    
    start_time = 1.hour.ago
    @execution.update!(started_at: start_time)
    
    elapsed = @execution.elapsed_time
    assert elapsed > 3500 # More than ~1 hour in seconds
    assert elapsed < 3700 # Less than ~1 hour + 2 minutes
  end
  
  test "should manage execution context" do
    @execution.add_context('user_score', 85)
    @execution.add_context('completed_actions', ['clicked_email'])
    
    assert_equal 85, @execution.get_context('user_score')
    assert_equal ['clicked_email'], @execution.get_context('completed_actions')
  end
  
  test "should have proper scopes" do
    completed = JourneyExecution.create!(
      journey: @journey,
      user: User.create!(email_address: "completed@test.com", password: "password"),
      status: "completed"
    )
    
    failed = JourneyExecution.create!(
      journey: @journey,
      user: User.create!(email_address: "failed@test.com", password: "password"),
      status: "failed"
    )
    
    assert_includes JourneyExecution.active, @execution
    assert_not_includes JourneyExecution.active, completed
    assert_not_includes JourneyExecution.active, failed
    
    assert_includes JourneyExecution.completed, completed
    assert_includes JourneyExecution.failed, failed
  end
  
  test "should handle conditional transitions" do
    # Create a conditional transition
    @step1.add_transition_to(@step3, { "min_engagement_score" => 80 })
    
    @execution.update!(current_step: @step1)
    @execution.add_context('engagement_score', 85)
    
    next_step = @execution.next_step
    assert_equal @step3, next_step # Should skip step2 due to high engagement
  end
end