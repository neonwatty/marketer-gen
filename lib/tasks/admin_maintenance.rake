namespace :admin do
  desc "Perform system maintenance and cleanup operations"
  
  task cleanup_old_activities: :environment do
    puts "Starting cleanup of old activities..."
    count = Activity.where("occurred_at < ?", 30.days.ago).delete_all
    puts "Deleted #{count} old activity records (older than 30 days)"
  end
  
  task cleanup_expired_sessions: :environment do
    puts "Starting cleanup of expired sessions..."
    count = Session.expired.delete_all
    puts "Deleted #{count} expired session records"
  end
  
  task cleanup_old_audit_logs: :environment do
    puts "Starting cleanup of old audit logs..."
    count = AdminAuditLog.where("created_at < ?", 90.days.ago).delete_all
    puts "Deleted #{count} old audit log records (older than 90 days)"
  end
  
  task full_cleanup: :environment do
    puts "Starting full system cleanup..."
    
    activities = Activity.where("occurred_at < ?", 30.days.ago).delete_all
    puts "Deleted #{activities} old activity records"
    
    sessions = Session.expired.delete_all
    puts "Deleted #{sessions} expired sessions"
    
    audit_logs = AdminAuditLog.where("created_at < ?", 90.days.ago).delete_all
    puts "Deleted #{audit_logs} old audit logs"
    
    puts "Full cleanup complete: #{activities + sessions + audit_logs} total records removed"
  end
  
  task generate_activity_report: :environment do
    puts "Generating activity report..."
    
    today = Date.current
    week_ago = 7.days.ago
    
    puts "\n=== Activity Report for Last 7 Days ==="
    puts "Total activities: #{Activity.where(occurred_at: week_ago..Time.current).count}"
    puts "Suspicious activities: #{Activity.suspicious.where(occurred_at: week_ago..Time.current).count}"
    puts "Failed login attempts: #{Activity.where(controller: "sessions", action: "create", response_status: 401).where(occurred_at: week_ago..Time.current).count}"
    puts "Average response time: #{Activity.where.not(response_time: nil).where(occurred_at: week_ago..Time.current).average(:response_time)&.round(4) || "N/A"} seconds"
    
    puts "\n=== User Statistics ==="
    puts "Total users: #{User.count}"
    puts "Active users: #{User.where(suspended_at: nil, locked_at: nil).count}"
    puts "Locked users: #{User.where.not(locked_at: nil).count}"
    puts "Suspended users: #{User.where.not(suspended_at: nil).count}"
    puts "New users this week: #{User.where(created_at: week_ago..Time.current).count}"
    
    puts "\n=== System Health ==="
    error_rate = Activity.where(response_status: 500..599, occurred_at: week_ago..Time.current).count.to_f / 
                 Activity.where(occurred_at: week_ago..Time.current).count.to_f * 100
    puts "Error rate: #{error_rate.round(2)}%"
    puts "Active sessions: #{Session.active.count}"
    
    puts "\nReport generated at: #{Time.current}"
  end
  
  task check_system_health: :environment do
    puts "Checking system health..."
    
    # Check for high error rates
    total_requests = Activity.where(occurred_at: 24.hours.ago..Time.current).count
    error_requests = Activity.where(response_status: 500..599, occurred_at: 24.hours.ago..Time.current).count
    error_rate = total_requests > 0 ? (error_requests.to_f / total_requests * 100).round(2) : 0
    
    puts "24-hour error rate: #{error_rate}%"
    
    if error_rate > 10
      puts "⚠️  HIGH ERROR RATE DETECTED!"
    elsif error_rate > 5
      puts "⚠️  Elevated error rate detected"
    else
      puts "✅ Error rate within normal limits"
    end
    
    # Check for suspicious activity
    suspicious_count = Activity.suspicious.where(occurred_at: 24.hours.ago..Time.current).count
    puts "Suspicious activities in last 24 hours: #{suspicious_count}"
    
    if suspicious_count > 50
      puts "⚠️  HIGH SUSPICIOUS ACTIVITY!"
    elsif suspicious_count > 10
      puts "⚠️  Elevated suspicious activity"
    else
      puts "✅ Suspicious activity within normal limits"
    end
    
    # Check for locked/suspended users
    locked_users = User.where.not(locked_at: nil).count
    suspended_users = User.where.not(suspended_at: nil).count
    
    puts "Locked users: #{locked_users}"
    puts "Suspended users: #{suspended_users}"
    
    # Check session health
    expired_sessions = Session.expired.count
    puts "Expired sessions needing cleanup: #{expired_sessions}"
    
    if expired_sessions > 1000
      puts "⚠️  Consider running session cleanup"
    end
    
    puts "\nSystem health check completed at: #{Time.current}"
  end
  
  task send_daily_report: :environment do
    puts "Generating and sending daily admin report..."
    
    # This would typically send an email report
    # For now, we'll just generate the report data
    
    report_data = {
      date: Date.current,
      total_users: User.count,
      new_users_today: User.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
      activities_today: Activity.where(occurred_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
      suspicious_activities: Activity.suspicious.where(occurred_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
      locked_users: User.where.not(locked_at: nil).count,
      suspended_users: User.where.not(suspended_at: nil).count,
      active_sessions: Session.active.count
    }
    
    puts "Daily Report Data:"
    report_data.each do |key, value|
      puts "  #{key.to_s.humanize}: #{value}"
    end
    
    # In a real application, you would send this via email:
    # AdminMailer.daily_report(report_data).deliver_now
    
    puts "Daily report generated at: #{Time.current}"
  end
end

# Convenience task to run all cleanup operations
task admin_cleanup: ["admin:full_cleanup"]

# Daily maintenance task that can be scheduled via cron
task daily_admin_maintenance: [
  "admin:cleanup_expired_sessions",
  "admin:check_system_health",
  "admin:send_daily_report"
]

# Weekly maintenance task
task weekly_admin_maintenance: [
  "admin:cleanup_old_activities",
  "admin:generate_activity_report"
]

# Monthly maintenance task
task monthly_admin_maintenance: [
  "admin:cleanup_old_audit_logs",
  "admin:full_cleanup"
]