require "test_helper"

class UserSessionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "sessions_user@example.com",
      password: "password123",
      role: "marketer"
    )
  end

  test "user sessions page loads successfully for authenticated user" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    assert_select "h1", "Active Sessions"
  end

  test "user sessions page redirects unauthenticated users" do
    get user_sessions_path
    assert_redirected_to new_session_path
  end

  test "user sessions page displays current session information" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    
    # Check current session section
    assert_select "div", text: /Current Session/
    
    # Should show session details
    assert_select "strong", "IP Address:"
    assert_select "strong", "Browser:"
    assert_select "strong", "Last Active:"
    assert_select "strong", "Expires:"
    
    # Should show Active status
    assert_select "div", "Active"
  end

  test "user sessions page shows session timestamp" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    
    # Should show when the session was created
    current_date = Date.current.strftime("%B %d, %Y")
    assert_select "div", text: /#{current_date}/
  end

  test "user sessions page displays IP address information" do
    sign_in_as(@user, ip: "192.168.1.100")
    
    get user_sessions_path
    assert_response :success
    
    # Should show the IP address from login
    assert_select "p", text: /IP Address:.*192\.168\.1\.100/
  end

  test "user sessions page shows browser information" do
    sign_in_as(@user, user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    
    get user_sessions_path
    assert_response :success
    
    # Should detect and show Chrome browser
    assert_select "p", text: /Browser:.*Chrome/
  end

  test "user sessions page displays session expiration time" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    
    # Should show expiration information
    assert_select "p", text: /Expires:/
    assert_select "p", text: /about 24 hours from now/
  end

  test "user sessions page shows last active time" do
    sign_in_as(@user)
    
    # Wait a moment to ensure time difference
    sleep(1)
    
    get user_sessions_path
    assert_response :success
    
    # Should show last active time
    assert_select "p", text: /Last Active:.*less than a minute ago/
  end

  test "user sessions page includes security tips" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    
    # Check security tips section
    assert_select "h3", "Security Tips:"
    
    # Check for specific security tips
    assert_select "li", text: /Review your active sessions regularly/
    assert_select "li", text: /End sessions on devices you no longer use/
    assert_select "li", text: /If you see an unfamiliar session, end it immediately and change your password/
    assert_select "li", text: /Sessions automatically expire after 24 hours of inactivity/
  end

  test "user sessions page shows mobile device detection" do
    mobile_user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
    
    sign_in_as(@user, user_agent: mobile_user_agent)
    
    get user_sessions_path
    assert_response :success
    
    # Should detect mobile browser
    assert_select "p", text: /Browser:.*Safari/
  end

  test "user sessions page handles different IP addresses" do
    # Test with IPv6 address
    sign_in_as(@user, ip: "::1")
    
    get user_sessions_path
    assert_response :success
    
    # Should show IPv6 address
    assert_select "p", text: /IP Address:.*::1/
  end

  test "user sessions page shows current session as active" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    
    # Current session should be marked as Active
    assert_select "div", "Active"
  end

  test "user sessions page displays session management description" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    
    # Should show description
    assert_select "p", "Manage your active sessions across different devices"
  end

  test "user sessions page shows session duration calculation" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    
    # Should show when session expires (24 hours from creation)
    tomorrow = (Date.current + 1.day).strftime("%B %d, %Y")
    assert_select "p", text: /#{tomorrow}/
  end

  test "user sessions page handles unknown browser gracefully" do
    unknown_user_agent = "CustomBot/1.0"
    
    sign_in_as(@user, user_agent: unknown_user_agent)
    
    get user_sessions_path
    assert_response :success
    
    # Should handle unknown browser
    assert_response :success
    assert_select "strong", "Browser:"
  end

  test "user sessions page refreshes session activity" do
    sign_in_as(@user)
    
    # First visit
    get user_sessions_path
    assert_response :success
    
    # Wait a moment
    sleep(1)
    
    # Second visit should update last active time
    get user_sessions_path
    assert_response :success
    
    assert_select "p", text: /Last Active:.*less than a minute ago/
  end

  test "user sessions page shows proper page structure" do
    sign_in_as(@user)
    
    get user_sessions_path
    assert_response :success
    
    # Check main page structure
    assert_select "main" do
      assert_select "h1", "Active Sessions"
      assert_select "div", text: /Current Session/
      assert_select "h3", "Security Tips:"
    end
  end

  private

  def sign_in_as(user, ip: "127.0.0.1", user_agent: "Rails Test")
    post session_path, 
         params: {
           email_address: user.email_address,
           password: "password123"
         },
         headers: {
           "REMOTE_ADDR" => ip,
           "HTTP_USER_AGENT" => user_agent
         }
  end
end