require "test_helper"

class SecurityMonitoringServiceTest < ActiveSupport::TestCase
  test "should send security alert with proper structure" do
    alert_data = {
      alert_type: "BRUTE_FORCE_ATTACK",
      ip_address: "192.168.1.100",
      attempt_count: 5,
      timestamp: Time.current
    }
    
    alert_id = SecurityMonitoringService.send_alert(alert_data)
    
    assert_not_nil alert_id
    assert_match /^SEC_\d+_[a-f0-9]{8}$/, alert_id
  end

  test "should create security incident for high severity alerts" do
    alert_data = {
      alert_type: "BRUTE_FORCE_ATTACK",
      ip_address: "192.168.1.100",
      attempt_count: 10,
      timestamp: Time.current
    }
    
    assert_difference 'SecurityIncident.count', 1 do
      SecurityMonitoringService.send_alert(alert_data)
    end
    
    incident = SecurityIncident.last
    assert_equal "brute_force_attack", incident.incident_type
    assert_equal "critical", incident.severity
    assert_equal "open", incident.status
  end

  test "should not create incident for low severity alerts" do
    alert_data = {
      alert_type: "RAPID_REQUESTS",
      ip_address: "192.168.1.100",
      timestamp: Time.current
    }
    
    assert_no_difference 'SecurityIncident.count' do
      SecurityMonitoringService.send_alert(alert_data)
    end
  end

  test "should detect behavioral anomalies" do
    user = users(:one)
    
    anomalies = SecurityMonitoringService.detect_behavioral_anomalies(user.id, 7.days)
    
    assert_kind_of Array, anomalies
    # Anomalies may or may not be detected based on simulated data
  end

  test "should check threat intelligence" do
    result = SecurityMonitoringService.check_threat_intelligence("192.168.999.1", "sqlmap/1.0")
    
    assert_kind_of Hash, result
    assert_includes result.keys, :threat_score
    assert_includes result.keys, :indicators
    assert result[:threat_score] > 0  # Should detect threat in malicious IP
  end

  test "should analyze attack patterns" do
    patterns = SecurityMonitoringService.analyze_attack_patterns(1.hour)
    
    assert_kind_of Array, patterns
    # Patterns may or may not be detected based on simulated data
  end

  test "should calculate risk score with multiple factors" do
    user = users(:one)
    session_data = {
      id: 123,
      ip_address: "192.168.1.1",
      user_agent: "Chrome/91.0",
      created_at: 1.hour.ago
    }
    request_data = {
      ip_address: "192.168.1.1",
      user_agent: "Chrome/91.0",
      path: "/dashboard"
    }
    
    result = SecurityMonitoringService.calculate_risk_score(user.id, session_data, request_data)
    
    assert_kind_of Hash, result
    assert_includes result.keys, :score
    assert_includes result.keys, :factors
    assert result[:score] >= 0
    assert result[:score] <= 100
  end

  test "should generate security report" do
    report = SecurityMonitoringService.generate_security_report(24.hours)
    
    assert_kind_of Hash, report
    assert_includes report.keys, :period
    assert_includes report.keys, :total_alerts
    assert_includes report.keys, :alerts_by_severity
    assert_includes report.keys, :recommendations
  end

  test "should check brute force attempts and create alert" do
    ip_address = "192.168.1.100"
    
    # Simulate multiple failed attempts
    attempts = []
    6.times do
      attempts << { timestamp: Time.current }
    end
    
    Rails.cache.write("failed_attempts:#{ip_address}", attempts)
    
    assert_difference 'SecurityIncident.count', 1 do
      SecurityMonitoringService.check_brute_force_attempts(ip_address, 15.minutes)
    end
    
    incident = SecurityIncident.last
    assert_equal "brute_force_attack", incident.incident_type
    assert_equal ip_address, incident.source_ip
  end

  test "should monitor data access and alert on excessive access" do
    user = users(:one)
    
    # Simulate excessive data access
    result = SecurityMonitoringService.monitor_data_access(user.id, 150, "campaigns#index")
    
    assert result >= 150  # Should return the record count
  end

  test "should determine correct severity levels" do
    service = SecurityMonitoringService
    
    # Test critical alerts
    brute_force_data = { alert_type: "BRUTE_FORCE_ATTACK" }
    assert_equal :critical, service.send(:determine_severity, brute_force_data)
    
    # Test high alerts  
    data_access_data = { alert_type: "EXCESSIVE_DATA_ACCESS" }
    assert_equal :high, service.send(:determine_severity, data_access_data)
    
    # Test medium alerts
    rapid_requests_data = { alert_type: "RAPID_REQUESTS" }
    assert_equal :medium, service.send(:determine_severity, rapid_requests_data)
    
    # Test default (low) severity
    unknown_data = { alert_type: "UNKNOWN_TYPE" }
    assert_equal :low, service.send(:determine_severity, unknown_data)
  end

  test "should properly map alert types to incident types" do
    service = SecurityMonitoringService
    
    assert_equal "brute_force_attack", service.send(:map_alert_to_incident_type, "BRUTE_FORCE_ATTACK")
    assert_equal "privilege_escalation", service.send(:map_alert_to_incident_type, "PRIVILEGE_ESCALATION") 
    assert_equal "excessive_data_access", service.send(:map_alert_to_incident_type, "EXCESSIVE_DATA_ACCESS")
    assert_equal "suspicious_login", service.send(:map_alert_to_incident_type, "UNKNOWN_TYPE")
  end

  test "should generate appropriate incident titles" do
    service = SecurityMonitoringService
    
    brute_force_data = { alert_type: "BRUTE_FORCE_ATTACK", ip_address: "192.168.1.1" }
    title = service.send(:generate_incident_title, brute_force_data)
    assert_includes title, "192.168.1.1"
    assert_includes title, "Brute force"
    
    privilege_data = { alert_type: "PRIVILEGE_ESCALATION", user_id: 123 }
    title = service.send(:generate_incident_title, privilege_data)
    assert_includes title, "123"
    assert_includes title, "Privilege escalation"
  end

  test "should extract threat indicators from alert data" do
    service = SecurityMonitoringService
    
    alert_data = {
      ip_address: "192.168.1.1",
      user_agent: "Chrome/91.0",
      threat_indicators: [
        { type: "malicious_domain", value: "evil.com", confidence: 0.9 }
      ]
    }
    
    indicators = service.send(:extract_threat_indicators, alert_data)
    
    assert_equal 3, indicators.count  # IP, user_agent, and existing indicator
    
    ip_indicator = indicators.find { |i| i[:type] == "ip_address" }
    assert_not_nil ip_indicator
    assert_equal "192.168.1.1", ip_indicator[:value]
    
    ua_indicator = indicators.find { |i| i[:type] == "user_agent" }
    assert_not_nil ua_indicator
    assert_equal "Chrome/91.0", ua_indicator[:value]
  end

  test "should identify malicious IPs correctly" do
    service = SecurityMonitoringService
    
    assert service.send(:is_malicious_ip?, "192.168.999.1")
    assert service.send(:is_malicious_ip?, "10.0.999.50")
    assert_not service.send(:is_malicious_ip?, "192.168.1.1")
    assert_not service.send(:is_malicious_ip?, "10.0.0.1")
  end

  test "should identify suspicious user agents" do
    service = SecurityMonitoringService
    
    assert service.send(:is_suspicious_user_agent?, "sqlmap/1.0")
    assert service.send(:is_suspicious_user_agent?, "Nikto/2.1.6")
    assert service.send(:is_suspicious_user_agent?, "Mozilla <script>alert(1)</script>")
    assert_not service.send(:is_suspicious_user_agent?, "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
  end

  test "should calculate user risk factors" do
    service = SecurityMonitoringService
    admin_user = users(:one)
    admin_user.update!(role: 'admin')
    
    score, factors = service.send(:calculate_user_risk, admin_user.id)
    
    assert score >= 10  # Admin users have base risk
    assert_includes factors, 'admin_user'
  end

  test "should calculate session risk factors" do
    service = SecurityMonitoringService
    
    old_session_data = { created_at: 25.hours.ago }
    score, factors = service.send(:calculate_session_risk, old_session_data)
    
    assert score >= 10  # Old sessions have risk
    assert_includes factors, 'old_session'
  end

  test "should calculate environmental risk factors" do
    service = SecurityMonitoringService
    
    malicious_request = {
      ip_address: "192.168.999.1",  # Known malicious pattern
      user_agent: "sqlmap/1.0"     # Suspicious user agent
    }
    
    score, factors = service.send(:calculate_environmental_risk, malicious_request)
    
    assert score >= 25  # Should detect malicious IP
    assert_includes factors, 'malicious_ip'
    assert_includes factors, 'suspicious_user_agent'
  end

  test "instance methods should work with proper initialization" do
    user = users(:one)
    session = Session.create!(user: user, ip_address: "192.168.1.1", user_agent: "Chrome/91.0")
    request_struct = Struct.new(:remote_ip)
    request = request_struct.new("192.168.1.2")
    
    service = SecurityMonitoringService.new(user: user, session: session, request: request)
    
    security_score = service.monitor_session_security
    
    assert_kind_of Numeric, security_score
    assert security_score >= 0
    assert security_score <= 100
  end
end