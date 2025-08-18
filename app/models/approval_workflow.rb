# frozen_string_literal: true

# Model for managing content approval workflows
class ApprovalWorkflow < ApplicationRecord
  belongs_to :generated_content
  belongs_to :created_by, class_name: 'User'
  
  # Workflow types
  WORKFLOW_TYPES = %w[
    single_approver
    multi_stage
    consensus
    parallel
    conditional
  ].freeze
  
  # Workflow statuses
  STATUSES = %w[
    pending
    in_review
    approved
    rejected
    cancelled
    escalated
    expired
  ].freeze
  
  validates :workflow_type, presence: true, inclusion: { in: WORKFLOW_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :required_approvers, presence: true
  validates :current_stage, presence: true, numericality: { greater_than: 0 }
  validates :generated_content_id, uniqueness: true
  
  validate :validate_required_approvers_format
  validate :validate_escalation_rules_format
  validate :validate_due_date_in_future
  
  scope :pending, -> { where(status: 'pending') }
  scope :in_review, -> { where(status: 'in_review') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :escalated, -> { where(status: 'escalated') }
  scope :active, -> { where(status: %w[pending in_review]) }
  scope :completed, -> { where(status: %w[approved rejected cancelled]) }
  scope :overdue, -> { where('due_date < ? AND status IN (?)', Time.current, %w[pending in_review]) }
  scope :by_workflow_type, ->(type) { where(workflow_type: type) }
  scope :by_approver, ->(user_id) { where("JSON_EXTRACT(required_approvers, '$[*]') LIKE ?", "%#{user_id}%") }
  scope :recent, -> { order(created_at: :desc) }
  
  # Create a new approval workflow
  def self.create_workflow!(content, workflow_type, approvers, options = {})
    workflow = create!(
      generated_content: content,
      workflow_type: workflow_type,
      required_approvers: format_approvers(approvers),
      created_by: options[:created_by] || content.created_by,
      due_date: options[:due_date],
      escalation_rules: options[:escalation_rules] || default_escalation_rules,
      metadata: options[:metadata] || {}
    )
    
    # Initialize the workflow
    workflow.start_workflow!
    workflow
  end
  
  # Start the approval workflow
  def start_workflow!
    return false unless pending?
    
    transaction do
      update!(status: 'in_review', metadata: (metadata || {}).merge(started_at: Time.current))
      notify_current_stage_approvers
      create_audit_entry('workflow_started', 'Approval workflow initiated')
    end
    
    true
  end
  
  # Process an approval decision from a user
  def process_approval!(user, decision, feedback = nil)
    return false unless can_approve?(user)
    return false unless active?
    
    transaction do
      record_approval_decision(user, decision, feedback)
      
      case decision
      when 'approve'
        handle_approval(user, feedback)
      when 'reject'
        handle_rejection(user, feedback)
      when 'request_changes'
        handle_change_request(user, feedback)
      end
    end
    
    true
  end
  
  # Check if a user can approve at the current stage
  def can_approve?(user)
    return false unless user.present?
    return false unless active?
    
    current_stage_approvers.include?(user.id.to_s) || 
    current_stage_approvers.include?(user.id)
  end
  
  # Get approvers for the current stage
  def current_stage_approvers
    case workflow_type
    when 'single_approver'
      required_approvers
    when 'multi_stage'
      stage_approvers = required_approvers.is_a?(Array) ? required_approvers[current_stage - 1] : required_approvers
      stage_approvers.is_a?(Array) ? stage_approvers : [stage_approvers]
    when 'consensus', 'parallel'
      required_approvers
    when 'conditional'
      get_conditional_approvers
    else
      required_approvers
    end
  end
  
  # Get all approvers across all stages
  def all_approvers
    case workflow_type
    when 'single_approver', 'consensus', 'parallel'
      required_approvers
    when 'multi_stage'
      required_approvers.flatten.compact.uniq
    when 'conditional'
      get_all_conditional_approvers
    else
      required_approvers
    end
  end
  
  # Check if workflow is pending
  def pending?
    status == 'pending'
  end
  
  # Check if workflow is active (pending or in review)
  def active?
    %w[pending in_review].include?(status)
  end

  # Check if workflow is overdue
  def overdue?
    due_date.present? && due_date < Time.current && active?
  end
  
  # Get time remaining until due date
  def time_remaining
    return nil unless due_date.present?
    return 0 if overdue?
    
    due_date - Time.current
  end
  
  # Get approval progress
  def approval_progress
    total_approvers = all_approvers.length
    completed_approvals = get_completed_approvals.length
    
    {
      total_approvers: total_approvers,
      completed_approvals: completed_approvals,
      percentage: total_approvers > 0 ? (completed_approvals.to_f / total_approvers * 100).round(1) : 0,
      current_stage: current_stage,
      total_stages: get_total_stages,
      remaining_approvers: get_remaining_approvers
    }
  end
  
  # Cancel the workflow
  def cancel!(user, reason = nil)
    return false unless active?
    
    transaction do
      update!(
        status: 'cancelled',
        completed_at: Time.current,
        metadata: (metadata || {}).merge(
          cancelled_by: user.id,
          cancellation_reason: reason,
          cancelled_at: Time.current
        )
      )
      
      create_audit_entry('workflow_cancelled', reason || 'Workflow cancelled')
      notify_stakeholders('workflow_cancelled')
    end
    
    true
  end
  
  # Escalate the workflow
  def escalate!(reason = nil)
    return false unless can_escalate?
    
    transaction do
      update!(
        status: 'escalated',
        metadata: (metadata || {}).merge(
          escalated_at: Time.current,
          escalation_reason: reason || 'Workflow escalated due to overdue'
        )
      )
      
      create_audit_entry('workflow_escalated', reason || 'Workflow escalated')
      notify_escalation_contacts
    end
    
    true
  end
  
  # Check if workflow can be escalated
  def can_escalate?
    active? && (overdue? || escalation_rules.present?)
  end
  
  # Get workflow summary
  def summary
    {
      id: id,
      content_title: generated_content.title,
      workflow_type: workflow_type.humanize,
      status: status.humanize,
      current_stage: current_stage,
      created_by: created_by.full_name,
      created_at: created_at,
      due_date: due_date,
      overdue: overdue?,
      time_remaining: time_remaining,
      progress: approval_progress,
      approvers: get_approver_details,
      recent_activity: get_recent_activity
    }
  end

  # Get approver details
  def get_approver_details
    all_approvers.map do |approver_id|
      user = User.find_by(id: approver_id)
      next unless user
      
      approval = get_completed_approvals.find { |a| a['user_id'].to_s == approver_id.to_s }
      
      {
        id: user.id,
        name: user.full_name,
        email: user.email_address,
        role: user.role,
        status: approval ? approval['decision'] : 'pending',
        approved_at: approval&.dig('timestamp'),
        feedback: approval&.dig('feedback')
      }
    end.compact
  end

  # Get recent activity
  def get_recent_activity
    (metadata&.dig('approvals') || []).last(5).reverse
  end

  # Get total number of stages for multi-stage workflows
  def get_total_stages
    case workflow_type
    when 'multi_stage'
      required_approvers.is_a?(Array) ? required_approvers.length : 1
    else
      1
    end
  end
  
  private
  
  def self.format_approvers(approvers)
    case approvers
    when Array
      # Handle nested arrays for multi-stage workflows
      if approvers.first.is_a?(Array)
        approvers.map { |stage| stage.map(&:to_s) }
      else
        approvers.map(&:to_s)
      end
    when Hash
      approvers
    else
      [approvers.to_s]
    end
  end
  
  def self.default_escalation_rules
    {
      escalate_after_hours: 24,
      escalation_contacts: [],
      auto_escalate: false
    }
  end
  
  def handle_approval(user, feedback)
    case workflow_type
    when 'single_approver'
      complete_workflow!('approved', user, feedback)
    when 'multi_stage'
      handle_multi_stage_approval(user, feedback)
    when 'consensus'
      handle_consensus_approval(user, feedback)
    when 'parallel'
      handle_parallel_approval(user, feedback)
    when 'conditional'
      handle_conditional_approval(user, feedback)
    end
  end
  
  def handle_rejection(user, feedback)
    complete_workflow!('rejected', user, feedback)
  end
  
  def handle_change_request(user, feedback)
    update!(
      status: 'pending',
      current_stage: 1,
      metadata: (metadata || {}).merge(
        change_requested_by: user.id,
        change_request_reason: feedback,
        change_requested_at: Time.current
      )
    )
    
    # Notify content creator about requested changes
    notify_content_creator('change_request', feedback)
  end
  
  def handle_multi_stage_approval(user, feedback)
    if all_stage_approvers_completed?
      if final_stage?
        complete_workflow!('approved', user)
      else
        advance_to_next_stage!
      end
    end
  end
  
  def handle_consensus_approval(user, feedback)
    if all_approvers_completed?
      complete_workflow!('approved', user)
    end
  end
  
  def handle_parallel_approval(user, feedback)
    # In parallel workflow, any approval completes the workflow
    complete_workflow!('approved', user)
  end
  
  def handle_conditional_approval(user, feedback)
    # Conditional logic based on metadata and rules
    next_approvers = get_next_conditional_approvers(user, feedback)
    
    if next_approvers.empty?
      complete_workflow!('approved', user)
    else
      update!(
        required_approvers: next_approvers,
        current_stage: current_stage + 1
      )
      notify_current_stage_approvers
    end
  end
  
  def complete_workflow!(final_status, completing_user, feedback = nil)
    update!(
      status: final_status,
      completed_at: Time.current,
      metadata: (metadata || {}).merge(
        completed_by: completing_user.id,
        completion_feedback: feedback,
        completed_at: Time.current
      )
    )
    
    # Update the content status based on workflow result
    if final_status == 'approved'
      generated_content.approve!(completing_user)
    elsif final_status == 'rejected'
      generated_content.reject!(completing_user, feedback)
    end
    
    create_audit_entry("workflow_#{final_status}", feedback || "Workflow #{final_status}")
    notify_stakeholders("workflow_#{final_status}")
  end
  
  def advance_to_next_stage!
    update!(current_stage: current_stage + 1)
    notify_current_stage_approvers
    create_audit_entry('stage_advanced', "Advanced to stage #{current_stage}")
  end
  
  def record_approval_decision(user, decision, feedback)
    approvals = metadata&.dig('approvals') || []
    approvals << {
      user_id: user.id,
      user_name: user.full_name,
      decision: decision,
      feedback: feedback,
      timestamp: Time.current,
      stage: current_stage
    }
    
    update!(metadata: (metadata || {}).merge(approvals: approvals))
    create_audit_entry("approval_#{decision}", feedback || "#{decision.humanize} by #{user.full_name}")
  end
  
  def get_completed_approvals
    metadata&.dig('approvals') || []
  end
  
  def get_remaining_approvers
    completed_user_ids = get_completed_approvals.map { |a| a['user_id'].to_s }
    current_stage_approvers.reject { |approver_id| completed_user_ids.include?(approver_id.to_s) }
  end
  
  def all_stage_approvers_completed?
    get_remaining_approvers.empty?
  end
  
  def all_approvers_completed?
    case workflow_type
    when 'consensus'
      get_remaining_approvers.empty?
    when 'parallel'
      get_completed_approvals.any?
    else
      get_remaining_approvers.empty?
    end
  end
  
  def final_stage?
    case workflow_type
    when 'multi_stage'
      current_stage >= required_approvers.length
    else
      true
    end
  end
  
  def get_conditional_approvers
    # Implement conditional logic based on content type, urgency, etc.
    rules = escalation_rules || {}
    content_type = generated_content.content_type
    
    case content_type
    when 'email', 'social_post'
      rules['low_priority_approvers'] || required_approvers
    when 'landing_page', 'press_release'
      rules['high_priority_approvers'] || required_approvers
    else
      required_approvers
    end
  end
  
  def get_all_conditional_approvers
    (escalation_rules&.values&.flatten || []) + required_approvers
  end
  
  def get_next_conditional_approvers(user, feedback)
    # Implement logic to determine next approvers based on current approval
    []
  end
  
  def notify_current_stage_approvers
    current_stage_approvers.each do |approver_id|
      user = User.find_by(id: approver_id)
      next unless user
      
      if Rails.env.test?
        ApprovalMailer.approval_request(self, user).deliver_now
      else
        ApprovalMailer.approval_request(self, user).deliver_later
      end
    end
  end
  
  def notify_stakeholders(notification_type)
    stakeholders = [created_by, generated_content.created_by] + 
                  User.where(id: all_approvers).to_a
    
    stakeholders.uniq.each do |user|
      if Rails.env.test?
        ApprovalMailer.send(notification_type, self, user).deliver_now
      else
        ApprovalMailer.send(notification_type, self, user).deliver_later
      end
    end
  end
  
  def notify_content_creator(notification_type, message = nil)
    if Rails.env.test?
      ApprovalMailer.send(notification_type, self, generated_content.created_by, message).deliver_now
    else
      ApprovalMailer.send(notification_type, self, generated_content.created_by, message).deliver_later
    end
  end
  
  def notify_escalation_contacts
    contacts = escalation_rules&.dig('escalation_contacts') || []
    contacts.each do |contact_id|
      user = User.find_by(id: contact_id)
      next unless user
      
      if Rails.env.test?
        ApprovalMailer.workflow_escalated(self, user).deliver_now
      else
        ApprovalMailer.workflow_escalated(self, user).deliver_later
      end
    end
  end
  
  def create_audit_entry(action, description)
    ContentAuditLog.create!(
      generated_content: generated_content,
      user: Current.user || created_by,
      action: 'workflow_event',
      new_values: { action: action, description: description },
      metadata: { workflow_id: id, workflow_status: status }
    )
  rescue => e
    Rails.logger.error "Failed to create workflow audit entry: #{e.message}"
  end
  
  def validate_required_approvers_format
    return if required_approvers.blank?
    
    case workflow_type
    when 'single_approver', 'consensus', 'parallel'
      unless required_approvers.is_a?(Array)
        errors.add(:required_approvers, 'must be an array for this workflow type')
      end
    when 'multi_stage'
      unless required_approvers.is_a?(Array) && required_approvers.all? { |stage| stage.is_a?(Array) || stage.is_a?(String) || stage.is_a?(Integer) }
        errors.add(:required_approvers, 'must be an array of arrays for multi-stage workflow')
      end
    end
  end
  
  def validate_escalation_rules_format
    return if escalation_rules.blank?
    
    unless escalation_rules.is_a?(Hash)
      errors.add(:escalation_rules, 'must be a hash')
    end
  end
  
  def validate_due_date_in_future
    return if due_date.blank?
    return if persisted? && status_changed? && %w[escalated cancelled completed].include?(status)
    
    if due_date <= Time.current
      errors.add(:due_date, 'must be in the future')
    end
  end
end
