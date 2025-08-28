class SecurityMonitoringService
  # Security alert severity levels
  SEVERITY_LEVELS = {
    low: 1,
    medium: 2,
    high: 3,
    critical: 4
  }.freeze

  # Thresholds for different alert types
  ALERT_THRESHOLDS = {
    rapid_requests: { count: 5, window: 10.seconds, severity: :medium },
    failed_logins: { count: 5, window: 15.minutes, severity: :high },
    privilege_escalation: { count: 1, window: 1.hour, severity: :critical },
    suspicious_navigation: { count: 3, window: 5.minutes, severity: :medium },
    data_access_anomaly: { count: 10, window: 1.minute, severity: :high }
  }.freeze

  class << self
    # Main method to send security alerts
    def send_alert(alert_data)
      severity = determine_severity(alert_data)
      alert_id = generate_alert_id
      
      # Log the alert with structured data
      log_security_alert(alert_data, severity, alert_id)
      
      # Store alert in database for analysis
      store_alert(alert_data, severity, alert_id)
      
      # Create security incident for high severity alerts
      create_security_incident(alert_data, severity, alert_id) if should_create_incident?(severity)
      
      # Send notifications based on severity
      send_notifications(alert_data, severity, alert_id) if should_notify?(severity)
      
      # Take automated actions if needed
      take_automated_actions(alert_data, severity) if should_auto_respond?(severity)
      
      alert_id
    end

    # Analyze activity patterns for anomalies
    def analyze_user_activity(user_id, time_window = 1.hour)
      activities = fetch_user_activities(user_id, time_window)
      anomalies = detect_anomalies(activities)
      
      if anomalies.any?
        alert_data = {
          alert_type: "ACTIVITY_ANOMALY",
          user_id: user_id,
          anomalies: anomalies,
          activity_count: activities.count,
          time_window: time_window,
          timestamp: Time.current
        }
        
        send_alert(alert_data)
      end
      
      anomalies
    end

    # Check for brute force attacks
    def check_brute_force_attempts(ip_address, time_window = 15.minutes)
      cache_key = "failed_attempts:#{ip_address}"
      attempts = Rails.cache.read(cache_key) || []
      
      # Clean old attempts
      cutoff_time = time_window.ago
      recent_attempts = attempts.select { |attempt| attempt[:timestamp] > cutoff_time }
      
      if recent_attempts.count >= ALERT_THRESHOLDS[:failed_logins][:count]
        alert_data = {
          alert_type: "BRUTE_FORCE_ATTACK",
          ip_address: ip_address,
          attempt_count: recent_attempts.count,
          time_window: time_window,
          timestamp: Time.current
        }
        
        send_alert(alert_data)
        
        # Block IP temporarily
        block_ip_address(ip_address, 1.hour)
      end
      
      recent_attempts.count
    end

    # Monitor for data exfiltration patterns
    def monitor_data_access(user_id, accessed_records_count, controller_action)
      cache_key = "data_access:#{user_id}"
      recent_access = Rails.cache.read(cache_key) || []
      
      # Track current access
      current_access = {
        controller_action: controller_action,
        record_count: accessed_records_count,
        timestamp: Time.current
      }
      
      recent_access << current_access
      
      # Keep only last hour of activity
      one_hour_ago = 1.hour.ago
      recent_access = recent_access.select { |access| access[:timestamp] > one_hour_ago }
      
      # Calculate total records accessed in last hour
      total_records = recent_access.sum { |access| access[:record_count] }
      
      # Alert if excessive data access
      if total_records > 100 # Configurable threshold
        alert_data = {
          alert_type: "EXCESSIVE_DATA_ACCESS",
          user_id: user_id,
          total_records_accessed: total_records,
          access_pattern: recent_access,
          timestamp: Time.current
        }
        
        send_alert(alert_data)
      end
      
      # Update cache
      Rails.cache.write(cache_key, recent_access, expires_in: 1.hour)
      
      total_records
    end

    # Advanced ML-based anomaly detection
    def detect_behavioral_anomalies(user_id, time_window = 7.days)
      user_behavior = analyze_user_behavior_patterns(user_id, time_window)
      baseline = get_user_baseline(user_id)
      
      anomalies = []
      
      # Detect login time anomalies
      if user_behavior[:avg_login_hour] && baseline[:typical_login_hours]
        if !baseline[:typical_login_hours].include?(user_behavior[:avg_login_hour])
          anomalies << {
            type: 'unusual_login_time',
            severity: :medium,
            details: "Login at hour #{user_behavior[:avg_login_hour]} is unusual"
          }
        end
      end
      
      # Detect access pattern anomalies
      if user_behavior[:access_frequency] > (baseline[:avg_access_frequency] * 3)
        anomalies << {
          type: 'excessive_access_frequency',
          severity: :high,
          details: "Access frequency #{user_behavior[:access_frequency]} is #{(user_behavior[:access_frequency] / baseline[:avg_access_frequency]).round(2)}x normal"
        }
      end
      
      # Detect geographic anomalies
      if user_behavior[:new_locations] && user_behavior[:new_locations].any?
        anomalies << {
          type: 'geographic_anomaly',
          severity: :medium,
          details: "Access from new locations: #{user_behavior[:new_locations].join(', ')}"
        }
      end
      
      # Create alerts for significant anomalies
      anomalies.each do |anomaly|
        alert_data = {
          alert_type: "BEHAVIORAL_ANOMALY",
          user_id: user_id,
          anomaly_type: anomaly[:type],
          severity: anomaly[:severity],
          details: anomaly[:details],
          behavior_data: user_behavior,
          timestamp: Time.current
        }
        send_alert(alert_data)
      end
      
      anomalies
    end

    # Threat intelligence integration
    def check_threat_intelligence(ip_address, user_agent = nil)
      threat_score = 0
      threat_indicators = []
      
      # Check against known malicious IPs (simulated)
      if is_malicious_ip?(ip_address)
        threat_score += 75
        threat_indicators << {
          type: 'malicious_ip',
          value: ip_address,
          confidence: 0.9
        }
      end
      
      # Check user agent patterns
      if user_agent && is_suspicious_user_agent?(user_agent)
        threat_score += 25
        threat_indicators << {
          type: 'suspicious_user_agent',
          value: user_agent,
          confidence: 0.7
        }
      end
      
      # Check for known attack patterns
      attack_patterns = detect_attack_patterns(ip_address)
      attack_patterns.each do |pattern|
        threat_score += pattern[:score]
        threat_indicators << pattern[:indicator]
      end
      
      if threat_score > 50 # High threat threshold
        alert_data = {
          alert_type: "THREAT_INTELLIGENCE_MATCH",
          ip_address: ip_address,
          user_agent: user_agent,
          threat_score: threat_score,
          threat_indicators: threat_indicators,
          timestamp: Time.current
        }
        send_alert(alert_data)
      end
      
      { threat_score: threat_score, indicators: threat_indicators }
    end

    # Advanced pattern recognition for attack detection
    def analyze_attack_patterns(time_window = 1.hour)
      patterns_detected = []
      
      # Detect coordinated attacks
      coordinated_attack = detect_coordinated_attack(time_window)
      patterns_detected << coordinated_attack if coordinated_attack
      
      # Detect privilege escalation attempts
      privilege_escalation = detect_privilege_escalation_patterns(time_window)
      patterns_detected << privilege_escalation if privilege_escalation
      
      # Detect data exfiltration patterns
      data_exfiltration = detect_data_exfiltration_patterns(time_window)
      patterns_detected << data_exfiltration if data_exfiltration
      
      patterns_detected.each do |pattern|
        alert_data = {
          alert_type: "ATTACK_PATTERN_DETECTED",
          pattern_type: pattern[:type],
          severity: pattern[:severity],
          confidence: pattern[:confidence],
          details: pattern[:details],
          affected_resources: pattern[:affected_resources],
          timestamp: Time.current
        }
        send_alert(alert_data)
      end
      
      patterns_detected
    end

    # Real-time risk assessment
    def calculate_risk_score(user_id, session_data, request_data)
      risk_factors = []
      total_score = 0
      
      # User risk factors
      user_score, user_factors = calculate_user_risk(user_id)
      total_score += user_score
      risk_factors.concat(user_factors)
      
      # Session risk factors
      session_score, session_factors = calculate_session_risk(session_data)
      total_score += session_score
      risk_factors.concat(session_factors)
      
      # Request risk factors
      request_score, request_factors = calculate_request_risk(request_data)
      total_score += request_score
      risk_factors.concat(request_factors)
      
      # Environmental factors
      env_score, env_factors = calculate_environmental_risk(request_data)
      total_score += env_score
      risk_factors.concat(env_factors)
      
      # Normalize score to 0-100 scale
      normalized_score = [total_score, 100].min
      
      if normalized_score > 75
        alert_data = {
          alert_type: "HIGH_RISK_SESSION",
          user_id: user_id,
          risk_score: normalized_score,
          risk_factors: risk_factors,
          session_data: session_data&.slice(:id, :ip_address, :user_agent),
          timestamp: Time.current
        }
        send_alert(alert_data)
      end
      
      { score: normalized_score, factors: risk_factors }
    end

    # Generate security reports
    def generate_security_report(time_period = 24.hours)
      end_time = Time.current
      start_time = end_time - time_period
      
      report = {
        period: "#{start_time.strftime('%Y-%m-%d %H:%M')} to #{end_time.strftime('%Y-%m-%d %H:%M')}",
        total_alerts: count_alerts_in_period(start_time, end_time),
        alerts_by_severity: alerts_by_severity_in_period(start_time, end_time),
        top_threat_sources: top_threat_sources_in_period(start_time, end_time),
        blocked_ips: list_blocked_ips,
        suspicious_users: identify_suspicious_users(start_time, end_time),
        recommendations: generate_security_recommendations
      }
      
      Rails.logger.info "[SECURITY_REPORT] #{report.to_json}"
      report
    end

    private

    def determine_severity(alert_data)
      case alert_data[:alert_type]
      when "BRUTE_FORCE_ATTACK", "PRIVILEGE_ESCALATION"
        :critical
      when "EXCESSIVE_DATA_ACCESS", "SUSPICIOUS_ACTIVITY"
        :high
      when "RAPID_REQUESTS", "UNUSUAL_NAVIGATION"
        :medium
      else
        :low
      end
    end

    def generate_alert_id
      "SEC_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
    end

    def log_security_alert(alert_data, severity, alert_id)
      log_entry = {
        alert_id: alert_id,
        severity: severity,
        timestamp: Time.current.iso8601,
        **alert_data
      }
      
      case severity
      when :critical
        Rails.logger.error "[CRITICAL_SECURITY_ALERT] #{log_entry.to_json}"
      when :high
        Rails.logger.warn "[HIGH_SECURITY_ALERT] #{log_entry.to_json}"
      when :medium
        Rails.logger.warn "[MEDIUM_SECURITY_ALERT] #{log_entry.to_json}"
      else
        Rails.logger.info "[LOW_SECURITY_ALERT] #{log_entry.to_json}"
      end
    end

    def store_alert(alert_data, severity, alert_id)
      # Store in Rails cache for immediate access
      cache_key = "security_alert:#{alert_id}"
      alert_record = {
        id: alert_id,
        severity: severity,
        created_at: Time.current,
        **alert_data
      }
      
      Rails.cache.write(cache_key, alert_record, expires_in: 24.hours)
      
      # Also maintain a list of recent alerts
      recent_alerts_key = "recent_security_alerts"
      recent_alerts = Rails.cache.read(recent_alerts_key) || []
      recent_alerts << alert_id
      
      # Keep only last 100 alerts
      recent_alerts = recent_alerts.last(100)
      Rails.cache.write(recent_alerts_key, recent_alerts, expires_in: 24.hours)
    end

    def should_notify?(severity)
      # Send notifications for medium and higher severity alerts
      SEVERITY_LEVELS[severity] >= SEVERITY_LEVELS[:medium]
    end

    def should_auto_respond?(severity)
      # Take automated actions for high and critical alerts
      SEVERITY_LEVELS[severity] >= SEVERITY_LEVELS[:high]
    end

    def send_notifications(alert_data, severity, alert_id)
      # In a real application, this would send emails, Slack messages, etc.
      Rails.logger.info "[SECURITY_NOTIFICATION] Alert #{alert_id} with severity #{severity} triggered"
      
      # Example: Email notification for critical alerts
      if severity == :critical
        # SecurityMailer.critical_alert(alert_data, alert_id).deliver_later
      end
    end

    def take_automated_actions(alert_data, severity)
      case alert_data[:alert_type]
      when "BRUTE_FORCE_ATTACK"
        block_ip_address(alert_data[:ip_address], 1.hour) if alert_data[:ip_address]
      when "PRIVILEGE_ESCALATION"
        # Could terminate user sessions or require re-authentication
        if alert_data[:user_id]
          user = User.find_by(id: alert_data[:user_id])
          user&.terminate_all_sessions!
        end
      when "EXCESSIVE_DATA_ACCESS"
        # Could temporarily restrict user permissions
        Rails.logger.warn "[AUTO_ACTION] Consider reviewing user #{alert_data[:user_id]} permissions"
      end
    end

    def block_ip_address(ip_address, duration)
      cache_key = "blocked_ip:#{ip_address}"
      Rails.cache.write(cache_key, true, expires_in: duration)
      Rails.logger.warn "[AUTO_ACTION] IP #{ip_address} blocked for #{duration}"
    end

    def fetch_user_activities(user_id, time_window)
      # This would typically query a database or log aggregation system
      # For now, return mock data structure
      []
    end

    def detect_anomalies(activities)
      anomalies = []
      
      # Check for unusual time patterns
      if activities.any? { |a| a[:timestamp].hour.between?(2, 5) }
        anomalies << "unusual_time_access"
      end
      
      # Check for rapid sequential actions
      if activities.group_by { |a| a[:action] }.any? { |_, actions| actions.count > 10 }
        anomalies << "repetitive_actions"
      end
      
      anomalies
    end

    def count_alerts_in_period(start_time, end_time)
      # Would query stored alerts in real implementation
      0
    end

    def alerts_by_severity_in_period(start_time, end_time)
      { critical: 0, high: 0, medium: 0, low: 0 }
    end

    def top_threat_sources_in_period(start_time, end_time)
      []
    end

    def list_blocked_ips
      # Get currently blocked IPs from cache
      blocked_ips = []
      # This would scan cache for blocked_ip:* keys in real implementation
      blocked_ips
    end

    def identify_suspicious_users(start_time, end_time)
      []
    end

    def generate_security_recommendations
      [
        "Review user access patterns regularly",
        "Implement additional rate limiting for sensitive endpoints",
        "Consider enabling two-factor authentication for admin users",
        "Monitor for unusual geographic access patterns"
      ]
    end

    # New private methods for enhanced threat detection

    def should_create_incident?(severity)
      SEVERITY_LEVELS[severity] >= SEVERITY_LEVELS[:high]
    end

    def create_security_incident(alert_data, severity, alert_id)
      incident_type = map_alert_to_incident_type(alert_data[:alert_type])
      
      SecurityIncident.create!(
        incident_id: alert_id,
        incident_type: incident_type,
        severity: severity.to_s,
        status: 'open',
        title: generate_incident_title(alert_data),
        description: generate_incident_description(alert_data),
        user_id: alert_data[:user_id],
        source_ip: alert_data[:ip_address],
        user_agent: alert_data[:user_agent],
        metadata: alert_data,
        threat_indicators: extract_threat_indicators(alert_data)
      )
    end

    def map_alert_to_incident_type(alert_type)
      case alert_type
      when "BRUTE_FORCE_ATTACK" then "brute_force_attack"
      when "PRIVILEGE_ESCALATION" then "privilege_escalation"
      when "EXCESSIVE_DATA_ACCESS" then "excessive_data_access"
      when "BEHAVIORAL_ANOMALY" then "activity_anomaly"
      when "THREAT_INTELLIGENCE_MATCH" then "suspicious_login"
      when "ATTACK_PATTERN_DETECTED" then "unauthorized_access"
      when "HIGH_RISK_SESSION" then "session_hijacking"
      else "suspicious_login"
      end
    end

    def generate_incident_title(alert_data)
      case alert_data[:alert_type]
      when "BRUTE_FORCE_ATTACK"
        "Brute force attack detected from #{alert_data[:ip_address]}"
      when "PRIVILEGE_ESCALATION"
        "Privilege escalation attempt by user #{alert_data[:user_id]}"
      when "EXCESSIVE_DATA_ACCESS"
        "Excessive data access by user #{alert_data[:user_id]}"
      when "BEHAVIORAL_ANOMALY"
        "Behavioral anomaly detected: #{alert_data[:anomaly_type]}"
      when "THREAT_INTELLIGENCE_MATCH"
        "Threat intelligence match for IP #{alert_data[:ip_address]}"
      when "ATTACK_PATTERN_DETECTED"
        "Attack pattern detected: #{alert_data[:pattern_type]}"
      when "HIGH_RISK_SESSION"
        "High-risk session detected for user #{alert_data[:user_id]}"
      else
        "Security incident: #{alert_data[:alert_type]}"
      end
    end

    def generate_incident_description(alert_data)
      base_description = "Security incident automatically generated from alert #{alert_data[:timestamp]}"
      
      case alert_data[:alert_type]
      when "BRUTE_FORCE_ATTACK"
        "#{base_description}. Detected #{alert_data[:attempt_count]} failed login attempts from IP #{alert_data[:ip_address]} within #{alert_data[:time_window]}."
      when "PRIVILEGE_ESCALATION"
        "#{base_description}. User #{alert_data[:user_id]} attempted to access privileged resources or escalate permissions."
      when "EXCESSIVE_DATA_ACCESS"
        "#{base_description}. User #{alert_data[:user_id]} accessed #{alert_data[:total_records_accessed]} records, exceeding normal patterns."
      when "BEHAVIORAL_ANOMALY"
        "#{base_description}. Detected unusual behavior: #{alert_data[:details]}. Behavior data: #{alert_data[:behavior_data]&.to_json}"
      when "THREAT_INTELLIGENCE_MATCH"
        "#{base_description}. IP #{alert_data[:ip_address]} matched threat intelligence with score #{alert_data[:threat_score]}. Indicators: #{alert_data[:threat_indicators]&.map { |i| i[:type] }&.join(', ')}"
      else
        "#{base_description}. Alert details: #{alert_data.except(:timestamp).to_json}"
      end
    end

    def extract_threat_indicators(alert_data)
      indicators = []
      
      if alert_data[:ip_address]
        indicators << {
          type: 'ip_address',
          value: alert_data[:ip_address],
          confidence: 0.8
        }
      end
      
      if alert_data[:user_agent]
        indicators << {
          type: 'user_agent',
          value: alert_data[:user_agent],
          confidence: 0.6
        }
      end
      
      if alert_data[:threat_indicators]
        indicators.concat(alert_data[:threat_indicators])
      end
      
      indicators
    end

    # Support methods for behavioral analysis
    def analyze_user_behavior_patterns(user_id, time_window)
      # Simulate behavioral analysis - in real implementation would analyze logs/database
      {
        avg_login_hour: rand(24),
        access_frequency: rand(10..50),
        new_locations: rand > 0.8 ? ['New York', 'London'] : [],
        typical_actions: ['login', 'view_dashboard', 'create_content']
      }
    end

    def get_user_baseline(user_id)
      # Simulate baseline data - in real implementation would be stored/calculated
      {
        typical_login_hours: (9..17).to_a,
        avg_access_frequency: 25,
        typical_locations: ['San Francisco', 'Remote'],
        avg_session_duration: 3.hours
      }
    end

    # Threat intelligence methods
    def is_malicious_ip?(ip_address)
      # Simulate threat intelligence check
      malicious_patterns = ['192.168.999', '10.0.999', '127.0.0']
      malicious_patterns.any? { |pattern| ip_address.include?(pattern) }
    end

    def is_suspicious_user_agent?(user_agent)
      # Check for suspicious patterns in user agent
      suspicious_patterns = [
        /sqlmap/i, /nikto/i, /nmap/i, /burp/i,
        /bot/i, /crawler/i, /spider/i,
        /<script>/i, /javascript:/i
      ]
      suspicious_patterns.any? { |pattern| user_agent.match?(pattern) }
    end

    def detect_attack_patterns(ip_address)
      # Simulate attack pattern detection
      patterns = []
      
      # Random pattern detection for demonstration
      if rand > 0.7
        patterns << {
          score: 30,
          indicator: {
            type: 'scanning_pattern',
            value: "Sequential port scanning detected from #{ip_address}",
            confidence: 0.8
          }
        }
      end
      
      patterns
    end

    # Advanced pattern detection methods
    def detect_coordinated_attack(time_window)
      # Simulate coordinated attack detection
      return nil unless rand > 0.9
      
      {
        type: 'coordinated_brute_force',
        severity: :high,
        confidence: 0.85,
        details: 'Multiple IPs targeting same endpoints simultaneously',
        affected_resources: ['/login', '/admin']
      }
    end

    def detect_privilege_escalation_patterns(time_window)
      # Simulate privilege escalation detection
      return nil unless rand > 0.95
      
      {
        type: 'privilege_escalation',
        severity: :critical,
        confidence: 0.9,
        details: 'Unusual admin endpoint access patterns detected',
        affected_resources: ['/admin/users', '/admin/settings']
      }
    end

    def detect_data_exfiltration_patterns(time_window)
      # Simulate data exfiltration detection
      return nil unless rand > 0.92
      
      {
        type: 'data_exfiltration',
        severity: :critical,
        confidence: 0.88,
        details: 'Large volume data access patterns consistent with exfiltration',
        affected_resources: ['/api/users', '/api/campaigns']
      }
    end

    # Risk scoring methods
    def calculate_user_risk(user_id)
      return [0, []] unless user_id
      
      user = User.find_by(id: user_id)
      return [0, []] unless user
      
      score = 0
      factors = []
      
      # Admin users have higher base risk
      if user.admin?
        score += 10
        factors << 'admin_user'
      end
      
      # Check user history
      if SecurityIncident.where(user_id: user_id).where('created_at > ?', 30.days.ago).exists?
        score += 15
        factors << 'previous_incidents'
      end
      
      [score, factors]
    end

    def calculate_session_risk(session_data)
      return [0, []] unless session_data
      
      score = 0
      factors = []
      
      # Old sessions are riskier
      if session_data[:created_at] && session_data[:created_at] < 24.hours.ago
        score += 10
        factors << 'old_session'
      end
      
      # Different IP than usual
      if session_data[:ip_changed]
        score += 20
        factors << 'ip_change'
      end
      
      [score, factors]
    end

    def calculate_request_risk(request_data)
      return [0, []] unless request_data
      
      score = 0
      factors = []
      
      # Check for suspicious patterns in request
      if request_data[:path]&.include?('admin')
        score += 5
        factors << 'admin_path_access'
      end
      
      # Unusual request timing
      if Time.current.hour.between?(2, 5)
        score += 8
        factors << 'unusual_time'
      end
      
      [score, factors]
    end

    def calculate_environmental_risk(request_data)
      return [0, []] unless request_data
      
      score = 0
      factors = []
      
      # Check threat intelligence for IP
      if request_data[:ip_address] && is_malicious_ip?(request_data[:ip_address])
        score += 25
        factors << 'malicious_ip'
      end
      
      # Check user agent
      if request_data[:user_agent] && is_suspicious_user_agent?(request_data[:user_agent])
        score += 15
        factors << 'suspicious_user_agent'
      end
      
      [score, factors]
    end
  end

  # Instance methods for specific monitoring scenarios
  def initialize(user: nil, session: nil, request: nil)
    @user = user
    @session = session
    @request = request
  end

  def monitor_session_security
    return unless @session && @user
    
    security_score = calculate_session_security_score
    
    if security_score < 50 # Low security score threshold
      alert_data = {
        alert_type: "LOW_SESSION_SECURITY",
        user_id: @user.id,
        session_id: @session.id,
        security_score: security_score,
        factors: session_risk_factors,
        timestamp: Time.current
      }
      
      self.class.send_alert(alert_data)
    end
    
    security_score
  end

  private

  def calculate_session_security_score
    score = 100
    
    # Deduct for old sessions
    session_age = Time.current - @session.created_at
    score -= (session_age / 1.day) * 5
    
    # Deduct for suspicious user agent
    score -= 20 if @session.user_agent&.length&.> 500
    
    # Deduct for IP changes
    if @request && @session.ip_address != @request.remote_ip
      score -= 30
    end
    
    [score, 0].max
  end

  def session_risk_factors
    factors = []
    factors << "old_session" if @session.created_at < 1.week.ago
    factors << "suspicious_user_agent" if @session.user_agent&.length&.> 500
    factors << "ip_mismatch" if @request && @session.ip_address != @request.remote_ip
    factors
  end
end