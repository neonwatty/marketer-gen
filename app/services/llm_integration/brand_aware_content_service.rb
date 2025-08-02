module LlmIntegration
  class BrandAwareContentService
    include ActiveModel::Model

    def initialize(brand)
      @brand = brand
      @voice_extractor = BrandVoiceExtractor.new
      @compliance_checker = BrandComplianceChecker.new
      @multi_provider = MultiProviderService.new
      @brand_integration = BrandSystemIntegration.new
    end

    def extract_brand_context
      # Get brand voice profile or create one
      voice_profile = @brand.brand_voice_profiles.first || create_voice_profile

      # Extract comprehensive brand context
      {
        voice_characteristics: voice_profile.voice_characteristics,
        tone_guidelines: extract_tone_guidelines,
        messaging_pillars: extract_messaging_pillars,
        brand_guidelines: compile_brand_guidelines,
        communication_style: voice_profile.communication_style,
        brand_personality: voice_profile.brand_personality,
        target_audience_insights: extract_audience_insights,
        content_restrictions: extract_content_restrictions,
        preferred_language_patterns: extract_language_patterns
      }
    end

    def generate_content(content_request)
      # Extract brand context
      brand_context = extract_brand_context

      # Build brand-aware prompt
      enhanced_prompt = build_brand_aware_prompt(content_request, brand_context)

      # Generate content with brand guidelines
      generation_options = {
        model: select_optimal_model(content_request),
        temperature: determine_temperature(content_request),
        max_tokens: calculate_max_tokens(content_request),
        system_message: build_brand_system_message(brand_context)
      }

      # Generate content
      result = @multi_provider.generate_content(enhanced_prompt, generation_options)

      # Check brand compliance
      compliance_result = @compliance_checker.check_compliance(result[:content], @brand)

      # Apply brand guidelines if compliance is low
      if compliance_result[:overall_score] < 0.9
        result[:content] = improve_brand_compliance(result[:content], compliance_result, brand_context)
        # Re-check compliance
        compliance_result = @compliance_checker.check_compliance(result[:content], @brand)
      end

      # Prepare final result
      {
        content: result[:content],
        brand_compliance_score: compliance_result[:overall_score],
        applied_guidelines: extract_applied_guidelines(brand_context),
        generation_metadata: {
          provider_used: result[:provider_used],
          generation_time: result[:generation_time],
          failover_occurred: result[:failover_occurred],
          content_type: content_request[:content_type],
          brand_voice_version: brand_context[:voice_characteristics]["version"]
        },
        compliance_details: compliance_result
      }
    end

    def validate_content_compliance(content)
      @compliance_checker.check_compliance(content, @brand)
    end

    def improve_content_for_brand(content, target_score = 0.95)
      suggestion_engine = ContentSuggestionEngine.new(@brand)
      current_score = validate_content_compliance(content)[:overall_score]

      return content if current_score >= target_score

      # Get improvement suggestions
      suggestions = suggestion_engine.generate_suggestions(content)

      # Apply suggestions iteratively
      improved_content = content
      suggestions.each do |suggestion|
        improved_content = apply_suggestion(improved_content, suggestion)
        new_score = validate_content_compliance(improved_content)[:overall_score]

        # Stop if we've reached the target score
        break if new_score >= target_score
      end

      improved_content
    end

    private

    def create_voice_profile
      # Extract voice profile from existing brand materials
      brand_materials = collect_brand_materials
      voice_characteristics = @voice_extractor.extract_voice_profile(brand_materials)

      LlmIntegration::BrandVoiceProfile.create!(
        brand: @brand,
        voice_characteristics: voice_characteristics,
        extracted_from_sources: [ "brand_guidelines", "existing_content" ],
        confidence_score: calculate_extraction_confidence(voice_characteristics),
        last_updated: Time.current,
        version: 1
      )
    end

    def collect_brand_materials
      materials = []

      # Collect from brand guidelines
      @brand.brand_guidelines.active.each do |guideline|
        materials << {
          source: "brand_guidelines",
          category: guideline.category,
          content: guideline.content
        }
      end

      # Collect from messaging framework
      if @brand.messaging_framework
        materials << {
          source: "messaging_framework",
          content: @brand.messaging_framework.value_propositions.to_s
        }
      end

      # Collect from existing brand analyses
      if @brand.latest_analysis
        materials << {
          source: "brand_analysis",
          content: @brand.latest_analysis.voice_attributes.to_s
        }
      end

      materials.join("\n\n")
    end

    def extract_tone_guidelines
      guidelines = @brand.brand_guidelines.where(category: "tone").active
      guidelines.map(&:content).join(". ")
    end

    def extract_messaging_pillars
      return [] unless @brand.messaging_framework

      framework = @brand.messaging_framework
      pillars = []

      pillars << framework.unique_value_proposition if framework.unique_value_proposition.present?
      pillars.concat(framework.value_propositions || [])
      pillars.concat(framework.key_messages || [])

      pillars.compact.uniq
    end

    def compile_brand_guidelines
      @brand.brand_guidelines.active.map do |guideline|
        "#{guideline.category.humanize}: #{guideline.content}"
      end.join("\n")
    end

    def extract_audience_insights
      # This could integrate with persona data if available
      {
        primary_audience: @brand.target_audience || "professionals",
        communication_preferences: "direct and informative",
        expertise_level: "intermediate to advanced"
      }
    end

    def extract_content_restrictions
      restrictions = []

      # Look for restriction guidelines
      restriction_guidelines = @brand.brand_guidelines.where(category: "restrictions").active
      restrictions.concat(restriction_guidelines.map(&:content))

      # Add common restrictions
      restrictions << "Avoid overly promotional language"
      restrictions << "Maintain professional credibility"

      restrictions
    end

    def extract_language_patterns
      voice_profile = @brand.brand_voice_profiles.first
      return {} unless voice_profile

      voice_profile.language_preferences || {}
    end

    def build_brand_aware_prompt(content_request, brand_context)
      base_prompt = content_request[:prompt] || generate_base_prompt(content_request)

      brand_instructions = []
      brand_instructions << "Brand Voice: #{brand_context[:voice_characteristics]['primary_traits']&.join(', ')}"
      brand_instructions << "Tone: #{brand_context[:voice_characteristics]['tone_descriptors']&.join(', ')}"
      brand_instructions << "Communication Style: #{brand_context[:communication_style]}"
      brand_instructions << "Brand Personality: #{brand_context[:brand_personality]}"

      if brand_context[:messaging_pillars].any?
        brand_instructions << "Key Messages: #{brand_context[:messaging_pillars].first(3).join(', ')}"
      end

      enhanced_prompt = "#{base_prompt}\n\nBRAND GUIDELINES:\n#{brand_instructions.join("\n")}"

      # Add content-type specific instructions
      case content_request[:content_type].to_sym
      when :social_media_post
        enhanced_prompt += "\n\nOptimize for social media engagement while maintaining brand voice."
      when :email_subject
        enhanced_prompt += "\n\nCreate compelling email subject line that reflects brand personality."
      when :ad_copy
        enhanced_prompt += "\n\nFocus on brand differentiation and value proposition."
      end

      enhanced_prompt
    end

    def build_brand_system_message(brand_context)
      personality = brand_context[:brand_personality]
      voice_traits = brand_context[:voice_characteristics]["primary_traits"]&.join(", ") || "professional"

      "You are a brand expert creating content for a #{personality} brand. " \
      "Your writing should embody these characteristics: #{voice_traits}. " \
      "Ensure all content aligns with the brand's voice, tone, and messaging guidelines. " \
      "Maintain consistency with the brand's communication style and target audience expectations."
    end

    def select_optimal_model(content_request)
      # Select model based on content type and complexity
      case content_request[:content_type].to_sym
      when :blog_post, :landing_page_content
        "gpt-4-turbo-preview" # More creative content
      when :email_subject, :social_media_post
        "gpt-3.5-turbo" # Shorter, punchier content
      when :ad_copy
        "claude-3-opus-20240229" # High-quality persuasive content
      else
        "gpt-4-turbo-preview" # Default to high-quality model
      end
    end

    def determine_temperature(content_request)
      # Adjust temperature based on content type
      case content_request[:content_type].to_sym
      when :social_media_post, :ad_copy
        0.8 # More creative
      when :email_subject, :blog_title
        0.7 # Balanced
      when :legal_copy, :technical_content
        0.3 # More conservative
      else
        0.7 # Default balanced approach
      end
    end

    def calculate_max_tokens(content_request)
      # Set token limits based on content type
      case content_request[:content_type].to_sym
      when :email_subject
        50
      when :social_media_post
        200
      when :ad_copy
        300
      when :blog_title
        100
      when :landing_page_headline
        150
      else
        500 # Default
      end
    end

    def improve_brand_compliance(content, compliance_result, brand_context)
      # Identify specific compliance issues
      violations = compliance_result[:violations] || []

      # Build improvement prompt
      improvement_prompt = build_improvement_prompt(content, violations, brand_context)

      # Generate improved version
      result = @multi_provider.generate_content(
        improvement_prompt,
        {
          model: "gpt-4-turbo-preview",
          temperature: 0.5,
          max_tokens: 500
        }
      )

      result[:content] || content # Fallback to original if improvement fails
    end

    def build_improvement_prompt(content, violations, brand_context)
      voice_instructions = brand_context[:voice_characteristics]["primary_traits"]&.join(", ") || "professional"
      tone_instructions = brand_context[:voice_characteristics]["tone_descriptors"]&.join(", ") || "confident"

      prompt = "Improve the following content to better align with brand guidelines:\n\n"
      prompt += "ORIGINAL CONTENT:\n#{content}\n\n"
      prompt += "BRAND REQUIREMENTS:\n"
      prompt += "- Voice: #{voice_instructions}\n"
      prompt += "- Tone: #{tone_instructions}\n"
      prompt += "- Style: #{brand_context[:communication_style]}\n\n"

      if violations.any?
        prompt += "ISSUES TO FIX:\n"
        violations.each { |v| prompt += "- #{v[:description]}\n" }
        prompt += "\n"
      end

      prompt += "Provide only the improved content that addresses these issues while maintaining the original intent."

      prompt
    end

    def extract_applied_guidelines(brand_context)
      guidelines = []

      if brand_context[:voice_characteristics]["primary_traits"]
        guidelines << "Applied voice traits: #{brand_context[:voice_characteristics]['primary_traits'].join(', ')}"
      end

      if brand_context[:tone_guidelines].present?
        guidelines << "Tone guidance: #{brand_context[:tone_guidelines]}"
      end

      guidelines << "Communication style: #{brand_context[:communication_style]}"
      guidelines << "Brand personality: #{brand_context[:brand_personality]}"

      guidelines
    end

    def generate_base_prompt(content_request)
      case content_request[:content_type].to_sym
      when :social_media_post
        "Create an engaging social media post about #{content_request[:topic] || 'our latest update'}"
      when :email_subject
        "Write a compelling email subject line for #{content_request[:topic] || 'our announcement'}"
      when :ad_copy
        "Create persuasive advertising copy for #{content_request[:topic] || 'our product'}"
      else
        "Create #{content_request[:content_type].to_s.humanize.downcase} content about #{content_request[:topic] || 'our offering'}"
      end
    end

    def calculate_extraction_confidence(voice_characteristics)
      # Calculate confidence based on completeness of extracted characteristics
      required_fields = %w[primary_traits tone_descriptors communication_style brand_personality]
      present_fields = required_fields.count { |field| voice_characteristics[field].present? }

      base_confidence = present_fields.to_f / required_fields.length

      # Bonus for specificity
      trait_count = voice_characteristics["primary_traits"]&.length || 0
      tone_count = voice_characteristics["tone_descriptors"]&.length || 0
      specificity_bonus = [ (trait_count + tone_count) * 0.05, 0.2 ].min

      [ base_confidence + specificity_bonus, 1.0 ].min
    end

    def apply_suggestion(content, suggestion)
      # Apply a specific brand compliance suggestion
      return content unless suggestion[:suggested_text].present?

      if suggestion[:current_text].present?
        content.gsub(suggestion[:current_text], suggestion[:suggested_text])
      else
        content # Return original if we can't apply the suggestion
      end
    end
  end
end
