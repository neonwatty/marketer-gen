require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should not save user without email" do
    user = User.new(password: "password123")
    assert_not user.save
    assert_includes user.errors[:email_address], "can't be blank"
  end
  
  test "should not save user without password" do
    user = User.new(email_address: "test@example.com")
    assert_not user.save
    assert_includes user.errors[:password], "can't be blank"
  end
  
  test "should not save user with short password" do
    user = User.new(email_address: "test@example.com", password: "short")
    assert_not user.save
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end
  
  test "should not save user with invalid email format" do
    user = User.new(email_address: "invalid-email", password: "password123")
    assert_not user.save
    assert_includes user.errors[:email_address], "is invalid"
  end
  
  test "should not save user with duplicate email" do
    User.create!(email_address: "test@example.com", password: "password123")
    user = User.new(email_address: "test@example.com", password: "password456")
    assert_not user.save
    assert_includes user.errors[:email_address], "has already been taken"
  end
  
  test "should normalize email address" do
    user = User.create!(email_address: "  TEST@EXAMPLE.COM  ", password: "password123")
    assert_equal "test@example.com", user.email_address
  end
  
  test "should save valid user" do
    user = User.new(email_address: "valid@example.com", password: "password123")
    assert user.save
  end
  
  test "should have secure password" do
    user = User.create!(email_address: "secure@example.com", password: "password123")
    assert user.authenticate("password123")
    assert_not user.authenticate("wrongpassword")
  end
  
  test "should destroy dependent sessions when user is destroyed" do
    user = User.create!(email_address: "session@example.com", password: "password123")
    session = user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Agent")
    
    assert_difference "Session.count", -1 do
      user.destroy
    end
  end
  
  test "should have default role of marketer" do
    user = User.create!(email_address: "default@example.com", password: "password123")
    assert_equal "marketer", user.role
    assert user.marketer?
    assert_not user.team_member?
    assert_not user.admin?
  end
  
  test "should be able to set role to team_member" do
    user = User.create!(email_address: "team@example.com", password: "password123", role: :team_member)
    assert_equal "team_member", user.role
    assert user.team_member?
    assert_not user.marketer?
    assert_not user.admin?
  end
  
  test "should be able to set role to admin" do
    user = User.create!(email_address: "admin@example.com", password: "password123", role: :admin)
    assert_equal "admin", user.role
    assert user.admin?
    assert_not user.marketer?
    assert_not user.team_member?
  end
  
  test "should have role enum methods" do
    user = User.new
    assert user.respond_to?(:marketer?)
    assert user.respond_to?(:team_member?)
    assert user.respond_to?(:admin?)
  end
  
  # Suspension functionality tests
  test "user can be suspended" do
    admin = User.create!(email_address: "admin@example.com", password: "password", role: "admin")
    user = User.create!(email_address: "user@example.com", password: "password")
    
    assert_not user.suspended?
    
    user.suspend!(reason: "Terms violation", by: admin)
    
    assert user.suspended?
    assert_not_nil user.suspended_at
    assert_equal "Terms violation", user.suspension_reason
    assert_equal admin, user.suspended_by
  end
  
  test "suspended user can be unsuspended" do
    admin = User.create!(email_address: "admin@example.com", password: "password", role: "admin")
    user = User.create!(email_address: "user@example.com", password: "password")
    
    user.suspend!(reason: "Test", by: admin)
    assert user.suspended?
    
    user.unsuspend!
    
    assert_not user.suspended?
    assert_nil user.suspended_at
    assert_nil user.suspension_reason
    assert_nil user.suspended_by
  end
  
  test "account_accessible? returns false for locked users" do
    user = User.create!(email_address: "user@example.com", password: "password")
    
    assert user.account_accessible?
    
    user.lock!("Security breach")
    assert_not user.account_accessible?
  end
  
  test "account_accessible? returns false for suspended users" do
    admin = User.create!(email_address: "admin@example.com", password: "password", role: "admin")
    user = User.create!(email_address: "user@example.com", password: "password")
    
    assert user.account_accessible?
    
    user.suspend!(reason: "Test", by: admin)
    assert_not user.account_accessible?
  end
end