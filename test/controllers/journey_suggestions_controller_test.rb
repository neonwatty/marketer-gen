require 'test_helper'

class JourneySuggestionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user)
    @persona = create(:persona, user: @user)
    @campaign = create(:campaign, user: @user, persona: @persona)
    @journey = create(:journey, user: @user, campaign: @campaign)
    @journey_step = create(:journey_step, journey: @journey)
    
    # Mock current_user method
    @controller = JourneySuggestionsController.new
    @controller.define_singleton_method(:current_user) { @user }
  end

  test "should get suggestions index" do
    VCR.use_cassette("journey_suggestions_controller_index") do
      get journey_suggestions_path(@journey), 
          headers: { 'Accept' => 'application/json' }
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response['success']
      assert json_response['data']['suggestions'].is_a?(Array)
      assert json_response['data']['journey_context'].present?
      assert json_response['meta']['total_suggestions'].present?
    end
  end

  test "should get suggestions for specific stage" do
    VCR.use_cassette("journey_suggestions_controller_stage") do
      get for_stage_journey_suggestions_path(@journey, stage: 'awareness'),
          headers: { 'Accept' => 'application/json' }
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response['success']
      assert_equal 'awareness', json_response['data']['stage']
      
      suggestions = json_response['data']['suggestions']
      assert suggestions.is_a?(Array)
      suggestions.each do |suggestion|
        assert_equal 'awareness', suggestion['stage']
      end
    end
  end

  test "should return error for invalid stage" do
    get for_stage_journey_suggestions_path(@journey, stage: 'invalid_stage'),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert_includes json_response['error']['message'], 'Invalid stage'
  end

  test "should get suggestions for specific step" do
    VCR.use_cassette("journey_suggestions_controller_step") do
      get for_step_journey_suggestions_path(@journey, step_id: @journey_step.id),
          headers: { 'Accept' => 'application/json' }
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response['success']
      assert_equal @journey_step.id, json_response['data']['current_step']['id']
      assert json_response['data']['suggestions'].is_a?(Array)
    end
  end

  test "should return 404 for non-existent step" do
    get for_step_journey_suggestions_path(@journey, step_id: 99999),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :not_found
    
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert_includes json_response['error']['message'], 'Journey step not found'
  end

  test "should create feedback successfully" do
    suggestion_data = {
      id: 'test-suggestion-1',
      name: 'Test Suggestion',
      stage: 'awareness',
      content_type: 'email'
    }
    
    feedback_data = {
      feedback_type: 'suggestion_quality',
      rating: 4,
      selected: true,
      context: 'Test feedback context'
    }
    
    assert_difference('SuggestionFeedback.count', 1) do
      post feedback_journey_suggestions_path(@journey),
           params: {
             suggestion: suggestion_data,
             feedback: feedback_data
           },
           headers: { 'Accept' => 'application/json' }
    end
    
    assert_response :created
    
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert json_response['data']['feedback_id'].present?
    
    feedback = SuggestionFeedback.last
    assert_equal @journey, feedback.journey
    assert_equal @user, feedback.user
    assert_equal 'suggestion_quality', feedback.feedback_type
    assert_equal 4, feedback.rating
    assert feedback.selected?
  end

  test "should handle feedback creation errors" do
    suggestion_data = { id: 'test-suggestion-1' }
    feedback_data = {
      feedback_type: 'invalid_type', # Invalid feedback type
      rating: 4
    }
    
    assert_no_difference('SuggestionFeedback.count') do
      post feedback_journey_suggestions_path(@journey),
           params: {
             suggestion: suggestion_data,
             feedback: feedback_data
           },
           headers: { 'Accept' => 'application/json' }
    end
    
    assert_response :unprocessable_entity
    
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert json_response['error']['details'].present?
  end

  test "should get journey insights" do
    # Create some test insights
    JourneyInsight.create!(
      journey: @journey,
      insights_type: 'ai_suggestions',
      data: { 'suggestions' => [{ 'name' => 'Test' }] },
      calculated_at: Time.current
    )
    
    # Create some feedback for analytics
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 4,
      suggested_step_id: 1
    )
    
    get insights_journey_suggestions_path(@journey),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert json_response['data']['insights'].is_a?(Array)
    assert json_response['data']['feedback_analytics'].present?
    assert json_response['data']['suggestion_performance'].present?
    assert json_response['data']['journey_summary'].present?
  end

  test "should get analytics" do
    # Create test data
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 4,
      selected: true,
      suggested_step_id: 1,
      metadata: { 'provider' => 'openai' }
    )
    
    get analytics_journey_suggestions_path(@journey),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['success']
    
    analytics = json_response['data']
    assert analytics['feedback_trends'].present?
    assert analytics['selection_rates'].present?
    assert analytics['performance_by_type'].present?
    assert analytics['ai_provider_comparison'].present?
    assert analytics['improvement_opportunities'].is_a?(Array)
  end

  test "should handle different date ranges for analytics" do
    get analytics_journey_suggestions_path(@journey),
        params: { date_range: '7_days' },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal '7_days', json_response['meta']['date_range']
    assert_equal 7, json_response['meta']['days_analyzed']
  end

  test "should clear cache" do
    # Set up some cache
    Rails.cache.write("journey_suggestions:#{@journey.id}:test", "test_data")
    
    delete cache_journey_suggestions_path(@journey),
           headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_includes json_response['message'], 'Cache cleared'
  end

  test "should return 404 for non-existent journey" do
    get journey_suggestions_path(99999),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :not_found
    
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert_includes json_response['error']['message'], 'Journey not found'
  end

  test "should return 403 for unauthorized journey access" do
    other_user = User.create!(
      email_address: 'other@example.com',
      password: 'password123'
    )
    
    other_journey = Journey.create!(
      name: 'Other Journey',
      user: other_user,
      status: 'draft'
    )
    
    get journey_suggestions_path(other_journey),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :forbidden
    
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert_includes json_response['error']['message'], 'Unauthorized access'
  end

  test "should handle AI service errors gracefully" do
    # Mock the suggestion engine to raise an error
    JourneySuggestionEngine.any_instance.stubs(:generate_suggestions).raises(StandardError.new("AI service error"))
    
    get journey_suggestions_path(@journey),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :internal_server_error
    
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert_includes json_response['error']['message'], 'Failed to generate suggestions'
  end

  test "should apply filters from parameters" do
    VCR.use_cassette("journey_suggestions_with_filters") do
      get journey_suggestions_path(@journey),
          params: {
            stage: 'awareness',
            content_type: 'email',
            channel: 'email',
            max_suggestions: 3,
            min_confidence: 0.7
          },
          headers: { 'Accept' => 'application/json' }
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      filters_applied = json_response['data']['filters_applied']
      
      assert_equal 'awareness', filters_applied['stage']
      assert_equal 'email', filters_applied['content_type']
      assert_equal 'email', filters_applied['channel']
      assert_equal 3, filters_applied['max_suggestions']
      assert_equal 0.7, filters_applied['min_confidence']
    end
  end

  test "should respect provider parameter" do
    VCR.use_cassette("journey_suggestions_anthropic_provider") do
      get journey_suggestions_path(@journey),
          params: { provider: 'anthropic' },
          headers: { 'Accept' => 'application/json' }
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert_equal 'anthropic', json_response['data']['provider']
    end
  end

  test "should set current step from parameter" do
    VCR.use_cassette("journey_suggestions_with_current_step") do
      get journey_suggestions_path(@journey),
          params: { current_step_id: @journey_step.id },
          headers: { 'Accept' => 'application/json' }
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      journey_context = json_response['data']['journey_context']
      
      assert_equal @journey_step.id, journey_context['current_step']['id']
      assert_equal @journey_step.name, journey_context['current_step']['name']
    end
  end

  test "should calculate selection rates correctly" do
    # Create test feedback data
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 4,
      selected: true,
      suggested_step_id: 1
    )
    
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 3,
      selected: false,
      suggested_step_id: 2
    )
    
    get insights_journey_suggestions_path(@journey),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    feedback_analytics = json_response['data']['feedback_analytics']
    
    assert_equal 50.0, feedback_analytics['selection_rate'] # 1 out of 2 selected
  end

  test "should identify improvement opportunities" do
    # Create feedback that indicates poor performance for email content
    3.times do
      SuggestionFeedback.create!(
        journey: @journey,
        journey_step: @journey_step,
        user: @user,
        feedback_type: 'suggestion_quality',
        rating: 2, # Low rating
        selected: false,
        suggested_step_id: rand(1..100)
      )
    end
    
    get analytics_journey_suggestions_path(@journey),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    opportunities = json_response['data']['improvement_opportunities']
    
    assert opportunities.is_a?(Array)
    
    # Should identify content improvement opportunity for email
    content_opportunity = opportunities.find { |opp| opp['type'] == 'content_improvement' }
    if content_opportunity
      assert_equal 'email', content_opportunity['content_type']
      assert content_opportunity['current_rating'] < 3.0
    end
  end

  private

  def journey_suggestions_path(journey)
    "/journeys/#{journey.id}/suggestions"
  end

  def for_stage_journey_suggestions_path(journey, stage:)
    "/journeys/#{journey.id}/suggestions/for_stage/#{stage}"
  end

  def for_step_journey_suggestions_path(journey, step_id:)
    "/journeys/#{journey.id}/suggestions/for_step/#{step_id}"
  end

  def feedback_journey_suggestions_path(journey)
    "/journeys/#{journey.id}/suggestions/feedback"
  end

  def insights_journey_suggestions_path(journey)
    "/journeys/#{journey.id}/suggestions/insights"
  end

  def analytics_journey_suggestions_path(journey)
    "/journeys/#{journey.id}/suggestions/analytics"
  end

  def cache_journey_suggestions_path(journey)
    "/journeys/#{journey.id}/suggestions/cache"
  end
end