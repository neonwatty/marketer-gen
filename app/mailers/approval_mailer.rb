# frozen_string_literal: true

# Mailer for sending approval workflow notifications
class ApprovalMailer < ApplicationMailer
  default from: 'approvals@marketergen.com'
  
  # Send approval request to designated approver
  def approval_request(workflow, approver)
    @workflow = workflow
    @approver = approver
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @approval_url = approve_generated_content_url(@content)
    @reject_url = reject_generated_content_url(@content)
    
    mail(
      to: @approver.email_address,
      subject: "Approval Required: #{@content.title}"
    )
  end
  
  # Send reminder for pending approvals
  def approval_reminder(workflow, approver, hours_waiting = nil)
    @workflow = workflow
    @approver = approver
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @hours_waiting = hours_waiting
    @approval_url = approve_generated_content_url(@content)
    @reject_url = reject_generated_content_url(@content)
    
    mail(
      to: @approver.email_address,
      subject: "Reminder: Approval Pending for #{@content.title}"
    )
  end
  
  # Notify stakeholders when workflow is approved
  def workflow_approved(workflow, recipient)
    @workflow = workflow
    @recipient = recipient
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @approver = User.find_by(id: workflow.metadata&.dig('completed_by'))
    @content_url = generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "✅ Approved: #{@content.title}"
    )
  end
  
  # Notify stakeholders when workflow is rejected
  def workflow_rejected(workflow, recipient)
    @workflow = workflow
    @recipient = recipient
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @rejector = User.find_by(id: workflow.metadata&.dig('completed_by'))
    @rejection_reason = workflow.metadata&.dig('completion_feedback')
    @content_url = generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "❌ Rejected: #{@content.title}"
    )
  end
  
  # Notify when workflow is escalated
  def workflow_escalated(workflow, recipient)
    @workflow = workflow
    @recipient = recipient
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @escalation_reason = workflow.metadata&.dig('escalation_reason')
    @content_url = generated_content_url(@content)
    @approve_url = approve_generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "🚨 Escalated: #{@content.title} Requires Immediate Attention"
    )
  end
  
  # Notify when approval is delegated
  def approval_delegated(workflow, from_user, to_user, reason = nil)
    @workflow = workflow
    @from_user = from_user
    @to_user = to_user
    @reason = reason
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @approval_url = approve_generated_content_url(@content)
    @reject_url = reject_generated_content_url(@content)
    
    mail(
      to: @to_user.email_address,
      subject: "Approval Delegated: #{@content.title}"
    )
  end
  
  # Warn about approaching deadline
  def deadline_warning(workflow, approver, time_remaining)
    @workflow = workflow
    @approver = approver
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @time_remaining = time_remaining
    @hours_remaining = (time_remaining / 1.hour).round(1)
    @approval_url = approve_generated_content_url(@content)
    @reject_url = reject_generated_content_url(@content)
    
    mail(
      to: @approver.email_address,
      subject: "⏰ Urgent: #{@content.title} - Deadline in #{@hours_remaining} hours"
    )
  end
  
  # Additional workflow notifications
  def workflow_cancelled(workflow, recipient)
    @workflow = workflow
    @recipient = recipient
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @cancellation_reason = workflow.metadata&.dig('cancellation_reason')
    @cancelled_by = User.find_by(id: workflow.metadata&.dig('cancelled_by'))
    
    mail(
      to: @recipient.email_address,
      subject: "Cancelled: #{@content.title} Approval Workflow"
    )
  end
  
  def status_update(workflow, recipient)
    @workflow = workflow
    @recipient = recipient
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @progress = workflow.approval_progress
    @content_url = generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "Status Update: #{@content.title}"
    )
  end
  
  def change_request(workflow, recipient, requested_changes = nil)
    @workflow = workflow
    @recipient = recipient
    @content = workflow.generated_content
    @campaign = @content.campaign_plan
    @requested_changes = requested_changes
    @requester = User.find_by(id: workflow.metadata&.dig('change_requested_by'))
    @content_url = edit_generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "Changes Requested: #{@content.title}"
    )
  end
  
  private
  
  def approve_generated_content_url(content)
    # This would be the actual URL in your application
    generated_content_url(content, action: 'approve')
  end
  
  def reject_generated_content_url(content)
    # This would be the actual URL in your application  
    generated_content_url(content, action: 'reject')
  end
end
