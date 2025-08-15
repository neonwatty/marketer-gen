require "test_helper"

class SessionSecurityTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    )
  end

  test "should detect expired sessions" do
    @session.update_column(:updated_at, 31.minutes.ago)
    assert @session.expired?
    assert_not @session.active?
  end

  test "should detect suspicious user agents" do
    suspicious_session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "x" * 501  # Abnormally long
    )
    assert suspicious_session.suspicious_activity?
  end

  test "should cleanup old sessions automatically" do
    initial_count = @user.sessions.count
    
    # Create 7 more sessions (should trigger cleanup to keep only 5)
    7.times do |i|
      @user.sessions.create!(
        ip_address: "192.168.1.#{i + 2}",
        user_agent: "test-#{i}"
      )
    end
    
    assert_equal 5, @user.reload.sessions.count
  end

  test "should extract browser info from user agent" do
    chrome_session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    )
    assert_equal "Chrome", chrome_session.browser_info
  end

  test "should cleanup expired sessions class method" do
    # Create expired session
    expired_session = @user.sessions.create!(
      ip_address: "192.168.1.2",
      user_agent: "test"
    )
    expired_session.update_column(:updated_at, 31.minutes.ago)
    
    initial_count = Session.count
    Session.cleanup_expired!
    
    assert_equal initial_count - 1, Session.count
    assert_not Session.exists?(expired_session.id)
  end
end