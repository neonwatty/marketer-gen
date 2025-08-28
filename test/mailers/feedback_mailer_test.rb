require "test_helper"

class FeedbackMailerTest < ActionMailer::TestCase
  def setup
    @user = users(:marketer_user)
    @reviewer = users(:team_member_user)
    @campaign_plan = campaign_plans(:completed_plan)
    
    @content = create_valid_test_content(
      campaign_plan: @campaign_plan,
      content_type: 'blog_article',
      format_variant: 'standard',
      title: 'Test Content for Feedback',
      created_by: @user
    )
    
    @feedback = ContentFeedback.create!(
      generated_content: @content,
      reviewer_user: @reviewer,
      feedback_text: 'This is comprehensive test feedback that meets the minimum character requirements for testing purposes.',
      feedback_type: 'comment',
      priority: ContentFeedback::PRIORITIES[:medium],
      status: 'pending'
    )
  end

  test "new_feedback" do
    mail = FeedbackMailer.new_feedback(@feedback, @user)
    assert_equal "🟢 MEDIUM New Feedback: #{@content.title}", mail.subject
    assert_equal [@user.email_address], mail.to
    assert_equal ["feedback@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "feedback_acknowledged" do
    mail = FeedbackMailer.feedback_acknowledged(@feedback, @user)
    assert_equal "✓ Feedback Acknowledged: #{@content.title}", mail.subject
    assert_equal [@reviewer.email_address], mail.to
    assert_equal ["feedback@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "feedback_addressed" do
    response_note = "We've addressed your concerns"
    mail = FeedbackMailer.feedback_addressed(@feedback, @user, response_note)
    assert_equal "📝 Feedback Addressed: #{@content.title}", mail.subject
    assert_equal [@reviewer.email_address], mail.to
    assert_equal ["feedback@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "feedback_resolved" do
    @feedback.update!(resolved_by_user: @user, resolved_at: Time.current)
    mail = FeedbackMailer.feedback_resolved(@feedback, @user)
    assert_equal "✅ Feedback Resolved: #{@content.title}", mail.subject
    assert_equal [@user.email_address], mail.to
    assert_equal ["feedback@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "feedback_escalated" do
    @feedback.update!(
      priority: ContentFeedback::PRIORITIES[:critical],
      metadata: { escalation_reason: 'Requires immediate attention' }
    )
    mail = FeedbackMailer.feedback_escalated(@feedback, @user)
    assert_equal "🚨 🔴 CRITICAL Feedback Escalated: #{@content.title}", mail.subject
    assert_equal [@user.email_address], mail.to
    assert_equal ["feedback@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "workflow_feedback" do
    workflow = ApprovalWorkflow.create_workflow!(
      @content,
      'single_approver',
      [@user.id],
      { created_by: @user }
    )
    @feedback.update!(approval_workflow: workflow)
    
    mail = FeedbackMailer.workflow_feedback(@feedback, @user)
    assert_equal "📋 Workflow Feedback: #{@content.title}", mail.subject
    assert_equal [@user.email_address], mail.to
    assert_equal ["feedback@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "feedback_urgent_attention" do
    @feedback.update!(priority: ContentFeedback::PRIORITIES[:critical])
    mail = FeedbackMailer.feedback_urgent_attention(@feedback, @user, 3)
    assert_equal "⚠️ URGENT: Feedback Requires Attention - #{@content.title}", mail.subject
    assert_equal [@user.email_address], mail.to
    assert_equal ["feedback@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end

  test "feedback_summary" do
    feedbacks = [@feedback]
    mail = FeedbackMailer.feedback_summary(@content, @user, feedbacks)
    assert_equal "📊 Feedback Summary: #{@content.title}", mail.subject
    assert_equal [@user.email_address], mail.to
    assert_equal ["feedback@marketergen.com"], mail.from
    assert_match @content.title, mail.body.encoded
  end
end
