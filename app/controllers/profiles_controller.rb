class ProfilesController < ApplicationController
  before_action :require_authentication

  def show
    @user = Current.user
    authorize @user, policy_class: ProfilePolicy
  end

  def edit
    @user = Current.user
    authorize @user, policy_class: ProfilePolicy
  end

  def update
    @user = Current.user
    authorize @user, policy_class: ProfilePolicy
    
    if @user.update(profile_params)
      redirect_to profile_path, notice: 'Profile updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :phone, :company, :bio, :avatar, 
                                 notification_preferences: [:email_notifications, :journey_updates, :marketing_emails, :weekly_digest])
  end
end
