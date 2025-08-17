require "test_helper"

class StrategicCampaignPlanningTest < ActionDispatch::IntegrationTest
  include Mocha::API
  
  def setup
    @user = users(:marketer_user)
    sign_in_as(@user)
  end

  test "complete strategic campaign planning workflow" do
    # Create a new campaign plan
    post campaign_plans_url, params: {
      campaign_plan: {
        name: "Strategic Test Campaign",
        description: "Test strategic planning",
        campaign_type: "product_launch", 
        objective: "brand_awareness",
        target_audience: "Tech professionals"
      }
    }
    
    campaign_plan = CampaignPlan.last
    assert_redirected_to campaign_plan_url(campaign_plan)
    follow_redirect!
    assert_response :success
    assert_select "h1", "Strategic Test Campaign"
    
    # Mock LLM service with strategic elements
    mock_llm_response = {
      summary: "Strategic campaign summary",
      strategy: { phases: ["Planning", "Execution"] },
      timeline: [{ week: 1, activity: "Research" }],
      assets: ["Graphics"],
      content_strategy: { 
        themes: ["innovation", "trust"],
        approach: "multi-channel",
        messaging_pillars: ["expertise", "reliability"]
      },
      creative_approach: { 
        style: "modern", 
        tone: "professional",
        visual_identity: "clean_minimal"
      },
      strategic_rationale: { 
        reasoning: "Data-driven approach based on market analysis",
        target_alignment: "Resonates with tech professionals"
      },
      content_mapping: [
        { platform: "LinkedIn", content_type: "article", frequency: "weekly" },
        { platform: "Twitter", content_type: "thread", frequency: "bi-weekly" }
      ]
    }
    
    # Mock the service at class level
    service = CampaignPlanService.new(campaign_plan)
    service.stubs(:llm_service).returns(stub(generate_campaign_plan: mock_llm_response))
    CampaignPlanService.stubs(:new).returns(service)
    
    # Generate the campaign plan
    post generate_campaign_plan_url(campaign_plan)
    assert_redirected_to campaign_plan_url(campaign_plan)
    follow_redirect!
    
    # Verify strategic elements were saved
    campaign_plan.reload
    assert_equal "completed", campaign_plan.status
    assert_not_nil campaign_plan.content_strategy
    assert_not_nil campaign_plan.creative_approach
    assert_not_nil campaign_plan.strategic_rationale
    assert_not_nil campaign_plan.content_mapping
    
    # Verify specific strategic content
    assert_equal "multi-channel", campaign_plan.content_strategy["approach"]
    assert_includes campaign_plan.content_strategy["themes"], "innovation"
    assert_equal "professional", campaign_plan.creative_approach["tone"]
    assert_equal "LinkedIn", campaign_plan.content_mapping.first["platform"]
    
    # View the completed plan
    get campaign_plan_url(campaign_plan)
    assert_response :success
    assert_select "h1", "Strategic Test Campaign"
    
    # Verify generation progress shows 100% (all 8 fields completed)
    assert_equal 100, campaign_plan.generation_progress
  end

  test "regenerate campaign with strategic elements workflow" do
    completed_plan = campaign_plans(:completed_plan)
    original_strategy = completed_plan.content_strategy
    
    # Mock new LLM response for regeneration
    new_mock_response = {
      summary: "Regenerated strategic campaign",
      strategy: { phases: ["New Phase"] },
      timeline: [{ week: 1, activity: "New Activity" }],
      assets: ["New Graphics"],
      content_strategy: { 
        themes: ["sustainability", "innovation"],
        approach: "omnichannel",
        focus: "environmental impact"
      },
      creative_approach: { 
        style: "minimalist", 
        tone: "confident",
        color_palette: "earth_tones"
      },
      strategic_rationale: { 
        reasoning: "Updated market analysis shows growing sustainability focus",
        competitive_advantage: "First-mover in eco-friendly approach"
      },
      content_mapping: [
        { platform: "Instagram", content_type: "story", frequency: "daily" },
        { platform: "YouTube", content_type: "video", frequency: "weekly" }
      ]
    }
    
    service = CampaignPlanService.new(completed_plan)
    service.stubs(:llm_service).returns(stub(generate_campaign_plan: new_mock_response))
    CampaignPlanService.stubs(:new).returns(service)
    
    # Visit the completed plan page
    get campaign_plan_url(completed_plan)
    assert_response :success
    
    # Regenerate the plan
    post regenerate_campaign_plan_url(completed_plan)
    assert_redirected_to campaign_plan_url(completed_plan)
    follow_redirect!
    
    completed_plan.reload
    # Verify strategic fields were updated
    assert_not_equal original_strategy, completed_plan.content_strategy
    assert_includes completed_plan.content_strategy["themes"], "sustainability"
    assert_equal "minimalist", completed_plan.creative_approach["style"]
    assert_equal "Instagram", completed_plan.content_mapping.first["platform"]
    assert_includes completed_plan.strategic_rationale["reasoning"], "Updated market analysis"
  end

  test "strategic planning workflow with service errors" do
    # Create a campaign plan
    post campaign_plans_url, params: {
      campaign_plan: {
        name: "Error Test Campaign",
        campaign_type: "brand_awareness",
        objective: "customer_acquisition"
      }
    }
    
    campaign_plan = CampaignPlan.last
    
    # Mock LLM service to raise an error
    service = CampaignPlanService.new(campaign_plan)
    service.stubs(:llm_service).raises(StandardError.new("Service temporarily unavailable"))
    CampaignPlanService.stubs(:new).returns(service)
    
    # Attempt to generate the plan
    post generate_campaign_plan_url(campaign_plan)
    assert_redirected_to campaign_plan_url(campaign_plan)
    follow_redirect!
    
    # Verify campaign plan is marked as failed
    campaign_plan.reload
    assert_equal "failed", campaign_plan.status
    assert_nil campaign_plan.content_strategy
    assert_nil campaign_plan.creative_approach
    assert_nil campaign_plan.strategic_rationale
    assert_nil campaign_plan.content_mapping
  end

  test "strategic planning workflow with partial LLM response" do
    # Create a campaign plan
    post campaign_plans_url, params: {
      campaign_plan: {
        name: "Partial Response Test",
        campaign_type: "lead_generation",
        objective: "lead_generation"
      }
    }
    
    campaign_plan = CampaignPlan.last
    
    # Mock LLM service with partial strategic elements (missing some fields)
    partial_mock_response = {
      summary: "Partial strategic campaign",
      strategy: { phases: ["Phase 1"] },
      timeline: [{ week: 1, activity: "Activity" }],
      assets: ["Asset"],
      content_strategy: { themes: ["lead_gen"] },
      creative_approach: { style: "corporate" }
      # Missing strategic_rationale and content_mapping
    }
    
    service = CampaignPlanService.new(campaign_plan)
    service.stubs(:llm_service).returns(stub(generate_campaign_plan: partial_mock_response))
    CampaignPlanService.stubs(:new).returns(service)
    
    # Generate the campaign plan
    post generate_campaign_plan_url(campaign_plan)
    assert_redirected_to campaign_plan_url(campaign_plan)
    
    campaign_plan.reload
    assert_equal "completed", campaign_plan.status
    
    # Verify partial strategic content was saved
    assert_not_nil campaign_plan.content_strategy
    assert_not_nil campaign_plan.creative_approach
    assert_nil campaign_plan.strategic_rationale
    assert_nil campaign_plan.content_mapping
    
    # Progress should reflect 6 out of 8 fields completed (75%)
    assert_equal 75, campaign_plan.generation_progress
  end

  test "view strategic campaign plan without authentication should redirect" do
    # Sign out
    delete session_url
    
    campaign_plan = campaign_plans(:completed_plan)
    
    # Try to access the campaign plan
    get campaign_plan_url(campaign_plan)
    assert_redirected_to new_session_url
  end

  test "user cannot access other user's strategic campaign plan" do
    other_user = users(:team_member_user)
    other_campaign = campaign_plans(:other_user_plan)
    
    # Try to access other user's plan
    get campaign_plan_url(other_campaign)
    assert_redirected_to campaign_plans_path
    assert_equal "You can only access your own campaign plans.", flash[:alert]
  end

  test "strategic campaign planning analytics display workflow" do
    completed_plan = campaign_plans(:completed_plan)
    
    # Visit the campaign plan page
    get campaign_plan_url(completed_plan)
    assert_response :success
    
    # The show action calls plan_analytics which includes strategic fields
    analytics = completed_plan.plan_analytics
    
    # Verify analytics include strategic field status
    assert analytics[:content_sections][:content_strategy]
    assert analytics[:content_sections][:creative_approach]
    assert analytics[:content_sections][:strategic_rationale]
    assert analytics[:content_sections][:content_mapping]
    
    # Verify generation progress is accurate
    assert_equal 100, analytics[:generation_progress]
  end
end