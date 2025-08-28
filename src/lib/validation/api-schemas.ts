import { z } from 'zod'

// Common validation schemas
export const commonSchemas = {
  id: z.string().cuid('Invalid ID format'),
  email: z.string().email('Invalid email format'),
  url: z.string().url('Invalid URL format').or(z.literal('')),
  pagination: z.object({
    page: z.string().optional().transform(val => val ? parseInt(val, 10) : 1),
    limit: z.string().optional().transform(val => val ? Math.min(parseInt(val, 10), 100) : 10),
    search: z.string().optional(),
  }),
  timestamp: z.string().datetime('Invalid timestamp format'),
  uuid: z.string().uuid('Invalid UUID format'),
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'Invalid slug format'),
  color: z.string().regex(/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/, 'Invalid color format'),
}

// Request validation schemas
export const requestSchemas = {
  // Query parameters
  paginationQuery: z.object({
    page: z.string().optional().transform(val => val ? Math.max(1, parseInt(val, 10)) : 1),
    limit: z.string().optional().transform(val => val ? Math.min(Math.max(1, parseInt(val, 10)), 100) : 10),
    search: z.string().optional(),
    sort: z.enum(['asc', 'desc']).optional(),
    sortBy: z.string().optional(),
  }),

  // Brand schemas
  createBrand: z.object({
    name: z.string().min(1, 'Brand name is required').max(100, 'Brand name too long'),
    description: z.string().max(500, 'Description too long').optional(),
    industry: z.string().max(100, 'Industry name too long').optional(),
    website: commonSchemas.url.optional(),
    tagline: z.string().max(200, 'Tagline too long').optional(),
    mission: z.string().max(1000, 'Mission statement too long').optional(),
    vision: z.string().max(1000, 'Vision statement too long').optional(),
    values: z.array(z.string().max(100, 'Value too long')).max(10, 'Too many values').optional(),
    personality: z.array(z.string().max(50, 'Personality trait too long')).max(20, 'Too many personality traits').optional(),
    voiceDescription: z.string().max(1000, 'Voice description too long').optional(),
    toneAttributes: z.record(z.string(), z.number().min(0).max(10)).optional(),
    communicationStyle: z.string().max(500, 'Communication style too long').optional(),
    messagingFramework: z.record(z.string(), z.any()).optional(),
    brandPillars: z.array(z.string().max(100, 'Brand pillar too long')).max(5, 'Too many brand pillars').optional(),
    targetAudience: z.record(z.string(), z.any()).optional(),
    competitivePosition: z.string().max(1000, 'Competitive position too long').optional(),
    brandPromise: z.string().max(500, 'Brand promise too long').optional(),
    complianceRules: z.record(z.string(), z.any()).optional(),
    usageGuidelines: z.record(z.string(), z.any()).optional(),
    restrictedTerms: z.array(z.string().max(50, 'Restricted term too long')).max(100, 'Too many restricted terms').optional(),
  }),

  updateBrand: z.object({
    name: z.string().min(1, 'Brand name is required').max(100, 'Brand name too long').optional(),
    description: z.string().max(500, 'Description too long').optional(),
    industry: z.string().max(100, 'Industry name too long').optional(),
    website: commonSchemas.url.optional(),
    tagline: z.string().max(200, 'Tagline too long').optional(),
    mission: z.string().max(1000, 'Mission statement too long').optional(),
    vision: z.string().max(1000, 'Vision statement too long').optional(),
    values: z.array(z.string().max(100, 'Value too long')).max(10, 'Too many values').optional(),
    personality: z.array(z.string().max(50, 'Personality trait too long')).max(20, 'Too many personality traits').optional(),
    voiceDescription: z.string().max(1000, 'Voice description too long').optional(),
    toneAttributes: z.record(z.string(), z.number().min(0).max(10)).optional(),
    communicationStyle: z.string().max(500, 'Communication style too long').optional(),
    messagingFramework: z.record(z.string(), z.any()).optional(),
    brandPillars: z.array(z.string().max(100, 'Brand pillar too long')).max(5, 'Too many brand pillars').optional(),
    targetAudience: z.record(z.string(), z.any()).optional(),
    competitivePosition: z.string().max(1000, 'Competitive position too long').optional(),
    brandPromise: z.string().max(500, 'Brand promise too long').optional(),
    complianceRules: z.record(z.string(), z.any()).optional(),
    usageGuidelines: z.record(z.string(), z.any()).optional(),
    restrictedTerms: z.array(z.string().max(50, 'Restricted term too long')).max(100, 'Too many restricted terms').optional(),
  }),

  // Brand asset schemas
  createBrandAsset: z.object({
    name: z.string().min(1, 'Asset name is required').max(200, 'Asset name too long'),
    description: z.string().max(1000, 'Description too long').optional(),
    type: z.enum(['LOGO', 'COLOR_PALETTE', 'TYPOGRAPHY', 'IMAGE', 'DOCUMENT', 'BRAND_GUIDELINES', 'OTHER']),
    category: z.string().max(100, 'Category name too long').optional(),
    fileUrl: z.string().url('Invalid file URL').optional(),
    filePath: z.string().optional(),
    fileName: z.string().max(255, 'File name too long').optional(),
    fileSize: z.number().positive('File size must be positive').optional(),
    mimeType: z.string().max(100, 'MIME type too long').optional(),
    metadata: z.record(z.string(), z.any()).optional(),
    tags: z.array(z.string().max(50, 'Tag too long')).max(20, 'Too many tags').optional(),
    isActive: z.boolean().optional().default(true),
  }),

  updateBrandAsset: z.object({
    name: z.string().min(1, 'Asset name is required').max(200, 'Asset name too long').optional(),
    description: z.string().max(1000, 'Description too long').optional(),
    type: z.enum(['LOGO', 'COLOR_PALETTE', 'TYPOGRAPHY', 'IMAGE', 'DOCUMENT', 'BRAND_GUIDELINES', 'OTHER']).optional(),
    category: z.string().max(100, 'Category name too long').optional(),
    metadata: z.record(z.string(), z.any()).optional(),
    tags: z.array(z.string().max(50, 'Tag too long')).max(20, 'Too many tags').optional(),
    isActive: z.boolean().optional(),
  }),

  // Campaign schemas
  createCampaign: z.object({
    name: z.string().min(1, 'Campaign name is required').max(200, 'Campaign name too long'),
    description: z.string().max(1000, 'Description too long').optional(),
    brandId: commonSchemas.id,
    type: z.enum(['EMAIL', 'SOCIAL', 'DISPLAY', 'VIDEO', 'OTHER']),
    status: z.enum(['DRAFT', 'ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED']).optional().default('DRAFT'),
    startDate: z.string().datetime('Invalid start date').optional(),
    endDate: z.string().datetime('Invalid end date').optional(),
    budget: z.number().positive('Budget must be positive').optional(),
    targetAudience: z.record(z.string(), z.any()).optional(),
    goals: z.array(z.string().max(200, 'Goal too long')).max(10, 'Too many goals').optional(),
    kpis: z.record(z.string(), z.any()).optional(),
    content: z.record(z.string(), z.any()).optional(),
    settings: z.record(z.string(), z.any()).optional(),
  }),

  updateCampaign: z.object({
    name: z.string().min(1, 'Campaign name is required').max(200, 'Campaign name too long').optional(),
    description: z.string().max(1000, 'Description too long').optional(),
    type: z.enum(['EMAIL', 'SOCIAL', 'DISPLAY', 'VIDEO', 'OTHER']).optional(),
    status: z.enum(['DRAFT', 'ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED']).optional(),
    startDate: z.string().datetime('Invalid start date').optional(),
    endDate: z.string().datetime('Invalid end date').optional(),
    budget: z.number().positive('Budget must be positive').optional(),
    targetAudience: z.record(z.string(), z.any()).optional(),
    goals: z.array(z.string().max(200, 'Goal too long')).max(10, 'Too many goals').optional(),
    kpis: z.record(z.string(), z.any()).optional(),
    content: z.record(z.string(), z.any()).optional(),
    settings: z.record(z.string(), z.any()).optional(),
  }),

  // Journey template schemas
  createJourneyTemplate: z.object({
    name: z.string().min(1, 'Template name is required').max(200, 'Template name too long'),
    description: z.string().max(1000, 'Description too long').optional(),
    category: z.string().max(100, 'Category name too long').optional(),
    industry: z.string().max(100, 'Industry name too long').optional(),
    targetAudience: z.string().max(200, 'Target audience too long').optional(),
    difficulty: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']).optional().default('BEGINNER'),
    estimatedDuration: z.number().positive('Duration must be positive').optional(),
    steps: z.array(z.object({
      title: z.string().min(1, 'Step title is required').max(200, 'Step title too long'),
      description: z.string().max(1000, 'Step description too long').optional(),
      order: z.number().int().positive('Order must be a positive integer'),
      type: z.enum(['EMAIL', 'SOCIAL', 'CONTENT', 'AUTOMATION', 'OTHER']).optional(),
      duration: z.number().positive('Duration must be positive').optional(),
      resources: z.array(z.string().max(500, 'Resource too long')).optional(),
      metadata: z.record(z.string(), z.any()).optional(),
    })).min(1, 'At least one step is required').max(50, 'Too many steps'),
    tags: z.array(z.string().max(50, 'Tag too long')).max(20, 'Too many tags').optional(),
    metadata: z.record(z.string(), z.any()).optional(),
    isPublic: z.boolean().optional().default(false),
  }),

  updateJourneyTemplate: z.object({
    name: z.string().min(1, 'Template name is required').max(200, 'Template name too long').optional(),
    description: z.string().max(1000, 'Description too long').optional(),
    category: z.string().max(100, 'Category name too long').optional(),
    industry: z.string().max(100, 'Industry name too long').optional(),
    targetAudience: z.string().max(200, 'Target audience too long').optional(),
    difficulty: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']).optional(),
    estimatedDuration: z.number().positive('Duration must be positive').optional(),
    steps: z.array(z.object({
      id: commonSchemas.id.optional(),
      title: z.string().min(1, 'Step title is required').max(200, 'Step title too long'),
      description: z.string().max(1000, 'Step description too long').optional(),
      order: z.number().int().positive('Order must be a positive integer'),
      type: z.enum(['EMAIL', 'SOCIAL', 'CONTENT', 'AUTOMATION', 'OTHER']).optional(),
      duration: z.number().positive('Duration must be positive').optional(),
      resources: z.array(z.string().max(500, 'Resource too long')).optional(),
      metadata: z.record(z.string(), z.any()).optional(),
    })).min(1, 'At least one step is required').max(50, 'Too many steps').optional(),
    tags: z.array(z.string().max(50, 'Tag too long')).max(20, 'Too many tags').optional(),
    metadata: z.record(z.string(), z.any()).optional(),
    isPublic: z.boolean().optional(),
  }),

  // Rating schema
  rateTemplate: z.object({
    rating: z.number().int().min(1, 'Rating must be at least 1').max(5, 'Rating must be at most 5'),
    review: z.string().max(1000, 'Review too long').optional(),
  }),

  // Document parsing schema
  parseDocument: z.object({
    fileUrl: z.string().url('Invalid file URL').optional(),
    filePath: z.string().optional(),
    extractionType: z.enum(['BRAND_GUIDELINES', 'COLOR_PALETTE', 'TYPOGRAPHY', 'CONTENT', 'ALL']).optional().default('ALL'),
    options: z.object({
      extractColors: z.boolean().optional().default(true),
      extractTypography: z.boolean().optional().default(true),
      extractContent: z.boolean().optional().default(true),
      extractImages: z.boolean().optional().default(false),
      maxPages: z.number().int().positive('Max pages must be positive').max(100, 'Too many pages').optional(),
    }).optional(),
  }).refine(data => data.fileUrl || data.filePath, {
    message: 'Either fileUrl or filePath must be provided',
  }),

  // Content generation schemas
  generateContent: z.object({
    brandId: commonSchemas.id,
    type: z.enum(['EMAIL', 'SOCIAL_POST', 'BLOG', 'AD_COPY', 'PRODUCT_DESCRIPTION', 'OTHER']),
    prompt: z.string().min(1, 'Prompt is required').max(2000, 'Prompt too long'),
    audience: z.string().max(500, 'Audience description too long').optional(),
    tone: z.enum(['PROFESSIONAL', 'CASUAL', 'FRIENDLY', 'AUTHORITATIVE', 'PLAYFUL', 'EMPATHETIC']).optional(),
    length: z.enum(['SHORT', 'MEDIUM', 'LONG']).optional(),
    includeCompliance: z.boolean().optional().default(true),
    context: z.record(z.string(), z.any()).optional(),
  }),

  // Content compliance schema
  checkCompliance: z.object({
    brandId: commonSchemas.id,
    content: z.string().min(1, 'Content is required').max(10000, 'Content too long'),
    contentType: z.enum(['EMAIL', 'SOCIAL_POST', 'BLOG', 'AD_COPY', 'PRODUCT_DESCRIPTION', 'OTHER']).optional(),
    checkLevel: z.enum(['BASIC', 'STANDARD', 'STRICT']).optional().default('STANDARD'),
  }),
}

// Response validation schemas
export const responseSchemas = {
  success: z.object({
    success: z.boolean(),
    message: z.string().optional(),
    data: z.any().optional(),
  }),

  error: z.object({
    error: z.string(),
    code: z.string().optional(),
    details: z.any().optional(),
    timestamp: z.string().datetime(),
    path: z.string().optional(),
    requestId: z.string().optional(),
  }),

  pagination: z.object({
    page: z.number().int().positive(),
    limit: z.number().int().positive(),
    total: z.number().int().min(0),
    pages: z.number().int().min(0),
  }),

  paginatedResponse: <T extends z.ZodTypeAny>(dataSchema: T) => z.object({
    data: z.array(dataSchema),
    pagination: responseSchemas.pagination,
  }),
}

// Validation helpers
export const validateQuery = <T>(schema: z.ZodSchema<T>, params: URLSearchParams): T => {
  const data: Record<string, string> = {}
  params.forEach((value, key) => {
    data[key] = value
  })
  return schema.parse(data)
}

export const validateBody = async <T>(schema: z.ZodSchema<T>, request: Request): Promise<T> => {
  const body = await request.json()
  return schema.parse(body)
}

export const validateParams = <T>(schema: z.ZodSchema<T>, params: Record<string, string>): T => {
  return schema.parse(params)
}

// Type exports
export type CreateBrandSchema = z.infer<typeof requestSchemas.createBrand>
export type UpdateBrandSchema = z.infer<typeof requestSchemas.updateBrand>
export type CreateBrandAssetSchema = z.infer<typeof requestSchemas.createBrandAsset>
export type UpdateBrandAssetSchema = z.infer<typeof requestSchemas.updateBrandAsset>
export type CreateCampaignSchema = z.infer<typeof requestSchemas.createCampaign>
export type UpdateCampaignSchema = z.infer<typeof requestSchemas.updateCampaign>
export type CreateJourneyTemplateSchema = z.infer<typeof requestSchemas.createJourneyTemplate>
export type UpdateJourneyTemplateSchema = z.infer<typeof requestSchemas.updateJourneyTemplate>
export type RateTemplateSchema = z.infer<typeof requestSchemas.rateTemplate>
export type ParseDocumentSchema = z.infer<typeof requestSchemas.parseDocument>
export type GenerateContentSchema = z.infer<typeof requestSchemas.generateContent>
export type CheckComplianceSchema = z.infer<typeof requestSchemas.checkCompliance>
export type PaginationQuerySchema = z.infer<typeof requestSchemas.paginationQuery>