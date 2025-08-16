require "test_helper"

class PlanShareMailerTest < ActionMailer::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:completed_plan)
    @share_token = PlanShareToken.create!(
      campaign_plan: @campaign_plan,
      email: "stakeholder@example.com"
    )
  end

  test "share_plan email" do
    mail = PlanShareMailer.share_plan(@share_token, @user)
    
    assert_equal "stakeholder@example.com", mail.to.first
    assert_includes mail.subject, @user.full_name
    assert_includes mail.subject, @campaign_plan.name
    
    assert_includes mail.body.encoded, @campaign_plan.name
    assert_includes mail.body.encoded, @user.full_name
    assert_includes mail.body.encoded, @campaign_plan.campaign_type.humanize
    assert_includes mail.body.encoded, @share_token.expires_at.strftime('%B %d, %Y')
    assert_includes mail.body.encoded, "shared/"
  end

  test "share_plan email includes access link" do
    mail = PlanShareMailer.share_plan(@share_token, @user)
    
    assert_includes mail.body.encoded, @share_token.token
    assert_includes mail.body.encoded, "View Campaign Plan"
  end

  test "share_plan email includes expiration warning" do
    mail = PlanShareMailer.share_plan(@share_token, @user)
    
    assert_includes mail.body.encoded, "Access expires"
    assert_includes mail.body.encoded, @share_token.expires_at.strftime('%B %d, %Y')
  end

  test "share_plan email includes campaign description when present" do
    @campaign_plan.update!(description: "Test campaign description")
    
    mail = PlanShareMailer.share_plan(@share_token, @user)
    
    assert_includes mail.body.encoded, "Test campaign description"
  end
end
