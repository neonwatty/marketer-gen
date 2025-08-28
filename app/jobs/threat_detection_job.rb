class ThreatDetectionJob < ApplicationJob
  queue_as :security
  
  # Retry configuration for security-critical jobs
  retry_on StandardError, wait: 10.seconds, attempts: 3
  retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 2
  discard_on ActiveJob::DeserializationError
  
  # Error reporting for failed threat detection
  rescue_from StandardError do |exception|
    Rails.error.report(exception, context: {
      job_class: self.class.name,
      arguments: arguments,
      queue_name: queue_name
    })
    
    Rails.logger.error "[THREAT_DETECTION_ERROR] #{exception.message}"
    raise exception
  end

  # Main threat detection analysis
  def perform(analysis_type, **options)
    case analysis_type
    when 'behavioral_analysis'
      perform_behavioral_analysis(options)
    when 'threat_intelligence_scan'
      perform_threat_intelligence_scan(options)
    when 'attack_pattern_analysis'
      perform_attack_pattern_analysis(options)
    when 'risk_assessment'
      perform_risk_assessment(options)
    when 'scheduled_full_scan'
      perform_scheduled_full_scan(options)
    else
      raise ArgumentError, "Unknown analysis type: #{analysis_type}"
    end
  end

  private

  # Behavioral anomaly detection using ML-style analysis
  def perform_behavioral_analysis(options = {})
    Rails.logger.info "[THREAT_DETECTION] Starting behavioral analysis"
    
    time_window = options[:time_window] || 7.days
    user_ids = options[:user_ids] || get_active_user_ids(time_window)
    
    anomalies_detected = 0
    
    user_ids.each do |user_id|
      begin
        anomalies = SecurityMonitoringService.detect_behavioral_anomalies(user_id, time_window)
        
        if anomalies.any?
          anomalies_detected += anomalies.count
          
          # Create detailed incident if high-severity anomalies found
          high_severity_anomalies = anomalies.select { |a| a[:severity] == :high }
          if high_severity_anomalies.any?
            create_behavioral_incident(user_id, high_severity_anomalies)
          end
        end
        
      rescue => e
        Rails.logger.error "[BEHAVIORAL_ANALYSIS_ERROR] User #{user_id}: #{e.message}"
        next
      end
    end
    
    Rails.logger.info "[THREAT_DETECTION] Behavioral analysis complete. Anomalies detected: #{anomalies_detected}"
    
    # Schedule follow-up analysis if anomalies found
    if anomalies_detected > 5
      ThreatDetectionJob.set(wait: 1.hour).perform_later('behavioral_analysis', 
        time_window: 2.hours, 
        user_ids: user_ids
      )
    end
    
    anomalies_detected
  end

  # Threat intelligence scanning and correlation
  def perform_threat_intelligence_scan(options = {})
    Rails.logger.info "[THREAT_DETECTION] Starting threat intelligence scan"
    
    time_window = options[:time_window] || 1.hour
    ip_addresses = options[:ip_addresses] || get_recent_ip_addresses(time_window)
    
    threats_detected = 0
    
    ip_addresses.each do |ip_data|
      begin
        ip_address = ip_data[:ip]
        user_agent = ip_data[:user_agent]
        
        threat_result = SecurityMonitoringService.check_threat_intelligence(ip_address, user_agent)
        
        if threat_result[:threat_score] > 70
          threats_detected += 1
          create_threat_intelligence_incident(ip_address, user_agent, threat_result)
          
          # Block high-threat IPs automatically
          if threat_result[:threat_score] > 90
            block_ip_address(ip_address, 24.hours)
          end
        end
        
      rescue => e
        Rails.logger.error "[THREAT_INTELLIGENCE_ERROR] IP #{ip_data[:ip]}: #{e.message}"
        next
      end
    end
    
    Rails.logger.info "[THREAT_DETECTION] Threat intelligence scan complete. Threats detected: #{threats_detected}"
    threats_detected
  end

  # Advanced attack pattern detection
  def perform_attack_pattern_analysis(options = {})
    Rails.logger.info "[THREAT_DETECTION] Starting attack pattern analysis"
    
    time_window = options[:time_window] || 1.hour
    
    patterns_detected = SecurityMonitoringService.analyze_attack_patterns(time_window)
    
    critical_patterns = patterns_detected.select { |p| p[:severity] == :critical }
    
    if critical_patterns.any?
      Rails.logger.warn "[CRITICAL_PATTERNS] #{critical_patterns.count} critical attack patterns detected"
      
      # Create incidents for critical patterns
      critical_patterns.each do |pattern|
        create_attack_pattern_incident(pattern)
      end
      
      # Trigger immediate defensive measures
      if critical_patterns.count > 3
        trigger_defensive_measures(critical_patterns)
      end
    end
    
    Rails.logger.info "[THREAT_DETECTION] Attack pattern analysis complete. Patterns detected: #{patterns_detected.count}"
    patterns_detected.count
  end

  # Real-time risk assessment
  def perform_risk_assessment(options = {})
    Rails.logger.info "[THREAT_DETECTION] Starting risk assessment"
    
    high_risk_sessions = identify_high_risk_sessions(options)
    
    high_risk_sessions.each do |session_data|
      begin
        risk_result = SecurityMonitoringService.calculate_risk_score(
          session_data[:user_id],
          session_data,
          session_data[:request_data]
        )
        
        if risk_result[:score] > 85
          create_high_risk_incident(session_data, risk_result)
          
          # Consider terminating extremely high-risk sessions
          if risk_result[:score] > 95
            terminate_high_risk_session(session_data)
          end
        end
        
      rescue => e
        Rails.logger.error "[RISK_ASSESSMENT_ERROR] Session #{session_data[:id]}: #{e.message}"
        next
      end
    end
    
    Rails.logger.info "[THREAT_DETECTION] Risk assessment complete. High-risk sessions: #{high_risk_sessions.count}"
    high_risk_sessions.count
  end

  # Comprehensive security scan
  def perform_scheduled_full_scan(options = {})
    Rails.logger.info "[THREAT_DETECTION] Starting scheduled full security scan"
    
    scan_results = {
      behavioral_anomalies: 0,
      threat_intelligence_matches: 0,
      attack_patterns: 0,
      high_risk_sessions: 0,
      total_incidents_created: 0
    }
    
    # Run all analysis types
    scan_results[:behavioral_anomalies] = perform_behavioral_analysis(time_window: 24.hours)
    scan_results[:threat_intelligence_matches] = perform_threat_intelligence_scan(time_window: 6.hours)
    scan_results[:attack_patterns] = perform_attack_pattern_analysis(time_window: 2.hours)
    scan_results[:high_risk_sessions] = perform_risk_assessment(time_window: 1.hour)
    
    # Count incidents created in the last hour (during this scan)
    scan_results[:total_incidents_created] = SecurityIncident
      .where('created_at > ?', 1.hour.ago)
      .count
    
    # Generate comprehensive security report
    security_report = SecurityMonitoringService.generate_security_report(24.hours)
    
    Rails.logger.info "[FULL_SCAN_COMPLETE] #{scan_results.to_json}"
    
    # Schedule next scan
    schedule_next_full_scan
    
    # Send report to security team if significant threats detected
    if scan_results[:total_incidents_created] > 10
      send_security_alert_report(scan_results, security_report)
    end
    
    scan_results
  end

  # Support methods for threat detection

  def get_active_user_ids(time_window)
    # In real implementation, would query session/activity logs
    # For now, return active users with sessions
    User.joins(:sessions)
        .where('sessions.created_at > ?', time_window.ago)
        .distinct
        .pluck(:id)
        .first(100) # Limit for performance
  end

  def get_recent_ip_addresses(time_window)
    # Simulate getting recent IP addresses with user agents
    # In real implementation, would query access logs
    [
      { ip: '192.168.1.100', user_agent: 'Mozilla/5.0 Chrome/91.0' },
      { ip: '10.0.0.50', user_agent: 'curl/7.68.0' },
      { ip: '127.0.0.1', user_agent: 'bot/scanner' }
    ]
  end

  def identify_high_risk_sessions(options = {})
    # Simulate high-risk session identification
    # In real implementation, would analyze session data
    Session.where('sessions.created_at > ?', 1.hour.ago)
           .joins(:user)
           .select('sessions.*, users.id as user_id')
           .map do |session|
             {
               id: session.id,
               user_id: session.user_id,
               ip_address: session.ip_address,
               user_agent: session.user_agent,
               created_at: session.created_at,
               request_data: { 
                 ip_address: session.ip_address,
                 user_agent: session.user_agent,
                 path: '/admin'  # Simulate admin path access
               }
             }
           end
  end

  def create_behavioral_incident(user_id, anomalies)
    SecurityIncident.create!(
      incident_type: 'activity_anomaly',
      severity: 'high',
      status: 'open',
      title: "Multiple behavioral anomalies detected for user #{user_id}",
      description: "Automated threat detection identified #{anomalies.count} behavioral anomalies: #{anomalies.map { |a| a[:type] }.join(', ')}",
      user_id: user_id,
      metadata: { anomalies: anomalies, detection_job: 'behavioral_analysis' },
      threat_indicators: anomalies.map { |a| { type: a[:type], value: a[:details], confidence: 0.8 } }
    )
  end

  def create_threat_intelligence_incident(ip_address, user_agent, threat_result)
    SecurityIncident.create!(
      incident_type: 'suspicious_login',
      severity: threat_result[:threat_score] > 90 ? 'critical' : 'high',
      status: 'open',
      title: "Threat intelligence match for IP #{ip_address}",
      description: "IP address matched threat intelligence sources with score #{threat_result[:threat_score]}",
      source_ip: ip_address,
      user_agent: user_agent,
      metadata: { threat_score: threat_result[:threat_score], detection_job: 'threat_intelligence_scan' },
      threat_indicators: threat_result[:indicators]
    )
  end

  def create_attack_pattern_incident(pattern)
    SecurityIncident.create!(
      incident_type: 'unauthorized_access',
      severity: pattern[:severity].to_s,
      status: 'open',
      title: "Attack pattern detected: #{pattern[:type]}",
      description: "Advanced pattern analysis detected #{pattern[:type]} with #{(pattern[:confidence] * 100).round}% confidence. Details: #{pattern[:details]}",
      metadata: { 
        pattern_type: pattern[:type],
        confidence: pattern[:confidence],
        affected_resources: pattern[:affected_resources],
        detection_job: 'attack_pattern_analysis'
      },
      threat_indicators: [
        { type: 'attack_pattern', value: pattern[:type], confidence: pattern[:confidence] }
      ]
    )
  end

  def create_high_risk_incident(session_data, risk_result)
    SecurityIncident.create!(
      incident_type: 'session_hijacking',
      severity: risk_result[:score] > 95 ? 'critical' : 'high',
      status: 'open',
      title: "High-risk session detected (score: #{risk_result[:score]})",
      description: "Session risk assessment identified session with #{risk_result[:score]} risk score. Risk factors: #{risk_result[:factors].join(', ')}",
      user_id: session_data[:user_id],
      source_ip: session_data[:ip_address],
      user_agent: session_data[:user_agent],
      metadata: { 
        risk_score: risk_result[:score],
        risk_factors: risk_result[:factors],
        session_data: session_data.slice(:id, :created_at),
        detection_job: 'risk_assessment'
      },
      threat_indicators: risk_result[:factors].map { |f| { type: 'risk_factor', value: f, confidence: 0.7 } }
    )
  end

  def block_ip_address(ip_address, duration)
    cache_key = "blocked_ip:#{ip_address}"
    Rails.cache.write(cache_key, true, expires_in: duration)
    Rails.logger.warn "[AUTO_BLOCK] IP #{ip_address} blocked for #{duration} due to high threat score"
  end

  def trigger_defensive_measures(critical_patterns)
    Rails.logger.warn "[DEFENSIVE_MEASURES] Triggering defensive measures for #{critical_patterns.count} critical patterns"
    
    # In real implementation, would trigger:
    # - Rate limiting increases
    # - Additional monitoring
    # - Alert security team
    # - Temporary access restrictions
  end

  def terminate_high_risk_session(session_data)
    Rails.logger.warn "[SESSION_TERMINATION] Terminating high-risk session #{session_data[:id]}"
    
    # Find and terminate the session
    session = Session.find_by(id: session_data[:id])
    if session
      session.destroy
      Rails.logger.info "[SESSION_TERMINATED] Session #{session_data[:id]} terminated due to high risk score"
    end
  end

  def schedule_next_full_scan
    # Schedule next full scan in 6 hours
    ThreatDetectionJob.set(wait: 6.hours).perform_later('scheduled_full_scan')
    Rails.logger.info "[SCHEDULING] Next full security scan scheduled in 6 hours"
  end

  def send_security_alert_report(scan_results, security_report)
    # In real implementation, would send email/Slack notification
    Rails.logger.warn "[SECURITY_ALERT] High threat activity detected. Scan results: #{scan_results.to_json}"
  end
end