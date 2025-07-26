# frozen_string_literal: true

module ActivityTrackable
  extend ActiveSupport::Concern

  included do
    # Track activity for all actions by default
    after_action :track_user_activity
  end

  private

  def track_user_activity
    return unless should_track_activity?

    UserActivity.log_activity(
      current_user,
      determine_activity_action,
      controller_name: controller_name,
      action_name: action_name,
      resource_type: determine_resource_type,
      resource_id: determine_resource_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      request_params: filtered_params,
      metadata: activity_metadata
    )
  rescue StandardError => e
    Rails.logger.error "Failed to track user activity: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def should_track_activity?
    # Only track if user is authenticated
    return false unless current_user.present?
    
    # Skip tracking for certain controllers/actions
    skip_controllers = %w[rails_admin]
    skip_actions = %w[show index]
    
    return false if skip_controllers.include?(controller_name)
    return false if skip_actions.include?(action_name) && request.get?
    
    true
  end

  def determine_activity_action
    case action_name
    when 'create'
      UserActivity::ACTIVITY_TYPES[:create]
    when 'update', 'edit'
      UserActivity::ACTIVITY_TYPES[:update]
    when 'destroy'
      UserActivity::ACTIVITY_TYPES[:delete]
    when 'download'
      UserActivity::ACTIVITY_TYPES[:download]
    when 'upload'
      UserActivity::ACTIVITY_TYPES[:upload]
    else
      # Map specific controller actions
      if controller_name == 'sessions' && action_name == 'create'
        UserActivity::ACTIVITY_TYPES[:login]
      elsif controller_name == 'sessions' && action_name == 'destroy'
        UserActivity::ACTIVITY_TYPES[:logout]
      elsif controller_name == 'passwords' && action_name == 'create'
        UserActivity::ACTIVITY_TYPES[:password_reset]
      elsif controller_name == 'profiles' && action_name == 'update'
        UserActivity::ACTIVITY_TYPES[:profile_update]
      else
        action_name
      end
    end
  end

  def determine_resource_type
    # Try to infer resource type from controller name
    return nil if params[:controller].blank?
    
    controller_parts = params[:controller].split('/')
    resource_name = controller_parts.last.singularize.camelize
    
    # Check if it's a valid model
    begin
      resource_name.constantize
      resource_name
    rescue NameError
      nil
    end
  end

  def determine_resource_id
    # Common parameter names for resource IDs
    id_params = [:id, :resource_id, "#{controller_name.singularize}_id".to_sym]
    
    id_params.each do |param|
      return params[param] if params[param].present?
    end
    
    nil
  end

  def filtered_params
    # Filter sensitive parameters
    filtered = params.except(
      :password,
      :password_confirmation,
      :token,
      :secret,
      :api_key,
      :access_token,
      :refresh_token,
      :authenticity_token
    )
    
    # Convert to hash and limit size
    filtered.to_unsafe_h.slice(*allowed_param_keys).to_json
  rescue StandardError
    '{}'
  end

  def allowed_param_keys
    # Define which parameters to log
    %w[action controller id page per_page search filter sort order]
  end

  def activity_metadata
    {
      session_id: session.id,
      referer: request.referer,
      method: request.method,
      path: request.path,
      timestamp: Time.current.iso8601
    }
  end

  # Helper method to track specific activities
  def track_activity(action, options = {})
    return unless current_user.present?

    UserActivity.log_activity(
      current_user,
      action,
      options.merge(
        controller_name: controller_name,
        action_name: action_name,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    )
  end

  # Track failed login attempts (call this manually in sessions controller)
  def track_failed_login(email)
    user = User.find_by(email: email)
    return unless user

    UserActivity.log_activity(
      user,
      UserActivity::ACTIVITY_TYPES[:failed_login],
      controller_name: controller_name,
      action_name: action_name,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      metadata: { attempted_email: email }
    )
  end
end