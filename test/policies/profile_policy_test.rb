require "test_helper"

class ProfilePolicyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @admin = User.create!(
      email_address: "admin@example.com",
      password: "password123",
      role: "admin"
    )
  end

  test "should allow user to view own profile" do
    policy = ProfilePolicy.new(@user, @user)
    assert policy.show?
    assert policy.edit?
    assert policy.update?
  end

  test "should not allow user to view other user profiles" do
    policy = ProfilePolicy.new(@user, @other_user)
    assert_not policy.show?
    assert_not policy.edit?
    assert_not policy.update?
  end

  test "should allow admin to view any profile" do
    policy = ProfilePolicy.new(@admin, @other_user)
    assert policy.show?
    assert policy.edit?
    assert policy.update?
  end

  test "should deny access to unauthenticated users" do
    policy = ProfilePolicy.new(nil, @user)
    assert_not policy.show?
    assert_not policy.edit?
    assert_not policy.update?
  end
end