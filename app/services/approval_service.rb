# frozen_string_literal: true

# Service for managing approval workflows and operations
class ApprovalService < ApplicationService
  
  # Initiate approval workflow for content
  def self.initiate_approval(content_id, workflow_type, approvers, options = {})
    new(content_id, workflow_type, approvers, options).initiate_approval
  end
  
  # Process approval decision
  def self.process_approval(content_id, user_id, decision, feedback = nil)
    new(content_id, user_id, decision, feedback).process_approval
  end
  
  # Check approval status
  def self.check_approval_status(content_id)
    new(content_id).check_approval_status
  end
  
  # Send notifications for workflow
  def self.send_notifications(content_id, notification_type, options = {})
    new(content_id, notification_type, options).send_notifications
  end
  
  # Bulk approve multiple content items
  def self.bulk_approve(content_ids, user_id, decision, options = {})
    new.bulk_approve(content_ids, user_id, decision, options)
  end
  
  def initialize(*args)
    case args.length
    when 1
      @content_id = args[0]
    when 2
      @content_id, @param2 = args
    when 3
      @content_id, @param2, @param3 = args
    when 4
      @content_id, @workflow_type, @approvers, @options = args
    else
      # For bulk operations or other variations
    end
  end
  
  def initiate_approval
    return { success: false, error: "Content not found" } unless content
    return { success: false, error: "Workflow already exists" } if content.approval_workflow.present?
    
    begin
      # Validate workflow type and approvers
      validation_result = validate_workflow_parameters
      return validation_result unless validation_result[:success]
      
      # Create the workflow
      workflow = ApprovalWorkflow.create_workflow!(
        content,
        @workflow_type,
        @approvers,
        @options.merge(created_by: current_user)
      )
      
      # Create initial audit entry
      create_workflow_audit_entry('workflow_initiated', workflow)
      
      { success: true, data: { 
        workflow: workflow, 
        message: "Approval workflow initiated successfully",
        approvers: workflow.get_approver_details,
        next_action: "Waiting for approval from: #{workflow.current_stage_approvers.join(', ')}"
      } }
    rescue => error
      { success: false, error: "Failed to initiate approval: #{error.message}" }
    end
  end
  
  def process_approval
    user = User.find_by(id: @param2)
    decision = @param3
    feedback = @options if @options.is_a?(String)
    
    return { success: false, error: "Content not found" } unless content
    return { success: false, error: "User not found" } unless user
    return { success: false, error: "No active workflow" } unless workflow&.active?
    return { success: false, error: "Invalid decision" } unless valid_decision?(decision)
    return { success: false, error: "User cannot approve at this stage" } unless workflow.can_approve?(user)
    
    begin
      # Process the approval decision
      result = workflow.process_approval!(user, decision, feedback)
      return { success: false, error: "Failed to process approval" } unless result
      
      # Create audit entry
      create_approval_audit_entry(user, decision, feedback)
      
      # Determine next actions
      next_actions = determine_next_actions(workflow, decision)
      
      { success: true, data: {
        workflow: workflow.reload,
        decision: decision,
        user: user.full_name,
        message: "Approval #{decision} processed successfully",
        status: workflow.status,
        progress: workflow.approval_progress,
        next_actions: next_actions
      } }
    rescue => error
      { success: false, error: "Failed to process approval: #{error.message}" }
    end
  end
  
  def check_approval_status
    return { success: false, error: "Content not found" } unless content
    return { success: false, error: "No workflow found" } unless workflow
    
    begin
      status_data = {
        workflow_id: workflow.id,
        status: workflow.status,
        workflow_type: workflow.workflow_type,
        current_stage: workflow.current_stage,
        total_stages: workflow.get_total_stages,
        progress: workflow.approval_progress,
        overdue: workflow.overdue?,
        time_remaining: workflow.time_remaining,
        approvers: workflow.get_approver_details,
        recent_activity: workflow.get_recent_activity,
        pending_approvers: workflow.get_remaining_approvers.map do |approver_id|
          user = User.find_by(id: approver_id)
          user ? { id: user.id, name: user.full_name, email: user.email_address } : nil
        end.compact,
        feedback_summary: get_feedback_summary
      }
      
      { success: true, data: status_data }
    rescue => error
      { success: false, error: "Failed to check status: #{error.message}" }
    end
  end
  
  def send_notifications
    notification_type = @param2
    options = @param3 || {}
    
    return { success: false, error: "Content not found" } unless content
    return { success: false, error: "No workflow found" } unless workflow
    
    begin
      case notification_type
      when 'reminder'
        send_approval_reminders(options)
      when 'escalation'
        send_escalation_notifications(options)
      when 'status_update'
        send_status_update_notifications(options)
      when 'deadline_warning'
        send_deadline_warnings(options)
      else
        return { success: false, error: "Invalid notification type" }
      end
      
      { success: true, data: { 
        message: "#{notification_type.humanize} notifications sent successfully"
      } }
    rescue => error
      { success: false, error: "Failed to send notifications: #{error.message}" }
    end
  end
  
  def bulk_approve(content_ids, user_id, decision, options = {})
    user = User.find_by(id: user_id)
    return { success: false, error: "User not found" } unless user
    return { success: false, error: "Invalid decision" } unless valid_decision?(decision)
    
    results = {
      successful: [],
      failed: [],
      total: content_ids.length
    }
    
    content_ids.each do |content_id|
      begin
        content = GeneratedContent.find_by(id: content_id)
        next unless content&.approval_workflow&.active?
        next unless content.approval_workflow.can_approve?(user)
        
        if content.approval_workflow.process_approval!(user, decision, options[:feedback])
          results[:successful] << {
            content_id: content_id,
            title: content.title,
            status: content.approval_workflow.status
          }
        else
          results[:failed] << {
            content_id: content_id,
            title: content.title,
            error: "Failed to process approval"
          }
        end
      rescue => error
        results[:failed] << {
          content_id: content_id,
          error: error.message
        }
      end
    end
    
    success_rate = results[:successful].length.to_f / results[:total] * 100
    
    { success: success_rate > 50, data: {
      results: results,
      success_rate: success_rate.round(1),
      message: "Processed #{results[:successful].length} of #{results[:total]} approvals"
    } }
  end
  
  # Cancel approval workflow
  def cancel_approval(reason = nil)
    return { success: false, error: "Content not found" } unless content
    return { success: false, error: "No active workflow" } unless workflow&.active?
    
    begin
      result = workflow.cancel!(current_user, reason)
      return { success: false, error: "Failed to cancel workflow" } unless result
      
      create_workflow_audit_entry('workflow_cancelled', workflow, reason)
      
      { success: true, data: {
        message: "Approval workflow cancelled successfully",
        reason: reason
      } }
    rescue => error
      { success: false, error: "Failed to cancel workflow: #{error.message}" }
    end
  end
  
  # Escalate approval workflow
  def escalate_approval(escalation_reason = nil)
    return { success: false, error: "Content not found" } unless content
    return { success: false, error: "No workflow found" } unless workflow
    return { success: false, error: "Workflow cannot be escalated" } unless workflow.can_escalate?
    
    begin
      result = workflow.escalate!(escalation_reason)
      return { success: false, error: "Failed to escalate workflow" } unless result
      
      create_workflow_audit_entry('workflow_escalated', workflow, escalation_reason)
      
      { success: true, data: {
        message: "Approval workflow escalated successfully",
        reason: escalation_reason,
        new_status: workflow.status
      } }
    rescue => error
      { success: false, error: "Failed to escalate workflow: #{error.message}" }
    end
  end
  
  # Delegate approval to another user
  def delegate_approval(from_user_id, to_user_id, workflow_id, reason = nil)
    from_user = User.find_by(id: from_user_id)
    to_user = User.find_by(id: to_user_id)
    workflow = ApprovalWorkflow.find_by(id: workflow_id)
    
    return { success: false, error: "Invalid users or workflow" } unless from_user && to_user && workflow
    return { success: false, error: "User cannot delegate" } unless workflow.can_approve?(from_user)
    return { success: false, error: "Cannot delegate to the same user" } if from_user == to_user
    
    begin
      # Update the workflow approvers
      current_approvers = workflow.current_stage_approvers
      updated_approvers = current_approvers.map { |id| id.to_s == from_user_id.to_s ? to_user_id.to_s : id }
      
      workflow.update!(
        required_approvers: update_approvers_list(workflow.required_approvers, from_user_id, to_user_id),
        metadata: (workflow.metadata || {}).merge(
          delegations: (workflow.metadata&.dig('delegations') || []) + [{
            from_user_id: from_user_id,
            to_user_id: to_user_id,
            delegated_at: Time.current,
            reason: reason
          }]
        )
      )
      
      # Notify the new approver
      ApprovalMailer.approval_delegated(workflow, from_user, to_user, reason).deliver_later
      
      create_workflow_audit_entry('approval_delegated', workflow, 
        "Approval delegated from #{from_user.full_name} to #{to_user.full_name}: #{reason}")
      
      { success: true, data: {
        message: "Approval successfully delegated",
        from_user: from_user.full_name,
        to_user: to_user.full_name,
        reason: reason
      } }
    rescue => error
      { success: false, error: "Failed to delegate approval: #{error.message}" }
    end
  end
  
  # Get approval analytics
  def get_approval_analytics(timeframe = 30.days)
    workflows = ApprovalWorkflow.where(created_at: timeframe.ago..Time.current)
    
    analytics = {
      total_workflows: workflows.count,
      completed_workflows: workflows.completed.count,
      pending_workflows: workflows.active.count,
      average_completion_time: calculate_average_completion_time(workflows.completed),
      approval_rate: calculate_approval_rate(workflows.completed),
      overdue_workflows: workflows.overdue.count,
      escalated_workflows: workflows.escalated.count,
      workflow_types: workflows.group(:workflow_type).count,
      approver_performance: calculate_approver_performance(workflows),
      bottlenecks: identify_bottlenecks(workflows),
      trends: calculate_approval_trends(workflows)
    }
    
    { success: true, data: analytics }
  end
  
  private
  
  def content
    @content ||= GeneratedContent.find_by(id: @content_id)
  end
  
  def workflow
    @workflow ||= content&.approval_workflow
  end
  
  def current_user
    @options&.dig(:current_user) || Current.user
  end
  
  def validate_workflow_parameters
    unless ApprovalWorkflow::WORKFLOW_TYPES.include?(@workflow_type)
      return { success: false, error: "Invalid workflow type" }
    end
    
    unless @approvers.present?
      return { success: false, error: "Approvers must be specified" }
    end
    
    # Validate approvers exist
    approver_ids = @approvers.is_a?(Array) ? @approvers.flatten : [@approvers]
    invalid_approvers = approver_ids.reject { |id| User.exists?(id) }
    
    if invalid_approvers.any?
      return { success: false, error: "Invalid approver IDs: #{invalid_approvers.join(', ')}" }
    end
    
    { success: true }
  end
  
  def valid_decision?(decision)
    %w[approve reject request_changes].include?(decision)
  end
  
  def determine_next_actions(workflow, decision)
    case decision
    when 'approve'
      if workflow.approved?
        ["Content approved and ready for publishing"]
      elsif workflow.in_review?
        remaining_approvers = workflow.get_remaining_approvers.map do |id|
          User.find_by(id: id)&.full_name
        end.compact
        ["Waiting for approval from: #{remaining_approvers.join(', ')}"]
      else
        ["Next stage approvers will be notified"]
      end
    when 'reject'
      ["Content rejected and returned to creator"]
    when 'request_changes'
      ["Content creator will be notified of requested changes"]
    else
      []
    end
  end
  
  def get_feedback_summary
    feedback = content.content_feedbacks.active
    
    {
      total_feedback: feedback.count,
      unresolved_feedback: feedback.unresolved.count,
      high_priority_feedback: feedback.high_priority.count,
      recent_feedback: feedback.recent.limit(3).map(&:summary)
    }
  end
  
  def send_approval_reminders(options)
    remaining_approvers = workflow.get_remaining_approvers
    hours_since_request = ((Time.current - workflow.created_at) / 1.hour).round(1)
    
    remaining_approvers.each do |approver_id|
      user = User.find_by(id: approver_id)
      next unless user
      
      ApprovalMailer.approval_reminder(workflow, user, hours_since_request).deliver_later
    end
  end
  
  def send_escalation_notifications(options)
    escalation_contacts = workflow.escalation_rules&.dig('escalation_contacts') || []
    escalation_contacts.each do |contact_id|
      user = User.find_by(id: contact_id)
      next unless user
      
      ApprovalMailer.escalation_notification(workflow, user).deliver_later
    end
  end
  
  def send_status_update_notifications(options)
    stakeholders = [workflow.created_by, content.created_by]
    stakeholders.each do |user|
      ApprovalMailer.status_update(workflow, user).deliver_later
    end
  end
  
  def send_deadline_warnings(options)
    return unless workflow.due_date.present?
    
    time_remaining = workflow.time_remaining
    return unless time_remaining && time_remaining < 4.hours
    
    remaining_approvers = workflow.get_remaining_approvers
    remaining_approvers.each do |approver_id|
      user = User.find_by(id: approver_id)
      next unless user
      
      ApprovalMailer.deadline_warning(workflow, user, time_remaining).deliver_later
    end
  end
  
  def update_approvers_list(approvers_list, from_user_id, to_user_id)
    case approvers_list
    when Array
      approvers_list.map { |id| id.to_s == from_user_id.to_s ? to_user_id.to_s : id }
    when Hash
      # For multi-stage workflows
      approvers_list.transform_values do |stage_approvers|
        stage_approvers.map { |id| id.to_s == from_user_id.to_s ? to_user_id.to_s : id }
      end
    else
      to_user_id.to_s
    end
  end
  
  def calculate_average_completion_time(completed_workflows)
    return 0 if completed_workflows.empty?
    
    total_time = completed_workflows.sum do |workflow|
      (workflow.completed_at - workflow.created_at) / 1.hour
    end
    
    (total_time / completed_workflows.count).round(2)
  end
  
  def calculate_approval_rate(completed_workflows)
    return 0 if completed_workflows.empty?
    
    approved_count = completed_workflows.approved.count
    (approved_count.to_f / completed_workflows.count * 100).round(1)
  end
  
  def calculate_approver_performance(workflows)
    approver_stats = {}
    
    workflows.each do |workflow|
      approvals = workflow.metadata&.dig('approvals') || []
      approvals.each do |approval|
        user_id = approval['user_id']
        approver_stats[user_id] ||= {
          total_approvals: 0,
          approved: 0,
          rejected: 0,
          avg_response_time: 0,
          response_times: []
        }
        
        approver_stats[user_id][:total_approvals] += 1
        approver_stats[user_id][:approved] += 1 if approval['decision'] == 'approve'
        approver_stats[user_id][:rejected] += 1 if approval['decision'] == 'reject'
        
        # Calculate response time
        approval_time = Time.parse(approval['timestamp'])
        response_time = (approval_time - workflow.created_at) / 1.hour
        approver_stats[user_id][:response_times] << response_time
      end
    end
    
    # Calculate averages
    approver_stats.each do |user_id, stats|
      stats[:avg_response_time] = stats[:response_times].sum / stats[:response_times].length
      stats[:approval_rate] = (stats[:approved].to_f / stats[:total_approvals] * 100).round(1)
      stats.delete(:response_times)
    end
    
    approver_stats
  end
  
  def identify_bottlenecks(workflows)
    # Identify stages or approvers that typically take longer
    stage_times = {}
    
    workflows.each do |workflow|
      approvals = workflow.metadata&.dig('approvals') || []
      approvals.each do |approval|
        stage = approval['stage']
        approval_time = Time.parse(approval['timestamp'])
        response_time = (approval_time - workflow.created_at) / 1.hour
        
        stage_times[stage] ||= []
        stage_times[stage] << response_time
      end
    end
    
    stage_times.map do |stage, times|
      {
        stage: stage,
        avg_time: times.sum / times.length,
        max_time: times.max,
        occurrences: times.length
      }
    end.sort_by { |data| data[:avg_time] }.reverse
  end
  
  def calculate_approval_trends(workflows)
    # Simple approach without groupdate gem - group by week manually
    workflow_list = workflows.to_a
    weekly_data = workflow_list
      .group_by { |w| w.created_at.beginning_of_week }
      .transform_values(&:count)
    
    completed_workflows = workflow_list.select { |w| w.status == 'approved' }
    completion_rates = completed_workflows
      .group_by { |w| (w.completed_at || w.updated_at).beginning_of_week }
      .transform_values(&:count)
    
    {
      weekly_submissions: weekly_data,
      weekly_completions: completion_rates,
      trend_direction: calculate_trend_direction(weekly_data.values)
    }
  end
  
  def calculate_trend_direction(values)
    return 'stable' if values.length < 2
    
    recent_avg = values.last(4).sum / 4.0
    older_avg = values.first([values.length - 4, 4].max).sum / [values.length - 4, 4].max.to_f
    
    if recent_avg > older_avg * 1.1
      'increasing'
    elsif recent_avg < older_avg * 0.9
      'decreasing'
    else
      'stable'
    end
  end
  
  def create_workflow_audit_entry(action, workflow, details = nil)
    ContentAuditLog.create!(
      generated_content: content,
      user: current_user || workflow.created_by,
      action: 'workflow_event',
      new_values: { action: action, details: details },
      metadata: { workflow_id: workflow.id, service: 'ApprovalService' }
    )
  rescue => e
    Rails.logger.error "Failed to create workflow audit entry: #{e.message}"
  end
  
  def create_approval_audit_entry(user, decision, feedback)
    ContentAuditLog.create!(
      generated_content: content,
      user: user,
      action: 'approval_decision',
      new_values: { decision: decision, feedback: feedback },
      metadata: { workflow_id: workflow.id, service: 'ApprovalService' }
    )
  rescue => e
    Rails.logger.error "Failed to create approval audit entry: #{e.message}"
  end
end