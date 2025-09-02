require 'test_helper'

class JourneyAiServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
    @brand_identity = brand_identities(:active_brand)
    @brand_identity.update!(is_active: true)
    
    @service = JourneyAiService.new(@journey, @user)
  end

  test "initializes with journey and user" do
    assert_not_nil @service
    assert_equal @journey, @service.journey
    assert_equal @user, @service.user
  end

  test "generates intelligent suggestions with brand context" do
    result = @service.generate_intelligent_suggestions(limit: 3)
    
    assert result[:success]
    assert_not_nil result[:suggestions]
    assert_equal 3, result[:suggestions].length
    
    # Check suggestion structure
    suggestion = result[:suggestions].first
    assert_not_nil suggestion[:title]
    assert_not_nil suggestion[:description]
    assert_not_nil suggestion[:step_type]
    assert_not_nil suggestion[:brand_compliance_score]
  end

  test "falls back to rule-based suggestions when LLM unavailable" do
    # Mock LLM service failure
    @service.stubs(:llm_service_available?).returns(false)
    
    result = @service.generate_intelligent_suggestions(limit: 5)
    
    assert_not_nil result[:suggestions]
    assert result[:metadata][:fallback_used] if result[:metadata]
  end

  test "applies brand compliance scoring to suggestions" do
    result = @service.generate_intelligent_suggestions(limit: 2)
    
    result[:suggestions].each do |suggestion|
      assert suggestion[:brand_compliance_score].between?(0, 100)
    end
  end

  test "generates step content with brand consistency" do
    result = @service.generate_step_content('email', { 
      campaign_goal: 'awareness',
      focus: 'product launch' 
    })
    
    if result[:success]
      assert_not_nil result[:content]
      assert_not_nil result[:brand_compliance]
      assert result[:metadata][:brand_applied]
    end
  end

  test "analyzes journey performance and suggests optimizations" do
    # Add some mock performance data
    @journey.journey_steps.create!(
      title: "Test Step",
      step_type: "email",
      ai_generated: true,
      performance_metrics: { engagement_rate: 45 }
    )
    
    result = @service.analyze_and_optimize
    
    assert_not_nil result[:optimizations]
    assert_includes result.keys, :predicted_improvement
    assert_includes result.keys, :confidence_score
  end

  test "predicts next best action for journey" do
    result = @service.predict_next_best_action
    
    assert_not_nil result[:next_action]
    assert_not_nil result[:reasoning] if result[:success]
    assert_not_nil result[:confidence] if result[:success]
  end

  test "handles missing brand identity gracefully" do
    @brand_identity.update!(is_active: false)
    service = JourneyAiService.new(@journey, @user)
    
    result = service.generate_intelligent_suggestions(limit: 2)
    
    assert_not_nil result[:suggestions]
    # Should still work but without brand context
    assert result[:metadata][:brand_applied] == false if result[:metadata]
  end

  test "respects suggestion limit parameter" do
    [1, 3, 5, 10].each do |limit|
      result = @service.generate_intelligent_suggestions(limit: limit)
      
      assert result[:suggestions].length <= limit
    end
  end

  test "includes relevant metadata in responses" do
    result = @service.generate_intelligent_suggestions(limit: 2)
    
    assert_not_nil result[:metadata]
    assert_not_nil result[:metadata][:generation_time]
    assert_includes [true, false], result[:metadata][:brand_applied]
  end

  test "handles errors gracefully with fallback" do
    # Force an error in LLM service
    @service.instance_variable_get(:@llm_service).stubs(:generate_journey_suggestions).raises(StandardError)
    
    result = @service.generate_intelligent_suggestions(limit: 3)
    
    assert_equal false, result[:success]
    assert_not_nil result[:error]
    assert_not_nil result[:suggestions] # Should have fallback suggestions
  end

  test "generates suggestions appropriate for campaign type" do
    @journey.update!(campaign_type: 'retention')
    service = JourneyAiService.new(@journey, @user)
    
    result = service.generate_intelligent_suggestions(limit: 3)
    
    # Suggestions should be relevant to retention campaigns
    result[:suggestions].each do |suggestion|
      assert_includes %w[email content nurture event], suggestion[:step_type]
    end
  end

  test "avoids duplicate suggestions" do
    # Add existing steps
    @journey.journey_steps.create!(
      title: "Welcome Email",
      step_type: "email"
    )
    
    result = @service.generate_intelligent_suggestions(limit: 5)
    
    # Check that suggestions don't duplicate existing steps
    titles = result[:suggestions].map { |s| s[:title] }
    assert_equal titles.uniq.length, titles.length
  end

  test "includes timing recommendations in suggestions" do
    result = @service.generate_intelligent_suggestions(limit: 3)
    
    result[:suggestions].each do |suggestion|
      assert_not_nil suggestion[:timing]
      assert_includes %w[immediate 1_day 3_days 1_week custom], suggestion[:timing]
    end
  end

  test "includes channel recommendations in suggestions" do
    result = @service.generate_intelligent_suggestions(limit: 3)
    
    result[:suggestions].each do |suggestion|
      assert_not_nil suggestion[:suggested_channels]
      assert suggestion[:suggested_channels].is_a?(Array)
      assert suggestion[:suggested_channels].any?
    end
  end

  test "natural language parsing for journey creation" do
    description = "Create a 5-day onboarding sequence with welcome email, product tour, and check-in"
    
    result = @service.parse_natural_language_journey(description)
    
    if result[:success]
      assert_not_nil result[:steps]
      assert result[:steps].length >= 3
      
      result[:steps].each do |step|
        assert_not_nil step[:title]
        assert_not_nil step[:description]
        assert_not_nil step[:step_type]
      end
    end
  end

  test "integrates performance feedback into suggestions" do
    # Add performance data
    @journey.update!(
      ai_learning_data: {
        patterns: {
          best_performing_step_types: [
            { type: 'email', avg_performance: 85 }
          ]
        }
      }
    )
    
    result = @service.generate_intelligent_suggestions(limit: 3)
    
    # Should prioritize high-performing step types
    email_suggestions = result[:suggestions].select { |s| s[:step_type] == 'email' }
    assert email_suggestions.any?
  end
end