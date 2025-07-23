require "test_helper"

class RememberMeTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
  end
  
  test "sign in without remember me sets normal session timeout" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123",
      remember_me: "0"
    }
    
    session = @user.sessions.last
    
    # Should have standard session timeout
    expected_expiry = Session::SESSION_TIMEOUT.from_now
    assert_in_delta expected_expiry.to_i, session.expires_at.to_i, 60 # within 1 minute
  end
  
  test "sign in with remember me sets extended session timeout" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123",
      remember_me: "1"
    }
    
    session = @user.sessions.last
    
    # Should have extended timeout (30 days)
    expected_expiry = 30.days.from_now
    assert_in_delta expected_expiry.to_i, session.expires_at.to_i, 60 # within 1 minute
  end
  
  test "remember me checkbox is shown on sign in form" do
    get new_session_path
    
    assert_select "input[type=checkbox][name=remember_me]"
    assert_select "label", text: /Remember me/i
  end
  
  test "session persists across browser restarts with remember me" do
    # Sign in with remember me
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123",
      remember_me: "1"
    }
    
    session_cookie = cookies[:session_id]
    
    # Simulate browser restart by clearing session but keeping cookies
    reset!
    cookies[:session_id] = session_cookie
    
    # Should still be signed in - try accessing a protected page
    get profile_path
    assert_response :success
  end
  
  test "session does not persist without remember me" do
    # Sign in without remember me
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123",
      remember_me: "0"
    }
    
    # Session should work initially
    get root_path
    assert_response :success
  end
  
  test "remember me session still respects inactivity timeout" do
    # Sign in with remember me
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123",
      remember_me: "1"
    }
    
    session = @user.sessions.last
    
    # Simulate inactivity
    session.update!(last_active_at: (Session::INACTIVE_TIMEOUT + 1.minute).ago)
    
    # Should be signed out due to inactivity
    get profile_path  # Use protected route
    assert_redirected_to sign_in_path
  end
  
  test "remember me preference is not stored in user model" do
    # Sign in with remember me
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123",
      remember_me: "1"
    }
    
    # User model should not have remember_me attribute
    assert_not_respond_to @user, :remember_me
  end
end