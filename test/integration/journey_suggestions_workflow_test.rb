require 'test_helper'

class JourneySuggestionsWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
  end

  test "complete journey suggestion workflow" do
    sign_in_as(@user)
    
    # Visit journey page
    get journey_path(@journey)
    assert_response :success
    assert_select '[data-controller="journey-suggestions"]'
    
    # Get suggestions
    get suggestions_journey_path(@journey)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    suggestions = json_response['suggestions']
    assert_not_empty suggestions
    
    # Use first suggestion to create a step
    suggestion = suggestions.first
    
    post journey_journey_steps_path(@journey), params: {
      journey_step: {
        title: suggestion['title'],
        description: suggestion['description'],
        step_type: suggestion['step_type'],
        channel: suggestion['suggested_channels']&.first
      }
    }
    
    # Verify step was created
    follow_redirect!
    assert_response :success
    assert_select '.step-number', text: /3/ # Third step (after existing 2)
  end

  test "suggestion filtering based on existing steps" do
    sign_in_as(@user)
    
    # Create journey with multiple steps
    test_journey = @user.journeys.create!(
      name: "Multi Step Journey",
      campaign_type: "conversion",
      status: "draft"
    )
    
    # Add multiple step types
    %w[email social_post content_piece].each_with_index do |step_type, index|
      test_journey.journey_steps.create!(
        title: "Step #{index + 1}",
        step_type: step_type,
        sequence_order: index
      )
    end
    
    # Get suggestions
    get suggestions_journey_path(test_journey)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    suggested_types = json_response['suggestions'].map { |s| s['step_type'] }
    
    # Should not include existing step types
    %w[email social_post content_piece].each do |existing_type|
      refute_includes suggested_types, existing_type
    end
    
    # Should include other conversion-focused types
    conversion_types = %w[landing_page automation webinar]
    assert (suggested_types & conversion_types).any?
  end

  test "stage parameter affects suggestion results" do
    sign_in_as(@user)
    
    # Get suggestions for discovery stage
    get suggestions_journey_path(@journey), params: { stage: 'discovery' }
    assert_response :success
    
    discovery_response = JSON.parse(response.body)
    assert_equal 'discovery', discovery_response['current_stage']
    discovery_suggestions = discovery_response['suggestions']
    
    # Get suggestions for engagement stage
    get suggestions_journey_path(@journey), params: { stage: 'engagement' }
    assert_response :success
    
    engagement_response = JSON.parse(response.body)
    assert_equal 'engagement', engagement_response['current_stage']
    engagement_suggestions = engagement_response['suggestions']
    
    # Suggestions should be different for different stages (if both have suggestions)
    if discovery_suggestions.any? && engagement_suggestions.any?
      discovery_titles = discovery_suggestions.map { |s| s['title'] }
      engagement_titles = engagement_suggestions.map { |s| s['title'] }
      
      # At least some suggestions should be different
      assert_not_equal discovery_titles.sort, engagement_titles.sort
    end
  end

  test "limit parameter controls number of suggestions" do
    sign_in_as(@user)
    
    # Test different limits
    [1, 3, 5, 10].each do |limit|
      get suggestions_journey_path(@journey), params: { limit: limit }
      assert_response :success
      
      json_response = JSON.parse(response.body)
      suggestions = json_response['suggestions']
      
      assert suggestions.length <= limit, "Should not exceed limit of #{limit}"
    end
  end

  test "suggestions work for different campaign types" do
    sign_in_as(@user)
    
    # Test each campaign type
    Journey::CAMPAIGN_TYPES.each do |campaign_type|
      test_journey = @user.journeys.create!(
        name: "#{campaign_type.humanize} Journey",
        campaign_type: campaign_type,
        status: "draft"
      )
      
      get suggestions_journey_path(test_journey)
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert_equal campaign_type, json_response['campaign_type']
      
      # Should return suggestions or empty array (not error)
      assert json_response['suggestions'].is_a?(Array)
    end
  end

  test "suggestions include enhanced details" do
    sign_in_as(@user)
    
    get suggestions_journey_path(@journey)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    suggestions = json_response['suggestions']
    
    unless suggestions.empty?
      suggestion = suggestions.first
      
      # Core suggestion fields
      %w[step_type title description priority estimated_effort].each do |field|
        assert suggestion.key?(field), "Missing field: #{field}"
        assert_not_nil suggestion[field], "Field #{field} should not be nil"
      end
      
      # Enhanced fields
      assert suggestion.key?('suggested_channels')
      assert suggestion.key?('content_suggestions')
      assert suggestion['suggested_channels'].is_a?(Array)
      assert suggestion['content_suggestions'].is_a?(Hash)
    end
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end