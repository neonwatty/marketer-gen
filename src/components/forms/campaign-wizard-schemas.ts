import { z } from "zod"

// Step 1: Campaign Basics
export const campaignBasicsSchema = z.object({
  name: z
    .string()
    .min(1, "Campaign name is required")
    .max(100, "Campaign name must be less than 100 characters"),
  description: z
    .string()
    .min(10, "Description must be at least 10 characters")
    .max(500, "Description must be less than 500 characters"),
  template: z.enum([
    'blank',
    'product-launch', 
    'brand-awareness',
    'lead-generation',
    'customer-retention',
    'seasonal-campaign',
    'event-promotion'
  ], {
    message: "Please select a campaign template",
  }).optional(),
  objectives: z.array(z.enum([
    'brand-awareness',
    'lead-generation', 
    'sales-conversion',
    'customer-retention',
    'engagement',
    'traffic-increase'
  ])).min(1, "Please select at least one objective"),
})

export type CampaignBasicsData = z.infer<typeof campaignBasicsSchema>

// Step 2: Target Audience & Channels
export const audienceChannelsSchema = z.object({
  targetAudience: z.object({
    demographics: z.object({
      ageRange: z.enum(['18-24', '25-34', '35-44', '45-54', '55-64', '65+']).optional(),
      gender: z.enum(['male', 'female', 'non-binary', 'all']).optional(),
      location: z.string().optional(),
      interests: z.array(z.string()).optional(),
    }),
    customDescription: z.string().min(10, "Please provide a detailed audience description").max(300),
  }),
  channels: z.array(z.enum([
    'email',
    'social-media',
    'blog',
    'display-ads',
    'search-ads',
    'influencer',
    'webinar',
    'direct-mail',
    'sms'
  ])).min(1, "Please select at least one channel"),
  tone: z.enum(['professional', 'casual', 'friendly', 'persuasive', 'informative', 'urgent'], {
    message: "Please select a tone",
  }),
  keywords: z.string().optional(),
})

export type AudienceChannelsData = z.infer<typeof audienceChannelsSchema>

// Step 3: Budget & Schedule
export const budgetScheduleSchema = z.object({
  budget: z.object({
    total: z.number().min(0, "Budget must be a positive number"),
    currency: z.enum(['USD', 'EUR', 'GBP', 'CAD']).default('USD'),
    allocation: z.record(z.string(), z.number()).optional(), // Per channel allocation
  }),
  schedule: z.object({
    startDate: z.date({
      message: "Start date is required",
    }),
    endDate: z.date({
      message: "End date is required",
    }),
    timezone: z.string().default('UTC'),
    launchImmediately: z.boolean().default(false),
  }),
}).refine(
  (data) => data.schedule.endDate > data.schedule.startDate,
  {
    message: "End date must be after start date",
    path: ["schedule", "endDate"],
  }
)

export type BudgetScheduleData = z.infer<typeof budgetScheduleSchema>

// Step 4: Content & Assets
export const contentAssetsSchema = z.object({
  contentStrategy: z.object({
    contentTypes: z.array(z.enum([
      'blog-post',
      'social-post',
      'email-newsletter',
      'landing-page',
      'video-script',
      'ad-copy',
      'infographic',
      'case-study'
    ])).min(1, "Please select at least one content type"),
    contentFrequency: z.enum(['daily', 'weekly', 'bi-weekly', 'monthly']),
    brandGuidelines: z.string().max(500).optional(),
  }),
  assets: z.object({
    brandAssets: z.array(z.string()).optional(), // File paths/URLs
    logoUrl: z.string().url().optional(),
    brandColors: z.array(z.string().regex(/^#[0-9A-F]{6}$/i)).optional(),
    fonts: z.array(z.string()).optional(),
  }).optional(),
  messaging: z.object({
    primaryMessage: z.string().min(10, "Primary message is required").max(200),
    callToAction: z.string().min(3, "Call to action is required").max(50),
    valueProposition: z.string().max(300).optional(),
  }),
})

export type ContentAssetsData = z.infer<typeof contentAssetsSchema>

// Step 5: Review & Finalization
export const reviewFinalizationSchema = z.object({
  campaignReview: z.object({
    agreedToTerms: z.boolean().refine((val) => val === true, {
      message: "You must agree to the terms and conditions",
    }),
    notifications: z.object({
      emailNotifications: z.boolean().default(true),
      slackNotifications: z.boolean().default(false),
      webhookUrl: z.string().url().optional(),
    }).optional(),
    launchPreference: z.enum(['immediate', 'scheduled', 'draft']),
  }),
})

export type ReviewFinalizationData = z.infer<typeof reviewFinalizationSchema>

// Combined Campaign Wizard Schema
export const campaignWizardSchema = z.object({
  basics: campaignBasicsSchema,
  audienceChannels: audienceChannelsSchema, 
  budgetSchedule: budgetScheduleSchema,
  contentAssets: contentAssetsSchema,
  reviewFinalization: reviewFinalizationSchema,
})

export type CampaignWizardData = z.infer<typeof campaignWizardSchema>

// Template definitions for campaign types
export const campaignTemplates = {
  'blank': {
    name: 'Blank Campaign',
    description: 'Start from scratch with a completely customizable campaign',
    icon: '📝',
    presets: {},
  },
  'product-launch': {
    name: 'Product Launch',
    description: 'Multi-channel campaign to introduce a new product to market',
    icon: '🚀',
    presets: {
      objectives: ['brand-awareness', 'lead-generation', 'sales-conversion'],
      channels: ['email', 'social-media', 'blog', 'display-ads'],
      contentTypes: ['blog-post', 'social-post', 'email-newsletter', 'landing-page'],
    },
  },
  'brand-awareness': {
    name: 'Brand Awareness',
    description: 'Build recognition and visibility for your brand',
    icon: '📢',
    presets: {
      objectives: ['brand-awareness', 'engagement'],
      channels: ['social-media', 'display-ads', 'influencer'],
      contentTypes: ['social-post', 'video-script', 'infographic'],
    },
  },
  'lead-generation': {
    name: 'Lead Generation',
    description: 'Capture and nurture potential customers',
    icon: '🎯',
    presets: {
      objectives: ['lead-generation', 'sales-conversion'],
      channels: ['email', 'search-ads', 'landing-page', 'webinar'],
      contentTypes: ['landing-page', 'email-newsletter', 'case-study'],
    },
  },
  'customer-retention': {
    name: 'Customer Retention',
    description: 'Keep existing customers engaged and loyal',
    icon: '🤝',
    presets: {
      objectives: ['customer-retention', 'engagement'],
      channels: ['email', 'sms', 'direct-mail'],
      contentTypes: ['email-newsletter', 'case-study'],
    },
  },
  'seasonal-campaign': {
    name: 'Seasonal Campaign',
    description: 'Time-sensitive campaigns for holidays or special events',
    icon: '🎁',
    presets: {
      objectives: ['sales-conversion', 'brand-awareness'],
      channels: ['email', 'social-media', 'display-ads'],
      contentTypes: ['social-post', 'email-newsletter', 'ad-copy'],
    },
  },
  'event-promotion': {
    name: 'Event Promotion',
    description: 'Drive awareness and attendance for events',
    icon: '🎪',
    presets: {
      objectives: ['brand-awareness', 'engagement'],
      channels: ['social-media', 'email', 'display-ads', 'influencer'],
      contentTypes: ['social-post', 'email-newsletter', 'landing-page'],
    },
  },
} as const

export type CampaignTemplate = keyof typeof campaignTemplates