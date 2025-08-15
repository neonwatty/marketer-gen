require 'test_helper'

class JourneysControllerErrorHandlingTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
  end

  test "suggestions endpoint handles service errors gracefully" do
    sign_in_as(@user)
    
    # Stub service method to raise error
    original_method = JourneySuggestionService.instance_method(:suggest_steps)
    JourneySuggestionService.define_method(:suggest_steps) do |**kwargs|
      raise StandardError.new("Service error")
    end
    
    assert_raises(StandardError) do
      get suggestions_journey_path(@journey)
    end
  ensure
    # Restore original method
    JourneySuggestionService.define_method(:suggest_steps, original_method)
  end

  test "suggestions endpoint handles malformed journey data" do
    sign_in_as(@user)
    
    # Create journey with malformed data by updating directly
    broken_journey = @user.journeys.create!(
      name: "Broken Journey",
      campaign_type: "awareness", # Start with valid type
      status: "draft"
    )
    
    # Update to invalid campaign type bypassing validation and also clear stages
    broken_journey.update_columns(campaign_type: "invalid_type", stages: nil)
    
    get suggestions_journey_path(broken_journey)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # Should return empty suggestions for invalid campaign type with no stages
    assert_empty json_response['suggestions']
  end

  test "suggestions endpoint handles extremely long parameter values" do
    sign_in_as(@user)
    
    # Test with very long stage parameter
    long_stage = "a" * 10000
    
    get suggestions_journey_path(@journey), params: { stage: long_stage }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal long_stage, json_response['current_stage']
  end

  test "suggestions endpoint handles negative limit parameter" do
    sign_in_as(@user)
    
    get suggestions_journey_path(@journey), params: { limit: -5 }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # Should handle negative limit gracefully
    assert json_response['suggestions'].is_a?(Array)
  end

  test "suggestions endpoint handles non-numeric limit parameter" do
    sign_in_as(@user)
    
    get suggestions_journey_path(@journey), params: { limit: "invalid" }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # Should default to 5 suggestions when limit is invalid
    assert json_response['suggestions'].length <= 5
  end

  test "suggestions endpoint handles missing journey gracefully" do
    sign_in_as(@user)
    
    # Try to access non-existent journey
    get "/journeys/99999/suggestions"
    assert_response :not_found
  end

  test "suggestions endpoint handles journey with no stages" do
    sign_in_as(@user)
    
    # Create journey without stages
    journey_no_stages = @user.journeys.create!(
      name: "No Stages Journey",
      campaign_type: "awareness",
      status: "draft"
    )
    journey_no_stages.update_column(:stages, nil)
    
    get suggestions_journey_path(journey_no_stages)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_nil json_response['current_stage']
    assert_nil json_response['available_stages']
    assert json_response['suggestions'].is_a?(Array)
  end

  test "suggestions endpoint handles journey with empty stages array" do
    sign_in_as(@user)
    
    # Create journey with empty stages array
    journey_empty_stages = @user.journeys.create!(
      name: "Empty Stages Journey",
      campaign_type: "awareness",
      status: "draft"
    )
    journey_empty_stages.update_column(:stages, [])
    
    get suggestions_journey_path(journey_empty_stages)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_nil json_response['current_stage']
    assert_equal [], json_response['available_stages']
  end

  test "suggestions endpoint handles special characters in stage parameter" do
    sign_in_as(@user)
    
    special_chars = ['<script>', '&amp;', '"quotes"', "'single'", "\n\r\t"]
    
    special_chars.each do |special_stage|
      get suggestions_journey_path(@journey), params: { stage: special_stage }
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert_equal special_stage, json_response['current_stage']
    end
  end

  test "suggestions endpoint handles very large limit parameter" do
    sign_in_as(@user)
    
    get suggestions_journey_path(@journey), params: { limit: 999999 }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # Should cap at reasonable number
    assert json_response['suggestions'].length <= 50
  end

  test "suggestions endpoint handles zero limit parameter" do
    sign_in_as(@user)
    
    get suggestions_journey_path(@journey), params: { limit: 0 }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_empty json_response['suggestions']
  end

  test "suggestions endpoint handles float limit parameter" do
    sign_in_as(@user)
    
    get suggestions_journey_path(@journey), params: { limit: 3.7 }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # Should convert to integer
    assert json_response['suggestions'].length <= 3
  end

  test "suggestions endpoint handles journey with massive number of existing steps" do
    sign_in_as(@user)
    
    # Create journey with many steps
    test_journey = @user.journeys.create!(
      name: "Many Steps Journey",
      campaign_type: "awareness",
      status: "draft"
    )
    
    # Add many journey steps
    100.times do |i|
      test_journey.journey_steps.create!(
        title: "Step #{i}",
        step_type: "email",
        sequence_order: i
      )
    end
    
    get suggestions_journey_path(test_journey)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['suggestions'].is_a?(Array)
  end

  test "suggestions endpoint handles malformed JSON in journey metadata" do
    sign_in_as(@user)
    
    # Create journey with malformed metadata
    journey_bad_metadata = @user.journeys.create!(
      name: "Bad Metadata Journey",
      campaign_type: "awareness",
      status: "draft"
    )
    
    # Set malformed JSON bypassing serialization
    journey_bad_metadata.update_column(:metadata, "invalid json")
    
    get suggestions_journey_path(journey_bad_metadata)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response['suggestions'].is_a?(Array)
  end

  test "suggestions endpoint handles concurrent requests" do
    sign_in_as(@user)
    
    # Make multiple concurrent requests (simulated)
    results = []
    errors = []
    
    5.times do
      begin
        get suggestions_journey_path(@journey)
        results << response.code
      rescue => e
        errors << e.message
      end
    end
    
    # All requests should succeed
    assert_equal 5, results.length
    assert_empty errors
    results.each { |code| assert_equal "200", code }
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end