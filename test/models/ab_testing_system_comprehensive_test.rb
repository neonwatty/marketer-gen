require 'test_helper'

class AbTestingSystemComprehensiveTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @campaign = campaigns(:product_launch)
    @journey_control = journeys(:onboarding_control)
    @journey_treatment = journeys(:onboarding_treatment)
    @ab_test = ab_tests(:conversion_test)
  end

  # Variant Generation and Management Tests
  test "should generate multiple test variants automatically" do
    variant_generator = AbTestVariantGenerator.new(@ab_test)
    
    generation_config = {
      base_journey: @journey_control,
      variant_count: 4,
      generation_strategy: "systematic_variation",
      variation_dimensions: ["messaging", "visual_design", "cta_placement", "timing"],
      target_metrics: ["conversion_rate", "engagement_rate"]
    }
    
    generated_variants = variant_generator.generate_variants(generation_config)
    
    assert_not_nil generated_variants
    assert_equal 4, generated_variants[:variants].length
    
    generated_variants[:variants].each_with_index do |variant, index|
      assert variant[:name].present?
      assert variant[:variant_id].present?
      assert variant[:variation_details].present?
      assert variant[:journey_configuration].present?
      assert_equal "generated", variant[:type]
      assert_not_equal @journey_control.id, variant[:journey_id] unless index == 0  # First should be control
    end
  end

  test "should create variants with smart messaging variations" do
    messaging_variant_engine = MessagingVariantEngine.new(@ab_test)
    
    base_messaging = {
      primary_headline: "Transform Your Business Today",
      subheading: "Discover the power of our innovative solution",
      cta_text: "Get Started Now",
      value_proposition: "Increase efficiency by 40%"
    }
    
    messaging_variants = messaging_variant_engine.generate_messaging_variants(base_messaging, 3)
    
    assert_equal 3, messaging_variants.length
    
    messaging_variants.each do |variant|
      assert variant[:primary_headline] != base_messaging[:primary_headline]
      assert variant[:sentiment_analysis].present?
      assert variant[:readability_score].present?
      assert variant[:persuasion_techniques].any?
      assert variant[:target_psychology_profile].present?
    end
  end

  test "should create variants with visual design changes" do
    visual_variant_engine = VisualVariantEngine.new(@ab_test)
    
    base_design = {
      color_scheme: "blue_professional",
      layout_type: "centered_single_column",
      button_style: "rounded_primary",
      image_placement: "top_hero",
      typography: "sans_serif_modern"
    }
    
    visual_variants = visual_variant_engine.generate_visual_variants(base_design, 4)
    
    assert_equal 4, visual_variants.length
    
    visual_variants.each do |variant|
      assert variant[:design_changes].any?
      assert variant[:contrast_score].present?
      assert variant[:accessibility_score].present?
      assert variant[:mobile_optimization_score].present?
      assert variant[:brand_consistency_score].present?
    end
  end

  test "should manage variant lifecycle and states" do
    variant_manager = AbTestVariantManager.new(@ab_test)
    
    # Create new variant
    new_variant = variant_manager.create_variant({
      name: "High-Urgency Messaging",
      journey_id: @journey_treatment.id,
      traffic_percentage: 25.0,
      variant_type: "treatment"
    })
    
    assert new_variant[:success]
    variant_id = new_variant[:variant_id]
    
    # Update variant configuration
    update_result = variant_manager.update_variant(variant_id, {
      traffic_percentage: 30.0,
      configuration_changes: { urgency_level: "high", scarcity_messaging: true }
    })
    
    assert update_result[:success]
    
    # Pause variant
    pause_result = variant_manager.pause_variant(variant_id, "Performance below threshold")
    assert pause_result[:success]
    
    # Resume variant
    resume_result = variant_manager.resume_variant(variant_id)
    assert resume_result[:success]
    
    # Archive variant
    archive_result = variant_manager.archive_variant(variant_id, "Test completed")
    assert archive_result[:success]
  end

  # Test Configuration and Traffic Splitting Tests
  test "should configure complex traffic splitting scenarios" do
    traffic_splitter = AbTestTrafficSplitter.new(@ab_test)
    
    splitting_config = {
      allocation_strategy: "weighted_performance",
      variants: [
        { variant_id: "control", initial_traffic: 40.0, max_traffic: 50.0 },
        { variant_id: "treatment_a", initial_traffic: 30.0, max_traffic: 40.0 },
        { variant_id: "treatment_b", initial_traffic: 20.0, max_traffic: 35.0 },
        { variant_id: "treatment_c", initial_traffic: 10.0, max_traffic: 25.0 }
      ],
      adjustment_rules: {
        min_sample_size: 1000,
        adjustment_frequency: "daily",
        performance_threshold: 0.05
      }
    }
    
    traffic_config = traffic_splitter.configure_traffic_splitting(splitting_config)
    
    assert traffic_config[:success]
    assert_equal 4, traffic_config[:variant_allocations].length
    assert_equal 100.0, traffic_config[:variant_allocations].sum { |v| v[:traffic_percentage] }
    assert traffic_config[:adaptive_allocation_enabled]
  end

  test "should implement adaptive traffic allocation based on performance" do
    adaptive_allocator = AdaptiveTrafficAllocator.new(@ab_test)
    
    # Simulate performance data
    performance_data = {
      "control" => { conversion_rate: 2.5, confidence: 0.85, sample_size: 2000 },
      "treatment_a" => { conversion_rate: 3.2, confidence: 0.92, sample_size: 1800 },
      "treatment_b" => { conversion_rate: 2.8, confidence: 0.78, sample_size: 1500 },
      "treatment_c" => { conversion_rate: 1.9, confidence: 0.65, sample_size: 1200 }
    }
    
    allocation_adjustment = adaptive_allocator.adjust_traffic_allocation(performance_data)
    
    assert allocation_adjustment[:adjustments_made]
    assert allocation_adjustment[:new_allocations].present?
    
    # Best performing variant should get more traffic
    best_variant = allocation_adjustment[:new_allocations].max_by { |v| v[:traffic_percentage] }
    assert_equal "treatment_a", best_variant[:variant_id]
    assert best_variant[:traffic_percentage] > 30.0
    
    # Worst performing variant should get less traffic
    worst_variant = allocation_adjustment[:new_allocations].min_by { |v| v[:traffic_percentage] }
    assert_equal "treatment_c", worst_variant[:variant_id]
  end

  test "should handle traffic allocation constraints and caps" do
    constrained_allocator = ConstrainedTrafficAllocator.new(@ab_test)
    
    constraints = {
      min_traffic_per_variant: 10.0,
      max_traffic_per_variant: 40.0,
      control_min_traffic: 25.0,
      total_test_traffic_cap: 80.0,  # 20% holdout
      adjustment_rate_limit: 5.0  # Max 5% change per adjustment
    }
    
    current_allocation = {
      "control" => 30.0,
      "treatment_a" => 25.0,
      "treatment_b" => 25.0,
      "treatment_c" => 20.0
    }
    
    desired_allocation = {
      "control" => 20.0,  # Would violate control_min_traffic
      "treatment_a" => 45.0,  # Would violate max_traffic_per_variant
      "treatment_b" => 30.0,
      "treatment_c" => 5.0  # Would violate min_traffic_per_variant
    }
    
    constrained_result = constrained_allocator.apply_constraints(
      current_allocation,
      desired_allocation,
      constraints
    )
    
    assert constrained_result[:success]
    assert constrained_result[:final_allocation]["control"] >= 25.0
    assert constrained_result[:final_allocation]["treatment_a"] <= 40.0
    assert constrained_result[:final_allocation]["treatment_c"] >= 10.0
    assert constrained_result[:constraint_violations].any?
  end

  # Real-time Metrics and Statistical Analysis Tests
  test "should collect and process real-time test metrics" do
    metrics_collector = RealTimeAbTestMetrics.new(@ab_test)
    
    # Simulate real-time events
    events = [
      { variant_id: "control", event_type: "page_view", timestamp: Time.current },
      { variant_id: "control", event_type: "conversion", timestamp: Time.current + 30.seconds },
      { variant_id: "treatment_a", event_type: "page_view", timestamp: Time.current + 1.minute },
      { variant_id: "treatment_a", event_type: "click", timestamp: Time.current + 1.5.minutes },
      { variant_id: "treatment_a", event_type: "conversion", timestamp: Time.current + 2.minutes }
    ]
    
    processing_result = metrics_collector.process_events_batch(events)
    
    assert processing_result[:success]
    assert_equal 5, processing_result[:events_processed]
    
    real_time_metrics = metrics_collector.get_real_time_metrics
    
    assert real_time_metrics[:control][:page_views] >= 1
    assert real_time_metrics[:control][:conversions] >= 1
    assert real_time_metrics[:treatment_a][:page_views] >= 1
    assert real_time_metrics[:treatment_a][:conversions] >= 1
    
    assert real_time_metrics[:control][:conversion_rate].present?
    assert real_time_metrics[:treatment_a][:conversion_rate].present?
  end

  test "should perform advanced statistical analysis continuously" do
    statistical_analyzer = AbTestStatisticalAnalyzer.new(@ab_test)
    
    # Provide sample data for analysis
    variant_data = {
      "control" => {
        visitors: 5000,
        conversions: 150,
        revenue: 15000.0,
        session_duration: 180.0,
        bounce_rate: 0.35
      },
      "treatment_a" => {
        visitors: 4800,
        conversions: 180,
        revenue: 19200.0,
        session_duration: 210.0,
        bounce_rate: 0.28
      }
    }
    
    analysis_result = statistical_analyzer.perform_comprehensive_analysis(variant_data)
    
    assert_not_nil analysis_result
    
    # Statistical significance tests
    assert analysis_result[:significance_tests].present?
    assert analysis_result[:significance_tests][:conversion_rate][:p_value].present?
    assert analysis_result[:significance_tests][:conversion_rate][:confidence_interval].present?
    
    # Effect size calculations
    assert analysis_result[:effect_sizes].present?
    assert analysis_result[:effect_sizes][:conversion_rate][:cohens_d].present?
    assert analysis_result[:effect_sizes][:revenue][:lift_percentage].present?
    
    # Power analysis
    assert analysis_result[:power_analysis].present?
    assert analysis_result[:power_analysis][:statistical_power].present?
    assert analysis_result[:power_analysis][:minimum_detectable_effect].present?
  end

  test "should perform Bayesian statistical analysis" do
    bayesian_analyzer = BayesianAbTestAnalyzer.new(@ab_test)
    
    prior_beliefs = {
      control_conversion_rate: { alpha: 1, beta: 50 },  # Weak prior
      treatment_conversion_rate: { alpha: 1, beta: 45 }  # Slightly optimistic prior
    }
    
    observed_data = {
      control: { conversions: 120, visitors: 4000 },
      treatment: { conversions: 156, visitors: 3800 }
    }
    
    bayesian_result = bayesian_analyzer.analyze_with_priors(prior_beliefs, observed_data)
    
    assert_not_nil bayesian_result
    
    # Posterior distributions
    assert bayesian_result[:posterior_distributions].present?
    assert bayesian_result[:posterior_distributions][:control][:alpha].present?
    assert bayesian_result[:posterior_distributions][:treatment][:beta].present?
    
    # Probability calculations
    assert bayesian_result[:probability_treatment_better].between?(0, 1)
    assert bayesian_result[:expected_loss_control].present?
    assert bayesian_result[:expected_loss_treatment].present?
    
    # Credible intervals
    assert bayesian_result[:credible_intervals].present?
    assert bayesian_result[:credible_intervals][:control][:lower_bound].present?
    assert bayesian_result[:credible_intervals][:treatment][:upper_bound].present?
  end

  # Confidence Calculations and Winner Declaration Tests
  test "should calculate confidence intervals with multiple correction methods" do
    confidence_calculator = AbTestConfidenceCalculator.new(@ab_test)
    
    test_data = {
      variants: [
        { name: "control", conversions: 145, visitors: 5000 },
        { name: "treatment_a", conversions: 178, visitors: 4900 },
        { name: "treatment_b", conversions: 162, visitors: 4800 },
        { name: "treatment_c", conversions: 134, visitors: 4700 }
      ],
      confidence_level: 0.95,
      correction_methods: ["bonferroni", "benjamini_hochberg", "holm"]
    }
    
    confidence_results = confidence_calculator.calculate_with_corrections(test_data)
    
    assert_not_nil confidence_results
    
    # Check each correction method results
    test_data[:correction_methods].each do |method|
      method_results = confidence_results[method.to_sym]
      assert method_results.present?
      
      method_results[:pairwise_comparisons].each do |comparison|
        assert comparison[:variant_a].present?
        assert comparison[:variant_b].present?
        assert comparison[:p_value].present?
        assert comparison[:adjusted_p_value].present?
        assert comparison[:confidence_interval].present?
        assert comparison[:is_significant].in?([true, false])
      end
    end
  end

  test "should implement early stopping rules for tests" do
    early_stopping = AbTestEarlyStopping.new(@ab_test)
    
    stopping_rules = {
      alpha_spending_function: "obrien_fleming",
      futility_boundary: "stochastic_curtailment", 
      minimum_sample_size: 1000,
      maximum_sample_size: 10000,
      interim_analysis_schedule: [0.25, 0.5, 0.75, 1.0]  # Fractions of max sample
    }
    
    current_data = {
      control: { conversions: 75, visitors: 2500 },
      treatment: { conversions: 95, visitors: 2400 }
    }
    
    stopping_decision = early_stopping.evaluate_stopping_condition(stopping_rules, current_data)
    
    assert_not_nil stopping_decision
    assert stopping_decision[:decision].in?(["continue", "stop_for_efficacy", "stop_for_futility"])
    assert stopping_decision[:analysis_stage].present?
    assert stopping_decision[:efficacy_boundary].present?
    assert stopping_decision[:futility_boundary].present?
    
    if stopping_decision[:decision] == "stop_for_efficacy"
      assert stopping_decision[:winner].present?
      assert stopping_decision[:final_p_value].present?
    end
  end

  test "should declare winners with comprehensive validation" do
    winner_declarator = AbTestWinnerDeclarator.new(@ab_test)
    
    final_results = {
      variants: [
        { 
          id: "control", 
          conversions: 145, 
          visitors: 5000, 
          revenue: 14500.0,
          secondary_metrics: { engagement_rate: 0.32, time_on_site: 180 }
        },
        { 
          id: "treatment_a", 
          conversions: 189, 
          visitors: 4950, 
          revenue: 20790.0,
          secondary_metrics: { engagement_rate: 0.41, time_on_site: 220 }
        }
      ],
      test_duration_days: 21,
      confidence_level: 0.95,
      minimum_lift_threshold: 0.10
    }
    
    winner_result = winner_declarator.declare_winner(final_results)
    
    assert_not_nil winner_result
    
    if winner_result[:has_winner]
      assert winner_result[:winner_variant_id].present?
      assert winner_result[:statistical_significance]
      assert winner_result[:practical_significance]
      assert winner_result[:lift_percentage] >= 10.0
      assert winner_result[:confidence_interval].present?
      
      # Validation checks
      assert winner_result[:validation_checks][:sample_size_adequate]
      assert winner_result[:validation_checks][:test_duration_sufficient]
      assert winner_result[:validation_checks][:external_validity_score].present?
    else
      assert winner_result[:inconclusive_reasons].any?
    end
  end

  # AI Recommendations and Pattern Recognition Tests
  test "should generate AI-powered test recommendations" do
    ai_recommender = AbTestAIRecommender.new(@ab_test)
    
    historical_context = {
      campaign_type: @campaign.campaign_type,
      industry: "technology",
      target_audience: @campaign.target_audience_context,
      previous_test_results: [
        { variation_type: "headline", winner_lift: 15.3, confidence: 0.94 },
        { variation_type: "cta_color", winner_lift: 8.7, confidence: 0.87 },
        { variation_type: "social_proof", winner_lift: 22.1, confidence: 0.96 }
      ]
    }
    
    ai_recommendations = ai_recommender.generate_recommendations(historical_context)
    
    assert_not_nil ai_recommendations
    
    # Test variation recommendations
    assert ai_recommendations[:suggested_variations].any?
    ai_recommendations[:suggested_variations].each do |variation|
      assert variation[:type].present?
      assert variation[:description].present?
      assert variation[:predicted_lift].present?
      assert variation[:confidence_score].between?(0, 1)
      assert variation[:implementation_difficulty].in?(["low", "medium", "high"])
    end
    
    # Statistical recommendations
    assert ai_recommendations[:statistical_recommendations].present?
    assert ai_recommendations[:statistical_recommendations][:recommended_sample_size].present?
    assert ai_recommendations[:statistical_recommendations][:estimated_test_duration].present?
    
    # Success probability
    assert ai_recommendations[:success_probability].between?(0, 1)
  end

  test "should recognize patterns from historical test data" do
    pattern_recognizer = AbTestPatternRecognizer.new
    
    historical_tests = [
      {
        campaign_type: "product_launch",
        variations: ["headline_benefit_focused", "urgency_messaging"],
        winner: "urgency_messaging",
        lift: 18.5,
        audience_segment: "early_adopters"
      },
      {
        campaign_type: "product_launch", 
        variations: ["social_proof_heavy", "feature_focused"],
        winner: "social_proof_heavy",
        lift: 12.3,
        audience_segment: "early_adopters"
      },
      {
        campaign_type: "retention",
        variations: ["personalized_content", "generic_content"],
        winner: "personalized_content", 
        lift: 25.7,
        audience_segment: "existing_customers"
      }
    ]
    
    patterns = pattern_recognizer.identify_patterns(historical_tests)
    
    assert_not_nil patterns
    
    # Campaign type patterns
    assert patterns[:campaign_type_patterns].present?
    product_launch_pattern = patterns[:campaign_type_patterns]["product_launch"]
    assert product_launch_pattern.present?
    assert product_launch_pattern[:successful_variations].include?("urgency_messaging")
    
    # Audience patterns
    assert patterns[:audience_patterns].present?
    early_adopters_pattern = patterns[:audience_patterns]["early_adopters"]
    assert early_adopters_pattern[:average_lift].present?
    
    # Variation effectiveness
    assert patterns[:variation_effectiveness].present?
    assert patterns[:variation_effectiveness]["urgency_messaging"][:win_rate].present?
  end

  test "should provide AI-powered optimization suggestions during tests" do
    optimization_ai = AbTestOptimizationAI.new(@ab_test)
    
    current_test_state = {
      days_running: 7,
      variants: [
        { id: "control", conversions: 45, visitors: 1500, conversion_rate: 3.0 },
        { id: "treatment_a", conversions: 38, visitors: 1450, conversion_rate: 2.62 },
        { id: "treatment_b", conversions: 52, visitors: 1480, conversion_rate: 3.51 }
      ],
      traffic_allocation: { "control" => 33.3, "treatment_a" => 33.3, "treatment_b" => 33.4 },
      statistical_power: 0.65
    }
    
    optimization_suggestions = optimization_ai.generate_optimization_suggestions(current_test_state)
    
    assert_not_nil optimization_suggestions
    
    # Traffic allocation suggestions
    if optimization_suggestions[:traffic_allocation_changes]
      allocation_changes = optimization_suggestions[:traffic_allocation_changes]
      assert allocation_changes[:reasoning].present?
      assert allocation_changes[:new_allocation].keys.sort == ["control", "treatment_a", "treatment_b"]
    end
    
    # Test duration suggestions
    assert optimization_suggestions[:duration_recommendations].present?
    duration_rec = optimization_suggestions[:duration_recommendations]
    assert duration_rec[:recommended_action].in?(["continue", "extend", "stop_early"])
    assert duration_rec[:reasoning].present?
    
    # Performance insights
    assert optimization_suggestions[:performance_insights].any?
    optimization_suggestions[:performance_insights].each do |insight|
      assert insight[:type].present?
      assert insight[:description].present?
      assert insight[:actionable_advice].present?
    end
  end

  test "should predict test outcomes using machine learning" do
    outcome_predictor = AbTestOutcomePredictor.new
    
    test_parameters = {
      campaign_context: {
        type: @campaign.campaign_type,
        industry: "technology",
        target_audience_size: 50000,
        budget: 25000
      },
      test_design: {
        variant_count: 3,
        primary_metric: "conversion_rate",
        planned_duration: 14,
        minimum_detectable_effect: 0.15
      },
      baseline_metrics: {
        current_conversion_rate: 2.8,
        current_traffic_volume: 1000,
        seasonal_factors: { holiday_impact: 1.15, day_of_week_variance: 0.12 }
      }
    }
    
    outcome_prediction = outcome_predictor.predict_test_outcome(test_parameters)
    
    assert_not_nil outcome_prediction
    
    # Success probability
    assert outcome_prediction[:success_probability].between?(0, 1)
    
    # Predicted metrics
    assert outcome_prediction[:predicted_results].present?
    predicted_results = outcome_prediction[:predicted_results]
    assert predicted_results[:expected_lift_range].present?
    assert predicted_results[:confidence_interval].present?
    assert predicted_results[:expected_statistical_power].present?
    
    # Risk factors
    assert outcome_prediction[:risk_factors].any?
    outcome_prediction[:risk_factors].each do |risk|
      assert risk[:factor].present?
      assert risk[:impact_level].in?(["low", "medium", "high"])
      assert risk[:mitigation_suggestion].present?
    end
    
    # Optimization opportunities  
    assert outcome_prediction[:optimization_opportunities].any?
  end

  private

  def create_test_ab_test_with_variants
    test = AbTest.create!(
      name: "Comprehensive Test",
      campaign: @campaign,
      user: @user,
      test_type: "conversion",
      hypothesis: "Treatment variants will outperform control",
      confidence_level: 95.0,
      significance_threshold: 5.0
    )
    
    # Create control variant
    test.ab_test_variants.create!(
      name: "Control",
      journey: @journey_control,
      is_control: true,
      traffic_percentage: 25.0,
      variant_type: "control"
    )
    
    # Create treatment variants
    ["Treatment A", "Treatment B", "Treatment C"].each_with_index do |name, index|
      test.ab_test_variants.create!(
        name: name,
        journey: @journey_treatment,
        is_control: false,
        traffic_percentage: 25.0,
        variant_type: "treatment"
      )
    end
    
    test
  end
end