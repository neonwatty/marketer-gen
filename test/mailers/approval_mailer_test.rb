require "test_helper"

class ApprovalMailerTest < ActionMailer::TestCase
  def setup
    @user = users(:marketer_user)
    @approver = users(:admin_user) || users(:team_member_user)
    @campaign_plan = campaign_plans(:completed_plan)
    @content = create_valid_test_content(
      campaign_plan: @campaign_plan,
      content_type: 'email',
      format_variant: 'standard',
      title: 'Test Email Content for Approval',
      created_by: @user
    )
    @workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
  end
  test "approval_request" do
    mail = ApprovalMailer.approval_request(@workflow, @approver)
    assert_equal "Approval Required: #{@content.title}", mail.subject
    assert_equal [@approver.email_address], mail.to
    assert_equal ["approvals@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "approval_reminder" do
    hours_waiting = 24
    mail = ApprovalMailer.approval_reminder(@workflow, @approver, hours_waiting)
    assert_equal "Reminder: Approval Pending for #{@content.title}", mail.subject
    assert_equal [@approver.email_address], mail.to
    assert_equal ["approvals@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "workflow_approved" do
    mail = ApprovalMailer.workflow_approved(@workflow, @user)
    assert_equal "✅ Approved: #{@content.title}", mail.subject
    assert_equal [@user.email_address], mail.to
    assert_equal ["approvals@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "workflow_rejected" do
    mail = ApprovalMailer.workflow_rejected(@workflow, @user)
    assert_equal "❌ Rejected: #{@content.title}", mail.subject
    assert_equal [@user.email_address], mail.to
    assert_equal ["approvals@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "workflow_escalated" do
    mail = ApprovalMailer.workflow_escalated(@workflow, @approver)
    assert_equal "🚨 Escalated: #{@content.title} Requires Immediate Attention", mail.subject
    assert_equal [@approver.email_address], mail.to
    assert_equal ["approvals@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "approval_delegated" do
    @delegate = users(:team_member_user) || users(:marketer_user)
    mail = ApprovalMailer.approval_delegated(@workflow, @approver, @delegate)
    assert_equal "Approval Delegated: #{@content.title}", mail.subject
    assert_equal [@delegate.email_address], mail.to
    assert_equal ["approvals@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "deadline_warning" do
    time_remaining = 2.hours
    mail = ApprovalMailer.deadline_warning(@workflow, @approver, time_remaining)
    assert_equal "⏰ Urgent: #{@content.title} - Deadline in 2 hours", mail.subject
    assert_equal [@approver.email_address], mail.to
    assert_equal ["approvals@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
    assert_match "2", mail.body.encoded
  end
end
