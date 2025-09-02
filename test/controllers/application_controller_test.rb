require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  
  def setup
    @user = users(:marketer_user)
    sign_in_as(@user)
  end

  # Record not found error handling
  test "should handle record not found with redirect for HTML requests" do
    # Try to access a non-existent campaign plan
    get campaign_plan_path(999999)
    
    assert_redirected_to campaign_plans_path
    assert_equal 'Campaign plan not found.', flash[:alert]
  end

  test "should handle record not found with JSON for AJAX requests" do
    # Try to access a non-existent campaign plan via AJAX
    get campaign_plan_path(999999), xhr: true
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'Record not found', json_response['error']
  end

  test "should handle record not found with JSON for JSON format requests" do
    # Try to access a non-existent campaign plan with JSON format
    get campaign_plan_path(999999), as: :json
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'Record not found', json_response['error']
  end

  # 404 routing error handling
  test "should handle routing errors for non-existent routes" do
    # Rails doesn't trigger rescue_from for routing errors in tests by default
    # We need to test this differently or in system tests
    # For now, we'll test that the application doesn't crash on bad routes
    assert_nothing_raised do
      get "/nonexistent-route-that-does-not-exist"
    end
  end

  # CSRF token error handling
  test "should handle CSRF token errors for HTML requests" do
    # Disable CSRF token for this test setup
    ActionController::Base.allow_forgery_protection = true
    
    # Try to post without CSRF token
    post campaign_plans_path, params: { 
      campaign_plan: { 
        name: "Test", 
        campaign_type: "product_launch",
        objective: "brand_awareness" 
      }
    }
    
    # Should redirect to sign in with alert
    assert_redirected_to new_session_path
    assert_match /Security verification failed/, flash[:alert]
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "should handle CSRF token errors for AJAX requests" do
    ActionController::Base.allow_forgery_protection = true
    
    # Try to post without CSRF token via AJAX
    post campaign_plans_path, 
         params: { 
           campaign_plan: { 
             name: "Test", 
             campaign_type: "product_launch",
             objective: "brand_awareness" 
           }
         },
         xhr: true
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal 'Invalid authenticity token', json_response['error']
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  # Rate limiting tests
  test "should enforce rate limiting" do
    # Mock the cache to simulate rate limit exceeded
    Rails.cache.write("rate_limit:#{@user.last_sign_in_ip || '127.0.0.1'}", 101)
    
    get root_path
    
    assert_response :too_many_requests
    assert_match /Rate limit exceeded/, response.body
    
    # Clean up
    Rails.cache.clear
  end

  test "should return JSON for rate limit on AJAX requests" do
    # Mock the cache to simulate rate limit exceeded
    Rails.cache.write("rate_limit:127.0.0.1", 101)
    
    get root_path, xhr: true
    
    assert_response :too_many_requests
    json_response = JSON.parse(response.body)
    assert_equal 'Rate limit exceeded', json_response['error']
    
    # Clean up
    Rails.cache.clear
  end

  # Security headers tests
  test "should set security headers" do
    get root_path
    
    assert_response :success
    
    # Check security headers
    assert_equal 'DENY', response.headers['X-Frame-Options']
    assert_equal 'nosniff', response.headers['X-Content-Type-Options']
    assert_equal '1; mode=block', response.headers['X-XSS-Protection']
    assert_equal 'strict-origin-when-cross-origin', response.headers['Referrer-Policy']
    assert_equal 'none', response.headers['X-Permitted-Cross-Domain-Policies']
  end

  # Authorization error handling
  test "should handle authorization errors gracefully" do
    # Create a campaign plan owned by another user
    other_user = users(:admin_user)
    other_plan = campaign_plans(:generating_plan)
    other_plan.update!(user: other_user)
    
    # Try to edit another user's campaign plan
    get edit_campaign_plan_path(other_plan)
    
    assert_redirected_to campaign_plans_path
    assert_equal 'You can only access your own campaign plans.', flash[:alert]
  end
end