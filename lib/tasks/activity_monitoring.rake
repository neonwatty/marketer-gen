namespace :activity_monitoring do
  desc "Clean up old activity logs"
  task cleanup: :environment do
    puts "Starting activity cleanup..."
    ActivityCleanupJob.perform_now
    puts "Activity cleanup completed."
  end
  
  desc "Generate daily activity report"
  task daily_report: :environment do
    puts "Generating daily activity reports..."
    
    # Generate reports for admin users
    User.admin.find_each do |admin|
      report = ActivityReportService.new(admin, start_date: 1.day.ago).generate_report
      
      # Log summary
      ActivityLogger.log(:info, "Daily activity report generated", {
        user_id: admin.id,
        total_activities: report[:summary][:total_activities],
        suspicious_count: report[:summary][:suspicious_count]
      })
      
      # Send email if configured
      if Rails.application.config.activity_alerts.enabled
        AdminMailer.daily_activity_report(admin, report).deliver_later
      end
    end
    
    puts "Daily reports generated."
  end
  
  desc "Check for suspicious activity patterns across all users"
  task security_scan: :environment do
    puts "Running security scan..."
    
    # Find users with suspicious patterns
    suspicious_users = []
    
    User.find_each do |user|
      recent_activities = user.activities.where("occurred_at > ?", 1.hour.ago)
      
      # Check for rapid requests
      if recent_activities.count > 200
        suspicious_users << {
          user: user,
          reason: "Excessive requests",
          count: recent_activities.count
        }
      end
      
      # Check for multiple IPs
      ip_count = recent_activities.distinct.count(:ip_address)
      if ip_count > 5
        suspicious_users << {
          user: user,
          reason: "Multiple IP addresses",
          ip_count: ip_count
        }
      end
      
      # Check for suspicious activities
      suspicious_count = recent_activities.suspicious.count
      if suspicious_count > 3
        suspicious_users << {
          user: user,
          reason: "Multiple suspicious activities",
          suspicious_count: suspicious_count
        }
      end
    end
    
    # Log and alert
    if suspicious_users.any?
      ActivityLogger.security('security_scan', "Security scan found suspicious users", {
        user_count: suspicious_users.count,
        users: suspicious_users.map { |s| { id: s[:user].id, reason: s[:reason] } }
      })
      
      # Send alert
      AdminMailer.security_scan_alert(suspicious_users).deliver_later if Rails.application.config.activity_alerts.enabled
    end
    
    puts "Security scan completed. Found #{suspicious_users.count} suspicious users."
  end
  
  desc "Generate activity statistics"
  task stats: :environment do
    puts "\n=== Activity Statistics ==="
    puts "Period: Last 30 days\n\n"
    
    # Overall stats
    total_activities = Activity.where("occurred_at > ?", 30.days.ago).count
    total_users = User.count
    active_users = Activity.where("occurred_at > ?", 30.days.ago).distinct.count(:user_id)
    
    puts "Total Activities: #{total_activities}"
    puts "Active Users: #{active_users} / #{total_users} (#{(active_users.to_f / total_users * 100).round(2)}%)"
    
    # Suspicious activities
    suspicious = Activity.where("occurred_at > ?", 30.days.ago).suspicious
    puts "\nSuspicious Activities: #{suspicious.count}"
    
    if suspicious.any?
      reasons = suspicious.flat_map { |a| a.metadata['suspicious_reasons'] || [] }.tally
      puts "Reasons:"
      reasons.sort_by { |_, count| -count }.each do |reason, count|
        puts "  - #{reason}: #{count}"
      end
    end
    
    # Top controllers/actions
    puts "\nTop Actions:"
    Activity.where("occurred_at > ?", 30.days.ago)
      .group(:controller, :action)
      .count
      .sort_by { |_, count| -count }
      .first(10)
      .each do |(controller, action), count|
        puts "  - #{controller}##{action}: #{count}"
      end
    
    # Performance stats
    activities_with_time = Activity.where("occurred_at > ? AND response_time IS NOT NULL", 30.days.ago)
    if activities_with_time.any?
      avg_time = activities_with_time.average(:response_time)
      max_time = activities_with_time.maximum(:response_time)
      
      puts "\nPerformance:"
      puts "  - Average Response Time: #{(avg_time * 1000).round(2)}ms"
      puts "  - Slowest Request: #{(max_time * 1000).round(2)}ms"
    end
    
    # Device stats
    puts "\nDevice Usage:"
    Activity.where("occurred_at > ?", 30.days.ago)
      .group(:device_type)
      .count
      .each do |device, count|
        percentage = (count.to_f / total_activities * 100).round(2)
        puts "  - #{device || 'Unknown'}: #{count} (#{percentage}%)"
      end
  end
  
  desc "Export activity logs to CSV"
  task :export_csv, [:user_id, :days] => :environment do |t, args|
    user_id = args[:user_id]
    days = (args[:days] || 30).to_i
    
    user = User.find(user_id)
    activities = user.activities.where("occurred_at > ?", days.days.ago).order(:occurred_at)
    
    require 'csv'
    
    filename = "activity_log_#{user.id}_#{Date.current}.csv"
    filepath = Rails.root.join('tmp', filename)
    
    CSV.open(filepath, 'wb') do |csv|
      csv << ['Occurred At', 'Controller', 'Action', 'Path', 'Method', 'Status', 'Response Time (ms)', 'IP Address', 'Device', 'Browser', 'Suspicious', 'Suspicious Reasons']
      
      activities.find_each do |activity|
        csv << [
          activity.occurred_at,
          activity.controller,
          activity.action,
          activity.request_path,
          activity.request_method,
          activity.response_status,
          activity.duration_in_ms,
          activity.ip_address,
          activity.device_type,
          activity.browser_name,
          activity.suspicious?,
          activity.metadata['suspicious_reasons']&.join(', ')
        ]
      end
    end
    
    puts "Activity log exported to: #{filepath}"
  end
end