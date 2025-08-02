module LlmIntegration
  class BrandComplianceChecker
    include ActiveModel::Model

    def initialize
      @llm_service = LlmService.new(model: "gpt-4-turbo-preview")
    end

    def check_compliance(content, brand)
      # Get existing brand compliance analysis
      existing_analysis = get_existing_compliance_analysis(brand)

      # Perform LLM-based compliance check
      llm_analysis = perform_llm_compliance_check(content, brand)

      # Combine with rule-based analysis
      rule_based_analysis = perform_rule_based_analysis(content, brand)

      # Calculate overall compliance score
      overall_score = calculate_overall_compliance_score(llm_analysis, rule_based_analysis)

      {
        overall_score: overall_score,
        voice_compliance: llm_analysis[:voice_score],
        tone_compliance: llm_analysis[:tone_score],
        messaging_compliance: llm_analysis[:messaging_score],
        violations: compile_violations(llm_analysis, rule_based_analysis),
        suggestions: generate_compliance_suggestions(llm_analysis, rule_based_analysis),
        confidence: calculate_confidence_score(llm_analysis, rule_based_analysis),
        analysis_details: {
          llm_analysis: llm_analysis,
          rule_based_analysis: rule_based_analysis,
          existing_integration: existing_analysis
        }
      }
    end

    private

    def get_existing_compliance_analysis(brand)
      # Integrate with existing brand compliance system
      begin
        real_time_service = RealTimeBrandComplianceService.new
        existing_result = real_time_service.check_compliance(
          content: "", # We'll analyze separately
          brand: brand
        )

        {
          service_available: true,
          brand_voice_attributes: existing_result&.voice_attributes || {},
          compliance_rules: existing_result&.compliance_rules || []
        }
      rescue => e
        Rails.logger.warn "Could not integrate with existing compliance system: #{e.message}"
        { service_available: false }
      end
    end

    def perform_llm_compliance_check(content, brand)
      # Build comprehensive brand context
      brand_context = build_brand_analysis_context(brand)

      # Create detailed compliance analysis prompt
      prompt = build_compliance_analysis_prompt(content, brand_context)

      # Get LLM analysis
      response = @llm_service.analyze(prompt, json_response: true, temperature: 0.3)

      # Parse and validate the response
      parse_llm_compliance_response(response)
    end

    def build_brand_analysis_context(brand)
      context = {
        brand_name: brand.name,
        industry: brand.industry,
        brand_guidelines: [],
        voice_attributes: {},
        messaging_framework: {}
      }

      # Collect brand guidelines
      brand.brand_guidelines.active.each do |guideline|
        context[:brand_guidelines] << {
          category: guideline.category,
          content: guideline.content,
          priority: guideline.priority
        }
      end

      # Get voice attributes from latest analysis
      if brand.latest_analysis
        context[:voice_attributes] = brand.latest_analysis.voice_attributes || {}
      end

      # Get messaging framework
      if brand.messaging_framework
        framework = brand.messaging_framework
        context[:messaging_framework] = {
          unique_value_proposition: framework.unique_value_proposition,
          value_propositions: framework.value_propositions,
          key_messages: framework.key_messages,
          target_audiences: framework.target_audiences
        }
      end

      # Get brand voice profile if available
      if brand.brand_voice_profiles.exists?
        voice_profile = brand.brand_voice_profiles.first
        context[:voice_profile] = {
          primary_traits: voice_profile.primary_traits,
          tone_descriptors: voice_profile.tone_descriptors,
          communication_style: voice_profile.communication_style,
          brand_personality: voice_profile.brand_personality
        }
      end

      context
    end

    def build_compliance_analysis_prompt(content, brand_context)
      prompt = <<~PROMPT
        Analyze the following content for brand compliance against the provided brand guidelines.

        CONTENT TO ANALYZE:
        #{content}

        BRAND CONTEXT:
        Brand: #{brand_context[:brand_name]}
        Industry: #{brand_context[:industry]}

        BRAND VOICE PROFILE:
        #{format_voice_profile(brand_context[:voice_profile])}

        BRAND GUIDELINES:
        #{format_brand_guidelines(brand_context[:brand_guidelines])}

        MESSAGING FRAMEWORK:
        #{format_messaging_framework(brand_context[:messaging_framework])}

        VOICE ATTRIBUTES:
        #{format_voice_attributes(brand_context[:voice_attributes])}

        Please provide a detailed compliance analysis with the following JSON structure:
        {
          "voice_score": 0.0-1.0,
          "tone_score": 0.0-1.0,#{' '}
          "messaging_score": 0.0-1.0,
          "voice_analysis": "detailed analysis of voice compliance",
          "tone_analysis": "detailed analysis of tone compliance",
          "messaging_analysis": "detailed analysis of messaging compliance",
          "specific_violations": [
            {
              "type": "voice_mismatch|tone_issue|messaging_inconsistency",
              "severity": "low|medium|high",
              "description": "specific issue description",
              "suggestion": "specific improvement suggestion"
            }
          ],
          "strengths": ["list of compliance strengths"],
          "overall_assessment": "summary assessment"
        }
      PROMPT
    end

    def format_voice_profile(voice_profile)
      return "No voice profile available" unless voice_profile

      formatted = []
      formatted << "Primary Traits: #{voice_profile[:primary_traits]&.join(', ')}" if voice_profile[:primary_traits]
      formatted << "Tone Descriptors: #{voice_profile[:tone_descriptors]&.join(', ')}" if voice_profile[:tone_descriptors]
      formatted << "Communication Style: #{voice_profile[:communication_style]}" if voice_profile[:communication_style]
      formatted << "Brand Personality: #{voice_profile[:brand_personality]}" if voice_profile[:brand_personality]

      formatted.join("\n")
    end

    def format_brand_guidelines(guidelines)
      return "No specific guidelines available" if guidelines.empty?

      guidelines.map do |guideline|
        "#{guideline[:category].humanize}: #{guideline[:content]}"
      end.join("\n")
    end

    def format_messaging_framework(framework)
      return "No messaging framework available" unless framework

      formatted = []
      formatted << "Unique Value Proposition: #{framework[:unique_value_proposition]}" if framework[:unique_value_proposition]
      formatted << "Value Propositions: #{framework[:value_propositions]&.join(', ')}" if framework[:value_propositions]
      formatted << "Key Messages: #{framework[:key_messages]&.join(', ')}" if framework[:key_messages]

      formatted.join("\n")
    end

    def format_voice_attributes(attributes)
      return "No voice attributes available" if attributes.empty?

      attributes.map { |k, v| "#{k.humanize}: #{v}" }.join("\n")
    end

    def parse_llm_compliance_response(response)
      begin
        if response.is_a?(String)
          parsed = JSON.parse(response)
        else
          parsed = response
        end

        {
          voice_score: parsed["voice_score"]&.to_f || 0.5,
          tone_score: parsed["tone_score"]&.to_f || 0.5,
          messaging_score: parsed["messaging_score"]&.to_f || 0.5,
          voice_analysis: parsed["voice_analysis"] || "",
          tone_analysis: parsed["tone_analysis"] || "",
          messaging_analysis: parsed["messaging_analysis"] || "",
          specific_violations: parsed["specific_violations"] || [],
          strengths: parsed["strengths"] || [],
          overall_assessment: parsed["overall_assessment"] || "",
          confidence: 0.8 # LLM analysis confidence
        }
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse LLM compliance response: #{e.message}"
        {
          voice_score: 0.5,
          tone_score: 0.5,
          messaging_score: 0.5,
          voice_analysis: "Analysis failed",
          tone_analysis: "Analysis failed",
          messaging_analysis: "Analysis failed",
          specific_violations: [],
          strengths: [],
          overall_assessment: "Could not complete analysis",
          confidence: 0.2
        }
      end
    end

    def perform_rule_based_analysis(content, brand)
      violations = []
      scores = { voice: 1.0, tone: 1.0, messaging: 1.0 }

      # Check for common brand violations
      violations.concat(check_language_violations(content, brand))
      violations.concat(check_tone_violations(content, brand))
      violations.concat(check_messaging_violations(content, brand))

      # Calculate rule-based scores
      if violations.any?
        severity_impact = violations.sum { |v| severity_to_impact(v[:severity]) }
        total_deduction = [ severity_impact * 0.1, 0.5 ].min # Max 50% deduction

        scores[:voice] = [ 1.0 - total_deduction, 0.0 ].max
        scores[:tone] = [ 1.0 - total_deduction, 0.0 ].max
        scores[:messaging] = [ 1.0 - total_deduction, 0.0 ].max
      end

      {
        violations: violations,
        scores: scores,
        confidence: 0.9 # Rule-based analysis is more confident
      }
    end

    def check_language_violations(content, brand)
      violations = []

      # Check for overly promotional language if brand guidelines prohibit it
      promotional_phrases = [ "amazing", "incredible", "unbelievable", "best ever", "revolutionary" ]
      promotional_phrases.each do |phrase|
        if content.downcase.include?(phrase.downcase)
          violations << {
            type: "language_violation",
            severity: "medium",
            description: "Contains potentially overly promotional language: '#{phrase}'",
            suggestion: "Consider using more measured, professional language"
          }
        end
      end

      violations
    end

    def check_tone_violations(content, brand)
      violations = []

      # Check for tone consistency based on brand voice profile
      if brand.brand_voice_profiles.exists?
        voice_profile = brand.brand_voice_profiles.first
        tone_descriptors = voice_profile.tone_descriptors || []

        # Check for informal language if brand is formal
        if tone_descriptors.include?("formal") || tone_descriptors.include?("professional")
          informal_patterns = [ "gonna", "wanna", "yeah", "awesome", "cool" ]
          informal_patterns.each do |pattern|
            if content.downcase.include?(pattern)
              violations << {
                type: "tone_mismatch",
                severity: "high",
                description: "Informal language '#{pattern}' conflicts with professional brand tone",
                suggestion: "Use more formal, professional language"
              }
            end
          end
        end
      end

      violations
    end

    def check_messaging_violations(content, brand)
      violations = []

      # Check messaging consistency with framework
      if brand.messaging_framework&.value_propositions.present?
        value_props = brand.messaging_framework.value_propositions

        # This is a simplified check - in practice you'd use more sophisticated text analysis
        has_value_prop_reference = value_props.any? do |prop|
          content.downcase.include?(prop.downcase[0..20]) # Check first 20 chars
        end

        unless has_value_prop_reference
          violations << {
            type: "messaging_inconsistency",
            severity: "low",
            description: "Content doesn't clearly reference brand value propositions",
            suggestion: "Consider incorporating key brand value propositions"
          }
        end
      end

      violations
    end

    def severity_to_impact(severity)
      case severity.to_s
      when "low" then 1
      when "medium" then 2
      when "high" then 3
      else 1
      end
    end

    def calculate_overall_compliance_score(llm_analysis, rule_based_analysis)
      # Weight LLM analysis more heavily but incorporate rule-based checks
      llm_weight = 0.7
      rule_weight = 0.3

      llm_overall = (llm_analysis[:voice_score] + llm_analysis[:tone_score] + llm_analysis[:messaging_score]) / 3.0
      rule_overall = (rule_based_analysis[:scores][:voice] + rule_based_analysis[:scores][:tone] + rule_based_analysis[:scores][:messaging]) / 3.0

      (llm_overall * llm_weight + rule_overall * rule_weight).round(3)
    end

    def compile_violations(llm_analysis, rule_based_analysis)
      violations = []

      # Add LLM-detected violations
      violations.concat(llm_analysis[:specific_violations] || [])

      # Add rule-based violations
      violations.concat(rule_based_analysis[:violations] || [])

      # Deduplicate similar violations
      deduplicate_violations(violations)
    end

    def generate_compliance_suggestions(llm_analysis, rule_based_analysis)
      suggestions = []

      # Extract suggestions from violations
      all_violations = compile_violations(llm_analysis, rule_based_analysis)
      suggestions.concat(all_violations.map { |v| v[:suggestion] }.compact)

      # Add general improvement suggestions based on scores
      if llm_analysis[:voice_score] < 0.8
        suggestions << "Review brand voice guidelines and adjust language to better match brand personality"
      end

      if llm_analysis[:tone_score] < 0.8
        suggestions << "Adjust tone to better align with brand communication style"
      end

      if llm_analysis[:messaging_score] < 0.8
        suggestions << "Incorporate more brand-specific messaging and value propositions"
      end

      suggestions.uniq
    end

    def calculate_confidence_score(llm_analysis, rule_based_analysis)
      # Combine confidence scores from both analyses
      llm_confidence = llm_analysis[:confidence] || 0.8
      rule_confidence = rule_based_analysis[:confidence] || 0.9

      # Weight by analysis type
      (llm_confidence * 0.6 + rule_confidence * 0.4).round(3)
    end

    def deduplicate_violations(violations)
      # Simple deduplication based on description similarity
      unique_violations = []

      violations.each do |violation|
        unless unique_violations.any? { |uv| similar_violations?(uv, violation) }
          unique_violations << violation
        end
      end

      unique_violations
    end

    def similar_violations?(violation1, violation2)
      # Simple similarity check - could be enhanced with more sophisticated text comparison
      return false unless violation1[:type] == violation2[:type]

      desc1 = violation1[:description].to_s.downcase
      desc2 = violation2[:description].to_s.downcase

      # Check if descriptions have significant overlap
      words1 = desc1.split
      words2 = desc2.split
      common_words = words1 & words2

      return false if words1.empty? || words2.empty?

      similarity = common_words.length.to_f / [ words1.length, words2.length ].max
      similarity > 0.5
    end
  end
end
