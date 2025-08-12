# WorkflowPermissionService - Role-based permission management for workflows
# Handles authorization, role assignments, and permission validation
class WorkflowPermissionService
  include ActiveModel::Model
  
  # Permission levels
  PERMISSION_LEVELS = {
    none: 0,
    read: 1,
    comment: 2,
    edit: 3,
    approve: 4,
    admin: 5
  }.freeze
  
  # Action to permission mapping
  ACTION_PERMISSIONS = {
    # Read actions
    'view' => :read,
    'list' => :read,
    'show' => :read,
    'history' => :read,
    'audit' => :read,
    
    # Comment actions
    'comment' => :comment,
    'note' => :comment,
    
    # Edit actions
    'create' => :edit,
    'edit' => :edit,
    'update' => :edit,
    'delete' => :edit,
    'submit_for_review' => :edit,
    'request_changes' => :edit,
    'return_to_draft' => :edit,
    
    # Approval actions
    'approve' => :approve,
    'reject' => :approve,
    'publish' => :approve,
    'schedule' => :approve,
    'archive' => :approve,
    'return_to_review' => :approve,
    
    # Administrative actions
    'assign_user' => :admin,
    'unassign_user' => :admin,
    'cancel_workflow' => :admin,
    'pause_workflow' => :admin,
    'resume_workflow' => :admin,
    'update_metadata' => :admin,
    'bulk_action' => :admin
  }.freeze
  
  attr_accessor :user, :workflow
  
  def initialize(user, workflow = nil)
    @user = user
    @workflow = workflow
  end
  
  # Core permission checking
  def can_perform_action?(action, context = {})
    return false unless @user
    
    # Admin users can do everything
    return true if is_admin?(@user)
    
    # Check if action is valid
    required_permission = ACTION_PERMISSIONS[action.to_s]
    return false unless required_permission
    
    # Get user's permission level for this workflow/stage
    user_permission_level = get_user_permission_level(context)
    required_permission_level = PERMISSION_LEVELS[required_permission]
    
    # Check if user has sufficient permission level
    user_permission_level >= required_permission_level
  end
  
  def can_view_workflow?
    can_perform_action?('view')
  end
  
  def can_edit_content?
    return false unless @workflow
    
    # Can edit if in draft stage and has edit permissions
    @workflow.current_stage == 'draft' && can_perform_action?('edit')
  end
  
  def can_submit_for_review?
    return false unless @workflow
    
    @workflow.current_stage == 'draft' && can_perform_action?('submit_for_review')
  end
  
  def can_approve_content?
    return false unless @workflow
    
    %w[review approved].include?(@workflow.current_stage) && can_perform_action?('approve')
  end
  
  def can_reject_content?
    return false unless @workflow
    
    %w[review approved].include?(@workflow.current_stage) && can_perform_action?('reject')
  end
  
  def can_publish_content?
    return false unless @workflow
    
    %w[approved scheduled].include?(@workflow.current_stage) && can_perform_action?('publish')
  end
  
  def can_assign_users?
    can_perform_action?('assign_user')
  end
  
  def can_manage_workflow?
    can_perform_action?('pause_workflow')
  end
  
  # Role-based checks
  def has_role?(role, stage = nil)
    return false unless @workflow && @user
    
    stage ||= @workflow.current_stage
    
    @workflow.assignments
             .current
             .where(user_id: @user.id, role: role.to_s, stage: stage.to_s)
             .exists?
  end
  
  def has_any_role?(roles, stage = nil)
    return false unless @workflow && @user
    
    stage ||= @workflow.current_stage
    
    @workflow.assignments
             .current
             .where(user_id: @user.id, role: roles.map(&:to_s), stage: stage.to_s)
             .exists?
  end
  
  def user_roles(stage = nil)
    return [] unless @workflow && @user
    
    stage ||= @workflow.current_stage
    
    @workflow.assignments
             .current
             .where(user_id: @user.id, stage: stage.to_s)
             .pluck(:role)
             .uniq
  end
  
  def highest_role(stage = nil)
    roles = user_roles(stage)
    return nil if roles.empty?
    
    # Return role with highest hierarchy level
    role_levels = roles.map do |role|
      [role, WorkflowEngine::WORKFLOW_ROLES.dig(role.to_sym, :hierarchy_level) || 0]
    end
    
    role_levels.max_by { |_role, level| level }&.first
  end
  
  # Permission level calculation
  def get_user_permission_level(context = {})
    return PERMISSION_LEVELS[:admin] if is_admin?(@user)
    return PERMISSION_LEVELS[:none] unless @workflow && @user
    
    stage = context[:stage] || @workflow.current_stage
    
    # Get all user roles for the current stage
    roles = user_roles(stage)
    return PERMISSION_LEVELS[:none] if roles.empty?
    
    # Calculate permission level based on highest role
    max_permission = PERMISSION_LEVELS[:none]
    
    roles.each do |role|
      role_permission = calculate_role_permission_level(role, stage)
      max_permission = [max_permission, role_permission].max
    end
    
    max_permission
  end
  
  def calculate_role_permission_level(role, stage)
    case role.to_s
    when 'creator'
      if stage == 'draft'
        PERMISSION_LEVELS[:edit]
      else
        PERMISSION_LEVELS[:comment]
      end
    when 'reviewer'
      if %w[draft review].include?(stage)
        PERMISSION_LEVELS[:approve]
      else
        PERMISSION_LEVELS[:read]
      end
    when 'approver'
      if %w[review approved].include?(stage)
        PERMISSION_LEVELS[:approve]
      else
        PERMISSION_LEVELS[:read]
      end
    when 'publisher'
      if %w[approved scheduled published].include?(stage)
        PERMISSION_LEVELS[:approve]
      else
        PERMISSION_LEVELS[:read]
      end
    when 'admin'
      PERMISSION_LEVELS[:admin]
    else
      PERMISSION_LEVELS[:read]
    end
  end
  
  # Permission scoping for queries
  def accessible_workflows(scope = ContentWorkflow.all)
    return scope if is_admin?(@user)
    return scope.none unless @user
    
    # Get workflows where user has any assignment
    assigned_workflow_ids = WorkflowAssignment.current
                                            .where(user_id: @user.id)
                                            .pluck(:content_workflow_id)
                                            .uniq
    
    # Also include workflows where user created content
    created_content_ids = get_user_created_content_ids
    created_workflow_ids = scope.where(content_item_id: created_content_ids).pluck(:id)
    
    accessible_ids = (assigned_workflow_ids + created_workflow_ids).uniq
    scope.where(id: accessible_ids)
  end
  
  def accessible_assignments(scope = WorkflowAssignment.all)
    return scope if is_admin?(@user)
    return scope.none unless @user
    
    # Users can see assignments for workflows they have access to
    accessible_workflow_ids = accessible_workflows.pluck(:id)
    scope.where(content_workflow_id: accessible_workflow_ids)
  end
  
  def accessible_audit_entries(scope = WorkflowAuditEntry.all)
    return scope if is_admin?(@user)
    return scope.none unless @user
    
    # Users can see audit entries for workflows they have access to
    accessible_workflow_ids = accessible_workflows.pluck(:id)
    scope.joins(:content_workflow).where(content_workflows: { id: accessible_workflow_ids })
  end
  
  # User management
  def can_assign_role?(target_user_id, role, stage)
    return false unless can_assign_users?
    
    # Users cannot assign roles higher than their own
    my_highest_role = highest_role(stage)
    return false unless my_highest_role
    
    my_level = WorkflowEngine::WORKFLOW_ROLES.dig(my_highest_role.to_sym, :hierarchy_level) || 0
    target_level = WorkflowEngine::WORKFLOW_ROLES.dig(role.to_sym, :hierarchy_level) || 0
    
    my_level >= target_level
  end
  
  def assignable_roles(stage = nil)
    return [] unless can_assign_users?
    
    my_highest_role = highest_role(stage)
    return [] unless my_highest_role
    
    my_level = WorkflowEngine::WORKFLOW_ROLES.dig(my_highest_role.to_sym, :hierarchy_level) || 0
    
    WorkflowEngine::WORKFLOW_ROLES.select do |_role, config|
      config[:hierarchy_level] <= my_level
    end.keys.map(&:to_s)
  end
  
  def assignable_users_for_role(role, stage = nil)
    return [] unless can_assign_role?(nil, role, stage)
    
    # This would integrate with your User model to find users with appropriate capabilities
    # For now, return mock user data
    case role.to_s
    when 'creator'
      get_users_with_capability('content_creation')
    when 'reviewer'
      get_users_with_capability('content_review')
    when 'approver'
      get_users_with_capability('content_approval')
    when 'publisher'
      get_users_with_capability('content_publishing')
    else
      []
    end
  end
  
  # Permission validation and reporting
  def permission_summary
    return { role: 'admin', level: 'admin', permissions: ['all'] } if is_admin?(@user)
    return { role: 'none', level: 'none', permissions: [] } unless @workflow
    
    stage = @workflow.current_stage
    roles = user_roles(stage)
    permission_level = get_user_permission_level
    
    available_actions = ACTION_PERMISSIONS.select do |action, required_level|
      PERMISSION_LEVELS[required_level] <= permission_level
    end.keys
    
    {
      user_id: @user.id,
      workflow_id: @workflow.id,
      current_stage: stage,
      roles: roles,
      highest_role: highest_role(stage),
      permission_level: PERMISSION_LEVELS.key(permission_level),
      available_actions: available_actions,
      specific_permissions: {
        can_view: can_view_workflow?,
        can_edit: can_edit_content?,
        can_submit: can_submit_for_review?,
        can_approve: can_approve_content?,
        can_reject: can_reject_content?,
        can_publish: can_publish_content?,
        can_assign: can_assign_users?,
        can_manage: can_manage_workflow?
      }
    }
  end
  
  def audit_permission_check(action, result, context = {})
    # Log permission checks for security auditing
    audit_data = {
      user_id: @user&.id,
      workflow_id: @workflow&.id,
      action: action,
      result: result,
      permission_level: get_user_permission_level(context),
      user_roles: user_roles(context[:stage]),
      timestamp: Time.current,
      context: context
    }
    
    Rails.logger.info "Permission Check: #{audit_data.to_json}"
    
    # Store in audit table if needed
    # PermissionAuditEntry.create!(audit_data)
  end
  
  # Bulk permission operations
  def self.bulk_permission_check(user, workflows, action)
    results = {}
    
    workflows.each do |workflow|
      permission_service = new(user, workflow)
      results[workflow.id] = permission_service.can_perform_action?(action)
    end
    
    results
  end
  
  def self.users_with_permission(workflow, action)
    # Find all users who can perform the specified action on the workflow
    user_ids = []
    
    # Get all assigned users
    assigned_users = workflow.assignments.current.pluck(:user_id).uniq
    
    # Check permission for each user
    assigned_users.each do |user_id|
      # This would load the actual User model
      # user = User.find(user_id)
      # permission_service = new(user, workflow)
      # user_ids << user_id if permission_service.can_perform_action?(action)
      
      # For now, mock the permission check
      user_ids << user_id if mock_user_can_perform_action?(user_id, workflow, action)
    end
    
    user_ids
  end
  
  def self.role_hierarchy_map
    WorkflowEngine::WORKFLOW_ROLES.transform_values do |config|
      {
        level: config[:hierarchy_level],
        permissions: config[:permissions],
        description: config[:description]
      }
    end.sort_by { |_role, data| data[:level] }.to_h
  end
  
  private
  
  def is_admin?(user)
    # This would integrate with your User model
    # user.admin? || user.has_role?(:admin)
    
    # For now, check if user ID is in admin list (mock)
    admin_user_ids = [999, 1000] # Mock admin user IDs
    admin_user_ids.include?(user.id) if user.respond_to?(:id)
  end
  
  def get_user_created_content_ids
    # This would query for content created by the user
    # For now, return empty array
    []
  end
  
  def get_users_with_capability(capability)
    # This would query your User model for users with specific capabilities
    # For now, return mock user IDs
    case capability
    when 'content_creation'
      [1, 2, 3, 4, 5]
    when 'content_review'
      [6, 7, 8]
    when 'content_approval'
      [9, 10]
    when 'content_publishing'
      [11, 12]
    else
      []
    end
  end
  
  def self.mock_user_can_perform_action?(user_id, workflow, action)
    # Mock permission check for demonstration
    # In reality, this would properly check user permissions
    
    required_permission = ACTION_PERMISSIONS[action.to_s]
    return false unless required_permission
    
    # Mock: assume certain user IDs have certain permission levels
    user_permission_level = case user_id
    when 1..5
      PERMISSION_LEVELS[:edit]
    when 6..8
      PERMISSION_LEVELS[:approve]
    when 9..12
      PERMISSION_LEVELS[:admin]
    when 999, 1000
      PERMISSION_LEVELS[:admin]
    else
      PERMISSION_LEVELS[:read]
    end
    
    required_permission_level = PERMISSION_LEVELS[required_permission]
    user_permission_level >= required_permission_level
  end
end