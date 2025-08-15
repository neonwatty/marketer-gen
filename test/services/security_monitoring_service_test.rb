require "test_helper"

class SecurityMonitoringServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @session = Session.create!(user: @user, ip_address: "127.0.0.1", user_agent: "test")
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "sends security alerts with proper structure" do
    alert_data = {
      alert_type: "TEST_ALERT",
      user_id: @user.id,
      message: "Test security alert"
    }

    alert_id = SecurityMonitoringService.send_alert(alert_data)
    
    assert alert_id.present?
    assert alert_id.start_with?("SEC_")
    
    # Check alert was stored in cache
    stored_alert = Rails.cache.read("security_alert:#{alert_id}")
    assert stored_alert.present?
    assert_equal "TEST_ALERT", stored_alert[:alert_type]
    assert_equal @user.id, stored_alert[:user_id]
  end

  test "determines alert severity correctly" do
    critical_alert = { alert_type: "BRUTE_FORCE_ATTACK" }
    high_alert = { alert_type: "EXCESSIVE_DATA_ACCESS" }
    medium_alert = { alert_type: "RAPID_REQUESTS" }
    low_alert = { alert_type: "UNKNOWN_TYPE" }

    assert_equal :critical, SecurityMonitoringService.send(:determine_severity, critical_alert)
    assert_equal :high, SecurityMonitoringService.send(:determine_severity, high_alert)
    assert_equal :medium, SecurityMonitoringService.send(:determine_severity, medium_alert)
    assert_equal :low, SecurityMonitoringService.send(:determine_severity, low_alert)
  end

  test "checks brute force attempts" do
    ip_address = "192.168.1.100"
    
    # Simulate multiple failed attempts
    cache_key = "failed_attempts:#{ip_address}"
    attempts = 6.times.map do |i|
      { timestamp: (15 - i).minutes.ago, ip: ip_address }
    end
    Rails.cache.write(cache_key, attempts)
    
    # This should trigger brute force detection
    count = SecurityMonitoringService.check_brute_force_attempts(ip_address)
    
    assert count >= 5
    
    # Check that IP was blocked
    block_key = "blocked_ip:#{ip_address}"
    assert Rails.cache.read(block_key)
  end

  test "monitors data access patterns" do
    user_id = @user.id
    
    # Monitor normal access
    count1 = SecurityMonitoringService.monitor_data_access(user_id, 5, "users#index")
    assert_equal 5, count1
    
    # Monitor excessive access
    count2 = SecurityMonitoringService.monitor_data_access(user_id, 50, "users#export")
    assert_equal 55, count2
    
    # Should trigger alert for excessive access
    count3 = SecurityMonitoringService.monitor_data_access(user_id, 50, "users#show")
    assert count3 > 100
  end

  test "generates security reports" do
    report = SecurityMonitoringService.generate_security_report(24.hours)
    
    assert report.key?(:period)
    assert report.key?(:total_alerts)
    assert report.key?(:alerts_by_severity)
    assert report.key?(:recommendations)
    
    # Check severity breakdown
    severity_breakdown = report[:alerts_by_severity]
    assert severity_breakdown.key?(:critical)
    assert severity_breakdown.key?(:high)
    assert severity_breakdown.key?(:medium)
    assert severity_breakdown.key?(:low)
  end

  test "analyzes user activity for anomalies" do
    user_id = @user.id
    
    # This would normally analyze real activity data
    anomalies = SecurityMonitoringService.analyze_user_activity(user_id, 1.hour)
    
    # Should return array of anomaly indicators
    assert anomalies.is_a?(Array)
  end

  test "blocks and unblocks IP addresses" do
    ip_address = "192.168.1.200"
    
    # Block IP
    SecurityMonitoringService.send(:block_ip_address, ip_address, 1.hour)
    
    # Check it's blocked
    cache_key = "blocked_ip:#{ip_address}"
    assert Rails.cache.read(cache_key)
    
    # Unblock IP
    Rails.cache.delete(cache_key)
    refute Rails.cache.read(cache_key)
  end

  test "maintains recent alerts list" do
    # Send multiple alerts
    3.times do |i|
      alert_data = {
        alert_type: "TEST_ALERT_#{i}",
        message: "Test alert #{i}"
      }
      SecurityMonitoringService.send_alert(alert_data)
    end
    
    # Check recent alerts list
    recent_alerts = Rails.cache.read("recent_security_alerts")
    assert recent_alerts.present?
    assert_equal 3, recent_alerts.length
  end

  test "instance monitoring calculates session security score" do
    monitoring_service = SecurityMonitoringService.new(
      user: @user,
      session: @session,
      request: nil
    )
    
    score = monitoring_service.send(:calculate_session_security_score)
    
    assert score.is_a?(Numeric)
    assert score >= 0
    assert score <= 100
  end

  test "instance monitoring identifies session risk factors" do
    # Create an old session for testing
    old_session = Session.create!(
      user: @user,
      ip_address: "127.0.0.1",
      user_agent: "test",
      created_at: 2.weeks.ago
    )
    
    monitoring_service = SecurityMonitoringService.new(
      user: @user,
      session: old_session,
      request: nil
    )
    
    risk_factors = monitoring_service.send(:session_risk_factors)
    
    assert risk_factors.include?("old_session")
  end

  test "handles missing data gracefully" do
    # Test with nil values
    monitoring_service = SecurityMonitoringService.new(
      user: nil,
      session: nil,
      request: nil
    )
    
    assert_nothing_raised do
      monitoring_service.monitor_session_security
    end
  end

  test "integrates automated actions for high severity alerts" do
    # Test automated response to brute force
    alert_data = {
      alert_type: "BRUTE_FORCE_ATTACK",
      ip_address: "192.168.1.300"
    }
    
    SecurityMonitoringService.send_alert(alert_data)
    
    # Check that IP was automatically blocked
    cache_key = "blocked_ip:192.168.1.300"
    assert Rails.cache.read(cache_key)
  end

  test "logs alerts with appropriate severity levels" do
    # Test different severity levels create appropriate log entries
    alerts = [
      { alert_type: "BRUTE_FORCE_ATTACK", expected_level: "CRITICAL" },
      { alert_type: "EXCESSIVE_DATA_ACCESS", expected_level: "HIGH" },
      { alert_type: "RAPID_REQUESTS", expected_level: "MEDIUM" },
      { alert_type: "OTHER", expected_level: "LOW" }
    ]
    
    alerts.each do |alert_config|
      alert_data = alert_config.except(:expected_level).merge({ 
        user_id: 1, 
        timestamp: Time.current 
      })
      
      SecurityMonitoringService.send_alert(alert_data)
      
      # Verify the alert was logged with correct severity
      logs = logs_containing("SECURITY_ALERT")
      assert logs.any?, "Expected security alert log entry"
      
      latest_log = logs.last
      assert_includes latest_log, alert_config[:expected_level]
    end
  end
end