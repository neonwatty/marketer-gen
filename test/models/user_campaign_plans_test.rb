require "test_helper"

class UserCampaignPlansTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
  end

  test "user should have many campaign plans" do
    assert_respond_to @user, :campaign_plans
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @user.campaign_plans
  end

  test "user campaign plans should be destroyed when user is destroyed" do
    # Create a fresh user to avoid fixture dependencies
    fresh_user = User.create!(
      first_name: 'Fresh',
      last_name: 'User',
      email_address: 'fresh@example.com',
      password: 'password123',
      role: 'marketer'
    )
    
    campaign_plan = fresh_user.campaign_plans.create!(
      name: "Test Campaign",
      campaign_type: "product_launch", 
      objective: "brand_awareness"
    )
    
    campaign_plan_id = campaign_plan.id
    assert CampaignPlan.exists?(campaign_plan_id)
    
    fresh_user.destroy!
    assert_not CampaignPlan.exists?(campaign_plan_id)
  end

  test "user can have multiple campaign plans" do
    initial_count = @user.campaign_plans.count
    
    plan1 = @user.campaign_plans.create!(
      name: "Campaign 1",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    plan2 = @user.campaign_plans.create!(
      name: "Campaign 2", 
      campaign_type: "lead_generation",
      objective: "lead_generation"
    )
    
    assert_includes @user.campaign_plans, plan1
    assert_includes @user.campaign_plans, plan2
    assert_equal initial_count + 2, @user.campaign_plans.count
  end

  test "user campaign plans should be scoped correctly" do
    other_user = users(:team_member_user)
    
    user_plan = @user.campaign_plans.create!(
      name: "User Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    other_plan = other_user.campaign_plans.create!(
      name: "Other Campaign",
      campaign_type: "product_launch", 
      objective: "brand_awareness"
    )
    
    assert_includes @user.campaign_plans, user_plan
    assert_not_includes @user.campaign_plans, other_plan
    assert_not_includes other_user.campaign_plans, user_plan
  end

  test "user campaign plans association should support chaining" do
    # Create a fresh user to avoid fixture dependencies
    fresh_user = User.create!(
      first_name: 'Chain',
      last_name: 'User',
      email_address: 'chain@example.com',
      password: 'password123',
      role: 'marketer'
    )
    
    # Create campaigns with different statuses
    fresh_user.campaign_plans.create!(
      name: "Draft Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      status: "draft"
    )
    
    fresh_user.campaign_plans.create!(
      name: "Completed Campaign", 
      campaign_type: "lead_generation",
      objective: "lead_generation",
      status: "completed"
    )
    
    # Test chaining scopes
    assert_equal 1, fresh_user.campaign_plans.by_status("draft").count
    assert_equal 1, fresh_user.campaign_plans.by_status("completed").count
    assert_equal 1, fresh_user.campaign_plans.by_campaign_type("product_launch").count
    assert_equal 2, fresh_user.campaign_plans.recent.count
  end
end