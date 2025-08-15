require "test_helper"

class ActivityMonitoringTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
    @session = Session.create!(user: @user, ip_address: "127.0.0.1", user_agent: "test")
    Current.session = @session
  end

  teardown do
    Current.reset
    Rails.cache.clear
  end

  test "logs user activity on controller actions" do
    sign_in_as(@user)
    
    assert_difference -> { logs_containing("USER_ACTIVITY").count } do
      get journeys_path
    end
    
    activity_log = logs_containing("USER_ACTIVITY").last
    assert_includes activity_log, @user.id.to_s
    assert_includes activity_log, "journeys"
    assert_includes activity_log, "index"
  end

  test "detects rapid requests pattern" do
    sign_in_as(@user)
    
    # Make 6 rapid requests in quick succession to trigger the alert
    # Each request should be added to session[:recent_activities]
    6.times do |i|
      get journeys_path
      # Small sleep to ensure timestamps are different but within 10-second window
      sleep(0.1) if i < 5
    end
    
    # Make one final request that should trigger the alert
    get journeys_path
    
    # Check if any security alert was logged
    security_logs = logs_containing("SECURITY_ALERT")
    assert security_logs.any?, "Should have generated security alert for rapid requests"
    alert_log = security_logs.last
    assert_includes alert_log, "rapid_requests"
  end

  test "detects unusual navigation patterns" do
    sign_in_as(@user)
    
    # Simulate direct access to sensitive area without normal navigation
    session[:recent_activities] = [
      { controller: "other", action: "show", timestamp: 2.minutes.ago.to_i, ip: "127.0.0.1" },
      { controller: "other", action: "index", timestamp: 1.minute.ago.to_i, ip: "127.0.0.1" }
    ]
    
    # Make admin a sensitive controller for test
    admin_controller_class = Class.new(ApplicationController) do
      def index
        render plain: "admin index"
      end
    end
    
    # This would trigger unusual navigation detection in real implementation
    # Create a test controller that includes ActivityMonitoring
    test_controller = Class.new(ApplicationController) do
      include ActivityMonitoring
      
      def controller_name
        "admin"
      end
      
      def session
        { recent_activities: [
          { "controller" => "other", "action" => "show", "timestamp" => 2.minutes.ago.to_i, "ip" => "127.0.0.1" },
          { "controller" => "other", "action" => "index", "timestamp" => 1.minute.ago.to_i, "ip" => "127.0.0.1" },
          { "controller" => "admin", "action" => "index", "timestamp" => Time.current.to_i, "ip" => "127.0.0.1" }
        ] }
      end
    end.new
    
    assert test_controller.send(:unusual_navigation_pattern?)
  end

  test "filters sensitive parameters from logs" do
    sign_in_as(@user)
    
    patch profile_path, params: {
      user: {
        first_name: "Updated",
        password: "secret123",
        password_confirmation: "secret123"
      }
    }
    
    activity_log = logs_containing("USER_ACTIVITY").last
    refute_includes activity_log, "secret123"
    assert_includes activity_log, "Updated"
  end

  test "handles suspicious activity indicators" do
    sign_in_as(@user)
    
    # Make 6 rapid requests to trigger suspicious activity detection
    6.times do |i|
      get journeys_path
      sleep(0.1) if i < 5  # Small delay but within 10-second window
    end
    
    # Count current alerts
    initial_alert_count = logs_containing("SECURITY_ALERT").count
    
    # This should trigger suspicious activity detection
    get journeys_path
    
    # Verify we got at least one more alert
    final_alert_count = logs_containing("SECURITY_ALERT").count
    assert final_alert_count > initial_alert_count, "Should have generated at least one more security alert"
  end

  test "stores activity in session correctly" do
    sign_in_as(@user)
    
    get journeys_path
    
    # Check that activity was stored in session
    assert session[:recent_activities].present?
    
    last_activity = session[:recent_activities].last
    assert_equal "journeys", last_activity[:controller]
    assert_equal "index", last_activity[:action]
    assert last_activity[:timestamp].present?
  end

  test "maintains activity history limit" do
    sign_in_as(@user)
    
    # Generate more than 20 activities
    25.times do |i|
      get journeys_path
    end
    
    # Should keep only last 20
    assert_equal 20, session[:recent_activities].length
  end

  test "integrates with security monitoring service" do
    sign_in_as(@user)
    
    # Test that SecurityMonitoringService is called by checking logs
    # Make rapid requests to trigger suspicious activity
    6.times do |i|
      get journeys_path
      sleep(0.1) if i < 5
    end
    
    # Count current alerts
    initial_alert_count = logs_containing("SECURITY_ALERT").count
    
    # This should trigger security monitoring service integration
    get journeys_path
    
    # Verify we got at least one more alert
    final_alert_count = logs_containing("SECURITY_ALERT").count
    assert final_alert_count > initial_alert_count, "Should have generated at least one more security alert"
  end

  test "skips monitoring for unauthenticated users" do
    # Don't sign in
    
    assert_no_difference -> { logs_containing("USER_ACTIVITY").count } do
      get root_path
    end
  end

  test "handles missing session gracefully" do
    # Clear current session
    Current.session = nil
    
    assert_nothing_raised do
      get root_path
    end
  end

end