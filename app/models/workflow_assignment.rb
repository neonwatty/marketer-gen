# WorkflowAssignment model - Tracks user assignments to workflow stages
# Manages role-based assignments and permissions for workflow stages
class WorkflowAssignment < ApplicationRecord
  belongs_to :content_workflow
  # User tracking - can be extended when User model is added
  # belongs_to :user
  # belongs_to :assigned_by, class_name: 'User', optional: true
  
  validates :user_id, presence: true
  validates :role, presence: true, inclusion: { 
    in: %w[creator reviewer approver publisher admin],
    message: 'must be a valid workflow role'
  }
  validates :stage, presence: true, inclusion: { 
    in: %w[draft review approved scheduled published archived],
    message: 'must be a valid workflow stage'
  }
  validates :user_id, uniqueness: { 
    scope: [:content_workflow_id, :stage, :role],
    message: 'User already assigned to this role and stage'
  }
  
  # Assignment status
  enum :status, {
    active: 0,
    inactive: 1,
    suspended: 2,
    expired: 3
  }, prefix: :assignment_status
  
  # Assignment types
  enum :assignment_type, {
    manual: 0,      # Manually assigned by user
    automatic: 1,   # Auto-assigned by system rules
    role_inherited: 2,   # Inherited from template or parent workflow
    temporary: 3    # Temporary assignment with expiration
  }, prefix: true
  
  scope :for_stage, ->(stage) { where(stage: stage) }
  scope :for_role, ->(role) { where(role: role) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :current, -> { assignment_status_active.where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at IS NOT NULL AND expires_at <= ?', Time.current) }
  scope :recent, -> { order(assigned_at: :desc) }
  
  before_validation :set_defaults, on: :create
  after_create :log_assignment_created
  after_update :log_assignment_updated, if: :saved_change_to_status?
  
  def initialize(attributes = {})
    super(attributes)
    self.assigned_at ||= Time.current
  end
  
  # Assignment status checks
  def is_active?
    assignment_status_active? && !is_expired?
  end
  
  def is_expired?
    expires_at.present? && expires_at <= Time.current
  end
  
  def is_current_stage?
    stage == content_workflow.current_stage
  end
  
  def can_act_in_current_stage?
    is_active? && is_current_stage?
  end
  
  def time_since_assignment
    Time.current - assigned_at
  end
  
  def time_until_expiration
    return nil unless expires_at
    return 0 if is_expired?
    
    expires_at - Time.current
  end
  
  # Role and permission management
  def role_hierarchy_level
    WorkflowEngine::WORKFLOW_ROLES.dig(role.to_sym, :hierarchy_level) || 0
  end
  
  def role_permissions
    WorkflowEngine::WORKFLOW_ROLES.dig(role.to_sym, :permissions) || []
  end
  
  def can_perform_action?(action)
    return false unless is_active?
    
    permissions = role_permissions
    return true if permissions.include?('all')
    
    permissions.include?(action.to_s)
  end
  
  def has_higher_role_than?(other_assignment)
    role_hierarchy_level > other_assignment.role_hierarchy_level
  end
  
  def effective_permissions
    base_permissions = role_permissions
    
    # Add stage-specific permissions
    stage_config = WorkflowEngine::WORKFLOW_STAGES[stage.to_sym]
    stage_actions = stage_config ? stage_config[:allowed_actions] : []
    
    # Intersection of role permissions and stage actions
    effective = base_permissions.include?('all') ? stage_actions : (base_permissions & stage_actions)
    
    {
      role: role,
      stage: stage,
      permissions: effective,
      can_act_in_current_stage: can_act_in_current_stage?,
      hierarchy_level: role_hierarchy_level
    }
  end
  
  # Assignment operations
  def activate!(activated_by = nil)
    update!(
      assignment_status: :active,
      activated_at: Time.current,
      activated_by_id: activated_by&.id
    )
    
    log_assignment_action('activated', "Assignment activated by #{activated_by&.name || 'system'}")
  end
  
  def deactivate!(reason = nil, deactivated_by = nil)
    update!(
      assignment_status: :inactive,
      unassigned_at: Time.current,
      unassigned_by_id: deactivated_by&.id
    )
    
    log_assignment_action('deactivated', reason || "Assignment deactivated by #{deactivated_by&.name || 'system'}")
  end
  
  def suspend!(reason, suspended_by = nil)
    update!(
      assignment_status: :suspended,
      suspended_at: Time.current,
      suspended_by_id: suspended_by&.id
    )
    
    log_assignment_action('suspended', reason)
  end
  
  def extend_expiration!(new_expiration, extended_by = nil)
    update!(
      expires_at: new_expiration,
      extended_at: Time.current,
      extended_by_id: extended_by&.id
    )
    
    log_assignment_action('extended', "Expiration extended to #{new_expiration}")
  end
  
  def make_permanent!(made_permanent_by = nil)
    update!(
      expires_at: nil,
      assignment_type: :manual,
      extended_at: Time.current,
      extended_by_id: made_permanent_by&.id
    )
    
    log_assignment_action('made_permanent', 'Assignment made permanent')
  end
  
  # Notification and communication
  def notify_assignment_created
    # Integration point for notification service
    WorkflowNotificationService.new.assignment_created(self)
  end
  
  def notify_assignment_expiring(days_before = 2)
    return unless expires_at
    return unless time_until_expiration <= days_before.days
    
    WorkflowNotificationService.new.assignment_expiring(self)
  end
  
  def notify_assignment_expired
    WorkflowNotificationService.new.assignment_expired(self)
  end
  
  # Reporting and analytics
  def activity_summary
    audit_entries = content_workflow.audit_entries.where(performed_by_id: user_id)
    
    {
      assignment_id: id,
      user_id: user_id,
      role: role,
      stage: stage,
      status: status,
      assignment_duration: time_since_assignment,
      actions_performed: audit_entries.count,
      last_action: audit_entries.order(:created_at).last&.action,
      last_activity: audit_entries.maximum(:created_at),
      is_current_stage: is_current_stage?,
      can_act: can_act_in_current_stage?
    }
  end
  
  def performance_metrics
    audit_entries = content_workflow.audit_entries.where(performed_by_id: user_id)
    stage_entries = audit_entries.where('from_stage = ? OR to_stage = ?', stage, stage)
    
    {
      total_actions: audit_entries.count,
      stage_specific_actions: stage_entries.count,
      average_response_time: calculate_average_response_time,
      efficiency_score: calculate_efficiency_score,
      collaboration_score: calculate_collaboration_score
    }
  end
  
  # Export and serialization
  def to_assignment_summary
    {
      id: id,
      user_id: user_id,
      role: role,
      stage: stage,
      status: status,
      assignment_type: assignment_type,
      assigned_at: assigned_at,
      expires_at: expires_at,
      is_active: is_active?,
      is_current_stage: is_current_stage?,
      can_act: can_act_in_current_stage?,
      permissions: effective_permissions,
      time_since_assignment: time_since_assignment.round(2),
      workflow_id: content_workflow_id
    }
  end
  
  # Class methods for management and reporting
  def self.auto_assign_users(workflow, stage, options = {})
    return [] unless workflow && stage
    
    template_name = workflow.template_name
    assignment_rules = load_assignment_rules(template_name)
    
    stage_rules = assignment_rules.dig(stage.to_s, 'auto_assign') || {}
    assignments_created = []
    
    stage_rules.each do |role, user_criteria|
      users = find_users_by_criteria(user_criteria)
      
      users.each do |user_id|
        assignment = create!(
          content_workflow: workflow,
          user_id: user_id,
          role: role,
          stage: stage,
          assignment_type: :automatic,
          assigned_at: Time.current,
          expires_at: options[:expires_at]
        )
        
        assignments_created << assignment
      end
    end
    
    assignments_created
  end
  
  def self.bulk_reassign(from_user_id, to_user_id, options = {})
    scope = active.where(user_id: from_user_id)
    scope = scope.where(stage: options[:stage]) if options[:stage]
    scope = scope.where(role: options[:role]) if options[:role]
    
    reassigned_count = 0
    
    scope.find_each do |assignment|
      new_assignment = assignment.dup
      new_assignment.user_id = to_user_id
      new_assignment.assigned_at = Time.current
      new_assignment.assignment_type = :manual
      
      if new_assignment.save
        assignment.deactivate!('Bulk reassignment', nil)
        reassigned_count += 1
      end
    end
    
    reassigned_count
  end
  
  def self.cleanup_expired_assignments
    expired_assignments = expired.active
    cleanup_count = 0
    
    expired_assignments.find_each do |assignment|
      assignment.update!(status: :expired)
      assignment.notify_assignment_expired
      cleanup_count += 1
    end
    
    cleanup_count
  end
  
  def self.assignment_statistics(start_date: 1.month.ago, end_date: Time.current)
    assignments = where(assigned_at: start_date..end_date)
    
    {
      total_assignments: assignments.count,
      active_assignments: assignments.active.count,
      assignment_by_role: assignments.group(:role).count,
      assignment_by_stage: assignments.group(:stage).count,
      assignment_by_type: assignments.group(:assignment_type).count,
      average_assignment_duration: calculate_average_assignment_duration(assignments),
      most_assigned_users: find_most_assigned_users(assignments, 10),
      role_distribution: calculate_role_distribution(assignments)
    }
  end
  
  private
  
  def set_defaults
    self.assigned_at ||= Time.current
    self.status ||= 0  # active
    self.assignment_type ||= 0  # manual
  end
  
  def log_assignment_created
    content_workflow.audit_entries.create!(
      action: 'assign_user',
      from_stage: content_workflow.current_stage,
      to_stage: content_workflow.current_stage,
      performed_by_id: assigned_by_id,
      comment: "User #{user_id} assigned as #{role} for #{stage} stage",
      metadata: {
        assignment_id: id,
        user_id: user_id,
        role: role,
        stage: stage,
        assignment_type: assignment_type
      }
    )
  end
  
  def log_assignment_updated
    return unless status_previously_changed?
    
    content_workflow.audit_entries.create!(
      action: status == 'active' ? 'assign_user' : 'unassign_user',
      from_stage: content_workflow.current_stage,
      to_stage: content_workflow.current_stage,
      performed_by_id: status == 'active' ? activated_by_id : unassigned_by_id,
      comment: "Assignment status changed to #{status}",
      metadata: {
        assignment_id: id,
        previous_status: status_previously_was,
        new_status: status
      }
    )
  end
  
  def log_assignment_action(action, comment)
    content_workflow.audit_entries.create!(
      action: action,
      from_stage: content_workflow.current_stage,
      to_stage: content_workflow.current_stage,
      performed_by_id: nil, # System action
      comment: comment,
      metadata: {
        assignment_id: id,
        assignment_action: action
      }
    )
  end
  
  def calculate_average_response_time
    # Calculate average time between workflow state changes and user actions
    # This is a simplified calculation
    user_actions = content_workflow.audit_entries.where(performed_by_id: user_id)
    return 0 if user_actions.empty?
    
    response_times = []
    
    user_actions.each do |action|
      previous_entry = content_workflow.audit_entries
                                      .where('created_at < ?', action.created_at)
                                      .where.not(performed_by_id: user_id)
                                      .order(:created_at)
                                      .last
      
      if previous_entry
        response_times << (action.created_at - previous_entry.created_at)
      end
    end
    
    return 0 if response_times.empty?
    
    (response_times.sum / response_times.count).round(2)
  end
  
  def calculate_efficiency_score
    # Simple efficiency score based on actions performed vs time assigned
    actions_count = content_workflow.audit_entries.where(performed_by_id: user_id).count
    assignment_duration_hours = time_since_assignment / 1.hour
    
    return 0 if assignment_duration_hours <= 0
    
    score = (actions_count / assignment_duration_hours * 10).round(2)
    [score, 100].min # Cap at 100
  end
  
  def calculate_collaboration_score
    # Score based on interactions with other users in the workflow
    all_audit_entries = content_workflow.audit_entries
    user_entries = all_audit_entries.where(performed_by_id: user_id)
    other_user_entries = all_audit_entries.where.not(performed_by_id: [nil, user_id])
    
    return 0 if user_entries.empty? || other_user_entries.empty?
    
    # Simple collaboration score: percentage of actions that follow others' actions
    collaboration_actions = 0
    
    user_entries.each do |entry|
      previous_entry = all_audit_entries
                        .where('created_at < ?', entry.created_at)
                        .order(:created_at)
                        .last
      
      if previous_entry && previous_entry.performed_by_id != user_id
        collaboration_actions += 1
      end
    end
    
    ((collaboration_actions.to_f / user_entries.count) * 100).round(2)
  end
  
  def self.load_assignment_rules(template_name)
    # In a real implementation, this would load from a configuration store
    # For now, return default rules
    {
      'draft' => {
        'auto_assign' => {
          'creator' => { 'department' => 'content', 'role' => 'writer' }
        }
      },
      'review' => {
        'auto_assign' => {
          'reviewer' => { 'department' => 'content', 'role' => 'editor' }
        }
      },
      'approved' => {
        'auto_assign' => {
          'approver' => { 'department' => 'marketing', 'role' => 'manager' }
        }
      }
    }
  end
  
  def self.find_users_by_criteria(criteria)
    # In a real implementation, this would query the User model
    # For now, return mock user IDs
    case criteria['role']
    when 'writer'
      [1, 2, 3]
    when 'editor'
      [4, 5]
    when 'manager'
      [6]
    else
      []
    end
  end
  
  def self.calculate_average_assignment_duration(assignments)
    completed_assignments = assignments.where.not(unassigned_at: nil)
    return 0 if completed_assignments.empty?
    
    total_duration = completed_assignments.sum do |assignment|
      (assignment.unassigned_at - assignment.assigned_at).to_f
    end
    
    (total_duration / completed_assignments.count / 1.day).round(2) # Return in days
  end
  
  def self.find_most_assigned_users(assignments, limit = 10)
    assignments.group(:user_id)
               .count
               .sort_by { |_user_id, count| -count }
               .first(limit)
               .to_h
  end
  
  def self.calculate_role_distribution(assignments)
    total = assignments.count.to_f
    return {} if total == 0
    
    role_counts = assignments.group(:role).count
    
    role_counts.transform_values do |count|
      ((count / total) * 100).round(2)
    end
  end
end