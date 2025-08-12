# WorkflowAuditEntry model - Tracks all workflow actions and transitions
# Provides comprehensive audit trail for compliance and analysis
class WorkflowAuditEntry < ApplicationRecord
  belongs_to :content_workflow
  # User tracking - can be extended when User model is added
  # belongs_to :performed_by, class_name: 'User', optional: true
  
  validates :action, presence: true, length: { minimum: 1, maximum: 100 }
  validates :content_workflow, presence: true
  
  # Action types for workflow operations
  WORKFLOW_ACTIONS = %w[
    create_workflow
    start_workflow
    submit_for_review
    approve
    reject
    request_changes
    return_to_draft
    return_to_review
    publish
    schedule
    cancel_schedule
    reschedule
    archive
    restore
    pause_workflow
    resume_workflow
    cancel_workflow
    assign_user
    unassign_user
    update_metadata
    bulk_action
  ].freeze
  
  validates :action, inclusion: { 
    in: WORKFLOW_ACTIONS,
    message: 'must be a valid workflow action'
  }
  
  serialize :metadata, coder: JSON
  
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user_id) { where(performed_by_id: user_id) }
  scope :stage_transitions, -> { where.not(from_stage: nil, to_stage: nil) }
  scope :system_actions, -> { where(performed_by_id: nil) }
  scope :user_actions, -> { where.not(performed_by_id: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :chronological, -> { order(:created_at) }
  scope :between_dates, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :for_stage, ->(stage) { where('from_stage = ? OR to_stage = ?', stage, stage) }
  
  before_validation :set_defaults, on: :create
  after_create :update_workflow_timestamp
  
  def initialize(attributes = {})
    super(attributes)
    self.metadata ||= {}
  end
  
  # Audit entry analysis
  def is_stage_transition?
    from_stage.present? && to_stage.present? && from_stage != to_stage
  end
  
  def is_system_action?
    performed_by_id.nil?
  end
  
  def is_user_action?
    performed_by_id.present?
  end
  
  def transition_direction
    return nil unless is_stage_transition?
    
    from_order = stage_order(from_stage)
    to_order = stage_order(to_stage)
    
    return nil unless from_order && to_order
    
    if to_order > from_order
      'forward'
    elsif to_order < from_order
      'backward'
    else
      'lateral'
    end
  end
  
  def duration_since_previous
    previous_entry = content_workflow.audit_entries
                                   .where('created_at < ?', created_at)
                                   .order(:created_at)
                                   .last
    
    return nil unless previous_entry
    
    created_at - previous_entry.created_at
  end
  
  def time_in_previous_stage
    return nil unless is_stage_transition?
    
    previous_stage_entry = content_workflow.audit_entries
                                          .where(to_stage: from_stage)
                                          .where('created_at < ?', created_at)
                                          .order(:created_at)
                                          .last
    
    return nil unless previous_stage_entry
    
    created_at - previous_stage_entry.created_at
  end
  
  def performer_name
    return 'System' if is_system_action?
    return "User #{performed_by_id}" unless performed_by_id
    
    # This would integrate with your User model
    # performed_by&.name || "User #{performed_by_id}"
    "User #{performed_by_id}"
  end
  
  def action_description
    case action
    when 'create_workflow'
      'Workflow created'
    when 'start_workflow'
      'Workflow started'
    when 'submit_for_review'
      'Submitted for review'
    when 'approve'
      'Content approved'
    when 'reject'
      'Content rejected'
    when 'request_changes'
      'Changes requested'
    when 'return_to_draft'
      'Returned to draft'
    when 'return_to_review'
      'Returned to review'
    when 'publish'
      'Content published'
    when 'schedule'
      'Publication scheduled'
    when 'cancel_schedule'
      'Schedule cancelled'
    when 'reschedule'
      'Publication rescheduled'
    when 'archive'
      'Content archived'
    when 'restore'
      'Content restored'
    when 'pause_workflow'
      'Workflow paused'
    when 'resume_workflow'
      'Workflow resumed'
    when 'cancel_workflow'
      'Workflow cancelled'
    when 'assign_user'
      'User assigned'
    when 'unassign_user'
      'User unassigned'
    when 'update_metadata'
      'Metadata updated'
    when 'bulk_action'
      'Bulk action performed'
    else
      action.humanize
    end
  end
  
  def transition_summary
    return action_description unless is_stage_transition?
    
    "#{action_description}: #{from_stage.humanize} → #{to_stage.humanize}"
  end
  
  def has_comment?
    comment.present?
  end
  
  def has_metadata?
    metadata.present? && metadata.any?
  end
  
  def risk_level
    case action
    when 'publish', 'archive', 'cancel_workflow'
      'high'
    when 'approve', 'reject', 'schedule'
      'medium'
    when 'submit_for_review', 'request_changes', 'assign_user'
      'low'
    else
      'minimal'
    end
  end
  
  def compliance_flags
    flags = []
    
    # Flag actions without comments in high-risk scenarios
    if risk_level == 'high' && !has_comment?
      flags << 'missing_comment_for_high_risk_action'
    end
    
    # Flag rapid transitions (possible automation issues)
    if duration_since_previous && duration_since_previous < 30.seconds
      flags << 'rapid_transition'
    end
    
    # Flag system actions on sensitive operations
    if is_system_action? && %w[approve publish].include?(action)
      flags << 'automated_sensitive_action'
    end
    
    # Flag unusual stage transitions
    if is_stage_transition? && transition_direction == 'backward'
      flags << 'backward_stage_transition'
    end
    
    flags
  end
  
  # Export and formatting
  def to_audit_summary
    {
      id: id,
      timestamp: created_at,
      action: action,
      description: action_description,
      transition: is_stage_transition? ? "#{from_stage} → #{to_stage}" : nil,
      performer: performer_name,
      comment: comment,
      risk_level: risk_level,
      duration_since_previous: duration_since_previous&.round(2),
      time_in_previous_stage: time_in_previous_stage&.round(2),
      compliance_flags: compliance_flags,
      metadata: metadata
    }
  end
  
  def to_timeline_entry
    {
      timestamp: created_at,
      title: transition_summary,
      description: comment,
      performer: performer_name,
      type: is_stage_transition? ? 'transition' : 'action',
      risk_level: risk_level,
      metadata: {
        action: action,
        from_stage: from_stage,
        to_stage: to_stage,
        duration_in_stage: time_in_previous_stage&.round(2)
      }
    }
  end
  
  # Class methods for reporting and analysis
  def self.action_frequency(start_date: 1.month.ago, end_date: Time.current)
    between_dates(start_date, end_date)
      .group(:action)
      .count
      .sort_by { |_action, count| -count }
      .to_h
  end
  
  def self.user_activity(start_date: 1.month.ago, end_date: Time.current)
    user_actions
      .between_dates(start_date, end_date)
      .group(:performed_by_id)
      .count
      .sort_by { |_user_id, count| -count }
      .to_h
  end
  
  def self.stage_transition_patterns(start_date: 1.month.ago, end_date: Time.current)
    stage_transitions
      .between_dates(start_date, end_date)
      .group(:from_stage, :to_stage)
      .count
      .sort_by { |_transition, count| -count }
      .to_h
  end
  
  def self.average_stage_durations(start_date: 1.month.ago, end_date: Time.current)
    transitions = stage_transitions
                   .between_dates(start_date, end_date)
                   .includes(:content_workflow)
    
    stage_times = {}
    
    transitions.each do |entry|
      stage = entry.from_stage
      duration = entry.time_in_previous_stage
      
      next unless stage && duration
      
      stage_times[stage] ||= []
      stage_times[stage] << duration
    end
    
    stage_times.transform_values do |durations|
      (durations.sum / durations.count).round(2)
    end
  end
  
  def self.compliance_report(start_date: 1.month.ago, end_date: Time.current)
    entries = between_dates(start_date, end_date)
    total_entries = entries.count
    
    return { error: 'No entries found' } if total_entries == 0
    
    flagged_entries = entries.select { |entry| entry.compliance_flags.any? }
    
    {
      total_entries: total_entries,
      flagged_entries: flagged_entries.count,
      compliance_rate: ((total_entries - flagged_entries.count).to_f / total_entries * 100).round(2),
      flag_breakdown: calculate_flag_breakdown(flagged_entries),
      high_risk_actions: entries.select { |entry| entry.risk_level == 'high' }.count,
      system_vs_user_actions: {
        system: entries.system_actions.count,
        user: entries.user_actions.count
      }
    }
  end
  
  def self.workflow_performance_metrics(start_date: 1.month.ago, end_date: Time.current)
    workflows = ContentWorkflow.joins(:audit_entries)
                              .where(workflow_audit_entries: { created_at: start_date..end_date })
                              .distinct
    
    {
      total_workflows: workflows.count,
      completed_workflows: workflows.where(status: :completed).count,
      average_transitions_per_workflow: calculate_average_transitions(workflows),
      most_common_bottlenecks: identify_common_bottlenecks(workflows),
      fastest_completions: find_fastest_workflows(workflows, 5),
      slowest_completions: find_slowest_workflows(workflows, 5)
    }
  end
  
  private
  
  def stage_order(stage_name)
    WorkflowEngine::WORKFLOW_STAGES.dig(stage_name.to_sym, :order)
  end
  
  def set_defaults
    self.metadata ||= {}
    
    # Add default metadata
    self.metadata = metadata.merge({
      ip_address: metadata['ip_address'],
      user_agent: metadata['user_agent'] || 'WorkflowEngine',
      session_id: metadata['session_id'],
      request_id: metadata['request_id']
    }.compact)
  end
  
  def update_workflow_timestamp
    content_workflow.touch(:updated_at)
  end
  
  def self.calculate_flag_breakdown(flagged_entries)
    all_flags = flagged_entries.flat_map(&:compliance_flags)
    all_flags.group_by(&:itself).transform_values(&:count)
  end
  
  def self.calculate_average_transitions(workflows)
    return 0 if workflows.empty?
    
    total_transitions = workflows.joins(:audit_entries).count
    (total_transitions.to_f / workflows.count).round(2)
  end
  
  def self.identify_common_bottlenecks(workflows)
    stage_durations = {}
    
    workflows.each do |workflow|
      workflow.audit_entries.stage_transitions.each do |entry|
        stage = entry.from_stage
        duration = entry.time_in_previous_stage
        
        next unless stage && duration
        
        stage_durations[stage] ||= []
        stage_durations[stage] << duration
      end
    end
    
    # Calculate average duration per stage and identify bottlenecks
    averages = stage_durations.transform_values do |durations|
      durations.sum / durations.count
    end
    
    averages.sort_by { |_stage, avg_duration| -avg_duration }.first(3).to_h
  end
  
  def self.find_fastest_workflows(workflows, limit = 5)
    completed_workflows = workflows.where(status: :completed)
    
    fastest = completed_workflows.map do |workflow|
      total_time = workflow.total_workflow_time
      next unless total_time
      
      {
        workflow_id: workflow.id,
        content_type: workflow.content_item_type,
        total_time: total_time,
        transition_count: workflow.audit_entries.count
      }
    end.compact
    
    fastest.sort_by { |w| w[:total_time] }.first(limit)
  end
  
  def self.find_slowest_workflows(workflows, limit = 5)
    completed_workflows = workflows.where(status: :completed)
    
    slowest = completed_workflows.map do |workflow|
      total_time = workflow.total_workflow_time
      next unless total_time
      
      {
        workflow_id: workflow.id,
        content_type: workflow.content_item_type,
        total_time: total_time,
        transition_count: workflow.audit_entries.count
      }
    end.compact
    
    slowest.sort_by { |w| -w[:total_time] }.first(limit)
  end
end