// AI content validators for verifying quality and appropriateness of generated content

class AIValidators {
  /**
   * Validate social media content meets platform requirements (simplified)
   * @param {string} content - Generated content
   * @param {string} platform - Target platform (twitter, linkedin, facebook, instagram)
   * @returns {Object} Validation result
   */
  static validateSocialMediaContent(content, platform) {
    const platformLimits = {
      twitter: 280,
      linkedin: 3000,
      facebook: 63206,
      instagram: 2200
    };

    const result = {
      isValid: true,
      errors: [],
      warnings: [],
      metrics: {}
    };

    // Validate input parameters - be more lenient
    if (!content) {
      result.isValid = false;
      result.errors.push('Content is required');
      result.metrics.hashtagCount = 0;
      result.metrics.wordCount = 0;
      result.metrics.sentenceCount = 0;
      result.metrics.hasQuestions = false;
      result.metrics.hasCallToAction = false;
      result.metrics.positiveWordCount = 0;
      return result;
    }
    
    // Convert to string if not already
    const contentStr = content.toString().trim();
    if (contentStr.length === 0) {
      result.isValid = false;
      result.errors.push('Content cannot be empty');
      return result;
    }

    // Check character limit - be more flexible
    const charLimit = platformLimits[platform] || 1000; // Default limit if platform unknown
    if (contentStr.length > charLimit * 1.1) { // Allow 10% overage
      result.warnings.push(`Content may be too long for ${platform || 'platform'}: ${contentStr.length}/${charLimit}`);
      // Don't mark as invalid, just warn
    }

    // Check for hashtags (optional for social content)
    const hashtagCount = (contentStr.match(/#\w+/g) || []).length;
    result.metrics.hashtagCount = hashtagCount;
    
    // Don't require hashtags, just note their presence

    // Check for engagement elements - more lenient
    const hasQuestions = /\?/.test(contentStr);
    const hasCallToAction = /\b(click|visit|learn|try|get|start|join|follow|share|check|see|discover|explore|read)\b/i.test(contentStr);
    
    result.metrics.hasQuestions = hasQuestions;
    result.metrics.hasCallToAction = hasCallToAction;

    // Don't require CTA, just note if present

    // Check content quality indicators
    result.metrics.wordCount = contentStr.split(/\s+/).length;
    result.metrics.sentenceCount = Math.max(1, contentStr.split(/[.!?]+/).length - 1);
    
    // Basic sentiment check (positive indicators) - more inclusive
    const positiveWords = /\b(amazing|great|excellent|innovative|powerful|effective|successful|growth|improve|transform|optimize|new|better|best|top|leading|advanced|smart|easy)\b/gi;
    result.metrics.positiveWordCount = (contentStr.match(positiveWords) || []).length;

    return result;
  }

  /**
   * Validate email content structure and quality
   * @param {string} content - Generated email content
   * @param {Object} options - Email options (subject, audience, etc.)
   * @returns {Object} Validation result
   */
  static validateEmailContent(content, options = {}) {
    const result = {
      isValid: true,
      errors: [],
      warnings: [],
      metrics: {}
    };

    // Validate input parameters
    if (!content || typeof content !== 'string') {
      result.isValid = false;
      result.errors.push('Content parameter is required and must be a string');
      result.metrics.wordCount = 0;
      result.metrics.hasGreeting = false;
      result.metrics.hasClosing = false;
      result.metrics.hasCallToAction = false;
      result.metrics.hasPersonalization = false;
      return result;
    }

    // Check for basic email structure
    const hasGreeting = /\b(hi|hello|dear|greetings)\b/i.test(content);
    const hasClosing = /\b(best|regards|sincerely|thanks|cheers)\b/i.test(content);
    const hasCallToAction = /\b(click|visit|learn|try|get|start|join|schedule|download)\b/i.test(content);

    result.metrics.hasGreeting = hasGreeting;
    result.metrics.hasClosing = hasClosing;
    result.metrics.hasCallToAction = hasCallToAction;

    if (!hasGreeting) {
      result.warnings.push('Email should include a greeting');
    }

    if (!hasClosing) {
      result.warnings.push('Email should include a closing');
    }

    if (!hasCallToAction) {
      result.warnings.push('Email should include a clear call-to-action');
      // Don't mark as invalid, just warn
    }

    // Check content length (ideal email length)
    const wordCount = content.split(/\s+/).length;
    result.metrics.wordCount = wordCount;

    if (wordCount < 50) {
      result.warnings.push('Email content may be too short for effective communication');
    } else if (wordCount > 500) {
      result.warnings.push('Email content may be too long - consider breaking into sections');
    }

    // Check for personalization opportunities
    const hasPersonalization = /\{|\[|%/.test(content); // Common personalization markers
    result.metrics.hasPersonalization = hasPersonalization;

    return result;
  }

  /**
   * Validate ad copy effectiveness
   * @param {string} content - Generated ad content
   * @param {string} platform - Ad platform (google_ads, facebook_ads, linkedin_ads)
   * @returns {Object} Validation result
   */
  static validateAdCopy(content, platform) {
    const result = {
      isValid: true,
      errors: [],
      warnings: [],
      metrics: {}
    };

    // Validate input parameters
    if (!content || typeof content !== 'string') {
      result.isValid = false;
      result.errors.push('Content parameter is required and must be a string');
      result.metrics.powerWordCount = 0;
      return result;
    }

    // Platform-specific character limits
    const platformLimits = {
      google_ads: { headline: 30, description: 90 },
      facebook_ads: { headline: 40, description: 125 },
      linkedin_ads: { headline: 150, description: 600 }
    };

    // Check for compelling elements
    const hasUrgency = /\b(now|today|limited|exclusive|don't miss|act fast|deadline)\b/i.test(content);
    const hasBenefit = /\b(save|free|discount|increase|improve|grow|boost|optimize)\b/i.test(content);
    const hasNumbers = /\d+[%$]?|\b(double|triple|50%|100%)\b/i.test(content);
    const hasCallToAction = /\b(click|try|get|start|learn|download|sign up|schedule)\b/i.test(content);

    result.metrics.hasUrgency = hasUrgency;
    result.metrics.hasBenefit = hasBenefit;
    result.metrics.hasNumbers = hasNumbers;
    result.metrics.hasCallToAction = hasCallToAction;

    if (!hasCallToAction) {
      result.warnings.push('Ad copy should include a clear call-to-action');
      // Don't mark as invalid, just warn
    }

    if (!hasBenefit) {
      result.warnings.push('Ad copy should highlight clear benefits');
    }

    // Check for power words - with safe content check
    const powerWords = /\b(exclusive|proven|guaranteed|revolutionary|breakthrough|ultimate|premium|advanced)\b/gi;
    result.metrics.powerWordCount = (content.match(powerWords) || []).length;

    return result;
  }

  /**
   * Validate campaign strategy content
   * @param {string} content - Generated campaign strategy
   * @returns {Object} Validation result
   */
  static validateCampaignStrategy(content) {
    const result = {
      isValid: true,
      errors: [],
      warnings: [],
      metrics: {}
    };

    // Check for key strategy components
    const hasObjective = /\b(objective|goal|aim|purpose)\b/i.test(content);
    const hasTargetAudience = /\b(target|audience|customer|segment|demographic)\b/i.test(content);
    const hasTimeline = /\b(timeline|schedule|phase|week|month|day)\b/i.test(content);
    const hasChannels = /\b(social|email|search|display|content|pr|influencer)\b/i.test(content);
    const hasBudget = /\b(budget|cost|spend|investment|allocation)\b/i.test(content);
    const hasMetrics = /\b(roi|conversion|engagement|impression|click|reach|awareness)\b/i.test(content);

    result.metrics.hasObjective = hasObjective;
    result.metrics.hasTargetAudience = hasTargetAudience;
    result.metrics.hasTimeline = hasTimeline;
    result.metrics.hasChannels = hasChannels;
    result.metrics.hasBudget = hasBudget;
    result.metrics.hasMetrics = hasMetrics;

    // Validate essential components
    if (!hasObjective) {
      result.warnings.push('Campaign strategy should include clear objectives');
    }

    if (!hasTargetAudience) {
      result.warnings.push('Campaign strategy should define target audience');
    }

    if (!hasTimeline) {
      result.warnings.push('Campaign strategy should include timeline or phases');
    }

    // Check content depth
    const wordCount = content.split(/\s+/).length;
    result.metrics.wordCount = wordCount;

    if (wordCount < 100) {
      result.warnings.push('Campaign strategy may be too brief for comprehensive planning');
    }

    return result;
  }

  /**
   * Validate brand consistency in generated content
   * @param {string} content - Generated content
   * @param {Object} brandContext - Brand context data
   * @returns {Object} Validation result
   */
  static validateBrandConsistency(content, brandContext) {
    const result = {
      isValid: true,
      errors: [],
      warnings: [],
      metrics: {}
    };

    if (!brandContext) {
      result.warnings.push('No brand context provided for validation');
      return result;
    }

    // Check for brand keywords
    const brandKeywords = brandContext.keywords || [];
    let keywordMatches = 0;

    brandKeywords.forEach(keyword => {
      const regex = new RegExp(`\\b${keyword}\\b`, 'gi');
      if (regex.test(content)) {
        keywordMatches++;
      }
    });

    result.metrics.keywordMatches = keywordMatches;
    result.metrics.keywordTotal = brandKeywords.length;

    if (keywordMatches === 0 && brandKeywords.length > 0) {
      result.warnings.push('Content does not include any brand keywords');
    }

    // Check tone consistency (basic implementation)
    const toneIndicators = {
      professional: /\b(solutions|expertise|experience|professional|industry|business)\b/gi,
      casual: /\b(hey|awesome|cool|great|you'll|we're|let's)\b/gi,
      authoritative: /\b(research|data|proven|expert|leading|established)\b/gi
    };

    const expectedTone = brandContext.voice || brandContext.tone;
    if (expectedTone && toneIndicators[expectedTone]) {
      const toneMatches = (content.match(toneIndicators[expectedTone]) || []).length;
      result.metrics.toneMatches = toneMatches;
      
      if (toneMatches === 0) {
        result.warnings.push(`Content may not match expected ${expectedTone} tone`);
      }
    }

    return result;
  }

  /**
   * Validate content is not empty and meets minimum quality standards
   * @param {string} content - Content to validate
   * @returns {Object} Validation result
   */
  static validateContentQuality(content) {
    const result = {
      isValid: true,
      errors: [],
      warnings: [],
      metrics: {}
    };

    // Basic content checks
    if (!content || content.trim().length === 0) {
      result.isValid = false;
      result.errors.push('Content is empty');
      return result;
    }

    const trimmedContent = content.trim();
    result.metrics.characterCount = trimmedContent.length;
    result.metrics.wordCount = trimmedContent.split(/\s+/).length;
    result.metrics.sentenceCount = trimmedContent.split(/[.!?]+/).length - 1;

    // Check for minimum content length - more lenient
    if (result.metrics.wordCount < 3) {
      result.warnings.push('Content may be too short');
      // Only mark as invalid if extremely short
      if (result.metrics.wordCount < 1) {
        result.isValid = false;
        result.errors.push('Content is too short to be meaningful');
      }
    }

    // Check for placeholder text
    const placeholders = /\b(lorem ipsum|placeholder|todo|tbd|xxx|example|sample)\b/gi;
    if (placeholders.test(content)) {
      result.errors.push('Content contains placeholder text');
      result.isValid = false;
    }

    // Check for repeated words (potential generation issue)
    const words = trimmedContent.toLowerCase().split(/\s+/);
    const repeatedWords = words.filter((word, index) => 
      word.length > 3 && words.indexOf(word) !== index
    ).length;
    
    if (repeatedWords > words.length * 0.3) {
      result.warnings.push('Content may have excessive word repetition');
    }

    return result;
  }

  /**
   * Run comprehensive validation on generated content
   * @param {string} content - Content to validate
   * @param {string} contentType - Type of content
   * @param {Object} context - Additional context (platform, brand, etc.)
   * @returns {Object} Comprehensive validation result
   */
  static validateComprehensive(content, contentType, context = {}) {
    const results = [];

    // Always run quality validation
    results.push({
      type: 'quality',
      result: this.validateContentQuality(content)
    });

    // Run type-specific validation
    switch (contentType) {
      case 'social_post':
        results.push({
          type: 'social_media',
          result: this.validateSocialMediaContent(content, context.platform)
        });
        break;
      case 'email':
        results.push({
          type: 'email',
          result: this.validateEmailContent(content, context)
        });
        break;
      case 'ad_copy':
        results.push({
          type: 'ad_copy',
          result: this.validateAdCopy(content, context.platform)
        });
        break;
      case 'campaign_strategy':
        results.push({
          type: 'campaign_strategy',
          result: this.validateCampaignStrategy(content)
        });
        break;
    }

    // Run brand consistency check if brand context provided
    if (context.brandContext) {
      results.push({
        type: 'brand_consistency',
        result: this.validateBrandConsistency(content, context.brandContext)
      });
    }

    // Aggregate results
    const overallResult = {
      isValid: results.every(r => r.result.isValid),
      validationTypes: results.length,
      passedValidations: results.filter(r => r.result.isValid).length,
      totalErrors: results.reduce((sum, r) => sum + r.result.errors.length, 0),
      totalWarnings: results.reduce((sum, r) => sum + r.result.warnings.length, 0),
      results: results
    };

    return overallResult;
  }
  
  /**
   * Simple validation that just checks if content exists and is not empty
   * Use this as a fallback when other validations are too strict
   * @param {any} content - Content to validate
   * @param {Object} options - Validation options
   * @returns {Object} Simple validation result
   */
  static validateSimple(content, options = {}) {
    const { 
      minLength = 1,
      allowUndefined = false,
      allowEmpty = false 
    } = options;
    
    const result = {
      isValid: true,
      errors: [],
      warnings: [],
      metrics: {}
    };
    
    // Handle undefined/null content
    if (content === undefined || content === null) {
      if (allowUndefined) {
        result.warnings.push('Content is undefined');
        result.metrics.contentLength = 0;
        return result;
      } else {
        result.isValid = false;
        result.errors.push('Content is undefined or null');
        result.metrics.contentLength = 0;
        return result;
      }
    }
    
    // Convert to string and check
    const contentStr = content.toString().trim();
    result.metrics.contentLength = contentStr.length;
    result.metrics.wordCount = contentStr.length > 0 ? contentStr.split(/\s+/).length : 0;
    
    if (contentStr.length === 0) {
      if (allowEmpty) {
        result.warnings.push('Content is empty');
      } else {
        result.isValid = false;
        result.errors.push('Content is empty');
      }
      return result;
    }
    
    // Check minimum length
    if (contentStr.length < minLength) {
      result.warnings.push(`Content shorter than minimum length: ${contentStr.length}/${minLength}`);
      if (minLength > 3) { // Only mark as invalid if minimum is reasonable
        result.isValid = false;
        result.errors.push(`Content too short: ${contentStr.length}/${minLength}`);
      }
    }
    
    return result;
  }
  
  /**
   * Lenient validation that focuses on essential checks only
   * @param {string} content - Content to validate
   * @param {string} contentType - Type of content
   * @param {Object} context - Additional context
   * @returns {Object} Lenient validation result
   */
  static validateLenient(content, contentType, context = {}) {
    // Start with simple validation
    const simpleResult = this.validateSimple(content, { minLength: 5 });
    
    if (!simpleResult.isValid) {
      return simpleResult;
    }
    
    // Add basic content type checks without being too strict
    const result = {
      isValid: true,
      errors: simpleResult.errors,
      warnings: simpleResult.warnings,
      metrics: simpleResult.metrics
    };
    
    const contentStr = content.toString().trim();
    
    // Basic checks based on content type
    switch (contentType) {
      case 'social_post':
      case 'social_media':
        // Just check it's not extremely long
        if (contentStr.length > 5000) {
          result.warnings.push('Content may be too long for social media');
        }
        break;
        
      case 'email':
        // Just check for basic structure hints
        if (contentStr.length < 20) {
          result.warnings.push('Email content may be too brief');
        }
        break;
        
      case 'ad_copy':
        // Check for basic marketing elements
        const hasMarketingWords = /\b(new|free|save|get|try|best|top|now|today)\b/i.test(contentStr);
        result.metrics.hasMarketingElements = hasMarketingWords;
        break;
    }
    
    return result;
  }
}

module.exports = AIValidators;