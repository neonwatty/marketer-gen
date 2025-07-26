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
  
  private
  
  def rails_admin_url_for(object, action = :show)
    host = Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000'
    protocol = Rails.application.config.action_mailer.default_url_options[:protocol] || 'http'
    model_name = object.class.name.underscore
    "#{protocol}://#{host}/admin/#{model_name}/#{object.id}"
  end
end