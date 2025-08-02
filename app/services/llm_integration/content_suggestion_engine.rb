module LlmIntegration
  class ContentSuggestionEngine
    include ActiveModel::Model

    def initialize(brand)
      @brand = brand
      @llm_service = LlmService.new(model: "gpt-4-turbo-preview")
      @compliance_checker = BrandComplianceChecker.new
    end

    def generate_suggestions(content)
      # Analyze current content for improvement opportunities
      compliance_result = @compliance_checker.check_compliance(content, @brand)

      # Generate targeted suggestions based on compliance gaps
      suggestions = []

      # Add suggestions based on compliance violations
      suggestions.concat(generate_violation_based_suggestions(compliance_result))

      # Add general improvement suggestions
      suggestions.concat(generate_general_improvements(content))

      # Add brand-specific suggestions
      suggestions.concat(generate_brand_specific_suggestions(content))

      # Score and prioritize suggestions
      scored_suggestions = score_suggestions(suggestions, compliance_result)

      # Return top suggestions
      scored_suggestions.sort_by { |s| -s[:brand_alignment_score] }
    end

    private

    def generate_violation_based_suggestions(compliance_result)
      suggestions = []

      violations = compliance_result[:violations] || []

      violations.each do |violation|
        case violation[:type]
        when "voice_mismatch"
          suggestions << create_voice_suggestion(violation)
        when "tone_issue"
          suggestions << create_tone_suggestion(violation)
        when "messaging_inconsistency"
          suggestions << create_messaging_suggestion(violation)
        end
      end

      suggestions.compact
    end

    def create_voice_suggestion(violation)
      voice_profile = @brand.brand_voice_profiles.first
      return nil unless voice_profile

      primary_traits = voice_profile.primary_traits.join(", ")

      {
        issue_type: "voice_alignment",
        current_text: extract_problematic_text(violation),
        suggested_text: nil, # Will be generated
        improvement_reason: "Adjust language to better reflect brand voice traits: #{primary_traits}",
        brand_alignment_score: 0.8,
        implementation_effort: "medium",
        expected_impact: "high"
      }
    end

    def create_tone_suggestion(violation)
      voice_profile = @brand.brand_voice_profiles.first
      return nil unless voice_profile

      tone_descriptors = voice_profile.tone_descriptors.join(", ")

      {
        issue_type: "tone_adjustment",
        current_text: extract_problematic_text(violation),
        suggested_text: nil, # Will be generated
        improvement_reason: "Adjust tone to be more #{tone_descriptors}",
        brand_alignment_score: 0.75,
        implementation_effort: "low",
        expected_impact: "medium"
      }
    end

    def create_messaging_suggestion(violation)
      messaging_framework = @brand.messaging_framework
      return nil unless messaging_framework

      key_messages = messaging_framework.key_messages || []

      {
        issue_type: "messaging_enhancement",
        current_text: extract_problematic_text(violation),
        suggested_text: nil, # Will be generated
        improvement_reason: "Incorporate key brand messages: #{key_messages.first(2).join(', ')}",
        brand_alignment_score: 0.85,
        implementation_effort: "high",
        expected_impact: "high"
      }
    end

    def generate_general_improvements(content)
      suggestions = []

      # Check for readability improvements
      if content.split(".").any? { |sentence| sentence.split.length > 25 }
        suggestions << {
          issue_type: "readability",
          current_text: nil,
          suggested_text: nil,
          improvement_reason: "Break down complex sentences for better readability",
          brand_alignment_score: 0.6,
          implementation_effort: "medium",
          expected_impact: "medium"
        }
      end

      # Check for engagement improvements
      if !content.include?("?") && content.length > 100
        suggestions << {
          issue_type: "engagement",
          current_text: nil,
          suggested_text: nil,
          improvement_reason: "Add questions or interactive elements to increase engagement",
          brand_alignment_score: 0.7,
          implementation_effort: "low",
          expected_impact: "medium"
        }
      end

      # Check for call-to-action
      cta_keywords = [ "click", "learn more", "contact", "get started", "try", "download", "subscribe" ]
      has_cta = cta_keywords.any? { |keyword| content.downcase.include?(keyword) }

      unless has_cta
        suggestions << {
          issue_type: "call_to_action",
          current_text: nil,
          suggested_text: nil,
          improvement_reason: "Add a clear call-to-action to drive user engagement",
          brand_alignment_score: 0.8,
          implementation_effort: "low",
          expected_impact: "high"
        }
      end

      suggestions
    end

    def generate_brand_specific_suggestions(content)
      suggestions = []

      # Check value proposition integration
      messaging_framework = @brand.messaging_framework
      if messaging_framework&.unique_value_proposition.present?
        uvp = messaging_framework.unique_value_proposition

        # Simple check if UVP is referenced
        unless content.downcase.include?(uvp.downcase[0..20])
          suggestions << {
            issue_type: "value_proposition",
            current_text: nil,
            suggested_text: nil,
            improvement_reason: "Consider incorporating the unique value proposition: #{uvp[0..50]}...",
            brand_alignment_score: 0.9,
            implementation_effort: "high",
            expected_impact: "high"
          }
        end
      end

      # Check brand personality alignment
      voice_profile = @brand.brand_voice_profiles.first
      if voice_profile
        personality = voice_profile.brand_personality

        case personality
        when "expert"
          unless content.include?("experience") || content.include?("expertise") || content.include?("proven")
            suggestions << {
              issue_type: "personality_alignment",
              current_text: nil,
              suggested_text: nil,
              improvement_reason: "Emphasize expertise and experience to align with expert brand personality",
              brand_alignment_score: 0.75,
              implementation_effort: "medium",
              expected_impact: "medium"
            }
          end
        when "innovative"
          unless content.include?("innovation") || content.include?("cutting-edge") || content.include?("advanced")
            suggestions << {
              issue_type: "personality_alignment",
              current_text: nil,
              suggested_text: nil,
              improvement_reason: "Highlight innovation and forward-thinking to align with innovative brand personality",
              brand_alignment_score: 0.75,
              implementation_effort: "medium",
              expected_impact: "medium"
            }
          end
        end
      end

      suggestions
    end

    def score_suggestions(suggestions, compliance_result)
      suggestions.map do |suggestion|
        # Calculate brand alignment score based on current compliance
        base_score = suggestion[:brand_alignment_score] || 0.5

        # Adjust based on current compliance gaps
        if compliance_result[:overall_score] < 0.8
          case suggestion[:issue_type]
          when "voice_alignment", "tone_adjustment"
            base_score += 0.1
          when "messaging_enhancement"
            base_score += 0.15
          end
        end

        # Adjust based on implementation effort vs impact
        effort_score = case suggestion[:implementation_effort]
        when "low" then 0.1
        when "medium" then 0.05
        when "high" then 0.0
        else 0.05
        end

        impact_score = case suggestion[:expected_impact]
        when "high" then 0.15
        when "medium" then 0.1
        when "low" then 0.05
        else 0.1
        end

        suggestion[:brand_alignment_score] = [ base_score + effort_score + impact_score, 1.0 ].min
        suggestion
      end
    end

    def extract_problematic_text(violation)
      # Extract the specific text that caused the violation
      # This is a simplified implementation
      violation[:current_text] || violation[:context] || nil
    end
  end
end
