module ActivityTracker
  extend ActiveSupport::Concern

  included do
    around_action :track_activity, if: :track_activity?
    before_action :set_current_request_context
  end

  private

  def track_activity
    return yield unless current_user && track_activity?

    start_time = Time.current
    
    # Set request ID for logging correlation
    Thread.current[:request_id] = request.request_id
    
    # Log the start of the action
    ActivityLogger.log(:debug, "Action started", {
      controller: controller_name,
      action: action_name,
      user_id: current_user.id,
      method: request.method
    })
    
    yield
    
    # Track successful activities
    response_time = Time.current - start_time
    log_user_activity(response_time: response_time) if start_time
    
    # Log performance metrics for slow requests
    if response_time > 1.0
      ActivityLogger.performance('slow_request', "Slow request detected", {
        controller: controller_name,
        action: action_name,
        duration_ms: (response_time * 1000).round,
        path: request.path
      })
    end
    
  rescue => e
    # Track failed activities
    response_time = start_time ? Time.current - start_time : nil
    
    # Log the error
    ActivityLogger.log(:error, "Action failed", {
      controller: controller_name,
      action: action_name,
      error: e.message,
      backtrace: e.backtrace.first(5),
      duration_ms: response_time ? (response_time * 1000).round : nil
    })
    
    log_user_activity(
      response_time: response_time,
      error: e.message,
      response_status: 500
    ) if current_user
    raise e
  ensure
    Thread.current[:request_id] = nil
  end

  def log_user_activity(additional_metadata = {})
    return unless current_user && should_log_activity?

    metadata = {
      params: filtered_params,
      response_time: additional_metadata[:response_time],
      error: additional_metadata[:error],
      request_format: request.format.to_s,
      ajax_request: request.xhr?,
      ssl: request.ssl?
    }.compact

    activity = Activity.log_activity(
      user: current_user,
      action: action_name,
      controller: controller_name,
      request: request,
      response: response,
      metadata: metadata
    )

    # Check for suspicious activity
    if activity.persisted?
      suspicious = check_suspicious_activity(activity)
      
      # Log security events
      if suspicious
        ActivityLogger.security('suspicious_activity', "Suspicious activity detected", {
          activity_id: activity.id,
          reasons: activity.metadata['suspicious_reasons']
        })
      end
    end
  rescue => e
    Rails.logger.error "Failed to log activity: #{e.message}"
    ActivityLogger.log(:error, "Activity logging failed", {
      error: e.message,
      controller: controller_name,
      action: action_name
    })
  end

  def check_suspicious_activity(activity)
    SuspiciousActivityDetector.new(activity).check
  end

  def track_activity?
    # Track all actions by default, override in controllers as needed
    true
  end

  def should_log_activity?
    # Don't log certain actions to avoid noise
    skip_actions = %w[heartbeat health_check]
    skip_controllers = %w[rails_admin active_storage]
    
    !skip_actions.include?(action_name) && 
    !skip_controllers.include?(controller_name) &&
    !request.path.start_with?('/rails/active_storage')
  end

  def filtered_params
    # Remove sensitive parameters
    request.filtered_parameters.except("controller", "action", "authenticity_token")
  rescue
    {}
  end
  
  def set_current_request_context
    # Set context for Current attributes
    Current.request_id = request.request_id
    Current.user_agent = request.user_agent
    Current.ip_address = request.remote_ip
    Current.session_id = session.id if session.loaded?
  end
end