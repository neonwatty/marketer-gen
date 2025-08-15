require "test_helper"

class JourneyPolicyTest < ActiveSupport::TestCase
  def setup
    @marketer = User.create!(email_address: "marketer@example.com", password: "password123", role: "marketer")
    @team_member = User.create!(email_address: "team@example.com", password: "password123", role: "team_member")
    @admin = User.create!(email_address: "admin@example.com", password: "password123", role: "admin")
    @other_marketer = User.create!(email_address: "other@example.com", password: "password123", role: "marketer")
    
    @journey = Journey.create!(
      name: "Test Journey",
      description: "Test description",
      campaign_type: "awareness",
      status: "draft",
      user: @marketer
    )
  end

  test "marketer can view index" do
    assert JourneyPolicy.new(@marketer, Journey).index?
  end

  test "team member can view index" do
    assert JourneyPolicy.new(@team_member, Journey).index?
  end

  test "admin can view index" do
    assert JourneyPolicy.new(@admin, Journey).index?
  end

  test "marketer can view own journey" do
    assert JourneyPolicy.new(@marketer, @journey).show?
  end

  test "marketer cannot view other marketer's journey" do
    assert_not JourneyPolicy.new(@other_marketer, @journey).show?
  end

  test "admin can view any journey" do
    assert JourneyPolicy.new(@admin, @journey).show?
  end

  test "marketer can create journey" do
    assert JourneyPolicy.new(@marketer, Journey).create?
  end

  test "team member cannot create journey" do
    assert_not JourneyPolicy.new(@team_member, Journey).create?
  end

  test "admin can create journey" do
    assert JourneyPolicy.new(@admin, Journey).create?
  end

  test "marketer can update own journey" do
    assert JourneyPolicy.new(@marketer, @journey).update?
  end

  test "marketer cannot update other marketer's journey" do
    assert_not JourneyPolicy.new(@other_marketer, @journey).update?
  end

  test "admin can update any journey" do
    assert JourneyPolicy.new(@admin, @journey).update?
  end

  test "marketer can destroy own journey" do
    assert JourneyPolicy.new(@marketer, @journey).destroy?
  end

  test "marketer cannot destroy other marketer's journey" do
    assert_not JourneyPolicy.new(@other_marketer, @journey).destroy?
  end

  test "admin can destroy any journey" do
    assert JourneyPolicy.new(@admin, @journey).destroy?
  end

  test "scope returns all journeys for admin" do
    other_journey = Journey.create!(
      name: "Other Journey",
      description: "Other description",
      campaign_type: "awareness",
      status: "draft",
      user: @other_marketer
    )

    scope = JourneyPolicy::Scope.new(@admin, Journey).resolve
    assert_includes scope, @journey
    assert_includes scope, other_journey
  end

  test "scope returns only own journeys for marketer" do
    other_journey = Journey.create!(
      name: "Other Journey",
      description: "Other description",
      campaign_type: "awareness",
      status: "draft",
      user: @other_marketer
    )

    scope = JourneyPolicy::Scope.new(@marketer, Journey).resolve
    assert_includes scope, @journey
    assert_not_includes scope, other_journey
  end
end