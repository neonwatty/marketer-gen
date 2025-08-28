require "test_helper"

class SecurityIncidentTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    incident = SecurityIncident.new(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description",
      source_ip: "192.168.1.1"
    )
    assert incident.valid?
  end

  test "should require incident_type" do
    incident = SecurityIncident.new(
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    assert_not incident.valid?
    assert_includes incident.errors[:incident_type], "can't be blank"
  end

  test "should validate incident_type inclusion" do
    incident = SecurityIncident.new(
      incident_type: "invalid_type",
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    assert_not incident.valid?
    assert_includes incident.errors[:incident_type], "is not included in the list"
  end

  test "should validate severity inclusion" do
    incident = SecurityIncident.new(
      incident_type: "brute_force_attack",
      severity: "invalid_severity",
      title: "Test incident", 
      description: "Test description"
    )
    assert_not incident.valid?
    assert_includes incident.errors[:severity], "is not included in the list"
  end

  test "should validate IP address format" do
    incident = SecurityIncident.new(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description",
      source_ip: "invalid.ip"
    )
    assert_not incident.valid?
    assert_includes incident.errors[:source_ip], "must be a valid IP address"
  end

  test "should generate incident_id before creation" do
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    assert_not_nil incident.incident_id
    assert_match /^SEC-\d{14}-[A-F0-9]{6}$/, incident.incident_id
  end

  test "should set default status" do
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    assert_equal "open", incident.status
  end

  test "should calculate severity level correctly" do
    incident = SecurityIncident.new(severity: "low")
    assert_equal 1, incident.severity_level

    incident = SecurityIncident.new(severity: "critical")
    assert_equal 4, incident.severity_level
  end

  test "should identify high severity incidents" do
    high_incident = SecurityIncident.new(severity: "high")
    critical_incident = SecurityIncident.new(severity: "critical")
    low_incident = SecurityIncident.new(severity: "low")

    assert high_incident.high_severity?
    assert critical_incident.high_severity?
    assert_not low_incident.high_severity?
  end

  test "should identify open incidents" do
    open_incident = SecurityIncident.new(status: "open")
    investigating_incident = SecurityIncident.new(status: "investigating")
    resolved_incident = SecurityIncident.new(status: "resolved")

    assert open_incident.open?
    assert investigating_incident.open?
    assert_not resolved_incident.open?
  end

  test "should calculate risk score based on factors" do
    # Base test case
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    
    base_score = incident.risk_score
    assert base_score > 0
    
    # Test with higher severity incident type
    critical_incident = SecurityIncident.create!(
      incident_type: "data_exfiltration",
      severity: "critical",
      title: "Critical incident",
      description: "Critical description"
    )
    
    assert critical_incident.risk_score > base_score
  end

  test "should add threat indicators" do
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    
    incident.add_threat_indicator("malicious_ip", "192.168.1.100", 0.9)
    
    assert_equal 1, incident.threat_indicators.count
    assert_equal "malicious_ip", incident.threat_indicators.first["type"]
    assert_equal "192.168.1.100", incident.threat_indicators.first["value"]
    assert_equal 0.9, incident.threat_indicators.first["confidence"]
  end

  test "should add response actions" do
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    
    incident.add_response_action("block_ip", "Blocked IP address 192.168.1.100")
    
    assert_equal 1, incident.response_actions.count
    assert_equal "block_ip", incident.response_actions.first["type"]
    assert_equal "Blocked IP address 192.168.1.100", incident.response_actions.first["description"]
    assert_equal "pending", incident.response_actions.first["status"]
  end

  test "should update status with notes" do
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    
    incident.update_status("investigating", "Investigation started")
    
    assert_equal "investigating", incident.status
    assert_not_nil incident.status_updated_at
    assert_equal 1, incident.metadata["status_notes"].count
    assert_equal "investigating", incident.metadata["status_notes"].first["status"]
    assert_equal "Investigation started", incident.metadata["status_notes"].first["notes"]
  end

  test "should set resolved_at when status becomes resolved" do
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description"
    )
    
    incident.update_status("resolved")
    
    assert_equal "resolved", incident.status
    assert_not_nil incident.resolved_at
    assert incident.resolved?
  end

  test "should generate comprehensive summary" do
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description",
      source_ip: "192.168.1.1"
    )
    
    incident.add_threat_indicator("malicious_ip", "192.168.1.1")
    incident.add_response_action("block_ip", "Blocked IP")
    
    summary = incident.summary
    
    assert_equal incident.incident_id, summary[:incident_id]
    assert_equal "brute_force_attack", summary[:type]
    assert_equal "high", summary[:severity]
    assert_equal "open", summary[:status]
    assert_equal "192.168.1.1", summary[:source_ip]
    assert_equal 1, summary[:threat_indicators_count]
    assert_equal 1, summary[:response_actions_count]
    assert summary[:risk_score] > 0
  end

  test "scopes should work correctly" do
    high_incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      status: "open",
      title: "High incident",
      description: "High description"
    )
    
    low_incident = SecurityIncident.create!(
      incident_type: "activity_anomaly",
      severity: "low",
      status: "resolved",
      title: "Low incident",
      description: "Low description"
    )
    
    assert_includes SecurityIncident.by_severity("high"), high_incident
    assert_not_includes SecurityIncident.by_severity("high"), low_incident
    
    assert_includes SecurityIncident.by_status("open"), high_incident
    assert_not_includes SecurityIncident.by_status("open"), low_incident
    
    assert_includes SecurityIncident.open_incidents, high_incident
    assert_not_includes SecurityIncident.open_incidents, low_incident
    
    assert_includes SecurityIncident.by_incident_type("brute_force_attack"), high_incident
    assert_not_includes SecurityIncident.by_incident_type("brute_force_attack"), low_incident
  end

  test "should serialize metadata correctly" do
    incident = SecurityIncident.create!(
      incident_type: "brute_force_attack",
      severity: "high",
      title: "Test incident",
      description: "Test description",
      metadata: { custom_field: "custom_value", count: 42 }
    )
    
    incident.reload
    assert_equal "custom_value", incident.metadata["custom_field"]
    assert_equal 42, incident.metadata["count"]
  end

  test "constants should be properly defined" do
    assert_not_empty SecurityIncident::SEVERITY_LEVELS
    assert_not_empty SecurityIncident::STATUS_VALUES 
    assert_not_empty SecurityIncident::INCIDENT_TYPES
    
    assert_includes SecurityIncident::SEVERITY_LEVELS, "low"
    assert_includes SecurityIncident::SEVERITY_LEVELS, "critical"
    
    assert_includes SecurityIncident::STATUS_VALUES, "open"
    assert_includes SecurityIncident::STATUS_VALUES, "resolved"
    
    assert_includes SecurityIncident::INCIDENT_TYPES, "brute_force_attack"
    assert_includes SecurityIncident::INCIDENT_TYPES, "data_exfiltration"
  end
end