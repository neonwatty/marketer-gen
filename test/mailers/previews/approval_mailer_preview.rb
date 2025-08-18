# Preview all emails at http://localhost:3000/rails/mailers/approval_mailer
class ApprovalMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/approval_mailer/approval_request
  def approval_request
    ApprovalMailer.approval_request
  end

  # Preview this email at http://localhost:3000/rails/mailers/approval_mailer/approval_reminder
  def approval_reminder
    ApprovalMailer.approval_reminder
  end

  # Preview this email at http://localhost:3000/rails/mailers/approval_mailer/workflow_approved
  def workflow_approved
    ApprovalMailer.workflow_approved
  end

  # Preview this email at http://localhost:3000/rails/mailers/approval_mailer/workflow_rejected
  def workflow_rejected
    ApprovalMailer.workflow_rejected
  end

  # Preview this email at http://localhost:3000/rails/mailers/approval_mailer/workflow_escalated
  def workflow_escalated
    ApprovalMailer.workflow_escalated
  end

  # Preview this email at http://localhost:3000/rails/mailers/approval_mailer/approval_delegated
  def approval_delegated
    ApprovalMailer.approval_delegated
  end

  # Preview this email at http://localhost:3000/rails/mailers/approval_mailer/deadline_warning
  def deadline_warning
    ApprovalMailer.deadline_warning
  end
end
