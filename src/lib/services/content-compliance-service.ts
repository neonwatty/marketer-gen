import OpenAI from 'openai'
import { z } from 'zod'

import { openAIService } from '@/lib/services/openai-service'
import { BrandContext, ContentOptimizationSuggestion } from '@/lib/types/content-generation'

/**
 * Configuration for content compliance service
 */
export interface ContentComplianceConfig {
  openaiApiKey?: string
  enableModeration?: boolean
  enableBrandCompliance?: boolean
  strictMode?: boolean
  customRules?: ContentComplianceRule[]
}

/**
 * Custom compliance rule definition
 */
export interface ContentComplianceRule {
  id: string
  name: string
  description: string
  type: 'content' | 'format' | 'brand' | 'safety' | 'industry'
  severity: 'error' | 'warning' | 'info'
  industry?: string[]
  validator: (content: string, context?: BrandContext) => Promise<ComplianceViolation[]>
}

/**
 * Industry-specific compliance templates
 */
export interface IndustryComplianceTemplate {
  id: string
  name: string
  industry: string
  description: string
  rules: ContentComplianceRule[]
  restrictedTerms: string[]
  requiredDisclosures: string[]
  tonalGuidelines: {
    formality: number // 0-1
    enthusiasm: number // 0-1
    trustworthiness: number // 0-1
  }
}

/**
 * Compliance violation details
 */
export interface ComplianceViolation {
  ruleId: string
  severity: 'error' | 'warning' | 'info'
  message: string
  suggestion?: string
  location?: {
    start: number
    end: number
    text: string
  }
}

/**
 * Content moderation result from OpenAI
 */
export interface ModerationResult {
  flagged: boolean
  categories: {
    harassment: boolean
    'harassment-threatening': boolean
    hate: boolean
    'hate-threatening': boolean
    'self-harm': boolean
    'self-harm-instructions': boolean
    'self-harm-intent': boolean
    sexual: boolean
    'sexual-minors': boolean
    violence: boolean
    'violence-graphic': boolean
  }
  category_scores: {
    harassment: number
    'harassment-threatening': number
    hate: number
    'hate-threatening': number
    'self-harm': number
    'self-harm-instructions': number
    'self-harm-intent': number
    sexual: number
    'sexual-minors': number
    violence: number
    'violence-graphic': number
  }
}

/**
 * Comprehensive compliance check result
 */
export interface ComplianceCheckResult {
  isCompliant: boolean
  overallScore: number
  violations: ComplianceViolation[]
  suggestions: ContentOptimizationSuggestion[]
  moderationResult?: ModerationResult
  brandComplianceScore: number
  safetyScore: number
  metadata: {
    checkedAt: string
    rulesApplied: string[]
    processingTime: number
  }
}

/**
 * Request validation schemas
 */
const ContentComplianceRequestSchema = z.object({
  content: z.string().min(1, 'Content is required').max(10000, 'Content too long'),
  contentType: z.enum([
    'EMAIL', 'SOCIAL_POST', 'SOCIAL_AD', 'SEARCH_AD', 'BLOG_POST',
    'LANDING_PAGE', 'VIDEO_SCRIPT', 'INFOGRAPHIC', 'NEWSLETTER', 'PRESS_RELEASE'
  ]).optional(),
  brandContext: z.object({
    name: z.string(),
    restrictedTerms: z.array(z.string()).optional(),
    complianceRules: z.array(z.object({
      rule: z.string(),
      severity: z.enum(['error', 'warning']),
      description: z.string(),
    })).optional(),
    voiceDescription: z.string().optional().nullable(),
    communicationStyle: z.string().optional().nullable(),
    values: z.array(z.string()).optional(),
    messagingFramework: z.array(z.object({
      pillar: z.string(),
      description: z.string(),
      keywords: z.array(z.string()),
    })).optional(),
  }).optional(),
  options: z.object({
    checkModeration: z.boolean().default(true),
    checkBrandCompliance: z.boolean().default(true),
    strictMode: z.boolean().default(false),
    includeDetailedAnalysis: z.boolean().default(false),
  }).optional(),
})

export type ContentComplianceRequest = z.infer<typeof ContentComplianceRequestSchema>

/**
 * Content Compliance Service
 * Provides comprehensive content filtering and brand compliance checking
 */
export class ContentComplianceService {
  private openaiClient?: OpenAI
  private config: Required<ContentComplianceConfig>
  private customRules: Map<string, ContentComplianceRule> = new Map()
  private industryTemplates: Map<string, IndustryComplianceTemplate> = new Map()

  constructor(config: ContentComplianceConfig = {}) {
    this.config = {
      openaiApiKey: config.openaiApiKey || process.env.OPENAI_API_KEY || '',
      enableModeration: config.enableModeration ?? true,
      enableBrandCompliance: config.enableBrandCompliance ?? true,
      strictMode: config.strictMode ?? false,
      customRules: config.customRules || [],
    }

    if (this.config.openaiApiKey && this.config.enableModeration && process.env.NODE_ENV !== 'test') {
      this.openaiClient = new OpenAI({
        apiKey: this.config.openaiApiKey,
      })
    }

    // Initialize custom rules
    this.config.customRules.forEach(rule => {
      this.customRules.set(rule.id, rule)
    })

    // Add built-in rules
    this.initializeBuiltInRules()
    
    // Initialize industry templates
    this.initializeIndustryTemplates()
  }

  /**
   * Initialize built-in compliance rules
   */
  private initializeBuiltInRules(): void {
    const builtInRules: ContentComplianceRule[] = [
      {
        id: 'restricted-terms',
        name: 'Restricted Terms Check',
        description: 'Checks for brand-specific restricted terms',
        type: 'brand',
        severity: 'error',
        validator: this.checkRestrictedTerms.bind(this),
      },
      {
        id: 'brand-voice-alignment',
        name: 'Brand Voice Alignment',
        description: 'Validates content alignment with brand voice',
        type: 'brand',
        severity: 'warning',
        validator: this.checkBrandVoiceAlignment.bind(this),
      },
      {
        id: 'messaging-framework',
        name: 'Messaging Framework Compliance',
        description: 'Ensures content follows brand messaging framework',
        type: 'brand',
        severity: 'warning',
        validator: this.checkMessagingFramework.bind(this),
      },
      {
        id: 'content-length',
        name: 'Content Length Validation',
        description: 'Validates content length for the specified format',
        type: 'format',
        severity: 'warning',
        validator: this.checkContentLength.bind(this),
      },
      {
        id: 'professionalism',
        name: 'Professional Language Check',
        description: 'Ensures professional and appropriate language use',
        type: 'content',
        severity: 'warning',
        validator: this.checkProfessionalism.bind(this),
      },
    ]

    builtInRules.forEach(rule => {
      this.customRules.set(rule.id, rule)
    })
  }

  /**
   * Initialize industry-specific compliance templates
   */
  private initializeIndustryTemplates(): void {
    const industryTemplates: IndustryComplianceTemplate[] = [
      {
        id: 'healthcare',
        name: 'Healthcare & Medical',
        industry: 'healthcare',
        description: 'Compliance rules for healthcare and medical content',
        restrictedTerms: ['cure', 'guaranteed', 'miracle', 'instant healing', 'medical breakthrough'],
        requiredDisclosures: ['This content is for informational purposes only', 'Consult your healthcare provider'],
        tonalGuidelines: {
          formality: 0.8,
          enthusiasm: 0.4,
          trustworthiness: 0.9
        },
        rules: [
          {
            id: 'healthcare-claims',
            name: 'Healthcare Claims Validation',
            description: 'Validates medical claims and disclaimers',
            type: 'industry',
            severity: 'error',
            industry: ['healthcare'],
            validator: this.validateHealthcareClaims.bind(this)
          },
          {
            id: 'medical-disclaimer',
            name: 'Medical Disclaimer Requirement',
            description: 'Ensures medical disclaimer is present',
            type: 'industry',
            severity: 'warning',
            industry: ['healthcare'],
            validator: this.checkMedicalDisclaimer.bind(this)
          }
        ]
      },
      {
        id: 'financial',
        name: 'Financial Services',
        industry: 'financial',
        description: 'Compliance rules for financial services content',
        restrictedTerms: ['guaranteed returns', 'risk-free', 'get rich quick', 'insider information'],
        requiredDisclosures: ['Past performance does not guarantee future results', 'Investment involves risk'],
        tonalGuidelines: {
          formality: 0.9,
          enthusiasm: 0.3,
          trustworthiness: 1.0
        },
        rules: [
          {
            id: 'financial-disclaimers',
            name: 'Financial Disclaimers',
            description: 'Ensures proper financial disclaimers',
            type: 'industry',
            severity: 'error',
            industry: ['financial'],
            validator: this.validateFinancialDisclaimer.bind(this)
          },
          {
            id: 'investment-risks',
            name: 'Investment Risk Disclosure',
            description: 'Validates investment risk statements',
            type: 'industry',
            severity: 'warning',
            industry: ['financial'],
            validator: this.checkInvestmentRisks.bind(this)
          }
        ]
      },
      {
        id: 'pharmaceutical',
        name: 'Pharmaceutical',
        industry: 'pharmaceutical',
        description: 'Compliance rules for pharmaceutical content',
        restrictedTerms: ['cure', 'treat', 'diagnose', 'prevent disease'],
        requiredDisclosures: ['For educational purposes only', 'Consult your physician'],
        tonalGuidelines: {
          formality: 0.9,
          enthusiasm: 0.2,
          trustworthiness: 1.0
        },
        rules: [
          {
            id: 'pharma-claims',
            name: 'Pharmaceutical Claims',
            description: 'Validates pharmaceutical claims and safety',
            type: 'industry',
            severity: 'error',
            industry: ['pharmaceutical'],
            validator: this.validatePharmaceuticalClaims.bind(this)
          }
        ]
      },
      {
        id: 'legal',
        name: 'Legal Services',
        industry: 'legal',
        description: 'Compliance rules for legal services content',
        restrictedTerms: ['guaranteed outcome', 'we will win', 'sure victory'],
        requiredDisclosures: ['This is not legal advice', 'Results may vary'],
        tonalGuidelines: {
          formality: 1.0,
          enthusiasm: 0.2,
          trustworthiness: 0.9
        },
        rules: [
          {
            id: 'legal-disclaimers',
            name: 'Legal Service Disclaimers',
            description: 'Ensures proper legal disclaimers',
            type: 'industry',
            severity: 'error',
            industry: ['legal'],
            validator: this.validateLegalDisclaimer.bind(this)
          }
        ]
      }
    ]

    // Add industry-specific rules to custom rules
    industryTemplates.forEach(template => {
      this.industryTemplates.set(template.id, template)
      template.rules.forEach(rule => {
        this.customRules.set(rule.id, rule)
      })
    })
  }

  /**
   * Perform comprehensive compliance check on content
   */
  async checkCompliance(request: ContentComplianceRequest): Promise<ComplianceCheckResult> {
    const startTime = Date.now()
    
    // Validate request
    const validatedRequest = ContentComplianceRequestSchema.parse(request)
    const { content, brandContext, options } = validatedRequest
    
    // Ensure options has default values
    const complianceOptions = {
      checkModeration: true,
      checkBrandCompliance: true,
      strictMode: false,
      includeDetailedAnalysis: false,
      ...options
    }

    const violations: ComplianceViolation[] = []
    const suggestions: ContentOptimizationSuggestion[] = []
    const rulesApplied: string[] = []
    
    let moderationResult: ModerationResult | undefined
    let safetyScore = 100
    let brandComplianceScore = 100

    // Filter out null values to match BrandContext interface
    const cleanBrandContext: BrandContext | undefined = brandContext ? {
      ...brandContext,
      voiceDescription: brandContext.voiceDescription || undefined,
      communicationStyle: brandContext.communicationStyle || undefined,
    } : undefined

    try {
      // 1. OpenAI Moderation API Check (highest priority)
      if (this.config.enableModeration && complianceOptions.checkModeration && this.openaiClient) {
        try {
          moderationResult = await this.performModerationCheck(content)
          
          if (moderationResult.flagged) {
            const flaggedCategories = Object.entries(moderationResult.categories)
              .filter(([_, flagged]) => flagged)
              .map(([category]) => category)

            violations.push({
              ruleId: 'openai-moderation',
              severity: 'error',
              message: `Content flagged by safety filters: ${flaggedCategories.join(', ')}`,
              suggestion: 'Remove or rephrase potentially harmful content',
            })

            // Calculate safety score based on category scores
            const maxScore = Math.max(...Object.values(moderationResult.category_scores))
            safetyScore = Math.max(0, 100 - (maxScore * 100))
          }
          
          rulesApplied.push('openai-moderation')
        } catch (error) {
          console.warn('Moderation API check failed:', error)
          violations.push({
            ruleId: 'moderation-error',
            severity: 'warning',
            message: 'Could not verify content safety - moderation service unavailable',
            suggestion: 'Manually review content for safety compliance',
          })
        }
      }

      // 2. Brand Compliance Checks
      if (this.config.enableBrandCompliance && complianceOptions.checkBrandCompliance && cleanBrandContext) {
        for (const [ruleId, rule] of this.customRules) {
          if (rule.type === 'brand' || rule.type === 'content') {
            try {
              const ruleViolations = await rule.validator(content, cleanBrandContext)
              violations.push(...ruleViolations)
              rulesApplied.push(ruleId)
            } catch (error) {
              console.warn(`Rule ${ruleId} failed:`, error)
            }
          }
        }
      }

      // 2.1. Industry-Specific Compliance Checks
      for (const [ruleId, rule] of this.customRules) {
        if (rule.type === 'industry') {
          try {
            const ruleViolations = await rule.validator(content, cleanBrandContext)
            violations.push(...ruleViolations)
            rulesApplied.push(ruleId)
          } catch (error) {
            console.warn(`Industry rule ${ruleId} failed:`, error)
          }
        }
      }

      // 3. Format and Structure Checks
      for (const [ruleId, rule] of this.customRules) {
        if (rule.type === 'format') {
          try {
            const ruleViolations = await rule.validator(content, cleanBrandContext)
            violations.push(...ruleViolations)
            rulesApplied.push(ruleId)
          } catch (error) {
            console.warn(`Rule ${ruleId} failed:`, error)
          }
        }
      }

      // Calculate brand compliance score
      const brandViolations = violations.filter(v => 
        v.ruleId.includes('brand') || v.ruleId.includes('messaging') || v.ruleId.includes('voice')
      )
      const errorPenalty = brandViolations.filter(v => v.severity === 'error').length * 30
      const warningPenalty = brandViolations.filter(v => v.severity === 'warning').length * 15
      brandComplianceScore = Math.max(0, 100 - errorPenalty - warningPenalty)

      // Generate suggestions based on violations
      violations.forEach(violation => {
        if (violation.suggestion) {
          suggestions.push({
            type: this.mapViolationToSuggestionType(violation.ruleId),
            priority: violation.severity === 'error' ? 'high' : violation.severity === 'warning' ? 'medium' : 'low',
            suggestion: violation.suggestion,
            reason: violation.message,
          })
        }
      })

      // Calculate overall score
      const errorCount = violations.filter(v => v.severity === 'error').length
      const warningCount = violations.filter(v => v.severity === 'warning').length
      const overallScore = Math.max(0, 100 - (errorCount * 25) - (warningCount * 10))

      // Determine compliance status
      const isCompliant = this.config.strictMode 
        ? violations.length === 0
        : violations.filter(v => v.severity === 'error').length === 0

      return {
        isCompliant,
        overallScore,
        violations,
        suggestions,
        moderationResult,
        brandComplianceScore,
        safetyScore,
        metadata: {
          checkedAt: new Date().toISOString(),
          rulesApplied,
          processingTime: Date.now() - startTime,
        },
      }

    } catch (error) {
      console.error('Compliance check failed:', error)
      throw new Error(`Compliance check failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
    }
  }

  /**
   * Perform OpenAI moderation check
   */
  private async performModerationCheck(content: string): Promise<ModerationResult> {
    if (!this.openaiClient) {
      throw new Error('OpenAI client not initialized')
    }

    const response = await this.openaiClient.moderations.create({
      input: content,
      model: 'text-moderation-latest'
    })

    const result = response.results[0]
    return {
      flagged: result.flagged,
      categories: result.categories as any,
      category_scores: result.category_scores as any,
    }
  }

  /**
   * Check for restricted terms
   */
  private async checkRestrictedTerms(content: string, brandContext?: BrandContext): Promise<ComplianceViolation[]> {
    if (!brandContext?.restrictedTerms) return []

    const violations: ComplianceViolation[] = []
    const contentLower = content.toLowerCase()

    for (const term of brandContext.restrictedTerms) {
      const index = contentLower.indexOf(term.toLowerCase())
      if (index !== -1) {
        violations.push({
          ruleId: 'restricted-terms',
          severity: 'error',
          message: `Contains restricted term: "${term}"`,
          suggestion: `Replace "${term}" with an approved alternative`,
          location: {
            start: index,
            end: index + term.length,
            text: content.substring(index, index + term.length),
          },
        })
      }
    }

    return violations
  }

  /**
   * Check brand voice alignment with enhanced AI-powered analysis
   */
  private async checkBrandVoiceAlignment(content: string, brandContext?: BrandContext): Promise<ComplianceViolation[]> {
    if (!brandContext?.voiceDescription) return []

    const violations: ComplianceViolation[] = []
    
    // Enhanced multi-dimensional brand voice analysis
    const voiceScore = await this.calculateBrandVoiceScore(content, brandContext)
    
    if (voiceScore < 40) {
      violations.push({
        ruleId: 'brand-voice-alignment',
        severity: voiceScore < 25 ? 'error' : 'warning',
        message: `Brand voice alignment score is low (${voiceScore}/100)`,
        suggestion: `Adjust content to better match brand voice characteristics: ${brandContext.voiceDescription}`,
      })
    }

    // Check for tone consistency
    const toneViolations = await this.checkToneConsistency(content, brandContext)
    violations.push(...toneViolations)

    // Check communication style adherence
    const styleViolations = await this.checkCommunicationStyle(content, brandContext)
    violations.push(...styleViolations)

    return violations
  }

  /**
   * Calculate comprehensive brand voice alignment score using AI
   */
  private async calculateBrandVoiceScore(content: string, brandContext: BrandContext): Promise<number> {
    try {
      // Use AI-powered analysis for more sophisticated brand voice scoring
      const aiScore = await this.getAIBrandVoiceScore(content, brandContext)
      if (aiScore !== null) {
        return aiScore
      }
    } catch (error) {
      console.warn('AI brand voice analysis failed, falling back to rule-based scoring:', error)
    }

    // Fallback to rule-based scoring - start with a more lenient base score
    let score = 85 // Start with 85 instead of 100 to be more realistic
    const scores = []
    const contentLower = content.toLowerCase()
    const words = contentLower.split(/\s+/)
    
    // Analyze voice characteristics
    if (brandContext.voiceDescription) {
      const voiceKeywords = this.extractVoiceCharacteristics(brandContext.voiceDescription)
      const alignmentScore = this.calculateSemanticSimilarity(content, brandContext.voiceDescription)
      scores.push(alignmentScore)
    }
    
    // Check communication style adherence
    if (brandContext.communicationStyle) {
      const styleScore = this.analyzeStyleAlignment(content, brandContext.communicationStyle)
      scores.push(styleScore)
    }
    
    // Analyze tone attributes if present
    if (brandContext.toneAttributes) {
      const toneScore = this.analyzeToneAttributes(content, brandContext.toneAttributes)
      scores.push(toneScore)
    }
    
    // Use average instead of minimum to be more lenient
    if (scores.length > 0) {
      const avgScore = scores.reduce((sum, s) => sum + s, 0) / scores.length
      score = Math.round((score + avgScore) / 2) // Blend base score with average
    }
    
    return Math.max(0, Math.min(100, score))
  }

  /**
   * AI-powered brand voice analysis
   */
  private async getAIBrandVoiceScore(content: string, brandContext: BrandContext): Promise<number | null> {
    if (!openAIService.instance.isReady()) {
      return null
    }

    const analysisPrompt = `
You are an expert brand voice analyst. Analyze the following content against the brand characteristics and provide a detailed scoring.

BRAND CONTEXT:
Brand Name: ${brandContext.name || 'Unknown'}
Voice Description: ${brandContext.voiceDescription || 'Not specified'}
Communication Style: ${brandContext.communicationStyle || 'Not specified'}
Values: ${JSON.stringify(brandContext.values || [])}
Target Audience: ${JSON.stringify(brandContext.targetAudience || {})}

CONTENT TO ANALYZE:
"${content}"

Please analyze the content and provide scores for each dimension (0-100):

1. VOICE_ALIGNMENT: How well does the content match the described brand voice?
2. STYLE_CONSISTENCY: How consistent is the writing style with brand communication style?
3. VALUE_REFLECTION: How well does the content reflect the brand values?
4. AUDIENCE_APPROPRIATENESS: How appropriate is the content for the target audience?
5. AUTHENTICITY: How authentic does the content sound for this brand?

Respond in this exact format:
VOICE_ALIGNMENT: [0-100]
STYLE_CONSISTENCY: [0-100]
VALUE_REFLECTION: [0-100]  
AUDIENCE_APPROPRIATENESS: [0-100]
AUTHENTICITY: [0-100]
OVERALL_SCORE: [0-100]
REASONING: [Brief explanation of the scoring]
    `.trim()

    try {
      const response = await openAIService.instance.generateText({
        prompt: analysisPrompt,
        maxTokens: 500,
        temperature: 0.2
      })

      return this.parseAIBrandScore(response.text)
    } catch (error) {
      console.error('AI brand voice scoring failed:', error)
      return null
    }
  }

  /**
   * Parse AI brand voice score response
   */
  private parseAIBrandScore(response: string): number {
    const overallMatch = response.match(/OVERALL_SCORE:\s*(\d+)/i)
    if (overallMatch) {
      return parseInt(overallMatch[1])
    }

    // Fallback: calculate average from individual scores
    const scoreMatches = [
      response.match(/VOICE_ALIGNMENT:\s*(\d+)/i),
      response.match(/STYLE_CONSISTENCY:\s*(\d+)/i),
      response.match(/VALUE_REFLECTION:\s*(\d+)/i),
      response.match(/AUDIENCE_APPROPRIATENESS:\s*(\d+)/i),
      response.match(/AUTHENTICITY:\s*(\d+)/i)
    ]

    const scores = scoreMatches
      .filter(match => match !== null)
      .map(match => parseInt(match![1]))

    if (scores.length > 0) {
      return Math.round(scores.reduce((sum, score) => sum + score, 0) / scores.length)
    }

    return 70 // Default fallback score
  }

  /**
   * Check tone consistency throughout content
   */
  private async checkToneConsistency(content: string, brandContext: BrandContext): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    
    if (!brandContext.toneAttributes) return violations
    
    // Analyze sentence-level tone variations
    const sentences = content.split(/[.!?]+/).filter(s => s.trim().length > 10)
    
    if (sentences.length > 2) {
      const toneVariations = this.analyzeToneVariations(sentences)
      
      if (toneVariations.inconsistencyScore > 0.85) {
        violations.push({
          ruleId: 'tone-consistency',
          severity: 'warning',
          message: 'Tone inconsistency detected across content sections',
          suggestion: 'Maintain consistent tone throughout the content',
        })
      }
    }
    
    return violations
  }

  /**
   * Check communication style adherence
   */
  private async checkCommunicationStyle(content: string, brandContext: BrandContext): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    
    if (!brandContext.communicationStyle) return violations
    
    const styleScore = this.analyzeStyleAlignment(content, brandContext.communicationStyle)
    
    if (styleScore < 30) {
      violations.push({
        ruleId: 'communication-style',
        severity: 'warning',
        message: `Communication style alignment is low (${styleScore}/100)`,
        suggestion: `Adjust language and structure to match brand communication style: ${brandContext.communicationStyle}`,
      })
    }
    
    return violations
  }

  /**
   * Check messaging framework compliance
   */
  private async checkMessagingFramework(content: string, brandContext?: BrandContext): Promise<ComplianceViolation[]> {
    if (!brandContext?.messagingFramework || brandContext.messagingFramework.length === 0) return []

    const violations: ComplianceViolation[] = []
    const contentLower = content.toLowerCase()
    
    let hasFrameworkAlignment = false
    
    for (const pillar of brandContext.messagingFramework) {
      const keywords = pillar.keywords || []
      const hasKeywords = keywords.some(keyword => contentLower.includes(keyword.toLowerCase()))
      
      if (hasKeywords) {
        hasFrameworkAlignment = true
        break
      }
    }

    if (!hasFrameworkAlignment) {
      violations.push({
        ruleId: 'messaging-framework',
        severity: 'warning',
        message: 'Content does not incorporate brand messaging framework',
        suggestion: 'Include key messaging pillars and keywords from brand framework',
      })
    }

    return violations
  }

  /**
   * Check content length appropriateness
   */
  private async checkContentLength(content: string): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    const length = content.length
    
    if (length < 10) {
      violations.push({
        ruleId: 'content-length',
        severity: 'error',
        message: 'Content is too short to be meaningful',
        suggestion: 'Expand content to provide more value',
      })
    } else if (length > 5000) {
      violations.push({
        ruleId: 'content-length',
        severity: 'warning',
        message: 'Content may be too long for optimal engagement',
        suggestion: 'Consider breaking into smaller sections or reducing length',
      })
    }

    return violations
  }

  /**
   * Check for professional language use
   */
  private async checkProfessionalism(content: string): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    
    // Check for common unprofessional patterns
    const unprofessionalPatterns = [
      /\b(omg|wtf|lol|lmao)\b/gi,
      /[!]{3,}/g,
      /[?]{3,}/g,
      /\b(gonna|wanna|gotta)\b/gi,
    ]

    for (const pattern of unprofessionalPatterns) {
      const matches = content.match(pattern)
      if (matches) {
        violations.push({
          ruleId: 'professionalism',
          severity: 'warning',
          message: `Potentially unprofessional language detected: ${matches.join(', ')}`,
          suggestion: 'Use more professional language alternatives',
        })
      }
    }

    return violations
  }

  /**
   * Calculate text similarity (simplified)
   */
  private calculateTextSimilarity(words1: string[], words2: string[]): number {
    const set1 = new Set(words1)
    const set2 = new Set(words2)
    const intersection = new Set([...set1].filter(x => set2.has(x)))
    const union = new Set([...set1, ...set2])
    
    return intersection.size / union.size
  }

  /**
   * Extract voice characteristics from brand voice description
   */
  private extractVoiceCharacteristics(voiceDescription: string): string[] {
    // Extract key descriptive words and phrases from voice description
    const words = voiceDescription.toLowerCase()
      .replace(/[^a-zA-Z\s]/g, ' ')
      .split(/\s+/)
      .filter(word => word.length > 2)
      .filter(word => !['the', 'and', 'but', 'for', 'with', 'this', 'that', 'are', 'was'].includes(word))
    
    return [...new Set(words)]
  }

  /**
   * Calculate semantic similarity between content and brand voice
   */
  private calculateSemanticSimilarity(content: string, voiceDescription: string): number {
    const contentWords = content.toLowerCase().split(/\s+/)
    const voiceWords = voiceDescription.toLowerCase().split(/\s+/)
    
    // Enhanced similarity calculation with word frequency and context
    const contentWordMap = new Map<string, number>()
    const voiceWordMap = new Map<string, number>()
    
    contentWords.forEach(word => {
      contentWordMap.set(word, (contentWordMap.get(word) || 0) + 1)
    })
    
    voiceWords.forEach(word => {
      voiceWordMap.set(word, (voiceWordMap.get(word) || 0) + 1)
    })
    
    let similarityScore = 0
    let totalWords = 0
    
    for (const [word, freq] of contentWordMap) {
      totalWords += freq
      if (voiceWordMap.has(word)) {
        similarityScore += freq * Math.min(voiceWordMap.get(word)! / voiceWords.length, 1)
      }
    }
    
    return totalWords > 0 ? Math.min(100, (similarityScore / totalWords) * 500) : 0
  }

  /**
   * Analyze style alignment with brand communication style
   */
  private analyzeStyleAlignment(content: string, communicationStyle: string): number {
    const styleMetrics = this.extractStyleMetrics(content)
    const targetStyleMetrics = this.parseStyleRequirements(communicationStyle)
    
    let alignmentScore = 100
    
    // Check sentence length alignment
    if (targetStyleMetrics.preferredSentenceLength) {
      const lengthDifference = Math.abs(styleMetrics.averageSentenceLength - targetStyleMetrics.preferredSentenceLength)
      alignmentScore -= Math.min(30, lengthDifference * 2)
    }
    
    // Check formality level
    if (targetStyleMetrics.formalityLevel) {
      const formalityDifference = Math.abs(styleMetrics.formalityScore - targetStyleMetrics.formalityLevel)
      alignmentScore -= Math.min(25, formalityDifference * 25)
    }
    
    // Check vocabulary complexity
    if (targetStyleMetrics.complexityLevel) {
      const complexityDifference = Math.abs(styleMetrics.vocabularyComplexity - targetStyleMetrics.complexityLevel)
      alignmentScore -= Math.min(20, complexityDifference * 20)
    }
    
    return Math.max(0, Math.round(alignmentScore))
  }

  /**
   * Analyze tone attributes alignment
   */
  private analyzeToneAttributes(content: string, toneAttributes: Record<string, any>): number {
    let score = 100
    const contentMetrics = this.analyzeToneMetrics(content)
    
    // Check for specific tone indicators
    Object.entries(toneAttributes).forEach(([attribute, targetValue]) => {
      const actualValue = contentMetrics[attribute] || 0
      if (typeof targetValue === 'number') {
        const difference = Math.abs(actualValue - targetValue)
        score -= Math.min(15, difference * 15)
      }
    })
    
    return Math.max(0, Math.round(score))
  }

  /**
   * Analyze tone variations across sentences
   */
  private analyzeToneVariations(sentences: string[]): { inconsistencyScore: number } {
    if (sentences.length < 2) return { inconsistencyScore: 0 }
    
    const sentenceTones = sentences.map(sentence => this.analyzeToneMetrics(sentence))
    
    // Calculate variance in tone metrics
    let totalVariance = 0
    const metrics = ['enthusiasm', 'formality', 'friendliness']
    
    metrics.forEach(metric => {
      const values = sentenceTones.map(tone => tone[metric] || 0)
      const avg = values.reduce((sum, val) => sum + val, 0) / values.length
      const variance = values.reduce((sum, val) => sum + Math.pow(val - avg, 2), 0) / values.length
      totalVariance += variance
    })
    
    return { inconsistencyScore: Math.min(1, totalVariance / metrics.length) }
  }

  /**
   * Extract style metrics from content
   */
  private extractStyleMetrics(content: string): {
    averageSentenceLength: number
    formalityScore: number
    vocabularyComplexity: number
  } {
    const sentences = content.split(/[.!?]+/).filter(s => s.trim().length > 0)
    const words = content.split(/\s+/)
    
    const averageSentenceLength = sentences.length > 0 ? words.length / sentences.length : 0
    
    // Simple formality score based on certain indicators
    const formalWords = words.filter(word => word.length > 6).length
    const contractionsCount = (content.match(/\b\w+'[a-z]+\b/g) || []).length
    const formalityScore = (formalWords / words.length) - (contractionsCount / words.length * 2)
    
    // Vocabulary complexity based on average word length
    const averageWordLength = words.reduce((sum, word) => sum + word.length, 0) / words.length
    const vocabularyComplexity = Math.min(1, averageWordLength / 8)
    
    return {
      averageSentenceLength,
      formalityScore: Math.max(0, Math.min(1, formalityScore)),
      vocabularyComplexity
    }
  }

  /**
   * Parse style requirements from communication style description
   */
  private parseStyleRequirements(communicationStyle: string): {
    preferredSentenceLength?: number
    formalityLevel?: number
    complexityLevel?: number
  } {
    const styleUpper = communicationStyle.toUpperCase()
    
    const requirements: any = {}
    
    // Determine preferred sentence length
    if (styleUpper.includes('CONCISE') || styleUpper.includes('SHORT')) {
      requirements.preferredSentenceLength = 12
    } else if (styleUpper.includes('DETAILED') || styleUpper.includes('COMPREHENSIVE')) {
      requirements.preferredSentenceLength = 20
    } else {
      requirements.preferredSentenceLength = 16
    }
    
    // Determine formality level
    if (styleUpper.includes('FORMAL') || styleUpper.includes('PROFESSIONAL')) {
      requirements.formalityLevel = 0.7
    } else if (styleUpper.includes('CASUAL') || styleUpper.includes('INFORMAL')) {
      requirements.formalityLevel = 0.3
    } else {
      requirements.formalityLevel = 0.5
    }
    
    // Determine complexity level
    if (styleUpper.includes('SIMPLE') || styleUpper.includes('ACCESSIBLE')) {
      requirements.complexityLevel = 0.3
    } else if (styleUpper.includes('SOPHISTICATED') || styleUpper.includes('TECHNICAL')) {
      requirements.complexityLevel = 0.8
    } else {
      requirements.complexityLevel = 0.5
    }
    
    return requirements
  }

  /**
   * Analyze tone metrics for content
   */
  private analyzeToneMetrics(content: string): Record<string, number> {
    const words = content.toLowerCase().split(/\s+/)
    const contentLength = words.length
    
    // Enthusiasm indicators
    const enthusiasticWords = ['amazing', 'incredible', 'fantastic', 'excellent', 'outstanding', 'wonderful']
    const enthusiasmCount = words.filter(word => enthusiasticWords.some(ew => word.includes(ew))).length
    const enthusiasm = contentLength > 0 ? enthusiasmCount / contentLength : 0
    
    // Formality indicators
    const formalWords = ['furthermore', 'therefore', 'consequently', 'nonetheless', 'moreover']
    const informalWords = ['cool', 'awesome', 'yeah', 'okay', 'super']
    const formalCount = words.filter(word => formalWords.some(fw => word.includes(fw))).length
    const informalCount = words.filter(word => informalWords.some(iw => word.includes(iw))).length
    const formality = contentLength > 0 ? (formalCount - informalCount) / contentLength + 0.5 : 0.5
    
    // Friendliness indicators
    const friendlyWords = ['welcome', 'thank', 'please', 'appreciate', 'happy', 'enjoy']
    const friendlyCount = words.filter(word => friendlyWords.some(fw => word.includes(fw))).length
    const friendliness = contentLength > 0 ? friendlyCount / contentLength : 0
    
    return {
      enthusiasm: Math.max(0, Math.min(1, enthusiasm * 10)),
      formality: Math.max(0, Math.min(1, formality)),
      friendliness: Math.max(0, Math.min(1, friendliness * 5))
    }
  }

  /**
   * Map violation type to suggestion type
   */
  private mapViolationToSuggestionType(ruleId: string): ContentOptimizationSuggestion['type'] {
    if (ruleId.includes('brand') || ruleId.includes('voice') || ruleId.includes('messaging')) {
      return 'brand'
    }
    if (ruleId.includes('length')) {
      return 'length'
    }
    if (ruleId.includes('tone') || ruleId.includes('professional')) {
      return 'tone'
    }
    if (ruleId.includes('keyword')) {
      return 'keywords'
    }
    if (ruleId.includes('structure') || ruleId.includes('format')) {
      return 'structure'
    }
    return 'structure'
  }

  /**
   * Add custom compliance rule
   */
  addCustomRule(rule: ContentComplianceRule): void {
    this.customRules.set(rule.id, rule)
  }

  /**
   * Remove custom compliance rule
   */
  removeCustomRule(ruleId: string): boolean {
    return this.customRules.delete(ruleId)
  }

  /**
   * Get all active rules
   */
  getActiveRules(): ContentComplianceRule[] {
    return Array.from(this.customRules.values())
  }

  /**
   * Test service connectivity
   */
  async testConnection(): Promise<boolean> {
    try {
      if (this.openaiClient) {
        const response = await this.performModerationCheck('Test content')
        return typeof response.flagged === 'boolean'
      }
      return true
    } catch {
      return false
    }
  }

  /**
   * Get service configuration
   */
  getConfig(): Omit<ContentComplianceConfig, 'openaiApiKey'> & { hasApiKey: boolean } {
    return {
      enableModeration: this.config.enableModeration,
      enableBrandCompliance: this.config.enableBrandCompliance,
      strictMode: this.config.strictMode,
      customRules: this.config.customRules,
      hasApiKey: !!this.config.openaiApiKey,
    }
  }

  /**
   * Get available industry templates
   */
  getIndustryTemplates(): IndustryComplianceTemplate[] {
    return Array.from(this.industryTemplates.values())
  }

  /**
   * Apply industry template to brand context
   */
  applyIndustryTemplate(industry: string, brandContext: BrandContext): BrandContext {
    const template = this.industryTemplates.get(industry)
    if (!template) return brandContext

    return {
      ...brandContext,
      restrictedTerms: [
        ...(brandContext.restrictedTerms || []),
        ...template.restrictedTerms
      ],
      complianceRules: [
        ...(brandContext.complianceRules || []),
        ...template.requiredDisclosures.map(disclosure => ({
          rule: `Required disclosure: ${disclosure}`,
          severity: 'warning' as const,
          description: `Industry requirement for ${template.industry}`
        }))
      ]
    }
  }

  /**
   * Industry-specific validator methods
   */

  /**
   * Validate healthcare claims
   */
  private async validateHealthcareClaims(content: string): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    const contentLower = content.toLowerCase()
    
    const problematicClaims = [
      'cure', 'guaranteed', 'miracle', 'instant healing', 'medical breakthrough',
      'fda approved', 'clinically proven', 'safe for everyone'
    ]
    
    problematicClaims.forEach(claim => {
      if (contentLower.includes(claim)) {
        violations.push({
          ruleId: 'healthcare-claims',
          severity: 'error',
          message: `Potentially misleading healthcare claim: "${claim}"`,
          suggestion: 'Replace with evidence-based, qualified statements'
        })
      }
    })
    
    return violations
  }

  /**
   * Check for medical disclaimer
   */
  private async checkMedicalDisclaimer(content: string): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    const contentLower = content.toLowerCase()
    
    const requiredDisclaimer = [
      'informational purposes',
      'consult your doctor',
      'healthcare provider',
      'medical advice'
    ]
    
    const hasDisclaimer = requiredDisclaimer.some(phrase => contentLower.includes(phrase))
    
    if (!hasDisclaimer) {
      violations.push({
        ruleId: 'medical-disclaimer',
        severity: 'warning',
        message: 'Missing medical disclaimer',
        suggestion: 'Add disclaimer about consulting healthcare providers'
      })
    }
    
    return violations
  }

  /**
   * Validate financial disclaimer
   */
  private async validateFinancialDisclaimer(content: string): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    const contentLower = content.toLowerCase()
    
    const riskyTerms = ['guaranteed returns', 'risk-free', 'get rich quick', 'insider information']
    
    riskyTerms.forEach(term => {
      if (contentLower.includes(term)) {
        violations.push({
          ruleId: 'financial-disclaimers',
          severity: 'error',
          message: `Prohibited financial claim: "${term}"`,
          suggestion: 'Remove or qualify investment claims with appropriate risk disclosures'
        })
      }
    })
    
    return violations
  }

  /**
   * Check investment risks
   */
  private async checkInvestmentRisks(content: string): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    const contentLower = content.toLowerCase()
    
    const investmentWords = ['invest', 'returns', 'profit', 'portfolio']
    const hasInvestmentContent = investmentWords.some(word => contentLower.includes(word))
    
    if (hasInvestmentContent) {
      const riskDisclosures = ['risk', 'past performance', 'may lose', 'not guaranteed']
      const hasRiskDisclosure = riskDisclosures.some(phrase => contentLower.includes(phrase))
      
      if (!hasRiskDisclosure) {
        violations.push({
          ruleId: 'investment-risks',
          severity: 'warning',
          message: 'Investment content missing risk disclosure',
          suggestion: 'Add risk disclosure statements for investment content'
        })
      }
    }
    
    return violations
  }

  /**
   * Validate pharmaceutical claims
   */
  private async validatePharmaceuticalClaims(content: string): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    const contentLower = content.toLowerCase()
    
    const prohibitedClaims = ['cure', 'treat', 'diagnose', 'prevent disease', 'fda approved']
    
    prohibitedClaims.forEach(claim => {
      if (contentLower.includes(claim)) {
        violations.push({
          ruleId: 'pharma-claims',
          severity: 'error',
          message: `Prohibited pharmaceutical claim: "${claim}"`,
          suggestion: 'Use qualified, evidence-based language for pharmaceutical content'
        })
      }
    })
    
    return violations
  }

  /**
   * Validate legal disclaimer
   */
  private async validateLegalDisclaimer(content: string): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    const contentLower = content.toLowerCase()
    
    const problematicClaims = ['guaranteed outcome', 'we will win', 'sure victory', '100% success']
    
    problematicClaims.forEach(claim => {
      if (contentLower.includes(claim)) {
        violations.push({
          ruleId: 'legal-disclaimers',
          severity: 'error',
          message: `Inappropriate legal claim: "${claim}"`,
          suggestion: 'Replace with qualified statements about legal services'
        })
      }
    })
    
    return violations
  }
}

// Export validation schemas
export { ContentComplianceRequestSchema }

// Default service instance factory
export const createContentComplianceService = (config?: ContentComplianceConfig) => {
  return new ContentComplianceService(config)
}

// Default service instance
let _defaultService: ContentComplianceService | null = null
export const contentComplianceService = {
  get instance() {
    if (!_defaultService) {
      _defaultService = new ContentComplianceService()
    }
    return _defaultService
  }
}