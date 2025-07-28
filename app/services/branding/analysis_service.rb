module Branding
  class AnalysisService
    attr_reader :brand, :content, :options, :visual_assets

    # Constants for analysis configuration
    MAX_CONTENT_LENGTH = 50_000
    CHUNK_SIZE = 4_000
    MIN_CONTENT_LENGTH = 100
    DEFAULT_CONFIDENCE_THRESHOLD = 0.7
    
    # Analysis categories
    VOICE_DIMENSIONS = {
      formality: %w[very_formal formal neutral casual very_casual],
      energy: %w[high_energy energetic balanced calm subdued],
      warmth: %w[very_warm warm neutral cool professional],
      authority: %w[commanding authoritative balanced approachable peer_level]
    }.freeze
    
    TONE_ATTRIBUTES = %w[
      professional friendly authoritative conversational playful
      serious inspiring educational empathetic bold innovative
      trustworthy approachable technical sophisticated
    ].freeze
    
    WRITING_STYLES = %w[
      descriptive concise technical storytelling analytical
      persuasive informative instructional narrative expository
    ].freeze

    def initialize(brand, content = nil, options = {})
      @brand = brand
      @options = options
      @content = content || aggregate_brand_content
      @visual_assets = brand.brand_assets.where(asset_type: ['logo', 'image', 'visual'])
      @llm_provider = options[:llm_provider] || determine_best_provider
    end

    def analyze
      return { success: false, error: "Insufficient content for analysis" } if content.blank? || content.length < MIN_CONTENT_LENGTH

      analysis = brand.brand_analyses.create!(
        analysis_status: "processing",
        analysis_data: { started_at: Time.current }
      )

      BrandAnalysisJob.perform_later(analysis.id)
      
      { success: true, analysis_id: analysis.id }
    rescue StandardError => e
      Rails.logger.error "Brand analysis error: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, error: e.message }
    end

    def perform_analysis(analysis)
      analysis.mark_as_processing!
      
      begin
        # Multi-stage analysis with chunking for large content
        content_chunks = chunk_content(@content)
        
        # Stage 1: Voice and tone analysis across all chunks
        voice_attrs = analyze_voice_and_tone_comprehensive(content_chunks)
        
        # Stage 2: Brand values extraction with context
        brand_vals = extract_brand_values_with_context(content_chunks)
        
        # Stage 3: Messaging pillars with examples
        messaging_pillars = extract_messaging_pillars_detailed(content_chunks)
        
        # Stage 4: Comprehensive guidelines extraction
        guidelines = extract_guidelines_comprehensive(content_chunks)
        
        # Stage 5: Visual brand analysis (if applicable)
        visual_guide = analyze_visual_brand_elements
        
        # Stage 6: Cross-reference and validate findings
        validated_data = cross_validate_findings(
          voice_attrs, brand_vals, messaging_pillars, guidelines
        )
        
        # Stage 7: Calculate comprehensive confidence score
        confidence = calculate_comprehensive_confidence_score(validated_data)
        
        # Update analysis with all findings
        analysis.update!(
          voice_attributes: validated_data[:voice_attributes],
          brand_values: validated_data[:brand_values],
          messaging_pillars: validated_data[:messaging_pillars],
          extracted_rules: validated_data[:guidelines],
          visual_guidelines: visual_guide,
          confidence_score: confidence[:overall],
          analysis_data: analysis.analysis_data.merge(
            confidence_breakdown: confidence[:breakdown],
            analysis_metadata: {
              content_length: @content.length,
              chunks_analyzed: content_chunks.size,
              visual_assets_analyzed: @visual_assets.count,
              llm_provider: @llm_provider,
              completed_at: Time.current
            }
          ),
          analysis_status: "completed",
          analyzed_at: Time.current
        )

        # Create actionable guidelines and frameworks
        create_comprehensive_guidelines(analysis)
        update_messaging_framework_detailed(analysis)
        generate_brand_consistency_report(analysis)

        true
      rescue StandardError => e
        Rails.logger.error "Analysis processing error: #{e.message}\n#{e.backtrace.join("\n")}"
        analysis.mark_as_failed!("Analysis failed: #{e.message}")
        false
      end
    end

    private

    def aggregate_brand_content
      # Prioritize content by type and recency
      content_sources = []
      
      # Priority 1: Brand guidelines and style guides
      guidelines_content = brand.brand_assets
        .where(asset_type: ['style_guide', 'brand_guidelines', 'voice_guide'])
        .processed
        .pluck(:extracted_text, :metadata)
      
      content_sources.concat(
        guidelines_content.map { |text, meta| 
          { content: text, priority: 1, source: meta['filename'] || 'Brand Guidelines' }
        }
      )
      
      # Priority 2: Marketing materials and messaging docs
      marketing_content = brand.brand_assets
        .where(asset_type: ['marketing_material', 'messaging_doc', 'presentation'])
        .processed
        .pluck(:extracted_text, :metadata)
      
      content_sources.concat(
        marketing_content.map { |text, meta| 
          { content: text, priority: 2, source: meta['filename'] || 'Marketing Material' }
        }
      )
      
      # Priority 3: Website content and other materials
      other_content = brand.brand_assets
        .where.not(asset_type: ['style_guide', 'brand_guidelines', 'voice_guide', 
                               'marketing_material', 'messaging_doc', 'presentation',
                               'logo', 'image', 'visual'])
        .processed
        .pluck(:extracted_text, :metadata)
      
      content_sources.concat(
        other_content.map { |text, meta| 
          { content: text, priority: 3, source: meta['filename'] || 'Other Content' }
        }
      )
      
      # Sort by priority and combine
      @content_sources = content_sources.sort_by { |s| s[:priority] }
      
      # Combine with priority weighting
      combined_content = @content_sources.map { |source| 
        "\n\n[Source: #{source[:source]}]\n#{source[:content]}"
      }.join("\n\n")
      
      # Truncate if too long
      combined_content.truncate(MAX_CONTENT_LENGTH)
    end
    
    def chunk_content(content)
      return [content] if content.length <= CHUNK_SIZE
      
      chunks = []
      sentences = content.split(/(?<=[.!?])\s+/)
      current_chunk = ""
      
      sentences.each do |sentence|
        if (current_chunk.length + sentence.length) > CHUNK_SIZE && current_chunk.present?
          chunks << current_chunk.strip
          current_chunk = sentence
        else
          current_chunk += " #{sentence}"
        end
      end
      
      chunks << current_chunk.strip if current_chunk.present?
      chunks
    end
    
    def determine_best_provider
      # Prioritize providers based on capabilities and availability
      if ENV['ANTHROPIC_API_KEY'].present?
        'claude-3-opus-20240229'  # Best for nuanced brand analysis
      elsif ENV['OPENAI_API_KEY'].present?
        'gpt-4-turbo-preview'     # Good for structured output
      else
        'gpt-3.5-turbo'           # Fallback option
      end
    end

    def analyze_voice_and_tone_comprehensive(content_chunks)
      # Analyze each chunk for voice consistency
      chunk_analyses = content_chunks.map.with_index do |chunk, index|
        prompt = build_comprehensive_voice_prompt(chunk, index, content_chunks.size)
        response = llm_service.analyze(prompt, json_response: true)
        parse_voice_response_safe(response)
      end
      
      # Aggregate and reconcile findings
      aggregate_voice_attributes(chunk_analyses)
    end
    
    def build_comprehensive_voice_prompt(content, chunk_index, total_chunks)
      <<~PROMPT
        You are an expert brand voice analyst. Analyze this brand content (chunk #{chunk_index + 1} of #{total_chunks}) for voice and tone characteristics.
        
        Content:
        #{content}
        
        Provide a detailed analysis in the following JSON structure:
        {
          "formality": {
            "level": "one of: #{VOICE_DIMENSIONS[:formality].join(', ')}",
            "score": 0.0-1.0,
            "evidence": ["specific phrases showing formality level"],
            "consistency": 0.0-1.0
          },
          "energy": {
            "level": "one of: #{VOICE_DIMENSIONS[:energy].join(', ')}",
            "score": 0.0-1.0,
            "evidence": ["specific phrases showing energy level"]
          },
          "warmth": {
            "level": "one of: #{VOICE_DIMENSIONS[:warmth].join(', ')}",
            "score": 0.0-1.0,
            "evidence": ["specific phrases showing warmth level"]
          },
          "authority": {
            "level": "one of: #{VOICE_DIMENSIONS[:authority].join(', ')}",
            "score": 0.0-1.0,
            "evidence": ["specific phrases showing authority level"]
          },
          "tone": {
            "primary": "main tone from: #{TONE_ATTRIBUTES.join(', ')}",
            "secondary": ["2-3 secondary tones"],
            "avoided": ["tones that are notably absent"],
            "consistency": 0.0-1.0
          },
          "style": {
            "writing": "primary style from: #{WRITING_STYLES.join(', ')}",
            "sentence_structure": "simple/compound/complex/varied",
            "vocabulary": "basic/intermediate/advanced/technical/mixed",
            "paragraph_length": "short/medium/long/varied",
            "active_passive_ratio": 0.0-1.0
          },
          "personality_traits": ["5-7 key personality descriptors"],
          "linguistic_patterns": {
            "common_phrases": ["frequently used phrases"],
            "power_words": ["impactful words used"],
            "transitions": ["common transition phrases"],
            "openings": ["typical sentence/paragraph starters"],
            "closings": ["typical ending patterns"]
          },
          "emotional_tone": {
            "primary_emotion": "dominant emotional undertone",
            "emotional_range": "narrow/moderate/wide",
            "positivity_ratio": 0.0-1.0
          }
        }
        
        Be specific and cite actual examples from the text. Focus on patterns, not isolated instances.
      PROMPT
    end
    
    def parse_voice_response_safe(response)
      return default_voice_attributes if response.blank?
      
      begin
        parsed = JSON.parse(response) rescue response
        
        # Validate and clean the response
        {
          formality: validate_dimension(parsed['formality'], 'formality'),
          energy: validate_dimension(parsed['energy'], 'energy'),
          warmth: validate_dimension(parsed['warmth'], 'warmth'),
          authority: validate_dimension(parsed['authority'], 'authority'),
          tone: validate_tone(parsed['tone']),
          style: validate_style(parsed['style']),
          personality_traits: Array(parsed['personality_traits']).first(7),
          linguistic_patterns: validate_patterns(parsed['linguistic_patterns']),
          emotional_tone: validate_emotional_tone(parsed['emotional_tone'])
        }
      rescue => e
        Rails.logger.error "Voice parsing error: #{e.message}"
        default_voice_attributes
      end
    end
    
    def validate_dimension(dimension_data, dimension_name)
      return default_dimension(dimension_name) unless dimension_data.is_a?(Hash)
      
      {
        level: VOICE_DIMENSIONS[dimension_name.to_sym].include?(dimension_data['level']) ? 
               dimension_data['level'] : VOICE_DIMENSIONS[dimension_name.to_sym][2],
        score: [dimension_data['score'].to_f, 1.0].min,
        evidence: Array(dimension_data['evidence']).first(5),
        consistency: dimension_data['consistency']&.to_f || 0.7
      }
    end
    
    def validate_tone(tone_data)
      return default_tone unless tone_data.is_a?(Hash)
      
      {
        primary: TONE_ATTRIBUTES.include?(tone_data['primary']) ? 
                 tone_data['primary'] : 'professional',
        secondary: Array(tone_data['secondary']).select { |t| TONE_ATTRIBUTES.include?(t) }.first(3),
        avoided: Array(tone_data['avoided']),
        consistency: tone_data['consistency']&.to_f || 0.7
      }
    end
    
    def validate_style(style_data)
      return default_style unless style_data.is_a?(Hash)
      
      {
        writing: WRITING_STYLES.include?(style_data['writing']) ? 
                 style_data['writing'] : 'informative',
        sentence_structure: style_data['sentence_structure'] || 'varied',
        vocabulary: style_data['vocabulary'] || 'intermediate',
        paragraph_length: style_data['paragraph_length'] || 'medium',
        active_passive_ratio: style_data['active_passive_ratio']&.to_f || 0.8
      }
    end
    
    def aggregate_voice_attributes(chunk_analyses)
      # Remove any failed analyses
      valid_analyses = chunk_analyses.reject { |a| a == default_voice_attributes }
      
      return default_voice_attributes if valid_analyses.empty?
      
      # Aggregate each dimension
      aggregated = {
        formality: aggregate_dimension(valid_analyses, :formality),
        energy: aggregate_dimension(valid_analyses, :energy),
        warmth: aggregate_dimension(valid_analyses, :warmth),
        authority: aggregate_dimension(valid_analyses, :authority),
        tone: aggregate_tone(valid_analyses),
        style: aggregate_style(valid_analyses),
        personality_traits: aggregate_personality_traits(valid_analyses),
        linguistic_patterns: aggregate_patterns(valid_analyses),
        emotional_tone: aggregate_emotional_tone(valid_analyses),
        consistency_score: calculate_voice_consistency(valid_analyses)
      }
      
      aggregated
    end
    
    def aggregate_dimension(analyses, dimension)
      dimensions = analyses.map { |a| a[dimension] }.compact
      
      # Count frequency of each level
      level_counts = dimensions.group_by { |d| d[:level] }
                              .transform_values(&:count)
      
      # Most common level
      primary_level = level_counts.max_by { |_, count| count }&.first
      
      # Average score
      avg_score = dimensions.map { |d| d[:score] }.sum.to_f / dimensions.size
      
      # Collect all evidence
      all_evidence = dimensions.flat_map { |d| d[:evidence] || [] }.uniq.first(10)
      
      # Calculate consistency across chunks
      consistency = calculate_dimension_consistency(dimensions)
      
      {
        level: primary_level,
        score: avg_score.round(2),
        evidence: all_evidence,
        consistency: consistency,
        distribution: level_counts
      }
    end

    def extract_brand_values_with_context(content_chunks)
      # Extract values from each chunk with context
      chunk_values = content_chunks.map.with_index do |chunk, index|
        prompt = build_brand_values_extraction_prompt(chunk, index, content_chunks.size)
        response = llm_service.analyze(prompt, json_response: true)
        parse_brand_values_response(response)
      end
      
      # Aggregate and rank by frequency and importance
      aggregate_brand_values(chunk_values)
    end
    
    def build_brand_values_extraction_prompt(content, chunk_index, total_chunks)
      <<~PROMPT
        You are an expert brand strategist analyzing brand values. Examine this content (chunk #{chunk_index + 1} of #{total_chunks}) to identify core brand values.
        
        Content:
        #{content}
        
        Identify brand values using this comprehensive approach:
        
        1. EXPLICIT VALUES: Look for directly stated values, mission statements, or "what we believe" sections
        2. IMPLIED VALUES: Infer values from:
           - Repeated themes and concepts
           - The way products/services are described
           - How the brand talks about customers
           - What the brand emphasizes or prioritizes
           - Language choices and framing
        
        3. BEHAVIORAL VALUES: Values demonstrated through:
           - Actions described
           - Commitments made
           - Problems the brand chooses to solve
           - How the brand differentiates itself
        
        Return a JSON response with this structure:
        {
          "explicit_values": [
            {
              "value": "Innovation",
              "evidence": "Direct quote or reference",
              "context": "Where/how it was mentioned",
              "strength": 0.0-1.0
            }
          ],
          "implied_values": [
            {
              "value": "Customer-centricity",
              "evidence": "Patterns or themes observed",
              "reasoning": "Why this value is implied",
              "strength": 0.0-1.0
            }
          ],
          "behavioral_values": [
            {
              "value": "Sustainability",
              "evidence": "Actions or commitments described",
              "manifestation": "How it's demonstrated",
              "strength": 0.0-1.0
            }
          ],
          "value_hierarchy": [
            "Ordered list of values by importance based on emphasis"
          ],
          "conflicting_values": [
            {
              "value1": "Speed",
              "value2": "Perfection",
              "explanation": "How these might conflict"
            }
          ]
        }
        
        Focus on identifying 3-7 core values that truly define this brand. Be specific and cite evidence.
      PROMPT
    end
    
    def parse_brand_values_response(response)
      return default_brand_values_structure if response.blank?
      
      begin
        parsed = JSON.parse(response) rescue response
        
        {
          explicit_values: parse_value_list(parsed['explicit_values']),
          implied_values: parse_value_list(parsed['implied_values']),
          behavioral_values: parse_value_list(parsed['behavioral_values']),
          value_hierarchy: Array(parsed['value_hierarchy']).first(7),
          conflicting_values: Array(parsed['conflicting_values'])
        }
      rescue => e
        Rails.logger.error "Brand values parsing error: #{e.message}"
        default_brand_values_structure
      end
    end
    
    def parse_value_list(values)
      return [] unless values.is_a?(Array)
      
      values.map do |value_data|
        next unless value_data.is_a?(Hash)
        
        {
          value: value_data['value'],
          evidence: value_data['evidence'],
          context: value_data['context'] || value_data['reasoning'] || value_data['manifestation'],
          strength: [value_data['strength'].to_f, 1.0].min
        }
      end.compact
    end
    
    def aggregate_brand_values(chunk_values)
      all_values = {
        explicit: [],
        implied: [],
        behavioral: []
      }
      
      # Collect all values across chunks
      chunk_values.each do |chunk|
        all_values[:explicit].concat(chunk[:explicit_values] || [])
        all_values[:implied].concat(chunk[:implied_values] || [])
        all_values[:behavioral].concat(chunk[:behavioral_values] || [])
      end
      
      # Group by value name and aggregate
      aggregated_values = {}
      
      [:explicit, :implied, :behavioral].each do |type|
        all_values[type].group_by { |v| v[:value]&.downcase }
                        .each do |value_name, instances|
          next if value_name.blank?
          
          aggregated_values[value_name] ||= {
            value: instances.first[:value],  # Original case
            type: type,
            frequency: 0,
            total_strength: 0,
            evidence: [],
            contexts: []
          }
          
          aggregated_values[value_name][:frequency] += instances.size
          aggregated_values[value_name][:total_strength] += instances.sum { |i| i[:strength] }
          aggregated_values[value_name][:evidence].concat(instances.map { |i| i[:evidence] }.compact)
          aggregated_values[value_name][:contexts].concat(instances.map { |i| i[:context] }.compact)
        end
      end
      
      # Calculate final scores and rank
      final_values = aggregated_values.values.map do |value_data|
        avg_strength = value_data[:total_strength] / value_data[:frequency]
        
        # Boost score for explicit values and frequency
        type_weight = case value_data[:type]
                     when :explicit then 1.2
                     when :behavioral then 1.1
                     else 1.0
                     end
        
        frequency_weight = Math.log(value_data[:frequency] + 1) / Math.log(chunk_values.size + 1)
        
        final_score = (avg_strength * type_weight * (0.7 + 0.3 * frequency_weight))
        
        {
          name: value_data[:value],
          score: final_score.round(3),
          type: value_data[:type],
          frequency: value_data[:frequency],
          evidence: value_data[:evidence].uniq.first(5),
          contexts: value_data[:contexts].uniq.first(3)
        }
      end
      
      # Sort by score and take top values
      final_values.sort_by { |v| -v[:score] }.first(7)
    end
    
    def default_brand_values_structure
      {
        explicit_values: [],
        implied_values: [],
        behavioral_values: [],
        value_hierarchy: [],
        conflicting_values: []
      }
    end

    def extract_messaging_pillars_detailed(content_chunks)
      # Extract pillars from each chunk
      chunk_pillars = content_chunks.map.with_index do |chunk, index|
        prompt = build_messaging_pillars_extraction_prompt(chunk, index, content_chunks.size)
        response = llm_service.analyze(prompt, json_response: true)
        parse_messaging_pillars_response(response)
      end
      
      # Aggregate and structure pillars
      aggregate_messaging_pillars(chunk_pillars)
    end
    
    def build_messaging_pillars_extraction_prompt(content, chunk_index, total_chunks)
      <<~PROMPT
        You are an expert messaging strategist. Analyze this brand content (chunk #{chunk_index + 1} of #{total_chunks}) to identify key messaging pillars.
        
        Content:
        #{content}
        
        Identify messaging pillars - the core themes that support all brand communications. Look for:
        
        1. RECURRING THEMES: Topics or concepts that appear multiple times
        2. VALUE PROPOSITIONS: Key benefits or advantages emphasized
        3. DIFFERENTIATORS: What makes this brand unique
        4. AUDIENCE BENEFITS: How the brand helps its customers
        5. PROOF POINTS: Evidence, features, or capabilities that support claims
        
        Return a JSON response with this structure:
        {
          "pillars": [
            {
              "name": "Clear, descriptive pillar name",
              "description": "What this pillar represents",
              "key_messages": [
                "Specific messages under this pillar"
              ],
              "supporting_points": [
                "Facts, features, or benefits that support this pillar"
              ],
              "target_emotion": "What feeling this pillar aims to evoke",
              "evidence": [
                "Quotes or references from the content"
              ],
              "frequency": 1-10,
              "importance": 1-10
            }
          ],
          "pillar_relationships": [
            {
              "pillar1": "Name of first pillar",
              "pillar2": "Name of second pillar",
              "relationship": "How these pillars connect or support each other"
            }
          ],
          "missing_pillars": [
            {
              "suggested_pillar": "What might be missing",
              "rationale": "Why this could strengthen the messaging"
            }
          ]
        }
        
        Identify 3-5 main pillars that form the foundation of this brand's messaging.
      PROMPT
    end
    
    def parse_messaging_pillars_response(response)
      return default_pillars_structure if response.blank?
      
      begin
        parsed = JSON.parse(response) rescue response
        
        {
          pillars: parse_pillars_list(parsed['pillars']),
          relationships: Array(parsed['pillar_relationships']),
          missing: Array(parsed['missing_pillars'])
        }
      rescue => e
        Rails.logger.error "Messaging pillars parsing error: #{e.message}"
        default_pillars_structure
      end
    end
    
    def parse_pillars_list(pillars)
      return [] unless pillars.is_a?(Array)
      
      pillars.map do |pillar|
        next unless pillar.is_a?(Hash)
        
        {
          name: pillar['name'],
          description: pillar['description'],
          key_messages: Array(pillar['key_messages']).first(5),
          supporting_points: Array(pillar['supporting_points']).first(5),
          target_emotion: pillar['target_emotion'],
          evidence: Array(pillar['evidence']).first(3),
          frequency: [pillar['frequency'].to_i, 10].min,
          importance: [pillar['importance'].to_i, 10].min
        }
      end.compact
    end
    
    def aggregate_messaging_pillars(chunk_pillars)
      all_pillars = {}
      all_relationships = []
      
      # Collect all pillars
      chunk_pillars.each do |chunk|
        chunk[:pillars].each do |pillar|
          key = pillar[:name]&.downcase&.strip
          next if key.blank?
          
          all_pillars[key] ||= {
            name: pillar[:name],
            description: [],
            key_messages: [],
            supporting_points: [],
            target_emotions: [],
            evidence: [],
            total_frequency: 0,
            total_importance: 0,
            occurrences: 0
          }
          
          all_pillars[key][:description] << pillar[:description]
          all_pillars[key][:key_messages].concat(pillar[:key_messages] || [])
          all_pillars[key][:supporting_points].concat(pillar[:supporting_points] || [])
          all_pillars[key][:target_emotions] << pillar[:target_emotion]
          all_pillars[key][:evidence].concat(pillar[:evidence] || [])
          all_pillars[key][:total_frequency] += pillar[:frequency]
          all_pillars[key][:total_importance] += pillar[:importance]
          all_pillars[key][:occurrences] += 1
        end
        
        all_relationships.concat(chunk[:relationships] || [])
      end
      
      # Process and rank pillars
      processed_pillars = all_pillars.map do |key, data|
        avg_frequency = data[:total_frequency].to_f / data[:occurrences]
        avg_importance = data[:total_importance].to_f / data[:occurrences]
        occurrence_weight = Math.log(data[:occurrences] + 1) / Math.log(chunk_pillars.size + 1)
        
        score = (avg_frequency * 0.3 + avg_importance * 0.5 + occurrence_weight * 10 * 0.2)
        
        {
          name: data[:name],
          description: most_representative(data[:description]),
          key_messages: deduplicate_and_rank(data[:key_messages], 5),
          supporting_points: deduplicate_and_rank(data[:supporting_points], 7),
          target_emotion: most_common(data[:target_emotions].compact),
          evidence: data[:evidence].uniq.first(5),
          strength_score: score.round(2),
          consistency_score: (data[:occurrences].to_f / chunk_pillars.size).round(2)
        }
      end
      
      # Sort by score and take top pillars
      top_pillars = processed_pillars.sort_by { |p| -p[:strength_score] }.first(5)
      
      # Process relationships for top pillars
      pillar_names = top_pillars.map { |p| p[:name].downcase }
      relevant_relationships = all_relationships.select do |rel|
        pillar_names.include?(rel['pillar1']&.downcase) && 
        pillar_names.include?(rel['pillar2']&.downcase)
      end.uniq
      
      {
        pillars: top_pillars,
        relationships: relevant_relationships,
        pillar_hierarchy: create_pillar_hierarchy(top_pillars, relevant_relationships)
      }
    end
    
    def most_representative(descriptions)
      # Find the most complete/representative description
      descriptions.compact.max_by(&:length) || ""
    end
    
    def deduplicate_and_rank(items, limit)
      # Remove duplicates and rank by frequency
      items.group_by { |item| item.downcase.strip }
           .sort_by { |_, instances| -instances.size }
           .first(limit)
           .map { |_, instances| instances.first }
    end
    
    def create_pillar_hierarchy(pillars, relationships)
      # Create a simple hierarchy based on scores and relationships
      {
        primary: pillars.first(2).map { |p| p[:name] },
        supporting: pillars[2..-1]&.map { |p| p[:name] } || [],
        connections: relationships.map { |r| 
          "#{r['pillar1']} + #{r['pillar2']}: #{r['relationship']}"
        }
      }
    end
    
    def default_pillars_structure
      {
        pillars: [],
        relationships: [],
        missing: []
      }
    end

    def extract_guidelines_comprehensive(content_chunks)
      # Extract guidelines from each chunk with categorization
      chunk_guidelines = content_chunks.map.with_index do |chunk, index|
        prompt = build_comprehensive_guidelines_prompt(chunk, index, content_chunks.size)
        response = llm_service.analyze(prompt, json_response: true)
        parse_guidelines_response(response)
      end
      
      # Aggregate and categorize guidelines
      aggregate_guidelines(chunk_guidelines)
    end
    
    def build_comprehensive_guidelines_prompt(content, chunk_index, total_chunks)
      <<~PROMPT
        You are an expert brand guidelines analyst. Extract all brand rules, guidelines, and requirements from this content (chunk #{chunk_index + 1} of #{total_chunks}).
        
        Content:
        #{content}
        
        Extract guidelines in these categories:
        
        1. VOICE & TONE RULES:
           - How to speak/write
           - Tone requirements
           - Voice characteristics to maintain
           - Language do's and don'ts
        
        2. MESSAGING RULES:
           - What to communicate
           - Key messages to include
           - Topics to avoid
           - Claims restrictions
        
        3. VISUAL RULES:
           - Color usage
           - Typography requirements
           - Logo usage
           - Image style
        
        4. GRAMMAR & STYLE:
           - Punctuation rules
           - Capitalization
           - Formatting requirements
           - Writing conventions
        
        5. BRAND BEHAVIOR:
           - How the brand should act
           - Customer interaction guidelines
           - Response patterns
           - Ethics and values in practice
        
        Return a JSON response with this structure:
        {
          "voice_tone_rules": {
            "must_do": ["Required voice/tone elements"],
            "should_do": ["Recommended practices"],
            "must_not_do": ["Prohibited voice/tone elements"],
            "examples": {
              "good": ["Examples of correct usage"],
              "bad": ["Examples to avoid"]
            }
          },
          "messaging_rules": {
            "required_elements": ["Must-include messages"],
            "key_phrases": ["Specific phrases to use"],
            "prohibited_topics": ["Topics/claims to avoid"],
            "competitor_mentions": "Guidelines for mentioning competitors"
          },
          "visual_rules": {
            "colors": {
              "primary": ["#hex codes"],
              "secondary": ["#hex codes"],
              "usage_rules": ["When/how to use colors"]
            },
            "typography": {
              "fonts": ["Font names and weights"],
              "sizes": ["Size specifications"],
              "usage_rules": ["When to use which fonts"]
            },
            "imagery": {
              "style": "Description of image style",
              "do": ["Image requirements"],
              "dont": ["Image restrictions"]
            }
          },
          "grammar_style_rules": {
            "punctuation": ["Specific punctuation rules"],
            "capitalization": ["What to capitalize"],
            "formatting": ["Format requirements"],
            "preferred_terms": {"use_this": "not_that"}
          },
          "behavioral_rules": {
            "customer_interaction": ["How to interact with customers"],
            "response_patterns": ["How to respond to situations"],
            "ethical_guidelines": ["Ethical considerations"]
          },
          "rule_priority": [
            {
              "rule": "Most important rule",
              "category": "Which category",
              "importance": 1-10,
              "consequences": "What happens if violated"
            }
          ]
        }
        
        Be specific and extract actual rules, not general observations.
      PROMPT
    end
    
    def parse_guidelines_response(response)
      return default_guidelines_structure if response.blank?
      
      begin
        parsed = JSON.parse(response) rescue response
        
        {
          voice_tone_rules: parse_rule_category(parsed['voice_tone_rules']),
          messaging_rules: parse_rule_category(parsed['messaging_rules']),
          visual_rules: parse_visual_rules(parsed['visual_rules']),
          grammar_style_rules: parse_rule_category(parsed['grammar_style_rules']),
          behavioral_rules: parse_rule_category(parsed['behavioral_rules']),
          rule_priority: parse_rule_priorities(parsed['rule_priority'])
        }
      rescue => e
        Rails.logger.error "Guidelines parsing error: #{e.message}"
        default_guidelines_structure
      end
    end
    
    def parse_rule_category(category_data)
      return {} unless category_data.is_a?(Hash)
      
      category_data.transform_values do |value|
        case value
        when Array then value.first(10)
        when Hash then value
        when String then value
        else []
        end
      end
    end
    
    def parse_visual_rules(visual_data)
      return {} unless visual_data.is_a?(Hash)
      
      {
        colors: parse_color_rules(visual_data['colors']),
        typography: parse_typography_rules(visual_data['typography']),
        imagery: parse_imagery_rules(visual_data['imagery'])
      }
    end
    
    def parse_color_rules(color_data)
      return {} unless color_data.is_a?(Hash)
      
      {
        primary: Array(color_data['primary']).select { |c| c =~ /^#[0-9A-Fa-f]{6}$/ },
        secondary: Array(color_data['secondary']).select { |c| c =~ /^#[0-9A-Fa-f]{6}$/ },
        usage_rules: Array(color_data['usage_rules'])
      }
    end
    
    def parse_typography_rules(typography_data)
      return {} unless typography_data.is_a?(Hash)
      
      {
        fonts: Array(typography_data['fonts']),
        sizes: Array(typography_data['sizes']),
        usage_rules: Array(typography_data['usage_rules'])
      }
    end
    
    def parse_imagery_rules(imagery_data)
      return {} unless imagery_data.is_a?(Hash)
      
      {
        style: imagery_data['style'] || '',
        do: Array(imagery_data['do']),
        dont: Array(imagery_data['dont'])
      }
    end
    
    def parse_rule_priorities(priorities)
      return [] unless priorities.is_a?(Array)
      
      priorities.map do |priority|
        next unless priority.is_a?(Hash)
        
        {
          rule: priority['rule'],
          category: priority['category'],
          importance: [priority['importance'].to_i, 10].min,
          consequences: priority['consequences']
        }
      end.compact.first(10)
    end
    
    def aggregate_guidelines(chunk_guidelines)
      aggregated = {
        voice_tone_rules: aggregate_rule_category(chunk_guidelines, :voice_tone_rules),
        messaging_rules: aggregate_rule_category(chunk_guidelines, :messaging_rules),
        visual_rules: aggregate_visual_rules(chunk_guidelines),
        grammar_style_rules: aggregate_rule_category(chunk_guidelines, :grammar_style_rules),
        behavioral_rules: aggregate_rule_category(chunk_guidelines, :behavioral_rules),
        rule_priorities: aggregate_priorities(chunk_guidelines),
        rule_consistency: calculate_rule_consistency(chunk_guidelines)
      }
      
      # Detect and resolve conflicts
      aggregated[:conflicts] = detect_rule_conflicts(aggregated)
      
      aggregated
    end
    
    def aggregate_rule_category(guidelines, category)
      all_rules = {
        must_do: [],
        should_do: [],
        must_not_do: [],
        examples: { good: [], bad: [] }
      }
      
      guidelines.each do |chunk|
        category_data = chunk[category] || {}
        
        all_rules[:must_do].concat(Array(category_data['must_do']))
        all_rules[:should_do].concat(Array(category_data['should_do']))
        all_rules[:must_not_do].concat(Array(category_data['must_not_do']))
        
        if category_data['examples'].is_a?(Hash)
          all_rules[:examples][:good].concat(Array(category_data['examples']['good']))
          all_rules[:examples][:bad].concat(Array(category_data['examples']['bad']))
        end
      end
      
      # Deduplicate and prioritize
      {
        must_do: deduplicate_rules(all_rules[:must_do]),
        should_do: deduplicate_rules(all_rules[:should_do]),
        must_not_do: deduplicate_rules(all_rules[:must_not_do]),
        examples: {
          good: all_rules[:examples][:good].uniq.first(5),
          bad: all_rules[:examples][:bad].uniq.first(5)
        }
      }
    end
    
    def deduplicate_rules(rules)
      # Group similar rules and take the most detailed version
      rules.group_by { |rule| rule.downcase.split.first(3).join(' ') }
           .map { |_, group| group.max_by(&:length) }
           .uniq
           .first(15)
    end
    
    def aggregate_visual_rules(guidelines)
      all_colors = { primary: [], secondary: [] }
      all_fonts = []
      all_imagery = { style: [], do: [], dont: [] }
      
      guidelines.each do |chunk|
        visual = chunk[:visual_rules] || {}
        
        if visual[:colors]
          all_colors[:primary].concat(visual[:colors][:primary] || [])
          all_colors[:secondary].concat(visual[:colors][:secondary] || [])
        end
        
        if visual[:typography]
          all_fonts.concat(visual[:typography][:fonts] || [])
        end
        
        if visual[:imagery]
          all_imagery[:style] << visual[:imagery][:style] if visual[:imagery][:style].present?
          all_imagery[:do].concat(visual[:imagery][:do] || [])
          all_imagery[:dont].concat(visual[:imagery][:dont] || [])
        end
      end
      
      {
        colors: {
          primary: all_colors[:primary].uniq,
          secondary: all_colors[:secondary].uniq
        },
        typography: {
          fonts: all_fonts.uniq
        },
        imagery: {
          style: all_imagery[:style].join('; '),
          do: all_imagery[:do].uniq.first(10),
          dont: all_imagery[:dont].uniq.first(10)
        }
      }
    end
    
    def aggregate_priorities(guidelines)
      all_priorities = guidelines.flat_map { |g| g[:rule_priorities] || [] }
      
      # Group by rule and average importance
      grouped = all_priorities.group_by { |p| p[:rule]&.downcase }
      
      priorities = grouped.map do |rule, instances|
        avg_importance = instances.map { |i| i[:importance] }.sum.to_f / instances.size
        
        {
          rule: instances.first[:rule],
          category: most_common(instances.map { |i| i[:category] }),
          importance: avg_importance.round,
          consequences: instances.first[:consequences],
          frequency: instances.size
        }
      end
      
      priorities.sort_by { |p| [-p[:importance], -p[:frequency]] }.first(20)
    end
    
    def calculate_rule_consistency(guidelines)
      # Measure how consistent rules are across chunks
      return 1.0 if guidelines.size <= 1
      
      rule_categories = [:voice_tone_rules, :messaging_rules, :grammar_style_rules]
      consistency_scores = []
      
      rule_categories.each do |category|
        all_must_rules = guidelines.map { |g| 
          (g[category][:must_do] || []).map(&:downcase) 
        }
        
        if all_must_rules.flatten.any?
          # Check overlap between chunks
          common_rules = all_must_rules.reduce(:&) || []
          total_unique = all_must_rules.flatten.uniq.size
          
          consistency = common_rules.size.to_f / total_unique
          consistency_scores << consistency
        end
      end
      
      consistency_scores.empty? ? 0.5 : (consistency_scores.sum / consistency_scores.size).round(2)
    end
    
    def detect_rule_conflicts(aggregated)
      conflicts = []
      
      # Check for contradictions between must_do and must_not_do
      [:voice_tone_rules, :messaging_rules, :behavioral_rules].each do |category|
        must_do = aggregated[category][:must_do] || []
        must_not = aggregated[category][:must_not_do] || []
        
        must_do.each do |do_rule|
          must_not.each do |dont_rule|
            if rules_conflict?(do_rule, dont_rule)
              conflicts << {
                category: category,
                rule1: do_rule,
                rule2: dont_rule,
                type: 'direct_contradiction'
              }
            end
          end
        end
      end
      
      conflicts
    end
    
    def rules_conflict?(rule1, rule2)
      # Simple conflict detection - can be made more sophisticated
      keywords1 = rule1.downcase.split(/\W+/)
      keywords2 = rule2.downcase.split(/\W+/)
      
      # Check for opposite actions on same subject
      common_keywords = keywords1 & keywords2
      common_keywords.size > 2
    end
    
    def default_guidelines_structure
      {
        voice_tone_rules: {},
        messaging_rules: {},
        visual_rules: {},
        grammar_style_rules: {},
        behavioral_rules: {},
        rule_priority: []
      }
    end

    def analyze_visual_brand_elements
      return {} if @visual_assets.empty?
      
      visual_analysis = {
        colors: extract_colors_from_assets,
        typography: extract_typography_from_assets,
        imagery: analyze_imagery_style,
        logo_usage: analyze_logo_usage,
        visual_consistency: calculate_visual_consistency
      }
      
      # If we have style guides, enhance with explicit rules
      style_guides = @visual_assets.where(asset_type: 'style_guide')
      if style_guides.any?
        enhance_visual_analysis_with_guides(visual_analysis, style_guides)
      end
      
      visual_analysis
    end
    
    def extract_colors_from_assets
      colors = {
        primary: [],
        secondary: [],
        accent: [],
        neutral: []
      }
      
      # Analyze logos and visual assets for color extraction
      @visual_assets.where(asset_type: ['logo', 'image']).each do |asset|
        if asset.metadata['dominant_colors'].present?
          colors[:primary].concat(asset.metadata['dominant_colors'].first(2))
          colors[:secondary].concat(asset.metadata['dominant_colors'][2..4] || [])
        end
      end
      
      # Process and deduplicate colors
      {
        primary: cluster_similar_colors(colors[:primary]).first(3),
        secondary: cluster_similar_colors(colors[:secondary]).first(4),
        accent: detect_accent_colors(colors),
        neutral: detect_neutral_colors(colors),
        color_relationships: analyze_color_relationships(colors)
      }
    end
    
    def cluster_similar_colors(colors)
      # Group similar colors together
      # This is a simplified version - in production, use proper color distance algorithms
      colors.uniq.sort_by { |color| color.downcase }
    end
    
    def detect_accent_colors(colors)
      # Detect high-saturation colors used sparingly
      []
    end
    
    def detect_neutral_colors(colors)
      # Detect grays, blacks, whites
      ['#FFFFFF', '#F5F5F5', '#E5E5E5', '#333333', '#000000']
    end
    
    def analyze_color_relationships(colors)
      {
        primary_usage: "Headers, CTAs, brand elements",
        secondary_usage: "Supporting elements, backgrounds",
        contrast_ratios: "Ensures accessibility"
      }
    end
    
    def extract_typography_from_assets
      typography = {
        fonts: [],
        weights: [],
        sizes: []
      }
      
      # Extract from metadata if available
      @visual_assets.each do |asset|
        if asset.metadata['fonts'].present?
          typography[:fonts].concat(Array(asset.metadata['fonts']))
        end
      end
      
      # Return structured typography data
      {
        primary_font: typography[:fonts].first || "System Default",
        secondary_font: typography[:fonts].second,
        heading_hierarchy: {
          h1: { size: "48px", weight: "bold" },
          h2: { size: "36px", weight: "semibold" },
          h3: { size: "24px", weight: "semibold" },
          h4: { size: "20px", weight: "medium" }
        },
        body_text: {
          size: "16px",
          line_height: "1.5",
          weight: "regular"
        }
      }
    end
    
    def analyze_imagery_style
      image_assets = @visual_assets.where(asset_type: 'image')
      
      return {} if image_assets.empty?
      
      {
        style_characteristics: determine_image_style(image_assets),
        common_subjects: extract_image_subjects(image_assets),
        color_treatment: analyze_image_color_treatment(image_assets),
        composition_patterns: analyze_composition(image_assets)
      }
    end
    
    def determine_image_style(assets)
      # Analyze metadata for style patterns
      styles = []
      
      assets.each do |asset|
        if asset.metadata['style'].present?
          styles << asset.metadata['style']
        end
      end
      
      # Return most common styles
      {
        primary_style: most_common(styles) || "modern",
        characteristics: ["clean", "professional", "vibrant"]
      }
    end
    
    def analyze_logo_usage
      logo_assets = @visual_assets.where(asset_type: 'logo')
      
      return {} unless logo_assets.any?
      
      {
        variations: logo_assets.pluck(:metadata).map { |m| m['variation'] }.compact.uniq,
        clear_space: "Minimum clear space equal to 'x' height",
        minimum_size: "No smaller than 24px height for digital",
        backgrounds: {
          preferred: "White or light backgrounds",
          acceptable: "Brand colors with sufficient contrast",
          prohibited: "Busy patterns or low contrast"
        }
      }
    end
    
    def calculate_visual_consistency
      # Measure consistency across visual assets
      consistency_factors = []
      
      # Color consistency
      if @visual_assets.any? { |a| a.metadata['dominant_colors'].present? }
        color_variations = @visual_assets.map { |a| a.metadata['dominant_colors'] }.compact
        consistency_factors << calculate_color_consistency(color_variations)
      end
      
      # Style consistency
      if @visual_assets.any? { |a| a.metadata['style'].present? }
        styles = @visual_assets.map { |a| a.metadata['style'] }.compact
        consistency_factors << calculate_style_consistency(styles)
      end
      
      consistency_factors.empty? ? 0.7 : (consistency_factors.sum / consistency_factors.size).round(2)
    end
    
    def calculate_color_consistency(color_sets)
      # Measure how consistent colors are across assets
      0.8  # Simplified - implement proper color distance calculation
    end
    
    def calculate_style_consistency(styles)
      # Measure style consistency
      unique_styles = styles.uniq.size
      total_styles = styles.size
      
      1.0 - (unique_styles - 1).to_f / total_styles
    end
    
    def enhance_visual_analysis_with_guides(analysis, guides)
      guides.each do |guide|
        # Extract explicit rules from style guide text
        if guide.extracted_text.present?
          extracted_rules = extract_visual_rules_from_text(guide.extracted_text)
          
          # Merge with analyzed data
          analysis[:colors].merge!(extracted_rules[:colors]) if extracted_rules[:colors]
          analysis[:typography].merge!(extracted_rules[:typography]) if extracted_rules[:typography]
          analysis[:imagery].merge!(extracted_rules[:imagery]) if extracted_rules[:imagery]
        end
      end
      
      analysis
    end
    
    def extract_visual_rules_from_text(text)
      # Use LLM to extract specific visual rules from style guide text
      prompt = build_visual_extraction_prompt(text)
      response = llm_service.analyze(prompt, json_response: true)
      
      parse_visual_rules_response(response)
    end
    
    def build_visual_extraction_prompt(text)
      <<~PROMPT
        Extract specific visual brand guidelines from this style guide text:
        
        #{text[0..3000]}
        
        Extract:
        1. Color codes (hex, RGB, CMYK)
        2. Font names and specifications
        3. Logo usage rules
        4. Image style requirements
        5. Spacing and layout rules
        
        Return as structured JSON.
      PROMPT
    end
    
    def parse_visual_rules_response(response)
      # Parse LLM response for visual rules
      {}
    end

    def default_voice_attributes
      {
        formality: default_dimension(:formality),
        energy: default_dimension(:energy),
        warmth: default_dimension(:warmth),
        authority: default_dimension(:authority),
        tone: default_tone,
        style: default_style,
        personality_traits: [],
        linguistic_patterns: {},
        emotional_tone: {}
      }
    end
    
    def default_dimension(name)
      {
        level: VOICE_DIMENSIONS[name][2],  # middle value
        score: 0.5,
        evidence: [],
        consistency: 0.5
      }
    end
    
    def default_tone
      {
        primary: 'professional',
        secondary: [],
        avoided: [],
        consistency: 0.5
      }
    end
    
    def default_style
      {
        writing: 'informative',
        sentence_structure: 'varied',
        vocabulary: 'intermediate',
        paragraph_length: 'medium',
        active_passive_ratio: 0.7
      }
    end

    def calculate_dimension_consistency(dimensions)
      return 1.0 if dimensions.size <= 1
      
      # Check how consistent the level is across chunks
      levels = dimensions.map { |d| d[:level] }
      unique_levels = levels.uniq
      
      # Perfect consistency = 1 unique level
      # Worst consistency = all different levels
      consistency = 1.0 - (unique_levels.size - 1).to_f / (VOICE_DIMENSIONS.values.first.size - 1)
      consistency.round(2)
    end
    
    def calculate_voice_consistency(analyses)
      # Overall consistency across all dimensions
      dimension_consistencies = [:formality, :energy, :warmth, :authority].map do |dim|
        analyses.first[dim][:consistency] || 0.5
      end
      
      (dimension_consistencies.sum / dimension_consistencies.size).round(2)
    end
    
    def aggregate_tone(analyses)
      # Collect all tone data
      all_primary = analyses.map { |a| a[:tone][:primary] }
      all_secondary = analyses.flat_map { |a| a[:tone][:secondary] || [] }
      all_avoided = analyses.flat_map { |a| a[:tone][:avoided] || [] }
      
      # Count frequencies
      primary_counts = all_primary.group_by(&:itself).transform_values(&:count)
      secondary_counts = all_secondary.group_by(&:itself).transform_values(&:count)
      
      {
        primary: primary_counts.max_by { |_, count| count }&.first || 'professional',
        secondary: secondary_counts.sort_by { |_, count| -count }
                                  .first(3)
                                  .map(&:first),
        avoided: all_avoided.group_by(&:itself)
                           .select { |_, instances| instances.size > 1 }
                           .keys,
        consistency: calculate_tone_consistency(analyses),
        distribution: primary_counts
      }
    end
    
    def calculate_tone_consistency(analyses)
      primary_tones = analyses.map { |a| a[:tone][:primary] }
      unique_primary = primary_tones.uniq
      
      # More consistent if fewer unique primary tones
      1.0 - (unique_primary.size - 1).to_f / analyses.size
    end
    
    def aggregate_style(analyses)
      styles = analyses.map { |a| a[:style] }.compact
      
      {
        writing: most_common(styles.map { |s| s[:writing] }),
        sentence_structure: most_common(styles.map { |s| s[:sentence_structure] }),
        vocabulary: most_common(styles.map { |s| s[:vocabulary] }),
        paragraph_length: most_common(styles.map { |s| s[:paragraph_length] }),
        active_passive_ratio: (styles.map { |s| s[:active_passive_ratio] }.sum / styles.size).round(2)
      }
    end
    
    def aggregate_personality_traits(analyses)
      all_traits = analyses.flat_map { |a| a[:personality_traits] || [] }
      trait_counts = all_traits.group_by(&:downcase).transform_values(&:count)
      
      # Sort by frequency and take top traits
      trait_counts.sort_by { |_, count| -count }
                  .first(7)
                  .map { |trait, count| 
                    { 
                      trait: all_traits.find { |t| t.downcase == trait },
                      frequency: count,
                      strength: count.to_f / analyses.size 
                    }
                  }
    end
    
    def aggregate_patterns(analyses)
      patterns = {
        common_phrases: [],
        power_words: [],
        transitions: [],
        openings: [],
        closings: []
      }
      
      analyses.each do |analysis|
        next unless analysis[:linguistic_patterns].is_a?(Hash)
        
        analysis[:linguistic_patterns].each do |key, values|
          patterns[key.to_sym] ||= []
          patterns[key.to_sym].concat(Array(values))
        end
      end
      
      # Deduplicate and count frequencies
      patterns.transform_values do |values|
        values.group_by(&:downcase)
              .select { |_, instances| instances.size > 1 }
              .sort_by { |_, instances| -instances.size }
              .first(10)
              .map { |_, instances| instances.first }
      end
    end
    
    def aggregate_emotional_tone(analyses)
      emotions = analyses.map { |a| a[:emotional_tone] }.compact
      
      return {} if emotions.empty?
      
      {
        primary_emotion: most_common(emotions.map { |e| e[:primary_emotion] }),
        emotional_range: most_common(emotions.map { |e| e[:emotional_range] }),
        positivity_ratio: (emotions.map { |e| e[:positivity_ratio] || 0.5 }.sum / emotions.size).round(2)
      }
    end
    
    def most_common(array)
      return nil if array.empty?
      array.group_by(&:itself).max_by { |_, v| v.size }&.first
    end

    def validate_patterns(patterns_data)
      return {} unless patterns_data.is_a?(Hash)
      
      {
        common_phrases: Array(patterns_data['common_phrases']).first(10),
        power_words: Array(patterns_data['power_words']).first(10),
        transitions: Array(patterns_data['transitions']).first(5),
        openings: Array(patterns_data['openings']).first(5),
        closings: Array(patterns_data['closings']).first(5)
      }
    end
    
    def validate_emotional_tone(emotional_data)
      return {} unless emotional_data.is_a?(Hash)
      
      {
        primary_emotion: emotional_data['primary_emotion'] || 'neutral',
        emotional_range: emotional_data['emotional_range'] || 'moderate',
        positivity_ratio: [emotional_data['positivity_ratio'].to_f, 1.0].min
      }
    end

    def cross_validate_findings(voice_attrs, brand_vals, messaging_pillars, guidelines)
      # Cross-reference all findings for consistency
      validated = {
        voice_attributes: voice_attrs,
        brand_values: brand_vals,
        messaging_pillars: messaging_pillars,
        guidelines: guidelines
      }
      
      # Validate voice attributes against guidelines
      voice_guideline_alignment = validate_voice_against_guidelines(voice_attrs, guidelines)
      
      # Validate brand values against messaging pillars
      value_pillar_alignment = validate_values_against_pillars(brand_vals, messaging_pillars)
      
      # Validate tone consistency across all elements
      tone_consistency = validate_tone_consistency(voice_attrs, guidelines, messaging_pillars)
      
      # Add validation metadata
      validated[:validation_results] = {
        voice_guideline_alignment: voice_guideline_alignment,
        value_pillar_alignment: value_pillar_alignment,
        tone_consistency: tone_consistency,
        overall_coherence: calculate_overall_coherence(voice_guideline_alignment, value_pillar_alignment, tone_consistency)
      }
      
      # Adjust findings based on validation
      if validated[:validation_results][:overall_coherence] < 0.7
        validated = reconcile_inconsistencies(validated)
      end
      
      validated
    end
    
    def validate_voice_against_guidelines(voice_attrs, guidelines)
      alignment_score = 1.0
      misalignments = []
      
      # Check if voice formality matches guideline requirements
      if guidelines[:voice_tone_rules][:must_do]
        formal_guidelines = guidelines[:voice_tone_rules][:must_do].select { |rule| 
          rule.downcase.include?('formal') || rule.downcase.include?('professional')
        }
        
        if formal_guidelines.any? && voice_attrs[:formality][:level] == 'very_casual'
          alignment_score -= 0.3
          misalignments << "Voice formality conflicts with guidelines"
        end
      end
      
      # Check tone alignment
      prohibited_tones = guidelines[:voice_tone_rules][:must_not_do] || []
      used_tones = [voice_attrs[:tone][:primary]] + (voice_attrs[:tone][:secondary] || [])
      
      conflicts = used_tones.select { |tone| 
        prohibited_tones.any? { |rule| rule.downcase.include?(tone.downcase) }
      }
      
      if conflicts.any?
        alignment_score -= 0.2 * conflicts.size
        misalignments << "Conflicting tones: #{conflicts.join(', ')}"
      end
      
      {
        score: [alignment_score, 0].max,
        misalignments: misalignments,
        recommendation: alignment_score < 0.7 ? "Review and reconcile voice guidelines" : "Good alignment"
      }
    end
    
    def validate_values_against_pillars(brand_values, messaging_pillars)
      # Check if brand values are reflected in messaging pillars
      values = brand_values.map { |v| v[:name].downcase }
      pillar_content = messaging_pillars[:pillars].flat_map { |p| 
        [p[:name], p[:description]] + p[:key_messages]
      }.join(' ').downcase
      
      reflected_values = values.select { |value| 
        pillar_content.include?(value) || 
        pillar_content.include?(value.gsub('-', ' '))
      }
      
      alignment_score = reflected_values.size.to_f / values.size
      
      {
        score: alignment_score,
        reflected: reflected_values,
        missing: values - reflected_values,
        recommendation: alignment_score < 0.6 ? "Strengthen value representation in messaging" : "Values well represented"
      }
    end
    
    def validate_tone_consistency(voice_attrs, guidelines, messaging_pillars)
      all_tones = []
      
      # Collect tones from voice analysis
      all_tones << voice_attrs[:tone][:primary]
      all_tones.concat(voice_attrs[:tone][:secondary] || [])
      
      # Collect implied tones from guidelines
      guideline_text = guidelines.values.flatten.join(' ').downcase
      TONE_ATTRIBUTES.each do |tone|
        all_tones << tone if guideline_text.include?(tone.downcase)
      end
      
      # Collect tones from messaging pillars
      pillars_text = messaging_pillars[:pillars].map { |p| p[:target_emotion] }.compact
      all_tones.concat(pillars_text)
      
      # Calculate consistency
      tone_groups = all_tones.group_by(&:downcase)
      consistency_score = tone_groups.values.map(&:size).max.to_f / all_tones.size
      
      {
        score: consistency_score,
        dominant_tones: tone_groups.sort_by { |_, v| -v.size }.first(3).map(&:first),
        variation: 1.0 - consistency_score,
        recommendation: consistency_score < 0.5 ? "Establish clearer tone direction" : "Consistent tone usage"
      }
    end
    
    def calculate_overall_coherence(voice_alignment, value_alignment, tone_consistency)
      weights = {
        voice: 0.35,
        values: 0.35,
        tone: 0.30
      }
      
      (
        voice_alignment[:score] * weights[:voice] +
        value_alignment[:score] * weights[:values] +
        tone_consistency[:score] * weights[:tone]
      ).round(2)
    end
    
    def reconcile_inconsistencies(validated)
      # Adjust findings to resolve major inconsistencies
      coherence = validated[:validation_results][:overall_coherence]
      
      if coherence < 0.5
        # Major inconsistencies - flag for manual review
        validated[:requires_manual_review] = true
        validated[:inconsistency_notes] = generate_inconsistency_report(validated[:validation_results])
      elsif coherence < 0.7
        # Minor inconsistencies - attempt automatic reconciliation
        
        # Adjust secondary tones that conflict
        if validated[:validation_results][:voice_guideline_alignment][:misalignments].any?
          conflicting_tones = validated[:voice_attributes][:tone][:secondary].select { |tone|
            validated[:guidelines][:voice_tone_rules][:must_not_do]&.any? { |rule| 
              rule.downcase.include?(tone.downcase)
            }
          }
          
          validated[:voice_attributes][:tone][:secondary] -= conflicting_tones
          validated[:voice_attributes][:tone][:avoided] = conflicting_tones
        end
      end
      
      validated
    end
    
    def generate_inconsistency_report(validation_results)
      report = []
      
      if validation_results[:voice_guideline_alignment][:score] < 0.7
        report << "Voice attributes conflict with stated guidelines: #{validation_results[:voice_guideline_alignment][:misalignments].join('; ')}"
      end
      
      if validation_results[:value_pillar_alignment][:score] < 0.6
        report << "Brand values not well reflected in messaging: Missing #{validation_results[:value_pillar_alignment][:missing].join(', ')}"
      end
      
      if validation_results[:tone_consistency][:score] < 0.5
        report << "Inconsistent tone usage across brand materials"
      end
      
      report
    end

    def extract_image_subjects(assets)
      subjects = []
      
      assets.each do |asset|
        if asset.metadata['subjects'].present?
          subjects.concat(Array(asset.metadata['subjects']))
        end
      end
      
      subjects.group_by(&:itself)
             .sort_by { |_, instances| -instances.size }
             .first(10)
             .map { |subject, _| subject }
    end
    
    def analyze_image_color_treatment(assets)
      treatments = []
      
      assets.each do |asset|
        if asset.metadata['color_treatment'].present?
          treatments << asset.metadata['color_treatment']
        end
      end
      
      {
        dominant_treatment: most_common(treatments) || "natural",
        variations: treatments.uniq
      }
    end
    
    def analyze_composition(assets)
      compositions = []
      
      assets.each do |asset|
        if asset.metadata['composition'].present?
          compositions << asset.metadata['composition']
        end
      end
      
      {
        common_patterns: compositions.group_by(&:itself)
                                    .sort_by { |_, v| -v.size }
                                    .first(5)
                                    .map(&:first),
        guidelines: "Follow rule of thirds, maintain visual hierarchy"
      }
    end

    def calculate_comprehensive_confidence_score(validated_data)
      scores = {}
      
      # Content volume score
      content_score = calculate_content_volume_score
      scores[:content_volume] = content_score
      
      # Voice consistency score
      voice_consistency = validated_data[:voice_attributes][:consistency_score] || 0.5
      scores[:voice_consistency] = voice_consistency
      
      # Value extraction confidence
      value_confidence = calculate_value_extraction_confidence(validated_data[:brand_values])
      scores[:value_confidence] = value_confidence
      
      # Messaging clarity score
      messaging_clarity = calculate_messaging_clarity(validated_data[:messaging_pillars])
      scores[:messaging_clarity] = messaging_clarity
      
      # Guidelines completeness
      guidelines_completeness = calculate_guidelines_completeness(validated_data[:guidelines])
      scores[:guidelines_completeness] = guidelines_completeness
      
      # Visual analysis confidence (if applicable)
      if validated_data[:visual_guidelines].present? && validated_data[:visual_guidelines].any?
        visual_confidence = validated_data[:visual_guidelines][:visual_consistency] || 0.5
        scores[:visual_confidence] = visual_confidence
      end
      
      # Cross-validation score
      validation_score = validated_data[:validation_results][:overall_coherence] || 0.7
      scores[:cross_validation] = validation_score
      
      # Calculate weighted overall score
      weights = {
        content_volume: 0.15,
        voice_consistency: 0.20,
        value_confidence: 0.15,
        messaging_clarity: 0.15,
        guidelines_completeness: 0.15,
        visual_confidence: 0.10,
        cross_validation: 0.20
      }
      
      overall_score = scores.sum { |key, score| 
        weight = weights[key] || 0
        score * weight 
      }
      
      {
        overall: overall_score.round(2),
        breakdown: scores,
        confidence_level: determine_confidence_level(overall_score),
        recommendations: generate_confidence_recommendations(scores)
      }
    end
    
    def calculate_content_volume_score
      word_count = @content.split.size
      source_count = @content_sources&.size || 1
      
      # Score based on word count
      volume_score = case word_count
                    when 0..500 then 0.2
                    when 501..1000 then 0.4
                    when 1001..3000 then 0.6
                    when 3001..7000 then 0.8
                    when 7001..15000 then 0.9
                    else 1.0
                    end
      
      # Bonus for multiple sources
      source_bonus = [source_count * 0.05, 0.2].min
      
      [volume_score + source_bonus, 1.0].min
    end
    
    def calculate_value_extraction_confidence(brand_values)
      return 0.3 if brand_values.empty?
      
      # Average confidence of top values
      top_values = brand_values.first(5)
      avg_score = top_values.map { |v| v[:score] }.sum / top_values.size
      
      # Bonus for explicit values
      explicit_count = brand_values.count { |v| v[:type] == :explicit }
      explicit_bonus = [explicit_count * 0.1, 0.3].min
      
      [avg_score + explicit_bonus, 1.0].min
    end
    
    def calculate_messaging_clarity(messaging_data)
      return 0.3 unless messaging_data[:pillars].any?
      
      pillars = messaging_data[:pillars]
      
      # Score based on pillar strength and consistency
      avg_strength = pillars.map { |p| p[:strength_score] }.sum / pillars.size
      avg_consistency = pillars.map { |p| p[:consistency_score] }.sum / pillars.size
      
      (avg_strength * 0.6 + avg_consistency * 0.4).round(2)
    end
    
    def calculate_guidelines_completeness(guidelines)
      total_categories = 5  # voice, messaging, visual, grammar, behavioral
      populated_categories = 0
      total_rules = 0
      
      [:voice_tone_rules, :messaging_rules, :visual_rules, :grammar_style_rules, :behavioral_rules].each do |category|
        if guidelines[category].present? && guidelines[category].any? { |_, v| v.present? && v.any? }
          populated_categories += 1
          total_rules += guidelines[category].values.flatten.size
        end
      end
      
      category_score = populated_categories.to_f / total_categories
      
      # Bonus for having many specific rules
      rule_bonus = case total_rules
                  when 0..5 then 0
                  when 6..15 then 0.1
                  when 16..30 then 0.2
                  else 0.3
                  end
      
      [category_score + rule_bonus, 1.0].min
    end
    
    def determine_confidence_level(score)
      case score
      when 0.9..1.0 then "Very High"
      when 0.75..0.89 then "High"
      when 0.6..0.74 then "Moderate"
      when 0.4..0.59 then "Low"
      else "Very Low"
      end
    end
    
    def generate_confidence_recommendations(scores)
      recommendations = []
      
      scores.each do |aspect, score|
        if score < 0.6
          case aspect
          when :content_volume
            recommendations << "Upload more brand materials for comprehensive analysis"
          when :voice_consistency
            recommendations << "Review brand voice for consistency across materials"
          when :value_confidence
            recommendations << "Clarify and explicitly state core brand values"
          when :messaging_clarity
            recommendations << "Develop clearer messaging pillars and key messages"
          when :guidelines_completeness
            recommendations << "Create more comprehensive brand guidelines"
          when :visual_confidence
            recommendations << "Ensure visual assets follow consistent style"
          when :cross_validation
            recommendations << "Align voice, values, and messaging for coherence"
          end
        end
      end
      
      recommendations
    end

    def create_comprehensive_guidelines(analysis)
      guidelines = []
      
      # Process each category of rules
      process_voice_tone_guidelines(analysis, guidelines)
      process_messaging_guidelines(analysis, guidelines)
      process_visual_guidelines(analysis, guidelines)
      process_grammar_style_guidelines(analysis, guidelines)
      process_behavioral_guidelines(analysis, guidelines)
      
      # Create high-priority rules from rule_priorities
      if analysis.extracted_rules[:rule_priorities]
        create_priority_guidelines(analysis.extracted_rules[:rule_priorities], guidelines)
      end
      
      guidelines
    end
    
    def process_voice_tone_guidelines(analysis, guidelines)
      rules = analysis.extracted_rules[:voice_tone_rules] || {}
      
      # Must do rules
      rules[:must_do]&.each_with_index do |rule, index|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: rule,
          category: "voice",
          priority: 9 - (index * 0.1),
          metadata: { source: "analysis", confidence: analysis.confidence_score }
        )
      end
      
      # Should do rules
      rules[:should_do]&.each_with_index do |rule, index|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "should",
          rule_content: rule,
          category: "voice",
          priority: 7 - (index * 0.1),
          metadata: { source: "analysis" }
        )
      end
      
      # Must not do rules
      rules[:must_not_do]&.each_with_index do |rule, index|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must_not",
          rule_content: rule,
          category: "voice",
          priority: 8 - (index * 0.1),
          metadata: { source: "analysis" }
        )
      end
    end
    
    def process_messaging_guidelines(analysis, guidelines)
      rules = analysis.extracted_rules[:messaging_rules] || {}
      
      # Required elements
      rules[:required_elements]&.each do |element|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "Include: #{element}",
          category: "messaging",
          priority: 8.5,
          metadata: { element_type: "required" }
        )
      end
      
      # Key phrases
      if rules[:key_phrases]&.any?
        guidelines << brand.brand_guidelines.create!(
          rule_type: "should",
          rule_content: "Use key phrases: #{rules[:key_phrases].join(', ')}",
          category: "messaging",
          priority: 7,
          metadata: { phrases: rules[:key_phrases] }
        )
      end
      
      # Prohibited topics
      rules[:prohibited_topics]&.each do |topic|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must_not",
          rule_content: "Avoid discussing: #{topic}",
          category: "messaging",
          priority: 8,
          metadata: { topic_type: "prohibited" }
        )
      end
    end
    
    def process_visual_guidelines(analysis, guidelines)
      visual = analysis.extracted_rules[:visual_rules] || {}
      
      # Color rules
      if visual[:colors]&.any? { |_, v| v.present? && v.any? }
        color_rule = build_color_rule(visual[:colors])
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: color_rule,
          category: "visual",
          priority: 9,
          metadata: { colors: visual[:colors] }
        )
      end
      
      # Typography rules
      if visual[:typography][:fonts]&.any?
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "Use fonts: #{visual[:typography][:fonts].join(', ')}",
          category: "visual",
          priority: 8.5,
          metadata: { typography: visual[:typography] }
        )
      end
      
      # Imagery rules
      if visual[:imagery][:do]&.any?
        guidelines << brand.brand_guidelines.create!(
          rule_type: "should",
          rule_content: "Image style: #{visual[:imagery][:style]}. #{visual[:imagery][:do].first(3).join('; ')}",
          category: "visual",
          priority: 7
        )
      end
      
      if visual[:imagery][:dont]&.any?
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must_not",
          rule_content: "Avoid: #{visual[:imagery][:dont].first(3).join('; ')}",
          category: "visual",
          priority: 7.5
        )
      end
    end
    
    def build_color_rule(colors)
      parts = []
      parts << "Primary colors: #{colors[:primary].join(', ')}" if colors[:primary]&.any?
      parts << "Secondary colors: #{colors[:secondary].join(', ')}" if colors[:secondary]&.any?
      parts.join('. ')
    end
    
    def process_grammar_style_guidelines(analysis, guidelines)
      rules = analysis.extracted_rules[:grammar_style_rules] || {}
      
      # Combine all grammar rules into comprehensive guidelines
      if rules.any? { |_, v| v.present? && v.any? }
        style_rules = []
        style_rules.concat(rules[:punctuation] || [])
        style_rules.concat(rules[:capitalization] || [])
        style_rules.concat(rules[:formatting] || [])
        
        if style_rules.any?
          guidelines << brand.brand_guidelines.create!(
            rule_type: "must",
            rule_content: "Follow style rules: #{style_rules.first(5).join('; ')}",
            category: "grammar",
            priority: 7,
            metadata: { style_rules: rules }
          )
        end
      end
      
      # Preferred terms
      if rules[:preferred_terms]&.any?
        term_guidelines = rules[:preferred_terms].map { |preferred, avoid| 
          "Use '#{preferred}' instead of '#{avoid}'"
        }
        
        guidelines << brand.brand_guidelines.create!(
          rule_type: "should",
          rule_content: term_guidelines.join('; '),
          category: "grammar",
          priority: 6.5,
          metadata: { terms: rules[:preferred_terms] }
        )
      end
    end
    
    def process_behavioral_guidelines(analysis, guidelines)
      rules = analysis.extracted_rules[:behavioral_rules] || {}
      
      # Customer interaction rules
      rules[:customer_interaction]&.each do |rule|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: rule,
          category: "behavior",
          priority: 8,
          metadata: { interaction_type: "customer" }
        )
      end
      
      # Response patterns
      if rules[:response_patterns]&.any?
        guidelines << brand.brand_guidelines.create!(
          rule_type: "should",
          rule_content: "Response approach: #{rules[:response_patterns].join('; ')}",
          category: "behavior",
          priority: 7
        )
      end
      
      # Ethical guidelines
      rules[:ethical_guidelines]&.each do |guideline|
        guidelines << brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: guideline,
          category: "behavior",
          priority: 9,
          metadata: { guideline_type: "ethical" }
        )
      end
    end
    
    def create_priority_guidelines(priorities, guidelines)
      # Create guidelines for the highest priority rules
      priorities.select { |p| p[:importance] >= 8 }.each do |priority_rule|
        existing = guidelines.find { |g| 
          g.rule_content.downcase.include?(priority_rule[:rule].downcase)
        }
        
        unless existing
          guidelines << brand.brand_guidelines.create!(
            rule_type: "must",
            rule_content: priority_rule[:rule],
            category: priority_rule[:category] || "general",
            priority: priority_rule[:importance],
            metadata: { 
              consequences: priority_rule[:consequences],
              source: "high_priority_analysis"
            }
          )
        end
      end
    end

    def update_messaging_framework_detailed(analysis)
      framework = brand.messaging_framework || brand.build_messaging_framework
      
      # Extract comprehensive tone data
      tone_data = {
        primary: analysis.voice_attributes[:tone][:primary],
        secondary: analysis.voice_attributes[:tone][:secondary],
        avoided: analysis.voice_attributes[:tone][:avoided],
        emotional_tone: analysis.voice_attributes[:emotional_tone],
        consistency: analysis.voice_attributes[:tone][:consistency]
      }
      
      # Build structured key messages from pillars
      key_messages = build_structured_key_messages(analysis.messaging_pillars)
      
      # Create value propositions with evidence
      value_props = build_evidence_based_value_propositions(analysis)
      
      # Update framework with comprehensive data
      framework.update!(
        tone_attributes: tone_data,
        key_messages: key_messages,
        value_propositions: value_props,
        audience_personas: extract_audience_insights(analysis),
        differentiation_points: extract_differentiators(analysis),
        brand_promise: generate_brand_promise(analysis),
        elevator_pitch: generate_elevator_pitch(analysis)
      )
      
      framework
    end
    
    def build_structured_key_messages(messaging_pillars)
      return {} unless messaging_pillars[:pillars].present?
      
      messages = {}
      
      messaging_pillars[:pillars].each do |pillar|
        messages[pillar[:name]] = {
          core_message: pillar[:description],
          supporting_points: pillar[:key_messages] || [],
          proof_points: pillar[:supporting_points] || [],
          emotional_goal: pillar[:target_emotion],
          usage_contexts: determine_usage_contexts(pillar)
        }
      end
      
      # Add hierarchy information
      messages[:hierarchy] = messaging_pillars[:pillar_hierarchy]
      
      messages
    end
    
    def build_evidence_based_value_propositions(analysis)
      primary_values = analysis.brand_values.first(3)
      
      {
        core_value_prop: generate_core_value_proposition(primary_values, analysis.messaging_pillars),
        supporting_props: primary_values.map { |value| 
          {
            value: value[:name],
            proposition: "We deliver #{value[:name].downcase} through #{value[:contexts].first}",
            evidence: value[:evidence],
            strength: value[:score]
          }
        },
        proof_points: extract_proof_points(analysis),
        competitive_advantages: identify_competitive_advantages(analysis)
      }
    end
    
    def generate_core_value_proposition(values, pillars)
      # Generate a cohesive value proposition from top values and pillars
      value_names = values.map { |v| v[:name] }.join(', ')
      primary_pillar = pillars[:pillars].first
      
      "We deliver #{value_names} by #{primary_pillar[:description].downcase}, "\
      "enabling #{primary_pillar[:target_emotion] || 'success'} for our customers."
    end
    
    def extract_audience_insights(analysis)
      # Extract implied audience characteristics from voice and messaging
      {
        communication_preferences: determine_audience_preferences(analysis.voice_attributes),
        value_alignment: analysis.brand_values.map { |v| v[:name] },
        emotional_drivers: extract_emotional_drivers(analysis.messaging_pillars),
        sophistication_level: determine_audience_sophistication(analysis.voice_attributes)
      }
    end
    
    def determine_audience_preferences(voice_attrs)
      preferences = []
      
      case voice_attrs[:formality][:level]
      when 'very_formal', 'formal'
        preferences << "Professional communication"
        preferences << "Detailed information"
      when 'casual', 'very_casual'
        preferences << "Conversational tone"
        preferences << "Quick, digestible content"
      else
        preferences << "Balanced communication style"
      end
      
      case voice_attrs[:style][:writing]
      when 'technical'
        preferences << "Data-driven insights"
        preferences << "Specific details"
      when 'storytelling'
        preferences << "Narrative examples"
        preferences << "Relatable scenarios"
      end
      
      preferences
    end
    
    def extract_emotional_drivers(messaging_pillars)
      pillars = messaging_pillars[:pillars] || []
      
      drivers = pillars.map { |p| p[:target_emotion] }.compact.uniq
      drivers.presence || ['trust', 'confidence', 'success']
    end
    
    def determine_audience_sophistication(voice_attrs)
      case voice_attrs[:style][:vocabulary]
      when 'advanced', 'technical'
        'High - Expert level'
      when 'intermediate'
        'Medium - Professional level'
      else
        'Accessible - General audience'
      end
    end
    
    def extract_differentiators(analysis)
      differentiators = []
      
      # Extract from messaging pillars
      analysis.messaging_pillars[:pillars].each do |pillar|
        if pillar[:name].downcase.include?('unique') || 
           pillar[:name].downcase.include?('different') ||
           pillar[:description].downcase.include?('only')
          differentiators << {
            point: pillar[:name],
            description: pillar[:description],
            evidence: pillar[:supporting_points]
          }
        end
      end
      
      # Extract from brand values that suggest differentiation
      unique_values = analysis.brand_values.select { |v| 
        v[:score] > 0.8 && v[:type] == :explicit 
      }
      
      unique_values.each do |value|
        differentiators << {
          point: "#{value[:name]} Leadership",
          description: "Demonstrated commitment to #{value[:name].downcase}",
          evidence: value[:evidence]
        }
      end
      
      differentiators.first(5)
    end
    
    def generate_brand_promise(analysis)
      # Create a concise brand promise from values and pillars
      top_value = analysis.brand_values.first[:name]
      primary_pillar = analysis.messaging_pillars[:pillars].first
      
      "We promise to deliver #{top_value.downcase} through #{primary_pillar[:description].downcase}, "\
      "ensuring #{primary_pillar[:target_emotion] || 'exceptional outcomes'} in every interaction."
    end
    
    def generate_elevator_pitch(analysis)
      # Create a 30-second elevator pitch
      values = analysis.brand_values.first(2).map { |v| v[:name] }.join(' and ')
      pillars = analysis.messaging_pillars[:pillars].first(2)
      
      "We are committed to #{values.downcase}, #{pillars.first[:description].downcase}. "\
      "#{pillars.second ? "We also #{pillars.second[:description].downcase}, " : ''}"\
      "delivering #{analysis.voice_attributes[:emotional_tone][:primary_emotion] || 'positive'} "\
      "experiences that #{pillars.first[:key_messages].first&.downcase || 'drive results'}."
    end
    
    def determine_usage_contexts(pillar)
      contexts = []
      
      # Determine contexts based on pillar content
      keywords = (pillar[:name] + ' ' + pillar[:description]).downcase
      
      contexts << "Sales conversations" if keywords.include?('value') || keywords.include?('benefit')
      contexts << "Marketing materials" if keywords.include?('brand') || keywords.include?('story')
      contexts << "Customer support" if keywords.include?('help') || keywords.include?('support')
      contexts << "Product descriptions" if keywords.include?('feature') || keywords.include?('capability')
      contexts << "Executive communications" if keywords.include?('vision') || keywords.include?('leadership')
      
      contexts.presence || ["General communications"]
    end
    
    def extract_proof_points(analysis)
      proof_points = []
      
      # Extract from pillar supporting points
      analysis.messaging_pillars[:pillars].each do |pillar|
        pillar[:supporting_points]&.each do |point|
          proof_points << {
            claim: pillar[:name],
            proof: point,
            strength: pillar[:strength_score]
          }
        end
      end
      
      # Extract from value evidence
      analysis.brand_values.each do |value|
        value[:evidence]&.each do |evidence|
          proof_points << {
            claim: value[:name],
            proof: evidence,
            strength: value[:score]
          }
        end
      end
      
      # Sort by strength and take top proof points
      proof_points.sort_by { |p| -p[:strength] }.first(10)
    end
    
    def identify_competitive_advantages(analysis)
      advantages = []
      
      # Look for superlatives and unique claims in pillars
      analysis.messaging_pillars[:pillars].each do |pillar|
        pillar[:key_messages]&.each do |message|
          if message =~ /best|first|only|unique|leading|superior/i
            advantages << message
          end
        end
      end
      
      # Look for high-scoring explicit values
      top_values = analysis.brand_values.select { |v| v[:score] > 0.85 && v[:type] == :explicit }
      top_values.each do |value|
        advantages << "Industry-leading commitment to #{value[:name].downcase}"
      end
      
      advantages.uniq.first(5)
    end
    
    def generate_brand_consistency_report(analysis)
      # This could be expanded to create a detailed consistency report
      # For now, we'll add it to the analysis notes
      
      consistency_data = {
        voice_consistency: analysis.voice_attributes[:consistency_score],
        value_alignment: analysis.analysis_data.dig('validation_results', 'value_pillar_alignment', 'score'),
        tone_consistency: analysis.analysis_data.dig('validation_results', 'tone_consistency', 'score'),
        rule_consistency: analysis.extracted_rules[:rule_consistency],
        visual_consistency: analysis.visual_guidelines[:visual_consistency],
        overall_coherence: analysis.analysis_data.dig('validation_results', 'overall_coherence')
      }
      
      report_summary = consistency_data.map { |aspect, score| 
        "#{aspect.to_s.humanize}: #{(score * 100).round}%" if score
      }.compact.join(', ')
      
      analysis.update!(
        analysis_notes: (analysis.analysis_notes || '') + "\n\nConsistency Report: #{report_summary}"
      )
    end

    def llm_service
      @llm_service ||= LlmService.new(
        model: @llm_provider,
        temperature: @options[:temperature] || 0.7
      )
    end
  end
end