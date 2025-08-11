# AI Content Validator for quality and appropriateness checks
# Validates AI-generated content for marketing campaigns
class AiContentValidator
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Validation types
  VALIDATION_TYPES = %w[
    quality
    appropriateness
    brand_compliance
    content_structure
    language_quality
    marketing_effectiveness
    platform_compliance
    safety
  ].freeze

  # Content categories
  CONTENT_CATEGORIES = %w[
    social_media
    email
    ad_copy
    blog_post
    landing_page
    campaign_strategy
    brand_analysis
  ].freeze

  # Validation severity levels
  SEVERITY_LEVELS = %w[info warning error critical].freeze

  class ValidationError < StandardError; end
  class InvalidConfigurationError < ValidationError; end

  attribute :validation_types, :string, default: -> { ['quality', 'appropriateness'] }
  attribute :content_category, :string, default: 'general'
  attribute :brand_guidelines, :string, default: -> { {} }
  attribute :platform_requirements, :string, default: -> { {} }
  attribute :strict_mode, :boolean, default: false
  attribute :min_quality_score, :integer, default: 70

  attr_reader :validation_results, :overall_score

  def initialize(attributes = {})
    super(attributes)
    @validation_results = []
    @overall_score = 0
    validate_configuration!
  end

  # Validate content and return comprehensive results
  def validate(content, options = {})
    return validation_error("Content cannot be empty") if content.blank?

    @validation_results = []
    @content = content
    @options = options

    # Normalize content for validation
    normalized_content = normalize_content(content)
    
    # Run each validation type
    validation_types.each do |validation_type|
      begin
        case validation_type
        when 'quality'
          validate_content_quality(normalized_content)
        when 'appropriateness'
          validate_content_appropriateness(normalized_content)
        when 'brand_compliance'
          validate_brand_compliance(normalized_content)
        when 'content_structure'
          validate_content_structure(normalized_content)
        when 'language_quality'
          validate_language_quality(normalized_content)
        when 'marketing_effectiveness'
          validate_marketing_effectiveness(normalized_content)
        when 'platform_compliance'
          validate_platform_compliance(normalized_content)
        when 'safety'
          validate_safety(normalized_content)
        end
      rescue => error
        add_result(
          type: validation_type,
          status: 'error',
          severity: 'critical',
          message: "Validation failed: #{error.message}",
          details: { error_class: error.class.name }
        )
      end
    end

    # Calculate overall score
    calculate_overall_score
    
    # Generate final assessment
    generate_validation_summary
  end

  # Quick validation check - returns pass/fail
  def valid?(content, options = {})
    results = validate(content, options)
    results[:overall_status] == 'pass'
  end

  # Get validation results by severity
  def results_by_severity(severity_level)
    @validation_results.select { |result| result[:severity] == severity_level }
  end

  # Get critical issues that must be addressed
  def critical_issues
    results_by_severity('critical')
  end

  # Get recommendations for improvement
  def recommendations
    @validation_results.map { |result| result[:recommendation] }.compact
  end

  private

  def validate_configuration!
    if validation_types.empty?
      raise InvalidConfigurationError, "At least one validation type must be specified"
    end
    
    invalid_types = validation_types - VALIDATION_TYPES
    if invalid_types.any?
      raise InvalidConfigurationError, "Invalid validation types: #{invalid_types.join(', ')}"
    end
    
    if content_category.present? && !CONTENT_CATEGORIES.include?(content_category)
      raise InvalidConfigurationError, "Invalid content category: #{content_category}"
    end
  end

  def normalize_content(content)
    case content
    when Hash
      # Extract main content field
      main_content = content[:content] || content['content'] || 
                    content[:text] || content['text'] ||
                    content[:body] || content['body']
      
      {
        main_content: main_content.to_s,
        metadata: content.except(:content, 'content', :text, 'text', :body, 'body'),
        original_format: 'hash'
      }
    when String
      {
        main_content: content,
        metadata: {},
        original_format: 'string'
      }
    else
      {
        main_content: content.to_s,
        metadata: {},
        original_format: content.class.name
      }
    end
  end

  # Quality validation methods

  def validate_content_quality(normalized_content)
    content_text = normalized_content[:main_content]
    quality_issues = []
    quality_score = 100

    # Check content length
    if content_text.length < 10
      quality_issues << "Content too short (#{content_text.length} characters)"
      quality_score -= 30
    elsif content_text.length > 5000 && content_category != 'blog_post'
      quality_issues << "Content may be too long for #{content_category}"
      quality_score -= 10
    end

    # Check for obvious placeholders
    placeholders = content_text.scan(/\[.*?\]|\{.*?\}|<.*?>|TODO|PLACEHOLDER|XXX/i)
    if placeholders.any?
      quality_issues << "Contains placeholders: #{placeholders.uniq.join(', ')}"
      quality_score -= 20
    end

    # Check for repeated phrases
    words = content_text.downcase.split(/\W+/)
    word_frequency = words.tally
    repeated_words = word_frequency.select { |_, count| count > 5 && words.length > 50 }
    
    if repeated_words.any?
      quality_issues << "Excessive word repetition detected"
      quality_score -= 15
    end

    # Check sentence structure (very basic)
    sentences = content_text.split(/[.!?]+/)
    if sentences.length > 3
      avg_sentence_length = words.length.to_f / sentences.length
      if avg_sentence_length < 3
        quality_issues << "Sentences may be too short (avg: #{avg_sentence_length.round(1)} words)"
        quality_score -= 10
      elsif avg_sentence_length > 40
        quality_issues << "Sentences may be too long (avg: #{avg_sentence_length.round(1)} words)"
        quality_score -= 10
      end
    end

    # Check for professional language
    informal_patterns = [
      /\b(gonna|wanna|gotta|kinda|sorta)\b/i,
      /\b(awesome|amazing|incredible)\b/i,  # Overused marketing words
      /!!+/,  # Multiple exclamation marks
      /\?{2,}/  # Multiple question marks
    ]

    informal_count = informal_patterns.sum { |pattern| content_text.scan(pattern).length }
    if informal_count > 2
      quality_issues << "Content may be too informal for professional marketing"
      quality_score -= 15
    end

    add_result(
      type: 'quality',
      status: quality_score >= min_quality_score ? 'pass' : 'fail',
      severity: quality_score < 50 ? 'critical' : (quality_score < 70 ? 'warning' : 'info'),
      message: quality_issues.any? ? quality_issues.join('; ') : 'Content quality is acceptable',
      score: quality_score,
      details: {
        character_count: content_text.length,
        word_count: words.length,
        sentence_count: sentences.length,
        issues_found: quality_issues.length
      },
      recommendation: quality_score < min_quality_score ? generate_quality_recommendations(quality_issues) : nil
    )
  end

  def validate_content_appropriateness(normalized_content)
    content_text = normalized_content[:main_content]
    appropriateness_issues = []
    appropriateness_score = 100

    # Check for inappropriate language
    inappropriate_patterns = [
      # Profanity (basic list)
      /\b(damn|hell|crap)\b/i,
      # Controversial topics
      /\b(politics|religion|sex|drugs|alcohol)\b/i,
      # Negative language
      /\b(hate|stupid|dumb|idiot|moron)\b/i,
      # Discriminatory language (basic patterns)
      /\b(racist|sexist|bigot)\b/i
    ]

    inappropriate_count = inappropriate_patterns.sum { |pattern| content_text.scan(pattern).length }
    if inappropriate_count > 0
      appropriateness_issues << "Contains potentially inappropriate language"
      appropriateness_score -= inappropriate_count * 25
    end

    # Check for overly promotional language
    promotional_patterns = [
      /\b(buy now|act now|limited time|don't miss out|exclusive offer)\b/i,
      /!{2,}/,  # Multiple exclamation marks
      /\bFREE\b/,  # All caps "FREE"
      /\b(guaranteed|promise|100%|instant)\b/i
    ]

    promotional_count = promotional_patterns.sum { |pattern| content_text.scan(pattern).length }
    if promotional_count > 3
      appropriateness_issues << "Content may be overly promotional or spammy"
      appropriateness_score -= 20
    end

    # Check for sensitive topics that might need review
    sensitive_patterns = [
      /\b(medical|health|disease|cure|treatment)\b/i,
      /\b(financial|investment|money|profit|income)\b/i,
      /\b(legal|lawsuit|attorney|court)\b/i
    ]

    sensitive_count = sensitive_patterns.sum { |pattern| content_text.scan(pattern).length }
    if sensitive_count > 2
      appropriateness_issues << "Content mentions sensitive topics that may require compliance review"
      appropriateness_score -= 10
    end

    add_result(
      type: 'appropriateness',
      status: appropriateness_score >= 80 ? 'pass' : (appropriateness_score >= 60 ? 'warning' : 'fail'),
      severity: appropriateness_score < 60 ? 'critical' : (appropriateness_score < 80 ? 'warning' : 'info'),
      message: appropriateness_issues.any? ? appropriateness_issues.join('; ') : 'Content appropriateness is acceptable',
      score: appropriateness_score,
      details: {
        inappropriate_matches: inappropriate_count,
        promotional_matches: promotional_count,
        sensitive_matches: sensitive_count
      },
      recommendation: appropriateness_score < 80 ? generate_appropriateness_recommendations(appropriateness_issues) : nil
    )
  end

  def validate_brand_compliance(normalized_content)
    return unless brand_guidelines.is_a?(Hash) && brand_guidelines.any?

    content_text = normalized_content[:main_content]
    compliance_issues = []
    compliance_score = 100

    # Check required brand terms
    if required_terms = brand_guidelines['required_terms']
      required_terms.each do |term|
        unless content_text.downcase.include?(term.downcase)
          compliance_issues << "Missing required brand term: '#{term}'"
          compliance_score -= 15
        end
      end
    end

    # Check forbidden terms
    if forbidden_terms = brand_guidelines['forbidden_terms']
      forbidden_terms.each do |term|
        if content_text.downcase.include?(term.downcase)
          compliance_issues << "Contains forbidden term: '#{term}'"
          compliance_score -= 25
        end
      end
    end

    # Check tone compliance
    if required_tone = brand_guidelines['tone']
      tone_keywords = {
        'professional' => %w[expertise experience quality service solutions],
        'friendly' => %w[welcome help support community together],
        'innovative' => %w[new cutting-edge advanced revolutionary technology],
        'trustworthy' => %w[reliable trusted established proven secure]
      }

      if tone_words = tone_keywords[required_tone.downcase]
        matching_words = tone_words.select { |word| content_text.downcase.include?(word) }
        if matching_words.empty?
          compliance_issues << "Content may not match required '#{required_tone}' tone"
          compliance_score -= 20
        end
      end
    end

    # Check brand voice consistency
    if brand_voice = brand_guidelines['voice_characteristics']
      voice_issues = validate_brand_voice(content_text, brand_voice)
      compliance_issues.concat(voice_issues)
      compliance_score -= voice_issues.length * 10
    end

    add_result(
      type: 'brand_compliance',
      status: compliance_score >= 70 ? 'pass' : 'fail',
      severity: compliance_score < 50 ? 'critical' : (compliance_score < 70 ? 'warning' : 'info'),
      message: compliance_issues.any? ? compliance_issues.join('; ') : 'Brand compliance is acceptable',
      score: compliance_score,
      details: {
        guidelines_checked: brand_guidelines.keys,
        issues_found: compliance_issues.length
      },
      recommendation: compliance_issues.any? ? generate_brand_compliance_recommendations(compliance_issues) : nil
    )
  end

  def validate_content_structure(normalized_content)
    content_text = normalized_content[:main_content]
    structure_issues = []
    structure_score = 100

    # Check for basic structure elements based on content category
    case content_category
    when 'email'
      validate_email_structure(content_text, structure_issues)
    when 'social_media'
      validate_social_media_structure(content_text, structure_issues)
    when 'ad_copy'
      validate_ad_copy_structure(content_text, structure_issues)
    when 'blog_post'
      validate_blog_post_structure(content_text, structure_issues)
    when 'landing_page'
      validate_landing_page_structure(content_text, structure_issues)
    end

    structure_score -= structure_issues.length * 15

    add_result(
      type: 'content_structure',
      status: structure_score >= 70 ? 'pass' : 'fail',
      severity: structure_score < 50 ? 'critical' : (structure_score < 70 ? 'warning' : 'info'),
      message: structure_issues.any? ? structure_issues.join('; ') : 'Content structure is acceptable',
      score: structure_score,
      details: {
        category: content_category,
        structure_elements_checked: get_structure_elements_for_category(content_category)
      },
      recommendation: structure_issues.any? ? generate_structure_recommendations(structure_issues) : nil
    )
  end

  def validate_language_quality(normalized_content)
    content_text = normalized_content[:main_content]
    language_issues = []
    language_score = 100

    # Check for basic grammar patterns (simplified)
    grammar_patterns = [
      { pattern: /\b(a)\s+([aeiou])/i, message: "Should use 'an' before vowel sounds", severity: 5 },
      { pattern: /\b(an)\s+([^aeiou])/i, message: "Should use 'a' before consonant sounds", severity: 5 },
      { pattern: /\s{2,}/, message: "Multiple consecutive spaces", severity: 2 },
      { pattern: /[.!?]\s*[a-z]/, message: "Sentence should start with capital letter", severity: 10 },
      { pattern: /[,;:]\s*[A-Z]/, message: "Unexpected capitalization after punctuation", severity: 5 }
    ]

    grammar_patterns.each do |pattern_info|
      matches = content_text.scan(pattern_info[:pattern])
      if matches.any?
        language_issues << "#{pattern_info[:message]} (#{matches.length} instances)"
        language_score -= pattern_info[:severity] * matches.length
      end
    end

    # Check for readability (simplified Flesch reading ease approximation)
    sentences = content_text.split(/[.!?]+/).length
    words = content_text.split(/\W+/).length
    syllables = approximate_syllable_count(content_text)
    
    if sentences > 0 && words > 0
      avg_sentence_length = words.to_f / sentences
      avg_syllables_per_word = syllables.to_f / words
      
      # Simplified readability score
      readability_score = 206.835 - (1.015 * avg_sentence_length) - (84.6 * avg_syllables_per_word)
      
      if readability_score < 30
        language_issues << "Content may be very difficult to read"
        language_score -= 25
      elsif readability_score < 50
        language_issues << "Content may be difficult to read"
        language_score -= 15
      end
    end

    add_result(
      type: 'language_quality',
      status: language_score >= 70 ? 'pass' : 'fail',
      severity: language_score < 50 ? 'critical' : (language_score < 70 ? 'warning' : 'info'),
      message: language_issues.any? ? language_issues.join('; ') : 'Language quality is acceptable',
      score: language_score,
      details: {
        grammar_issues: language_issues.select { |issue| issue.include?('Should use') }.length,
        readability_estimated: sentences > 0 ? (words.to_f / sentences).round(1) : 0
      },
      recommendation: language_issues.any? ? generate_language_recommendations(language_issues) : nil
    )
  end

  def validate_marketing_effectiveness(normalized_content)
    content_text = normalized_content[:main_content]
    effectiveness_issues = []
    effectiveness_score = 100

    # Check for call-to-action presence
    cta_patterns = [
      /\b(click|tap|visit|buy|purchase|order|subscribe|sign up|learn more|get started|try|download)\b/i,
      /\b(call now|contact us|book now|schedule|register|join)\b/i
    ]

    has_cta = cta_patterns.any? { |pattern| content_text.match?(pattern) }
    unless has_cta
      effectiveness_issues << "No clear call-to-action found"
      effectiveness_score -= 30
    end

    # Check for benefit-focused language
    benefit_patterns = [
      /\b(save|benefit|advantage|improve|increase|reduce|enhance|boost|optimize)\b/i,
      /\b(free|discount|offer|deal|special|limited|exclusive)\b/i,
      /\b(results|success|proven|effective|guaranteed)\b/i
    ]

    benefit_count = benefit_patterns.sum { |pattern| content_text.scan(pattern).length }
    if benefit_count == 0
      effectiveness_issues << "No clear benefits or value propositions mentioned"
      effectiveness_score -= 25
    elsif benefit_count < 2
      effectiveness_issues << "Limited benefit-focused language"
      effectiveness_score -= 10
    end

    # Check for urgency/scarcity (if appropriate for content type)
    if ['ad_copy', 'email'].include?(content_category)
      urgency_patterns = [
        /\b(limited time|hurry|urgent|deadline|expires|ends soon|last chance)\b/i,
        /\b(only|just|few left|limited|exclusive|rare opportunity)\b/i
      ]

      urgency_count = urgency_patterns.sum { |pattern| content_text.scan(pattern).length }
      if urgency_count == 0
        effectiveness_issues << "Consider adding urgency or scarcity elements"
        effectiveness_score -= 10
      end
    end

    # Check for personalization elements
    personalization_patterns = [
      /\b(you|your|yours)\b/i,
      /\b(we|us|our)\b/i,
      /\b(name|personal|custom|individual)\b/i
    ]

    personalization_count = personalization_patterns.sum { |pattern| content_text.scan(pattern).length }
    if personalization_count < 3
      effectiveness_issues << "Limited personalization or direct address"
      effectiveness_score -= 15
    end

    add_result(
      type: 'marketing_effectiveness',
      status: effectiveness_score >= 70 ? 'pass' : 'fail',
      severity: effectiveness_score < 50 ? 'warning' : 'info',
      message: effectiveness_issues.any? ? effectiveness_issues.join('; ') : 'Marketing effectiveness is acceptable',
      score: effectiveness_score,
      details: {
        has_cta: has_cta,
        benefit_mentions: benefit_count,
        personalization_level: personalization_count
      },
      recommendation: effectiveness_issues.any? ? generate_effectiveness_recommendations(effectiveness_issues) : nil
    )
  end

  def validate_platform_compliance(normalized_content)
    return unless platform_requirements.is_a?(Hash) && platform_requirements.any?

    content_text = normalized_content[:main_content]
    platform_issues = []
    platform_score = 100

    # Check character limits
    if max_length = platform_requirements['max_length']
      if content_text.length > max_length
        platform_issues << "Content exceeds platform limit (#{content_text.length}/#{max_length} characters)"
        platform_score -= 30
      end
    end

    # Check hashtag limits and format
    if hashtag_limit = platform_requirements['max_hashtags']
      hashtags = content_text.scan(/#\w+/)
      if hashtags.length > hashtag_limit
        platform_issues << "Too many hashtags (#{hashtags.length}/#{hashtag_limit})"
        platform_score -= 20
      end
    end

    # Check for required platform elements
    if required_elements = platform_requirements['required_elements']
      required_elements.each do |element|
        case element
        when 'hashtags'
          unless content_text.include?('#')
            platform_issues << "Missing required hashtags"
            platform_score -= 15
          end
        when 'mention'
          unless content_text.include?('@')
            platform_issues << "Missing required mentions"
            platform_score -= 15
          end
        when 'url'
          unless content_text.match?(/https?:\/\//)
            platform_issues << "Missing required URL"
            platform_score -= 15
          end
        end
      end
    end

    add_result(
      type: 'platform_compliance',
      status: platform_score >= 80 ? 'pass' : 'fail',
      severity: platform_score < 60 ? 'critical' : (platform_score < 80 ? 'warning' : 'info'),
      message: platform_issues.any? ? platform_issues.join('; ') : 'Platform compliance is acceptable',
      score: platform_score,
      details: platform_requirements.merge(content_length: content_text.length),
      recommendation: platform_issues.any? ? generate_platform_recommendations(platform_issues) : nil
    )
  end

  def validate_safety(normalized_content)
    content_text = normalized_content[:main_content]
    safety_issues = []
    safety_score = 100

    # Check for potential safety concerns
    safety_patterns = [
      { pattern: /\b(hack|crack|steal|fraud|scam|cheat)\b/i, message: "Contains potentially harmful language", severity: 30 },
      { pattern: /\b(password|credit card|ssn|social security)\b/i, message: "References sensitive personal information", severity: 25 },
      { pattern: /\b(virus|malware|phishing|spam)\b/i, message: "Contains security-related terms that might trigger filters", severity: 20 },
      { pattern: /\b(suicide|death|kill|murder|violence)\b/i, message: "Contains violent or harmful language", severity: 40 }
    ]

    safety_patterns.each do |pattern_info|
      matches = content_text.scan(pattern_info[:pattern])
      if matches.any?
        safety_issues << "#{pattern_info[:message]} (#{matches.length} instances)"
        safety_score -= pattern_info[:severity]
      end
    end

    # Check for potential misinformation markers
    misinformation_patterns = [
      /\b(cure|guaranteed|miracle|secret|doctors hate|conspiracy)\b/i,
      /\b(100% effective|never fails|instant results)\b/i
    ]

    misinformation_count = misinformation_patterns.sum { |pattern| content_text.scan(pattern).length }
    if misinformation_count > 0
      safety_issues << "Contains language that might be flagged as misinformation"
      safety_score -= misinformation_count * 15
    end

    add_result(
      type: 'safety',
      status: safety_score >= 90 ? 'pass' : (safety_score >= 70 ? 'warning' : 'fail'),
      severity: safety_score < 70 ? 'critical' : (safety_score < 90 ? 'warning' : 'info'),
      message: safety_issues.any? ? safety_issues.join('; ') : 'Content safety is acceptable',
      score: safety_score,
      details: {
        safety_concerns: safety_issues.length,
        misinformation_flags: misinformation_count
      },
      recommendation: safety_issues.any? ? generate_safety_recommendations(safety_issues) : nil
    )
  end

  # Helper methods for structure validation

  def validate_email_structure(content_text, issues)
    issues << "Missing subject line pattern" unless content_text.match?(/^.*:/m)
    issues << "Missing call-to-action" unless content_text.match?(/\b(click|visit|call|contact|buy|order)\b/i)
    issues << "No clear greeting" unless content_text.match?(/\b(hello|hi|dear|greetings)\b/i)
  end

  def validate_social_media_structure(content_text, issues)
    issues << "No hashtags found" unless content_text.include?('#')
    issues << "Content may be too long for social media" if content_text.length > 280
    issues << "No engaging hook" unless content_text.match?(/^[!?]|question|how|why|what/i)
  end

  def validate_ad_copy_structure(content_text, issues)
    issues << "Missing clear headline" unless content_text.split("\n").first.length > 10
    issues << "No clear call-to-action" unless content_text.match?(/\b(buy|order|click|visit|call)\b/i)
    issues << "No benefit mentioned" unless content_text.match?(/\b(save|free|discount|improve|better)\b/i)
  end

  def validate_blog_post_structure(content_text, issues)
    issues << "No clear introduction" unless content_text.length > 100
    issues << "Missing headings structure" unless content_text.include?('#') || content_text.match?(/^[A-Z][^.]*$/m)
    issues << "No conclusion or summary" unless content_text.match?(/\b(conclusion|summary|finally|in closing)\b/i)
  end

  def validate_landing_page_structure(content_text, issues)
    issues << "Missing headline" unless content_text.split("\n").first.length > 15
    issues << "No clear value proposition" unless content_text.match?(/\b(benefit|advantage|solution|results)\b/i)
    issues << "Missing call-to-action" unless content_text.match?(/\b(sign up|get started|buy now|learn more)\b/i)
  end

  # Scoring and summary methods

  def calculate_overall_score
    return 0 if @validation_results.empty?

    total_score = @validation_results.sum { |result| result[:score] || 0 }
    @overall_score = (total_score.to_f / @validation_results.length).round(1)
  end

  def generate_validation_summary
    critical_count = results_by_severity('critical').length
    warning_count = results_by_severity('warning').length
    
    overall_status = if critical_count > 0
      'fail'
    elsif warning_count > 2 || @overall_score < min_quality_score
      'warning'
    else
      'pass'
    end

    {
      overall_status: overall_status,
      overall_score: @overall_score,
      total_validations: @validation_results.length,
      critical_issues: critical_count,
      warnings: warning_count,
      validation_results: @validation_results,
      recommendations: recommendations.uniq,
      summary: generate_summary_message(overall_status, critical_count, warning_count)
    }
  end

  def generate_summary_message(status, critical_count, warning_count)
    case status
    when 'pass'
      "Content validation passed successfully with an overall score of #{@overall_score}%"
    when 'warning'
      "Content validation completed with #{warning_count} warnings. Review recommended before publishing."
    when 'fail'
      "Content validation failed with #{critical_count} critical issues. Revisions required before use."
    end
  end

  # Recommendation generators

  def generate_quality_recommendations(issues)
    recommendations = []
    
    issues.each do |issue|
      case issue
      when /too short/
        recommendations << "Expand content with more detailed information or examples"
      when /too long/
        recommendations << "Consider breaking into sections or reducing length"
      when /placeholders/
        recommendations << "Replace all placeholder text with actual content"
      when /repetition/
        recommendations << "Vary word choice and sentence structure"
      when /informal/
        recommendations << "Use more professional language appropriate for business communication"
      end
    end
    
    recommendations.compact.uniq
  end

  def generate_appropriateness_recommendations(issues)
    recommendations = []
    
    issues.each do |issue|
      case issue
      when /inappropriate/
        recommendations << "Review and remove any potentially offensive language"
      when /promotional/
        recommendations << "Reduce promotional language and focus on value proposition"
      when /sensitive/
        recommendations << "Review sensitive topics for compliance requirements"
      end
    end
    
    recommendations << "Consider having content reviewed by compliance team"
    recommendations.compact.uniq
  end

  def generate_brand_compliance_recommendations(issues)
    recommendations = ["Review brand guidelines and ensure consistent application"]
    
    issues.each do |issue|
      case issue
      when /missing.*term/
        recommendations << "Include required brand terminology naturally in content"
      when /forbidden.*term/
        recommendations << "Remove or replace forbidden terms with approved alternatives"
      when /tone/
        recommendations << "Adjust language to match brand tone guidelines"
      end
    end
    
    recommendations.compact.uniq
  end

  def generate_structure_recommendations(issues)
    ["Review content structure requirements for #{content_category}",
     "Ensure all required elements are included and properly formatted"]
  end

  def generate_language_recommendations(issues)
    ["Proofread content for grammar and readability",
     "Consider using grammar checking tools",
     "Break up complex sentences for better readability"]
  end

  def generate_effectiveness_recommendations(issues)
    recommendations = []
    
    issues.each do |issue|
      case issue
      when /call-to-action/
        recommendations << "Add a clear, specific call-to-action"
      when /benefits/
        recommendations << "Highlight specific benefits and value propositions"
      when /urgency/
        recommendations << "Consider adding urgency or scarcity elements"
      when /personalization/
        recommendations << "Use more direct, personal language addressing the reader"
      end
    end
    
    recommendations.compact.uniq
  end

  def generate_platform_recommendations(issues)
    ["Review platform-specific requirements and constraints",
     "Adjust content to meet platform guidelines"]
  end

  def generate_safety_recommendations(issues)
    ["Review content for safety and compliance concerns",
     "Consider legal review if sensitive topics are mentioned",
     "Ensure all claims are factual and supportable"]
  end

  # Utility methods

  def add_result(result_hash)
    @validation_results << result_hash.merge(
      timestamp: Time.current,
      validator_version: '1.0'
    )
  end

  def validation_error(message)
    {
      overall_status: 'error',
      overall_score: 0,
      error: message,
      validation_results: [],
      recommendations: ["Fix validation error: #{message}"]
    }
  end

  def get_structure_elements_for_category(category)
    case category
    when 'email'
      ['subject', 'greeting', 'call-to-action']
    when 'social_media'
      ['hashtags', 'engaging hook', 'length check']
    when 'ad_copy'
      ['headline', 'call-to-action', 'benefits']
    when 'blog_post'
      ['introduction', 'headings', 'conclusion']
    when 'landing_page'
      ['headline', 'value proposition', 'call-to-action']
    else
      []
    end
  end

  def validate_brand_voice(content_text, voice_characteristics)
    issues = []
    
    voice_characteristics.each do |characteristic, expected_value|
      case characteristic
      when 'formality'
        if expected_value == 'formal' && content_text.match?(/\b(hey|hi there|awesome|cool)\b/i)
          issues << "Content may be too informal for brand voice"
        elsif expected_value == 'informal' && !content_text.match?(/\b(you|your|we|us)\b/i)
          issues << "Content may be too formal for brand voice"
        end
      when 'enthusiasm'
        if expected_value == 'high' && !content_text.match?(/[!]|exciting|amazing|love|passion/i)
          issues << "Content may lack enthusiasm expected in brand voice"
        end
      end
    end
    
    issues
  end

  def approximate_syllable_count(text)
    # Very rough approximation
    words = text.downcase.split(/\W+/)
    syllables = 0
    
    words.each do |word|
      # Count vowel groups
      vowel_groups = word.scan(/[aeiouy]+/).length
      syllables += vowel_groups > 0 ? vowel_groups : 1
    end
    
    syllables
  end
end