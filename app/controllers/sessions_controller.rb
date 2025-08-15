class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    email = params[:email_address]
    
    # Check if IP is blocked
    security_monitor = SecurityMonitorService.new
    if security_monitor.ip_blocked?(request.remote_ip)
      Rails.logger.warn "Blocked IP attempted login: #{request.remote_ip}"
      redirect_to new_session_path, alert: "Access temporarily restricted. Please try again later."
      return
    end
    
    if user = User.authenticate_by(params.permit(:email_address, :password))
      # Clear failed attempts on successful login
      security_monitor.clear_failed_attempts(request.remote_ip)
      
      # Log successful authentication
      Rails.logger.info "Successful login for user #{user.id} from IP #{request.remote_ip}"
      
      start_new_session_for user
      redirect_to after_authentication_url
    else
      # Track failed login attempt
      security_monitor.track_failed_login(request.remote_ip, email)
      
      Rails.logger.warn "Failed login attempt for email: #{email} from IP: #{request.remote_ip}"
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
