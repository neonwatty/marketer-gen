module LlmIntegration
  class RealTimeBrandValidator
    include ActiveModel::Model

    def initialize(brand)
      @brand = brand
      @compliance_checker = BrandComplianceChecker.new
    end

    def validate(content)
      # Perform real-time validation of content against brand guidelines
      start_time = Time.current

      # Get compliance check
      compliance_result = @compliance_checker.check_compliance(content, @brand)

      # Determine if content is compliant
      is_compliant = compliance_result[:overall_score] >= 0.9
      confidence = compliance_result[:confidence] || 0.95

      # Extract violations
      violations = extract_validation_violations(compliance_result)

      validation_time = Time.current - start_time

      {
        compliant: is_compliant,
        confidence: confidence,
        violations: violations,
        overall_score: compliance_result[:overall_score],
        voice_score: compliance_result[:voice_compliance],
        tone_score: compliance_result[:tone_compliance],
        messaging_score: compliance_result[:messaging_compliance],
        validation_time: validation_time,
        suggestions: compliance_result[:suggestions] || [],
        timestamp: Time.current
      }
    end

    def validate_in_real_time(content_stream)
      # For streaming validation (placeholder for real-time streaming)
      # This would be used for real-time content editing scenarios

      # For now, validate the complete content
      validate(content_stream)
    end

    def get_validation_rules
      # Return the validation rules used for this brand
      rules = []

      # Voice rules
      if @brand.brand_voice_profiles.exists?
        voice_profile = @brand.brand_voice_profiles.first

        rules << {
          category: "voice",
          type: "required_traits",
          criteria: voice_profile.primary_traits,
          description: "Content must embody these voice traits: #{voice_profile.primary_traits.join(', ')}"
        }

        rules << {
          category: "tone",
          type: "required_tone",
          criteria: voice_profile.tone_descriptors,
          description: "Content must use this tone: #{voice_profile.tone_descriptors.join(', ')}"
        }
      end

      # Guideline rules
      @brand.brand_guidelines.active.each do |guideline|
        rules << {
          category: guideline.category,
          type: "guideline_compliance",
          criteria: guideline.content,
          description: "Must comply with #{guideline.category} guideline: #{guideline.content[0..100]}..."
        }
      end

      rules
    end

    private

    def extract_validation_violations(compliance_result)
      violations = compliance_result[:violations] || []

      # Format violations for real-time validation response
      violations.map do |violation|
        {
          type: map_violation_type(violation[:type]),
          severity: violation[:severity] || "medium",
          message: violation[:description] || "Compliance issue detected",
          suggestion: violation[:suggestion],
          location: violation[:location], # Could be enhanced to show position in text
          rule_violated: violation[:rule] || "Brand compliance"
        }
      end
    end

    def map_violation_type(original_type)
      case original_type
      when "voice_mismatch"
        "tone_mismatch"
      when "tone_issue"
        "tone_mismatch"
      when "messaging_inconsistency"
        "messaging_inconsistency"
      else
        original_type || "general"
      end
    end
  end
end
