class ActivityLogger
  include Singleton
  
  SECURITY_EVENTS = %w[
    authentication_failure
    authorization_failure
    suspicious_activity
    account_locked
    password_reset
    admin_action
    data_export
    bulk_operation
    system_error
    repeated_errors
    unusual_error_pattern
  ].freeze
  
  PERFORMANCE_EVENTS = %w[
    slow_request
    database_slow_query
    cache_miss
    api_timeout
    background_job_failure
  ].freeze
  
  class << self
    delegate :log, :security, :performance, :audit, to: :instance
  end
  
  def initialize
    @logger = Rails.logger
    @security_logger = Rails.application.config.respond_to?(:security_logger) ? 
                       Rails.application.config.security_logger : 
                       Rails.logger
  end
  
  # General activity logging
  def log(level, message, context = {})
    structured_log = build_log_entry(message, context)
    @logger.send(level, structured_log.to_json)
    
    # Also log to database if it's an important event
    persist_to_database(level, message, context) if should_persist?(level, context)
  end
  
  # Security-specific logging
  def security(event_type, message, context = {})
    return unless SECURITY_EVENTS.include?(event_type.to_s)
    
    context[:event_type] = event_type
    context[:security_event] = true
    
    @security_logger.tagged('SECURITY', event_type.to_s.upcase) do
      @security_logger.warn build_log_entry(message, context).to_json
    end
    
    # Trigger notifications for critical security events
    notify_security_event(event_type, message, context) if critical_security_event?(event_type)
    
    # Instrument for monitoring
    ActiveSupport::Notifications.instrument('suspicious_activity.security', 
      event_type: event_type,
      message: message,
      context: context
    )
  end
  
  # Performance logging
  def performance(metric_type, message, context = {})
    return unless PERFORMANCE_EVENTS.include?(metric_type.to_s)
    
    context[:metric_type] = metric_type
    context[:performance_event] = true
    
    @logger.tagged('PERFORMANCE', metric_type.to_s.upcase) do
      @logger.info build_log_entry(message, context).to_json
    end
    
    # Send to monitoring service
    send_to_monitoring(metric_type, context) if Rails.env.production?
  end
  
  # Audit logging for compliance
  def audit(action, resource, changes = {}, user = nil)
    audit_entry = {
      action: action,
      resource_type: resource.class.name,
      resource_id: resource.id,
      changes: sanitize_changes(changes),
      user_id: user&.id,
      user_email: user&.email_address,
      timestamp: Time.current.iso8601
    }
    
    @logger.tagged('AUDIT') do
      @logger.info audit_entry.to_json
    end
    
    # Store audit trail in database
    if defined?(AdminAuditLog) && user
      AdminAuditLog.create!(
        user: user,
        action: action,
        auditable: resource,
        change_details: sanitize_changes(changes).to_json,
        ip_address: Current.ip_address,
        user_agent: Current.user_agent
      )
    end
  end
  
  private
  
  def build_log_entry(message, context = {})
    {
      timestamp: Time.current.iso8601,
      level: context[:level] || 'info',
      message: message,
      request_id: Current.request_id || Thread.current[:request_id],
      user_id: Current.user&.id,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      session_id: Current.session_id,
      context: context.except(:level)
    }.compact
  end
  
  def should_persist?(level, context)
    # Persist warnings, errors, and security events
    %w[warn error fatal].include?(level.to_s) || 
    context[:security_event] || 
    context[:audit_event]
  end
  
  def persist_to_database(level, message, context)
    return unless Current.user
    
    Activity.create!(
      user: Current.user,
      action: context[:action] || 'system_log',
      controller: context[:controller] || 'system',
      metadata: {
        message: message,
        level: level,
        context: context
      },
      suspicious: context[:security_event] || level.to_s == 'error'
    )
  rescue => e
    Rails.logger.error "Failed to persist log to database: #{e.message}"
  end
  
  def critical_security_event?(event_type)
    %w[suspicious_activity account_locked authorization_failure system_error repeated_errors].include?(event_type.to_s)
  end
  
  def notify_security_event(event_type, message, context)
    # Queue notification job
    if defined?(SecurityNotificationJob)
      SecurityNotificationJob.perform_later(
        event_type: event_type,
        message: message,
        context: context
      )
    end
  end
  
  def send_to_monitoring(metric_type, context)
    # Integration with monitoring services like DataDog, New Relic, etc.
    # This is a placeholder for actual monitoring integration
    Rails.logger.info "Monitoring metric: #{metric_type} - #{context.to_json}"
  end
  
  def sanitize_changes(changes)
    # Remove sensitive data from audit logs
    sensitive_fields = %w[password password_confirmation password_digest token secret]
    
    changes.deep_dup.tap do |sanitized|
      sensitive_fields.each do |field|
        sanitized.delete(field)
        sanitized.delete(field.to_sym)
      end
    end
  end
  
  # Error pattern detection methods
  def self.track_error_pattern(error_type, context = {})
    return unless Rails.env.production?
    
    # Track error patterns by IP, user, and error type
    ip_key = "error_pattern_ip_#{context[:ip_address]}_#{error_type}"
    user_key = "error_pattern_user_#{context[:user_id]}_#{error_type}" if context[:user_id]
    global_key = "error_pattern_global_#{error_type}"
    
    # Increment counters
    ip_count = Rails.cache.increment(ip_key, 1, expires_in: 1.hour) || 1
    user_count = Rails.cache.increment(user_key, 1, expires_in: 1.hour) || 1 if user_key
    global_count = Rails.cache.increment(global_key, 1, expires_in: 1.hour) || 1
    
    # Check for suspicious patterns
    check_error_patterns(error_type, ip_count, user_count, global_count, context)
  end
  
  def self.check_error_patterns(error_type, ip_count, user_count, global_count, context)
    # IP-based pattern detection
    if ip_count && ip_count > 20
      instance.security('repeated_errors', 
        "Excessive #{error_type} errors from IP", 
        context.merge(error_count: ip_count, pattern_type: 'ip_based')
      )
    end
    
    # User-based pattern detection
    if user_count && user_count > 15
      instance.security('repeated_errors', 
        "Excessive #{error_type} errors from user", 
        context.merge(error_count: user_count, pattern_type: 'user_based')
      )
    end
    
    # Global pattern detection
    if global_count && global_count > 100
      instance.security('unusual_error_pattern', 
        "Unusual spike in #{error_type} errors globally", 
        context.merge(error_count: global_count, pattern_type: 'global_spike')
      )
    end
  end
  
  def self.error_recovery_suggestions(error_type, context = {})
    case error_type.to_s
    when 'not_found'
      [
        "Check URL for typos",
        "Use site navigation",
        "Search for content",
        "Contact support if needed"
      ]
    when 'unprocessable_entity'
      [
        "Review form data for completeness",
        "Check data format requirements",
        "Refresh session if expired",
        "Contact support for permission issues"
      ]
    when 'internal_server_error'
      [
        "Wait a few minutes and try again",
        "Check system status page",
        "Try different browser or device",
        "Contact support if problem persists"
      ]
    else
      [
        "Refresh the page",
        "Try again in a few minutes",
        "Contact support if issue continues"
      ]
    end
  end
end