require 'test_helper'

class ContentOptimizationEngineTest < ActiveSupport::TestCase
  def setup
    @brand = brands(:one)
    @optimization_engine = LlmIntegration::ContentOptimizationEngine.new(@brand)
    @multivariate_tester = LlmIntegration::MultivariateContentTester.new
    @performance_analyzer = LlmIntegration::ContentPerformanceAnalyzer.new
  end

  test "should generate content variants for A/B testing" do
    base_content = {
      type: :email_subject,
      content: "Introducing Our New AI-Powered Analytics Platform",
      context: {
        audience: "B2B decision makers",
        goal: "increase_open_rates",
        campaign_type: "product_launch"
      }
    }
    
    variants = @optimization_engine.generate_variants(base_content, count: 5)
    
    assert_equal 5, variants.length
    
    variants.each_with_index do |variant, index|
      assert_not_nil variant[:content]
      assert_not_equal base_content[:content], variant[:content]
      assert_not_nil variant[:optimization_strategy]
      assert_not_nil variant[:expected_performance_lift]
      assert variant[:brand_compliance_score] >= 0.90
      
      # Each variant should use different optimization approach
      assert_not_nil variant[:optimization_rationale]
    end
    
    # Variants should be sufficiently different from each other
    content_similarity_matrix = @optimization_engine.calculate_content_similarity(variants)
    content_similarity_matrix.each do |similarity_score|
      assert similarity_score < 0.8, "Variants are too similar"
    end
  end

  test "should optimize content for different channels and formats" do
    base_message = "Transform your business with our AI-powered analytics solution"
    
    channel_optimizations = [
      { channel: :twitter, max_chars: 280, hashtag_count: 3 },
      { channel: :linkedin, tone: :professional, length: :medium },
      { channel: :email_subject, max_chars: 50, urgency: :moderate },
      { channel: :facebook_ad, cta_required: true, audience: :b2b },
      { channel: :google_ad_headline, max_chars: 30, keyword_density: :high }
    ]
    
    channel_optimizations.each do |optimization|
      optimized_content = @optimization_engine.optimize_for_channel(
        base_message, 
        optimization
      )
      
      assert_not_nil optimized_content[:content]
      assert_equal optimization[:channel], optimized_content[:channel]
      
      # Verify channel-specific constraints
      case optimization[:channel]
      when :twitter
        assert optimized_content[:content].length <= 280
        hashtag_count = optimized_content[:content].scan(/#\w+/).length
        assert hashtag_count <= 3
      when :email_subject
        assert optimized_content[:content].length <= 50
      when :google_ad_headline
        assert optimized_content[:content].length <= 30
      end
      
      assert optimized_content[:optimization_score] >= 0.8
    end
  end

  test "should provide performance predictions and recommendations" do
    content_sample = {
      type: :landing_page_headline,
      content: "Revolutionary AI Analytics for Enterprise Success",
      metadata: {
        character_count: 49,
        word_count: 6,
        power_words: ["Revolutionary", "Success"],
        emotional_sentiment: 0.7
      }
    }
    
    performance_prediction = @performance_analyzer.predict_performance(content_sample)
    
    assert_includes performance_prediction.keys, :predicted_ctr
    assert_includes performance_prediction.keys, :predicted_conversion_rate
    assert_includes performance_prediction.keys, :predicted_engagement_score
    assert_includes performance_prediction.keys, :confidence_interval
    
    # Predictions should be realistic ranges
    assert performance_prediction[:predicted_ctr] >= 0.0
    assert performance_prediction[:predicted_ctr] <= 1.0
    assert performance_prediction[:confidence_interval][:lower] <= performance_prediction[:predicted_ctr]
    assert performance_prediction[:confidence_interval][:upper] >= performance_prediction[:predicted_ctr]
    
    # Should provide actionable recommendations
    recommendations = performance_prediction[:recommendations]
    assert_instance_of Array, recommendations
    assert recommendations.length > 0
    
    first_recommendation = recommendations.first
    assert_includes first_recommendation.keys, :improvement_type
    assert_includes first_recommendation.keys, :suggested_change
    assert_includes first_recommendation.keys, :expected_impact
  end

  test "should implement multivariate testing with statistical significance" do
    test_variables = {
      headline: ["Transform Your Business", "Revolutionize Your Operations", "Accelerate Your Growth"],
      cta: ["Get Started Today", "Try It Free", "Request Demo"],
      tone: [:professional, :enthusiastic, :urgent]
    }
    
    multivariate_test = @multivariate_tester.create_test(test_variables)
    
    # Should generate all combinations
    expected_combinations = 3 * 3 * 3  # 27 combinations
    assert_equal expected_combinations, multivariate_test.combinations.length
    
    # Each combination should be properly formatted
    multivariate_test.combinations.each do |combination|
      assert_includes test_variables[:headline], combination[:headline]
      assert_includes test_variables[:cta], combination[:cta]
      assert_includes test_variables[:tone], combination[:tone]
      assert_not_nil combination[:variant_id]
    end
    
    # Test statistical analysis
    sample_results = generate_sample_test_results(multivariate_test.combinations)
    statistical_analysis = @multivariate_tester.analyze_results(sample_results)
    
    assert_includes statistical_analysis.keys, :winning_combination
    assert_includes statistical_analysis.keys, :statistical_significance
    assert_includes statistical_analysis.keys, :confidence_level
    assert_includes statistical_analysis.keys, :variable_impact_analysis
  end

  test "should optimize content based on historical performance data" do
    historical_performance_data = [
      { content: "Free Trial Available", ctr: 0.15, conversion_rate: 0.08, engagement: 0.6 },
      { content: "Start Your Journey", ctr: 0.12, conversion_rate: 0.06, engagement: 0.5 },
      { content: "Transform Your Business", ctr: 0.18, conversion_rate: 0.11, engagement: 0.8 },
      { content: "Revolutionary Solution", ctr: 0.09, conversion_rate: 0.04, engagement: 0.4 }
    ]
    
    performance_learner = LlmIntegration::PerformanceBasedLearner.new
    
    # Train on historical data
    performance_learner.train(historical_performance_data)
    
    # Test optimization based on learning
    new_content = "Innovative AI Platform"
    optimized_version = performance_learner.optimize_content(new_content)
    
    assert_not_nil optimized_version[:optimized_content]
    assert optimized_version[:predicted_improvement] > 0
    assert_not_empty optimized_version[:optimization_reasons]
    
    # Should identify high-performing patterns
    patterns = performance_learner.identify_high_performing_patterns
    assert_includes patterns[:effective_words], "Transform"
    assert patterns[:optimal_length_range][:min] > 0
    assert patterns[:optimal_length_range][:max] > patterns[:optimal_length_range][:min]
  end

  test "should provide real-time content quality scoring" do
    quality_scorer = LlmIntegration::RealTimeQualityScorer.new(@brand)
    
    test_contents = [
      "Our AI solution delivers measurable results for enterprise clients",  # High quality
      "Amazing product that will blow your mind!!!",  # Low quality  
      "Professional analytics platform with proven ROI",  # Medium-high quality
      "stuff for business things"  # Very low quality
    ]
    
    test_contents.each do |content|
      quality_score = quality_scorer.score_content(content)
      
      assert_includes quality_score.keys, :overall_score
      assert_includes quality_score.keys, :component_scores
      assert_includes quality_score.keys, :improvement_suggestions
      
      # Overall score should be 0-100
      assert quality_score[:overall_score] >= 0
      assert quality_score[:overall_score] <= 100
      
      # Component scores should include key metrics
      component_scores = quality_score[:component_scores]
      assert_includes component_scores.keys, :clarity
      assert_includes component_scores.keys, :professionalism
      assert_includes component_scores.keys, :brand_alignment
      assert_includes component_scores.keys, :engagement_potential
      assert_includes component_scores.keys, :grammar_quality
    end
  end

  test "should support automated content improvement workflows" do
    improvement_workflow = LlmIntegration::AutomatedImprovementWorkflow.new(@brand)
    
    suboptimal_content = {
      type: :email_content,
      content: "Hi there! We have some products that might be good for your company. Maybe you want to check them out?",
      target_score: 85
    }
    
    improvement_result = improvement_workflow.improve_content(suboptimal_content)
    
    assert improvement_result[:improved_content][:quality_score] >= suboptimal_content[:target_score]
    assert_not_equal suboptimal_content[:content], improvement_result[:improved_content][:content]
    
    # Should provide improvement tracking
    assert_includes improvement_result.keys, :improvements_made
    assert_includes improvement_result.keys, :before_after_comparison
    assert_includes improvement_result.keys, :iteration_count
    
    improvements_made = improvement_result[:improvements_made]
    assert improvements_made.length > 0
    
    first_improvement = improvements_made.first
    assert_includes first_improvement.keys, :improvement_type
    assert_includes first_improvement.keys, :original_text
    assert_includes first_improvement.keys, :improved_text
    assert_includes first_improvement.keys, :rationale
  end

  test "should handle content optimization for different audience segments" do
    audience_segments = [
      { segment: :enterprise_executives, preferences: { tone: :formal, length: :concise, focus: :roi } },
      { segment: :small_business_owners, preferences: { tone: :friendly, length: :detailed, focus: :value } },
      { segment: :technical_users, preferences: { tone: :informative, length: :comprehensive, focus: :features } }
    ]
    
    base_content = "Our platform helps businesses analyze data more effectively"
    
    audience_segments.each do |segment_info|
      optimized_content = @optimization_engine.optimize_for_audience(
        base_content,
        segment_info[:segment],
        segment_info[:preferences]
      )
      
      assert_not_nil optimized_content[:content]
      assert_equal segment_info[:segment], optimized_content[:target_audience]
      assert optimized_content[:audience_fit_score] >= 0.8
      
      # Content should reflect audience preferences
      case segment_info[:segment]
      when :enterprise_executives
        assert_includes optimized_content[:content].downcase, "roi"
        assert optimized_content[:formality_score] >= 0.8
      when :small_business_owners
        assert optimized_content[:friendliness_score] >= 0.7
      when :technical_users
        assert optimized_content[:technical_depth_score] >= 0.8
      end
    end
  end

  test "should integrate content optimization with A/B testing framework" do
    ab_integration = LlmIntegration::ContentOptimizationABIntegration.new
    
    # Create optimization-driven A/B test
    optimization_request = {
      content_type: :landing_page_headline,
      base_content: "Transform Your Business Operations",
      optimization_goals: [:increase_conversions, :improve_engagement],
      test_duration_days: 14,
      minimum_sample_size: 1000
    }
    
    ab_test = ab_integration.create_optimization_test(optimization_request)
    
    assert_not_nil ab_test[:test_id]
    assert ab_test[:variants].length >= 2
    assert_not_nil ab_test[:success_metrics]
    assert_not_nil ab_test[:statistical_power]
    
    # Variants should be optimization-driven
    ab_test[:variants].each do |variant|
      assert_not_nil variant[:optimization_strategy]
      assert_not_nil variant[:predicted_performance]
      assert variant[:content] != optimization_request[:base_content]
    end
    
    # Test result analysis integration
    mock_test_results = {
      variant_a: { conversions: 45, visitors: 500, engagement_time: 120 },
      variant_b: { conversions: 62, visitors: 500, engagement_time: 145 }
    }
    
    optimization_insights = ab_integration.analyze_optimization_results(
      ab_test[:test_id],
      mock_test_results
    )
    
    assert_includes optimization_insights.keys, :winning_strategy
    assert_includes optimization_insights.keys, :performance_lift
    assert_includes optimization_insights.keys, :optimization_learnings
  end

  test "should provide content optimization analytics and reporting" do
    analytics_engine = LlmIntegration::ContentOptimizationAnalytics.new(@brand)
    
    # Test comprehensive optimization reporting
    date_range = 30.days.ago..Time.current
    optimization_report = analytics_engine.generate_optimization_report(date_range)
    
    assert_includes optimization_report.keys, :total_optimizations_performed
    assert_includes optimization_report.keys, :average_quality_improvement
    assert_includes optimization_report.keys, :performance_improvements
    assert_includes optimization_report.keys, :top_optimization_strategies
    assert_includes optimization_report.keys, :roi_analysis
    
    # Performance improvements should show measurable impact
    performance_improvements = optimization_report[:performance_improvements]
    assert_includes performance_improvements.keys, :ctr_improvements
    assert_includes performance_improvements.keys, :conversion_improvements
    assert_includes performance_improvements.keys, :engagement_improvements
    
    # ROI analysis should demonstrate value
    roi_analysis = optimization_report[:roi_analysis]
    assert roi_analysis[:optimization_roi] > 0
    assert_not_nil roi_analysis[:cost_savings]
    assert_not_nil roi_analysis[:revenue_impact]
  end

  private

  def generate_sample_test_results(combinations)
    combinations.map do |combination|
      {
        variant_id: combination[:variant_id],
        impressions: rand(800..1200),
        clicks: rand(40..120),
        conversions: rand(5..25),
        engagement_time: rand(30..180)
      }
    end
  end
end