class SecurityIncident < ApplicationRecord
  belongs_to :user, optional: true
  
  # Severity levels for security incidents
  SEVERITY_LEVELS = %w[low medium high critical].freeze
  
  # Status values for incident management
  STATUS_VALUES = %w[open investigating resolved closed false_positive].freeze
  
  # Incident types for categorization
  INCIDENT_TYPES = %w[
    brute_force_attack
    privilege_escalation
    excessive_data_access
    activity_anomaly
    suspicious_login
    malware_detected
    data_exfiltration
    unauthorized_access
    session_hijacking
    sql_injection_attempt
    xss_attempt
    ddos_attack
    insider_threat
  ].freeze

  validates :incident_type, presence: true, inclusion: { in: INCIDENT_TYPES }
  validates :severity, presence: true, inclusion: { in: SEVERITY_LEVELS }
  validates :status, presence: true, inclusion: { in: STATUS_VALUES }
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validates :source_ip, format: { 
    with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z/, 
    message: "must be a valid IP address" 
  }, allow_blank: true

  serialize :metadata, coder: JSON
  serialize :threat_indicators, coder: JSON
  serialize :response_actions, coder: JSON

  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_incident_type, ->(type) { where(incident_type: type) }
  scope :open_incidents, -> { where(status: ['open', 'investigating']) }
  scope :recent, ->(time_period = 24.hours) { where('created_at > ?', time_period.ago) }
  scope :critical_incidents, -> { where(severity: 'critical') }

  # Generate unique incident ID
  before_create :generate_incident_id
  
  # Set default status
  before_validation :set_default_status, on: :create

  def severity_level
    SEVERITY_LEVELS.index(severity) + 1
  end

  def high_severity?
    severity.in?(['high', 'critical'])
  end

  def open?
    status.in?(['open', 'investigating'])
  end

  def resolved?
    status.in?(['resolved', 'closed'])
  end

  # Calculate risk score based on various factors
  def risk_score
    base_score = severity_level * 25
    
    # Adjust for incident type severity
    type_multiplier = case incident_type
    when 'brute_force_attack', 'privilege_escalation' then 1.5
    when 'data_exfiltration', 'malware_detected' then 2.0
    when 'sql_injection_attempt', 'xss_attempt' then 1.3
    else 1.0
    end
    
    # Adjust for user involvement (insider threats are higher risk)
    user_multiplier = user_id.present? ? 1.2 : 1.0
    
    # Adjust for response time (older unresolved incidents are higher risk)
    time_factor = if open? && created_at < 1.hour.ago
      1 + ((Time.current - created_at) / 1.hour.to_f * 0.1)
    else
      1.0
    end
    
    (base_score * type_multiplier * user_multiplier * time_factor).round(2)
  end

  # Add threat indicator
  def add_threat_indicator(indicator_type, value, confidence = nil)
    self.threat_indicators ||= []
    indicator = {
      type: indicator_type,
      value: value,
      confidence: confidence,
      detected_at: Time.current
    }
    self.threat_indicators << indicator
    save!
  end

  # Add response action
  def add_response_action(action_type, description, status = 'pending')
    self.response_actions ||= []
    action = {
      type: action_type,
      description: description,
      status: status,
      timestamp: Time.current
    }
    self.response_actions << action
    save!
  end

  # Update incident status with optional notes
  def update_status(new_status, notes = nil)
    self.status = new_status
    self.status_updated_at = Time.current
    self.resolved_at = Time.current if resolved? && resolved_at.nil?
    
    if notes.present?
      self.metadata ||= {}
      self.metadata['status_notes'] ||= []
      self.metadata['status_notes'] << {
        status: new_status,
        notes: notes,
        timestamp: Time.current
      }
    end
    
    save!
  end

  # Generate incident summary for reporting
  def summary
    {
      incident_id: incident_id,
      type: incident_type,
      severity: severity,
      status: status,
      risk_score: risk_score,
      user_id: user_id,
      source_ip: source_ip,
      created_at: created_at,
      resolved_at: resolved_at,
      duration: resolved_at ? (resolved_at - created_at).to_i : nil,
      threat_indicators_count: threat_indicators&.count || 0,
      response_actions_count: response_actions&.count || 0
    }
  end

  private

  def generate_incident_id
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    random_suffix = SecureRandom.hex(3).upcase
    self.incident_id = "SEC-#{timestamp}-#{random_suffix}"
  end

  def set_default_status
    self.status ||= 'open'
  end
end