require 'test_helper'

class PredictiveAnalyticsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @campaign_plan = campaign_plans(:one)
    @service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'campaign_performance')
    
    # Use existing prediction model from fixtures for testing
    @prediction_model = prediction_models(:campaign_performance_model)
  end

  # Initialization Tests
  test "should initialize with valid parameters" do
    service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'roi_forecast')
    
    assert_equal @campaign_plan, service.campaign_plan
    assert_equal 'roi_forecast', service.prediction_type
    assert service.options.is_a?(Hash)
  end

  test "should use default prediction type when not specified" do
    service = PredictiveAnalyticsService.new(@campaign_plan)
    assert_equal 'campaign_performance', service.prediction_type
  end

  test "should raise error with nil campaign plan" do
    error = assert_raises(ArgumentError) do
      PredictiveAnalyticsService.new(nil)
    end
    assert_equal 'Campaign plan cannot be nil', error.message
  end

  test "should raise error with unpersisted campaign plan" do
    new_plan = CampaignPlan.new(name: "Test")
    error = assert_raises(ArgumentError) do
      PredictiveAnalyticsService.new(new_plan)
    end
    assert_equal 'Campaign plan must be persisted', error.message
  end

  test "should raise error with invalid prediction type" do
    error = assert_raises(ArgumentError) do
      PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'invalid_type')
    end
    assert_match(/Invalid prediction type/, error.message)
  end

  # Campaign Performance Prediction Tests
  test "should generate campaign performance prediction successfully" do
    result = @service.call
    
    puts "DEBUG: result = #{result.inspect}"

    assert result[:success]
    assert_equal 'campaign_performance', result[:data][:prediction_type]
    assert result[:data][:model_version].present?
    assert result[:data][:confidence_score].present?
    assert result[:data][:prediction_data].present?
    assert result[:data][:generated_at].present?
    assert result[:data][:model_accuracy].present?
  end

  test "should handle missing prediction model gracefully" do
    @prediction_model.destroy
    
    # Mock model creation
    PredictiveAnalyticsService.any_instance.stubs(:create_or_retrain_model).returns(nil)
    
    result = @service.call
    
    assert_not result[:success]
    assert result[:error].present?
  end

  # ROI Forecast Tests
  test "should generate roi forecast prediction" do
    roi_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'roi_forecast')
    
    # Create ROI model
    roi_model = PredictionModel.create!(
      name: "ROI Model",
      prediction_type: "roi_forecast",
      model_type: "gradient_boosting",
      status: "active",
      version: next_version_for("roi_forecast"),
      accuracy_score: 0.75,
      confidence_level: 0.8,
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    result = roi_service.call

    assert result[:success]
    assert_equal 'roi_forecast', result[:data][:prediction_type]
    assert result[:data][:roi_projection].present?
    assert result[:data][:confidence_interval].present?
    assert result[:data][:break_even_analysis].present?
    assert result[:data][:revenue_projection].present?
    assert result[:data][:time_to_roi].present?
  end

  # Optimization Opportunities Tests  
  test "should generate optimization opportunities" do
    opt_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'optimization_opportunities')
    
    # Create optimization model
    opt_model = PredictionModel.create!(
      name: "Optimization Model",
      prediction_type: "optimization_opportunities",
      model_type: "random_forest",
      status: "active",
      version: next_version_for("optimization_opportunities"),
      accuracy_score: 0.82,
      confidence_level: 0.88,
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    result = opt_service.call

    assert result[:success]
    assert_equal 'optimization_opportunities', result[:data][:prediction_type]
    assert result[:data][:total_opportunities].present?
    assert result[:data][:high_impact_opportunities].present?
    assert result[:data][:prioritized_list].present?
    assert result[:data][:potential_improvement_range].present?
  end

  # Audience Engagement Tests
  test "should generate audience engagement prediction" do
    engagement_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'audience_engagement')
    
    # Create engagement model
    engagement_model = PredictionModel.create!(
      name: "Engagement Model",
      prediction_type: "audience_engagement",
      model_type: "neural_network",
      status: "active",
      version: next_version_for("audience_engagement"),
      accuracy_score: 0.78,
      confidence_level: 0.83,
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    result = engagement_service.call

    assert result[:success]
    assert_equal 'audience_engagement', result[:data][:prediction_type]
    assert result[:data][:overall_engagement_score].present?
    assert result[:data][:channel_breakdown].present?
    assert result[:data][:optimal_timing].present?
    assert result[:data][:audience_segments].present?
    assert result[:data][:content_recommendations].present?
  end

  # Budget Optimization Tests
  test "should generate budget optimization recommendations" do
    budget_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'budget_optimization')
    
    # Mock LLM service response
    mock_llm_response = {
      success: true,
      content: JSON.generate({
        budget_recommendations: [
          { channel: 'social_media', current_allocation: 30, recommended_allocation: 35, reasoning: 'Higher ROI' },
          { channel: 'paid_search', current_allocation: 40, recommended_allocation: 35, reasoning: 'Market saturation' }
        ],
        efficiency_gain: 15,
        implementation_steps: ['Reallocate budget', 'Monitor performance', 'Adjust based on results']
      })
    }
    
    budget_service.stubs(:llm_service).returns(mock(generate_content: mock_llm_response))

    result = budget_service.call

    assert result[:success]
    assert_equal 'budget_optimization', result[:data][:prediction_type]
    assert result[:data][:current_budget_analysis].present?
    assert result[:data][:optimization_recommendations].present?
    assert result[:data][:projected_efficiency_gain].present?
  end

  # Analytics Dashboard Tests
  test "should generate comprehensive analytics dashboard" do
    result = @service.generate_analytics_dashboard

    assert result[:success]
    
    dashboard = result[:data]
    assert dashboard[:campaign_overview].present?
    assert dashboard[:performance_predictions].present?
    assert dashboard[:optimization_insights].present?
    assert dashboard[:risk_assessment].present?
    assert dashboard[:recommendations].present?
    assert dashboard[:model_confidence].present?
    assert dashboard[:last_updated].present?
  end

  # Batch Predictions Tests
  test "should generate batch predictions for multiple types" do
    # Create models for multiple prediction types
    PredictionModel.create!(
      name: "ROI Model",
      prediction_type: "roi_forecast",
      model_type: "gradient_boosting",
      status: "active",
      version: next_version_for("roi_forecast"),
      accuracy_score: 0.75,
      confidence_level: 0.8,
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    PredictionModel.create!(
      name: "Engagement Model",
      prediction_type: "audience_engagement",
      model_type: "neural_network",
      status: "active",
      version: next_version_for("audience_engagement"),
      accuracy_score: 0.78,
      confidence_level: 0.83,
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    prediction_types = ['campaign_performance', 'roi_forecast', 'audience_engagement']
    result = @service.generate_batch_predictions(prediction_types)

    assert result[:success]
    assert result[:data][:complete_success] || result[:data][:partial_success]
    assert result[:data][:predictions].present?
    
    # Should have predictions for each type
    prediction_types.each do |type|
      assert result[:data][:predictions].key?(type)
    end
  end

  test "should handle batch prediction errors gracefully" do
    # Test with prediction types that don't have models
    prediction_types = ['nonexistent_type']
    result = @service.generate_batch_predictions(prediction_types)

    # Should still return success with errors recorded
    assert result[:success]
    assert result[:data][:errors].present?
    assert result[:data][:partial_success]
  end

  # Model Training Tests
  test "should trigger model training successfully" do
    # Mock sufficient data
    @service.stubs(:sufficient_data_for_training?).returns(true)
    @service.stubs(:available_data_points).returns(100)

    # Mock job enqueuing
    ModelTrainingJob.expects(:perform_later).once

    result = @service.trigger_model_training

    assert result[:success]
    assert result[:data][:model_id].present?
    assert result[:data][:version].present?
    assert result[:data][:training_started]
    assert result[:data][:estimated_completion].present?
    assert result[:data][:message].present?
  end

  test "should not trigger training with insufficient data" do
    @service.stubs(:sufficient_data_for_training?).returns(false)
    @service.stubs(:available_data_points).returns(10)

    result = @service.trigger_model_training

    assert_not result[:success]
    assert_match(/Insufficient data/, result[:error])
  end

  # Model Comparison Tests
  test "should compare model versions successfully" do
    # Create second model version
    model_b = PredictionModel.create!(
      name: "Model V2",
      prediction_type: "campaign_performance",
      model_type: "random_forest",
      status: "trained",
      version: next_version_for("campaign_performance"),
      accuracy_score: 0.85,
      confidence_level: 0.9,
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    result = @service.compare_model_versions(@prediction_model.id, model_b.id)

    assert result[:success]
    assert result[:data].present?
    # The comparison results would be mocked/stubbed in implementation
  end

  test "should not compare incomparable models" do
    # Create model with different prediction type
    different_model = PredictionModel.create!(
      name: "Different Model",
      prediction_type: "roi_forecast",
      model_type: "linear_regression",
      status: "active",
      version: next_version_for("roi_forecast"),
      accuracy_score: 0.7,
      confidence_level: 0.75,
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    result = @service.compare_model_versions(@prediction_model.id, different_model.id)

    assert_not result[:success]
    assert_match(/not comparable/, result[:error])
  end

  test "should handle non-existent model comparison" do
    result = @service.compare_model_versions(@prediction_model.id, 99999)

    assert_not result[:success]
    assert result[:error].present?
  end

  # Model Retrieval Tests
  test "should get existing active prediction model" do
    model = @service.get_prediction_model
    assert_equal @prediction_model, model
  end

  test "should create model when none exists" do
    @prediction_model.destroy

    # Mock model creation
    new_model = PredictionModel.new(
      name: "New Model",
      prediction_type: "campaign_performance",
      model_type: "linear_regression",
      status: "draft",
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    @service.stubs(:create_or_retrain_model).returns(new_model)
    @service.stubs(:trigger_model_training).returns(true)

    model = @service.get_prediction_model
    assert model.present?
  end

  # Error Handling Tests
  test "should handle service errors gracefully" do
    # Force an error in prediction generation
    PredictionModel.any_instance.stubs(:generate_prediction).raises(StandardError.new("Test error"))

    result = @service.call

    assert_not result[:success]
    assert_equal "Test error", result[:error]
    assert result[:context].present?
  end

  test "should handle unsupported prediction type" do
    service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'campaign_performance')
    service.instance_variable_set(:@prediction_type, 'unsupported_type')

    result = service.call

    assert_not result[:success]
    assert_match(/Unsupported prediction type/, result[:error])
  end

  # Data Preparation Tests
  test "should prepare campaign input data correctly" do
    input_data = @service.send(:prepare_campaign_input_data)

    assert input_data.is_a?(Hash)
    assert input_data.key?(:campaign_type)
    assert input_data.key?(:objective)
    assert input_data.key?(:budget)
    assert input_data.key?(:timeline_days)
    assert input_data.key?(:target_audience_size)
    assert input_data.key?(:brand_strength)
    assert input_data.key?(:market_conditions)
    assert input_data.key?(:competitive_pressure)
    assert input_data.key?(:seasonal_factors)
    assert input_data.key?(:historical_performance)
  end

  test "should prepare optimization input data correctly" do
    opt_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'optimization_opportunities')
    input_data = opt_service.send(:prepare_optimization_input_data)

    assert input_data.is_a?(Hash)
    # Should include all campaign data plus optimization-specific data
    assert input_data.key?(:current_performance)
    assert input_data.key?(:channel_efficiency)
    assert input_data.key?(:content_performance)
    assert input_data.key?(:audience_engagement)
  end

  # Helper Method Tests
  test "should extract total budget correctly" do
    # Mock budget allocations
    active_allocations = mock()
    active_allocations.stubs(:sum).with(:allocated_amount).returns(15000)
    
    budget_allocations = mock()
    budget_allocations.stubs(:active).returns(active_allocations)
    @campaign_plan.stubs(:budget_allocations).returns(budget_allocations)

    budget = @service.send(:extract_total_budget)
    assert_equal 15000, budget
  end

  test "should use default budget when none available" do
    # Mock budget allocations
    active_allocations = mock()
    active_allocations.stubs(:sum).with(:allocated_amount).returns(nil)
    
    budget_allocations = mock()
    budget_allocations.stubs(:active).returns(active_allocations)
    @campaign_plan.stubs(:budget_allocations).returns(budget_allocations)

    budget = @service.send(:extract_total_budget)
    assert_equal 10000, budget  # Default value
  end

  test "should extract timeline duration correctly" do
    # Mock timeline data
    timeline_data = { 'duration_days' => 45 }
    @campaign_plan.stubs(:generated_timeline).returns(timeline_data)

    duration = @service.send(:extract_timeline_duration)
    assert_equal 45, duration
  end

  test "should use default timeline when none available" do
    @campaign_plan.stubs(:generated_timeline).returns(nil)

    duration = @service.send(:extract_timeline_duration)
    assert_equal 30, duration  # Default value
  end

  test "should assess competitive pressure correctly" do
    # Mock competitive data
    competitive_data = {
      competitor_data: {
        'competitors' => [
          { 'name' => 'Competitor 1' },
          { 'name' => 'Competitor 2' },
          { 'name' => 'Competitor 3' },
          { 'name' => 'Competitor 4' }
        ]
      }
    }
    @campaign_plan.stubs(:competitive_analysis_summary).returns(competitive_data)

    pressure = @service.send(:assess_competitive_pressure)
    assert_equal 'medium', pressure  # 4 competitors = medium pressure
  end

  test "should assess seasonal factors correctly" do
    # Test different months
    Date.stubs(:current).returns(Date.new(2024, 12, 15))  # December
    factors = @service.send(:assess_seasonal_factors)
    assert_equal 'positive', factors

    Date.stubs(:current).returns(Date.new(2024, 7, 15))   # July
    factors = @service.send(:assess_seasonal_factors)
    assert_equal 'neutral', factors

    Date.stubs(:current).returns(Date.new(2024, 3, 15))   # March
    factors = @service.send(:assess_seasonal_factors)
    assert_equal 'neutral', factors
  end

  # Training Data Tests
  test "should determine sufficient data for training correctly" do
    @service.stubs(:available_data_points).returns(60)
    assert @service.send(:sufficient_data_for_training?)

    @service.stubs(:available_data_points).returns(20)
    assert_not @service.send(:sufficient_data_for_training?)
  end

  test "should calculate available data points correctly" do
    # Mock related data
    @campaign_plan.stubs(:campaign_insights).returns(mock(count: 5))
    @campaign_plan.stubs(:generated_contents).returns(mock(count: 10))
    @campaign_plan.stubs(:content_ab_tests).returns(mock(count: 3))
    
    @service.stubs(:extract_historical_performance).returns([1, 2, 3])

    data_points = @service.send(:available_data_points)
    # 5*2 + 10 + 3*5 + 3 = 10 + 10 + 15 + 3 = 38
    assert_equal 38, data_points
  end

  # Model Versioning Tests
  test "should generate appropriate model name" do
    name = @service.send(:generate_model_name)
    assert_match(/Campaign performance Model/, name)
    assert_match(/v\d+/, name)
  end

  test "should calculate next model version correctly" do
    # There are already models with versions 1 and 2 in fixtures, so next should be 3
    version = @service.send(:next_model_version)
    assert_equal 3, version
  end

  test "should determine optimal model type based on prediction type" do
    performance_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'campaign_performance')
    assert_equal 'ensemble', performance_service.send(:determine_optimal_model_type)

    roi_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'roi_forecast')
    assert_equal 'gradient_boosting', roi_service.send(:determine_optimal_model_type)

    opt_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'optimization_opportunities')
    assert_equal 'random_forest', opt_service.send(:determine_optimal_model_type)

    engagement_service = PredictiveAnalyticsService.new(@campaign_plan, prediction_type: 'audience_engagement')
    assert_equal 'neural_network', engagement_service.send(:determine_optimal_model_type)
  end

  # Integration Tests
  test "should work end-to-end for campaign performance prediction" do
    # Ensure we have an active model
    assert @prediction_model.active?
    
    # Store initial prediction count
    initial_count = @prediction_model.prediction_count

    # Generate prediction
    result = @service.call

    # Verify successful prediction
    assert result[:success]
    assert result[:data][:prediction_type] == 'campaign_performance'
    assert result[:data][:prediction_data].present?

    # Verify model usage was tracked (count should be incremented by 1)
    @prediction_model.reload
    assert_equal initial_count + 1, @prediction_model.prediction_count
    assert @prediction_model.last_prediction_at.present?
  end

  test "should handle complete workflow with model creation and training" do
    # Remove existing model to test full creation workflow
    @prediction_model.destroy

    # Mock training data availability
    @service.stubs(:sufficient_data_for_training?).returns(true)
    @service.stubs(:prepare_training_data).returns([
      { 'features' => { 'budget' => 1000 }, 'target' => 0.8 },
      { 'features' => { 'budget' => 2000 }, 'target' => 0.9 }
    ])

    # Mock job enqueuing to avoid actual job execution
    ModelTrainingJob.stubs(:perform_later)

    # This should create a new model and start training
    model = @service.get_prediction_model
    
    assert model.present?
    assert model.persisted?
    assert_equal 'campaign_performance', model.prediction_type
    assert_equal @campaign_plan, model.campaign_plan
  end

  private

  def next_version_for(prediction_type)
    max_version = @campaign_plan.prediction_models
                                .where(prediction_type: prediction_type)
                                .maximum(:version) || 0
    max_version + 1
  end

  def mock_llm_service_response(content)
    { success: true, content: content }
  end
end