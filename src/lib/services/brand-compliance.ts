import { z } from 'zod'

import { BrandComplianceConfig, BrandContext } from '@/lib/types/content-generation'

import { openAIService } from './openai-service'

// OpenAI Moderation API schemas and types
const ModerationRequestSchema = z.object({
  input: z.union([z.string(), z.array(z.string())]),
  model: z.string().optional().default('text-moderation-007')
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
// Simple in-memory cache for validation results
interface ValidationCacheEntry {
  result: DetailedBrandComplianceResult
  timestamp: number
  expiresAt: number
}

export class BrandComplianceService {
  private openAIApiKey: string
  private openAIServiceInstance?: any
  private validationCache = new Map<string, ValidationCacheEntry>()
  private cacheExpirationMs = 15 * 60 * 1000 // 15 minutes
  private maxCacheSize = 1000

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
   * Generate cache key for content and brand context
   */
  private generateCacheKey(content: string, brandContext: BrandContext, config: BrandComplianceConfig): string {
    const configKey = JSON.stringify(config)
    const brandKey = JSON.stringify({
      name: brandContext.name,
      voiceDescription: brandContext.voiceDescription,
      restrictedTerms: brandContext.restrictedTerms,
      messagingFramework: brandContext.messagingFramework
    })
    return Buffer.from(`${content}:${brandKey}:${configKey}`).toString('base64')
  }

  /**
   * Clean expired cache entries
   */
  private cleanCache(): void {
    const now = Date.now()
    for (const [key, entry] of this.validationCache.entries()) {
      if (entry.expiresAt < now) {
        this.validationCache.delete(key)
      }
    }

    // If cache is still too large, remove oldest entries
    if (this.validationCache.size > this.maxCacheSize) {
      const entries = Array.from(this.validationCache.entries())
      entries.sort((a, b) => a[1].timestamp - b[1].timestamp)
      const toRemove = entries.slice(0, entries.length - this.maxCacheSize)
      toRemove.forEach(([key]) => this.validationCache.delete(key))
    }
  }

  /**
   * Get cached validation result
   */
  private getCachedResult(cacheKey: string): DetailedBrandComplianceResult | null {
    const entry = this.validationCache.get(cacheKey)
    if (entry && entry.expiresAt > Date.now()) {
      return entry.result
    }
    return null
  }

  /**
   * Store validation result in cache
   */
  private setCachedResult(cacheKey: string, result: DetailedBrandComplianceResult): void {
    const now = Date.now()
    this.validationCache.set(cacheKey, {
      result,
      timestamp: now,
      expiresAt: now + this.cacheExpirationMs
    })
    this.cleanCache()
  }

  /**
   * Process validation results with error isolation
   */
  private processValidationResults(results: PromiseSettledResult<any>[], tasks: string[]): any[] {
    return results.map((result, index) => {
      if (result.status === 'fulfilled') {
        return result.value
      } else {
        // Only log warnings if not in test environment
        if (process.env.NODE_ENV !== 'test') {
          console.warn(`Validation task ${tasks[index]} failed:`, result.reason)
        }
        
        // For critical errors (like API failures), we should re-throw
        if (tasks[index] === 'moderation' && result.reason instanceof BrandComplianceError) {
          throw result.reason
        }
        
        // Return appropriate fallback based on task type for non-critical errors
        if (tasks[index] === 'moderation') {
          return { id: '', model: '', results: [{ categories: {}, category_scores: {}, flagged: false }] }
        }
        return [] // For violation arrays
      }
    })
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
    
    // Check cache first
    const cacheKey = this.generateCacheKey(content, brandContext, config)
    const cachedResult = this.getCachedResult(cacheKey)
    if (cachedResult) {
      // Update processing timestamp for cached result
      cachedResult.processing.timestamp = new Date().toISOString()
      cachedResult.processing.duration = Date.now() - startTime
      return cachedResult
    }

    const violations: ComplianceViolation[] = []

    try {
      // Enhanced parallel processing with batch optimization and error isolation
      const validationPromises: Promise<any>[] = []
      const validationTasks: string[] = []

      // Core moderation (always runs)
      validationPromises.push(this.checkContentModeration(content, brandContext))
      validationTasks.push('moderation')

      // Optional validations based on config
      if (config.enforceBrandVoice) {
        validationPromises.push(this.validateBrandVoice(content, brandContext))
        validationTasks.push('brandVoice')
      } else {
        validationPromises.push(Promise.resolve([]))
        validationTasks.push('brandVoice')
      }

      if (config.checkRestrictedTerms) {
        validationPromises.push(Promise.resolve(this.checkRestrictedTerms(content, brandContext)))
        validationTasks.push('restrictedTerms')
      } else {
        validationPromises.push(Promise.resolve([]))
        validationTasks.push('restrictedTerms')
      }

      if (config.validateMessaging) {
        validationPromises.push(this.validateMessagingFramework(content, brandContext))
        validationTasks.push('messaging')
      } else {
        validationPromises.push(Promise.resolve([]))
        validationTasks.push('messaging')
      }

      // Add custom rules processing if available
      const advancedConfig = config as any
      if (advancedConfig.customRules && advancedConfig.customRules.length > 0) {
        validationPromises.push(this.processComplexRules(content, brandContext, advancedConfig.customRules))
        validationTasks.push('customRules')
      }

      // Execute all validations with individual error handling
      const results = await Promise.allSettled(validationPromises)
      
      // Process results with error isolation
      const [moderationResult, brandVoiceViolations, restrictedTermsViolations, messagingViolations, customRuleViolations] = 
        this.processValidationResults(results, validationTasks)

      // Collect all violations from successful validations
      violations.push(
        ...this.processModerationResult(moderationResult),
        ...brandVoiceViolations,
        ...restrictedTermsViolations,
        ...messagingViolations,
        ...(customRuleViolations || [])
      )

      // Calculate compliance scores
      const brandAlignmentScore = await this.calculateBrandAlignment(content, brandContext)
      const overallScore = this.calculateOverallComplianceScore(violations, brandAlignmentScore)

      const processingTime = Date.now() - startTime

      const result: DetailedBrandComplianceResult = {
        isCompliant: violations.filter(v => v.severity === 'error').length === 0,
        violations: violations,
        suggestions: violations.filter(v => v.suggestion).map(v => v.suggestion!),
        score: overallScore,
        moderationResult,
        brandAlignmentScore,
        processing: {
          duration: processingTime,
          timestamp: new Date().toISOString(),
          model: 'text-moderation-007'
        }
      }

      // Cache the result for future use
      this.setCachedResult(cacheKey, result)

      return result

    } catch (error) {
      throw new BrandComplianceError(
        `Brand compliance validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        'VALIDATION_FAILED',
        violations
      )
    }
  }

  /**
   * Check content using OpenAI Moderation API with context-aware analysis
   */
  private async checkContentModeration(content: string, brandContext?: BrandContext): Promise<ModerationResponse> {
    try {
      // Enhanced context-aware moderation with brand context
      const contextAwareInput = brandContext ? 
        `Brand Context: ${brandContext.name} - ${brandContext.voiceDescription || 'No voice description'}\nContent Type: Marketing Content\nContent: ${content}` : 
        content

      const response = await fetch('https://api.openai.com/v1/moderations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.openAIApiKey}`
        },
        body: JSON.stringify({
          input: contextAwareInput,
          model: 'text-moderation-007'
        })
      })

      if (!response.ok) {
        throw new Error(`OpenAI Moderation API error: ${response.status} ${response.statusText}`)
      }

      const moderationResult = await response.json()

      // Add contextual analysis if brand context is available
      if (brandContext) {
        moderationResult.contextAnalysis = await this.performContextualModerationAnalysis(content, brandContext, moderationResult)
      }

      return moderationResult
    } catch (error) {
      throw new BrandComplianceError(
        `Content moderation failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        'MODERATION_API_ERROR'
      )
    }
  }

  /**
   * Perform contextual moderation analysis using AI
   */
  private async performContextualModerationAnalysis(
    content: string,
    brandContext: BrandContext,
    moderationResult: any
  ): Promise<any> {
    try {
      const contextPrompt = `
Analyze this content for contextual appropriateness within the brand context:

Brand Context:
- Name: ${brandContext.name}
- Voice: ${brandContext.voiceDescription || 'Not specified'}
- Values: ${brandContext.values?.join(', ') || 'Not specified'}
- Industry Context: Marketing/Brand Communication

Content: "${content}"

Moderation Flags: ${JSON.stringify(moderationResult.results[0]?.categories || {})}

Provide contextual analysis considering:
1. Industry context (marketing content)
2. Brand appropriateness
3. Potential false positives/negatives
4. Context-specific recommendations

Respond with JSON:
{
  "contextuallyAppropriate": boolean,
  "brandAlignment": number (0-100),
  "contextualRisks": ["risk1", "risk2"],
  "recommendations": ["rec1", "rec2"],
  "adjustedSeverity": "low" | "medium" | "high"
}
`

      const response = await this.getOpenAIService().instance.generateText({
        prompt: contextPrompt,
        temperature: 0.2,
        maxTokens: 300
      })

      if (response && response.text) {
        return JSON.parse(response.text)
      }
      return null
    } catch (error) {
      console.warn('Contextual moderation analysis failed:', error)
      return null
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
   * Advanced GPT-4 powered contextual compliance analysis
   */
  private async performGPT4ComplianceAnalysis(
    content: string,
    brandContext: BrandContext
  ): Promise<ComplianceViolation[]> {
    if (!brandContext.voiceDescription && !brandContext.communicationStyle && !brandContext.values) {
      return []
    }

    const violations: ComplianceViolation[] = []

    try {
      const comprehensivePrompt = `
You are an expert brand compliance analyst with deep understanding of marketing communications. 
Perform a comprehensive analysis of the following content against the brand guidelines.

Brand Profile:
- Name: ${brandContext.name}
- Voice Description: ${brandContext.voiceDescription || 'Not specified'}
- Communication Style: ${brandContext.communicationStyle || 'Not specified'}
- Brand Values: ${brandContext.values?.join(', ') || 'Not specified'}
- Messaging Framework: ${brandContext.messagingFramework?.map(p => `${p.pillar}: ${p.description}`).join('; ') || 'Not specified'}
- Restricted Terms: ${brandContext.restrictedTerms?.join(', ') || 'None'}
- Target Audience: ${JSON.stringify(brandContext.targetAudience) || 'Not specified'}

Content to Analyze: "${content}"

Perform a multi-dimensional analysis covering:

1. BRAND VOICE ALIGNMENT
- Does the tone match the brand voice?
- Is the language appropriate for the target audience?
- Does it reflect brand personality?

2. MESSAGE CONSISTENCY
- Alignment with brand values
- Consistency with messaging framework
- Appropriate level of formality

3. CONTEXTUAL APPROPRIATENESS
- Industry standards compliance
- Cultural sensitivity
- Potential misinterpretations

4. STRATEGIC BRAND POSITIONING
- Reinforces desired brand perception
- Differentiates from competitors
- Supports business objectives

5. RISK ASSESSMENT
- Potential PR risks
- Legal concerns
- Stakeholder reactions

Respond with a detailed JSON analysis:
{
  "overallCompliance": {
    "isCompliant": boolean,
    "confidenceScore": number (0-100),
    "overallRisk": "low" | "medium" | "high"
  },
  "dimensionalAnalysis": {
    "brandVoiceScore": number (0-100),
    "messageConsistencyScore": number (0-100),
    "contextualAppropriatenessScore": number (0-100),
    "strategicPositioningScore": number (0-100),
    "riskAssessmentScore": number (0-100)
  },
  "detailedViolations": [
    {
      "category": string,
      "severity": "error" | "warning" | "info",
      "issue": string,
      "explanation": string,
      "suggestion": string,
      "confidence": number (0-1)
    }
  ],
  "strengths": [string],
  "improvements": [string],
  "alternativeVersions": [string] // Optional improved versions
}
`

      const response = await this.getOpenAIService().instance.generateText({
        prompt: comprehensivePrompt,
        temperature: 0.3,
        maxTokens: 1500
      })

      if (!response || !response.text) {
        throw new Error('Invalid response from GPT-4 analysis')
      }

      const analysis = JSON.parse(response.text)
      
      // Process detailed violations from GPT-4 analysis
      if (analysis.detailedViolations && Array.isArray(analysis.detailedViolations)) {
        for (const violation of analysis.detailedViolations) {
          violations.push({
            type: this.mapAnalysisCategoryToViolationType(violation.category),
            severity: violation.severity === 'info' ? 'warning' : violation.severity,
            message: `GPT-4 Analysis: ${violation.issue}`,
            suggestion: violation.suggestion,
            context: `${violation.explanation} (Confidence: ${Math.round(violation.confidence * 100)}%)`,
            confidence: violation.confidence
          })
        }
      }

      // Add overall analysis as context if no specific violations but low scores
      if (analysis.overallCompliance && !analysis.overallCompliance.isCompliant && violations.length === 0) {
        violations.push({
          type: 'brand_voice',
          severity: 'warning',
          message: `Content compliance concern detected by advanced analysis`,
          suggestion: analysis.improvements?.[0] || 'Review content against brand guidelines',
          context: `GPT-4 comprehensive analysis (Risk: ${analysis.overallCompliance.overallRisk})`,
          confidence: analysis.overallCompliance.confidenceScore / 100
        })
      }

    } catch (error) {
      // Only log warnings if not in test environment
      if (process.env.NODE_ENV !== 'test') {
        console.warn('GPT-4 compliance analysis failed:', error)
      }
      // Fallback to standard brand voice validation
      return this.validateBrandVoiceStandard(content, brandContext)
    }

    return violations
  }

  /**
   * Map analysis category to violation type
   */
  private mapAnalysisCategoryToViolationType(category: string): ComplianceViolation['type'] {
    const categoryLower = category.toLowerCase()
    
    if (categoryLower.includes('voice') || categoryLower.includes('tone')) {
      return 'brand_voice'
    }
    if (categoryLower.includes('message') || categoryLower.includes('messaging')) {
      return 'messaging_framework'
    }
    if (categoryLower.includes('term') || categoryLower.includes('language')) {
      return 'restricted_terms'
    }
    if (categoryLower.includes('moderation') || categoryLower.includes('content')) {
      return 'content_moderation'
    }
    
    return 'tone_mismatch'
  }

  /**
   * Standard brand voice validation (fallback method)
   */
  private async validateBrandVoiceStandard(
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
      console.warn('Standard brand voice validation failed:', error)
    }

    return violations
  }

  /**
   * Validate content against brand voice guidelines (enhanced with GPT-4)
   */
  private async validateBrandVoice(
    content: string,
    brandContext: BrandContext
  ): Promise<ComplianceViolation[]> {
    // Use advanced GPT-4 analysis for comprehensive brand voice validation
    return this.performGPT4ComplianceAnalysis(content, brandContext)
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
   * Process complex rules with priority and severity management
   */
  private async processComplexRules(
    content: string,
    brandContext: BrandContext,
    customRules: ComplexRule[] = []
  ): Promise<ComplianceViolation[]> {
    const violations: ComplianceViolation[] = []
    
    // Sort rules by priority (higher priority first)
    const sortedRules = customRules.filter(rule => rule.enabled).sort((a, b) => b.priority - a.priority)
    
    for (const rule of sortedRules) {
      try {
        const ruleViolation = await this.evaluateComplexRule(rule, content, brandContext)
        if (ruleViolation) {
          violations.push(ruleViolation)
          
          // If this is a blocking error, stop processing lower priority rules
          if (rule.severity === 'error' && rule.action.type === 'block') {
            break
          }
        }
      } catch (error) {
        console.warn(`Failed to process rule ${rule.id}:`, error)
      }
    }
    
    return violations
  }

  /**
   * Evaluate a complex rule against content and brand context
   */
  private async evaluateComplexRule(
    rule: ComplexRule,
    content: string,
    brandContext: BrandContext
  ): Promise<ComplianceViolation | null> {
    const ruleMatches = await this.evaluateRuleConditions(rule.conditions, content, brandContext)
    
    if (ruleMatches) {
      return {
        type: this.mapRuleToViolationType(rule.metadata?.category || 'custom'),
        severity: rule.severity === 'info' ? 'warning' : rule.severity as 'error' | 'warning',
        message: rule.action.message,
        suggestion: rule.action.suggestion,
        context: `Rule: ${rule.name} (Priority: ${rule.priority})`,
        confidence: 1.0 // Complex rules have full confidence when they match
      }
    }
    
    return null
  }

  /**
   * Evaluate rule conditions recursively
   */
  private async evaluateRuleConditions(
    conditions: { operator: 'AND' | 'OR'; rules: any[] },
    content: string,
    brandContext: BrandContext
  ): Promise<boolean> {
    const results: boolean[] = []
    
    for (const rule of conditions.rules) {
      if ('field' in rule) {
        // This is a RuleCondition
        const result = this.evaluateRuleCondition(rule as RuleCondition, content, brandContext)
        results.push(result)
      } else if ('conditions' in rule) {
        // This is a nested rule group
        const result = await this.evaluateRuleConditions(rule.conditions, content, brandContext)
        results.push(result)
      }
    }
    
    return conditions.operator === 'AND' 
      ? results.every(r => r)
      : results.some(r => r)
  }

  /**
   * Evaluate a single rule condition
   */
  private evaluateRuleCondition(
    condition: RuleCondition,
    content: string,
    brandContext: BrandContext
  ): boolean {
    const value = this.getFieldValue(condition.field, content, brandContext)
    
    if (value === undefined || value === null) {
      return false
    }
    
    const conditionValue = condition.value
    const valueStr = String(value)
    const conditionStr = String(conditionValue)
    
    switch (condition.operator) {
      case 'equals':
        return condition.caseSensitive 
          ? valueStr === conditionStr
          : valueStr.toLowerCase() === conditionStr.toLowerCase()
      
      case 'contains':
        return condition.caseSensitive
          ? valueStr.includes(conditionStr)
          : valueStr.toLowerCase().includes(conditionStr.toLowerCase())
      
      case 'not_equals':
        return condition.caseSensitive 
          ? valueStr !== conditionStr
          : valueStr.toLowerCase() !== conditionStr.toLowerCase()
      
      case 'not_contains':
        return condition.caseSensitive
          ? !valueStr.includes(conditionStr)
          : !valueStr.toLowerCase().includes(conditionStr.toLowerCase())
      
      case 'matches':
        try {
          const regex = new RegExp(conditionStr, condition.caseSensitive ? 'g' : 'gi')
          return regex.test(valueStr)
        } catch {
          return false
        }
      
      case 'length_gt':
        return valueStr.length > Number(conditionValue)
      
      case 'length_lt':
        return valueStr.length < Number(conditionValue)
      
      default:
        return false
    }
  }

  /**
   * Get field value from content or brand context using dot notation
   */
  private getFieldValue(field: string, content: string, brandContext: BrandContext): any {
    if (field === 'content') {
      return content
    }
    
    if (field.startsWith('brandContext.')) {
      const fieldPath = field.substring('brandContext.'.length)
      return this.getNestedValue(brandContext, fieldPath)
    }
    
    return undefined
  }

  /**
   * Get nested object value using dot notation
   */
  private getNestedValue(obj: any, path: string): any {
    return path.split('.').reduce((current, key) => {
      return current && typeof current === 'object' ? current[key] : undefined
    }, obj)
  }

  /**
   * Map rule category to violation type
   */
  private mapRuleToViolationType(category: string): ComplianceViolation['type'] {
    const mapping: Record<string, ComplianceViolation['type']> = {
      'brand_voice': 'brand_voice',
      'restricted_terms': 'restricted_terms',
      'messaging': 'messaging_framework',
      'moderation': 'content_moderation',
      'tone': 'tone_mismatch'
    }
    
    return mapping[category] || 'brand_voice'
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
   * Predict potential violations before they occur
   */
  async predictViolations(
    content: string,
    brandContext: BrandContext,
    config: BrandComplianceConfig = {
      enforceBrandVoice: true,
      checkRestrictedTerms: true,
      validateMessaging: true
    }
  ): Promise<{
    predictions: Array<{
      type: ComplianceViolation['type']
      likelihood: number // 0-1
      reason: string
      prevention: string
      confidence: number
    }>
    overallRiskScore: number // 0-100
    recommendations: string[]
  }> {
    try {
      const predictionPrompt = `
You are a predictive compliance analyst. Analyze this content for potential brand compliance violations BEFORE they become actual violations.

Brand Context:
- Name: ${brandContext.name}
- Voice: ${brandContext.voiceDescription || 'Not specified'}
- Style: ${brandContext.communicationStyle || 'Not specified'}
- Values: ${brandContext.values?.join(', ') || 'Not specified'}
- Restricted Terms: ${brandContext.restrictedTerms?.join(', ') || 'None'}

Content: "${content}"

Analyze for POTENTIAL violations in these areas:
1. Brand Voice Misalignment Risk
2. Messaging Framework Drift Risk  
3. Tone Inconsistency Risk
4. Restricted Term Usage Risk
5. Content Moderation Risk
6. Cultural Sensitivity Risk
7. Legal/Compliance Risk

For each area, predict:
- Likelihood of violation (0-1)
- Specific risk factors
- Preventive measures
- Confidence in prediction

Respond with JSON:
{
  "predictions": [
    {
      "type": "brand_voice|messaging_framework|tone_mismatch|restricted_terms|content_moderation",
      "likelihood": number (0-1),
      "reason": "why this violation might occur",
      "prevention": "specific preventive action",
      "confidence": number (0-1)
    }
  ],
  "overallRiskScore": number (0-100),
  "recommendations": [
    "specific recommendation 1",
    "specific recommendation 2"
  ]
}
`

      const response = await this.getOpenAIService().instance.generateText({
        prompt: predictionPrompt,
        temperature: 0.2,
        maxTokens: 800
      })

      if (!response || !response.text) {
        throw new Error('Invalid response from prediction service')
      }

      return JSON.parse(response.text)
    } catch (error) {
      // Only log warnings if not in test environment
      if (process.env.NODE_ENV !== 'test') {
        console.warn('Violation prediction failed:', error)
      }
      return {
        predictions: [],
        overallRiskScore: 50,
        recommendations: ['Unable to perform predictive analysis - review content manually']
      }
    }
  }

  /**
   * Generate preventive suggestions based on content analysis
   */
  async generatePreventiveSuggestions(
    content: string,
    brandContext: BrandContext,
    targetAudience?: string,
    contentType?: string
  ): Promise<{
    suggestions: Array<{
      category: string
      priority: 'high' | 'medium' | 'low'
      suggestion: string
      rationale: string
      implementationTips: string[]
    }>
    alternativeApproaches: string[]
    riskMitigation: string[]
  }> {
    try {
      const suggestionPrompt = `
You are a brand compliance consultant providing preventive guidance.

Brand: ${brandContext.name}
Voice: ${brandContext.voiceDescription || 'Not specified'}
Content Type: ${contentType || 'Marketing Content'}
Target Audience: ${targetAudience || 'General'}

Content: "${content}"

Generate preventive suggestions to ensure brand compliance BEFORE issues arise:

1. PROACTIVE IMPROVEMENTS
- Strengthen brand voice alignment
- Enhance message clarity
- Improve audience targeting
- Optimize tone and style

2. RISK MITIGATION
- Identify potential problem areas
- Suggest alternative phrasings
- Recommend structural changes
- Propose safety measures

3. STRATEGIC ENHANCEMENTS  
- Amplify brand strengths
- Differentiate from competitors
- Increase engagement potential
- Maximize conversion opportunities

Respond with JSON:
{
  "suggestions": [
    {
      "category": "Brand Voice|Message Clarity|Tone|Structure|Safety",
      "priority": "high|medium|low",
      "suggestion": "specific actionable suggestion",
      "rationale": "why this will help",
      "implementationTips": ["tip1", "tip2"]
    }
  ],
  "alternativeApproaches": ["approach1", "approach2"],
  "riskMitigation": ["mitigation1", "mitigation2"]
}
`

      const response = await this.getOpenAIService().instance.generateText({
        prompt: suggestionPrompt,
        temperature: 0.3,
        maxTokens: 1000
      })

      if (!response || !response.text) {
        throw new Error('Invalid response from suggestion service')
      }

      return JSON.parse(response.text)
    } catch (error) {
      console.warn('Preventive suggestions generation failed:', error)
      return {
        suggestions: [],
        alternativeApproaches: ['Review content against brand guidelines manually'],
        riskMitigation: ['Conduct thorough compliance review before publication']
      }
    }
  }

  /**
   * Auto-fix minor compliance issues
   */
  async autoFixViolations(
    content: string,
    violations: ComplianceViolation[],
    brandContext: BrandContext
  ): Promise<{
    fixedContent: string
    appliedFixes: Array<{
      violation: ComplianceViolation
      fix: string
      confidence: number
    }>
    manualReviewRequired: ComplianceViolation[]
  }> {
    const autoFixableViolations = violations.filter(v => 
      v.severity === 'warning' && 
      (v.type === 'restricted_terms' || v.type === 'tone_mismatch')
    )
    
    const manualReviewRequired = violations.filter(v => !autoFixableViolations.includes(v))

    if (autoFixableViolations.length === 0) {
      return {
        fixedContent: content,
        appliedFixes: [],
        manualReviewRequired
      }
    }

    try {
      const autoFixPrompt = `
You are an expert content editor. Fix the following compliance violations while preserving the core message and brand voice.

Brand Context:
- Name: ${brandContext.name}
- Voice: ${brandContext.voiceDescription || 'Not specified'}
- Style: ${brandContext.communicationStyle || 'Not specified'}

Original Content: "${content}"

Violations to Fix:
${autoFixableViolations.map(v => `- ${v.type}: ${v.message} | Suggestion: ${v.suggestion || 'N/A'}`).join('\n')}

Requirements:
1. Fix only the specific violations listed
2. Preserve original meaning and intent
3. Maintain brand voice and style
4. Keep the same content length approximately
5. Make minimal changes necessary

Respond with JSON:
{
  "fixedContent": "corrected content here",
  "appliedFixes": [
    {
      "violationType": "type of violation fixed",
      "originalPhrase": "what was changed",
      "fixedPhrase": "what it became",
      "rationale": "why this fix was applied",
      "confidence": number (0-1)
    }
  ]
}
`

      const response = await this.getOpenAIService().instance.generateText({
        prompt: autoFixPrompt,
        temperature: 0.2,
        maxTokens: 1200
      })

      if (!response || !response.text) {
        throw new Error('Invalid response from auto-fix service')
      }

      const result = JSON.parse(response.text)
      
      return {
        fixedContent: result.fixedContent || content,
        appliedFixes: result.appliedFixes?.map((fix: any) => ({
          violation: autoFixableViolations.find(v => v.type.includes(fix.violationType)) || autoFixableViolations[0],
          fix: `Changed "${fix.originalPhrase}" to "${fix.fixedPhrase}": ${fix.rationale}`,
          confidence: fix.confidence || 0.7
        })) || [],
        manualReviewRequired
      }
    } catch (error) {
      console.warn('Auto-fix failed:', error)
      return {
        fixedContent: content,
        appliedFixes: [],
        manualReviewRequired: violations
      }
    }
  }

  /**
   * Batch validate multiple contents with optimized parallel processing
   */
  async batchValidateContent(
    contents: Array<{ id: string; content: string }>,
    brandContext: BrandContext,
    config: BrandComplianceConfig = {
      enforceBrandVoice: true,
      checkRestrictedTerms: true,
      validateMessaging: true
    },
    maxConcurrency: number = 5
  ): Promise<Array<{ id: string; result: DetailedBrandComplianceResult; error?: string }>> {
    const results: Array<{ id: string; result: DetailedBrandComplianceResult; error?: string }> = []
    
    // Process in batches to avoid overwhelming the API
    for (let i = 0; i < contents.length; i += maxConcurrency) {
      const batch = contents.slice(i, i + maxConcurrency)
      
      const batchPromises = batch.map(async ({ id, content }) => {
        try {
          const result = await this.validateContent(content, brandContext, config)
          return { id, result }
        } catch (error) {
          return { 
            id, 
            result: this.createErrorResult(),
            error: error instanceof Error ? error.message : 'Unknown error'
          }
        }
      })
      
      const batchResults = await Promise.allSettled(batchPromises)
      
      batchResults.forEach((settledResult) => {
        if (settledResult.status === 'fulfilled') {
          results.push(settledResult.value)
        } else {
          console.error('Batch validation error:', settledResult.reason)
        }
      })
      
      // Brief pause between batches to be respectful to APIs
      if (i + maxConcurrency < contents.length) {
        await new Promise(resolve => setTimeout(resolve, 100))
      }
    }
    
    return results
  }

  /**
   * Create error result for failed validations
   */
  private createErrorResult(): DetailedBrandComplianceResult {
    return {
      isCompliant: false,
      violations: [{
        type: 'content_moderation',
        severity: 'error',
        message: 'Validation failed due to service error',
        suggestion: 'Please try again or review content manually'
      }],
      suggestions: ['Manual review recommended due to service error'],
      score: 0,
      brandAlignmentScore: 0,
      processing: {
        duration: 0,
        timestamp: new Date().toISOString(),
        model: 'error'
      }
    }
  }

  /**
   * Performance monitoring for validation operations
   */
  async getPerformanceMetrics(): Promise<{
    cacheHitRate: number
    cacheSize: number
    averageProcessingTime: number
    totalValidations: number
  }> {
    const cacheSize = this.validationCache.size
    const validEntries = Array.from(this.validationCache.values()).filter(
      entry => entry.expiresAt > Date.now()
    )
    
    const averageProcessingTime = validEntries.length > 0 
      ? validEntries.reduce((sum, entry) => sum + entry.result.processing.duration, 0) / validEntries.length
      : 0
    
    return {
      cacheHitRate: 0, // This would need to be tracked over time
      cacheSize: validEntries.length,
      averageProcessingTime,
      totalValidations: validEntries.length
    }
  }

  /**
   * Test the service connection
   */
  async testConnection(): Promise<boolean> {
    try {
      const testResult = await this.checkContentModeration('This is a test message.')
      return testResult && testResult.results && testResult.results.length > 0
    } catch (error) {
      // Only log errors if not in test environment
      if (process.env.NODE_ENV !== 'test') {
        console.error('Brand compliance service test failed:', error)
      }
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

// Enhanced Zod schemas for complex rule validation
export const RuleConditionSchema = z.object({
  field: z.string(), // The field to check (e.g., 'content', 'brandContext.name')
  operator: z.enum(['equals', 'contains', 'matches', 'not_equals', 'not_contains', 'length_gt', 'length_lt']),
  value: z.union([z.string(), z.number(), z.boolean()]),
  caseSensitive: z.boolean().default(true)
})

export const ComplexRuleSchema: z.ZodType<any> = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string(),
  priority: z.number().min(1).max(10).default(5),
  severity: z.enum(['error', 'warning', 'info']),
  enabled: z.boolean().default(true),
  conditions: z.object({
    operator: z.enum(['AND', 'OR']).default('AND'),
    rules: z.array(z.union([
      RuleConditionSchema,
      z.lazy(() => z.object({
        conditions: z.object({
          operator: z.enum(['AND', 'OR']),
          rules: z.array(RuleConditionSchema)
        })
      }))
    ]))
  }),
  action: z.object({
    type: z.enum(['block', 'warn', 'suggest']),
    message: z.string(),
    suggestion: z.string().optional(),
    autoFix: z.boolean().default(false)
  }),
  metadata: z.object({
    category: z.string().optional(),
    tags: z.array(z.string()).default([]),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional()
  }).optional()
})

export const RuleSetSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().optional(),
  version: z.string().default('1.0.0'),
  rules: z.array(ComplexRuleSchema),
  globalSettings: z.object({
    enableCaching: z.boolean().default(true),
    cacheExpirationMinutes: z.number().default(15),
    parallelProcessing: z.boolean().default(true),
    maxConcurrentRules: z.number().default(10)
  }).optional()
})

// Advanced compliance configuration with rule sets
export const AdvancedBrandComplianceConfigSchema = z.object({
  enforceBrandVoice: z.boolean().default(true),
  checkRestrictedTerms: z.boolean().default(true),
  validateMessaging: z.boolean().default(true),
  customRules: z.array(ComplexRuleSchema).optional(),
  ruleSets: z.array(z.string()).optional(), // Rule set IDs
  processingOptions: z.object({
    enableContextAnalysis: z.boolean().default(true),
    enablePredictiveAnalysis: z.boolean().default(false),
    confidenceThreshold: z.number().min(0).max(1).default(0.7),
    maxProcessingTimeMs: z.number().default(30000)
  }).optional()
})

// Types derived from enhanced schemas
export type RuleCondition = z.infer<typeof RuleConditionSchema>
export type ComplexRule = z.infer<typeof ComplexRuleSchema>
export type RuleSet = z.infer<typeof RuleSetSchema>
export type AdvancedBrandComplianceConfig = z.infer<typeof AdvancedBrandComplianceConfigSchema>