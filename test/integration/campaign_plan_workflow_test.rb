require "test_helper"

class CampaignPlanWorkflowTest < ActionDispatch::IntegrationTest

  def setup
    @user = users(:marketer_user)
    sign_in_as(@user)
  end

  test "complete campaign plan creation and generation workflow" do
    # Step 1: Visit campaign plans index
    get campaign_plans_path
    assert_response :success
    assert_select "h1", "Campaign Plans"

    # Step 2: Create a new campaign plan
    get new_campaign_plan_path
    assert_response :success
    assert_select "h1", "Create Campaign Plan"

    # Step 3: Submit campaign plan form
    assert_difference("CampaignPlan.count") do
      post campaign_plans_path, params: {
        campaign_plan: {
          name: "Integration Test Campaign",
          description: "A comprehensive test campaign for integration testing",
          campaign_type: "product_launch",
          objective: "brand_awareness",
          target_audience: "Tech professionals and early adopters",
          budget_constraints: "Budget: $25,000 over 2 months",
          timeline_constraints: "Launch by end of Q1"
        }
      }
    end

    campaign_plan = CampaignPlan.last
    assert_redirected_to campaign_plan_path(campaign_plan)
    follow_redirect!

    # Step 4: View the created campaign plan
    assert_response :success
    assert_select "h1", "Integration Test Campaign"
    assert_match /Draft/i, response.body
    assert_select "a[href='#{generate_campaign_plan_path(campaign_plan)}']", "Generate Plan"

    # Step 5: Generate the campaign plan
    # Mock the LLM service response
    mock_response = {
      summary: "Comprehensive product launch targeting tech professionals with multi-channel approach",
      strategy: {
        phases: ["Pre-launch buzz", "Launch event", "Post-launch nurturing"],
        channels: ["Social Media", "Email Marketing", "Content Marketing", "PR"],
        budget_allocation: { social: 35, email: 25, content: 25, pr: 15 }
      },
      timeline: [
        { week: 1, activity: "Brand messaging and content creation" },
        { week: 2, activity: "Influencer partnerships and PR outreach" },
        { week: 3, activity: "Soft launch and early access program" },
        { week: 4, activity: "Full product launch and media campaign" },
        { week: 5, activity: "Post-launch optimization and analysis" }
      ],
      assets: [
        "Brand messaging framework",
        "Social media content calendar (8 weeks)",
        "Email automation sequences (3 flows)",
        "Landing page copy and design",
        "Press release and media kit",
        "Influencer collaboration guidelines"
      ],
      metadata: { service: "mock", generated_at: Time.current }
    }

    CampaignPlanService.any_instance.expects(:generate_plan).returns({
      success: true,
      message: "Campaign plan generated successfully",
      data: campaign_plan
    }).at_least_once

    # Call the generation endpoint while plan is still in draft status
    post generate_campaign_plan_path(campaign_plan)
    assert_redirected_to campaign_plan_path(campaign_plan)
    follow_redirect!

    # Simulate the generation process after the call
    campaign_plan.update!(
      status: "generating",
      metadata: { generation_started_at: Time.current }
    )

    # Step 6: Simulate completion of generation
    campaign_plan.update!(
      status: "completed",
      generated_summary: mock_response[:summary],
      generated_strategy: mock_response[:strategy],
      generated_timeline: mock_response[:timeline],
      generated_assets: mock_response[:assets],
      metadata: campaign_plan.metadata.merge(
        generation_completed_at: Time.current,
        generation_duration: 45.seconds
      )
    )

    # Step 7: View the completed campaign plan
    get campaign_plan_path(campaign_plan)
    assert_response :success
    
    # Verify generated content is displayed
    assert_match mock_response[:summary], response.body
    assert_match "Pre-launch buzz", response.body
    assert_match "Launch event", response.body
    assert_match "Social Media", response.body
    assert_match "Email Marketing", response.body
    assert_match "Brand messaging framework", response.body
    assert_match "Social media content calendar", response.body
    
    # Verify status is completed
    assert_match "Completed", response.body
    assert_select "a[href='#{regenerate_campaign_plan_path(campaign_plan)}']", "Regenerate"

    # Step 8: Test editing the campaign plan
    get edit_campaign_plan_path(campaign_plan)
    assert_response :success
    assert_select "input[value='Integration Test Campaign']"

    patch campaign_plan_path(campaign_plan), params: {
      campaign_plan: {
        description: "Updated comprehensive test campaign for integration testing",
        target_audience: "Tech professionals, early adopters, and innovation leaders"
      }
    }
    assert_redirected_to campaign_plan_path(campaign_plan)
    follow_redirect!

    campaign_plan.reload
    assert_equal "Updated comprehensive test campaign for integration testing", campaign_plan.description
    assert_equal "Tech professionals, early adopters, and innovation leaders", campaign_plan.target_audience

    # Step 9: Test regeneration workflow
    CampaignPlanService.any_instance.expects(:regenerate_plan).returns({
      success: true,
      message: "Campaign plan regenerated successfully",
      data: campaign_plan
    })

    post regenerate_campaign_plan_path(campaign_plan)
    assert_redirected_to campaign_plan_path(campaign_plan)
    follow_redirect!

    # Step 10: Test archiving
    patch archive_campaign_plan_path(campaign_plan)
    assert_redirected_to campaign_plans_path
    follow_redirect!

    campaign_plan.reload
    assert_equal "archived", campaign_plan.status

    # Step 11: Verify archived plan appears in index
    assert_response :success
    assert_match "Integration Test Campaign", response.body
    assert_match "Archived", response.body
  end

  test "campaign plan filtering and search workflow" do
    # Create multiple campaign plans with different attributes
    plans = [
      CampaignPlan.create!(
        user: @user,
        name: "Product Launch Alpha",
        campaign_type: "product_launch",
        objective: "brand_awareness",
        status: "draft"
      ),
      CampaignPlan.create!(
        user: @user,
        name: "Brand Awareness Beta",
        campaign_type: "brand_awareness",
        objective: "customer_acquisition",
        status: "completed"
      ),
      CampaignPlan.create!(
        user: @user,
        name: "Lead Generation Gamma",
        campaign_type: "lead_generation",
        objective: "lead_generation",
        status: "failed"
      )
    ]

    # Test campaign type filtering
    get campaign_plans_path, params: { campaign_type: "product_launch" }
    assert_response :success
    assert_match "Product Launch Alpha", response.body
    assert_no_match "Brand Awareness Beta", response.body
    assert_no_match "Lead Generation Gamma", response.body

    # Test objective filtering
    get campaign_plans_path, params: { objective: "customer_acquisition" }
    assert_response :success
    assert_match "Brand Awareness Beta", response.body
    assert_no_match "Product Launch Alpha", response.body
    assert_no_match "Lead Generation Gamma", response.body

    # Test status filtering
    get campaign_plans_path, params: { status: "completed" }
    assert_response :success
    assert_match "Brand Awareness Beta", response.body
    assert_no_match "Product Launch Alpha", response.body
    assert_no_match "Lead Generation Gamma", response.body

    # Test search functionality
    get campaign_plans_path, params: { search: "Alpha" }
    assert_response :success
    assert_match "Product Launch Alpha", response.body
    assert_no_match "Brand Awareness Beta", response.body
    assert_no_match "Lead Generation Gamma", response.body

    # Test combined filters
    get campaign_plans_path, params: { 
      campaign_type: "brand_awareness", 
      status: "completed" 
    }
    assert_response :success
    assert_match "Brand Awareness Beta", response.body
    assert_no_match "Product Launch Alpha", response.body
    assert_no_match "Lead Generation Gamma", response.body

    # Test clearing filters
    get campaign_plans_path
    assert_response :success
    # Should show all plans
    assert_match "Product Launch Alpha", response.body
    assert_match "Brand Awareness Beta", response.body
    assert_match "Lead Generation Gamma", response.body
  end

  test "campaign plan error handling workflow" do
    # Create a campaign plan
    campaign_plan = CampaignPlan.create!(
      user: @user,
      name: "Error Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      status: "draft"
    )

    # Test generation failure
    CampaignPlanService.any_instance.expects(:generate_plan).returns({
      success: false,
      message: "Service temporarily unavailable"
    })

    post generate_campaign_plan_path(campaign_plan)
    assert_redirected_to campaign_plan_path(campaign_plan)
    assert_equal "Service temporarily unavailable", flash[:alert]

    # Test invalid form submission
    patch campaign_plan_path(campaign_plan), params: {
      campaign_plan: {
        name: "", # Required field
        campaign_type: "invalid_type"
      }
    }
    assert_response :unprocessable_entity
    assert_select "h3", "Please fix the following errors:"

    # Test access to non-existent campaign plan
    get campaign_plan_path(id: 999999)
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]
  end

  test "campaign plan permissions workflow" do
    # Use existing other user's campaign plan from fixtures
    other_user = users(:team_member_user)
    other_plan = campaign_plans(:other_user_plan)

    # Try to access other user's campaign plan
    get campaign_plan_path(other_plan)
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]

    # Try to edit other user's campaign plan
    get edit_campaign_plan_path(other_plan)
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]

    # Try to update other user's campaign plan
    patch campaign_plan_path(other_plan), params: {
      campaign_plan: { name: "Hacked Name" }
    }
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]

    other_plan.reload
    assert_not_equal "Hacked Name", other_plan.name

    # Try to delete other user's campaign plan
    assert_no_difference("CampaignPlan.count") do
      delete campaign_plan_path(other_plan)
    end
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]
  end

  test "campaign plan with brand identity integration workflow" do
    # Create a brand identity for the user
    brand_identity = brand_identities(:active_brand)
    brand_identity.update!(
      user: @user,
      is_active: true,
      name: "TechCorp",
      brand_voice: "innovative and approachable",
      tone_guidelines: "Professional yet friendly"
    )

    # Create new campaign plan
    get new_campaign_plan_path
    assert_response :success
    
    # Should have brand context pre-populated
    assert_match "TechCorp", response.body

    # Create the campaign plan
    post campaign_plans_path, params: {
      campaign_plan: {
        name: "Brand Integration Test",
        campaign_type: "product_launch",
        objective: "brand_awareness",
        target_audience: "Enterprise customers"
      }
    }

    campaign_plan = CampaignPlan.last
    assert_redirected_to campaign_plan_path(campaign_plan)

    # Verify brand context was integrated
    brand_context = JSON.parse(campaign_plan.brand_context) rescue {}
    assert_equal "TechCorp", brand_context["brand_name"]
    assert_equal "innovative and approachable", brand_context["brand_voice"]
  end
end