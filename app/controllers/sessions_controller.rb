class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      if user.locked?
        redirect_to new_session_path, alert: "Your account has been locked: #{user.lock_reason}"
      elsif user.suspended?
        redirect_to new_session_path, alert: "Your account has been suspended: #{user.suspension_reason}"
      else
        start_new_session_for(user, remember_me: params[:remember_me] == "1")
        redirect_to after_authentication_url
      end
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
