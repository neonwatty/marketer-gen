import { z } from 'zod'

// Journey stage types
export const JourneyStageType = {
  AWARENESS: 'awareness',
  CONSIDERATION: 'consideration',
  CONVERSION: 'conversion',
  RETENTION: 'retention',
  ADVOCACY: 'advocacy',
} as const

export type JourneyStageTypeKey = keyof typeof JourneyStageType
export type JourneyStageTypeValue = typeof JourneyStageType[JourneyStageTypeKey]

// Journey industry enum matching Prisma schema
export const JourneyIndustry = {
  TECHNOLOGY: 'TECHNOLOGY',
  HEALTHCARE: 'HEALTHCARE',
  FINANCE: 'FINANCE',
  RETAIL: 'RETAIL',
  EDUCATION: 'EDUCATION',
  REAL_ESTATE: 'REAL_ESTATE',
  AUTOMOTIVE: 'AUTOMOTIVE',
  HOSPITALITY: 'HOSPITALITY',
  MANUFACTURING: 'MANUFACTURING',
  CONSULTING: 'CONSULTING',
  NONPROFIT: 'NONPROFIT',
  ECOMMERCE: 'ECOMMERCE',
  SAAS: 'SAAS',
  MEDIA: 'MEDIA',
  FOOD_BEVERAGE: 'FOOD_BEVERAGE',
  FITNESS: 'FITNESS',
  TRAVEL: 'TRAVEL',
  FASHION: 'FASHION',
  LEGAL: 'LEGAL',
  OTHER: 'OTHER',
} as const

export type JourneyIndustryKey = keyof typeof JourneyIndustry
export type JourneyIndustryValue = typeof JourneyIndustry[JourneyIndustryKey]

// Journey category enum matching Prisma schema
export const JourneyCategory = {
  CUSTOMER_ACQUISITION: 'CUSTOMER_ACQUISITION',
  LEAD_NURTURING: 'LEAD_NURTURING',
  CUSTOMER_ONBOARDING: 'CUSTOMER_ONBOARDING',
  RETENTION: 'RETENTION',
  UPSELL_CROSS_SELL: 'UPSELL_CROSS_SELL',
  WIN_BACK: 'WIN_BACK',
  REFERRAL: 'REFERRAL',
  BRAND_AWARENESS: 'BRAND_AWARENESS',
  PRODUCT_LAUNCH: 'PRODUCT_LAUNCH',
  EVENT_PROMOTION: 'EVENT_PROMOTION',
  SEASONAL_CAMPAIGN: 'SEASONAL_CAMPAIGN',
  CRISIS_COMMUNICATION: 'CRISIS_COMMUNICATION',
} as const

export type JourneyCategoryKey = keyof typeof JourneyCategory
export type JourneyCategoryValue = typeof JourneyCategory[JourneyCategoryKey]

// Journey stage configuration interface
export interface JourneyStageConfig {
  id: string
  type: JourneyStageTypeValue
  title: string
  description: string
  position: { x: number; y: number }
  contentTypes: string[]
  messagingSuggestions: string[]
  channels?: string[]
  objectives?: string[]
  metrics?: string[]
  duration?: number // Duration in days
  automations?: JourneyAutomation[]
}

// Journey automation configuration
export interface JourneyAutomation {
  id: string
  trigger: 'time_delay' | 'user_action' | 'behavior' | 'attribute' | 'custom'
  conditions: JourneyCondition[]
  actions: JourneyAction[]
  isActive: boolean
}

// Journey condition for automation logic
export interface JourneyCondition {
  field: string
  operator: 'equals' | 'not_equals' | 'contains' | 'greater_than' | 'less_than' | 'in' | 'not_in'
  value: any
  logicalOperator?: 'AND' | 'OR'
}

// Journey action for automation
export interface JourneyAction {
  type: 'send_email' | 'send_sms' | 'create_task' | 'update_attribute' | 'add_tag' | 'remove_tag' | 'wait'
  config: Record<string, any>
}

// Journey template interface
export interface JourneyTemplate {
  id: string
  name: string
  description?: string
  industry: JourneyIndustryValue
  category: JourneyCategoryValue
  stages: JourneyStageConfig[]
  metadata?: JourneyTemplateMetadata
  isActive: boolean
  isPublic: boolean
  customizationConfig?: JourneyCustomizationConfig
  defaultSettings?: JourneyDefaultSettings
  usageCount: number
  rating?: number
  ratingCount: number
  createdAt: string
  updatedAt: string
  createdBy?: string
  updatedBy?: string
}

// Journey template metadata
export interface JourneyTemplateMetadata {
  tags?: string[]
  difficulty?: 'beginner' | 'intermediate' | 'advanced'
  estimatedDuration?: number // Duration in days
  requiredChannels?: string[]
  targetAudience?: string[]
  businessGoals?: string[]
  kpis?: string[]
  bestPractices?: string[]
  customizations?: string[]
}

// Journey customization configuration
export interface JourneyCustomizationConfig {
  allowStageReordering: boolean
  allowStageAddition: boolean
  allowStageDeletion: boolean
  editableFields: string[]
  requiredFields: string[]
  customFieldOptions?: Record<string, any[]>
  industrySpecificOptions?: Record<string, any>
}

// Journey default settings
export interface JourneyDefaultSettings {
  timezone?: string
  workingHours?: { start: string; end: string }
  workingDays?: number[]
  defaultChannels?: string[]
  brandCompliance?: boolean
  autoOptimization?: boolean
  trackingSettings?: {
    enableAnalytics: boolean
    trackConversions: boolean
    customEvents?: string[]
  }
}

// Journey instance (created from template)
export interface JourneyInstance {
  id: string
  templateId?: string
  campaignId: string
  name: string
  status: 'DRAFT' | 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'CANCELLED'
  stages: JourneyStageConfig[]
  settings: JourneyDefaultSettings
  customizations?: Record<string, any>
  createdAt: string
  updatedAt: string
  createdBy?: string
  updatedBy?: string
}

// Journey performance metrics
export interface JourneyMetrics {
  templateId?: string
  journeyId: string
  totalParticipants: number
  completionRate: number
  conversionRate: number
  averageCompletionTime: number
  stageMetrics: {
    [stageId: string]: {
      entranceCount: number
      exitCount: number
      conversionRate: number
      averageTimeSpent: number
    }
  }
  channelPerformance: Record<string, {
    opens: number
    clicks: number
    conversions: number
    engagementRate: number
  }>
  lastUpdated: string
}

// Journey template filters
export interface JourneyTemplateFilters {
  industry?: JourneyIndustryValue[]
  category?: JourneyCategoryValue[]
  difficulty?: ('beginner' | 'intermediate' | 'advanced')[]
  tags?: string[]
  channels?: string[]
  minRating?: number
  isPublic?: boolean
  searchQuery?: string
}

// Journey template sort options
export type JourneyTemplateSortBy = 'name' | 'rating' | 'usageCount' | 'createdAt' | 'updatedAt'
export type JourneyTemplateSortOrder = 'asc' | 'desc'

// Validation schemas using Zod
export const JourneyStageConfigSchema = z.object({
  id: z.string(),
  type: z.enum(['awareness', 'consideration', 'conversion', 'retention', 'advocacy']),
  title: z.string().min(1, 'Stage title is required'),
  description: z.string().min(1, 'Stage description is required'),
  position: z.object({
    x: z.number(),
    y: z.number(),
  }),
  contentTypes: z.array(z.string()),
  messagingSuggestions: z.array(z.string()),
  channels: z.array(z.string()).optional(),
  objectives: z.array(z.string()).optional(),
  metrics: z.array(z.string()).optional(),
  duration: z.number().positive().optional(),
  automations: z.array(z.any()).optional(), // Detailed automation schema would be complex
})

export const JourneyTemplateSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(1, 'Template name is required').max(100, 'Template name too long'),
  description: z.string().max(500, 'Description too long').optional(),
  industry: z.enum([
    'TECHNOLOGY', 'HEALTHCARE', 'FINANCE', 'RETAIL', 'EDUCATION', 'REAL_ESTATE',
    'AUTOMOTIVE', 'HOSPITALITY', 'MANUFACTURING', 'CONSULTING', 'NONPROFIT',
    'ECOMMERCE', 'SAAS', 'MEDIA', 'FOOD_BEVERAGE', 'FITNESS', 'TRAVEL', 'FASHION', 'LEGAL', 'OTHER'
  ]),
  category: z.enum([
    'CUSTOMER_ACQUISITION', 'LEAD_NURTURING', 'CUSTOMER_ONBOARDING', 'RETENTION',
    'UPSELL_CROSS_SELL', 'WIN_BACK', 'REFERRAL', 'BRAND_AWARENESS', 'PRODUCT_LAUNCH',
    'EVENT_PROMOTION', 'SEASONAL_CAMPAIGN', 'CRISIS_COMMUNICATION'
  ]),
  stages: z.array(JourneyStageConfigSchema).min(1, 'At least one stage is required'),
  metadata: z.object({
    tags: z.array(z.string()).optional(),
    difficulty: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
    estimatedDuration: z.number().positive().optional(),
    requiredChannels: z.array(z.string()).optional(),
    targetAudience: z.array(z.string()).optional(),
    businessGoals: z.array(z.string()).optional(),
    kpis: z.array(z.string()).optional(),
    bestPractices: z.array(z.string()).optional(),
    customizations: z.array(z.string()).optional(),
  }).optional(),
  isActive: z.boolean().default(true),
  isPublic: z.boolean().default(true),
  customizationConfig: z.object({
    allowStageReordering: z.boolean().default(true),
    allowStageAddition: z.boolean().default(true),
    allowStageDeletion: z.boolean().default(false),
    editableFields: z.array(z.string()).default([]),
    requiredFields: z.array(z.string()).default([]),
    customFieldOptions: z.record(z.string(), z.array(z.any())).optional(),
    industrySpecificOptions: z.record(z.string(), z.any()).optional(),
  }).optional(),
  defaultSettings: z.object({
    timezone: z.string().optional(),
    workingHours: z.object({
      start: z.string(),
      end: z.string(),
    }).optional(),
    workingDays: z.array(z.number().min(0).max(6)).optional(),
    defaultChannels: z.array(z.string()).optional(),
    brandCompliance: z.boolean().default(true),
    autoOptimization: z.boolean().default(false),
    trackingSettings: z.object({
      enableAnalytics: z.boolean().default(true),
      trackConversions: z.boolean().default(true),
      customEvents: z.array(z.string()).optional(),
    }).optional(),
  }).optional(),
})

export const JourneyTemplateFiltersSchema = z.object({
  industry: z.array(z.enum([
    'TECHNOLOGY', 'HEALTHCARE', 'FINANCE', 'RETAIL', 'EDUCATION', 'REAL_ESTATE',
    'AUTOMOTIVE', 'HOSPITALITY', 'MANUFACTURING', 'CONSULTING', 'NONPROFIT',
    'ECOMMERCE', 'SAAS', 'MEDIA', 'FOOD_BEVERAGE', 'FITNESS', 'TRAVEL', 'FASHION', 'LEGAL', 'OTHER'
  ])).optional(),
  category: z.array(z.enum([
    'CUSTOMER_ACQUISITION', 'LEAD_NURTURING', 'CUSTOMER_ONBOARDING', 'RETENTION',
    'UPSELL_CROSS_SELL', 'WIN_BACK', 'REFERRAL', 'BRAND_AWARENESS', 'PRODUCT_LAUNCH',
    'EVENT_PROMOTION', 'SEASONAL_CAMPAIGN', 'CRISIS_COMMUNICATION'
  ])).optional(),
  difficulty: z.array(z.enum(['beginner', 'intermediate', 'advanced'])).optional(),
  tags: z.array(z.string()).optional(),
  channels: z.array(z.string()).optional(),
  minRating: z.number().min(1).max(5).optional(),
  isPublic: z.boolean().optional(),
  searchQuery: z.string().optional(),
})

// Helper functions
export const getIndustryDisplayName = (industry: JourneyIndustryValue): string => {
  const displayNames: Record<JourneyIndustryValue, string> = {
    [JourneyIndustry.TECHNOLOGY]: 'Technology',
    [JourneyIndustry.HEALTHCARE]: 'Healthcare',
    [JourneyIndustry.FINANCE]: 'Finance',
    [JourneyIndustry.RETAIL]: 'Retail',
    [JourneyIndustry.EDUCATION]: 'Education',
    [JourneyIndustry.REAL_ESTATE]: 'Real Estate',
    [JourneyIndustry.AUTOMOTIVE]: 'Automotive',
    [JourneyIndustry.HOSPITALITY]: 'Hospitality',
    [JourneyIndustry.MANUFACTURING]: 'Manufacturing',
    [JourneyIndustry.CONSULTING]: 'Consulting',
    [JourneyIndustry.NONPROFIT]: 'Non-Profit',
    [JourneyIndustry.ECOMMERCE]: 'E-commerce',
    [JourneyIndustry.SAAS]: 'SaaS',
    [JourneyIndustry.MEDIA]: 'Media',
    [JourneyIndustry.FOOD_BEVERAGE]: 'Food & Beverage',
    [JourneyIndustry.FITNESS]: 'Fitness',
    [JourneyIndustry.TRAVEL]: 'Travel',
    [JourneyIndustry.FASHION]: 'Fashion',
    [JourneyIndustry.LEGAL]: 'Legal',
    [JourneyIndustry.OTHER]: 'Other',
  }
  return displayNames[industry] || industry
}

export const getCategoryDisplayName = (category: JourneyCategoryValue): string => {
  const displayNames: Record<JourneyCategoryValue, string> = {
    [JourneyCategory.CUSTOMER_ACQUISITION]: 'Customer Acquisition',
    [JourneyCategory.LEAD_NURTURING]: 'Lead Nurturing',
    [JourneyCategory.CUSTOMER_ONBOARDING]: 'Customer Onboarding',
    [JourneyCategory.RETENTION]: 'Customer Retention',
    [JourneyCategory.UPSELL_CROSS_SELL]: 'Upsell/Cross-sell',
    [JourneyCategory.WIN_BACK]: 'Win-back Campaign',
    [JourneyCategory.REFERRAL]: 'Referral Program',
    [JourneyCategory.BRAND_AWARENESS]: 'Brand Awareness',
    [JourneyCategory.PRODUCT_LAUNCH]: 'Product Launch',
    [JourneyCategory.EVENT_PROMOTION]: 'Event Promotion',
    [JourneyCategory.SEASONAL_CAMPAIGN]: 'Seasonal Campaign',
    [JourneyCategory.CRISIS_COMMUNICATION]: 'Crisis Communication',
  }
  return displayNames[category] || category
}

export const getStageTypeDisplayName = (type: JourneyStageTypeValue): string => {
  const displayNames: Record<JourneyStageTypeValue, string> = {
    [JourneyStageType.AWARENESS]: 'Awareness',
    [JourneyStageType.CONSIDERATION]: 'Consideration',
    [JourneyStageType.CONVERSION]: 'Conversion',
    [JourneyStageType.RETENTION]: 'Retention',
    [JourneyStageType.ADVOCACY]: 'Advocacy',
  }
  return displayNames[type] || type
}

// Template utility functions
export const createDefaultStageConfig = (
  type: JourneyStageTypeValue,
  position: { x: number; y: number }
): JourneyStageConfig => {
  const baseConfigs: Record<JourneyStageTypeValue, Partial<JourneyStageConfig>> = {
    [JourneyStageType.AWARENESS]: {
      title: 'Awareness',
      description: 'Build brand awareness and attract potential customers',
      contentTypes: ['Blog Posts', 'Social Media', 'Video Content'],
      messagingSuggestions: [
        'Introduce your brand values',
        'Share educational content',
        'Tell your brand story',
      ],
      channels: ['social_media', 'content_marketing', 'paid_advertising'],
    },
    [JourneyStageType.CONSIDERATION]: {
      title: 'Consideration',
      description: 'Educate prospects and build trust',
      contentTypes: ['Whitepapers', 'Webinars', 'Case Studies'],
      messagingSuggestions: [
        'Demonstrate expertise',
        'Show social proof',
        'Address pain points',
      ],
      channels: ['email', 'webinars', 'content_marketing'],
    },
    [JourneyStageType.CONVERSION]: {
      title: 'Conversion',
      description: 'Convert prospects into customers',
      contentTypes: ['Product Demos', 'Free Trials', 'Pricing Pages'],
      messagingSuggestions: [
        'Create urgency',
        'Highlight unique value',
        'Reduce friction',
      ],
      channels: ['email', 'sales_outreach', 'landing_pages'],
    },
    [JourneyStageType.RETENTION]: {
      title: 'Retention',
      description: 'Keep customers engaged and satisfied',
      contentTypes: ['Email Newsletters', 'Support Content', 'Community'],
      messagingSuggestions: [
        'Provide ongoing value',
        'Build community',
        'Gather feedback',
      ],
      channels: ['email', 'in_app', 'community'],
    },
    [JourneyStageType.ADVOCACY]: {
      title: 'Advocacy',
      description: 'Turn customers into brand advocates',
      contentTypes: ['Referral Programs', 'User-Generated Content', 'Case Studies'],
      messagingSuggestions: [
        'Celebrate customer success',
        'Enable sharing',
        'Reward advocacy',
      ],
      channels: ['email', 'social_media', 'referral_programs'],
    },
  }

  const baseConfig = baseConfigs[type]
  return {
    id: `stage-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    type,
    position,
    objectives: [],
    metrics: [],
    duration: 7,
    automations: [],
    ...baseConfig,
  } as JourneyStageConfig
}

// Type exports
export type {
  JourneyInstance as JourneyInstanceType,
  JourneyMetrics as JourneyMetricsType,
  JourneyStageConfig as JourneyStageConfigType,
  JourneyTemplateFilters as JourneyTemplateFiltersType,
  JourneyTemplate as JourneyTemplateType,
}