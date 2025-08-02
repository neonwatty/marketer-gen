module LlmIntegration
  class ContentOptimizationEngine
    include ActiveModel::Model

    def initialize(brand)
      @brand = brand
      @llm_service = MultiProviderService.new
      @performance_analyzer = ContentPerformanceAnalyzer.new
      @multivariate_tester = MultivariateContentTester.new
    end

    def generate_variants(base_content, options = {})
      count = options[:count] || 3
      variants = []

      optimization_strategies = [
        "emotional_appeal",
        "logical_benefits",
        "urgency_creation",
        "social_proof",
        "value_proposition"
      ]

      count.times do |i|
        strategy = optimization_strategies[i % optimization_strategies.length]

        variant_prompt = build_variant_prompt(base_content, strategy)
        generated_content = @llm_service.generate_content(variant_prompt)

        variants << {
          content: generated_content[:text],
          optimization_strategy: strategy,
          expected_performance_lift: calculate_expected_lift(strategy, base_content),
          confidence_score: generated_content[:confidence] || 0.8,
          brand_compliance_score: check_brand_compliance(generated_content[:text])
        }
      end

      variants
    end

    def optimize_for_audience(content, segment_info, preferences = nil)
      # Handle both single segment and array of segments
      if segment_info.is_a?(Array)
        optimized_variants = {}

        segment_info.each do |segment|
          audience_context = build_audience_context(segment)
          optimization_prompt = build_audience_optimization_prompt(content, audience_context)

          optimized_content = @llm_service.generate_content(optimization_prompt)

          optimized_variants[segment[:name]] = {
            content: optimized_content[:text],
            audience_segment: segment,
            optimization_score: calculate_audience_optimization_score(optimized_content, segment),
            brand_compliance_score: check_brand_compliance(optimized_content[:text])
          }
        end

        optimized_variants
      else
        # Single segment with preferences
        segment = segment_info
        segment[:preferences] = preferences if preferences

        audience_context = build_audience_context(segment)
        optimization_prompt = build_audience_optimization_prompt(content, audience_context)

        optimized_content = @llm_service.generate_content(optimization_prompt)

        {
          content: optimized_content[:text],
          audience_segment: segment,
          optimization_score: calculate_audience_optimization_score(optimized_content, segment),
          brand_compliance_score: check_brand_compliance(optimized_content[:text])
        }
      end
    end

    def analyze_performance_potential(content, goals = [])
      analysis_prompt = build_performance_analysis_prompt(content, goals)
      performance_analysis = @llm_service.analyze(analysis_prompt, json_response: true)

      {
        overall_score: performance_analysis["overall_score"] || 0.7,
        engagement_potential: performance_analysis["engagement_potential"] || 0.7,
        conversion_potential: performance_analysis["conversion_potential"] || 0.7,
        brand_alignment: performance_analysis["brand_alignment"] || 0.8,
        improvement_suggestions: performance_analysis["suggestions"] || [],
        performance_predictions: performance_analysis["predictions"] || {}
      }
    end

    def suggest_improvements(content, performance_data = {})
      improvement_prompt = build_improvement_prompt(content, performance_data)
      suggestions = @llm_service.analyze(improvement_prompt, json_response: true)

      {
        priority_improvements: suggestions["priority_improvements"] || [],
        quick_wins: suggestions["quick_wins"] || [],
        strategic_changes: suggestions["strategic_changes"] || [],
        risk_assessment: suggestions["risk_assessment"] || {},
        implementation_complexity: suggestions["complexity"] || "medium"
      }
    end

    def test_multivariate_performance(variants, test_parameters = {})
      @multivariate_tester.setup_test(variants, test_parameters)

      {
        test_id: SecureRandom.uuid,
        variants_count: variants.length,
        estimated_test_duration: calculate_test_duration(variants, test_parameters),
        confidence_requirements: test_parameters[:confidence_level] || 0.95,
        traffic_allocation: distribute_traffic(variants.length),
        success_metrics: test_parameters[:success_metrics] || [ "engagement", "conversion" ]
      }
    end

    def optimize_for_channel(content, channels)
      optimized_results = {}

      channels.each do |channel|
        channel_context = build_channel_context(channel)
        optimization_prompt = build_channel_optimization_prompt(content, channel_context)

        optimized_content = @llm_service.generate_content(optimization_prompt)

        optimized_results[channel] = {
          content: optimized_content[:text],
          channel: channel,
          optimization_score: calculate_channel_optimization_score(optimized_content, channel),
          brand_compliance_score: check_brand_compliance(optimized_content[:text]),
          channel_specific_metrics: predict_channel_performance(optimized_content[:text], channel)
        }
      end

      optimized_results
    end

    private

    def build_variant_prompt(base_content, strategy)
      <<~PROMPT
        Create a content variant using the #{strategy} optimization strategy.

        ORIGINAL CONTENT:
        Type: #{base_content[:type]}
        Content: #{base_content[:content]}
        Context: #{format_context(base_content[:context])}

        BRAND CONTEXT:
        #{build_brand_context}

        OPTIMIZATION STRATEGY: #{strategy}
        #{get_strategy_description(strategy)}

        Requirements:
        - Maintain brand voice and compliance
        - Apply the #{strategy} strategy effectively
        - Keep the same content type and general purpose
        - Ensure the variant is measurably different from the original

        Return only the optimized content variant.
      PROMPT
    end

    def build_audience_context(segment)
      {
        name: segment[:name] || "General Audience",
        demographics: segment[:demographics] || {},
        psychographics: segment[:psychographics] || {},
        preferences: segment[:preferences] || {},
        pain_points: segment[:pain_points] || [],
        communication_style: segment[:communication_style] || "professional"
      }
    end

    def build_audience_optimization_prompt(content, audience_context)
      <<~PROMPT
        Optimize the following content specifically for this audience segment:

        CONTENT TO OPTIMIZE:
        #{content}

        TARGET AUDIENCE:
        Name: #{audience_context[:name]}
        Demographics: #{format_hash(audience_context[:demographics])}
        Psychographics: #{format_hash(audience_context[:psychographics])}
        Preferences: #{format_hash(audience_context[:preferences])}
        Pain Points: #{audience_context[:pain_points].join(', ')}
        Communication Style: #{audience_context[:communication_style]}

        BRAND CONTEXT:
        #{build_brand_context}

        Requirements:
        - Tailor language and messaging to resonate with this specific audience
        - Address their specific pain points and preferences
        - Maintain brand voice while adapting tone for the audience
        - Ensure cultural sensitivity and appropriateness

        Return the audience-optimized content.
      PROMPT
    end

    def build_performance_analysis_prompt(content, goals)
      <<~PROMPT
        Analyze the performance potential of this content against the specified goals:

        CONTENT:
        #{content}

        PERFORMANCE GOALS:
        #{goals.join(', ')}

        BRAND CONTEXT:
        #{build_brand_context}

        Provide analysis in JSON format:
        {
          "overall_score": 0.0-1.0,
          "engagement_potential": 0.0-1.0,
          "conversion_potential": 0.0-1.0,
          "brand_alignment": 0.0-1.0,
          "suggestions": ["improvement suggestion 1", "suggestion 2"],
          "predictions": {
            "estimated_engagement_rate": "percentage",
            "estimated_conversion_rate": "percentage"
          }
        }
      PROMPT
    end

    def build_improvement_prompt(content, performance_data)
      <<~PROMPT
        Suggest specific improvements for this content based on performance data:

        CONTENT:
        #{content}

        PERFORMANCE DATA:
        #{format_hash(performance_data)}

        BRAND CONTEXT:
        #{build_brand_context}

        Provide suggestions in JSON format:
        {
          "priority_improvements": ["high-impact change 1", "change 2"],
          "quick_wins": ["easy improvement 1", "improvement 2"],
          "strategic_changes": ["strategic change 1", "change 2"],
          "risk_assessment": {
            "low_risk": ["safe change 1"],
            "medium_risk": ["moderate change 1"],
            "high_risk": ["risky change 1"]
          },
          "complexity": "low|medium|high"
        }
      PROMPT
    end

    def build_brand_context
      context = []
      context << "Brand: #{@brand.name}"
      context << "Industry: #{@brand.industry}" if @brand.respond_to?(:industry)

      if @brand.respond_to?(:brand_voice_profiles) && @brand.brand_voice_profiles.exists?
        profile = @brand.brand_voice_profiles.first
        context << "Voice Traits: #{profile.primary_traits&.join(', ')}"
        context << "Tone: #{profile.tone_descriptors&.join(', ')}"
      end

      context.join("\n")
    end

    def get_strategy_description(strategy)
      descriptions = {
        "emotional_appeal" => "Focus on emotional triggers and human connections",
        "logical_benefits" => "Emphasize rational benefits and logical reasoning",
        "urgency_creation" => "Create appropriate urgency and time-sensitivity",
        "social_proof" => "Incorporate social validation and credibility",
        "value_proposition" => "Highlight unique value and competitive advantages"
      }

      descriptions[strategy] || "Apply general optimization principles"
    end

    def calculate_expected_lift(strategy, base_content)
      # Simplified lift calculation based on strategy and content type
      base_lifts = {
        "emotional_appeal" => 0.15,
        "logical_benefits" => 0.12,
        "urgency_creation" => 0.18,
        "social_proof" => 0.20,
        "value_proposition" => 0.14
      }

      content_type_multiplier = case base_content[:type]
      when :email_subject then 1.2
      when :ad_copy then 1.1
      when :landing_page then 0.9
      else 1.0
      end

      (base_lifts[strategy] || 0.1) * content_type_multiplier
    end

    def calculate_audience_optimization_score(content, segment)
      # Simplified scoring based on content analysis
      base_score = 0.7

      # Boost score if content includes audience-specific elements
      if content[:text]&.downcase&.include?(segment[:name]&.downcase)
        base_score += 0.1
      end

      if segment[:pain_points]&.any? { |pain| content[:text]&.include?(pain) }
        base_score += 0.15
      end

      [ base_score, 1.0 ].min
    end

    def check_brand_compliance(content)
      # Use existing brand compliance checker
      compliance_checker = BrandComplianceChecker.new
      result = compliance_checker.check_compliance(content, @brand)
      result[:overall_score]
    end

    def calculate_test_duration(variants, parameters)
      base_duration = 14 # days
      traffic_factor = (parameters[:daily_traffic] || 1000) / 1000.0
      variants_factor = variants.length / 3.0
      confidence_factor = (parameters[:confidence_level] || 0.95) > 0.95 ? 1.2 : 1.0

      (base_duration * variants_factor / traffic_factor * confidence_factor).round
    end

    def distribute_traffic(variants_count)
      equal_split = (100.0 / variants_count).round(2)

      variants_count.times.map do |i|
        {
          variant_index: i,
          traffic_percentage: equal_split
        }
      end
    end

    def format_context(context)
      return "" unless context.is_a?(Hash)
      context.map { |k, v| "#{k.to_s.humanize}: #{v}" }.join("\n")
    end

    def format_hash(hash)
      return "" unless hash.is_a?(Hash)
      hash.map { |k, v| "#{k}: #{v}" }.join(", ")
    end

    def build_channel_context(channel)
      channel_specs = {
        "email" => {
          character_limits: { subject: 50, body: 2000 },
          style: "conversational",
          call_to_action: "strong",
          personalization: "high"
        },
        "social_media" => {
          character_limits: { post: 280, caption: 150 },
          style: "engaging",
          call_to_action: "moderate",
          hashtags: "recommended"
        },
        "website" => {
          character_limits: { headline: 60, description: 160 },
          style: "professional",
          call_to_action: "prominent",
          seo_optimized: true
        },
        "print" => {
          character_limits: { headline: 40, body: 500 },
          style: "formal",
          call_to_action: "clear",
          visual_hierarchy: "important"
        }
      }

      channel_specs[channel] || channel_specs["website"]
    end

    def build_channel_optimization_prompt(content, channel_context)
      <<~PROMPT
        Optimize the following content for the specified channel:

        CONTENT TO OPTIMIZE:
        #{content}

        CHANNEL SPECIFICATIONS:
        Character Limits: #{format_hash(channel_context[:character_limits] || {})}
        Style: #{channel_context[:style]}
        Call-to-Action Requirement: #{channel_context[:call_to_action]}
        Special Requirements: #{format_hash(channel_context.except(:character_limits, :style, :call_to_action))}

        BRAND CONTEXT:
        #{build_brand_context}

        Requirements:
        - Adhere to channel-specific character limits
        - Match the required style and tone for this channel
        - Optimize call-to-action placement and strength
        - Maintain brand voice while adapting to channel requirements
        - Ensure content performs well on this specific channel

        Return the channel-optimized content.
      PROMPT
    end

    def calculate_channel_optimization_score(content, channel)
      # Simplified scoring based on channel requirements
      base_score = 0.7

      # Channel-specific scoring logic
      case channel
      when "email"
        base_score += content[:text]&.include?("you") ? 0.1 : 0
        base_score += content[:text]&.length&.between?(100, 500) ? 0.1 : 0
      when "social_media"
        base_score += content[:text]&.length&.<(280) ? 0.2 : -0.1
        base_score += content[:text]&.count("#") > 0 ? 0.1 : 0
      when "website"
        base_score += content[:text]&.include?("learn more") ? 0.1 : 0
      end

      [ base_score, 1.0 ].min
    end

    def predict_channel_performance(content, channel)
      # Simplified performance prediction
      {
        estimated_engagement: case channel
                              when "email" then 0.25
                              when "social_media" then 0.15
                              when "website" then 0.35
                              else 0.20
                              end,
        estimated_conversion: case channel
                              when "email" then 0.05
                              when "social_media" then 0.02
                              when "website" then 0.08
                              else 0.03
                              end
      }
    end
  end
end
