require "test_helper"

class OptimizationRuleTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    
    # Set up campaign plan for execution
    @campaign_plan.update!(plan_execution_started_at: 2.days.ago)
    @optimization_rule = OptimizationRule.new(
      campaign_plan: @campaign_plan,
      name: "Test Budget Optimization",
      rule_type: "budget_reallocation",
      trigger_type: "performance_threshold",
      priority: 5,
      confidence_threshold: 0.7,
      trigger_conditions: { metric: "ctr", threshold: 1.0, operator: "less_than" },
      optimization_actions: { 
        budget_adjustments: { 
          "google_ads" => { change_percent: 20, max_increase: 1000 } 
        } 
      },
      safety_checks: {
        max_budget_change_percent: 25,
        minimum_campaign_age_hours: 24
      }
    )
  end

  test "should be valid with valid attributes" do
    assert @optimization_rule.valid?
  end

  test "should require campaign_plan" do
    @optimization_rule.campaign_plan = nil
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:campaign_plan], "must exist"
  end

  test "should require name" do
    @optimization_rule.name = nil
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:name], "can't be blank"
  end

  test "should require rule_type" do
    @optimization_rule.rule_type = nil
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:rule_type], "can't be blank"
  end

  test "should validate rule_type inclusion" do
    @optimization_rule.rule_type = "invalid_type"
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:rule_type], "is not included in the list"
  end

  test "should require trigger_type" do
    @optimization_rule.trigger_type = nil
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:trigger_type], "can't be blank"
  end

  test "should validate trigger_type inclusion" do
    @optimization_rule.trigger_type = "invalid_trigger"
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:trigger_type], "is not included in the list"
  end

  test "should validate priority range" do
    @optimization_rule.priority = 0
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:priority], "must be greater than or equal to 1"

    @optimization_rule.priority = 11
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:priority], "must be less than or equal to 10"

    @optimization_rule.priority = 5
    assert @optimization_rule.valid?
  end

  test "should validate confidence_threshold range" do
    @optimization_rule.confidence_threshold = -0.1
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:confidence_threshold], "must be greater than or equal to 0.0"

    @optimization_rule.confidence_threshold = 1.1
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:confidence_threshold], "must be less than or equal to 1.0"

    @optimization_rule.confidence_threshold = 0.8
    assert @optimization_rule.valid?
  end

  test "should validate JSON fields" do
    @optimization_rule.trigger_conditions = "invalid json"
    assert_not @optimization_rule.valid?
    assert_includes @optimization_rule.errors[:trigger_conditions], "Trigger conditions must be valid JSON"
  end

  test "should set default values on create" do
    rule = OptimizationRule.new(
      campaign_plan: @campaign_plan,
      name: "Test Rule",
      rule_type: "budget_reallocation",
      trigger_type: "performance_threshold"
    )
    
    rule.validate
    
    assert_equal 'active', rule.status
    assert_equal 5, rule.priority
    assert_equal 0.7, rule.confidence_threshold
    assert_equal 0, rule.execution_count
    assert_not_nil rule.safety_checks
  end

  test "should have default safety checks" do
    rule = OptimizationRule.create!(
      campaign_plan: @campaign_plan,
      name: "Test Rule",
      rule_type: "budget_reallocation",
      trigger_type: "performance_threshold"
    )
    
    safety_checks = rule.parsed_safety_checks
    assert_equal 20, safety_checks['max_budget_change_percent']
    assert_equal 50, safety_checks['max_bid_change_percent']
    assert_equal 100, safety_checks['require_minimum_data_points']
    assert_equal 24, safety_checks['minimum_campaign_age_hours']
    assert_equal 3, safety_checks['maximum_daily_executions']
  end

  # Status methods tests
  test "should have status query methods" do
    assert @optimization_rule.active?
    assert_not @optimization_rule.inactive?
    assert_not @optimization_rule.paused?
    assert_not @optimization_rule.testing?

    @optimization_rule.status = 'paused'
    assert_not @optimization_rule.active?
    assert @optimization_rule.paused?
  end

  # Execution eligibility tests
  test "can_be_executed should return false for inactive rules" do
    @optimization_rule.status = 'inactive'
    @optimization_rule.save!
    
    assert_not @optimization_rule.can_be_executed?
  end

  test "can_be_executed should check cooldown period" do
    @optimization_rule.save!
    @optimization_rule.update!(last_executed_at: 25.hours.ago)
    
    assert_not @optimization_rule.execution_in_cooldown?
    assert @optimization_rule.can_be_executed?

    @optimization_rule.update!(last_executed_at: 1.hour.ago)
    assert @optimization_rule.execution_in_cooldown?
    assert_not @optimization_rule.can_be_executed?
  end

  # Trigger condition tests
  test "should_trigger should work for performance_threshold trigger" do
    @optimization_rule.save!
    
    performance_data = { 'ctr' => 0.5 }
    assert @optimization_rule.should_trigger?(performance_data)
    
    performance_data = { 'ctr' => 1.5 }
    assert_not @optimization_rule.should_trigger?(performance_data)
  end

  test "should_trigger should work for cost_efficiency trigger" do
    @optimization_rule.trigger_type = 'cost_efficiency'
    @optimization_rule.trigger_conditions = { 
      max_cpc: 2.0, 
      max_cpm: 10.0 
    }
    @optimization_rule.save!
    
    performance_data = {
      'cost_metrics' => { 'cpc' => 3.0, 'cpm' => 12.0 }
    }
    assert @optimization_rule.should_trigger?(performance_data)
    
    performance_data = {
      'cost_metrics' => { 'cpc' => 1.0, 'cpm' => 5.0 }
    }
    assert_not @optimization_rule.should_trigger?(performance_data)
  end

  test "should_trigger should work for conversion_rate trigger" do
    @optimization_rule.trigger_type = 'conversion_rate'
    @optimization_rule.trigger_conditions = { min_conversion_rate: 2.0 }
    @optimization_rule.save!
    
    performance_data = { 'conversion_rate' => 1.5 }
    assert @optimization_rule.should_trigger?(performance_data)
    
    performance_data = { 'conversion_rate' => 3.0 }
    assert_not @optimization_rule.should_trigger?(performance_data)
  end

  test "should_trigger should work for schedule_based trigger" do
    @optimization_rule.trigger_type = 'schedule_based'
    
    # Test daily schedule
    current_hour = Time.current.hour
    @optimization_rule.trigger_conditions = { 
      schedule_type: 'daily', 
      execution_hour: current_hour 
    }
    @optimization_rule.save!
    
    assert @optimization_rule.should_trigger?({})
    
    # Test different hour
    @optimization_rule.trigger_conditions = { 
      schedule_type: 'daily', 
      execution_hour: (current_hour + 1) % 24 
    }
    @optimization_rule.save!
    
    assert_not @optimization_rule.should_trigger?({})
  end

  # Execution recording tests
  test "record_execution should create optimization_execution and update counters" do
    @optimization_rule.save!
    
    result = {
      success: true,
      actions_taken: [{ platform: 'google_ads', action: 'budget_increase' }],
      performance_snapshot: { before: { ctr: 0.5 }, after: { ctr: 1.2 } },
      trigger_reason: 'CTR below threshold',
      confidence_score: 0.85,
      safety_checks_passed: true
    }
    
    assert_difference 'OptimizationExecution.count', 1 do
      @optimization_rule.record_execution!(result)
    end
    
    @optimization_rule.reload
    assert_equal 1, @optimization_rule.execution_count
    assert_equal 'success', @optimization_rule.last_execution_result
    assert_not_nil @optimization_rule.last_executed_at
  end

  # Control methods tests
  test "pause! should update status and timestamp" do
    @optimization_rule.save!
    
    @optimization_rule.pause!
    
    assert_equal 'paused', @optimization_rule.status
    assert_not_nil @optimization_rule.paused_at
  end

  test "resume! should reactivate rule" do
    @optimization_rule.status = 'paused'
    @optimization_rule.paused_at = Time.current
    @optimization_rule.save!
    
    @optimization_rule.resume!
    
    assert_equal 'active', @optimization_rule.status
    assert_nil @optimization_rule.paused_at
  end

  test "deactivate! should set status to inactive" do
    @optimization_rule.save!
    
    @optimization_rule.deactivate!
    
    assert_equal 'inactive', @optimization_rule.status
    assert_not_nil @optimization_rule.deactivated_at
  end

  # Scopes tests
  test "scopes should work correctly" do
    @optimization_rule.save!
    
    active_rules = OptimizationRule.active
    assert_includes active_rules, @optimization_rule
    
    by_priority = OptimizationRule.by_priority
    assert_equal @optimization_rule, by_priority.first
    
    budget_rules = OptimizationRule.by_rule_type('budget_reallocation')
    assert_includes budget_rules, @optimization_rule
    
    threshold_rules = OptimizationRule.by_trigger_type('performance_threshold')
    assert_includes threshold_rules, @optimization_rule
    
    high_confidence = OptimizationRule.high_confidence
    assert_not_includes high_confidence, @optimization_rule # 0.7 < 0.8
    
    @optimization_rule.update!(confidence_threshold: 0.9)
    high_confidence = OptimizationRule.high_confidence
    assert_includes high_confidence, @optimization_rule
  end

  # JSON parsing tests
  test "should parse JSON fields correctly" do
    @optimization_rule.save!
    
    conditions = @optimization_rule.parsed_trigger_conditions
    assert_equal 'ctr', conditions['metric']
    assert_equal 1.0, conditions['threshold']
    assert_equal 'less_than', conditions['operator']
    
    actions = @optimization_rule.parsed_optimization_actions
    assert_not_nil actions['budget_adjustments']
    assert_not_nil actions['budget_adjustments']['google_ads']
    
    safety_checks = @optimization_rule.parsed_safety_checks
    assert_equal 25, safety_checks['max_budget_change_percent']
  end

  test "should handle invalid JSON gracefully" do
    @optimization_rule.save!
    
    # Directly update the database to simulate corrupted JSON
    @optimization_rule.update_column(:trigger_conditions, 'invalid json')
    
    conditions = @optimization_rule.parsed_trigger_conditions
    assert_equal({}, conditions)
  end

  # Association tests
  test "should belong to campaign_plan" do
    @optimization_rule.save!
    assert_equal @campaign_plan, @optimization_rule.campaign_plan
  end

  test "should have many optimization_executions" do
    @optimization_rule.save!
    
    execution = OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: Time.current,
      status: 'successful',
      result: { success: true }
    )
    
    assert_includes @optimization_rule.optimization_executions, execution
  end

  test "should destroy dependent optimization_executions" do
    @optimization_rule.save!
    
    execution = OptimizationExecution.create!(
      optimization_rule: @optimization_rule,
      executed_at: Time.current,
      status: 'successful',
      result: { success: true }
    )
    
    assert_difference 'OptimizationExecution.count', -1 do
      @optimization_rule.destroy!
    end
  end
end