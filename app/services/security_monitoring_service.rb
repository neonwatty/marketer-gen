class SecurityMonitoringService
  # Security alert severity levels
  SEVERITY_LEVELS = {
    low: 1,
    medium: 2,
    high: 3,
    critical: 4
  }.freeze

  # Thresholds for different alert types
  ALERT_THRESHOLDS = {
    rapid_requests: { count: 5, window: 10.seconds, severity: :medium },
    failed_logins: { count: 5, window: 15.minutes, severity: :high },
    privilege_escalation: { count: 1, window: 1.hour, severity: :critical },
    suspicious_navigation: { count: 3, window: 5.minutes, severity: :medium },
    data_access_anomaly: { count: 10, window: 1.minute, severity: :high }
  }.freeze

  class << self
    # Main method to send security alerts
    def send_alert(alert_data)
      severity = determine_severity(alert_data)
      alert_id = generate_alert_id
      
      # Log the alert with structured data
      log_security_alert(alert_data, severity, alert_id)
      
      # Store alert in database for analysis
      store_alert(alert_data, severity, alert_id)
      
      # Send notifications based on severity
      send_notifications(alert_data, severity, alert_id) if should_notify?(severity)
      
      # Take automated actions if needed
      take_automated_actions(alert_data, severity) if should_auto_respond?(severity)
      
      alert_id
    end

    # Analyze activity patterns for anomalies
    def analyze_user_activity(user_id, time_window = 1.hour)
      activities = fetch_user_activities(user_id, time_window)
      anomalies = detect_anomalies(activities)
      
      if anomalies.any?
        alert_data = {
          alert_type: "ACTIVITY_ANOMALY",
          user_id: user_id,
          anomalies: anomalies,
          activity_count: activities.count,
          time_window: time_window,
          timestamp: Time.current
        }
        
        send_alert(alert_data)
      end
      
      anomalies
    end

    # Check for brute force attacks
    def check_brute_force_attempts(ip_address, time_window = 15.minutes)
      cache_key = "failed_attempts:#{ip_address}"
      attempts = Rails.cache.read(cache_key) || []
      
      # Clean old attempts
      cutoff_time = time_window.ago
      recent_attempts = attempts.select { |attempt| attempt[:timestamp] > cutoff_time }
      
      if recent_attempts.count >= ALERT_THRESHOLDS[:failed_logins][:count]
        alert_data = {
          alert_type: "BRUTE_FORCE_ATTACK",
          ip_address: ip_address,
          attempt_count: recent_attempts.count,
          time_window: time_window,
          timestamp: Time.current
        }
        
        send_alert(alert_data)
        
        # Block IP temporarily
        block_ip_address(ip_address, 1.hour)
      end
      
      recent_attempts.count
    end

    # Monitor for data exfiltration patterns
    def monitor_data_access(user_id, accessed_records_count, controller_action)
      cache_key = "data_access:#{user_id}"
      recent_access = Rails.cache.read(cache_key) || []
      
      # Track current access
      current_access = {
        controller_action: controller_action,
        record_count: accessed_records_count,
        timestamp: Time.current
      }
      
      recent_access << current_access
      
      # Keep only last hour of activity
      one_hour_ago = 1.hour.ago
      recent_access = recent_access.select { |access| access[:timestamp] > one_hour_ago }
      
      # Calculate total records accessed in last hour
      total_records = recent_access.sum { |access| access[:record_count] }
      
      # Alert if excessive data access
      if total_records > 100 # Configurable threshold
        alert_data = {
          alert_type: "EXCESSIVE_DATA_ACCESS",
          user_id: user_id,
          total_records_accessed: total_records,
          access_pattern: recent_access,
          timestamp: Time.current
        }
        
        send_alert(alert_data)
      end
      
      # Update cache
      Rails.cache.write(cache_key, recent_access, expires_in: 1.hour)
      
      total_records
    end

    # Generate security reports
    def generate_security_report(time_period = 24.hours)
      end_time = Time.current
      start_time = end_time - time_period
      
      report = {
        period: "#{start_time.strftime('%Y-%m-%d %H:%M')} to #{end_time.strftime('%Y-%m-%d %H:%M')}",
        total_alerts: count_alerts_in_period(start_time, end_time),
        alerts_by_severity: alerts_by_severity_in_period(start_time, end_time),
        top_threat_sources: top_threat_sources_in_period(start_time, end_time),
        blocked_ips: list_blocked_ips,
        suspicious_users: identify_suspicious_users(start_time, end_time),
        recommendations: generate_security_recommendations
      }
      
      Rails.logger.info "[SECURITY_REPORT] #{report.to_json}"
      report
    end

    private

    def determine_severity(alert_data)
      case alert_data[:alert_type]
      when "BRUTE_FORCE_ATTACK", "PRIVILEGE_ESCALATION"
        :critical
      when "EXCESSIVE_DATA_ACCESS", "SUSPICIOUS_ACTIVITY"
        :high
      when "RAPID_REQUESTS", "UNUSUAL_NAVIGATION"
        :medium
      else
        :low
      end
    end

    def generate_alert_id
      "SEC_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
    end

    def log_security_alert(alert_data, severity, alert_id)
      log_entry = {
        alert_id: alert_id,
        severity: severity,
        timestamp: Time.current.iso8601,
        **alert_data
      }
      
      case severity
      when :critical
        Rails.logger.error "[CRITICAL_SECURITY_ALERT] #{log_entry.to_json}"
      when :high
        Rails.logger.warn "[HIGH_SECURITY_ALERT] #{log_entry.to_json}"
      when :medium
        Rails.logger.warn "[MEDIUM_SECURITY_ALERT] #{log_entry.to_json}"
      else
        Rails.logger.info "[LOW_SECURITY_ALERT] #{log_entry.to_json}"
      end
    end

    def store_alert(alert_data, severity, alert_id)
      # Store in Rails cache for immediate access
      cache_key = "security_alert:#{alert_id}"
      alert_record = {
        id: alert_id,
        severity: severity,
        created_at: Time.current,
        **alert_data
      }
      
      Rails.cache.write(cache_key, alert_record, expires_in: 24.hours)
      
      # Also maintain a list of recent alerts
      recent_alerts_key = "recent_security_alerts"
      recent_alerts = Rails.cache.read(recent_alerts_key) || []
      recent_alerts << alert_id
      
      # Keep only last 100 alerts
      recent_alerts = recent_alerts.last(100)
      Rails.cache.write(recent_alerts_key, recent_alerts, expires_in: 24.hours)
    end

    def should_notify?(severity)
      # Send notifications for medium and higher severity alerts
      SEVERITY_LEVELS[severity] >= SEVERITY_LEVELS[:medium]
    end

    def should_auto_respond?(severity)
      # Take automated actions for high and critical alerts
      SEVERITY_LEVELS[severity] >= SEVERITY_LEVELS[:high]
    end

    def send_notifications(alert_data, severity, alert_id)
      # In a real application, this would send emails, Slack messages, etc.
      Rails.logger.info "[SECURITY_NOTIFICATION] Alert #{alert_id} with severity #{severity} triggered"
      
      # Example: Email notification for critical alerts
      if severity == :critical
        # SecurityMailer.critical_alert(alert_data, alert_id).deliver_later
      end
    end

    def take_automated_actions(alert_data, severity)
      case alert_data[:alert_type]
      when "BRUTE_FORCE_ATTACK"
        block_ip_address(alert_data[:ip_address], 1.hour) if alert_data[:ip_address]
      when "PRIVILEGE_ESCALATION"
        # Could terminate user sessions or require re-authentication
        if alert_data[:user_id]
          user = User.find_by(id: alert_data[:user_id])
          user&.terminate_all_sessions!
        end
      when "EXCESSIVE_DATA_ACCESS"
        # Could temporarily restrict user permissions
        Rails.logger.warn "[AUTO_ACTION] Consider reviewing user #{alert_data[:user_id]} permissions"
      end
    end

    def block_ip_address(ip_address, duration)
      cache_key = "blocked_ip:#{ip_address}"
      Rails.cache.write(cache_key, true, expires_in: duration)
      Rails.logger.warn "[AUTO_ACTION] IP #{ip_address} blocked for #{duration}"
    end

    def fetch_user_activities(user_id, time_window)
      # This would typically query a database or log aggregation system
      # For now, return mock data structure
      []
    end

    def detect_anomalies(activities)
      anomalies = []
      
      # Check for unusual time patterns
      if activities.any? { |a| a[:timestamp].hour.between?(2, 5) }
        anomalies << "unusual_time_access"
      end
      
      # Check for rapid sequential actions
      if activities.group_by { |a| a[:action] }.any? { |_, actions| actions.count > 10 }
        anomalies << "repetitive_actions"
      end
      
      anomalies
    end

    def count_alerts_in_period(start_time, end_time)
      # Would query stored alerts in real implementation
      0
    end

    def alerts_by_severity_in_period(start_time, end_time)
      { critical: 0, high: 0, medium: 0, low: 0 }
    end

    def top_threat_sources_in_period(start_time, end_time)
      []
    end

    def list_blocked_ips
      # Get currently blocked IPs from cache
      blocked_ips = []
      # This would scan cache for blocked_ip:* keys in real implementation
      blocked_ips
    end

    def identify_suspicious_users(start_time, end_time)
      []
    end

    def generate_security_recommendations
      [
        "Review user access patterns regularly",
        "Implement additional rate limiting for sensitive endpoints",
        "Consider enabling two-factor authentication for admin users",
        "Monitor for unusual geographic access patterns"
      ]
    end
  end

  # Instance methods for specific monitoring scenarios
  def initialize(user: nil, session: nil, request: nil)
    @user = user
    @session = session
    @request = request
  end

  def monitor_session_security
    return unless @session && @user
    
    security_score = calculate_session_security_score
    
    if security_score < 50 # Low security score threshold
      alert_data = {
        alert_type: "LOW_SESSION_SECURITY",
        user_id: @user.id,
        session_id: @session.id,
        security_score: security_score,
        factors: session_risk_factors,
        timestamp: Time.current
      }
      
      self.class.send_alert(alert_data)
    end
    
    security_score
  end

  private

  def calculate_session_security_score
    score = 100
    
    # Deduct for old sessions
    session_age = Time.current - @session.created_at
    score -= (session_age / 1.day) * 5
    
    # Deduct for suspicious user agent
    score -= 20 if @session.user_agent&.length&.> 500
    
    # Deduct for IP changes
    if @request && @session.ip_address != @request.remote_ip
      score -= 30
    end
    
    [score, 0].max
  end

  def session_risk_factors
    factors = []
    factors << "old_session" if @session.created_at < 1.week.ago
    factors << "suspicious_user_agent" if @session.user_agent&.length&.> 500
    factors << "ip_mismatch" if @request && @session.ip_address != @request.remote_ip
    factors
  end
end