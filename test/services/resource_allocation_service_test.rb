require 'test_helper'

class ResourceAllocationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @campaign_plan = campaign_plans(:one) if defined?(campaign_plans)
    
    @base_params = {
      action: 'optimize',
      total_budget: 10000.0,
      channels: %w[social_media search email],
      objectives: ['conversions'],
      time_period: {
        start: Date.current.to_s,
        end: (Date.current + 30.days).to_s
      }
    }
  end

  test 'should initialize service correctly' do
    service = ResourceAllocationService.new(
      user: @user,
      campaign_plan: @campaign_plan,
      allocation_params: @base_params
    )
    
    assert_equal @user, service.instance_variable_get(:@user)
    assert_equal @campaign_plan, service.instance_variable_get(:@campaign_plan)
    assert_equal @base_params, service.instance_variable_get(:@allocation_params)
  end

  test 'should optimize allocations successfully' do
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    result = service.call
    
    assert result[:success]
    assert_not_nil result[:data]
    assert_not_nil result[:data][:allocations]
    assert_not_nil result[:data][:predictions]
    assert_not_nil result[:data][:optimization_score]
    assert_not_nil result[:data][:recommendations]
  end

  test 'should return error for invalid budget' do
    invalid_params = @base_params.merge(total_budget: -1000)
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: invalid_params
    )
    
    result = service.call
    
    assert_not result[:success]
    assert_includes result[:error], "Invalid budget amount"
  end

  test 'should return error for unknown action' do
    invalid_params = @base_params.merge(action: 'unknown_action')
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: invalid_params
    )
    
    result = service.call
    
    assert_not result[:success]
    assert_includes result[:error], "Unknown action: unknown_action"
  end

  test 'should predict performance for existing allocations' do
    # Create test allocation
    allocation = BudgetAllocation.create!(
      user: @user,
      name: 'Test Allocation',
      total_budget: 5000.0,
      allocated_amount: 3000.0,
      channel_type: 'social_media',
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 30.days,
      optimization_objective: 'conversions',
      status: 'active'
    )
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: { action: 'predict' }
    )
    
    result = service.call
    
    assert result[:success]
    assert_not_nil result[:data][:predictions]
    assert_not_nil result[:data][:aggregate_forecast]
    
    # Check prediction structure
    prediction = result[:data][:predictions].first
    assert_equal allocation.id, prediction[:allocation_id]
    assert_not_nil prediction[:predicted_metrics]
    assert_not_nil prediction[:confidence_score]
    assert_not_nil prediction[:risk_assessment]
  end

  test 'should create new allocation successfully' do
    create_params = {
      action: 'create',
      name: 'New Test Allocation',
      total_budget: 8000.0,
      allocated_amount: 4000.0,
      channel_type: 'search',
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 30.days,
      optimization_objective: 'revenue',
      enable_predictive_modeling: true
    }
    
    service = ResourceAllocationService.new(
      user: @user,
      campaign_plan: @campaign_plan,
      allocation_params: create_params
    )
    
    result = service.call
    
    assert result[:success]
    assert_not_nil result[:data][:allocation]
    assert_not_nil result[:data][:optimization_suggestions]
    
    # Verify allocation was created
    allocation = result[:data][:allocation]
    assert_equal 'New Test Allocation', allocation.name
    assert_equal 8000.0, allocation.total_budget
    assert_equal 4000.0, allocation.allocated_amount
    assert_equal 'search', allocation.channel_type
    assert_not_nil allocation.predictive_model_data
  end

  test 'should handle allocation creation failure' do
    invalid_params = {
      action: 'create',
      name: '', # invalid - required field
      total_budget: -1000, # invalid - must be positive
      channel_type: 'invalid_channel' # invalid channel
    }
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: invalid_params
    )
    
    result = service.call
    
    assert_not result[:success]
    assert_includes result[:error], "Allocation creation failed"
  end

  test 'should rebalance budget based on performance' do
    # Create test allocations with different performance
    allocation1 = BudgetAllocation.create!(
      user: @user,
      name: 'High Performer',
      total_budget: 5000.0,
      allocated_amount: 3000.0,
      channel_type: 'search',
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 30.days,
      optimization_objective: 'conversions',
      status: 'active',
      performance_metrics: {
        spent_to_date: 1000.0,
        burn_rate: 100.0,
        current_metrics: { efficiency: 85 }
      }
    )
    
    allocation2 = BudgetAllocation.create!(
      user: @user,
      name: 'Low Performer',
      total_budget: 5000.0,
      allocated_amount: 3000.0,
      channel_type: 'display',
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 30.days,
      optimization_objective: 'conversions',
      status: 'active',
      performance_metrics: {
        spent_to_date: 1500.0,
        burn_rate: 200.0,
        current_metrics: { efficiency: 45 }
      }
    )
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: { action: 'rebalance' }
    )
    
    result = service.call
    
    assert result[:success]
    assert_not_nil result[:data][:rebalanced_allocations]
    assert_not_nil result[:data][:rebalancing_rationale]
    
    # Check that rebalanced allocations are returned
    rebalanced = result[:data][:rebalanced_allocations]
    assert_equal 2, rebalanced.length
  end

  test 'should calculate optimal distribution correctly' do
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    allocations = service.send(
      :calculate_optimal_distribution,
      10000.0,
      %w[social_media search email],
      ['conversions'],
      { start: Date.current.to_s, end: (Date.current + 30.days).to_s }
    )
    
    assert_equal 3, allocations.length
    
    # Verify each allocation has required fields
    allocations.each do |allocation|
      assert_not_nil allocation[:channel_type]
      assert_not_nil allocation[:allocated_amount]
      assert_not_nil allocation[:optimization_factors]
      assert allocation[:allocated_amount] > 0
    end
    
    # Verify total equals budget (allowing for rounding)
    total_allocated = allocations.sum { |a| a[:allocated_amount] }
    assert_in_delta 10000.0, total_allocated, 100.0
  end

  test 'should apply correct channel weights' do
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    # Test known channel weights
    assert_equal 1.0, service.send(:get_channel_base_weight, 'social_media')
    assert_equal 1.2, service.send(:get_channel_base_weight, 'search')
    assert_equal 0.8, service.send(:get_channel_base_weight, 'email')
    assert_equal 0.9, service.send(:get_channel_base_weight, 'display')
    assert_equal 1.1, service.send(:get_channel_base_weight, 'video')
    assert_equal 1.0, service.send(:get_channel_base_weight, 'content_marketing')
    assert_equal 1.0, service.send(:get_channel_base_weight, 'unknown_channel')
  end

  test 'should calculate objective multipliers correctly' do
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    # Test awareness objective with social media (should be 1.3)
    multiplier = service.send(:calculate_objective_multiplier, 'social_media', ['awareness'])
    assert_equal 1.3, multiplier
    
    # Test conversions objective with search (should be 1.4)
    multiplier = service.send(:calculate_objective_multiplier, 'search', ['conversions'])
    assert_equal 1.4, multiplier
    
    # Test multiple objectives (should average the multipliers)
    multiplier = service.send(:calculate_objective_multiplier, 'social_media', ['awareness', 'engagement'])
    expected = (1.3 + 1.4) / 2.0 # awareness: 1.3, engagement: 1.4 for social_media
    assert_equal expected, multiplier
  end

  test 'should calculate predicted metrics correctly' do
    allocation = BudgetAllocation.new(
      allocated_amount: 2000.0,
      channel_type: 'social_media',
      time_period_start: Date.current,
      time_period_end: Date.current + 20.days
    )
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    metrics = service.send(:calculate_predicted_metrics, allocation)
    
    assert_not_nil metrics[:estimated_impressions]
    assert_not_nil metrics[:estimated_clicks]
    assert_not_nil metrics[:estimated_conversions]
    assert_not_nil metrics[:estimated_revenue]
    assert_not_nil metrics[:daily_budget]
    
    # Verify daily budget calculation
    assert_equal 100.0, metrics[:daily_budget] # 2000 / 20 days
  end

  test 'should assess risk factors correctly' do
    # High risk allocation
    high_risk_allocation = BudgetAllocation.new(
      user: @user,
      allocated_amount: 8000.0,
      total_budget: 10000.0, # 80% allocation
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 5.days, # short duration
      channel_type: 'video'
    )
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    risk_assessment = service.send(:assess_risk_factors, high_risk_allocation)
    
    assert_not_nil risk_assessment[:risk_level]
    assert_not_nil risk_assessment[:risk_factors]
    assert_not_nil risk_assessment[:mitigation_suggestions]
    
    # Should identify high budget concentration and short duration
    assert_includes risk_assessment[:risk_factors], 'high_budget_concentration'
    assert_includes risk_assessment[:risk_factors], 'short_duration'
  end

  test 'should calculate confidence score correctly' do
    # High confidence allocation
    high_confidence_allocation = BudgetAllocation.new(
      user: @user,
      allocated_amount: 5000.0, # good budget size
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 45.days, # long duration
      channel_type: 'search'
    )
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    confidence_score = service.send(:calculate_confidence_score, high_confidence_allocation)
    
    assert confidence_score > 0.5
    assert confidence_score <= 1.0
  end

  test 'should generate predictive model data correctly' do
    allocation = BudgetAllocation.new(
      user: @user,
      allocated_amount: 3000.0,
      channel_type: 'search',
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 30.days
    )
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    model_data = service.send(:generate_predictive_model_data, allocation)
    
    assert_equal '1.0', model_data[:model_version]
    assert_not_nil model_data[:confidence_score]
    assert_not_nil model_data[:predicted_performance]
    assert_not_nil model_data[:generated_at]
    assert_not_nil model_data[:factors_considered]
    assert model_data[:factors_considered].is_a?(Array)
  end

  test 'should use default values when parameters missing' do
    minimal_params = { action: 'optimize', total_budget: 5000 }
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: minimal_params
    )
    
    result = service.call
    
    assert result[:success]
    
    # Should use default channels and objectives
    allocations = result[:data][:allocations]
    default_channels = %w[social_media search email display]
    allocation_channels = allocations.map { |a| a[:channel_type] }
    
    default_channels.each do |channel|
      assert_includes allocation_channels, channel
    end
  end

  test 'should handle service exceptions gracefully' do
    # Force an exception by passing nil user
    service = ResourceAllocationService.new(
      user: nil,
      allocation_params: @base_params
    )
    
    result = service.call
    
    assert_not result[:success]
    assert_not_nil result[:error]
    assert_not_nil result[:context]
  end

  test 'should calculate optimization score correctly' do
    allocations = [
      { channel_type: 'search', allocated_amount: 4000.0 }, # weight 1.2
      { channel_type: 'social_media', allocated_amount: 3000.0 }, # weight 1.0
      { channel_type: 'email', allocated_amount: 3000.0 } # weight 0.8
    ]
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    score = service.send(:calculate_optimization_score, allocations)
    
    assert score > 0
    assert score <= 120 # Maximum possible with 1.2 weight
    
    # Should be weighted average of channel efficiencies
    total_budget = 10000.0
    expected_score = (
      (4000.0 / total_budget * 1.2) + 
      (3000.0 / total_budget * 1.0) + 
      (3000.0 / total_budget * 0.8)
    ) * 100
    
    assert_equal expected_score.round(2), score
  end

  test 'should generate meaningful recommendations' do
    # Allocations with imbalanced distribution
    poor_allocations = [
      { channel_type: 'display', allocated_amount: 9000.0 }, # low weight channel gets most budget
      { channel_type: 'search', allocated_amount: 1000.0 }  # high weight channel gets little
    ]
    
    service = ResourceAllocationService.new(
      user: @user,
      allocation_params: @base_params
    )
    
    recommendations = service.send(:generate_recommendations, poor_allocations)
    
    assert recommendations.is_a?(Array)
    assert recommendations.any? { |r| r.include?('high-performing channels') }
  end
end