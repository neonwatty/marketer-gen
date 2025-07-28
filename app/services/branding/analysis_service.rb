module Branding
  class AnalysisService
    attr_reader :brand, :content, :options

    def initialize(brand, content = nil, options = {})
      @brand = brand
      @content = content || aggregate_brand_content
      @options = options
    end

    def analyze
      return false if content.blank?

      analysis = brand.brand_analyses.create!(
        analysis_status: "processing"
      )

      begin
        # Extract various brand attributes
        voice_attrs = analyze_voice_and_tone
        brand_vals = extract_brand_values
        messaging_pillars = extract_messaging_pillars
        guidelines = extract_guidelines
        visual_guide = extract_visual_guidelines

        analysis.update!(
          voice_attributes: voice_attrs,
          brand_values: brand_vals,
          messaging_pillars: messaging_pillars,
          extracted_rules: guidelines,
          visual_guidelines: visual_guide,
          confidence_score: calculate_confidence_score(voice_attrs, brand_vals),
          analysis_status: "completed",
          analyzed_at: Time.current
        )

        # Update brand guidelines based on analysis
        create_guidelines_from_analysis(analysis)
        
        # Update messaging framework
        update_messaging_framework(analysis)

        true
      rescue StandardError => e
        analysis.mark_as_failed!(e.message)
        false
      end
    end

    private

    def aggregate_brand_content
      # Collect all processed brand asset texts
      brand.brand_assets.processed
           .where.not(extracted_text: [nil, ""])
           .pluck(:extracted_text)
           .join("\n\n")
    end

    def analyze_voice_and_tone
      prompt = build_voice_analysis_prompt
      response = llm_service.analyze(prompt)
      
      parse_voice_attributes(response)
    end

    def extract_brand_values
      prompt = build_brand_values_prompt
      response = llm_service.analyze(prompt)
      
      parse_brand_values(response)
    end

    def extract_messaging_pillars
      prompt = build_messaging_pillars_prompt
      response = llm_service.analyze(prompt)
      
      parse_messaging_pillars(response)
    end

    def extract_guidelines
      prompt = build_guidelines_extraction_prompt
      response = llm_service.analyze(prompt)
      
      parse_guidelines(response)
    end

    def extract_visual_guidelines
      # This would analyze image assets and extract visual guidelines
      # For now, returning a basic structure
      {
        colors: extract_color_guidelines,
        typography: extract_typography_guidelines,
        imagery: extract_imagery_guidelines
      }
    end

    def build_voice_analysis_prompt
      <<~PROMPT
        Analyze the following brand content and extract voice and tone characteristics.
        
        Content:
        #{content[0..5000]} # Limit content to avoid token limits
        
        Please identify:
        1. Formality level (very formal, formal, neutral, casual, very casual)
        2. Tone (professional, friendly, authoritative, conversational, etc.)
        3. Writing style (descriptive, concise, technical, storytelling, etc.)
        4. Personality traits (innovative, trustworthy, approachable, etc.)
        5. Communication approach (direct, indirect, persuasive, informative, etc.)
        
        Provide response in JSON format.
      PROMPT
    end

    def build_brand_values_prompt
      <<~PROMPT
        Extract core brand values from the following brand content.
        
        Content:
        #{content[0..5000]}
        
        Identify 3-5 core brand values that are consistently emphasized.
        Look for:
        - Explicitly stated values
        - Implied values through messaging
        - Repeated themes and concepts
        
        Return as a JSON array of values with brief descriptions.
      PROMPT
    end

    def build_messaging_pillars_prompt
      <<~PROMPT
        Identify key messaging pillars from the following brand content.
        
        Content:
        #{content[0..5000]}
        
        Extract 3-5 main messaging pillars that support the brand's communication.
        Each pillar should represent a core theme or message category.
        
        Return as JSON with pillar names and supporting points.
      PROMPT
    end

    def build_guidelines_extraction_prompt
      <<~PROMPT
        Extract brand guidelines and rules from the following content.
        
        Content:
        #{content[0..5000]}
        
        Identify:
        1. Do's and Don'ts
        2. Must-have elements
        3. Restrictions and limitations
        4. Preferred approaches
        5. Things to avoid
        
        Categorize by: voice, tone, visual, messaging, grammar, style
        
        Return as structured JSON.
      PROMPT
    end

    def parse_voice_attributes(response)
      # Parse LLM response and structure voice attributes
      # This is a simplified version - actual implementation would be more robust
      {
        formality: {
          level: "professional",
          score: 0.8
        },
        tone: {
          primary: "friendly",
          secondary: "authoritative",
          attributes: ["approachable", "knowledgeable", "supportive"]
        },
        style: {
          writing: "conversational",
          communication: "direct",
          personality: ["innovative", "trustworthy", "helpful"]
        }
      }
    end

    def parse_brand_values(response)
      # Parse and return brand values
      [
        "Innovation",
        "Customer-centricity",
        "Transparency",
        "Excellence",
        "Sustainability"
      ]
    end

    def parse_messaging_pillars(response)
      # Parse and return messaging pillars
      [
        {
          name: "Customer Success",
          description: "Focus on helping customers achieve their goals",
          key_points: ["Support", "Guidance", "Results"]
        },
        {
          name: "Innovation Leadership",
          description: "Pioneering new solutions and approaches",
          key_points: ["Technology", "Creativity", "Progress"]
        }
      ]
    end

    def parse_guidelines(response)
      # Parse and structure guidelines
      {
        dos: [
          "Use clear, concise language",
          "Address customer needs directly",
          "Include specific examples"
        ],
        donts: [
          "Avoid jargon without explanation",
          "Don't make unsupported claims",
          "Avoid negative competitor mentions"
        ],
        requirements: [
          "Always include value proposition",
          "Use active voice",
          "Maintain consistent terminology"
        ]
      }
    end

    def extract_color_guidelines
      # Extract from visual assets
      {
        primary: ["#1E40AF", "#3B82F6"],
        secondary: ["#10B981", "#F59E0B"],
        neutral: ["#F3F4F6", "#9CA3AF", "#1F2937"]
      }
    end

    def extract_typography_guidelines
      # Extract from brand guidelines
      {
        headings: {
          font_family: "Inter",
          weights: ["bold", "semibold"]
        },
        body: {
          font_family: "Inter",
          weights: ["regular", "medium"]
        }
      }
    end

    def extract_imagery_guidelines
      {
        style: "modern, clean, professional",
        subjects: ["people in work settings", "technology", "collaboration"],
        avoid: ["stock photos", "cliches", "outdated imagery"]
      }
    end

    def calculate_confidence_score(voice_attrs, brand_vals)
      # Calculate confidence based on content amount and consistency
      base_score = 0.7
      
      # Adjust based on content volume
      content_words = content.split.size
      if content_words > 5000
        base_score += 0.2
      elsif content_words > 2000
        base_score += 0.1
      end
      
      # Cap at 1.0
      [base_score, 1.0].min
    end

    def create_guidelines_from_analysis(analysis)
      # Create BrandGuideline records from analysis
      guidelines = []
      
      # Create dos
      analysis.extracted_rules["dos"]&.each do |rule|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "do",
          rule_content: rule,
          category: "messaging",
          priority: 7
        )
      end
      
      # Create don'ts
      analysis.extracted_rules["donts"]&.each do |rule|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "dont",
          rule_content: rule,
          category: "messaging",
          priority: 8
        )
      end
      
      # Create requirements
      analysis.extracted_rules["requirements"]&.each do |rule|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: rule,
          category: "style",
          priority: 9
        )
      end
      
      guidelines
    end

    def update_messaging_framework(analysis)
      framework = brand.messaging_framework
      return unless framework
      
      # Update tone attributes
      framework.update!(
        tone_attributes: analysis.voice_attributes.dig("tone") || {},
        key_messages: build_key_messages(analysis),
        value_propositions: build_value_propositions(analysis)
      )
    end

    def build_key_messages(analysis)
      messages = {}
      
      analysis.messaging_pillars.each do |pillar|
        messages[pillar["name"]] = pillar["key_points"] || []
      end
      
      messages
    end

    def build_value_propositions(analysis)
      {
        main: analysis.brand_values,
        supporting: analysis.messaging_pillars.map { |p| p["description"] }
      }
    end

    def llm_service
      @llm_service ||= LlmService.new
    end
  end
end