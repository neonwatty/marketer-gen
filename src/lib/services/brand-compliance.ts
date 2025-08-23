import { z } from 'zod'

import { BrandComplianceConfig, BrandContext } from '@/lib/types/content-generation'

import { openAIService } from './openai-service'

// OpenAI Moderation API schemas and types
const ModerationRequestSchema = z.object({
  input: z.union([z.string(), z.array(z.string())]),
  model: z.string().optional().default('text-moderation-latest')
})

export interface ModerationResponse {
  id: string
  model: string
  results: Array<{
    categories: {
      hate: boolean
      'hate/threatening': boolean
      harassment: boolean
      'harassment/threatening': boolean
      'self-harm': boolean
      'self-harm/intent': boolean
      'self-harm/instructions': boolean
      sexual: boolean
      'sexual/minors': boolean
      violence: boolean
      'violence/graphic': boolean
    }
    category_scores: {
      hate: number
      'hate/threatening': number
      harassment: number
      'harassment/threatening': number
      'self-harm': number
      'self-harm/intent': number
      'self-harm/instructions': number
      sexual: number
      'sexual/minors': number
      violence: number
      'violence/graphic': number
    }
    flagged: boolean
  }>
}

// Brand compliance violation types
export interface ComplianceViolation {
  type: 'brand_voice' | 'restricted_terms' | 'messaging_framework' | 'content_moderation' | 'tone_mismatch'
  severity: 'error' | 'warning'
  message: string
  suggestion?: string
  context?: string
  confidence?: number
}

// Extended brand compliance result with detailed violations
export interface DetailedBrandComplianceResult {
  isCompliant: boolean
  violations: ComplianceViolation[]
  suggestions?: string[]
  score?: number
  moderationResult?: ModerationResponse
  brandAlignmentScore: number
  processing: {
    duration: number
    timestamp: string
    model?: string
  }
}

export class BrandComplianceError extends Error {
  constructor(
    message: string,
    public code: string,
    public violations?: ComplianceViolation[]
  ) {
    super(message)
    this.name = 'BrandComplianceError'
  }
}

/**
 * Brand Compliance Service
 * Validates content against brand guidelines and OpenAI moderation policies
 */
export class BrandComplianceService {
  private openAIApiKey: string
  private openAIServiceInstance?: any

  constructor(openAIApiKey?: string, openAIServiceInstance?: any) {
    this.openAIApiKey = openAIApiKey || process.env.OPENAI_API_KEY || ''
    this.openAIServiceInstance = openAIServiceInstance
    
    // Only throw error if the final API key is empty and no service instance provided
    if (!this.openAIApiKey && !this.openAIServiceInstance) {
      throw new BrandComplianceError(
        'OpenAI API key is required',
        'MISSING_API_KEY'
      )
    }
  }

  private getOpenAIService() {
    if (this.openAIServiceInstance) {
      return { instance: this.openAIServiceInstance }
    }
    return openAIService
  }

  /**
   * Validate content against brand compliance rules
   */
  async validateContent(
    content: string,
    brandContext: BrandContext,
    config: BrandComplianceConfig = {
      enforceBrandVoice: true,
      checkRestrictedTerms: true,
      validateMessaging: true
    }
  ): Promise<DetailedBrandComplianceResult> {
    const startTime = Date.now()
    const violations: ComplianceViolation[] = []

    try {
      // Run all validation checks in parallel for better performance
      const [
        moderationResult,
        brandVoiceViolations,
        restrictedTermsViolations,
        messagingViolations
      ] = await Promise.all([
        this.checkContentModeration(content),
        config.enforceBrandVoice ? this.validateBrandVoice(content, brandContext) : [],
        config.checkRestrictedTerms ? this.checkRestrictedTerms(content, brandContext) : [],
        config.validateMessaging ? this.validateMessagingFramework(content, brandContext) : []
      ])

      // Collect all violations
      violations.push(
        ...this.processModerationResult(moderationResult),
        ...brandVoiceViolations,
        ...restrictedTermsViolations,
        ...messagingViolations
      )

      // Calculate compliance scores
      const brandAlignmentScore = await this.calculateBrandAlignment(content, brandContext)
      const overallScore = this.calculateOverallComplianceScore(violations, brandAlignmentScore)

      const processingTime = Date.now() - startTime

      return {
        isCompliant: violations.filter(v => v.severity === 'error').length === 0,
        violations: violations,
        suggestions: violations.filter(v => v.suggestion).map(v => v.suggestion!),
        score: overallScore,
        moderationResult,
        brandAlignmentScore,
        processing: {
          duration: processingTime,
          timestamp: new Date().toISOString(),
          model: 'text-moderation-latest'
        }
      } as DetailedBrandComplianceResult

    } catch (error) {
      throw new BrandComplianceError(
        `Brand compliance validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        'VALIDATION_FAILED',
        violations
      )
    }
  }

  /**
   * Check content using OpenAI Moderation API
   */
  private async checkContentModeration(content: string): Promise<ModerationResponse> {
    try {
      const response = await fetch('https://api.openai.com/v1/moderations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.openAIApiKey}`
        },
        body: JSON.stringify({
          input: content,
          model: 'text-moderation-latest'
        })
      })

      if (!response.ok) {
        throw new Error(`OpenAI Moderation API error: ${response.status} ${response.statusText}`)
      }

      return await response.json()
    } catch (error) {
      throw new BrandComplianceError(
        `Content moderation failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        'MODERATION_API_ERROR'
      )
    }
  }

  /**
   * Process OpenAI moderation result into compliance violations
   */
  private processModerationResult(moderationResult: ModerationResponse): ComplianceViolation[] {
    const violations: ComplianceViolation[] = []

    for (const result of moderationResult.results) {
      if (result.flagged) {
        const flaggedCategories = Object.entries(result.categories)
          .filter(([_, flagged]) => flagged)
          .map(([category]) => category)

        violations.push({
          type: 'content_moderation',
          severity: 'error',
          message: `Content flagged for: ${flaggedCategories.join(', ')}`,
          suggestion: 'Review and revise content to remove potentially harmful or inappropriate language',
          context: 'OpenAI Content Moderation',
          confidence: Math.max(...Object.values(result.category_scores))
        })
      }
    }

    return violations
  }

  /**
   * Validate content against brand voice guidelines
   */
  private async validateBrandVoice(
    content: string,
    brandContext: BrandContext
  ): Promise<ComplianceViolation[]> {
    if (!brandContext.voiceDescription && !brandContext.communicationStyle) {
      return []
    }

    const violations: ComplianceViolation[] = []

    try {
      const brandVoicePrompt = `
Analyze the following content for brand voice compliance:

Brand Voice: ${brandContext.voiceDescription || 'Not specified'}
Communication Style: ${brandContext.communicationStyle || 'Not specified'}
Brand Values: ${brandContext.values?.join(', ') || 'Not specified'}

Content to analyze:
"${content}"

Respond with a JSON object containing:
{
  "isCompliant": boolean,
  "violations": [
    {
      "issue": "description of voice mismatch",
      "suggestion": "how to fix it"
    }
  ],
  "confidence": number between 0-1
}
`

      const response = await this.getOpenAIService().instance.generateText({
        prompt: brandVoicePrompt,
        temperature: 0.3,
        maxTokens: 500
      })

      if (!response || !response.text) {
        throw new Error('Invalid response from OpenAI service')
      }

      const analysis = JSON.parse(response.text)
      
      if (!analysis.isCompliant && analysis.violations) {
        for (const violation of analysis.violations) {
          violations.push({
            type: 'brand_voice',
            severity: 'warning',
            message: `Brand voice mismatch: ${violation.issue}`,
            suggestion: violation.suggestion,
            confidence: analysis.confidence
          })
        }
      }

    } catch (error) {
      console.warn('Brand voice validation failed:', error)
      // Don't fail the entire validation if brand voice check fails
    }

    return violations
  }

  /**
   * Check for restricted terms
   */
  private checkRestrictedTerms(
    content: string,
    brandContext: BrandContext
  ): ComplianceViolation[] {
    const violations: ComplianceViolation[] = []
    
    if (!brandContext.restrictedTerms || brandContext.restrictedTerms.length === 0) {
      return violations
    }

    const contentLower = content.toLowerCase()
    
    for (const restrictedTerm of brandContext.restrictedTerms) {
      const termLower = restrictedTerm.toLowerCase()
      if (contentLower.includes(termLower)) {
        violations.push({
          type: 'restricted_terms',
          severity: 'error',
          message: `Content contains restricted term: "${restrictedTerm}"`,
          suggestion: `Remove or replace the term "${restrictedTerm}" with an approved alternative`,
          context: `Found in content at position: ${contentLower.indexOf(termLower)}`
        })
      }
    }

    return violations
  }

  /**
   * Validate content against messaging framework
   */
  private async validateMessagingFramework(
    content: string,
    brandContext: BrandContext
  ): Promise<ComplianceViolation[]> {
    if (!brandContext.messagingFramework || brandContext.messagingFramework.length === 0) {
      return []
    }

    const violations: ComplianceViolation[] = []

    try {
      const messagingPrompt = `
Analyze the following content against the brand's messaging framework:

Messaging Pillars:
${brandContext.messagingFramework.map(pillar => 
  `- ${pillar.pillar}: ${pillar.description} (Keywords: ${pillar.keywords.join(', ')})`
).join('\n')}

Content to analyze:
"${content}"

Determine if the content aligns with at least one messaging pillar. Respond with JSON:
{
  "alignsWithFramework": boolean,
  "alignedPillars": ["pillar names that match"],
  "misalignmentReason": "explanation if not aligned",
  "suggestion": "how to better align with messaging framework"
}
`

      const response = await this.getOpenAIService().instance.generateText({
        prompt: messagingPrompt,
        temperature: 0.2,
        maxTokens: 300
      })

      if (!response || !response.text) {
        throw new Error('Invalid response from OpenAI service')
      }

      const analysis = JSON.parse(response.text)
      
      if (!analysis.alignsWithFramework) {
        violations.push({
          type: 'messaging_framework',
          severity: 'warning',
          message: `Content doesn't align with messaging framework: ${analysis.misalignmentReason}`,
          suggestion: analysis.suggestion
        })
      }

    } catch (error) {
      console.warn('Messaging framework validation failed:', error)
    }

    return violations
  }

  /**
   * Calculate brand alignment score using AI analysis
   */
  private async calculateBrandAlignment(
    content: string,
    brandContext: BrandContext
  ): Promise<number> {
    try {
      const alignmentPrompt = `
Rate how well this content aligns with the brand on a scale of 0-100:

Brand Profile:
- Name: ${brandContext.name}
- Tagline: ${brandContext.tagline || 'Not specified'}
- Voice: ${brandContext.voiceDescription || 'Not specified'}
- Style: ${brandContext.communicationStyle || 'Not specified'}
- Values: ${brandContext.values?.join(', ') || 'Not specified'}

Content: "${content}"

Respond with only a number between 0-100 representing the alignment score.
`

      const response = await this.getOpenAIService().instance.generateText({
        prompt: alignmentPrompt,
        temperature: 0.1,
        maxTokens: 10
      })

      if (!response || !response.text) {
        throw new Error('Invalid response from OpenAI service')
      }

      const score = parseInt(response.text.trim())
      return isNaN(score) ? 50 : Math.max(0, Math.min(100, score))

    } catch (error) {
      console.warn('Brand alignment calculation failed:', error)
      return 50 // Default neutral score
    }
  }

  /**
   * Calculate overall compliance score based on violations and brand alignment
   */
  private calculateOverallComplianceScore(
    violations: ComplianceViolation[],
    brandAlignmentScore: number
  ): number {
    // Start with brand alignment score
    let score = brandAlignmentScore

    // Deduct points for violations
    for (const violation of violations) {
      if (violation.severity === 'error') {
        score -= 25 // Major deduction for errors
      } else if (violation.severity === 'warning') {
        score -= 10 // Minor deduction for warnings
      }
    }

    return Math.max(0, Math.min(100, score))
  }

  /**
   * Get compliance rules from brand context
   */
  getComplianceRules(brandContext: BrandContext): Array<{ rule: string; severity: 'error' | 'warning'; description: string }> {
    const rules = brandContext.complianceRules || []
    
    // Add default rules based on brand context
    if (brandContext.restrictedTerms && brandContext.restrictedTerms.length > 0) {
      rules.push({
        rule: 'No restricted terms',
        severity: 'error',
        description: `Avoid using these restricted terms: ${brandContext.restrictedTerms.join(', ')}`
      })
    }

    if (brandContext.voiceDescription) {
      rules.push({
        rule: 'Brand voice alignment',
        severity: 'warning',
        description: `Content should align with brand voice: ${brandContext.voiceDescription}`
      })
    }

    if (brandContext.messagingFramework && brandContext.messagingFramework.length > 0) {
      rules.push({
        rule: 'Messaging framework alignment',
        severity: 'warning',
        description: 'Content should align with at least one messaging pillar'
      })
    }

    return rules
  }

  /**
   * Test the service connection
   */
  async testConnection(): Promise<boolean> {
    try {
      const testResult = await this.checkContentModeration('This is a test message.')
      return testResult && testResult.results && testResult.results.length > 0
    } catch (error) {
      console.error('Brand compliance service test failed:', error)
      return false
    }
  }
}

// Default service instance factory
export const createBrandComplianceService = (openAIApiKey?: string) => 
  new BrandComplianceService(openAIApiKey)

// Default service instance (lazy initialization)
let _defaultBrandComplianceService: BrandComplianceService | null = null
export const brandComplianceService = {
  get instance() {
    if (!_defaultBrandComplianceService) {
      _defaultBrandComplianceService = new BrandComplianceService(undefined, undefined)
    }
    return _defaultBrandComplianceService
  }
}

// Note: BrandComplianceConfigSchema is exported from @/lib/types/content-generation

export const ComplianceViolationSchema = z.object({
  type: z.enum(['brand_voice', 'restricted_terms', 'messaging_framework', 'content_moderation', 'tone_mismatch']),
  severity: z.enum(['error', 'warning']),
  message: z.string(),
  suggestion: z.string().optional(),
  context: z.string().optional(),
  confidence: z.number().min(0).max(1).optional()
})