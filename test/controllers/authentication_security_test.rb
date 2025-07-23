require "test_helper"

class AuthenticationSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
  end
  
  test "session expires after timeout period" do
    # Sign in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    session = @user.sessions.last
    
    # Fast forward past session timeout
    travel_to (Session::SESSION_TIMEOUT + 1.minute).from_now do
      get profile_path  # Use protected route
      assert_redirected_to sign_in_path
    end
  end
  
  test "session expires after inactivity timeout" do
    # Sign in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    session = @user.sessions.last
    
    # Update last_active_at to simulate inactivity
    session.update!(last_active_at: (Session::INACTIVE_TIMEOUT + 1.minute).ago)
    
    get profile_path  # Use protected route
    assert_redirected_to sign_in_path
  end
  
  test "session activity is tracked on each request" do
    # Sign in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    session = @user.sessions.last
    initial_activity = session.last_active_at
    
    # Make a request after a short delay
    travel_to 1.minute.from_now do
      get profile_path  # Use a protected route
      assert_response :success
      
      session.reload
      assert session.last_active_at > initial_activity
    end
  end
  
  test "remember me extends session timeout" do
    # Sign in with remember me
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123",
      remember_me: "1"
    }
    
    session = @user.sessions.last
    
    # Check that session has extended timeout
    assert session.expires_at > 25.days.from_now
    assert session.expires_at < 31.days.from_now
  end
  
  test "sign out terminates the session" do
    # Sign in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    session = @user.sessions.last
    
    # Sign out
    delete session_path
    
    # Session should be destroyed
    assert_nil Session.find_by(id: session.id)
    assert_redirected_to new_session_path
  end
  
  test "concurrent sessions are supported" do
    # First session
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }, headers: { "User-Agent" => "Browser 1" }
    
    first_session = @user.sessions.last
    first_cookie = cookies[:session_id]
    
    # Clear cookies to simulate different browser
    cookies.delete(:session_id)
    
    # Second session
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }, headers: { "User-Agent" => "Browser 2" }
    
    second_session = @user.sessions.last
    second_cookie = cookies[:session_id]
    
    # Both sessions should exist
    assert_not_equal first_session.id, second_session.id
    assert_not_equal first_cookie, second_cookie
    assert_equal 2, @user.sessions.active.count
  end
  
  test "invalid session cookie is handled gracefully" do
    cookies[:session_id] = "invalid_session_id"
    
    get profile_path  # Use protected route
    assert_redirected_to sign_in_path
  end
  
  test "session hijacking protection with IP validation" do
    # Sign in from one IP
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }, env: { "REMOTE_ADDR" => "192.168.1.1" }
    
    session = @user.sessions.last
    assert_equal "192.168.1.1", session.ip_address
    
    # Try to use session from different IP (would need additional implementation)
    # This test documents expected behavior for future enhancement
  end
end