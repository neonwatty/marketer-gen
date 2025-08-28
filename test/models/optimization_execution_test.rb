require "test_helper"

class OptimizationExecutionTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    
    # Set up campaign plan for execution
    @campaign_plan.update!(plan_execution_started_at: 2.days.ago)
    @optimization_rule = OptimizationRule.create!(
      campaign_plan: @campaign_plan,
      name: "Test Budget Optimization",
      rule_type: "budget_reallocation",
      trigger_type: "performance_threshold",
      priority: 5,
      confidence_threshold: 0.7,
      trigger_conditions: { metric: "roi", threshold: 160.0, operator: "less_than" },
      optimization_actions: { 
        budget_adjustments: { 
          "google_ads" => { change_percent: 20, max_increase: 1000 } 
        } 
      }
    )
    
    @optimization_execution = OptimizationExecution.new(
      optimization_rule: @optimization_rule,
      executed_at: Time.current,
      result: {
        success: true,
        actions_taken: [
          { platform: 'google_ads', action: 'budget_increase', amount: 500 }
        ]
      },
      performance_data_snapshot: {
        before: { ctr: 0.5, cpc: 2.0, roi: 150 },
        after: { ctr: 1.2, cpc: 1.8, roi: 180 }
      },
      actions_taken: [
        { platform: 'google_ads', action: 'budget_increase', amount: 500 }
      ],
      metadata: {
        confidence_score: 0.85,
        trigger_reason: 'CTR below threshold'
      }
    )
  end

  test "should be valid with valid attributes" do
    assert @optimization_execution.valid?
  end

  test "should require optimization_rule" do
    @optimization_execution.optimization_rule = nil
    assert_not @optimization_execution.valid?
    assert_includes @optimization_execution.errors[:optimization_rule], "must exist"
  end

  test "should require executed_at" do
    @optimization_execution.executed_at = nil
    assert_not @optimization_execution.valid?
    assert_includes @optimization_execution.errors[:executed_at], "can't be blank"
  end

  test "should validate status inclusion when present" do
    # Create a new execution with invalid status after it's already created
    execution = OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: Time.current,
      result: { success: true }
    )
    execution.status = "invalid_status"
    
    assert_not execution.valid?
    assert_includes execution.errors[:status], "is not included in the list"
    
    execution.status = "successful"
    assert execution.valid?
  end

  test "should allow nil status" do
    @optimization_execution.status = nil
    assert @optimization_execution.valid?
  end

  test "should set status from result on create" do
    # Test successful result
    @optimization_execution.result = { success: true }
    @optimization_execution.save!
    assert_equal 'successful', @optimization_execution.status

    # Test failed result
    execution2 = OptimizationExecution.new(
      optimization_rule: @optimization_rule,
      executed_at: Time.current,
      result: { success: false, error: 'API error' }
    )
    execution2.save!
    assert_equal 'failed', execution2.status

    # Test partial success result
    execution3 = OptimizationExecution.new(
      optimization_rule: @optimization_rule,
      executed_at: Time.current,
      result: { partial: true, completed_actions: 2, failed_actions: 1 }
    )
    execution3.save!
    assert_equal 'partial_success', execution3.status
  end

  test "should handle string JSON result when setting status" do
    @optimization_execution.result = '{"success": true}'
    @optimization_execution.save!
    assert_equal 'successful', @optimization_execution.status
  end

  test "should set failed status for invalid JSON result" do
    @optimization_execution.result = 'invalid json'
    @optimization_execution.save!
    assert_equal 'failed', @optimization_execution.status
  end

  # Status query methods
  test "should have status query methods" do
    @optimization_execution.status = 'successful'
    assert @optimization_execution.successful?
    assert_not @optimization_execution.failed?
    assert_not @optimization_execution.rolled_back?

    @optimization_execution.status = 'failed'
    assert_not @optimization_execution.successful?
    assert @optimization_execution.failed?

    @optimization_execution.status = 'rolled_back'
    assert @optimization_execution.rolled_back?
  end

  # Execution summary tests
  test "execution_summary should return formatted summary" do
    @optimization_execution.save!
    
    summary = @optimization_execution.execution_summary
    
    assert_equal @optimization_execution.id, summary[:id]
    assert_equal @optimization_execution.executed_at, summary[:executed_at]
    assert_equal @optimization_execution.status, summary[:status]
    assert_equal @optimization_rule.rule_type, summary[:rule_type]
    assert_equal 1, summary[:actions_count]
    assert_not_nil summary[:performance_improvement]
    assert_equal 0.85, summary[:confidence_score]
  end

  # Performance improvement calculation tests
  test "performance_improvement should calculate improvement correctly" do
    @optimization_execution.save!
    
    # ROI improved from 150 to 180, should be 20% improvement
    improvement = @optimization_execution.performance_improvement
    assert_equal 20.0, improvement
  end

  test "performance_improvement should return 0 for failed executions" do
    @optimization_execution.result = { success: false, error: 'Test failure' }
    @optimization_execution.save!
    
    improvement = @optimization_execution.performance_improvement
    assert_equal 0, improvement
  end

  test "performance_improvement should return 0 when before value is zero" do
    @optimization_execution.performance_data_snapshot = {
      before: { roi: 0 },
      after: { roi: 100 }
    }
    @optimization_execution.save!
    
    improvement = @optimization_execution.performance_improvement
    assert_equal 0, improvement
  end

  test "performance_improvement should use trigger metric when available" do
    # Set up rule with ROI as trigger metric  
    @optimization_rule.update!(
      trigger_conditions: { metric: 'roi', threshold: 160.0 }
    )
    @optimization_execution.save!
    
    # ROI improved from 150 to 180, should be 20% improvement
    improvement = @optimization_execution.performance_improvement
    assert_equal 20.0, improvement
  end

  # Parsed actions taken tests
  test "parsed_actions_taken should parse JSON correctly" do
    @optimization_execution.save!
    
    actions = @optimization_execution.parsed_actions_taken
    assert_equal 1, actions.length
    assert_equal 'google_ads', actions.first['platform']
    assert_equal 'budget_increase', actions.first['action']
    assert_equal 500, actions.first['amount']
  end

  test "parsed_actions_taken should handle string JSON" do
    @optimization_execution.actions_taken = '[{"platform": "facebook", "action": "bid_decrease"}]'
    @optimization_execution.save!
    
    actions = @optimization_execution.parsed_actions_taken
    assert_equal 1, actions.length
    assert_equal 'facebook', actions.first['platform']
    assert_equal 'bid_decrease', actions.first['action']
  end

  test "parsed_actions_taken should handle invalid JSON gracefully" do
    @optimization_execution.actions_taken = 'invalid json'
    @optimization_execution.save!
    
    actions = @optimization_execution.parsed_actions_taken
    assert_equal [], actions
  end

  test "parsed_actions_taken should return empty array for nil actions" do
    @optimization_execution.actions_taken = nil
    @optimization_execution.save!
    
    actions = @optimization_execution.parsed_actions_taken
    assert_equal [], actions
  end

  # Rollback functionality tests
  test "rollback! should change status to rolled_back" do
    @optimization_execution.save!
    
    assert @optimization_execution.rollback!
    
    @optimization_execution.reload
    assert_equal 'rolled_back', @optimization_execution.status
    assert_not_nil @optimization_execution.rolled_back_at
    assert_equal 'manual_rollback', @optimization_execution.metadata['rolled_back_reason']
  end

  test "rollback! should return false if already rolled back" do
    @optimization_execution.save!
    @optimization_execution.rollback! # First rollback
    
    # Second rollback should return false
    assert_not @optimization_execution.rollback!
  end

  test "rollback! should set user id in metadata when Current.user is present" do
    @optimization_execution.save!
    
    # Mock Current.user
    Current.stub :user, @user do
      @optimization_execution.rollback!
    end
    
    @optimization_execution.reload
    assert_equal @user.id, @optimization_execution.metadata['rolled_back_by']
  end

  # Scopes tests
  test "successful scope should return only successful executions" do
    @optimization_execution.save!
    
    failed_execution = OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: Time.current,
      status: 'failed',
      result: { success: false }
    )
    
    successful_executions = OptimizationExecution.successful
    assert_includes successful_executions, @optimization_execution
    assert_not_includes successful_executions, failed_execution
  end

  test "failed scope should return only failed executions" do
    @optimization_execution.save!
    
    failed_execution = OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: Time.current,
      status: 'failed',
      result: { success: false }
    )
    
    failed_executions = OptimizationExecution.failed
    assert_not_includes failed_executions, @optimization_execution
    assert_includes failed_executions, failed_execution
  end

  test "recent scope should return executions from last 30 days" do
    @optimization_execution.save!
    
    old_execution = OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: 31.days.ago,
      status: 'successful',
      result: { success: true }
    )
    
    recent_executions = OptimizationExecution.recent
    assert_includes recent_executions, @optimization_execution
    assert_not_includes recent_executions, old_execution
  end

  test "by_rule scope should filter by optimization rule" do
    @optimization_execution.save!
    
    other_rule = OptimizationRule.create!(
      campaign_plan: @campaign_plan,
      name: "Other Rule",
      rule_type: "bid_adjustment",
      trigger_type: "cost_efficiency"
    )
    
    other_execution = OptimizationExecution.create!(
      optimization_rule: other_rule,
      executed_at: Time.current,
      status: 'successful',
      result: { success: true }
    )
    
    rule_executions = OptimizationExecution.by_rule(@optimization_rule.id)
    assert_includes rule_executions, @optimization_execution
    assert_not_includes rule_executions, other_execution
  end

  # Association tests
  test "should belong to optimization_rule" do
    @optimization_execution.save!
    assert_equal @optimization_rule, @optimization_execution.optimization_rule
  end

  test "should serialize JSON fields correctly" do
    @optimization_execution.save!
    
    # Test result serialization
    result = @optimization_execution.result
    assert result.is_a?(Hash)
    assert_equal true, result['success']
    
    # Test performance_data_snapshot serialization
    snapshot = @optimization_execution.performance_data_snapshot
    assert snapshot.is_a?(Hash)
    assert_not_nil snapshot['before']
    assert_not_nil snapshot['after']
    assert_equal 0.5, snapshot['before']['ctr']
    assert_equal 1.2, snapshot['after']['ctr']
    
    # Test actions_taken serialization
    actions = @optimization_execution.actions_taken
    assert actions.is_a?(Array)
    assert_equal 'google_ads', actions.first['platform']
    
    # Test metadata serialization
    metadata = @optimization_execution.metadata
    assert metadata.is_a?(Hash)
    assert_equal 0.85, metadata['confidence_score']
    assert_equal 'CTR below threshold', metadata['trigger_reason']
  end
end