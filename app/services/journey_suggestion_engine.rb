class JourneySuggestionEngine
  # AI providers configuration
  PROVIDERS = {
    openai: {
      api_url: 'https://api.openai.com/v1/chat/completions',
      model: 'gpt-4-turbo-preview',
      headers: ->(api_key) { { 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json' } }
    },
    anthropic: {
      api_url: 'https://api.anthropic.com/v1/messages',
      model: 'claude-3-sonnet-20240229',
      headers: ->(api_key) { { 'x-api-key' => api_key, 'Content-Type' => 'application/json', 'anthropic-version' => '2023-06-01' } }
    }
  }.freeze

  FEEDBACK_TYPES = %w[suggestion_quality relevance usefulness timing channel_fit].freeze
  CACHE_TTL = 1.hour

  attr_reader :journey, :user, :current_step, :provider

  def initialize(journey:, user:, current_step: nil, provider: :openai)
    @journey = journey
    @user = user
    @current_step = current_step
    @provider = provider.to_sym
    @http_client = build_http_client
  end

  # Main method to generate contextual suggestions for the next journey step
  def generate_suggestions(filters = {})
    cache_key = build_cache_key(filters)
    
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      context = build_journey_context
      suggestions = fetch_ai_suggestions(context, filters)
      ranked_suggestions = rank_suggestions(suggestions, context)
      
      store_journey_insights(ranked_suggestions, context)
      
      ranked_suggestions
    end
  end

  # Generate suggestions for specific stage and context
  def suggest_for_stage(stage, filters = {})
    context = build_stage_context(stage)
    suggestions = fetch_ai_suggestions(context, filters.merge(stage: stage))
    rank_suggestions(suggestions, context)
  end

  # Record user feedback on suggestions for learning
  def record_feedback(suggested_step_data, feedback_type, rating: nil, selected: false, context: nil)
    return unless FEEDBACK_TYPES.include?(feedback_type)
    
    SuggestionFeedback.create!(
      journey: journey,
      journey_step: current_step,
      suggested_step_id: suggested_step_data[:id],
      user: user,
      feedback_type: feedback_type,
      rating: rating,
      selected: selected,
      context: context,
      metadata: {
        suggested_step_data: suggested_step_data,
        timestamp: Time.current,
        provider: provider
      }
    )
  end

  # Get historical feedback for learning algorithm
  def get_feedback_insights
    journey.suggestion_feedbacks
           .joins(:journey_step)
           .group(:feedback_type)
           .average(:rating)
  end

  private

  def build_http_client
    Faraday.new do |faraday|
      faraday.request :json
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter Faraday.default_adapter
      faraday.request :retry, max: 3, interval: 0.5
    end
  end

  def build_journey_context
    base_context = {
      journey: {
        name: journey.name,
        description: journey.description,
        campaign_type: journey.campaign_type,
        target_audience: journey.target_audience,
        goals: journey.goals,
        current_status: journey.status,
        total_steps: journey.total_steps,
        stages_coverage: journey.steps_by_stage
      },
      current_step: current_step&.as_json(
        only: [:name, :description, :stage, :content_type, :channel, :duration_days],
        include: { next_steps: { only: [:name, :stage, :content_type] } }
      ),
      existing_steps: journey.journey_steps.by_position.map do |step|
        {
          name: step.name,
          stage: step.stage,
          content_type: step.content_type,
          channel: step.channel,
          position: step.position
        }
      end,
      user_preferences: extract_user_preferences,
      historical_performance: get_historical_performance,
      industry_best_practices: get_best_practices_for_campaign_type
    }
    
    # Add brand context if journey has an associated brand
    if journey.brand_id.present?
      base_context[:brand] = extract_brand_context
    end
    
    base_context
  end

  def build_stage_context(stage)
    build_journey_context.merge(
      target_stage: stage,
      stage_gaps: identify_stage_gaps(stage),
      stage_performance: get_stage_performance(stage)
    )
  end

  def fetch_ai_suggestions(context, filters)
    prompt = build_suggestion_prompt(context, filters)
    
    raw_suggestions = case provider
    when :openai
      fetch_openai_suggestions(prompt)
    when :anthropic
      fetch_anthropic_suggestions(prompt)
    else
      raise ArgumentError, "Unsupported provider: #{provider}"
    end
    
    # Apply brand guideline filtering if brand context is available
    if context[:brand].present?
      filter_suggestions_by_brand_guidelines(raw_suggestions, context[:brand])
    else
      raw_suggestions
    end
  rescue => e
    Rails.logger.error "AI suggestion generation failed: #{e.message}"
    generate_fallback_suggestions(context, filters)
  end

  def build_suggestion_prompt(context, filters)
    base_prompt = <<~PROMPT
      You are an expert marketing journey strategist. Based on the following journey context, 
      suggest 3-5 highly relevant next steps that would optimize the customer journey.

      Journey Context:
      #{context.to_json}

      Filters Applied:
      #{filters.to_json}

      Please provide suggestions in the following JSON format:
      {
        "suggestions": [
          {
            "name": "Step name",
            "description": "Detailed description",
            "stage": "awareness|consideration|conversion|retention|advocacy",
            "content_type": "email|blog_post|social_post|landing_page|video|webinar|etc",
            "channel": "email|website|facebook|instagram|etc",
            "duration_days": 1-30,
            "reasoning": "Why this step would be effective",
            "confidence_score": 0.0-1.0,
            "expected_impact": "high|medium|low",
            "priority": 1-5,
            "best_practices": ["practice1", "practice2"],
            "success_metrics": ["metric1", "metric2"],
            "brand_compliance_score": 0.0-1.0
          }
        ]
      }

      Focus on:
      1. Logical progression from current step
      2. Addressing gaps in the journey stages
      3. Optimizing for the stated goals
      4. Leveraging successful patterns from similar campaigns
      5. Considering target audience preferences
    PROMPT

    # Add brand-specific guidelines if available
    if context[:brand].present?
      base_prompt += <<~BRAND_CONTEXT

        BRAND COMPLIANCE REQUIREMENTS:
        #{format_brand_guidelines_for_prompt(context[:brand])}

        IMPORTANT: All suggestions must strictly adhere to brand guidelines. 
        Include a brand_compliance_score (0.0-1.0) for each suggestion indicating 
        how well it aligns with the brand voice, messaging, and visual guidelines.
      BRAND_CONTEXT
    end

    if filters[:stage]
      base_prompt += "\n\nSpecial focus: Generate suggestions specifically for the '#{filters[:stage]}' stage."
    end

    if filters[:content_type]
      base_prompt += "\n\nContent preference: Prioritize '#{filters[:content_type]}' content types."
    end

    if filters[:channel]
      base_prompt += "\n\nChannel preference: Focus on '#{filters[:channel]}' channel opportunities."
    end

    base_prompt
  end

  def fetch_openai_suggestions(prompt)
    config = PROVIDERS[:openai]
    api_key = Rails.application.credentials.openai_api_key
    
    return generate_fallback_suggestions({}, {}) unless api_key

    response = @http_client.post(config[:api_url]) do |req|
      req.headers.merge!(config[:headers].call(api_key))
      req.body = {
        model: config[:model],
        messages: [
          { role: 'system', content: 'You are a marketing journey optimization expert.' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 2000
      }
    end

    if response.success?
      content = response.body.dig('choices', 0, 'message', 'content')
      JSON.parse(content)['suggestions']
    else
      Rails.logger.error "OpenAI API error: #{response.body}"
      generate_fallback_suggestions({}, {})
    end
  end

  def fetch_anthropic_suggestions(prompt)
    config = PROVIDERS[:anthropic]
    api_key = Rails.application.credentials.anthropic_api_key
    
    return generate_fallback_suggestions({}, {}) unless api_key

    response = @http_client.post(config[:api_url]) do |req|
      req.headers.merge!(config[:headers].call(api_key))
      req.body = {
        model: config[:model],
        max_tokens: 2000,
        messages: [
          { role: 'user', content: prompt }
        ]
      }
    end

    if response.success?
      content = response.body.dig('content', 0, 'text')
      JSON.parse(content)['suggestions']
    else
      Rails.logger.error "Anthropic API error: #{response.body}"
      generate_fallback_suggestions({}, {})
    end
  end

  def rank_suggestions(suggestions, context)
    return suggestions unless suggestions.is_a?(Array)

    # Apply learning algorithm based on historical feedback
    feedback_insights = get_feedback_insights
    
    suggestions.map do |suggestion|
      base_score = suggestion['confidence_score'] || 0.5
      
      # Adjust score based on historical feedback
      feedback_adjustment = calculate_feedback_adjustment(suggestion, feedback_insights)
      
      # Adjust for journey completeness
      completeness_adjustment = calculate_completeness_adjustment(suggestion, context)
      
      # Adjust for user preferences
      preference_adjustment = calculate_preference_adjustment(suggestion, context)
      
      # Adjust for brand compliance if brand context is available
      brand_adjustment = context[:brand].present? ? 
        calculate_brand_compliance_adjustment(suggestion, context[:brand]) : 0.0
      
      final_score = [
        base_score + feedback_adjustment + completeness_adjustment + preference_adjustment + brand_adjustment,
        1.0
      ].min

      suggestion.merge(
        'calculated_score' => final_score,
        'ranking_factors' => {
          'base_confidence' => base_score,
          'feedback_adjustment' => feedback_adjustment,
          'completeness_adjustment' => completeness_adjustment,
          'preference_adjustment' => preference_adjustment,
          'brand_compliance_adjustment' => brand_adjustment
        }
      )
    end.sort_by { |s| -s['calculated_score'] }
  end

  def calculate_feedback_adjustment(suggestion, feedback_insights)
    # Weight suggestions based on historical feedback for similar content types and stages
    content_type_rating = feedback_insights["#{suggestion['content_type']}_rating"] || 3.0
    stage_rating = feedback_insights["#{suggestion['stage']}_rating"] || 3.0
    
    # Convert 1-5 rating to -0.2 to +0.2 adjustment
    ((content_type_rating + stage_rating) / 2 - 3.0) * 0.1
  end

  def calculate_completeness_adjustment(suggestion, context)
    # Favor suggestions that fill gaps in the journey
    existing_stages = context[:journey][:stages_coverage].keys
    suggested_stage = suggestion['stage']
    
    # Boost score if this stage is underrepresented
    stage_count = context[:journey][:stages_coverage][suggested_stage] || 0
    total_steps = context[:journey][:total_steps] || 1
    
    if stage_count < (total_steps / 5.0) # If stage has less than 20% representation
      0.15
    elsif stage_count == 0 # If stage is completely missing
      0.25
    else
      0.0
    end
  end

  def calculate_preference_adjustment(suggestion, context)
    # Adjust based on user's historical preferences and journey goals
    user_prefs = context[:user_preferences]
    
    adjustment = 0.0
    
    # Favor preferred content types
    if user_prefs[:preferred_content_types]&.include?(suggestion['content_type'])
      adjustment += 0.1
    end
    
    # Favor preferred channels
    if user_prefs[:preferred_channels]&.include?(suggestion['channel'])
      adjustment += 0.1
    end
    
    adjustment
  end

  def generate_fallback_suggestions(context, filters)
    # Fallback suggestions based on common patterns and templates
    stage = filters[:stage] || detect_next_logical_stage
    
    case stage
    when 'awareness'
      generate_awareness_suggestions
    when 'consideration'
      generate_consideration_suggestions
    when 'conversion'
      generate_conversion_suggestions
    when 'retention'
      generate_retention_suggestions
    when 'advocacy'
      generate_advocacy_suggestions
    else
      generate_general_suggestions
    end
  end

  def detect_next_logical_stage
    return 'awareness' unless current_step
    
    stage_progression = %w[awareness consideration conversion retention advocacy]
    current_stage_index = stage_progression.index(current_step.stage) || 0
    
    # Move to next stage or stay in current if it's the last one
    stage_progression[current_stage_index + 1] || current_step.stage
  end

  def generate_awareness_suggestions
    [
      {
        'name' => 'Educational Blog Post',
        'description' => 'Create valuable content that addresses target audience pain points',
        'stage' => 'awareness',
        'content_type' => 'blog_post',
        'channel' => 'website',
        'duration_days' => 7,
        'reasoning' => 'Blog content drives organic traffic and establishes thought leadership',
        'confidence_score' => 0.8,
        'calculated_score' => 0.8
      },
      {
        'name' => 'Social Media Campaign',
        'description' => 'Engaging social content to increase brand visibility',
        'stage' => 'awareness',
        'content_type' => 'social_post',
        'channel' => 'facebook',
        'duration_days' => 3,
        'reasoning' => 'Social media expands reach and engagement with target audience',
        'confidence_score' => 0.75,
        'calculated_score' => 0.75
      }
    ]
  end

  def generate_consideration_suggestions
    [
      {
        'name' => 'Product Demo Video',
        'description' => 'Showcase product features and benefits through video demonstration',
        'stage' => 'consideration',
        'content_type' => 'video',
        'channel' => 'website',
        'duration_days' => 5,
        'reasoning' => 'Video content helps prospects understand product value proposition',
        'confidence_score' => 0.85,
        'calculated_score' => 0.85
      },
      {
        'name' => 'Comparison Guide',
        'description' => 'Detailed comparison of solutions to help decision making',
        'stage' => 'consideration',
        'content_type' => 'ebook',
        'channel' => 'email',
        'duration_days' => 7,
        'reasoning' => 'Comparison content addresses evaluation criteria concerns',
        'confidence_score' => 0.8,
        'calculated_score' => 0.8
      }
    ]
  end

  def generate_conversion_suggestions
    [
      {
        'name' => 'Limited Time Offer',
        'description' => 'Time-sensitive promotion to encourage immediate action',
        'stage' => 'conversion',
        'content_type' => 'email',
        'channel' => 'email',
        'duration_days' => 3,
        'reasoning' => 'Urgency and scarcity drive conversion behavior',
        'confidence_score' => 0.9,
        'calculated_score' => 0.9
      },
      {
        'name' => 'Free Trial Landing Page',
        'description' => 'Dedicated page optimized for trial sign-ups',
        'stage' => 'conversion',
        'content_type' => 'landing_page',
        'channel' => 'website',
        'duration_days' => 1,
        'reasoning' => 'Reduces friction and focuses on conversion goal',
        'confidence_score' => 0.85,
        'calculated_score' => 0.85
      }
    ]
  end

  def generate_retention_suggestions
    [
      {
        'name' => 'Onboarding Email Series',
        'description' => 'Multi-part email series to guide new customers',
        'stage' => 'retention',
        'content_type' => 'email',
        'channel' => 'email',
        'duration_days' => 14,
        'reasoning' => 'Proper onboarding increases customer lifetime value',
        'confidence_score' => 0.9,
        'calculated_score' => 0.9
      }
    ]
  end

  def generate_advocacy_suggestions
    [
      {
        'name' => 'Customer Success Story',
        'description' => 'Showcase customer achievements and testimonials',
        'stage' => 'advocacy',
        'content_type' => 'case_study',
        'channel' => 'website',
        'duration_days' => 7,
        'reasoning' => 'Success stories build credibility and encourage referrals',
        'confidence_score' => 0.85,
        'calculated_score' => 0.85
      }
    ]
  end

  def generate_general_suggestions
    [
      {
        'name' => 'Welcome Email',
        'description' => 'Introductory email to new subscribers or customers',
        'stage' => 'awareness',
        'content_type' => 'email',
        'channel' => 'email',
        'duration_days' => 1,
        'reasoning' => 'Sets expectations and begins relationship building',
        'confidence_score' => 0.7,
        'calculated_score' => 0.7
      }
    ]
  end

  def extract_user_preferences
    # Analyze user's historical journey patterns
    user_journeys = user.journeys.published
    
    {
      preferred_content_types: calculate_preferred_content_types(user_journeys),
      preferred_channels: calculate_preferred_channels(user_journeys),
      avg_journey_length: calculate_avg_journey_length(user_journeys),
      successful_patterns: identify_successful_patterns(user_journeys)
    }
  end

  def calculate_preferred_content_types(journeys)
    journeys.joins(:journey_steps)
            .group('journey_steps.content_type')
            .count
            .sort_by { |_, count| -count }
            .first(3)
            .map(&:first)
            .compact
  end

  def calculate_preferred_channels(journeys)
    journeys.joins(:journey_steps)
            .group('journey_steps.channel')
            .count
            .sort_by { |_, count| -count }
            .first(3)
            .map(&:first)
            .compact
  end

  def calculate_avg_journey_length(journeys)
    return 0 if journeys.empty?
    
    journeys.joins(:journey_steps).group(:id).count.values.sum.to_f / journeys.count
  end

  def identify_successful_patterns(journeys)
    # This would analyze successful journeys based on execution data
    # For now, return empty hash - to be implemented with analytics
    {}
  end

  def get_historical_performance
    # Analyze performance of similar journey steps
    # This would integrate with analytics data
    {}
  end

  def get_best_practices_for_campaign_type
    # Return best practices based on campaign type from templates
    return {} unless journey.campaign_type

    template = JourneyTemplate.where(campaign_type: journey.campaign_type)
                             .order(usage_count: :desc)
                             .first
    
    template&.best_practices || {}
  end

  def identify_stage_gaps(target_stage)
    existing_stages = journey.journey_steps.pluck(:stage).uniq
    all_stages = Journey::STAGES
    
    all_stages - existing_stages
  end

  def get_stage_performance(stage)
    # Analyze performance of steps in this stage
    # This would integrate with analytics data
    {}
  end

  def store_journey_insights(suggestions, context)
    JourneyInsight.create!(
      journey: journey,
      insights_type: 'ai_suggestions',
      data: {
        suggestions: suggestions,
        context_summary: {
          total_steps: context[:journey][:total_steps],
          stages_coverage: context[:journey][:stages_coverage],
          provider: provider
        },
        generated_at: Time.current
      },
      calculated_at: Time.current,
      expires_at: 24.hours.from_now,
      metadata: {
        provider: provider,
        user_id: user.id,
        current_step_id: current_step&.id
      }
    )
  end

  def build_cache_key(filters)
    key_parts = [
      "journey_suggestions",
      journey.id,
      journey.updated_at.to_i,
      current_step&.id,
      user.id,
      provider,
      Digest::MD5.hexdigest(filters.to_json)
    ]
    
    # Include brand context in cache key if available
    if journey.brand_id.present?
      key_parts << journey.brand_id
      key_parts << journey.brand.updated_at.to_i
    end
    
    key_parts.join(":")
  end
  
  # Brand-related helper methods
  def extract_brand_context
    brand = journey.brand
    return {} unless brand
    
    {
      id: brand.id,
      name: brand.name,
      industry: brand.industry,
      brand_voice: extract_brand_voice(brand),
      messaging_framework: extract_messaging_framework(brand),
      guidelines: extract_brand_guidelines(brand),
      color_scheme: brand.color_scheme || {},
      typography: brand.typography || {},
      visual_identity: extract_visual_identity(brand)
    }
  end
  
  def extract_brand_voice(brand)
    voice_data = brand.brand_voice_attributes || {}
    latest_analysis = brand.latest_analysis
    
    if latest_analysis&.voice_attributes.present?
      voice_data.merge(latest_analysis.voice_attributes)
    else
      voice_data
    end
  end
  
  def extract_messaging_framework(brand)
    framework = brand.messaging_framework
    return {} unless framework
    
    {
      key_messages: framework.key_messages || {},
      value_propositions: framework.value_propositions || {},
      approved_phrases: framework.approved_phrases || [],
      banned_words: framework.banned_words || [],
      tone_attributes: framework.tone_attributes || {}
    }
  end
  
  def extract_brand_guidelines(brand)
    guidelines = brand.brand_guidelines.active.order(priority: :desc).limit(10)
    
    guidelines.map do |guideline|
      {
        category: guideline.category,
        rule_type: guideline.rule_type,
        rule_text: guideline.rule_text,
        priority: guideline.priority,
        compliance_level: guideline.compliance_level
      }
    end
  end
  
  def extract_visual_identity(brand)
    {
      primary_colors: brand.primary_colors,
      secondary_colors: brand.secondary_colors,
      font_families: brand.font_families,
      has_brand_assets: brand.has_complete_brand_assets?
    }
  end
  
  def format_brand_guidelines_for_prompt(brand_context)
    guidelines_text = []
    
    # Brand voice and tone
    if brand_context[:brand_voice].present?
      guidelines_text << "Brand Voice: #{brand_context[:brand_voice].to_json}"
    end
    
    # Messaging framework
    framework = brand_context[:messaging_framework]
    if framework.present?
      guidelines_text << "Key Messages: #{framework[:key_messages].to_json}" if framework[:key_messages].present?
      guidelines_text << "Value Propositions: #{framework[:value_propositions].to_json}" if framework[:value_propositions].present?
      guidelines_text << "Approved Phrases: #{framework[:approved_phrases].join(', ')}" if framework[:approved_phrases].any?
      guidelines_text << "Banned Words: #{framework[:banned_words].join(', ')}" if framework[:banned_words].any?
      guidelines_text << "Tone Requirements: #{framework[:tone_attributes].to_json}" if framework[:tone_attributes].present?
    end
    
    # Brand guidelines
    if brand_context[:guidelines].any?
      guidelines_text << "Brand Guidelines:"
      brand_context[:guidelines].each do |guideline|
        guidelines_text << "- #{guideline[:category]} (#{guideline[:rule_type]}): #{guideline[:rule_text]}"
      end
    end
    
    # Visual identity
    visual = brand_context[:visual_identity]
    if visual.present?
      guidelines_text << "Primary Colors: #{visual[:primary_colors].join(', ')}" if visual[:primary_colors].any?
      guidelines_text << "Typography: #{visual[:font_families].keys.join(', ')}" if visual[:font_families].any?
    end
    
    guidelines_text.join("\n")
  end
  
  def filter_suggestions_by_brand_guidelines(suggestions, brand_context)
    return suggestions unless suggestions.is_a?(Array)
    
    framework = brand_context[:messaging_framework] || {}
    banned_words = framework[:banned_words] || []
    
    # Filter out suggestions that contain banned words
    filtered_suggestions = suggestions.reject do |suggestion|
      text_content = "#{suggestion['name']} #{suggestion['description']}".downcase
      banned_words.any? { |word| text_content.include?(word.downcase) }
    end
    
    # Add compliance warnings for potentially problematic suggestions
    filtered_suggestions.map do |suggestion|
      warnings = []
      
      # Check for tone compliance
      if framework[:tone_attributes].present?
        tone_warnings = check_tone_compliance(suggestion, framework[:tone_attributes])
        warnings.concat(tone_warnings)
      end
      
      suggestion['compliance_warnings'] = warnings if warnings.any?
      suggestion
    end
  end
  
  def check_tone_compliance(suggestion, tone_attributes)
    warnings = []
    content = "#{suggestion['name']} #{suggestion['description']}".downcase
    
    # Check formality level
    if tone_attributes['formality'] == 'formal'
      informal_words = ['hey', 'yeah', 'cool', 'awesome', 'gonna', 'wanna']
      found_informal = informal_words.select { |word| content.include?(word) }
      if found_informal.any?
        warnings << "Contains informal language: #{found_informal.join(', ')}"
      end
    elsif tone_attributes['formality'] == 'casual'
      formal_words = ['utilize', 'facilitate', 'endeavor', 'subsequently']
      found_formal = formal_words.select { |word| content.include?(word) }
      if found_formal.any?
        warnings << "Contains overly formal language: #{found_formal.join(', ')}"
      end
    end
    
    warnings
  end
  
  def calculate_brand_compliance_adjustment(suggestion, brand_context)
    return 0.0 unless brand_context.present?
    
    base_compliance_score = suggestion['brand_compliance_score'] || 0.5
    
    # Higher weight for brand compliance in scoring
    compliance_weight = 0.3
    
    # Convert compliance score to adjustment (-0.15 to +0.15)
    adjustment = (base_compliance_score - 0.5) * compliance_weight
    
    # Additional penalty for compliance warnings
    if suggestion['compliance_warnings']&.any?
      adjustment -= 0.1
    end
    
    adjustment
  end
end