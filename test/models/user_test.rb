require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "user has default role of marketer" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    assert_equal "marketer", user.role
  end

  test "user can be a marketer" do
    user = User.create!(email_address: "test@example.com", password: "password123", role: "marketer")
    assert user.marketer?
    assert_not user.team_member?
    assert_not user.admin?
  end

  test "user can be a team member" do
    user = User.create!(email_address: "test@example.com", password: "password123", role: "team_member")
    assert user.team_member?
    assert_not user.marketer?
    assert_not user.admin?
  end

  test "user can be an admin" do
    user = User.create!(email_address: "test@example.com", password: "password123", role: "admin")
    assert user.admin?
    assert_not user.marketer?
    assert_not user.team_member?
  end

  test "user role must be valid" do
    user = User.new(email_address: "test@example.com", password: "password123", role: "invalid_role")
    assert_not user.valid?
    assert user.errors[:role].any?
  end
end
