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
end