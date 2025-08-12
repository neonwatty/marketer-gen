require 'test_helper'

class WorkflowPermissionServiceTest < ActiveSupport::TestCase
  def setup
    @campaign = campaigns(:summer_launch)
    @workflow = ContentWorkflow.create!(
      content_item: @campaign,
      current_stage: 'draft',
      template_name: 'standard_content_approval',
      template_version: '1.0'
    )
    
    @creator_user = mock_user(id: 1, name: 'Creator User')
    @reviewer_user = mock_user(id: 6, name: 'Reviewer User')
    @approver_user = mock_user(id: 9, name: 'Approver User')
    @admin_user = mock_user(id: 999, name: 'Admin User')
    
    @permission_service = WorkflowPermissionService.new(@creator_user, @workflow)
  end

  test 'should initialize with user and workflow' do
    assert_equal @creator_user, @permission_service.user
    assert_equal @workflow, @permission_service.workflow
  end

  test 'should allow admin users to perform any action' do
    admin_service = WorkflowPermissionService.new(@admin_user, @workflow)
    
    assert admin_service.can_perform_action?('view')
    assert admin_service.can_perform_action?('edit')
    assert admin_service.can_perform_action?('approve')
    assert admin_service.can_perform_action?('publish')
    assert admin_service.can_perform_action?('assign_user')
    assert admin_service.can_perform_action?('cancel_workflow')
  end

  test 'should check basic view permissions' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    assert @permission_service.can_view_workflow?
  end

  test 'should check edit permissions based on stage and role' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    assert @permission_service.can_edit_content?
    
    # Move to review stage - creator should not be able to edit
    @workflow.update!(current_stage: 'review')
    refute @permission_service.can_edit_content?
  end

  test 'should check submit for review permissions' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    assert @permission_service.can_submit_for_review?
    
    # Move to review stage - should not be able to submit again
    @workflow.update!(current_stage: 'review')
    refute @permission_service.can_submit_for_review?
  end

  test 'should check approval permissions' do
    assign_user_to_workflow(@reviewer_user.id, 'reviewer', 'review')
    reviewer_service = WorkflowPermissionService.new(@reviewer_user, @workflow)
    
    @workflow.update!(current_stage: 'review')
    assert reviewer_service.can_approve_content?
    
    # Creator should not be able to approve
    refute @permission_service.can_approve_content?
  end

  test 'should check rejection permissions' do
    assign_user_to_workflow(@reviewer_user.id, 'reviewer', 'review')
    reviewer_service = WorkflowPermissionService.new(@reviewer_user, @workflow)
    
    @workflow.update!(current_stage: 'review')
    assert reviewer_service.can_reject_content?
    
    # Should also work in approved stage
    @workflow.update!(current_stage: 'approved')
    assert reviewer_service.can_reject_content?
  end

  test 'should check publishing permissions' do
    assign_user_to_workflow(@approver_user.id, 'publisher', 'approved')
    publisher_service = WorkflowPermissionService.new(@approver_user, @workflow)
    
    @workflow.update!(current_stage: 'approved')
    assert publisher_service.can_publish_content?
    
    # Should also work from scheduled stage
    @workflow.update!(current_stage: 'scheduled')
    assert publisher_service.can_publish_content?
    
    # Should not work from draft
    @workflow.update!(current_stage: 'draft')
    refute publisher_service.can_publish_content?
  end

  test 'should check user assignment permissions' do
    assign_user_to_workflow(@admin_user.id, 'admin', 'draft')
    admin_service = WorkflowPermissionService.new(@admin_user, @workflow)
    
    assert admin_service.can_assign_users?
    
    # Regular users should not be able to assign
    refute @permission_service.can_assign_users?
  end

  test 'should check workflow management permissions' do
    assign_user_to_workflow(@admin_user.id, 'admin', 'draft')
    admin_service = WorkflowPermissionService.new(@admin_user, @workflow)
    
    assert admin_service.can_manage_workflow?
    
    # Regular users should not be able to manage
    refute @permission_service.can_manage_workflow?
  end

  test 'should check if user has specific role' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    assert @permission_service.has_role?('creator')
    refute @permission_service.has_role?('reviewer')
  end

  test 'should check if user has any of multiple roles' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    assert @permission_service.has_any_role?(['creator', 'reviewer'])
    refute @permission_service.has_any_role?(['reviewer', 'approver'])
  end

  test 'should get user roles for current stage' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    assign_user_to_workflow(@creator_user.id, 'reviewer', 'review')
    
    draft_roles = @permission_service.user_roles('draft')
    review_roles = @permission_service.user_roles('review')
    
    assert_includes draft_roles, 'creator'
    refute_includes draft_roles, 'reviewer'
    
    assert_includes review_roles, 'reviewer'
    refute_includes review_roles, 'creator'
  end

  test 'should get highest role for user' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    assert_equal 'creator', @permission_service.highest_role
    
    # Add higher role
    assign_user_to_workflow(@creator_user.id, 'approver', 'draft')
    assert_equal 'approver', @permission_service.highest_role
  end

  test 'should calculate user permission level' do
    # No assignments = no permissions
    assert_equal 0, @permission_service.get_user_permission_level
    
    # Creator in draft stage = edit level
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    assert_equal 3, @permission_service.get_user_permission_level # edit level
    
    # Reviewer in review stage = approve level
    assign_user_to_workflow(@reviewer_user.id, 'reviewer', 'review')
    reviewer_service = WorkflowPermissionService.new(@reviewer_user, @workflow)
    @workflow.update!(current_stage: 'review')
    assert_equal 4, reviewer_service.get_user_permission_level # approve level
  end

  test 'should filter accessible workflows' do
    # Create additional workflows
    other_campaign = campaigns(:holiday_campaign)
    other_workflow = ContentWorkflow.create!(
      content_item: other_campaign,
      current_stage: 'draft',
      template_name: 'standard_content_approval',
      template_version: '1.0'
    )
    
    # Assign user to only one workflow
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    accessible = @permission_service.accessible_workflows(ContentWorkflow.all)
    
    assert_includes accessible.pluck(:id), @workflow.id
    refute_includes accessible.pluck(:id), other_workflow.id
  end

  test 'should check role assignment permissions' do
    assign_user_to_workflow(@approver_user.id, 'approver', 'draft')
    approver_service = WorkflowPermissionService.new(@approver_user, @workflow)
    
    # Approver should be able to assign creator and reviewer roles
    assert approver_service.can_assign_role?(123, 'creator', 'draft')
    assert approver_service.can_assign_role?(123, 'reviewer', 'draft')
    
    # But not admin role (higher than approver)
    refute approver_service.can_assign_role?(123, 'admin', 'draft')
    
    # Creator should not be able to assign any roles
    refute @permission_service.can_assign_role?(123, 'creator', 'draft')
  end

  test 'should get assignable roles for user' do
    assign_user_to_workflow(@approver_user.id, 'approver', 'draft')
    approver_service = WorkflowPermissionService.new(@approver_user, @workflow)
    
    assignable_roles = approver_service.assignable_roles
    
    assert_includes assignable_roles, 'creator'
    assert_includes assignable_roles, 'reviewer'
    assert_includes assignable_roles, 'approver'
    refute_includes assignable_roles, 'admin'
  end

  test 'should provide permission summary' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    summary = @permission_service.permission_summary
    
    assert_equal @creator_user.id, summary[:user_id]
    assert_equal @workflow.id, summary[:workflow_id]
    assert_equal 'draft', summary[:current_stage]
    assert_includes summary[:roles], 'creator'
    assert_equal 'creator', summary[:highest_role]
    assert_includes summary[:available_actions], 'edit'
    
    assert summary[:specific_permissions][:can_view]
    assert summary[:specific_permissions][:can_edit]
    assert summary[:specific_permissions][:can_submit]
    refute summary[:specific_permissions][:can_approve]
  end

  test 'should perform bulk permission checks' do
    other_workflow = ContentWorkflow.create!(
      content_item: campaigns(:holiday_campaign),
      current_stage: 'review',
      template_name: 'standard_content_approval',
      template_version: '1.0'
    )
    
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    
    workflows = [@workflow, other_workflow]
    results = WorkflowPermissionService.bulk_permission_check(@creator_user, workflows, 'edit')
    
    assert results[@workflow.id]  # Can edit assigned workflow in draft
    refute results[other_workflow.id]  # Cannot edit unassigned workflow
  end

  test 'should find users with specific permission' do
    assign_user_to_workflow(@creator_user.id, 'creator', 'draft')
    assign_user_to_workflow(@reviewer_user.id, 'reviewer', 'review')
    
    users_with_edit = WorkflowPermissionService.users_with_permission(@workflow, 'edit')
    users_with_approve = WorkflowPermissionService.users_with_permission(@workflow, 'approve')
    
    assert_includes users_with_edit, @creator_user.id
    refute_includes users_with_edit, @reviewer_user.id
    
    assert_includes users_with_approve, @reviewer_user.id
    refute_includes users_with_approve, @creator_user.id
  end

  test 'should provide role hierarchy information' do
    hierarchy = WorkflowPermissionService.role_hierarchy_map
    
    assert hierarchy.key?(:creator)
    assert hierarchy.key?(:reviewer)
    assert hierarchy.key?(:approver)
    assert hierarchy.key?(:admin)
    
    assert hierarchy[:creator][:level] < hierarchy[:reviewer][:level]
    assert hierarchy[:reviewer][:level] < hierarchy[:approver][:level]
    assert hierarchy[:approver][:level] < hierarchy[:admin][:level]
  end

  test 'should handle users without permissions gracefully' do
    unassigned_user = mock_user(id: 999, name: 'Unassigned User')
    unassigned_service = WorkflowPermissionService.new(unassigned_user, @workflow)
    
    refute unassigned_service.can_view_workflow?
    refute unassigned_service.can_edit_content?
    refute unassigned_service.can_perform_action?('edit')
    
    assert_empty unassigned_service.user_roles
    assert_nil unassigned_service.highest_role
    assert_equal 0, unassigned_service.get_user_permission_level
  end

  test 'should handle workflows without assignments' do
    # Workflow with no assignments
    empty_workflow = ContentWorkflow.create!(
      content_item: campaigns(:holiday_campaign),
      current_stage: 'draft',
      template_name: 'standard_content_approval',
      template_version: '1.0'
    )
    
    empty_service = WorkflowPermissionService.new(@creator_user, empty_workflow)
    
    refute empty_service.can_edit_content?
    assert_empty empty_service.user_roles
    assert_equal 0, empty_service.get_user_permission_level
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

  def assign_user_to_workflow(user_id, role, stage)
    WorkflowAssignment.create!(
      content_workflow: @workflow,
      user_id: user_id,
      role: role,
      stage: stage,
      assignment_type: :manual,
      status: :active,
      assigned_at: Time.current
    )
  end
end