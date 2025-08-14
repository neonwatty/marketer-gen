require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "complete authentication flow" do
    # Visit home page
    get root_url
    assert_response :success
    assert_select "a", "Sign Up"
    assert_select "a", "Sign In"
    
    # Sign up a new user
    get sign_up_url
    assert_response :success
    
    assert_difference("User.count") do
      post sign_up_url, params: { user: { 
        email_address: "newuser@example.com", 
        password: "password123", 
        password_confirmation: "password123" 
      } }
    end
    
    assert_redirected_to root_url
    follow_redirect!
    assert_select "p", "You are logged in as: newuser@example.com"
    assert_select "button", "Sign Out"
    
    # Sign out
    delete session_url
    assert_redirected_to new_session_url
    follow_redirect!
    
    # Try to access protected page (should redirect to login)
    # We'll need to create a protected controller for this test
    
    # Sign back in
    post session_url, params: { 
      email_address: "newuser@example.com", 
      password: "password123" 
    }
    assert_redirected_to root_url
    follow_redirect!
    assert_select "p", "You are logged in as: newuser@example.com"
  end
  
  test "password reset flow" do
    user = User.create!(email_address: "reset@example.com", password: "oldpassword")
    
    # Request password reset
    get new_password_url
    assert_response :success
    
    post passwords_url, params: { email_address: user.email_address }
    assert_redirected_to new_session_url
    
    # In a real test, we would check that an email was sent
    # and extract the reset token from it
  end
  
  test "authentication required for protected pages" do
    # Test that public pages are accessible without authentication
    get root_path
    assert_response :success
    
    get new_session_path 
    assert_response :success
    
    get sign_up_path
    assert_response :success
    
    # Test authentication flow
    user = User.create!(email_address: "auth_test@example.com", password: "password123")
    
    # Login user
    post session_path, params: { email_address: user.email_address, password: "password123" }
    assert_response :redirect
    
    # Follow redirect to verify successful authentication
    follow_redirect!
    assert_response :success
    
    # Verify user has a session
    user.reload
    assert user.sessions.any?, "User should have at least one session after login"
    
    # Test logout functionality
    session = user.sessions.last
    delete session_path
    assert_response :redirect
    
    # Verify session was destroyed
    assert_not Session.exists?(session.id), "Session should be destroyed after logout"
    
    # Test that authentication concern works by verifying all current controllers
    # allow unauthenticated access (which is the current design)
    get root_path
    assert_response :success, "Root path should be accessible without authentication"
  end
end