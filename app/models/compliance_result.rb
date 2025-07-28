class ComplianceResult < ApplicationRecord
  belongs_to :brand

  # Validations
  validates :content_type, presence: true
  validates :content_hash, presence: true
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :violations_count, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :compliant, -> { where(compliant: true) }
  scope :non_compliant, -> { where(compliant: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :high_score, -> { where("score >= ?", 0.9) }
  scope :low_score, -> { where("score < ?", 0.5) }

  # Class methods
  def self.average_score
    average(:score) || 0.0
  end

  def self.compliance_rate
    return 0.0 if count == 0
    (compliant.count.to_f / count * 100).round(2)
  end

  def self.common_violations(limit = 10)
    all_violations = pluck(:violations_data).flatten
    violation_counts = Hash.new(0)
    
    all_violations.each do |violation|
      key = violation["type"] || violation[:type]
      violation_counts[key] += 1 if key
    end
    
    violation_counts.sort_by { |_, count| -count }.first(limit).to_h
  end

  # Instance methods
  def high_severity_violations
    violations_data.select { |v| %w[critical high].include?(v["severity"] || v[:severity]) }
  end

  def violation_summary
    violations_by_type = violations_data.group_by { |v| v["type"] || v[:type] }
    violations_by_type.transform_values(&:count)
  end

  def suggested_actions
    suggestions_data.select { |s| (s["priority"] || s[:priority]) == "high" }
  end

  def processing_time_seconds
    metadata&.dig("processing_time") || 0
  end

  def validators_used
    metadata&.dig("validators_used") || []
  end

  def cache_efficiency
    cache_hits = metadata&.dig("cache_hits") || 0
    total_validators = validators_used.length
    return 0.0 if total_validators == 0
    
    (cache_hits.to_f / total_validators * 100).round(2)
  end
end
