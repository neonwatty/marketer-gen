require "test_helper"

class FeedbackCommentTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @team_user = users(:team_member_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @plan_version = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    @feedback_comment = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "This is a test feedback comment with enough content",
      comment_type: "general",
      priority: "medium"
    )
  end

  # Basic validations
  test "should be valid with valid attributes" do
    comment = FeedbackComment.new(
      plan_version: @plan_version,
      user: @user,
      content: "Valid feedback comment with sufficient length",
      comment_type: "suggestion",
      priority: "low"
    )
    assert comment.valid?
  end

  test "should require plan_version" do
    @feedback_comment.plan_version = nil
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:plan_version], "must exist"
  end

  test "should require user" do
    @feedback_comment.user = nil
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:user], "must exist"
  end

  test "should require content" do
    @feedback_comment.content = nil
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:content], "can't be blank"
  end

  test "should validate content length" do
    @feedback_comment.content = "short"
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:content], "is too short (minimum is 10 characters)"
    
    @feedback_comment.content = "a" * 5001
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:content], "is too long (maximum is 5000 characters)"
  end

  test "should require comment_type" do
    @feedback_comment.comment_type = nil
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:comment_type], "can't be blank"
  end

  test "should validate comment_type inclusion" do
    @feedback_comment.comment_type = "invalid_type"
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:comment_type], "is not included in the list"
  end

  test "should require priority" do
    @feedback_comment.priority = nil
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:priority], "can't be blank"
  end

  test "should validate priority inclusion" do
    @feedback_comment.priority = "invalid_priority"
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:priority], "is not included in the list"
  end

  test "should require status" do
    @feedback_comment.status = nil
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    @feedback_comment.status = "invalid_status"
    assert_not @feedback_comment.valid?
    assert_includes @feedback_comment.errors[:status], "is not included in the list"
  end

  test "should have default status of open" do
    comment = FeedbackComment.new(
      plan_version: @plan_version,
      user: @user,
      content: "Test comment with enough content",
      comment_type: "general",
      priority: "low"
    )
    assert_equal "open", comment.status
  end

  # Associations and relationships
  test "should belong to plan_version" do
    assert_equal @plan_version, @feedback_comment.plan_version
  end

  test "should belong to user" do
    assert_equal @user, @feedback_comment.user
  end

  test "campaign_plan should delegate to plan_version" do
    assert_equal @campaign_plan, @feedback_comment.campaign_plan
  end

  test "should support parent-child comment relationships" do
    reply = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @team_user,
      content: "This is a reply to the original comment",
      comment_type: "general",
      priority: "low",
      parent_comment: @feedback_comment
    )
    
    assert_equal @feedback_comment, reply.parent_comment
    assert_includes @feedback_comment.replies, reply
  end

  test "should destroy dependent replies when parent is deleted" do
    reply = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @team_user,
      content: "This is a reply to the original comment",
      comment_type: "general",
      priority: "low",
      parent_comment: @feedback_comment
    )
    
    assert_difference 'FeedbackComment.count', -2 do
      @feedback_comment.destroy
    end
  end

  # Status predicates
  test "is_reply? should work correctly" do
    assert_not @feedback_comment.is_reply?
    
    reply = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @team_user,
      content: "This is a reply to the original comment",
      comment_type: "general",
      priority: "low",
      parent_comment: @feedback_comment
    )
    
    assert reply.is_reply?
  end

  test "is_critical? should work correctly" do
    assert_not @feedback_comment.is_critical?
    
    @feedback_comment.priority = "critical"
    assert @feedback_comment.is_critical?
  end

  test "is_open? should work correctly" do
    assert @feedback_comment.is_open?
    
    @feedback_comment.status = "resolved"
    assert_not @feedback_comment.is_open?
  end

  test "is_resolved? should work correctly" do
    assert_not @feedback_comment.is_resolved?
    
    @feedback_comment.status = "resolved"
    assert @feedback_comment.is_resolved?
  end

  test "needs_attention? should work correctly" do
    # Medium priority general comment shouldn't need attention
    assert_not @feedback_comment.needs_attention?
    
    # Critical priority should need attention
    @feedback_comment.priority = "critical"
    assert @feedback_comment.needs_attention?
    
    # Concern type should need attention
    @feedback_comment.priority = "medium"
    @feedback_comment.comment_type = "concern"
    assert @feedback_comment.needs_attention?
    
    # Resolved concern shouldn't need attention
    @feedback_comment.status = "resolved"
    assert_not @feedback_comment.needs_attention?
  end

  # Action methods
  test "mark_as_addressed! should update status and create audit log" do
    response = "We have addressed this feedback"
    
    assert_difference 'PlanAuditLog.count', 1 do
      @feedback_comment.mark_as_addressed!(@team_user, response)
    end
    
    @feedback_comment.reload
    assert_equal "addressed", @feedback_comment.status
    assert_equal @team_user.id, @feedback_comment.metadata["addressed_by"]
    assert_not_nil @feedback_comment.metadata["addressed_at"]
    
    # Should create a reply
    assert_equal 1, @feedback_comment.replies.count
    reply = @feedback_comment.replies.first
    assert_equal response, reply.content
    assert_equal @team_user, reply.user
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "feedback_addressed", audit_log.action
    assert_equal @feedback_comment.id, audit_log.details["feedback_id"]
  end

  test "mark_as_addressed! without response should not create reply" do
    assert_difference 'PlanAuditLog.count', 1 do
      assert_no_difference 'FeedbackComment.count' do
        @feedback_comment.mark_as_addressed!(@team_user)
      end
    end
    
    @feedback_comment.reload
    assert_equal "addressed", @feedback_comment.status
    assert_equal 0, @feedback_comment.replies.count
  end

  test "mark_as_resolved! should update status and create audit log" do
    assert_difference 'PlanAuditLog.count', 1 do
      @feedback_comment.mark_as_resolved!(@team_user)
    end
    
    @feedback_comment.reload
    assert_equal "resolved", @feedback_comment.status
    assert_equal @team_user.id, @feedback_comment.metadata["resolved_by"]
    assert_not_nil @feedback_comment.metadata["resolved_at"]
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "feedback_resolved", audit_log.action
    assert_equal @feedback_comment.id, audit_log.details["feedback_id"]
  end

  test "dismiss! should update status with reason and create audit log" do
    reason = "Not relevant to current version"
    
    assert_difference 'PlanAuditLog.count', 1 do
      @feedback_comment.dismiss!(@team_user, reason)
    end
    
    @feedback_comment.reload
    assert_equal "dismissed", @feedback_comment.status
    assert_equal @team_user.id, @feedback_comment.metadata["dismissed_by"]
    assert_equal reason, @feedback_comment.metadata["dismissal_reason"]
    assert_not_nil @feedback_comment.metadata["dismissed_at"]
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "feedback_dismissed", audit_log.action
    assert_equal reason, audit_log.details["reason"]
  end

  # Utility methods
  test "urgency_score should calculate correctly" do
    # Low priority general comment
    @feedback_comment.priority = "low"
    @feedback_comment.comment_type = "general"
    assert_equal 25, @feedback_comment.urgency_score
    
    # Critical priority concern
    @feedback_comment.priority = "critical"
    @feedback_comment.comment_type = "concern"
    assert_equal 125, @feedback_comment.urgency_score # 100 + 25
    
    # High priority suggestion
    @feedback_comment.priority = "high"
    @feedback_comment.comment_type = "suggestion"
    assert_equal 75, @feedback_comment.urgency_score
    
    # Medium priority concern
    @feedback_comment.priority = "medium"
    @feedback_comment.comment_type = "concern"
    assert_equal 75, @feedback_comment.urgency_score # 50 + 25
  end

  test "formatted_section_reference should handle various inputs" do
    @feedback_comment.section_reference = nil
    assert_equal "General", @feedback_comment.formatted_section_reference
    
    @feedback_comment.section_reference = ""
    assert_equal "General", @feedback_comment.formatted_section_reference
    
    @feedback_comment.section_reference = "strategic_overview"
    assert_equal "Strategic Overview", @feedback_comment.formatted_section_reference
    
    @feedback_comment.section_reference = "content_mapping"
    assert_equal "Content Mapping", @feedback_comment.formatted_section_reference
  end

  test "time_since_created should use time_ago_in_words" do
    @feedback_comment.update!(created_at: 2.hours.ago)
    
    assert_includes @feedback_comment.time_since_created, "hour"
  end

  test "can_be_edited_by? should work correctly" do
    # Author can edit recent open comment (just created)
    assert @feedback_comment.can_be_edited_by?(@user)
    
    # Non-author cannot edit
    assert_not @feedback_comment.can_be_edited_by?(@team_user)
    
    # Author cannot edit old comment
    travel_to 1.hour.from_now do
      assert_not @feedback_comment.can_be_edited_by?(@user)
    end
    
    # Author cannot edit non-open comment
    @feedback_comment.update!(status: "resolved")
    assert_not @feedback_comment.can_be_edited_by?(@user)
  end

  # Scopes
  test "by_type scope should filter correctly" do
    suggestion = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "This is a suggestion comment",
      comment_type: "suggestion",
      priority: "low"
    )
    
    general_comments = FeedbackComment.by_type("general")
    suggestion_comments = FeedbackComment.by_type("suggestion")
    
    assert_includes general_comments, @feedback_comment
    assert_not_includes general_comments, suggestion
    assert_includes suggestion_comments, suggestion
    assert_not_includes suggestion_comments, @feedback_comment
  end

  test "by_priority scope should filter correctly" do
    high_comment = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "This is a high priority comment",
      comment_type: "concern",
      priority: "high"
    )
    
    medium_comments = FeedbackComment.by_priority("medium")
    high_comments = FeedbackComment.by_priority("high")
    
    assert_includes medium_comments, @feedback_comment
    assert_not_includes medium_comments, high_comment
    assert_includes high_comments, high_comment
    assert_not_includes high_comments, @feedback_comment
  end

  test "by_status scope should filter correctly" do
    @feedback_comment.update!(status: "resolved")
    
    resolved_comment = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "This comment will be resolved",
      comment_type: "general",
      priority: "low",
      status: "resolved"
    )
    
    open_comments = FeedbackComment.by_status("open")
    resolved_comments = FeedbackComment.by_status("resolved")
    
    assert_not_includes open_comments, @feedback_comment
    assert_includes resolved_comments, @feedback_comment
    assert_includes resolved_comments, resolved_comment
  end

  test "open scope should return only open comments" do
    @feedback_comment.update!(status: "resolved")
    
    open_comment = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "This comment is open",
      comment_type: "general",
      priority: "low",
      status: "open"
    )
    
    open_comments = FeedbackComment.open
    assert_includes open_comments, open_comment
    assert_not_includes open_comments, @feedback_comment
  end

  test "critical scope should return only critical priority comments" do
    critical_comment = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "This is a critical comment",
      comment_type: "concern",
      priority: "critical"
    )
    
    critical_comments = FeedbackComment.critical
    assert_includes critical_comments, critical_comment
    assert_not_includes critical_comments, @feedback_comment
  end

  test "top_level scope should return only parent comments" do
    reply = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @team_user,
      content: "This is a reply comment",
      comment_type: "general",
      priority: "low",
      parent_comment: @feedback_comment
    )
    
    top_level_comments = FeedbackComment.top_level
    assert_includes top_level_comments, @feedback_comment
    assert_not_includes top_level_comments, reply
  end

  test "for_section scope should filter by section_reference" do
    @feedback_comment.update!(section_reference: "strategic_overview")
    
    timeline_comment = FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Timeline feedback comment",
      comment_type: "suggestion",
      priority: "medium",
      section_reference: "timeline_visualization"
    )
    
    overview_comments = FeedbackComment.for_section("strategic_overview")
    timeline_comments = FeedbackComment.for_section("timeline_visualization")
    
    assert_includes overview_comments, @feedback_comment
    assert_not_includes overview_comments, timeline_comment
    assert_includes timeline_comments, timeline_comment
    assert_not_includes timeline_comments, @feedback_comment
  end

  # Class methods
  test "grouped_by_section should group comments correctly" do
    @feedback_comment.update!(section_reference: "strategic_overview")
    
    FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Another strategic overview comment",
      comment_type: "suggestion",
      priority: "low",
      section_reference: "strategic_overview"
    )
    
    FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Timeline comment",
      comment_type: "general",
      priority: "medium",
      section_reference: "timeline_visualization"
    )
    
    grouped = FeedbackComment.grouped_by_section
    assert_equal 2, grouped["strategic_overview"]
    assert_equal 1, grouped["timeline_visualization"]
  end

  test "summary_stats should return comprehensive statistics" do
    # Create various comments for testing
    FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Critical suggestion comment",
      comment_type: "suggestion",
      priority: "critical",
      status: "open"
    )
    
    FeedbackComment.create!(
      plan_version: @plan_version,
      user: @user,
      content: "Resolved concern comment",
      comment_type: "concern",
      priority: "high",
      status: "resolved"
    )
    
    stats = FeedbackComment.summary_stats
    
    assert_equal 3, stats[:total]
    assert_equal 2, stats[:open] # original + critical suggestion
    assert_equal 1, stats[:critical]
    assert stats[:by_type]["general"] >= 1 # at least original
    assert_equal 1, stats[:by_type]["suggestion"]
    assert_equal 1, stats[:by_type]["concern"]
    assert_equal 2, stats[:by_status]["open"]
    assert_equal 1, stats[:by_status]["resolved"]
  end

  # Audit log creation
  test "should create audit log on creation" do
    assert_difference 'PlanAuditLog.count', 1 do
      FeedbackComment.create!(
        plan_version: @plan_version,
        user: @team_user,
        content: "New feedback comment for audit test",
        comment_type: "suggestion",
        priority: "medium"
      )
    end
    
    audit_log = PlanAuditLog.last
    assert_equal "feedback_added", audit_log.action
    assert_equal @team_user, audit_log.user
    assert_equal @plan_version, audit_log.plan_version
  end

  test "should create audit log on status change" do
    # Initial creation creates one audit log
    assert_difference 'PlanAuditLog.count', 1 do
      @feedback_comment.update!(status: "addressed")
    end
    
    audit_log = PlanAuditLog.last
    assert_equal "feedback_status_changed", audit_log.action
    assert_equal "open", audit_log.details["from_status"]
    assert_equal "addressed", audit_log.details["to_status"]
  end
end