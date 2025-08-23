import { z } from 'zod'

// Content type enumeration matching Prisma schema
export const ContentType = {
  EMAIL: 'EMAIL',
  SOCIAL_POST: 'SOCIAL_POST',
  SOCIAL_AD: 'SOCIAL_AD',
  SEARCH_AD: 'SEARCH_AD',
  BLOG_POST: 'BLOG_POST',
  LANDING_PAGE: 'LANDING_PAGE',
  VIDEO_SCRIPT: 'VIDEO_SCRIPT',
  INFOGRAPHIC: 'INFOGRAPHIC',
  NEWSLETTER: 'NEWSLETTER',
  PRESS_RELEASE: 'PRESS_RELEASE',
} as const

export type ContentTypeKey = keyof typeof ContentType
export type ContentTypeValue = typeof ContentType[ContentTypeKey]

// Tone options for content generation
export const ToneOption = {
  PROFESSIONAL: 'professional',
  CASUAL: 'casual',
  FRIENDLY: 'friendly',
  AUTHORITATIVE: 'authoritative',
  PLAYFUL: 'playful',
  URGENT: 'urgent',
} as const

export type ToneOptionKey = keyof typeof ToneOption
export type ToneOptionValue = typeof ToneOption[ToneOptionKey]

// Brand compliance configuration
export interface BrandComplianceConfig {
  enforceBrandVoice: boolean
  checkRestrictedTerms: boolean
  validateMessaging: boolean
}

// Brand compliance result
export interface BrandComplianceResult {
  isCompliant: boolean
  violations: string[]
  suggestions?: string[]
  score?: number // 0-100 compliance score
}

// Content generation request interface
export interface ContentGenerationRequest {
  brandId: string
  contentType: ContentTypeValue
  prompt: string
  targetAudience?: string
  tone?: ToneOptionValue
  channel?: string
  callToAction?: string
  includeVariants?: boolean
  variantCount?: number
  maxLength?: number
  keywords?: string[]
  brandCompliance?: BrandComplianceConfig
}

// Content generation response interface
export interface ContentGenerationResponse {
  success: boolean
  content: string
  variants?: string[]
  brandCompliance: BrandComplianceResult
  metadata: ContentGenerationMetadata
  error?: string
}

// Content metadata interface
export interface ContentGenerationMetadata {
  brandId: string
  contentType: string
  generatedAt: string
  wordCount: number
  charCount: number
  processingTime?: number
  model?: string
  tokensUsed?: number
}

// Content analysis result
export interface ContentAnalysisResult {
  sentiment: 'positive' | 'neutral' | 'negative'
  readabilityScore: number
  keywordDensity: Record<string, number>
  brandAlignment: number // 0-100
  suggestions: string[]
}

// Content optimization suggestions
export interface ContentOptimizationSuggestion {
  type: 'length' | 'tone' | 'keywords' | 'cta' | 'structure' | 'brand'
  priority: 'high' | 'medium' | 'low'
  suggestion: string
  reason: string
}

// Content template interface
export interface ContentTemplate {
  id: string
  type: ContentTypeValue
  name: string
  description?: string
  template: string
  variables: string[]
  category?: string
  isActive: boolean
  createdAt: string
  updatedAt: string
}

// Content variant interface
export interface ContentVariant {
  id: string
  content: string
  strategy: 'style_variation' | 'length_variation' | 'angle_variation' | 'tone_variation' | 'cta_variation'
  score?: number
  metrics?: {
    estimatedEngagement: number
    readabilityScore: number
    brandAlignment: number
    formatOptimization: number
  }
  formatOptimizations?: {
    platform?: string
    characterCount: number
    wordCount: number
    hasHashtags?: boolean
    hasCTA?: boolean
    keywordDensity: Record<string, number>
  }
}

// Brand context for content generation
export interface BrandContext {
  name: string
  tagline?: string
  voiceDescription?: string
  communicationStyle?: string
  toneAttributes?: Record<string, any>
  targetAudience?: Record<string, any>
  values?: string[]
  messagingFramework?: Array<{
    pillar: string
    description: string
    keywords: string[]
  }>
  restrictedTerms?: string[]
  complianceRules?: Array<{
    rule: string
    severity: 'error' | 'warning'
    description: string
  }>
}

// Content generation options
export interface ContentGenerationOptions {
  temperature?: number
  maxTokens?: number
  model?: string
  includeAnalysis?: boolean
  optimizeForPlatform?: string
  includeMetrics?: boolean
  validateCompliance?: boolean
  variantStrategies?: Array<'style_variation' | 'length_variation' | 'angle_variation' | 'tone_variation' | 'cta_variation'>
  formatTemplates?: boolean
}

// Content export format
export interface ContentExport {
  content: string
  metadata: ContentGenerationMetadata
  brandInfo: {
    name: string
    id: string
  }
  exportedAt: string
  format: 'json' | 'text' | 'html' | 'markdown'
}

// Validation schemas using Zod
export const ContentGenerationRequestSchema = z.object({
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
  maxLength: z.number().min(50).max(5000).optional(),
  keywords: z.array(z.string()).max(10).optional(),
  brandCompliance: z.object({
    enforceBrandVoice: z.boolean().default(true),
    checkRestrictedTerms: z.boolean().default(true),
    validateMessaging: z.boolean().default(true),
  }).optional(),
})

export const ContentGenerationResponseSchema = z.object({
  success: z.boolean(),
  content: z.string(),
  variants: z.array(z.string()).optional(),
  brandCompliance: z.object({
    isCompliant: z.boolean(),
    violations: z.array(z.string()),
    suggestions: z.array(z.string()).optional(),
    score: z.number().min(0).max(100).optional(),
  }),
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
  error: z.string().optional(),
})

export const BrandContextSchema = z.object({
  name: z.string(),
  tagline: z.string().optional(),
  voiceDescription: z.string().optional(),
  communicationStyle: z.string().optional(),
  toneAttributes: z.record(z.string(), z.any()).optional(),
  targetAudience: z.record(z.string(), z.any()).optional(),
  values: z.array(z.string()).optional(),
  messagingFramework: z.array(z.object({
    pillar: z.string(),
    description: z.string(),
    keywords: z.array(z.string()),
  })).optional(),
  restrictedTerms: z.array(z.string()).optional(),
  complianceRules: z.array(z.object({
    rule: z.string(),
    severity: z.enum(['error', 'warning']),
    description: z.string(),
  })).optional(),
})

// Type exports
export type {
  BrandContext as BrandContextType,
  ContentGenerationRequest as ContentGenerationRequestType,
  ContentGenerationResponse as ContentGenerationResponseType,
}

// Helper functions
export const getContentTypeDisplayName = (type: ContentTypeValue): string => {
  const displayNames: Record<ContentTypeValue, string> = {
    [ContentType.EMAIL]: 'Email',
    [ContentType.SOCIAL_POST]: 'Social Media Post',
    [ContentType.SOCIAL_AD]: 'Social Media Ad',
    [ContentType.SEARCH_AD]: 'Search Ad',
    [ContentType.BLOG_POST]: 'Blog Post',
    [ContentType.LANDING_PAGE]: 'Landing Page',
    [ContentType.VIDEO_SCRIPT]: 'Video Script',
    [ContentType.INFOGRAPHIC]: 'Infographic',
    [ContentType.NEWSLETTER]: 'Newsletter',
    [ContentType.PRESS_RELEASE]: 'Press Release',
  }
  return displayNames[type] || type
}

export const getToneDisplayName = (tone: ToneOptionValue): string => {
  const displayNames: Record<ToneOptionValue, string> = {
    [ToneOption.PROFESSIONAL]: 'Professional',
    [ToneOption.CASUAL]: 'Casual',
    [ToneOption.FRIENDLY]: 'Friendly',
    [ToneOption.AUTHORITATIVE]: 'Authoritative',
    [ToneOption.PLAYFUL]: 'Playful',
    [ToneOption.URGENT]: 'Urgent',
  }
  return displayNames[tone] || tone
}

// Format-specific templates and optimizations
export interface ContentFormatTemplate {
  type: ContentTypeValue
  name: string
  template: string
  placeholders: string[]
  optimizations: {
    maxCharacters: number
    maxWords: number
    requiredElements: string[]
    bestPractices: string[]
    platforms?: string[]
  }
  examples: string[]
}

// Variant generation strategies
export interface VariantStrategy {
  name: 'style_variation' | 'length_variation' | 'angle_variation' | 'tone_variation' | 'cta_variation'
  description: string
  prompt: string
  temperature: number
  maxTokens?: number
}

// Brand compliance config validation schema
export const BrandComplianceConfigSchema = z.object({
  enforceBrandVoice: z.boolean().default(true),
  checkRestrictedTerms: z.boolean().default(true),
  validateMessaging: z.boolean().default(true)
})

export const validateContentLength = (content: string, type: ContentTypeValue): { isValid: boolean; message?: string } => {
  const limits: Record<ContentTypeValue, { min: number; max: number }> = {
    [ContentType.EMAIL]: { min: 100, max: 3000 },
    [ContentType.SOCIAL_POST]: { min: 20, max: 280 },
    [ContentType.SOCIAL_AD]: { min: 30, max: 150 },
    [ContentType.SEARCH_AD]: { min: 25, max: 90 },
    [ContentType.BLOG_POST]: { min: 300, max: 5000 },
    [ContentType.LANDING_PAGE]: { min: 200, max: 2000 },
    [ContentType.VIDEO_SCRIPT]: { min: 100, max: 1500 },
    [ContentType.INFOGRAPHIC]: { min: 50, max: 500 },
    [ContentType.NEWSLETTER]: { min: 200, max: 4000 },
    [ContentType.PRESS_RELEASE]: { min: 300, max: 1500 },
  }

  const limit = limits[type]
  const length = content.length

  if (length < limit.min) {
    return { isValid: false, message: `Content too short. Minimum ${limit.min} characters required.` }
  }

  if (length > limit.max) {
    return { isValid: false, message: `Content too long. Maximum ${limit.max} characters allowed.` }
  }

  return { isValid: true }
}