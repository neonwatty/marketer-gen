class ActivityReportsController < ApplicationController
  before_action :require_authentication
  
  def show
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current
    
    @report = ActivityReportService.new(
      current_user,
      start_date: @start_date,
      end_date: @end_date
    ).generate_report
    
    respond_to do |format|
      format.html
      format.json { render json: @report }
      format.pdf { render_pdf } if defined?(Prawn)
    end
  end
  
  def export
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current
    
    activities = current_user.activities
      .where(occurred_at: @start_date.beginning_of_day..@end_date.end_of_day)
      .order(:occurred_at)
    
    respond_to do |format|
      format.csv { send_data generate_csv(activities), filename: "activity_report_#{Date.current}.csv" }
    end
  end
  
  private
  
  def generate_csv(activities)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        'Date/Time',
        'Action',
        'Path',
        'Method',
        'Status',
        'Response Time (ms)',
        'IP Address',
        'Device',
        'Browser',
        'OS',
        'Suspicious',
        'Reasons'
      ]
      
      activities.find_each do |activity|
        csv << [
          activity.occurred_at.strftime('%Y-%m-%d %H:%M:%S'),
          activity.full_action,
          activity.request_path,
          activity.request_method,
          activity.response_status,
          activity.duration_in_ms,
          activity.ip_address,
          activity.device_type,
          activity.browser_name,
          activity.os_name,
          activity.suspicious? ? 'Yes' : 'No',
          activity.metadata['suspicious_reasons']&.join(', ')
        ]
      end
    end
  end
  
  def render_pdf
    # This would require the Prawn gem
    # Implementation depends on specific PDF requirements
    render plain: "PDF export not implemented", status: :not_implemented
  end
end