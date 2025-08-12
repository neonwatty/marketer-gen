# WorkflowNotificationService - Handles notifications for workflow events
# Manages email, in-app, and webhook notifications for workflow transitions
class WorkflowNotificationService
  include ActiveModel::Model
  
  # Notification types
  NOTIFICATION_TYPES = %w[
    workflow_started
    stage_transitioned
    assignment_created
    assignment_expiring
    assignment_expired
    workflow_overdue
    workflow_completed
    workflow_cancelled
    approval_requested
    content_rejected
    content_approved
    publication_scheduled
    content_published
    escalation_triggered
  ].freeze
  
  # Notification channels
  NOTIFICATION_CHANNELS = %w[
    email
    in_app
    slack
    webhook
    sms
    push
  ].freeze
  
  # Priority levels
  PRIORITY_LEVELS = {
    low: 1,
    normal: 2,
    high: 3,
    urgent: 4,
    critical: 5
  }.freeze
  
  def initialize(options = {})
    @delivery_service = options[:delivery_service] || NotificationDeliveryService.new
    @template_service = options[:template_service] || NotificationTemplateService.new
    @preference_service = options[:preference_service] || UserPreferenceService.new
  end
  
  # Core notification methods
  def workflow_started(workflow, started_by = nil)
    notification_data = build_notification_data(
      type: 'workflow_started',
      workflow: workflow,
      actor: started_by,
      priority: :normal,
      title: "Workflow Started",
      message: "A new #{workflow.template_name} workflow has been started for #{workflow.content_item_type}",
      metadata: {
        workflow_id: workflow.id,
        content_type: workflow.content_item_type,
        template: workflow.template_name
      }
    )
    
    # Notify assigned users for the initial stage
    recipients = get_stage_recipients(workflow, workflow.current_stage)
    send_notifications(recipients, notification_data)
    
    # Notify stakeholders if configured
    stakeholders = get_workflow_stakeholders(workflow)
    send_notifications(stakeholders, notification_data) if stakeholders.any?
  end
  
  def stage_transitioned(workflow, from_stage, to_stage, performed_by = nil)
    notification_data = build_notification_data(
      type: 'stage_transitioned',
      workflow: workflow,
      actor: performed_by,
      priority: determine_transition_priority(from_stage, to_stage),
      title: "Workflow Stage Changed",
      message: "Content has moved from #{from_stage.humanize} to #{to_stage.humanize}",
      metadata: {
        workflow_id: workflow.id,
        from_stage: from_stage,
        to_stage: to_stage,
        transition_type: determine_transition_type(from_stage, to_stage)
      }
    )
    
    # Notify users assigned to the new stage
    new_stage_recipients = get_stage_recipients(workflow, to_stage)
    send_notifications(new_stage_recipients, notification_data)
    
    # Notify previous stage users if it's a rejection/return
    if is_backward_transition?(from_stage, to_stage)
      previous_stage_recipients = get_stage_recipients(workflow, to_stage)
      rejection_data = notification_data.merge(
        title: "Content Returned",
        message: "Content has been returned to #{to_stage.humanize} stage",
        priority: :high
      )
      send_notifications(previous_stage_recipients, rejection_data)
    end
    
    # Send special notifications for critical transitions
    handle_special_transitions(workflow, from_stage, to_stage, performed_by)
  end
  
  def assignment_created(assignment)
    notification_data = build_notification_data(
      type: 'assignment_created',
      workflow: assignment.content_workflow,
      priority: :normal,
      title: "New Assignment",
      message: "You have been assigned as #{assignment.role.humanize} for the #{assignment.stage.humanize} stage",
      metadata: {
        assignment_id: assignment.id,
        role: assignment.role,
        stage: assignment.stage,
        workflow_id: assignment.content_workflow_id
      }
    )
    
    recipients = [assignment.user_id]
    send_notifications(recipients, notification_data)
  end
  
  def assignment_expiring(assignment)
    time_remaining = assignment.time_until_expiration
    
    notification_data = build_notification_data(
      type: 'assignment_expiring',
      workflow: assignment.content_workflow,
      priority: :high,
      title: "Assignment Expiring Soon",
      message: "Your assignment as #{assignment.role.humanize} will expire in #{distance_of_time_in_words(time_remaining)}",
      metadata: {
        assignment_id: assignment.id,
        expires_at: assignment.expires_at,
        time_remaining: time_remaining
      }
    )
    
    recipients = [assignment.user_id]
    send_notifications(recipients, notification_data)
  end
  
  def assignment_expired(assignment)
    notification_data = build_notification_data(
      type: 'assignment_expired',
      workflow: assignment.content_workflow,
      priority: :urgent,
      title: "Assignment Expired",
      message: "Your assignment as #{assignment.role.humanize} has expired",
      metadata: {
        assignment_id: assignment.id,
        expired_at: assignment.expires_at
      }
    )
    
    recipients = [assignment.user_id]
    send_notifications(recipients, notification_data)
    
    # Notify workflow administrators
    admins = get_workflow_administrators(assignment.content_workflow)
    admin_notification = notification_data.merge(
      title: "User Assignment Expired",
      message: "Assignment for user #{assignment.user_id} as #{assignment.role.humanize} has expired"
    )
    send_notifications(admins, admin_notification)
  end
  
  def workflow_overdue(workflow, overdue_hours = 48)
    notification_data = build_notification_data(
      type: 'workflow_overdue',
      workflow: workflow,
      priority: :urgent,
      title: "Workflow Overdue",
      message: "Workflow has been in #{workflow.current_stage.humanize} stage for over #{overdue_hours} hours",
      metadata: {
        workflow_id: workflow.id,
        overdue_hours: overdue_hours,
        time_in_stage: workflow.time_in_current_stage
      }
    )
    
    # Notify current stage assignees
    current_assignees = get_stage_recipients(workflow, workflow.current_stage)
    send_notifications(current_assignees, notification_data)
    
    # Escalate to administrators
    admins = get_workflow_administrators(workflow)
    escalation_notification = notification_data.merge(
      title: "Workflow Escalation",
      message: "Workflow requires attention - overdue for #{overdue_hours} hours",
      priority: :critical
    )
    send_notifications(admins, escalation_notification)
  end
  
  def approval_requested(workflow, requested_by = nil)
    notification_data = build_notification_data(
      type: 'approval_requested',
      workflow: workflow,
      actor: requested_by,
      priority: :high,
      title: "Approval Requested",
      message: "Content is ready for your approval",
      metadata: {
        workflow_id: workflow.id,
        requested_by: requested_by&.id,
        stage: workflow.current_stage
      }
    )
    
    # Notify approvers
    approvers = get_role_recipients(workflow, 'approver')
    send_notifications(approvers, notification_data)
  end
  
  def content_approved(workflow, approved_by = nil)
    notification_data = build_notification_data(
      type: 'content_approved',
      workflow: workflow,
      actor: approved_by,
      priority: :normal,
      title: "Content Approved",
      message: "Your content has been approved and is ready for publication",
      metadata: {
        workflow_id: workflow.id,
        approved_by: approved_by&.id,
        approved_at: Time.current
      }
    )
    
    # Notify content creators
    creators = get_role_recipients(workflow, 'creator')
    send_notifications(creators, notification_data)
    
    # Notify publishers
    publishers = get_role_recipients(workflow, 'publisher')
    publisher_notification = notification_data.merge(
      title: "Content Ready for Publication",
      message: "Approved content is ready for publication"
    )
    send_notifications(publishers, publisher_notification)
  end
  
  def content_rejected(workflow, rejected_by = nil, reason = nil)
    notification_data = build_notification_data(
      type: 'content_rejected',
      workflow: workflow,
      actor: rejected_by,
      priority: :high,
      title: "Content Rejected",
      message: reason || "Your content has been rejected and requires changes",
      metadata: {
        workflow_id: workflow.id,
        rejected_by: rejected_by&.id,
        rejection_reason: reason,
        rejected_at: Time.current
      }
    )
    
    # Notify content creators
    creators = get_role_recipients(workflow, 'creator')
    send_notifications(creators, notification_data)
  end
  
  def content_published(workflow, published_by = nil)
    notification_data = build_notification_data(
      type: 'content_published',
      workflow: workflow,
      actor: published_by,
      priority: :normal,
      title: "Content Published",
      message: "Your content has been successfully published",
      metadata: {
        workflow_id: workflow.id,
        published_by: published_by&.id,
        published_at: Time.current
      }
    )
    
    # Notify all workflow participants
    all_participants = get_all_workflow_participants(workflow)
    send_notifications(all_participants, notification_data)
  end
  
  def workflow_completed(workflow)
    notification_data = build_notification_data(
      type: 'workflow_completed',
      workflow: workflow,
      priority: :normal,
      title: "Workflow Completed",
      message: "Workflow has been completed successfully",
      metadata: {
        workflow_id: workflow.id,
        completed_at: Time.current,
        total_duration: workflow.total_workflow_time
      }
    )
    
    # Notify all participants
    all_participants = get_all_workflow_participants(workflow)
    send_notifications(all_participants, notification_data)
  end
  
  def workflow_cancelled(workflow, cancelled_by = nil, reason = nil)
    notification_data = build_notification_data(
      type: 'workflow_cancelled',
      workflow: workflow,
      actor: cancelled_by,
      priority: :high,
      title: "Workflow Cancelled",
      message: reason || "Workflow has been cancelled",
      metadata: {
        workflow_id: workflow.id,
        cancelled_by: cancelled_by&.id,
        cancellation_reason: reason,
        cancelled_at: Time.current
      }
    )
    
    # Notify all active participants
    active_participants = get_active_workflow_participants(workflow)
    send_notifications(active_participants, notification_data)
  end
  
  # Bulk notification methods
  def send_overdue_notifications(overdue_hours = 48)
    overdue_workflows = ContentWorkflow.active
                                      .joins(:audit_entries)
                                      .where('workflow_audit_entries.created_at < ?', overdue_hours.hours.ago)
                                      .where.not(current_stage: ['published', 'archived'])
                                      .distinct
    
    notifications_sent = 0
    
    overdue_workflows.find_each do |workflow|
      workflow_overdue(workflow, overdue_hours)
      notifications_sent += 1
    end
    
    notifications_sent
  end
  
  def send_assignment_expiry_reminders(days_before = 2)
    expiring_assignments = WorkflowAssignment.active
                                           .where('expires_at IS NOT NULL')
                                           .where('expires_at BETWEEN ? AND ?', 
                                                  Time.current, 
                                                  days_before.days.from_now)
    
    notifications_sent = 0
    
    expiring_assignments.find_each do |assignment|
      assignment_expiring(assignment)
      notifications_sent += 1
    end
    
    notifications_sent
  end
  
  def send_digest_notifications(frequency = :daily, user_ids = nil)
    case frequency
    when :daily
      send_daily_digest(user_ids)
    when :weekly
      send_weekly_digest(user_ids)
    when :monthly
      send_monthly_digest(user_ids)
    end
  end
  
  private
  
  def build_notification_data(type:, workflow:, actor: nil, priority: :normal, title:, message:, metadata: {})
    {
      type: type,
      priority: priority,
      title: title,
      message: message,
      workflow_id: workflow.id,
      content_type: workflow.content_item_type,
      content_id: workflow.content_item_id,
      actor_id: actor&.id,
      created_at: Time.current,
      metadata: metadata.merge({
        template_name: workflow.template_name,
        current_stage: workflow.current_stage,
        workflow_status: workflow.status
      })
    }
  end
  
  def send_notifications(recipient_ids, notification_data)
    return if recipient_ids.empty?
    
    recipient_ids.each do |user_id|
      # Get user notification preferences
      preferences = @preference_service.get_preferences(user_id)
      
      # Skip if user has disabled this notification type
      next unless should_send_notification?(preferences, notification_data[:type])
      
      # Determine delivery channels
      channels = determine_channels(preferences, notification_data[:priority])
      
      # Send via each enabled channel
      channels.each do |channel|
        deliver_notification(user_id, notification_data, channel, preferences)
      end
    end
    
    # Store notification in database
    store_notification(recipient_ids, notification_data)
  end
  
  def should_send_notification?(preferences, notification_type)
    # Check if user has this notification type enabled
    type_preferences = preferences.dig('notifications', notification_type)
    return true if type_preferences.nil? # Default to enabled
    
    type_preferences['enabled'] != false
  end
  
  def determine_channels(preferences, priority)
    default_channels = ['in_app']
    
    # Add email for high priority notifications
    if PRIORITY_LEVELS[priority] >= PRIORITY_LEVELS[:high]
      default_channels << 'email'
    end
    
    # Add urgent channels for critical notifications
    if priority == :critical
      default_channels += ['slack', 'sms']
    end
    
    # Filter by user preferences
    enabled_channels = preferences.dig('channels') || {}
    
    default_channels.select do |channel|
      enabled_channels[channel] != false
    end
  end
  
  def deliver_notification(user_id, notification_data, channel, preferences)
    case channel
    when 'email'
      deliver_email_notification(user_id, notification_data, preferences)
    when 'in_app'
      deliver_in_app_notification(user_id, notification_data)
    when 'slack'
      deliver_slack_notification(user_id, notification_data, preferences)
    when 'webhook'
      deliver_webhook_notification(user_id, notification_data, preferences)
    when 'sms'
      deliver_sms_notification(user_id, notification_data, preferences)
    when 'push'
      deliver_push_notification(user_id, notification_data)
    end
  rescue => e
    Rails.logger.error "Failed to deliver #{channel} notification to user #{user_id}: #{e.message}"
  end
  
  def deliver_email_notification(user_id, notification_data, preferences)
    template = @template_service.get_email_template(notification_data[:type])
    
    @delivery_service.send_email(
      to: get_user_email(user_id),
      subject: notification_data[:title],
      template: template,
      data: notification_data
    )
  end
  
  def deliver_in_app_notification(user_id, notification_data)
    WorkflowNotification.create!(
      user_id: user_id,
      notification_type: notification_data[:type],
      title: notification_data[:title],
      message: notification_data[:message],
      priority: notification_data[:priority],
      workflow_id: notification_data[:workflow_id],
      metadata: notification_data[:metadata],
      read_at: nil
    )
  end
  
  def deliver_slack_notification(user_id, notification_data, preferences)
    slack_webhook = preferences.dig('integrations', 'slack', 'webhook_url')
    return unless slack_webhook
    
    @delivery_service.send_slack_message(
      webhook_url: slack_webhook,
      message: format_slack_message(notification_data)
    )
  end
  
  def deliver_webhook_notification(user_id, notification_data, preferences)
    webhook_url = preferences.dig('integrations', 'webhook', 'url')
    return unless webhook_url
    
    @delivery_service.send_webhook(
      url: webhook_url,
      data: notification_data
    )
  end
  
  def deliver_sms_notification(user_id, notification_data, preferences)
    phone_number = preferences.dig('contact', 'phone')
    return unless phone_number
    
    @delivery_service.send_sms(
      to: phone_number,
      message: "#{notification_data[:title]}: #{notification_data[:message]}"
    )
  end
  
  def deliver_push_notification(user_id, notification_data)
    device_tokens = get_user_device_tokens(user_id)
    return if device_tokens.empty?
    
    device_tokens.each do |token|
      @delivery_service.send_push_notification(
        token: token,
        title: notification_data[:title],
        body: notification_data[:message],
        data: notification_data[:metadata]
      )
    end
  end
  
  def store_notification(recipient_ids, notification_data)
    # Store in database for audit and in-app display
    recipient_ids.each do |user_id|
      WorkflowNotification.create!(
        user_id: user_id,
        notification_type: notification_data[:type],
        title: notification_data[:title],
        message: notification_data[:message],
        priority: notification_data[:priority],
        workflow_id: notification_data[:workflow_id],
        metadata: notification_data[:metadata]
      )
    end
  end
  
  def get_stage_recipients(workflow, stage)
    workflow.assignments
           .current
           .where(stage: stage)
           .pluck(:user_id)
           .uniq
  end
  
  def get_role_recipients(workflow, role)
    workflow.assignments
           .current
           .where(role: role)
           .pluck(:user_id)
           .uniq
  end
  
  def get_all_workflow_participants(workflow)
    workflow.audit_entries
           .where.not(performed_by_id: nil)
           .distinct
           .pluck(:performed_by_id)
  end
  
  def get_active_workflow_participants(workflow)
    workflow.assignments
           .current
           .pluck(:user_id)
           .uniq
  end
  
  def get_workflow_stakeholders(workflow)
    # This would be configured per workflow template
    # For now, return empty array
    []
  end
  
  def get_workflow_administrators(workflow)
    # This would query for users with admin role
    # For now, return mock admin IDs
    [999] # Mock admin user ID
  end
  
  def determine_transition_priority(from_stage, to_stage)
    if is_backward_transition?(from_stage, to_stage)
      :high
    elsif to_stage == 'published'
      :high
    elsif to_stage == 'approved'
      :normal
    else
      :normal
    end
  end
  
  def determine_transition_type(from_stage, to_stage)
    if is_backward_transition?(from_stage, to_stage)
      'backward'
    else
      'forward'
    end
  end
  
  def is_backward_transition?(from_stage, to_stage)
    stage_orders = WorkflowEngine::WORKFLOW_STAGES.transform_values { |config| config[:order] }
    
    from_order = stage_orders[from_stage.to_sym]
    to_order = stage_orders[to_stage.to_sym]
    
    return false unless from_order && to_order
    
    to_order < from_order
  end
  
  def handle_special_transitions(workflow, from_stage, to_stage, performed_by)
    case to_stage
    when 'published'
      content_published(workflow, performed_by)
    when 'approved'
      content_approved(workflow, performed_by)
    when 'draft'
      if from_stage != 'archived'
        content_rejected(workflow, performed_by)
      end
    when 'archived'
      workflow_completed(workflow)
    end
  end
  
  def format_slack_message(notification_data)
    {
      text: notification_data[:title],
      attachments: [
        {
          color: priority_color(notification_data[:priority]),
          fields: [
            {
              title: "Message",
              value: notification_data[:message],
              short: false
            },
            {
              title: "Workflow",
              value: "ID: #{notification_data[:workflow_id]}",
              short: true
            },
            {
              title: "Stage",
              value: notification_data.dig(:metadata, :current_stage)&.humanize,
              short: true
            }
          ]
        }
      ]
    }
  end
  
  def priority_color(priority)
    case priority
    when :critical
      'danger'
    when :urgent, :high
      'warning'
    when :normal
      'good'
    else
      '#439FE0'
    end
  end
  
  def get_user_email(user_id)
    # This would integrate with your User model
    "user#{user_id}@example.com"
  end
  
  def get_user_device_tokens(user_id)
    # This would query device tokens from your user devices table
    []
  end
  
  def send_daily_digest(user_ids = nil)
    # Implementation for daily digest notifications
    # Would aggregate notifications and send summary
  end
  
  def send_weekly_digest(user_ids = nil)
    # Implementation for weekly digest notifications
  end
  
  def send_monthly_digest(user_ids = nil)
    # Implementation for monthly digest notifications
  end
  
  def distance_of_time_in_words(seconds)
    # Simple time distance helper
    if seconds < 1.hour
      "#{(seconds / 60).round} minutes"
    elsif seconds < 1.day
      "#{(seconds / 1.hour).round} hours"
    else
      "#{(seconds / 1.day).round} days"
    end
  end
end

# Supporting service classes (would be implemented separately)
class NotificationDeliveryService
  def send_email(to:, subject:, template:, data:)
    # Email delivery implementation
    Rails.logger.info "Sending email to #{to}: #{subject}"
  end
  
  def send_slack_message(webhook_url:, message:)
    # Slack webhook implementation
    Rails.logger.info "Sending Slack message to #{webhook_url}"
  end
  
  def send_webhook(url:, data:)
    # Generic webhook implementation
    Rails.logger.info "Sending webhook to #{url}"
  end
  
  def send_sms(to:, message:)
    # SMS delivery implementation
    Rails.logger.info "Sending SMS to #{to}: #{message}"
  end
  
  def send_push_notification(token:, title:, body:, data:)
    # Push notification implementation
    Rails.logger.info "Sending push notification to #{token}: #{title}"
  end
end

class NotificationTemplateService
  def get_email_template(notification_type)
    # Return email template for notification type
    "default_template"
  end
end

class UserPreferenceService
  def get_preferences(user_id)
    # Return user notification preferences
    # Default preferences
    {
      'notifications' => {},
      'channels' => {
        'email' => true,
        'in_app' => true,
        'slack' => false
      },
      'contact' => {},
      'integrations' => {}
    }
  end
end