# Preview all emails at http://localhost:3000/rails/mailers/admin_mailer
class AdminMailerPreview < ActionMailer::Preview
  def suspicious_activity_alert
    user = User.first || User.new(
      email_address: "suspicious@example.com",
      full_name: "Suspicious User"
    )
    
    activity = Activity.first || Activity.new(
      user: user,
      action: "create",
      controller: "sessions",
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124",
      request_path: "/admin/users",
      occurred_at: Time.current,
      suspicious: true,
      response_status: 401,
      metadata: { 
        suspicious_reasons: ["rapid_requests", "failed_login_attempts", "ip_hopping"],
        params: { controller: "sessions", action: "create" }
      }
    )
    
    reasons = ["rapid_requests", "failed_login_attempts", "ip_hopping"]
    
    AdminMailer.suspicious_activity_alert(activity, reasons)
  end
end