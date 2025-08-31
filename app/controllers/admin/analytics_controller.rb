class Admin::AnalyticsController < ApplicationController
  include Authentication
  
  before_action :require_authentication
  before_action :require_admin
  
  def index
    @analytics = DemoAnalytic.includes(:user, :demo_progresses)
                             .recent
                             .limit(50)
    
    @stats = calculate_stats
  end
  
  def show
    @analytic = DemoAnalytic.includes(:user, :demo_progresses).find(params[:id])
  end
  
  private
  
  def require_admin
    redirect_to root_path, alert: 'Access denied' unless current_user&.admin?
  end
  
  def calculate_stats
    {
      total_demos: DemoAnalytic.count,
      completed_demos: DemoAnalytic.completed.count,
      completion_rate: calculate_completion_rate,
      popular_workflows: popular_workflows_data,
      average_completion_time: average_completion_time,
      daily_stats: daily_stats_data
    }
  end
  
  def calculate_completion_rate
    total = DemoAnalytic.count
    return 0 if total.zero?
    
    (DemoAnalytic.completed.count.to_f / total * 100).round(1)
  end
  
  def popular_workflows_data
    DemoAnalytic.group(:workflow_key)
                .order(Arel.sql('COUNT(*) DESC'))
                .limit(5)
                .count
  end
  
  def average_completion_time
    completed_demos = DemoAnalytic.completed.where.not(duration: nil)
    return 0 if completed_demos.count.zero?
    
    (completed_demos.average(:duration) || 0).round(1)
  end
  
  def daily_stats_data
    DemoAnalytic.where(started_at: 30.days.ago..Time.current)
                .group("DATE(started_at)")
                .count
  end
end
