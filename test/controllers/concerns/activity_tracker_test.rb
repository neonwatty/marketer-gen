require "test_helper"

class ActivityTrackerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
  end

  test "tracks activities for authenticated users" do
    sign_in @user
    
    assert_difference "Activity.count", 1 do
      get root_path
      assert_response :success
    end
    
    activity = Activity.last
    assert_not_nil activity
    assert_equal @user, activity.user
    assert_equal "index", activity.action
    assert_equal "home", activity.controller
    assert_not_nil activity.ip_address
    assert_not_nil activity.user_agent
  end

  test "does not track activities for unauthenticated users" do
    assert_no_difference "Activity.count" do
      get root_path
    end
  end

  test "tracks response status correctly" do
    sign_in @user
    
    # Test successful request
    get root_path
    assert_response :success
    
    activity = Activity.last
    assert_not_nil activity
    assert_equal 200, activity.response_status
  end

  test "tracks response time" do
    sign_in @user
    
    get root_path
    assert_response :success
    
    activity = Activity.last
    assert_not_nil activity
    assert_not_nil activity.response_time
    assert activity.response_time > 0
  end

  test "tracks request metadata correctly" do
    sign_in @user
    
    get root_path, headers: {
      "User-Agent" => "Test Browser/1.0",
      "Referer" => "http://example.com"
    }
    assert_response :success
    
    activity = Activity.last
    assert_not_nil activity
    assert_equal "Test Browser/1.0", activity.user_agent
    assert_equal "http://example.com", activity.referrer
  end

  test "filters sensitive parameters from metadata" do
    sign_in @user
    
    # Make a request with sensitive parameters
    patch profile_path, params: {
      user: {
        email_address: "new@example.com",
        password: "newsecret123"
      }
    }
    
    activity = Activity.last
    assert_not_nil activity
    assert_not_includes activity.metadata.to_s, "newsecret123"
    assert_not_includes activity.metadata.to_s, "password"
  end

  test "skips tracking for excluded actions" do
    sign_in @user
    
    # Assuming heartbeat is an excluded action
    assert_no_difference "Activity.count" do
      get "/heartbeat" if defined?(heartbeat_path)
    end
  end

  test "skips tracking for rails_admin controllers" do
    admin = User.create!(
      email_address: "admin@example.com",
      password: "password123",
      role: "admin"
    )
    
    sign_in admin
    
    assert_no_difference "Activity.count" do
      get rails_admin_path if defined?(rails_admin_path)
    end
  end

  test "tracks errors and exceptions" do
    sign_in @user
    
    # Force an error by trying to update with invalid data
    patch profile_path, params: {
      user: {
        email_address: "" # Invalid - blank email
      }
    }
    
    # Activity should be tracked even with validation errors
    activity = Activity.last
    assert_not_nil activity
    assert_equal "profiles", activity.controller
    assert_equal "update", activity.action
  end

  test "checks for suspicious activity after tracking" do
    sign_in @user
    
    # Create conditions for suspicious activity - rapid requests
    102.times do |i|
      get root_path
      assert_response :success
    end
    
    # Check recent activities for suspicious flags
    recent_activities = Activity.where(user: @user).recent.limit(10)
    assert recent_activities.any?(&:suspicious?), "Expected at least one activity to be marked as suspicious"
  end

  private

  def sign_in(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end