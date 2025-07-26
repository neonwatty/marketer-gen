class SuspiciousActivityAlertJob < ApplicationJob
  queue_as :critical

  def perform(activity_id, reasons)
    activity = Activity.find(activity_id)
    
    # Send email to admins
    AdminMailer.suspicious_activity_alert(activity, reasons).deliver_later
    
    # Log to security monitoring system
    log_to_security_monitoring(activity, reasons)
    
    # Check if user should be temporarily locked
    check_user_lockout(activity.user, reasons)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Activity #{activity_id} not found for suspicious activity alert"
  end

  private

  def log_to_security_monitoring(activity, reasons)
    log_message = <<~LOG
      [SECURITY] Suspicious Activity Detected:
      User: #{activity.user.email_address} (ID: #{activity.user.id})
      IP: #{activity.ip_address}
      Action: #{activity.full_action}
      Path: #{activity.request_path}
      Reasons: #{reasons.join(", ")}
      Time: #{activity.occurred_at}
      User Agent: #{activity.user_agent}
    LOG
    
    Rails.logger.warn log_message
  end

  def check_user_lockout(user, reasons)
    # Lock user if there are critical security concerns
    critical_reasons = ["failed_login_attempts", "ip_hopping", "excessive_errors"]
    
    if (reasons & critical_reasons).any?
      recent_suspicious_count = user.activities
        .suspicious
        .where("occurred_at > ?", 1.hour.ago)
        .count
      
      if recent_suspicious_count >= 3
        lock_user_temporarily(user)
      end
    end
  end

  def lock_user_temporarily(user)
    user.update!(
      locked_at: Time.current,
      lock_reason: "Suspicious activity detected"
    )
    
    # Send notification to user
    UserMailer.account_temporarily_locked(user).deliver_later
  end
end
