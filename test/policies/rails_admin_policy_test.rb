require "test_helper"

class RailsAdminPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(
      email_address: "admin@example.com",
      password: "password123",
      role: "admin"
    )
    
    @marketer = User.create!(
      email_address: "marketer@example.com",
      password: "password123",
      role: "marketer"
    )
    
    @team_member = User.create!(
      email_address: "team@example.com",
      password: "password123",
      role: "team_member"
    )
  end

  test "admin can access all Rails Admin actions" do
    policy = RailsAdminPolicy.new(@admin, nil)
    
    assert policy.dashboard?
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
    assert policy.suspend?
    assert policy.unsuspend?
  end

  test "non-admin users cannot access Rails Admin actions" do
    [@marketer, @team_member].each do |user|
      policy = RailsAdminPolicy.new(user, nil)
      
      assert_not policy.dashboard?
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
      assert_not policy.suspend?
      assert_not policy.unsuspend?
    end
  end

  test "nil user cannot access Rails Admin actions" do
    policy = RailsAdminPolicy.new(nil, nil)
    
    assert_not policy.dashboard?
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
    assert_not policy.suspend?
    assert_not policy.unsuspend?
  end
end