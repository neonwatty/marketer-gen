module Branding
  module Compliance
    class SuggestionEngine
      attr_reader :brand, :violations, :analysis_results

      def initialize(brand, violations, analysis_results = {})
        @brand = brand
        @violations = violations
        @analysis_results = analysis_results
        @llm_service = LlmService.new
      end

      def generate_suggestions
        suggestions = []
        
        # Group violations by type for pattern analysis
        grouped_violations = group_violations
        
        # Generate contextual suggestions for each violation type
        grouped_violations.each do |type, type_violations|
          suggestions.concat(generate_suggestions_for_type(type, type_violations))
        end
        
        # Add proactive improvements based on analysis
        suggestions.concat(generate_proactive_suggestions)
        
        # Prioritize and deduplicate suggestions
        prioritized_suggestions = prioritize_suggestions(suggestions)
        
        # Generate implementation guidance
        add_implementation_guidance(prioritized_suggestions)
      end

      def generate_fix(violation, content)
        case violation[:type]
        when "banned_words"
          fix_banned_words(violation, content)
        when "tone_mismatch"
          fix_tone_mismatch(violation, content)
        when "missing_required_element"
          fix_missing_element(violation, content)
        when "readability_mismatch"
          fix_readability(violation, content)
        else
          generate_ai_fix(violation, content)
        end
      end

      def suggest_alternatives(phrase, context = {})
        prompt = build_alternatives_prompt(phrase, context)
        
        response = @llm_service.analyze(prompt, {
          json_response: true,
          temperature: 0.7,
          max_tokens: 500
        })
        
        parse_alternatives_response(response)
      end

      private

      def group_violations
        violations.group_by { |v| v[:type] }
      end

      def generate_suggestions_for_type(type, type_violations)
        case type
        when "tone_mismatch"
          generate_tone_suggestions(type_violations)
        when "banned_words"
          generate_vocabulary_suggestions(type_violations)
        when "missing_required_element"
          generate_element_suggestions(type_violations)
        when "readability_mismatch"
          generate_readability_suggestions(type_violations)
        when "brand_voice_misalignment"
          generate_voice_suggestions(type_violations)
        when "color_violation"
          generate_color_suggestions(type_violations)
        when "typography_violation"
          generate_typography_suggestions(type_violations)
        else
          generate_generic_suggestions(type_violations)
        end
      end

      def generate_tone_suggestions(violations)
        suggestions = []
        
        # Analyze the pattern of tone issues
        expected_tones = violations.map { |v| v[:details][:expected] }.uniq
        detected_tones = violations.map { |v| v[:details][:detected] }.uniq
        
        if expected_tones.length == 1
          target_tone = expected_tones.first
          
          suggestions << {
            type: "tone_adjustment",
            priority: "high",
            title: "Align content tone with brand voice",
            description: "Adjust the overall tone to be more #{target_tone}",
            specific_actions: generate_tone_actions(target_tone, detected_tones),
            examples: generate_tone_examples(target_tone),
            effort_level: "medium"
          }
        end
        
        suggestions
      end

      def generate_tone_actions(target_tone, current_tones)
        actions = []
        
        tone_adjustments = {
          "professional" => {
            "casual" => ["Replace contractions with full forms", "Use more formal vocabulary", "Structure sentences more formally"],
            "friendly" => ["Maintain warmth while adding authority", "Use industry terminology appropriately"]
          },
          "friendly" => {
            "formal" => ["Use conversational language", "Add personal pronouns", "Include relatable examples"],
            "professional" => ["Soften technical language", "Add warmth to explanations"]
          },
          "casual" => {
            "formal" => ["Use contractions where appropriate", "Simplify complex sentences", "Add colloquialisms"],
            "professional" => ["Relax the tone while maintaining credibility", "Use everyday language"]
          }
        }
        
        current_tones.each do |current|
          if tone_adjustments[target_tone] && tone_adjustments[target_tone][current]
            actions.concat(tone_adjustments[target_tone][current])
          end
        end
        
        actions.uniq
      end

      def generate_tone_examples(target_tone)
        examples = {
          "professional" => [
            { before: "We're gonna help you out!", after: "We will assist you with your needs." },
            { before: "Check this out!", after: "Please review the following information." }
          ],
          "friendly" => [
            { before: "The user must complete the form.", after: "You'll need to fill out a quick form." },
            { before: "This is required.", after: "We'll need this from you." }
          ],
          "casual" => [
            { before: "We are pleased to announce", after: "Hey, we've got some great news" },
            { before: "Please be advised", after: "Just wanted to let you know" }
          ]
        }
        
        examples[target_tone] || []
      end

      def generate_vocabulary_suggestions(violations)
        suggestions = []
        
        banned_words = violations.flat_map { |v| v[:details] }.uniq
        
        suggestions << {
          type: "vocabulary_replacement",
          priority: "critical",
          title: "Replace prohibited terminology",
          description: "Remove or replace words that conflict with brand guidelines",
          specific_actions: [
            "Review and replace all instances of banned words",
            "Update content to use approved brand terminology",
            "Create a glossary of preferred alternatives"
          ],
          word_replacements: generate_word_replacements(banned_words),
          effort_level: "low"
        }
        
        suggestions
      end

      def generate_word_replacements(banned_words)
        replacements = {}
        
        # Get brand-specific alternatives
        messaging_framework = brand.messaging_framework
        preferred_terms = messaging_framework&.metadata&.dig("preferred_terms") || {}
        
        banned_words.each do |word|
          replacements[word] = find_alternatives_for_word(word, preferred_terms)
        end
        
        replacements
      end

      def find_alternatives_for_word(word, preferred_terms)
        # Check if we have a direct mapping
        return preferred_terms[word] if preferred_terms[word]
        
        # Generate contextual alternatives
        common_replacements = {
          "cheap" => ["affordable", "value-priced", "economical"],
          "expensive" => ["premium", "investment", "high-value"],
          "problem" => ["challenge", "opportunity", "situation"],
          "failure" => ["learning experience", "setback", "area for improvement"]
        }
        
        common_replacements[word.downcase] || ["[Review context for appropriate alternative]"]
      end

      def generate_element_suggestions(violations)
        suggestions = []
        
        missing_elements = violations.map { |v| v[:details][:category] }.uniq
        
        suggestions << {
          type: "content_addition",
          priority: "high",
          title: "Add required brand elements",
          description: "Include mandatory elements missing from the content",
          specific_actions: missing_elements.map { |element| "Add #{element}" },
          templates: generate_element_templates(missing_elements),
          effort_level: "medium"
        }
        
        suggestions
      end

      def generate_element_templates(elements)
        templates = {}
        
        element_mappings = {
          "tagline" => brand.messaging_framework&.taglines&.dig("primary"),
          "disclaimer" => brand.brand_guidelines.by_category("legal").first&.rule_content,
          "contact" => generate_contact_template,
          "cta" => generate_cta_template
        }
        
        elements.each do |element|
          templates[element] = element_mappings[element] || "[Custom content required]"
        end
        
        templates
      end

      def generate_readability_suggestions(violations)
        suggestions = []
        
        readability_issues = violations.first[:details]
        current_grade = readability_issues[:current_grade]
        target_grade = readability_issues[:target_grade]
        
        if current_grade > target_grade
          suggestions << {
            type: "simplification",
            priority: "medium",
            title: "Simplify content for target audience",
            description: "Reduce complexity to match reading level #{target_grade}",
            specific_actions: [
              "Shorten sentences (aim for 15-20 words average)",
              "Replace complex words with simpler alternatives",
              "Break up long paragraphs",
              "Use active voice",
              "Add subheadings for better scanning"
            ],
            examples: generate_simplification_examples,
            effort_level: "high"
          }
        else
          suggestions << {
            type: "sophistication",
            priority: "medium",
            title: "Enhance content sophistication",
            description: "Increase complexity to match reading level #{target_grade}",
            specific_actions: [
              "Use more varied sentence structures",
              "Incorporate industry-specific terminology",
              "Add nuanced explanations",
              "Develop ideas more thoroughly"
            ],
            effort_level: "medium"
          }
        end
        
        suggestions
      end

      def generate_simplification_examples
        [
          {
            before: "The implementation of our comprehensive solution necessitates a thorough evaluation of existing infrastructure.",
            after: "To use our solution, we need to review your current setup."
          },
          {
            before: "Utilize this functionality to optimize your workflow efficiency.",
            after: "Use this feature to work faster."
          }
        ]
      end

      def generate_voice_suggestions(violations)
        suggestions = []
        
        alignment_score = violations.first[:details][:alignment_score]
        missing_elements = violations.first[:details][:missing_elements] || []
        
        suggestions << {
          type: "brand_voice_alignment",
          priority: "high",
          title: "Strengthen brand voice consistency",
          description: "Align content more closely with established brand personality",
          specific_actions: [
            "Incorporate brand personality traits throughout",
            "Use brand-specific phrases and expressions",
            "Mirror the brand's communication style",
            "Include brand storytelling elements"
          ],
          voice_checklist: generate_voice_checklist,
          missing_elements: missing_elements,
          effort_level: "high"
        }
        
        suggestions
      end

      def generate_voice_checklist
        voice_attributes = brand.brand_voice_attributes
        
        checklist = []
        
        voice_attributes.each do |category, attributes|
          attributes.each do |key, value|
            checklist << {
              attribute: "#{category}.#{key}",
              target: value,
              check: "Does the content reflect #{value}?"
            }
          end
        end
        
        checklist
      end

      def generate_color_suggestions(violations)
        suggestions = []
        
        non_compliant_colors = violations.flat_map { |v| v[:details][:non_compliant_colors] }.uniq
        
        suggestions << {
          type: "color_correction",
          priority: "high",
          title: "Align colors with brand palette",
          description: "Replace non-brand colors with approved alternatives",
          specific_actions: [
            "Update all color values to match brand guidelines",
            "Ensure proper color usage hierarchy",
            "Maintain color consistency across all elements"
          ],
          color_mappings: generate_color_mappings(non_compliant_colors),
          effort_level: "low"
        }
        
        suggestions
      end

      def generate_color_mappings(non_compliant_colors)
        mappings = {}
        brand_colors = brand.primary_colors + brand.secondary_colors
        
        non_compliant_colors.each do |color|
          mappings[color] = find_closest_brand_color(color, brand_colors)
        end
        
        mappings
      end

      def find_closest_brand_color(color, brand_colors)
        return brand_colors.first if brand_colors.empty?
        
        # Find the brand color with minimum color distance
        closest = brand_colors.min_by do |brand_color|
          color_distance(color, brand_color)
        end
        
        {
          color: closest,
          distance: color_distance(color, closest).round(2)
        }
      end

      def color_distance(color1, color2)
        # Simplified - would use proper color distance calculation
        0.0
      end

      def generate_typography_suggestions(violations)
        suggestions = []
        
        non_compliant_fonts = violations.flat_map { |v| v[:details][:non_compliant_fonts] }.uniq
        
        suggestions << {
          type: "typography_alignment",
          priority: "medium",
          title: "Update typography to brand standards",
          description: "Use only approved brand fonts",
          specific_actions: [
            "Replace non-brand fonts with approved alternatives",
            "Ensure proper font hierarchy",
            "Apply consistent font sizing and spacing"
          ],
          font_mappings: generate_font_mappings(non_compliant_fonts),
          effort_level: "medium"
        }
        
        suggestions
      end

      def generate_font_mappings(non_compliant_fonts)
        mappings = {}
        brand_fonts = brand.font_families
        
        non_compliant_fonts.each do |font|
          mappings[font] = suggest_brand_font(font, brand_fonts)
        end
        
        mappings
      end

      def suggest_brand_font(font, brand_fonts)
        # Map common fonts to brand alternatives
        font_categories = {
          serif: ["Georgia", "Times New Roman", "Garamond"],
          sans_serif: ["Arial", "Helvetica", "Verdana"],
          monospace: ["Courier", "Consolas", "Monaco"]
        }
        
        # Determine font category
        category = font_categories.find { |_, fonts| fonts.include?(font) }&.first || :sans_serif
        
        # Return appropriate brand font
        brand_fonts[category.to_s] || brand_fonts["primary"] || "Use primary brand font"
      end

      def generate_generic_suggestions(violations)
        violations.map do |violation|
          {
            type: "compliance_fix",
            priority: violation[:severity],
            title: "Address: #{violation[:message]}",
            description: "Fix compliance issue",
            specific_actions: ["Review and correct the identified issue"],
            effort_level: "medium"
          }
        end
      end

      def generate_proactive_suggestions
        suggestions = []
        
        # Based on analysis results, suggest improvements
        if analysis_results[:nlp_analysis]
          suggestions.concat(generate_nlp_based_suggestions)
        end
        
        if analysis_results[:visual_analysis]
          suggestions.concat(generate_visual_based_suggestions)
        end
        
        suggestions
      end

      def generate_nlp_based_suggestions
        suggestions = []
        nlp = analysis_results[:nlp_analysis]
        
        # Suggest improvements based on scores
        if nlp[:tone][:confidence] < 0.8
          suggestions << {
            type: "tone_strengthening",
            priority: "low",
            title: "Strengthen brand tone consistency",
            description: "Make the brand tone more prominent throughout the content",
            specific_actions: [
              "Use more characteristic brand expressions",
              "Maintain consistent tone throughout all sections",
              "Avoid tone shifts mid-content"
            ],
            effort_level: "medium"
          }
        end
        
        if nlp[:keyword_density]
          low_density_keywords = nlp[:keyword_density][:keyword_densities].select do |_, data|
            data[:density] < data[:optimal_range][:min]
          end
          
          if low_density_keywords.any?
            suggestions << {
              type: "keyword_optimization",
              priority: "low",
              title: "Optimize keyword usage",
              description: "Increase usage of important brand keywords",
              keywords_to_increase: low_density_keywords.keys,
              effort_level: "low"
            }
          end
        end
        
        suggestions
      end

      def generate_visual_based_suggestions
        suggestions = []
        # Add visual-specific proactive suggestions
        suggestions
      end

      def prioritize_suggestions(suggestions)
        # Define priority weights
        priority_weights = {
          "critical" => 1000,
          "high" => 100,
          "medium" => 10,
          "low" => 1
        }
        
        # Sort by priority weight
        sorted = suggestions.sort_by do |suggestion|
          -priority_weights[suggestion[:priority]]
        end
        
        # Remove duplicates while preserving order
        sorted.uniq { |s| [s[:type], s[:title]] }
      end

      def add_implementation_guidance(suggestions)
        suggestions.map do |suggestion|
          suggestion[:implementation_guide] = generate_implementation_guide(suggestion)
          suggestion[:estimated_time] = estimate_implementation_time(suggestion)
          suggestion[:automation_possible] = can_automate?(suggestion)
          
          if suggestion[:automation_possible]
            suggestion[:automation_script] = generate_automation_script(suggestion)
          end
          
          suggestion
        end
      end

      def generate_implementation_guide(suggestion)
        case suggestion[:type]
        when "tone_adjustment"
          generate_tone_implementation_guide(suggestion)
        when "vocabulary_replacement"
          generate_vocabulary_implementation_guide(suggestion)
        when "content_addition"
          generate_content_implementation_guide(suggestion)
        else
          generate_generic_implementation_guide(suggestion)
        end
      end

      def generate_tone_implementation_guide(suggestion)
        {
          steps: [
            "Review current content tone using the provided examples",
            "Identify sections that need adjustment",
            "Apply the specific actions listed",
            "Read through the entire content to ensure consistency",
            "Test with sample audience if possible"
          ],
          tools: ["Grammar checker", "Readability analyzer", "Brand voice guide"],
          checkpoints: [
            "All contractions addressed (if formalizing)",
            "Vocabulary matches target tone",
            "Sentence structure aligns with tone",
            "Overall feel matches brand voice"
          ]
        }
      end

      def generate_vocabulary_implementation_guide(suggestion)
        {
          steps: [
            "Use find-and-replace for each banned word",
            "Review context for each replacement",
            "Ensure replacements maintain sentence flow",
            "Update any related phrases or variations",
            "Document replacements for future reference"
          ],
          tools: ["Text editor with find-replace", "Brand terminology guide"],
          checkpoints: [
            "All banned words replaced",
            "Replacements fit context",
            "Content still reads naturally",
            "Brand voice maintained"
          ]
        }
      end

      def generate_content_implementation_guide(suggestion)
        {
          steps: [
            "Locate appropriate positions for missing elements",
            "Use provided templates as starting points",
            "Customize templates to fit content context",
            "Ensure smooth integration with existing content",
            "Verify all required elements are included"
          ],
          tools: ["Brand element templates", "Content guidelines"],
          checkpoints: [
            "All required elements present",
            "Elements properly formatted",
            "Natural integration achieved",
            "Brand consistency maintained"
          ]
        }
      end

      def generate_generic_implementation_guide(suggestion)
        {
          steps: suggestion[:specific_actions],
          tools: ["Brand guidelines", "Style guide"],
          checkpoints: ["Issue resolved", "Brand compliance achieved"]
        }
      end

      def estimate_implementation_time(suggestion)
        base_times = {
          "low" => 15,
          "medium" => 45,
          "high" => 120
        }
        
        base_time = base_times[suggestion[:effort_level]] || 30
        
        # Adjust based on specific factors
        if suggestion[:specific_actions].length > 5
          base_time *= 1.5
        end
        
        if suggestion[:automation_possible]
          base_time *= 0.3
        end
        
        {
          minutes: base_time.round,
          human_readable: format_time(base_time)
        }
      end

      def format_time(minutes)
        if minutes < 60
          "#{minutes.round} minutes"
        else
          hours = (minutes / 60.0).round(1)
          "#{hours} hours"
        end
      end

      def can_automate?(suggestion)
        automatable_types = [
          "vocabulary_replacement",
          "color_correction",
          "typography_alignment"
        ]
        
        automatable_types.include?(suggestion[:type])
      end

      def generate_automation_script(suggestion)
        case suggestion[:type]
        when "vocabulary_replacement"
          generate_replacement_script(suggestion)
        when "color_correction"
          generate_color_script(suggestion)
        when "typography_alignment"
          generate_typography_script(suggestion)
        else
          nil
        end
      end

      def generate_replacement_script(suggestion)
        replacements = suggestion[:word_replacements]
        
        {
          type: "text_replacement",
          description: "Automated word replacement script",
          script: replacements.map do |word, alternatives|
            {
              find: word,
              replace: alternatives.first,
              case_sensitive: false,
              whole_word: true
            }
          end
        }
      end

      def generate_color_script(suggestion)
        mappings = suggestion[:color_mappings]
        
        {
          type: "css_replacement",
          description: "Automated color replacement for CSS",
          script: mappings.map do |old_color, new_color_data|
            {
              find: old_color,
              replace: new_color_data[:color],
              contexts: ["css", "style attributes"]
            }
          end
        }
      end

      def generate_typography_script(suggestion)
        mappings = suggestion[:font_mappings]
        
        {
          type: "font_replacement",
          description: "Automated font replacement",
          script: mappings.map do |old_font, new_font|
            {
              find: old_font,
              replace: new_font,
              preserve_weight: true,
              preserve_style: true
            }
          end
        }
      end

      # Fix generation methods
      def fix_banned_words(violation, content)
        banned_words = violation[:details]
        replacements = generate_word_replacements(banned_words)
        
        fixed_content = content.dup
        
        replacements.each do |word, alternatives|
          regex = /\b#{Regexp.escape(word)}\b/i
          fixed_content.gsub!(regex, alternatives.first)
        end
        
        {
          fixed_content: fixed_content,
          changes_made: replacements,
          confidence: 0.9
        }
      end

      def fix_tone_mismatch(violation, content)
        expected_tone = violation[:details][:expected]
        
        prompt = build_tone_fix_prompt(content, expected_tone)
        
        response = @llm_service.analyze(prompt, {
          temperature: 0.5,
          max_tokens: content.length + 500
        })
        
        {
          fixed_content: response,
          changes_made: ["Adjusted tone to be more #{expected_tone}"],
          confidence: 0.7
        }
      end

      def fix_missing_element(violation, content)
        missing_element = violation[:details][:category]
        template = generate_element_templates([missing_element])[missing_element]
        
        # Determine where to add the element
        if missing_element == "disclaimer" || missing_element == "footer"
          fixed_content = "#{content}\n\n#{template}"
        else
          fixed_content = "#{template}\n\n#{content}"
        end
        
        {
          fixed_content: fixed_content,
          changes_made: ["Added required #{missing_element}"],
          confidence: 0.8
        }
      end

      def fix_readability(violation, content)
        current_grade = violation[:details][:current_grade]
        target_grade = violation[:details][:target_grade]
        
        prompt = build_readability_fix_prompt(content, current_grade, target_grade)
        
        response = @llm_service.analyze(prompt, {
          temperature: 0.3,
          max_tokens: content.length + 500
        })
        
        {
          fixed_content: response,
          changes_made: ["Adjusted readability from grade #{current_grade} to #{target_grade}"],
          confidence: 0.6
        }
      end

      def generate_ai_fix(violation, content)
        prompt = build_generic_fix_prompt(violation, content)
        
        response = @llm_service.analyze(prompt, {
          temperature: 0.4,
          max_tokens: content.length + 500
        })
        
        {
          fixed_content: response,
          changes_made: ["Applied AI-generated fix for #{violation[:type]}"],
          confidence: 0.5
        }
      end

      # Prompt builders
      def build_alternatives_prompt(phrase, context)
        brand_voice = brand.brand_voice_attributes
        
        <<~PROMPT
          Generate alternative phrasings for: "#{phrase}"
          
          Context:
          Content Type: #{context[:content_type]}
          Target Audience: #{context[:audience]}
          Brand Voice: #{brand_voice.to_json}
          
          Provide 3-5 alternatives that:
          1. Maintain the same meaning
          2. Align with brand voice
          3. Fit the context
          4. Vary in style/approach
          
          Format as JSON:
          {
            "alternatives": [
              {
                "text": "alternative phrase",
                "style": "formal|casual|technical|friendly",
                "best_for": "situation where this works best"
              }
            ]
          }
        PROMPT
      end

      def build_tone_fix_prompt(content, target_tone)
        <<~PROMPT
          Rewrite the following content to have a #{target_tone} tone:
          
          #{content}
          
          Guidelines:
          - Maintain all factual information
          - Keep the same structure and flow
          - Adjust vocabulary and sentence structure
          - Ensure consistent #{target_tone} tone throughout
          
          Return only the rewritten content.
        PROMPT
      end

      def build_readability_fix_prompt(content, current_grade, target_grade)
        direction = current_grade > target_grade ? "simplify" : "sophisticate"
        
        <<~PROMPT
          #{direction.capitalize} the following content from grade level #{current_grade} to #{target_grade}:
          
          #{content}
          
          Guidelines:
          - Maintain all key information
          - #{direction == "simplify" ? "Use shorter sentences and simpler words" : "Use more complex sentence structures and vocabulary"}
          - Keep the same overall message
          - Ensure natural flow
          
          Return only the adjusted content.
        PROMPT
      end

      def build_generic_fix_prompt(violation, content)
        <<~PROMPT
          Fix the following compliance issue in the content:
          
          Issue: #{violation[:message]}
          Type: #{violation[:type]}
          Details: #{violation[:details].to_json}
          
          Content:
          #{content}
          
          Guidelines:
          - Address the specific issue identified
          - Maintain content meaning and flow
          - Follow brand guidelines
          - Make minimal necessary changes
          
          Return only the fixed content.
        PROMPT
      end

      def parse_alternatives_response(response)
        return [] unless response
        
        begin
          parsed = JSON.parse(response, symbolize_names: true)
          parsed[:alternatives] || []
        rescue JSON::ParserError
          []
        end
      end

      def generate_contact_template
        "Contact us at [email] or call [phone]"
      end

      def generate_cta_template
        primary_cta = brand.messaging_framework&.metadata&.dig("primary_cta") || "Learn More"
        "#{primary_cta} →"
      end
    end
  end
end