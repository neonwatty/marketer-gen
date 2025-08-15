require "test_helper"

class UserSecurityTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "should validate role inclusion" do
    @user.role = "invalid_role"
    assert_not @user.valid?
    assert_includes @user.errors[:role], "is not included in the list"
  end

  test "should validate profile field lengths" do
    @user.first_name = "a" * 51
    @user.last_name = "b" * 51
    @user.company = "c" * 101
    @user.bio = "d" * 501
    
    assert_not @user.valid?
    assert_includes @user.errors[:first_name], "is too long (maximum is 50 characters)"
    assert_includes @user.errors[:last_name], "is too long (maximum is 50 characters)"
    assert_includes @user.errors[:company], "is too long (maximum is 100 characters)"
    assert_includes @user.errors[:bio], "is too long (maximum is 500 characters)"
  end

  test "should validate phone number format" do
    invalid_phones = ["123", "abc-def-ghij", "123-45-6789-0123-4567", "0123456789"]
    
    invalid_phones.each do |phone|
      @user.phone = phone
      assert_not @user.valid?, "#{phone} should be invalid"
      assert_includes @user.errors[:phone], "must be a valid phone number"
    end
    
    valid_phones = ["+1-555-123-4567", "555-123-4567", "5551234567", "1234567890"]
    
    valid_phones.each do |phone|
      @user.phone = phone
      assert @user.valid?, "#{phone} should be valid"
    end
  end

  test "should handle notification preferences correctly" do
    prefs = {
      "email_notifications" => "true",
      "journey_updates" => "false",
      "marketing_emails" => "true",
      "weekly_digest" => "false"
    }
    
    @user.notification_preferences = prefs
    @user.save!
    
    @user.reload
    assert_equal true, @user.notification_preferences["email_notifications"]
    assert_equal false, @user.notification_preferences["journey_updates"]
    assert_equal true, @user.notification_preferences["marketing_emails"]
    assert_equal false, @user.notification_preferences["weekly_digest"]
  end

  test "should provide default notification preferences" do
    new_user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    defaults = new_user.notification_preferences
    assert_equal true, defaults[:email_notifications]
    assert_equal true, defaults[:journey_updates]
    assert_equal false, defaults[:marketing_emails]
    assert_equal true, defaults[:weekly_digest]
  end

  test "should calculate session security score" do
    # Clean slate
    @user.sessions.destroy_all
    
    # Create normal session
    normal_session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0 (Normal Browser)"
    )
    
    assert_equal 100, @user.session_security_score
    
    # Add suspicious session
    suspicious_session = @user.sessions.create!(
      ip_address: "192.168.1.2",
      user_agent: "x" * 501  # Suspicious
    )
    
    assert @user.session_security_score < 100
  end

  test "should terminate all sessions" do
    # Create multiple sessions
    3.times do |i|
      @user.sessions.create!(
        ip_address: "192.168.1.#{i + 1}",
        user_agent: "test-#{i}"
      )
    end
    
    initial_count = @user.sessions.count
    assert initial_count > 0
    
    @user.terminate_all_sessions!
    assert_equal 0, @user.sessions.count
  end

  test "should terminate other sessions but keep current" do
    current_session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "current"
    )
    
    # Create other sessions
    3.times do |i|
      @user.sessions.create!(
        ip_address: "192.168.1.#{i + 2}",
        user_agent: "other-#{i}"
      )
    end
    
    @user.terminate_other_sessions!(current_session)
    
    assert_equal 1, @user.sessions.count
    assert @user.sessions.exists?(current_session.id)
  end

  test "should generate appropriate initials" do
    @user.first_name = "John"
    @user.last_name = "Doe"
    assert_equal "JD", @user.initials
    
    @user.first_name = nil
    @user.last_name = nil
    expected = @user.email_address[0..1].upcase
    assert_equal expected, @user.initials
  end

  test "should generate full name correctly" do
    @user.first_name = "John"
    @user.last_name = "Doe"
    assert_equal "John Doe", @user.full_name
    
    @user.first_name = "John"
    @user.last_name = nil
    assert_equal "John", @user.full_name
    
    @user.first_name = nil
    @user.last_name = nil
    expected = @user.email_address.split('@').first
    assert_equal expected, @user.full_name
  end
end