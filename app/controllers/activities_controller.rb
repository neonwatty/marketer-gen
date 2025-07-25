class ActivitiesController < ApplicationController
  def index
    @activities = current_user.activities
      .includes(:user)
      .recent
      .page(params[:page])
      .per(25)
    
    # Filter by date range
    if params[:start_date].present?
      @activities = @activities.where("occurred_at >= ?", params[:start_date])
    end
    
    if params[:end_date].present?
      @activities = @activities.where("occurred_at <= ?", params[:end_date])
    end
    
    # Filter by status
    case params[:status]
    when "suspicious"
      @activities = @activities.suspicious
    when "failed"
      @activities = @activities.failed_requests
    when "successful"
      @activities = @activities.successful_requests
    end
    
    # Activity statistics
    @stats = {
      total: current_user.activities.count,
      today: current_user.activities.today.count,
      this_week: current_user.activities.this_week.count,
      suspicious: current_user.activities.suspicious.count,
      failed_requests: current_user.activities.failed_requests.count
    }
  end
end
