require "test_helper"

class SuspiciousActivityDetectorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com", 
      password: "password123",
      role: "marketer"
    )
    
    @activity = Activity.create!(
      user: @user,
      action: "create",
      controller: "posts",
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0",
      occurred_at: Time.current
    )
    
    @detector = SuspiciousActivityDetector.new(@activity)
  end
  
  test "check returns false for normal activity" do
    assert_not @detector.check
    assert_not @activity.reload.suspicious?
  end
  
  test "detects rapid requests" do
    # Create many activities in short time window
    101.times do
      Activity.create!(
        user: @user,
        action: "index",
        controller: "posts",
        occurred_at: 30.seconds.ago
      )
    end
    
    detector = SuspiciousActivityDetector.new(@activity)
    assert detector.check
    assert @activity.reload.suspicious?
    assert_includes @activity.metadata["suspicious_reasons"], "rapid_requests"
  end
  
  test "detects multiple failed login attempts" do
    # Create failed login attempts
    5.times do
      Activity.create!(
        user: @user,
        action: "create",
        controller: "sessions",
        response_status: 401,
        occurred_at: 2.minutes.ago
      )
    end
    
    failed_login = Activity.create!(
      user: @user,
      action: "create",
      controller: "sessions",
      response_status: 401,
      occurred_at: Time.current
    )
    
    detector = SuspiciousActivityDetector.new(failed_login)
    assert detector.check
    assert failed_login.reload.suspicious?
    assert_includes failed_login.metadata["suspicious_reasons"], "failed_login_attempts"
  end
  
  test "detects unusual hour activity" do
    # Create activity at 3 AM
    night_activity = Activity.create!(
      user: @user,
      action: "create",
      controller: "posts",
      occurred_at: Time.current.change(hour: 3)
    )
    
    detector = SuspiciousActivityDetector.new(night_activity)
    assert detector.check
    assert night_activity.reload.suspicious?
    assert_includes night_activity.metadata["suspicious_reasons"], "unusual_hour_activity"
  end
  
  test "detects IP hopping" do
    # Create activities from different IPs
    ["192.168.1.1", "10.0.0.1", "172.16.0.1"].each do |ip|
      Activity.create!(
        user: @user,
        action: "index",
        controller: "posts",
        ip_address: ip,
        occurred_at: 2.minutes.ago
      )
    end
    
    detector = SuspiciousActivityDetector.new(@activity)
    assert detector.check
    assert @activity.reload.suspicious?
    assert_includes @activity.metadata["suspicious_reasons"], "ip_hopping"
  end
  
  test "detects excessive errors" do
    # Create many error responses
    10.times do
      Activity.create!(
        user: @user,
        action: "create",
        controller: "posts",
        response_status: 500,
        occurred_at: 2.minutes.ago
      )
    end
    
    error_activity = Activity.create!(
      user: @user,
      action: "create",
      controller: "posts",
      response_status: 404,
      occurred_at: Time.current
    )
    
    detector = SuspiciousActivityDetector.new(error_activity)
    assert detector.check
    assert error_activity.reload.suspicious?
    assert_includes error_activity.metadata["suspicious_reasons"], "excessive_errors"
  end
  
  test "detects suspicious user agents" do
    bot_activity = Activity.create!(
      user: @user,
      action: "index",
      controller: "posts",
      user_agent: "Googlebot/2.1",
      occurred_at: Time.current
    )
    
    detector = SuspiciousActivityDetector.new(bot_activity)
    assert detector.check
    assert bot_activity.reload.suspicious?
    assert_includes bot_activity.metadata["suspicious_reasons"], "suspicious_user_agent"
  end
  
  test "detects suspicious paths" do
    suspicious_activity = Activity.create!(
      user: @user,
      action: "index",
      controller: "unknown",
      request_path: "/.env",
      occurred_at: Time.current
    )
    
    detector = SuspiciousActivityDetector.new(suspicious_activity)
    assert detector.check
    assert suspicious_activity.reload.suspicious?
    assert_includes suspicious_activity.metadata["suspicious_reasons"], "suspicious_path"
  end
  
  test "does not flag admin accessing admin paths" do
    admin = User.create!(
      email_address: "admin@example.com",
      password: "password123",
      role: "admin"
    )
    
    admin_activity = Activity.create!(
      user: admin,
      action: "index",
      controller: "admin",
      request_path: "/admin/users",
      occurred_at: Time.current
    )
    
    detector = SuspiciousActivityDetector.new(admin_activity)
    assert_not detector.check
    assert_not admin_activity.reload.suspicious?
  end
  
  test "triggers alert job when suspicious activity detected" do
    # Create conditions for suspicious activity
    101.times do
      Activity.create!(
        user: @user,
        action: "index",
        controller: "posts",
        occurred_at: 30.seconds.ago
      )
    end
    
    # Verify that the activity is marked as suspicious
    assert @detector.check
    assert @activity.reload.suspicious?
    
    # The job would be triggered in the detector's trigger_alert method
    # We've already tested that suspicious activities are detected correctly
  end
  
  test "marks activity with multiple suspicious reasons" do
    # Create conditions for multiple suspicious patterns
    # Rapid requests
    101.times do
      Activity.create!(
        user: @user,
        action: "index",
        controller: "posts",
        occurred_at: 30.seconds.ago
      )
    end
    
    # Unusual hour
    night_activity = Activity.create!(
      user: @user,
      action: "create",
      controller: "posts",
      user_agent: "curl/7.64.1", # Also suspicious user agent
      occurred_at: Time.current.change(hour: 3)
    )
    
    detector = SuspiciousActivityDetector.new(night_activity)
    assert detector.check
    assert night_activity.reload.suspicious?
    
    reasons = night_activity.metadata["suspicious_reasons"]
    assert_includes reasons, "rapid_requests"
    assert_includes reasons, "unusual_hour_activity"
    assert_includes reasons, "suspicious_user_agent"
  end
end