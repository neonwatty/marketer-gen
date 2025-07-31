require 'test_helper'

class JourneySuggestionEngineTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @persona = create(:persona, user: @user)
    @campaign = create(:campaign, user: @user, persona: @persona)
    @journey = create(:journey, user: @user, campaign: @campaign)
    @current_step = create(:journey_step, journey: @journey, stage: 'awareness')
    
    # Mock LLM API responses
    mock_llm_response(
      JSON.generate({
        suggestions: [
          {
            name: "Welcome Email Sequence",
            description: "Send a personalized welcome email",
            stage: "awareness",
            content_type: "email",
            channel: "email",
            confidence_score: 0.85
          },
          {
            name: "Product Demo Video",
            description: "Share an engaging product demo",
            stage: "consideration", 
            content_type: "video",
            channel: "email",
            confidence_score: 0.75
          }
        ]
      })
    )
    
    @engine = JourneySuggestionEngine.new(
      journey: @journey,
      user: @user,
      current_step: @current_step,
      provider: :openai
    )
  end

  test "should initialize with required parameters" do
    assert_equal @journey, @engine.journey
    assert_equal @user, @engine.user
    assert_equal @current_step, @engine.current_step
    assert_equal :openai, @engine.provider
  end

  test "should raise error for unsupported provider" do
    assert_raises(ArgumentError) do
      JourneySuggestionEngine.new(
        journey: @journey,
        user: @user,
        provider: :unsupported_provider
      ).send(:fetch_ai_suggestions, {}, {})
    end
  end

  test "should generate fallback suggestions when API fails" do
    # Mock API failure
    engine = JourneySuggestionEngine.new(
      journey: @journey,
      user: @user,
      current_step: @current_step,
      provider: :openai
    )

    # Stub the API call to fail
    engine.stubs(:fetch_openai_suggestions).raises(StandardError.new("API Error"))
    
    suggestions = engine.generate_suggestions
    
    assert suggestions.is_a?(Array)
    assert suggestions.length > 0
    assert suggestions.first.key?('name')
    assert suggestions.first.key?('stage')
  end

  test "should generate stage-specific suggestions" do
    VCR.use_cassette("journey_suggestions_awareness") do
      suggestions = @engine.suggest_for_stage('awareness')
      
      assert suggestions.is_a?(Array)
      suggestions.each do |suggestion|
        assert_equal 'awareness', suggestion['stage']
        assert suggestion.key?('name')
        assert suggestion.key?('description')
        assert suggestion.key?('content_type')
        assert suggestion.key?('channel')
      end
    end
  end

  test "should record feedback successfully" do
    suggested_step_data = {
      id: 'test-suggestion-1',
      name: 'Test Suggestion',
      stage: 'awareness'
    }

    feedback = @engine.record_feedback(
      suggested_step_data,
      'suggestion_quality',
      rating: 4,
      selected: true,
      context: 'Test feedback context'
    )

    assert feedback.persisted?
    assert_equal @journey, feedback.journey
    assert_equal @current_step, feedback.journey_step
    assert_equal @user, feedback.user
    assert_equal 'suggestion_quality', feedback.feedback_type
    assert_equal 4, feedback.rating
    assert feedback.selected?
  end

  test "should not record feedback for invalid feedback type" do
    suggested_step_data = { id: 'test-suggestion-1' }

    assert_raises(ActiveRecord::RecordInvalid) do
      @engine.record_feedback(
        suggested_step_data,
        'invalid_feedback_type',
        rating: 4
      )
    end
  end

  test "should get feedback insights" do
    # Create some feedback data
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @current_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 4,
      suggested_step_id: 1
    )

    insights = @engine.get_feedback_insights
    assert insights.is_a?(Hash)
  end

  test "should build journey context correctly" do
    context = @engine.send(:build_journey_context)

    assert context.key?(:journey)
    assert context.key?(:current_step)
    assert context.key?(:existing_steps)
    assert context.key?(:user_preferences)

    journey_data = context[:journey]
    assert_equal @journey.name, journey_data[:name]
    assert_equal @journey.campaign_type, journey_data[:campaign_type]
    assert_equal @journey.total_steps, journey_data[:total_steps]
  end

  test "should build stage context correctly" do
    context = @engine.send(:build_stage_context, 'consideration')

    assert context.key?(:target_stage)
    assert context.key?(:stage_gaps)
    assert_equal 'consideration', context[:target_stage]
  end

  test "should rank suggestions based on multiple factors" do
    suggestions = [
      {
        'name' => 'Low confidence suggestion',
        'confidence_score' => 0.3,
        'stage' => 'awareness',
        'content_type' => 'email'
      },
      {
        'name' => 'High confidence suggestion',
        'confidence_score' => 0.9,
        'stage' => 'conversion',
        'content_type' => 'landing_page'
      }
    ]

    context = @engine.send(:build_journey_context)
    ranked_suggestions = @engine.send(:rank_suggestions, suggestions, context)

    assert ranked_suggestions.first['calculated_score'] >= ranked_suggestions.last['calculated_score']
    assert ranked_suggestions.all? { |s| s.key?('calculated_score') }
    assert ranked_suggestions.all? { |s| s.key?('ranking_factors') }
  end

  test "should calculate feedback adjustment correctly" do
    suggestion = {
      'content_type' => 'email',
      'stage' => 'awareness'
    }

    feedback_insights = {
      'email_rating' => 4.5,
      'awareness_rating' => 3.5
    }

    adjustment = @engine.send(:calculate_feedback_adjustment, suggestion, feedback_insights)
    assert adjustment.is_a?(Float)
    assert adjustment > 0 # Should be positive since ratings are above 3.0
  end

  test "should calculate completeness adjustment for missing stages" do
    suggestion = { 'stage' => 'advocacy' }
    context = {
      journey: {
        stages_coverage: { 'awareness' => 3, 'consideration' => 2 },
        total_steps: 5
      }
    }

    adjustment = @engine.send(:calculate_completeness_adjustment, suggestion, context)
    assert adjustment > 0 # Should boost score for missing stage
  end

  test "should generate appropriate fallback suggestions for each stage" do
    %w[awareness consideration conversion retention advocacy].each do |stage|
      suggestions = @engine.send(:generate_fallback_suggestions, {}, { stage: stage })
      
      assert suggestions.is_a?(Array)
      assert suggestions.length > 0
      
      suggestions.each do |suggestion|
        assert_equal stage, suggestion['stage']
        assert suggestion.key?('name')
        assert suggestion.key?('description')
        assert suggestion.key?('confidence_score')
      end
    end
  end

  test "should extract user preferences from historical data" do
    preferences = @engine.send(:extract_user_preferences)

    assert preferences.is_a?(Hash)
    assert preferences.key?(:preferred_content_types)
    assert preferences.key?(:preferred_channels)
    assert preferences.key?(:avg_journey_length)
    assert preferences.key?(:successful_patterns)
  end

  test "should cache suggestions properly" do
    Rails.cache.clear

    # First call should hit the API
    VCR.use_cassette("journey_suggestions_cache_test") do
      suggestions1 = @engine.generate_suggestions

      # Second call should use cache
      suggestions2 = @engine.generate_suggestions

      assert_equal suggestions1, suggestions2
    end
  end

  test "should store journey insights after generating suggestions" do
    initial_insights_count = @journey.journey_insights.count

    VCR.use_cassette("journey_suggestions_insights") do
      @engine.generate_suggestions
    end

    assert_equal initial_insights_count + 1, @journey.journey_insights.count

    insight = @journey.journey_insights.last
    assert_equal 'ai_suggestions', insight.insights_type
    assert insight.data.key?('suggestions')
    assert insight.calculated_at.present?
  end

  test "should detect next logical stage correctly" do
    # Test progression through stages
    awareness_step = JourneyStep.new(stage: 'awareness')
    @engine.instance_variable_set(:@current_step, awareness_step)
    
    next_stage = @engine.send(:detect_next_logical_stage)
    assert_equal 'consideration', next_stage

    # Test last stage
    advocacy_step = JourneyStep.new(stage: 'advocacy')
    @engine.instance_variable_set(:@current_step, advocacy_step)
    
    next_stage = @engine.send(:detect_next_logical_stage)
    assert_equal 'advocacy', next_stage

    # Test no current step
    @engine.instance_variable_set(:@current_step, nil)
    next_stage = @engine.send(:detect_next_logical_stage)
    assert_equal 'awareness', next_stage
  end

  test "should build cache key consistently" do
    filters = { stage: 'awareness', content_type: 'email' }
    
    cache_key1 = @engine.send(:build_cache_key, filters)
    cache_key2 = @engine.send(:build_cache_key, filters)
    
    assert_equal cache_key1, cache_key2
    assert cache_key1.include?(@journey.id.to_s)
    assert cache_key1.include?(@user.id.to_s)
    assert cache_key1.include?('openai')
  end

  private

  def journeys(symbol)
    Journey.new(
      id: 1,
      name: 'Test Journey',
      description: 'Test Description',
      campaign_type: 'product_launch',
      user: @user,
      status: 'draft'
    )
  end

  def journey_steps(symbol)
    JourneyStep.new(
      id: 1,
      journey: @journey,
      name: 'Test Step',
      stage: 'awareness',
      position: 1,
      content_type: 'email',
      channel: 'email'
    )
  end

  def users(symbol)
    User.new(
      id: 1,
      email_address: 'test@example.com',
      password: 'password123'
    )
  end
end