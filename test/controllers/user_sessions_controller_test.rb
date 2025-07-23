require "test_helper"

class UserSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
    
    # Create multiple sessions for testing
    @session1 = @user.sessions.create!(
      user_agent: "Chrome/91.0",
      ip_address: "192.168.1.1",
      expires_at: 1.day.from_now,
      last_active_at: 1.hour.ago
    )
    
    @session2 = @user.sessions.create!(
      user_agent: "Firefox/89.0",
      ip_address: "192.168.1.2",
      expires_at: 2.days.from_now,
      last_active_at: 30.minutes.ago
    )
    
    # Sign in to create current session
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    @current_session = @user.sessions.last
  end
  
  test "should get index when signed in" do
    get user_sessions_path
    assert_response :success
    
    # Should show all active sessions
    assert_select "h1", "Active Sessions"
    assert_select ".bg-white.rounded-lg.shadow", count: 3 # All sessions
    assert_select ".ring-2.ring-blue-500", count: 1 # Current session highlighted
  end
  
  test "should redirect to sign in when not authenticated" do
    delete session_path # Sign out
    
    get user_sessions_path
    assert_redirected_to sign_in_path
  end
  
  test "should show session details" do
    get user_sessions_path
    
    # Check session information is displayed
    assert_match "Chrome", response.body
    assert_match "Firefox", response.body
    assert_match "192.168.1.1", response.body
    assert_match "192.168.1.2", response.body
    assert_match "Last Active:", response.body
    assert_match "Expires:", response.body
  end
  
  test "should show current session indicator" do
    get user_sessions_path
    
    assert_select ".text-blue-600", text: "Current Session"
    assert_select ".text-gray-400", text: "Active"
  end
  
  test "should destroy non-current session" do
    assert_difference("Session.count", -1) do
      delete user_session_path(@session1)
    end
    
    assert_redirected_to user_sessions_path
    assert_equal "Session ended successfully.", flash[:notice]
  end
  
  test "should not destroy current session" do
    assert_no_difference("Session.count") do
      delete user_session_path(@current_session)
    end
    
    assert_redirected_to user_sessions_path
    assert_equal "You cannot end your current session from here. Use Sign Out instead.", flash[:alert]
  end
  
  test "should not destroy another user's session" do
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password123"
    )
    
    other_session = other_user.sessions.create!(
      user_agent: "Safari",
      ip_address: "10.0.0.1"
    )
    
    assert_no_difference("Session.count") do
      delete user_session_path(other_session)
    end
    
    assert_response :not_found
  end
  
  test "should handle non-existent session gracefully" do
    delete user_session_path(999999)
    assert_response :not_found
  end
  
  test "should show security tips" do
    get user_sessions_path
    
    assert_select "h3", text: "Security Tips:"
    assert_match "Review your active sessions regularly", response.body
    assert_match "Sessions automatically expire after", response.body
  end
  
  test "should not show expired sessions" do
    # Clear existing sessions first
    @user.sessions.destroy_all
    
    # Sign in to create new current session
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    # Create an expired session
    expired_session = @user.sessions.create!(
      user_agent: "Old Browser",
      ip_address: "192.168.1.3",
      expires_at: 1.hour.ago
    )
    
    get user_sessions_path
    
    # Should not show expired session
    assert_no_match "Old Browser", response.body
    # Should only show the current active session
    assert_select ".bg-white.rounded-lg.shadow", count: 1
  end
  
  test "should parse user agents correctly" do
    get user_sessions_path
    
    # User agent parsing should work
    assert_match "Chrome 91", response.body
    assert_match "Firefox 89", response.body
  end
  
  
  test "should show profile link to session management" do
    get profile_path
    
    assert_select "a[href=?]", user_sessions_path, text: "Manage Active Sessions"
  end
end
