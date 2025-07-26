require "test_helper"
require "stringio"

class SuspiciousActivityAlertJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    @admin = User.create!(
      email_address: "admin@example.com",
      password: "password123",
      role: "admin"
    )
    
    @activity = Activity.create!(
      user: @user,
      action: "create",
      controller: "sessions",
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0",
      request_path: "/sessions",
      occurred_at: Time.current,
      suspicious: true,
      metadata: { suspicious_reasons: ["rapid_requests", "ip_hopping"] }
    )
  end
  
  test "sends email to all admin users" do
    assert_emails 1 do
      SuspiciousActivityAlertJob.perform_now(@activity.id, ["rapid_requests", "ip_hopping"])
    end
  end
  
  test "logs security warning" do
    # Capture Rails logger output
    original_logger = Rails.logger
    output = StringIO.new
    Rails.logger = Logger.new(output)
    
    SuspiciousActivityAlertJob.perform_now(@activity.id, ["rapid_requests"])
    
    Rails.logger = original_logger
    assert_match /SECURITY.*Suspicious Activity Detected/, output.string
  end
  
  test "handles missing activity gracefully" do
    assert_nothing_raised do
      SuspiciousActivityAlertJob.perform_now(999999, ["test"])
    end
  end
  
  test "checks for user lockout with critical reasons" do
    # Create multiple suspicious activities
    3.times do
      Activity.create!(
        user: @user,
        action: "create",
        controller: "sessions",
        occurred_at: 30.minutes.ago,
        suspicious: true
      )
    end
    
    assert_emails 2 do # One to admin, one to user for lockout
      SuspiciousActivityAlertJob.perform_now(@activity.id, ["failed_login_attempts"])
    end
    
    @user.reload
    assert @user.locked?
    assert_equal "Suspicious activity detected", @user.lock_reason
  end
  
  test "does not lock user for non-critical reasons" do
    SuspiciousActivityAlertJob.perform_now(@activity.id, ["unusual_hour_activity"])
    
    @user.reload
    assert_not @user.locked?
  end
  
  test "does not lock user if threshold not met" do
    # Only 1 recent suspicious activity (not enough for lockout)
    SuspiciousActivityAlertJob.perform_now(@activity.id, ["ip_hopping"])
    
    @user.reload
    assert_not @user.locked?
  end
  
  test "logs detailed security information" do
    # Capture Rails logger output
    original_logger = Rails.logger
    output = StringIO.new
    Rails.logger = Logger.new(output)
    
    SuspiciousActivityAlertJob.perform_now(@activity.id, ["rapid_requests", "ip_hopping"])
    
    Rails.logger = original_logger
    log_output = output.string
    
    assert_match @user.email_address, log_output
    assert_match @activity.ip_address, log_output
    assert_match @activity.full_action, log_output
    assert_match "rapid_requests, ip_hopping", log_output
  end
end
