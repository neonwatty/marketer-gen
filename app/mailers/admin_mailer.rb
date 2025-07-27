class AdminMailer < ApplicationMailer
  helper_method :rails_admin_url_for
  
  def suspicious_activity_alert(activity, reasons)
    @activity = activity
    @reasons = reasons
    @user = activity.user
    
    # Get all admin users
    admin_emails = User.where(role: :admin).pluck(:email_address)
    
    mail(
      to: admin_emails,
      subject: "[SECURITY ALERT] Suspicious activity detected for #{@user.email_address}"
    )
  end
  
  def daily_activity_report(admin, report)
    @admin = admin
    @report = report
    @date = Date.current - 1.day
    
    mail(
      to: admin.email_address,
      subject: "Daily Activity Report - #{@date.strftime('%B %d, %Y')}"
    )
  end
  
  def security_scan_alert(suspicious_users)
    @suspicious_users = suspicious_users
    @scan_time = Time.current
    
    # Get all admin users
    admin_emails = User.where(role: :admin).pluck(:email_address)
    
    mail(
      to: admin_emails,
      subject: "[SECURITY] Automated scan detected #{suspicious_users.count} suspicious users"
    )
  end
  
  def system_maintenance_report(admin_user, maintenance_results)
    @admin_user = admin_user
    @maintenance_results = maintenance_results
    @maintenance_time = Time.current
    
    mail(to: admin_user.email_address, subject: "System Maintenance Report - #{@maintenance_time.strftime('%m/%d/%Y')}")
  end
  
  def user_account_alert(admin_user, user, alert_type, details = {})
    @admin_user = admin_user
    @user = user
    @alert_type = alert_type
    @details = details
    @alert_time = Time.current
    
    subject = case alert_type
              when 'locked'
                "User Account Locked - #{user.email_address}"
              when 'suspended'
                "User Account Suspended - #{user.email_address}"
              when 'multiple_failed_logins'
                "Multiple Failed Login Attempts - #{user.email_address}"
              else
                "User Account Alert - #{user.email_address}"
              end
    
    mail(to: admin_user.email_address, subject: subject)
  end
  
  def system_health_alert(admin_user, health_status, metrics)
    @admin_user = admin_user
    @health_status = health_status
    @metrics = metrics
    @alert_time = Time.current
    
    subject = case health_status
              when 'critical'
                "🚨 CRITICAL System Health Alert"
              when 'warning'
                "⚠️ System Health Warning"
              else
                "System Health Status Update"
              end
    
    mail(to: admin_user.email_address, subject: subject)
  end
  
  def weekly_summary_report(admin_user, summary_data)
    @admin_user = admin_user
    @summary_data = summary_data
    @week_start = 1.week.ago.beginning_of_week
    @week_end = Date.current.end_of_week
    
    mail(to: admin_user.email_address, subject: "Weekly Summary Report - #{@week_start.strftime('%m/%d')} to #{@week_end.strftime('%m/%d/%Y')}")
  end
  
  private
  
  def rails_admin_url_for(object, action = :show)
    host = Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000'
    protocol = Rails.application.config.action_mailer.default_url_options[:protocol] || 'http'
    model_name = object.class.name.underscore
    "#{protocol}://#{host}/admin/#{model_name}/#{object.id}"
  end
end