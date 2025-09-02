require 'test_helper'

class JourneysAiActionsTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
    @brand_identity = brand_identities(:active_brand)
    @brand_identity.update!(is_active: true)
    
    sign_in_as(@user)
  end

  test "suggestions action returns AI-powered suggestions when brand exists" do
    get suggestions_journey_path(@journey), params: { limit: 3 }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_not_nil json_response['suggestions']
    assert json_response['suggestions'].length <= 3
    assert_includes [true, false], json_response['ai_powered']
  end

  test "suggestions action falls back to rule-based when no brand identity" do
    BrandIdentity.where(user: @user).update_all(is_active: false)
    
    get suggestions_journey_path(@journey), params: { limit: 5 }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_not_nil json_response['suggestions']
    assert_equal false, json_response['ai_powered']
  end

  test "apply_ai_suggestion creates new journey step" do
    suggestion = {
      title: "AI Generated Welcome Email",
      description: "Personalized welcome message",
      step_type: "email",
      channels: ["email"],
      timing: "immediate",
      brand_compliance_score: 92
    }
    
    assert_difference '@journey.journey_steps.count', 1 do
      post apply_ai_suggestion_journey_path(@journey), 
           params: { suggestion: suggestion.to_json },
           headers: { 'Accept' => 'application/json' }
    end
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['success']
    
    # Check the created step
    new_step = @journey.journey_steps.last
    assert_equal "AI Generated Welcome Email", new_step.name
    assert new_step.ai_generated
    assert_equal 92, new_step.brand_compliance_score
  end

  test "apply_ai_suggestion validates suggestion data" do
    post apply_ai_suggestion_journey_path(@journey), 
         params: { suggestion: "" },
         headers: { 'Accept' => 'application/json' }
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert json_response['error']
  end

  test "ai_feedback records user feedback on suggestions" do
    post ai_feedback_journey_path(@journey),
         params: { 
           suggestion_index: 0,
           feedback: 'helpful'
         },
         headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 'Feedback recorded', json_response['message']
  end

  test "ai_feedback requires both parameters" do
    post ai_feedback_journey_path(@journey),
         params: { feedback: 'helpful' },
         headers: { 'Accept' => 'application/json' }
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert json_response['error']
  end

  test "ai_optimization_insights generates journey insights" do
    # Add some AI-generated steps with performance data
    @journey.journey_steps.create!(
      name: "AI Step",
      ai_generated: true,
      performance_metrics: { engagement_rate: 75 }
    )
    
    get ai_optimization_insights_journey_path(@journey),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_not_nil json_response['optimizations']
    assert_not_nil json_response['predicted_improvement']
    assert_not_nil json_response['confidence_score']
  end

  test "enable_ai_optimization toggles AI optimization setting" do
    # Enable AI optimization
    post enable_ai_optimization_journey_path(@journey),
         params: { enabled: 'true' },
         headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['enabled']
    
    @journey.reload
    assert @journey.ai_optimization_enabled
    
    # Disable AI optimization
    post enable_ai_optimization_journey_path(@journey),
         params: { enabled: 'false' },
         headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_not json_response['enabled']
    
    @journey.reload
    assert_not @journey.ai_optimization_enabled
  end

  test "generate_with_ai creates journey steps from natural language" do
    prompt = "Create a 3-step email nurture sequence for new customers"
    
    post generate_with_ai_journey_path(@journey),
         params: { prompt: prompt },
         headers: { 'Accept' => 'application/json' }
    
    json_response = JSON.parse(response.body)
    
    if json_response['success']
      assert_not_nil json_response['steps']
      assert json_response['steps'].is_a?(Array)
    else
      # Handle graceful failure
      assert_not_nil json_response['error']
    end
  end

  test "generate_with_ai requires prompt parameter" do
    post generate_with_ai_journey_path(@journey),
         params: {},
         headers: { 'Accept' => 'application/json' }
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert json_response['error']
  end

  test "AI actions require authentication" do
    sign_out
    
    # Test each AI action without authentication
    get suggestions_journey_path(@journey)
    assert_redirected_to new_session_path
    
    post apply_ai_suggestion_journey_path(@journey)
    assert_redirected_to new_session_path
    
    post ai_feedback_journey_path(@journey)
    assert_redirected_to new_session_path
    
    get ai_optimization_insights_journey_path(@journey)
    assert_redirected_to new_session_path
    
    post enable_ai_optimization_journey_path(@journey)
    assert_redirected_to new_session_path
    
    post generate_with_ai_journey_path(@journey)
    assert_redirected_to new_session_path
  end

  test "AI actions prevent cross-user access" do
    other_user = users(:two)
    other_journey = journeys(:conversion_journey)
    other_journey.update!(user: other_user)
    
    # Try to access other user's journey AI features
    get suggestions_journey_path(other_journey)
    assert_response :not_found
    
    post apply_ai_suggestion_journey_path(other_journey)
    assert_response :not_found
    
    post ai_feedback_journey_path(other_journey)
    assert_response :not_found
  end

  test "suggestions respects stage parameter" do
    @journey.update!(stages: ['awareness', 'consideration', 'decision'])
    
    get suggestions_journey_path(@journey), 
        params: { stage: 'consideration', limit: 3 }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 'consideration', json_response['current_stage']
  end

  test "apply_ai_suggestion increments AI applied count" do
    initial_count = @journey.ai_applied_count || 0
    
    suggestion = {
      title: "Test Suggestion",
      description: "Test",
      step_type: "email"
    }
    
    post apply_ai_suggestion_journey_path(@journey),
         params: { suggestion: suggestion.to_json },
         headers: { 'Accept' => 'application/json' }
    
    @journey.reload
    assert_equal initial_count + 1, @journey.ai_applied_count
  end

  test "AI suggestions include brand compliance scores" do
    get suggestions_journey_path(@journey), params: { limit: 3 }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    
    json_response['suggestions'].each do |suggestion|
      if suggestion['ai_generated']
        assert_not_nil suggestion['brand_compliance_score']
        assert suggestion['brand_compliance_score'].between?(0, 100)
      end
    end
  end

  test "handles malformed JSON in suggestion data gracefully" do
    post apply_ai_suggestion_journey_path(@journey),
         params: { suggestion: "not valid json{" },
         headers: { 'Accept' => 'application/json' }
    
    # Should handle error gracefully
    assert_response :unprocessable_entity
    
    json_response = JSON.parse(response.body)
    assert json_response['error']
  end
end