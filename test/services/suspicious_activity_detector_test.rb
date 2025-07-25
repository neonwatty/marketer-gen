require "test_helper"

class SuspiciousActivityDetectorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    @activity = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      occurred_at: Time.current,
      ip_address: "192.168.1.1"
    )
  end

  test "detects rapid requests" do
    # Create many activities in short time
    105.times do
      Activity.create!(
        user: @user,
        action: "index",
        controller: "home",
        occurred_at: Time.current
      )
    end

    detector = SuspiciousActivityDetector.new(@activity)
    assert detector.check
    
    @activity.reload
    assert @activity.suspicious?
    assert_includes @activity.metadata["suspicious_reasons"], "rapid_requests"
  end

  test "detects failed login attempts" do
    # Create failed login activities
    5.times do |i|
      Activity.create!(
        user: @user,
        action: "create",
        controller: "sessions",
        response_status: 401,
        occurred_at: i.minutes.ago
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
    
    failed_login.reload
    assert failed_login.suspicious?
    assert_includes failed_login.metadata["suspicious_reasons"], "failed_login_attempts"
  end

  test "detects unusual hour activity" do
    # Create activity at 3 AM
    night_activity = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      occurred_at: Time.current.change(hour: 3)
    )

    detector = SuspiciousActivityDetector.new(night_activity)
    assert detector.check
    
    night_activity.reload
    assert night_activity.suspicious?
    assert_includes night_activity.metadata["suspicious_reasons"], "unusual_hour_activity"
  end

  test "detects IP hopping" do
    # Create activities from different IPs
    ["192.168.1.1", "192.168.1.2", "192.168.1.3"].each do |ip|
      Activity.create!(
        user: @user,
        action: "index",
        controller: "home",
        ip_address: ip,
        occurred_at: 1.minute.ago
      )
    end

    detector = SuspiciousActivityDetector.new(@activity)
    assert detector.check
    
    @activity.reload
    assert @activity.suspicious?
    assert_includes @activity.metadata["suspicious_reasons"], "ip_hopping"
  end

  test "detects excessive errors" do
    # Create many error activities
    11.times do
      Activity.create!(
        user: @user,
        action: "create",
        controller: "posts",
        response_status: 500,
        occurred_at: Time.current
      )
    end

    detector = SuspiciousActivityDetector.new(@activity)
    assert detector.check
    
    @activity.reload
    assert @activity.suspicious?
    assert_includes @activity.metadata["suspicious_reasons"], "excessive_errors"
  end

  test "detects suspicious user agent" do
    bot_activity = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      user_agent: "Googlebot/2.1",
      occurred_at: Time.current
    )

    detector = SuspiciousActivityDetector.new(bot_activity)
    assert detector.check
    
    bot_activity.reload
    assert bot_activity.suspicious?
    assert_includes bot_activity.metadata["suspicious_reasons"], "suspicious_user_agent"
  end

  test "detects suspicious paths" do
    suspicious_activity = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      request_path: "/.env",
      occurred_at: Time.current
    )

    detector = SuspiciousActivityDetector.new(suspicious_activity)
    assert detector.check
    
    suspicious_activity.reload
    assert suspicious_activity.suspicious?
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
    
    admin_activity.reload
    assert_not admin_activity.suspicious?
  end

  test "marks activity with multiple suspicious patterns" do
    # Create scenario with multiple suspicious patterns
    ["192.168.1.1", "192.168.1.2", "192.168.1.3"].each do |ip|
      Activity.create!(
        user: @user,
        action: "index",
        controller: "home",
        ip_address: ip,
        occurred_at: 1.minute.ago
      )
    end

    suspicious_activity = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      request_path: "/.env",
      user_agent: "curl/7.68.0",
      occurred_at: Time.current.change(hour: 3)
    )

    detector = SuspiciousActivityDetector.new(suspicious_activity)
    assert detector.check
    
    suspicious_activity.reload
    assert suspicious_activity.suspicious?
    
    reasons = suspicious_activity.metadata["suspicious_reasons"]
    assert_includes reasons, "unusual_hour_activity"
    assert_includes reasons, "ip_hopping"
    assert_includes reasons, "suspicious_user_agent"
    assert_includes reasons, "suspicious_path"
  end

  test "triggers alert job when suspicious activity detected" do
    # Force a suspicious detection
    @activity.update!(user_agent: "curl/7.68.0")
    
    assert_enqueued_jobs 1, only: SuspiciousActivityAlertJob do
      detector = SuspiciousActivityDetector.new(@activity)
      detector.check
    end
  end
end