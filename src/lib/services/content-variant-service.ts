import { ContentFormatTemplate, ContentType, ContentTypeValue, ContentVariant,ToneOptionValue, VariantStrategy } from '@/lib/types/content-generation'

import { openAIService } from './openai-service'

/**
 * Enhanced content variant generation service
 * Implements multiple strategies for generating diverse content variants
 * with format-specific optimizations
 */
export class ContentVariantService {
  
  // Format-specific templates for better content generation
  private static formatTemplates: Record<ContentTypeValue, ContentFormatTemplate> = {
    [ContentType.EMAIL]: {
      type: ContentType.EMAIL,
      name: 'Email Marketing Template',
      template: `Subject: {{subject}}

Hi {{recipient}},

{{opening}}

{{body}}

{{cta}}

Best regards,
{{sender}}`,
      placeholders: ['subject', 'recipient', 'opening', 'body', 'cta', 'sender'],
      optimizations: {
        maxCharacters: 3000,
        maxWords: 500,
        requiredElements: ['subject', 'personalization', 'clear_cta'],
        bestPractices: ['Use personalization', 'Clear subject line', 'Single CTA', 'Mobile-friendly'],
        platforms: ['email']
      },
      examples: ['Newsletter', 'Promotional email', 'Welcome series']
    },
    
    [ContentType.SOCIAL_POST]: {
      type: ContentType.SOCIAL_POST,
      name: 'Social Media Post Template',
      template: `{{hook}}

{{content}}

{{hashtags}}`,
      placeholders: ['hook', 'content', 'hashtags'],
      optimizations: {
        maxCharacters: 280,
        maxWords: 50,
        requiredElements: ['engaging_hook', 'hashtags'],
        bestPractices: ['Start with a hook', 'Include hashtags', 'Ask questions', 'Use emojis sparingly'],
        platforms: ['twitter', 'facebook', 'linkedin']
      },
      examples: ['Engagement post', 'Behind-the-scenes', 'Tips and insights']
    },
    
    [ContentType.SOCIAL_AD]: {
      type: ContentType.SOCIAL_AD,
      name: 'Social Media Ad Template',
      template: `{{headline}}

{{description}}

{{cta}}`,
      placeholders: ['headline', 'description', 'cta'],
      optimizations: {
        maxCharacters: 150,
        maxWords: 30,
        requiredElements: ['compelling_headline', 'clear_cta', 'benefit_focused'],
        bestPractices: ['Focus on benefits', 'Strong CTA', 'Social proof', 'Urgency'],
        platforms: ['facebook', 'instagram', 'linkedin', 'twitter']
      },
      examples: ['Lead generation', 'Product promotion', 'Brand awareness']
    },
    
    [ContentType.SEARCH_AD]: {
      type: ContentType.SEARCH_AD,
      name: 'Search Ad Template',
      template: `{{headline1}} | {{headline2}}
{{description}}
{{cta}}`,
      placeholders: ['headline1', 'headline2', 'description', 'cta'],
      optimizations: {
        maxCharacters: 90,
        maxWords: 20,
        requiredElements: ['keyword_match', 'clear_cta', 'value_proposition'],
        bestPractices: ['Include keywords', 'Match search intent', 'Highlight unique value', 'Use ad extensions'],
        platforms: ['google_ads', 'bing_ads']
      },
      examples: ['Search campaign', 'Product ads', 'Local ads']
    },
    
    [ContentType.BLOG_POST]: {
      type: ContentType.BLOG_POST,
      name: 'Blog Post Template',
      template: `# {{title}}

{{introduction}}

## {{section1_title}}
{{section1_content}}

## {{section2_title}}
{{section2_content}}

{{conclusion}}

{{cta}}`,
      placeholders: ['title', 'introduction', 'section1_title', 'section1_content', 'section2_title', 'section2_content', 'conclusion', 'cta'],
      optimizations: {
        maxCharacters: 5000,
        maxWords: 1000,
        requiredElements: ['engaging_title', 'clear_structure', 'actionable_content', 'seo_optimized'],
        bestPractices: ['Use headings', 'Include visuals', 'SEO optimization', 'Internal linking'],
        platforms: ['website', 'cms']
      },
      examples: ['How-to guides', 'Industry insights', 'Company updates']
    },
    
    [ContentType.LANDING_PAGE]: {
      type: ContentType.LANDING_PAGE,
      name: 'Landing Page Template',
      template: `# {{headline}}

{{subheadline}}

{{value_proposition}}

{{benefits}}

{{social_proof}}

{{cta}}`,
      placeholders: ['headline', 'subheadline', 'value_proposition', 'benefits', 'social_proof', 'cta'],
      optimizations: {
        maxCharacters: 2000,
        maxWords: 400,
        requiredElements: ['compelling_headline', 'clear_value_prop', 'strong_cta', 'social_proof'],
        bestPractices: ['Above-the-fold CTA', 'Social proof', 'Benefit-focused', 'Mobile optimized'],
        platforms: ['website', 'landing_page_builders']
      },
      examples: ['Product launch', 'Lead generation', 'Event registration']
    },
    
    [ContentType.VIDEO_SCRIPT]: {
      type: ContentType.VIDEO_SCRIPT,
      name: 'Video Script Template',
      template: `HOOK (0-3s): {{hook}}

PROBLEM (3-10s): {{problem}}

SOLUTION (10-30s): {{solution}}

PROOF (30-45s): {{proof}}

CTA (45-60s): {{cta}}`,
      placeholders: ['hook', 'problem', 'solution', 'proof', 'cta'],
      optimizations: {
        maxCharacters: 1500,
        maxWords: 300,
        requiredElements: ['attention_hook', 'clear_structure', 'compelling_cta'],
        bestPractices: ['Start with hook', 'Structured narrative', 'Visual cues', 'Clear timing'],
        platforms: ['youtube', 'social_video', 'ads']
      },
      examples: ['Explainer videos', 'Product demos', 'Brand stories']
    },
    
    [ContentType.INFOGRAPHIC]: {
      type: ContentType.INFOGRAPHIC,
      name: 'Infographic Content Template',
      template: `TITLE: {{title}}

STAT 1: {{stat1}}
STAT 2: {{stat2}}
STAT 3: {{stat3}}

KEY INSIGHT: {{insight}}

TAKEAWAY: {{takeaway}}`,
      placeholders: ['title', 'stat1', 'stat2', 'stat3', 'insight', 'takeaway'],
      optimizations: {
        maxCharacters: 500,
        maxWords: 100,
        requiredElements: ['compelling_title', 'data_points', 'key_insight'],
        bestPractices: ['Data-driven', 'Visual hierarchy', 'Shareable', 'Brand consistent'],
        platforms: ['social_media', 'presentations', 'reports']
      },
      examples: ['Industry statistics', 'Process flows', 'Comparison charts']
    },
    
    [ContentType.NEWSLETTER]: {
      type: ContentType.NEWSLETTER,
      name: 'Newsletter Template',
      template: `Subject: {{subject}}

## {{greeting}}

{{intro}}

### {{section1_title}}
{{section1_content}}

### {{section2_title}}
{{section2_content}}

{{closing}}

{{signature}}`,
      placeholders: ['subject', 'greeting', 'intro', 'section1_title', 'section1_content', 'section2_title', 'section2_content', 'closing', 'signature'],
      optimizations: {
        maxCharacters: 4000,
        maxWords: 800,
        requiredElements: ['engaging_subject', 'personal_greeting', 'valuable_content', 'clear_sections'],
        bestPractices: ['Consistent format', 'Value-first', 'Scannable', 'Personal touch'],
        platforms: ['email']
      },
      examples: ['Weekly updates', 'Industry news', 'Product updates']
    },
    
    [ContentType.PRESS_RELEASE]: {
      type: ContentType.PRESS_RELEASE,
      name: 'Press Release Template',
      template: `FOR IMMEDIATE RELEASE

{{headline}}

{{dateline}}

{{lead_paragraph}}

{{body_paragraph1}}

{{body_paragraph2}}

{{quote}}

{{company_info}}

###`,
      placeholders: ['headline', 'dateline', 'lead_paragraph', 'body_paragraph1', 'body_paragraph2', 'quote', 'company_info'],
      optimizations: {
        maxCharacters: 1500,
        maxWords: 300,
        requiredElements: ['newsworthy_headline', 'lead_paragraph', 'quotes', 'company_boilerplate'],
        bestPractices: ['Inverted pyramid', 'Third person', 'Quotable content', 'Media contact info'],
        platforms: ['media', 'press_distribution']
      },
      examples: ['Product launches', 'Company news', 'Partnership announcements']
    }
  }

  // Variant generation strategies with specific prompts and configurations
  private static variantStrategies: Record<string, VariantStrategy> = {
    style_variation: {
      name: 'style_variation',
      description: 'Generate variants with different writing styles while maintaining core message',
      prompt: `Create a style variation of this content. Maintain the same core message and key points, but change the writing style, sentence structure, and approach. 
      
      Variations can include:
      - Formal vs casual tone
      - Direct vs storytelling approach  
      - Technical vs simplified language
      - First person vs third person perspective
      
      Original content: {{content}}
      Content type: {{contentType}}
      Brand context: {{brandContext}}
      
      Style variation:`,
      temperature: 0.8,
      maxTokens: 1000
    },

    length_variation: {
      name: 'length_variation', 
      description: 'Generate shorter and longer versions optimized for different contexts',
      prompt: `Create a length variation of this content. {{lengthInstruction}}
      
      Guidelines:
      - Maintain core message and brand voice
      - Adjust detail level appropriately
      - Keep most important information
      - Optimize for the target length
      
      Original content: {{content}}
      Content type: {{contentType}}
      Target adjustment: {{lengthInstruction}}
      
      Length variation:`,
      temperature: 0.6,
      maxTokens: 1200
    },

    angle_variation: {
      name: 'angle_variation',
      description: 'Generate variants with different messaging angles or perspectives',
      prompt: `Create an angle variation of this content by approaching it from a different perspective or messaging angle.
      
      Alternative angles might include:
      - Problem-focused vs solution-focused
      - Feature-focused vs benefit-focused  
      - Emotional vs rational appeal
      - Individual vs community impact
      - Present vs future orientation
      
      Original content: {{content}}
      Content type: {{contentType}}
      Brand context: {{brandContext}}
      
      Angle variation:`,
      temperature: 0.9,
      maxTokens: 1000
    },

    tone_variation: {
      name: 'tone_variation',
      description: 'Generate variants with different emotional tones',
      prompt: `Create a tone variation of this content with a different emotional approach while staying true to the brand.
      
      Tone variations might include:
      - Urgent vs reassuring
      - Exciting vs calm
      - Authoritative vs conversational
      - Optimistic vs realistic
      - Personal vs professional
      
      Original content: {{content}}
      Content type: {{contentType}}
      Current tone: {{currentTone}}
      Brand voice: {{brandVoice}}
      
      Tone variation:`,
      temperature: 0.7,
      maxTokens: 1000
    },

    cta_variation: {
      name: 'cta_variation',
      description: 'Generate variants with different calls-to-action and conversion strategies',
      prompt: `Create a CTA variation of this content by changing the call-to-action approach and conversion strategy.
      
      CTA variations might include:
      - Direct vs soft ask
      - Single vs multiple CTAs
      - Action-oriented vs information-oriented
      - Urgency-based vs value-based
      - Different action types (subscribe, buy, learn, download, etc.)
      
      Original content: {{content}}
      Content type: {{contentType}}
      Business goal: {{businessGoal}}
      
      CTA variation:`,
      temperature: 0.7,
      maxTokens: 1000
    }
  }

  /**
   * Generate multiple content variants using different strategies
   */
  static async generateEnhancedVariants(
    originalContent: string,
    contentType: ContentTypeValue,
    variantCount: number,
    brandContext: string,
    options: {
      strategies?: Array<'style_variation' | 'length_variation' | 'angle_variation' | 'tone_variation' | 'cta_variation'>
      currentTone?: ToneOptionValue
      businessGoal?: string
      targetAudience?: string
    } = {}
  ): Promise<ContentVariant[]> {
    if (variantCount <= 1) return []

    const {
      strategies = ['style_variation', 'angle_variation', 'tone_variation'],
      currentTone = 'professional',
      businessGoal = 'engagement',
      targetAudience = 'general audience'
    } = options

    const variants: ContentVariant[] = []
    const strategyList = strategies.slice(0, variantCount - 1) // -1 because original is variant 0

    try {
      // Generate variants using different strategies
      for (let i = 0; i < Math.min(strategyList.length, variantCount - 1); i++) {
        const strategyName = strategyList[i % strategyList.length]
        const strategy = this.variantStrategies[strategyName]
        
        if (!strategy) {
          console.warn(`Strategy ${strategyName} not found, skipping...`)
          continue
        }

        // Customize prompt based on strategy
        let customizedPrompt = strategy.prompt
          .replace('{{content}}', originalContent)
          .replace('{{contentType}}', contentType.toLowerCase().replace('_', ' '))
          .replace('{{brandContext}}', brandContext)
          .replace('{{currentTone}}', currentTone)
          .replace('{{brandVoice}}', brandContext)
          .replace('{{businessGoal}}', businessGoal)

        // Special handling for length variations
        if (strategyName === 'length_variation') {
          const lengthInstructions = [
            'Create a shorter, more concise version (50-70% of original length)',
            'Create a longer, more detailed version (120-150% of original length)',
            'Create an ultra-concise version (30-50% of original length)'
          ]
          const lengthInstruction = lengthInstructions[i % lengthInstructions.length]
          customizedPrompt = customizedPrompt.replace(/{{lengthInstruction}}/g, lengthInstruction)
        }

        // Generate variant using OpenAI
        const result = await openAIService.instance.generateText({
          prompt: customizedPrompt,
          maxTokens: strategy.maxTokens || 1000,
          temperature: strategy.temperature
        })

        const variantContent = result.text.trim()
        
        // Calculate metrics for the variant
        const metrics = await this.calculateVariantMetrics(variantContent, contentType, originalContent)
        const formatOptimizations = this.analyzeFormatOptimization(variantContent, contentType)

        variants.push({
          id: `variant_${i + 2}`, // Start from 2 since original is 1
          content: variantContent,
          strategy: strategyName,
          metrics,
          formatOptimizations
        })
      }

      // If we need more variants, generate additional ones using random strategies
      while (variants.length < variantCount - 1) {
        const randomStrategy = strategyList[Math.floor(Math.random() * strategyList.length)]
        const strategy = this.variantStrategies[randomStrategy]
        
        const customizedPrompt = strategy.prompt
          .replace('{{content}}', originalContent)
          .replace('{{contentType}}', contentType.toLowerCase().replace('_', ' '))
          .replace('{{brandContext}}', brandContext)
          .replace('{{currentTone}}', currentTone)
          .replace('{{brandVoice}}', brandContext)
          .replace('{{businessGoal}}', businessGoal)

        const result = await openAIService.instance.generateText({
          prompt: customizedPrompt + ` (Alternative version ${variants.length + 2})`,
          maxTokens: strategy.maxTokens || 1000,
          temperature: Math.min(1.0, strategy.temperature + 0.1) // Slightly higher temperature for more variety
        })

        const variantContent = result.text.trim()
        const metrics = await this.calculateVariantMetrics(variantContent, contentType, originalContent)
        const formatOptimizations = this.analyzeFormatOptimization(variantContent, contentType)

        variants.push({
          id: `variant_${variants.length + 2}`,
          content: variantContent,
          strategy: randomStrategy,
          metrics,
          formatOptimizations
        })
      }

      return variants

    } catch (error) {
      console.error('Enhanced variant generation failed:', error)
      return []
    }
  }

  /**
   * Calculate comprehensive metrics for a content variant
   */
  private static async calculateVariantMetrics(
    variantContent: string,
    contentType: ContentTypeValue,
    originalContent: string
  ): Promise<{
    estimatedEngagement: number
    readabilityScore: number
    brandAlignment: number
    formatOptimization: number
  }> {
    const metrics = {
      estimatedEngagement: 0,
      readabilityScore: 0,
      brandAlignment: 70, // Default moderate alignment
      formatOptimization: 0
    }

    try {
      // Calculate readability score using simplified Flesch Reading Ease
      const sentences = variantContent.split(/[.!?]+/).filter(s => s.trim()).length || 1
      const words = variantContent.match(/\b\w+\b/g) || []
      const syllables = words.reduce((acc, word) => {
        const vowelMatches = word.match(/[aeiouy]/g)
        return acc + Math.max(1, vowelMatches ? vowelMatches.length : 1)
      }, 0)
      
      metrics.readabilityScore = Math.max(0, Math.min(100, 
        206.835 - (1.015 * (words.length / sentences)) - (84.6 * (syllables / words.length))
      ))

      // Calculate format optimization based on content type requirements
      const template = this.formatTemplates[contentType]
      const charCount = variantContent.length
      const wordCount = words.length

      // Check length optimization
      const lengthScore = this.calculateLengthScore(charCount, wordCount, template.optimizations)
      
      // Check required elements
      const elementScore = this.calculateElementScore(variantContent, template.optimizations.requiredElements)
      
      // Overall format optimization score
      metrics.formatOptimization = Math.round((lengthScore + elementScore) / 2)

      // Estimate engagement based on content characteristics
      metrics.estimatedEngagement = this.estimateEngagement(variantContent, contentType)

      return metrics

    } catch (error) {
      console.warn('Metrics calculation failed:', error)
      return metrics
    }
  }

  /**
   * Calculate length optimization score
   */
  private static calculateLengthScore(charCount: number, wordCount: number, optimizations: any): number {
    const { maxCharacters, maxWords } = optimizations
    
    const charScore = charCount <= maxCharacters ? 100 : Math.max(0, 100 - ((charCount - maxCharacters) / maxCharacters * 50))
    const wordScore = wordCount <= maxWords ? 100 : Math.max(0, 100 - ((wordCount - maxWords) / maxWords * 50))
    
    return Math.round((charScore + wordScore) / 2)
  }

  /**
   * Calculate required elements score
   */
  private static calculateElementScore(content: string, requiredElements: string[]): number {
    if (!requiredElements.length) return 100

    const contentLower = content.toLowerCase()
    let score = 0
    
    for (const element of requiredElements) {
      switch (element) {
        case 'clear_cta':
        case 'compelling_cta':
        case 'strong_cta':
          if (/\b(click|buy|purchase|subscribe|sign up|learn more|get started|contact|download|try|shop|order|register)\b/i.test(content)) {
            score += 100 / requiredElements.length
          }
          break
        case 'hashtags':
          if (content.includes('#')) {
            score += 100 / requiredElements.length
          }
          break
        case 'personalization':
          if (/\b(you|your|yours)\b/i.test(content)) {
            score += 100 / requiredElements.length
          }
          break
        case 'engaging_hook':
        case 'attention_hook':
          if (/^[^a-z]*[A-Z][^.!?]*[!?]/.test(content) || /^[^a-z]*(?:Did you know|Imagine|What if|Here's|Discover)/i.test(content)) {
            score += 100 / requiredElements.length
          }
          break
        default:
          // Generic check for element keywords in content
          if (contentLower.includes(element.toLowerCase().replace('_', ' '))) {
            score += 100 / requiredElements.length
          }
      }
    }
    
    return Math.round(score)
  }

  /**
   * Estimate engagement potential based on content characteristics
   */
  private static estimateEngagement(content: string, contentType: ContentTypeValue): number {
    let score = 50 // Base score
    
    const contentLower = content.toLowerCase()
    
    // Positive indicators
    if (/[!?]/.test(content)) score += 10 // Excitement/questions
    if (/\b(you|your|yours)\b/i.test(content)) score += 15 // Personalization
    if (/\b(free|save|discount|limited|exclusive|new)\b/i.test(content)) score += 10 // Value words
    if (content.includes('#')) score += 5 // Hashtags (for social)
    if (/\b(discover|learn|find out|revealed|secret)\b/i.test(content)) score += 8 // Curiosity
    
    // Content type specific bonuses
    switch (contentType) {
      case ContentType.SOCIAL_POST:
        if (content.length <= 140) score += 10 // Optimal length
        if (/^[^a-z]*(?:Did you know|What if|Pro tip)/i.test(content)) score += 12 // Good hooks
        break
      case ContentType.EMAIL:
        if (/Subject:/i.test(content)) score += 8 // Has subject line
        if (content.includes('Hi ') || content.includes('Hello ')) score += 5 // Personal greeting
        break
      case ContentType.BLOG_POST:
        if (content.includes('#') && content.includes('##')) score += 8 // Good structure
        if (content.split('\n').length > 5) score += 5 // Multiple sections
        break
    }
    
    // Penalties
    if (content.length < 20) score -= 20 // Too short
    if (!/[.!?]$/.test(content.trim())) score -= 5 // No proper ending
    if ((content.match(/\b(and|the|of|to|in|for)\b/g) || []).length / content.split(/\s+/).length > 0.3) {
      score -= 8 // Too many filler words
    }
    
    return Math.max(0, Math.min(100, Math.round(score)))
  }

  /**
   * Analyze format-specific optimizations
   */
  private static analyzeFormatOptimization(content: string, contentType: ContentTypeValue): {
    platform?: string
    characterCount: number
    wordCount: number
    hasHashtags?: boolean
    hasCTA?: boolean
    keywordDensity: Record<string, number>
  } {
    const words = content.match(/\b\w+\b/g) || []
    const wordFreq = new Map<string, number>()
    
    words.forEach(word => {
      if (word.length > 3) {
        const lowerWord = word.toLowerCase()
        wordFreq.set(lowerWord, (wordFreq.get(lowerWord) || 0) + 1)
      }
    })

    const keywordDensity: Record<string, number> = {}
    wordFreq.forEach((count, word) => {
      const density = (count / words.length) * 100
      if (density > 1) {
        keywordDensity[word] = Math.round(density * 100) / 100
      }
    })

    const template = this.formatTemplates[contentType]
    const platform = template.optimizations.platforms?.[0]

    return {
      platform,
      characterCount: content.length,
      wordCount: words.length,
      hasHashtags: content.includes('#'),
      hasCTA: /\b(click|buy|purchase|subscribe|sign up|learn more|get started|contact|download|try)\b/i.test(content),
      keywordDensity
    }
  }

  /**
   * Get format template for a specific content type
   */
  static getFormatTemplate(contentType: ContentTypeValue): ContentFormatTemplate {
    return this.formatTemplates[contentType]
  }

  /**
   * Get all available variant strategies
   */
  static getVariantStrategies(): Record<string, VariantStrategy> {
    return this.variantStrategies
  }

  /**
   * Generate template-based content using format-specific templates
   */
  static async generateTemplatedContent(
    contentType: ContentTypeValue,
    prompt: string,
    brandContext: string,
    templateVars: Record<string, string> = {}
  ): Promise<string> {
    const template = this.formatTemplates[contentType]
    
    const templatePrompt = `Generate ${contentType.toLowerCase().replace('_', ' ')} content following this template structure:

TEMPLATE:
${template.template}

REQUIREMENTS:
- Max characters: ${template.optimizations.maxCharacters}
- Max words: ${template.optimizations.maxWords}
- Required elements: ${template.optimizations.requiredElements.join(', ')}
- Best practices: ${template.optimizations.bestPractices.join(', ')}

USER REQUEST: ${prompt}
BRAND CONTEXT: ${brandContext}

Generate content that fills the template appropriately while maintaining brand voice and meeting all requirements. Provide only the final content, not the template structure.`

    try {
      const result = await openAIService.instance.generateText({
        prompt: templatePrompt,
        maxTokens: Math.min(2000, Math.ceil(template.optimizations.maxCharacters / 2)),
        temperature: 0.7
      })

      return result.text.trim()
    } catch (error) {
      console.error('Template-based content generation failed:', error)
      throw error
    }
  }
}