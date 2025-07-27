require "test_helper"

class ActivityTrackingTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "tracker@example.com",
      password: "password123",
      role: "marketer"
    )
  end

  test "tracks successful login activity" do
    assert_difference "Activity.count", 1 do
      post session_path, params: {
        email_address: @user.email_address,
        password: "password123"
      }
    end

    activity = Activity.last
    assert_equal @user, activity.user
    assert_equal "create", activity.action
    assert_equal "sessions", activity.controller
    assert_equal 302, activity.response_status # Redirect after login
    assert_not activity.suspicious?
  end

  test "tracks failed login activity" do
    # First create the user to track failed login
    post session_path, params: {
      email_address: @user.email_address,
      password: "wrong_password"
    }

    # Since authentication failed, no activity should be tracked
    # (user is not authenticated)
    assert_equal 0, Activity.count
  end

  test "tracks user navigation through the site" do
    # Sign in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    # Visit various pages
    get root_path
    assert_response :success
    
    get profile_path
    assert_response :success
    
    get activities_path
    assert_response :success
    
    # Check activities were tracked
    activities = @user.activities.recent
    assert activities.any? { |a| a.controller == "home" && a.action == "index" }
    assert activities.any? { |a| a.controller == "profiles" && a.action == "show" }
    assert activities.any? { |a| a.controller == "activities" && a.action == "index" }
  end

  test "tracks response time for activities" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    get root_path
    
    activity = @user.activities.last
    assert_not_nil activity.response_time
    assert activity.response_time > 0
  end

  test "tracks device and browser information" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }, headers: {
      "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
    }
    
    activity = Activity.last
    assert_equal "mobile", activity.device_type
    assert_equal "Safari", activity.browser_name
    assert_equal "iOS", activity.os_name
  end

  test "tracks IP address and session information" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }, headers: {
      "REMOTE_ADDR" => "192.168.1.100"
    }
    
    activity = Activity.last
    assert_equal "192.168.1.100", activity.ip_address
    assert_not_nil activity.session_id
  end

  test "does not track activities for unauthenticated users" do
    assert_no_difference "Activity.count" do
      get root_path
    end
  end

  test "handles activity tracking errors gracefully" do
    # Sign in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    # Mock activity logging to raise an error
    Activity.expects(:log_activity).raises(StandardError.new("Logging error"))
    
    # Should still complete the request successfully
    get root_path
    assert_response :success
  end

  test "tracks suspicious activity patterns" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    # Simulate suspicious behavior - rapid requests
    assert_enqueued_with(job: SuspiciousActivityAlertJob) do
      105.times do
        get root_path
      end
    end
    
    # Check that activities were marked as suspicious
    suspicious_activities = @user.activities.suspicious
    assert suspicious_activities.any?
  end

  test "tracks activities across different controllers" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    # Visit different areas of the site
    get profile_path
    get edit_profile_path
    patch profile_path, params: {
      user: { full_name: "New Name" }
    }
    
    # Check activities
    activities = @user.activities.recent
    
    profile_activities = activities.select { |a| a.controller == "profiles" }
    assert profile_activities.any? { |a| a.action == "show" }
    assert profile_activities.any? { |a| a.action == "edit" }
    assert profile_activities.any? { |a| a.action == "update" }
  end

  test "tracks failed requests with error status" do
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    # Try to access a non-existent resource
    assert_raises(ActiveRecord::RecordNotFound) do
      get user_path(999999)
    end
    
    # Activity should still be tracked with error status
    activity = @user.activities.last
    assert_equal 500, activity.response_status
    assert activity.metadata["error"].present?
  end

  test "respects activity tracking configuration" do
    # Create a controller that disables tracking
    ApplicationController.class_eval do
      def track_activity?
        controller_name != "health"
      end
    end
    
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    initial_count = Activity.count
    
    # This should not be tracked
    get rails_health_check_path
    
    assert_equal initial_count, Activity.count
  ensure
    # Reset the method
    ApplicationController.class_eval do
      def track_activity?
        true
      end
    end
  end
end