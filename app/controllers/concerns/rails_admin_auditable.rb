module RailsAdminAuditable
  extend ActiveSupport::Concern
  
  included do
    after_action :log_admin_action, if: :admin_action_performed?
  end
  
  private
  
  def admin_action_performed?
    # Only log write actions in admin panel
    controller_name == 'rails_admin/main' && 
      %w[create update destroy bulk_delete].include?(action_name)
  end
  
  def log_admin_action
    return unless current_user
    
    action = determine_admin_action
    auditable = determine_auditable
    changes = determine_changes
    
    AdminAuditLog.log_action(
      user: current_user,
      action: action,
      auditable: auditable,
      changes: changes,
      request: request
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log admin action: #{e.message}"
  end
  
  def determine_admin_action
    case action_name
    when 'create'
      "created_#{@model_config.abstract_model.model.name.underscore}"
    when 'update'
      "updated_#{@model_config.abstract_model.model.name.underscore}"
    when 'destroy'
      "deleted_#{@model_config.abstract_model.model.name.underscore}"
    when 'bulk_delete'
      "bulk_deleted_#{@model_config.abstract_model.model.name.underscore.pluralize}"
    else
      action_name
    end
  end
  
  def determine_auditable
    case action_name
    when 'create', 'update'
      @object
    when 'destroy'
      # Object might be destroyed, so we log the class and ID
      { type: @model_config.abstract_model.model.name, id: params[:id] }
    when 'bulk_delete'
      { type: @model_config.abstract_model.model.name, ids: params[:bulk_ids] }
    else
      nil
    end
  end
  
  def determine_changes
    case action_name
    when 'create'
      @object.attributes
    when 'update'
      @object.previous_changes.except('updated_at')
    when 'destroy'
      { deleted_record: @object.attributes }
    when 'bulk_delete'
      { deleted_count: params[:bulk_ids]&.size || 0 }
    else
      nil
    end
  end
end