import { z } from 'zod'

import { openAIService } from '@/lib/services/openai-service'
import { BrandContext } from '@/lib/types/content-generation'

// Brand guideline parsing result
export interface BrandGuidelineParseResult {
  success: boolean
  brandContext: Partial<BrandContext>
  extractedData: {
    voiceKeywords: string[]
    styleAttributes: string[]
    values: string[]
    restrictedTerms: string[]
    messagingPillars: Array<{
      pillar: string
      description: string
      keywords: string[]
    }>
  }
  confidence: number
  processingTime: number
  error?: string
}

// Document type enumeration
export enum DocumentType {
  BRAND_GUIDE = 'brand_guide',
  STYLE_GUIDE = 'style_guide',
  MESSAGING_FRAMEWORK = 'messaging_framework',
  VOICE_TONE_GUIDE = 'voice_tone_guide',
  CONTENT_GUIDELINES = 'content_guidelines',
  UNKNOWN = 'unknown'
}

// Brand guideline validation rules
export const BrandGuidelineValidationSchema = z.object({
  hasVoiceDescription: z.boolean(),
  hasCommunicationStyle: z.boolean(),
  hasValues: z.boolean(),
  hasMessagingFramework: z.boolean(),
  hasRestrictedTerms: z.boolean(),
  hasTargetAudience: z.boolean(),
  completenessScore: z.number().min(0).max(100)
})

export type BrandGuidelineValidation = z.infer<typeof BrandGuidelineValidationSchema>

/**
 * Brand Guideline Parser
 * Extracts brand information from various document formats and text inputs
 */
export class BrandGuidelineParser {
  
  /**
   * Parse brand guidelines from text content
   */
  static async parseFromText(
    content: string,
    documentType: DocumentType = DocumentType.UNKNOWN
  ): Promise<BrandGuidelineParseResult> {
    const startTime = Date.now()

    try {
      // Determine document type if unknown
      const detectedType = documentType === DocumentType.UNKNOWN 
        ? await this.detectDocumentType(content)
        : documentType

      // Extract brand information using AI
      const extractionPrompt = this.buildExtractionPrompt(content, detectedType)
      
      const response = await openAIService.instance.generateText({
        prompt: extractionPrompt,
        temperature: 0.2,
        maxTokens: 1500
      })

      // Parse AI response
      const extractedData = JSON.parse(response.text)
      
      // Build brand context from extracted data
      const brandContext = this.buildBrandContext(extractedData)
      
      // Calculate confidence score
      const confidence = this.calculateConfidence(extractedData, content.length)
      
      return {
        success: true,
        brandContext,
        extractedData: {
          voiceKeywords: extractedData.voiceKeywords || [],
          styleAttributes: extractedData.styleAttributes || [],
          values: extractedData.values || [],
          restrictedTerms: extractedData.restrictedTerms || [],
          messagingPillars: extractedData.messagingPillars || []
        },
        confidence,
        processingTime: Date.now() - startTime
      }

    } catch (error) {
      return {
        success: false,
        brandContext: {},
        extractedData: {
          voiceKeywords: [],
          styleAttributes: [],
          values: [],
          restrictedTerms: [],
          messagingPillars: []
        },
        confidence: 0,
        processingTime: Date.now() - startTime,
        error: error instanceof Error ? error.message : 'Unknown parsing error'
      }
    }
  }

  /**
   * Validate brand context completeness
   */
  static validateBrandContext(brandContext: BrandContext): BrandGuidelineValidation {
    const validation = {
      hasVoiceDescription: !!brandContext.voiceDescription && brandContext.voiceDescription.length > 10,
      hasCommunicationStyle: !!brandContext.communicationStyle && brandContext.communicationStyle.length > 10,
      hasValues: !!brandContext.values && brandContext.values.length > 0,
      hasMessagingFramework: !!brandContext.messagingFramework && brandContext.messagingFramework.length > 0,
      hasRestrictedTerms: !!brandContext.restrictedTerms && brandContext.restrictedTerms.length > 0,
      hasTargetAudience: !!brandContext.targetAudience && Object.keys(brandContext.targetAudience).length > 0,
      completenessScore: 0
    }

    // Calculate completeness score
    const criteria = [
      validation.hasVoiceDescription,
      validation.hasCommunicationStyle,
      validation.hasValues,
      validation.hasMessagingFramework,
      validation.hasTargetAudience
    ]
    
    validation.completenessScore = Math.round(
      (criteria.filter(Boolean).length / criteria.length) * 100
    )

    return validation
  }

  /**
   * Merge multiple brand contexts (useful for processing multiple documents)
   */
  static mergeBrandContexts(contexts: Partial<BrandContext>[]): BrandContext {
    const merged: Partial<BrandContext> = {
      name: '',
      values: [],
      restrictedTerms: [],
      messagingFramework: [],
      complianceRules: []
    }

    for (const context of contexts) {
      // Take the first non-empty value for singular fields
      if (!merged.name && context.name) merged.name = context.name
      if (!merged.tagline && context.tagline) merged.tagline = context.tagline
      if (!merged.voiceDescription && context.voiceDescription) merged.voiceDescription = context.voiceDescription
      if (!merged.communicationStyle && context.communicationStyle) merged.communicationStyle = context.communicationStyle

      // Merge arrays without duplicates
      if (context.values) {
        merged.values = [...new Set([...(merged.values || []), ...context.values])]
      }
      
      if (context.restrictedTerms) {
        merged.restrictedTerms = [...new Set([...(merged.restrictedTerms || []), ...context.restrictedTerms])]
      }

      if (context.messagingFramework) {
        const existingPillars = new Set((merged.messagingFramework || []).map(p => p.pillar))
        const newPillars = context.messagingFramework.filter(p => !existingPillars.has(p.pillar))
        merged.messagingFramework = [...(merged.messagingFramework || []), ...newPillars]
      }

      if (context.complianceRules) {
        const existingRules = new Set((merged.complianceRules || []).map(r => r.rule))
        const newRules = context.complianceRules.filter(r => !existingRules.has(r.rule))
        merged.complianceRules = [...(merged.complianceRules || []), ...newRules]
      }

      // Merge objects
      if (context.toneAttributes) {
        merged.toneAttributes = { ...merged.toneAttributes, ...context.toneAttributes }
      }

      if (context.targetAudience) {
        merged.targetAudience = { ...merged.targetAudience, ...context.targetAudience }
      }
    }

    return merged as BrandContext
  }

  /**
   * Detect document type from content
   */
  private static async detectDocumentType(content: string): Promise<DocumentType> {
    try {
      const detectionPrompt = `
Analyze this document content and determine its type. Respond with only one of these exact values:
- brand_guide
- style_guide  
- messaging_framework
- voice_tone_guide
- content_guidelines
- unknown

Document content (first 1000 characters):
${content.substring(0, 1000)}...
`

      const response = await openAIService.instance.generateText({
        prompt: detectionPrompt,
        temperature: 0.1,
        maxTokens: 10
      })

      const detectedType = response.text.trim().toLowerCase()
      
      return Object.values(DocumentType).includes(detectedType as DocumentType)
        ? (detectedType as DocumentType)
        : DocumentType.UNKNOWN

    } catch (error) {
      console.warn('Document type detection failed:', error)
      return DocumentType.UNKNOWN
    }
  }

  /**
   * Build extraction prompt based on document type
   */
  private static buildExtractionPrompt(content: string, documentType: DocumentType): string {
    const basePrompt = `
Extract brand information from this ${documentType.replace('_', ' ')} document.

Document content:
${content}

Extract the following information and respond with a JSON object:
{
  "brandName": "brand name if found",
  "tagline": "brand tagline or slogan",
  "voiceDescription": "description of brand voice and personality",
  "communicationStyle": "how the brand communicates",
  "voiceKeywords": ["keywords describing voice/tone"],
  "styleAttributes": ["style characteristics"],
  "values": ["brand values"],
  "targetAudience": {
    "demographics": "target audience demographics",
    "psychographics": "target audience interests/behaviors",
    "painPoints": "audience pain points"
  },
  "messagingPillars": [
    {
      "pillar": "pillar name",
      "description": "pillar description", 
      "keywords": ["related keywords"]
    }
  ],
  "restrictedTerms": ["terms to avoid"],
  "complianceRules": [
    {
      "rule": "rule description",
      "severity": "error|warning",
      "description": "detailed explanation"
    }
  ],
  "toneAttributes": {
    "formal": "boolean or description",
    "friendly": "boolean or description",
    "professional": "boolean or description"
  }
}

Only include fields where you can extract meaningful information. Return "null" for missing information.
`

    // Add document-type specific instructions
    switch (documentType) {
      case DocumentType.VOICE_TONE_GUIDE:
        return basePrompt + '\nFocus especially on voice description, tone attributes, and communication style.'
      
      case DocumentType.MESSAGING_FRAMEWORK:
        return basePrompt + '\nFocus especially on messaging pillars, values, and target audience.'
      
      case DocumentType.STYLE_GUIDE:
        return basePrompt + '\nFocus especially on style attributes, tone attributes, and communication guidelines.'
      
      default:
        return basePrompt
    }
  }

  /**
   * Build BrandContext from extracted data
   */
  private static buildBrandContext(extractedData: any): Partial<BrandContext> {
    return {
      name: extractedData.brandName || '',
      tagline: extractedData.tagline || undefined,
      voiceDescription: extractedData.voiceDescription || undefined,
      communicationStyle: extractedData.communicationStyle || undefined,
      toneAttributes: extractedData.toneAttributes || undefined,
      targetAudience: extractedData.targetAudience || undefined,
      values: extractedData.values || [],
      messagingFramework: extractedData.messagingPillars || [],
      restrictedTerms: extractedData.restrictedTerms || [],
      complianceRules: extractedData.complianceRules || []
    }
  }

  /**
   * Calculate confidence score based on extracted data quality
   */
  private static calculateConfidence(extractedData: any, contentLength: number): number {
    let score = 0
    const weights = {
      brandName: 15,
      voiceDescription: 20,
      communicationStyle: 15,
      values: 15,
      messagingPillars: 20,
      targetAudience: 10,
      restrictedTerms: 5
    }

    // Score based on presence and quality of extracted data
    Object.entries(weights).forEach(([field, weight]) => {
      const value = extractedData[field]
      if (value) {
        if (Array.isArray(value) && value.length > 0) {
          score += weight
        } else if (typeof value === 'string' && value.length > 10) {
          score += weight
        } else if (typeof value === 'object' && Object.keys(value).length > 0) {
          score += weight
        }
      }
    })

    // Boost confidence for longer, more detailed content
    if (contentLength > 1000) score += 5
    if (contentLength > 5000) score += 5

    return Math.min(100, score)
  }

  /**
   * Extract restricted terms using pattern matching and AI analysis
   */
  static async extractRestrictedTerms(
    content: string,
    existingTerms: string[] = []
  ): Promise<string[]> {
    try {
      const extractionPrompt = `
Analyze this content and identify terms or phrases that appear to be restricted, prohibited, or should be avoided based on the context:

Content:
${content}

Existing restricted terms: ${existingTerms.join(', ')}

Look for:
- Explicit mentions of "avoid", "don't use", "restricted", "prohibited"
- Competitor names that shouldn't be mentioned
- Inappropriate language for the brand
- Terms that conflict with brand values

Return a JSON array of strings: ["term1", "term2", ...]
`

      const response = await openAIService.instance.generateText({
        prompt: extractionPrompt,
        temperature: 0.2,
        maxTokens: 200
      })

      const newTerms = JSON.parse(response.text)
      
      if (Array.isArray(newTerms)) {
        // Combine with existing terms and remove duplicates
        return [...new Set([...existingTerms, ...newTerms.map(term => String(term).toLowerCase())])]
      }

      return existingTerms

    } catch (error) {
      console.warn('Restricted terms extraction failed:', error)
      return existingTerms
    }
  }
}

// Export convenience functions
export const parseFromText = BrandGuidelineParser.parseFromText.bind(BrandGuidelineParser)
export const validateBrandContext = BrandGuidelineParser.validateBrandContext.bind(BrandGuidelineParser)
export const mergeBrandContexts = BrandGuidelineParser.mergeBrandContexts.bind(BrandGuidelineParser)
export const extractRestrictedTerms = BrandGuidelineParser.extractRestrictedTerms.bind(BrandGuidelineParser)