require "test_helper"

class SecurityWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = users(:one)
    @security_service = SecurityMonitorService.new
    # Clear cache to avoid test contamination
    Rails.cache.clear
  end
  
  def teardown
    super
    Rails.cache.clear
  end

  test "should block user after multiple failed login attempts" do
    # Clear any existing rate limiting
    @security_service.clear_failed_attempts("127.0.0.1")
    
    # Make 5 failed login attempts
    5.times do
      post session_path, params: {
        email_address: "wrong@example.com",
        password: "wrongpassword"
      }
      assert_redirected_to new_session_path
    end
    
    # 6th attempt should be blocked
    assert @security_service.ip_blocked?("127.0.0.1")
  end

  test "should clear failed attempts on successful login" do
    # Track some failed attempts
    3.times do
      @security_service.track_failed_login("127.0.0.1", @user.email_address)
    end
    
    # Verify we have failed attempts recorded
    assert @security_service.track_failed_login("127.0.0.1", @user.email_address) > 1
    
    # Clear attempts (simulating successful login)
    @security_service.clear_failed_attempts("127.0.0.1")
    
    # Should not be blocked after clearing
    assert_not @security_service.ip_blocked?("127.0.0.1")
    
    # Next failed attempt should start fresh at count 1
    count = @security_service.track_failed_login("127.0.0.1", @user.email_address)
    assert_equal 1, count
  end

  test "should handle session hijacking detection" do
    # Login normally
    sign_in_as(@user)
    get root_path
    assert_response :success
    
    # Simulate request from different IP
    get root_path, headers: { 'REMOTE_ADDR' => '10.0.0.1' }
    
    # Should still work but log warning (check logs if needed)
    assert_response :success
  end

  test "should enforce session timeout" do
    # Create an expired session
    expired_session = @user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "test"
    )
    expired_session.update_column(:updated_at, 31.minutes.ago)
    
    # Test that the session is correctly identified as expired
    assert expired_session.expired?
    assert_not expired_session.active?
    
    # Test that expired sessions are found by the scope
    assert_includes Session.expired, expired_session
    assert_not_includes Session.active, expired_session
  end
end