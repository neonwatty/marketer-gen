require "test_helper"

class JourneySecurityIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @journey = journeys(:awareness_journey) # Belongs to @user
    @other_journey = journeys(:conversion_journey) # Belongs to @other_user
    @journey_step = journey_steps(:awareness_step_one)
  end

  # Authentication Tests
  test "requires authentication for all journey actions" do
    # Journey controller actions
    get journeys_path
    assert_redirected_to new_session_path
    
    get journey_path(@journey)
    assert_redirected_to new_session_path
    
    get new_journey_path
    assert_redirected_to new_session_path
    
    post journeys_path, params: { journey: { name: "Test" } }
    assert_redirected_to new_session_path
    
    get edit_journey_path(@journey)
    assert_redirected_to new_session_path
    
    patch journey_path(@journey), params: { journey: { name: "Updated" } }
    assert_redirected_to new_session_path
    
    delete journey_path(@journey)
    assert_redirected_to new_session_path
    
    patch reorder_steps_journey_path(@journey), params: { step_ids: [] }
    assert_redirected_to new_session_path
  end

  test "requires authentication for all journey step actions" do
    # Journey steps controller actions
    get new_journey_journey_step_path(@journey)
    assert_redirected_to new_session_path
    
    post journey_journey_steps_path(@journey), params: { journey_step: { title: "Test" } }
    assert_redirected_to new_session_path
    
    get edit_journey_journey_step_path(@journey, @journey_step)
    assert_redirected_to new_session_path
    
    patch journey_journey_step_path(@journey, @journey_step), params: { journey_step: { title: "Updated" } }
    assert_redirected_to new_session_path
    
    delete journey_journey_step_path(@journey, @journey_step)
    assert_redirected_to new_session_path
  end

  # Authorization Tests
  test "prevents access to other users journeys" do
    sign_in_as(@user)
    
    # Should not be able to view other user's journey
    get journey_path(@other_journey)
    assert_response :not_found
    
    # Should not be able to edit other user's journey
    get edit_journey_path(@other_journey)
    assert_response :not_found
    
    # Should not be able to update other user's journey
    patch journey_path(@other_journey), params: { journey: { name: "Hacked" } }
    assert_response :not_found
    
    # Should not be able to delete other user's journey
    delete journey_path(@other_journey)
    assert_response :not_found
    
    # Should not be able to reorder other user's journey steps
    patch reorder_steps_journey_path(@other_journey), params: { step_ids: [] }
    assert_response :not_found
  end

  test "prevents access to other users journey steps" do
    sign_in_as(@user)
    other_step = @other_journey.journey_steps.first
    
    # Should not be able to access other user's journey steps
    get new_journey_journey_step_path(@other_journey)
    assert_response :not_found
    
    post journey_journey_steps_path(@other_journey), params: { journey_step: { title: "Hacked" } }
    assert_response :not_found
    
    get edit_journey_journey_step_path(@other_journey, other_step)
    assert_response :not_found
    
    patch journey_journey_step_path(@other_journey, other_step), params: { journey_step: { title: "Hacked" } }
    assert_response :not_found
    
    delete journey_journey_step_path(@other_journey, other_step)
    assert_response :not_found
  end

  # Parameter Security Tests
  test "prevents mass assignment of protected attributes" do
    sign_in_as(@user)
    
    # Try to assign user_id directly (should be ignored)
    post journeys_path, params: {
      journey: {
        name: "Test Journey",
        campaign_type: "awareness",
        status: "draft",
        user_id: @other_user.id # Attempting to assign to other user
      }
    }
    
    journey = Journey.last
    assert_equal @user.id, journey.user_id # Should remain current user
    assert_not_equal @other_user.id, journey.user_id
  end

  test "validates step IDs belong to journey in reorder action" do
    sign_in_as(@user)
    
    # Create step for other journey
    other_step = @other_journey.journey_steps.create!(
      title: "Other Step",
      step_type: "email",
      sequence_order: 10  # Use high number to avoid conflicts
    )
    
    # Try to include other user's step in reorder
    patch reorder_steps_journey_path(@journey), params: {
      step_ids: [other_step.id] # Step belongs to different journey
    }
    
    assert_response :not_found
  end

  # CSRF Protection Tests
  test "requires CSRF token for state-changing operations" do
    skip "CSRF protection test needs better setup"
  end

  # Input Validation Security Tests
  test "prevents XSS in journey fields" do
    sign_in_as(@user)
    
    malicious_script = "<script>alert('xss')</script>"
    
    post journeys_path, params: {
      journey: {
        name: "Safe Journey #{malicious_script}",
        description: "Safe description #{malicious_script}",
        campaign_type: "awareness",
        status: "draft"
      }
    }
    
    journey = Journey.last
    follow_redirect!
    
    # Script tags should be escaped in output
    assert_no_match /<script>/, response.body
    assert_match /&lt;script&gt;/, response.body
  end

  test "prevents SQL injection in filters" do
    sign_in_as(@user)
    
    # Attempt SQL injection in filter parameters
    malicious_sql = "'; DROP TABLE journeys; --"
    
    # Should not raise SQL errors
    assert_nothing_raised do
      get journeys_path, params: { 
        campaign_type: malicious_sql,
        template_type: malicious_sql,
        status: malicious_sql
      }
    end
    
    assert_response :success
    # Journeys table should still exist
    assert Journey.table_exists?
  end

  # File Upload Security (if implemented)
  test "validates file uploads if journey attachments added" do
    skip "TODO: Fix during incremental development"
    # This test would be relevant if file uploads are added later
    skip "File upload functionality not yet implemented"
  end

  # Rate Limiting (if implemented)
  test "handles rapid successive requests gracefully" do
    sign_in_as(@user)
    
    # Make rapid requests
    10.times do |i|
      post journeys_path, params: {
        journey: {
          name: "Rapid Journey #{i}",
          campaign_type: "awareness", 
          status: "draft"
        }
      }
      # Should not raise errors or timeouts
      assert_response :redirect
    end
  end

  # Session Security
  test "invalidates actions after session expires" do
    sign_in_as(@user)
    
    # Verify user is signed in
    get journeys_path
    assert_response :success
    
    # Simulate session expiration
    reset!
    
    # Should require re-authentication
    get journeys_path
    assert_redirected_to new_session_path
  end

  # Integer Overflow Protection
  test "handles large sequence order values" do
    sign_in_as(@user)
    
    large_number = 2**31 - 1 # Max 32-bit integer
    
    post journey_journey_steps_path(@journey), params: {
      journey_step: {
        title: "Large Sequence Step",
        step_type: "email",
        sequence_order: large_number
      }
    }
    
    # Should handle gracefully without overflow
    assert_response :redirect
    step = JourneyStep.last
    assert step.sequence_order >= 0
  end

  # Edge Cases
  test "handles malformed JSON in reorder request" do
    sign_in_as(@user)
    
    # Verify authentication worked
    get journeys_path
    assert_response :success
    
    # Send malformed request
    patch reorder_steps_journey_path(@journey), 
          params: "malformed json",
          headers: { "Content-Type" => "application/json" }
    
    # Should handle gracefully
    assert_response :bad_request
  end

  test "handles extremely long parameter values" do
    sign_in_as(@user)
    
    # Verify authentication worked
    get journeys_path
    assert_response :success
    
    very_long_string = "a" * 10000
    
    post journeys_path, params: {
      journey: {
        name: very_long_string,
        description: very_long_string,
        campaign_type: "awareness",
        status: "draft"
      }
    }
    
    # Should validate length constraints
    assert_response :unprocessable_entity
  end

  private

end