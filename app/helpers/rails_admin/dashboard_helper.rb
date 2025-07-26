module RailsAdmin
  module DashboardHelper
    def user_growth_percentage
      current_count = User.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
      previous_count = User.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).count
      
      return 0 if previous_count.zero?
      ((current_count - previous_count).to_f / previous_count * 100).round(2)
    end
    
    def activity_trend_percentage
      current_count = Activity.where(occurred_at: Date.current.beginning_of_day..Date.current.end_of_day).count
      previous_count = Activity.where(occurred_at: 1.day.ago.beginning_of_day..1.day.ago.end_of_day).count
      
      return 0 if previous_count.zero?
      ((current_count - previous_count).to_f / previous_count * 100).round(2)
    end
    
    def system_health_status
      error_rate = calculate_error_rate(24.hours)
      avg_response_time = calculate_average_response_time(24.hours)
      
      if error_rate > 5 || (avg_response_time && avg_response_time > 1.0)
        { status: "warning", color: "warning", icon: "exclamation-triangle" }
      elsif error_rate > 10
        { status: "critical", color: "danger", icon: "times-circle" }
      else
        { status: "healthy", color: "success", icon: "check-circle" }
      end
    end
    
    private
    
    def calculate_error_rate(time_window)
      total = Activity.where(occurred_at: time_window.ago..Time.current).count
      return 0 if total.zero?
      
      errors = Activity.where(response_status: 400..599, occurred_at: time_window.ago..Time.current).count
      (errors.to_f / total * 100).round(2)
    end
    
    def calculate_average_response_time(time_window)
      Activity.where.not(response_time: nil)
              .where(occurred_at: time_window.ago..Time.current)
              .average(:response_time)
    end
  end
end