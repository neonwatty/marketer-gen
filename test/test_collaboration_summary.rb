require "test_helper"

class CollaborationSummaryTest < ActiveSupport::TestCase
  def setup
    @marketer = users(:marketer_user)
    @team_member = users(:team_member_user)
    @admin = users(:admin_user)
    @campaign_plan = campaign_plans(:completed_plan)
  end

  test "complete collaboration workflow - end to end" do
    # Step 1: Plan creation (this creates audit log)
    initial_audit_count = PlanAuditLog.count
    
    plan = CampaignPlan.create!(
      user: @marketer,
      name: "E2E Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      status: "completed",
      approval_status: "draft",
      generated_summary: "Test summary for collaboration",
      generated_strategy: { phases: ["Research", "Launch"] }
    )
    
    assert_equal initial_audit_count + 1, PlanAuditLog.count
    
    # Step 2: Submit for approval (creates version + audit log)
    assert_difference 'PlanVersion.count', 1 do
      plan.submit_for_approval!(@marketer)
    end
    
    plan.reload
    assert_equal "pending_approval", plan.approval_status
    current_version = plan.current_version
    assert_not_nil current_version
    
    # Step 3: Add feedback with different priorities
    critical_feedback = FeedbackComment.create!(
      plan_version: current_version,
      user: @admin,
      content: "Critical issue: budget exceeds allocated amount",
      comment_type: "concern",
      priority: "critical",
      section_reference: "strategic_overview"
    )
    
    medium_feedback = FeedbackComment.create!(
      plan_version: current_version,
      user: @team_member,
      content: "Consider adding more digital channels to the strategy",
      comment_type: "suggestion",
      priority: "medium",
      section_reference: "content_strategy"
    )
    
    # Step 4: Version cannot be approved with critical feedback
    assert_not current_version.can_be_approved?
    assert_equal 1, current_version.critical_feedback.count
    
    # Step 5: Address critical feedback
    critical_feedback.mark_as_addressed!(@marketer, "Updated budget to align with allocation")
    critical_feedback.mark_as_resolved!(@admin)
    
    # Step 6: Address medium feedback with threading
    reply = FeedbackComment.create!(
      plan_version: current_version,
      user: @marketer,
      content: "Good suggestion! I've added Instagram and TikTok to the strategy",
      comment_type: "general",
      priority: "low",
      parent_comment: medium_feedback
    )
    
    medium_feedback.mark_as_resolved!(@team_member)
    
    # Step 7: Now version can be approved
    current_version.reload
    assert current_version.can_be_approved?
    assert_equal 0, current_version.critical_feedback.count
    
    # Step 8: Approve version
    current_version.approve!(@admin)
    
    plan.reload
    assert_equal "approved", plan.approval_status
    assert_equal @admin, plan.approved_by
    assert_not_nil plan.approved_at
    
    # Step 9: Verify audit trail completeness
    audit_trail = PlanAuditLog.audit_trail_for_plan(plan)
    
    expected_actions = [
      "created", "submitted_for_approval", "feedback_added", 
      "feedback_addressed", "feedback_resolved", "version_approved"
    ]
    
    actual_actions = audit_trail.map(&:action)
    expected_actions.each do |action|
      assert_includes actual_actions, action, "Missing action: #{action}"
    end
    
    # Step 10: Verify feedback relationships and threading
    assert_equal critical_feedback, critical_feedback.reload
    assert_equal "resolved", critical_feedback.status
    assert_equal medium_feedback, reply.parent_comment
    assert_includes medium_feedback.replies, reply
    
    # Step 11: Test version navigation
    assert_equal 1, current_version.version_number
    assert current_version.is_current?
    
    # Step 12: Verify summary statistics
    stats = FeedbackComment.summary_stats
    assert stats[:total] >= 3 # At least our 3 comments
    assert stats[:by_priority]["critical"] >= 1
    assert stats[:by_priority]["medium"] >= 1
    
    activity = PlanAuditLog.activity_summary(1)
    assert activity[:total_activity] >= 6
    assert activity[:approvals] >= 1
    assert activity[:feedback_items] >= 2
    
    puts "✅ Collaboration workflow test completed successfully!"
    puts "   - Plan created and submitted for approval"
    puts "   - Critical and medium feedback added"
    puts "   - Feedback addressed and resolved with threading"
    puts "   - Version approved after feedback resolution"
    puts "   - Complete audit trail maintained"
    puts "   - #{audit_trail.count} audit log entries created"
    puts "   - #{stats[:total]} feedback comments processed"
  end

  test "feedback priority and urgency system" do
    plan = CampaignPlan.create!(
      user: @marketer,
      name: "Priority Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      status: "completed",
      approval_status: "draft",
      generated_summary: "Test summary for priority testing",
      generated_strategy: { phases: ["Research", "Launch"] }
    )
    
    plan.submit_for_approval!(@marketer)
    version = plan.current_version
    
    # Test different urgency combinations
    test_cases = [
      { type: "general", priority: "low", expected_score: 25 },
      { type: "suggestion", priority: "medium", expected_score: 50 },
      { type: "concern", priority: "medium", expected_score: 75 }, # 50 + 25 concern bonus
      { type: "concern", priority: "critical", expected_score: 125 } # 100 + 25 concern bonus
    ]
    
    test_cases.each_with_index do |test_case, index|
      comment = FeedbackComment.create!(
        plan_version: version,
        user: @team_member,
        content: "Test comment #{index + 1} with enough content to meet minimum length",
        comment_type: test_case[:type],
        priority: test_case[:priority]
      )
      
      assert_equal test_case[:expected_score], comment.urgency_score,
        "Urgency score mismatch for #{test_case[:type]}/#{test_case[:priority]}"
    end
    
    puts "✅ Feedback priority system working correctly!"
  end

  test "version management and navigation" do
    # Use a plan that can have versions created
    plan = CampaignPlan.create!(
      user: @marketer,
      name: "Version Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      status: "completed",
      generated_summary: "Test summary for collaboration",
      generated_strategy: { phases: ["Research", "Launch"] }
    )
    
    # Create multiple versions
    version1 = plan.create_version!(@marketer, "Initial version")
    
    plan.update!(generated_summary: "Updated summary v2")
    version2 = plan.create_version!(@marketer, "Second version")
    
    plan.update!(generated_summary: "Updated summary v3")
    version3 = plan.create_version!(@marketer, "Third version")
    
    # Test version numbers
    assert_equal 1, version1.version_number
    assert_equal 2, version2.version_number
    assert_equal 3, version3.version_number
    
    # Test current version (reload to get fresh data)
    version1.reload
    version2.reload
    version3.reload
    
    assert_not version1.is_current?
    assert_not version2.is_current?
    assert version3.is_current?
    
    # Test navigation
    assert_nil version1.previous_version
    assert_equal version2, version1.next_version
    assert_equal version1, version2.previous_version
    assert_equal version3, version2.next_version
    assert_equal version2, version3.previous_version
    assert_nil version3.next_version
    
    # Test content snapshots
    assert_equal "Test summary for collaboration", version1.content["generated_summary"]
    assert_equal "Updated summary v2", version2.content["generated_summary"]
    assert_equal "Updated summary v3", version3.content["generated_summary"]
    
    puts "✅ Version management system working correctly!"
    puts "   - Created #{plan.plan_versions.count} versions"
    puts "   - Version navigation working"
    puts "   - Content snapshots preserved"
  end

  test "comprehensive audit logging" do
    initial_count = PlanAuditLog.count
    
    # Create a plan for audit testing
    plan = CampaignPlan.create!(
      user: @marketer,
      name: "Audit Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      status: "completed",
      approval_status: "draft",
      generated_summary: "Test summary for audit",
      generated_strategy: { phases: ["Research", "Launch"] }
    )
    
    # Perform various actions that should create audit logs
    plan.submit_for_approval!(@marketer)
    version = plan.current_version
    
    feedback = FeedbackComment.create!(
      plan_version: version,
      user: @team_member,
      content: "Audit test feedback comment with sufficient length",
      comment_type: "suggestion",
      priority: "medium"
    )
    
    feedback.mark_as_addressed!(@marketer, "Addressed in audit test")
    feedback.mark_as_resolved!(@team_member)
    version.approve!(@admin)
    
    final_count = PlanAuditLog.count
    created_logs = final_count - initial_count
    
    # Should have created at least 5 audit logs
    assert created_logs >= 5, "Expected at least 5 audit logs, got #{created_logs}"
    
    # Test audit log content
    recent_logs = PlanAuditLog.recent.limit(created_logs)
    actions = recent_logs.map(&:action)
    
    expected_actions = [
      "submitted_for_approval", "feedback_added", "feedback_addressed", 
      "feedback_resolved", "version_approved"
    ]
    
    expected_actions.each do |action|
      assert_includes actions, action, "Missing audit action: #{action}"
    end
    
    # Test audit log descriptions
    recent_logs.each do |log|
      description = log.action_description
      assert description.present?, "Audit log #{log.id} has no description"
      assert description.is_a?(String), "Audit log description should be a string"
    end
    
    puts "✅ Audit logging system working correctly!"
    puts "   - Created #{created_logs} audit log entries"
    puts "   - All expected actions logged"
    puts "   - Descriptions generated properly"
  end
end