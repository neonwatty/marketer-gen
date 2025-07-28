class JourneyInsight < ApplicationRecord
  belongs_to :journey

  INSIGHTS_TYPES = %w[
    ai_suggestions
    performance_metrics
    user_behavior
    completion_rates
    stage_effectiveness
    content_performance
    channel_performance
    optimization_opportunities
    predictive_analytics
    benchmark_comparison
    brand_compliance
    brand_voice_analysis
    brand_guideline_adherence
  ].freeze

  validates :insights_type, inclusion: { in: INSIGHTS_TYPES }
  validates :calculated_at, presence: true

  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at IS NOT NULL AND expires_at <= ?', Time.current) }
  scope :by_type, ->(type) { where(insights_type: type) }
  scope :recent, ->(days = 7) { where('calculated_at >= ?', days.days.ago) }

  # Scopes for different insights types
  scope :ai_suggestions, -> { by_type('ai_suggestions') }
  scope :performance_metrics, -> { by_type('performance_metrics') }
  scope :user_behavior, -> { by_type('user_behavior') }
  scope :brand_compliance, -> { by_type('brand_compliance') }
  scope :brand_voice_analysis, -> { by_type('brand_voice_analysis') }
  scope :brand_guideline_adherence, -> { by_type('brand_guideline_adherence') }

  # Class methods for analytics
  def self.latest_for_journey(journey_id, insights_type = nil)
    query = where(journey_id: journey_id).active.order(calculated_at: :desc)
    query = query.by_type(insights_type) if insights_type
    query.first
  end

  def self.insights_summary_for_journey(journey_id)
    where(journey_id: journey_id)
      .active
      .group(:insights_type)
      .maximum(:calculated_at)
      .transform_values { |timestamp| where(journey_id: journey_id, calculated_at: timestamp) }
  end

  def self.cleanup_expired
    expired.delete_all
  end

  def self.refresh_stale_insights(threshold = 24.hours)
    where('calculated_at < ?', threshold.ago).delete_all
  end
  
  # Brand compliance analytics class methods
  def self.brand_compliance_summary(journey_id, days = 30)
    compliance_insights = where(journey_id: journey_id)
                          .brand_compliance
                          .where('calculated_at >= ?', days.days.ago)
                          .order(calculated_at: :desc)
    
    return {} if compliance_insights.empty?
    
    scores = compliance_insights.map { |insight| insight.data['score'] }.compact
    violations_counts = compliance_insights.map { |insight| insight.data['violations_count'] || 0 }
    
    {
      average_score: scores.sum.to_f / scores.length,
      latest_score: scores.first,
      score_trend: calculate_score_trend(scores),
      total_violations: violations_counts.sum,
      average_violations_per_check: violations_counts.sum.to_f / violations_counts.length,
      checks_performed: compliance_insights.count,
      compliant_checks: compliance_insights.count { |insight| insight.data['compliant'] },
      compliance_rate: compliance_insights.count { |insight| insight.data['compliant'] }.to_f / compliance_insights.count * 100
    }
  end
  
  def self.brand_compliance_by_step(journey_id, days = 30)
    compliance_insights = where(journey_id: journey_id)
                          .brand_compliance
                          .where('calculated_at >= ?', days.days.ago)
    
    step_compliance = {}
    
    compliance_insights.each do |insight|
      step_id = insight.data['step_id']
      next unless step_id
      
      step_compliance[step_id] ||= {
        scores: [],
        violations: [],
        checks: 0
      }
      
      step_compliance[step_id][:scores] << insight.data['score']
      step_compliance[step_id][:violations] << (insight.data['violations_count'] || 0)
      step_compliance[step_id][:checks] += 1
    end
    
    # Calculate averages for each step
    step_compliance.transform_values do |data|
      {
        average_score: data[:scores].sum.to_f / data[:scores].length,
        total_violations: data[:violations].sum,
        checks_performed: data[:checks],
        latest_score: data[:scores].first
      }
    end
  end
  
  def self.brand_violations_breakdown(journey_id, days = 30)
    compliance_insights = where(journey_id: journey_id)
                          .brand_compliance
                          .where('calculated_at >= ?', days.days.ago)
    
    violation_categories = Hash.new(0)
    violation_severity = Hash.new(0)
    
    compliance_insights.each do |insight|
      violations = insight.data['violations'] || []
      violations.each do |violation|
        violation_categories[violation['type']] += 1
        violation_severity[violation['severity']] += 1
      end
    end
    
    {
      by_category: violation_categories,
      by_severity: violation_severity,
      total_violations: violation_categories.values.sum
    }
  end
  
  def self.calculate_score_trend(scores)
    return 'stable' if scores.length < 3
    
    recent_scores = scores.first(3)
    older_scores = scores.last(3)
    
    recent_avg = recent_scores.sum.to_f / recent_scores.length
    older_avg = older_scores.sum.to_f / older_scores.length
    
    diff = recent_avg - older_avg
    
    if diff > 0.05
      'improving'
    elsif diff < -0.05
      'declining'
    else
      'stable'
    end
  end

  # Instance methods
  def expired?
    expires_at && expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def age_in_hours
    ((Time.current - calculated_at) / 1.hour).round(2)
  end

  def age_in_days
    ((Time.current - calculated_at) / 1.day).round(2)
  end

  def time_to_expiry
    return nil unless expires_at
    
    seconds_remaining = expires_at - Time.current
    return 0 if seconds_remaining <= 0
    
    {
      days: (seconds_remaining / 1.day).floor,
      hours: ((seconds_remaining % 1.day) / 1.hour).floor,
      minutes: ((seconds_remaining % 1.hour) / 1.minute).floor
    }
  end

  # Insights data accessors
  def suggestions_data
    return {} unless insights_type == 'ai_suggestions'
    
    data['suggestions'] || []
  end

  def performance_data
    return {} unless insights_type == 'performance_metrics'
    
    data['metrics'] || {}
  end

  def user_behavior_data
    return {} unless insights_type == 'user_behavior'
    
    data['behavior_patterns'] || {}
  end

  def optimization_opportunities
    return [] unless insights_type == 'optimization_opportunities'
    
    data['opportunities'] || []
  end
  
  # Brand compliance data accessors
  def brand_compliance_data
    return {} unless insights_type == 'brand_compliance'
    
    {
      score: data['score'],
      compliant: data['compliant'],
      violations: data['violations'] || [],
      suggestions: data['suggestions'] || [],
      violations_count: data['violations_count'] || 0,
      step_id: data['step_id'],
      brand_id: data['brand_id']
    }
  end
  
  def brand_voice_data
    return {} unless insights_type == 'brand_voice_analysis'
    
    data['voice_analysis'] || {}
  end
  
  def brand_guideline_data
    return {} unless insights_type == 'brand_guideline_adherence'
    
    data['guideline_adherence'] || {}
  end

  # Data validation and integrity
  def validate_data_structure
    case insights_type
    when 'ai_suggestions'
      validate_suggestions_data
    when 'performance_metrics'
      validate_performance_data
    when 'user_behavior'
      validate_behavior_data
    when 'brand_compliance'
      validate_brand_compliance_data
    when 'brand_voice_analysis'
      validate_brand_voice_data
    when 'brand_guideline_adherence'
      validate_brand_guideline_data
    end
  end

  # Export and summary methods
  def to_summary
    {
      id: id,
      journey_id: journey_id,
      insights_type: insights_type,
      calculated_at: calculated_at,
      expires_at: expires_at,
      age_hours: age_in_hours,
      active: active?,
      data_keys: data.keys,
      metadata_keys: metadata.keys,
      provider: metadata['provider']
    }
  end

  def to_export
    {
      insights_type: insights_type,
      data: data,
      metadata: metadata,
      calculated_at: calculated_at,
      journey_context: {
        journey_id: journey_id,
        journey_name: journey.name,
        journey_status: journey.status
      }
    }
  end

  private

  def validate_suggestions_data
    suggestions = data['suggestions']
    return if suggestions.blank?

    unless suggestions.is_a?(Array)
      errors.add(:data, 'suggestions must be an array')
      return
    end

    suggestions.each_with_index do |suggestion, index|
      unless suggestion.is_a?(Hash)
        errors.add(:data, "suggestion at index #{index} must be a hash")
        next
      end

      required_keys = %w[name description stage content_type channel]
      missing_keys = required_keys - suggestion.keys

      if missing_keys.any?
        errors.add(:data, "suggestion at index #{index} missing keys: #{missing_keys.join(', ')}")
      end
    end
  end

  def validate_performance_data
    metrics = data['metrics']
    return if metrics.blank?

    unless metrics.is_a?(Hash)
      errors.add(:data, 'performance metrics must be a hash')
    end
  end

  def validate_behavior_data
    behavior = data['behavior_patterns']
    return if behavior.blank?

    unless behavior.is_a?(Hash)
      errors.add(:data, 'behavior patterns must be a hash')
    end
  end
  
  def validate_brand_compliance_data
    return if data.blank?
    
    required_keys = %w[score compliant violations_count]
    missing_keys = required_keys - data.keys
    
    if missing_keys.any?
      errors.add(:data, "brand compliance data missing keys: #{missing_keys.join(', ')}")
    end
    
    # Validate score is numeric and in valid range
    if data['score'].present? && (!data['score'].is_a?(Numeric) || data['score'] < 0 || data['score'] > 1)
      errors.add(:data, 'brand compliance score must be a number between 0 and 1')
    end
    
    # Validate compliant is boolean
    unless [true, false].include?(data['compliant'])
      errors.add(:data, 'brand compliance compliant field must be boolean')
    end
    
    # Validate violations array structure
    if data['violations'].present?
      unless data['violations'].is_a?(Array)
        errors.add(:data, 'violations must be an array')
        return
      end
      
      data['violations'].each_with_index do |violation, index|
        unless violation.is_a?(Hash)
          errors.add(:data, "violation at index #{index} must be a hash")
          next
        end
        
        violation_required_keys = %w[type severity message]
        violation_missing_keys = violation_required_keys - violation.keys
        
        if violation_missing_keys.any?
          errors.add(:data, "violation at index #{index} missing keys: #{violation_missing_keys.join(', ')}")
        end
      end
    end
  end
  
  def validate_brand_voice_data
    voice_data = data['voice_analysis']
    return if voice_data.blank?
    
    unless voice_data.is_a?(Hash)
      errors.add(:data, 'brand voice analysis must be a hash')
    end
  end
  
  def validate_brand_guideline_data
    guideline_data = data['guideline_adherence']
    return if guideline_data.blank?
    
    unless guideline_data.is_a?(Hash)
      errors.add(:data, 'brand guideline adherence must be a hash')
    end
  end

  validate :validate_data_structure

  # Callbacks
  before_save :set_default_expires_at, if: -> { expires_at.blank? && insights_type == 'ai_suggestions' }

  private

  def set_default_expires_at
    self.expires_at = 24.hours.from_now
  end
end