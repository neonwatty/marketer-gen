require "test_helper"

class SharedCampaignPlansControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:completed_plan)
    @share_token = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "stakeholder@example.com"
    )
  end

  test "should show shared campaign plan with valid token" do
    get shared_campaign_plan_path(token: @share_token.token)
    
    assert_response :success
    assert_select "h1", @campaign_plan.name
    assert_select "p", /Shared by: #{@campaign_plan.user.full_name}/
    
    @share_token.reload
    assert_equal 1, @share_token.access_count
    assert @share_token.accessed_at.present?
  end

  test "should show not found for invalid token" do
    get shared_campaign_plan_path(token: "invalid-token")
    
    assert_response :not_found
  end

  test "should show expired message for expired token" do
    @share_token.update!(expires_at: 1.hour.ago)
    
    get shared_campaign_plan_path(token: @share_token.token)
    
    assert_response :gone
  end

  test "should display campaign plan content sections" do
    @campaign_plan.update!(
      generated_summary: "Test summary",
      generated_strategy: { "key_strategies" => ["Strategy 1", "Strategy 2"] }.to_json
    )
    
    get shared_campaign_plan_path(token: @share_token.token)
    
    assert_response :success
    assert_select "h2", "Campaign Summary"
    assert_select "h2", "Strategy"
    assert_match /Test summary/, response.body
  end

  test "should track multiple accesses" do
    get shared_campaign_plan_path(token: @share_token.token)
    assert_response :success
    
    get shared_campaign_plan_path(token: @share_token.token)
    assert_response :success
    
    @share_token.reload
    assert_equal 2, @share_token.access_count
  end

  test "should show expiration information" do
    get shared_campaign_plan_path(token: @share_token.token)
    
    assert_response :success
    assert_match /Access expires:/, response.body
    assert_match @share_token.expires_at.strftime('%b %d, %Y'), response.body
  end

  test "should not require authentication for shared access" do
    get shared_campaign_plan_path(token: @share_token.token)
    
    assert_response :success
  end
end
