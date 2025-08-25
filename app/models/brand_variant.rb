class BrandVariant < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :brand_identity
  belongs_to :persona, optional: true
  
  # Constants
  ADAPTATION_CONTEXTS = %w[
    audience_segment
    channel_specific
    campaign_context
    temporal_context
    geographical_context
    competitive_context
  ].freeze
  
  ADAPTATION_TYPES = %w[
    tone_adaptation
    messaging_adaptation
    visual_adaptation
    channel_optimization
    demographic_targeting
    behavioral_targeting
    contextual_adaptation
  ].freeze
  
  STATUSES = %w[draft active archived testing].freeze
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: [:user_id, :brand_identity_id] }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :adaptation_context, presence: true, inclusion: { in: ADAPTATION_CONTEXTS }
  validates :adaptation_type, presence: true, inclusion: { in: ADAPTATION_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :effectiveness_score, numericality: { 
    greater_than_or_equal_to: 0.0, 
    less_than_or_equal_to: 10.0 
  }, allow_nil: true
  validates :usage_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :priority, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # JSON fields are automatically handled by Rails 8 - no serialize needed
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :draft, -> { where(status: 'draft') }
  scope :archived, -> { where(status: 'archived') }
  scope :testing, -> { where(status: 'testing') }
  scope :by_context, ->(context) { where(adaptation_context: context) }
  scope :by_type, ->(type) { where(adaptation_type: type) }
  scope :by_priority, -> { order(:priority) }
  scope :effective, -> { where('effectiveness_score >= ?', 7.0) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_brand, ->(brand) { where(brand_identity: brand) }
  scope :for_persona, ->(persona) { where(persona: persona) }
  
  # Callbacks
  before_validation :set_default_values, on: :create
  after_update :update_performance_tracking, if: :saved_change_to_effectiveness_score?
  
  # Instance methods
  def draft?
    status == 'draft'
  end
  
  def active?
    status == 'active'
  end
  
  def archived?
    status == 'archived'
  end
  
  def testing?
    status == 'testing'
  end
  
  def activate!
    update!(status: 'active', activated_at: Time.current)
  end
  
  def deactivate!
    update!(status: 'draft', activated_at: nil)
  end
  
  def archive!
    update!(status: 'archived', archived_at: Time.current)
  end
  
  def start_testing!
    update!(status: 'testing', testing_started_at: Time.current)
  end
  
  def increment_usage!
    increment!(:usage_count)
    touch(:last_used_at)
  end
  
  def update_effectiveness!(score)
    update!(effectiveness_score: score, last_measured_at: Time.current)
  end
  
  # Brand adaptation methods
  def apply_brand_adaptation(content, context = {})
    adapted_content = content.dup
    
    # Apply voice adjustments
    if brand_voice_adjustments.present?
      adapted_content = apply_voice_adjustments(adapted_content, context)
    end
    
    # Apply messaging variations
    if messaging_variations.present?
      adapted_content = apply_messaging_variations(adapted_content, context)
    end
    
    # Apply channel-specific optimizations
    if channel_specifications.present? && context[:channel]
      adapted_content = apply_channel_optimizations(adapted_content, context[:channel])
    end
    
    # Apply audience targeting adjustments
    if audience_targeting.present? && context[:audience]
      adapted_content = apply_audience_targeting(adapted_content, context[:audience])
    end
    
    increment_usage!
    adapted_content
  end
  
  def generate_variant(base_content, variant_params = {})
    context = {
      adaptation_context: adaptation_context,
      adaptation_type: adaptation_type,
      brand_identity: brand_identity,
      persona: persona,
      user_preferences: variant_params
    }
    
    apply_brand_adaptation(base_content, context)
  end
  
  def compatibility_score_with(persona_instance)
    return 0.0 unless persona_instance
    
    persona_prefs = persona_instance.parse_content_preferences
    audience_match = calculate_audience_compatibility(persona_prefs)
    context_match = calculate_context_compatibility(persona_instance)
    adaptation_match = calculate_adaptation_compatibility(persona_instance)
    
    # Weighted average of compatibility factors
    (audience_match * 0.4 + context_match * 0.3 + adaptation_match * 0.3).round(2)
  end
  
  def performance_summary
    {
      effectiveness_score: effectiveness_score || 0.0,
      usage_count: usage_count,
      last_used: last_used_at,
      status: status,
      adaptation_type: adaptation_type,
      adaptation_context: adaptation_context,
      a_b_test_winner: a_b_test_results&.dig('is_winner') || false,
      performance_trend: calculate_performance_trend
    }
  end
  
  def parsed_adaptation_rules
    parse_json_field(adaptation_rules)
  end
  
  def parsed_brand_voice_adjustments
    parse_json_field(brand_voice_adjustments)
  end
  
  def parsed_messaging_variations
    parse_json_field(messaging_variations)
  end
  
  def parsed_visual_guidelines
    parse_json_field(visual_guidelines)
  end
  
  def parsed_channel_specifications
    parse_json_field(channel_specifications)
  end
  
  def parsed_audience_targeting
    parse_json_field(audience_targeting)
  end
  
  def parsed_performance_metrics
    parse_json_field(performance_metrics)
  end
  
  def parsed_a_b_test_results
    parse_json_field(a_b_test_results)
  end
  
  # Public methods for test access
  def extract_restricted_terms(restrictions)
    return [] unless restrictions.present?
    restrictions.downcase.split(/[,;]/).map(&:strip).select { |term| term.length > 2 }
  end
  
  def remove_restricted_terms(content, restricted_terms)
    restricted_terms.each do |term|
      content = content.gsub(/\b#{Regexp.escape(term)}\b/i, '[alternative needed]')
    end
    content
  end
  
  def align_with_brand_voice(content)
    # Ensure content aligns with established brand voice
    if brand_identity.brand_voice.present?
      voice_keywords = extract_voice_keywords(brand_identity.brand_voice)
      content = incorporate_voice_keywords(content, voice_keywords)
    end
    
    content
  end
  
  def extract_voice_keywords(brand_voice)
    # Extract key voice characteristics
    brand_voice.downcase.split(/\W+/).select { |word| word.length > 3 }
                      .reject { |word| %w[that this with have been].include?(word) }
                      .uniq
                      .first(5)
  end
  
  def incorporate_voice_keywords(content, keywords)
    # Subtly incorporate brand voice keywords if they're not already present
    content_lower = content.downcase
    missing_keywords = keywords.reject { |keyword| content_lower.include?(keyword) }
    
    # Add one missing keyword if content is long enough
    if missing_keywords.any? && content.length > 100
      keyword = missing_keywords.first
      content += " Our #{keyword} approach ensures the best results."
    end
    
    content
  end
  
  private
  
  def parse_json_field(field)
    case field
    when Hash
      field
    when String
      begin
        JSON.parse(field)
      rescue JSON::ParserError
        {}
      end
    when NilClass
      {}
    else
      {}
    end
  end
  
  def set_default_values
    self.status ||= 'draft'
    self.usage_count ||= 0
    self.priority ||= 0
    self.adaptation_rules ||= {}
    self.brand_voice_adjustments ||= {}
    self.messaging_variations ||= {}
    self.visual_guidelines ||= {}
    self.channel_specifications ||= {}
    self.audience_targeting ||= {}
    self.performance_metrics ||= {}
    self.a_b_test_results ||= {}
  end
  
  
  def update_performance_tracking
    metrics = parsed_performance_metrics
    metrics['effectiveness_history'] ||= []
    metrics['effectiveness_history'] << {
      'score' => effectiveness_score,
      'measured_at' => Time.current.iso8601,
      'context' => 'manual_update'
    }
    
    # Keep only last 50 measurements
    metrics['effectiveness_history'] = metrics['effectiveness_history'].last(50)
    self.performance_metrics = metrics
  end
  
  # Brand adaptation implementation methods
  def apply_voice_adjustments(content, context)
    adjustments = parsed_brand_voice_adjustments
    return content unless adjustments.present?
    
    # Apply tone adjustments
    if adjustments['tone_shift']
      content = adjust_tone(content, adjustments['tone_shift'], context)
    end
    
    # Apply formality adjustments
    if adjustments['formality_level']
      content = adjust_formality(content, adjustments['formality_level'])
    end
    
    # Apply personality traits
    if adjustments['personality_traits']
      content = apply_personality_traits(content, adjustments['personality_traits'])
    end
    
    content
  end
  
  def apply_messaging_variations(content, context)
    variations = parsed_messaging_variations
    return content unless variations.present?
    
    # Apply key message emphasis
    if variations['key_messages']
      content = emphasize_key_messages(content, variations['key_messages'])
    end
    
    # Apply value proposition adjustments
    if variations['value_propositions']
      content = adjust_value_propositions(content, variations['value_propositions'])
    end
    
    # Apply call-to-action variations
    if variations['cta_variations']
      content = apply_cta_variations(content, variations['cta_variations'])
    end
    
    content
  end
  
  def apply_channel_optimizations(content, channel)
    specs = parsed_channel_specifications[channel.to_s]
    return content unless specs.present?
    
    # Apply length constraints
    if specs['max_length']
      content = content.truncate(specs['max_length'].to_i)
    end
    
    # Apply format adjustments
    if specs['format_style']
      content = format_for_channel(content, specs['format_style'])
    end
    
    # Apply channel-specific elements
    if specs['channel_elements']
      content = add_channel_elements(content, specs['channel_elements'])
    end
    
    content
  end
  
  def apply_audience_targeting(content, audience)
    targeting = parsed_audience_targeting
    return content unless targeting.present?
    
    audience_key = audience.to_s
    audience_specs = targeting[audience_key]
    return content unless audience_specs.present?
    
    # Apply demographic adjustments
    if audience_specs['demographic_adaptations']
      content = apply_demographic_adaptations(content, audience_specs['demographic_adaptations'])
    end
    
    # Apply psychographic adjustments
    if audience_specs['psychographic_adaptations']
      content = apply_psychographic_adaptations(content, audience_specs['psychographic_adaptations'])
    end
    
    content
  end
  
  # Compatibility calculation methods
  def calculate_audience_compatibility(persona_prefs)
    return 0.5 unless audience_targeting.present? && persona_prefs.present?
    
    audience_specs = parsed_audience_targeting
    compatibility_scores = []
    
    # Check demographic compatibility
    if audience_specs.dig('demographics') && persona_prefs['demographics']
      demo_compatibility = calculate_demographic_overlap(
        audience_specs['demographics'],
        persona_prefs['demographics']
      )
      compatibility_scores << demo_compatibility
    end
    
    # Check behavioral compatibility
    if audience_specs.dig('behavioral_traits') && persona_prefs['behavioral_preferences']
      behavioral_compatibility = calculate_behavioral_overlap(
        audience_specs['behavioral_traits'],
        persona_prefs['behavioral_preferences']
      )
      compatibility_scores << behavioral_compatibility
    end
    
    compatibility_scores.empty? ? 0.5 : compatibility_scores.sum / compatibility_scores.size
  end
  
  def calculate_context_compatibility(persona_instance)
    persona_channels = persona_instance.parse_preferred_channels
    return 0.5 if persona_channels.empty?
    
    specs = parsed_channel_specifications
    return 0.5 if specs.empty?
    
    # Calculate overlap between supported channels and persona preferences
    supported_channels = specs.keys
    overlap = (persona_channels & supported_channels).size
    total = (persona_channels | supported_channels).size
    
    total.zero? ? 0.0 : overlap.to_f / persona_channels.size
  end
  
  def calculate_adaptation_compatibility(persona_instance)
    persona_adaptations = persona_instance.class::ADAPTATION_TYPES
    return 0.5 unless persona_adaptations.include?(adaptation_type)
    
    # Check if adaptation type is suitable for persona
    case adaptation_type
    when 'demographic_targeting'
      persona_instance.parse_demographic_data.present? ? 1.0 : 0.2
    when 'behavioral_targeting'
      persona_instance.parse_behavioral_traits.present? ? 1.0 : 0.2
    when 'channel_optimization'
      persona_instance.parse_preferred_channels.present? ? 1.0 : 0.3
    else
      0.7 # Default compatibility for other types
    end
  end
  
  def calculate_performance_trend
    metrics = parsed_performance_metrics
    history = metrics['effectiveness_history']
    return 'stable' unless history.present? && history.size >= 3
    
    recent_scores = history.last(5).map { |h| h['score'].to_f }
    trend_slope = calculate_trend_slope(recent_scores)
    
    if trend_slope > 0.2
      'improving'
    elsif trend_slope < -0.2
      'declining'
    else
      'stable'
    end
  end
  
  def calculate_trend_slope(scores)
    return 0 if scores.size < 2
    
    n = scores.size
    sum_x = (0...n).sum
    sum_y = scores.sum
    sum_xy = scores.each_with_index.sum { |score, i| score * i }
    sum_x2 = (0...n).sum { |i| i * i }
    
    denominator = n * sum_x2 - sum_x * sum_x
    return 0 if denominator.zero?
    
    (n * sum_xy - sum_x * sum_y) / denominator.to_f
  end
  
  # Content adaptation helper methods
  def adjust_tone(content, tone_shift, context)
    # Implementation would use LLM service for actual tone adjustment
    # This is a simplified version for demonstration
    case tone_shift
    when 'more_formal'
      content.gsub(/\b(hey|hi)\b/i, 'Greetings').gsub(/!+/, '.')
    when 'more_casual'
      content.gsub(/\bGreetings\b/, 'Hey').gsub(/\.$/, '!')
    when 'more_enthusiastic'
      content.gsub(/\.$/, '!').gsub(/\bgood\b/i, 'amazing')
    else
      content
    end
  end
  
  def adjust_formality(content, level)
    case level
    when 'high'
      content.gsub(/\bcan't\b/, 'cannot').gsub(/\bwon't\b/, 'will not')
    when 'low'
      content.gsub(/\bcannot\b/, "can't").gsub(/\bwill not\b/, "won't")
    else
      content
    end
  end
  
  def apply_personality_traits(content, traits)
    traits.each do |trait|
      case trait
      when 'friendly'
        content = "#{content} We're here to help!"
      when 'authoritative'
        content = "Industry experts recommend: #{content}"
      when 'empathetic'
        content = "We understand this can be challenging. #{content}"
      end
    end
    content
  end
  
  def emphasize_key_messages(content, key_messages)
    key_messages.each do |message|
      content = content.gsub(/#{Regexp.escape(message)}/i) { |match| "**#{match}**" }
    end
    content
  end
  
  def adjust_value_propositions(content, value_props)
    # Add value propositions if they're not already present
    existing_content = content.downcase
    value_props.each do |prop|
      unless existing_content.include?(prop.downcase)
        content += " #{prop}"
      end
    end
    content
  end
  
  def apply_cta_variations(content, cta_variations)
    # Replace generic CTAs with variant-specific ones
    cta_variations.each do |original, variant|
      content = content.gsub(/#{Regexp.escape(original)}/i, variant)
    end
    content
  end
  
  def format_for_channel(content, format_style)
    case format_style
    when 'bullet_points'
      sentences = content.split(/[.!?]+/).reject(&:blank?)
      sentences.map { |s| "• #{s.strip}" }.join("\n")
    when 'numbered_list'
      sentences = content.split(/[.!?]+/).reject(&:blank?)
      sentences.map.with_index(1) { |s, i| "#{i}. #{s.strip}" }.join("\n")
    when 'short_paragraphs'
      content.gsub(/(.{100,200}[.!?])/, "\\1\n\n")
    else
      content
    end
  end
  
  def add_channel_elements(content, elements)
    elements.each do |element_type, element_value|
      case element_type
      when 'hashtags'
        content += " #{element_value}"
      when 'mentions'
        content += " #{element_value}"
      when 'emoji'
        content += " #{element_value}"
      end
    end
    content
  end
  
  def apply_demographic_adaptations(content, adaptations)
    adaptations.each do |demo_key, adaptation|
      case demo_key
      when 'age_group'
        content = adapt_for_age_group(content, adaptation)
      when 'income_level'
        content = adapt_for_income_level(content, adaptation)
      end
    end
    content
  end
  
  def apply_psychographic_adaptations(content, adaptations)
    adaptations.each do |psycho_key, adaptation|
      case psycho_key
      when 'values'
        content = emphasize_values(content, adaptation)
      when 'lifestyle'
        content = adapt_for_lifestyle(content, adaptation)
      end
    end
    content
  end
  
  def adapt_for_age_group(content, age_adaptation)
    # Simple age-based adaptations
    case age_adaptation
    when 'younger'
      content.gsub(/\btraditional\b/i, 'modern').gsub(/\bestablished\b/i, 'trending')
    when 'older'
      content.gsub(/\btrending\b/i, 'established').gsub(/\bmodern\b/i, 'proven')
    else
      content
    end
  end
  
  def adapt_for_income_level(content, income_adaptation)
    case income_adaptation
    when 'budget_conscious'
      content += ' Affordable pricing available.'
    when 'premium'
      content += ' Premium quality guaranteed.'
    else
      content
    end
  end
  
  def emphasize_values(content, values)
    values.each do |value|
      case value
      when 'sustainability'
        content += ' Environmentally friendly.'
      when 'innovation'
        content += ' Cutting-edge technology.'
      end
    end
    content
  end
  
  def adapt_for_lifestyle(content, lifestyle)
    case lifestyle
    when 'busy_professional'
      content += ' Save time with our efficient solution.'
    when 'family_focused'
      content += ' Perfect for families.'
    else
      content
    end
  end
  
  # Overlap calculation methods
  def calculate_demographic_overlap(brand_demographics, persona_demographics)
    return 0.0 unless brand_demographics.is_a?(Hash) && persona_demographics.is_a?(Hash)
    
    common_keys = brand_demographics.keys & persona_demographics.keys
    return 0.0 if common_keys.empty?
    
    matches = common_keys.count do |key|
      brand_demographics[key] == persona_demographics[key]
    end
    
    matches.to_f / common_keys.size
  end
  
  def calculate_behavioral_overlap(brand_traits, persona_traits)
    return 0.0 unless brand_traits.is_a?(Hash) && persona_traits.is_a?(Hash)
    
    common_keys = brand_traits.keys & persona_traits.keys
    return 0.0 if common_keys.empty?
    
    total_similarity = common_keys.sum do |key|
      brand_value = brand_traits[key]
      persona_value = persona_traits[key]
      
      if brand_value.is_a?(Numeric) && persona_value.is_a?(Numeric)
        # Calculate similarity for numeric values (0-1 scale)
        max_diff = 10 # Assuming 1-10 scale
        diff = (brand_value - persona_value).abs
        [1.0 - (diff / max_diff.to_f), 0.0].max
      elsif brand_value == persona_value
        1.0
      else
        0.0
      end
    end
    
    total_similarity / common_keys.size
  end
end