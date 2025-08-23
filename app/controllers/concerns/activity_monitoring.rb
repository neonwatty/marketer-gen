module ActivityMonitoring
  extend ActiveSupport::Concern

  included do
    before_action :log_user_activity
    after_action :detect_suspicious_patterns
  end

  private

  # General purpose activity logging method for controllers
  def log_activity(event_type, event_data = {})
    return unless Current.session&.user

    activity_data = {
      user_id: Current.session.user.id,
      session_id: Current.session.id,
      event_type: event_type,
      event_data: event_data,
      controller: controller_name,
      action: action_name,
      method: request.method,
      path: request.path,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      timestamp: Time.current
    }

    # Log to Rails logger with structured format
    Rails.logger.info "[ACTIVITY_LOG] #{activity_data.to_json}"
  end

  def log_user_activity
    # Ensure Current.session is set by calling resume_session if needed
    if Current.session.nil? && respond_to?(:resume_session, true)
      resume_session
    end
    
    return unless Current.session&.user

    activity_data = {
      user_id: Current.session.user.id,
      session_id: Current.session.id,
      controller: controller_name,
      action: action_name,
      method: request.method,
      path: request.path,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      timestamp: Time.current,
      params: filtered_params_for_logging
    }

    # Log to Rails logger with structured format
    Rails.logger.info "[USER_ACTIVITY] #{activity_data.to_json}"

    # Store in session for pattern analysis
    store_activity_in_session(activity_data)
  end

  def detect_suspicious_patterns
    return unless Current.session

    suspicious_indicators = []

    # Check for rapid successive requests (possible bot activity)
    if rapid_requests_detected?
      suspicious_indicators << "rapid_requests"
    end

    # Check for unusual navigation patterns
    if unusual_navigation_pattern?
      suspicious_indicators << "unusual_navigation"
    end

    # Check for access to multiple user accounts
    if multiple_user_access_pattern?
      suspicious_indicators << "multiple_user_access"
    end

    # Check for sensitive action attempts
    if sensitive_action_attempted?
      suspicious_indicators << "sensitive_action_access"
    end

    if suspicious_indicators.any?
      log_suspicious_activity(suspicious_indicators)
      handle_suspicious_activity(suspicious_indicators)
    end
  rescue => e
    # Log any exceptions that occur during suspicious pattern detection
    Rails.logger.error "[ACTIVITY_MONITORING] Error in detect_suspicious_patterns: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def store_activity_in_session(activity_data)
    # Store last 20 activities in session metadata for pattern analysis
    session[:recent_activities] ||= []
    session[:recent_activities] << {
      controller: activity_data[:controller],
      action: activity_data[:action],
      timestamp: activity_data[:timestamp].to_f,  # Use float for more precision
      ip: activity_data[:ip_address]
    }
    
    # Keep only last 20 activities
    session[:recent_activities] = session[:recent_activities].last(20)
  end

  def rapid_requests_detected?
    recent_activities = session[:recent_activities] || []
    return false if recent_activities.length < 5

    # Check if 5+ requests in last 10 seconds
    ten_seconds_ago = 10.seconds.ago.to_f
    recent_count = recent_activities.count do |activity| 
      timestamp = activity[:timestamp] || activity["timestamp"]  # Handle both symbol and string keys
      timestamp && timestamp > ten_seconds_ago
    end
    
    recent_count >= 5
  end

  def unusual_navigation_pattern?
    recent_activities = session[:recent_activities] || []
    return false if recent_activities.length < 3

    # Check for direct access to admin/sensitive pages without normal navigation
    last_three = recent_activities.last(3)
    sensitive_controllers = %w[admin users profiles]
    
    # If accessing sensitive area without coming from home or dashboard  
    last_controller = last_three.last[:controller] || last_three.last["controller"]
    if last_controller&.in?(sensitive_controllers)
      normal_entry_points = %w[home dashboard sessions]
      previous_controllers = last_three.first(2).map { |a| a[:controller] || a["controller"] }
      
      !previous_controllers.any? { |c| c&.in?(normal_entry_points) }
    else
      false
    end
  end

  def multiple_user_access_pattern?
    # This would require tracking across sessions, implemented via database
    # For now, check session metadata for user switching indicators
    false # Placeholder - would need more sophisticated tracking
  end

  def sensitive_action_attempted?
    sensitive_actions = {
      'users' => %w[destroy update],
      'sessions' => %w[destroy],
      'profiles' => %w[update destroy],
      'admin' => %w[index show update destroy]
    }

    controller_sensitive_actions = sensitive_actions[controller_name]
    return false unless controller_sensitive_actions

    controller_sensitive_actions.include?(action_name)
  end

  def log_suspicious_activity(indicators)
    activity_alert = {
      alert_type: "SUSPICIOUS_ACTIVITY",
      user_id: Current.session.user.id,
      session_id: Current.session.id,
      indicators: indicators,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      controller: controller_name,
      action: action_name,
      path: request.path,
      timestamp: Time.current,
      recent_activities: session[:recent_activities]
    }

    # Log with high priority
    Rails.logger.warn "[SECURITY_ALERT] #{activity_alert.to_json}"

    # Send to security monitoring service
    SecurityMonitoringService.send_alert(activity_alert)
  end

  def handle_suspicious_activity(indicators)
    # Rate limiting for rapid requests
    if indicators.include?("rapid_requests")
      # Could implement rate limiting here
      Rails.logger.info "[ACTIVITY_MONITORING] Rate limiting triggered for user #{Current.session.user.id}"
    end

    # Additional security measures for high-risk indicators
    high_risk_indicators = %w[multiple_user_access sensitive_action_access]
    if (indicators & high_risk_indicators).any?
      # Store suspicious activity indicator in session for tracking
      session[:suspicious_activity_detected] = true
      session[:suspicious_indicators] = indicators
      
      # Could trigger additional authentication requirements
      Rails.logger.warn "[ACTIVITY_MONITORING] High-risk activity detected for user #{Current.session.user.id}"
    end
  end

  def filtered_params_for_logging
    # Remove sensitive parameters from logging
    filtered = params.deep_dup
    filtered = filter_sensitive_keys(filtered)
    
    # Truncate large values
    filtered.transform_values do |value|
      if value.is_a?(String) && value.length > 200
        "#{value[0..197]}..."
      else
        value
      end
    end
  end

  def filter_sensitive_keys(hash)
    return hash unless hash.is_a?(Hash) || hash.is_a?(ActionController::Parameters)
    
    sensitive_keys = [:password, :password_confirmation, :current_password, :authenticity_token, "password", "password_confirmation", "current_password", "authenticity_token"]
    
    hash.each do |key, value|
      if sensitive_keys.include?(key) || sensitive_keys.include?(key.to_s) || sensitive_keys.include?(key.to_sym)
        hash[key] = "[FILTERED]"
      elsif value.is_a?(Hash) || value.is_a?(ActionController::Parameters)
        filter_sensitive_keys(value)
      end
    end
    
    hash
  end

  # Helper methods for checking specific activity patterns
  def failed_login_attempts_exceeded?
    # Check for excessive failed login attempts
    # This would typically be tracked in a separate model or cache
    false # Placeholder
  end

  def privilege_escalation_attempted?
    # Check if user is trying to access resources above their permission level
    return false unless Current.session&.user

    # Example: non-admin trying to access admin functions
    if controller_name == 'admin' && !Current.session.user.admin?
      true
    else
      false
    end
  end

  def data_exfiltration_pattern?
    # Check for patterns that might indicate data theft
    # E.g., accessing many user records quickly
    recent_activities = session[:recent_activities] || []
    
    # Check if accessing many show/index actions rapidly
    last_minute = 1.minute.ago.to_i
    recent_read_actions = recent_activities.select do |activity|
      activity[:timestamp] > last_minute && 
      activity[:action].in?(%w[show index export])
    end
    
    recent_read_actions.count > 10
  end

  # Class methods for activity analysis
  module ClassMethods
    def track_activity_for(*actions)
      # Allow selective activity tracking for specific actions
      before_action :log_user_activity, only: actions
      after_action :detect_suspicious_patterns, only: actions
    end

    def skip_activity_monitoring_for(*actions)
      # Allow skipping monitoring for specific actions (e.g., health checks)
      skip_before_action :log_user_activity, only: actions
      skip_after_action :detect_suspicious_patterns, only: actions
    end
  end
end