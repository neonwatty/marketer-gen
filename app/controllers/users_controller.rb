class UsersController < ApplicationController
  before_action :set_user, only: [:show]
  
  def index
    @users = policy_scope(User)
    authorize User
  end

  def show
    authorize @user
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
end
