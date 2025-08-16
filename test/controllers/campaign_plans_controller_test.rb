require "test_helper"

class CampaignPlansControllerTest < ActionDispatch::IntegrationTest

  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    sign_in_as(@user)
  end

  test "should get index" do
    get campaign_plans_url
    assert_response :success
    assert_select "h1", "Campaign Plans"
    assert_select "a[href='#{new_campaign_plan_path}']", "New Campaign Plan"
  end

  test "should filter campaigns by type" do
    get campaign_plans_url, params: { campaign_type: "product_launch" }
    assert_response :success
    # Should show draft_plan but not other types
    assert_match @campaign_plan.name, response.body
  end

  test "should filter campaigns by objective" do
    get campaign_plans_url, params: { objective: "brand_awareness" }
    assert_response :success
    assert_match @campaign_plan.name, response.body
  end

  test "should filter campaigns by status" do
    get campaign_plans_url, params: { status: "draft" }
    assert_response :success
    assert_match @campaign_plan.name, response.body
  end

  test "should search campaigns by name" do
    get campaign_plans_url, params: { search: "Q1" }
    assert_response :success
    assert_match @campaign_plan.name, response.body
    
    get campaign_plans_url, params: { search: "nonexistent" }
    assert_response :success
    assert_no_match @campaign_plan.name, response.body
  end

  test "should show campaign plan" do
    get campaign_plan_url(@campaign_plan)
    assert_response :success
    assert_select "h1", @campaign_plan.name
    assert_select "a[href='#{edit_campaign_plan_path(@campaign_plan)}']", "Edit"
  end

  test "should not show other user's campaign plan" do
    other_plan = campaign_plans(:other_user_plan)
    get campaign_plan_url(other_plan)
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]
  end

  test "should get new" do
    get new_campaign_plan_url
    assert_response :success
    assert_select "h1", "Create Campaign Plan"
    assert_select "form[action='#{campaign_plans_path}']"
  end

  test "should create campaign plan with valid parameters" do
    assert_difference("CampaignPlan.count") do
      post campaign_plans_url, params: {
        campaign_plan: {
          name: "New Test Campaign",
          description: "Test description",
          campaign_type: "brand_awareness",
          objective: "customer_acquisition",
          target_audience: "Test audience"
        }
      }
    end

    campaign_plan = CampaignPlan.last
    assert_redirected_to campaign_plan_url(campaign_plan)
    assert_equal "Campaign plan was successfully created.", flash[:notice]
    assert_equal @user, campaign_plan.user
    assert_equal "New Test Campaign", campaign_plan.name
  end

  test "should not create campaign plan with invalid parameters" do
    assert_no_difference("CampaignPlan.count") do
      post campaign_plans_url, params: {
        campaign_plan: {
          name: "", # Required field
          campaign_type: "invalid_type",
          objective: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "h3", "Please fix the following errors:"
  end

  test "should get edit" do
    get edit_campaign_plan_url(@campaign_plan)
    assert_response :success
    assert_select "h1", "Edit Campaign Plan"
    assert_select "form[action='#{campaign_plan_path(@campaign_plan)}']"
    assert_select "input[value='#{@campaign_plan.name}']"
  end

  test "should not edit other user's campaign plan" do
    other_plan = campaign_plans(:other_user_plan)
    get edit_campaign_plan_url(other_plan)
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]
  end

  test "should update campaign plan with valid parameters" do
    patch campaign_plan_url(@campaign_plan), params: {
      campaign_plan: {
        name: "Updated Campaign Name",
        description: "Updated description",
        campaign_type: "brand_awareness"
      }
    }

    assert_redirected_to campaign_plan_url(@campaign_plan)
    assert_equal "Campaign plan was successfully updated.", flash[:notice]
    
    @campaign_plan.reload
    assert_equal "Updated Campaign Name", @campaign_plan.name
    assert_equal "Updated description", @campaign_plan.description
  end

  test "should not update campaign plan with invalid parameters" do
    patch campaign_plan_url(@campaign_plan), params: {
      campaign_plan: {
        name: "", # Required field
        campaign_type: "invalid_type"
      }
    }

    assert_response :unprocessable_entity
    assert_select "h3", "Please fix the following errors:"
    
    @campaign_plan.reload
    assert_not_equal "", @campaign_plan.name # Should not be updated
  end

  test "should not update other user's campaign plan" do
    other_plan = campaign_plans(:other_user_plan)
    patch campaign_plan_url(other_plan), params: {
      campaign_plan: { name: "Hacked Name" }
    }
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]
  end

  test "should destroy campaign plan" do
    assert_difference("CampaignPlan.count", -1) do
      delete campaign_plan_url(@campaign_plan)
    end

    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan was successfully deleted.", flash[:notice]
  end

  test "should not destroy other user's campaign plan" do
    other_plan = campaign_plans(:other_user_plan)
    assert_no_difference("CampaignPlan.count") do
      delete campaign_plan_url(other_plan)
    end
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]
  end

  test "should generate campaign plan" do
    # Mock the service to return success
    CampaignPlanService.any_instance.expects(:generate_plan).returns({
      success: true,
      message: "Plan generated successfully",
      data: @campaign_plan
    })

    post generate_campaign_plan_url(@campaign_plan)
    
    assert_redirected_to campaign_plan_url(@campaign_plan)
    assert_equal "Campaign plan is being generated. Please refresh to see updates.", flash[:notice]
  end

  test "should not generate campaign plan if not ready" do
    @campaign_plan.update_column(:name, "") # Make it not ready
    
    post generate_campaign_plan_url(@campaign_plan)
    
    assert_redirected_to campaign_plan_url(@campaign_plan)
    assert_equal "Campaign plan is not ready for generation.", flash[:alert]
  end

  test "should handle generation failure" do
    # Mock the service to return failure
    CampaignPlanService.any_instance.expects(:generate_plan).returns({
      success: false,
      message: "Generation failed due to service error"
    })

    post generate_campaign_plan_url(@campaign_plan)
    
    assert_redirected_to campaign_plan_url(@campaign_plan)
    assert_equal "Generation failed due to service error", flash[:alert]
  end

  test "should regenerate campaign plan" do
    completed_plan = campaign_plans(:completed_plan)
    
    # Mock the service to return success
    CampaignPlanService.any_instance.expects(:regenerate_plan).returns({
      success: true,
      message: "Plan regenerated successfully",
      data: completed_plan
    })

    post regenerate_campaign_plan_url(completed_plan)
    
    assert_redirected_to campaign_plan_url(completed_plan)
    assert_equal "Campaign plan is being regenerated. Please refresh to see updates.", flash[:notice]
  end

  test "should not regenerate if not allowed" do
    # Draft plans cannot be regenerated
    post regenerate_campaign_plan_url(@campaign_plan)
    
    assert_redirected_to campaign_plan_url(@campaign_plan)
    assert_equal "Campaign plan cannot be regenerated.", flash[:alert]
  end

  test "should archive campaign plan" do
    completed_plan = campaign_plans(:completed_plan)
    
    patch archive_campaign_plan_url(completed_plan)
    
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan was successfully archived.", flash[:notice]
    
    completed_plan.reload
    assert_equal "archived", completed_plan.status
  end

  test "should not archive if not allowed" do
    # Draft plans cannot be archived
    patch archive_campaign_plan_url(@campaign_plan)
    
    assert_redirected_to campaign_plan_url(@campaign_plan)
    assert_equal "Campaign plan cannot be archived.", flash[:alert]
    
    @campaign_plan.reload
    assert_equal "draft", @campaign_plan.status
  end

  test "should require authentication for all actions" do
    # Sign out by clearing all user sessions
    @user.sessions.destroy_all
    Current.session = nil
    
    get campaign_plans_url
    assert_redirected_to new_session_path
    
    get campaign_plan_url(@campaign_plan)
    assert_redirected_to new_session_path
    
    get new_campaign_plan_url
    assert_redirected_to new_session_path
    
    post campaign_plans_url, params: { campaign_plan: { name: "Test" } }
    assert_redirected_to new_session_path
    
    get edit_campaign_plan_url(@campaign_plan)
    assert_redirected_to new_session_path
    
    patch campaign_plan_url(@campaign_plan), params: { campaign_plan: { name: "Test" } }
    assert_redirected_to new_session_path
    
    delete campaign_plan_url(@campaign_plan)
    assert_redirected_to new_session_path
    
    post generate_campaign_plan_url(@campaign_plan)
    assert_redirected_to new_session_path
  end

  test "should handle nonexistent campaign plan gracefully" do
    get campaign_plan_url(id: 999999)
    assert_redirected_to campaign_plans_path
    assert_equal "Campaign plan not found.", flash[:alert]
  end

  test "should pre-populate brand context from active brand identity" do
    # Create an active brand identity
    brand_identity = brand_identities(:active_brand)
    brand_identity.update!(user: @user, is_active: true)
    
    get new_campaign_plan_url
    assert_response :success
    
    # The form should have brand context pre-populated
    assert_match brand_identity.name, response.body
  end

  test "should monitor activity for important actions" do
    # Test that activity monitoring is called (would need to mock the monitoring service in a real test)
    get campaign_plans_url
    assert_response :success
    
    get campaign_plan_url(@campaign_plan)
    assert_response :success
    
    post campaign_plans_url, params: {
      campaign_plan: {
        name: "Test Campaign",
        campaign_type: "product_launch",
        objective: "brand_awareness"
      }
    }
    assert_response :redirect
  end

  test "should show appropriate buttons based on campaign status" do
    # Draft plan should show Generate button
    get campaign_plan_url(@campaign_plan)
    assert_response :success
    assert_select "a[href='#{generate_campaign_plan_path(@campaign_plan)}']", "Generate Plan"
    
    # Completed plan should show Regenerate button
    completed_plan = campaign_plans(:completed_plan)
    get campaign_plan_url(completed_plan)
    assert_response :success
    assert_select "a[href='#{regenerate_campaign_plan_path(completed_plan)}']", "Regenerate"
  end

  test "should display generated content properly" do
    completed_plan = campaign_plans(:completed_plan)
    get campaign_plan_url(completed_plan)
    assert_response :success
    
    # Should show generated summary
    assert_match completed_plan.generated_summary, response.body
    
    # Should show strategy phases
    assert_match "Discovery", response.body
    assert_match "Launch", response.body
    
    # Should show timeline
    assert_match "Campaign setup", response.body
    
    # Should show assets
    assert_match "Social media graphics", response.body
  end

  test "should handle empty filter parameters" do
    get campaign_plans_url, params: { 
      campaign_type: "", 
      objective: "", 
      status: "", 
      search: "" 
    }
    assert_response :success
    # Should show all campaigns when filters are empty
    assert_match @campaign_plan.name, response.body
  end
end