class UserSessionsController < ApplicationController
  before_action :set_session, only: :destroy
  
  def index
    @sessions = current_user.sessions.active.order(last_active_at: :desc)
    @current_session = Current.session
  end

  def destroy
    if @session == Current.session
      # Can't destroy current session from this page
      redirect_to user_sessions_path, alert: "You cannot end your current session from here. Use Sign Out instead."
    else
      @session.destroy
      redirect_to user_sessions_path, notice: "Session ended successfully."
    end
  end
  
  private
  
  def set_session
    @session = current_user.sessions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
