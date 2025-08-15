class SecurityMonitorService
  include ActiveSupport::Configurable
  
  # Configuration options
  config_accessor :max_failed_attempts, default: 5
  config_accessor :lockout_duration, default: 30.minutes
  config_accessor :suspicious_activity_threshold, default: 10
  
  def initialize
    @cache_prefix = 'security_monitor'
  end
  
  # Track failed login attempts
  def track_failed_login(ip_address, email = nil)
    key = failed_login_key(ip_address)
    # Use fetch with a block to ensure atomic read and increment
    count = Rails.cache.fetch(key, expires_in: 1.hour) { 0 }
    count += 1
    Rails.cache.write(key, count, expires_in: 1.hour)
    
    Rails.logger.warn "Failed login attempt #{count} from IP: #{ip_address}" + 
                     (email ? " for email: #{email}" : "")
    
    if count >= max_failed_attempts
      Rails.logger.error "IP #{ip_address} exceeded failed login threshold. Potential brute force attack."
      block_ip(ip_address)
    end
    
    count
  end
  
  # Clear failed login attempts (on successful login)
  def clear_failed_attempts(ip_address)
    Rails.cache.delete(failed_login_key(ip_address))
  end
  
  # Check if IP is blocked
  def ip_blocked?(ip_address)
    !!Rails.cache.read(blocked_ip_key(ip_address))
  end
  
  # Block an IP address
  def block_ip(ip_address, duration = lockout_duration)
    Rails.cache.write(blocked_ip_key(ip_address), true, expires_in: duration)
    Rails.logger.error "Blocked IP address: #{ip_address} for #{duration} seconds"
  end
  
  # Unblock an IP address
  def unblock_ip(ip_address)
    Rails.cache.delete(blocked_ip_key(ip_address))
    Rails.logger.info "Unblocked IP address: #{ip_address}"
  end
  
  # Track suspicious activity
  def track_suspicious_activity(user_id, activity_type, details = {})
    key = suspicious_activity_key(user_id)
    
    activity_data = {
      type: activity_type,
      timestamp: Time.current,
      details: details
    }
    
    # Use fetch to ensure we always get an array
    activities = Rails.cache.fetch(key, expires_in: 24.hours) { [] }
    activities = [] unless activities.is_a?(Array) # Safety check
    activities << activity_data
    
    # Keep only last 24 hours of activities
    activities = activities.select { |a| a[:timestamp] > 24.hours.ago }
    
    Rails.cache.write(key, activities, expires_in: 24.hours)
    
    # Check if threshold exceeded
    if activities.count >= suspicious_activity_threshold
      Rails.logger.error "User #{user_id} exceeded suspicious activity threshold"
      alert_administrators(user_id, activities)
    end
    
    activities.count
  end
  
  # Get security metrics
  def security_metrics
    {
      total_sessions: Session.count,
      active_sessions: Session.active.count,
      expired_sessions: Session.expired.count,
      suspicious_sessions: Session.suspicious_sessions.count,
      blocked_ips: blocked_ips_count,
      recent_failed_logins: recent_failed_logins_count
    }
  end
  
  # Generate security report
  def generate_security_report
    metrics = security_metrics
    
    report = {
      generated_at: Time.current,
      summary: metrics,
      details: {
        users_with_suspicious_sessions: users_with_suspicious_sessions,
        most_active_ips: most_active_ips,
        recent_security_events: recent_security_events
      }
    }
    
    Rails.logger.info "Security report generated: #{report.to_json}"
    report
  end
  
  # Check if user should be required to re-authenticate
  def require_reauth?(user)
    return false unless user
    
    # Force re-auth if user has suspicious sessions
    return true if user.has_suspicious_sessions?
    
    # Force re-auth if security score is too low
    return true if user.session_security_score < 50
    
    # Force re-auth if last login was too long ago
    last_session = user.sessions.order(:updated_at).last
    return true if last_session && last_session.updated_at < 7.days.ago
    
    false
  end
  
  private
  
  def failed_login_key(ip_address)
    "#{@cache_prefix}:failed_logins:#{ip_address}"
  end
  
  def blocked_ip_key(ip_address)
    "#{@cache_prefix}:blocked_ips:#{ip_address}"
  end
  
  def suspicious_activity_key(user_id)
    "#{@cache_prefix}:suspicious:#{user_id}"
  end
  
  def blocked_ips_count
    # This is a simplified count - in production you might want to track this differently
    Rails.cache.instance_variable_get(:@data)&.keys&.count { |k| k.include?('blocked_ips') } || 0
  end
  
  def recent_failed_logins_count
    # Count failed login attempts in the last hour
    Rails.cache.instance_variable_get(:@data)&.keys&.count { |k| k.include?('failed_logins') } || 0
  end
  
  def users_with_suspicious_sessions
    User.joins(:sessions).where(sessions: { id: Session.suspicious_sessions.select(:id) }).distinct.count
  end
  
  def most_active_ips
    # Get most common IP addresses from recent sessions
    Session.where('created_at > ?', 24.hours.ago)
           .group(:ip_address)
           .order(Arel.sql('COUNT(*) DESC'))
           .limit(10)
           .count
  end
  
  def recent_security_events
    # This would typically come from a dedicated security events table
    # For now, we'll return recent suspicious sessions
    Session.suspicious_sessions.recent.limit(10).map do |session|
      {
        type: 'suspicious_session',
        user_id: session.user_id,
        ip_address: session.ip_address,
        timestamp: session.created_at
      }
    end
  end
  
  def alert_administrators(user_id, activities)
    # In a real application, you might send emails or notifications
    Rails.logger.error "SECURITY ALERT: User #{user_id} suspicious activities: #{activities.to_json}"
    
    # You could implement email notifications here
    # AdminMailer.security_alert(user_id, activities).deliver_later
  end
end