class AdminController < ApplicationController
  before_action :ensure_admin
  
  def index
    @users = User.all.limit(20)
    @recent_activities = Activity.includes(:user).order(occurred_at: :desc).limit(10)
    @admin_audit_logs = AdminAuditLog.includes(:user).order(created_at: :desc).limit(10)
  end
  
  def users
    @users = User.all
  end
  
  def activities
    @activities = Activity.includes(:user).order(occurred_at: :desc).page(params[:page]).per(50)
  end
  
  def audit_logs
    @audit_logs = AdminAuditLog.includes(:user).order(created_at: :desc).page(params[:page]).per(50)
  end
  
  private
  
  def ensure_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end
end