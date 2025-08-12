require 'test_helper'

class WorkflowEngineTest < ActiveSupport::TestCase
  def setup
    # Create a mock content item (Campaign)
    @campaign = campaigns(:summer_launch) # Uses fixture
    @user = mock_user(id: 1, name: 'Test User')
    @workflow_engine = WorkflowEngine.new(@campaign, @user)
  end

  test 'should initialize with content item and user' do
    assert_equal @campaign, @workflow_engine.content_item
    assert_equal @user, @workflow_engine.current_user
  end

  test 'should start workflow with default template' do
    workflow = @workflow_engine.start_workflow

    assert workflow.persisted?
    assert_equal 'draft', workflow.current_stage
    assert_equal 'standard_content_approval', workflow.template_name
    assert_equal '1.0', workflow.template_version
    assert workflow.audit_entries.any?
  end

  test 'should start workflow with custom metadata' do
    metadata = { priority: 'high', department: 'marketing' }
    workflow = @workflow_engine.start_workflow(metadata: metadata)

    assert_equal 'high', workflow.metadata['priority']
    assert_equal 'marketing', workflow.metadata['department']
  end

  test 'should transition between valid stages' do
    workflow = @workflow_engine.start_workflow

    # Transition from draft to review
    result_workflow = @workflow_engine.transition_to(workflow, :review, :submit_for_review)

    assert_equal 'review', result_workflow.current_stage
    assert_equal 'draft', result_workflow.previous_stage
    assert_equal 2, workflow.audit_entries.count # initial + transition
  end

  test 'should reject invalid transitions' do
    workflow = @workflow_engine.start_workflow

    # Try to transition directly to published (not allowed from draft)
    assert_raises(WorkflowTransitionError) do
      @workflow_engine.transition_to(workflow, :published, :publish)
    end
  end

  test 'should check user permissions for actions' do
    # Mock user as creator
    allow_user_role(@user, :creator)

    assert @workflow_engine.can_perform_action?(:edit, :draft)
    assert @workflow_engine.can_perform_action?(:submit_for_review, :draft)
    refute @workflow_engine.can_perform_action?(:approve, :review)
  end

  test 'should get available actions for current stage' do
    workflow = @workflow_engine.start_workflow
    allow_user_role(@user, :creator)

    available_actions = @workflow_engine.get_available_actions(workflow)

    assert_includes available_actions, 'edit'
    assert_includes available_actions, 'submit_for_review'
    assert_includes available_actions, 'delete'
  end

  test 'should get possible transitions' do
    workflow = @workflow_engine.start_workflow
    allow_user_role(@user, :creator)

    transitions = @workflow_engine.get_possible_transitions(workflow)

    submit_transition = transitions.find { |t| t[:action] == 'submit_for_review' }
    assert submit_transition
    assert_equal :draft, submit_transition[:from_stage]
    assert_equal :review, submit_transition[:to_stage]
  end

  test 'should submit content for review' do
    workflow = @workflow_engine.start_workflow
    allow_user_role(@user, :creator)

    updated_workflow = @workflow_engine.submit_for_review(workflow, comment: 'Ready for review')

    assert_equal 'review', updated_workflow.current_stage
    
    # Check audit entry
    audit_entry = workflow.audit_entries.last
    assert_equal 'submit_for_review', audit_entry.action
    assert_equal 'Ready for review', audit_entry.comment
  end

  test 'should approve content' do
    workflow = create_workflow_in_review_stage
    allow_user_role(@user, :reviewer)

    approved_workflow = @workflow_engine.approve_content(workflow, comment: 'Content approved')

    assert_equal 'approved', approved_workflow.current_stage
    
    audit_entry = workflow.audit_entries.last
    assert_equal 'approve', audit_entry.action
    assert_equal 'Content approved', audit_entry.comment
  end

  test 'should reject content with reason' do
    workflow = create_workflow_in_review_stage
    allow_user_role(@user, :reviewer)

    rejected_workflow = @workflow_engine.reject_content(
      workflow, 
      reason: 'Quality issues', 
      comment: 'Please fix formatting'
    )

    assert_equal 'draft', rejected_workflow.current_stage
    assert_equal 'Quality issues', rejected_workflow.metadata['rejection_reason']
  end

  test 'should publish content' do
    workflow = create_workflow_in_approved_stage
    allow_user_role(@user, :publisher)

    published_workflow = @workflow_engine.publish_content(workflow)

    assert_equal 'published', published_workflow.current_stage
    assert published_workflow.metadata['published_at']
  end

  test 'should schedule content for publication' do
    workflow = create_workflow_in_approved_stage
    allow_user_role(@user, :publisher)
    
    scheduled_time = 2.hours.from_now
    scheduled_workflow = @workflow_engine.schedule_content(
      workflow, 
      scheduled_at: scheduled_time,
      publish_options: { platform: 'social_media' }
    )

    assert_equal 'scheduled', scheduled_workflow.current_stage
    assert_equal scheduled_time, scheduled_workflow.metadata['scheduled_at']
    assert_equal 'social_media', scheduled_workflow.metadata['publish_options']['platform']
  end

  test 'should provide workflow status summary' do
    workflow = @workflow_engine.start_workflow
    allow_user_role(@user, :creator)

    status = @workflow_engine.workflow_status(workflow)

    assert_equal 'active', status[:status]
    assert_equal 'draft', status[:current_stage]
    assert status[:available_actions].any?
    assert status[:possible_transitions].any?
  end

  test 'should generate workflow history' do
    workflow = @workflow_engine.start_workflow
    allow_user_role(@user, :creator)
    
    @workflow_engine.submit_for_review(workflow, comment: 'First submission')

    history = @workflow_engine.workflow_history(workflow)

    assert_equal 2, history.length
    assert_equal 'start_workflow', history.first[:action]
    assert_equal 'submit_for_review', history.last[:action]
  end

  test 'should calculate workflow metrics' do
    # Create some historical workflows
    create_completed_workflows

    metrics = @workflow_engine.workflow_metrics(start_date: 1.week.ago)

    assert metrics[:total_workflows] > 0
    assert metrics.key?(:completed_workflows)
    assert metrics.key?(:average_completion_time)
    assert metrics.key?(:stage_distribution)
  end

  test 'should handle workflow with admin user permissions' do
    admin_user = mock_user(id: 999, name: 'Admin User') # Admin user ID
    admin_engine = WorkflowEngine.new(@campaign, admin_user)
    workflow = admin_engine.start_workflow

    # Admin should be able to perform any action
    assert admin_engine.can_perform_action?(:approve, :review)
    assert admin_engine.can_perform_action?(:publish, :approved)
    assert admin_engine.can_perform_action?(:cancel_workflow, :draft)
  end

  test 'should enforce workflow permissions' do
    workflow = @workflow_engine.start_workflow
    
    # User without proper role should not be able to approve
    assert_raises(WorkflowPermissionError) do
      @workflow_engine.approve_content(workflow)
    end
  end

  test 'should log all workflow actions in audit trail' do
    workflow = @workflow_engine.start_workflow
    allow_user_role(@user, :creator)
    
    initial_count = workflow.audit_entries.count
    
    @workflow_engine.submit_for_review(workflow, comment: 'Test submission')
    
    assert_equal initial_count + 1, workflow.audit_entries.count
    
    audit_entry = workflow.audit_entries.last
    assert_equal 'submit_for_review', audit_entry.action
    assert_equal @user.id, audit_entry.performed_by_id
    assert_equal 'Test submission', audit_entry.comment
  end

  test 'should handle workflow notification triggers' do
    # Skip this test as it requires more complex mocking setup
    # In a real implementation, this would test notification service integration
    skip "Notification service integration test - requires full mocking setup"
  end

  private

  def mock_user(attributes = {})
    user = Object.new
    attributes.each do |key, value|
      user.define_singleton_method(key) { value }
    end
    user.define_singleton_method(:respond_to?) { |method| attributes.key?(method) }
    user
  end

  def allow_user_role(user, role)
    # Mock the user role checking in WorkflowEngine
    # This would integrate with your actual user role system
    @restore_get_user_roles = stub_method(WorkflowEngine, :get_user_roles, [role])
  end

  def create_workflow_in_review_stage
    workflow = @workflow_engine.start_workflow
    workflow.update!(current_stage: 'review', previous_stage: 'draft')
    
    # Add audit entry for the transition
    workflow.audit_entries.create!(
      action: 'submit_for_review',
      from_stage: 'draft',
      to_stage: 'review',
      performed_by_id: @user.id,
      comment: 'Submitted for review'
    )
    
    workflow
  end

  def create_workflow_in_approved_stage
    workflow = create_workflow_in_review_stage
    workflow.update!(current_stage: 'approved', previous_stage: 'review')
    
    workflow.audit_entries.create!(
      action: 'approve',
      from_stage: 'review',
      to_stage: 'approved',
      performed_by_id: @user.id,
      comment: 'Content approved'
    )
    
    workflow
  end

  def create_completed_workflows
    # Create some sample completed workflows for metrics testing
    3.times do |i|
      completed_workflow = ContentWorkflow.create!(
        content_item: @campaign,
        current_stage: 'published',
        template_name: 'standard_content_approval',
        template_version: '1.0',
        status: :completed,
        created_at: (i + 1).days.ago
      )
      
      # Add some audit entries to simulate workflow history
      completed_workflow.audit_entries.create!(
        action: 'start_workflow',
        to_stage: 'draft',
        performed_by_id: @user.id,
        created_at: (i + 1).days.ago
      )
      
      completed_workflow.audit_entries.create!(
        action: 'publish',
        from_stage: 'approved',
        to_stage: 'published',
        performed_by_id: @user.id,
        created_at: i.days.ago
      )
    end
  end
end