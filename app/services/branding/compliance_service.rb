module Branding
  class ComplianceService
    attr_reader :brand, :content, :content_type

    COMPLIANCE_THRESHOLDS = {
      high: 0.9,
      medium: 0.7,
      low: 0.5
    }.freeze

    def initialize(brand, content, content_type = "general")
      @brand = brand
      @content = content
      @content_type = content_type
      @violations = []
      @suggestions = []
      @score = 0.0
    end

    def check_compliance
      return build_response(false, "No content provided") if content.blank?
      return build_response(false, "No brand specified") if brand.blank?

      # Run all compliance checks
      check_banned_words
      check_tone_compliance
      check_messaging_alignment
      check_style_guidelines
      check_required_elements
      check_visual_compliance if visual_content?

      # Calculate overall compliance score
      calculate_compliance_score

      build_response(true)
    end

    def validate_and_suggest
      result = check_compliance
      
      if result[:compliant]
        result[:suggestions] = generate_improvements
      else
        result[:corrections] = generate_corrections
      end
      
      result
    end

    private

    def check_banned_words
      messaging_framework = brand.messaging_framework
      return unless messaging_framework

      banned_words = messaging_framework.get_banned_words_in_text(content)
      
      if banned_words.any?
        add_violation(
          type: "banned_words",
          severity: "high",
          message: "Content contains banned words: #{banned_words.join(', ')}",
          details: banned_words
        )
      end
    end

    def check_tone_compliance
      analysis = brand.latest_analysis
      return unless analysis

      expected_tone = analysis.voice_attributes.dig("tone", "primary")
      detected_tone = analyze_content_tone

      if tone_mismatch?(expected_tone, detected_tone)
        add_violation(
          type: "tone_mismatch",
          severity: "medium",
          message: "Content tone (#{detected_tone}) doesn't match brand tone (#{expected_tone})",
          details: {
            expected: expected_tone,
            detected: detected_tone
          }
        )
      end
    end

    def check_messaging_alignment
      messaging_framework = brand.messaging_framework
      return unless messaging_framework

      key_messages = messaging_framework.key_messages.values.flatten
      value_props = messaging_framework.value_propositions["main"] || []

      alignment_score = calculate_message_alignment(key_messages + value_props)

      if alignment_score < 0.3
        add_violation(
          type: "messaging_misalignment",
          severity: "medium",
          message: "Content doesn't align well with brand key messages",
          details: {
            alignment_score: alignment_score,
            missing_themes: identify_missing_themes(key_messages)
          }
        )
      elsif alignment_score < 0.6
        add_suggestion(
          type: "messaging_improvement",
          message: "Consider incorporating more brand key messages",
          details: {
            current_alignment: alignment_score,
            suggested_themes: identify_missing_themes(key_messages).first(3)
          }
        )
      end
    end

    def check_style_guidelines
      guidelines = brand.brand_guidelines.active.by_category("style")
      
      guidelines.each do |guideline|
        if guideline.mandatory? && !content_follows_guideline?(guideline)
          add_violation(
            type: "style_violation",
            severity: guideline.priority >= 8 ? "high" : "medium",
            message: "Violates style guideline: #{guideline.rule_content}",
            details: {
              rule_type: guideline.rule_type,
              guideline_id: guideline.id
            }
          )
        end
      end
    end

    def check_required_elements
      required_guidelines = brand.brand_guidelines.mandatory_rules
      
      required_guidelines.each do |guideline|
        next if content_includes_required_element?(guideline)
        
        add_violation(
          type: "missing_required_element",
          severity: "high",
          message: "Missing required element: #{guideline.rule_content}",
          details: {
            guideline_id: guideline.id,
            category: guideline.category
          }
        )
      end
    end

    def check_visual_compliance
      # Placeholder for visual content compliance checks
      # Would check colors, fonts, logo usage, etc.
    end

    def analyze_content_tone
      # Simplified tone detection - in production would use NLP
      formal_indicators = %w[therefore however furthermore consequently]
      casual_indicators = %w[hey gonna wanna cool awesome]
      
      content_lower = content.downcase
      
      formal_count = formal_indicators.count { |word| content_lower.include?(word) }
      casual_count = casual_indicators.count { |word| content_lower.include?(word) }
      
      if formal_count > casual_count * 2
        "formal"
      elsif casual_count > formal_count * 2
        "casual"
      else
        "neutral"
      end
    end

    def tone_mismatch?(expected, detected)
      tone_compatibility = {
        "formal" => ["formal", "professional"],
        "professional" => ["formal", "professional", "neutral"],
        "friendly" => ["friendly", "casual", "neutral"],
        "casual" => ["casual", "friendly"]
      }
      
      compatible_tones = tone_compatibility[expected] || [expected]
      !compatible_tones.include?(detected)
    end

    def calculate_message_alignment(key_messages)
      return 0.0 if key_messages.empty?
      
      content_lower = content.downcase
      matched_messages = key_messages.count do |message|
        message_words = message.downcase.split(/\W+/)
        message_words.any? { |word| content_lower.include?(word) }
      end
      
      matched_messages.to_f / key_messages.size
    end

    def identify_missing_themes(key_messages)
      content_lower = content.downcase
      
      key_messages.reject do |message|
        message_words = message.downcase.split(/\W+/)
        message_words.any? { |word| content_lower.include?(word) }
      end
    end

    def content_follows_guideline?(guideline)
      case guideline.rule_type
      when "do", "must"
        # Check if content follows positive guideline
        guideline_keywords = extract_keywords(guideline.rule_content)
        guideline_keywords.any? { |keyword| content.downcase.include?(keyword.downcase) }
      when "dont", "avoid"
        # Check if content avoids negative guideline
        guideline_keywords = extract_keywords(guideline.rule_content)
        guideline_keywords.none? { |keyword| content.downcase.include?(keyword.downcase) }
      else
        true
      end
    end

    def content_includes_required_element?(guideline)
      return true unless guideline.rule_type == "must"
      
      # Check if required element is present
      required_keywords = extract_keywords(guideline.rule_content)
      required_keywords.any? { |keyword| content.downcase.include?(keyword.downcase) }
    end

    def extract_keywords(text)
      # Extract meaningful keywords from guideline text
      stop_words = %w[the a an and or but in on at to for of with as by]
      
      text.downcase
          .split(/\W+/)
          .reject { |word| stop_words.include?(word) || word.length < 3 }
    end

    def calculate_compliance_score
      return 1.0 if @violations.empty?
      
      # Weight violations by severity
      severity_weights = { high: 1.0, medium: 0.5, low: 0.25 }
      
      total_weight = @violations.sum do |violation|
        severity_weights[violation[:severity].to_sym] || 0.5
      end
      
      # Calculate score (0-1 scale)
      max_possible_violations = 10.0 # Assumed maximum
      @score = [1.0 - (total_weight / max_possible_violations), 0].max
    end

    def generate_improvements
      improvements = []
      
      # Suggest incorporating more key messages if alignment is moderate
      if @score > 0.7 && @score < 0.9
        improvements << {
          type: "enhance_messaging",
          suggestion: "Consider adding more brand-specific value propositions",
          priority: "low"
        }
      end
      
      # Suggest tone adjustments
      if @suggestions.any? { |s| s[:type] == "tone_adjustment" }
        improvements << {
          type: "refine_tone",
          suggestion: "Fine-tune the tone to better match brand voice",
          priority: "medium"
        }
      end
      
      improvements + @suggestions
    end

    def generate_corrections
      @violations.map do |violation|
        {
          type: violation[:type],
          correction: suggest_correction_for(violation),
          priority: violation[:severity],
          details: violation[:details]
        }
      end
    end

    def suggest_correction_for(violation)
      case violation[:type]
      when "banned_words"
        "Replace the following banned words: #{violation[:details].join(', ')}"
      when "tone_mismatch"
        "Adjust tone from #{violation[:details][:detected]} to #{violation[:details][:expected]}"
      when "missing_required_element"
        "Add required element: #{violation[:message]}"
      when "style_violation"
        "Follow style guideline: #{violation[:message]}"
      else
        "Address issue: #{violation[:message]}"
      end
    end

    def visual_content?
      %w[image video infographic].include?(content_type)
    end

    def add_violation(type:, severity:, message:, details: {})
      @violations << {
        type: type,
        severity: severity,
        message: message,
        details: details,
        timestamp: Time.current
      }
    end

    def add_suggestion(type:, message:, details: {})
      @suggestions << {
        type: type,
        message: message,
        details: details,
        timestamp: Time.current
      }
    end

    def build_response(success, error_message = nil)
      if success
        {
          compliant: @violations.empty?,
          score: @score,
          violations: @violations,
          suggestions: @suggestions,
          summary: compliance_summary
        }
      else
        {
          compliant: false,
          score: 0,
          error: error_message,
          violations: [],
          suggestions: []
        }
      end
    end

    def compliance_summary
      if @violations.empty?
        "Content is fully compliant with brand guidelines."
      elsif @score >= COMPLIANCE_THRESHOLDS[:high]
        "Content is highly compliant with minor adjustments needed."
      elsif @score >= COMPLIANCE_THRESHOLDS[:medium]
        "Content is moderately compliant. Several improvements recommended."
      elsif @score >= COMPLIANCE_THRESHOLDS[:low]
        "Content has compliance issues that should be addressed."
      else
        "Content has significant compliance violations requiring major revisions."
      end
    end
  end
end