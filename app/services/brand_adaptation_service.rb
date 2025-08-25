# frozen_string_literal: true

# Ensure ApplicationService is loaded
require_relative 'application_service' unless ApplicationService.method_defined?(:log_service_call)

class BrandAdaptationService < ApplicationService
  attr_reader :user, :brand_identity, :content, :adaptation_params
  
  # Service initialization
  def initialize(user:, brand_identity:, content:, adaptation_params: {})
    @user = user
    @brand_identity = brand_identity
    @content = content
    @adaptation_params = adaptation_params.with_indifferent_access
    
    log_service_call('BrandAdaptationService', {
      user_id: user&.id,
      brand_identity_id: brand_identity&.id,
      content_length: content&.length,
      adaptation_params: adaptation_params.keys
    })
  end

  # Main service method
  def call
    validate_inputs!
    
    # Extract adaptation requirements
    context = extract_adaptation_context
    target_persona = find_target_persona
    adaptation_type = determine_adaptation_type(context, target_persona)
    
    # Find or create appropriate brand variant
    brand_variant = find_or_create_brand_variant(
      adaptation_type: adaptation_type,
      context: context,
      persona: target_persona
    )
    
    # Apply brand adaptation
    adapted_content = apply_brand_adaptation(brand_variant, context)
    
    # Track usage and performance
    track_adaptation_usage(brand_variant, context)
    
    success_response({
      adapted_content: adapted_content,
      brand_variant: brand_variant,
      adaptation_type: adaptation_type,
      context: context,
      original_content: content,
      performance_metrics: calculate_adaptation_metrics(brand_variant)
    })
    
  rescue StandardError => e
    handle_service_error(e, {
      user_id: user&.id,
      brand_identity_id: brand_identity&.id,
      adaptation_params: adaptation_params
    })
  end
  
  # Class methods for common operations
  def self.adapt_content_for_persona(user:, brand_identity:, content:, persona:)
    call(
      user: user,
      brand_identity: brand_identity,
      content: content,
      adaptation_params: { persona_id: persona.id, adaptation_type: 'demographic_targeting' }
    )
  end
  
  def self.adapt_content_for_channel(user:, brand_identity:, content:, channel:)
    call(
      user: user,
      brand_identity: brand_identity,
      content: content,
      adaptation_params: { channel: channel, adaptation_type: 'channel_optimization' }
    )
  end
  
  def self.adapt_content_for_audience(user:, brand_identity:, content:, audience_segment:)
    call(
      user: user,
      brand_identity: brand_identity,
      content: content,
      adaptation_params: { 
        audience_segment: audience_segment, 
        adaptation_type: 'demographic_targeting' 
      }
    )
  end
  
  def self.create_brand_variant(user:, brand_identity:, variant_params:)
    new(
      user: user,
      brand_identity: brand_identity,
      content: '',
      adaptation_params: variant_params
    ).create_brand_variant_only
  end
  
  def self.analyze_brand_consistency(user:, brand_identity:, content_samples:)
    new(
      user: user,
      brand_identity: brand_identity,
      content: content_samples.join("\n\n"),
      adaptation_params: { analysis_type: 'consistency_check' }
    ).analyze_consistency
  end
  
  # Additional public methods for brand variant management
  def create_brand_variant_only
    validate_inputs_for_variant_creation!
    
    context = extract_adaptation_context
    persona = find_target_persona
    adaptation_type = determine_adaptation_type(context, persona)
    
    brand_variant = create_new_brand_variant(adaptation_type, context, persona)
    
    success_response({
      brand_variant: brand_variant,
      context: context,
      adaptation_type: adaptation_type
    })
  rescue StandardError => e
    handle_service_error(e, { operation: 'create_brand_variant_only' })
  end
  
  def analyze_consistency
    validate_inputs!
    
    content_samples = content.split("\n\n").reject(&:blank?)
    
    # Analyze consistency across samples
    consistency_scores = analyze_content_consistency(content_samples)
    brand_alignment = analyze_brand_alignment(content_samples)
    recommendations = generate_consistency_recommendations(consistency_scores, brand_alignment)
    
    success_response({
      consistency_analysis: {
        overall_score: consistency_scores[:overall],
        tone_consistency: consistency_scores[:tone],
        voice_consistency: consistency_scores[:voice],
        messaging_consistency: consistency_scores[:messaging],
        brand_alignment: brand_alignment,
        recommendations: recommendations,
        analyzed_samples: content_samples.count
      }
    })
  rescue StandardError => e
    handle_service_error(e, { operation: 'analyze_consistency' })
  end
  
  private
  
  def validate_inputs!
    raise ArgumentError, "User is required" unless user
    raise ArgumentError, "Brand identity is required" unless brand_identity
    raise ArgumentError, "Content is required" unless content.present?
    raise ArgumentError, "User does not own this brand identity" unless brand_identity.user_id == user.id
    raise ArgumentError, "Brand identity must be active" unless brand_identity.active?
  end
  
  def validate_inputs_for_variant_creation!
    raise ArgumentError, "User is required" unless user
    raise ArgumentError, "Brand identity is required" unless brand_identity
    raise ArgumentError, "User does not own this brand identity" unless brand_identity.user_id == user.id
    raise ArgumentError, "Brand identity must be active" unless brand_identity.active?
  end
  
  def extract_adaptation_context
    {
      channel: adaptation_params[:channel],
      audience_segment: adaptation_params[:audience_segment],
      campaign_context: adaptation_params[:campaign_context],
      temporal_context: extract_temporal_context,
      geographical_context: adaptation_params[:geographical_context],
      competitive_context: adaptation_params[:competitive_context],
      persona_id: adaptation_params[:persona_id],
      adaptation_goals: adaptation_params[:adaptation_goals] || []
    }
  end
  
  def extract_temporal_context
    return adaptation_params[:temporal_context] if adaptation_params[:temporal_context].present?
    
    # Auto-detect temporal context based on current time/season
    now = Time.current
    context = []
    
    # Seasonal context
    season = case now.month
             when 12, 1, 2 then 'winter'
             when 3, 4, 5 then 'spring'
             when 6, 7, 8 then 'summer'
             when 9, 10, 11 then 'fall'
             end
    context << "season_#{season}"
    
    # Time of day context
    hour = now.hour
    time_period = case hour
                  when 5..11 then 'morning'
                  when 12..17 then 'afternoon'
                  when 18..21 then 'evening'
                  else 'night'
                  end
    context << "time_#{time_period}"
    
    # Day of week context
    day_type = [0, 6].include?(now.wday) ? 'weekend' : 'weekday'
    context << "day_#{day_type}"
    
    context.join(',')
  end
  
  def find_target_persona
    return nil unless adaptation_params[:persona_id].present?
    
    user.personas.find_by(id: adaptation_params[:persona_id])
  end
  
  def determine_adaptation_type(context, persona)
    # Return explicit type if provided
    return adaptation_params[:adaptation_type] if adaptation_params[:adaptation_type].present?
    
    # Auto-determine based on context and persona
    if persona.present?
      # Check if persona has demographic or behavioral data
      demographic_data = persona.parse_demographic_data rescue {}
      behavioral_traits = persona.parse_behavioral_traits rescue {}
      
      return 'demographic_targeting' if demographic_data.present? && !demographic_data.empty?
      return 'behavioral_targeting' if behavioral_traits.present? && !behavioral_traits.empty?
      return 'demographic_targeting'  # Default to demographic targeting for personas
    end
    
    if context[:channel].present?
      return 'channel_optimization'
    end
    
    if context[:audience_segment].present?
      return 'demographic_targeting'
    end
    
    if context[:campaign_context].present?
      return 'contextual_adaptation'
    end
    
    # Default to tone adaptation
    'tone_adaptation'
  end
  
  def find_or_create_brand_variant(adaptation_type:, context:, persona:)
    # Try to find existing variant that matches the context
    existing_variant = find_matching_brand_variant(adaptation_type, context, persona)
    return existing_variant if existing_variant
    
    # Create new variant if none found
    create_new_brand_variant(adaptation_type, context, persona)
  end
  
  def find_matching_brand_variant(adaptation_type, context, persona)
    variants = brand_identity.brand_variants
                            .active
                            .where(adaptation_type: adaptation_type)
                            .where(persona: persona)
    
    # If only one variant matches, use it regardless of score
    return variants.first if variants.count == 1
    
    # If multiple variants, find the best match based on context
    return nil if variants.empty?
    
    best_variant = nil
    best_score = 0
    
    variants.each do |variant|
      score = calculate_context_match_score(variant, context)
      if score > best_score
        best_score = score
        best_variant = variant
      end
    end
    
    # For multiple variants, require a good match score (> 0.5)
    # For single variant case already handled above
    best_score > 0.5 ? best_variant : variants.first
  end
  
  def calculate_context_match_score(variant, context)
    score = 0.0
    total_weight = 0
    
    # Check channel match
    if context[:channel].present?
      channel_specs = variant.parsed_channel_specifications
      if channel_specs[context[:channel]].present?
        score += 0.3
      end
      total_weight += 0.3
    end
    
    # Check audience segment match
    if context[:audience_segment].present?
      audience_targeting = variant.parsed_audience_targeting
      if audience_targeting[context[:audience_segment]].present?
        score += 0.25
      end
      total_weight += 0.25
    end
    
    # Check temporal context match
    if context[:temporal_context].present?
      adaptation_rules = variant.parsed_adaptation_rules
      temporal_rules = adaptation_rules['temporal_rules'] || {}
      context_match = context[:temporal_context].split(',').any? do |ctx|
        temporal_rules.key?(ctx)
      end
      score += 0.2 if context_match
      total_weight += 0.2
    end
    
    # Check campaign context match
    if context[:campaign_context].present?
      adaptation_rules = variant.parsed_adaptation_rules
      campaign_rules = adaptation_rules['campaign_rules'] || {}
      score += 0.15 if campaign_rules[context[:campaign_context]].present?
      total_weight += 0.15
    end
    
    # Check geographical context match
    if context[:geographical_context].present?
      audience_targeting = variant.parsed_audience_targeting
      geo_targeting = audience_targeting['geographical'] || {}
      score += 0.1 if geo_targeting[context[:geographical_context]].present?
      total_weight += 0.1
    end
    
    total_weight > 0 ? score / total_weight : 0.0
  end
  
  def create_new_brand_variant(adaptation_type, context, persona)
    variant_name = generate_variant_name(adaptation_type, context, persona)
    
    # Generate adaptation rules based on context
    adaptation_rules = generate_adaptation_rules(context)
    brand_voice_adjustments = generate_voice_adjustments(context, persona)
    messaging_variations = generate_messaging_variations(context, persona)
    channel_specifications = generate_channel_specifications(context)
    audience_targeting = generate_audience_targeting(context, persona)
    
    brand_identity.brand_variants.create!(
      user: user,
      persona: persona,
      name: variant_name,
      description: generate_variant_description(adaptation_type, context, persona),
      adaptation_context: determine_adaptation_context(context),
      adaptation_type: adaptation_type,
      status: 'active',
      priority: calculate_variant_priority(adaptation_type, context),
      adaptation_rules: adaptation_rules,
      brand_voice_adjustments: brand_voice_adjustments,
      messaging_variations: messaging_variations,
      channel_specifications: channel_specifications,
      audience_targeting: audience_targeting,
      performance_metrics: initialize_performance_metrics,
      a_b_test_results: {}
    )
  end
  
  def generate_variant_name(adaptation_type, context, persona)
    parts = []
    
    # Add persona name if present
    parts << persona.name if persona.present?
    
    # Add channel if present
    parts << context[:channel].humanize if context[:channel].present?
    
    # Add audience segment if present
    parts << context[:audience_segment].humanize if context[:audience_segment].present?
    
    # Add adaptation type with proper title case
    parts << adaptation_type.humanize.titleize
    
    # Add timestamp to ensure uniqueness
    parts << Time.current.strftime("%m%d_%H%M")
    
    parts.join(" - ")
  end
  
  def generate_variant_description(adaptation_type, context, persona)
    parts = []
    
    parts << "Brand adaptation for #{adaptation_type.humanize.downcase}"
    
    if persona.present?
      parts << "targeting #{persona.name} persona"
    end
    
    if context[:channel].present?
      parts << "optimized for #{context[:channel].humanize.downcase}"
    end
    
    if context[:audience_segment].present?
      parts << "focusing on #{context[:audience_segment].humanize.downcase} audience"
    end
    
    description = parts.join(", ")
    # Capitalize first letter while preserving proper nouns
    if description.present?
      description[0] = description[0].upcase
      description + "."
    else
      description
    end
  end
  
  def determine_adaptation_context(context)
    return 'audience_segment' if context[:audience_segment].present?
    return 'channel_specific' if context[:channel].present?
    return 'campaign_context' if context[:campaign_context].present?
    return 'temporal_context' if context[:temporal_context].present?
    return 'geographical_context' if context[:geographical_context].present?
    return 'competitive_context' if context[:competitive_context].present?
    
    'audience_segment' # default
  end
  
  def calculate_variant_priority(adaptation_type, context)
    priority = 0
    
    # Higher priority for persona-based adaptations
    priority += 10 if context[:persona_id].present?
    
    # Higher priority for specific channels
    priority += 8 if context[:channel].present?
    
    # Higher priority for specific audience segments
    priority += 6 if context[:audience_segment].present?
    
    # Add priority based on adaptation type
    type_priorities = {
      'demographic_targeting' => 12,
      'behavioral_targeting' => 10,
      'channel_optimization' => 8,
      'contextual_adaptation' => 6,
      'tone_adaptation' => 4
    }
    
    priority += type_priorities[adaptation_type] || 2
    
    priority
  end
  
  def generate_adaptation_rules(context)
    rules = {}
    
    # Temporal rules
    if context[:temporal_context].present?
      rules['temporal_rules'] = parse_temporal_context(context[:temporal_context])
    end
    
    # Campaign rules
    if context[:campaign_context].present?
      rules['campaign_rules'] = generate_campaign_rules(context[:campaign_context])
    end
    
    # Competitive rules
    if context[:competitive_context].present?
      rules['competitive_rules'] = generate_competitive_rules(context[:competitive_context])
    end
    
    # Context-based adaptation triggers
    rules['adaptation_triggers'] = context[:adaptation_goals] || []
    
    # Brand consistency rules
    rules['consistency_rules'] = generate_consistency_rules
    
    rules
  end
  
  def parse_temporal_context(temporal_context)
    rules = {}
    contexts = temporal_context.split(',')
    
    contexts.each do |ctx|
      case ctx.strip
      when /^season_(.+)/
        rules['seasonal_adaptations'] = { Regexp.last_match(1) => true }
      when /^time_(.+)/
        rules['time_adaptations'] = { Regexp.last_match(1) => true }
      when /^day_(.+)/
        rules['day_adaptations'] = { Regexp.last_match(1) => true }
      end
    end
    
    rules
  end
  
  def generate_campaign_rules(campaign_context)
    {
      'campaign_type' => campaign_context,
      'messaging_focus' => determine_campaign_messaging_focus(campaign_context),
      'tone_adjustments' => determine_campaign_tone(campaign_context)
    }
  end
  
  def determine_campaign_messaging_focus(campaign_context)
    case campaign_context.downcase
    when 'launch', 'announcement'
      'excitement_and_newness'
    when 'sale', 'promotion'
      'urgency_and_value'
    when 'educational', 'awareness'
      'information_and_benefits'
    when 'retention', 'loyalty'
      'appreciation_and_exclusivity'
    else
      'general_brand_messaging'
    end
  end
  
  def determine_campaign_tone(campaign_context)
    case campaign_context.downcase
    when 'launch', 'announcement'
      'enthusiastic'
    when 'sale', 'promotion'
      'urgent_but_friendly'
    when 'educational', 'awareness'
      'informative_and_helpful'
    when 'retention', 'loyalty'
      'appreciative_and_warm'
    else
      'professional_and_engaging'
    end
  end
  
  def generate_competitive_rules(competitive_context)
    {
      'differentiation_focus' => competitive_context,
      'messaging_emphasis' => 'unique_value_proposition',
      'tone_adjustments' => 'confident_but_respectful'
    }
  end
  
  def generate_consistency_rules
    # Use fallback if processed_guidelines_summary method doesn't exist or returns nil
    brand_guidelines = if brand_identity.respond_to?(:processed_guidelines_summary)
                         brand_identity.processed_guidelines_summary || {}
                       else
                         {}
                       end
    
    {
      'maintain_brand_voice' => true,
      'preserve_core_messaging' => true,
      'respect_tone_guidelines' => brand_guidelines[:tone_extracted] || brand_identity.tone_guidelines.present?,
      'follow_messaging_framework' => brand_guidelines[:messaging_extracted] || brand_identity.messaging_framework.present?,
      'adhere_to_restrictions' => brand_guidelines[:restrictions_extracted] || brand_identity.restrictions.present?
    }
  end
  
  def generate_voice_adjustments(context, persona)
    adjustments = {}
    
    # Base adjustments from brand identity
    if brand_identity.tone_guidelines.present?
      adjustments['base_tone'] = extract_tone_from_guidelines
    end
    
    # Persona-specific adjustments
    if persona.present?
      persona_prefs = persona.parse_content_preferences
      adjustments['tone_shift'] = determine_persona_tone_shift(persona_prefs)
      adjustments['formality_level'] = determine_persona_formality(persona_prefs)
      adjustments['personality_traits'] = extract_persona_personality_traits(persona)
    end
    
    # Context-specific adjustments
    if context[:channel].present?
      adjustments['channel_tone'] = determine_channel_tone(context[:channel])
    end
    
    if context[:campaign_context].present?
      adjustments['campaign_tone'] = determine_campaign_tone(context[:campaign_context])
    end
    
    adjustments
  end
  
  def extract_tone_from_guidelines
    # This would ideally use NLP to extract tone from brand guidelines
    # For now, we'll use a simple keyword-based approach
    guidelines = brand_identity.tone_guidelines.downcase
    
    if guidelines.include?('professional') || guidelines.include?('formal')
      'professional'
    elsif guidelines.include?('casual') || guidelines.include?('friendly')
      'casual'
    elsif guidelines.include?('enthusiastic') || guidelines.include?('energetic')
      'enthusiastic'
    elsif guidelines.include?('empathetic') || guidelines.include?('caring')
      'empathetic'
    else
      'balanced'
    end
  end
  
  def determine_persona_tone_shift(persona_prefs)
    return nil unless persona_prefs.present?
    
    preferred_tone = persona_prefs['tone']
    base_tone = extract_tone_from_guidelines
    
    return nil if preferred_tone == base_tone
    
    # Determine shift direction and intensity
    tone_scale = %w[very_formal formal professional balanced casual very_casual]
    base_index = tone_scale.index(base_tone) || 3
    preferred_index = tone_scale.index(preferred_tone) || 3
    
    if preferred_index > base_index
      'more_casual'
    elsif preferred_index < base_index
      'more_formal'
    else
      nil
    end
  end
  
  def determine_persona_formality(persona_prefs)
    return 'medium' unless persona_prefs.present?
    
    demographics = persona_prefs['demographics'] || {}
    age_group = demographics['age_group']
    occupation = demographics['occupation']
    
    # Adjust formality based on persona characteristics
    if %w[18-25 26-35].include?(age_group)
      'low'
    elsif %w[executive manager professional].any? { |role| occupation.to_s.downcase.include?(role) }
      'high'
    else
      'medium'
    end
  end
  
  def extract_persona_personality_traits(persona)
    traits = []
    
    # Extract from persona characteristics
    characteristics = persona.characteristics.downcase
    
    traits << 'friendly' if characteristics.include?('friendly') || characteristics.include?('social')
    traits << 'authoritative' if characteristics.include?('leader') || characteristics.include?('expert')
    traits << 'empathetic' if characteristics.include?('caring') || characteristics.include?('empathetic')
    traits << 'innovative' if characteristics.include?('innovative') || characteristics.include?('creative')
    
    traits
  end
  
  def determine_channel_tone(channel)
    case channel.downcase
    when 'email'
      'professional_but_personal'
    when 'social_media', 'instagram', 'facebook'
      'casual_and_engaging'
    when 'linkedin'
      'professional_and_authoritative'
    when 'twitter'
      'concise_and_engaging'
    when 'blog', 'website'
      'informative_and_approachable'
    else
      'balanced'
    end
  end
  
  def generate_messaging_variations(context, persona)
    variations = {}
    
    # Key message adjustments
    variations['key_messages'] = extract_key_messages_for_context(context)
    
    # Value proposition adjustments
    variations['value_propositions'] = determine_value_props_for_persona(persona)
    
    # CTA variations
    variations['cta_variations'] = generate_cta_variations_for_channel(context[:channel])
    
    # Persona-specific messaging
    if persona.present?
      variations['persona_messaging'] = generate_persona_specific_messaging(persona)
    end
    
    variations
  end
  
  def extract_key_messages_for_context(context)
    messages = []
    
    # Extract from brand identity messaging framework
    if brand_identity.messaging_framework.present?
      framework = brand_identity.messaging_framework
      # This would ideally use NLP to extract key messages
      # For now, we'll look for common patterns
      messages = framework.split(/[.!?]+/).reject(&:blank?).map(&:strip)
    end
    
    # Filter and prioritize based on context
    if context[:campaign_context] == 'sale'
      messages.select! { |msg| msg.downcase.include?('save') || msg.downcase.include?('discount') }
    elsif context[:campaign_context] == 'launch'
      messages.select! { |msg| msg.downcase.include?('new') || msg.downcase.include?('introducing') }
    end
    
    messages.first(3) # Limit to top 3 key messages
  end
  
  def determine_value_props_for_persona(persona)
    return [] unless persona.present?
    
    value_props = []
    
    # Extract from persona goals
    goals = persona.parse_goals_data
    goals.each do |goal|
      case goal.downcase
      when 'save_money'
        value_props << 'Cost-effective solution'
      when 'save_time'
        value_props << 'Time-saving benefits'
      when 'increase_productivity'
        value_props << 'Productivity enhancement'
      when 'reduce_stress'
        value_props << 'Stress-free experience'
      end
    end
    
    # Extract from persona pain points
    pain_points = persona.parse_pain_points_data
    pain_points.each do |pain|
      case pain.downcase
      when 'lack_of_time'
        value_props << 'Quick and efficient'
      when 'complex_processes'
        value_props << 'Simple and straightforward'
      when 'high_costs'
        value_props << 'Affordable pricing'
      end
    end
    
    value_props.uniq
  end
  
  def generate_cta_variations_for_channel(channel)
    return {} unless channel.present?
    
    variations = {}
    
    case channel.downcase
    when 'email'
      variations = {
        'Learn More' => 'Discover the Details',
        'Get Started' => 'Begin Your Journey',
        'Sign Up' => 'Join Our Community'
      }
    when 'social_media'
      variations = {
        'Learn More' => 'Tap to Learn More! 👆',
        'Get Started' => 'Start Now! 🚀',
        'Sign Up' => 'Join Us! ✨'
      }
    when 'linkedin'
      variations = {
        'Learn More' => 'Explore Professional Benefits',
        'Get Started' => 'Advance Your Career',
        'Sign Up' => 'Join Professional Network'
      }
    end
    
    variations
  end
  
  def generate_persona_specific_messaging(persona)
    messaging = {}
    
    # Generate opening hooks based on persona characteristics
    characteristics = persona.characteristics.downcase
    if characteristics.include?('busy') || characteristics.include?('time-pressed')
      messaging['opening_hooks'] = ['Quick question:', 'In just 2 minutes:', 'No time to waste?']
    elsif characteristics.include?('detail-oriented') || characteristics.include?('analytical')
      messaging['opening_hooks'] = ['Here are the facts:', 'Data shows:', 'Research indicates:']
    elsif characteristics.include?('creative') || characteristics.include?('innovative')
      messaging['opening_hooks'] = ['Imagine this:', 'Picture this:', 'What if you could:']
    end
    
    # Generate closing statements
    goals = persona.parse_goals_data
    if goals.include?('save_money')
      messaging['closing_statements'] = ['Start saving today', 'More value for your money']
    elsif goals.include?('save_time')
      messaging['closing_statements'] = ['Get back your time', 'Efficiency starts here']
    end
    
    messaging
  end
  
  def generate_channel_specifications(context)
    return {} unless context[:channel].present?
    
    channel = context[:channel].downcase
    specifications = {}
    
    case channel
    when 'email'
      specifications[channel] = {
        'max_length' => 500,
        'format_style' => 'paragraph',
        'personalization' => true,
        'subject_line_optimization' => true,
        'channel_elements' => {
          'preheader' => true,
          'signature' => true
        }
      }
    when 'social_media', 'facebook', 'instagram'
      specifications[channel] = {
        'max_length' => 300,
        'format_style' => 'short_paragraphs',
        'visual_elements' => true,
        'channel_elements' => {
          'hashtags' => '#trending #lifestyle',
          'emoji' => '✨ 🚀 💫'
        }
      }
    when 'linkedin'
      specifications[channel] = {
        'max_length' => 400,
        'format_style' => 'professional',
        'thought_leadership' => true,
        'channel_elements' => {
          'hashtags' => '#business #professional #networking',
          'mentions' => '@connections'
        }
      }
    when 'twitter'
      specifications[channel] = {
        'max_length' => 280,
        'format_style' => 'concise',
        'thread_optimization' => true,
        'channel_elements' => {
          'hashtags' => '#relevant #trending',
          'mentions' => '@relevant_accounts'
        }
      }
    when 'blog'
      specifications[channel] = {
        'max_length' => 1500,
        'format_style' => 'structured_content',
        'seo_optimization' => true,
        'channel_elements' => {
          'headings' => true,
          'bullet_points' => true,
          'call_to_action' => true
        }
      }
    end
    
    specifications
  end
  
  def generate_audience_targeting(context, persona)
    targeting = {}
    
    # Demographic targeting
    if context[:audience_segment].present?
      targeting[context[:audience_segment]] = generate_demographic_targeting(context[:audience_segment])
    end
    
    # Persona-based targeting
    if persona.present?
      targeting['persona_targeting'] = {
        'demographic_adaptations' => generate_persona_demographic_adaptations(persona),
        'psychographic_adaptations' => generate_persona_psychographic_adaptations(persona),
        'behavioral_adaptations' => generate_persona_behavioral_adaptations(persona)
      }
    end
    
    # Geographical targeting
    if context[:geographical_context].present?
      targeting['geographical'] = {
        context[:geographical_context] => {
          'localization' => true,
          'cultural_adaptations' => determine_cultural_adaptations(context[:geographical_context])
        }
      }
    end
    
    targeting
  end
  
  def generate_demographic_targeting(audience_segment)
    case audience_segment.downcase
    when 'young_adults'
      {
        'age_group' => '18-35',
        'messaging_style' => 'energetic',
        'channel_preference' => 'social_media',
        'value_focus' => 'innovation_and_trends'
      }
    when 'professionals'
      {
        'age_group' => '25-50',
        'messaging_style' => 'authoritative',
        'channel_preference' => 'linkedin_email',
        'value_focus' => 'productivity_and_results'
      }
    when 'families'
      {
        'age_group' => '30-50',
        'messaging_style' => 'caring',
        'channel_preference' => 'email_facebook',
        'value_focus' => 'safety_and_value'
      }
    else
      {
        'messaging_style' => 'balanced',
        'channel_preference' => 'multi_channel',
        'value_focus' => 'quality_and_reliability'
      }
    end
  end
  
  def generate_persona_demographic_adaptations(persona)
    demographic_data = persona.parse_demographic_data
    adaptations = {}
    
    if demographic_data['age_group'].present?
      age_group = demographic_data['age_group']
      case age_group
      when '18-25'
        adaptations['age_group'] = 'younger'
      when '56-65', '65+'
        adaptations['age_group'] = 'older'
      end
    end
    
    if demographic_data['income_level'].present?
      income = demographic_data['income_level']
      case income
      when 'low', 'below_average'
        adaptations['income_level'] = 'budget_conscious'
      when 'high', 'above_average'
        adaptations['income_level'] = 'premium'
      end
    end
    
    adaptations
  end
  
  def generate_persona_psychographic_adaptations(persona)
    adaptations = {}
    
    # Extract values from persona characteristics
    characteristics = persona.characteristics.downcase
    values = []
    
    values << 'sustainability' if characteristics.include?('environmental') || characteristics.include?('green')
    values << 'innovation' if characteristics.include?('innovative') || characteristics.include?('tech')
    values << 'quality' if characteristics.include?('quality') || characteristics.include?('premium')
    values << 'value' if characteristics.include?('budget') || characteristics.include?('cost')
    
    adaptations['values'] = values if values.any?
    
    # Extract lifestyle indicators
    lifestyle = []
    lifestyle << 'busy_professional' if characteristics.include?('busy') || characteristics.include?('professional')
    lifestyle << 'family_focused' if characteristics.include?('family') || characteristics.include?('parent')
    lifestyle << 'health_conscious' if characteristics.include?('health') || characteristics.include?('fitness')
    
    adaptations['lifestyle'] = lifestyle.first if lifestyle.any?
    
    adaptations
  end
  
  def generate_persona_behavioral_adaptations(persona)
    behavioral_traits = persona.parse_behavioral_traits
    adaptations = {}
    
    # Decision-making style adaptations
    if behavioral_traits['decision_making_style'].present?
      style = behavioral_traits['decision_making_style']
      case style
      when 'analytical', 'careful'
        adaptations['decision_support'] = 'provide_detailed_information'
      when 'quick', 'impulsive'
        adaptations['decision_support'] = 'create_urgency'
      when 'social'
        adaptations['decision_support'] = 'include_social_proof'
      end
    end
    
    # Communication preferences
    if behavioral_traits['communication_style'].present?
      comm_style = behavioral_traits['communication_style']
      adaptations['communication_adaptation'] = comm_style
    end
    
    adaptations
  end
  
  def determine_cultural_adaptations(geographical_context)
    # This would ideally be much more comprehensive
    case geographical_context.downcase
    when 'us', 'usa', 'united_states'
      ['direct_communication', 'individual_focus', 'time_sensitive']
    when 'uk', 'united_kingdom'
      ['polite_communication', 'understatement', 'queue_culture']
    when 'japan'
      ['formal_communication', 'group_harmony', 'indirect_style']
    else
      ['respectful_communication', 'cultural_sensitivity']
    end
  end
  
  def initialize_performance_metrics
    {
      'created_at' => Time.current.iso8601,
      'usage_count' => 0,
      'effectiveness_scores' => [],
      'adaptation_success_rate' => 0.0,
      'last_performance_update' => Time.current.iso8601,
      'performance_benchmarks' => {
        'baseline_effectiveness' => 5.0,
        'target_effectiveness' => 7.0,
        'excellence_threshold' => 8.5
      }
    }
  end
  
  def apply_brand_adaptation(brand_variant, context)
    # Use the brand variant to adapt the content
    adapted_content = brand_variant.apply_brand_adaptation(content, context)
    
    # Apply additional context-specific adaptations
    if context[:adaptation_goals].present?
      adapted_content = apply_goal_specific_adaptations(adapted_content, context[:adaptation_goals])
    end
    
    # Ensure brand consistency
    adapted_content = ensure_brand_consistency(adapted_content, brand_variant)
    
    # Apply final polishing
    polish_adapted_content(adapted_content, context)
  end
  
  def apply_goal_specific_adaptations(content, goals)
    goals.each do |goal|
      case goal
      when 'increase_engagement'
        content = add_engagement_elements(content)
      when 'improve_clarity'
        content = improve_content_clarity(content)
      when 'enhance_persuasion'
        content = add_persuasive_elements(content)
      when 'boost_memorability'
        content = add_memorable_elements(content)
      end
    end
    
    content
  end
  
  def add_engagement_elements(content)
    # Add questions, calls-to-action, or interactive elements
    if content.length < 200
      content += " What do you think?"
    else
      content += " Share your thoughts in the comments!"
    end
  end
  
  def improve_content_clarity(content)
    # Simplify language and improve readability
    # This is a simplified version - real implementation would use NLP
    content.gsub(/\butilize\b/, 'use')
           .gsub(/\bfacilitate\b/, 'help')
           .gsub(/\bdemonstrate\b/, 'show')
  end
  
  def add_persuasive_elements(content)
    # Add social proof, urgency, or benefits
    persuasive_phrases = [
      'Join thousands of satisfied customers',
      'Limited time offer',
      'Proven results',
      'Risk-free guarantee'
    ]
    
    phrase = persuasive_phrases.sample
    "#{phrase}. #{content}"
  end
  
  def add_memorable_elements(content)
    # Add metaphors, stories, or unique angles
    content = "Here's something interesting: #{content}"
    content += " It's like having a personal assistant that never sleeps!"
  end
  
  def ensure_brand_consistency(content, brand_variant)
    consistency_rules = brand_variant.parsed_adaptation_rules['consistency_rules'] || {}
    
    # Check against brand restrictions
    if brand_identity.restrictions.present?
      restricted_terms = extract_restricted_terms(brand_identity.restrictions)
      content = remove_restricted_terms(content, restricted_terms)
    end
    
    # Ensure brand voice consistency
    if consistency_rules['maintain_brand_voice']
      content = align_with_brand_voice(content)
    end
    
    content
  end
  
  def extract_restricted_terms(restrictions)
    # Extract terms that should be avoided
    # This is a simplified version - real implementation would be more sophisticated
    # Handle common prefixes like "Avoid:", "Don't use:", etc.
    cleaned_restrictions = restrictions.downcase.gsub(/^(avoid|don't\s+use|prohibited|forbidden)[:\s]*/, '')
    cleaned_restrictions.split(/[,;]/).map(&:strip).select { |term| term.length > 2 }
  end
  
  def remove_restricted_terms(content, restricted_terms)
    restricted_terms.each do |term|
      content = content.gsub(/\b#{Regexp.escape(term)}\b/i, '[alternative needed]')
    end
    content
  end
  
  def align_with_brand_voice(content)
    # Ensure content aligns with established brand voice
    # This would ideally use the brand's voice guidelines
    voice_source = brand_identity.brand_voice.presence || brand_identity.tone_guidelines
    
    if voice_source.present?
      voice_keywords = extract_voice_keywords(voice_source)
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
    if missing_keywords.any? && content.length > 10
      keyword = missing_keywords.first
      if content.length > 100
        content += " Our #{keyword} approach ensures the best results."
      else
        content += " (#{keyword})"
      end
    end
    
    content
  end
  
  def polish_adapted_content(content, context)
    # Final polishing based on context
    polished_content = content
    
    # Ensure proper sentence structure
    polished_content = ensure_proper_sentences(polished_content)
    
    # Apply channel-specific final touches
    if context[:channel].present?
      polished_content = apply_channel_final_touches(polished_content, context[:channel])
    end
    
    # Trim to appropriate length if needed
    if context[:max_length].present?
      polished_content = polished_content.truncate(context[:max_length].to_i)
    end
    
    polished_content.strip
  end
  
  # Content adjustment methods used by tests
  def adjust_tone(content, tone_direction, options = {})
    case tone_direction
    when "more_formal"
      content.gsub(/\bHey\b/i, "Hello")
             .gsub(/\bawesome\b/i, "excellent")
             .gsub(/\byou guys\b/i, "you")
             .gsub(/\bkinda\b/i, "somewhat")
    when "more_casual"
      content.gsub(/\bHello\b/, "Hey")
             .gsub(/\bexcellent\b/i, "awesome")
             .gsub(/\bsomewhat\b/i, "kinda")
    else
      content
    end
  end
  
  def adjust_formality(content, formality_level)
    case formality_level
    when "high"
      content.gsub(/\bcan't\b/, "cannot")
             .gsub(/\bwon't\b/, "will not")
             .gsub(/\bdon't\b/, "do not")
             .gsub(/\bisn't\b/, "is not")
    when "low"
      content.gsub(/\bcannot\b/, "can't")
             .gsub(/\bwill not\b/, "won't")
             .gsub(/\bdo not\b/, "don't")
             .gsub(/\bis not\b/, "isn't")
    else
      content
    end
  end
  
  def ensure_proper_sentences(content)
    # Ensure sentences end properly
    content.gsub(/([a-zA-Z])([.!?])\s*$/, '\1\2')
           .gsub(/([a-zA-Z])\s*$/, '\1.')
  end
  
  def apply_channel_final_touches(content, channel)
    case channel.downcase
    when 'twitter'
      # Ensure under character limit and add appropriate hashtags
      content.truncate(260) + " #innovation"
    when 'linkedin'
      # Add professional closing
      content += "\n\nWhat are your thoughts on this?"
    when 'email'
      # Add appropriate email closing
      content += "\n\nBest regards,\nThe Team"
    else
      content
    end
  end
  
  def track_adaptation_usage(brand_variant, context)
    # Increment usage count
    brand_variant.increment_usage!
    
    # Update performance metrics
    metrics = brand_variant.parsed_performance_metrics
    metrics['last_used'] = Time.current.iso8601
    metrics['usage_contexts'] ||= []
    metrics['usage_contexts'] << {
      'context' => context,
      'timestamp' => Time.current.iso8601
    }
    
    # Keep only last 100 usage contexts
    metrics['usage_contexts'] = metrics['usage_contexts'].last(100)
    
    # Update adaptation success tracking
    update_adaptation_success_tracking(brand_variant, metrics, context)
    
    # Save updated metrics
    brand_variant.update!(performance_metrics: metrics)
  end
  
  def update_adaptation_success_tracking(brand_variant, metrics, context)
    # Track successful adaptations by context type
    context_type = context[:adaptation_type] || 'general'
    metrics['success_by_context'] ||= {}
    metrics['success_by_context'][context_type] ||= { 'total' => 0, 'successful' => 0 }
    metrics['success_by_context'][context_type]['total'] += 1
    
    # For now, assume adaptation is successful (would be updated based on actual performance data)
    metrics['success_by_context'][context_type]['successful'] += 1
    
    # Calculate success rate
    total = metrics['success_by_context'][context_type]['total']
    successful = metrics['success_by_context'][context_type]['successful']
    success_rate = (successful.to_f / total * 100).round(2)
    metrics['success_by_context'][context_type]['success_rate'] = success_rate
  end
  
  def calculate_adaptation_metrics(brand_variant)
    metrics = brand_variant.parsed_performance_metrics
    
    {
      usage_count: brand_variant.usage_count,
      effectiveness_score: brand_variant.effectiveness_score,
      last_used: brand_variant.last_used_at,
      adaptation_success_rate: metrics['adaptation_success_rate'] || 0.0,
      context_performance: metrics['success_by_context'] || {},
      performance_trend: brand_variant.send(:calculate_performance_trend),
      benchmarks: metrics['performance_benchmarks'] || {}
    }
  end
  
  private
  
  def analyze_content_consistency(samples)
    # This would ideally use advanced NLP techniques
    # For now, we'll use a simplified approach
    
    scores = {
      tone: calculate_tone_consistency(samples),
      voice: calculate_voice_consistency(samples),
      messaging: calculate_messaging_consistency(samples)
    }
    
    scores[:overall] = (scores.values.sum / scores.values.count).round(2)
    scores
  end
  
  def calculate_tone_consistency(samples)
    # Simplified tone consistency calculation
    # Would ideally use sentiment analysis and tone detection
    
    tone_indicators = {
      'formal' => %w[therefore however consequently furthermore],
      'casual' => %w[hey awesome cool great],
      'professional' => %w[deliver ensure optimize solutions],
      'enthusiastic' => %w[exciting amazing fantastic incredible]
    }
    
    tone_scores = samples.map do |sample|
      sample_lower = sample.downcase
      tone_matches = tone_indicators.map do |tone, indicators|
        match_count = indicators.count { |indicator| sample_lower.include?(indicator) }
        [tone, match_count]
      end.to_h
      
      dominant_tone = tone_matches.max_by { |_, count| count }.first
      { sample: sample, tone: dominant_tone, matches: tone_matches }
    end
    
    # Calculate consistency based on tone distribution
    tone_distribution = tone_scores.group_by { |score| score[:tone] }
    consistency = 1.0 - (tone_distribution.keys.count - 1) * 0.2
    [consistency, 0.0].max.round(2)
  end
  
  def calculate_voice_consistency(samples)
    # Analyze voice consistency across samples
    if brand_identity.brand_voice.blank?
      return 0.5 # Neutral score if no brand voice defined
    end
    
    brand_voice_keywords = extract_voice_keywords(brand_identity.brand_voice)
    
    consistency_scores = samples.map do |sample|
      sample_lower = sample.downcase
      matches = brand_voice_keywords.count { |keyword| sample_lower.include?(keyword) }
      matches.to_f / brand_voice_keywords.count
    end
    
    # Calculate average consistency
    average_consistency = consistency_scores.sum / consistency_scores.count
    
    # Penalize high variance
    variance = consistency_scores.map { |score| (score - average_consistency) ** 2 }.sum / consistency_scores.count
    consistency_penalty = [variance * 2, 0.5].min
    
    [average_consistency - consistency_penalty, 0.0].max.round(2)
  end
  
  def calculate_messaging_consistency(samples)
    # Analyze messaging consistency
    if brand_identity.messaging_framework.blank?
      return 0.5 # Neutral score if no messaging framework
    end
    
    key_messages = extract_key_messages_for_context({})
    return 0.5 if key_messages.empty?
    
    message_presence = samples.map do |sample|
      sample_lower = sample.downcase
      present_messages = key_messages.count { |msg| sample_lower.include?(msg.downcase) }
      present_messages.to_f / key_messages.count
    end
    
    # Consistency is better if all samples have similar message presence
    average_presence = message_presence.sum / message_presence.count
    variance = message_presence.map { |presence| (presence - average_presence) ** 2 }.sum / message_presence.count
    
    consistency_score = average_presence - (variance * 0.5)
    [consistency_score, 0.0].max.round(2)
  end
  
  def analyze_brand_alignment(samples)
    alignment = {
      voice_alignment: 0.0,
      tone_alignment: 0.0,
      messaging_alignment: 0.0,
      restriction_compliance: 1.0
    }
    
    # Voice alignment
    if brand_identity.brand_voice.present?
      alignment[:voice_alignment] = calculate_voice_consistency(samples)
    end
    
    # Tone alignment  
    if brand_identity.tone_guidelines.present?
      alignment[:tone_alignment] = calculate_tone_alignment(samples)
    end
    
    # Messaging alignment
    if brand_identity.messaging_framework.present?
      alignment[:messaging_alignment] = calculate_messaging_consistency(samples)
    end
    
    # Restriction compliance
    if brand_identity.restrictions.present?
      alignment[:restriction_compliance] = calculate_restriction_compliance(samples)
    end
    
    alignment[:overall] = alignment.values.sum / alignment.values.count
    alignment
  end
  
  def calculate_tone_alignment(samples)
    target_tone = extract_tone_from_guidelines
    return 0.5 unless target_tone
    
    # This is simplified - would need more sophisticated tone analysis
    aligned_samples = samples.count do |sample|
      sample_tone = detect_sample_tone(sample)
      sample_tone == target_tone
    end
    
    (aligned_samples.to_f / samples.count).round(2)
  end
  
  def detect_sample_tone(sample)
    # Simplified tone detection
    sample_lower = sample.downcase
    
    if sample_lower.match?(/\b(therefore|however|consequently)\b/)
      'professional'
    elsif sample_lower.match?(/\b(hey|awesome|cool)\b/)
      'casual'
    elsif sample_lower.match?(/\b(exciting|amazing|fantastic)\b/)
      'enthusiastic'
    else
      'balanced'
    end
  end
  
  def calculate_restriction_compliance(samples)
    return 1.0 if brand_identity.restrictions.blank?
    
    restricted_terms = extract_restricted_terms(brand_identity.restrictions)
    return 1.0 if restricted_terms.empty?
    
    violations = samples.sum do |sample|
      sample_lower = sample.downcase
      restricted_terms.count { |term| sample_lower.include?(term) }
    end
    
    total_possible_violations = samples.count * restricted_terms.count
    compliance_rate = 1.0 - (violations.to_f / total_possible_violations)
    
    [compliance_rate, 0.0].max.round(2)
  end
  
  def generate_consistency_recommendations(consistency_scores, brand_alignment)
    recommendations = []
    
    if consistency_scores[:overall] < 0.7
      recommendations << {
        type: 'consistency',
        priority: 'high',
        message: 'Content consistency is below target. Focus on maintaining uniform tone and messaging.'
      }
    end
    
    if brand_alignment[:voice_alignment] < 0.6
      recommendations << {
        type: 'voice_alignment',
        priority: 'high',
        message: 'Content voice alignment needs improvement. Review brand voice guidelines.'
      }
    end
    
    if brand_alignment[:tone_alignment] < 0.6
      recommendations << {
        type: 'tone_alignment',
        priority: 'medium',
        message: 'Tone consistency could be improved. Ensure all content follows tone guidelines.'
      }
    end
    
    if brand_alignment[:restriction_compliance] < 0.9
      recommendations << {
        type: 'compliance',
        priority: 'critical',
        message: 'Brand restriction violations detected. Review and correct restricted content.'
      }
    end
    
    if consistency_scores[:messaging] < 0.6
      recommendations << {
        type: 'messaging',
        priority: 'medium',
        message: 'Key messaging consistency needs attention. Ensure core messages are present.'
      }
    end
    
    # Add positive reinforcement
    if consistency_scores[:overall] >= 0.8
      recommendations << {
        type: 'positive',
        priority: 'low',
        message: 'Excellent content consistency. Continue following current guidelines.'
      }
    end
    
    recommendations
  end
end