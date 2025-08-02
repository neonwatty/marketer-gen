module LlmIntegration
  class BrandVoiceExtractor
    include ActiveModel::Model

    def initialize
      @llm_service = LlmService.new(model: "gpt-4-turbo-preview")
    end

    def extract_voice_profile(brand_materials)
      # Analyze brand materials to extract voice characteristics
      analysis_prompt = build_voice_extraction_prompt(brand_materials)

      response = @llm_service.analyze(analysis_prompt, json_response: true, temperature: 0.3)

      parsed_response = parse_voice_analysis_response(response)

      # Validate and structure the voice profile
      {
        "primary_traits" => extract_primary_traits(parsed_response),
        "tone_descriptors" => extract_tone_descriptors(parsed_response),
        "communication_style" => extract_communication_style(parsed_response),
        "brand_personality" => extract_brand_personality(parsed_response),
        "language_preferences" => extract_language_preferences(parsed_response),
        "content_themes" => extract_content_themes(parsed_response),
        "audience_approach" => extract_audience_approach(parsed_response),
        "confidence_indicators" => calculate_extraction_confidence(parsed_response)
      }
    end

    def apply_voice_to_prompt(base_prompt:, voice_profile:, content_brief:)
      # Apply voice profile characteristics to enhance a content generation prompt
      voice_instructions = build_voice_instructions(voice_profile)
      context_instructions = build_context_instructions(content_brief)

      enhanced_prompt = <<~PROMPT
        #{base_prompt}

        BRAND VOICE REQUIREMENTS:
        #{voice_instructions}

        CONTENT CONTEXT:
        #{context_instructions}

        Ensure the content reflects the specified brand voice characteristics while meeting the content requirements.
      PROMPT

      enhanced_prompt.strip
    end

    def compare_voice_profiles(profile1, profile2)
      # Compare two voice profiles for similarity
      trait_similarity = calculate_array_similarity(
        profile1["primary_traits"] || [],
        profile2["primary_traits"] || []
      )

      tone_similarity = calculate_array_similarity(
        profile1["tone_descriptors"] || [],
        profile2["tone_descriptors"] || []
      )

      style_similarity = profile1["communication_style"] == profile2["communication_style"] ? 1.0 : 0.0
      personality_similarity = profile1["brand_personality"] == profile2["brand_personality"] ? 1.0 : 0.0

      overall_similarity = (trait_similarity * 0.4) +
                          (tone_similarity * 0.3) +
                          (style_similarity * 0.15) +
                          (personality_similarity * 0.15)

      {
        overall_similarity: overall_similarity.round(3),
        trait_similarity: trait_similarity.round(3),
        tone_similarity: tone_similarity.round(3),
        style_match: style_similarity == 1.0,
        personality_match: personality_similarity == 1.0,
        differences: identify_voice_differences(profile1, profile2)
      }
    end

    def validate_voice_profile(voice_profile)
      # Validate the completeness and consistency of a voice profile
      errors = []
      warnings = []

      # Check required fields
      required_fields = %w[primary_traits tone_descriptors communication_style brand_personality]
      required_fields.each do |field|
        if voice_profile[field].blank?
          errors << "Missing required field: #{field}"
        end
      end

      # Check for consistency
      traits = voice_profile["primary_traits"] || []
      tone = voice_profile["tone_descriptors"] || []
      style = voice_profile["communication_style"]
      personality = voice_profile["brand_personality"]

      # Check for conflicting characteristics
      if traits.include?("formal") && tone.include?("casual")
        warnings << "Potential conflict: formal traits with casual tone"
      end

      if traits.include?("conservative") && tone.include?("edgy")
        warnings << "Potential conflict: conservative traits with edgy tone"
      end

      # Check for sufficient detail
      if traits.length < 2
        warnings << "Consider adding more primary traits for better definition"
      end

      if tone.length < 2
        warnings << "Consider adding more tone descriptors for better clarity"
      end

      {
        valid: errors.empty?,
        errors: errors,
        warnings: warnings,
        completeness_score: calculate_completeness_score(voice_profile)
      }
    end

    private

    def build_voice_extraction_prompt(brand_materials)
      <<~PROMPT
        Analyze the following brand materials to extract the brand's voice and communication characteristics.

        BRAND MATERIALS:
        #{brand_materials}

        Please analyze these materials and extract the brand voice profile with the following JSON structure:
        {
          "primary_traits": ["list of 3-5 core brand voice characteristics"],
          "tone_descriptors": ["list of 3-5 tone descriptors"],
          "communication_style": "overall communication approach (e.g., 'direct and informative', 'conversational and approachable')",
          "brand_personality": "primary brand personality type (e.g., 'expert advisor', 'innovative leader', 'trusted partner')",
          "language_preferences": {
            "complexity_level": "simple|moderate|sophisticated",
            "sentence_structure": "short|varied|complex",#{' '}
            "vocabulary_style": "everyday|professional|technical",
            "emotional_tone": "neutral|warm|energetic|serious"
          },
          "content_themes": ["common themes and topics the brand focuses on"],
          "audience_approach": "how the brand typically addresses its audience",
          "confidence_level": 0.0-1.0,
          "extraction_notes": "any notable observations about the brand voice"
        }

        Focus on identifying:
        1. Consistent voice characteristics across materials
        2. Tone patterns and emotional qualities
        3. Communication style and approach
        4. Language complexity and vocabulary choices
        5. How the brand positions itself relative to its audience
      PROMPT
    end

    def parse_voice_analysis_response(response)
      begin
        if response.is_a?(String)
          JSON.parse(response)
        else
          response
        end
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse voice analysis response: #{e.message}"
        # Return default structure
        {
          "primary_traits" => [ "professional" ],
          "tone_descriptors" => [ "confident" ],
          "communication_style" => "professional",
          "brand_personality" => "expert",
          "language_preferences" => {},
          "content_themes" => [],
          "audience_approach" => "direct",
          "confidence_level" => 0.3
        }
      end
    end

    def extract_primary_traits(parsed_response)
      traits = parsed_response["primary_traits"] || []
      # Validate and clean traits
      cleaned_traits = traits.select { |trait| trait.is_a?(String) && trait.length > 2 }
      cleaned_traits.empty? ? [ "professional" ] : cleaned_traits.uniq.first(5)
    end

    def extract_tone_descriptors(parsed_response)
      descriptors = parsed_response["tone_descriptors"] || []
      # Validate and clean descriptors
      cleaned_descriptors = descriptors.select { |desc| desc.is_a?(String) && desc.length > 2 }
      cleaned_descriptors.empty? ? [ "confident" ] : cleaned_descriptors.uniq.first(5)
    end

    def extract_communication_style(parsed_response)
      style = parsed_response["communication_style"]
      return "professional" unless style.is_a?(String) && style.length > 5
      style
    end

    def extract_brand_personality(parsed_response)
      personality = parsed_response["brand_personality"]
      return "expert" unless personality.is_a?(String) && personality.length > 3
      personality
    end

    def extract_language_preferences(parsed_response)
      prefs = parsed_response["language_preferences"] || {}
      return {} unless prefs.is_a?(Hash)

      # Validate each preference
      validated_prefs = {}

      if prefs["complexity_level"] && %w[simple moderate sophisticated].include?(prefs["complexity_level"])
        validated_prefs["complexity_level"] = prefs["complexity_level"]
      end

      if prefs["sentence_structure"] && %w[short varied complex].include?(prefs["sentence_structure"])
        validated_prefs["sentence_structure"] = prefs["sentence_structure"]
      end

      if prefs["vocabulary_style"] && %w[everyday professional technical].include?(prefs["vocabulary_style"])
        validated_prefs["vocabulary_style"] = prefs["vocabulary_style"]
      end

      if prefs["emotional_tone"] && %w[neutral warm energetic serious].include?(prefs["emotional_tone"])
        validated_prefs["emotional_tone"] = prefs["emotional_tone"]
      end

      validated_prefs
    end

    def extract_content_themes(parsed_response)
      themes = parsed_response["content_themes"] || []
      themes.select { |theme| theme.is_a?(String) && theme.length > 3 }.uniq.first(10)
    end

    def extract_audience_approach(parsed_response)
      approach = parsed_response["audience_approach"]
      return "professional" unless approach.is_a?(String) && approach.length > 3
      approach
    end

    def calculate_extraction_confidence(parsed_response)
      confidence = parsed_response["confidence_level"] || 0.5

      # Validate confidence is a number between 0 and 1
      if confidence.is_a?(Numeric) && confidence.between?(0, 1)
        confidence
      else
        0.5
      end
    end

    def build_voice_instructions(voice_profile)
      instructions = []

      if voice_profile["primary_traits"]&.any?
        instructions << "Voice Traits: Embody these characteristics - #{voice_profile['primary_traits'].join(', ')}"
      end

      if voice_profile["tone_descriptors"]&.any?
        instructions << "Tone: Use a #{voice_profile['tone_descriptors'].join(', ')} tone"
      end

      if voice_profile["communication_style"]
        instructions << "Communication Style: #{voice_profile['communication_style']}"
      end

      if voice_profile["brand_personality"]
        instructions << "Brand Personality: Write as a #{voice_profile['brand_personality']}"
      end

      # Add language preferences
      lang_prefs = voice_profile["language_preferences"] || {}
      if lang_prefs.any?
        pref_instructions = []
        pref_instructions << "complexity: #{lang_prefs['complexity_level']}" if lang_prefs["complexity_level"]
        pref_instructions << "vocabulary: #{lang_prefs['vocabulary_style']}" if lang_prefs["vocabulary_style"]
        pref_instructions << "emotional tone: #{lang_prefs['emotional_tone']}" if lang_prefs["emotional_tone"]

        if pref_instructions.any?
          instructions << "Language Preferences: #{pref_instructions.join(', ')}"
        end
      end

      instructions.join("\n")
    end

    def build_context_instructions(content_brief)
      instructions = []

      instructions << "Target Audience: #{content_brief[:audience]}" if content_brief[:audience]
      instructions << "Content Goal: #{content_brief[:goal]}" if content_brief[:goal]
      instructions << "Channel: #{content_brief[:channel]}" if content_brief[:channel]
      instructions << "Key Message: #{content_brief[:message]}" if content_brief[:message]

      instructions.join("\n")
    end

    def calculate_array_similarity(array1, array2)
      return 0.0 if array1.empty? && array2.empty?
      return 0.0 if array1.empty? || array2.empty?

      intersection = (array1.map(&:downcase) & array2.map(&:downcase)).length
      union = (array1.map(&:downcase) | array2.map(&:downcase)).length

      intersection.to_f / union
    end

    def identify_voice_differences(profile1, profile2)
      differences = []

      # Compare traits
      traits1 = (profile1["primary_traits"] || []).map(&:downcase)
      traits2 = (profile2["primary_traits"] || []).map(&:downcase)

      unique_to_1 = traits1 - traits2
      unique_to_2 = traits2 - traits1

      if unique_to_1.any?
        differences << "Profile 1 has unique traits: #{unique_to_1.join(', ')}"
      end

      if unique_to_2.any?
        differences << "Profile 2 has unique traits: #{unique_to_2.join(', ')}"
      end

      # Compare communication styles
      if profile1["communication_style"] != profile2["communication_style"]
        differences << "Different communication styles: '#{profile1['communication_style']}' vs '#{profile2['communication_style']}'"
      end

      # Compare personalities
      if profile1["brand_personality"] != profile2["brand_personality"]
        differences << "Different brand personalities: '#{profile1['brand_personality']}' vs '#{profile2['brand_personality']}'"
      end

      differences
    end

    def calculate_completeness_score(voice_profile)
      # Calculate how complete the voice profile is
      total_fields = 7 # Total expected fields
      present_fields = 0

      required_fields = %w[primary_traits tone_descriptors communication_style brand_personality]
      required_fields.each do |field|
        present_fields += 1 if voice_profile[field].present?
      end

      # Bonus for optional fields
      optional_fields = %w[language_preferences content_themes audience_approach]
      optional_fields.each do |field|
        present_fields += 0.5 if voice_profile[field].present?
      end

      # Bonus for detail level
      trait_count = (voice_profile["primary_traits"] || []).length
      tone_count = (voice_profile["tone_descriptors"] || []).length
      detail_bonus = [ (trait_count + tone_count) * 0.1, 1.0 ].min

      base_score = [ present_fields / total_fields.to_f, 1.0 ].min
      (base_score + detail_bonus).round(3)
    end
  end
end
