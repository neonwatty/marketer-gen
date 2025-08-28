require 'test_helper'

class BudgetAllocationTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @campaign_plan = campaign_plans(:one) if defined?(campaign_plans)
    
    @valid_attributes = {
      user: @user,
      campaign_plan: @campaign_plan,
      name: 'Test Budget Allocation',
      total_budget: 10000.0,
      allocated_amount: 5000.0,
      channel_type: 'social_media',
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 30.days,
      optimization_objective: 'conversions',
      status: 'active'
    }
  end

  test 'should create valid budget allocation' do
    allocation = BudgetAllocation.new(@valid_attributes)
    assert allocation.valid?, "Budget allocation should be valid: #{allocation.errors.full_messages.join(', ')}"
    assert allocation.save
  end

  test 'should require name' do
    allocation = BudgetAllocation.new(@valid_attributes.except(:name))
    assert_not allocation.valid?
    assert_includes allocation.errors[:name], "can't be blank"
  end

  test 'should require total_budget' do
    allocation = BudgetAllocation.new(@valid_attributes.except(:total_budget))
    assert_not allocation.valid?
    assert_includes allocation.errors[:total_budget], "can't be blank"
  end

  test 'should require positive total_budget' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(total_budget: -100))
    assert_not allocation.valid?
    assert_includes allocation.errors[:total_budget], "must be greater than 0"

    allocation = BudgetAllocation.new(@valid_attributes.merge(total_budget: 0))
    assert_not allocation.valid?
    assert_includes allocation.errors[:total_budget], "must be greater than 0"
  end

  test 'should require allocated_amount' do
    allocation = BudgetAllocation.new(@valid_attributes.except(:allocated_amount))
    assert_not allocation.valid?
    assert_includes allocation.errors[:allocated_amount], "can't be blank"
  end

  test 'should allow zero allocated_amount' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(allocated_amount: 0))
    assert allocation.valid?
  end

  test 'should not allow negative allocated_amount' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(allocated_amount: -100))
    assert_not allocation.valid?
    assert_includes allocation.errors[:allocated_amount], "must be greater than or equal to 0"
  end

  test 'should require valid channel_type' do
    allocation = BudgetAllocation.new(@valid_attributes.except(:channel_type))
    assert_not allocation.valid?
    assert_includes allocation.errors[:channel_type], "can't be blank"

    allocation = BudgetAllocation.new(@valid_attributes.merge(channel_type: 'invalid_channel'))
    assert_not allocation.valid?
    assert_includes allocation.errors[:channel_type], "is not included in the list"
  end

  test 'should accept valid channel_types' do
    valid_channels = %w[social_media email search display video content_marketing]
    
    valid_channels.each do |channel|
      allocation = BudgetAllocation.new(@valid_attributes.merge(channel_type: channel))
      assert allocation.valid?, "#{channel} should be a valid channel type"
    end
  end

  test 'should require valid optimization_objective' do
    allocation = BudgetAllocation.new(@valid_attributes.except(:optimization_objective))
    assert_not allocation.valid?
    assert_includes allocation.errors[:optimization_objective], "can't be blank"

    allocation = BudgetAllocation.new(@valid_attributes.merge(optimization_objective: 'invalid_objective'))
    assert_not allocation.valid?
    assert_includes allocation.errors[:optimization_objective], "is not included in the list"
  end

  test 'should accept valid optimization_objectives' do
    valid_objectives = %w[awareness engagement conversions revenue cost_efficiency]
    
    valid_objectives.each do |objective|
      allocation = BudgetAllocation.new(@valid_attributes.merge(optimization_objective: objective))
      assert allocation.valid?, "#{objective} should be a valid optimization objective"
    end
  end

  test 'should validate allocation does not exceed budget' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      total_budget: 1000.0,
      allocated_amount: 1500.0
    ))
    
    assert_not allocation.valid?
    assert_includes allocation.errors[:allocated_amount], "cannot exceed total budget of $1000.0"
  end

  test 'should validate time period dates' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      time_period_start: Date.current + 5.days,
      time_period_end: Date.current + 1.day
    ))
    
    assert_not allocation.valid?
    assert_includes allocation.errors[:time_period_end], "must be after start date"
  end

  test 'should not allow start date in the past' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      time_period_start: Date.current - 1.day
    ))
    
    assert_not allocation.valid?
    assert_includes allocation.errors[:time_period_start], "cannot be in the past"
  end

  test 'should calculate allocation_percentage correctly' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      total_budget: 10000.0,
      allocated_amount: 2500.0
    ))
    
    assert_equal 25.0, allocation.allocation_percentage
  end

  test 'should calculate remaining_budget correctly' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      total_budget: 10000.0,
      allocated_amount: 3000.0
    ))
    
    assert_equal 7000.0, allocation.remaining_budget
  end

  test 'should identify over_budget allocations' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      total_budget: 1000.0,
      allocated_amount: 1200.0
    ))
    
    assert allocation.is_over_budget?
    
    allocation.allocated_amount = 800.0
    assert_not allocation.is_over_budget?
  end

  test 'should calculate duration_days correctly' do
    start_date = Date.current + 1.day
    end_date = start_date + 29.days
    
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      time_period_start: start_date,
      time_period_end: end_date
    ))
    
    assert_equal 29, allocation.duration_days
  end

  test 'should calculate daily_allocation correctly' do
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      allocated_amount: 3000.0,
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 31.days
    ))
    
    expected_daily = 3000.0 / 30
    assert_equal expected_daily, allocation.daily_allocation
  end

  test 'should validate predictive_model_data when present' do
    invalid_data = { model_version: '1.0' } # missing required fields
    
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      predictive_model_data: invalid_data
    ))
    
    assert_not allocation.valid?
    assert_includes allocation.errors[:predictive_model_data], "missing required fields: confidence_score, predicted_performance"
  end

  test 'should validate confidence_score in predictive_model_data' do
    invalid_data = {
      model_version: '1.0',
      confidence_score: 1.5, # invalid - should be between 0 and 1
      predicted_performance: {}
    }
    
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      predictive_model_data: invalid_data
    ))
    
    assert_not allocation.valid?
    assert_includes allocation.errors[:predictive_model_data], "confidence_score must be between 0 and 1"
  end

  test 'should accept valid predictive_model_data' do
    valid_data = {
      model_version: '1.0',
      confidence_score: 0.85,
      predicted_performance: {
        estimated_conversions: 100,
        estimated_revenue: 5000
      }
    }
    
    allocation = BudgetAllocation.new(@valid_attributes.merge(
      predictive_model_data: valid_data
    ))
    
    assert allocation.valid?
  end

  test 'should calculate efficiency_score before save' do
    allocation = BudgetAllocation.create!(@valid_attributes.merge(
      total_budget: 10000.0,
      allocated_amount: 5000.0,
      channel_type: 'search' # has 1.2 multiplier
    ))
    
    expected_efficiency = (5000.0 / 10000.0 * 100) * 1.2
    assert_equal expected_efficiency.round(2), allocation.efficiency_score
  end

  test 'should track budget changes in performance_metrics' do
    allocation = BudgetAllocation.create!(@valid_attributes)
    original_amount = allocation.allocated_amount
    
    allocation.update!(allocated_amount: 7000.0)
    
    history = allocation.performance_metrics['allocation_history']
    assert_not_nil history
    assert_equal 1, history.length
    assert_equal original_amount, history.first['old_amount']
    assert_equal 7000.0, history.first['new_amount']
  end

  test 'should scope by_channel correctly' do
    social_allocation = BudgetAllocation.create!(@valid_attributes.merge(channel_type: 'social_media', name: 'Social Test'))
    email_allocation = BudgetAllocation.create!(@valid_attributes.merge(channel_type: 'email', name: 'Email Test'))
    
    social_results = BudgetAllocation.by_channel('social_media')
    assert_includes social_results, social_allocation
    assert_not_includes social_results, email_allocation
  end

  test 'should scope by_objective correctly' do
    conversion_allocation = BudgetAllocation.create!(@valid_attributes.merge(optimization_objective: 'conversions', name: 'Conversion Test'))
    awareness_allocation = BudgetAllocation.create!(@valid_attributes.merge(optimization_objective: 'awareness', name: 'Awareness Test'))
    
    conversion_results = BudgetAllocation.by_objective('conversions')
    assert_includes conversion_results, conversion_allocation
    assert_not_includes conversion_results, awareness_allocation
  end

  test 'should scope active_in_period correctly' do
    # Create allocation that overlaps with test period
    overlapping_allocation = BudgetAllocation.create!(@valid_attributes.merge(
      time_period_start: Date.current + 1.day,
      time_period_end: Date.current + 15.days,
      status: 'active',
      name: 'Overlapping Test'
    ))
    
    # Create allocation outside test period  
    non_overlapping_allocation = BudgetAllocation.create!(@valid_attributes.merge(
      time_period_start: Date.current + 50.days,
      time_period_end: Date.current + 80.days,
      status: 'active',
      name: 'Non-overlapping Test'
    ))
    
    results = BudgetAllocation.active_in_period(Date.current, Date.current + 7.days)
    assert_includes results, overlapping_allocation
    assert_not_includes results, non_overlapping_allocation
  end

  test 'should have correct associations' do
    allocation = BudgetAllocation.new(@valid_attributes)
    
    assert_respond_to allocation, :user
    assert_respond_to allocation, :campaign_plan
  end

  test 'should serialize JSON fields correctly' do
    data = { test_key: 'test_value', nested: { key: 'value' } }
    valid_predictive_data = {
      model_version: '1.0',
      confidence_score: 0.8,
      predicted_performance: { conversions: 100 }
    }
    
    allocation = BudgetAllocation.create!(@valid_attributes.merge(
      predictive_model_data: valid_predictive_data,
      performance_metrics: data,
      allocation_breakdown: data
    ))
    
    allocation.reload
    
    assert_equal valid_predictive_data.with_indifferent_access, allocation.predictive_model_data
    
    # Performance metrics should include the original data plus the efficiency_score added by the callback
    expected_performance_metrics = data.with_indifferent_access.merge('efficiency_score' => "50.0")
    assert_equal expected_performance_metrics, allocation.performance_metrics
    
    assert_equal data.with_indifferent_access, allocation.allocation_breakdown
  end
end