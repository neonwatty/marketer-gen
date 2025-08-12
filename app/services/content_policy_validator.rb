# Service for validating content against platform policies and guidelines
# Provides comprehensive content compliance checking across different platforms
class ContentPolicyValidator
  include ActiveModel::Model

  # Platform-specific policy rules and guidelines
  PLATFORM_POLICIES = {
    twitter: {
      max_length: 280,
      prohibits_spam: true,
      prohibits_hate_speech: true,
      prohibits_misleading_info: true,
      prohibits_graphic_content: true,
      automated_content_rules: true,
      copyright_enforcement: true,
      banned_keywords: %w[spam bot fake follower buy],
      suspicious_patterns: [
        /follow.*back/i,
        /click.*link.*bio/i,
        /dm.*for.*info/i,
        /make.*money.*fast/i
      ],
      trademark_sensitive: true,
      political_content_restrictions: false
    },
    instagram: {
      max_length: 2200,
      prohibits_spam: true,
      prohibits_hate_speech: true,
      prohibits_nudity: true,
      prohibits_graphic_content: true,
      prohibits_fake_engagement: true,
      copyright_enforcement: true,
      banned_keywords: %w[follow4follow like4like spam bot fake],
      suspicious_patterns: [
        /follow.*me.*follow.*back/i,
        /like.*comment.*follow/i,
        /dm.*for.*collaboration/i,
        /link.*in.*bio.*check/i
      ],
      hashtag_spam_detection: true,
      community_guidelines_strict: true
    },
    facebook: {
      max_length: 63206,
      prohibits_spam: true,
      prohibits_hate_speech: true,
      prohibits_misleading_info: true,
      prohibits_graphic_content: true,
      prohibits_fake_news: true,
      copyright_enforcement: true,
      fact_checking_enabled: true,
      banned_keywords: %w[fake news clickbait spam scam],
      suspicious_patterns: [
        /share.*if.*agree/i,
        /type.*amen/i,
        /facebook.*will.*delete/i,
        /copy.*paste.*status/i
      ],
      political_content_restrictions: true,
      advertising_policies_strict: true
    },
    linkedin: {
      max_length: 3000,
      professional_context_required: true,
      prohibits_spam: true,
      prohibits_hate_speech: true,
      prohibits_inappropriate_content: true,
      prohibits_personal_attacks: true,
      copyright_enforcement: true,
      banned_keywords: %w[mlm pyramid scheme get rich quick],
      suspicious_patterns: [
        /make.*money.*from.*home/i,
        /work.*from.*home.*opportunity/i,
        /earn.*\$.*per.*day/i,
        /financial.*freedom/i
      ],
      requires_professional_tone: true,
      networking_spam_detection: true
    },
    tiktok: {
      max_length: 2200,
      prohibits_spam: true,
      prohibits_hate_speech: true,
      prohibits_graphic_content: true,
      prohibits_dangerous_activities: true,
      copyright_enforcement: true,
      community_guidelines_strict: true,
      banned_keywords: %w[challenge dangerous harmful viral],
      suspicious_patterns: [
        /follow.*for.*follow/i,
        /like.*for.*like/i,
        /dangerous.*challenge/i
      ],
      age_appropriate_content: true,
      viral_content_monitoring: true
    },
    youtube: {
      prohibits_spam: true,
      prohibits_hate_speech: true,
      prohibits_graphic_content: true,
      prohibits_misleading_info: true,
      copyright_enforcement: true,
      demonetization_risks: true,
      banned_keywords: %w[subscribe4subscribe sub4sub spam clickbait],
      suspicious_patterns: [
        /subscribe.*bell.*icon/i,
        /smash.*like.*button/i,
        /comment.*below.*subscribe/i
      ],
      advertiser_friendly_required: true,
      community_strikes_system: true
    },
    email: {
      prohibits_spam: true,
      can_spam_compliance: true,
      gdpr_compliance: true,
      unsubscribe_required: true,
      sender_authentication: true,
      banned_keywords: %w[urgent act now limited time free money winner],
      suspicious_patterns: [
        /act.*now.*expire/i,
        /click.*here.*winner/i,
        /congratulations.*selected/i,
        /urgent.*action.*required/i,
        /free.*money.*guaranteed/i
      ],
      spam_filter_triggers: [
        /\$\$\$/,
        /!!!/,
        /ALL CAPS WORDS/,
        /FREE FREE FREE/i
      ],
      deliverability_factors: true
    }
  }.freeze

  # Content categories that require special attention
  SENSITIVE_CATEGORIES = {
    financial: {
      keywords: %w[investment money loan credit debt mortgage insurance trading crypto bitcoin],
      requires_disclaimers: true,
      high_regulation: true,
      platforms_with_restrictions: [:facebook, :google_ads, :youtube]
    },
    health: {
      keywords: %w[medicine medical health cure treatment disease therapy supplement],
      requires_disclaimers: true,
      high_regulation: true,
      platforms_with_restrictions: [:facebook, :google_ads, :instagram, :youtube]
    },
    political: {
      keywords: %w[election vote candidate political party democracy government policy],
      requires_disclaimers: true,
      platform_restrictions: true,
      platforms_with_restrictions: [:facebook, :google_ads, :twitter]
    },
    adult: {
      keywords: %w[adult dating casino gambling alcohol tobacco],
      age_restrictions: true,
      platform_restrictions: true,
      platforms_with_restrictions: [:instagram, :tiktok, :youtube]
    },
    cryptocurrency: {
      keywords: %w[bitcoin ethereum crypto cryptocurrency nft blockchain trading investment],
      high_volatility: true,
      regulatory_scrutiny: true,
      platforms_with_restrictions: [:facebook, :google_ads, :youtube]
    }
  }.freeze

  # Spam indicators and patterns
  SPAM_INDICATORS = {
    excessive_caps: {
      pattern: /[A-Z]{4,}/,
      threshold: 3,
      severity: :medium
    },
    excessive_punctuation: {
      pattern: /[!?]{3,}/,
      threshold: 2,
      severity: :medium
    },
    excessive_emojis: {
      threshold: 10,
      severity: :low
    },
    repeated_words: {
      threshold: 3,
      severity: :medium
    },
    suspicious_urls: {
      pattern: /bit\.ly|tinyurl|goo\.gl/,
      threshold: 2,
      severity: :high
    },
    urgency_language: {
      patterns: [
        /urgent/i,
        /act.*now/i,
        /limited.*time/i,
        /expires.*soon/i,
        /last.*chance/i
      ],
      threshold: 2,
      severity: :medium
    }
  }.freeze

  attr_accessor :platform, :content_type, :brand_guidelines, :regulatory_requirements

  def initialize(platform:, content_type: nil, brand_guidelines: {}, regulatory_requirements: {})
    @platform = platform.to_sym
    @content_type = content_type
    @brand_guidelines = brand_guidelines || {}
    @regulatory_requirements = regulatory_requirements || {}
    validate_platform!
  end

  # Main validation method
  def validate_content(content, options = {})
    validation_result = {
      valid: true,
      compliance_score: 1.0,
      errors: [],
      warnings: [],
      suggestions: [],
      policy_violations: [],
      spam_indicators: [],
      sensitive_content_flags: [],
      required_disclaimers: [],
      metadata: {
        platform: platform,
        content_length: content.length,
        validation_timestamp: Time.current.iso8601
      }
    }

    # Run all validation checks
    validate_platform_policies(content, validation_result)
    validate_spam_indicators(content, validation_result)
    validate_sensitive_content(content, validation_result)
    validate_brand_compliance(content, validation_result)
    validate_regulatory_compliance(content, validation_result)
    validate_accessibility_requirements(content, validation_result)

    # Calculate overall compliance score
    calculate_compliance_score(validation_result)

    # Generate actionable suggestions
    generate_compliance_suggestions(content, validation_result)

    validation_result
  end

  # Quick compliance check
  def quick_compliance_check(content)
    platform_rules = get_platform_policies
    
    issues = []
    
    # Check length limits
    if platform_rules[:max_length] && content.length > platform_rules[:max_length]
      issues << "Content exceeds platform length limit"
    end

    # Check for banned keywords
    banned_found = find_banned_keywords(content, platform_rules[:banned_keywords] || [])
    issues += banned_found.map { |keyword| "Contains banned keyword: #{keyword}" }

    # Check for suspicious patterns
    suspicious_found = find_suspicious_patterns(content, platform_rules[:suspicious_patterns] || [])
    issues += suspicious_found.map { |pattern| "Contains suspicious pattern: #{pattern}" }

    {
      compliant: issues.empty?,
      issues_count: issues.length,
      critical_issues: issues
    }
  end

  # Generate compliance report
  def generate_compliance_report(content_samples)
    report = {
      total_content_pieces: content_samples.length,
      overall_compliance_rate: 0.0,
      common_violations: [],
      platform_specific_issues: {},
      recommendations: [],
      trend_analysis: {}
    }

    validation_results = content_samples.map { |content| validate_content(content) }
    
    # Calculate overall compliance
    compliant_count = validation_results.count { |result| result[:valid] }
    report[:overall_compliance_rate] = (compliant_count.to_f / content_samples.length * 100).round(2)

    # Analyze common violations
    all_violations = validation_results.flat_map { |result| result[:policy_violations] }
    report[:common_violations] = all_violations.tally.sort_by { |_, count| -count }.first(10).to_h

    # Platform-specific analysis
    report[:platform_specific_issues] = analyze_platform_issues(validation_results)

    # Generate recommendations
    report[:recommendations] = generate_report_recommendations(report)

    report
  end

  private

  def validate_platform!
    unless PLATFORM_POLICIES.key?(platform)
      raise ArgumentError, "Unsupported platform: #{platform}. Supported platforms: #{PLATFORM_POLICIES.keys.join(', ')}"
    end
  end

  def get_platform_policies
    PLATFORM_POLICIES[platform] || {}
  end

  # Platform policy validation
  def validate_platform_policies(content, result)
    platform_rules = get_platform_policies

    # Check length limits
    if platform_rules[:max_length] && content.length > platform_rules[:max_length]
      result[:valid] = false
      result[:errors] << "Content exceeds platform maximum length: #{content.length}/#{platform_rules[:max_length]} characters"
      result[:policy_violations] << 'length_violation'
    end

    # Check banned keywords
    banned_keywords = find_banned_keywords(content, platform_rules[:banned_keywords] || [])
    if banned_keywords.any?
      result[:warnings] += banned_keywords.map { |keyword| "Contains potentially banned keyword: '#{keyword}'" }
      result[:policy_violations] += banned_keywords.map { |keyword| "banned_keyword_#{keyword}" }
    end

    # Check suspicious patterns
    suspicious_patterns = find_suspicious_patterns(content, platform_rules[:suspicious_patterns] || [])
    if suspicious_patterns.any?
      result[:warnings] += suspicious_patterns.map { |pattern| "Contains suspicious pattern that may trigger automated detection" }
      result[:policy_violations] += suspicious_patterns.map { |_| 'suspicious_pattern' }
    end

    # Platform-specific checks
    validate_platform_specific_rules(content, platform_rules, result)
  end

  def validate_platform_specific_rules(content, platform_rules, result)
    case platform
    when :linkedin
      validate_linkedin_professional_context(content, result)
    when :email
      validate_email_can_spam_compliance(content, result)
    when :facebook
      validate_facebook_community_standards(content, result)
    when :instagram
      validate_instagram_community_guidelines(content, result)
    when :twitter
      validate_twitter_rules(content, result)
    end
  end

  def validate_linkedin_professional_context(content, result)
    unprofessional_indicators = [
      /party/i,
      /drunk/i,
      /hangover/i,
      /personal.*drama/i
    ]

    unprofessional_found = unprofessional_indicators.any? { |pattern| content.match?(pattern) }
    if unprofessional_found
      result[:warnings] << "Content may not align with LinkedIn's professional context expectations"
      result[:policy_violations] << 'unprofessional_content'
    end
  end

  def validate_email_can_spam_compliance(content, result)
    # Check for required unsubscribe language
    unless content.match?(/unsubscribe|opt.*out|remove.*list/i)
      result[:warnings] << "Email content should include unsubscribe information for CAN-SPAM compliance"
      result[:policy_violations] << 'missing_unsubscribe'
    end

    # Check for sender identification
    unless content.match?/company|organization|business|contact/i
      result[:warnings] << "Email should clearly identify the sender organization"
      result[:policy_violations] << 'unclear_sender'
    end
  end

  def validate_facebook_community_standards(content, result)
    # Check for fact-checking triggers
    fact_check_triggers = [
      /breaking.*news/i,
      /government.*cover.*up/i,
      /doctors.*hate.*this/i,
      /miracle.*cure/i
    ]

    if fact_check_triggers.any? { |pattern| content.match?(pattern) }
      result[:warnings] << "Content may trigger Facebook's fact-checking systems"
      result[:policy_violations] << 'fact_check_trigger'
    end
  end

  def validate_instagram_community_guidelines(content, result)
    # Check for follow-for-follow content
    if content.match?(/follow.*follow|f4f|follow.*back/i)
      result[:warnings] << "Follow-for-follow content violates Instagram's community guidelines"
      result[:policy_violations] << 'engagement_bait'
    end

    # Check hashtag spam
    hashtag_count = content.scan(/#\w+/).length
    if hashtag_count > 15
      result[:warnings] << "Excessive hashtags may be flagged as spam on Instagram"
      result[:policy_violations] << 'hashtag_spam'
    end
  end

  def validate_twitter_rules(content, result)
    # Check for automated behavior patterns
    if content.match?(/follow.*me.*follow.*you|auto.*follow|follow.*train/i)
      result[:warnings] << "Content suggests automated behavior which violates Twitter rules"
      result[:policy_violations] << 'automated_behavior'
    end
  end

  # Spam indicator validation
  def validate_spam_indicators(content, result)
    SPAM_INDICATORS.each do |indicator_name, config|
      case indicator_name
      when :excessive_caps
        validate_excessive_caps(content, config, result)
      when :excessive_punctuation
        validate_excessive_punctuation(content, config, result)
      when :excessive_emojis
        validate_excessive_emojis(content, config, result)
      when :repeated_words
        validate_repeated_words(content, config, result)
      when :suspicious_urls
        validate_suspicious_urls(content, config, result)
      when :urgency_language
        validate_urgency_language(content, config, result)
      end
    end
  end

  def validate_excessive_caps(content, config, result)
    caps_matches = content.scan(config[:pattern])
    if caps_matches.length > config[:threshold]
      severity = config[:severity]
      result[:spam_indicators] << {
        type: 'excessive_caps',
        severity: severity,
        count: caps_matches.length,
        threshold: config[:threshold]
      }
      
      message = "Excessive use of capital letters detected (#{caps_matches.length} instances)"
      add_result_message(result, message, severity)
    end
  end

  def validate_excessive_punctuation(content, config, result)
    punct_matches = content.scan(config[:pattern])
    if punct_matches.length > config[:threshold]
      severity = config[:severity]
      result[:spam_indicators] << {
        type: 'excessive_punctuation',
        severity: severity,
        count: punct_matches.length,
        threshold: config[:threshold]
      }
      
      message = "Excessive punctuation detected (#{punct_matches.length} instances)"
      add_result_message(result, message, severity)
    end
  end

  def validate_excessive_emojis(content, config, result)
    emoji_count = count_emojis(content)
    if emoji_count > config[:threshold]
      severity = config[:severity]
      result[:spam_indicators] << {
        type: 'excessive_emojis',
        severity: severity,
        count: emoji_count,
        threshold: config[:threshold]
      }
      
      message = "Excessive emoji usage detected (#{emoji_count} emojis)"
      add_result_message(result, message, severity)
    end
  end

  def validate_repeated_words(content, config, result)
    words = content.downcase.split(/\W+/)
    word_counts = words.tally
    repeated_words = word_counts.select { |_, count| count > config[:threshold] }
    
    if repeated_words.any?
      severity = config[:severity]
      result[:spam_indicators] << {
        type: 'repeated_words',
        severity: severity,
        repeated_words: repeated_words.keys,
        threshold: config[:threshold]
      }
      
      message = "Repeated words detected: #{repeated_words.keys.join(', ')}"
      add_result_message(result, message, severity)
    end
  end

  def validate_suspicious_urls(content, config, result)
    url_matches = content.scan(config[:pattern])
    if url_matches.length > config[:threshold]
      severity = config[:severity]
      result[:spam_indicators] << {
        type: 'suspicious_urls',
        severity: severity,
        count: url_matches.length,
        threshold: config[:threshold]
      }
      
      message = "Suspicious URL shorteners detected (#{url_matches.length} instances)"
      add_result_message(result, message, severity)
    end
  end

  def validate_urgency_language(content, config, result)
    urgency_matches = config[:patterns].count { |pattern| content.match?(pattern) }
    if urgency_matches > config[:threshold]
      severity = config[:severity]
      result[:spam_indicators] << {
        type: 'urgency_language',
        severity: severity,
        count: urgency_matches,
        threshold: config[:threshold]
      }
      
      message = "Excessive urgency language detected (#{urgency_matches} instances)"
      add_result_message(result, message, severity)
    end
  end

  # Sensitive content validation
  def validate_sensitive_content(content, result)
    SENSITIVE_CATEGORIES.each do |category, config|
      category_keywords = find_category_keywords(content, config[:keywords])
      
      if category_keywords.any?
        result[:sensitive_content_flags] << {
          category: category,
          keywords_found: category_keywords,
          requires_disclaimers: config[:requires_disclaimers],
          high_regulation: config[:high_regulation],
          platform_restrictions: config[:platforms_with_restrictions]&.include?(platform)
        }

        if config[:requires_disclaimers]
          result[:required_disclaimers] << generate_disclaimer_text(category)
        end

        if config[:platforms_with_restrictions]&.include?(platform)
          result[:warnings] << "Content contains #{category} keywords which may have restrictions on #{platform}"
          result[:policy_violations] << "sensitive_content_#{category}"
        end
      end
    end
  end

  # Brand compliance validation
  def validate_brand_compliance(content, result)
    return if brand_guidelines.empty?

    # Check brand voice compliance
    if brand_guidelines[:tone] && !matches_brand_tone?(content, brand_guidelines[:tone])
      result[:warnings] << "Content tone may not align with brand guidelines (expected: #{brand_guidelines[:tone]})"
    end

    # Check prohibited terms
    if brand_guidelines[:prohibited_terms]
      prohibited_found = find_banned_keywords(content, brand_guidelines[:prohibited_terms])
      if prohibited_found.any?
        result[:warnings] += prohibited_found.map { |term| "Contains prohibited brand term: '#{term}'" }
        result[:policy_violations] += prohibited_found.map { |term| "brand_prohibited_#{term}" }
      end
    end

    # Check required terms
    if brand_guidelines[:required_terms]
      missing_terms = brand_guidelines[:required_terms] - find_category_keywords(content, brand_guidelines[:required_terms])
      if missing_terms.any?
        result[:suggestions] += missing_terms.map { |term| "Consider including required brand term: '#{term}'" }
      end
    end
  end

  # Regulatory compliance validation
  def validate_regulatory_compliance(content, result)
    return if regulatory_requirements.empty?

    # GDPR compliance for EU content
    if regulatory_requirements[:gdpr_required]
      unless content.match?(/privacy.*policy|data.*protection|gdpr/i)
        result[:warnings] << "GDPR-regulated content should reference privacy policy or data protection"
        result[:required_disclaimers] << "Privacy policy reference required for GDPR compliance"
      end
    end

    # FTC disclosure requirements
    if regulatory_requirements[:ftc_disclosure_required]
      unless content.match?(/#ad|#sponsored|#partnership|advertisement/i)
        result[:warnings] << "FTC requires disclosure of paid partnerships or sponsored content"
        result[:required_disclaimers] << "Required FTC disclosure: #ad or #sponsored"
      end
    end

    # Medical disclaimers
    if regulatory_requirements[:medical_disclaimer_required]
      unless content.match?(/consult.*doctor|medical.*advice|healthcare.*professional/i)
        result[:warnings] << "Medical content requires professional consultation disclaimer"
        result[:required_disclaimers] << "Medical disclaimer: Consult healthcare professional"
      end
    end
  end

  # Accessibility validation
  def validate_accessibility_requirements(content, result)
    # Check for alt text mentions for images
    if content.match?(/image|photo|picture/i) && !content.match?(/alt.*text|describe/i)
      result[:suggestions] << "Consider including alt text descriptions for accessibility"
    end

    # Check for readable formatting
    if content.length > 500 && !content.include?("\n")
      result[:suggestions] << "Consider adding paragraph breaks for better readability"
    end

    # Check for plain language
    complex_words = count_complex_words(content)
    if complex_words > content.split.length * 0.2
      result[:suggestions] << "Consider simplifying language for better accessibility"
    end
  end

  # Helper methods
  def find_banned_keywords(content, banned_list)
    return [] if banned_list.empty?
    
    content_words = content.downcase.split(/\W+/)
    banned_list.select { |keyword| content_words.include?(keyword.downcase) }
  end

  def find_suspicious_patterns(content, pattern_list)
    return [] if pattern_list.empty?
    
    pattern_list.select { |pattern| content.match?(pattern) }
  end

  def find_category_keywords(content, keyword_list)
    return [] if keyword_list.empty?
    
    content_words = content.downcase.split(/\W+/)
    keyword_list.select { |keyword| content_words.include?(keyword.downcase) }
  end

  def count_emojis(content)
    emoji_pattern = /[\u{1f300}-\u{1f5ff}\u{1f600}-\u{1f64f}\u{1f680}-\u{1f6ff}\u{1f700}-\u{1f77f}\u{1f780}-\u{1f7ff}\u{1f800}-\u{1f8ff}\u{2600}-\u{26ff}\u{2700}-\u{27bf}]/
    content.scan(emoji_pattern).length
  end

  def count_complex_words(content)
    words = content.split(/\W+/)
    words.count { |word| word.length > 7 || word.match?(/\w{3,}\w{3,}/) }
  end

  def matches_brand_tone?(content, expected_tone)
    tone_indicators = {
      'professional' => %w[professional expertise experience solution quality service],
      'casual' => %w[hey cool awesome great fun easy simple],
      'friendly' => %w[welcome help happy excited love enjoy together],
      'authoritative' => %w[expert proven research data evidence results studies]
    }

    content_words = content.downcase.split(/\W+/)
    tone_words = tone_indicators[expected_tone.to_s] || []
    
    matching_words = content_words & tone_words
    matching_words.length >= 2 # Require at least 2 tone-matching words
  end

  def generate_disclaimer_text(category)
    case category
    when :financial
      "Investment advice disclaimer: Past performance does not guarantee future results. Consult a financial advisor."
    when :health
      "Health disclaimer: This information is not medical advice. Consult your healthcare provider."
    when :political
      "Political content disclaimer: Views expressed are opinions and not endorsements."
    else
      "Disclaimer: This content is for informational purposes only."
    end
  end

  def add_result_message(result, message, severity)
    case severity
    when :high
      result[:errors] << message
      result[:valid] = false
    when :medium
      result[:warnings] << message
    when :low
      result[:suggestions] << message
    end
  end

  def calculate_compliance_score(result)
    base_score = 1.0
    
    # Deduct for errors (critical violations)
    base_score -= result[:errors].length * 0.2
    
    # Deduct for warnings (moderate violations)
    base_score -= result[:warnings].length * 0.1
    
    # Deduct for spam indicators
    spam_penalty = result[:spam_indicators].sum do |indicator|
      case indicator[:severity]
      when :high then 0.15
      when :medium then 0.1
      when :low then 0.05
      else 0.05
      end
    end
    base_score -= spam_penalty
    
    # Deduct for sensitive content on restricted platforms
    sensitive_penalty = result[:sensitive_content_flags].count { |flag| flag[:platform_restrictions] } * 0.1
    base_score -= sensitive_penalty
    
    result[:compliance_score] = [base_score, 0.0].max
  end

  def generate_compliance_suggestions(content, result)
    # Generate actionable suggestions based on validation results
    if result[:compliance_score] < 0.8
      result[:suggestions] << "Consider revising content to improve platform compliance"
    end

    if result[:spam_indicators].any?
      result[:suggestions] << "Reduce spam-like elements to improve content delivery"
    end

    if result[:sensitive_content_flags].any?
      result[:suggestions] << "Add appropriate disclaimers for sensitive content categories"
    end

    # Platform-specific suggestions
    case platform
    when :linkedin
      if result[:policy_violations].include?('unprofessional_content')
        result[:suggestions] << "Maintain professional tone appropriate for LinkedIn audience"
      end
    when :email
      if result[:policy_violations].include?('missing_unsubscribe')
        result[:suggestions] << "Include unsubscribe link for CAN-SPAM compliance"
      end
    when :instagram
      if result[:policy_violations].include?('engagement_bait')
        result[:suggestions] << "Focus on authentic engagement rather than follow-for-follow tactics"
      end
    end
  end

  def analyze_platform_issues(validation_results)
    platform_issues = {}
    
    all_violations = validation_results.flat_map { |result| result[:policy_violations] }
    platform_issues[:most_common_violations] = all_violations.tally.sort_by { |_, count| -count }.first(5).to_h
    
    compliance_scores = validation_results.map { |result| result[:compliance_score] }
    platform_issues[:average_compliance_score] = (compliance_scores.sum / compliance_scores.length).round(3)
    
    platform_issues[:compliance_distribution] = {
      high_compliance: compliance_scores.count { |score| score >= 0.8 },
      medium_compliance: compliance_scores.count { |score| score >= 0.6 && score < 0.8 },
      low_compliance: compliance_scores.count { |score| score < 0.6 }
    }
    
    platform_issues
  end

  def generate_report_recommendations(report)
    recommendations = []
    
    if report[:overall_compliance_rate] < 80
      recommendations << "Overall compliance rate is low. Focus on addressing common violations."
    end

    if report[:common_violations].key?('length_violation')
      recommendations << "Content length violations are common. Implement automated length checking."
    end

    if report[:common_violations].any? { |violation, _| violation.start_with?('banned_keyword') }
      recommendations << "Review and train content creators on platform-specific banned keywords."
    end

    if report[:common_violations].key?('engagement_bait')
      recommendations << "Educate team on authentic engagement strategies vs. engagement bait."
    end

    recommendations
  end
end