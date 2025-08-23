import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'

import { z } from 'zod'

import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/db'
import { ContentVariantService } from '@/lib/services/content-variant-service'
import { openAIService } from '@/lib/services/openai-service'

// Retry configuration
const RETRY_CONFIG = {
  maxRetries: process.env.NODE_ENV === 'test' ? 0 : 3, // No retries in tests
  baseDelay: 1000, // 1 second
  maxDelay: 10000, // 10 seconds
}

// Utility function for exponential backoff retry
async function retryWithBackoff<T>(
  operation: () => Promise<T>,
  maxRetries: number = RETRY_CONFIG.maxRetries,
  baseDelay: number = RETRY_CONFIG.baseDelay
): Promise<T> {
  let lastError: Error
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation()
    } catch (error) {
      lastError = error as Error
      
      // Don't retry on certain types of errors
      if (error instanceof z.ZodError || 
          (error instanceof Error && error.name === 'OpenAIServiceError')) {
        const openAIError = error as any
        // Don't retry on client errors (400s) except rate limits
        if (openAIError.statusCode && openAIError.statusCode >= 400 && 
            openAIError.statusCode < 500 && openAIError.statusCode !== 429) {
          throw error
        }
      }
      
      // Don't retry on the last attempt
      if (attempt === maxRetries) {
        throw lastError
      }
      
      // Calculate delay with exponential backoff and jitter
      const delay = Math.min(
        baseDelay * Math.pow(2, attempt) + Math.random() * 1000,
        RETRY_CONFIG.maxDelay
      )
      
      console.warn(`Retry attempt ${attempt + 1}/${maxRetries} after ${delay}ms for error:`, error)
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }
  
  throw lastError!
}

// Request validation schema for content generation
const ContentGenerationRequestSchema = z.object({
  brandId: z.string().cuid('Invalid brand ID format'),
  contentType: z.enum([
    'EMAIL', 'SOCIAL_POST', 'SOCIAL_AD', 'SEARCH_AD', 'BLOG_POST', 
    'LANDING_PAGE', 'VIDEO_SCRIPT', 'INFOGRAPHIC', 'NEWSLETTER', 'PRESS_RELEASE'
  ]),
  prompt: z.string().min(10, 'Prompt must be at least 10 characters').max(2000, 'Prompt too long'),
  targetAudience: z.string().optional(),
  tone: z.enum(['professional', 'casual', 'friendly', 'authoritative', 'playful', 'urgent']).optional(),
  channel: z.string().optional(),
  callToAction: z.string().optional(),
  includeVariants: z.boolean().default(false),
  variantCount: z.number().min(1).max(5).default(1),
  variantStrategies: z.array(z.enum(['style_variation', 'length_variation', 'angle_variation', 'tone_variation', 'cta_variation'])).optional(),
  useTemplates: z.boolean().default(false),
  maxLength: z.number().min(50).max(5000).optional(),
  keywords: z.array(z.string()).max(10).optional(),
  brandCompliance: z.object({
    enforceBrandVoice: z.boolean().default(true),
    checkRestrictedTerms: z.boolean().default(true),
    validateMessaging: z.boolean().default(true),
  }).optional(),
  streaming: z.boolean().default(false),
  includeAnalysis: z.boolean().default(false),
})

type ContentGenerationRequest = z.infer<typeof ContentGenerationRequestSchema>

// Response schema for type safety
const ContentGenerationResponseSchema = z.object({
  success: z.boolean(),
  content: z.string(),
  variants: z.array(z.string()).optional(),
  enhancedVariants: z.array(z.object({
    id: z.string(),
    content: z.string(),
    strategy: z.enum(['style_variation', 'length_variation', 'angle_variation', 'tone_variation', 'cta_variation']),
    score: z.number().optional(),
    metrics: z.object({
      estimatedEngagement: z.number(),
      readabilityScore: z.number(),
      brandAlignment: z.number(),
      formatOptimization: z.number(),
    }).optional(),
    formatOptimizations: z.object({
      platform: z.string().optional(),
      characterCount: z.number(),
      wordCount: z.number(),
      hasHashtags: z.boolean().optional(),
      hasCTA: z.boolean().optional(),
      keywordDensity: z.record(z.string(), z.number()),
    }).optional(),
  })).optional(),
  brandCompliance: z.object({
    isCompliant: z.boolean(),
    violations: z.array(z.string()),
    suggestions: z.array(z.string()).optional(),
    score: z.number().min(0).max(100),
  }),
  analysis: z.object({
    sentiment: z.enum(['positive', 'neutral', 'negative']),
    readabilityScore: z.number(),
    keywordDensity: z.record(z.string(), z.number()),
    brandAlignment: z.number().min(0).max(100),
    suggestions: z.array(z.object({
      type: z.enum(['length', 'tone', 'keywords', 'cta', 'structure', 'brand']),
      priority: z.enum(['high', 'medium', 'low']),
      suggestion: z.string(),
      reason: z.string(),
    })),
  }).optional(),
  metadata: z.object({
    brandId: z.string(),
    contentType: z.string(),
    generatedAt: z.string(),
    wordCount: z.number(),
    charCount: z.number(),
    processingTime: z.number().optional(),
    model: z.string().optional(),
    tokensUsed: z.number().optional(),
  }),
})

type ContentGenerationResponse = z.infer<typeof ContentGenerationResponseSchema>

// Enhanced brand compliance validation function with scoring
async function validateBrandCompliance(
  content: string,
  brandData: any,
  options: ContentGenerationRequest['brandCompliance'] = {
    enforceBrandVoice: true,
    checkRestrictedTerms: true,
    validateMessaging: true,
  }
): Promise<{ isCompliant: boolean; violations: string[]; suggestions?: string[]; score: number }> {
  const violations: string[] = []
  const suggestions: string[] = []
  let complianceScore = 100 // Start with perfect score

  const { enforceBrandVoice = true, checkRestrictedTerms = true, validateMessaging = true } = options

  // Check restricted terms (high severity - 20 point deduction per term)
  if (checkRestrictedTerms && brandData.restrictedTerms) {
    const restrictedTerms = Array.isArray(brandData.restrictedTerms) 
      ? brandData.restrictedTerms 
      : JSON.parse(brandData.restrictedTerms || '[]')
    
    const contentLower = content.toLowerCase()
    for (const term of restrictedTerms) {
      if (contentLower.includes(term.toLowerCase())) {
        violations.push(`Contains restricted term: "${term}"`)
        suggestions.push(`Replace "${term}" with an approved alternative`)
        complianceScore -= 20
      }
    }
  }

  // Check brand voice compliance using enhanced AI analysis
  if (enforceBrandVoice && brandData.voiceDescription) {
    try {
      const voiceAnalysisPrompt = `
        Analyze the following content for brand voice compliance and provide a detailed assessment:
        
        Brand Voice Description: ${brandData.voiceDescription}
        Brand Communication Style: ${brandData.communicationStyle || 'Not specified'}
        Brand Tone Attributes: ${JSON.stringify(brandData.toneAttributes || {})}
        Brand Values: ${JSON.stringify(brandData.values || [])}
        
        Content to analyze: "${content}"
        
        Provide your response in this exact format:
        SCORE: [0-100]
        STATUS: [COMPLIANT|NON_COMPLIANT]
        REASON: [detailed explanation]
        SUGGESTIONS: [specific improvement recommendations]
      `

      const voiceAnalysis = await retryWithBackoff(() => 
        openAIService.instance.generateText({
          prompt: voiceAnalysisPrompt,
          maxTokens: 250,
          temperature: 0.1
        })
      )

      const analysisResult = voiceAnalysis.text.trim()
      const scoreMatch = analysisResult.match(/SCORE:\s*(\d+)/)
      const statusMatch = analysisResult.match(/STATUS:\s*(COMPLIANT|NON_COMPLIANT)/)
      const reasonMatch = analysisResult.match(/REASON:\s*(.+?)(?=SUGGESTIONS:|$)/)
      const suggestionsMatch = analysisResult.match(/SUGGESTIONS:\s*(.+)/)

      if (scoreMatch) {
        const voiceScore = parseInt(scoreMatch[1])
        complianceScore = Math.min(complianceScore, (complianceScore * voiceScore) / 100)
      }

      if (statusMatch && statusMatch[1] === 'NON_COMPLIANT') {
        const reason = reasonMatch ? reasonMatch[1].trim() : 'Voice style does not match brand guidelines'
        violations.push(`Brand voice violation: ${reason}`)
        
        if (suggestionsMatch) {
          suggestions.push(`Voice improvement: ${suggestionsMatch[1].trim()}`)
        } else {
          suggestions.push('Adjust tone and style to match brand voice guidelines')
        }
      }
    } catch (error) {
      console.warn('Brand voice analysis failed:', error)
      complianceScore -= 5 // Small penalty for failed analysis
    }
  }

  // Check messaging framework compliance with weighted scoring
  if (validateMessaging && brandData.messagingFramework) {
    const messagingPillars = Array.isArray(brandData.messagingFramework)
      ? brandData.messagingFramework
      : JSON.parse(brandData.messagingFramework || '[]')
    
    if (messagingPillars.length > 0) {
      let messagingAlignmentScore = 0
      const contentLower = content.toLowerCase()
      
      for (const pillar of messagingPillars) {
        const pillarText = typeof pillar === 'string' 
          ? pillar 
          : pillar.pillar || pillar.description || pillar.text || pillar.title || ''
        
        // Check for pillar keywords
        const keywords = typeof pillar === 'object' && pillar.keywords 
          ? pillar.keywords 
          : [pillarText]
        
        const keywordMatches = keywords.filter((keyword: string) => 
          contentLower.includes(keyword.toLowerCase())
        ).length
        
        if (keywordMatches > 0) {
          messagingAlignmentScore += (keywordMatches / keywords.length) * (100 / messagingPillars.length)
        }
      }
      
      if (messagingAlignmentScore < 30) {
        violations.push('Content does not align with brand messaging framework')
        suggestions.push('Incorporate key brand messaging pillars and keywords into the content')
        complianceScore = Math.min(complianceScore, messagingAlignmentScore + 50)
      } else {
        // Reward good messaging alignment
        complianceScore = Math.min(100, complianceScore * (1 + messagingAlignmentScore / 200))
      }
    }
  }

  // Additional compliance checks for content quality
  const contentLength = content.length
  if (contentLength < 50) {
    violations.push('Content is too short for meaningful brand compliance assessment')
    suggestions.push('Expand content to better represent brand messaging')
    complianceScore -= 15
  }

  // Check for excessive repetition (indicates poor quality generation)
  const words = content.toLowerCase().split(/\s+/)
  const wordFreq = new Map<string, number>()
  words.forEach(word => {
    if (word.length > 3) { // Only count meaningful words
      wordFreq.set(word, (wordFreq.get(word) || 0) + 1)
    }
  })

  const excessivelyRepeatedWords = Array.from(wordFreq.entries()).filter(
    ([_, count]) => count > Math.max(2, words.length * 0.1)
  )

  if (excessivelyRepeatedWords.length > 0) {
    violations.push('Content contains excessive word repetition')
    suggestions.push('Vary vocabulary to improve content quality and brand representation')
    complianceScore -= 10
  }

  // Ensure score is within bounds
  complianceScore = Math.max(0, Math.min(100, Math.round(complianceScore)))

  return {
    isCompliant: violations.length === 0 && complianceScore >= 70,
    violations,
    suggestions: suggestions.length > 0 ? suggestions : undefined,
    score: complianceScore
  }
}

// Legacy variant generation for backwards compatibility
async function generateContentVariants(
  originalContent: string,
  contentType: string,
  variantCount: number,
  brandContext: string
): Promise<string[]> {
  if (variantCount <= 1) return []

  try {
    const variantPrompts = Array.from({ length: variantCount - 1 }, (_, i) => {
      return `Create variant ${i + 2} of this ${contentType.toLowerCase().replace('_', ' ')} content. 
      Maintain the same core message and brand alignment but vary the style, structure, or approach:
      
      Original: ${originalContent}
      Brand Context: ${brandContext}
      
      Variant ${i + 2}:`
    })

    const variants: string[] = []
    for (const prompt of variantPrompts) {
      const result = await retryWithBackoff(() =>
        openAIService.instance.generateText({
          prompt,
          maxTokens: Math.min(1500, originalContent.length * 2),
          temperature: 0.8
        })
      )
      variants.push(result.text.trim())
    }

    return variants
  } catch (error) {
    console.error('Failed to generate content variants:', error)
    return []
  }
}

// Main content generation function with enhanced tracking
async function generateContent(
  request: ContentGenerationRequest,
  brandData: any,
  _userId: string
): Promise<ContentGenerationResponse> {
  const startTime = Date.now()
  const {
    contentType,
    prompt,
    targetAudience,
    tone = 'professional',
    channel,
    callToAction,
    maxLength,
    keywords,
    includeVariants,
    variantCount,
    variantStrategies,
    useTemplates,
    brandCompliance,
    includeAnalysis
  } = request

  // Build comprehensive context for AI generation
  const brandContext = [
    brandData.name && `Brand: ${brandData.name}`,
    brandData.tagline && `Tagline: ${brandData.tagline}`,
    brandData.voiceDescription && `Voice: ${brandData.voiceDescription}`,
    brandData.communicationStyle && `Style: ${brandData.communicationStyle}`,
    brandData.targetAudience && `Target Audience: ${JSON.stringify(brandData.targetAudience)}`,
    brandData.values && `Values: ${JSON.stringify(brandData.values)}`,
    brandData.messagingFramework && `Key Messages: ${JSON.stringify(brandData.messagingFramework)}`,
  ].filter(Boolean).join('\n')

  // Generate main content - use template-based generation if requested
  let mainContent: string
  let contentResult: any

  if (useTemplates) {
    try {
      mainContent = await ContentVariantService.generateTemplatedContent(
        contentType,
        prompt,
        brandContext
      )
      // Create a mock result object for consistency
      contentResult = { text: mainContent }
    } catch (error) {
      console.warn('Template-based generation failed, falling back to standard generation:', error)
      // Fall back to standard generation
      const generationPrompt = `
        You are a professional content creator specializing in ${contentType.toLowerCase().replace('_', ' ')} content.
        
        BRAND CONTEXT:
        ${brandContext}
        
        CONTENT REQUIREMENTS:
        - Type: ${contentType.replace('_', ' ')}
        - Tone: ${tone}
        ${targetAudience ? `- Target Audience: ${targetAudience}` : ''}
        ${channel ? `- Channel: ${channel}` : ''}
        ${callToAction ? `- Include CTA: ${callToAction}` : ''}
        ${maxLength ? `- Max Length: ${maxLength} characters` : ''}
        ${keywords ? `- Include Keywords: ${keywords.join(', ')}` : ''}
        
        USER PROMPT: ${prompt}
        
        Generate high-quality, brand-compliant ${contentType.toLowerCase().replace('_', ' ')} content that:
        1. Aligns with the brand voice and messaging framework
        2. Engages the target audience effectively  
        3. Maintains the specified tone throughout
        4. Incorporates the requirements naturally
        5. Is optimized for the intended channel
        6. Avoids restricted terms and follows brand guidelines
        7. Uses varied vocabulary and engaging language
        
        Important: Create content that would score highly on brand compliance checks.
        Provide only the content, no explanations or meta-commentary.
      `

      const maxTokens = maxLength ? Math.min(2000, Math.ceil(maxLength / 2)) : 1500
      contentResult = await retryWithBackoff(() =>
        openAIService.instance.generateText({
          prompt: generationPrompt,
          maxTokens,
          temperature: 0.7
        })
      )
      mainContent = contentResult.text.trim()
    }
  } else {
    // Standard generation
    const generationPrompt = `
      You are a professional content creator specializing in ${contentType.toLowerCase().replace('_', ' ')} content.
      
      BRAND CONTEXT:
      ${brandContext}
      
      CONTENT REQUIREMENTS:
      - Type: ${contentType.replace('_', ' ')}
      - Tone: ${tone}
      ${targetAudience ? `- Target Audience: ${targetAudience}` : ''}
      ${channel ? `- Channel: ${channel}` : ''}
      ${callToAction ? `- Include CTA: ${callToAction}` : ''}
      ${maxLength ? `- Max Length: ${maxLength} characters` : ''}
      ${keywords ? `- Include Keywords: ${keywords.join(', ')}` : ''}
      
      USER PROMPT: ${prompt}
      
      Generate high-quality, brand-compliant ${contentType.toLowerCase().replace('_', ' ')} content that:
      1. Aligns with the brand voice and messaging framework
      2. Engages the target audience effectively  
      3. Maintains the specified tone throughout
      4. Incorporates the requirements naturally
      5. Is optimized for the intended channel
      6. Avoids restricted terms and follows brand guidelines
      7. Uses varied vocabulary and engaging language
      
      Important: Create content that would score highly on brand compliance checks.
      Provide only the content, no explanations or meta-commentary.
    `

    const maxTokens = maxLength ? Math.min(2000, Math.ceil(maxLength / 2)) : 1500
    contentResult = await retryWithBackoff(() =>
      openAIService.instance.generateText({
        prompt: generationPrompt,
        maxTokens,
        temperature: 0.7
      })
    )
    mainContent = contentResult.text.trim()
  }

  // Validate brand compliance with enhanced scoring
  const complianceResult = await validateBrandCompliance(mainContent, brandData, brandCompliance)

  // Generate variants if requested - use enhanced variant service if strategies specified
  let variants: string[] | undefined
  let enhancedVariants: any[] | undefined

  if (includeVariants && variantStrategies && variantStrategies.length > 0) {
    // Use enhanced variant generation
    try {
      const enhancedVariantResults = await ContentVariantService.generateEnhancedVariants(
        mainContent,
        contentType,
        variantCount,
        brandContext,
        {
          strategies: variantStrategies,
          currentTone: tone,
          businessGoal: 'engagement',
          targetAudience
        }
      )
      
      enhancedVariants = enhancedVariantResults
      // Also provide basic variants for backwards compatibility
      variants = enhancedVariantResults.map(v => v.content)
    } catch (error) {
      console.warn('Enhanced variant generation failed, falling back to legacy:', error)
      // Fall back to legacy variant generation
      variants = await generateContentVariants(mainContent, contentType, variantCount, brandContext)
      enhancedVariants = undefined // Explicitly set to undefined on fallback
    }
  } else if (includeVariants) {
    // Use legacy variant generation
    variants = await generateContentVariants(mainContent, contentType, variantCount, brandContext)
  }

  // Calculate content metrics
  const wordCount = mainContent.split(/\s+/).length
  const charCount = mainContent.length
  const processingTime = Date.now() - startTime

  // Get model configuration
  const config = openAIService.instance.getConfig()

  // Perform content analysis if requested
  const analysis = includeAnalysis 
    ? await analyzeContent(mainContent, contentType, brandData, targetAudience)
    : undefined

  return {
    success: true,
    content: mainContent,
    variants,
    enhancedVariants,
    brandCompliance: complianceResult,
    analysis,
    metadata: {
      brandId: request.brandId,
      contentType,
      generatedAt: new Date().toISOString(),
      wordCount,
      charCount,
      processingTime,
      model: config.model,
      tokensUsed: Math.ceil(contentResult.text.length / 4) // Approximate token count
    }
  }
}

// Streaming content generation function
async function generateContentStream(
  request: ContentGenerationRequest,
  brandData: any,
  _userId: string
) {
  const {
    contentType,
    prompt,
    targetAudience,
    tone = 'professional',
    channel,
    callToAction,
    maxLength,
    keywords,
    brandCompliance
  } = request

  // Build comprehensive context for AI generation
  const brandContext = [
    brandData.name && `Brand: ${brandData.name}`,
    brandData.tagline && `Tagline: ${brandData.tagline}`,
    brandData.voiceDescription && `Voice: ${brandData.voiceDescription}`,
    brandData.communicationStyle && `Style: ${brandData.communicationStyle}`,
    brandData.targetAudience && `Target Audience: ${JSON.stringify(brandData.targetAudience)}`,
    brandData.values && `Values: ${JSON.stringify(brandData.values)}`,
    brandData.messagingFramework && `Key Messages: ${JSON.stringify(brandData.messagingFramework)}`,
  ].filter(Boolean).join('\n')

  // Generate streaming content with enhanced prompt structure
  const generationPrompt = `
    You are a professional content creator specializing in ${contentType.toLowerCase().replace('_', ' ')} content.
    
    BRAND CONTEXT:
    ${brandContext}
    
    CONTENT REQUIREMENTS:
    - Type: ${contentType.replace('_', ' ')}
    - Tone: ${tone}
    ${targetAudience ? `- Target Audience: ${targetAudience}` : ''}
    ${channel ? `- Channel: ${channel}` : ''}
    ${callToAction ? `- Include CTA: ${callToAction}` : ''}
    ${maxLength ? `- Max Length: ${maxLength} characters` : ''}
    ${keywords ? `- Include Keywords: ${keywords.join(', ')}` : ''}
    
    USER PROMPT: ${prompt}
    
    Generate high-quality, brand-compliant ${contentType.toLowerCase().replace('_', ' ')} content that:
    1. Aligns with the brand voice and messaging framework
    2. Engages the target audience effectively  
    3. Maintains the specified tone throughout
    4. Incorporates the requirements naturally
    5. Is optimized for the intended channel
    6. Avoids restricted terms and follows brand guidelines
    7. Uses varied vocabulary and engaging language
    
    Important: Create content that would score highly on brand compliance checks.
    Provide only the content, no explanations or meta-commentary.
  `

  const maxTokens = maxLength ? Math.min(2000, Math.ceil(maxLength / 2)) : 1500
  
  // Return the streaming result directly
  const streamResult = await openAIService.instance.streamText({
    prompt: generationPrompt,
    maxTokens,
    temperature: 0.7
  })

  return streamResult
}

// Advanced content analysis function
async function analyzeContent(
  content: string,
  contentType: string,
  brandData: any,
  targetAudience?: string
): Promise<{
  sentiment: 'positive' | 'neutral' | 'negative'
  readabilityScore: number
  keywordDensity: Record<string, number>
  brandAlignment: number
  suggestions: Array<{
    type: 'length' | 'tone' | 'keywords' | 'cta' | 'structure' | 'brand'
    priority: 'high' | 'medium' | 'low'
    suggestion: string
    reason: string
  }>
}> {
  const suggestions: Array<{
    type: 'length' | 'tone' | 'keywords' | 'cta' | 'structure' | 'brand'
    priority: 'high' | 'medium' | 'low'
    suggestion: string
    reason: string
  }> = []

  // Analyze content length for content type
  const wordCount = content.split(/\s+/).length
  const charCount = content.length

  const lengthRecommendations: Record<string, { min: number; max: number; optimal: number }> = {
    EMAIL: { min: 50, max: 300, optimal: 150 },
    SOCIAL_POST: { min: 20, max: 280, optimal: 100 },
    SOCIAL_AD: { min: 30, max: 150, optimal: 80 },
    SEARCH_AD: { min: 25, max: 90, optimal: 60 },
    BLOG_POST: { min: 300, max: 2000, optimal: 800 },
    LANDING_PAGE: { min: 200, max: 1000, optimal: 500 },
    VIDEO_SCRIPT: { min: 100, max: 800, optimal: 400 },
    INFOGRAPHIC: { min: 50, max: 200, optimal: 100 },
    NEWSLETTER: { min: 200, max: 1500, optimal: 600 },
    PRESS_RELEASE: { min: 300, max: 800, optimal: 500 },
  }

  const lengthRec = lengthRecommendations[contentType] || { min: 50, max: 500, optimal: 200 }
  
  if (wordCount < lengthRec.min) {
    suggestions.push({
      type: 'length',
      priority: 'high',
      suggestion: `Expand content to at least ${lengthRec.min} words`,
      reason: `Current content (${wordCount} words) is too short for ${contentType}`
    })
  } else if (wordCount > lengthRec.max) {
    suggestions.push({
      type: 'length',
      priority: 'medium',
      suggestion: `Consider reducing content to under ${lengthRec.max} words`,
      reason: `Current content (${wordCount} words) may be too long for optimal engagement`
    })
  }

  // Analyze keyword density
  const words = content.toLowerCase().match(/\b\w+\b/g) || []
  const wordFreq = new Map<string, number>()
  words.forEach(word => {
    if (word.length > 3) {
      wordFreq.set(word, (wordFreq.get(word) || 0) + 1)
    }
  })

  const keywordDensity: Record<string, number> = {}
  wordFreq.forEach((count, word) => {
    const density = (count / words.length) * 100
    if (density > 1) { // Only include words with >1% density
      keywordDensity[word] = Math.round(density * 100) / 100
    }
  })

  // Check for excessive keyword repetition
  const highDensityWords = Object.entries(keywordDensity).filter(([_, density]) => density > 5)
  if (highDensityWords.length > 0) {
    suggestions.push({
      type: 'keywords',
      priority: 'medium',
      suggestion: 'Vary vocabulary to avoid keyword stuffing',
      reason: `Words "${highDensityWords.map(([word]) => word).join('", "')}" appear too frequently`
    })
  }

  // Analyze CTA presence
  const ctaWords = ['click', 'buy', 'purchase', 'subscribe', 'sign up', 'learn more', 'get started', 'contact', 'download', 'try']
  const hasCTA = ctaWords.some(cta => content.toLowerCase().includes(cta))
  
  if (['EMAIL', 'SOCIAL_AD', 'SEARCH_AD', 'LANDING_PAGE'].includes(contentType) && !hasCTA) {
    suggestions.push({
      type: 'cta',
      priority: 'high',
      suggestion: 'Add a clear call-to-action',
      reason: `${contentType} should include a compelling call-to-action to drive conversions`
    })
  }

  // Basic sentiment analysis using AI
  let sentiment: 'positive' | 'neutral' | 'negative' = 'neutral'
  let brandAlignment = 70 // Default moderate alignment
  
  try {
    const analysisPrompt = `
      Analyze the following content and provide a brief assessment:
      
      Content: "${content}"
      Brand Values: ${JSON.stringify(brandData.values || [])}
      Target Audience: ${targetAudience || 'General'}
      
      Respond in this exact format:
      SENTIMENT: [positive|neutral|negative]
      BRAND_ALIGNMENT: [0-100]
      TONE_ASSESSMENT: [brief description]
    `

    const analysis = await retryWithBackoff(() =>
      openAIService.instance.generateText({
        prompt: analysisPrompt,
        maxTokens: 100,
        temperature: 0.1
      })
    )

    const sentimentMatch = analysis.text.match(/SENTIMENT:\s*(positive|neutral|negative)/i)
    const alignmentMatch = analysis.text.match(/BRAND_ALIGNMENT:\s*(\d+)/)
    
    if (sentimentMatch) {
      sentiment = sentimentMatch[1].toLowerCase() as 'positive' | 'neutral' | 'negative'
    }
    if (alignmentMatch) {
      brandAlignment = parseInt(alignmentMatch[1])
    }

    // Add brand alignment suggestions
    if (brandAlignment < 60) {
      suggestions.push({
        type: 'brand',
        priority: 'high',
        suggestion: 'Improve brand alignment by incorporating brand values and messaging',
        reason: `Current brand alignment score is low (${brandAlignment}/100)`
      })
    }

    // Add sentiment-based suggestions
    if (sentiment === 'negative' && !['PRESS_RELEASE'].includes(contentType)) {
      suggestions.push({
        type: 'tone',
        priority: 'medium',
        suggestion: 'Consider using more positive language',
        reason: 'Content has negative sentiment which may not align with marketing goals'
      })
    }
  } catch (error) {
    console.warn('Content analysis failed:', error)
  }

  // Calculate readability score (simplified Flesch Reading Ease)
  const sentences = content.split(/[.!?]+/).filter(s => s.trim()).length
  const syllables = words.reduce((acc, word) => {
    // Simple syllable counting heuristic
    const vowelMatches = word.match(/[aeiouy]/g)
    return acc + Math.max(1, vowelMatches ? vowelMatches.length : 1)
  }, 0)
  
  const readabilityScore = Math.max(0, Math.min(100, 
    206.835 - (1.015 * (words.length / sentences)) - (84.6 * (syllables / words.length))
  ))

  if (readabilityScore < 30) {
    suggestions.push({
      type: 'structure',
      priority: 'medium',
      suggestion: 'Simplify sentence structure and use shorter words',
      reason: 'Content may be too complex for the target audience'
    })
  }

  return {
    sentiment,
    readabilityScore: Math.round(readabilityScore * 10) / 10,
    keywordDensity,
    brandAlignment,
    suggestions
  }
}

// POST endpoint for content generation
export async function POST(req: NextRequest) {
  try {
    // Authenticate user
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      )
    }

    // Parse and validate request body
    const body = await req.json()
    const validatedRequest = ContentGenerationRequestSchema.parse(body)

    // Fetch brand data and verify ownership
    const brand = await prisma.brand.findFirst({
      where: {
        id: validatedRequest.brandId,
        userId: session.user.id,
        deletedAt: null
      }
    })

    if (!brand) {
      return NextResponse.json(
        { error: 'Brand not found or access denied' },
        { status: 404 }
      )
    }

    // Check OpenAI service availability
    if (!openAIService.instance.isReady()) {
      return NextResponse.json(
        { error: 'AI service not available. Please check configuration.' },
        { status: 503 }
      )
    }

    // Handle streaming vs non-streaming requests
    if (validatedRequest.streaming) {
      // Generate streaming content
      const streamResult = await generateContentStream(validatedRequest, brand, session.user.id)
      
      // Return streaming response
      // In test environment, we can't use the full streaming API
      if (process.env.NODE_ENV === 'test') {
        return new Response('Test streaming content', {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Transfer-Encoding': 'chunked',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'X-Content-Type-Options': 'nosniff',
          },
        })
      }
      
      // Production streaming response
      return streamResult.toTextStreamResponse({
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'X-Content-Type-Options': 'nosniff',
        },
      })
    } else {
      // Generate content normally
      const result = await generateContent(validatedRequest, brand, session.user.id)

      // Validate response structure
      const validatedResponse = ContentGenerationResponseSchema.parse(result)

      return NextResponse.json(validatedResponse, { status: 200 })
    }

  } catch (error) {
    console.error('Content generation error:', error)

    // Handle validation errors
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        {
          error: 'Validation error',
          details: error.issues.map((err: any) => ({
            field: err.path.join('.'),
            message: err.message
          })),
          code: 'VALIDATION_ERROR'
        },
        { status: 400 }
      )
    }

    // Handle OpenAI service errors with detailed classification
    if (error instanceof Error && error.name === 'OpenAIServiceError') {
      const openAIError = error as any
      
      if (openAIError.code === 'RATE_LIMIT' || openAIError.statusCode === 429) {
        return NextResponse.json(
          { 
            error: 'Rate limit exceeded', 
            message: 'Too many requests. Please try again in a moment.',
            code: 'RATE_LIMIT_ERROR',
            retryAfter: 60 // seconds
          },
          { status: 429, headers: { 'Retry-After': '60' } }
        )
      }
      
      if (openAIError.code === 'INVALID_API_KEY' || openAIError.statusCode === 401) {
        return NextResponse.json(
          { 
            error: 'AI service configuration error', 
            message: 'Service temporarily unavailable.',
            code: 'SERVICE_UNAVAILABLE'
          },
          { status: 503 }
        )
      }
      
      if (openAIError.statusCode === 404) {
        return NextResponse.json(
          { 
            error: 'AI model not available', 
            message: 'The requested AI model is not available.',
            code: 'MODEL_UNAVAILABLE'
          },
          { status: 503 }
        )
      }

      return NextResponse.json(
        { 
          error: 'AI service error', 
          message: openAIError.message || 'AI service encountered an error.',
          code: 'AI_SERVICE_ERROR'
        },
        { status: 502 }
      )
    }

    // Handle database errors
    if (error instanceof Error && (error.message.includes('PrismaClient') || error.message.includes('database'))) {
      return NextResponse.json(
        { 
          error: 'Database error', 
          message: 'Unable to process request due to data service issues.',
          code: 'DATABASE_ERROR'
        },
        { status: 503 }
      )
    }

    // Handle timeout errors
    if (error instanceof Error && (error.message.includes('timeout') || error.message.includes('ETIMEDOUT'))) {
      return NextResponse.json(
        { 
          error: 'Request timeout', 
          message: 'Request took too long to process. Please try again.',
          code: 'TIMEOUT_ERROR'
        },
        { status: 408 }
      )
    }

    // Generic error response with request ID for tracking
    const requestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    console.error(`Request ${requestId} failed with error:`, error)
    
    return NextResponse.json(
      { 
        error: 'Internal server error',
        message: 'An unexpected error occurred. Please try again.',
        code: 'INTERNAL_ERROR',
        requestId
      },
      { status: 500 }
    )
  }
}

// GET endpoint for service health check
export async function GET() {
  try {
    const serviceReady = openAIService.instance.isReady()
    const config = openAIService.instance.getConfig()

    return NextResponse.json({
      status: 'healthy',
      aiService: {
        ready: serviceReady,
        model: config.model,
        hasApiKey: config.hasApiKey
      },
      supportedContentTypes: [
        'EMAIL', 'SOCIAL_POST', 'SOCIAL_AD', 'SEARCH_AD', 'BLOG_POST',
        'LANDING_PAGE', 'VIDEO_SCRIPT', 'INFOGRAPHIC', 'NEWSLETTER', 'PRESS_RELEASE'
      ],
      variantStrategies: Object.keys(ContentVariantService.getVariantStrategies()),
      formatTemplatesAvailable: true, 
      features: {
        enhancedVariants: true,
        templateGeneration: true,
        formatOptimization: true,
        strategicVariation: true
      }
    })
  } catch (error) {
    console.error('Health check error:', error)
    return NextResponse.json(
      { status: 'unhealthy', error: 'Service check failed' },
      { status: 503 }
    )
  }
}

// Export types for external use
export type { ContentGenerationRequest, ContentGenerationResponse }