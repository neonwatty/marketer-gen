# AI-powered service for generating intelligent variant suggestions
# Analyzes content patterns, performance data, and best practices to recommend optimal variants
class AiVariantAdvisorService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Best practice patterns for different content types and platforms
  BEST_PRACTICE_PATTERNS = {
    social_media: {
      twitter: {
        optimal_length_range: (100..200),
        engagement_boosters: ['questions', 'emojis', 'hashtags', 'mentions'],
        high_performing_structures: ['question_first', 'benefit_statement', 'story_hook'],
        cta_effectiveness: { 'reply' => 0.8, 'retweet' => 0.7, 'click_link' => 0.6 },
        timing_insights: { 'morning' => 0.7, 'afternoon' => 0.9, 'evening' => 0.6 }
      },
      instagram: {
        optimal_length_range: (200..500),
        engagement_boosters: ['hashtags', 'emojis', 'user_tags', 'location_tags'],
        high_performing_structures: ['story_driven', 'behind_scenes', 'user_generated'],
        hashtag_range: (10..25),
        timing_insights: { 'morning' => 0.6, 'afternoon' => 0.8, 'evening' => 0.9 }
      },
      linkedin: {
        optimal_length_range: (300..800),
        engagement_boosters: ['industry_insights', 'data_points', 'professional_questions'],
        high_performing_structures: ['insight_sharing', 'case_study', 'thought_leadership'],
        professional_tone_required: true,
        timing_insights: { 'weekday_morning' => 0.9, 'weekday_afternoon' => 0.8, 'weekend' => 0.3 }
      },
      facebook: {
        optimal_length_range: (150..400),
        engagement_boosters: ['visual_content', 'community_questions', 'shared_experiences'],
        high_performing_structures: ['community_focused', 'storytelling', 'value_sharing'],
        timing_insights: { 'evening' => 0.8, 'weekend' => 0.7, 'afternoon' => 0.6 }
      }
    },
    email: {
      newsletter: {
        subject_line_range: (30..50),
        body_length_range: (200..800),
        engagement_boosters: ['personalization', 'clear_value_prop', 'scannable_format'],
        high_performing_structures: ['problem_solution', 'news_update', 'how_to_guide'],
        optimal_cta_count: 1
      },
      promotional: {
        subject_line_range: (25..40),
        body_length_range: (100..400),
        engagement_boosters: ['urgency', 'social_proof', 'clear_benefit'],
        high_performing_structures: ['benefit_focused', 'urgency_driven', 'testimonial_based'],
        optimal_cta_count: 1
      }
    },
    ads: {
      google_ads: {
        headline_range: (20..30),
        description_range: (80..90),
        engagement_boosters: ['keywords', 'benefits', 'call_to_action'],
        high_performing_structures: ['keyword_focused', 'benefit_driven', 'action_oriented']
      },
      facebook_ads: {
        headline_range: (25..40),
        body_range: (90..125),
        engagement_boosters: ['visual_appeal', 'social_proof', 'clear_value'],
        high_performing_structures: ['visual_first', 'social_proof', 'benefit_statement']
      }
    }
  }.freeze

  # Performance prediction models based on content analysis
  PERFORMANCE_MODELS = {
    engagement_factors: {
      emotional_words: { weight: 0.15, positive_impact: true },
      question_marks: { weight: 0.12, positive_impact: true },
      personal_pronouns: { weight: 0.10, positive_impact: true },
      power_words: { weight: 0.13, positive_impact: true },
      numbers_and_stats: { weight: 0.08, positive_impact: true },
      urgency_words: { weight: 0.07, positive_impact: true, platform_dependent: true }
    },
    conversion_factors: {
      clear_value_proposition: { weight: 0.20, positive_impact: true },
      social_proof: { weight: 0.15, positive_impact: true },
      scarcity_indicators: { weight: 0.12, positive_impact: true },
      risk_reduction: { weight: 0.10, positive_impact: true },
      specific_benefits: { weight: 0.13, positive_impact: true }
    },
    readability_factors: {
      sentence_length: { weight: 0.15, optimal_range: (10..20) },
      paragraph_length: { weight: 0.10, optimal_range: (2..4) },
      syllable_complexity: { weight: 0.12, positive_impact: false },
      active_voice: { weight: 0.08, positive_impact: true }
    }
  }.freeze

  # AI prompt templates for different variant generation scenarios
  AI_PROMPT_TEMPLATES = {
    performance_optimization: {
      template: "Analyze this content and suggest 3 high-performing variants based on proven marketing principles:\n\nOriginal: {content}\nPlatform: {platform}\nGoal: {goal}\n\nFor each variant, explain the strategy and expected performance improvement.",
      max_tokens: 800,
      temperature: 0.7
    },
    audience_targeting: {
      template: "Create variants of this content optimized for different audience segments:\n\nContent: {content}\nAudiences: {audiences}\nPlatform: {platform}\n\nTailor messaging, tone, and approach for each audience while maintaining core value proposition.",
      max_tokens: 1000,
      temperature: 0.8
    },
    competitive_analysis: {
      template: "Based on competitive analysis and industry trends, suggest content variants that would outperform typical industry content:\n\nContent: {content}\nIndustry: {industry}\nCompetitive landscape: {competitive_insights}\n\nFocus on differentiation and unique value propositions.",
      max_tokens: 900,
      temperature: 0.6
    },
    conversion_optimization: {
      template: "Optimize this content for maximum conversion rates using proven persuasion techniques:\n\nContent: {content}\nConversion goal: {conversion_goal}\nTarget audience: {audience}\n\nApply psychological triggers, social proof, and urgency where appropriate.",
      max_tokens: 700,
      temperature: 0.5
    }
  }.freeze

  attr_accessor :ai_service, :performance_data, :industry_insights, :competitive_data

  def initialize(ai_service:, performance_data: {}, industry_insights: {}, competitive_data: {})
    @ai_service = ai_service
    @performance_data = performance_data || {}
    @industry_insights = industry_insights || {}
    @competitive_data = competitive_data || {}
    validate_ai_service!
  end

  # Generate AI-powered variant suggestions based on comprehensive analysis
  def generate_intelligent_suggestions(content, context = {})
    analysis_result = {
      content_analysis: analyze_content_deeply(content, context),
      performance_predictions: predict_performance_potential(content, context),
      ai_recommendations: generate_ai_recommendations(content, context),
      optimization_opportunities: identify_optimization_opportunities(content, context),
      variant_strategies: recommend_variant_strategies(content, context),
      expected_improvements: calculate_expected_improvements(content, context)
    }

    # Generate specific variant suggestions
    analysis_result[:suggested_variants] = create_suggested_variants(content, context, analysis_result)
    
    analysis_result
  end

  # Generate variants optimized for specific performance goals
  def generate_goal_optimized_suggestions(content, goal, context = {})
    goal_context = context.merge(optimization_goal: goal)
    
    case goal.to_sym
    when :engagement
      generate_engagement_optimized_variants(content, goal_context)
    when :conversion
      generate_conversion_optimized_variants(content, goal_context)
    when :click_through
      generate_ctr_optimized_variants(content, goal_context)
    when :brand_awareness
      generate_awareness_optimized_variants(content, goal_context)
    else
      generate_intelligent_suggestions(content, goal_context)
    end
  end

  # Analyze historical performance and suggest improvements
  def analyze_and_suggest_improvements(content, historical_data = {})
    merged_data = performance_data.merge(historical_data)
    
    analysis = {
      performance_gaps: identify_performance_gaps(content, merged_data),
      successful_patterns: extract_successful_patterns(merged_data),
      improvement_opportunities: find_improvement_opportunities(content, merged_data),
      recommended_changes: generate_improvement_recommendations(content, merged_data)
    }

    # Generate AI-powered improvement suggestions
    analysis[:ai_suggestions] = generate_improvement_focused_variants(content, analysis)
    
    analysis
  end

  # Generate variants based on competitive intelligence
  def generate_competitive_variants(content, competitor_analysis = {})
    competitive_context = competitive_data.merge(competitor_analysis)
    
    {
      competitive_landscape: analyze_competitive_landscape(competitive_context),
      differentiation_opportunities: identify_differentiation_opportunities(content, competitive_context),
      competitive_variants: create_competitive_variants(content, competitive_context),
      positioning_strategies: recommend_positioning_strategies(content, competitive_context)
    }
  end

  # Generate audience-specific variants
  def generate_audience_targeted_variants(content, audience_segments, context = {})
    audience_variants = {}
    
    audience_segments.each do |segment, segment_data|
      segment_context = context.merge(
        target_audience: segment,
        audience_data: segment_data
      )
      
      audience_variants[segment] = {
        tailored_content: generate_audience_specific_content(content, segment_context),
        messaging_strategy: determine_messaging_strategy(segment_data),
        tone_adjustments: recommend_tone_adjustments(segment_data),
        platform_optimizations: suggest_platform_optimizations(segment_data, context[:platform])
      }
    end
    
    audience_variants
  end

  private

  def validate_ai_service!
    raise ArgumentError, "AI service is required for variant suggestions" unless ai_service
  end

  # Deep content analysis
  def analyze_content_deeply(content, context)
    {
      structural_analysis: analyze_content_structure(content),
      linguistic_analysis: analyze_language_patterns(content),
      persuasion_analysis: analyze_persuasion_elements(content),
      platform_alignment: analyze_platform_alignment(content, context[:platform]),
      audience_alignment: analyze_audience_alignment(content, context[:target_audience]),
      competitive_positioning: analyze_competitive_position(content)
    }
  end

  def analyze_content_structure(content)
    sentences = content.split(/[.!?]+/).reject(&:blank?)
    paragraphs = content.split(/\n\s*\n/).reject(&:blank?)
    
    {
      sentence_count: sentences.length,
      paragraph_count: paragraphs.length,
      average_sentence_length: sentences.empty? ? 0 : content.split.length / sentences.length,
      structure_type: determine_structure_type(content),
      flow_analysis: analyze_content_flow(sentences),
      readability_score: calculate_readability_score(content)
    }
  end

  def analyze_language_patterns(content)
    words = content.downcase.split(/\W+/).reject(&:blank?)
    
    {
      word_count: words.length,
      unique_word_ratio: words.uniq.length.to_f / words.length,
      emotional_language_score: calculate_emotional_language_score(content),
      power_words_count: count_power_words(content),
      technical_language_level: assess_technical_language(content),
      sentiment_analysis: analyze_sentiment(content)
    }
  end

  def analyze_persuasion_elements(content)
    {
      social_proof_indicators: extract_social_proof(content),
      urgency_indicators: extract_urgency_elements(content),
      authority_signals: extract_authority_signals(content),
      scarcity_elements: extract_scarcity_elements(content),
      reciprocity_triggers: extract_reciprocity_triggers(content),
      commitment_consistency: extract_commitment_elements(content)
    }
  end

  def analyze_platform_alignment(content, platform)
    return { alignment_score: 0.5, issues: [] } unless platform
    
    platform_rules = BEST_PRACTICE_PATTERNS.dig(:social_media, platform.to_sym) || 
                    BEST_PRACTICE_PATTERNS.dig(:email, platform.to_sym) ||
                    BEST_PRACTICE_PATTERNS.dig(:ads, platform.to_sym) || {}
    
    alignment_issues = []
    alignment_score = 1.0
    
    # Check length alignment
    if platform_rules[:optimal_length_range]
      range = platform_rules[:optimal_length_range]
      unless range.include?(content.length)
        alignment_issues << "Content length (#{content.length}) outside optimal range (#{range})"
        alignment_score -= 0.2
      end
    end
    
    # Check engagement boosters
    if platform_rules[:engagement_boosters]
      missing_boosters = platform_rules[:engagement_boosters] - detect_engagement_elements(content)
      if missing_boosters.any?
        alignment_issues << "Missing engagement boosters: #{missing_boosters.join(', ')}"
        alignment_score -= 0.1 * missing_boosters.length
      end
    end
    
    {
      alignment_score: [alignment_score, 0.0].max,
      issues: alignment_issues,
      recommendations: generate_platform_recommendations(platform_rules, content)
    }
  end

  def analyze_audience_alignment(content, audience)
    return { alignment_score: 0.5 } unless audience
    
    # Analyze tone appropriateness for audience
    tone_analysis = analyze_tone_for_audience(content, audience)
    
    # Analyze complexity level
    complexity_analysis = analyze_complexity_for_audience(content, audience)
    
    # Analyze interest alignment
    interest_analysis = analyze_interest_alignment(content, audience)
    
    {
      tone_alignment: tone_analysis,
      complexity_alignment: complexity_analysis,
      interest_alignment: interest_analysis,
      overall_alignment: (tone_analysis[:score] + complexity_analysis[:score] + interest_analysis[:score]) / 3
    }
  end

  # Performance prediction
  def predict_performance_potential(content, context)
    predictions = {}
    
    PERFORMANCE_MODELS.each do |model_type, factors|
      model_score = 0.0
      factor_scores = {}
      
      factors.each do |factor, config|
        factor_score = calculate_factor_score(content, factor, config)
        factor_scores[factor] = factor_score
        model_score += factor_score * config[:weight]
      end
      
      predictions[model_type] = {
        overall_score: model_score,
        factor_breakdown: factor_scores,
        confidence_level: calculate_prediction_confidence(model_score, factor_scores)
      }
    end
    
    predictions
  end

  def calculate_factor_score(content, factor, config)
    case factor
    when :emotional_words
      calculate_emotional_words_score(content)
    when :question_marks
      calculate_question_score(content)
    when :personal_pronouns
      calculate_personal_pronouns_score(content)
    when :power_words
      calculate_power_words_score(content)
    when :numbers_and_stats
      calculate_numbers_score(content)
    when :urgency_words
      calculate_urgency_score(content)
    when :clear_value_proposition
      calculate_value_prop_score(content)
    when :social_proof
      calculate_social_proof_score(content)
    when :scarcity_indicators
      calculate_scarcity_score(content)
    else
      0.5 # Default neutral score
    end
  end

  # AI recommendation generation
  def generate_ai_recommendations(content, context)
    recommendations = []
    
    # Select appropriate AI prompt template
    template_key = determine_prompt_template(context)
    template_config = AI_PROMPT_TEMPLATES[template_key]
    
    # Build AI prompt
    prompt = build_ai_prompt(template_config[:template], content, context)
    
    begin
      ai_response = ai_service.generate_content({
        prompt: prompt,
        max_tokens: template_config[:max_tokens],
        temperature: template_config[:temperature],
        context: context
      })
      
      recommendations = parse_ai_recommendations(ai_response)
      
    rescue => e
      Rails.logger.error "AI recommendation generation failed: #{e.message}"
      recommendations = generate_fallback_recommendations(content, context)
    end
    
    recommendations
  end

  def determine_prompt_template(context)
    if context[:optimization_goal] == :conversion
      :conversion_optimization
    elsif context[:competitive_analysis]
      :competitive_analysis
    elsif context[:audience_segments]
      :audience_targeting
    else
      :performance_optimization
    end
  end

  def build_ai_prompt(template, content, context)
    prompt = template.dup
    
    # Replace template variables
    prompt.gsub!('{content}', content)
    prompt.gsub!('{platform}', context[:platform].to_s)
    prompt.gsub!('{goal}', context[:optimization_goal].to_s)
    prompt.gsub!('{audience}', context[:target_audience].to_s)
    prompt.gsub!('{industry}', industry_insights[:industry_name].to_s)
    
    # Add performance context if available
    if performance_data.any?
      prompt += "\n\nPerformance Context:\n"
      prompt += format_performance_context(performance_data)
    end
    
    # Add competitive context if available
    if competitive_data.any?
      prompt += "\n\nCompetitive Context:\n"
      prompt += format_competitive_context(competitive_data)
    end
    
    prompt
  end

  def parse_ai_recommendations(ai_response)
    # Parse structured AI response into recommendations
    content = ai_response.is_a?(Hash) ? ai_response[:content] : ai_response.to_s
    
    recommendations = []
    
    # Look for numbered recommendations
    content.scan(/\d+\.\s*(.+?)(?=\d+\.|$)/m) do |match|
      recommendation_text = match[0].strip
      
      recommendations << {
        text: recommendation_text,
        strategy: extract_strategy_from_text(recommendation_text),
        confidence: extract_confidence_from_text(recommendation_text),
        expected_improvement: extract_improvement_from_text(recommendation_text)
      }
    end
    
    # If no numbered recommendations found, treat as single recommendation
    if recommendations.empty?
      recommendations << {
        text: content,
        strategy: 'general_improvement',
        confidence: 0.7,
        expected_improvement: 'moderate'
      }
    end
    
    recommendations
  end

  def generate_fallback_recommendations(content, context)
    [
      {
        text: "Consider adding a compelling question to increase engagement",
        strategy: 'engagement_boost',
        confidence: 0.6,
        expected_improvement: 'moderate'
      },
      {
        text: "Strengthen the call-to-action to improve conversion rates",
        strategy: 'cta_optimization',
        confidence: 0.7,
        expected_improvement: 'high'
      },
      {
        text: "Add specific numbers or statistics to increase credibility",
        strategy: 'credibility_boost',
        confidence: 0.5,
        expected_improvement: 'moderate'
      }
    ]
  end

  # Variant strategy recommendation
  def recommend_variant_strategies(content, context)
    strategies = []
    
    # Analyze current content weaknesses
    weaknesses = identify_content_weaknesses(content, context)
    
    # Recommend strategies based on weaknesses
    weaknesses.each do |weakness|
      strategy = map_weakness_to_strategy(weakness)
      strategies << strategy if strategy
    end
    
    # Add platform-specific strategies
    if context[:platform]
      platform_strategies = get_platform_specific_strategies(context[:platform])
      strategies += platform_strategies
    end
    
    # Add goal-specific strategies
    if context[:optimization_goal]
      goal_strategies = get_goal_specific_strategies(context[:optimization_goal])
      strategies += goal_strategies
    end
    
    strategies.uniq
  end

  def identify_content_weaknesses(content, context)
    weaknesses = []
    
    # Check for common weaknesses
    weaknesses << :weak_headline unless has_strong_headline(content)
    weaknesses << :unclear_value_prop unless has_clear_value_proposition(content)
    weaknesses << :weak_cta unless has_strong_cta(content)
    weaknesses << :low_engagement unless has_engagement_elements(content)
    weaknesses << :poor_readability if poor_readability(content)
    weaknesses << :lack_social_proof unless has_social_proof(content)
    
    weaknesses
  end

  def map_weakness_to_strategy(weakness)
    strategy_mapping = {
      weak_headline: 'headline_variation',
      unclear_value_prop: 'benefit_focused_rewrite',
      weak_cta: 'cta_variation',
      low_engagement: 'engagement_optimization',
      poor_readability: 'structure_simplification',
      lack_social_proof: 'social_proof_integration'
    }
    
    strategy_mapping[weakness]
  end

  # Specific optimization methods
  def generate_engagement_optimized_variants(content, context)
    engagement_strategies = [
      'Add compelling questions to encourage interaction',
      'Include emotional triggers to create connection',
      'Use power words to increase impact',
      'Add personal pronouns to create intimacy',
      'Include trending hashtags or topics'
    ]
    
    create_strategy_based_variants(content, engagement_strategies, context)
  end

  def generate_conversion_optimized_variants(content, context)
    conversion_strategies = [
      'Strengthen call-to-action with urgency',
      'Add social proof elements',
      'Clarify unique value proposition',
      'Reduce friction in messaging',
      'Add risk-reduction guarantees'
    ]
    
    create_strategy_based_variants(content, conversion_strategies, context)
  end

  def generate_ctr_optimized_variants(content, context)
    ctr_strategies = [
      'Create curiosity-driven headlines',
      'Use numbers and specific benefits',
      'Add urgency indicators',
      'Include power words that demand attention',
      'Create benefit-focused subject lines'
    ]
    
    create_strategy_based_variants(content, ctr_strategies, context)
  end

  def create_strategy_based_variants(content, strategies, context)
    variants = []
    
    strategies.each_with_index do |strategy, index|
      variant_prompt = build_strategy_prompt(content, strategy, context)
      
      begin
        ai_response = ai_service.generate_content({
          prompt: variant_prompt,
          max_tokens: 400,
          temperature: 0.7,
          context: context
        })
        
        variant_content = extract_content_from_ai_response(ai_response)
        
        variants << {
          id: "strategy_#{index + 1}",
          content: variant_content,
          strategy: strategy,
          expected_improvement: predict_strategy_improvement(strategy),
          confidence: calculate_strategy_confidence(strategy)
        }
        
      rescue => e
        Rails.logger.error "Strategy-based variant generation failed: #{e.message}"
      end
    end
    
    variants
  end

  def build_strategy_prompt(content, strategy, context)
    "Apply this strategy to improve the content: #{strategy}\n\n" \
    "Original content: #{content}\n\n" \
    "Platform: #{context[:platform]}\n" \
    "Goal: #{context[:optimization_goal]}\n\n" \
    "Generate an improved version that implements the strategy while maintaining the core message."
  end

  # Helper methods for content analysis
  def has_strong_headline(content)
    first_sentence = content.split(/[.!?]+/).first&.strip
    return false unless first_sentence
    
    # Check for headline indicators
    first_sentence.match?(/\b(how|why|what|when|where|discover|learn|get|save|increase)\b/i) ||
    first_sentence.include?('?') ||
    first_sentence.match?(/\d+/) ||
    first_sentence.length.between?(20, 60)
  end

  def has_clear_value_proposition(content)
    value_indicators = %w[save gain get achieve improve increase reduce solve help benefit]
    content_words = content.downcase.split(/\W+/)
    (content_words & value_indicators).any?
  end

  def has_strong_cta(content)
    cta_patterns = [
      /\b(get started|learn more|sign up|buy now|contact us|try now|download|subscribe)\b/i,
      /\b(click|call|visit|shop|order|book|register)\b/i
    ]
    
    cta_patterns.any? { |pattern| content.match?(pattern) }
  end

  def has_engagement_elements(content)
    content.include?('?') || 
    content.match?(/\b(you|your|we|us)\b/i) ||
    content.match?(/\b(think|believe|feel|agree|share)\b/i)
  end

  def has_social_proof(content)
    social_proof_indicators = %w[customers clients users testimonial review rating thousand million]
    content_words = content.downcase.split(/\W+/)
    (content_words & social_proof_indicators).any?
  end

  def poor_readability(content)
    sentences = content.split(/[.!?]+/).reject(&:blank?)
    return true if sentences.empty?
    
    avg_sentence_length = content.split.length.to_f / sentences.length
    avg_sentence_length > 25 # Sentences too long
  end

  # Utility methods
  def calculate_emotional_language_score(content)
    emotional_words = %w[amazing incredible fantastic love hate exciting thrilling wonderful terrible awful]
    content_words = content.downcase.split(/\W+/)
    matches = (content_words & emotional_words).length
    [matches.to_f / content_words.length * 10, 1.0].min
  end

  def count_power_words(content)
    power_words = %w[secret proven guaranteed instant ultimate exclusive limited breakthrough revolutionary]
    content_words = content.downcase.split(/\W+/)
    (content_words & power_words).length
  end

  def extract_strategy_from_text(text)
    strategy_keywords = {
      'headline' => 'headline_optimization',
      'question' => 'engagement_boost',
      'urgency' => 'urgency_optimization',
      'social proof' => 'social_proof_integration',
      'call' => 'cta_optimization'
    }
    
    strategy_keywords.each do |keyword, strategy|
      return strategy if text.downcase.include?(keyword)
    end
    
    'general_optimization'
  end

  def extract_confidence_from_text(text)
    if text.match?(/high|strong|significant/i)
      0.8
    elsif text.match?(/moderate|good|solid/i)
      0.6
    else
      0.4
    end
  end

  def extract_improvement_from_text(text)
    if text.match?/significant|dramatic|major/i
      'high'
    elsif text.match?/moderate|good|noticeable/i
      'moderate'
    else
      'low'
    end
  end

  def format_performance_context(data)
    context = ""
    if data[:top_performing_content]
      context += "Top performing content patterns: #{data[:top_performing_content].join(', ')}\n"
    end
    if data[:engagement_rates]
      context += "Average engagement rate: #{data[:engagement_rates][:average]}%\n"
    end
    context
  end

  def format_competitive_context(data)
    context = ""
    if data[:competitor_strengths]
      context += "Competitor strengths: #{data[:competitor_strengths].join(', ')}\n"
    end
    if data[:market_gaps]
      context += "Market opportunities: #{data[:market_gaps].join(', ')}\n"
    end
    context
  end

  def create_suggested_variants(content, context, analysis_result)
    suggestions = []
    
    # Create variants based on AI recommendations
    analysis_result[:ai_recommendations].each_with_index do |recommendation, index|
      suggestion = {
        id: "ai_suggestion_#{index + 1}",
        strategy: recommendation[:strategy],
        description: recommendation[:text],
        confidence: recommendation[:confidence],
        expected_improvement: recommendation[:expected_improvement]
      }
      
      suggestions << suggestion
    end
    
    # Add performance-based suggestions
    if analysis_result[:optimization_opportunities].any?
      analysis_result[:optimization_opportunities].each_with_index do |opportunity, index|
        suggestion = {
          id: "optimization_#{index + 1}",
          strategy: opportunity[:type],
          description: opportunity[:description],
          confidence: opportunity[:impact_score],
          expected_improvement: opportunity[:expected_result]
        }
        
        suggestions << suggestion
      end
    end
    
    suggestions
  end

  def identify_optimization_opportunities(content, context)
    opportunities = []
    
    # Analyze content for specific optimization opportunities
    content_analysis = analyze_content_deeply(content, context)
    
    # Length optimization
    if content.length < 50
      opportunities << {
        type: 'length_expansion',
        description: 'Content is too short - expand with more details and benefits',
        impact_score: 0.7,
        expected_result: 'moderate'
      }
    elsif content.length > 500 && context[:platform] == :twitter
      opportunities << {
        type: 'length_reduction',
        description: 'Content too long for Twitter - create concise version',
        impact_score: 0.8,
        expected_result: 'high'
      }
    end
    
    # Engagement optimization
    unless content.include?('?')
      opportunities << {
        type: 'engagement_boost',
        description: 'Add questions to increase audience interaction',
        impact_score: 0.6,
        expected_result: 'moderate'
      }
    end
    
    # CTA optimization
    unless has_strong_cta(content)
      opportunities << {
        type: 'cta_improvement',
        description: 'Add or strengthen call-to-action for better conversions',
        impact_score: 0.8,
        expected_result: 'high'
      }
    end
    
    opportunities
  end

  def calculate_expected_improvements(content, context)
    improvements = {
      engagement_rate: { baseline: 0.05, optimized: 0.08, improvement: '60%' },
      click_through_rate: { baseline: 0.02, optimized: 0.035, improvement: '75%' },
      conversion_rate: { baseline: 0.01, optimized: 0.018, improvement: '80%' }
    }
    
    # Adjust based on current content quality
    content_quality_score = calculate_overall_content_quality(content, context)
    
    improvements.each do |metric, data|
      quality_multiplier = 1.0 + (1.0 - content_quality_score) * 0.5
      data[:optimized] = data[:baseline] * quality_multiplier
      data[:improvement] = ((data[:optimized] - data[:baseline]) / data[:baseline] * 100).round.to_s + '%'
    end
    
    improvements
  end

  def calculate_overall_content_quality(content, context)
    scores = []
    
    scores << (has_strong_headline(content) ? 0.8 : 0.4)
    scores << (has_clear_value_proposition(content) ? 0.8 : 0.4)
    scores << (has_strong_cta(content) ? 0.8 : 0.4)
    scores << (has_engagement_elements(content) ? 0.7 : 0.3)
    scores << (poor_readability(content) ? 0.3 : 0.7)
    
    scores.sum / scores.length
  end
end