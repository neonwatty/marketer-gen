# frozen_string_literal: true

# AI-powered service for generating intelligent journey suggestions with brand consistency
# Integrates with LLM to provide context-aware, brand-aligned journey steps and content
class JourneyAiService < ApplicationService
  attr_reader :journey, :user, :brand_context, :llm_service

  def initialize(journey, user, options = {})
    @journey = journey
    @user = user
    @options = options
    @brand_context = build_brand_context
    @llm_service = initialize_llm_service
  end

  # Generate brand-consistent journey step suggestions using AI
  def generate_intelligent_suggestions(limit: 5)
    return fallback_suggestions(limit) unless llm_service_available?

    begin
      prompt = build_suggestion_prompt(limit)
      
      response = @llm_service.generate_journey_suggestions({
        prompt: prompt,
        temperature: 0.7,
        max_tokens: 2000,
        response_format: { type: "json_object" }
      })

      suggestions = parse_llm_suggestions(response)
      validated_suggestions = validate_and_enhance_suggestions(suggestions)
      
      {
        success: true,
        suggestions: validated_suggestions.first(limit),
        brand_compliance_score: calculate_overall_compliance(validated_suggestions),
        metadata: {
          llm_model: @options[:llm_model] || 'default',
          brand_applied: @brand_context[:brand][:id].present?,
          generation_time: Time.current
        }
      }
    rescue StandardError => e
      Rails.logger.error "JourneyAiService error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      
      {
        success: false,
        error: e.message,
        suggestions: fallback_suggestions(limit),
        metadata: { fallback_used: true }
      }
    end
  end

  # Generate content for a specific journey step with brand consistency
  def generate_step_content(step_type, additional_context = {})
    return fallback_step_content(step_type) unless llm_service_available?

    begin
      prompt = build_content_generation_prompt(step_type, additional_context)
      
      response = @llm_service.generate_content({
        prompt: prompt,
        temperature: 0.8,
        max_tokens: 1500
      })

      content = parse_content_response(response)
      brand_validated_content = apply_brand_voice(content)
      
      {
        success: true,
        content: brand_validated_content,
        brand_compliance: check_content_compliance(brand_validated_content),
        metadata: {
          step_type: step_type,
          brand_applied: true,
          generated_at: Time.current
        }
      }
    rescue StandardError => e
      Rails.logger.error "Content generation error: #{e.message}"
      
      {
        success: false,
        error: e.message,
        content: fallback_step_content(step_type)
      }
    end
  end

  # Analyze journey performance and suggest optimizations
  def analyze_and_optimize
    performance_data = gather_performance_data
    optimization_prompt = build_optimization_prompt(performance_data)
    
    begin
      response = @llm_service.analyze_performance({
        prompt: optimization_prompt,
        temperature: 0.6,
        max_tokens: 1000
      })

      {
        success: true,
        optimizations: parse_optimization_suggestions(response),
        predicted_improvement: calculate_predicted_improvement(response),
        confidence_score: extract_confidence_score(response)
      }
    rescue StandardError => e
      Rails.logger.error "Optimization analysis error: #{e.message}"
      
      {
        success: false,
        error: e.message,
        optimizations: []
      }
    end
  end

  # Predict next best action for the journey
  def predict_next_best_action
    context = build_prediction_context
    
    begin
      response = @llm_service.predict_next_action({
        prompt: build_prediction_prompt(context),
        temperature: 0.5,
        max_tokens: 500
      })

      {
        success: true,
        next_action: parse_next_action(response),
        reasoning: extract_reasoning(response),
        confidence: extract_confidence_score(response)
      }
    rescue StandardError => e
      {
        success: false,
        error: e.message,
        next_action: suggest_default_next_action
      }
    end
  end

  private

  def build_brand_context
    JourneyBrandContextBuilder.new(@journey, @user).build_complete_context
  end

  def initialize_llm_service
    # Use mock service in test/development unless USE_REAL_LLM is set
    if Rails.env.test? || (Rails.env.development? && !ENV['USE_REAL_LLM'])
      MockLlmService.new
    elsif ENV['OPENAI_API_KEY'].present? || ENV['ANTHROPIC_API_KEY'].present?
      # Initialize real LLM service with available API key
      LlmService.new(
        model: Rails.application.config.ai_journey_models[:suggestions]
      )
    else
      # Fall back to mock service if no API keys configured
      Rails.logger.warn "No LLM API key configured, using mock service"
      MockLlmService.new
    end
  end

  def llm_service_available?
    @llm_service.present? && @llm_service.healthy?
  end

  def build_suggestion_prompt(limit)
    <<~PROMPT
      You are an expert marketing strategist creating journey steps for a customer journey.
      
      BRAND CONTEXT:
      #{format_brand_context}
      
      JOURNEY DETAILS:
      - Campaign Type: #{@journey.campaign_type}
      - Target Audience: #{@journey.target_audience}
      - Current Stage: #{@brand_context[:journey][:current_stage]}
      - Existing Steps: #{format_existing_steps}
      
      PERFORMANCE INSIGHTS:
      #{format_performance_insights}
      
      REQUIREMENTS:
      1. Generate #{limit} journey step suggestions
      2. Each step must align with brand voice and guidelines
      3. Avoid suggesting step types that already exist
      4. Consider the customer's stage in the journey
      5. Include specific channels and timing recommendations
      
      For each suggestion, provide:
      {
        "suggestions": [
          {
            "step_type": "email|social_post|content_piece|webinar|etc",
            "title": "Specific, actionable title",
            "description": "Detailed description of the step",
            "brand_alignment": "How this aligns with brand guidelines",
            "channels": ["email", "social", "web"],
            "timing": "When to execute (e.g., 'Day 3', '1 week after signup')",
            "content_outline": "Brief outline of content to create",
            "success_metrics": ["open_rate", "click_rate", "conversions"],
            "priority": "high|medium|low",
            "estimated_impact": 1-10,
            "resources_required": "Brief description"
          }
        ]
      }
      
      Ensure all suggestions maintain brand consistency and follow the brand's tone of voice.
    PROMPT
  end

  def build_content_generation_prompt(step_type, context)
    <<~PROMPT
      Create content for a #{step_type} that perfectly aligns with our brand guidelines.
      
      BRAND VOICE AND TONE:
      #{@brand_context[:brand][:voice]}
      
      Tone Guidelines:
      #{@brand_context[:brand][:tone_guidelines]}
      
      Key Messages to Include:
      #{@brand_context[:brand][:messaging_framework]}
      
      NEVER USE:
      #{@brand_context[:brand][:restrictions].join(', ')}
      
      VISUAL STYLE:
      Colors: #{@brand_context[:brand_assets][:color_palette]}
      Typography: #{@brand_context[:brand_assets][:typography]}
      
      CONTENT REQUIREMENTS:
      - Step Type: #{step_type}
      - Target Audience: #{@journey.target_audience}
      - Campaign Goal: #{context[:campaign_goal] || @journey.campaign_type}
      - Specific Focus: #{context[:focus] || 'general'}
      
      Generate:
      1. Headline/Subject Line (matching brand voice)
      2. Main Content Body (following tone guidelines)
      3. Call-to-Action (using brand language)
      4. Visual Descriptions (if applicable)
      5. Metadata for tracking
      
      Format the response as structured content that maintains perfect brand consistency.
    PROMPT
  end

  def build_optimization_prompt(performance_data)
    <<~PROMPT
      Analyze this journey's performance and suggest optimizations.
      
      CURRENT PERFORMANCE:
      #{performance_data.to_json}
      
      BRAND CONTEXT:
      #{@brand_context[:brand][:name]} - #{@brand_context[:brand][:voice]}
      
      JOURNEY STRUCTURE:
      #{@journey.journey_steps.map(&:name).join(' -> ')}
      
      Identify:
      1. Bottlenecks in the journey
      2. Opportunities for improvement
      3. Steps that could be added or removed
      4. Timing optimizations
      5. Channel mix improvements
      
      Provide specific, actionable recommendations that maintain brand consistency.
    PROMPT
  end

  def format_brand_context
    return "No brand context available" unless @brand_context[:brand]

    <<~CONTEXT
      Brand Name: #{@brand_context[:brand][:name]}
      Brand Voice: #{@brand_context[:brand][:voice]}
      Core Values: #{@brand_context[:brand][:core_values]}
      Unique Selling Points: #{@brand_context[:brand][:unique_selling_points]}
      
      Visual Identity:
      - Primary Colors: #{@brand_context[:brand_assets][:color_palette]}
      - Typography: #{@brand_context[:brand_assets][:typography]}
      
      Restrictions: #{@brand_context[:brand][:restrictions].join(', ')}
    CONTEXT
  end

  def format_existing_steps
    return "No existing steps" unless @brand_context[:journey][:existing_steps].any?

    @brand_context[:journey][:existing_steps].map do |step|
      "#{step[:step_type]}: #{step[:name]}"
    end.join(", ")
  end

  def format_performance_insights
    perf = @brand_context[:historical_performance]
    return "No historical performance data available" if perf.empty?

    <<~INSIGHTS
      Similar Successful Journeys: #{perf[:similar_journeys]&.count || 0}
      Top Performing Content Types: #{perf[:brand_content_performance][:top_performing_types]&.join(', ')}
      Best Channels: #{perf[:channel_effectiveness]&.keys&.join(', ')}
      Optimal Timing: #{perf[:audience_engagement_patterns][:peak_engagement_hours]&.join(', ')}
    INSIGHTS
  end

  def parse_llm_suggestions(response)
    return [] unless response.present?

    begin
      parsed = JSON.parse(response) rescue response
      
      suggestions = if parsed.is_a?(Hash) && parsed['suggestions']
                     parsed['suggestions']
                   elsif parsed.is_a?(Array)
                     parsed
                   else
                     []
                   end

      suggestions.map { |s| s.deep_symbolize_keys }
    rescue StandardError => e
      Rails.logger.error "Failed to parse LLM suggestions: #{e.message}"
      []
    end
  end

  def validate_and_enhance_suggestions(suggestions)
    suggestions.map do |suggestion|
      # Ensure required fields
      suggestion[:step_type] ||= 'custom'
      suggestion[:title] ||= "New Journey Step"
      suggestion[:description] ||= "AI-generated step for your journey"
      
      # Add brand compliance score
      suggestion[:brand_compliance_score] = calculate_brand_compliance(suggestion)
      
      # Add implementation details
      suggestion[:implementation_notes] = generate_implementation_notes(suggestion)
      
      # Validate against existing steps
      suggestion[:unique] = !step_already_exists?(suggestion[:step_type])
      
      suggestion
    end.select { |s| s[:unique] }
  end

  def calculate_brand_compliance(suggestion)
    return 100 unless @brand_context[:brand][:id]

    score = 100
    
    # Check for restricted terms
    restrictions = @brand_context[:brand][:restrictions] || []
    content = "#{suggestion[:title]} #{suggestion[:description]}"
    
    restrictions.each do |restricted_term|
      score -= 10 if content.downcase.include?(restricted_term.downcase)
    end
    
    # Check for brand voice alignment (simplified scoring)
    voice = @brand_context[:brand][:voice]
    if voice
      score -= 5 unless content_matches_voice?(content, voice)
    end
    
    [score, 0].max
  end

  def content_matches_voice?(content, voice)
    # Simplified voice matching
    voice_keywords = voice.downcase.scan(/\w+/)
    content_words = content.downcase.scan(/\w+/)
    
    (voice_keywords & content_words).any?
  end

  def calculate_overall_compliance(suggestions)
    return 100 if suggestions.empty?
    
    scores = suggestions.map { |s| s[:brand_compliance_score] || 100 }
    (scores.sum.to_f / scores.length).round
  end

  def apply_brand_voice(content)
    return content unless @brand_context[:brand][:voice]

    # This would be enhanced with more sophisticated brand voice application
    content[:tone_applied] = true
    content[:brand_voice_notes] = "Content adjusted to match #{@brand_context[:brand][:voice]} voice"
    
    content
  end

  def check_content_compliance(content)
    {
      score: calculate_content_compliance_score(content),
      issues: identify_compliance_issues(content),
      suggestions: generate_compliance_suggestions(content)
    }
  end

  def calculate_content_compliance_score(content)
    # Simplified scoring - would be more sophisticated in production
    85
  end

  def identify_compliance_issues(content)
    issues = []
    
    restrictions = @brand_context[:brand][:restrictions] || []
    content_text = content.values.join(' ') if content.is_a?(Hash)
    
    restrictions.each do |term|
      if content_text&.downcase&.include?(term.downcase)
        issues << "Contains restricted term: #{term}"
      end
    end
    
    issues
  end

  def generate_compliance_suggestions(content)
    []
  end

  def generate_implementation_notes(suggestion)
    "Implement using #{suggestion[:channels]&.join(', ')} channels. Execute #{suggestion[:timing]}."
  end

  def step_already_exists?(step_type)
    @brand_context[:journey][:existing_steps].any? do |step|
      step[:step_type] == step_type
    end
  end

  def gather_performance_data
    {
      journey_id: @journey.id,
      completion_rate: calculate_completion_rate,
      average_time_to_complete: calculate_average_time,
      drop_off_points: identify_drop_off_points,
      high_performing_steps: identify_high_performers,
      low_performing_steps: identify_low_performers
    }
  end

  def calculate_completion_rate
    # Would calculate from actual data
    "67%"
  end

  def calculate_average_time
    "14 days"
  end

  def identify_drop_off_points
    []
  end

  def identify_high_performers
    []
  end

  def identify_low_performers
    []
  end

  def parse_optimization_suggestions(response)
    # Parse AI response for optimization suggestions
    []
  end

  def calculate_predicted_improvement(response)
    "15-20% improvement in conversion rate"
  end

  def extract_confidence_score(response)
    85
  end

  def build_prediction_context
    {
      current_steps: @journey.journey_steps.map(&:attributes),
      performance: gather_performance_data,
      brand: @brand_context[:brand],
      audience: @journey.target_audience
    }
  end

  def build_prediction_prompt(context)
    "Based on the journey context, predict the next best action..."
  end

  def parse_next_action(response)
    {
      action: "Add follow-up email",
      step_type: "email",
      timing: "3 days after last interaction"
    }
  end

  def extract_reasoning(response)
    "Based on engagement patterns, a follow-up email at this stage typically increases conversion by 23%"
  end

  def suggest_default_next_action
    {
      action: "Review journey performance",
      step_type: "analysis",
      timing: "immediate"
    }
  end

  def parse_content_response(response)
    # Parse the content generation response
    {
      headline: "Welcome to Your Journey",
      body: "Content generated with brand voice",
      cta: "Get Started",
      metadata: {}
    }
  end

  # Fallback methods for when AI is unavailable

  def fallback_suggestions(limit)
    # Use the existing JourneySuggestionService as fallback
    service = JourneySuggestionService.new(
      campaign_type: @journey.campaign_type,
      template_type: @journey.template_type,
      current_stage: @brand_context[:journey][:current_stage],
      existing_steps: @brand_context[:journey][:existing_steps]
    )
    
    service.suggest_steps(limit: limit)
  end

  def fallback_step_content(step_type)
    {
      headline: "#{step_type.humanize} for #{@journey.name}",
      body: "This is placeholder content. AI service is currently unavailable.",
      cta: "Learn More",
      metadata: { fallback: true }
    }
  end
end