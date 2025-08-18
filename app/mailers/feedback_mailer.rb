# frozen_string_literal: true

# Mailer for sending feedback and collaboration notifications
class FeedbackMailer < ApplicationMailer
  default from: 'feedback@marketergen.com'
  
  # Notify stakeholders when new feedback is submitted
  def new_feedback(feedback, recipient = nil)
    @feedback = feedback
    @recipient = recipient || feedback.generated_content.created_by
    @content = feedback.generated_content
    @campaign = @content.campaign_plan
    @reviewer = feedback.reviewer_user
    @workflow = feedback.approval_workflow
    @content_url = generated_content_url(@content)
    @priority_indicator = priority_indicator(@feedback.priority)
    
    mail(
      to: @recipient.email_address,
      subject: "#{@priority_indicator} New Feedback: #{@content.title}"
    )
  end

  # Notify reviewer when their feedback is acknowledged
  def feedback_acknowledged(feedback, acknowledged_by)
    @feedback = feedback
    @acknowledged_by = acknowledged_by
    @content = feedback.generated_content
    @campaign = @content.campaign_plan
    @reviewer = feedback.reviewer_user
    @acknowledgment_note = feedback.metadata&.dig('acknowledgment_note')
    @content_url = generated_content_url(@content)
    
    mail(
      to: @reviewer.email_address,
      subject: "✓ Feedback Acknowledged: #{@content.title}"
    )
  end

  # Notify reviewer when their feedback is addressed
  def feedback_addressed(feedback, addressed_by, response_note = nil)
    @feedback = feedback
    @addressed_by = addressed_by
    @response_note = response_note
    @content = feedback.generated_content
    @campaign = @content.campaign_plan
    @reviewer = feedback.reviewer_user
    @content_url = generated_content_url(@content)
    
    mail(
      to: @reviewer.email_address,
      subject: "📝 Feedback Addressed: #{@content.title}"
    )
  end

  # Notify stakeholders when feedback is resolved
  def feedback_resolved(feedback, recipient)
    @feedback = feedback
    @recipient = recipient
    @content = feedback.generated_content
    @campaign = @content.campaign_plan
    @reviewer = feedback.reviewer_user
    @resolved_by = feedback.resolved_by_user
    @resolution_note = feedback.metadata&.dig('resolution_note')
    @content_url = generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "✅ Feedback Resolved: #{@content.title}"
    )
  end

  # Notify stakeholders when feedback is escalated
  def feedback_escalated(feedback, recipient)
    @feedback = feedback
    @recipient = recipient
    @content = feedback.generated_content
    @campaign = @content.campaign_plan
    @reviewer = feedback.reviewer_user
    @escalation_reason = feedback.metadata&.dig('escalation_reason')
    @escalated_to = feedback.metadata&.dig('escalated_to')
    @content_url = generated_content_url(@content)
    @priority_indicator = priority_indicator(@feedback.priority)
    
    mail(
      to: @recipient.email_address,
      subject: "🚨 #{@priority_indicator} Feedback Escalated: #{@content.title}"
    )
  end

  # Notify stakeholders about workflow-related feedback
  def workflow_feedback(feedback, recipient = nil)
    @feedback = feedback
    @workflow = feedback.approval_workflow
    @recipient = recipient || feedback.generated_content.created_by
    @content = feedback.generated_content
    @campaign = @content.campaign_plan
    @reviewer = feedback.reviewer_user
    @workflow_stage = @workflow&.current_stage
    @content_url = generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "📋 Workflow Feedback: #{@content.title}"
    )
  end

  # Notify when feedback requires urgent attention
  def feedback_urgent_attention(feedback, recipient, days_overdue = nil)
    @feedback = feedback
    @recipient = recipient
    @content = feedback.generated_content
    @campaign = @content.campaign_plan
    @reviewer = feedback.reviewer_user
    @days_overdue = days_overdue
    @content_url = generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "⚠️ URGENT: Feedback Requires Attention - #{@content.title}"
    )
  end

  # Notify reviewer about feedback status updates
  def feedback_status_update(feedback, recipient)
    @feedback = feedback
    @recipient = recipient
    @content = feedback.generated_content
    @campaign = @content.campaign_plan
    @reviewer = feedback.reviewer_user
    @status_change = feedback.metadata&.dig('status_change')
    @content_url = generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "Status Update: #{@content.title} Feedback"
    )
  end

  # Notify stakeholders about feedback summary for content
  def feedback_summary(content, recipient, feedbacks)
    @content = content
    @recipient = recipient
    @campaign = content.campaign_plan
    @feedbacks = feedbacks
    @total_feedback_count = feedbacks.count
    @pending_count = feedbacks.select { |f| f.status == 'pending' }.count
    @resolved_count = feedbacks.select { |f| f.status == 'resolved' }.count
    @content_url = generated_content_url(@content)
    
    mail(
      to: @recipient.email_address,
      subject: "📊 Feedback Summary: #{@content.title}"
    )
  end

  private

  def priority_indicator(priority)
    case priority
    when ContentFeedback::PRIORITIES[:critical]
      "🔴 CRITICAL"
    when ContentFeedback::PRIORITIES[:high]
      "🟡 HIGH"
    when ContentFeedback::PRIORITIES[:medium]
      "🟢 MEDIUM"
    when ContentFeedback::PRIORITIES[:low]
      "🔵 LOW"
    else
      ""
    end
  end
end
