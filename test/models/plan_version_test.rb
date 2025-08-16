require "test_helper"

class PlanVersionTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @plan_version = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user,
      content: { generated_summary: "Test summary" },
      metadata: { campaign_type: "product_launch" }
    )
  end

  # Basic validations
  test "should be valid with valid attributes" do
    version = PlanVersion.new(
      campaign_plan: @campaign_plan,
      created_by: @user,
      content: { test: "content" }
    )
    assert version.valid?
  end

  test "should require campaign_plan" do
    @plan_version.campaign_plan = nil
    assert_not @plan_version.valid?
    assert_includes @plan_version.errors[:campaign_plan], "must exist"
  end

  test "should require created_by" do
    @plan_version.created_by = nil
    assert_not @plan_version.valid?
    assert_includes @plan_version.errors[:created_by], "must exist"
  end

  test "should require version_number" do
    @plan_version.version_number = nil
    assert_not @plan_version.valid?
    assert_includes @plan_version.errors[:version_number], "can't be blank"
  end

  test "should require status" do
    @plan_version.status = nil
    assert_not @plan_version.valid?
    assert_includes @plan_version.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    @plan_version.status = "invalid_status"
    assert_not @plan_version.valid?
    assert_includes @plan_version.errors[:status], "is not included in the list"
  end

  test "should enforce unique version_number per campaign_plan" do
    duplicate_version = PlanVersion.new(
      campaign_plan: @campaign_plan,
      created_by: @user,
      version_number: @plan_version.version_number
    )
    assert_not duplicate_version.valid?
    assert_includes duplicate_version.errors[:version_number], "has already been taken"
  end

  test "should allow same version_number for different campaign_plans" do
    other_plan = campaign_plans(:completed_plan)
    version = PlanVersion.new(
      campaign_plan: other_plan,
      created_by: @user,
      version_number: @plan_version.version_number
    )
    assert version.valid?
  end

  # Version number management
  test "should auto-assign version_number on create" do
    version = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    assert_equal 2, version.version_number
  end

  test "next_version_number should increment correctly" do
    assert_equal 2, @plan_version.next_version_number
  end

  test "should set as current version on create by default" do
    # Create a new version to test this behavior
    new_version = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user,
      content: { generated_summary: "Another test summary" }
    )
    
    new_version.reload
    assert new_version.is_current?
    assert_equal new_version.id, @campaign_plan.reload.current_version_id
    
    # Original version should no longer be current
    @plan_version.reload
    assert_not @plan_version.is_current?
  end

  # Navigation methods
  test "previous_version should return correct version" do
    version2 = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    assert_equal @plan_version, version2.previous_version
    assert_nil @plan_version.previous_version
  end

  test "next_version should return correct version" do
    version2 = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    assert_equal version2, @plan_version.next_version
    assert_nil version2.next_version
  end

  # Feedback methods
  test "has_feedback? should work correctly" do
    assert_not @plan_version.has_feedback?
    
    FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Test feedback comment",
      comment_type: "general",
      priority: "low"
    )
    
    assert @plan_version.has_feedback?
  end

  test "open_feedback should return only open feedback" do
    open_feedback = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Open feedback",
      comment_type: "general",
      priority: "medium",
      status: "open"
    )
    
    addressed_feedback = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Addressed feedback",
      comment_type: "general",
      priority: "medium",
      status: "addressed"
    )
    
    assert_includes @plan_version.open_feedback, open_feedback
    assert_not_includes @plan_version.open_feedback, addressed_feedback
  end

  test "critical_feedback should return only critical open feedback" do
    critical_open = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Critical open feedback",
      comment_type: "concern",
      priority: "critical",
      status: "open"
    )
    
    critical_resolved = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Critical resolved feedback",
      comment_type: "concern",
      priority: "critical",
      status: "resolved"
    )
    
    high_open = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "High priority open feedback",
      comment_type: "suggestion",
      priority: "high",
      status: "open"
    )
    
    assert_includes @plan_version.critical_feedback, critical_open
    assert_not_includes @plan_version.critical_feedback, critical_resolved
    assert_not_includes @plan_version.critical_feedback, high_open
  end

  # Approval workflow
  test "can_be_approved? should work correctly" do
    @plan_version.update!(status: "pending_review")
    assert @plan_version.can_be_approved?
    
    # Should not be approvable with critical feedback
    FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Critical issue",
      comment_type: "concern",
      priority: "critical",
      status: "open"
    )
    
    assert_not @plan_version.can_be_approved?
    
    # Should not be approvable in draft status
    @plan_version.update!(status: "draft")
    assert_not @plan_version.can_be_approved?
  end

  test "approve! should update status and campaign_plan" do
    @plan_version.update!(status: "pending_review")
    
    assert_difference 'PlanAuditLog.count', 1 do
      @plan_version.approve!(@user)
    end
    
    @plan_version.reload
    @campaign_plan.reload
    
    assert_equal "approved", @plan_version.status
    assert_equal "approved", @campaign_plan.approval_status
    assert_equal @user, @campaign_plan.approved_by
    assert_not_nil @campaign_plan.approved_at
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "version_approved", audit_log.action
    assert_equal @plan_version, audit_log.plan_version
    assert_equal @user, audit_log.user
  end

  test "reject! should update status and campaign_plan with reason" do
    @plan_version.update!(status: "pending_review")
    reason = "Content needs improvement"
    
    assert_difference 'PlanAuditLog.count', 1 do
      @plan_version.reject!(@user, reason)
    end
    
    @plan_version.reload
    @campaign_plan.reload
    
    assert_equal "rejected", @plan_version.status
    assert_equal "rejected", @campaign_plan.approval_status
    assert_equal @user, @campaign_plan.rejected_by
    assert_equal reason, @campaign_plan.rejection_reason
    assert_not_nil @campaign_plan.rejected_at
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "version_rejected", audit_log.action
    assert_equal reason, audit_log.details["reason"]
  end

  test "submit_for_review! should update status and campaign_plan" do
    assert_difference 'PlanAuditLog.count', 1 do
      @plan_version.submit_for_review!(@user)
    end
    
    @plan_version.reload
    @campaign_plan.reload
    
    assert_equal "pending_review", @plan_version.status
    assert_equal "pending_approval", @campaign_plan.approval_status
    assert_not_nil @campaign_plan.submitted_for_approval_at
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "version_submitted_for_review", audit_log.action
  end

  # Content snapshot
  test "create_snapshot_from_plan! should capture all campaign plan content" do
    @campaign_plan.update!(
      generated_summary: "Updated summary",
      generated_strategy: { phases: ["Discovery", "Launch"] },
      generated_timeline: [{ week: 1, activity: "Research" }],
      generated_assets: ["Logo", "Banner"],
      content_strategy: { themes: ["Innovation"] },
      creative_approach: { style: "Modern" },
      strategic_rationale: { reasoning: "Market analysis" },
      content_mapping: [{ platform: "LinkedIn" }],
      target_audience: "Tech professionals",
      budget_constraints: "$50,000",
      timeline_constraints: "Q1 2025"
    )
    
    @plan_version.create_snapshot_from_plan!
    @plan_version.reload
    
    assert_equal "Updated summary", @plan_version.content["generated_summary"]
    assert_equal ["Discovery", "Launch"], @plan_version.content["generated_strategy"]["phases"]
    assert_equal "Tech professionals", @plan_version.metadata["target_audience"]
    assert_equal "$50,000", @plan_version.metadata["budget_constraints"]
    assert_not_nil @plan_version.metadata["snapshot_created_at"]
  end

  # Scopes
  test "current scope should return only current versions" do
    version2 = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    # version2 should now be current, @plan_version should not be
    @plan_version.reload
    version2.reload
    
    current_versions = PlanVersion.current
    assert_includes current_versions, version2
    assert_not_includes current_versions, @plan_version
  end

  test "by_status scope should filter correctly" do
    @plan_version.update!(status: "approved")
    
    version2 = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user,
      status: "draft"
    )
    
    approved_versions = PlanVersion.by_status("approved")
    assert_includes approved_versions, @plan_version
    assert_not_includes approved_versions, version2
  end

  test "recent scope should order by created_at desc" do
    sleep(0.01) # Ensure different timestamps
    version2 = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    recent_versions = PlanVersion.recent
    assert_equal version2, recent_versions.first
    assert_equal @plan_version, recent_versions.last
  end

  # Associations
  test "should belong to campaign_plan" do
    assert_equal @campaign_plan, @plan_version.campaign_plan
  end

  test "should belong to created_by user" do
    assert_equal @user, @plan_version.created_by
  end

  test "should have many feedback_comments" do
    comment = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Test comment",
      comment_type: "general",
      priority: "low"
    )
    
    assert_includes @plan_version.feedback_comments, comment
  end

  test "should destroy dependent feedback_comments" do
    comment = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Test comment",
      comment_type: "general",
      priority: "low"
    )
    
    assert_difference 'FeedbackComment.count', -1 do
      @plan_version.destroy
    end
  end

  test "should have many plan_audit_logs" do
    log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      plan_version: @plan_version,
      user: @user,
      action: "version_created"
    )
    
    assert_includes @plan_version.plan_audit_logs, log
  end

  # Current version management
  test "should update campaign_plan current_version_id when set as current" do
    version2 = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user,
      is_current: false
    )
    
    version2.update!(is_current: true)
    @campaign_plan.reload
    
    assert_equal version2.id, @campaign_plan.current_version_id
    assert_not @plan_version.reload.is_current?
  end

  test "should ensure only one current version per campaign_plan" do
    version2 = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    # version2 should be current, plan_version should not be
    @plan_version.reload
    version2.reload
    
    assert_not @plan_version.is_current?
    assert version2.is_current?
    
    # Verify only one current version exists
    current_versions = @campaign_plan.plan_versions.where(is_current: true)
    assert_equal 1, current_versions.count
  end
end