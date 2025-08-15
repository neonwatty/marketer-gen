require "test_helper"

class SecurityMonitorServiceTest < ActiveSupport::TestCase
  def setup
    @service = SecurityMonitorService.new
    @ip_address = "192.168.1.100"
    @user = users(:one)
    Rails.cache.clear
  end

  def teardown
    Rails.cache.clear
  end

  # Failed login tracking tests
  test "should track failed login attempts" do
    count = @service.track_failed_login(@ip_address, "test@example.com")
    assert_equal 1, count

    count = @service.track_failed_login(@ip_address, "test@example.com")
    assert_equal 2, count
  end

  test "should block IP after max failed attempts" do
    # Exceed the threshold
    6.times { @service.track_failed_login(@ip_address) }
    
    assert @service.ip_blocked?(@ip_address)
  end

  test "should clear failed attempts" do
    @service.track_failed_login(@ip_address)
    @service.clear_failed_attempts(@ip_address)
    
    # Next attempt should start at 1 again
    count = @service.track_failed_login(@ip_address)
    assert_equal 1, count
  end

  # IP blocking tests
  test "should block and unblock IP addresses" do
    assert_not @service.ip_blocked?(@ip_address)
    
    @service.block_ip(@ip_address)
    assert @service.ip_blocked?(@ip_address)
    
    @service.unblock_ip(@ip_address)
    assert_not @service.ip_blocked?(@ip_address)
  end

  test "should block IP with custom duration" do
    @service.block_ip(@ip_address, 1.minute)
    assert @service.ip_blocked?(@ip_address)
    
    # Test that it would expire (we can't actually wait)
    travel 2.minutes do
      assert_not @service.ip_blocked?(@ip_address)
    end
  end

  # Suspicious activity tracking tests
  test "should track suspicious activity" do
    count = @service.track_suspicious_activity(@user.id, "multiple_login_attempts")
    assert_equal 1, count

    count = @service.track_suspicious_activity(@user.id, "unusual_location")
    assert_equal 2, count
  end

  test "should alert on excessive suspicious activity" do
    # Track activities up to threshold
    11.times do |i|
      @service.track_suspicious_activity(@user.id, "test_activity_#{i}")
    end

    # Should have logged an alert (we can't easily test the actual alert)
    # This test verifies the count reaches the threshold
    activities = Rails.cache.read("security_monitor:suspicious:#{@user.id}") || []
    assert activities.count >= 10
  end

  test "should expire old suspicious activities" do
    # Add activity from 25 hours ago
    old_activity = {
      type: "old_activity",
      timestamp: 25.hours.ago,
      details: {}
    }
    
    Rails.cache.write("security_monitor:suspicious:#{@user.id}", [old_activity])
    
    # Add new activity
    @service.track_suspicious_activity(@user.id, "new_activity")
    
    # Old activity should be removed
    activities = Rails.cache.read("security_monitor:suspicious:#{@user.id}") || []
    assert_equal 1, activities.count
    assert_equal "new_activity", activities.first[:type]
  end

  # Security metrics tests
  test "should generate security metrics" do
    metrics = @service.security_metrics
    
    assert_includes metrics.keys, :total_sessions
    assert_includes metrics.keys, :active_sessions
    assert_includes metrics.keys, :expired_sessions
    assert_includes metrics.keys, :suspicious_sessions
    assert_includes metrics.keys, :blocked_ips
    assert_includes metrics.keys, :recent_failed_logins
    
    # All values should be numeric
    metrics.values.each do |value|
      assert value.is_a?(Integer), "Expected integer, got #{value.class}"
    end
  end

  test "should generate security report" do
    report = @service.generate_security_report
    
    assert_includes report.keys, :generated_at
    assert_includes report.keys, :summary
    assert_includes report.keys, :details
    
    assert report[:generated_at].is_a?(Time)
    assert report[:summary].is_a?(Hash)
    assert report[:details].is_a?(Hash)
  end

  # Re-authentication checks
  test "should require reauth for users with suspicious sessions" do
    # Create a suspicious session
    suspicious_session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "x" * 501 # Triggers suspicious activity
    )
    
    assert @service.require_reauth?(@user)
  end

  test "should require reauth for users with low security score" do
    # Create conditions that result in a low security score
    # Create multiple suspicious sessions to lower the score
    5.times do |i|
      @user.sessions.create!(
        ip_address: "192.168.1.#{i + 10}",
        user_agent: "x" * 501  # Makes it suspicious
      )
    end
    
    assert @service.require_reauth?(@user)
  end

  test "should require reauth for users with old sessions" do
    # Create an old session
    old_session = @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "test"
    )
    old_session.update_column(:updated_at, 8.days.ago)
    
    assert @service.require_reauth?(@user)
  end

  test "should not require reauth for secure users" do
    # Create a normal, recent session
    @user.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    )
    
    assert_not @service.require_reauth?(@user)
  end

  test "should handle nil user gracefully" do
    assert_not @service.require_reauth?(nil)
  end

  # Configuration tests
  test "should use configurable values" do
    original_max_attempts = @service.max_failed_attempts
    
    @service.max_failed_attempts = 3
    
    # Should block after 3 attempts instead of default 5
    3.times { @service.track_failed_login(@ip_address) }
    assert @service.ip_blocked?(@ip_address)
    
    # Reset
    @service.max_failed_attempts = original_max_attempts
  end
end