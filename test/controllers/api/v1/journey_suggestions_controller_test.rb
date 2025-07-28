require "test_helper"

class Api::V1::JourneySuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @journey = journeys(:one)
    @journey.update!(user: @user)
    sign_in_as(@user)
  end

  test "should get suggestions index" do
    get api_v1_journey_suggestions_url, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['suggestions'].is_a?(Array)
    assert response_data['data']['suggestions'].count > 0
  end

  test "should get suggestions for stage" do
    get for_stage_api_v1_journey_suggestions_url('awareness'), as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['suggestions'].is_a?(Array)
    
    # Check that suggestions are for the awareness stage
    awareness_suggestions = response_data['data']['suggestions'].select do |s|
      s['data']['stage'] == 'awareness'
    end
    assert awareness_suggestions.count > 0
  end

  test "should handle invalid stage" do
    get for_stage_api_v1_journey_suggestions_url('invalid_stage'), as: :json
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal false, response_data['success']
    assert_equal 'Invalid stage specified', response_data['message']
    assert_equal 'INVALID_STAGE', response_data['code']
  end

  test "should get suggestions for step" do
    step_params = {
      type: 'lead_magnet',
      stage: 'awareness',
      previous_steps: [],
      journey_context: {}
    }

    get for_step_api_v1_journey_suggestions_url, params: step_params, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['suggestions'].is_a?(Array)
  end

  test "should get bulk suggestions" do
    bulk_params = {
      journey_id: @journey.id,
      count: 3,
      stages: ['awareness', 'consideration']
    }

    post bulk_suggestions_api_v1_journey_suggestions_url, params: bulk_params, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['bulk_suggestions']
    assert response_data['data']['bulk_suggestions']['awareness']
    assert response_data['data']['bulk_suggestions']['consideration']
    assert response_data['data']['journey_context']
  end

  test "should get personalized suggestions" do
    persona = @user.personas.create!(
      name: "Test Persona",
      age_range: "25-35",
      location: "Urban"
    )
    
    campaign = @user.campaigns.create!(
      name: "Test Campaign",
      campaign_type: "email_nurture",
      persona: persona
    )

    personalized_params = {
      persona_id: persona.id,
      campaign_id: campaign.id,
      journey_id: @journey.id
    }

    post personalized_suggestions_api_v1_journey_suggestions_url, params: personalized_params, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['suggestions'].is_a?(Array)
    assert response_data['data']['personalization_context']
  end

  test "should create feedback" do
    feedback_params = {
      suggestion_id: 'test-suggestion-001',
      feedback_type: 'quality',
      rating: 4,
      comment: 'Great suggestion!',
      journey_id: @journey.id
    }

    assert_difference('SuggestionFeedback.count') do
      post feedback_api_v1_journey_suggestions_url, params: feedback_params, as: :json
    end

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 'Feedback recorded successfully', response_data['message']
    
    feedback = SuggestionFeedback.last
    assert_equal 'test-suggestion-001', feedback.suggestion_id
    assert_equal 4, feedback.rating
    assert_equal @user.id, feedback.user_id
  end

  test "should get feedback analytics" do
    # Create some test feedback
    @user.suggestion_feedbacks.create!(
      suggestion_id: 'test-1',
      feedback_type: 'quality',
      rating: 5,
      journey_id: @journey.id
    )

    get feedback_analytics_api_v1_journey_suggestions_url, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['total_feedback_count']
    assert response_data['data']['average_rating']
    assert response_data['data']['feedback_by_type']
  end

  test "should get suggestion history" do
    get suggestion_history_api_v1_journey_suggestions_url, params: { journey_id: @journey.id }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['suggestions_generated']
    assert response_data['data']['suggestions_used']
  end

  test "should refresh cache" do
    post refresh_cache_api_v1_journey_suggestions_url, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 'Suggestion cache refreshed successfully', response_data['message']
  end

  test "should require authentication" do
    sign_out
    
    get api_v1_journey_suggestions_url, as: :json
    assert_response :unauthorized
  end

  test "should handle feedback creation errors" do
    feedback_params = {
      suggestion_id: '', # Invalid: empty suggestion_id
      feedback_type: 'quality',
      rating: 4
    }

    post feedback_api_v1_journey_suggestions_url, params: feedback_params, as: :json
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal false, response_data['success']
    assert_match(/Failed to record feedback/, response_data['message'])
  end

  private

  def sign_in_as(user)
    post session_path, params: { 
      email_address: user.email_address, 
      password: "password" 
    }
  end

  def sign_out
    delete session_path
  end
end