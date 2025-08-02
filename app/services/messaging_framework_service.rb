class MessagingFrameworkService
  include ActiveSupport::Configurable

  config_accessor :real_time_validation, default: true
  config_accessor :compliance_threshold, default: 0.8
  config_accessor :cache_validations, default: true

  attr_reader :brand, :content, :framework_data, :validation_results

  # Content validation patterns
  VALIDATION_PATTERNS = {
    tone_consistency: {
      formal: /\b(?:furthermore|therefore|consequently|nevertheless|moreover)\b/i,
      casual: /\b(?:hey|cool|awesome|totally|super|gonna)\b/i,
      professional: /\b(?:deliver|optimize|strategic|innovative|excellence)\b/i
    },
    brand_voice: {
      authoritative: /\b(?:proven|certified|guaranteed|established|leading)\b/i,
      friendly: /\b(?:welcome|happy|excited|love|enjoy)\b/i,
      helpful: /\b(?:assist|support|guide|help|enable)\b/i
    },
    compliance_violations: {
      competitor_mentions: /\b(?:competitor|rival|alternative|versus|vs\.)\b/i,
      prohibited_terms: /\b(?:cheap|discount|sale|free|limited time)\b/i,
      unapproved_claims: /\b(?:best|number one|unbeatable|perfect)\b/i
    }
  }.freeze

  # Scoring weights for different validation aspects
  SCORING_WEIGHTS = {
    tone_consistency: 0.3,
    voice_alignment: 0.25,
    message_clarity: 0.2,
    compliance: 0.15,
    brand_alignment: 0.1
  }.freeze

  def initialize(brand, content = nil, framework_data = {})
    @brand = brand
    @content = content
    @framework_data = framework_data.with_indifferent_access
    @validation_results = {}
  end

  def create_messaging_framework(brand_analysis)
    framework = {
      core_messages: extract_core_messages(brand_analysis),
      voice_guidelines: build_voice_guidelines(brand_analysis),
      tone_variations: generate_tone_variations(brand_analysis),
      message_hierarchy: establish_message_hierarchy(brand_analysis),
      channel_adaptations: create_channel_adaptations(brand_analysis),
      compliance_rules: build_compliance_rules(brand_analysis),
      validation_criteria: define_validation_criteria(brand_analysis)
    }

    store_framework(framework)
    framework
  end

  def validate_content_real_time(content, context = {})
    return { valid: true, score: 1.0 } unless config.real_time_validation

    validation_scores = {}
    violations = []
    recommendations = []

    # Tone consistency validation
    tone_score = validate_tone_consistency(content)
    validation_scores[:tone_consistency] = tone_score[:score]
    violations.concat(tone_score[:violations])

    # Voice alignment validation
    voice_score = validate_voice_alignment(content)
    validation_scores[:voice_alignment] = voice_score[:score]
    violations.concat(voice_score[:violations])

    # Message clarity validation
    clarity_score = validate_message_clarity(content)
    validation_scores[:message_clarity] = clarity_score[:score]
    recommendations.concat(clarity_score[:recommendations])

    # Compliance validation
    compliance_score = validate_compliance(content)
    validation_scores[:compliance] = compliance_score[:score]
    violations.concat(compliance_score[:violations])

    # Calculate overall score
    overall_score = calculate_weighted_score(validation_scores)

    {
      valid: overall_score >= config.compliance_threshold,
      score: overall_score,
      breakdown: validation_scores,
      violations: violations,
      recommendations: recommendations,
      context: context
    }
  end

  def generate_compliance_report(content_items)
    report = {
      summary: {
        total_items: content_items.size,
        compliant_items: 0,
        average_score: 0.0,
        common_violations: []
      },
      detailed_results: [],
      recommendations: []
    }

    all_violations = []
    total_score = 0.0

    content_items.each do |item|
      result = validate_content_real_time(item[:content], item[:context] || {})

      report[:detailed_results] << {
        item_id: item[:id],
        content_type: item[:type],
        score: result[:score],
        violations: result[:violations],
        recommendations: result[:recommendations]
      }

      report[:summary][:compliant_items] += 1 if result[:valid]
      all_violations.concat(result[:violations])
      total_score += result[:score]
    end

    report[:summary][:average_score] = (total_score / content_items.size).round(3)
    report[:summary][:common_violations] = find_common_violations(all_violations)
    report[:recommendations] = generate_global_recommendations(all_violations)

    report
  end

  private

  def extract_core_messages(brand_analysis)
    messaging_data = brand_analysis.analysis_data&.dig("messaging_framework") || {}

    {
      primary_message: messaging_data["key_messages"]&.first || "Driving innovation through excellence",
      supporting_messages: messaging_data["key_messages"] || [],
      value_propositions: messaging_data["value_propositions"] || [],
      proof_points: extract_proof_points(brand_analysis),
      call_to_actions: generate_ctas(brand_analysis)
    }
  end

  def build_voice_guidelines(brand_analysis)
    voice_data = brand_analysis.voice_attributes || {}

    {
      primary_tone: voice_data["tone"] || "professional",
      formality_level: voice_data["formality"] || "semi-formal",
      personality_traits: brand_analysis.brand_values || [],
      do_say: generate_approved_phrases(brand_analysis),
      dont_say: generate_prohibited_phrases(brand_analysis),
      examples: {
        good: generate_good_examples(voice_data),
        bad: generate_bad_examples(voice_data)
      }
    }
  end

  def generate_tone_variations(brand_analysis)
    base_tone = brand_analysis.voice_tone

    {
      social_media: adapt_tone_for_channel(base_tone, "social"),
      email_marketing: adapt_tone_for_channel(base_tone, "email"),
      website_copy: adapt_tone_for_channel(base_tone, "web"),
      presentations: adapt_tone_for_channel(base_tone, "presentation"),
      documentation: adapt_tone_for_channel(base_tone, "documentation")
    }
  end

  def validate_tone_consistency(content)
    brand_tone = brand.brand_analyses.recent.first&.voice_tone || "professional"
    detected_patterns = []
    violations = []

    VALIDATION_PATTERNS[:tone_consistency].each do |tone, pattern|
      matches = content.scan(pattern).size
      detected_patterns << { tone: tone, matches: matches } if matches > 0
    end

    # Check if detected tone matches brand tone
    primary_detected = detected_patterns.max_by { |p| p[:matches] }

    if primary_detected && primary_detected[:tone].to_s != brand_tone
      violations << {
        type: "tone_mismatch",
        message: "Detected #{primary_detected[:tone]} tone, but brand uses #{brand_tone}",
        severity: "medium"
      }
    end

    score = violations.empty? ? 1.0 : [ 1.0 - (violations.size * 0.2), 0.0 ].max

    { score: score, violations: violations, detected_patterns: detected_patterns }
  end

  def validate_voice_alignment(content)
    violations = []
    recommendations = []

    # Check for brand voice patterns
    brand_values = brand.brand_analyses.recent.first&.brand_values || []

    if brand_values.include?("friendly") && !content.match?(VALIDATION_PATTERNS[:brand_voice][:friendly])
      recommendations << {
        type: "voice_enhancement",
        message: "Consider adding more friendly language to align with brand values",
        severity: "low"
      }
    end

    score = violations.empty? ? 0.9 : [ 0.9 - (violations.size * 0.15), 0.0 ].max

    { score: score, violations: violations, recommendations: recommendations }
  end

  def validate_message_clarity(content)
    recommendations = []

    # Basic readability checks
    sentences = content.split(/[.!?]+/)
    avg_sentence_length = sentences.map(&:split).map(&:size).sum.to_f / sentences.size

    if avg_sentence_length > 20
      recommendations << {
        type: "readability",
        message: "Consider shorter sentences for better readability (current avg: #{avg_sentence_length.round(1)} words)",
        severity: "low"
      }
    end

    score = avg_sentence_length > 25 ? 0.7 : 0.9

    { score: score, recommendations: recommendations }
  end

  def validate_compliance(content)
    violations = []

    VALIDATION_PATTERNS[:compliance_violations].each do |violation_type, pattern|
      matches = content.scan(pattern)
      if matches.any?
        violations << {
          type: violation_type,
          message: "Found prohibited #{violation_type.to_s.humanize.downcase}: #{matches.first(3).join(', ')}",
          severity: "high",
          matches: matches
        }
      end
    end

    score = violations.empty? ? 1.0 : [ 1.0 - (violations.size * 0.3), 0.0 ].max

    { score: score, violations: violations }
  end

  def calculate_weighted_score(validation_scores)
    total_score = 0.0

    SCORING_WEIGHTS.each do |category, weight|
      score = validation_scores[category] || 0.5
      total_score += (score * weight)
    end

    total_score.round(3)
  end

  def adapt_tone_for_channel(base_tone, channel)
    adaptations = {
      "social" => { formality: -1, energy: +1 },
      "email" => { formality: 0, personal: +1 },
      "web" => { clarity: +1, conciseness: +1 },
      "presentation" => { authority: +1, formality: +1 },
      "documentation" => { precision: +1, formality: +1 }
    }

    {
      base_tone: base_tone,
      channel_adaptations: adaptations[channel] || {},
      sample_phrases: generate_channel_phrases(base_tone, channel)
    }
  end

  def generate_channel_phrases(tone, channel)
    # Mock channel-specific phrase generation
    {
      openings: [ "Welcome to #{channel} content", "Discover our #{channel} approach" ],
      closings: [ "Learn more", "Get started today" ],
      transitions: [ "Additionally", "Furthermore", "Next" ]
    }
  end

  def extract_proof_points(brand_analysis)
    [ "Industry-leading results", "Trusted by 500+ companies", "Award-winning platform" ]
  end

  def generate_ctas(brand_analysis)
    [ "Get Started", "Learn More", "Contact Us", "Download Now", "Schedule Demo" ]
  end

  def generate_approved_phrases(brand_analysis)
    [ "innovative solutions", "proven results", "strategic advantage", "measurable outcomes" ]
  end

  def generate_prohibited_phrases(brand_analysis)
    [ "cheap alternative", "quick fix", "guaranteed results", "one-size-fits-all" ]
  end

  def generate_good_examples(voice_data)
    [ "We deliver strategic solutions that drive measurable growth for your business." ]
  end

  def generate_bad_examples(voice_data)
    [ "Buy our cheap stuff now! Limited time offer!" ]
  end

  def find_common_violations(all_violations)
    violation_counts = all_violations.group_by { |v| v[:type] }.transform_values(&:size)
    violation_counts.sort_by { |_, count| -count }.first(5).to_h
  end

  def generate_global_recommendations(all_violations)
    common_violations = find_common_violations(all_violations)

    common_violations.map do |violation_type, count|
      {
        type: violation_type,
        frequency: count,
        recommendation: "Address #{violation_type.to_s.humanize.downcase} issues across #{count} content items"
      }
    end
  end

  def store_framework(framework)
    # Store the messaging framework in the brand's messaging_frameworks
    messaging_framework = brand.messaging_frameworks.find_or_create_by(
      framework_type: "primary"
    )

    messaging_framework.update!(
      framework_data: framework,
      updated_at: Time.current
    )
  end
end
