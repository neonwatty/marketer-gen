class PersonaContent < ApplicationRecord
  # Associations
  belongs_to :persona
  belongs_to :generated_content
  
  # Constants
  ADAPTATION_TYPES = %w[
    tone_adaptation
    length_adaptation
    channel_optimization
    demographic_targeting
    goal_alignment
    pain_point_focus
    behavioral_trigger
    personalized_messaging
  ].freeze
  
  # Validations
  validates :adaptation_type, presence: true, inclusion: { in: ADAPTATION_TYPES }
  validates :effectiveness_score, numericality: { in: 0.0..10.0 }, allow_nil: true
  validates :persona_id, uniqueness: { scope: :generated_content_id }
  
  # JSON serialization
  serialize :adaptation_metadata, coder: JSON
  
  # Scopes
  scope :by_adaptation_type, ->(type) { where(adaptation_type: type) }
  scope :primary_adaptations, -> { where(is_primary_adaptation: true) }
  scope :secondary_adaptations, -> { where(is_primary_adaptation: false) }
  scope :effective, -> { where('effectiveness_score >= ?', 7.0) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_effectiveness, -> { order(effectiveness_score: :desc) }
  
  # Callbacks
  before_validation :set_default_metadata, on: :create
  after_create :update_persona_performance_metrics
  after_update :update_persona_performance_metrics, if: :saved_change_to_effectiveness_score?
  
  # Instance methods
  def effective?
    effectiveness_score && effectiveness_score >= 7.0
  end
  
  def primary_adaptation?
    is_primary_adaptation
  end
  
  def secondary_adaptation?
    !is_primary_adaptation
  end
  
  def set_as_primary!
    transaction do
      # Remove primary status from other adaptations for this content
      PersonaContent.where(generated_content: generated_content)
                   .where.not(id: id)
                   .update_all(is_primary_adaptation: false)
      
      # Set this as primary
      update!(is_primary_adaptation: true)
    end
  end
  
  def parsed_metadata
    adaptation_metadata.is_a?(Hash) ? adaptation_metadata : {}
  end
  
  def update_metadata(new_metadata)
    current_metadata = parsed_metadata
    merged_metadata = current_metadata.merge(new_metadata)
    update!(adaptation_metadata: merged_metadata)
  end
  
  def performance_summary
    {
      adaptation_type: adaptation_type,
      effectiveness_score: effectiveness_score,
      is_primary: is_primary_adaptation,
      persona_name: persona.name,
      content_type: generated_content.content_type,
      created_at: created_at,
      last_updated: updated_at,
      metadata: parsed_metadata
    }
  end
  
  # Content comparison methods
  def content_length_change
    return nil unless adapted_content.present? && generated_content.body_content.present?
    
    original_length = generated_content.body_content.length
    adapted_length = adapted_content.length
    
    {
      original: original_length,
      adapted: adapted_length,
      change: adapted_length - original_length,
      percentage_change: ((adapted_length - original_length).to_f / original_length * 100).round(2)
    }
  end
  
  def word_count_change
    return nil unless adapted_content.present? && generated_content.body_content.present?
    
    original_words = generated_content.body_content.split.length
    adapted_words = adapted_content.split.length
    
    {
      original: original_words,
      adapted: adapted_words,
      change: adapted_words - original_words,
      percentage_change: ((adapted_words - original_words).to_f / original_words * 100).round(2)
    }
  end
  
  def adaptation_impact_analysis
    {
      length_impact: content_length_change,
      word_count_impact: word_count_change,
      effectiveness_score: effectiveness_score,
      adaptation_rationale: adaptation_rationale,
      metadata_insights: extract_metadata_insights
    }
  end
  
  # Class methods
  def self.effectiveness_analytics
    {
      total_adaptations: count,
      average_effectiveness: average(:effectiveness_score) || 0.0,
      effectiveness_by_type: group(:adaptation_type).average(:effectiveness_score),
      most_effective_type: group(:adaptation_type).average(:effectiveness_score).max_by(&:last)&.first,
      primary_adaptation_rate: primary_adaptations.count.to_f / count * 100,
      recent_trends: recent.limit(10).pluck(:adaptation_type, :effectiveness_score)
    }
  end
  
  def self.create_adaptation(persona, content, adaptation_type, options = {})
    adapted_text = persona.generate_personalized_content(content.body_content, adaptation_type)
    
    create!(
      persona: persona,
      generated_content: content,
      adaptation_type: adaptation_type,
      adapted_content: adapted_text,
      adaptation_rationale: options[:rationale] || "Adapted content using #{adaptation_type} for #{persona.name}",
      adaptation_metadata: build_adaptation_metadata(persona, content, adaptation_type, options),
      is_primary_adaptation: options[:primary] || false
    )
  end
  
  def self.build_adaptation_metadata(persona, content, adaptation_type, options)
    {
      original_content_type: content.content_type,
      original_length: content.body_content.length,
      persona_characteristics: {
        name: persona.name,
        priority: persona.priority,
        demographics: persona.parse_demographic_data,
        goals: persona.parse_goals_data,
        pain_points: persona.parse_pain_points_data
      },
      adaptation_context: {
        adaptation_timestamp: Time.current,
        adaptation_method: adaptation_type,
        custom_parameters: options.except(:rationale, :primary)
      },
      performance_tracking: {
        baseline_effectiveness: nil,
        engagement_prediction: calculate_engagement_prediction(persona, content),
        conversion_likelihood: calculate_conversion_likelihood(persona, content)
      }
    }
  end
  
  def self.calculate_engagement_prediction(persona, content)
    # Mock implementation - in real app, this would use ML models
    base_score = 50
    
    # Adjust based on persona-content alignment
    if persona.content_preferences.present?
      prefs = persona.parse_content_preferences
      if prefs['preferred_content_types']&.include?(content.content_type)
        base_score += 20
      end
    end
    
    # Adjust based on channel preferences
    if persona.preferred_channels.present?
      channels = persona.parse_preferred_channels
      if content.platform_settings.keys.any? { |k| channels.include?(k) }
        base_score += 15
      end
    end
    
    [base_score, 100].min
  end
  
  def self.calculate_conversion_likelihood(persona, content)
    # Mock implementation - in real app, this would use historical data and ML
    base_likelihood = 25
    
    # Adjust based on goal alignment
    goals = persona.parse_goals_data
    if goals.any? && content.metadata&.dig('target_goals')
      common_goals = goals & content.metadata['target_goals']
      base_likelihood += common_goals.size * 10
    end
    
    [base_likelihood, 100].min
  end
  
  private
  
  def set_default_metadata
    self.adaptation_metadata ||= {
      created_at: Time.current,
      adaptation_version: '1.0'
    }
  end
  
  def update_persona_performance_metrics
    return unless persona.present?
    
    # This would typically trigger a background job to update persona performance
    PersonaPerformanceUpdateJob.perform_later(persona.id) if defined?(PersonaPerformanceUpdateJob)
  end
  
  def extract_metadata_insights
    metadata = parsed_metadata
    insights = {}
    
    if metadata['performance_tracking']
      perf = metadata['performance_tracking']
      insights[:engagement_prediction] = perf['engagement_prediction']
      insights[:conversion_likelihood] = perf['conversion_likelihood']
    end
    
    if metadata['persona_characteristics']
      insights[:persona_alignment_score] = calculate_persona_alignment_score
    end
    
    insights
  end
  
  def calculate_persona_alignment_score
    # Calculate how well the adaptation aligns with persona characteristics
    # Mock implementation
    return 0 unless effectiveness_score
    
    # Base the alignment on effectiveness score
    (effectiveness_score / 10.0 * 100).round(0)
  end
end
