class PersonaTailoringService
  def initialize(user, content = nil)
    @user = user
    @content = content
  end

  def call
    return failure("User must have active personas") unless @user.has_personas?
    return failure("Content is required for adaptation") unless @content

    result = {
      success: true,
      adaptations: [],
      persona_matches: [],
      recommendations: []
    }

    # Generate persona adaptations for all active personas
    @user.active_personas.each do |persona|
      adaptation_result = create_persona_adaptation(persona)
      
      if adaptation_result[:success]
        result[:adaptations] << adaptation_result[:adaptation]
        result[:persona_matches] << {
          persona: persona,
          match_score: calculate_persona_content_match(persona, @content)
        }
      end
    end

    # Generate recommendations for optimization
    result[:recommendations] = generate_optimization_recommendations(result[:adaptations])

    success(result)
  rescue => e
    failure("Error in persona tailoring: #{e.message}")
  end

  def self.tailor_content_for_user_profile(content, user_profile, user)
    return content.body_content unless user_profile.is_a?(Hash) && user.has_personas?

    service = new(user, content)
    matching_personas = user.find_matching_personas(user_profile)
    
    return content.body_content if matching_personas.empty?

    best_persona = matching_personas.first
    adaptation = content.persona_contents.find_by(persona: best_persona)
    
    if adaptation&.effective?
      adaptation.adapted_content
    else
      # Create adaptation on-demand
      service.create_persona_adaptation(best_persona)[:adaptation]&.adapted_content || content.body_content
    end
  end

  def self.batch_create_adaptations(user, contents)
    return [] unless user.has_personas? && contents.any?

    service = new(user)
    results = []

    contents.each do |content|
      service.instance_variable_set(:@content, content)
      result = service.call
      results << {
        content_id: content.id,
        content_title: content.title,
        result: result
      }
    end

    results
  end

  def self.analyze_persona_effectiveness(user, time_period = 30.days)
    return {} unless user.has_personas?

    personas_analysis = {}
    
    user.active_personas.each do |persona|
      recent_adaptations = persona.persona_contents
                                 .where('persona_contents.created_at >= ?', time_period.ago)
                                 .includes(:generated_content)

      personas_analysis[persona.id] = {
        persona_name: persona.name,
        total_adaptations: recent_adaptations.count,
        average_effectiveness: recent_adaptations.average(:effectiveness_score) || 0.0,
        content_types_adapted: recent_adaptations.joins(:generated_content)
                                               .group('generated_contents.content_type')
                                               .count,
        best_adaptation_types: recent_adaptations.group(:adaptation_type)
                                                .average(:effectiveness_score)
                                                .transform_values { |v| v || 0 }
                                                .sort_by(&:last)
                                                .reverse
                                                .first(3),
        performance_trend: calculate_performance_trend(recent_adaptations)
      }
    end

    personas_analysis
  end

  def self.recommend_persona_improvements(user)
    return [] unless user.has_personas?

    recommendations = []
    
    user.active_personas.each do |persona|
      persona_analysis = analyze_single_persona(persona)
      recommendations.concat(generate_persona_recommendations(persona, persona_analysis))
    end

    recommendations.sort_by { |rec| rec[:priority] }.reverse
  end

  def create_persona_adaptation(persona)
    return failure("Adaptation already exists") if @content.persona_contents.exists?(persona: persona)

    adaptation_type = determine_optimal_adaptation_type(persona, @content)
    
    begin
      adaptation = @content.create_persona_adaptation(
        persona, 
        adaptation_type,
        {
          rationale: "Automated adaptation for #{persona.name} based on persona characteristics",
          primary: @content.persona_contents.empty?
        }
      )

      success({
        adaptation: adaptation,
        persona: persona,
        adaptation_type: adaptation_type
      })
    rescue => e
      failure("Failed to create adaptation: #{e.message}")
    end
  end

  private

  def determine_optimal_adaptation_type(persona, content)
    # Analyze persona characteristics and content type to determine best adaptation
    content_type = content.content_type
    persona_traits = persona.parse_behavioral_traits
    persona_preferences = persona.parse_content_preferences
    
    # Content-type specific recommendations
    type_recommendations = {
      'email' => 'tone_adaptation',
      'social_post' => 'length_adaptation', 
      'blog_article' => 'goal_alignment',
      'ad_copy' => 'behavioral_trigger',
      'landing_page' => 'demographic_targeting'
    }

    base_recommendation = type_recommendations[content_type] || 'personalized_messaging'

    # Override based on persona traits
    if persona_traits['urgency_sensitive'] == true
      'behavioral_trigger'
    elsif persona_traits['attention_span'] == 'short'
      'length_adaptation'
    elsif persona_preferences['tone']&.present?
      'tone_adaptation'
    elsif persona.preferred_channels.present? && persona.parse_preferred_channels.any?
      'channel_optimization'
    else
      base_recommendation
    end
  end

  def calculate_persona_content_match(persona, content)
    # Calculate how well a persona matches with specific content
    score = 0
    max_score = 0

    # Content type preference match
    if persona.content_preferences.present?
      prefs = persona.parse_content_preferences
      if prefs['preferred_content_types']&.include?(content.content_type)
        score += 25
      end
      max_score += 25
    end

    # Channel alignment
    if persona.preferred_channels.present? && content.platform_settings.any?
      channels = persona.parse_preferred_channels
      if channels.any? { |c| content.platform_settings.key?(c) }
        score += 20
      end
      max_score += 20
    end

    # Goal alignment with content metadata
    if persona.goals.present? && content.metadata&.dig('target_goals')
      goals = persona.parse_goals_data
      target_goals = content.metadata['target_goals']
      overlap = goals & target_goals
      score += overlap.size * 5
      max_score += goals.size * 5
    end

    # Length preference alignment
    if persona.behavioral_traits.present?
      traits = persona.parse_behavioral_traits
      attention_span = traits['attention_span']
      content_length = content.body_content.length

      length_match = case attention_span
                    when 'short' then content_length < 500 ? 15 : 5
                    when 'medium' then content_length.between?(300, 1500) ? 15 : 8
                    when 'long' then content_length > 1000 ? 15 : 10
                    else 10
                    end
      
      score += length_match
      max_score += 15
    end

    max_score.zero? ? 0 : (score.to_f / max_score * 100).round(2)
  end

  def generate_optimization_recommendations(adaptations)
    recommendations = []

    # Analyze adaptation effectiveness
    effective_adaptations = adaptations.select { |a| a[:adaptation]&.effective? }
    
    if effective_adaptations.empty?
      recommendations << {
        type: 'improvement',
        priority: 'high',
        message: 'No highly effective adaptations found. Consider refining persona characteristics.',
        action: 'review_personas'
      }
    end

    # Check for missing adaptation types
    used_types = adaptations.map { |a| a[:adaptation_type] }.compact.uniq
    missing_types = PersonaContent::ADAPTATION_TYPES - used_types

    if missing_types.any?
      recommendations << {
        type: 'expansion',
        priority: 'medium', 
        message: "Consider testing these adaptation types: #{missing_types.join(', ')}",
        action: 'test_adaptation_types',
        data: missing_types
      }
    end

    # Performance-based recommendations
    if adaptations.any? { |a| a[:adaptation] }
      avg_match_score = adaptations.map { |a| a.dig(:persona_matches, :match_score) || 0 }.sum.to_f / adaptations.size
      
      if avg_match_score < 60
        recommendations << {
          type: 'targeting',
          priority: 'high',
          message: 'Low persona-content match scores detected. Review persona targeting rules.',
          action: 'refine_targeting'
        }
      end
    end

    recommendations
  end

  def self.calculate_performance_trend(adaptations)
    return 'insufficient_data' if adaptations.count < 3

    # Sort by creation date and calculate trend
    sorted_adaptations = adaptations.order(:created_at)
    recent_half = sorted_adaptations.last(sorted_adaptations.count / 2)
    earlier_half = sorted_adaptations.first(sorted_adaptations.count / 2)

    recent_avg = recent_half.average(:effectiveness_score) || 0
    earlier_avg = earlier_half.average(:effectiveness_score) || 0

    if recent_avg > earlier_avg + 0.5
      'improving'
    elsif recent_avg < earlier_avg - 0.5
      'declining'
    else
      'stable'
    end
  end

  def self.analyze_single_persona(persona)
    adaptations = persona.persona_contents.includes(:generated_content)
    
    {
      total_adaptations: adaptations.count,
      average_effectiveness: adaptations.average(:effectiveness_score) || 0,
      content_type_performance: adaptations.joins(:generated_content)
                                          .group('generated_contents.content_type')
                                          .average(:effectiveness_score)
                                          .transform_values { |v| v || 0 },
      adaptation_type_performance: adaptations.group(:adaptation_type)
                                             .average(:effectiveness_score)
                                             .transform_values { |v| v || 0 },
      recent_performance: adaptations.where('persona_contents.created_at >= ?', 7.days.ago)
                                    .average(:effectiveness_score) || 0
    }
  end

  def self.generate_persona_recommendations(persona, analysis)
    recommendations = []

    # Low performance recommendation
    if analysis[:average_effectiveness] < 5.0
      recommendations << {
        persona_id: persona.id,
        persona_name: persona.name,
        type: 'performance',
        priority: 9,
        message: 'Persona showing low adaptation effectiveness. Consider reviewing characteristics.',
        action: 'review_persona_definition'
      }
    end

    # Content type gaps
    adapted_types = analysis[:content_type_performance].keys
    all_types = GeneratedContent::CONTENT_TYPES
    missing_types = all_types - adapted_types

    if missing_types.size > 3
      recommendations << {
        persona_id: persona.id,
        persona_name: persona.name,
        type: 'coverage',
        priority: 6,
        message: "Persona has limited content type coverage. Consider testing: #{missing_types.first(3).join(', ')}",
        action: 'expand_content_coverage'
      }
    end

    # Best performing adaptation types
    if analysis[:adaptation_type_performance].any?
      best_type = analysis[:adaptation_type_performance].max_by(&:last)
      
      if best_type && best_type.last > 7.0
        recommendations << {
          persona_id: persona.id,
          persona_name: persona.name,
          type: 'strength',
          priority: 3,
          message: "#{best_type.first} adaptations perform exceptionally well for this persona",
          action: 'leverage_strength'
        }
      end
    end

    recommendations
  end

  def success(data)
    { success: true }.merge(data)
  end

  def failure(message)
    { success: false, error: message }
  end
end