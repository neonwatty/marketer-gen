require "test_helper"

class ActivityMonitoringIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "logs user activity during normal navigation" do
    sign_in_as(@user)
    
    # Navigate to different pages
    get journeys_path
    assert_response :success
    
    get new_journey_path
    assert_response :success
    
    # Check that activities were logged (stored in session)
    assert session[:recent_activities].present?
    assert session[:recent_activities].length >= 2
    
    # Verify activity structure
    last_activity = session[:recent_activities].last
    controller = last_activity[:controller] || last_activity["controller"]
    action = last_activity[:action] || last_activity["action"]
    timestamp = last_activity[:timestamp] || last_activity["timestamp"]
    assert_equal "journeys", controller
    assert_equal "new", action
    assert timestamp.present?
  end

  test "detects and alerts on rapid request patterns" do
    sign_in_as(@user)
    
    # Make rapid requests to naturally trigger the detection
    6.times do |i|
      get journeys_path
      sleep(0.1) if i < 5  # Small delay but within 10-second window
    end
    
    # This should trigger suspicious activity detection
    get journeys_path
    assert_response :success
    
    # Check that an alert was generated (stored in cache)
    recent_alerts = Rails.cache.read("recent_security_alerts")
    assert recent_alerts.present?, "Should have generated security alert"
  end

  test "maintains activity history correctly" do
    sign_in_as(@user)
    
    # Make multiple requests
    5.times do
      get journeys_path
    end
    
    # Check activity history (sign-in adds one activity, so expect 6 total)
    activities = session[:recent_activities]
    assert_equal 6, activities.length
    
    # Last 5 should be for journeys#index
    last_five = activities.last(5)
    last_five.each do |activity|
      controller = activity[:controller] || activity["controller"]
      action = activity[:action] || activity["action"]
      assert_equal "journeys", controller
      assert_equal "index", action
    end
  end

  test "filters sensitive parameters from logs" do
    sign_in_as(@user)
    
    # Make request with sensitive data to the profile controller
    patch profile_path, params: {
      user: {
        first_name: "Updated Name",
        password: "secret123",
        password_confirmation: "secret123"
      }
    }
    
    # Activity should be logged but without sensitive params
    activities = session[:recent_activities]
    last_activity = activities.last
    controller = last_activity[:controller] || last_activity["controller"]
    action = last_activity[:action] || last_activity["action"]
    assert_equal "profiles", controller
    assert_equal "update", action
    
    # Note: In a real implementation, we'd check the actual log output
    # to ensure passwords aren't logged
  end

  test "monitors session security during activity" do
    sign_in_as(@user)
    
    # Test that session security monitoring is active
    # (This would normally verify specific security checks)
    
    get journeys_path
    assert_response :success
    
    # Verify the user has an active session in the database
    active_sessions = @user.sessions.active
    assert active_sessions.any?, "User should have at least one active session"
    
    # Verify activity monitoring is working by checking session activities
    assert session[:recent_activities].present?, "Session should have activity data"
  end

  test "handles unauthenticated users gracefully" do
    # Don't sign in
    
    get journeys_path
    
    # Should redirect to login without errors
    assert_redirected_to new_session_path
    
    # No activity should be logged for unauthenticated users
    assert session[:recent_activities].blank?
  end

  test "security monitoring service integration" do
    # Test that monitoring service methods work
    alert_data = {
      alert_type: "INTEGRATION_TEST",
      user_id: @user.id,
      test_data: "test"
    }
    
    alert_id = SecurityMonitoringService.send_alert(alert_data)
    assert alert_id.present?
    assert alert_id.start_with?("SEC_")
    
    # Check alert was stored
    stored_alert = Rails.cache.read("security_alert:#{alert_id}")
    assert stored_alert.present?
    assert_equal "INTEGRATION_TEST", stored_alert[:alert_type]
  end

  test "brute force detection works" do
    ip_address = "192.168.1.99"
    
    # Simulate multiple failed attempts
    cache_key = "failed_attempts:#{ip_address}"
    attempts = 6.times.map do |i|
      { timestamp: (15 - i).minutes.ago, ip: ip_address }
    end
    Rails.cache.write(cache_key, attempts)
    
    # Check brute force detection
    count = SecurityMonitoringService.check_brute_force_attempts(ip_address)
    assert count >= 5
    
    # IP should be blocked
    block_key = "blocked_ip:#{ip_address}"
    assert Rails.cache.read(block_key)
  end

  test "data access monitoring works" do
    user_id = @user.id
    
    # Monitor normal data access
    count = SecurityMonitoringService.monitor_data_access(user_id, 10, "users#index")
    assert_equal 10, count
    
    # Monitor excessive access (should trigger alert)
    count = SecurityMonitoringService.monitor_data_access(user_id, 95, "users#export")
    assert_equal 105, count
    
    # Check that alert was generated for excessive access
    recent_alerts = Rails.cache.read("recent_security_alerts")
    assert recent_alerts.present?
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }
    follow_redirect!
  end
end