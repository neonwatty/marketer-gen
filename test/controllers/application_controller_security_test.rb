require "test_helper"

class ApplicationControllerSecurityTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = users(:one)
    # Clear cache to avoid test contamination
    Rails.cache.clear
  end
  
  def teardown
    super
    Rails.cache.clear
  end

  test "should set security headers on all requests" do
    sign_in_as(@user)
    get root_path
    
    assert_equal 'DENY', response.headers['X-Frame-Options']
    assert_equal 'nosniff', response.headers['X-Content-Type-Options']
    assert_equal '1; mode=block', response.headers['X-XSS-Protection']
    assert_equal 'strict-origin-when-cross-origin', response.headers['Referrer-Policy']
    assert_equal 'none', response.headers['X-Permitted-Cross-Domain-Policies']
  end

  test "should enforce rate limiting" do
    sign_in_as(@user)
    
    # Clear any existing rate limit
    Rails.cache.delete("rate_limit:127.0.0.1")
    
    # Make requests up to the limit
    99.times do
      get root_path
      assert_response :success
    end
    
    # The 100th request should still succeed
    get root_path
    assert_response :success
    
    # The 101st request should be rate limited
    get root_path
    assert_response :too_many_requests
  end

  test "should handle parameter parse errors gracefully" do
    sign_in_as(@user)
    
    # Clear rate limiting first
    Rails.cache.delete("rate_limit:127.0.0.1")
    
    # Simulate malformed parameters
    post journeys_path, params: "malformed{json}", headers: {
      'Content-Type' => 'application/json'
    }
    
    assert_response :bad_request
  end

  test "should handle CSRF errors appropriately for AJAX requests" do
    sign_in_as(@user)
    
    # Enable CSRF protection for this test
    old_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    
    begin
      post journeys_path, 
           params: { journey: { name: "Test" } },
           headers: { 
             "X-Requested-With" => "XMLHttpRequest",
             "X-CSRF-Token" => "invalid"
           }
      
      assert_response :unprocessable_entity
      assert_match /Invalid authenticity token/, response.body
    ensure
      ActionController::Base.allow_forgery_protection = old_protection
    end
  end

  test "should redirect unauthorized users appropriately" do
    # Test Pundit authorization error handling
    other_user = users(:two)
    sign_in_as(@user)
    
    # Try to access another user's journey - this should return 404 due to policy scope
    other_journey = journeys(:conversion_journey) # belongs to users(:two)
    
    get journey_path(other_journey)
    # The policy scope should prevent finding the journey, resulting in 404
    assert_response :not_found
  end
end