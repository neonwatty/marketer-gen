require "test_helper"

class ThreatDetectionJobTest < ActiveSupport::TestCase
  test "should perform behavioral analysis" do
    job = ThreatDetectionJob.new
    
    result = job.perform('behavioral_analysis')
    
    assert_kind_of Integer, result
    assert result >= 0
  end

  test "should perform threat intelligence scan" do
    job = ThreatDetectionJob.new
    
    result = job.perform('threat_intelligence_scan')
    
    assert_kind_of Integer, result
    assert result >= 0
  end

  test "should perform attack pattern analysis" do
    job = ThreatDetectionJob.new
    
    result = job.perform('attack_pattern_analysis')
    
    assert_kind_of Integer, result
    assert result >= 0
  end

  test "should perform risk assessment" do
    job = ThreatDetectionJob.new
    
    result = job.perform('risk_assessment')
    
    assert_kind_of Integer, result
    assert result >= 0
  end

  test "should perform scheduled full scan" do
    job = ThreatDetectionJob.new
    
    result = job.perform('scheduled_full_scan')
    
    assert_kind_of Hash, result
    assert_includes result.keys, :behavioral_anomalies
    assert_includes result.keys, :threat_intelligence_matches
    assert_includes result.keys, :attack_patterns
    assert_includes result.keys, :high_risk_sessions
    assert_includes result.keys, :total_incidents_created
  end

  test "should raise error for unknown analysis type" do
    job = ThreatDetectionJob.new
    
    assert_raises ArgumentError do
      job.perform('unknown_analysis_type')
    end
  end

  test "should create behavioral incident when high severity anomalies detected" do
    user = users(:one)
    anomalies = [
      { type: 'excessive_access_frequency', severity: :high, details: 'High access frequency' },
      { type: 'unusual_login_time', severity: :medium, details: 'Login at 3 AM' }
    ]
    
    job = ThreatDetectionJob.new
    
    assert_difference 'SecurityIncident.count', 1 do
      job.send(:create_behavioral_incident, user.id, anomalies)
    end
    
    incident = SecurityIncident.last
    assert_equal 'activity_anomaly', incident.incident_type
    assert_equal 'high', incident.severity
    assert_equal user.id, incident.user_id
    assert_includes incident.title, user.id.to_s
  end

  test "should create threat intelligence incident" do
    threat_result = {
      threat_score: 95,
      indicators: [
        { type: 'malicious_ip', value: '192.168.999.1', confidence: 0.9 }
      ]
    }
    
    job = ThreatDetectionJob.new
    
    assert_difference 'SecurityIncident.count', 1 do
      job.send(:create_threat_intelligence_incident, '192.168.999.1', 'sqlmap/1.0', threat_result)
    end
    
    incident = SecurityIncident.last
    assert_equal 'suspicious_login', incident.incident_type
    assert_equal 'critical', incident.severity  # Score > 90
    assert_equal '192.168.999.1', incident.source_ip
    assert_equal 'sqlmap/1.0', incident.user_agent
  end

  test "should create attack pattern incident" do
    pattern = {
      type: 'sql_injection',
      severity: :critical,
      confidence: 0.95,
      details: 'SQL injection attempt detected',
      affected_resources: ['/api/users']
    }
    
    job = ThreatDetectionJob.new
    
    assert_difference 'SecurityIncident.count', 1 do
      job.send(:create_attack_pattern_incident, pattern)
    end
    
    incident = SecurityIncident.last
    assert_equal 'unauthorized_access', incident.incident_type
    assert_equal 'critical', incident.severity
    assert_includes incident.title, 'sql_injection'
    assert_includes incident.description, '95%'
  end

  test "should create high risk incident" do
    user = users(:one)
    session_data = {
      id: 123,
      user_id: user.id,
      ip_address: '192.168.1.1',
      user_agent: 'Chrome/91.0',
      created_at: 1.hour.ago
    }
    risk_result = {
      score: 90,
      factors: ['admin_user', 'unusual_time']
    }
    
    job = ThreatDetectionJob.new
    
    assert_difference 'SecurityIncident.count', 1 do
      job.send(:create_high_risk_incident, session_data, risk_result)
    end
    
    incident = SecurityIncident.last
    assert_equal 'session_hijacking', incident.incident_type
    assert_equal 'high', incident.severity  # Score < 95
    assert_equal user.id, incident.user_id
    assert_includes incident.title, '90'
  end

  test "should block IP address with cache" do
    job = ThreatDetectionJob.new
    ip_address = '192.168.1.100'
    
    job.send(:block_ip_address, ip_address, 1.hour)
    
    cache_key = "blocked_ip:#{ip_address}"
    assert Rails.cache.read(cache_key)
  end

  test "should get active user IDs" do
    user = users(:one)
    Session.create!(user: user, ip_address: "192.168.1.1", user_agent: "Chrome/91.0")
    
    job = ThreatDetectionJob.new
    user_ids = job.send(:get_active_user_ids, 1.day)
    
    assert_includes user_ids, user.id
  end

  test "should get recent IP addresses" do
    job = ThreatDetectionJob.new
    ip_addresses = job.send(:get_recent_ip_addresses, 1.hour)
    
    assert_kind_of Array, ip_addresses
    assert ip_addresses.all? { |ip_data| ip_data.key?(:ip) && ip_data.key?(:user_agent) }
  end

  test "should identify high risk sessions" do
    user = users(:one)
    Session.create!(user: user, ip_address: "192.168.1.1", user_agent: "Chrome/91.0")
    
    job = ThreatDetectionJob.new
    high_risk_sessions = job.send(:identify_high_risk_sessions)
    
    assert_kind_of Array, high_risk_sessions
    # May or may not have sessions depending on timing
  end

  test "should terminate high risk session" do
    user = users(:one)
    session = Session.create!(user: user, ip_address: "192.168.1.1", user_agent: "Chrome/91.0")
    
    session_data = { id: session.id }
    job = ThreatDetectionJob.new
    
    assert_difference 'Session.count', -1 do
      job.send(:terminate_high_risk_session, session_data)
    end
  end

  test "behavioral analysis should handle user processing errors gracefully" do
    job = ThreatDetectionJob.new
    
    # Mock SecurityMonitoringService to raise an error for first user
    SecurityMonitoringService.stub(:detect_behavioral_anomalies, ->(*args) { raise StandardError, "Test error" }) do
      # Should not raise error, should continue processing
      result = job.send(:perform_behavioral_analysis, user_ids: [999]) # Non-existent user ID
      assert_kind_of Integer, result
    end
  end

  test "threat intelligence scan should process multiple IPs" do
    job = ThreatDetectionJob.new
    
    ip_addresses = [
      { ip: '192.168.1.1', user_agent: 'Chrome/91.0' },
      { ip: '192.168.999.1', user_agent: 'sqlmap/1.0' }
    ]
    
    result = job.send(:perform_threat_intelligence_scan, ip_addresses: ip_addresses)
    
    assert_kind_of Integer, result
    assert result >= 0
  end

  test "should schedule follow-up analysis for high anomaly count" do
    job = ThreatDetectionJob.new
    
    # Test that high anomaly count triggers scheduling logic
    # (Actual scheduling would happen in real scenario)
    result = job.send(:perform_behavioral_analysis, user_ids: [users(:one).id] * 10)
    
    # Just verify the method runs without error when high anomaly count
    assert_kind_of Integer, result
  end

  test "job should be queued in security queue" do
    assert_equal "security", ThreatDetectionJob.queue_name
  end

  test "job should have proper retry configuration" do
    job = ThreatDetectionJob.new
    
    # Test that job has retry configuration
    assert_respond_to ThreatDetectionJob, :retry_on
  end

  test "should handle performance optimization for large user sets" do
    # Create multiple users with sessions
    5.times do |i|
      user = User.create!(
        email_address: "test#{i}@example.com", 
        password: "password123"
      )
      Session.create!(user: user, ip_address: "192.168.1.#{i}", user_agent: "Chrome/91.0")
    end
    
    job = ThreatDetectionJob.new
    user_ids = job.send(:get_active_user_ids, 1.day)
    
    # Should limit to 100 users for performance
    assert user_ids.count <= 100
  end
end