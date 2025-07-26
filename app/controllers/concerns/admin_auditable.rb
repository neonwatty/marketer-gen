module AdminAuditable
  extend ActiveSupport::Concern

  included do
    if respond_to?(:after_action)
      after_action :log_admin_action, if: :should_audit?
    end
  end

  private

  def log_admin_action
    return unless current_user && admin_action_performed?

    action_name = determine_admin_action
    auditable = determine_auditable_resource
    changes = determine_changes

    AdminAuditLog.log_action(
      user: current_user,
      action: action_name,
      auditable: auditable,
      changes: changes,
      request: request
    )
  rescue => e
    Rails.logger.error "Failed to log admin action: #{e.message}"
  end

  def should_audit?
    # Only audit if user is admin and we're in the admin area
    current_user&.admin? && request.path.start_with?("/admin")
  end

  def admin_action_performed?
    # Check if the request method indicates a change was made
    request.post? || request.put? || request.patch? || request.delete?
  end

  def determine_admin_action
    case request.method.downcase
    when "post"
      params[:action] == "create" ? "created" : "action_performed"
    when "put", "patch"
      "updated"
    when "delete"
      "deleted"
    else
      "viewed"
    end
  end

  def determine_auditable_resource
    # Try to determine the resource being acted upon
    if defined?(@object) && @object.present?
      @object
    elsif params[:model_name].present? && params[:id].present?
      begin
        model_class = params[:model_name].classify.constantize
        model_class.find_by(id: params[:id])
      rescue
        nil
      end
    end
  end

  def determine_changes
    return nil unless defined?(@object) && @object.present?
    
    if @object.respond_to?(:previous_changes) && @object.previous_changes.any?
      # Filter out sensitive fields
      @object.previous_changes.except(
        "password_digest", 
        "password", 
        "password_confirmation",
        "session_token",
        "reset_token"
      )
    elsif params[:bulk_ids].present?
      { bulk_action: true, affected_ids: params[:bulk_ids] }
    else
      params.permit!.to_h.except(
        :controller, 
        :action, 
        :authenticity_token,
        :_method,
        :utf8,
        :password,
        :password_confirmation
      ).presence
    end
  end
end