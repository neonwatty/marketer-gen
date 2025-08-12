# Service for generating A/B test variants of content with AI-powered suggestions
# Creates multiple versions of content for testing different approaches and optimizations
class VariantGeneratorService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Variant generation strategies and their configurations
  VARIANT_STRATEGIES = {
    tone_variation: {
      name: 'Tone Variation',
      description: 'Generate variants with different tones (professional, casual, friendly, urgent)',
      options: %w[professional casual friendly urgent persuasive authoritative conversational],
      effectiveness_score: 0.8
    },
    structure_variation: {
      name: 'Structure Variation',
      description: 'Vary content structure (question-first, benefit-first, story-driven)',
      options: %w[question_first benefit_first story_driven problem_solution list_format direct_approach],
      effectiveness_score: 0.7
    },
    cta_variation: {
      name: 'Call-to-Action Variation',
      description: 'Different call-to-action approaches and placements',
      options: %w[soft_cta strong_cta question_cta urgency_cta benefit_focused action_focused],
      effectiveness_score: 0.9
    },
    length_variation: {
      name: 'Length Variation',
      description: 'Generate shorter and longer versions of the content',
      options: %w[concise standard detailed expanded],
      effectiveness_score: 0.6
    },
    headline_variation: {
      name: 'Headline Variation',
      description: 'Different headline approaches and formulas',
      options: %w[curiosity_driven benefit_focused question_headline number_headline how_to emotional],
      effectiveness_score: 0.85
    },
    emotional_appeal: {
      name: 'Emotional Appeal',
      description: 'Vary emotional triggers and appeals',
      options: %w[fear_of_missing_out social_proof curiosity excitement trust security achievement],
      effectiveness_score: 0.75
    },
    format_variation: {
      name: 'Format Variation',
      description: 'Different content formats and presentations',
      options: %w[paragraph_form bullet_points numbered_list question_answer storytelling testimonial],
      effectiveness_score: 0.65
    },
    platform_optimization: {
      name: 'Platform Optimization',
      description: 'Optimize content specifically for different platforms',
      options: %w[social_optimized email_optimized ad_optimized blog_optimized mobile_optimized],
      effectiveness_score: 0.8
    }
  }.freeze

  # Performance prediction factors
  PERFORMANCE_FACTORS = {
    readability: {
      weight: 0.2,
      metrics: [:sentence_length, :word_complexity, :paragraph_structure]
    },
    engagement_potential: {
      weight: 0.25,
      metrics: [:question_count, :emotional_words, :call_to_action_strength]
    },
    clarity: {
      weight: 0.2,
      metrics: [:clear_benefit, :specific_language, :jargon_level]
    },
    persuasiveness: {
      weight: 0.15,
      metrics: [:social_proof, :urgency_indicators, :benefit_focus]
    },
    platform_fit: {
      weight: 0.2,
      metrics: [:length_appropriateness, :format_suitability, :platform_conventions]
    }
  }.freeze

  attr_accessor :ai_service, :original_content, :context, :platform, :target_audience

  def initialize(ai_service:, original_content:, context: {}, platform: nil, target_audience: nil)
    @ai_service = ai_service
    @original_content = original_content
    @context = context || {}
    @platform = platform
    @target_audience = target_audience
    validate_inputs!
  end

  # Generate multiple variants using different strategies
  def generate_variants(strategies: nil, variant_count: 3, options: {})
    strategies ||= select_optimal_strategies(variant_count)
    
    generation_result = {
      original_content: original_content,
      variants: [],
      strategy_analysis: {},
      performance_predictions: {},
      metadata: {
        generation_timestamp: Time.current.iso8601,
        platform: platform,
        target_audience: target_audience,
        strategies_used: strategies
      }
    }

    strategies.each_with_index do |strategy, index|
      variant_data = generate_single_variant(strategy, index + 1, options)
      generation_result[:variants] << variant_data
      generation_result[:strategy_analysis][strategy] = analyze_strategy_effectiveness(strategy, variant_data)
    end

    # Generate performance predictions for all variants
    generation_result[:performance_predictions] = predict_variant_performance(generation_result[:variants])
    
    # Rank variants by predicted performance
    generation_result[:variants] = rank_variants_by_performance(generation_result[:variants])

    generation_result
  end

  # Generate a single variant using a specific strategy
  def generate_single_variant(strategy, variant_number, options = {})
    strategy_config = VARIANT_STRATEGIES[strategy.to_sym]
    raise ArgumentError, "Unknown strategy: #{strategy}" unless strategy_config

    variant_data = {
      id: generate_variant_id(variant_number),
      strategy: strategy,
      strategy_name: strategy_config[:name],
      variant_number: variant_number,
      content: nil,
      generation_prompt: nil,
      performance_score: 0.0,
      metadata: {},
      differences_from_original: [],
      tags: [strategy.to_s]
    }

    # Build generation prompt
    generation_prompt = build_generation_prompt(strategy, strategy_config, options)
    variant_data[:generation_prompt] = generation_prompt

    # Generate content using AI service
    begin
      generated_response = ai_service.generate_content({
        prompt: generation_prompt,
        context: context.merge(
          original_content: original_content,
          strategy: strategy,
          platform: platform,
          target_audience: target_audience
        ),
        max_tokens: calculate_max_tokens(strategy),
        temperature: calculate_temperature(strategy)
      })

      variant_data[:content] = extract_content_from_response(generated_response)
      variant_data[:metadata] = extract_metadata_from_response(generated_response)
      
    rescue => e
      Rails.logger.error "Variant generation failed for strategy #{strategy}: #{e.message}"
      variant_data[:content] = generate_fallback_variant(strategy)
      variant_data[:error] = e.message
    end

    # Analyze differences from original
    variant_data[:differences_from_original] = analyze_content_differences(original_content, variant_data[:content])
    
    # Calculate performance score
    variant_data[:performance_score] = calculate_variant_performance_score(variant_data[:content], strategy)

    variant_data
  end

  # Generate variants based on historical performance data
  def generate_performance_based_variants(performance_data = {}, variant_count = 3)
    # Analyze what has worked well historically
    successful_patterns = analyze_performance_patterns(performance_data)
    
    # Select strategies based on what has been most effective
    optimal_strategies = select_strategies_from_performance(successful_patterns, variant_count)
    
    # Generate variants with performance-informed prompts
    generate_variants(
      strategies: optimal_strategies,
      variant_count: variant_count,
      options: { performance_informed: true, patterns: successful_patterns }
    )
  end

  # Generate variants optimized for specific goals
  def generate_goal_optimized_variants(goal, variant_count = 3)
    goal_strategies = {
      engagement: [:emotional_appeal, :tone_variation, :cta_variation],
      conversion: [:cta_variation, :headline_variation, :emotional_appeal],
      click_through: [:headline_variation, :curiosity_driven, :format_variation],
      brand_awareness: [:tone_variation, :emotional_appeal, :structure_variation],
      lead_generation: [:cta_variation, :benefit_focused, :urgency_cta]
    }

    strategies = goal_strategies[goal.to_sym] || goal_strategies[:engagement]
    selected_strategies = strategies.first(variant_count)

    generate_variants(
      strategies: selected_strategies,
      variant_count: variant_count,
      options: { optimization_goal: goal }
    )
  end

  # Quick variant generation for rapid testing
  def generate_quick_variants(count = 2)
    quick_strategies = [:tone_variation, :cta_variation]
    
    generate_variants(
      strategies: quick_strategies.first(count),
      variant_count: count,
      options: { quick_generation: true }
    )
  end

  # Analyze variant performance predictions
  def analyze_variant_predictions(variants)
    analysis = {
      highest_predicted_performance: nil,
      lowest_predicted_performance: nil,
      strategy_effectiveness: {},
      recommendation: nil,
      confidence_levels: {}
    }

    return analysis if variants.empty?

    # Find best and worst performing variants
    sorted_variants = variants.sort_by { |v| v[:performance_score] }.reverse
    analysis[:highest_predicted_performance] = sorted_variants.first
    analysis[:lowest_predicted_performance] = sorted_variants.last

    # Analyze strategy effectiveness
    strategy_scores = variants.group_by { |v| v[:strategy] }
                             .transform_values { |vs| vs.map { |v| v[:performance_score] }.sum / vs.length }
    
    analysis[:strategy_effectiveness] = strategy_scores.sort_by { |_, score| -score }.to_h

    # Generate recommendation
    analysis[:recommendation] = generate_testing_recommendation(sorted_variants)

    # Calculate confidence levels
    analysis[:confidence_levels] = calculate_prediction_confidence(variants)

    analysis
  end

  private

  def validate_inputs!
    raise ArgumentError, "AI service is required" unless ai_service
    raise ArgumentError, "Original content cannot be blank" if original_content.blank?
  end

  # Strategy selection and optimization
  def select_optimal_strategies(variant_count)
    # Default strategy selection based on effectiveness scores
    all_strategies = VARIANT_STRATEGIES.sort_by { |_, config| -config[:effectiveness_score] }
    
    selected = []
    
    # Always include high-impact strategies first
    high_impact = [:cta_variation, :headline_variation, :tone_variation]
    selected += high_impact.select { |s| VARIANT_STRATEGIES.key?(s) }
    
    # Fill remaining slots with next most effective strategies
    remaining_count = variant_count - selected.length
    if remaining_count > 0
      remaining_strategies = all_strategies.keys - selected
      selected += remaining_strategies.first(remaining_count)
    end

    selected.first(variant_count)
  end

  def select_strategies_from_performance(performance_patterns, variant_count)
    # Select strategies based on what has historically performed well
    strategy_effectiveness = performance_patterns[:strategy_effectiveness] || {}
    
    if strategy_effectiveness.empty?
      return select_optimal_strategies(variant_count)
    end

    # Sort strategies by historical effectiveness
    sorted_strategies = strategy_effectiveness.sort_by { |_, score| -score }.map(&:first)
    
    # Ensure we have enough strategies
    all_available = VARIANT_STRATEGIES.keys.map(&:to_s)
    needed_strategies = variant_count - sorted_strategies.length
    
    if needed_strategies > 0
      additional = (all_available - sorted_strategies).first(needed_strategies)
      sorted_strategies += additional
    end

    sorted_strategies.map(&:to_sym).first(variant_count)
  end

  # Prompt generation
  def build_generation_prompt(strategy, strategy_config, options)
    base_prompt = "Generate a variant of the following content using the #{strategy_config[:name]} strategy.\n\n"
    base_prompt += "Original content: #{original_content}\n\n"
    
    # Add strategy-specific instructions
    base_prompt += build_strategy_instructions(strategy, strategy_config, options)
    
    # Add context information
    base_prompt += build_context_instructions
    
    # Add constraints and requirements
    base_prompt += build_constraint_instructions
    
    base_prompt += "\nGenerate a complete, ready-to-use variant that maintains the core message while implementing the specified strategy."
    
    base_prompt
  end

  def build_strategy_instructions(strategy, strategy_config, options)
    instructions = "Strategy: #{strategy_config[:description]}\n"
    
    case strategy.to_sym
    when :tone_variation
      tone_option = strategy_config[:options].sample
      instructions += "Use a #{tone_option} tone throughout the content.\n"
    when :structure_variation
      structure_option = strategy_config[:options].sample
      instructions += "Restructure the content using a #{structure_option.humanize} approach.\n"
    when :cta_variation
      cta_option = strategy_config[:options].sample
      instructions += "Implement a #{cta_option.humanize} call-to-action approach.\n"
    when :length_variation
      length_option = strategy_config[:options].sample
      instructions += "Create a #{length_option} version of the content.\n"
    when :headline_variation
      headline_option = strategy_config[:options].sample
      instructions += "Use a #{headline_option.humanize} headline approach.\n"
    when :emotional_appeal
      emotion_option = strategy_config[:options].sample
      instructions += "Focus on #{emotion_option.humanize} as the primary emotional appeal.\n"
    when :format_variation
      format_option = strategy_config[:options].sample
      instructions += "Present the content in #{format_option.humanize} format.\n"
    when :platform_optimization
      platform_option = platform ? "#{platform}_optimized" : strategy_config[:options].sample
      instructions += "Optimize the content for #{platform_option.humanize} platform requirements.\n"
    end

    if options[:performance_informed] && options[:patterns]
      instructions += "\nConsider these successful patterns from historical data:\n"
      options[:patterns][:successful_elements]&.each do |element|
        instructions += "- #{element}\n"
      end
    end

    instructions += "\n"
  end

  def build_context_instructions
    instructions = ""
    
    if platform
      instructions += "Platform: #{platform.to_s.humanize}\n"
    end
    
    if target_audience
      instructions += "Target audience: #{target_audience}\n"
    end
    
    if context[:brand_context]
      instructions += "Brand context: #{context[:brand_context]}\n"
    end
    
    if context[:campaign_goal]
      instructions += "Campaign goal: #{context[:campaign_goal]}\n"
    end
    
    instructions += "\n" unless instructions.empty?
  end

  def build_constraint_instructions
    instructions = "Requirements:\n"
    instructions += "- Maintain the core message and key information\n"
    instructions += "- Ensure the variant is clearly different from the original\n"
    instructions += "- Keep the content appropriate for the target audience\n"
    
    if platform
      case platform.to_sym
      when :twitter
        instructions += "- Stay within Twitter's character limits\n"
      when :instagram
        instructions += "- Include relevant hashtags for Instagram\n"
      when :linkedin
        instructions += "- Maintain professional tone suitable for LinkedIn\n"
      when :email
        instructions += "- Include clear subject line and call-to-action\n"
      end
    end
    
    instructions += "\n"
  end

  # Content generation utilities
  def calculate_max_tokens(strategy)
    base_tokens = 500
    
    case strategy.to_sym
    when :length_variation
      800 # May need more tokens for expanded content
    when :structure_variation
      600 # Structure changes may require more content
    else
      base_tokens
    end
  end

  def calculate_temperature(strategy)
    case strategy.to_sym
    when :tone_variation, :emotional_appeal
      0.8 # Higher creativity for tone and emotion
    when :structure_variation, :format_variation
      0.7 # Moderate creativity for structural changes
    when :cta_variation, :headline_variation
      0.6 # More focused for specific elements
    else
      0.7 # Default moderate creativity
    end
  end

  def extract_content_from_response(response)
    if response.is_a?(Hash)
      response[:content] || response['content'] || response.to_s
    else
      response.to_s
    end
  end

  def extract_metadata_from_response(response)
    if response.is_a?(Hash)
      response.except(:content, 'content')
    else
      {}
    end
  end

  def generate_fallback_variant(strategy)
    case strategy.to_sym
    when :tone_variation
      original_content.gsub(/\./, '!').gsub(/\b(good|great)\b/i, 'amazing')
    when :cta_variation
      original_content + " Take action now!"
    when :length_variation
      sentences = original_content.split(/[.!?]+/)
      sentences.first(2).join('. ') + '.'
    else
      # Simple modification as fallback
      original_content.gsub(/\b(the|a|an)\b/i, '').strip
    end
  end

  # Content analysis
  def analyze_content_differences(original, variant)
    differences = []
    
    # Length difference
    length_diff = variant.length - original.length
    if length_diff.abs > 50
      differences << {
        type: 'length',
        description: length_diff > 0 ? "#{length_diff} characters longer" : "#{length_diff.abs} characters shorter"
      }
    end

    # Tone difference
    if analyze_tone(original) != analyze_tone(variant)
      differences << {
        type: 'tone',
        description: "Tone changed from #{analyze_tone(original)} to #{analyze_tone(variant)}"
      }
    end

    # Structure difference
    original_structure = analyze_structure(original)
    variant_structure = analyze_structure(variant)
    if original_structure != variant_structure
      differences << {
        type: 'structure',
        description: "Structure changed from #{original_structure} to #{variant_structure}"
      }
    end

    # CTA difference
    original_cta = extract_cta(original)
    variant_cta = extract_cta(variant)
    if original_cta != variant_cta
      differences << {
        type: 'call_to_action',
        description: "CTA changed: '#{original_cta}' → '#{variant_cta}'"
      }
    end

    differences
  end

  def analyze_tone(content)
    # Simple tone analysis based on keywords and patterns
    professional_indicators = %w[professional expertise experience solution quality]
    casual_indicators = %w[hey cool awesome great fun easy]
    urgent_indicators = %w[now urgent immediately limited time act fast]
    
    content_words = content.downcase.split(/\W+/)
    
    professional_score = (content_words & professional_indicators).length
    casual_score = (content_words & casual_indicators).length
    urgent_score = (content_words & urgent_indicators).length
    
    scores = { professional: professional_score, casual: casual_score, urgent: urgent_score }
    scores.max_by { |_, score| score }&.first || :neutral
  end

  def analyze_structure(content)
    sentences = content.split(/[.!?]+/).map(&:strip).reject(&:blank?)
    return :single_sentence if sentences.length <= 1
    
    first_sentence = sentences.first
    
    case
    when first_sentence.include?('?')
      :question_first
    when first_sentence.match?(/benefit|advantage|save|gain|improve/i)
      :benefit_first
    when first_sentence.match?(/imagine|picture|story|once/i)
      :story_driven
    when sentences.length > 3 && sentences.any? { |s| s.match?(/first|second|third|1\.|2\.|3\./i) }
      :list_format
    else
      :direct_approach
    end
  end

  def extract_cta(content)
    cta_patterns = [
      /\b(learn more|get started|sign up|contact us|buy now|shop now|discover|try now)\b/i,
      /\b(call|click|visit|download|subscribe|join)\b/i,
      /\b(act now|don't wait|limited time|hurry)\b/i
    ]
    
    cta_patterns.each do |pattern|
      match = content.match(pattern)
      return match.to_s if match
    end
    
    'No clear CTA'
  end

  # Performance prediction
  def calculate_variant_performance_score(content, strategy)
    base_score = 0.5
    
    # Factor in strategy effectiveness
    strategy_config = VARIANT_STRATEGIES[strategy.to_sym]
    base_score += strategy_config[:effectiveness_score] * 0.3 if strategy_config
    
    # Analyze content factors
    PERFORMANCE_FACTORS.each do |factor, config|
      factor_score = calculate_factor_score(content, factor, config[:metrics])
      base_score += factor_score * config[:weight]
    end
    
    # Platform-specific adjustments
    if platform
      platform_score = calculate_platform_fit_score(content, platform)
      base_score += platform_score * 0.1
    end
    
    # Ensure score stays within bounds
    [[base_score, 0.0].max, 1.0].min
  end

  def calculate_factor_score(content, factor, metrics)
    case factor
    when :readability
      calculate_readability_score(content)
    when :engagement_potential
      calculate_engagement_score(content)
    when :clarity
      calculate_clarity_score(content)
    when :persuasiveness
      calculate_persuasiveness_score(content)
    when :platform_fit
      calculate_platform_fit_score(content, platform)
    else
      0.5 # Default neutral score
    end
  end

  def calculate_readability_score(content)
    sentences = content.split(/[.!?]+/).reject(&:blank?)
    words = content.split(/\W+/).reject(&:blank?)
    
    return 0.3 if sentences.empty? || words.empty?
    
    avg_sentence_length = words.length.to_f / sentences.length
    avg_word_length = content.length.to_f / words.length
    
    # Ideal: 15-20 words per sentence, 4-6 characters per word
    sentence_score = 1.0 - [(avg_sentence_length - 17.5).abs / 17.5, 1.0].min
    word_score = 1.0 - [(avg_word_length - 5.0).abs / 5.0, 1.0].min
    
    (sentence_score + word_score) / 2
  end

  def calculate_engagement_score(content)
    engagement_elements = 0
    
    # Questions increase engagement
    engagement_elements += content.scan(/\?/).length * 0.2
    
    # Emotional words
    emotional_words = %w[amazing incredible fantastic love hate exciting thrilling wonderful terrible]
    content_words = content.downcase.split(/\W+/)
    engagement_elements += (content_words & emotional_words).length * 0.1
    
    # Call-to-action presence
    if extract_cta(content) != 'No clear CTA'
      engagement_elements += 0.3
    end
    
    # Personal pronouns (you, your, we, us)
    personal_pronouns = %w[you your we us our]
    engagement_elements += (content_words & personal_pronouns).length * 0.05
    
    [engagement_elements, 1.0].min
  end

  def calculate_clarity_score(content)
    clarity_score = 0.5
    
    # Clear benefit statements
    benefit_words = %w[benefit advantage save gain improve increase reduce help solve]
    content_words = content.downcase.split(/\W+/)
    if (content_words & benefit_words).any?
      clarity_score += 0.2
    end
    
    # Specific vs. vague language
    specific_indicators = /\d+%|\$\d+|\d+ times|exactly|specifically|precisely/
    if content.match?(specific_indicators)
      clarity_score += 0.2
    end
    
    # Jargon penalty
    jargon_words = %w[synergy leverage paradigm optimize maximize utilize methodology]
    jargon_count = (content_words & jargon_words).length
    clarity_score -= jargon_count * 0.1
    
    [clarity_score, 1.0].min
  end

  def calculate_persuasiveness_score(content)
    persuasion_score = 0.3
    
    # Social proof indicators
    social_proof = %w[customers clients users testimonial review rating thousand million]
    content_words = content.downcase.split(/\W+/)
    if (content_words & social_proof).any?
      persuasion_score += 0.25
    end
    
    # Urgency indicators
    urgency_words = %w[now today limited hurry deadline expires soon]
    if (content_words & urgency_words).any?
      persuasion_score += 0.2
    end
    
    # Benefit-focused language
    benefit_focus = %w[get receive achieve gain save earn improve]
    persuasion_score += [(content_words & benefit_focus).length * 0.05, 0.25].min
    
    [persuasion_score, 1.0].min
  end

  def calculate_platform_fit_score(content, platform_name)
    return 0.5 unless platform_name
    
    case platform_name.to_sym
    when :twitter
      # Twitter favors concise, engaging content
      score = content.length <= 280 ? 0.8 : 0.3
      score += content.include?('#') ? 0.1 : 0
      score += content.include?('@') ? 0.1 : 0
    when :linkedin
      # LinkedIn favors professional, detailed content
      score = content.length >= 100 ? 0.7 : 0.4
      professional_words = %w[professional business industry expertise experience]
      content_words = content.downcase.split(/\W+/)
      score += (content_words & professional_words).any? ? 0.2 : 0
      score += content.include?('#') ? 0.1 : 0
    when :instagram
      # Instagram favors visual, lifestyle content with hashtags
      score = 0.6
      score += content.scan(/#\w+/).length >= 3 ? 0.3 : 0
      score += content.match?(/visual|photo|image|picture/i) ? 0.1 : 0
    when :email
      # Email favors clear subject and strong CTA
      score = 0.6
      score += extract_cta(content) != 'No clear CTA' ? 0.3 : 0
      score += content.length >= 50 ? 0.1 : 0
    else
      score = 0.5
    end
    
    [score, 1.0].min
  end

  # Variant management
  def predict_variant_performance(variants)
    predictions = {}
    
    variants.each do |variant|
      predictions[variant[:id]] = {
        overall_score: variant[:performance_score],
        confidence: calculate_prediction_confidence([variant]),
        expected_metrics: predict_specific_metrics(variant),
        recommendation: generate_variant_recommendation(variant)
      }
    end
    
    predictions
  end

  def predict_specific_metrics(variant)
    base_ctr = 0.02 # 2% base click-through rate
    base_engagement = 0.05 # 5% base engagement rate
    base_conversion = 0.01 # 1% base conversion rate
    
    performance_multiplier = variant[:performance_score]
    
    {
      estimated_ctr: (base_ctr * performance_multiplier).round(4),
      estimated_engagement_rate: (base_engagement * performance_multiplier).round(4),
      estimated_conversion_rate: (base_conversion * performance_multiplier).round(4),
      confidence_interval: calculate_confidence_interval(performance_multiplier)
    }
  end

  def calculate_confidence_interval(score)
    margin = 0.1 * (1 - score) # Lower confidence for lower scores
    {
      lower: [score - margin, 0.0].max,
      upper: [score + margin, 1.0].min
    }
  end

  def rank_variants_by_performance(variants)
    variants.sort_by { |variant| -variant[:performance_score] }
  end

  def generate_variant_recommendation(variant)
    score = variant[:performance_score]
    strategy = variant[:strategy]
    
    case
    when score >= 0.8
      "High potential variant. Recommend for primary A/B test."
    when score >= 0.6
      "Good potential. Consider for testing against control."
    when score >= 0.4
      "Moderate potential. May work for specific audiences."
    else
      "Lower predicted performance. Consider revising strategy."
    end
  end

  def generate_testing_recommendation(ranked_variants)
    return "No variants to analyze" if ranked_variants.empty?
    
    top_variant = ranked_variants.first
    score_diff = ranked_variants.length > 1 ? 
      top_variant[:performance_score] - ranked_variants[1][:performance_score] : 0
    
    if score_diff > 0.2
      "Strong favorite: Test #{top_variant[:strategy_name]} variant against control"
    elsif ranked_variants.length >= 2
      "Close competition: Run A/B/C test with top 2-3 variants"
    else
      "Single variant testing: Compare #{top_variant[:strategy_name]} against control"
    end
  end

  def calculate_prediction_confidence(variants)
    return {} if variants.empty?
    
    scores = variants.map { |v| v[:performance_score] }
    avg_score = scores.sum / scores.length
    score_variance = scores.map { |s| (s - avg_score) ** 2 }.sum / scores.length
    
    {
      average_confidence: avg_score,
      prediction_stability: 1.0 - [score_variance, 1.0].min,
      recommendation_strength: avg_score > 0.7 ? 'high' : avg_score > 0.5 ? 'medium' : 'low'
    }
  end

  # Performance pattern analysis
  def analyze_performance_patterns(performance_data)
    patterns = {
      successful_elements: [],
      effective_strategies: {},
      audience_preferences: {},
      platform_insights: {},
      optimal_timing: {}
    }

    return patterns if performance_data.empty?

    # Analyze successful content elements
    if performance_data[:high_performing_content]
      patterns[:successful_elements] = extract_common_elements(performance_data[:high_performing_content])
    end

    # Analyze strategy effectiveness
    if performance_data[:strategy_performance]
      patterns[:effective_strategies] = performance_data[:strategy_performance]
                                       .sort_by { |_, metrics| -(metrics[:engagement_rate] || 0) }
                                       .to_h
    end

    # Analyze audience preferences
    if performance_data[:audience_segments]
      patterns[:audience_preferences] = analyze_audience_performance(performance_data[:audience_segments])
    end

    patterns
  end

  def extract_common_elements(high_performing_content)
    elements = []
    
    high_performing_content.each do |content|
      # Extract successful patterns
      elements << "Questions engage audience" if content.include?('?')
      elements << "Numbers add credibility" if content.match?(/\d+/)
      elements << "Strong CTAs drive action" if extract_cta(content) != 'No clear CTA'
      elements << "Personal pronouns increase connection" if content.match?/\b(you|your|we|us)\b/i
    end
    
    elements.tally.select { |_, count| count >= 2 }.keys
  end

  def analyze_audience_performance(audience_segments)
    preferences = {}
    
    audience_segments.each do |segment, data|
      preferences[segment] = {
        preferred_tone: extract_preferred_tone(data),
        optimal_length: extract_optimal_length(data),
        best_cta_type: extract_best_cta_type(data)
      }
    end
    
    preferences
  end

  def extract_preferred_tone(segment_data)
    tone_performance = segment_data[:tone_performance] || {}
    tone_performance.max_by { |_, score| score }&.first || :professional
  end

  def extract_optimal_length(segment_data)
    length_performance = segment_data[:length_performance] || {}
    length_performance.max_by { |_, score| score }&.first || :medium
  end

  def extract_best_cta_type(segment_data)
    cta_performance = segment_data[:cta_performance] || {}
    cta_performance.max_by { |_, score| score }&.first || :standard
  end

  # Utility methods
  def generate_variant_id(variant_number)
    "variant_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{variant_number}"
  end
end