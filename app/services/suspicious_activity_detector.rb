class SuspiciousActivityDetector
  attr_reader :activity
  
  # Class method for recurring job to scan all users
  def self.scan_all_users
    Rails.logger.info "Starting security scan for all users..."
    suspicious_users = []
    
    User.find_each do |user|
      # Check recent activities
      recent_activities = user.activities.where("occurred_at > ?", 1.hour.ago)
      next if recent_activities.empty?
      
      # Various suspicious pattern checks
      suspicious_patterns = []
      
      # Rapid requests
      if recent_activities.count > 200
        suspicious_patterns << {
          pattern: 'rapid_requests',
          value: recent_activities.count,
          threshold: 200
        }
      end
      
      # Multiple IPs
      ip_count = recent_activities.distinct.count(:ip_address)
      if ip_count > 5
        suspicious_patterns << {
          pattern: 'ip_hopping',
          value: ip_count,
          threshold: 5
        }
      end
      
      # Failed requests
      failed_count = recent_activities.failed_requests.count
      if failed_count > 20
        suspicious_patterns << {
          pattern: 'excessive_errors',
          value: failed_count,
          threshold: 20
        }
      end
      
      # Suspicious activities
      suspicious_count = recent_activities.suspicious.count
      if suspicious_count > 3
        suspicious_patterns << {
          pattern: 'multiple_suspicious',
          value: suspicious_count,
          threshold: 3
        }
      end
      
      if suspicious_patterns.any?
        suspicious_users << {
          user: user,
          patterns: suspicious_patterns,
          activity_count: recent_activities.count
        }
      end
    end
    
    # Process findings
    if suspicious_users.any?
      # Log security event
      ActivityLogger.security('security_scan_alert', "Security scan detected suspicious users", {
        user_count: suspicious_users.count,
        details: suspicious_users.map { |s| 
          {
            user_id: s[:user].id,
            email: s[:user].email_address,
            patterns: s[:patterns].map { |p| p[:pattern] }
          }
        }
      })
      
      # Send alerts if configured
      if Rails.application.config.activity_alerts.enabled
        AdminMailer.security_scan_alert(suspicious_users).deliver_later
      end
    end
    
    Rails.logger.info "Security scan completed. Found #{suspicious_users.count} suspicious users."
    suspicious_users
  end

  SUSPICIOUS_PATTERNS = {
    rapid_requests: {
      threshold: 100, # requests
      window: 60 # seconds
    },
    failed_logins: {
      threshold: 5, # attempts
      window: 300 # 5 minutes
    },
    unusual_hour_activity: {
      start_hour: 2, # 2 AM
      end_hour: 5 # 5 AM
    },
    ip_hopping: {
      threshold: 3, # different IPs
      window: 300 # 5 minutes
    },
    excessive_errors: {
      threshold: 10, # 4xx/5xx errors
      window: 300 # 5 minutes
    }
  }.freeze

  def initialize(activity)
    @activity = activity
  end

  def check
    suspicious_reasons = []

    suspicious_reasons << "rapid_requests" if rapid_requests?
    suspicious_reasons << "failed_login_attempts" if failed_login_attempts?
    suspicious_reasons << "unusual_hour_activity" if unusual_hour_activity?
    suspicious_reasons << "ip_hopping" if ip_hopping?
    suspicious_reasons << "excessive_errors" if excessive_errors?
    suspicious_reasons << "suspicious_user_agent" if suspicious_user_agent?
    suspicious_reasons << "suspicious_path" if suspicious_path?

    if suspicious_reasons.any?
      mark_as_suspicious(suspicious_reasons)
      trigger_alert(suspicious_reasons)
    end

    suspicious_reasons.any?
  end

  private

  def rapid_requests?
    threshold = SUSPICIOUS_PATTERNS[:rapid_requests][:threshold]
    window = SUSPICIOUS_PATTERNS[:rapid_requests][:window]

    recent_count = Activity
      .by_user(activity.user)
      .where("occurred_at > ?", window.seconds.ago)
      .count

    recent_count > threshold
  end

  def failed_login_attempts?
    return false unless activity.controller == "sessions" && activity.action == "create" && activity.failed?

    threshold = SUSPICIOUS_PATTERNS[:failed_logins][:threshold]
    window = SUSPICIOUS_PATTERNS[:failed_logins][:window]

    failed_count = Activity
      .by_user(activity.user)
      .by_controller("sessions")
      .by_action("create")
      .failed_requests
      .where("occurred_at > ?", window.seconds.ago)
      .count

    failed_count >= threshold
  end

  def unusual_hour_activity?
    hour = activity.occurred_at.hour
    start_hour = SUSPICIOUS_PATTERNS[:unusual_hour_activity][:start_hour]
    end_hour = SUSPICIOUS_PATTERNS[:unusual_hour_activity][:end_hour]

    hour >= start_hour && hour <= end_hour
  end

  def ip_hopping?
    threshold = SUSPICIOUS_PATTERNS[:ip_hopping][:threshold]
    window = SUSPICIOUS_PATTERNS[:ip_hopping][:window]

    unique_ips = Activity
      .by_user(activity.user)
      .where("occurred_at > ?", window.seconds.ago)
      .distinct
      .pluck(:ip_address)
      .compact
      .size

    unique_ips >= threshold
  end

  def excessive_errors?
    threshold = SUSPICIOUS_PATTERNS[:excessive_errors][:threshold]
    window = SUSPICIOUS_PATTERNS[:excessive_errors][:window]

    error_count = Activity
      .by_user(activity.user)
      .failed_requests
      .where("occurred_at > ?", window.seconds.ago)
      .count

    error_count >= threshold
  end

  def suspicious_user_agent?
    return false unless activity.user_agent

    suspicious_patterns = [
      /bot/i,
      /crawler/i,
      /spider/i,
      /scraper/i,
      /curl/i,
      /wget/i,
      /python/i,
      /java/i,
      /ruby/i
    ]

    suspicious_patterns.any? { |pattern| activity.user_agent.match?(pattern) }
  end

  def suspicious_path?
    return false unless activity.request_path

    suspicious_paths = [
      /\.env/i,
      /config\//i,
      /admin/i,
      /wp-admin/i,
      /phpmyadmin/i,
      /\.git/i,
      /\.svn/i,
      /backup/i,
      /sql/i,
      /database/i
    ]

    # Skip if the user is actually an admin accessing admin paths
    return false if activity.user.admin? && activity.request_path.match?(/admin/i)

    suspicious_paths.any? { |pattern| activity.request_path.match?(pattern) }
  end

  def mark_as_suspicious(reasons)
    metadata = activity.metadata || {}
    metadata["suspicious_reasons"] = reasons
    
    activity.update!(
      suspicious: true,
      metadata: metadata
    )
  end

  def trigger_alert(reasons)
    # In production, this would send notifications to admins
    Rails.logger.warn "Suspicious activity detected for user #{activity.user.email_address}: #{reasons.join(', ')}"
    
    # Queue alert job if configured
    if defined?(SuspiciousActivityAlertJob)
      SuspiciousActivityAlertJob.perform_later(activity.id, reasons)
    end
  end
end