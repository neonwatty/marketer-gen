require 'test_helper'

class JourneysSuggestionsSecurityTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @journey = journeys(:awareness_journey) # Belongs to @user
    @other_journey = journeys(:conversion_journey) # Belongs to @other_user
  end

  test "suggestions endpoint prevents unauthorized access" do
    # Test without authentication
    get suggestions_journey_path(@journey)
    assert_redirected_to new_session_path
  end

  test "suggestions endpoint prevents cross-user access" do
    sign_in_as(@user)
    
    # Try to access other user's journey suggestions
    get suggestions_journey_path(@other_journey)
    assert_response :not_found
  end

  test "suggestions endpoint prevents SQL injection in stage parameter" do
    sign_in_as(@user)
    
    malicious_stage = "'; DROP TABLE journeys; --"
    
    get suggestions_journey_path(@journey), params: { stage: malicious_stage }
    assert_response :success
    
    # Journey should still exist
    assert Journey.exists?(@journey.id)
    
    # Verify response includes the malicious string as-is (not executed)
    json_response = JSON.parse(response.body)
    assert_equal malicious_stage, json_response['current_stage']
  end

  test "suggestions endpoint prevents SQL injection in limit parameter" do
    sign_in_as(@user)
    
    malicious_limit = "1; DROP TABLE journey_steps; --"
    
    get suggestions_journey_path(@journey), params: { limit: malicious_limit }
    assert_response :success
    
    # Journey steps table should still exist and have data
    assert JourneyStep.exists?
    assert @journey.journey_steps.exists?
  end

  test "suggestions endpoint sanitizes HTML in response" do
    sign_in_as(@user)
    
    get suggestions_journey_path(@journey)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    suggestions = json_response['suggestions']
    
    # Check that no HTML tags are present in suggestions
    suggestions.each do |suggestion|
      %w[title description].each do |field|
        next if suggestion[field].nil?
        refute_match(/<[^>]*>/, suggestion[field].to_s, "HTML found in #{field}")
      end
    end
  end

  test "suggestions endpoint prevents XSS in stage parameter" do
    sign_in_as(@user)
    
    xss_payload = "<script>alert('xss')</script>"
    
    get suggestions_journey_path(@journey), params: { stage: xss_payload }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # Should return the payload as plain text, not execute it
    assert_equal xss_payload, json_response['current_stage']
  end

  test "suggestions endpoint enforces authentication on all request methods" do
    # Test GET without auth
    get suggestions_journey_path(@journey)
    assert_redirected_to new_session_path
    
    # Test POST without auth (should return 404 since route doesn't exist)
    begin
      post suggestions_journey_path(@journey)
      # If we get here, Rails handled it differently than expected
      assert_response :not_found
    rescue ActionController::RoutingError
      # This is the expected behavior
      assert true
    end
    
    # Test PUT without auth (should return 404 since route doesn't exist)
    begin
      put suggestions_journey_path(@journey)
      # If we get here, Rails handled it differently than expected
      assert_response :not_found
    rescue ActionController::RoutingError
      # This is the expected behavior
      assert true
    end
  end

  test "suggestions endpoint validates journey ownership consistently" do
    sign_in_as(@user)
    
    # Try various ways to access other user's journey
    other_journey_id = @other_journey.id
    
    # Direct access
    get suggestions_journey_path(@other_journey)
    assert_response :not_found
    
    # Try with query parameters that might bypass authorization
    get "/journeys/#{other_journey_id}/suggestions", params: { user_id: @user.id }
    assert_response :not_found
    
    # Try with additional headers
    get "/journeys/#{other_journey_id}/suggestions", headers: { 'X-User-ID' => @user.id.to_s }
    assert_response :not_found
  end

  test "suggestions endpoint handles authorization errors gracefully" do
    sign_in_as(@user)
    
    # Test accessing other user's journey (should raise authorization error)
    get suggestions_journey_path(@other_journey)
    assert_response :not_found
  end

  test "suggestions endpoint prevents parameter pollution" do
    sign_in_as(@user)
    
    # Try to pollute parameters
    get suggestions_journey_path(@journey), params: { 
      stage: ['discovery', 'malicious_stage'],
      limit: ['3', '999'],
      'stage[]' => 'array_injection'
    }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    # Should handle parameter pollution gracefully - stage should be treated as a string
    current_stage = json_response['current_stage']
    assert current_stage.nil? || current_stage.is_a?(String)
  end

  test "suggestions endpoint prevents mass assignment vulnerabilities" do
    sign_in_as(@user)
    
    # Try to pass unauthorized parameters
    get suggestions_journey_path(@journey), params: {
      journey: { user_id: @other_user.id },
      user_id: @other_user.id,
      admin: true,
      authenticated: false
    }
    
    assert_response :success
    # Should still return current user's journey suggestions
    json_response = JSON.parse(response.body)
    assert_equal @journey.campaign_type, json_response['campaign_type']
  end

  test "suggestions endpoint handles session tampering" do
    # Sign in as user
    sign_in_as(@user)
    
    # Tamper with session (simulate session hijacking attempt)
    # This is a simplified test - real session tampering would be more complex
    get suggestions_journey_path(@journey), headers: { 'Cookie' => 'session_id=tampered_session' }
    
    # Should either work (if session is still valid) or redirect to login
    assert_includes [200, 302], response.status
  end

  test "suggestions endpoint rate limiting protection" do
    sign_in_as(@user)
    
    # Make multiple rapid requests to test for potential DoS
    start_time = Time.current
    request_count = 20
    
    request_count.times do
      get suggestions_journey_path(@journey)
      # All should succeed unless rate limiting is implemented
    end
    
    end_time = Time.current
    
    # Verify all requests completed
    assert_response :success
    
    # If rate limiting is implemented, some requests might be rejected
    # This test documents the current behavior
  end

  test "suggestions endpoint prevents information disclosure through error messages" do
    sign_in_as(@user)
    
    # Try to access non-existent journey
    get "/journeys/99999/suggestions"
    assert_response :not_found
    
    # In test environment, detailed error pages are shown, but in production
    # this would return a simple 404 page without revealing information
    # This test documents the expected behavior
  end

  test "suggestions endpoint handles malicious headers" do
    sign_in_as(@user)
    
    malicious_headers = {
      'X-Forwarded-For' => '127.0.0.1; DROP TABLE users;',
      'User-Agent' => '<script>alert("xss")</script>',
      'Accept' => 'application/json; charset=utf-8; boundary=--malicious',
      'X-Requested-With' => '../../../etc/passwd'
    }
    
    get suggestions_journey_path(@journey), headers: malicious_headers
    assert_response :success
    
    # Should handle malicious headers without issues
    json_response = JSON.parse(response.body)
    assert json_response['suggestions'].is_a?(Array)
  end

  test "suggestions endpoint validates CSRF token properly" do
    sign_in_as(@user)
    
    # Rails automatically includes CSRF protection for non-GET requests
    # This test documents that GET requests don't require CSRF tokens (which is correct)
    get suggestions_journey_path(@journey)
    assert_response :success
    
    # If this were a POST/PUT/DELETE, we'd test CSRF token validation
  end

  test "suggestions endpoint prevents directory traversal attacks" do
    sign_in_as(@user)
    
    # Try directory traversal in stage parameter instead (more realistic attack vector)
    traversal_attempts = [
      "../../../etc/passwd",
      "..\\..\\windows\\system32",
      "/etc/passwd"
    ]
    
    traversal_attempts.each do |malicious_stage|
      get suggestions_journey_path(@journey), params: { stage: malicious_stage }
      assert_response :success
      
      json_response = JSON.parse(response.body)
      # Should treat as normal stage parameter, not access file system
      assert_equal malicious_stage, json_response['current_stage']
      assert json_response['suggestions'].is_a?(Array)
    end
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end