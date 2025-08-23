import OpenAI from 'openai'
import { z } from 'zod'
import { BrandContext, BrandComplianceResult, ContentOptimizationSuggestion } from '@/lib/types/content-generation'

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
  type: 'content' | 'format' | 'brand' | 'safety'
  severity: 'error' | 'warning' | 'info'
  validator: (content: string, context?: BrandContext) => Promise<ComplianceViolation[]>
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
   * Check brand voice alignment
   */
  private async checkBrandVoiceAlignment(content: string, brandContext?: BrandContext): Promise<ComplianceViolation[]> {
    if (!brandContext?.voiceDescription) return []

    // This is a simplified check - in production, you might use more sophisticated NLP
    const violations: ComplianceViolation[] = []
    
    // Check for basic tone indicators
    const voiceKeywords = brandContext.voiceDescription.toLowerCase().split(/\s+/)
    const contentWords = content.toLowerCase().split(/\s+/)
    
    const alignmentScore = this.calculateTextSimilarity(voiceKeywords, contentWords)
    
    if (alignmentScore < 0.2) {
      violations.push({
        ruleId: 'brand-voice-alignment',
        severity: 'warning',
        message: 'Content does not align well with brand voice',
        suggestion: `Adjust tone to match brand voice: ${brandContext.voiceDescription}`,
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