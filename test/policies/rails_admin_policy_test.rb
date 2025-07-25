require "test_helper"

class RailsAdminPolicyTest < ActiveSupport::TestCase
  def setup
    @admin = User.create!(
      email_address: "admin@example.com",
      password: "password",
      role: "admin"
    )
    
    @marketer = User.create!(
      email_address: "marketer@example.com",
      password: "password",
      role: "marketer"
    )
    
    @team_member = User.create!(
      email_address: "team@example.com",
      password: "password",
      role: "team_member"
    )
  end
  
  test "admin can access dashboard" do
    policy = RailsAdminPolicy.new(@admin, nil)
    assert policy.dashboard?
  end
  
  test "non-admin cannot access dashboard" do
    policy = RailsAdminPolicy.new(@marketer, nil)
    assert_not policy.dashboard?
    
    policy = RailsAdminPolicy.new(@team_member, nil)
    assert_not policy.dashboard?
  end
  
  test "admin has all permissions" do
    policy = RailsAdminPolicy.new(@admin, nil)
    
    assert policy.index?
    assert policy.show?
    assert policy.new?
    assert policy.edit?
    assert policy.destroy?
    assert policy.export?
    assert policy.bulk_delete?
    assert policy.show_in_app?
    assert policy.history_index?
    assert policy.history_show?
  end
  
  test "non-admin has no permissions" do
    policy = RailsAdminPolicy.new(@marketer, nil)
    
    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.new?
    assert_not policy.edit?
    assert_not policy.destroy?
    assert_not policy.export?
    assert_not policy.bulk_delete?
    assert_not policy.show_in_app?
    assert_not policy.history_index?
    assert_not policy.history_show?
  end
  
  test "nil user has no permissions" do
    policy = RailsAdminPolicy.new(nil, nil)
    
    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.new?
    assert_not policy.edit?
    assert_not policy.destroy?
    assert_not policy.export?
    assert_not policy.bulk_delete?
    assert_not policy.show_in_app?
    assert_not policy.history_index?
    assert_not policy.history_show?
  end
end