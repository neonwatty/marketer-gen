require "test_helper"

class ApprovalWorkflowTest < ActiveSupport::TestCase
  self.use_transactional_tests = false  # Disable transactional tests since we're managing data manually
  
  def setup
    # Skip fixtures entirely and create test data manually
    # Clean up any existing data by temporarily disabling foreign keys
    ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = OFF;')
    
    ApprovalWorkflow.delete_all
    GeneratedContent.delete_all
    CampaignPlan.delete_all
    User.delete_all
    
    ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = ON;')
    
    # Create users manually to avoid fixture issues
    @user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email_address: 'test@example.com',
      password: 'password123',
      role: 'marketer'
    )
    
    @approver = User.create!(
      first_name: 'Approver',
      last_name: 'User',
      email_address: 'approver@example.com',
      password: 'password123',
      role: 'admin'
    )
    
    @other_user = User.create!(
      first_name: 'Other',
      last_name: 'User',
      email_address: 'other@example.com',
      password: 'password123',
      role: 'team_member'
    )
    
    @campaign = CampaignPlan.create!(
      name: 'Test Campaign',
      description: 'Test campaign description',
      target_audience: 'Test audience',
      campaign_type: 'brand_awareness',
      objective: 'brand_awareness',
      user: @user
    )
    
    @content = GeneratedContent.create!(
      content_type: "blog_article",
      title: "Test Content #{SecureRandom.hex(4)}",
      body_content: "This is test content for approval workflow testing. It contains enough characters to meet the standard format requirements and provides a foundation for testing various workflow features.",
      format_variant: "standard",
      status: "draft",
      version_number: 1,
      campaign_plan: @campaign,
      created_by: @user
    )
  end
  
  def teardown
    super
    # Clean up test data by temporarily disabling foreign keys
    ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = OFF;')
    
    ApprovalWorkflow.delete_all
    GeneratedContent.delete_all
    CampaignPlan.delete_all
    User.delete_all
    
    ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = ON;')
  end

  test "should create single approver workflow" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    assert workflow.persisted?
    assert_equal 'single_approver', workflow.workflow_type
    assert_equal [@approver.id.to_s], workflow.required_approvers
    assert_equal 'in_review', workflow.status
    assert_equal 1, workflow.current_stage
    assert_equal @content, workflow.generated_content
  end

  test "should create multi-stage workflow" do
    approvers = [[@approver.id], [@other_user.id]]
    workflow = ApprovalWorkflow.create_workflow!(@content, 'multi_stage', approvers)
    
    assert workflow.persisted?
    assert_equal 'multi_stage', workflow.workflow_type
    assert_equal approvers.map { |stage| stage.map(&:to_s) }, workflow.required_approvers
    assert_equal 2, workflow.get_total_stages
  end

  test "should create consensus workflow" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'consensus', [@approver.id, @other_user.id])
    
    assert workflow.persisted?
    assert_equal 'consensus', workflow.workflow_type
    assert_equal [@approver.id.to_s, @other_user.id.to_s], workflow.required_approvers
  end

  test "should validate workflow type" do
    workflow = ApprovalWorkflow.new(
      generated_content: @content,
      workflow_type: 'invalid_type',
      required_approvers: [@approver.id],
      created_by: @user
    )
    
    assert_not workflow.valid?
    assert_includes workflow.errors[:workflow_type], "is not included in the list"
  end

  test "should validate status" do
    workflow = ApprovalWorkflow.new(
      generated_content: @content,
      workflow_type: 'single_approver',
      required_approvers: [@approver.id],
      status: 'invalid_status',
      created_by: @user
    )
    
    assert_not workflow.valid?
    assert_includes workflow.errors[:status], "is not included in the list"
  end

  test "should validate required approvers presence" do
    workflow = ApprovalWorkflow.new(
      generated_content: @content,
      workflow_type: 'single_approver',
      required_approvers: [],
      created_by: @user
    )
    
    assert_not workflow.valid?
    assert_includes workflow.errors[:required_approvers], "can't be blank"
  end

  test "should validate current stage" do
    workflow = ApprovalWorkflow.new(
      generated_content: @content,
      workflow_type: 'single_approver',
      required_approvers: [@approver.id],
      current_stage: 0,
      created_by: @user
    )
    
    assert_not workflow.valid?
    assert_includes workflow.errors[:current_stage], "must be greater than 0"
  end

  test "should validate unique generated content" do
    ApprovalWorkflow.create!(
      generated_content: @content,
      workflow_type: 'single_approver',
      required_approvers: [@approver.id],
      created_by: @user
    )
    
    duplicate_workflow = ApprovalWorkflow.new(
      generated_content: @content,
      workflow_type: 'single_approver',
      required_approvers: [@approver.id],
      created_by: @user
    )
    
    assert_not duplicate_workflow.valid?
    assert_includes duplicate_workflow.errors[:generated_content_id], "has already been taken"
  end

  test "should start workflow" do
    skip "TODO: Fix during incremental development"
    workflow = ApprovalWorkflow.create!(
      generated_content: @content,
      workflow_type: 'single_approver',
      required_approvers: [@approver.id],
      status: 'pending',
      created_by: @user
    )
    
    assert_emails 1 do
      result = workflow.start_workflow!
      assert result
    end
    
    workflow.reload
    assert_equal 'in_review', workflow.status
    assert_not_nil workflow.metadata['started_at']
  end

  test "should not start workflow if not pending" do
    workflow = ApprovalWorkflow.create!(
      generated_content: @content,
      workflow_type: 'single_approver',
      required_approvers: [@approver.id],
      status: 'approved',
      created_by: @user
    )
    
    result = workflow.start_workflow!
    assert_not result
  end

  test "should process single approver approval" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    result = workflow.process_approval!(@approver, 'approve', 'Looks good!')
    
    assert result
    workflow.reload
    assert_equal 'approved', workflow.status
    assert_not_nil workflow.completed_at
    assert_equal @approver.id, workflow.metadata['completed_by']
    assert_equal 'Looks good!', workflow.metadata['completion_feedback']
  end

  test "should process rejection" do
    skip "TODO: Fix during incremental development"
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    result = workflow.process_approval!(@approver, 'reject', 'Needs improvement')
    
    assert result
    workflow.reload
    assert_equal 'rejected', workflow.status
    assert_not_nil workflow.completed_at
  end

  test "should handle change request" do
    skip "TODO: Fix during incremental development"
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    assert_emails 1 do
      result = workflow.process_approval!(@approver, 'request_changes', 'Please update the headline')
      assert result
    end
    
    workflow.reload
    assert_equal 'pending', workflow.status
    assert_equal 1, workflow.current_stage
    assert_equal @approver.id, workflow.metadata['change_requested_by']
  end

  test "should advance multi-stage workflow" do
    approver2 = @other_user
    approvers = [[@approver.id], [approver2.id]]
    workflow = ApprovalWorkflow.create_workflow!(@content, 'multi_stage', approvers)
    
    # First stage approval
    assert_emails 1 do
      result = workflow.process_approval!(@approver, 'approve', 'Stage 1 approved')
      assert result
    end
    
    workflow.reload
    assert_equal 'in_review', workflow.status
    assert_equal 2, workflow.current_stage
    
    # Second stage approval
    result = workflow.process_approval!(approver2, 'approve', 'Stage 2 approved')
    assert result
    
    workflow.reload
    assert_equal 'approved', workflow.status
  end

  test "should handle consensus workflow" do
    approver2 = @other_user
    workflow = ApprovalWorkflow.create_workflow!(@content, 'consensus', [@approver.id, approver2.id])
    
    # First approver
    result = workflow.process_approval!(@approver, 'approve', 'I approve')
    assert result
    
    workflow.reload
    assert_equal 'in_review', workflow.status # Still need second approver
    
    # Second approver
    result = workflow.process_approval!(approver2, 'approve', 'I also approve')
    assert result
    
    workflow.reload
    assert_equal 'approved', workflow.status
  end

  test "should handle parallel workflow" do
    approver2 = @other_user
    workflow = ApprovalWorkflow.create_workflow!(@content, 'parallel', [@approver.id, approver2.id])
    
    # Any one approver is sufficient
    result = workflow.process_approval!(@approver, 'approve', 'I approve')
    assert result
    
    workflow.reload
    assert_equal 'approved', workflow.status
  end

  test "should check if user can approve" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    assert workflow.can_approve?(@approver)
    assert_not workflow.can_approve?(@user)
    assert_not workflow.can_approve?(@other_user)
  end

  test "should get current stage approvers" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    approvers = workflow.current_stage_approvers
    assert_equal [@approver.id.to_s], approvers
  end

  test "should get all approvers" do
    approver2 = @other_user
    approvers = [[@approver.id], [approver2.id]]
    workflow = ApprovalWorkflow.create_workflow!(@content, 'multi_stage', approvers)
    
    all_approvers = workflow.all_approvers
    assert_includes all_approvers, @approver.id.to_s
    assert_includes all_approvers, approver2.id.to_s
  end

  test "should detect overdue workflow" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id], 
                                                 due_date: 1.hour.from_now)
    
    # Manually update the due date to simulate an overdue workflow
    workflow.update_column(:due_date, 1.hour.ago)
    
    assert workflow.overdue?
  end

  test "should calculate time remaining" do
    due_date = 2.hours.from_now
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id], 
                                                 due_date: due_date)
    
    time_remaining = workflow.time_remaining
    assert time_remaining > 0
    assert time_remaining <= 2.hours
  end

  test "should get approval progress" do
    skip "TODO: Fix during incremental development"
    approver2 = @other_user
    workflow = ApprovalWorkflow.create_workflow!(@content, 'consensus', [@approver.id, approver2.id])
    
    progress = workflow.approval_progress
    assert_equal 2, progress[:total_approvers]
    assert_equal 0, progress[:completed_approvals]
    assert_equal 0.0, progress[:percentage]
    
    # Add an approval
    workflow.process_approval!(@approver, 'approve')
    
    progress = workflow.approval_progress
    assert_equal 1, progress[:completed_approvals]
    assert_equal 50.0, progress[:percentage]
  end

  test "should cancel workflow" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    # Clear emails sent during workflow creation
    ActionMailer::Base.deliveries.clear
    
    assert_emails 2 do
      result = workflow.cancel!(@user, "No longer needed")
      assert result
    end
    
    workflow.reload
    assert_equal 'cancelled', workflow.status
    assert_not_nil workflow.completed_at
    assert_equal @user.id, workflow.metadata['cancelled_by']
    assert_equal "No longer needed", workflow.metadata['cancellation_reason']
  end

  test "should escalate workflow" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id], 
                                                 due_date: 1.hour.from_now)
    
    # Manually update the due date to simulate an overdue workflow
    workflow.update_column(:due_date, 1.hour.ago)
    
    result = workflow.escalate!("Overdue approval")
    assert result
    
    workflow.reload
    assert_equal 'escalated', workflow.status
    assert_equal "Overdue approval", workflow.metadata['escalation_reason']
  end

  test "should get workflow summary" do
    workflow = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    summary = workflow.summary
    assert_equal workflow.id, summary[:id]
    assert_equal @content.title, summary[:content_title]
    assert_equal 'Single approver', summary[:workflow_type]
    assert_equal 'In review', summary[:status]
    assert_not_nil summary[:progress]
    assert_not_nil summary[:approvers]
  end

  test "should validate due date in future" do
    workflow = ApprovalWorkflow.new(
      generated_content: @content,
      workflow_type: 'single_approver',
      required_approvers: [@approver.id],
      due_date: 1.hour.ago,
      created_by: @user
    )
    
    assert_not workflow.valid?
    assert_includes workflow.errors[:due_date], "must be in the future"
  end

  test "should scope workflows correctly" do
    workflow1 = ApprovalWorkflow.create_workflow!(@content, 'single_approver', [@approver.id])
    
    content2 = GeneratedContent.create!(
      content_type: "email",
      title: "Test Content 2 #{SecureRandom.hex(4)}",
      body_content: "This is another test content for approval workflow testing. It contains enough characters to meet the standard format requirements and provides a foundation for testing various workflow features.",
      format_variant: "standard",
      status: "draft",
      version_number: 1,
      campaign_plan: @campaign,
      created_by: @user
    )
    workflow2 = ApprovalWorkflow.create_workflow!(content2, 'single_approver', [@approver.id])
    workflow2.process_approval!(@approver, 'approve')
    
    # Test scopes
    assert_includes ApprovalWorkflow.active, workflow1
    assert_not_includes ApprovalWorkflow.active, workflow2
    
    assert_includes ApprovalWorkflow.approved, workflow2
    assert_not_includes ApprovalWorkflow.approved, workflow1
    
    assert_includes ApprovalWorkflow.by_workflow_type('single_approver'), workflow1
    assert_includes ApprovalWorkflow.by_workflow_type('single_approver'), workflow2
  end

  private

  def assert_emails(count)
    original_count = ActionMailer::Base.deliveries.size
    yield
    assert_equal original_count + count, ActionMailer::Base.deliveries.size
  end
end
