require "test_helper"

class JourneyFlowEngineTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(
        email_address: "flow_engine_test@example.com",
        password: "password123",
        role: "marketer"
      )
      
      @journey = Journey.create!(
        user: @user,
        name: "Test Flow Journey",
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
        name: "Educational Content",
        stage: "consideration",
        position: 1,
        conditions: { "min_engagement_score" => 5 }
      )
      
      @step3 = JourneyStep.create!(
        journey: @journey,
        name: "Special Offer",
        stage: "conversion",
        position: 2,
        is_exit_point: true
      )
      
      # Create conditional transitions with proper priorities (lower number = higher priority)
      transition_to_step3 = @step1.add_transition_to(@step3, { "engagement_threshold" => 80 })
      transition_to_step3.update!(priority: 0) # Highest priority for high engagement
      
      transition_to_step2 = @step1.add_transition_to(@step2, { "engagement_threshold" => 40 })
      transition_to_step2.update!(priority: 1) # Lower priority
      
      @step2.add_transition_to(@step3)
    end
    
    test "should start journey and create execution" do
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      
      assert execution.persisted?
      assert_equal @journey, execution.journey
      assert_equal @user, execution.user
      assert execution.running?
      assert_equal @step1, execution.current_step
    end
    
    test "should not start if journey is not published" do
      @journey.update!(status: "draft")
      
      assert_raises(RuntimeError) do
        JourneyFlowEngine.start_journey(@journey, @user)
      end
    end
    
    test "should find or create existing execution" do
      existing = JourneyFlowEngine.find_or_create_execution(@journey, @user)
      duplicate = JourneyFlowEngine.find_or_create_execution(@journey, @user)
      
      assert_equal existing.id, duplicate.id
    end
    
    test "should advance through sequential steps" do
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      engine = JourneyFlowEngine.new(execution)
      
      # Should be at step1
      assert_equal @step1, execution.current_step
      
      # Advance to step2 (low engagement score)
      execution.add_context('engagement_score', 50)
      result = engine.advance!
      
      assert result
      assert_equal @step2, execution.current_step
      assert execution.running?
      
      # Advance to step3 (exit point)
      result = engine.advance!
      
      assert result
      assert_equal @step3, execution.current_step
      assert execution.completed?
    end
    
    test "should handle conditional branching" do
      execution = JourneyFlowEngine.start_journey(@journey, @user, { "engagement_score" => 85 })
      engine = JourneyFlowEngine.new(execution)
      
      # Should be at step1
      assert_equal @step1, execution.current_step
      
      # Should skip to step3 due to high engagement
      result = engine.advance!
      
      assert result
      assert_equal @step3, execution.current_step
      assert execution.completed? # step3 is exit point
    end
    
    test "should pause and resume execution" do
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      engine = JourneyFlowEngine.new(execution)
      
      engine.pause!
      assert execution.paused?
      
      engine.resume!
      assert execution.running?
    end
    
    test "should fail execution with reason" do
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      engine = JourneyFlowEngine.new(execution)
      
      engine.fail!("Test failure reason")
      
      assert execution.failed?
      assert_equal "Test failure reason", execution.get_context('failure_reason')
    end
    
    test "should evaluate step conditions" do
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      engine = JourneyFlowEngine.new(execution)
      
      # Test with sufficient engagement score
      execution.add_context('engagement_score', 10)
      assert engine.evaluate_conditions(@step2)
      
      # Test with insufficient engagement score
      execution.add_context('engagement_score', 3)
      assert_not engine.evaluate_conditions(@step2)
    end
    
    test "should get available next steps" do
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      engine = JourneyFlowEngine.new(execution)
      
      # High engagement should show step3 as option
      execution.add_context('engagement_score', 85)
      available = engine.get_available_next_steps
      
      assert_equal 1, available.length
      assert_equal @step3, available.first[:step]
      assert_equal 'conditional', available.first[:transition_type]
      
      # Medium engagement should show step2 as option
      execution.add_context('engagement_score', 50)
      available = engine.get_available_next_steps
      
      assert_equal 1, available.length
      assert_equal @step2, available.first[:step]
    end
    
    test "should simulate journey flow" do
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      engine = JourneyFlowEngine.new(execution)
      
      # Simulate with high engagement
      simulation = engine.simulate_journey({ "engagement_score" => 85 })
      
      assert_equal 2, simulation.length
      assert_equal @step1, simulation[0][:step]
      assert_equal @step3, simulation[1][:step]
      
      # Simulate with medium engagement
      simulation = engine.simulate_journey({ "engagement_score" => 50 })
      
      assert_equal 3, simulation.length
      assert_equal @step1, simulation[0][:step]
      assert_equal @step2, simulation[1][:step]
      assert_equal @step3, simulation[2][:step]
    end
    
    test "should handle journey without entry points" do
      # Remove entry point flag
      @step1.update!(is_entry_point: false)
      
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      
      # Should still use first step by position
      assert_equal @step1, execution.current_step
    end
    
    test "should create step executions when advancing" do
      execution = JourneyFlowEngine.start_journey(@journey, @user)
      engine = JourneyFlowEngine.new(execution)
      
      # Should have initial step execution
      assert_equal 1, execution.step_executions.count
      initial_exec = execution.step_executions.first
      assert_equal @step1, initial_exec.journey_step
      
      # Advance and check new step execution
      execution.add_context('engagement_score', 50)
      engine.advance!
      
      assert_equal 2, execution.step_executions.count
      second_exec = execution.step_executions.last
      assert_equal @step2, second_exec.journey_step
    end
    
    test "should handle execution context in step executions" do
      execution = JourneyFlowEngine.start_journey(@journey, @user, { "user_type" => "premium" })
      engine = JourneyFlowEngine.new(execution)
      
      step_exec = execution.step_executions.first
      assert_equal "premium", step_exec.context["user_type"]
      
      # Add more context and advance
      execution.add_context('engagement_score', 50)
      engine.advance!
      
      step_exec2 = execution.step_executions.last
      assert_equal "premium", step_exec2.context["user_type"]
      assert_equal 50, step_exec2.context["engagement_score"]
    end
    
    test "should complete journey when no more steps available" do
      # Create a journey with only one step
      simple_journey = Journey.create!(
        user: @user,
        name: "Simple Journey",
        status: "published"
      )
      
      single_step = JourneyStep.create!(
        journey: simple_journey,
        name: "Only Step",
        stage: "awareness",
        position: 0,
        is_entry_point: true
      )
      
      execution = JourneyFlowEngine.start_journey(simple_journey, @user)
      engine = JourneyFlowEngine.new(execution)
      
      # Should complete when advancing from the only step
      result = engine.advance!
      
      assert_not result # No more steps to advance to
      assert execution.completed?
    end
  end