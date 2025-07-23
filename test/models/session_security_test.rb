require "test_helper"

class SessionSecurityTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123"
    )
  end
  
  test "session is created with expiration time" do
    session = @user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "127.0.0.1"
    )
    
    assert_not_nil session.expires_at
    assert_not_nil session.last_active_at
    assert session.expires_at > Time.current
    assert_equal Session::SESSION_TIMEOUT.from_now.to_i, session.expires_at.to_i
  end
  
  test "expired? returns true for expired sessions" do
    session = @user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "127.0.0.1",
      expires_at: 1.hour.ago
    )
    
    assert session.expired?
  end
  
  test "expired? returns false for active sessions" do
    session = @user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "127.0.0.1",
      expires_at: 1.hour.from_now
    )
    
    assert_not session.expired?
  end
  
  test "inactive? returns true for inactive sessions" do
    session = @user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "127.0.0.1",
      last_active_at: 3.hours.ago
    )
    
    assert session.inactive?
  end
  
  test "inactive? returns false for recently active sessions" do
    session = @user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "127.0.0.1",
      last_active_at: 30.minutes.ago
    )
    
    assert_not session.inactive?
  end
  
  test "touch_activity! updates last_active_at" do
    session = @user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "127.0.0.1",
      last_active_at: 1.hour.ago
    )
    
    old_time = session.last_active_at
    session.touch_activity!
    
    assert session.last_active_at > old_time
    assert_in_delta Time.current.to_i, session.last_active_at.to_i, 1
  end
  
  test "extend_session! updates expiration time" do
    session = @user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "127.0.0.1",
      expires_at: 1.hour.from_now
    )
    
    old_expiry = session.expires_at
    session.extend_session!
    
    assert session.expires_at > old_expiry
    assert_equal Session::SESSION_TIMEOUT.from_now.to_i, session.expires_at.to_i
  end
  
  test "active scope returns only non-expired sessions" do
    active_session = @user.sessions.create!(
      user_agent: "Active Browser",
      ip_address: "127.0.0.1",
      expires_at: 1.hour.from_now
    )
    
    expired_session = @user.sessions.create!(
      user_agent: "Expired Browser",
      ip_address: "127.0.0.1",
      expires_at: 1.hour.ago
    )
    
    active_sessions = @user.sessions.active
    
    assert_includes active_sessions, active_session
    assert_not_includes active_sessions, expired_session
  end
  
  test "expired scope returns only expired sessions" do
    active_session = @user.sessions.create!(
      user_agent: "Active Browser",
      ip_address: "127.0.0.1",
      expires_at: 1.hour.from_now
    )
    
    expired_session = @user.sessions.create!(
      user_agent: "Expired Browser",
      ip_address: "127.0.0.1",
      expires_at: 1.hour.ago
    )
    
    expired_sessions = @user.sessions.expired
    
    assert_includes expired_sessions, expired_session
    assert_not_includes expired_sessions, active_session
  end
end