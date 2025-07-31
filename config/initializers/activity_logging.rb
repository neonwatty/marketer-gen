# Activity Logging Configuration
# This initializer sets up comprehensive logging for user activities and security monitoring

Rails.application.configure do
  # Enable detailed logging in production for audit trails
  if Rails.env.production?
    config.log_level = :info
    
    # Use a separate log file for security events
    security_logger = ActiveSupport::Logger.new(Rails.root.join('log', 'security.log'))
    security_logger.formatter = Logger::Formatter.new
    
    # Tag security logs
    config.security_logger = ActiveSupport::TaggedLogging.new(security_logger)
  end
  
  # Configure activity tracking settings
  config.activity_tracking = ActiveSupport::OrderedOptions.new
  config.activity_tracking.enabled = true
  config.activity_tracking.track_anonymous = false # Only track authenticated users
  config.activity_tracking.retention_days = 90 # Keep logs for 90 days
  
  # Configure suspicious activity thresholds
  config.suspicious_activity = ActiveSupport::OrderedOptions.new
  config.suspicious_activity.rapid_requests_threshold = 100
  config.suspicious_activity.rapid_requests_window = 60 # seconds
  config.suspicious_activity.failed_login_threshold = 5
  config.suspicious_activity.failed_login_window = 300 # 5 minutes
  config.suspicious_activity.ip_hopping_threshold = 3
  config.suspicious_activity.ip_hopping_window = 300 # 5 minutes
  
  # Configure automated alerts
  config.activity_alerts = ActiveSupport::OrderedOptions.new
  config.activity_alerts.enabled = true
  config.activity_alerts.admin_emails = ENV.fetch('ADMIN_ALERT_EMAILS', '').split(',')
  config.activity_alerts.slack_webhook = ENV['SLACK_SECURITY_WEBHOOK']
  
  # Configure rate limiting for activities
  config.activity_rate_limits = ActiveSupport::OrderedOptions.new
  config.activity_rate_limits.requests_per_minute = 60
  config.activity_rate_limits.requests_per_hour = 1000
  config.activity_rate_limits.failed_logins_per_hour = 10
end

# Configure Rails logger for request ID tracing across all environments
# This ensures consistent logging with request IDs in development, test, and production
unless Rails.env.test?
  # Configure log tags to include request_id if not already configured
  if Rails.application.config.log_tags.blank?
    Rails.application.config.log_tags = [:request_id]
  elsif !Rails.application.config.log_tags.include?(:request_id)
    Rails.application.config.log_tags << :request_id
  end
  
  # Ensure we have a tagged logger for consistent behavior
  # In Rails 8.0, we need to use TaggedLogging instead of setting formatter directly
  unless Rails.logger.is_a?(ActiveSupport::TaggedLogging)
    if Rails.env.development?
      # In development, wrap the existing logger with TaggedLogging
      Rails.logger = ActiveSupport::TaggedLogging.new(Rails.logger)
    end
  end
end

# Add custom log subscribers for activity tracking
ActiveSupport::Notifications.subscribe 'process_action.action_controller' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  
  # Log performance metrics
  if event.duration > 1000 # Log slow requests (> 1 second)
    Rails.logger.warn "Slow request: #{event.payload[:controller]}##{event.payload[:action]} took #{event.duration}ms"
  end
  
  # Log error responses
  if event.payload[:status].to_i >= 400
    Rails.logger.error "Error response: #{event.payload[:controller]}##{event.payload[:action]} returned #{event.payload[:status]}"
  end
end

# Subscribe to security events
ActiveSupport::Notifications.subscribe 'suspicious_activity.security' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  
  if Rails.application.config.respond_to?(:security_logger) && Rails.application.config.security_logger
    Rails.application.config.security_logger.tagged('SECURITY', 'SUSPICIOUS') do
      Rails.application.config.security_logger.warn event.payload.to_json
    end
  end
end

# Subscribe to authentication events
ActiveSupport::Notifications.subscribe 'authenticate.action_controller' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  
  if event.payload[:success] == false
    Rails.logger.warn "Failed authentication attempt: #{event.payload[:email]} from #{event.payload[:ip]}"
  end
end