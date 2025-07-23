require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  def setup
    @marketer = User.create!(email_address: "marketer@example.com", password: "password123", role: :marketer)
    @team_member = User.create!(email_address: "team@example.com", password: "password123", role: :team_member)
    @admin = User.create!(email_address: "admin@example.com", password: "password123", role: :admin)
    @other_user = User.create!(email_address: "other@example.com", password: "password123", role: :marketer)
  end
  
  # Show tests
  test "user can view their own profile" do
    policy = UserPolicy.new(@marketer, @marketer)
    assert policy.show?
  end
  
  test "user cannot view other profiles" do
    policy = UserPolicy.new(@marketer, @other_user)
    assert_not policy.show?
  end
  
  test "admin can view any profile" do
    policy = UserPolicy.new(@admin, @marketer)
    assert policy.show?
    
    policy = UserPolicy.new(@admin, @other_user)
    assert policy.show?
  end
  
  # Update tests
  test "user can update their own profile" do
    policy = UserPolicy.new(@marketer, @marketer)
    assert policy.update?
  end
  
  test "user cannot update other profiles" do
    policy = UserPolicy.new(@marketer, @other_user)
    assert_not policy.update?
  end
  
  test "admin can update any profile" do
    policy = UserPolicy.new(@admin, @marketer)
    assert policy.update?
  end
  
  # Index tests
  test "regular users cannot view user index" do
    policy = UserPolicy.new(@marketer, User)
    assert_not policy.index?
    
    policy = UserPolicy.new(@team_member, User)
    assert_not policy.index?
  end
  
  test "admin can view user index" do
    policy = UserPolicy.new(@admin, User)
    assert policy.index?
  end
  
  # Destroy tests
  test "regular users cannot delete any user" do
    policy = UserPolicy.new(@marketer, @other_user)
    assert_not policy.destroy?
    
    policy = UserPolicy.new(@marketer, @marketer)
    assert_not policy.destroy?
  end
  
  test "admin can delete other users" do
    policy = UserPolicy.new(@admin, @marketer)
    assert policy.destroy?
  end
  
  test "admin cannot delete themselves" do
    policy = UserPolicy.new(@admin, @admin)
    assert_not policy.destroy?
  end
  
  # Scope tests
  test "regular users can only see themselves in scope" do
    scope = UserPolicy::Scope.new(@marketer, User).resolve
    assert_equal [@marketer], scope.to_a
  end
  
  test "admin can see all users in scope" do
    scope = UserPolicy::Scope.new(@admin, User).resolve
    assert_equal User.all.to_a.sort_by(&:id), scope.to_a.sort_by(&:id)
  end
end