class ComplianceRequirement < ApplicationRecord
  belongs_to :user
  has_many :compliance_assessments, dependent: :destroy
  has_many :compliance_reports, dependent: :destroy

  COMPLIANCE_TYPES = %w[
    gdpr
    ccpa
    hipaa
    sox
    pci_dss
    iso_27001
    custom
  ].freeze

  RISK_LEVELS = %w[low medium high critical].freeze
  STATUSES = %w[draft active monitoring non_compliant compliant archived].freeze
  FREQUENCIES = %w[daily weekly monthly quarterly annual].freeze

  validates :name, presence: true, length: { maximum: 200 }
  validates :compliance_type, inclusion: { in: COMPLIANCE_TYPES }
  validates :risk_level, inclusion: { in: RISK_LEVELS }
  validates :status, inclusion: { in: STATUSES }
  validates :monitoring_frequency, inclusion: { in: FREQUENCIES }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :regulatory_reference, length: { maximum: 500 }
  validates :implementation_deadline, presence: true
  validates :next_review_date, presence: true
  validates :responsible_party, presence: true, length: { maximum: 200 }

  validate :implementation_deadline_future_date
  validate :next_review_date_logical
  validate :custom_validation_rules

  scope :active, -> { where(status: 'active') }
  scope :high_risk, -> { where(risk_level: ['high', 'critical']) }
  scope :overdue, -> { where('implementation_deadline < ?', Time.current) }
  scope :due_soon, -> { where(implementation_deadline: Time.current..1.month.from_now) }
  scope :by_type, ->(type) { where(compliance_type: type) }
  scope :needs_review, -> { where('next_review_date <= ?', Time.current) }

  serialize :custom_rules, coder: JSON
  serialize :evidence_requirements, coder: JSON
  serialize :monitoring_criteria, coder: JSON

  before_validation :set_defaults
  after_update :log_status_changes

  def overdue?
    implementation_deadline < Time.current && !compliant?
  end

  def due_soon?
    implementation_deadline.between?(Time.current, 1.month.from_now)
  end

  def compliant?
    status == 'compliant'
  end

  def non_compliant?
    status == 'non_compliant'
  end

  def high_risk?
    %w[high critical].include?(risk_level)
  end

  def needs_review?
    next_review_date <= Time.current
  end

  def risk_score
    base_score = case risk_level
                 when 'critical' then 100
                 when 'high' then 75
                 when 'medium' then 50
                 when 'low' then 25
                 else 0
                 end

    # Adjust based on status
    status_multiplier = case status
                       when 'non_compliant' then 2.0
                       when 'monitoring' then 1.5
                       when 'active' then 1.0
                       when 'compliant' then 0.5
                       else 1.0
                       end

    # Adjust based on deadline proximity
    deadline_multiplier = if overdue?
                           2.0
                         elsif due_soon?
                           1.5
                         else
                           1.0
                         end

    (base_score * status_multiplier * deadline_multiplier).round
  end

  def compliance_percentage
    return 0 unless compliance_assessments.exists?
    
    total_criteria = compliance_assessments.sum(:total_criteria)
    met_criteria = compliance_assessments.sum(:met_criteria)
    
    return 0 if total_criteria.zero?
    
    ((met_criteria.to_f / total_criteria) * 100).round(2)
  end

  def generate_compliance_report
    ComplianceReportGenerationJob.perform_later(self)
  end

  private

  def set_defaults
    self.status ||= 'draft'
    self.risk_level ||= 'medium'
    self.monitoring_frequency ||= 'monthly'
    self.next_review_date ||= 3.months.from_now
    self.custom_rules ||= {}
    self.evidence_requirements ||= []
    self.monitoring_criteria ||= {}
  end

  def implementation_deadline_future_date
    return unless implementation_deadline.present?
    
    if status == 'draft' && implementation_deadline < Time.current
      errors.add(:implementation_deadline, 'must be in the future for draft requirements')
    end
  end

  def next_review_date_logical
    return unless next_review_date.present? && implementation_deadline.present?
    
    if next_review_date < implementation_deadline
      errors.add(:next_review_date, 'must be after implementation deadline')
    end
  end

  def custom_validation_rules
    return unless custom_rules.present? && custom_rules.is_a?(Hash)

    custom_rules.each do |rule_name, rule_config|
      next unless rule_config.is_a?(Hash) && rule_config['enabled']

      case rule_name
      when 'data_retention_period'
        validate_data_retention_rule(rule_config)
      when 'access_control_requirements'
        validate_access_control_rule(rule_config)
      when 'audit_trail_requirements'
        validate_audit_trail_rule(rule_config)
      end
    end
  end

  def validate_data_retention_rule(config)
    max_days = config['max_retention_days']
    if max_days.present? && (!max_days.is_a?(Integer) || max_days <= 0)
      errors.add(:custom_rules, 'data retention period must be a positive integer')
    end
  end

  def validate_access_control_rule(config)
    required_roles = config['required_roles']
    if required_roles.present? && !required_roles.is_a?(Array)
      errors.add(:custom_rules, 'access control roles must be an array')
    end
  end

  def validate_audit_trail_rule(config)
    retention_years = config['audit_retention_years']
    if retention_years.present? && (!retention_years.is_a?(Integer) || retention_years <= 0)
      errors.add(:custom_rules, 'audit retention period must be a positive integer')
    end
  end

  def log_status_changes
    if saved_change_to_status?
      Rails.logger.info "Compliance requirement #{id} status changed from #{saved_changes['status'][0]} to #{status}"
    end
  end
end