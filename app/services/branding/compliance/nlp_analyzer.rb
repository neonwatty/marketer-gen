module Branding
  module Compliance
    class NlpAnalyzer < BaseValidator
      ANALYSIS_TYPES = %i[
        tone sentiment readability brand_alignment 
        keyword_density emotion style coherence
      ].freeze

      def initialize(brand, content, options = {})
        super
        @llm_service = options[:llm_service] || LlmService.new
        @analysis_cache = {}
      end

      def validate
        analyze_all_aspects
        
        # Check tone compliance
        check_tone_compliance
        
        # Check sentiment alignment
        check_sentiment_alignment
        
        # Check readability standards
        check_readability_standards
        
        # Check brand voice alignment
        check_brand_voice_alignment
        
        # Check messaging consistency
        check_messaging_consistency
        
        # Analyze emotional resonance
        check_emotional_resonance
        
        # Check style consistency
        check_style_consistency
        
        { violations: @violations, suggestions: @suggestions, analysis: @analysis_cache }
      end

      def analyze_aspect(aspect_type)
        return @analysis_cache[aspect_type] if @analysis_cache[aspect_type]
        
        analysis = case aspect_type
        when :tone then analyze_tone
        when :sentiment then analyze_sentiment
        when :readability then analyze_readability
        when :brand_alignment then analyze_brand_alignment
        when :keyword_density then analyze_keyword_density
        when :emotion then analyze_emotion
        when :style then analyze_style
        when :coherence then analyze_coherence
        else
          raise ArgumentError, "Unknown analysis type: #{aspect_type}"
        end
        
        @analysis_cache[aspect_type] = analysis
        analysis
      end

      private

      def analyze_all_aspects
        ANALYSIS_TYPES.each { |type| analyze_aspect(type) }
      end

      def analyze_tone
        cached_result("tone_analysis") do
          prompt = build_tone_analysis_prompt
          
          response = @llm_service.analyze(prompt, {
            json_response: true,
            temperature: 0.3,
            system_message: "You are an expert content analyst specializing in tone and voice analysis."
          })
          
          parse_json_response(response) || default_tone_analysis
        end
      end

      def analyze_sentiment
        cached_result("sentiment_analysis") do
          prompt = build_sentiment_analysis_prompt
          
          response = @llm_service.analyze(prompt, {
            json_response: true,
            temperature: 0.2
          })
          
          parse_json_response(response) || default_sentiment_analysis
        end
      end

      def analyze_readability
        cached_result("readability_analysis") do
          # Calculate various readability metrics
          {
            flesch_kincaid_score: calculate_flesch_kincaid,
            gunning_fog_index: calculate_gunning_fog,
            average_sentence_length: calculate_average_sentence_length,
            average_word_length: calculate_average_word_length,
            complex_word_percentage: calculate_complex_word_percentage,
            readability_grade: determine_readability_grade
          }
        end
      end

      def analyze_brand_alignment
        cached_result("brand_alignment_analysis") do
          prompt = build_brand_alignment_prompt
          
          response = @llm_service.analyze(prompt, {
            json_response: true,
            temperature: 0.4,
            max_tokens: 1500
          })
          
          parse_json_response(response) || default_brand_alignment
        end
      end

      def analyze_keyword_density
        cached_result("keyword_density_analysis") do
          keywords = extract_brand_keywords
          content_words = tokenize_content
          
          density_map = {}
          keywords.each do |keyword|
            count = content_words.count { |word| word.downcase == keyword.downcase }
            density = (count.to_f / content_words.length * 100).round(2)
            density_map[keyword] = {
              count: count,
              density: density,
              optimal_range: determine_optimal_density(keyword)
            }
          end
          
          {
            keyword_densities: density_map,
            total_keywords: keywords.length,
            content_length: content_words.length
          }
        end
      end

      def analyze_emotion
        cached_result("emotion_analysis") do
          prompt = build_emotion_analysis_prompt
          
          response = @llm_service.analyze(prompt, {
            json_response: true,
            temperature: 0.5
          })
          
          parse_json_response(response) || default_emotion_analysis
        end
      end

      def analyze_style
        cached_result("style_analysis") do
          {
            sentence_variety: analyze_sentence_variety,
            paragraph_structure: analyze_paragraph_structure,
            transition_usage: analyze_transitions,
            active_passive_ratio: calculate_active_passive_ratio,
            formality_level: detect_formality_level
          }
        end
      end

      def analyze_coherence
        cached_result("coherence_analysis") do
          prompt = build_coherence_analysis_prompt
          
          response = @llm_service.analyze(prompt, {
            json_response: true,
            temperature: 0.3
          })
          
          parse_json_response(response) || default_coherence_analysis
        end
      end

      # Validation checks
      def check_tone_compliance
        tone_analysis = analyze_aspect(:tone)
        expected_tone = brand.latest_analysis&.voice_attributes&.dig("tone", "primary") || "professional"
        
        detected_tone = tone_analysis[:primary_tone]
        confidence = tone_analysis[:confidence]
        
        if !tone_compatible?(detected_tone, expected_tone)
          add_violation(
            type: "tone_mismatch",
            severity: confidence > 0.8 ? "high" : "medium",
            message: "Content tone '#{detected_tone}' doesn't match brand tone '#{expected_tone}'",
            details: {
              expected: expected_tone,
              detected: detected_tone,
              confidence: confidence,
              secondary_tones: tone_analysis[:secondary_tones]
            }
          )
        elsif confidence < 0.6
          add_suggestion(
            type: "tone_clarity",
            message: "Consider strengthening the #{expected_tone} tone",
            details: {
              current_confidence: confidence,
              detected_tones: tone_analysis[:all_tones]
            }
          )
        end
      end

      def check_sentiment_alignment
        sentiment = analyze_aspect(:sentiment)
        brand_sentiment = brand.latest_analysis&.sentiment_profile || { "positive" => 0.7 }
        
        sentiment_score = sentiment[:overall_score]
        expected_range = determine_expected_sentiment_range(brand_sentiment)
        
        if !sentiment_score.between?(expected_range[:min], expected_range[:max])
          add_violation(
            type: "sentiment_misalignment",
            severity: "medium",
            message: "Content sentiment (#{sentiment_score.round(2)}) outside brand range (#{expected_range[:min]}-#{expected_range[:max]})",
            details: {
              current_sentiment: sentiment_score,
              expected_range: expected_range,
              sentiment_breakdown: sentiment[:breakdown]
            }
          )
        end
      end

      def check_readability_standards
        readability = analyze_aspect(:readability)
        target_grade = brand.brand_guidelines.by_category("readability").first&.metadata&.dig("target_grade") || 8
        
        current_grade = readability[:readability_grade]
        
        if (current_grade - target_grade).abs > 2
          severity = (current_grade - target_grade).abs > 4 ? "high" : "medium"
          
          add_violation(
            type: "readability_mismatch",
            severity: severity,
            message: "Readability grade #{current_grade} significantly differs from target #{target_grade}",
            details: {
              current_grade: current_grade,
              target_grade: target_grade,
              metrics: readability
            }
          )
        elsif (current_grade - target_grade).abs > 1
          add_suggestion(
            type: "readability_adjustment",
            message: "Consider adjusting readability closer to grade #{target_grade}",
            details: {
              current_grade: current_grade,
              suggestions: suggest_readability_improvements(readability, target_grade)
            }
          )
        end
      end

      def check_brand_voice_alignment
        alignment = analyze_aspect(:brand_alignment)
        alignment_score = alignment[:overall_score] || 0
        
        if alignment_score < 0.5
          add_violation(
            type: "brand_voice_misalignment",
            severity: "high",
            message: "Content doesn't align well with brand voice (#{(alignment_score * 100).round}% match)",
            details: {
              alignment_score: alignment_score,
              missing_elements: alignment[:missing_elements],
              conflicting_elements: alignment[:conflicting_elements]
            }
          )
        elsif alignment_score < 0.7
          add_suggestion(
            type: "brand_voice_enhancement",
            message: "Strengthen brand voice elements",
            details: {
              current_score: alignment_score,
              improvement_areas: alignment[:improvement_suggestions]
            },
            priority: "high"
          )
        end
      end

      def check_messaging_consistency
        brand_messages = extract_brand_messages
        alignment = analyze_aspect(:brand_alignment)
        
        missing_messages = alignment[:missing_key_messages] || []
        
        if missing_messages.length > brand_messages.length * 0.5
          add_violation(
            type: "key_message_absence",
            severity: "medium",
            message: "Missing #{missing_messages.length} key brand messages",
            details: {
              missing_messages: missing_messages,
              total_expected: brand_messages.length
            }
          )
        elsif missing_messages.any?
          add_suggestion(
            type: "message_incorporation",
            message: "Consider incorporating these key messages",
            details: {
              missing_messages: missing_messages.first(3)
            }
          )
        end
      end

      def check_emotional_resonance
        emotion = analyze_aspect(:emotion)
        target_emotions = brand.latest_analysis&.emotional_targets || ["trust", "confidence"]
        
        detected_emotions = emotion[:primary_emotions] || []
        emotion_match = (detected_emotions & target_emotions).length.to_f / target_emotions.length
        
        if emotion_match < 0.3
          add_violation(
            type: "emotional_disconnect",
            severity: "medium",
            message: "Content doesn't evoke target brand emotions",
            details: {
              target_emotions: target_emotions,
              detected_emotions: detected_emotions,
              match_percentage: (emotion_match * 100).round
            }
          )
        elsif emotion_match < 0.6
          add_suggestion(
            type: "emotional_enhancement",
            message: "Strengthen emotional connection with brand values",
            details: {
              current_emotions: detected_emotions,
              target_emotions: target_emotions,
              suggestions: suggest_emotional_improvements(emotion, target_emotions)
            }
          )
        end
      end

      def check_style_consistency
        style = analyze_aspect(:style)
        guidelines = brand.brand_guidelines.by_category("style")
        
        # Check sentence variety
        if style[:sentence_variety][:score] < 0.4
          add_suggestion(
            type: "sentence_variety",
            message: "Vary sentence structure for better flow",
            details: {
              current_variety: style[:sentence_variety],
              suggestions: ["Mix short and long sentences", "Use different sentence openings"]
            }
          )
        end
        
        # Check formality level
        expected_formality = guidelines.find { |g| g.metadata&.dig("formality_level") }&.metadata&.dig("formality_level") || "moderate"
        if !formality_matches?(style[:formality_level], expected_formality)
          add_violation(
            type: "formality_mismatch",
            severity: "low",
            message: "Formality level '#{style[:formality_level]}' doesn't match expected '#{expected_formality}'",
            details: {
              current: style[:formality_level],
              expected: expected_formality
            }
          )
        end
      end

      # Helper methods
      def build_tone_analysis_prompt
        <<~PROMPT
          Analyze the tone of the following content and provide a detailed assessment.
          
          Content:
          #{content}
          
          Provide analysis in this JSON structure:
          {
            "primary_tone": "professional|casual|formal|friendly|authoritative|conversational|etc",
            "secondary_tones": ["tone1", "tone2"],
            "confidence": 0.0-1.0,
            "all_tones": {
              "tone_name": confidence_score
            },
            "tone_consistency": 0.0-1.0,
            "tone_shifts": [
              {
                "position": "paragraph/sentence reference",
                "from_tone": "tone1",
                "to_tone": "tone2"
              }
            ]
          }
        PROMPT
      end

      def build_sentiment_analysis_prompt
        <<~PROMPT
          Analyze the sentiment of the following content.
          
          Content:
          #{content}
          
          Provide analysis in this JSON structure:
          {
            "overall_score": -1.0 to 1.0,
            "breakdown": {
              "positive": 0.0-1.0,
              "negative": 0.0-1.0,
              "neutral": 0.0-1.0
            },
            "sentiment_flow": [
              {
                "section": "identifier",
                "score": -1.0 to 1.0
              }
            ],
            "emotional_words": {
              "positive": ["word1", "word2"],
              "negative": ["word1", "word2"]
            }
          }
        PROMPT
      end

      def build_brand_alignment_prompt
        brand_voice = brand.brand_voice_attributes
        key_messages = brand.messaging_framework&.key_messages || {}
        
        <<~PROMPT
          Analyze how well the content aligns with the brand voice and messaging.
          
          Content:
          #{content}
          
          Brand Voice Attributes:
          #{brand_voice.to_json}
          
          Key Messages:
          #{key_messages.to_json}
          
          Provide analysis in this JSON structure:
          {
            "overall_score": 0.0-1.0,
            "voice_alignment": {
              "matching_attributes": ["attribute1", "attribute2"],
              "missing_attributes": ["attribute1", "attribute2"],
              "conflicting_attributes": ["attribute1", "attribute2"]
            },
            "message_alignment": {
              "incorporated_messages": ["message1", "message2"],
              "missing_key_messages": ["message1", "message2"],
              "message_clarity": 0.0-1.0
            },
            "improvement_suggestions": [
              {
                "area": "voice|messaging|tone",
                "suggestion": "specific improvement",
                "priority": "high|medium|low"
              }
            ],
            "missing_elements": ["element1", "element2"],
            "conflicting_elements": ["element1", "element2"]
          }
        PROMPT
      end

      def build_emotion_analysis_prompt
        <<~PROMPT
          Analyze the emotional content and impact of the following text.
          
          Content:
          #{content}
          
          Provide analysis in this JSON structure:
          {
            "primary_emotions": ["emotion1", "emotion2", "emotion3"],
            "emotion_intensity": {
              "emotion_name": 0.0-1.0
            },
            "emotional_arc": [
              {
                "section": "beginning|middle|end",
                "dominant_emotion": "emotion",
                "intensity": 0.0-1.0
              }
            ],
            "emotional_triggers": [
              {
                "phrase": "triggering phrase",
                "emotion": "triggered emotion",
                "strength": 0.0-1.0
              }
            ]
          }
        PROMPT
      end

      def build_coherence_analysis_prompt
        <<~PROMPT
          Analyze the coherence and logical flow of the following content.
          
          Content:
          #{content}
          
          Provide analysis in this JSON structure:
          {
            "overall_coherence": 0.0-1.0,
            "logical_flow": 0.0-1.0,
            "topic_consistency": 0.0-1.0,
            "transition_quality": 0.0-1.0,
            "issues": [
              {
                "type": "logical_gap|topic_shift|unclear_transition",
                "location": "paragraph/sentence reference",
                "severity": "high|medium|low",
                "suggestion": "how to fix"
              }
            ],
            "strengths": ["strength1", "strength2"]
          }
        PROMPT
      end

      def parse_json_response(response)
        return nil if response.nil? || response.empty?
        
        begin
          if response.is_a?(String)
            JSON.parse(response, symbolize_names: true)
          else
            response
          end
        rescue JSON::ParserError => e
          Rails.logger.error "Failed to parse LLM JSON response: #{e.message}"
          nil
        end
      end

      def calculate_flesch_kincaid
        sentences = content.split(/[.!?]+/).reject(&:blank?)
        words = tokenize_content
        syllables = words.sum { |word| count_syllables(word) }
        
        return 0 if sentences.empty? || words.empty?
        
        score = 206.835 - 1.015 * (words.length.to_f / sentences.length) - 84.6 * (syllables.to_f / words.length)
        score.round(1)
      end

      def calculate_gunning_fog
        sentences = content.split(/[.!?]+/).reject(&:blank?)
        words = tokenize_content
        complex_words = words.count { |word| count_syllables(word) >= 3 }
        
        return 0 if sentences.empty? || words.empty?
        
        score = 0.4 * ((words.length.to_f / sentences.length) + 100 * (complex_words.to_f / words.length))
        score.round(1)
      end

      def calculate_average_sentence_length
        sentences = content.split(/[.!?]+/).reject(&:blank?)
        words = tokenize_content
        
        return 0 if sentences.empty?
        
        (words.length.to_f / sentences.length).round(1)
      end

      def calculate_average_word_length
        words = tokenize_content
        return 0 if words.empty?
        
        total_length = words.sum(&:length)
        (total_length.to_f / words.length).round(1)
      end

      def calculate_complex_word_percentage
        words = tokenize_content
        complex_words = words.count { |word| count_syllables(word) >= 3 }
        
        return 0 if words.empty?
        
        ((complex_words.to_f / words.length) * 100).round(1)
      end

      def determine_readability_grade
        flesch_score = calculate_flesch_kincaid
        
        case flesch_score
        when 90..100 then 5
        when 80..89 then 6
        when 70..79 then 7
        when 60..69 then 8
        when 50..59 then 10
        when 30..49 then 13
        when 0..29 then 16
        else 12
        end
      end

      def tokenize_content
        content.downcase.gsub(/[^\w\s]/, ' ').split.reject { |w| w.length < 2 }
      end

      def count_syllables(word)
        return 1 if word.length <= 3
        
        word = word.downcase
        vowels = "aeiouy"
        syllable_count = 0
        previous_was_vowel = false
        
        word.each_char do |char|
          is_vowel = vowels.include?(char)
          if is_vowel && !previous_was_vowel
            syllable_count += 1
          end
          previous_was_vowel = is_vowel
        end
        
        # Adjust for silent e
        syllable_count -= 1 if word.end_with?('e') && syllable_count > 1
        
        [syllable_count, 1].max
      end

      def analyze_sentence_variety
        sentences = content.split(/[.!?]+/).reject(&:blank?)
        return { score: 0, variety: "none" } if sentences.empty?
        
        lengths = sentences.map { |s| s.split.length }
        
        # Calculate standard deviation
        mean = lengths.sum.to_f / lengths.length
        variance = lengths.sum { |l| (l - mean) ** 2 } / lengths.length
        std_dev = Math.sqrt(variance)
        
        # Normalize to 0-1 score
        variety_score = [std_dev / mean, 1.0].min
        
        {
          score: variety_score.round(2),
          variety: case variety_score
                   when 0..0.2 then "very_low"
                   when 0.2..0.4 then "low"
                   when 0.4..0.6 then "moderate"
                   when 0.6..0.8 then "good"
                   else "excellent"
                   end,
          stats: {
            mean_length: mean.round(1),
            std_deviation: std_dev.round(1),
            min_length: lengths.min,
            max_length: lengths.max
          }
        }
      end

      def analyze_paragraph_structure
        paragraphs = content.split(/\n\n+/).reject(&:blank?)
        
        {
          count: paragraphs.length,
          average_length: paragraphs.sum { |p| p.split.length } / paragraphs.length.to_f,
          consistency: calculate_paragraph_consistency(paragraphs)
        }
      end

      def analyze_transitions
        transition_words = %w[
          however therefore furthermore moreover consequently 
          additionally nevertheless nonetheless meanwhile
          alternatively subsequently thus hence accordingly
        ]
        
        sentences = content.split(/[.!?]+/)
        transitions_used = 0
        
        sentences.each do |sentence|
          sentence_lower = sentence.downcase
          transitions_used += 1 if transition_words.any? { |t| sentence_lower.include?(t) }
        end
        
        {
          count: transitions_used,
          percentage: (transitions_used.to_f / sentences.length * 100).round(1),
          quality: transitions_used > sentences.length * 0.2 ? "good" : "needs_improvement"
        }
      end

      def calculate_active_passive_ratio
        # Simplified active/passive detection
        passive_indicators = /\b(was|were|been|being|is|are|am)\s+\w+ed\b/
        sentences = content.split(/[.!?]+/)
        
        passive_count = sentences.count { |s| s.match?(passive_indicators) }
        active_count = sentences.length - passive_count
        
        {
          active: active_count,
          passive: passive_count,
          ratio: active_count.to_f / [passive_count, 1].max
        }
      end

      def detect_formality_level
        formal_indicators = %w[therefore furthermore consequently thus hence moreover]
        informal_indicators = %w[gonna wanna gotta kinda sorta yeah yep nope]
        contractions = /\b\w+'(ll|ve|re|d|s|t)\b/
        
        content_lower = content.downcase
        
        formal_score = formal_indicators.count { |word| content_lower.include?(word) }
        informal_score = informal_indicators.count { |word| content_lower.include?(word) }
        informal_score += content.scan(contractions).length
        
        if formal_score > informal_score * 2
          "formal"
        elsif informal_score > formal_score * 2
          "informal"
        elsif formal_score > informal_score
          "moderate_formal"
        elsif informal_score > formal_score
          "moderate_informal"
        else
          "neutral"
        end
      end

      def tone_compatible?(detected, expected)
        compatible_tones = {
          "professional" => ["professional", "formal", "authoritative"],
          "casual" => ["casual", "conversational", "friendly"],
          "friendly" => ["friendly", "casual", "conversational", "warm"],
          "formal" => ["formal", "professional", "authoritative"],
          "authoritative" => ["authoritative", "professional", "formal", "expert"]
        }
        
        expected_group = compatible_tones[expected] || [expected]
        expected_group.include?(detected)
      end

      def determine_expected_sentiment_range(brand_sentiment)
        base_positive = brand_sentiment["positive"] || 0.7
        
        {
          min: base_positive - 0.2,
          max: [base_positive + 0.2, 1.0].min
        }
      end

      def suggest_readability_improvements(readability, target_grade)
        suggestions = []
        
        current_grade = readability[:readability_grade]
        
        if current_grade > target_grade
          suggestions << "Simplify complex sentences"
          suggestions << "Use shorter words where possible"
          suggestions << "Break up long paragraphs"
        else
          suggestions << "Add more descriptive language"
          suggestions << "Use more varied vocabulary"
          suggestions << "Combine short, choppy sentences"
        end
        
        suggestions
      end

      def extract_brand_keywords
        keywords = []
        
        # From messaging framework
        if brand.messaging_framework
          keywords += brand.messaging_framework.key_messages.values.flatten
          keywords += brand.messaging_framework.value_propositions.values.flatten
        end
        
        # From brand analysis
        if brand.latest_analysis
          keywords += brand.latest_analysis.keywords || []
        end
        
        keywords.uniq.map(&:downcase)
      end

      def extract_brand_messages
        messages = []
        
        if brand.messaging_framework
          messages += brand.messaging_framework.key_messages.values.flatten
          messages += brand.messaging_framework.value_propositions.values.flatten
        end
        
        messages.uniq
      end

      def determine_optimal_density(keyword)
        # Primary keywords should appear more frequently
        if brand.messaging_framework&.key_messages&.values&.flatten&.include?(keyword)
          { min: 1.0, max: 3.0 }
        else
          { min: 0.5, max: 2.0 }
        end
      end

      def suggest_emotional_improvements(current_emotion, target_emotions)
        suggestions = []
        
        missing_emotions = target_emotions - current_emotion[:primary_emotions]
        
        emotion_techniques = {
          "trust" => "Include testimonials, credentials, or guarantees",
          "excitement" => "Use dynamic language and emphasize benefits",
          "confidence" => "Highlight expertise and success stories",
          "warmth" => "Use personal anecdotes and inclusive language",
          "innovation" => "Emphasize cutting-edge features and forward-thinking"
        }
        
        missing_emotions.each do |emotion|
          if technique = emotion_techniques[emotion]
            suggestions << technique
          end
        end
        
        suggestions
      end

      def formality_matches?(detected, expected)
        formality_groups = {
          "formal" => ["formal", "moderate_formal"],
          "informal" => ["informal", "moderate_informal"],
          "neutral" => ["neutral", "moderate_formal", "moderate_informal"]
        }
        
        expected_group = formality_groups[expected] || [expected]
        expected_group.include?(detected)
      end

      def calculate_paragraph_consistency(paragraphs)
        return 1.0 if paragraphs.length <= 1
        
        lengths = paragraphs.map { |p| p.split.length }
        mean = lengths.sum.to_f / lengths.length
        variance = lengths.sum { |l| (l - mean) ** 2 } / lengths.length
        
        # Lower variance = more consistent
        consistency = 1.0 - ([Math.sqrt(variance) / mean, 1.0].min)
        consistency.round(2)
      end

      # Default analysis results for fallback
      def default_tone_analysis
        {
          primary_tone: "neutral",
          secondary_tones: [],
          confidence: 0.5,
          all_tones: { "neutral" => 0.5 },
          tone_consistency: 0.5,
          tone_shifts: []
        }
      end

      def default_sentiment_analysis
        {
          overall_score: 0.0,
          breakdown: { positive: 0.33, negative: 0.33, neutral: 0.34 },
          sentiment_flow: [],
          emotional_words: { positive: [], negative: [] }
        }
      end

      def default_brand_alignment
        {
          overall_score: 0.5,
          voice_alignment: {
            matching_attributes: [],
            missing_attributes: [],
            conflicting_attributes: []
          },
          message_alignment: {
            incorporated_messages: [],
            missing_key_messages: [],
            message_clarity: 0.5
          },
          improvement_suggestions: [],
          missing_elements: [],
          conflicting_elements: []
        }
      end

      def default_emotion_analysis
        {
          primary_emotions: ["neutral"],
          emotion_intensity: { "neutral" => 0.5 },
          emotional_arc: [],
          emotional_triggers: []
        }
      end

      def default_coherence_analysis
        {
          overall_coherence: 0.5,
          logical_flow: 0.5,
          topic_consistency: 0.5,
          transition_quality: 0.5,
          issues: [],
          strengths: []
        }
      end
    end
  end
end