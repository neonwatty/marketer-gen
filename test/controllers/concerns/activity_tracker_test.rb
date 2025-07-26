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
    end
    
    activity = Activity.last
    assert_equal @user, activity.user
    assert_equal "index", activity.action
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
    activity = Activity.last
    assert_equal 200, activity.response_status
    
    # Test failed request (assuming this route doesn't exist)
    assert_raises(ActionController::RoutingError) do
      get "/nonexistent"
    end
  end

  test "tracks response time" do
    sign_in @user
    
    get root_path
    activity = Activity.last
    
    assert_not_nil activity.response_time
    assert activity.response_time > 0
  end

  test "tracks request metadata correctly" do
    sign_in @user
    
    get root_path, headers: {
      "User-Agent" => "Test Browser/1.0",
      "Referer" => "http://example.com"
    }
    
    activity = Activity.last
    assert_equal "Test Browser/1.0", activity.user_agent
    assert_equal "http://example.com", activity.referrer
  end

  test "filters sensitive parameters from metadata" do
    sign_in @user
    
    post sessions_path, params: {
      email_address: "test@example.com",
      password: "secret123",
      remember_me: "1"
    }
    
    activity = Activity.last
    assert_not_includes activity.metadata.to_s, "secret123"
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
    
    # Mock a controller that raises an error
    Rails.application.routes.draw do
      get "/test_error", to: -> (env) { raise StandardError, "Test error" }
    end
    
    assert_raises(StandardError) do
      get "/test_error"
    end
    
    activity = Activity.last
    assert_equal 500, activity.response_status
    assert_includes activity.metadata["error"], "Test error"
  ensure
    Rails.application.reload_routes!
  end

  test "checks for suspicious activity after tracking" do
    sign_in @user
    
    # Create conditions for suspicious activity
    101.times do
      get root_path
    end
    
    # The last activity should be marked as suspicious
    activity = Activity.last
    assert activity.suspicious?
  end

  private

  def sign_in(user)
    post sessions_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end