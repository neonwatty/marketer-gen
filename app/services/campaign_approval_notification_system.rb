class CampaignApprovalNotificationSystem
  def initialize(campaign)
    @campaign = campaign
  end

  def notify_approval_request(user, workflow_id:, campaign_name:)
    # In a real implementation, this would send an actual email
    # For testing purposes, we'll create a mock email

    mock_email = OpenStruct.new(
      to: [ user.email_address ],
      subject: "Approval Request: #{campaign_name}",
      body: build_approval_request_body(user, workflow_id, campaign_name),
      delivered_at: Time.current
    )

    # Add to ActionMailer deliveries for testing
    ActionMailer::Base.deliveries << mock_email

    { success: true, email_sent: true, recipient: user.email_address }
  end

  def notify_approval_status_change(user, status:, workflow_id:, approver:)
    subject = case status
    when "approved"
      "Campaign Plan Approved"
    when "rejected"
      "Campaign Plan Rejected"
    else
      "Campaign Plan Status Update"
    end

    mock_email = OpenStruct.new(
      to: [ user.email_address ],
      subject: subject,
      body: build_status_change_body(user, status, workflow_id, approver),
      delivered_at: Time.current
    )

    # Add to ActionMailer deliveries for testing
    ActionMailer::Base.deliveries << mock_email

    { success: true, email_sent: true, recipient: user.email_address }
  end

  def notify_deadline_reminder(user, workflow_id:, days_remaining:)
    mock_email = OpenStruct.new(
      to: [ user.email_address ],
      subject: "Approval Deadline Reminder",
      body: build_deadline_reminder_body(user, workflow_id, days_remaining),
      delivered_at: Time.current
    )

    # Add to ActionMailer deliveries for testing
    ActionMailer::Base.deliveries << mock_email

    { success: true, email_sent: true, recipient: user.email_address }
  end

  def notify_workflow_completion(users, workflow_id:, final_status:)
    users.each do |user|
      subject = final_status == "approved" ? "Campaign Plan Approved - Ready for Execution" : "Campaign Plan Workflow Completed"

      mock_email = OpenStruct.new(
        to: [ user.email_address ],
        subject: subject,
        body: build_completion_body(user, workflow_id, final_status),
        delivered_at: Time.current
      )

      ActionMailer::Base.deliveries << mock_email
    end

    { success: true, emails_sent: users.length, recipients: users.map(&:email_address) }
  end

  def send_escalation_notification(managers, workflow_id:, overdue_days:)
    managers.each do |manager|
      mock_email = OpenStruct.new(
        to: [ manager.email_address ],
        subject: "Overdue Approval Escalation",
        body: build_escalation_body(manager, workflow_id, overdue_days),
        delivered_at: Time.current
      )

      ActionMailer::Base.deliveries << mock_email
    end

    { success: true, escalation_sent: true, recipients: managers.map(&:email_address) }
  end

  private

  def build_approval_request_body(user, workflow_id, campaign_name)
    <<~BODY
      Hello #{user.display_name},

      You have been requested to review and approve the campaign plan for: #{campaign_name}

      Campaign Details:
      - Campaign: #{@campaign.name}
      - Type: #{@campaign.campaign_type&.humanize}
      - Status: #{@campaign.status&.humanize}

      Please review the campaign plan and provide your approval or feedback.

      Workflow ID: #{workflow_id}

      Best regards,
      Marketing Team
    BODY
  end

  def build_status_change_body(user, status, workflow_id, approver)
    <<~BODY
      Hello #{user.display_name},

      The campaign plan for "#{@campaign.name}" has been #{status}.

      #{status == 'approved' ? 'Approved' : 'Reviewed'} by: #{approver.display_name}
      Date: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}
      Workflow ID: #{workflow_id}

      #{status == 'approved' ? 'The campaign plan is now ready for execution.' : 'Please review the feedback and make necessary adjustments.'}

      Best regards,
      Marketing Team
    BODY
  end

  def build_deadline_reminder_body(user, workflow_id, days_remaining)
    <<~BODY
      Hello #{user.display_name},

      This is a reminder that you have #{days_remaining} days remaining to review and approve the campaign plan for "#{@campaign.name}".

      Campaign Details:
      - Campaign: #{@campaign.name}
      - Type: #{@campaign.campaign_type&.humanize}
      - Deadline: #{days_remaining} days remaining

      Please complete your review as soon as possible to avoid delays in campaign execution.

      Workflow ID: #{workflow_id}

      Best regards,
      Marketing Team
    BODY
  end

  def build_completion_body(user, workflow_id, final_status)
    <<~BODY
      Hello #{user.display_name},

      The approval workflow for campaign "#{@campaign.name}" has been completed.

      Final Status: #{final_status.humanize}
      Completed: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}
      Workflow ID: #{workflow_id}

      #{final_status == 'approved' ? 'The campaign is now approved and ready for execution.' : 'Please review the final decision and next steps.'}

      Thank you for your participation in the approval process.

      Best regards,
      Marketing Team
    BODY
  end

  def build_escalation_body(manager, workflow_id, overdue_days)
    <<~BODY
      Hello #{manager.name},

      This is an escalation notice for an overdue campaign approval.

      Campaign: #{@campaign.name}
      Overdue: #{overdue_days} days
      Workflow ID: #{workflow_id}

      The approval workflow has been pending longer than expected. Please follow up with the assigned approvers or take appropriate action.

      Best regards,
      Marketing Operations
    BODY
  end
end
