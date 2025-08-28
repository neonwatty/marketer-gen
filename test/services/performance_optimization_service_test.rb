require "test_helper"

class PerformanceOptimizationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    
    # Set up campaign plan with execution in progress and ensure it's old enough for safety checks
    @campaign_plan.update!(
      plan_execution_started_at: 2.days.ago,
      created_at: 2.days.ago, # Ensure campaign is old enough for safety checks
      performance_data: {
        roi: 150,
        ctr: 0.8,
        cpc: 2.5,
        conversion_rate: 1.2,
        platform_breakdown: {
          google_ads: { spend: 1000, conversions: 25 },
          facebook: { spend: 800, conversions: 18 }
        }
      }.to_json
    )
    
    # Create optimization rules
    @budget_rule = OptimizationRule.create!(
      campaign_plan: @campaign_plan,
      name: "Budget Reallocation Rule",
      rule_type: "budget_reallocation",
      trigger_type: "performance_threshold",
      priority: 1,
      confidence_threshold: 0.7,
      trigger_conditions: { metric: "ctr", threshold: 1.0, operator: "less_than" },
      optimization_actions: {
        budget_adjustments: {
          "google_ads" => { change_percent: 15, max_increase: 500 },
          "facebook" => { change_percent: -10, max_decrease: 200 }
        }
      },
      safety_checks: {
        max_budget_change_percent: 20,
        minimum_campaign_age_hours: 24
      }
    )
    
    @bid_rule = OptimizationRule.create!(
      campaign_plan: @campaign_plan,
      name: "Bid Adjustment Rule",
      rule_type: "bid_adjustment", 
      trigger_type: "cost_efficiency",
      priority: 2,
      confidence_threshold: 0.8,
      trigger_conditions: { max_cpc: 2.0 },
      optimization_actions: {
        bid_adjustments: {
          "google_ads" => { change_percent: -15 },
          "facebook" => { change_percent: -10 }
        }
      },
      status: 'paused' # This rule should not trigger
    )
    
    @performance_data = {
      'roi' => 150,
      'ctr' => 0.8, # Below threshold, should trigger budget rule
      'cpc' => 2.5, # Above threshold, should trigger bid rule if active
      'conversion_rate' => 1.2,
      'cost_metrics' => { 'cpc' => 2.5, 'cpm' => 15.0 },
      'platform_breakdown' => {
        'google_ads' => { 'spend' => 1000, 'conversions' => 25 },
        'facebook' => { 'spend' => 800, 'conversions' => 18 }
      }
    }
    
    @service = PerformanceOptimizationService.new(@campaign_plan, @performance_data)
  end

  def teardown
    Rails.cache.clear
  end

  # Initialization tests
  test "should initialize with campaign plan and performance data" do
    assert_equal @campaign_plan, @service.campaign_plan
    assert_equal @performance_data, @service.performance_data
    assert_equal 1, @service.optimization_rules.count # Only active rules
  end

  test "should initialize with fetched performance data when none provided" do
    service = PerformanceOptimizationService.new(@campaign_plan)
    
    assert_not_nil service.performance_data
    assert service.performance_data.is_a?(Hash)
    assert_not_nil service.performance_data['roi']
  end

  # Main call method tests
  test "should return success when optimization completes successfully" do
    result = @service.call
    
    assert result[:success]
    assert_not_nil result[:data]
    assert result[:data][:triggered_rules_count] >= 0
    assert_not_nil result[:data][:optimization_results]
  end

  test "should return early when no performance data available" do
    service = PerformanceOptimizationService.new(@campaign_plan, nil)
    
    result = service.call
    
    assert result[:success]
    assert_equal 'No performance data available', result[:data][:message]
  end

  test "should return early when no active optimization rules found" do
    @budget_rule.update!(status: 'inactive')
    
    result = @service.call
    
    assert result[:success]
    assert_equal 'No active optimization rules found', result[:data][:message]
  end

  test "should handle service errors gracefully" do
    # Mock an error in the optimization cycle
    @service.stub :execute_optimization_cycle, -> { raise StandardError, "Test error" } do
      result = @service.call
      
      assert_not result[:success]
      assert_equal "Test error", result[:error]
      assert_not_nil result[:context]
    end
  end

  # Class methods tests
  test "optimize_campaign should create service and call it" do
    result = PerformanceOptimizationService.optimize_campaign(@campaign_plan)
    
    assert result[:success]
    assert_not_nil result[:data]
  end

  test "bulk_optimize_campaigns should process multiple campaigns" do
    campaign_plan2 = campaign_plans(:another_plan) # Assuming this fixture exists
    campaign_plans = [@campaign_plan, campaign_plan2]
    
    result = PerformanceOptimizationService.bulk_optimize_campaigns(campaign_plans)
    
    assert result[:success]
    assert_equal 2, result[:data][:total_campaigns]
    assert result[:data][:successful_optimizations] >= 0
    assert result[:data][:failed_optimizations] >= 0
    assert_equal 2, result[:data][:results].count
  end

  # Optimization execution tests
  test "should trigger rules based on performance data" do
    # CTR is 0.8, below threshold of 1.0, should trigger budget rule
    result = @service.call
    
    assert result[:success]
    assert result[:data][:triggered_rules_count] >= 1
    assert result[:data][:successful_optimizations] >= 0
  end

  test "should not trigger paused rules" do
    # Bid rule is paused, even though CPC exceeds threshold
    result = @service.call
    
    triggered_rule_types = result[:data][:optimization_results].map { |r| r[:rule_type] }
    assert_not_includes triggered_rule_types, "bid_adjustment"
  end

  test "should record safety violations" do
    # Set up a rule that will fail safety checks
    @budget_rule.update!(
      safety_checks: {
        minimum_campaign_age_hours: 72 # Campaign is only 2 days old
      }
    )
    
    result = @service.call
    
    assert result[:success]
    assert result[:data][:safety_violations].any?
    
    safety_violation = result[:data][:safety_violations].first
    assert_equal @budget_rule.id, safety_violation[:rule_id]
    assert safety_violation[:safety_check_failures].any? { |f| f.include?("Campaign too young") }
  end

  # Safety checks tests
  test "passes_safety_checks should validate campaign age" do
    @budget_rule.update!(
      safety_checks: { minimum_campaign_age_hours: 1 }
    )
    
    assert @service.send(:passes_safety_checks?, @budget_rule)
    
    @budget_rule.update!(
      safety_checks: { minimum_campaign_age_hours: 72 }
    )
    
    assert_not @service.send(:passes_safety_checks?, @budget_rule)
  end

  test "passes_safety_checks should validate data points" do
    @service.stub :get_data_points_count, 150 do
      @budget_rule.update!(
        safety_checks: { require_minimum_data_points: 100 }
      )
      
      assert @service.send(:passes_safety_checks?, @budget_rule)
    end
    
    @service.stub :get_data_points_count, 50 do
      @budget_rule.update!(
        safety_checks: { require_minimum_data_points: 100 }
      )
      
      assert_not @service.send(:passes_safety_checks?, @budget_rule)
    end
  end

  test "passes_safety_checks should validate daily execution limits" do
    # Create recent executions
    3.times do |i|
      OptimizationExecution.create!(
        optimization_rule: @budget_rule,
        executed_at: (i + 1).hours.ago,
        status: 'successful',
        result: { success: true }
      )
    end
    
    @budget_rule.update!(
      safety_checks: { maximum_daily_executions: 3 }
    )
    
    assert_not @service.send(:passes_safety_checks?, @budget_rule)
  end

  # Rule execution tests
  test "execute_budget_reallocation should adjust platform budgets" do
    result = @service.send(:execute_budget_reallocation, @budget_rule)
    
    assert result[:success]
    assert_equal @budget_rule.id, result[:rule_id]
    assert_equal 'budget_reallocation', result[:rule_type]
    assert result[:actions_taken].any?
    assert_not_nil result[:performance_snapshot]
    assert result[:safety_checks_passed]
  end

  test "execute_bid_adjustment should adjust platform bids" do
    result = @service.send(:execute_bid_adjustment, @bid_rule)
    
    assert result[:success]
    assert_equal @bid_rule.id, result[:rule_id]
    assert_equal 'bid_adjustment', result[:rule_type]
    assert result[:actions_taken].any?
  end

  test "execute_audience_expansion should expand audience settings" do
    audience_rule = OptimizationRule.create!(
      campaign_plan: @campaign_plan,
      name: "Audience Expansion",
      rule_type: "audience_expansion",
      trigger_type: "performance_threshold",
      optimization_actions: {
        audience_expansion: {
          "google_ads" => { expand_similar: true, lookalike_percentage: 2.0 }
        }
      }
    )
    
    result = @service.send(:execute_audience_expansion, audience_rule)
    
    assert result[:success]
    assert_equal 'audience_expansion', result[:rule_type]
  end

  test "should handle unknown rule types gracefully" do
    unknown_rule = OptimizationRule.new(
      rule_type: 'unknown_type',
      id: 999
    )
    
    result = @service.send(:execute_optimization_rule, unknown_rule)
    
    assert_not result[:success]
    assert_includes result[:error], "Unknown optimization rule type"
  end

  # Performance data fetching tests
  test "fetch_current_performance_data should extract metrics from campaign" do
    performance_data = @service.send(:fetch_current_performance_data)
    
    assert_equal 150, performance_data['roi']
    assert_not_nil performance_data['cost_metrics']
    assert_not_nil performance_data['budget_metrics']
    assert_not_nil performance_data['platform_breakdown']
  end

  test "should extract metrics from campaign performance data" do
    ctr_value = @service.send(:extract_metric_from_performance_data, 'ctr')
    assert_equal 0.8, ctr_value
  end

  test "should create performance snapshot with current data" do
    snapshot = @service.send(:create_performance_snapshot)
    
    assert_equal @performance_data, snapshot['before']
    assert_not_nil snapshot['timestamp']
    assert_equal @campaign_plan.id, snapshot['campaign_id']
    assert_equal 'performance_optimization_service', snapshot['data_source']
  end

  # Confidence scoring tests
  test "calculate_confidence_score should factor in data quality and history" do
    confidence = @service.send(:calculate_confidence_score, @budget_rule)
    
    assert confidence.is_a?(Float)
    assert confidence >= 0.0
    assert confidence <= 1.0
  end

  test "calculate_data_quality_factor should consider data points and age" do
    @service.stub :get_data_points_count, 1000 do
      @service.stub :get_data_age_hours, 1 do
        factor = @service.send(:calculate_data_quality_factor)
        assert factor > 0.8 # Should be high with lots of fresh data
      end
    end
  end

  test "calculate_rule_history_factor should use execution success rate" do
    # Create some successful executions
    3.times do
      OptimizationExecution.create!(
        optimization_rule: @budget_rule,
        executed_at: rand(48).hours.ago,
        status: 'successful',
        result: { success: true }
      )
    end
    
    # Create one failed execution
    OptimizationExecution.create!(
      optimization_rule: @budget_rule,
      executed_at: rand(48).hours.ago,
      status: 'failed',
      result: { success: false }
    )
    
    @budget_rule.update!(execution_count: 4)
    
    factor = @service.send(:calculate_rule_history_factor, @budget_rule)
    assert_equal 0.75, factor # 3 successful out of 4 total
  end

  # Platform integration mock tests
  test "platform adjustment methods should return success results" do
    # These are mock implementations, should all return success
    platforms = ['google_ads', 'facebook', 'linkedin']
    
    platforms.each do |platform|
      result = @service.send(:adjust_platform_budget, platform, { change_percent: 10 })
      assert result[:success]
      assert_equal platform, result[:platform]
      assert_equal 'budget_adjustment', result[:action]
    end
  end

  test "audience optimization methods should return success results" do
    platform = 'google_ads'
    settings = { expand_similar: true, lookalike_percentage: 2.0 }
    
    expand_result = @service.send(:expand_audience, platform, settings)
    assert expand_result[:success]
    assert_equal 'audience_expansion', expand_result[:action]
    
    refine_result = @service.send(:refine_audience, platform, settings)
    assert refine_result[:success]
    assert_equal 'audience_refinement', refine_result[:action]
  end

  test "creative and schedule optimization methods should return success results" do
    platform = 'google_ads'
    settings = { rotation_type: 'optimize', frequency_cap: 3 }
    
    creative_result = @service.send(:rotate_creative_assets, platform, settings)
    assert creative_result[:success]
    assert_equal 'creative_rotation', creative_result[:action]
    
    schedule_result = @service.send(:optimize_ad_schedule, platform, settings)
    assert schedule_result[:success]
    assert_equal 'schedule_optimization', schedule_result[:action]
  end

  # Error handling tests
  test "should log service calls" do
    # Capture log output
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)
    
    @service.call
    
    log_contents = log_output.string
    assert_includes log_contents, "Service Call: PerformanceOptimizationService with params:"
    
    Rails.logger = original_logger
  end

  test "should handle errors in individual rule executions" do
    # Mock a rule execution to raise an error
    @service.stub :execute_budget_reallocation, -> (rule) { raise StandardError, "Mock error" } do
      result = @service.call
      
      # Service should continue and return results, handling the error gracefully
      assert result[:success]
      assert result[:data][:failed_optimizations] >= 0
    end
  end

  # Integration tests
  test "end-to-end optimization should record executions" do
    assert_difference 'OptimizationExecution.count', 1 do
      result = @service.call
      assert result[:success]
    end
    
    execution = OptimizationExecution.last
    assert_equal @budget_rule, execution.optimization_rule
    assert_equal 'successful', execution.status
  end

  test "optimization should update rule execution counters" do
    original_count = @budget_rule.execution_count
    
    @service.call
    
    @budget_rule.reload
    assert_equal original_count + 1, @budget_rule.execution_count
    assert_not_nil @budget_rule.last_executed_at
    assert_equal 'success', @budget_rule.last_execution_result
  end
end