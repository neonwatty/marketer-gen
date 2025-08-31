// Test data factory for generating realistic test data for AI workflow tests

class TestDataFactory {
  /**
   * Generate campaign plan data with correct model values
   * @param {Object} overrides - Override default values
   * @returns {Object} Campaign plan data
   */
  static generateCampaignPlan(overrides = {}) {
    // Valid values from CampaignPlan model constants
    const validCampaignTypes = [
      'product_launch', 'brand_awareness', 'lead_generation', 
      'customer_retention', 'sales_promotion', 'event_marketing'
    ];
    
    const validObjectives = [
      'brand_awareness', 'lead_generation', 'customer_acquisition',
      'customer_retention', 'sales_growth', 'market_expansion'
    ];
    
    const defaults = {
      name: `Test Campaign ${Date.now()}`,
      description: 'AI-powered marketing campaign for testing purposes',
      campaign_type: 'brand_awareness', // ✅ Fixed: use valid model value
      objective: 'brand_awareness', // ✅ Fixed: use valid model value
      target_audience: 'Tech-savvy professionals aged 25-45 in marketing and sales roles. Decision-makers at mid-size companies looking for marketing automation solutions.',
      budget_constraints: '$10,000 - $25,000 monthly budget. Focus on cost-effective digital channels with measurable ROI.',
      timeline_constraints: '3-month campaign launch timeline. Q4 2024 execution with monthly optimization cycles.'
    };

    return { ...defaults, ...overrides };
  }
  
  /**
   * Get valid campaign types from model
   * @returns {Array} Valid campaign type values
   */
  static getValidCampaignTypes() {
    return ['product_launch', 'brand_awareness', 'lead_generation', 'customer_retention', 'sales_promotion', 'event_marketing'];
  }
  
  /**
   * Get valid objectives from model
   * @returns {Array} Valid objective values  
   */
  static getValidObjectives() {
    return ['brand_awareness', 'lead_generation', 'customer_acquisition', 'customer_retention', 'sales_growth', 'market_expansion'];
  }
  
  /**
   * Generate random valid campaign data
   * @param {Object} overrides - Override default values
   * @returns {Object} Campaign plan data with random valid values
   */
  static generateRandomCampaignPlan(overrides = {}) {
    const campaignTypes = this.getValidCampaignTypes();
    const objectives = this.getValidObjectives();
    
    const randomDefaults = {
      campaign_type: campaignTypes[Math.floor(Math.random() * campaignTypes.length)],
      objective: objectives[Math.floor(Math.random() * objectives.length)]
    };
    
    return this.generateCampaignPlan({ ...randomDefaults, ...overrides });
  }

  /**
   * Generate generated content data
   * @param {Object} overrides - Override default values
   * @returns {Object} Generated content data
   */
  static generateContent(overrides = {}) {
    const contentTypes = ['social_post', 'email', 'ad_copy', 'landing_page', 'blog_post'];
    const formatVariants = ['short', 'medium', 'long'];
    
    const defaults = {
      title: `Test Content ${Date.now()}`,
      content_type: contentTypes[Math.floor(Math.random() * contentTypes.length)],
      format_variant: formatVariants[Math.floor(Math.random() * formatVariants.length)],
      body_content: '' // Leave blank for AI generation
    };

    return { ...defaults, ...overrides };
  }

  /**
   * Generate brand identity data
   * @param {Object} overrides - Override default values
   * @returns {Object} Brand identity data
   */
  static generateBrandIdentity(overrides = {}) {
    const defaults = {
      name: `Test Brand ${Date.now()}`,
      industry: 'technology',
      voice_tone: 'professional',
      target_audience: 'B2B marketing professionals',
      key_messages: [
        'Innovation-driven solutions',
        'Data-driven results',
        'Customer success focused'
      ],
      brand_guidelines: this.generateBrandGuidelinesText()
    };

    return { ...defaults, ...overrides };
  }

  /**
   * Generate realistic brand guidelines text
   * @returns {string} Brand guidelines content
   */
  static generateBrandGuidelinesText() {
    return `
BRAND VOICE & TONE GUIDELINES

Voice Characteristics:
- Professional yet approachable
- Data-driven and results-focused
- Innovation-focused messaging
- Authoritative but not arrogant

Tone Guidelines:
- Use active voice
- Be concise and clear
- Focus on benefits, not features
- Include data and metrics when possible
- Avoid jargon and complex terminology

Key Messaging Pillars:
1. Innovation: We deliver cutting-edge marketing solutions
2. Results: Data-driven approach with measurable ROI
3. Partnership: Success through collaboration

Brand Personality:
- Intelligent and analytical
- Reliable and trustworthy  
- Forward-thinking and innovative
- Results-oriented and practical

Communication Style:
- No excessive emojis in professional content
- Use sentence case for headlines
- Include social proof and testimonials
- Focus on customer success stories

Target Audience:
- Marketing professionals and decision-makers
- Small to mid-size business owners
- Growth-focused companies
- Technology-aware audiences
    `.trim();
  }

  /**
   * Generate journey data
   * @param {Object} overrides - Override default values
   * @returns {Object} Journey data
   */
  static generateJourney(overrides = {}) {
    const journeyTypes = ['email_sequence', 'social_media_campaign', 'webinar_series', 'product_launch'];
    
    const defaults = {
      name: `Test Journey ${Date.now()}`,
      description: 'AI-generated customer journey for testing',
      journey_type: journeyTypes[Math.floor(Math.random() * journeyTypes.length)],
      target_stage: 'awareness' // awareness, consideration, decision
    };

    return { ...defaults, ...overrides };
  }

  /**
   * Generate social media platform options
   * @returns {Array} Platform options
   */
  static getSocialMediaPlatforms() {
    return [
      { value: 'twitter', name: 'Twitter', charLimit: 280 },
      { value: 'linkedin', name: 'LinkedIn', charLimit: 3000 },
      { value: 'facebook', name: 'Facebook', charLimit: 63206 },
      { value: 'instagram', name: 'Instagram', charLimit: 2200 }
    ];
  }

  /**
   * Generate email content parameters
   * @returns {Object} Email parameters
   */
  static generateEmailParams() {
    const subjects = [
      'Transform Your Marketing ROI',
      'New AI Features Available',
      'Your Marketing Performance Report',
      'Exclusive Insights for Growth'
    ];

    return {
      subject: subjects[Math.floor(Math.random() * subjects.length)],
      audience: 'marketing_professionals',
      tone: 'professional',
      cta: 'Schedule a Demo'
    };
  }

  /**
   * Generate ad copy parameters
   * @returns {Object} Ad parameters
   */
  static generateAdParams() {
    return {
      platform: 'google_ads', // google_ads, facebook_ads, linkedin_ads
      campaign_type: 'search', // search, display, social
      target_action: 'signup', // signup, demo, purchase
      budget_range: '1000-5000'
    };
  }

  /**
   * Generate sample file content for upload testing
   * @param {string} type - File type (pdf, txt, doc)
   * @returns {Object} File data
   */
  static generateSampleFile(type = 'txt') {
    const files = {
      txt: {
        name: 'brand_guidelines.txt',
        content: this.generateBrandGuidelinesText(),
        mimeType: 'text/plain'
      },
      pdf: {
        name: 'brand_guidelines.pdf',
        content: 'Mock PDF content for testing',
        mimeType: 'application/pdf'
      }
    };

    return files[type] || files.txt;
  }

  /**
   * Generate API request data for content generation
   * @param {string} contentType - Type of content to generate
   * @returns {Object} API request payload
   */
  static generateAPIRequestData(contentType) {
    const baseData = {
      tone: 'professional',
      brand_context: {
        voice: 'innovative',
        keywords: ['AI', 'automation', 'ROI', 'marketing'],
        industry: 'technology'
      }
    };

    const typeSpecificData = {
      social_media: {
        platform: 'linkedin',
        topic: 'AI marketing automation',
        character_limit: 300
      },
      email: {
        subject_focus: 'product_announcement',
        audience: 'existing_customers',
        cta_type: 'learn_more'
      },
      ad_copy: {
        platform: 'google_ads',
        ad_type: 'search',
        target_keyword: 'marketing automation'
      },
      landing_page: {
        page_goal: 'lead_generation',
        target_action: 'demo_request',
        industry: 'saas'
      }
    };

    return {
      ...baseData,
      ...typeSpecificData[contentType]
    };
  }

  /**
   * Generate realistic test delays for AI processing
   * @param {string} complexity - simple, medium, complex
   * @returns {number} Delay in milliseconds
   */
  static getAIProcessingDelay(complexity = 'medium') {
    const delays = {
      simple: 2000,  // 2 seconds
      medium: 5000,  // 5 seconds  
      complex: 10000 // 10 seconds
    };

    return delays[complexity] || delays.medium;
  }
}

module.exports = TestDataFactory;