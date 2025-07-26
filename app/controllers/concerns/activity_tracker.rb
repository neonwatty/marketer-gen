module ActivityTracker
  extend ActiveSupport::Concern

  included do
    around_action :track_activity, if: :track_activity?
  end

  private

  def track_activity
    return yield unless current_user && track_activity?

    start_time = Time.current
    
    yield
    
    # Track successful activities
    response_time = Time.current - start_time
    log_user_activity(response_time: response_time) if start_time
    
  rescue => e
    # Track failed activities
    response_time = start_time ? Time.current - start_time : nil
    log_user_activity(
      response_time: response_time,
      error: e.message,
      response_status: 500
    ) if current_user
    raise e
  end

  def log_user_activity(additional_metadata = {})
    return unless current_user && should_log_activity?

    metadata = {
      params: filtered_params,
      response_time: additional_metadata[:response_time],
      error: additional_metadata[:error]
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
    check_suspicious_activity(activity) if activity.persisted?
  rescue => e
    Rails.logger.error "Failed to log activity: #{e.message}"
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
    !skip_controllers.include?(controller_name)
  end

  def filtered_params
    # Remove sensitive parameters
    request.filtered_parameters.except("controller", "action")
  rescue
    {}
  end
end