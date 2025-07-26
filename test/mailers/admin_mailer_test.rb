require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    @admin1 = User.create!(
      email_address: "admin1@example.com",
      password: "password123",
      role: "admin"
    )
    
    @admin2 = User.create!(
      email_address: "admin2@example.com",
      password: "password123",
      role: "admin"
    )
    
    @activity = Activity.create!(
      user: @user,
      action: "create",
      controller: "sessions",
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0 Chrome/91.0",
      request_path: "/sessions",
      occurred_at: Time.current,
      suspicious: true,
      metadata: { suspicious_reasons: ["rapid_requests", "ip_hopping"] }
    )
  end
  
  test "suspicious_activity_alert sends to all admins" do
    email = AdminMailer.suspicious_activity_alert(@activity, ["rapid_requests", "ip_hopping"])
    
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ["admin1@example.com", "admin2@example.com"].sort, email.to.sort
    assert_equal "[SECURITY ALERT] Suspicious activity detected for test@example.com", email.subject
    assert_equal ["from@example.com"], email.from
  end
  
  test "suspicious_activity_alert email body contains activity details" do
    email = AdminMailer.suspicious_activity_alert(@activity, ["rapid_requests", "ip_hopping"])
    
    # Check HTML version
    assert_match @user.email_address, email.html_part.body.to_s
    assert_match @activity.ip_address, email.html_part.body.to_s
    assert_match "sessions#create", email.html_part.body.to_s
    assert_match "/sessions", email.html_part.body.to_s
    assert_match "Rapid requests", email.html_part.body.to_s
    assert_match "Ip hopping", email.html_part.body.to_s
    
    # Check text version
    assert_match @user.email_address, email.text_part.body.to_s
    assert_match @activity.ip_address, email.text_part.body.to_s
    assert_match "sessions#create", email.text_part.body.to_s
    assert_match "/sessions", email.text_part.body.to_s
  end
  
  test "suspicious_activity_alert includes admin panel link" do
    email = AdminMailer.suspicious_activity_alert(@activity, ["rapid_requests"])
    
    assert_match "/admin/user/#{@user.id}", email.html_part.body.to_s
    assert_match "/admin/user/#{@user.id}", email.text_part.body.to_s
  end
  
  test "handles empty admin list gracefully" do
    # Remove all admins
    User.where(role: "admin").destroy_all
    
    email = AdminMailer.suspicious_activity_alert(@activity, ["rapid_requests"])
    assert_equal [], email.to
  end
end