class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  
  # Rate limit password reset requests to prevent abuse
  rate_limit to: 5, within: 1.hour, only: :create, with: -> { 
    redirect_to new_password_path, alert: "Too many password reset requests. Please try again later." 
  }

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to new_session_path, notice: "Password has been reset."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
    
    def user_params
      params.permit(:password, :password_confirmation)
    end
end
