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

  # Data validation and integrity
  def validate_data_structure
    case insights_type
    when 'ai_suggestions'
      validate_suggestions_data
    when 'performance_metrics'
      validate_performance_data
    when 'user_behavior'
      validate_behavior_data
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

  validate :validate_data_structure

  # Callbacks
  before_save :set_default_expires_at, if: -> { expires_at.blank? && insights_type == 'ai_suggestions' }

  private

  def set_default_expires_at
    self.expires_at = 24.hours.from_now
  end
end