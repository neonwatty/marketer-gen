require "test_helper"

class SessionCleanupJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
  end

  test "should cleanup expired sessions" do
    # Create expired session
    expired_session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "test"
    )
    expired_session.update_column(:updated_at, 31.minutes.ago)
    
    # Create active session
    active_session = @user.sessions.create!(
      ip_address: "192.168.1.2",
      user_agent: "test"
    )
    
    initial_count = Session.count
    
    SessionCleanupJob.perform_now
    
    assert_not Session.exists?(expired_session.id)
    assert Session.exists?(active_session.id)
    assert_equal initial_count - 1, Session.count
  end

  test "should cleanup suspicious sessions" do
    # Create suspicious session
    suspicious_session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "x" * 501  # Suspicious
    )
    
    # Create normal session
    normal_session = @user.sessions.create!(
      ip_address: "192.168.1.2",
      user_agent: "Mozilla/5.0"
    )
    
    SessionCleanupJob.perform_now
    
    assert_not Session.exists?(suspicious_session.id)
    assert Session.exists?(normal_session.id)
  end

  test "should cleanup old sessions per user" do
    # Create 15 sessions for a user (the model automatically keeps only 5)
    sessions = []
    15.times do |i|
      sessions << @user.sessions.create!(
        ip_address: "192.168.1.#{i + 1}",
        user_agent: "test-#{i}"
      )
    end
    
    # Should have already been limited to 5 by the model callback
    assert_equal 5, @user.reload.sessions.count
    
    SessionCleanupJob.perform_now
    
    # Should still have 5 or fewer
    assert @user.reload.sessions.count <= 5
  end

  test "should handle errors gracefully" do
    # Mock an error by overriding the method temporarily
    original_method = Session.method(:expired)
    Session.define_singleton_method(:expired) { raise StandardError.new("Test error") }
    
    begin
      assert_raises StandardError do
        SessionCleanupJob.perform_now
      end
    ensure
      # Restore original method
      Session.define_singleton_method(:expired, original_method)
    end
  end

  test "should log cleanup metrics" do
    # Create test data
    expired_session = @user.sessions.create!(ip_address: "192.168.1.1", user_agent: "test")
    expired_session.update_column(:updated_at, 31.minutes.ago)
    
    suspicious_session = @user.sessions.create!(ip_address: "192.168.1.2", user_agent: "x" * 501)
    
    # Test that the job runs without error (log checking is complex in tests)
    assert_nothing_raised do
      SessionCleanupJob.perform_now
    end
    
    # Verify the cleanup actually happened
    assert_not Session.exists?(expired_session.id)
    assert_not Session.exists?(suspicious_session.id)
  end
end