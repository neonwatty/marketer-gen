# WorkflowEngine - Flexible approval workflow engine with role-based permissions
# Manages content approval processes with customizable stages and transitions
class WorkflowEngine
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  # Standard workflow stages
  WORKFLOW_STAGES = {
    draft: {
      name: 'Draft',
      description: 'Content is being created or edited',
      order: 1,
      allowed_actions: %w[edit submit_for_review delete],
      required_roles: %w[creator]
    },
    review: {
      name: 'Review',
      description: 'Content is under review for quality and compliance',
      order: 2,
      allowed_actions: %w[approve reject request_changes return_to_draft],
      required_roles: %w[reviewer]
    },
    approved: {
      name: 'Approved',
      description: 'Content has been approved and is ready for publishing',
      order: 3,
      allowed_actions: %w[publish schedule reject return_to_review],
      required_roles: %w[approver publisher]
    },
    scheduled: {
      name: 'Scheduled',
      description: 'Content is scheduled for future publication',
      order: 4,
      allowed_actions: %w[publish cancel_schedule reschedule],
      required_roles: %w[publisher]
    },
    published: {
      name: 'Published',
      description: 'Content has been published and is live',
      order: 5,
      allowed_actions: %w[archive update_metadata],
      required_roles: %w[publisher]
    },
    archived: {
      name: 'Archived',
      description: 'Content has been archived and is no longer active',
      order: 6,
      allowed_actions: %w[restore],
      required_roles: %w[publisher]
    }
  }.freeze
  
  # Role hierarchy and permissions
  WORKFLOW_ROLES = {
    creator: {
      name: 'Creator',
      description: 'Can create and edit content in draft stage',
      permissions: %w[create edit delete submit_for_review],
      hierarchy_level: 1
    },
    reviewer: {
      name: 'Reviewer',
      description: 'Can review content and request changes',
      permissions: %w[view review approve reject request_changes return_to_draft],
      hierarchy_level: 2
    },
    approver: {
      name: 'Approver',
      description: 'Can approve content for publication',
      permissions: %w[view review approve reject schedule return_to_review],
      hierarchy_level: 3
    },
    publisher: {
      name: 'Publisher',
      description: 'Can publish and manage live content',
      permissions: %w[view publish schedule archive restore update_metadata],
      hierarchy_level: 4
    },
    admin: {
      name: 'Admin',
      description: 'Full access to all workflow operations',
      permissions: %w[all],
      hierarchy_level: 5
    }
  }.freeze
  
  # Workflow transition rules
  WORKFLOW_TRANSITIONS = {
    draft: {
      submit_for_review: :review,
      delete: :archived
    },
    review: {
      approve: :approved,
      reject: :draft,
      request_changes: :draft,
      return_to_draft: :draft
    },
    approved: {
      publish: :published,
      schedule: :scheduled,
      reject: :draft,
      return_to_review: :review
    },
    scheduled: {
      publish: :published,
      cancel_schedule: :approved,
      reschedule: :scheduled
    },
    published: {
      archive: :archived
    },
    archived: {
      restore: :draft
    }
  }.freeze
  
  attr_accessor :content_item, :current_user, :workflow_template
  
  def initialize(content_item, current_user = nil, workflow_template = nil)
    @content_item = content_item
    @current_user = current_user
    @workflow_template = workflow_template || default_workflow_template
    @notification_service = WorkflowNotificationService.new
  end
  
  # Core workflow operations
  def start_workflow(initial_stage: :draft, metadata: {})
    workflow = ContentWorkflow.create!(
      content_item: @content_item,
      current_stage: initial_stage.to_s,
      template_name: @workflow_template[:name],
      template_version: @workflow_template[:version],
      metadata: metadata.merge({
        workflow_started_at: Time.current,
        started_by: @current_user&.id
      })
    )
    
    # Create initial audit entry
    log_workflow_action(workflow, :start_workflow, initial_stage, nil, 'Workflow started')
    
    # Send notification
    @notification_service.workflow_started(workflow, @current_user)
    
    workflow
  end
  
  def transition_to(workflow, target_stage, action, options = {})
    current_stage = workflow.current_stage.to_sym
    target_stage = target_stage.to_sym
    
    # Validate transition
    validation_result = validate_transition(current_stage, target_stage, action)
    unless validation_result[:valid]
      raise WorkflowTransitionError, validation_result[:errors].join(', ')
    end
    
    # Check permissions
    unless can_perform_action?(action, current_stage)
      raise WorkflowPermissionError, "User does not have permission to perform action: #{action}"
    end
    
    # Perform transition
    workflow.transaction do
      previous_stage = workflow.current_stage
      
      # Update workflow state
      workflow.update!(
        current_stage: target_stage.to_s,
        previous_stage: previous_stage,
        updated_by_id: @current_user&.id,
        metadata: workflow.metadata.merge({
          last_transition_at: Time.current,
          last_action: action.to_s
        }.merge(options[:metadata] || {}))
      )
      
      # Log the transition
      log_workflow_action(workflow, action, target_stage, previous_stage, options[:comment])
      
      # Handle stage-specific logic
      handle_stage_transition(workflow, previous_stage.to_sym, target_stage, action, options)
      
      # Send notifications
      @notification_service.stage_transitioned(workflow, previous_stage.to_sym, target_stage, @current_user)
      
      workflow
    end
  rescue => e
    Rails.logger.error "Workflow transition failed: #{e.message}"
    raise e
  end
  
  def submit_for_review(workflow, comment: nil)
    transition_to(workflow, :review, :submit_for_review, comment: comment)
  end
  
  def approve_content(workflow, comment: nil)
    transition_to(workflow, :approved, :approve, comment: comment)
  end
  
  def reject_content(workflow, reason:, comment: nil)
    transition_to(workflow, :draft, :reject, 
      comment: comment,
      metadata: { rejection_reason: reason }
    )
  end
  
  def publish_content(workflow, publish_options: {})
    if workflow.current_stage == 'scheduled'
      transition_to(workflow, :published, :publish, metadata: { published_at: Time.current })
    else
      transition_to(workflow, :published, :publish, 
        metadata: { 
          published_at: Time.current,
          publish_options: publish_options 
        }
      )
    end
  end
  
  def schedule_content(workflow, scheduled_at:, publish_options: {})
    transition_to(workflow, :scheduled, :schedule,
      metadata: {
        scheduled_at: scheduled_at,
        publish_options: publish_options
      }
    )
  end
  
  # Permission checking
  def can_perform_action?(action, stage = nil)
    return false unless @current_user
    
    stage ||= @content_item.workflow&.current_stage&.to_sym || :draft
    user_roles = get_user_roles(@current_user)
    
    # Admin can do everything
    return true if user_roles.include?(:admin)
    
    # Check if any user role can perform the action in the current stage
    stage_config = WORKFLOW_STAGES[stage]
    return false unless stage_config
    
    required_roles = stage_config[:required_roles]
    allowed_actions = stage_config[:allowed_actions]
    
    # Check if action is allowed in this stage
    return false unless allowed_actions.include?(action.to_s)
    
    # Check if user has required role
    user_roles.any? { |role| required_roles.include?(role.to_s) }
  end
  
  def get_available_actions(workflow = nil)
    workflow ||= @content_item.workflow
    return [] unless workflow
    
    current_stage = workflow.current_stage.to_sym
    stage_config = WORKFLOW_STAGES[current_stage]
    return [] unless stage_config
    
    # Filter actions based on user permissions
    stage_config[:allowed_actions].select do |action|
      can_perform_action?(action.to_sym, current_stage)
    end
  end
  
  def get_possible_transitions(workflow = nil)
    workflow ||= @content_item.workflow
    return [] unless workflow
    
    current_stage = workflow.current_stage.to_sym
    available_actions = get_available_actions(workflow)
    transitions = WORKFLOW_TRANSITIONS[current_stage] || {}
    
    available_actions.map do |action|
      target_stage = transitions[action.to_sym]
      next unless target_stage
      
      {
        action: action,
        from_stage: current_stage,
        to_stage: target_stage,
        description: "#{action.humanize} (#{current_stage} → #{target_stage})"
      }
    end.compact
  end
  
  # Workflow analysis and reporting
  def workflow_status(workflow = nil)
    workflow ||= @content_item.workflow
    return { status: 'no_workflow' } unless workflow
    
    current_stage_config = WORKFLOW_STAGES[workflow.current_stage.to_sym]
    available_actions = get_available_actions(workflow)
    possible_transitions = get_possible_transitions(workflow)
    
    {
      status: 'active',
      current_stage: workflow.current_stage,
      stage_description: current_stage_config[:description],
      stage_order: current_stage_config[:order],
      available_actions: available_actions,
      possible_transitions: possible_transitions,
      workflow_age: Time.current - workflow.created_at,
      last_activity: workflow.updated_at,
      total_transitions: workflow.audit_entries.count,
      assigned_users: get_workflow_participants(workflow)
    }
  end
  
  def workflow_history(workflow = nil)
    workflow ||= @content_item.workflow
    return [] unless workflow
    
    workflow.audit_entries.includes(:performed_by).order(:created_at).map do |entry|
      {
        timestamp: entry.created_at,
        action: entry.action,
        from_stage: entry.from_stage,
        to_stage: entry.to_stage,
        performer: entry.performed_by&.name || 'System',
        comment: entry.comment,
        metadata: entry.metadata
      }
    end
  end
  
  def workflow_metrics(start_date: 1.month.ago, end_date: Time.current)
    workflows = ContentWorkflow.where(created_at: start_date..end_date)
    
    {
      total_workflows: workflows.count,
      completed_workflows: workflows.where(current_stage: ['published', 'archived']).count,
      average_completion_time: calculate_average_completion_time(workflows),
      stage_distribution: workflows.group(:current_stage).count,
      bottlenecks: identify_workflow_bottlenecks(workflows),
      user_activity: calculate_user_activity(workflows, start_date, end_date)
    }
  end
  
  private
  
  def default_workflow_template
    {
      name: 'standard_content_approval',
      version: '1.0',
      stages: WORKFLOW_STAGES.keys,
      roles: WORKFLOW_ROLES.keys,
      transitions: WORKFLOW_TRANSITIONS
    }
  end
  
  def validate_transition(from_stage, to_stage, action)
    errors = []
    
    # Check if transition is defined
    allowed_transitions = WORKFLOW_TRANSITIONS[from_stage]
    unless allowed_transitions&.key?(action.to_sym)
      errors << "Action '#{action}' is not allowed from stage '#{from_stage}'"
    end
    
    # Check if target stage matches expected transition
    expected_stage = allowed_transitions&.[](action.to_sym)
    if expected_stage && expected_stage != to_stage
      errors << "Action '#{action}' should transition to '#{expected_stage}', not '#{to_stage}'"
    end
    
    {
      valid: errors.empty?,
      errors: errors
    }
  end
  
  def get_user_roles(user)
    # This would typically integrate with your user role system
    # For now, returning default roles based on user attributes
    return [:admin] if user.respond_to?(:admin?) && user.admin?
    return [:publisher] if user.respond_to?(:publisher?) && user.publisher?
    return [:approver] if user.respond_to?(:approver?) && user.approver?
    return [:reviewer] if user.respond_to?(:reviewer?) && user.reviewer?
    
    [:creator] # Default role
  end
  
  def log_workflow_action(workflow, action, to_stage, from_stage, comment)
    WorkflowAuditEntry.create!(
      content_workflow: workflow,
      action: action.to_s,
      from_stage: from_stage&.to_s,
      to_stage: to_stage&.to_s,
      performed_by_id: @current_user,
      comment: comment,
      metadata: {
        timestamp: Time.current,
        user_agent: 'WorkflowEngine',
        ip_address: nil # Could be passed in from controller
      }
    )
  end
  
  def handle_stage_transition(workflow, from_stage, to_stage, action, options)
    case to_stage
    when :scheduled
      # Set up scheduled publishing
      scheduled_at = options.dig(:metadata, :scheduled_at)
      if scheduled_at
        ScheduledPublishJob.set(wait_until: scheduled_at).perform_later(workflow.id)
      end
    when :published
      # Handle publishing logic
      handle_content_publishing(workflow, options)
    when :archived
      # Handle archiving logic
      handle_content_archiving(workflow, options)
    end
  end
  
  def handle_content_publishing(workflow, options)
    # Integration point for actual content publishing
    # This would integrate with your publishing system
    Rails.logger.info "Publishing content for workflow #{workflow.id}"
    
    # Update content item status
    if workflow.content_item.respond_to?(:publish!)
      workflow.content_item.publish!(options[:metadata] || {})
    end
  end
  
  def handle_content_archiving(workflow, options)
    # Integration point for content archiving
    Rails.logger.info "Archiving content for workflow #{workflow.id}"
    
    # Update content item status
    if workflow.content_item.respond_to?(:archive!)
      workflow.content_item.archive!(options[:metadata] || {})
    end
  end
  
  def get_workflow_participants(workflow)
    # Get all users who have interacted with this workflow
    participant_ids = workflow.audit_entries.distinct.pluck(:performed_by_id).compact
    
    # This would integrate with your User model
    # User.where(id: participant_ids).pluck(:name, :email)
    participant_ids.map { |id| "User #{id}" }
  end
  
  def calculate_average_completion_time(workflows)
    completed = workflows.where(current_stage: ['published', 'archived'])
    return 0 if completed.empty?
    
    total_time = completed.sum do |workflow|
      last_entry = workflow.audit_entries.where(to_stage: workflow.current_stage).last
      next 0 unless last_entry
      
      (last_entry.created_at - workflow.created_at).to_f
    end
    
    (total_time / completed.count / 1.day).round(2) # Return in days
  end
  
  def identify_workflow_bottlenecks(workflows)
    stage_times = {}
    
    workflows.each do |workflow|
      entries = workflow.audit_entries.order(:created_at)
      
      entries.each_cons(2) do |from_entry, to_entry|
        stage = from_entry.to_stage
        time_in_stage = to_entry.created_at - from_entry.created_at
        
        stage_times[stage] ||= []
        stage_times[stage] << time_in_stage
      end
    end
    
    # Calculate average time per stage
    stage_times.transform_values do |times|
      (times.sum / times.count / 1.hour).round(2) # Return in hours
    end.sort_by { |_stage, avg_time| -avg_time }.to_h
  end
  
  def calculate_user_activity(workflows, start_date, end_date)
    audit_entries = WorkflowAuditEntry.joins(:content_workflow)
                                      .where(content_workflows: { id: workflows.ids })
                                      .where(created_at: start_date..end_date)
    
    audit_entries.group(:performed_by_id).count
  end
end

# Custom exception classes
class WorkflowTransitionError < StandardError; end
class WorkflowPermissionError < StandardError; end
class WorkflowConfigurationError < StandardError; end