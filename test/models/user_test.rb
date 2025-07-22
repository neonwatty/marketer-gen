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
end