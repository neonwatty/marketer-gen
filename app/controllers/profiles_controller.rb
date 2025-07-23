class ProfilesController < ApplicationController
  before_action :set_user
  before_action :authorize_user
  
  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to profile_path, notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_user
    @user = current_user
  end
  
  def authorize_user
    # Users can only view/edit their own profile
    redirect_to root_path, alert: "Not authorized" unless @user == current_user
  end
  
  def user_params
    params.require(:user).permit(
      :full_name, 
      :bio, 
      :phone_number, 
      :company, 
      :job_title, 
      :timezone,
      :notification_email,
      :notification_marketing,
      :notification_product,
      :avatar
    )
  end
end
