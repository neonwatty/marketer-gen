# AI Content Moderator for filtering and moderation
# Provides content filtering and moderation capabilities for AI-generated content
class AiContentModerator
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Moderation categories
  MODERATION_CATEGORIES = %w[
    profanity
    hate_speech
    spam
    adult_content
    violence
    harassment
    misinformation
    copyright
    personal_info
    discrimination
  ].freeze

  # Filter actions
  FILTER_ACTIONS = %w[allow block flag redact].freeze

  # Severity levels
  SEVERITY_LEVELS = %w[low medium high critical].freeze

  class ModerationError < StandardError; end
  class InvalidConfigurationError < ModerationError; end

  attribute :enabled_categories, :string, default: -> { MODERATION_CATEGORIES }
  attribute :strictness_level, :string, default: 'medium'  # low, medium, high
  attribute :auto_block_threshold, :integer, default: 80
  attribute :flag_threshold, :integer, default: 60
  attribute :redact_personal_info, :boolean, default: true
  attribute :custom_blocked_terms, :string, default: -> { [] }
  attribute :custom_flagged_terms, :string, default: -> { [] }
  attribute :whitelist_terms, :string, default: -> { [] }

  attr_reader :moderation_results, :filtered_content

  def initialize(attributes = {})
    super(attributes)
    @moderation_results = []
    @filtered_content = nil
    validate_configuration!
  end

  # Main moderation method
  def moderate(content, options = {})
    return moderation_error("Content cannot be empty") if content.blank?

    @original_content = content
    @moderation_results = []
    @filtered_content = content.dup

    # Normalize content for processing
    normalized_content = normalize_content(content)
    text_content = extract_text_content(normalized_content)

    # Run moderation checks
    enabled_categories.each do |category|
      begin
        case category
        when 'profanity'
          check_profanity(text_content)
        when 'hate_speech'
          check_hate_speech(text_content)
        when 'spam'
          check_spam_patterns(text_content)
        when 'adult_content'
          check_adult_content(text_content)
        when 'violence'
          check_violence(text_content)
        when 'harassment'
          check_harassment(text_content)
        when 'misinformation'
          check_misinformation(text_content)
        when 'copyright'
          check_copyright_violations(text_content)
        when 'personal_info'
          check_personal_information(text_content)
        when 'discrimination'
          check_discriminatory_content(text_content)
        end
      rescue => error
        Rails.logger.error "Moderation check failed for #{category}: #{error.message}"
        add_result(
          category: category,
          action: 'flag',
          severity: 'medium',
          confidence: 0,
          message: "Moderation check failed: #{error.message}",
          matches: [],
          error: true
        )
      end
    end

    # Apply custom term filtering
    apply_custom_filters(text_content) if custom_blocked_terms.any? || custom_flagged_terms.any?

    # Apply whitelist protection
    apply_whitelist_protection if whitelist_terms.any?

    # Generate final moderation decision
    generate_moderation_decision
  end

  # Check if content should be blocked
  def blocked?
    return false unless @moderation_results

    @moderation_results.any? { |result| result[:action] == 'block' } ||
    overall_risk_score >= auto_block_threshold
  end

  # Check if content should be flagged for review
  def flagged?
    return false unless @moderation_results

    @moderation_results.any? { |result| result[:action] == 'flag' } ||
    overall_risk_score >= flag_threshold
  end

  # Get overall risk score
  def overall_risk_score
    return 0 unless @moderation_results&.any?

    # Calculate weighted average based on severity and confidence
    total_weighted_score = 0
    total_weight = 0

    @moderation_results.each do |result|
      next if result[:error]

      severity_weight = case result[:severity]
      when 'critical' then 4
      when 'high' then 3
      when 'medium' then 2
      when 'low' then 1
      else 1
      end

      confidence = result[:confidence] || 50
      weighted_score = (confidence * severity_weight) / 4.0
      
      total_weighted_score += weighted_score
      total_weight += severity_weight
    end

    total_weight > 0 ? (total_weighted_score / total_weight).round(1) : 0
  end

  # Get filtered content with redactions applied
  def filtered_content
    @filtered_content || @original_content
  end

  # Get moderation summary
  def moderation_summary
    {
      overall_action: determine_overall_action,
      overall_risk_score: overall_risk_score,
      blocked: blocked?,
      flagged: flagged?,
      categories_flagged: flagged_categories,
      total_issues: @moderation_results.length,
      content_modified: @filtered_content != @original_content,
      moderation_results: @moderation_results,
      timestamp: Time.current
    }
  end

  private

  def validate_configuration!
    invalid_categories = enabled_categories - MODERATION_CATEGORIES
    if invalid_categories.any?
      raise InvalidConfigurationError, "Invalid moderation categories: #{invalid_categories.join(', ')}"
    end

    unless %w[low medium high].include?(strictness_level)
      raise InvalidConfigurationError, "Invalid strictness level: #{strictness_level}"
    end

    if auto_block_threshold < flag_threshold
      raise InvalidConfigurationError, "Auto block threshold must be >= flag threshold"
    end
  end

  def normalize_content(content)
    case content
    when Hash
      content
    when String
      { main_content: content, content_type: 'text' }
    else
      { main_content: content.to_s, content_type: content.class.name }
    end
  end

  def extract_text_content(normalized_content)
    if normalized_content.is_a?(Hash)
      # Extract text from various possible fields
      text_content = normalized_content[:main_content] ||
                     normalized_content[:content] ||
                     normalized_content[:text] ||
                     normalized_content[:body] ||
                     normalized_content.values.select { |v| v.is_a?(String) }.join(' ')
      text_content.to_s
    else
      normalized_content.to_s
    end
  end

  # Profanity checking
  def check_profanity(content)
    profanity_patterns = build_profanity_patterns
    matches = []
    confidence = 0

    profanity_patterns.each do |pattern_info|
      found_matches = content.downcase.scan(pattern_info[:pattern]).flatten
      if found_matches.any?
        matches.concat(found_matches)
        confidence = [confidence, pattern_info[:confidence]].max
      end
    end

    if matches.any?
      action = determine_action_by_confidence(confidence)
      severity = determine_severity_by_confidence(confidence)

      # Apply redaction if enabled
      if action == 'redact' || (redact_personal_info && action != 'allow')
        apply_profanity_redaction(matches)
      end

      add_result(
        category: 'profanity',
        action: action,
        severity: severity,
        confidence: confidence,
        message: "Found #{matches.length} profanity matches",
        matches: matches.uniq
      )
    end
  end

  # Hate speech checking
  def check_hate_speech(content)
    hate_speech_patterns = build_hate_speech_patterns
    matches = []
    max_confidence = 0

    hate_speech_patterns.each do |pattern_info|
      if content.downcase.match?(pattern_info[:pattern])
        matches << pattern_info[:term]
        max_confidence = [max_confidence, pattern_info[:confidence]].max
      end
    end

    if matches.any?
      action = determine_action_by_confidence(max_confidence)
      # Hate speech is always at least flagged
      action = 'flag' if action == 'allow' && max_confidence > 30

      add_result(
        category: 'hate_speech',
        action: action,
        severity: 'high',
        confidence: max_confidence,
        message: "Potential hate speech detected",
        matches: matches.uniq
      )
    end
  end

  # Spam pattern checking
  def check_spam_patterns(content)
    spam_indicators = [
      { pattern: /\b(buy now|act now|limited time|don't wait|hurry|urgent)\b/i, score: 20, description: "Urgency language" },
      { pattern: /\b(free|100%|guarantee|no risk|money back)\b/i, score: 15, description: "Too-good-to-be-true language" },
      { pattern: /[A-Z]{4,}/, score: 10, description: "Excessive capitalization" },
      { pattern: /!{3,}/, score: 10, description: "Multiple exclamation marks" },
      { pattern: /\$[\d,]+/, score: 5, description: "Money amounts" },
      { pattern: /(click here|visit now|call now)/i, score: 15, description: "Aggressive CTA" }
    ]

    spam_score = 0
    matches = []

    spam_indicators.each do |indicator|
      found_matches = content.scan(indicator[:pattern])
      if found_matches.any?
        spam_score += indicator[:score] * found_matches.length
        matches << indicator[:description]
      end
    end

    # Check for excessive repetition
    words = content.downcase.split(/\W+/)
    if words.length > 20
      word_counts = words.tally
      repeated_words = word_counts.select { |_, count| count > words.length / 10 }
      
      if repeated_words.any?
        spam_score += 25
        matches << "Excessive word repetition"
      end
    end

    if spam_score > 30
      confidence = [spam_score, 100].min
      action = determine_action_by_confidence(confidence)

      add_result(
        category: 'spam',
        action: action,
        severity: spam_score > 70 ? 'high' : 'medium',
        confidence: confidence,
        message: "Spam indicators detected (score: #{spam_score})",
        matches: matches.uniq
      )
    end
  end

  # Adult content checking
  def check_adult_content(content)
    adult_patterns = [
      { pattern: /\b(sex|sexy|nude|naked|porn|adult|erotic)\b/i, confidence: 70, severity: 'high' },
      { pattern: /\b(dating|romance|singles|hookup|affair)\b/i, confidence: 40, severity: 'medium' },
      { pattern: /\b(casino|gambling|poker|bet|lottery)\b/i, confidence: 60, severity: 'medium' }
    ]

    matches = []
    max_confidence = 0

    adult_patterns.each do |pattern_info|
      found_matches = content.downcase.scan(pattern_info[:pattern])
      if found_matches.any?
        matches.concat(found_matches)
        max_confidence = [max_confidence, pattern_info[:confidence]].max
      end
    end

    if matches.any?
      action = determine_action_by_confidence(max_confidence)

      add_result(
        category: 'adult_content',
        action: action,
        severity: max_confidence > 60 ? 'high' : 'medium',
        confidence: max_confidence,
        message: "Adult content indicators detected",
        matches: matches.uniq
      )
    end
  end

  # Violence checking
  def check_violence(content)
    violence_patterns = [
      { pattern: /\b(kill|murder|death|violence|weapon|gun|knife|bomb)\b/i, confidence: 80, severity: 'high' },
      { pattern: /\b(fight|attack|assault|hurt|harm|damage|destroy)\b/i, confidence: 50, severity: 'medium' },
      { pattern: /\b(war|battle|combat|shooting|explosion)\b/i, confidence: 40, severity: 'medium' }
    ]

    matches = []
    max_confidence = 0

    violence_patterns.each do |pattern_info|
      found_matches = content.downcase.scan(pattern_info[:pattern])
      if found_matches.any?
        matches.concat(found_matches)
        max_confidence = [max_confidence, pattern_info[:confidence]].max
      end
    end

    if matches.any?
      action = determine_action_by_confidence(max_confidence)

      add_result(
        category: 'violence',
        action: action,
        severity: max_confidence > 60 ? 'high' : 'medium',
        confidence: max_confidence,
        message: "Violent content indicators detected",
        matches: matches.uniq
      )
    end
  end

  # Personal information detection
  def check_personal_information(content)
    pii_patterns = [
      { pattern: /\b\d{3}-\d{2}-\d{4}\b/, type: 'SSN', confidence: 90 },
      { pattern: /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/, type: 'Credit Card', confidence: 85 },
      { pattern: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, type: 'Email', confidence: 70 },
      { pattern: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/, type: 'Phone Number', confidence: 60 },
      { pattern: /\b\d{1,5}\s\w+\s(?:Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Lane|Ln|Boulevard|Blvd)\b/i, type: 'Address', confidence: 75 }
    ]

    pii_found = []
    redaction_applied = false

    pii_patterns.each do |pattern_info|
      matches = content.scan(pattern_info[:pattern])
      if matches.any?
        pii_found << {
          type: pattern_info[:type],
          count: matches.length,
          confidence: pattern_info[:confidence]
        }

        # Apply redaction if enabled
        if redact_personal_info
          @filtered_content = @filtered_content.gsub(pattern_info[:pattern], "[#{pattern_info[:type]} REDACTED]")
          redaction_applied = true
        end
      end
    end

    if pii_found.any?
      max_confidence = pii_found.map { |pii| pii[:confidence] }.max
      action = redact_personal_info ? 'redact' : determine_action_by_confidence(max_confidence)

      add_result(
        category: 'personal_info',
        action: action,
        severity: 'medium',
        confidence: max_confidence,
        message: "Personal information detected: #{pii_found.map { |p| p[:type] }.join(', ')}",
        matches: pii_found,
        redaction_applied: redaction_applied
      )
    end
  end

  # Custom term filtering
  def apply_custom_filters(content)
    # Check blocked terms
    if custom_blocked_terms.any?
      blocked_matches = []
      custom_blocked_terms.each do |term|
        if content.downcase.include?(term.downcase)
          blocked_matches << term
        end
      end

      if blocked_matches.any?
        add_result(
          category: 'custom_blocked',
          action: 'block',
          severity: 'high',
          confidence: 100,
          message: "Custom blocked terms found",
          matches: blocked_matches
        )
      end
    end

    # Check flagged terms
    if custom_flagged_terms.any?
      flagged_matches = []
      custom_flagged_terms.each do |term|
        if content.downcase.include?(term.downcase)
          flagged_matches << term
        end
      end

      if flagged_matches.any?
        add_result(
          category: 'custom_flagged',
          action: 'flag',
          severity: 'medium',
          confidence: 90,
          message: "Custom flagged terms found",
          matches: flagged_matches
        )
      end
    end
  end

  # Apply whitelist protection (reduce confidence for whitelisted terms)
  def apply_whitelist_protection
    whitelist_terms.each do |term|
      if @filtered_content.downcase.include?(term.downcase)
        # Reduce confidence of existing results that might have flagged this term
        @moderation_results.each do |result|
          if result[:matches]&.any? { |match| match.downcase.include?(term.downcase) }
            result[:confidence] = (result[:confidence] * 0.5).round
            result[:whitelist_protected] = true
          end
        end
      end
    end
  end

  # Helper methods for pattern building

  def build_profanity_patterns
    base_profanity = %w[damn hell crap shit fuck] # Basic list - would be expanded
    
    patterns = []
    base_profanity.each do |word|
      # Exact match
      patterns << { pattern: /\b#{Regexp.escape(word)}\b/i, confidence: 80 }
      # With character substitution (l33t speak)
      patterns << { pattern: /\b#{word.gsub(/[aeiou]/, '[aeiou@#$%]')}\b/i, confidence: 70 }
      # With spaces or special chars
      patterns << { pattern: /#{word.chars.join('[\s\-_]*')}/i, confidence: 60 }
    end
    
    patterns
  end

  def build_hate_speech_patterns
    hate_terms = [
      { term: 'hate speech indicator', pattern: /\b(hate|racist|nazi|supremacist)\b/i, confidence: 90 },
      { term: 'discriminatory language', pattern: /\b(inferior|subhuman|savage)\b/i, confidence: 70 },
      { term: 'slur pattern', pattern: /\b(n-word|f-word|other-slurs)\b/i, confidence: 95 }
    ]
    # Note: In production, this would include actual hate speech patterns
    # This is a simplified example
    hate_terms
  end

  # Action determination methods

  def determine_action_by_confidence(confidence)
    case strictness_level
    when 'low'
      confidence >= 90 ? 'block' : (confidence >= 70 ? 'flag' : 'allow')
    when 'medium'
      confidence >= 80 ? 'block' : (confidence >= 60 ? 'flag' : 'allow')
    when 'high'
      confidence >= 70 ? 'block' : (confidence >= 50 ? 'flag' : 'allow')
    else
      'allow'
    end
  end

  def determine_severity_by_confidence(confidence)
    case confidence
    when 90..100 then 'critical'
    when 70..89 then 'high'
    when 50..69 then 'medium'
    else 'low'
    end
  end

  def determine_overall_action
    return 'error' if @moderation_results.any? { |r| r[:error] }
    return 'block' if blocked?
    return 'flag' if flagged?
    'allow'
  end

  def flagged_categories
    @moderation_results.select { |r| r[:action] == 'flag' || r[:action] == 'block' }
                      .map { |r| r[:category] }
                      .uniq
  end

  # Content modification methods

  def apply_profanity_redaction(matches)
    matches.each do |match|
      replacement = match[0] + ('*' * (match.length - 1))
      @filtered_content = @filtered_content.gsub(/\b#{Regexp.escape(match)}\b/i, replacement)
    end
  end

  # Result management

  def add_result(result_hash)
    @moderation_results << result_hash.merge(
      timestamp: Time.current,
      moderator_version: '1.0'
    )
  end

  def moderation_error(message)
    {
      overall_action: 'error',
      error: message,
      moderation_results: [],
      timestamp: Time.current
    }
  end

  def generate_moderation_decision
    overall_action = determine_overall_action
    
    {
      overall_action: overall_action,
      overall_risk_score: overall_risk_score,
      blocked: blocked?,
      flagged: flagged?,
      categories_flagged: flagged_categories,
      total_issues: @moderation_results.length,
      content_modified: @filtered_content != @original_content,
      filtered_content: @filtered_content,
      moderation_results: @moderation_results,
      recommendations: generate_recommendations,
      timestamp: Time.current,
      moderator_config: {
        strictness_level: strictness_level,
        enabled_categories: enabled_categories,
        auto_block_threshold: auto_block_threshold,
        flag_threshold: flag_threshold
      }
    }
  end

  def generate_recommendations
    recommendations = []
    
    if blocked?
      recommendations << "Content should not be published without manual review and revision"
    elsif flagged?
      recommendations << "Content should be reviewed by a human moderator before publication"
    end
    
    @moderation_results.each do |result|
      case result[:category]
      when 'profanity'
        recommendations << "Remove or replace inappropriate language"
      when 'personal_info'
        recommendations << "Remove or redact personal information"
      when 'spam'
        recommendations << "Reduce promotional language and excessive formatting"
      when 'hate_speech'
        recommendations << "Review content for potentially offensive language"
      when 'adult_content'
        recommendations << "Ensure content is appropriate for all audiences"
      end
    end
    
    recommendations.uniq
  end

  # Placeholder methods for more complex checks (to be implemented)
  def check_harassment(content); end
  def check_misinformation(content); end
  def check_copyright_violations(content); end
  def check_discriminatory_content(content); end
end