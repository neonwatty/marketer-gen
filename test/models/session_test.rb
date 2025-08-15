require "test_helper"

class SessionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    )
  end

  # Basic validations
  test "should require ip_address" do
    session = Session.new(user: @user, user_agent: "test", ip_address: "")
    assert_not session.valid?
    assert_includes session.errors[:ip_address], "can't be blank"
  end

  test "should require user_agent" do
    session = Session.new(user: @user, ip_address: "192.168.1.1", user_agent: "")
    assert_not session.valid?
    assert_includes session.errors[:user_agent], "can't be blank"
  end

  test "should set defaults for missing values" do
    session = Session.new(user: @user)
    session.valid? # Trigger validation
    assert_equal "unknown", session.ip_address
    assert_equal "unknown", session.user_agent
  end

  # Session expiry tests
  test "should detect expired sessions by idle timeout" do
    @session.update_column(:updated_at, 1.hour.ago)
    assert @session.expired?
    assert_not @session.active?
  end

  test "should detect expired sessions by total timeout" do
    @session.update_column(:created_at, 3.weeks.ago)
    assert @session.expired?
    assert_not @session.active?
  end

  test "should detect active sessions" do
    @session.touch(:updated_at)
    assert_not @session.expired?
    assert @session.active?
  end

  # Scopes tests
  test "active scope should return non-expired sessions" do
    active_session = @user.sessions.create!(
      ip_address: "192.168.1.2",
      user_agent: "test"
    )
    
    expired_session = @user.sessions.create!(
      ip_address: "192.168.1.3",
      user_agent: "test"
    )
    expired_session.update_column(:updated_at, 1.hour.ago)

    active_sessions = Session.active
    assert_includes active_sessions, active_session
    assert_not_includes active_sessions, expired_session
  end

  test "expired scope should return expired sessions" do
    expired_session = @user.sessions.create!(
      ip_address: "192.168.1.3",
      user_agent: "test"
    )
    expired_session.update_column(:updated_at, 1.hour.ago)

    expired_sessions = Session.expired
    assert_includes expired_sessions, expired_session
    assert_not_includes expired_sessions, @session
  end

  # Security tests
  test "should detect suspicious activity for blank user agent" do
    @session.update_column(:user_agent, nil)
    assert @session.suspicious_activity?
  end

  test "should detect suspicious activity for very long user agent" do
    long_agent = "x" * 501
    @session.update_column(:user_agent, long_agent)
    assert @session.suspicious_activity?
  end

  test "should detect suspicious activity for very old sessions" do
    @session.update_columns(created_at: 7.months.ago, updated_at: 7.months.ago)
    assert @session.suspicious_activity?
  end

  test "should not flag normal sessions as suspicious" do
    assert_not @session.suspicious_activity?
  end

  # Browser detection tests
  test "should detect Chrome browser" do
    @session.update_column(:user_agent, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
    assert_equal "Chrome", @session.browser_info
  end

  test "should detect Firefox browser" do
    @session.update_column(:user_agent, "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0")
    assert_equal "Firefox", @session.browser_info
  end

  test "should handle unknown browser" do
    @session.update_column(:user_agent, "CustomBot/1.0")
    assert_equal "Other", @session.browser_info
  end

  # Activity tracking tests
  test "should touch activity for active sessions" do
    original_time = @session.updated_at
    travel 1.minute do
      @session.touch_activity!
      assert @session.updated_at > original_time
    end
  end

  test "should not touch activity for expired sessions" do
    @session.update_column(:updated_at, 1.hour.ago)
    original_time = @session.updated_at
    @session.touch_activity!
    assert_equal original_time, @session.reload.updated_at
  end

  # Cleanup tests
  test "should cleanup old user sessions on create" do
    # Create 7 sessions (exceeding the limit of 5)
    7.times do |i|
      @user.sessions.create!(
        ip_address: "192.168.1.#{i + 10}",
        user_agent: "test-#{i}"
      )
    end

    # Should have only 5 sessions (latest ones)
    assert_equal 5, @user.sessions.count
  end

  test "cleanup_expired should remove expired sessions" do
    expired_session = @user.sessions.create!(
      ip_address: "192.168.1.100",
      user_agent: "test"
    )
    expired_session.update_column(:updated_at, 1.hour.ago)

    initial_count = Session.count
    Session.cleanup_expired!
    
    assert_equal initial_count - 1, Session.count
    assert_not Session.exists?(expired_session.id)
  end

  test "suspicious_sessions scope should find suspicious sessions" do
    # Create session with long user agent
    suspicious_session = @user.sessions.create!(
      ip_address: "192.168.1.200",
      user_agent: "x" * 501
    )

    suspicious_sessions = Session.suspicious_sessions
    assert_includes suspicious_sessions, suspicious_session
    assert_not_includes suspicious_sessions, @session
  end
end