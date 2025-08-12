# ContentWorkflow model - Tracks workflow instances for content approval processes
# Manages workflow state, transitions, and metadata for content items
class ContentWorkflow < ApplicationRecord
  belongs_to :content_item, polymorphic: true
  # Author/user tracking - can be extended when User model is added
  # belongs_to :created_by, class_name: 'User', optional: true
  # belongs_to :updated_by, class_name: 'User', optional: true
  
  has_many :audit_entries, class_name: 'WorkflowAuditEntry', dependent: :destroy
  has_many :assignments, class_name: 'WorkflowAssignment', dependent: :destroy
  has_many :notifications, class_name: 'WorkflowNotification', dependent: :destroy
  
  validates :current_stage, presence: true, inclusion: { 
    in: %w[draft review approved scheduled published archived],
    message: 'must be a valid workflow stage'
  }
  validates :template_name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :template_version, presence: true, format: { 
    with: /\A\d+\.\d+(\.\d+)?\z/, 
    message: 'must be in semantic version format (e.g., 1.0.0)'
  }
  
  # Workflow states
  enum :status, {
    active: 0,
    completed: 1,
    cancelled: 2,
    paused: 3,
    failed: 4
  }
  
  # Priority levels
  enum :priority, {
    low: 0,
    normal: 1,
    high: 2,
    urgent: 3,
    critical: 4
  }
  
  serialize :metadata, coder: JSON
  serialize :settings, coder: JSON
  
  scope :in_stage, ->(stage) { where(current_stage: stage) }
  scope :by_template, ->(template_name) { where(template_name: template_name) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :stale, ->(days = 7) { where('updated_at < ?', days.days.ago) }
  scope :by_priority, ->(priority_level) { where(priority: priority_level) }
  
  before_validation :set_defaults, on: :create
  after_create :create_initial_audit_entry
  
  def initialize(attributes = {})
    super(attributes)
    self.metadata ||= {}
    self.settings ||= {}
  end
  
  # Workflow state management
  def engine(current_user = nil)
    @engine ||= WorkflowEngine.new(content_item, current_user, workflow_template)
  end
  
  def can_transition_to?(target_stage, action = nil)
    begin
      engine(nil).validate_transition(current_stage.to_sym, target_stage.to_sym, action)[:valid]
    rescue => e
      Rails.logger.warn "Transition validation failed: #{e.message}"
      false
    end
  end
  
  def available_actions(user = nil)
    temp_engine = WorkflowEngine.new(content_item, user, workflow_template)
    temp_engine.get_available_actions(self)
  end
  
  def possible_transitions(user = nil)
    temp_engine = WorkflowEngine.new(content_item, user, workflow_template)
    temp_engine.get_possible_transitions(self)
  end
  
  def current_stage_config
    WorkflowEngine::WORKFLOW_STAGES[current_stage.to_sym]
  end
  
  def next_required_roles
    stage_config = current_stage_config
    stage_config ? stage_config[:required_roles] : []
  end
  
  def is_in_final_stage?
    %w[published archived].include?(current_stage)
  end
  
  def is_awaiting_action?
    !is_in_final_stage? && %w[review approved scheduled].include?(current_stage)
  end
  
  def time_in_current_stage
    last_transition = audit_entries.where(to_stage: current_stage).last
    return Time.current - created_at unless last_transition
    
    Time.current - last_transition.created_at
  end
  
  def total_workflow_time
    return nil unless is_in_final_stage?
    
    final_entry = audit_entries.where(to_stage: current_stage).last
    return Time.current - created_at unless final_entry
    
    final_entry.created_at - created_at
  end
  
  # Assignment management
  def assign_to_user(user_id, role:, stage: nil)
    stage ||= current_stage
    
    assignment = assignments.find_or_create_by(
      user_id: user_id,
      stage: stage,
      role: role
    ) do |a|
      a.assigned_at = Time.current
      a.status = 0  # active
    end
    
    # Send notification
    WorkflowNotificationService.new.user_assigned(self, assignment)
    assignment
  end
  
  def unassign_user(user_id, stage: nil, role: nil)
    scope = assignments.where(user_id: user_id)
    scope = scope.where(stage: stage) if stage
    scope = scope.where(role: role) if role
    
    scope.update_all(
      status: 1,  # inactive
      unassigned_at: Time.current
    )
  end
  
  def assigned_users(stage: nil, role: nil)
    scope = assignments.assignment_status_active
    scope = scope.where(stage: stage) if stage
    scope = scope.where(role: role) if role
    
    scope.includes(:user).map(&:user_id)
  end
  
  def current_assignees
    assigned_users(stage: current_stage)
  end
  
  # Workflow history and analytics
  def transition_history
    audit_entries.order(:created_at).map do |entry|
      {
        timestamp: entry.created_at,
        action: entry.action,
        from_stage: entry.from_stage,
        to_stage: entry.to_stage,
        performer: entry.performed_by_id ? "User #{entry.performed_by_id}" : 'System',
        comment: entry.comment,
        duration_in_previous_stage: calculate_stage_duration(entry)
      }
    end
  end
  
  def stage_durations
    durations = {}
    entries = audit_entries.order(:created_at)
    
    entries.each_cons(2) do |from_entry, to_entry|
      stage = from_entry.to_stage
      duration = to_entry.created_at - from_entry.created_at
      
      durations[stage] ||= []
      durations[stage] << duration
    end
    
    # Add current stage duration if not in final stage
    unless is_in_final_stage?
      last_entry = entries.last
      if last_entry
        current_duration = Time.current - last_entry.created_at
        durations[current_stage] ||= []
        durations[current_stage] << current_duration
      end
    end
    
    # Calculate averages
    durations.transform_values do |times|
      (times.sum / times.count).round(2)
    end
  end
  
  def workflow_performance_metrics
    {
      total_duration: total_workflow_time,
      stage_durations: stage_durations,
      transition_count: audit_entries.count,
      average_stage_time: calculate_average_stage_time,
      bottleneck_stage: identify_bottleneck_stage,
      completion_rate: calculate_completion_rate,
      time_since_last_activity: Time.current - updated_at
    }
  end
  
  def is_overdue?(sla_hours = 48)
    time_in_current_stage > sla_hours.hours
  end
  
  def estimated_completion_time
    # Simple estimation based on historical data for similar workflows
    template_workflows = self.class.completed
                            .where(template_name: template_name)
                            .where('created_at > ?', 3.months.ago)
    
    return nil if template_workflows.empty?
    
    avg_completion_time = template_workflows.average(:total_workflow_time)
    current_progress = calculate_workflow_progress
    
    return nil unless avg_completion_time && current_progress > 0
    
    remaining_percentage = (100 - current_progress) / 100.0
    (avg_completion_time * remaining_percentage).round(2)
  end
  
  # Workflow validation and health checks
  def validate_workflow_integrity
    errors = []
    
    # Check if current stage is valid
    unless WorkflowEngine::WORKFLOW_STAGES.key?(current_stage.to_sym)
      errors << "Invalid current stage: #{current_stage}"
    end
    
    # Check if template exists and is valid
    unless workflow_template
      errors << "Workflow template '#{template_name}' not found"
    end
    
    # Check for orphaned assignments
    orphaned_assignments = assignments.active.joins('LEFT JOIN users ON users.id = workflow_assignments.user_id')
                                     .where(users: { id: nil })
    
    if orphaned_assignments.exists?
      errors << "Found #{orphaned_assignments.count} assignments to non-existent users"
    end
    
    # Check for stale workflow
    if is_overdue?(72) && !is_in_final_stage?
      errors << "Workflow has been inactive for more than 72 hours"
    end
    
    errors
  end
  
  def health_check
    validation_errors = validate_workflow_integrity
    
    {
      healthy: validation_errors.empty?,
      errors: validation_errors,
      warnings: generate_workflow_warnings,
      recommendations: generate_workflow_recommendations
    }
  end
  
  # Workflow operations
  def pause!(reason = nil, user = nil)
    transaction do
      update!(
        status: :paused,
        metadata: metadata.merge({
          paused_at: Time.current,
          pause_reason: reason,
          paused_by: user&.id
        })
      )
      
      log_system_action('pause_workflow', reason)
    end
  end
  
  def resume!(user = nil)
    transaction do
      update!(
        status: :active,
        metadata: metadata.merge({
          resumed_at: Time.current,
          resumed_by: user&.id
        })
      )
      
      log_system_action('resume_workflow', 'Workflow resumed')
    end
  end
  
  def cancel!(reason = nil, user = nil)
    transaction do
      update!(
        status: :cancelled,
        metadata: metadata.merge({
          cancelled_at: Time.current,
          cancellation_reason: reason,
          cancelled_by: user&.id
        })
      )
      
      # Inactivate all assignments
      assignments.assignment_status_active.update_all(
        status: 1,  # inactive
        unassigned_at: Time.current
      )
      
      log_system_action('cancel_workflow', reason)
    end
  end
  
  def clone_workflow(new_content_item = nil)
    new_content_item ||= content_item
    
    cloned_workflow = self.class.create!(
      content_item: new_content_item,
      current_stage: 'draft',
      template_name: template_name,
      template_version: template_version,
      priority: priority,
      settings: settings.deep_dup,
      metadata: {
        cloned_from: id,
        cloned_at: Time.current
      }
    )
    
    # Clone assignments for draft stage
    assignments.where(stage: 'draft').each do |assignment|
      cloned_workflow.assignments.create!(
        user_id: assignment.user_id,
        role: assignment.role,
        stage: 'draft',
        status: 0,  # active
        assigned_at: Time.current
      )
    end
    
    cloned_workflow
  end
  
  # Export and reporting
  def to_workflow_summary
    {
      id: id,
      content_item: {
        type: content_item_type,
        id: content_item_id
      },
      current_stage: current_stage,
      status: status,
      priority: priority,
      template: {
        name: template_name,
        version: template_version
      },
      timing: {
        created_at: created_at,
        updated_at: updated_at,
        time_in_current_stage: time_in_current_stage,
        total_workflow_time: total_workflow_time,
        is_overdue: is_overdue?
      },
      participants: {
        current_assignees: current_assignees.count,
        total_participants: audit_entries.distinct.count(:performed_by_id)
      },
      health: health_check
    }
  end
  
  def generate_workflow_report
    {
      workflow_summary: to_workflow_summary,
      transition_history: transition_history,
      performance_metrics: workflow_performance_metrics,
      stage_analysis: analyze_stage_performance,
      recommendations: generate_workflow_recommendations
    }
  end
  
  private
  
  def workflow_template
    # In a real implementation, this would load from a template store
    # For now, return the default template from WorkflowEngine
    @workflow_template ||= {
      name: template_name,
      version: template_version,
      stages: WorkflowEngine::WORKFLOW_STAGES.keys,
      roles: WorkflowEngine::WORKFLOW_ROLES.keys,
      transitions: WorkflowEngine::WORKFLOW_TRANSITIONS
    }
  end
  
  def set_defaults
    self.current_stage ||= 'draft'
    self.template_name ||= 'standard_content_approval'
    self.template_version ||= '1.0'
    self.status ||= :active
    self.priority ||= :normal
  end
  
  def create_initial_audit_entry
    audit_entries.create!(
      action: 'create_workflow',
      to_stage: current_stage,
      performed_by_id: created_by_id,
      comment: 'Workflow created',
      metadata: {
        template: template_name,
        version: template_version
      }
    )
  end
  
  def log_system_action(action, comment = nil)
    audit_entries.create!(
      action: action,
      from_stage: current_stage,
      to_stage: current_stage,
      performed_by_id: nil, # System action
      comment: comment,
      metadata: {
        system_action: true,
        timestamp: Time.current
      }
    )
  end
  
  def calculate_stage_duration(entry)
    previous_entry = audit_entries.where('created_at < ?', entry.created_at)
                                  .order(:created_at)
                                  .last
    
    return nil unless previous_entry
    
    (entry.created_at - previous_entry.created_at).round(2)
  end
  
  def calculate_average_stage_time
    durations = stage_durations
    return 0 if durations.empty?
    
    total_time = durations.values.sum
    (total_time / durations.count).round(2)
  end
  
  def identify_bottleneck_stage
    durations = stage_durations
    return nil if durations.empty?
    
    durations.max_by { |_stage, duration| duration }&.first
  end
  
  def calculate_completion_rate
    total_stages = WorkflowEngine::WORKFLOW_STAGES.count
    current_stage_order = current_stage_config[:order]
    
    ((current_stage_order.to_f / total_stages) * 100).round(1)
  end
  
  def calculate_workflow_progress
    stage_orders = WorkflowEngine::WORKFLOW_STAGES.transform_values { |config| config[:order] }
    current_order = stage_orders[current_stage.to_sym] || 0
    max_order = stage_orders.values.max || 1
    
    ((current_order.to_f / max_order) * 100).round(1)
  end
  
  def generate_workflow_warnings
    warnings = []
    
    # Check for overdue workflow
    if is_overdue?(24)
      warnings << "Workflow has been in #{current_stage} stage for more than 24 hours"
    end
    
    # Check for missing assignments
    if current_assignees.empty? && is_awaiting_action?
      warnings << "No users assigned to current stage: #{current_stage}"
    end
    
    # Check for excessive transitions
    if audit_entries.count > 20
      warnings << "Workflow has an unusually high number of transitions (#{audit_entries.count})"
    end
    
    warnings
  end
  
  def generate_workflow_recommendations
    recommendations = []
    
    # Suggest assignments
    if current_assignees.empty?
      required_roles = next_required_roles
      recommendations << "Assign users with roles: #{required_roles.join(', ')}"
    end
    
    # Suggest escalation for overdue workflows
    if is_overdue?(48)
      recommendations << "Consider escalating this workflow to higher priority"
    end
    
    # Performance recommendations
    bottleneck = identify_bottleneck_stage
    if bottleneck
      recommendations << "Consider optimizing the '#{bottleneck}' stage to reduce processing time"
    end
    
    recommendations
  end
  
  def analyze_stage_performance
    durations = stage_durations
    stage_configs = WorkflowEngine::WORKFLOW_STAGES
    
    durations.map do |stage, duration|
      config = stage_configs[stage.to_sym]
      
      {
        stage: stage,
        duration_seconds: duration,
        duration_human: distance_of_time_in_words(duration),
        description: config[:description],
        order: config[:order],
        performance_rating: calculate_stage_performance_rating(stage, duration)
      }
    end.sort_by { |analysis| analysis[:order] }
  end
  
  def calculate_stage_performance_rating(stage, duration)
    # Simple performance rating based on duration
    # This would be enhanced with historical data and benchmarks
    case duration
    when 0..3600 # < 1 hour
      'excellent'
    when 3600..86400 # 1-24 hours
      'good'
    when 86400..259200 # 1-3 days
      'fair'
    else # > 3 days
      'poor'
    end
  end
end