# frozen_string_literal: true

# Model for managing feedback and comments on content
class ContentFeedback < ApplicationRecord
  belongs_to :generated_content
  belongs_to :reviewer_user, class_name: 'User'
  belongs_to :resolved_by_user, class_name: 'User', optional: true
  belongs_to :approval_workflow, optional: true
  
  # Feedback types
  FEEDBACK_TYPES = %w[
    comment
    suggestion
    approval
    rejection
    question
    concern
    compliment
    change_request
    clarification
  ].freeze
  
  # Feedback statuses
  STATUSES = %w[
    pending
    acknowledged
    addressed
    resolved
    dismissed
    escalated
  ].freeze
  
  # Priority levels
  PRIORITIES = {
    low: 1,
    medium: 2,
    high: 3,
    critical: 4
  }.freeze
  
  validates :feedback_text, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :feedback_type, presence: true, inclusion: { in: FEEDBACK_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, presence: true, inclusion: { in: PRIORITIES.values }
  validates :reviewer_user, presence: true
  validates :generated_content, presence: true
  
  validate :resolved_fields_consistency
  
  scope :pending, -> { where(status: 'pending') }
  scope :acknowledged, -> { where(status: 'acknowledged') }
  scope :addressed, -> { where(status: 'addressed') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :unresolved, -> { where.not(status: 'resolved') }
  scope :dismissed, -> { where(status: 'dismissed') }
  scope :escalated, -> { where(status: 'escalated') }
  scope :active, -> { where(status: %w[pending acknowledged addressed]) }
  
  scope :by_type, ->(type) { where(feedback_type: type) }
  scope :by_priority, ->(priority) { where(priority: PRIORITIES[priority.to_sym] || priority) }
  scope :high_priority, -> { where(priority: [PRIORITIES[:high], PRIORITIES[:critical]]) }
  scope :critical, -> { where(priority: PRIORITIES[:critical]) }
  
  scope :for_content, ->(content_id) { where(generated_content_id: content_id) }
  scope :by_reviewer, ->(user_id) { where(reviewer_user_id: user_id) }
  scope :in_workflow, ->(workflow_id) { where(approval_workflow_id: workflow_id) }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :by_priority_desc, -> { order(priority: :desc, created_at: :desc) }
  
  # Create feedback with automatic workflow association
  def self.create_feedback!(content, reviewer, feedback_text, feedback_type, options = {})
    feedback = new(
      generated_content: content,
      reviewer_user: reviewer,
      feedback_text: feedback_text,
      feedback_type: feedback_type,
      priority: options[:priority] || PRIORITIES[:medium],
      approval_workflow: content.approval_workflow,
      metadata: options[:metadata] || {}
    )
    
    feedback.save!
    feedback.notify_stakeholders
    feedback.create_audit_entry('feedback_created')
    feedback
  end
  
  # Acknowledge feedback
  def acknowledge!(user = nil)
    return false if resolved?
    
    transaction do
      update!(
        status: 'acknowledged',
        metadata: (metadata || {}).merge(
          acknowledged_by: user&.id,
          acknowledged_at: Time.current
        )
      )
      
      create_audit_entry('feedback_acknowledged', user)
      notify_reviewer('feedback_acknowledged')
    end
    
    true
  end
  
  # Mark feedback as addressed
  def address!(user, response = nil)
    return false if resolved?
    
    transaction do
      update!(
        status: 'addressed',
        metadata: (metadata || {}).merge(
          addressed_by: user.id,
          addressed_at: Time.current,
          response: response
        )
      )
      
      create_audit_entry('feedback_addressed', user, response)
      notify_reviewer('feedback_addressed', response)
    end
    
    true
  end
  
  # Resolve feedback
  def resolve!(user, resolution_notes = nil)
    return false if resolved?
    
    transaction do
      update!(
        status: 'resolved',
        resolved_at: Time.current,
        resolved_by_user: user,
        metadata: (metadata || {}).merge(
          resolution_notes: resolution_notes,
          resolved_at: Time.current
        )
      )
      
      create_audit_entry('feedback_resolved', user, resolution_notes)
      notify_reviewer('feedback_resolved', resolution_notes)
    end
    
    true
  end
  
  # Dismiss feedback
  def dismiss!(user, reason = nil)
    return false if resolved?
    
    transaction do
      update!(
        status: 'dismissed',
        resolved_at: Time.current,
        resolved_by_user: user,
        metadata: (metadata || {}).merge(
          dismissal_reason: reason,
          dismissed_at: Time.current
        )
      )
      
      create_audit_entry('feedback_dismissed', user, reason)
      notify_reviewer('feedback_dismissed', reason)
    end
    
    true
  end
  
  # Escalate feedback
  def escalate!(user, escalation_reason = nil)
    return false if resolved? || escalated?
    
    transaction do
      update!(
        status: 'escalated',
        priority: [priority + 1, PRIORITIES[:critical]].min,
        metadata: (metadata || {}).merge(
          escalated_by: user.id,
          escalated_at: Time.current,
          escalation_reason: escalation_reason
        )
      )
      
      create_audit_entry('feedback_escalated', user, escalation_reason)
      notify_escalation_contacts(escalation_reason)
    end
    
    true
  end
  
  # Check if feedback requires action
  def requires_action?
    %w[pending acknowledged].include?(status) && high_priority?
  end
  
  # Check if feedback is high priority
  def high_priority?
    priority >= PRIORITIES[:high]
  end
  
  # Check if feedback is critical
  def critical?
    priority == PRIORITIES[:critical]
  end
  
  # Check if feedback is resolved
  def resolved?
    status == 'resolved'
  end
  
  # Check if feedback is escalated
  def escalated?
    status == 'escalated'
  end
  
  # Get priority name
  def priority_name
    PRIORITIES.key(priority)&.to_s&.humanize || 'Unknown'
  end
  
  # Get time since creation
  def age_in_hours
    ((Time.current - created_at) / 1.hour).round(1)
  end
  
  # Check if feedback is overdue (based on priority)
  def overdue?
    case priority
    when PRIORITIES[:critical]
      age_in_hours > 2  # 2 hours for critical
    when PRIORITIES[:high]
      age_in_hours > 8  # 8 hours for high
    when PRIORITIES[:medium]
      age_in_hours > 24 # 24 hours for medium
    else
      age_in_hours > 72 # 72 hours for low
    end
  end
  
  # Get feedback summary
  def summary
    {
      id: id,
      content_title: generated_content.title,
      reviewer: reviewer_user.full_name,
      feedback_type: feedback_type.humanize,
      priority: priority_name,
      status: status.humanize,
      created_at: created_at,
      age_hours: age_in_hours,
      overdue: overdue?,
      requires_action: requires_action?,
      preview: feedback_text.truncate(100),
      resolved_by: resolved_by_user&.full_name,
      resolved_at: resolved_at
    }
  end
  
  # Get related feedback for the same content
  def related_feedback
    ContentFeedback.for_content(generated_content_id)
                  .where.not(id: id)
                  .recent
                  .limit(5)
  end
  
  # Get feedback thread (replies and related comments)
  def feedback_thread
    thread_feedback = []
    
    # Get feedback from the same workflow
    if approval_workflow_id.present?
      thread_feedback += ContentFeedback.in_workflow(approval_workflow_id)
                                       .where.not(id: id)
                                       .recent
    end
    
    # Get feedback from the same user on this content
    thread_feedback += ContentFeedback.for_content(generated_content_id)
                                     .by_reviewer(reviewer_user_id)
                                     .where.not(id: id)
                                     .recent
    
    thread_feedback.uniq.sort_by(&:created_at)
  end
  
  # Export feedback data
  def export_data
    {
      id: id,
      content_id: generated_content_id,
      content_title: generated_content.title,
      reviewer: {
        id: reviewer_user.id,
        name: reviewer_user.full_name,
        email: reviewer_user.email_address,
        role: reviewer_user.role
      },
      feedback: {
        text: feedback_text,
        type: feedback_type,
        priority: priority_name,
        status: status
      },
      workflow_id: approval_workflow_id,
      timestamps: {
        created_at: created_at,
        resolved_at: resolved_at,
        age_hours: age_in_hours
      },
      resolution: {
        resolved_by: resolved_by_user&.full_name,
        notes: metadata&.dig('resolution_notes'),
        response: metadata&.dig('response')
      },
      metadata: metadata
    }
  end
  
  def notify_stakeholders
    # Notify content creator about new feedback
    FeedbackMailer.new_feedback(self).deliver_later
    
    # Notify workflow participants if part of approval process
    if approval_workflow.present?
      FeedbackMailer.workflow_feedback(self).deliver_later
    end
  end
  
  def notify_reviewer(notification_type, message = nil)
    case notification_type
    when 'feedback_acknowledged'
      acknowledged_by_id = metadata&.dig('acknowledged_by')
      acknowledged_by = acknowledged_by_id ? User.find(acknowledged_by_id) : nil
      FeedbackMailer.feedback_acknowledged(self, acknowledged_by).deliver_later if acknowledged_by
    when 'feedback_addressed'
      addressed_by_id = metadata&.dig('addressed_by')
      addressed_by = addressed_by_id ? User.find(addressed_by_id) : nil
      FeedbackMailer.feedback_addressed(self, addressed_by, message).deliver_now if addressed_by
    when 'feedback_resolved'
      FeedbackMailer.feedback_resolved(self, reviewer_user).deliver_later
    when 'feedback_dismissed'
      FeedbackMailer.feedback_resolved(self, reviewer_user).deliver_now
    end
  end
  
  def notify_escalation_contacts(reason)
    # Notify content creator about escalated feedback
    FeedbackMailer.feedback_escalated(self, generated_content.created_by).deliver_now
  end
  
  def priority_label
    case priority
    when PRIORITIES[:urgent]
      'Urgent'
    when PRIORITIES[:high]
      'High'
    when PRIORITIES[:medium]
      'Medium'
    when PRIORITIES[:low]
      'Low'
    else
      'Unknown'
    end
  end

  def create_audit_entry(action, user = nil, details = nil)
    ContentAuditLog.create!(
      generated_content: generated_content,
      user: user || reviewer_user,
      action: 'feedback_event',
      new_values: { 
        action: action, 
        feedback_id: id, 
        feedback_type: feedback_type,
        details: details 
      },
      metadata: { 
        feedback_id: id, 
        feedback_status: status,
        workflow_id: approval_workflow_id 
      }
    )
  rescue => e
    Rails.logger.error "Failed to create feedback audit entry: #{e.message}"
  end
  
  def resolved_fields_consistency
    if resolved_at.present? && resolved_by_user.blank?
      errors.add(:resolved_by_user, 'must be present when resolved_at is set')
    end
    
    if resolved_by_user.present? && resolved_at.blank?
      errors.add(:resolved_at, 'must be present when resolved_by_user is set')
    end
    
    if resolved? && (resolved_at.blank? || resolved_by_user.blank?)
      errors.add(:base, 'Resolved feedback must have resolved_at and resolved_by_user')
    end
  end
end
