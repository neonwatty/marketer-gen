# Preview all emails at http://localhost:3000/rails/mailers/feedback_mailer
class FeedbackMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/feedback_mailer/new_feedback
  def new_feedback
    feedback = sample_feedback
    recipient = sample_user
    FeedbackMailer.new_feedback(feedback, recipient)
  end

  # Preview this email at http://localhost:3000/rails/mailers/feedback_mailer/feedback_acknowledged
  def feedback_acknowledged
    feedback = sample_feedback
    acknowledged_by = sample_user
    FeedbackMailer.feedback_acknowledged(feedback, acknowledged_by)
  end

  # Preview this email at http://localhost:3000/rails/mailers/feedback_mailer/feedback_addressed
  def feedback_addressed
    feedback = sample_feedback
    addressed_by = sample_user
    response_note = "Thank you for your feedback. We've updated the content accordingly."
    FeedbackMailer.feedback_addressed(feedback, addressed_by, response_note)
  end

  # Preview this email at http://localhost:3000/rails/mailers/feedback_mailer/feedback_resolved
  def feedback_resolved
    feedback = sample_feedback
    recipient = sample_user
    FeedbackMailer.feedback_resolved(feedback, recipient)
  end

  # Preview this email at http://localhost:3000/rails/mailers/feedback_mailer/feedback_escalated
  def feedback_escalated
    feedback = sample_feedback
    recipient = sample_user
    FeedbackMailer.feedback_escalated(feedback, recipient)
  end

  # Preview this email at http://localhost:3000/rails/mailers/feedback_mailer/workflow_feedback
  def workflow_feedback
    workflow = sample_workflow
    feedback = sample_feedback
    recipient = sample_user
    FeedbackMailer.workflow_feedback(workflow, feedback, recipient)
  end

  # Preview this email at http://localhost:3000/rails/mailers/feedback_mailer/feedback_urgent_attention
  def feedback_urgent_attention
    feedback = sample_feedback
    recipient = sample_user
    days_overdue = 3
    FeedbackMailer.feedback_urgent_attention(feedback, recipient, days_overdue)
  end

  # Preview this email at http://localhost:3000/rails/mailers/feedback_mailer/feedback_summary
  def feedback_summary
    content = sample_content
    recipient = sample_user
    feedbacks = ContentFeedback.limit(5)
    FeedbackMailer.feedback_summary(content, recipient, feedbacks)
  end

  private

  def sample_user
    User.first || User.create!(
      email: 'sample@example.com',
      first_name: 'Sample',
      last_name: 'User'
    )
  end

  def sample_content
    GeneratedContent.first || GeneratedContent.create!(
      title: 'Sample Marketing Content',
      body_content: 'This is sample marketing content for testing purposes.',
      content_type: 'blog_post',
      platform: 'blog',
      version: '1.0.0',
      status: 'draft',
      user: sample_user
    )
  end

  def sample_workflow
    content = sample_content
    content.approval_workflow || ApprovalWorkflow.create_workflow!(
      content,
      'single_approver',
      ['approver@example.com'],
      { created_by: sample_user }
    )
  end

  def sample_feedback
    ContentFeedback.first || ContentFeedback.create!(
      generated_content: sample_content,
      reviewer_user: sample_user,
      feedback_text: 'This content needs some minor adjustments to the tone.',
      feedback_type: 'content_quality',
      priority: ContentFeedback::PRIORITIES[:medium],
      status: 'pending'
    )
  end
end
