namespace :security do
  desc "Start security monitoring background jobs"
  task start_monitoring: :environment do
    puts "Starting security monitoring system..."
    
    # Start immediate monitoring
    SecurityMonitoringJob.perform_later
    
    # Start daily reporting
    SecurityReportJob.perform_later
    
    puts "Security monitoring jobs started successfully"
    puts "- User activity monitoring runs every 15 minutes"
    puts "- Security reports generate daily"
    puts "- Check Rails logs for security alerts"
  end
  
  desc "Generate immediate security report"
  task report: :environment do
    puts "Generating security report..."
    
    report = SecurityMonitoringService.generate_security_report
    
    puts "\n" + "="*60
    puts "SECURITY REPORT - #{report[:period]}"
    puts "="*60
    puts "Total Alerts: #{report[:total_alerts]}"
    puts "\nAlerts by Severity:"
    report[:alerts_by_severity].each do |severity, count|
      puts "  #{severity.to_s.capitalize}: #{count}"
    end
    
    puts "\nBlocked IPs: #{report[:blocked_ips].count}"
    report[:blocked_ips].each { |ip| puts "  - #{ip}" }
    
    puts "\nSuspicious Users: #{report[:suspicious_users].count}"
    report[:suspicious_users].each { |user| puts "  - User #{user}" }
    
    puts "\nRecommendations:"
    report[:recommendations].each { |rec| puts "  - #{rec}" }
    puts "="*60
  end
  
  desc "Analyze user activity for suspicious patterns"
  task :analyze_users, [:time_window] => :environment do |t, args|
    time_window = args[:time_window]&.to_i&.hours || 24.hours
    
    puts "Analyzing user activity patterns for last #{time_window/1.hour} hours..."
    
    suspicious_count = 0
    total_users = 0
    
    User.find_each do |user|
      anomalies = SecurityMonitoringService.analyze_user_activity(user.id, time_window)
      
      if anomalies.any?
        puts "User #{user.id} (#{user.email_address}): #{anomalies.join(', ')}"
        suspicious_count += 1
      end
      
      total_users += 1
    end
    
    puts "\nAnalysis complete:"
    puts "Total users analyzed: #{total_users}"
    puts "Users with suspicious activity: #{suspicious_count}"
    puts "Suspicion rate: #{(suspicious_count.to_f / total_users * 100).round(2)}%"
  end
  
  desc "Block IP address temporarily"
  task :block_ip, [:ip_address, :duration] => :environment do |t, args|
    ip = args[:ip_address]
    duration = args[:duration]&.to_i&.hours || 1.hour
    
    if ip.blank?
      puts "Usage: rake security:block_ip[192.168.1.1,24] (24 hours)"
      exit 1
    end
    
    cache_key = "blocked_ip:#{ip}"
    Rails.cache.write(cache_key, true, expires_in: duration)
    
    puts "IP #{ip} blocked for #{duration/1.hour} hours"
    
    # Log the manual block
    alert_data = {
      alert_type: "MANUAL_IP_BLOCK",
      ip_address: ip,
      duration: duration,
      blocked_by: "admin_rake_task",
      timestamp: Time.current
    }
    
    SecurityMonitoringService.send_alert(alert_data)
  end
  
  desc "Unblock IP address"
  task :unblock_ip, [:ip_address] => :environment do |t, args|
    ip = args[:ip_address]
    
    if ip.blank?
      puts "Usage: rake security:unblock_ip[192.168.1.1]"
      exit 1
    end
    
    cache_key = "blocked_ip:#{ip}"
    Rails.cache.delete(cache_key)
    
    puts "IP #{ip} unblocked"
    
    # Log the manual unblock
    Rails.logger.info "[SECURITY_ADMIN] IP #{ip} manually unblocked"
  end
  
  desc "List blocked IP addresses"
  task list_blocked_ips: :environment do
    puts "Currently blocked IP addresses:"
    
    # This would need cache inspection in real implementation
    puts "Note: Check Rails cache for 'blocked_ip:*' keys"
    puts "(Feature requires cache key enumeration capability)"
  end
  
  desc "Clean up old security data"
  task cleanup: :environment do
    puts "Cleaning up old security data..."
    
    # Clean up old sessions
    old_sessions = Session.where('created_at < ?', 3.months.ago)
    puts "Removing #{old_sessions.count} sessions older than 3 months"
    old_sessions.destroy_all
    
    # Clean up expired cache entries (this is automatic with Rails cache)
    puts "Cache cleanup is handled automatically by Rails"
    
    puts "Security data cleanup complete"
  end
  
  desc "Test security monitoring system"
  task test_monitoring: :environment do
    puts "Testing security monitoring system..."
    
    # Test alert generation
    test_alert = {
      alert_type: "SYSTEM_TEST",
      test_timestamp: Time.current,
      message: "Security monitoring system test"
    }
    
    alert_id = SecurityMonitoringService.send_alert(test_alert)
    puts "Test alert generated with ID: #{alert_id}"
    
    # Test job functionality
    puts "Testing security monitoring job..."
    SecurityMonitoringJob.perform_now(1.hour)
    
    puts "Security monitoring system test complete"
  end
end