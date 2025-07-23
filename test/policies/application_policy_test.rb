require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  def setup
    @marketer = User.create!(email_address: "marketer@example.com", password: "password123", role: :marketer)
    @team_member = User.create!(email_address: "team@example.com", password: "password123", role: :team_member)
    @admin = User.create!(email_address: "admin@example.com", password: "password123", role: :admin)
  end
  
  test "default policy should deny all actions" do
    policy = ApplicationPolicy.new(@marketer, Object.new)
    
    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.new?
    assert_not policy.update?
    assert_not policy.edit?
    assert_not policy.destroy?
  end
  
  test "new? should alias to create?" do
    policy = ApplicationPolicy.new(@marketer, Object.new)
    assert_equal policy.create?, policy.new?
  end
  
  test "edit? should alias to update?" do
    policy = ApplicationPolicy.new(@marketer, Object.new)
    assert_equal policy.update?, policy.edit?
  end
  
  test "policy should accept user and record" do
    record = Object.new
    policy = ApplicationPolicy.new(@admin, record)
    
    assert_equal @admin, policy.user
    assert_equal record, policy.record
  end
  
  test "scope should raise NotImplementedError" do
    scope = ApplicationPolicy::Scope.new(@marketer, User.all)
    
    assert_raises(NoMethodError) do
      scope.resolve
    end
  end
end