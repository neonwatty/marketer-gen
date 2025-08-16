require "test_helper"

class CollaborationWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @marketer = users(:marketer_user)
    @team_member = users(:team_member_user)
    @admin = users(:admin_user)
    @campaign_plan = campaign_plans(:completed_plan)
  end

  test "complete approval workflow from submission to approval" do
    sign_in_as(@marketer)
    
    # Step 1: Submit plan for approval
    assert_difference 'PlanVersion.count', 1 do
      assert_difference 'PlanAuditLog.count', 1 do
        @campaign_plan.submit_for_approval!(@marketer)
      end
    end
    
    @campaign_plan.reload
    assert_equal "pending_approval", @campaign_plan.approval_status
    assert_not_nil @campaign_plan.submitted_for_approval_at
    assert_not_nil @campaign_plan.current_version_id
    
    # Verify audit log
    submission_log = PlanAuditLog.last
    assert_equal "submitted_for_approval", submission_log.action
    assert_equal @marketer, submission_log.user
    
    # Step 2: Admin approves the plan
    current_version = @campaign_plan.current_version
    
    assert_difference 'PlanAuditLog.count', 1 do
      current_version.approve!(@admin)
    end
    
    @campaign_plan.reload
    assert_equal "approved", @campaign_plan.approval_status
    assert_equal @admin, @campaign_plan.approved_by
    assert_not_nil @campaign_plan.approved_at
    
    # Verify audit log
    approval_log = PlanAuditLog.last
    assert_equal "version_approved", approval_log.action
    assert_equal @admin, approval_log.user
    assert_equal current_version, approval_log.plan_version
  end

  test "complete rejection workflow with feedback" do
    sign_in_as(@marketer)
    
    # Submit plan for approval
    @campaign_plan.submit_for_approval!(@marketer)
    current_version = @campaign_plan.current_version
    
    # Step 1: Add critical feedback
    sign_in_as(@team_member)
    
    assert_difference 'FeedbackComment.count', 1 do
      assert_difference 'PlanAuditLog.count', 1 do
        critical_feedback = FeedbackComment.create!(
          plan_version: current_version,
          user: @team_member,
          content: "The budget allocation section needs significant revision. The proposed spending on digital ads seems excessive.",
          comment_type: "concern",
          priority: "critical",
          section_reference: "strategic_overview"
        )
      end
    end
    
    critical_comment = FeedbackComment.last
    
    # Verify feedback creation audit log
    feedback_log = PlanAuditLog.last
    assert_equal "feedback_added", feedback_log.action
    assert_equal critical_comment.id, feedback_log.details["feedback_id"]
    
    # Step 2: Admin rejects due to critical feedback
    sign_in_as(@admin)
    rejection_reason = "Critical feedback regarding budget allocation must be addressed before approval"
    
    assert_difference 'PlanAuditLog.count', 1 do
      current_version.reject!(@admin, rejection_reason)
    end
    
    @campaign_plan.reload
    assert_equal "rejected", @campaign_plan.approval_status
    assert_equal @admin, @campaign_plan.rejected_by
    assert_equal rejection_reason, @campaign_plan.rejection_reason
    assert_not_nil @campaign_plan.rejected_at
    
    # Verify rejection audit log
    rejection_log = PlanAuditLog.last
    assert_equal "version_rejected", rejection_log.action
    assert_equal rejection_reason, rejection_log.details["reason"]
  end

  test "feedback lifecycle: add, address, resolve" do
    # Setup: Submit plan and create version
    @campaign_plan.submit_for_approval!(@marketer)
    current_version = @campaign_plan.current_version
    
    # Step 1: Team member adds feedback
    sign_in_as(@team_member)
    
    feedback = FeedbackComment.create!(
      plan_version: current_version,
      user: @team_member,
      content: "The timeline seems too aggressive for Q1. Consider extending the launch phase by 2 weeks.",
      comment_type: "suggestion",
      priority: "medium",
      section_reference: "timeline_visualization"
    )
    
    assert_equal "open", feedback.status
    assert feedback.is_open?
    
    # Step 2: Marketer addresses the feedback with response
    sign_in_as(@marketer)
    response = "Good point! I've adjusted the timeline to include a 2-week buffer in the launch phase."
    
    assert_difference 'FeedbackComment.count', 1 do # Creates reply
      assert_difference 'PlanAuditLog.count', 1 do
        feedback.mark_as_addressed!(@marketer, response)
      end
    end
    
    feedback.reload
    assert_equal "addressed", feedback.status
    assert_equal @marketer.id, feedback.metadata["addressed_by"]
    assert_not_nil feedback.metadata["addressed_at"]
    
    # Verify reply was created
    reply = feedback.replies.last
    assert_equal response, reply.content
    assert_equal @marketer, reply.user
    assert_equal "general", reply.comment_type
    
    # Verify audit log
    addressed_log = PlanAuditLog.last
    assert_equal "feedback_addressed", addressed_log.action
    assert_equal feedback.id, addressed_log.details["feedback_id"]
    
    # Step 3: Team member resolves the feedback
    sign_in_as(@team_member)
    
    assert_difference 'PlanAuditLog.count', 1 do
      feedback.mark_as_resolved!(@team_member)
    end
    
    feedback.reload
    assert_equal "resolved", feedback.status
    assert feedback.is_resolved?
    assert_equal @team_member.id, feedback.metadata["resolved_by"]
    
    # Verify audit log
    resolved_log = PlanAuditLog.last
    assert_equal "feedback_resolved", resolved_log.action
  end

  test "feedback threading and replies" do
    @campaign_plan.submit_for_approval!(@marketer)
    current_version = @campaign_plan.current_version
    
    # Create parent comment
    parent_comment = FeedbackComment.create!(
      plan_version: current_version,
      user: @team_member,
      content: "The creative approach section lacks specificity. What specific design elements will be used?",
      comment_type: "suggestion",
      priority: "medium",
      section_reference: "creative_approach"
    )
    
    # Create reply from marketer
    sign_in_as(@marketer)
    reply1 = FeedbackComment.create!(
      plan_version: current_version,
      user: @marketer,
      content: "Great question! I'll add details about color palette, typography, and visual style guidelines.",
      comment_type: "general",
      priority: "low",
      parent_comment: parent_comment
    )
    
    # Create second reply from admin
    sign_in_as(@admin)
    reply2 = FeedbackComment.create!(
      plan_version: current_version,
      user: @admin,
      content: "Please also include brand compliance guidelines in the creative approach.",
      comment_type: "suggestion",
      priority: "medium",
      parent_comment: parent_comment
    )
    
    # Test relationships
    assert_equal parent_comment, reply1.parent_comment
    assert_equal parent_comment, reply2.parent_comment
    assert_includes parent_comment.replies, reply1
    assert_includes parent_comment.replies, reply2
    
    # Test predicates
    assert_not parent_comment.is_reply?
    assert reply1.is_reply?
    assert reply2.is_reply?
    
    # Test scopes
    top_level_comments = current_version.feedback_comments.top_level
    assert_includes top_level_comments, parent_comment
    assert_not_includes top_level_comments, reply1
    assert_not_includes top_level_comments, reply2
  end

  test "version creation and management workflow" do
    # Start with completed plan
    assert @campaign_plan.has_generated_content?
    
    # Step 1: Create initial version
    sign_in_as(@marketer)
    
    assert_difference 'PlanVersion.count', 1 do
      version1 = @campaign_plan.create_version!(@marketer, "Initial version for review")
    end
    
    version1 = PlanVersion.last
    assert_equal 1, version1.version_number
    assert_equal "Initial version for review", version1.change_summary
    assert version1.is_current?
    assert_equal version1.id, @campaign_plan.reload.current_version_id
    
    # Verify snapshot content
    assert_equal @campaign_plan.generated_summary, version1.content["generated_summary"]
    assert_equal @campaign_plan.generated_strategy, version1.content["generated_strategy"]
    assert_equal @campaign_plan.target_audience, version1.metadata["target_audience"]
    
    # Step 2: Submit for review
    assert_difference 'PlanAuditLog.count', 1 do
      version1.submit_for_review!(@marketer)
    end
    
    version1.reload
    assert_equal "pending_review", version1.status
    assert_equal "pending_approval", @campaign_plan.reload.approval_status
    
    # Step 3: Make changes and create new version
    @campaign_plan.update!(
      generated_summary: "Updated summary with market research insights"
    )
    
    assert_difference 'PlanVersion.count', 1 do
      version2 = @campaign_plan.create_version!(@marketer, "Updated based on market research")
    end
    
    version2 = PlanVersion.last
    assert_equal 2, version2.version_number
    assert_equal "Updated based on market research", version2.change_summary
    assert version2.is_current?
    assert_not version1.reload.is_current?
    
    # Test version navigation
    assert_equal version1, version2.previous_version
    assert_equal version2, version1.next_version
    assert_nil version1.previous_version
    assert_nil version2.next_version
  end

  test "audit trail comprehensive tracking" do
    sign_in_as(@marketer)
    
    # Track initial state
    initial_log_count = PlanAuditLog.count
    
    # Step 1: Submit for approval (creates version and audit log)
    @campaign_plan.submit_for_approval!(@marketer)
    assert_equal initial_log_count + 1, PlanAuditLog.count
    
    current_version = @campaign_plan.current_version
    
    # Step 2: Add feedback (creates audit log)
    sign_in_as(@team_member)
    feedback = FeedbackComment.create!(
      plan_version: current_version,
      user: @team_member,
      content: "This section needs more detail about target demographics.",
      comment_type: "suggestion",
      priority: "medium"
    )
    assert_equal initial_log_count + 2, PlanAuditLog.count
    
    # Step 3: Address feedback (creates audit log)
    sign_in_as(@marketer)
    feedback.mark_as_addressed!(@marketer, "I'll add demographic breakdown in next revision")
    assert_equal initial_log_count + 3, PlanAuditLog.count
    
    # Step 4: Resolve feedback (creates audit log)
    sign_in_as(@team_member)
    feedback.mark_as_resolved!(@team_member)
    assert_equal initial_log_count + 4, PlanAuditLog.count
    
    # Step 5: Approve version (creates audit log)
    sign_in_as(@admin)
    current_version.approve!(@admin)
    assert_equal initial_log_count + 5, PlanAuditLog.count
    
    # Verify audit trail content
    audit_trail = PlanAuditLog.audit_trail_for_plan(@campaign_plan, 10)
    assert_equal 5, audit_trail.count
    
    actions = audit_trail.map(&:action)
    assert_includes actions, "submitted_for_approval"
    assert_includes actions, "feedback_added"
    assert_includes actions, "feedback_addressed"
    assert_includes actions, "feedback_resolved"
    assert_includes actions, "version_approved"
    
    # Test activity summary
    summary = PlanAuditLog.activity_summary(1) # Last 1 day
    assert summary[:total_activity] >= 5
    assert summary[:approvals] >= 1
    assert summary[:feedback_items] >= 1
  end

  test "complex collaboration scenario with multiple stakeholders" do
    sign_in_as(@marketer)
    
    # Initial submission
    @campaign_plan.submit_for_approval!(@marketer)
    current_version = @campaign_plan.current_version
    
    # Multiple stakeholders provide feedback
    sign_in_as(@team_member)
    feedback1 = FeedbackComment.create!(
      plan_version: current_version,
      user: @team_member,
      content: "Budget allocation needs review - digital spend seems too high relative to traditional media",
      comment_type: "concern",
      priority: "high",
      section_reference: "strategic_overview"
    )
    
    sign_in_as(@admin)
    feedback2 = FeedbackComment.create!(
      plan_version: current_version,
      user: @admin,
      content: "Timeline looks aggressive but achievable. Make sure to account for holiday scheduling.",
      comment_type: "general",
      priority: "medium",
      section_reference: "timeline_visualization"
    )
    
    # Create critical feedback that will block approval
    critical_feedback = FeedbackComment.create!(
      plan_version: current_version,
      user: @admin,
      content: "Legal compliance section is missing. This is required before any approval.",
      comment_type: "concern",
      priority: "critical",
      section_reference: "strategic_rationale"
    )
    
    # Verify version cannot be approved with critical feedback
    assert_not current_version.can_be_approved?
    assert_equal 1, current_version.critical_feedback.count
    
    # Address non-critical feedback
    sign_in_as(@marketer)
    feedback1.mark_as_addressed!(@marketer, "Adjusted budget allocation - increased traditional media by 15%")
    feedback2.mark_as_addressed!(@marketer, "Added holiday schedule buffer in Q4")
    
    # Critical feedback still blocks approval
    assert_not current_version.reload.can_be_approved?
    
    # Address critical feedback
    critical_feedback.mark_as_addressed!(@marketer, "Added comprehensive legal compliance section")
    
    # Mark critical feedback as resolved
    sign_in_as(@admin)
    critical_feedback.mark_as_resolved!(@admin)
    
    # Now version can be approved
    current_version.reload
    assert current_version.can_be_approved?
    assert_equal 0, current_version.critical_feedback.count
    
    # Final approval
    current_version.approve!(@admin)
    
    @campaign_plan.reload
    assert_equal "approved", @campaign_plan.approval_status
    assert_equal @admin, @campaign_plan.approved_by
    
    # Verify comprehensive audit trail
    audit_trail = PlanAuditLog.audit_trail_for_plan(@campaign_plan)
    
    # Should include all major actions
    actions = audit_trail.map(&:action)
    assert_includes actions, "submitted_for_approval"
    assert_includes actions, "feedback_added"
    assert_includes actions, "feedback_addressed"
    assert_includes actions, "feedback_resolved"
    assert_includes actions, "version_approved"
    
    # Should track all stakeholder interactions
    users = audit_trail.map(&:user).uniq
    assert_includes users, @marketer
    assert_includes users, @team_member
    assert_includes users, @admin
  end

  test "feedback urgency scoring and prioritization" do
    @campaign_plan.submit_for_approval!(@marketer)
    current_version = @campaign_plan.current_version
    
    # Create feedback with different urgency levels
    low_general = FeedbackComment.create!(
      plan_version: current_version,
      user: @team_member,
      content: "Minor suggestion for improvement",
      comment_type: "general",
      priority: "low"
    )
    
    medium_suggestion = FeedbackComment.create!(
      plan_version: current_version,
      user: @team_member,
      content: "This could be enhanced with additional detail",
      comment_type: "suggestion",
      priority: "medium"
    )
    
    high_concern = FeedbackComment.create!(
      plan_version: current_version,
      user: @admin,
      content: "This approach may not align with brand guidelines",
      comment_type: "concern",
      priority: "high"
    )
    
    critical_concern = FeedbackComment.create!(
      plan_version: current_version,
      user: @admin,
      content: "This violates our advertising standards and must be changed",
      comment_type: "concern",
      priority: "critical"
    )
    
    # Test urgency scoring
    assert_equal 25, low_general.urgency_score # 25 (low) + 0 (general)
    assert_equal 50, medium_suggestion.urgency_score # 50 (medium) + 0 (suggestion)
    assert_equal 100, high_concern.urgency_score # 75 (high) + 25 (concern)
    assert_equal 125, critical_concern.urgency_score # 100 (critical) + 25 (concern)
    
    # Test needs_attention predicate
    assert_not low_general.needs_attention?
    assert_not medium_suggestion.needs_attention?
    assert high_concern.needs_attention?
    assert critical_concern.needs_attention?
    
    # Test critical scope
    critical_comments = current_version.critical_feedback
    assert_includes critical_comments, critical_concern
    assert_not_includes critical_comments, high_concern
    
    # Test can_be_approved with critical feedback
    assert_not current_version.can_be_approved?
    
    # Resolve critical feedback
    critical_concern.mark_as_resolved!(@admin)
    
    # Should now be approvable (high concern doesn't block approval)
    current_version.reload
    assert current_version.can_be_approved?
  end

  private

  def sign_in_as(user)
    @current_user = user
  end
end