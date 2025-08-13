// Bulk content generation types and utilities

export interface JourneyStageDefinition {
  id: string
  name: string
  type: "awareness" | "consideration" | "conversion" | "retention"
  description: string
  objectives: string[]
  recommendedChannels: string[]
  recommendedContentTypes: string[]
  customerMindset: string
  contentGoals: string[]
  messagingFocus: string[]
}

export interface BulkGenerationRequest {
  id: string
  name: string
  description?: string
  stages: string[] // Journey stage IDs to generate content for
  contentTypesPerStage: Record<string, string[]> // stage ID -> content types
  channelsPerStage: Record<string, string[]> // stage ID -> channels
  quantity: number // Number of content pieces per stage per type
  brandContext: {
    companyName?: string
    industry?: string
    targetAudience?: string
    brandVoice?: string
    brandGuidelines?: string
    logoUrl?: string
    brandColors?: string[]
  }
  contentSettings: {
    tone: string
    contentLength: string
    urgencyLevel?: string
    includeHashtags?: boolean
    includeCTA?: boolean
    customInstructions?: string
  }
  campaignId?: string
  createdBy?: string
  scheduledFor?: Date
  priority: "low" | "medium" | "high"
  status: "draft" | "queued" | "processing" | "completed" | "failed" | "cancelled"
}

export interface BulkGenerationJob {
  id: string
  requestId: string
  stage: string
  contentType: string
  channel: string
  status: "pending" | "processing" | "completed" | "failed"
  progress: number
  startedAt?: Date
  completedAt?: Date
  generatedContent?: {
    id: string
    title: string
    content: string
    metadata: Record<string, any>
  }
  error?: string
  retryCount: number
  estimatedDuration?: number
}

export interface BulkGenerationProgress {
  requestId: string
  totalJobs: number
  completedJobs: number
  failedJobs: number
  inProgressJobs: number
  pendingJobs: number
  progress: number // 0-100
  estimatedTimeRemaining?: number
  startedAt: Date
  completedAt?: Date
  status: "initializing" | "processing" | "paused" | "completed" | "failed" | "cancelled"
}

export interface StageContentTemplate {
  stageId: string
  contentType: string
  channel: string
  template: {
    titlePrompt: string
    contentPrompt: string
    ctaPrompt?: string
    hashtagPrompt?: string
    additionalContext: string
  }
  examples: Array<{
    title: string
    content: string
    notes?: string
  }>
}

// Journey stage definitions based on marketing funnel
export const JOURNEY_STAGE_DEFINITIONS: Record<string, JourneyStageDefinition> = {
  awareness: {
    id: "awareness",
    name: "Awareness",
    type: "awareness",
    description: "Introducing your brand and solutions to potential customers who are discovering they have a problem or need.",
    objectives: [
      "Build brand recognition and visibility",
      "Educate about the problem or need",
      "Generate initial interest and engagement",
      "Drive traffic to owned properties"
    ],
    recommendedChannels: ["social-media", "blog", "seo", "display-ads", "pr", "influencer"],
    recommendedContentTypes: ["blog-post", "social-post", "infographic", "video", "podcast", "whitepaper"],
    customerMindset: "Problem unaware or problem aware, seeking information and solutions",
    contentGoals: [
      "Educational and informative content",
      "Problem identification and solution awareness",
      "Brand storytelling and values communication",
      "Thought leadership establishment"
    ],
    messagingFocus: [
      "Problem education",
      "Industry insights",
      "Brand values and mission",
      "Educational resources"
    ]
  },
  consideration: {
    id: "consideration",
    name: "Consideration", 
    type: "consideration",
    description: "Nurturing prospects who are evaluating different solutions and considering your brand as a potential option.",
    objectives: [
      "Build trust and credibility",
      "Demonstrate expertise and authority",
      "Showcase product/service benefits",
      "Nurture leads through the evaluation process"
    ],
    recommendedChannels: ["email", "webinars", "landing-pages", "retargeting", "content-marketing"],
    recommendedContentTypes: ["case-study", "comparison", "demo", "email-series", "webinar", "ebook"],
    customerMindset: "Solution aware, comparing options and evaluating vendors",
    contentGoals: [
      "Trust building and social proof",
      "Product/service differentiation",
      "Detailed feature and benefit explanation",
      "Lead nurturing and qualification"
    ],
    messagingFocus: [
      "Unique value proposition",
      "Customer success stories",
      "Product features and benefits",
      "Competitive advantages"
    ]
  },
  conversion: {
    id: "conversion",
    name: "Conversion",
    type: "conversion", 
    description: "Converting qualified prospects into customers through compelling offers and clear calls-to-action.",
    objectives: [
      "Drive purchase decisions",
      "Remove final objections and barriers",
      "Create urgency and motivation to act",
      "Optimize conversion rates and sales"
    ],
    recommendedChannels: ["landing-pages", "email", "sales", "retargeting", "ppc"],
    recommendedContentTypes: ["landing-page", "sales-page", "offer", "testimonial", "guarantee", "faq"],
    customerMindset: "Ready to purchase, needs final motivation and reassurance",
    contentGoals: [
      "Clear value proposition communication",
      "Objection handling and risk reversal", 
      "Urgency and scarcity creation",
      "Streamlined conversion process"
    ],
    messagingFocus: [
      "Special offers and promotions",
      "Risk-free guarantees",
      "Limited-time urgency",
      "Clear next steps and CTAs"
    ]
  },
  retention: {
    id: "retention",
    name: "Retention",
    type: "retention",
    description: "Engaging existing customers to increase satisfaction, encourage repeat purchases, and drive advocacy.",
    objectives: [
      "Increase customer lifetime value",
      "Reduce churn and improve retention",
      "Encourage repeat purchases and upsells",
      "Turn customers into brand advocates"
    ],
    recommendedChannels: ["email", "support", "community", "app-notifications", "loyalty-programs"],
    recommendedContentTypes: ["onboarding", "tutorial", "newsletter", "loyalty-program", "survey", "referral"],
    customerMindset: "Existing customer seeking value, support, and continued engagement",
    contentGoals: [
      "Customer success and satisfaction",
      "Product adoption and usage",
      "Community building and engagement",
      "Advocacy and referral generation"
    ],
    messagingFocus: [
      "Ongoing value delivery",
      "Product updates and features",
      "Community and support",
      "Loyalty and appreciation"
    ]
  }
}

// Content type mapping for different stages
export const STAGE_CONTENT_TYPE_MAPPING: Record<string, Record<string, string[]>> = {
  awareness: {
    "social-media": ["social-post", "video", "infographic"],
    "blog": ["blog-post", "article", "guide"],
    "email": ["newsletter", "announcement"],
    "advertising": ["display-ad", "video-ad", "banner-ad"]
  },
  consideration: {
    "email": ["email-series", "nurture-sequence"],
    "landing-pages": ["landing-page", "comparison-page"],
    "content-marketing": ["case-study", "whitepaper", "ebook"],
    "social-media": ["testimonial", "demo-video"]
  },
  conversion: {
    "landing-pages": ["sales-page", "offer-page", "checkout"],
    "email": ["sales-email", "abandoned-cart", "promotion"],
    "advertising": ["conversion-ad", "retargeting-ad"],
    "sales": ["proposal", "quote", "contract"]
  },
  retention: {
    "email": ["onboarding-series", "newsletter", "update"],
    "support": ["tutorial", "faq", "help-article"],
    "community": ["announcement", "survey", "feedback"],
    "loyalty": ["reward-program", "referral-program"]
  }
}

// Utility functions for bulk generation
export class BulkGenerationUtils {
  static calculateEstimatedDuration(totalJobs: number, avgJobDuration: number = 30): number {
    // Estimate based on parallel processing capacity
    const parallelCapacity = 5 // Assume 5 concurrent jobs
    const batches = Math.ceil(totalJobs / parallelCapacity)
    return batches * avgJobDuration // seconds
  }

  static generateJobsFromRequest(request: BulkGenerationRequest): BulkGenerationJob[] {
    const jobs: BulkGenerationJob[] = []
    let jobIndex = 0

    for (const stageId of request.stages) {
      const contentTypes = request.contentTypesPerStage[stageId] || []
      const channels = request.channelsPerStage[stageId] || []

      for (const contentType of contentTypes) {
        for (const channel of channels) {
          for (let i = 0; i < request.quantity; i++) {
            jobs.push({
              id: `job-${request.id}-${jobIndex++}`,
              requestId: request.id,
              stage: stageId,
              contentType,
              channel,
              status: "pending",
              progress: 0,
              retryCount: 0,
              estimatedDuration: 30 // seconds
            })
          }
        }
      }
    }

    return jobs
  }

  static calculateTotalJobs(request: BulkGenerationRequest): number {
    let total = 0
    for (const stageId of request.stages) {
      const contentTypes = request.contentTypesPerStage[stageId] || []
      const channels = request.channelsPerStage[stageId] || []
      total += contentTypes.length * channels.length * request.quantity
    }
    return total
  }

  static getStageDefinition(stageId: string): JourneyStageDefinition | null {
    return JOURNEY_STAGE_DEFINITIONS[stageId] || null
  }

  static getRecommendedContentTypes(stageId: string, channel?: string): string[] {
    const stageDef = JOURNEY_STAGE_DEFINITIONS[stageId]
    if (!stageDef) return []

    if (channel && STAGE_CONTENT_TYPE_MAPPING[stageId]?.[channel]) {
      return STAGE_CONTENT_TYPE_MAPPING[stageId][channel]
    }

    return stageDef.recommendedContentTypes
  }

  static validateBulkRequest(request: BulkGenerationRequest): { 
    isValid: boolean
    errors: string[]
    warnings: string[]
  } {
    const errors: string[] = []
    const warnings: string[] = []

    // Basic validation
    if (!request.name?.trim()) {
      errors.push("Request name is required")
    }

    if (!request.stages || request.stages.length === 0) {
      errors.push("At least one journey stage must be selected")
    }

    if (request.quantity < 1 || request.quantity > 50) {
      errors.push("Quantity must be between 1 and 50 per stage per content type")
    }

    // Stage-specific validation
    for (const stageId of request.stages) {
      if (!JOURNEY_STAGE_DEFINITIONS[stageId]) {
        errors.push(`Invalid stage ID: ${stageId}`)
        continue
      }

      const contentTypes = request.contentTypesPerStage[stageId]
      if (!contentTypes || contentTypes.length === 0) {
        warnings.push(`No content types selected for ${stageId} stage`)
      }

      const channels = request.channelsPerStage[stageId] 
      if (!channels || channels.length === 0) {
        warnings.push(`No channels selected for ${stageId} stage`)
      }
    }

    // Calculate total jobs and warn if too many
    const totalJobs = this.calculateTotalJobs(request)
    if (totalJobs > 100) {
      warnings.push(`High volume request: ${totalJobs} total content pieces will be generated`)
    }

    return {
      isValid: errors.length === 0,
      errors,
      warnings
    }
  }

  static formatEstimatedTime(seconds: number): string {
    if (seconds < 60) return `${seconds} seconds`
    if (seconds < 3600) return `${Math.round(seconds / 60)} minutes`
    return `${Math.round(seconds / 3600)} hours`
  }
}