class Persona < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :persona_contents, dependent: :destroy
  has_many :generated_contents, through: :persona_contents
  
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
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :user_id }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :priority, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :characteristics, presence: true
  validates :demographics, presence: true
  validates :goals, presence: true
  validates :pain_points, presence: true
  validates :preferred_channels, presence: true
  validates :content_preferences, presence: true
  validates :behavioral_traits, presence: true
  
  # JSON serialization
  serialize :tags, coder: JSON
  serialize :matching_rules, coder: JSON
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_priority, -> { order(:priority) }
  scope :for_user, ->(user) { where(user: user) }
  
  # Callbacks
  before_validation :set_default_values, on: :create
  
  # Instance methods
  def active?
    is_active
  end
  
  def inactive?
    !is_active
  end
  
  def activate!
    update!(is_active: true)
  end
  
  def deactivate!
    update!(is_active: false)
  end
  
  def parsed_tags
    tags.is_a?(Array) ? tags : (tags.present? ? [tags].flatten : [])
  end
  
  def parsed_matching_rules
    matching_rules.is_a?(Hash) ? matching_rules : {}
  end
  
  def add_tag(tag)
    current_tags = parsed_tags
    current_tags << tag.to_s unless current_tags.include?(tag.to_s)
    self.tags = current_tags
    save
  end
  
  def remove_tag(tag)
    current_tags = parsed_tags
    current_tags.delete(tag.to_s)
    self.tags = current_tags
    save
  end
  
  def has_tag?(tag)
    parsed_tags.include?(tag.to_s)
  end
  
  # Content matching and adaptation methods
  def matches_user_profile?(user_profile)
    return false if user_profile.nil? || !user_profile.is_a?(Hash)
    
    rules = parsed_matching_rules
    score = 0
    max_score = 0
    
    # Check demographic match
    if demographics.present? && user_profile['demographics']
      persona_demographics = parse_demographic_data
      demo_score = calculate_demographic_match(persona_demographics, user_profile['demographics'])
      weight = rules['demographics_weight'] || 1
      score += demo_score * weight
      max_score += weight
    end
    
    # Check behavioral match
    if behavioral_traits.present? && user_profile['behavioral_traits']
      persona_traits = parse_behavioral_traits
      behavior_score = calculate_behavioral_match(persona_traits, user_profile['behavioral_traits'])
      weight = rules['behavioral_weight'] || 1
      score += behavior_score * weight
      max_score += weight
    end
    
    # Check goals alignment
    if goals.present? && user_profile['goals']
      persona_goals = parse_goals_data
      goal_score = calculate_goals_match(persona_goals, user_profile['goals'])
      weight = rules['goals_weight'] || 1
      score += goal_score * weight
      max_score += weight
    end
    
    return false if max_score.zero?
    
    match_percentage = (score.to_f / max_score) * 100
    threshold = rules['match_threshold'] || 60
    
    match_percentage >= threshold
  end
  
  def calculate_match_score(user_profile)
    return 0 if user_profile.nil? || !user_profile.is_a?(Hash)
    
    total_score = 0
    max_possible = 0
    
    # Demographic matching (weight: 30%)
    if demographics.present? && user_profile['demographics']
      persona_demographics = parse_demographic_data
      demo_score = calculate_demographic_match(persona_demographics, user_profile['demographics'])
      total_score += demo_score * 30
      max_possible += 30
    end
    
    # Behavioral matching (weight: 40%)  
    if behavioral_traits.present? && user_profile['behavioral_traits']
      persona_traits = parse_behavioral_traits
      behavior_score = calculate_behavioral_match(persona_traits, user_profile['behavioral_traits'])
      total_score += behavior_score * 40
      max_possible += 40
    end
    
    # Goals alignment (weight: 30%)
    if goals.present? && user_profile['goals']
      persona_goals = parse_goals_data
      goal_score = calculate_goals_match(persona_goals, user_profile['goals'])
      total_score += goal_score * 30
      max_possible += 30
    end
    
    max_possible.zero? ? 0 : (total_score / max_possible).round(2)
  end
  
  def adapt_content_for_persona(content)
    adaptations = {}
    
    # Tone adaptation based on persona characteristics
    if content_preferences.present?
      prefs = parse_content_preferences
      adaptations[:tone] = adapt_tone(content, prefs['tone']) if prefs['tone']
      adaptations[:style] = adapt_style(content, prefs['style']) if prefs['style']
      adaptations[:format] = adapt_format(content, prefs['format']) if prefs['format']
    end
    
    # Length adaptation based on behavioral traits
    if behavioral_traits.present?
      traits = parse_behavioral_traits
      adaptations[:length] = adapt_length(content, traits['attention_span']) if traits['attention_span']
    end
    
    # Channel optimization
    if preferred_channels.present?
      channels = parse_preferred_channels
      adaptations[:channel_optimization] = optimize_for_channels(content, channels)
    end
    
    adaptations
  end
  
  def generate_personalized_content(base_content, adaptation_type)
    case adaptation_type
    when 'tone_adaptation'
      adapt_tone_comprehensive(base_content)
    when 'length_adaptation'
      adapt_length_comprehensive(base_content)
    when 'channel_optimization'
      optimize_for_preferred_channels(base_content)
    when 'demographic_targeting'
      target_demographics(base_content)
    when 'goal_alignment'
      align_with_goals(base_content)
    when 'pain_point_focus'
      focus_on_pain_points(base_content)
    when 'behavioral_trigger'
      apply_behavioral_triggers(base_content)
    when 'personalized_messaging'
      create_personalized_messaging(base_content)
    else
      base_content
    end
  end
  
  # Content effectiveness tracking
  def average_effectiveness_score
    persona_contents.average(:effectiveness_score) || 0.0
  end
  
  def content_performance_summary
    {
      total_adaptations: persona_contents.count,
      average_effectiveness: average_effectiveness_score,
      best_adaptation_type: persona_contents.group(:adaptation_type).average(:effectiveness_score).max_by(&:last)&.first,
      recent_adaptations: persona_contents.order(created_at: :desc).limit(5).pluck(:adaptation_type, :effectiveness_score),
      content_types_adapted: generated_contents.distinct.pluck(:content_type)
    }
  end
  
  def parse_demographic_data
    return {} unless demographics.present?
    
    begin
      JSON.parse(demographics)
    rescue JSON::ParserError
      {}
    end
  end
  
  def parse_goals_data
    return [] unless goals.present?
    
    begin
      goals_data = JSON.parse(goals)
      goals_data.is_a?(Array) ? goals_data : [goals_data].flatten
    rescue JSON::ParserError
      []
    end
  end
  
  def parse_pain_points_data
    return [] unless pain_points.present?
    
    begin
      pain_data = JSON.parse(pain_points)
      pain_data.is_a?(Array) ? pain_data : [pain_data].flatten
    rescue JSON::ParserError
      []
    end
  end

  def parse_content_preferences
    return {} unless content_preferences.present?
    
    begin
      JSON.parse(content_preferences)
    rescue JSON::ParserError
      {}
    end
  end
  
  def parse_behavioral_traits
    return {} unless behavioral_traits.present?
    
    begin
      JSON.parse(behavioral_traits)
    rescue JSON::ParserError
      {}
    end
  end
  
  def parse_preferred_channels
    return [] unless preferred_channels.present?
    
    begin
      channels = JSON.parse(preferred_channels)
      channels.is_a?(Array) ? channels : [channels].flatten
    rescue JSON::ParserError
      []
    end
  end

  private
  
  def set_default_values
    self.is_active = true if is_active.nil?
    self.priority = 0 if priority.nil?
    self.tags ||= []
    self.matching_rules ||= {
      'match_threshold' => 60,
      'demographics_weight' => 1,
      'behavioral_weight' => 1,
      'goals_weight' => 1
    }
  end

  public
  
  def parse_content_preferences
    return {} unless content_preferences.present?
    
    begin
      JSON.parse(content_preferences)
    rescue JSON::ParserError
      {}
    end
  end
  
  def parse_behavioral_traits
    return {} unless behavioral_traits.present?
    
    begin
      JSON.parse(behavioral_traits)
    rescue JSON::ParserError
      {}
    end
  end
  
  def parse_preferred_channels
    return [] unless preferred_channels.present?
    
    begin
      channels = JSON.parse(preferred_channels)
      channels.is_a?(Array) ? channels : [channels].flatten
    rescue JSON::ParserError
      []
    end
  end
  
  private

  # Matching calculation methods
  def calculate_demographic_match(persona_demographics, user_demographics)
    return 0 unless persona_demographics.is_a?(Hash) && user_demographics.is_a?(Hash)
    
    matches = 0
    total_criteria = persona_demographics.keys.size
    
    persona_demographics.each do |key, expected_value|
      if user_demographics[key] == expected_value
        matches += 1
      elsif user_demographics[key].is_a?(Array) && user_demographics[key].include?(expected_value)
        matches += 0.8  # Partial match for array inclusion
      end
    end
    
    total_criteria.zero? ? 0 : (matches.to_f / total_criteria)
  end
  
  def calculate_behavioral_match(persona_traits, user_traits)
    return 0 unless persona_traits.is_a?(Hash) && user_traits.is_a?(Hash)
    
    matches = 0
    total_traits = persona_traits.keys.size
    
    persona_traits.each do |trait, expected_level|
      user_level = user_traits[trait]
      next unless user_level
      
      # Calculate similarity score based on level matching
      if expected_level == user_level
        matches += 1
      elsif expected_level.is_a?(Numeric) && user_level.is_a?(Numeric)
        # For numeric traits, calculate proximity
        max_difference = 5 # Assuming scale of 1-10
        difference = (expected_level - user_level).abs
        similarity = [1 - (difference.to_f / max_difference), 0].max
        matches += similarity
      end
    end
    
    total_traits.zero? ? 0 : (matches.to_f / total_traits)
  end
  
  def calculate_goals_match(persona_goals, user_goals)
    return 0 unless persona_goals.is_a?(Array) && user_goals.is_a?(Array)
    
    overlap = (persona_goals & user_goals).size
    union = (persona_goals | user_goals).size
    
    union.zero? ? 0 : (overlap.to_f / persona_goals.size)
  end
  
  # Content adaptation methods
  def adapt_tone(content, desired_tone)
    # Mock implementation - in real app, this would use AI/NLP
    tone_mapping = {
      'professional' => 'formal language and industry terminology',
      'casual' => 'conversational and friendly language',
      'enthusiastic' => 'energetic and exciting language',
      'empathetic' => 'understanding and supportive language'
    }
    
    tone_instruction = tone_mapping[desired_tone] || desired_tone
    "Content adapted for #{tone_instruction}: #{content}"
  end
  
  def adapt_style(content, desired_style)
    # Mock implementation
    "Content adapted for #{desired_style} style: #{content}"
  end
  
  def adapt_format(content, desired_format)
    # Mock implementation  
    case desired_format
    when 'bullet_points'
      content.split('.').map { |s| "• #{s.strip}" }.join("\n")
    when 'numbered_list'
      content.split('.').map.with_index { |s, i| "#{i+1}. #{s.strip}" }.join("\n")
    else
      content
    end
  end
  
  def adapt_length(content, attention_span)
    case attention_span
    when 'short'
      content.truncate(100)
    when 'medium'
      content.truncate(300)
    when 'long'
      content # Keep full length
    else
      content
    end
  end
  
  def optimize_for_channels(content, channels)
    optimizations = {}
    
    channels.each do |channel|
      case channel
      when 'email'
        optimizations[channel] = "Email-optimized: #{content.truncate(200)}"
      when 'social_media'
        optimizations[channel] = "Social-optimized: #{content.truncate(280)} #hashtag"
      when 'linkedin'
        optimizations[channel] = "LinkedIn-optimized: Professional tone - #{content}"
      when 'twitter'
        optimizations[channel] = content.truncate(270) + " #tweet"
      else
        optimizations[channel] = content
      end
    end
    
    optimizations
  end
  
  # Advanced adaptation methods
  def adapt_tone_comprehensive(content)
    prefs = parse_content_preferences
    tone = prefs['tone'] || 'professional'
    
    case tone
    when 'professional'
      "We are pleased to present #{content}"
    when 'casual'
      "Hey there! Check this out: #{content}"
    when 'enthusiastic'
      "This is amazing! #{content} Don't miss out!"
    when 'empathetic'
      "We understand your challenges. Here's how we can help: #{content}"
    else
      content
    end
  end
  
  def adapt_length_comprehensive(content)
    traits = parse_behavioral_traits
    attention_span = traits['attention_span'] || 'medium'
    
    case attention_span
    when 'short'
      content.split('.').first + '.'
    when 'long'
      "#{content}\n\nFor more detailed information and comprehensive insights, please consider the following additional context and background..."
    else
      content
    end
  end
  
  def optimize_for_preferred_channels(content)
    channels = parse_preferred_channels
    return content if channels.empty?
    
    primary_channel = channels.first
    case primary_channel
    when 'email'
      "Subject: Important Update\n\nDear Valued Customer,\n\n#{content}\n\nBest regards,\nThe Team"
    when 'social_media'
      "📢 #{content.truncate(240)} #trending #update"
    when 'linkedin'
      "Professional insight: #{content} #networking #business"
    else
      content
    end
  end
  
  def target_demographics(content)
    demo_data = parse_demographic_data
    age_group = demo_data['age_group']
    
    case age_group
    when '18-25'
      "✨ #{content} Perfect for your lifestyle! 🔥"
    when '26-40'
      "Smart choice for busy professionals: #{content}"
    when '41-65'
      "Trusted solution with proven results: #{content}"
    else
      content
    end
  end
  
  def align_with_goals(content)
    goal_data = parse_goals_data
    return content unless goal_data.any?
    
    primary_goal = goal_data.first
    case primary_goal
    when 'save_money'
      "Cost-effective solution: #{content} - Save up to 30%!"
    when 'save_time'
      "Quick and efficient: #{content} - Done in minutes!"
    when 'increase_productivity'
      "Boost your productivity: #{content} - Get more done!"
    else
      "Achieve your goals: #{content}"
    end
  end
  
  def focus_on_pain_points(content)
    pain_data = parse_pain_points_data
    return content unless pain_data.any?
    
    primary_pain = pain_data.first
    case primary_pain
    when 'lack_of_time'
      "No more time wasted! #{content}"
    when 'complex_processes'
      "Simplify your workflow: #{content}"
    when 'high_costs'
      "Affordable solution: #{content}"
    else
      "Solve your biggest challenge: #{content}"
    end
  end
  
  def apply_behavioral_triggers(content)
    traits = parse_behavioral_traits
    return content unless traits.any?
    
    if traits['urgency_sensitive']
      "Limited time offer: #{content} - Act now!"
    elsif traits['social_proof_motivated']
      "Join thousands of satisfied customers: #{content}"
    elsif traits['detail_oriented']
      "Comprehensive solution with full documentation: #{content}"
    else
      content
    end
  end
  
  def create_personalized_messaging(content)
    "Personalized for #{name}: #{content}"
  end
  
end
