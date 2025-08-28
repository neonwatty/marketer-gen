require "test_helper"

class CampaignPlanTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
  end

  test "should be valid with valid attributes" do
    campaign_plan = CampaignPlan.new(
      user: @user,
      name: "Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    assert campaign_plan.valid?
  end

  test "should require name" do
    @campaign_plan.name = nil
    assert_not @campaign_plan.valid?
    assert_includes @campaign_plan.errors[:name], "can't be blank"
  end

  test "should require campaign_type" do
    @campaign_plan.campaign_type = nil
    assert_not @campaign_plan.valid?
    assert_includes @campaign_plan.errors[:campaign_type], "can't be blank"
  end

  test "should require objective" do
    @campaign_plan.objective = nil
    assert_not @campaign_plan.valid?
    assert_includes @campaign_plan.errors[:objective], "can't be blank"
  end

  test "should require user" do
    @campaign_plan.user = nil
    assert_not @campaign_plan.valid?
    assert_includes @campaign_plan.errors[:user], "must exist"
  end

  test "should validate campaign_type inclusion" do
    @campaign_plan.campaign_type = "invalid_type"
    assert_not @campaign_plan.valid?
    assert_includes @campaign_plan.errors[:campaign_type], "is not included in the list"
  end

  test "should validate objective inclusion" do
    @campaign_plan.objective = "invalid_objective"
    assert_not @campaign_plan.valid?
    assert_includes @campaign_plan.errors[:objective], "is not included in the list"
  end

  test "should validate status inclusion" do
    @campaign_plan.status = "invalid_status"
    assert_not @campaign_plan.valid?
    assert_includes @campaign_plan.errors[:status], "is not included in the list"
  end

  test "should enforce unique name per user" do
    duplicate_plan = CampaignPlan.new(
      user: @user,
      name: @campaign_plan.name,
      campaign_type: "brand_awareness",
      objective: "customer_acquisition"
    )
    assert_not duplicate_plan.valid?
    assert_includes duplicate_plan.errors[:name], "already exists for this user"
  end

  test "should allow same name for different users" do
    other_user = users(:team_member_user)
    duplicate_plan = CampaignPlan.new(
      user: other_user,
      name: @campaign_plan.name,
      campaign_type: "brand_awareness",
      objective: "customer_acquisition"
    )
    assert duplicate_plan.valid?
  end

  test "should validate length constraints" do
    @campaign_plan.name = "a" * 256
    assert_not @campaign_plan.valid?
    
    @campaign_plan.name = "Valid Name"
    @campaign_plan.description = "a" * 2001
    assert_not @campaign_plan.valid?
    
    @campaign_plan.description = "Valid description"
    @campaign_plan.target_audience = "a" * 1001
    assert_not @campaign_plan.valid?
  end

  test "should have default status of draft" do
    campaign_plan = CampaignPlan.new(
      user: @user,
      name: "Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    assert_equal "draft", campaign_plan.status
  end

  test "should set default metadata on create" do
    campaign_plan = CampaignPlan.create!(
      user: @user,
      name: "Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    assert_not_nil campaign_plan.metadata
    assert_equal "campaign_plan_generator", campaign_plan.metadata["created_via"]
    assert_equal "1.0", campaign_plan.metadata["version"]
  end

  test "status predicates should work correctly" do
    @campaign_plan.status = "draft"
    assert @campaign_plan.draft?
    assert_not @campaign_plan.generating?
    assert_not @campaign_plan.completed?
    assert_not @campaign_plan.failed?
    assert_not @campaign_plan.archived?

    @campaign_plan.status = "generating"
    assert_not @campaign_plan.draft?
    assert @campaign_plan.generating?
    assert_not @campaign_plan.completed?

    @campaign_plan.status = "completed"
    assert @campaign_plan.completed?

    @campaign_plan.status = "failed"
    assert @campaign_plan.failed?

    @campaign_plan.status = "archived"
    assert @campaign_plan.archived?
  end

  test "ready_for_generation should work correctly" do
    @campaign_plan.status = "draft"
    @campaign_plan.name = "Test"
    @campaign_plan.campaign_type = "product_launch"
    @campaign_plan.objective = "brand_awareness"
    assert @campaign_plan.ready_for_generation?

    @campaign_plan.name = nil
    assert_not @campaign_plan.ready_for_generation?

    @campaign_plan.name = "Test"
    @campaign_plan.status = "completed"
    assert_not @campaign_plan.ready_for_generation?
  end

  test "has_generated_content should work correctly" do
    plan = campaign_plans(:draft_plan)
    assert_not plan.has_generated_content?

    plan = campaign_plans(:completed_plan)
    assert plan.has_generated_content?
  end

  test "generation_progress should calculate correctly" do
    plan = campaign_plans(:draft_plan)
    assert_equal 0, plan.generation_progress

    plan = campaign_plans(:completed_plan)
    assert_equal 100, plan.generation_progress

    # Test partial progress (1 out of 8 fields = 12.5%, rounded to 13%)
    plan.generated_summary = "Summary"
    plan.generated_strategy = nil
    plan.generated_timeline = nil
    plan.generated_assets = nil
    plan.content_strategy = nil
    plan.creative_approach = nil
    plan.strategic_rationale = nil
    plan.content_mapping = nil
    plan.status = "generating"
    assert_equal 13, plan.generation_progress
  end

  test "context summary methods should handle JSON and text" do
    # Test with JSON
    @campaign_plan.brand_context = '{"voice": "professional", "tone": "friendly"}'
    context = @campaign_plan.brand_context_summary
    assert_equal "professional", context["voice"]
    assert_equal "friendly", context["tone"]

    # Test with plain text
    @campaign_plan.brand_context = "Plain text context"
    context = @campaign_plan.brand_context_summary
    assert_equal "Plain text context", context[:raw_context]

    # Test with empty/nil
    @campaign_plan.brand_context = nil
    assert_equal({}, @campaign_plan.brand_context_summary)
  end

  test "plan_analytics should return comprehensive data" do
    plan = campaign_plans(:completed_plan)
    analytics = plan.plan_analytics
    
    assert_equal plan.campaign_type, analytics[:campaign_type]
    assert_equal plan.objective, analytics[:objective]
    assert_equal plan.status, analytics[:status]
    assert analytics[:has_content]
    assert_equal 100, analytics[:generation_progress]
    assert analytics[:content_sections][:summary]
    assert analytics[:content_sections][:strategy]
  end

  test "can_be_archived should work correctly" do
    plan = campaign_plans(:completed_plan)
    assert plan.can_be_archived?

    plan = campaign_plans(:failed_plan)
    assert plan.can_be_archived?

    plan = campaign_plans(:draft_plan)
    assert_not plan.can_be_archived?

    plan = campaign_plans(:generating_plan)
    assert_not plan.can_be_archived?
  end

  test "can_be_regenerated should work correctly" do
    plan = campaign_plans(:completed_plan)
    assert plan.can_be_regenerated?

    plan = campaign_plans(:failed_plan)
    assert plan.can_be_regenerated?

    plan = campaign_plans(:archived_plan)
    assert plan.can_be_regenerated?

    plan = campaign_plans(:draft_plan)
    assert_not plan.can_be_regenerated?

    plan = campaign_plans(:generating_plan)
    assert_not plan.can_be_regenerated?
  end

  test "archive! should work correctly" do
    plan = campaign_plans(:completed_plan)
    assert plan.archive!
    plan.reload
    assert_equal "archived", plan.status

    plan = campaign_plans(:draft_plan)
    assert_not plan.archive!
    plan.reload
    assert_equal "draft", plan.status
  end

  test "mark_generation_started! should update status and metadata" do
    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      @campaign_plan.mark_generation_started!
      @campaign_plan.reload
      
      assert_equal "generating", @campaign_plan.status
      assert_not_nil @campaign_plan.metadata["generation_started_at"]
    end
  end

  test "mark_generation_completed! should update status and metadata" do
    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      @campaign_plan.metadata = { "generation_started_at" => Time.zone.parse("2025-01-15 09:58:00") }
      @campaign_plan.mark_generation_completed!
      @campaign_plan.reload
      
      assert_equal "completed", @campaign_plan.status
      assert_not_nil @campaign_plan.metadata["generation_completed_at"]
      assert_not_nil @campaign_plan.metadata["generation_duration"]
    end
  end

  test "mark_generation_failed! should update status and metadata" do
    error_message = "Test error"
    @campaign_plan.mark_generation_failed!(error_message)
    @campaign_plan.reload
    
    assert_equal "failed", @campaign_plan.status
    assert_equal error_message, @campaign_plan.metadata["error_message"]
    assert_not_nil @campaign_plan.metadata["generation_failed_at"]
  end

  test "scopes should work correctly" do
    # Test by_campaign_type
    product_launch_plans = CampaignPlan.by_campaign_type("product_launch")
    assert_includes product_launch_plans, campaign_plans(:draft_plan)

    # Test by_objective
    brand_awareness_plans = CampaignPlan.by_objective("brand_awareness")
    assert_includes brand_awareness_plans, campaign_plans(:draft_plan)

    # Test by_status
    draft_plans = CampaignPlan.by_status("draft")
    assert_includes draft_plans, campaign_plans(:draft_plan)

    # Test completed
    completed_plans = CampaignPlan.completed
    assert_includes completed_plans, campaign_plans(:completed_plan)
    assert_not_includes completed_plans, campaign_plans(:draft_plan)

    # Test recent (should order by created_at desc)
    recent_plans = CampaignPlan.recent
    assert_equal recent_plans.first.id, recent_plans.order(created_at: :desc).first.id
  end

  test "should belong to user" do
    assert_equal @user, @campaign_plan.user
  end

  test "should serialize JSON fields correctly" do
    plan = campaign_plans(:completed_plan)
    
    # Test strategy serialization
    assert plan.generated_strategy.is_a?(Hash)
    assert_includes plan.generated_strategy["phases"], "Discovery"
    
    # Test timeline serialization
    assert plan.generated_timeline.is_a?(Array)
    assert_equal 1, plan.generated_timeline.first["week"]
    
    # Test assets serialization
    assert plan.generated_assets.is_a?(Array)
    assert_includes plan.generated_assets, "Social media graphics"
    
    # Test metadata serialization
    assert plan.metadata.is_a?(Hash)
    assert_not_nil plan.metadata["generated_at"]
  end

  # Strategic fields tests
  test "strategic fields should serialize JSON correctly" do
    @campaign_plan.content_strategy = { key_themes: ["innovation", "trust"], approach: "multi-channel" }
    @campaign_plan.creative_approach = { style: "modern", tone: "professional" }
    @campaign_plan.strategic_rationale = { reasoning: "Market analysis supports this approach" }
    @campaign_plan.content_mapping = [{ platform: "LinkedIn", content_type: "article" }]
    @campaign_plan.save!

    @campaign_plan.reload
    assert @campaign_plan.content_strategy.is_a?(Hash)
    assert_equal "multi-channel", @campaign_plan.content_strategy["approach"]
    assert @campaign_plan.creative_approach.is_a?(Hash)
    assert_equal "professional", @campaign_plan.creative_approach["tone"]
    assert @campaign_plan.strategic_rationale.is_a?(Hash)
    assert @campaign_plan.content_mapping.is_a?(Array)
    assert_equal "LinkedIn", @campaign_plan.content_mapping.first["platform"]
  end

  test "has_generated_content should include strategic fields" do
    plan = CampaignPlan.new(
      user: @user,
      name: "Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    assert_not plan.has_generated_content?

    plan.content_strategy = { key_themes: ["innovation"] }
    assert plan.has_generated_content?

    plan.content_strategy = nil
    plan.creative_approach = { style: "modern" }
    assert plan.has_generated_content?

    plan.creative_approach = nil
    plan.strategic_rationale = { reasoning: "test" }
    assert plan.has_generated_content?

    plan.strategic_rationale = nil
    plan.content_mapping = [{ platform: "test" }]
    assert plan.has_generated_content?
  end

  test "generation_progress should include strategic fields in calculation" do
    plan = campaign_plans(:draft_plan)
    plan.status = "generating"
    assert_equal 0, plan.generation_progress

    # Add one strategic field (1/8 = 12.5%, rounded to 13%)
    plan.content_strategy = { key_themes: ["innovation"] }
    assert_equal 13, plan.generation_progress

    # Add another strategic field (2/8 = 25%)
    plan.creative_approach = { style: "modern" }
    assert_equal 25, plan.generation_progress

    # Add all fields (8/8 = 100%)
    plan.generated_summary = "Summary"
    plan.generated_strategy = { description: "Strategy" }
    plan.generated_timeline = [{ activity: "Timeline" }]
    plan.generated_assets = ["Asset"]
    plan.strategic_rationale = { reasoning: "Rationale" }
    plan.content_mapping = [{ platform: "Platform" }]
    assert_equal 100, plan.generation_progress
  end

  test "plan_analytics should include strategic fields in content_sections" do
    plan = CampaignPlan.new(
      user: @user,
      name: "Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    plan.content_strategy = { key_themes: ["innovation"] }
    plan.creative_approach = { style: "modern" }
    plan.strategic_rationale = { reasoning: "test" }
    plan.content_mapping = [{ platform: "test" }]
    
    analytics = plan.plan_analytics
    assert analytics[:content_sections][:content_strategy]
    assert analytics[:content_sections][:creative_approach]
    assert analytics[:content_sections][:strategic_rationale]
    assert analytics[:content_sections][:content_mapping]
  end

  # Collaboration workflow tests
  test "submit_for_approval! should update approval status and create version" do
    @campaign_plan.update!(
      status: "completed",
      generated_summary: "Test summary",
      generated_strategy: { description: "Strategy" }
    )
    
    assert_difference 'PlanVersion.count', 1 do
      assert_difference 'PlanAuditLog.count', 1 do
        @campaign_plan.submit_for_approval!(@user)
      end
    end
    
    @campaign_plan.reload
    assert_equal "pending_approval", @campaign_plan.approval_status
    assert_not_nil @campaign_plan.submitted_for_approval_at
    assert_not_nil @campaign_plan.current_version_id
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "submitted_for_approval", audit_log.action
    assert_equal @user, audit_log.user
  end

  test "approve! should update approval status and timestamps" do
    @campaign_plan.update!(approval_status: "pending_approval")
    approver = users(:admin_user)
    
    assert_difference 'PlanAuditLog.count', 1 do
      @campaign_plan.approve!(approver)
    end
    
    @campaign_plan.reload
    assert_equal "approved", @campaign_plan.approval_status
    assert_equal approver, @campaign_plan.approved_by
    assert_not_nil @campaign_plan.approved_at
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "approved", audit_log.action
    assert_equal approver, audit_log.user
  end

  test "reject! should update approval status with reason" do
    @campaign_plan.update!(approval_status: "pending_approval")
    approver = users(:admin_user)
    reason = "Content needs improvement"
    
    assert_difference 'PlanAuditLog.count', 1 do
      @campaign_plan.reject!(approver, reason)
    end
    
    @campaign_plan.reload
    assert_equal "rejected", @campaign_plan.approval_status
    assert_equal approver, @campaign_plan.rejected_by
    assert_equal reason, @campaign_plan.rejection_reason
    assert_not_nil @campaign_plan.rejected_at
    
    # Check audit log
    audit_log = PlanAuditLog.last
    assert_equal "rejected", audit_log.action
    assert_equal reason, audit_log.details["reason"]
  end

  test "create_version! should create snapshot with proper content" do
    @campaign_plan.update!(
      generated_summary: "Test summary",
      generated_strategy: { phases: ["Discovery"] },
      content_strategy: { themes: ["Innovation"] },
      target_audience: "Tech professionals"
    )
    
    assert_difference 'PlanVersion.count', 1 do
      version = @campaign_plan.create_version!(@user)
      
      assert_equal @campaign_plan, version.campaign_plan
      assert_equal @user, version.created_by
      assert_equal "Test summary", version.content["generated_summary"]
      assert_equal ["Discovery"], version.content["generated_strategy"]["phases"]
      assert_equal "Tech professionals", version.metadata["target_audience"]
      assert_equal version.id, @campaign_plan.reload.current_version_id
    end
  end

  test "create_version! with change summary should include it" do
    change_summary = "Updated strategic approach based on market research"
    
    version = @campaign_plan.create_version!(@user, change_summary)
    assert_equal change_summary, version.change_summary
  end

  # Approval workflow predicate tests
  test "can_be_submitted_for_approval? should work correctly" do
    # Draft plan with content can be submitted
    @campaign_plan.update!(
      status: "completed",
      generated_summary: "Summary",
      approval_status: "draft"
    )
    assert @campaign_plan.can_be_submitted_for_approval?
    
    # Already pending approval cannot be resubmitted
    @campaign_plan.update!(approval_status: "pending_approval")
    assert_not @campaign_plan.can_be_submitted_for_approval?
    
    # Already approved cannot be resubmitted
    @campaign_plan.update!(approval_status: "approved")
    assert_not @campaign_plan.can_be_submitted_for_approval?
    
    # Plan without content cannot be submitted
    @campaign_plan.update!(
      approval_status: "draft",
      generated_summary: nil,
      status: "draft"
    )
    assert_not @campaign_plan.can_be_submitted_for_approval?
  end

  test "needs_approval? should work correctly" do
    @campaign_plan.update!(approval_status: "pending_approval")
    assert @campaign_plan.needs_approval?
    
    @campaign_plan.update!(approval_status: "approved")
    assert_not @campaign_plan.needs_approval?
    
    @campaign_plan.update!(approval_status: "draft")
    assert_not @campaign_plan.needs_approval?
  end

  test "is_approved? should work correctly" do
    @campaign_plan.update!(approval_status: "approved")
    assert @campaign_plan.is_approved?
    
    @campaign_plan.update!(approval_status: "pending_approval")
    assert_not @campaign_plan.is_approved?
  end

  test "is_rejected? should work correctly" do
    @campaign_plan.update!(approval_status: "rejected")
    assert @campaign_plan.is_rejected?
    
    @campaign_plan.update!(approval_status: "approved")
    assert_not @campaign_plan.is_rejected?
  end

  # Association tests for collaboration features
  test "should have many plan_versions" do
    version1 = PlanVersion.create!(campaign_plan: @campaign_plan, created_by: @user)
    version2 = PlanVersion.create!(campaign_plan: @campaign_plan, created_by: @user)
    
    assert_includes @campaign_plan.plan_versions, version1
    assert_includes @campaign_plan.plan_versions, version2
  end

  test "should destroy dependent plan_versions" do
    # Create a fresh campaign plan to avoid fixture dependencies
    fresh_campaign = CampaignPlan.create!(
      user: @user,
      name: "Test Campaign for Destruction",
      description: "Test campaign description",
      target_audience: "Test audience",
      campaign_type: "brand_awareness",
      objective: "brand_awareness"
    )
    
    version = PlanVersion.create!(campaign_plan: fresh_campaign, created_by: @user)
    
    assert_difference 'PlanVersion.count', -1 do
      fresh_campaign.destroy
    end
  end

  test "should have many plan_audit_logs" do
    log1 = PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @user, action: "created")
    log2 = PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @user, action: "updated")
    
    assert_includes @campaign_plan.plan_audit_logs, log1
    assert_includes @campaign_plan.plan_audit_logs, log2
  end

  test "should destroy dependent plan_audit_logs" do
    # Create a fresh campaign plan to avoid fixture dependencies
    # This will automatically create one audit log via after_create callback
    fresh_campaign = CampaignPlan.create!(
      user: @user,
      name: "Test Campaign for Audit Logs",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    # Manually create an additional audit log
    log = PlanAuditLog.create!(campaign_plan: fresh_campaign, user: @user, action: "updated")
    
    # Should destroy both the automatically created audit log and the manually created one
    assert_difference 'PlanAuditLog.count', -2 do
      fresh_campaign.destroy
    end
  end

  test "should belong to approved_by and rejected_by users" do
    approver = users(:admin_user)
    @campaign_plan.update!(approved_by: approver)
    assert_equal approver, @campaign_plan.approved_by
    
    rejector = users(:team_member_user)
    @campaign_plan.update!(rejected_by: rejector)
    assert_equal rejector, @campaign_plan.rejected_by
  end

  test "current_version should return the current plan version" do
    version1 = PlanVersion.create!(campaign_plan: @campaign_plan, created_by: @user, is_current: false)
    version2 = PlanVersion.create!(campaign_plan: @campaign_plan, created_by: @user, is_current: true)
    
    @campaign_plan.update!(current_version_id: version2.id)
    assert_equal version2, @campaign_plan.current_version
  end

  # Feedback relationship tests
  test "feedback_comments should return all feedback through versions" do
    version1 = PlanVersion.create!(campaign_plan: @campaign_plan, created_by: @user)
    version2 = PlanVersion.create!(campaign_plan: @campaign_plan, created_by: @user)
    
    comment1 = FeedbackComment.create!(
      plan_version: version1,
      user: @user,
      content: "Feedback for version 1",
      comment_type: "general",
      priority: "medium"
    )
    
    comment2 = FeedbackComment.create!(
      plan_version: version2,
      user: @user,
      content: "Feedback for version 2",
      comment_type: "suggestion",
      priority: "high"
    )
    
    all_feedback = @campaign_plan.feedback_comments
    assert_includes all_feedback, comment1
    assert_includes all_feedback, comment2
  end

  # Audit trail tests
  test "should create audit log when campaign plan is created" do
    assert_difference 'PlanAuditLog.count', 1 do
      CampaignPlan.create!(
        user: @user,
        name: "New Campaign Plan",
        campaign_type: "brand_awareness",
        objective: "customer_acquisition"
      )
    end
    
    audit_log = PlanAuditLog.last
    assert_equal "created", audit_log.action
    assert_equal @user, audit_log.user
  end

  test "should create audit log when campaign plan is updated" do
    original_name = @campaign_plan.name
    
    assert_difference 'PlanAuditLog.count', 1 do
      @campaign_plan.update!(name: "Updated Campaign Name")
    end
    
    audit_log = PlanAuditLog.last
    assert_equal "updated", audit_log.action
    assert_includes audit_log.details["changed_fields"], "name"
    assert_equal [original_name, "Updated Campaign Name"], audit_log.details["changes"]["name"]
  end

  # Competitive Analysis Tests
  test "should serialize competitive analysis JSON fields" do
    competitive_data = {
      "competitive_advantages" => ["advantage1", "advantage2"],
      "market_threats" => ["threat1", "threat2"]
    }
    
    @campaign_plan.competitive_intelligence = competitive_data
    @campaign_plan.save!
    @campaign_plan.reload
    
    assert_equal competitive_data, @campaign_plan.competitive_intelligence
  end

  test "has_competitive_data? should return false when no competitive data" do
    @campaign_plan.competitive_intelligence = nil
    @campaign_plan.market_research_data = nil
    @campaign_plan.competitor_analysis = nil
    @campaign_plan.industry_benchmarks = nil
    
    assert_not @campaign_plan.has_competitive_data?
  end

  test "has_competitive_data? should return true when any competitive data present" do
    @campaign_plan.competitive_intelligence = { "data" => "test" }
    
    assert @campaign_plan.has_competitive_data?
  end

  test "competitive_analysis_stale? should return true when never updated" do
    @campaign_plan.competitive_analysis_last_updated_at = nil
    
    assert @campaign_plan.competitive_analysis_stale?
  end

  test "competitive_analysis_stale? should return true when updated more than 7 days ago" do
    @campaign_plan.competitive_analysis_last_updated_at = 8.days.ago
    
    assert @campaign_plan.competitive_analysis_stale?
  end

  test "competitive_analysis_stale? should return false when updated recently" do
    @campaign_plan.competitive_analysis_last_updated_at = 3.days.ago
    
    assert_not @campaign_plan.competitive_analysis_stale?
  end

  test "parsed_competitive_intelligence should return parsed JSON" do
    intelligence_data = {
      "competitive_advantages" => ["advantage1"],
      "market_threats" => ["threat1"]
    }
    
    @campaign_plan.competitive_intelligence = intelligence_data
    
    assert_equal intelligence_data, @campaign_plan.parsed_competitive_intelligence
  end

  test "parsed_competitive_intelligence should return empty hash for nil data" do
    @campaign_plan.competitive_intelligence = nil
    
    assert_equal({}, @campaign_plan.parsed_competitive_intelligence)
  end

  test "competitive_analysis_summary should include all competitive data" do
    @campaign_plan.competitive_intelligence = { "advantages" => ["test"] }
    @campaign_plan.market_research_data = { "trends" => ["trend1"] }
    @campaign_plan.competitor_analysis = { "competitors" => ["comp1"] }
    @campaign_plan.industry_benchmarks = { "metrics" => ["metric1"] }
    @campaign_plan.competitive_analysis_last_updated_at = Time.current
    
    summary = @campaign_plan.competitive_analysis_summary
    
    assert_includes summary.keys, :competitive_intelligence
    assert_includes summary.keys, :market_research
    assert_includes summary.keys, :competitor_data
    assert_includes summary.keys, :industry_benchmarks
    assert_includes summary.keys, :last_updated
    assert_includes summary.keys, :is_stale
  end

  test "top_competitors should return sorted competitors by market share" do
    competitor_data = {
      "competitors" => [
        { "name" => "Competitor A", "market_share" => 15 },
        { "name" => "Competitor B", "market_share" => 25 },
        { "name" => "Competitor C", "market_share" => 10 }
      ]
    }
    
    @campaign_plan.competitor_analysis = competitor_data
    
    top_competitors = @campaign_plan.top_competitors
    
    assert_equal 3, top_competitors.length
    assert_equal "Competitor B", top_competitors.first["name"]
    assert_equal 25, top_competitors.first["market_share"]
  end

  test "key_market_insights should extract insights from market research" do
    market_data = {
      "market_trends" => ["trend1", "trend2"],
      "consumer_insights" => ["insight1"],
      "growth_opportunities" => ["opportunity1", "opportunity2"]
    }
    
    @campaign_plan.market_research_data = market_data
    
    insights = @campaign_plan.key_market_insights
    
    assert_equal 5, insights.length
    assert_includes insights, "trend1"
    assert_includes insights, "insight1"
    assert_includes insights, "opportunity1"
  end

  test "competitive_advantages should extract advantages from intelligence data" do
    intelligence_data = {
      "competitive_advantages" => ["advantage1", "advantage2", "advantage3"]
    }
    
    @campaign_plan.competitive_intelligence = intelligence_data
    
    advantages = @campaign_plan.competitive_advantages
    
    assert_equal 3, advantages.length
    assert_includes advantages, "advantage1"
  end

  test "market_threats should extract threats from intelligence data" do
    intelligence_data = {
      "market_threats" => ["threat1", "threat2"]
    }
    
    @campaign_plan.competitive_intelligence = intelligence_data
    
    threats = @campaign_plan.market_threats
    
    assert_equal 2, threats.length
    assert_includes threats, "threat1"
  end

  # Scopes tests
  test "with_competitive_analysis scope should find plans with competitive data" do
    plan_with_data = campaign_plans(:draft_plan)
    plan_with_data.update!(competitive_intelligence: { "data" => "test" })
    
    plan_without_data = campaign_plans(:generating_plan)
    plan_without_data.update!(competitive_intelligence: nil)
    
    plans_with_data = CampaignPlan.with_competitive_analysis
    
    assert_includes plans_with_data, plan_with_data
    assert_not_includes plans_with_data, plan_without_data
  end

  test "competitive_analysis_stale scope should find stale plans" do
    stale_plan = campaign_plans(:draft_plan)
    stale_plan.update!(competitive_analysis_last_updated_at: 8.days.ago)
    
    fresh_plan = campaign_plans(:generating_plan)
    fresh_plan.update!(competitive_analysis_last_updated_at: 2.days.ago)
    
    stale_plans = CampaignPlan.competitive_analysis_stale
    
    assert_includes stale_plans, stale_plan
    assert_not_includes stale_plans, fresh_plan
  end

  test "needs_competitive_analysis scope should find plans never analyzed" do
    never_analyzed = campaign_plans(:draft_plan)
    never_analyzed.update!(competitive_analysis_last_updated_at: nil)
    
    previously_analyzed = campaign_plans(:generating_plan)
    previously_analyzed.update!(competitive_analysis_last_updated_at: 1.day.ago)
    
    needs_analysis = CampaignPlan.needs_competitive_analysis
    
    assert_includes needs_analysis, never_analyzed
    assert_not_includes needs_analysis, previously_analyzed
  end
end