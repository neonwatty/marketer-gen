require 'ostruct'

class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      if user.locked?
        log_authentication_activity(user, success: false, reason: "account_locked")
        redirect_to new_session_path, alert: "Your account has been locked: #{user.lock_reason}"
      elsif user.suspended?
        log_authentication_activity(user, success: false, reason: "account_suspended")
        redirect_to new_session_path, alert: "Your account has been suspended: #{user.suspension_reason}"
      else
        start_new_session_for(user, remember_me: params[:remember_me] == "1")
        log_authentication_activity(user, success: true)
        redirect_to after_authentication_url
      end
    else
      # Log failed authentication attempt if we can identify the user
      if params[:email_address].present?
        failed_user = User.find_by(email_address: params[:email_address])
        log_authentication_activity(failed_user, success: false, reason: "invalid_credentials") if failed_user
      end
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
  
  private
  
  def log_authentication_activity(user, success:, reason: nil)
    return unless user
    
    metadata = {
      success: success,
      reason: reason,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    }.compact
    
    activity = Activity.log_activity(
      user: user,
      action: "create",
      controller: "sessions",
      request: request,
      response: OpenStruct.new(status: success ? 302 : 401),
      metadata: metadata
    )
    
    # Check for suspicious activity
    if activity.persisted?
      SuspiciousActivityDetector.new(activity).check
    end
  rescue => e
    Rails.logger.error "Failed to log authentication activity: #{e.message}"
  end
end
