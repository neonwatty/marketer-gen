require 'test_helper'

class ContentWorkflowTest < ActiveSupport::TestCase
  def setup
    @campaign = campaigns(:summer_launch)
    @workflow = ContentWorkflow.create!(
      content_item: @campaign,
      current_stage: 'draft',
      template_name: 'standard_content_approval',
      template_version: '1.0'
    )
  end

  test 'should create valid workflow' do
    assert @workflow.valid?
    assert @workflow.persisted?
    assert_equal 'draft', @workflow.current_stage
    assert_equal 'standard_content_approval', @workflow.template_name
    assert_equal 'active', @workflow.status
  end

  test 'should require current_stage' do
    workflow = ContentWorkflow.new(content_item: @campaign)
    workflow.current_stage = nil
    
    refute workflow.valid?
    assert workflow.errors[:current_stage].any?
  end

  test 'should require template_name' do
    workflow = ContentWorkflow.new(content_item: @campaign)
    workflow.template_name = nil
    
    refute workflow.valid?
    assert workflow.errors[:template_name].any?
  end

  test 'should validate template_version format' do
    @workflow.template_version = 'invalid'
    
    refute @workflow.valid?
    assert @workflow.errors[:template_version].any?
    
    @workflow.template_version = '1.0.0'
    assert @workflow.valid?
  end

  test 'should validate current_stage inclusion' do
    @workflow.current_stage = 'invalid_stage'
    
    refute @workflow.valid?
    assert @workflow.errors[:current_stage].any?
  end

  test 'should initialize with default values' do
    workflow = ContentWorkflow.new
    
    assert_equal({}, workflow.metadata)
    assert_equal({}, workflow.settings)
  end

  test 'should create initial audit entry after creation' do
    new_workflow = ContentWorkflow.create!(
      content_item: @campaign,
      current_stage: 'draft',
      template_name: 'test_template',
      template_version: '1.0'
    )
    
    assert_equal 1, new_workflow.audit_entries.count
    
    audit_entry = new_workflow.audit_entries.first
    assert_equal 'create_workflow', audit_entry.action
    assert_equal 'draft', audit_entry.to_stage
  end

  test 'should check if workflow can transition to target stage' do
    # Mock the workflow engine validation
    @restore_validate_transition = stub_method(WorkflowEngine, :validate_transition, { valid: true })
    
    assert @workflow.can_transition_to?(:review, :submit_for_review)
    
    @restore_validate_transition.call if @restore_validate_transition
  end

  test 'should get current stage configuration' do
    stage_config = @workflow.current_stage_config
    
    assert_equal 'Draft', stage_config[:name]
    assert_equal 1, stage_config[:order]
    assert_includes stage_config[:allowed_actions], 'edit'
  end

  test 'should identify if workflow is in final stage' do
    refute @workflow.is_in_final_stage?
    
    @workflow.update!(current_stage: 'published')
    assert @workflow.is_in_final_stage?
    
    @workflow.update!(current_stage: 'archived')
    assert @workflow.is_in_final_stage?
  end

  test 'should identify if workflow is awaiting action' do
    refute @workflow.is_awaiting_action? # draft stage doesn't await action
    
    @workflow.update!(current_stage: 'review')
    assert @workflow.is_awaiting_action?
    
    @workflow.update!(current_stage: 'approved')
    assert @workflow.is_awaiting_action?
  end

  test 'should calculate time in current stage' do
    travel_to 2.hours.ago do
      @workflow.update!(current_stage: 'review')
      
      # Create audit entry for stage transition
      @workflow.audit_entries.create!(
        action: 'submit_for_review',
        from_stage: 'draft',
        to_stage: 'review',
        performed_by_id: 1
      )
    end
    
    time_in_stage = @workflow.time_in_current_stage
    assert_in_delta 2.hours, time_in_stage, 1.minute
  end

  test 'should calculate total workflow time for completed workflow' do
    travel_to 3.days.ago do
      @workflow.audit_entries.create!(
        action: 'start_workflow',
        to_stage: 'draft',
        performed_by_id: 1
      )
    end
    
    travel_to 1.day.ago do
      @workflow.update!(current_stage: 'published')
      @workflow.audit_entries.create!(
        action: 'publish',
        from_stage: 'approved',
        to_stage: 'published',
        performed_by_id: 1
      )
    end
    
    total_time = @workflow.total_workflow_time
    assert_in_delta 2.days, total_time, 1.hour
  end

  test 'should assign user to workflow stage' do
    user_id = 123
    assignment = @workflow.assign_to_user(user_id, role: 'creator')
    
    assert assignment.persisted?
    assert_equal user_id, assignment.user_id
    assert_equal 'creator', assignment.role
    assert_equal 'draft', assignment.stage
    assert assignment.assignment_status_active?
  end

  test 'should unassign user from workflow' do
    user_id = 123
    @workflow.assign_to_user(user_id, role: 'creator')
    
    @workflow.unassign_user(user_id)
    
    assignment = @workflow.assignments.where(user_id: user_id).first
    assert assignment.assignment_status_inactive?
    assert assignment.unassigned_at
  end

  test 'should get assigned users for stage' do
    user_id_1 = 123
    user_id_2 = 456
    
    @workflow.assign_to_user(user_id_1, role: 'creator', stage: 'draft')
    @workflow.assign_to_user(user_id_2, role: 'reviewer', stage: 'review')
    
    draft_assignees = @workflow.assigned_users(stage: 'draft')
    review_assignees = @workflow.assigned_users(stage: 'review')
    
    assert_includes draft_assignees, user_id_1
    refute_includes draft_assignees, user_id_2
    assert_includes review_assignees, user_id_2
    refute_includes review_assignees, user_id_1
  end

  test 'should get current assignees' do
    user_id = 123
    @workflow.assign_to_user(user_id, role: 'creator')
    
    current_assignees = @workflow.current_assignees
    assert_includes current_assignees, user_id
  end

  test 'should generate transition history' do
    # Create some audit entries
    @workflow.audit_entries.create!(
      action: 'submit_for_review',
      from_stage: 'draft',
      to_stage: 'review',
      performed_by_id: 1,
      comment: 'Ready for review',
      created_at: 1.hour.ago
    )
    
    @workflow.audit_entries.create!(
      action: 'approve',
      from_stage: 'review',
      to_stage: 'approved',
      performed_by_id: 2,
      comment: 'Approved',
      created_at: 30.minutes.ago
    )
    
    history = @workflow.transition_history
    
    assert_equal 3, history.length # including initial create_workflow entry
    
    submit_entry = history.find { |h| h[:action] == 'submit_for_review' }
    assert_equal 'draft', submit_entry[:from_stage]
    assert_equal 'review', submit_entry[:to_stage]
    assert_equal 'User 1', submit_entry[:performer]
  end

  test 'should calculate stage durations' do
    # Create audit entries with specific timestamps
    travel_to 3.hours.ago do
      @workflow.audit_entries.create!(
        action: 'submit_for_review',
        from_stage: 'draft',
        to_stage: 'review',
        performed_by_id: 1
      )
    end
    
    travel_to 1.hour.ago do
      @workflow.audit_entries.create!(
        action: 'approve',
        from_stage: 'review',
        to_stage: 'approved',
        performed_by_id: 1
      )
    end
    
    @workflow.update!(current_stage: 'approved')
    durations = @workflow.stage_durations
    
    assert durations.key?('draft')
    assert_in_delta 2.hours, durations['review'], 5.minutes
  end

  test 'should generate workflow performance metrics' do
    # Setup workflow with some history
    create_workflow_history
    
    metrics = @workflow.workflow_performance_metrics
    
    assert metrics.key?(:total_duration)
    assert metrics.key?(:stage_durations)
    assert metrics.key?(:transition_count)
    assert metrics.key?(:average_stage_time)
  end

  test 'should detect overdue workflow' do
    refute @workflow.is_overdue?(1) # Just created, not overdue
    
    # Simulate old workflow
    @workflow.audit_entries.first.update!(created_at: 3.days.ago)
    
    assert @workflow.is_overdue?(48) # 48 hours SLA
  end

  test 'should validate workflow integrity' do
    errors = @workflow.validate_workflow_integrity
    assert_empty errors # New workflow should be valid
    
    # Test with invalid stage
    @workflow.update_column(:current_stage, 'invalid_stage')
    errors = @workflow.validate_workflow_integrity
    assert errors.any?
    assert errors.first.include?('Invalid current stage')
  end

  test 'should perform health check' do
    health = @workflow.health_check
    
    assert health.key?(:healthy)
    assert health.key?(:errors)
    assert health.key?(:warnings)
    assert health.key?(:recommendations)
  end

  test 'should pause workflow' do
    @workflow.pause!('Testing pause functionality')
    
    assert @workflow.paused?
    assert_equal 'Testing pause functionality', @workflow.metadata['pause_reason']
    assert @workflow.metadata['paused_at']
  end

  test 'should resume paused workflow' do
    @workflow.pause!('Test pause')
    @workflow.resume!
    
    assert @workflow.active?
    assert @workflow.metadata['resumed_at']
  end

  test 'should cancel workflow' do
    user_id = 123
    @workflow.assign_to_user(user_id, role: 'creator')
    
    @workflow.cancel!('Project cancelled')
    
    assert @workflow.cancelled?
    assert_equal 'Project cancelled', @workflow.metadata['cancellation_reason']
    
    # Should inactivate all assignments
    assignment = @workflow.assignments.where(user_id: user_id).first
    assert assignment.inactive?
  end

  test 'should clone workflow' do
    @workflow.assign_to_user(123, role: 'creator')
    @workflow.update!(priority: :high, settings: { custom: 'value' })
    
    new_campaign = campaigns(:holiday_campaign)
    cloned_workflow = @workflow.clone_workflow(new_campaign)
    
    assert cloned_workflow.persisted?
    assert_equal new_campaign, cloned_workflow.content_item
    assert_equal 'draft', cloned_workflow.current_stage
    assert_equal @workflow.template_name, cloned_workflow.template_name
    assert_equal 'high', cloned_workflow.priority
    assert_equal 'value', cloned_workflow.settings['custom']
    assert_equal @workflow.id, cloned_workflow.metadata['cloned_from']
    
    # Should clone draft stage assignments
    assert_equal 1, cloned_workflow.assignments.count
    cloned_assignment = cloned_workflow.assignments.first
    assert_equal 123, cloned_assignment.user_id
    assert_equal 'creator', cloned_assignment.role
  end

  test 'should generate workflow summary' do
    summary = @workflow.to_workflow_summary
    
    assert_equal @workflow.id, summary[:id]
    assert_equal 'Campaign', summary[:content_item][:type]
    assert_equal @workflow.content_item_id, summary[:content_item][:id]
    assert_equal 'draft', summary[:current_stage]
    assert_equal 'active', summary[:status]
    assert summary[:timing].key?(:created_at)
    assert summary[:participants].key?(:current_assignees)
    assert summary[:health].key?(:healthy)
  end

  test 'should generate comprehensive workflow report' do
    create_workflow_history
    
    report = @workflow.generate_workflow_report
    
    assert report.key?(:workflow_summary)
    assert report.key?(:transition_history)
    assert report.key?(:performance_metrics)
    assert report.key?(:stage_analysis)
    assert report.key?(:recommendations)
    
    assert report[:workflow_summary][:id] == @workflow.id
    assert report[:transition_history].is_a?(Array)
    assert report[:performance_metrics].key?(:total_duration)
  end

  private

  def create_workflow_history
    # Create realistic workflow history for testing
    travel_to 2.days.ago do
      @workflow.audit_entries.create!(
        action: 'submit_for_review',
        from_stage: 'draft',
        to_stage: 'review',
        performed_by_id: 1,
        comment: 'Initial submission'
      )
    end
    
    travel_to 1.day.ago do
      @workflow.audit_entries.create!(
        action: 'approve',
        from_stage: 'review',
        to_stage: 'approved',
        performed_by_id: 2,
        comment: 'Content looks good'
      )
    end
    
    travel_to 2.hours.ago do
      @workflow.audit_entries.create!(
        action: 'publish',
        from_stage: 'approved',
        to_stage: 'published',
        performed_by_id: 3,
        comment: 'Published successfully'
      )
    end
    
    @workflow.update!(current_stage: 'published', status: :completed)
  end
end