require "test_helper"

class PlanShareTokenTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:completed_plan)
  end

  test "should generate unique token on creation" do
    token1 = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "test1@example.com"
    )
    
    token2 = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "test2@example.com"
    )

    assert token1.token.present?
    assert token2.token.present?
    assert_not_equal token1.token, token2.token
  end

  test "should set expiration on creation" do
    token = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "test@example.com"
    )

    assert token.expires_at.present?
    assert token.expires_at > Time.current
    assert token.expires_at <= 7.days.from_now
  end

  test "should validate email format" do
    token = PlanShareToken.new(
      campaign_plan: @campaign_plan,
      email: "invalid-email"
    )

    assert_not token.valid?
    assert_includes token.errors[:email], "is invalid"
  end

  test "should be active when not expired" do
    token = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "test@example.com"
    )

    assert token.active?
    assert_not token.expired?
  end

  test "should be expired when past expiration date" do
    token = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "test@example.com"
    )
    
    token.update!(expires_at: 1.hour.ago)

    assert token.expired?
    assert_not token.active?
  end

  test "should track access" do
    token = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "test@example.com"
    )

    assert_equal 0, token.access_count
    assert_nil token.accessed_at

    token.access!

    assert_equal 1, token.access_count
    assert token.accessed_at.present?
  end

  test "should not allow access when expired" do
    token = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "test@example.com"
    )
    
    token.update!(expires_at: 1.hour.ago)

    assert_not token.access!
    assert_equal 0, token.access_count
  end
end
