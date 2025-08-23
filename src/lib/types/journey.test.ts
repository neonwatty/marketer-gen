import {
  createDefaultStageConfig,
  getCategoryDisplayName,
  getIndustryDisplayName,
  getStageTypeDisplayName,
  JourneyCategory,
  JourneyIndustry,
  JourneyStageConfigSchema,
  JourneyStageType,
  JourneyTemplateFiltersSchema,
  JourneyTemplateSchema,
} from './journey'

describe('Journey Types and Utilities', () => {
  describe('JourneyTemplateSchema validation', () => {
    const validTemplate = {
      name: 'Test Template',
      description: 'A test template',
      industry: 'TECHNOLOGY',
      category: 'CUSTOMER_ACQUISITION',
      stages: [
        {
          id: 'stage-1',
          type: 'awareness',
          title: 'Awareness Stage',
          description: 'Build awareness',
          position: { x: 100, y: 100 },
          contentTypes: ['Blog Posts'],
          messagingSuggestions: ['Introduce your brand'],
        },
      ],
      isActive: true,
      isPublic: true,
    }

    it('should validate a correct template', () => {
      const result = JourneyTemplateSchema.safeParse(validTemplate)
      expect(result.success).toBe(true)
    })

    it('should fail validation for missing required fields', () => {
      const invalidTemplate = {
        ...validTemplate,
        name: '', // Empty name should fail
        stages: [], // Empty stages should fail
      }

      const result = JourneyTemplateSchema.safeParse(invalidTemplate)
      expect(result.success).toBe(false)
      
      if (!result.success) {
        const errors = result.error.issues.map(issue => issue.message)
        expect(errors).toContain('Template name is required')
        expect(errors).toContain('At least one stage is required')
      }
    })

    it('should fail validation for invalid industry', () => {
      const invalidTemplate = {
        ...validTemplate,
        industry: 'INVALID_INDUSTRY',
      }

      const result = JourneyTemplateSchema.safeParse(invalidTemplate)
      expect(result.success).toBe(false)
    })

    it('should fail validation for invalid category', () => {
      const invalidTemplate = {
        ...validTemplate,
        category: 'INVALID_CATEGORY',
      }

      const result = JourneyTemplateSchema.safeParse(invalidTemplate)
      expect(result.success).toBe(false)
    })

    it('should apply default values', () => {
      const minimalTemplate = {
        name: 'Test Template',
        industry: 'TECHNOLOGY',
        category: 'CUSTOMER_ACQUISITION',
        stages: [
          {
            id: 'stage-1',
            type: 'awareness',
            title: 'Awareness Stage',
            description: 'Build awareness',
            position: { x: 100, y: 100 },
            contentTypes: ['Blog Posts'],
            messagingSuggestions: ['Introduce your brand'],
          },
        ],
      }

      const result = JourneyTemplateSchema.safeParse(minimalTemplate)
      expect(result.success).toBe(true)
      
      if (result.success) {
        expect(result.data.isActive).toBe(true)
        expect(result.data.isPublic).toBe(true)
      }
    })

    it('should validate metadata fields', () => {
      const templateWithMetadata = {
        ...validTemplate,
        metadata: {
          tags: ['test', 'sample'],
          difficulty: 'intermediate',
          estimatedDuration: 30,
          requiredChannels: ['email', 'social_media'],
          targetAudience: ['decision makers'],
          businessGoals: ['increase conversions'],
          kpis: ['conversion rate'],
        },
      }

      const result = JourneyTemplateSchema.safeParse(templateWithMetadata)
      expect(result.success).toBe(true)
    })

    it('should validate customization config', () => {
      const templateWithCustomization = {
        ...validTemplate,
        customizationConfig: {
          allowStageReordering: true,
          allowStageAddition: false,
          allowStageDeletion: false,
          editableFields: ['title', 'description'],
          requiredFields: ['title'],
        },
      }

      const result = JourneyTemplateSchema.safeParse(templateWithCustomization)
      expect(result.success).toBe(true)
    })

    it('should validate default settings', () => {
      const templateWithSettings = {
        ...validTemplate,
        defaultSettings: {
          timezone: 'UTC',
          workingHours: { start: '09:00', end: '17:00' },
          workingDays: [1, 2, 3, 4, 5],
          defaultChannels: ['email', 'social_media'],
          brandCompliance: true,
          autoOptimization: false,
          trackingSettings: {
            enableAnalytics: true,
            trackConversions: true,
            customEvents: ['signup', 'conversion'],
          },
        },
      }

      const result = JourneyTemplateSchema.safeParse(templateWithSettings)
      expect(result.success).toBe(true)
    })
  })

  describe('JourneyStageConfigSchema validation', () => {
    const validStage = {
      id: 'stage-1',
      type: 'awareness',
      title: 'Awareness Stage',
      description: 'Build awareness',
      position: { x: 100, y: 100 },
      contentTypes: ['Blog Posts'],
      messagingSuggestions: ['Introduce your brand'],
    }

    it('should validate a correct stage', () => {
      const result = JourneyStageConfigSchema.safeParse(validStage)
      expect(result.success).toBe(true)
    })

    it('should fail validation for empty title', () => {
      const invalidStage = {
        ...validStage,
        title: '',
      }

      const result = JourneyStageConfigSchema.safeParse(invalidStage)
      expect(result.success).toBe(false)
      
      if (!result.success) {
        const errors = result.error.issues.map(issue => issue.message)
        expect(errors).toContain('Stage title is required')
      }
    })

    it('should fail validation for empty description', () => {
      const invalidStage = {
        ...validStage,
        description: '',
      }

      const result = JourneyStageConfigSchema.safeParse(invalidStage)
      expect(result.success).toBe(false)
      
      if (!result.success) {
        const errors = result.error.issues.map(issue => issue.message)
        expect(errors).toContain('Stage description is required')
      }
    })

    it('should fail validation for invalid stage type', () => {
      const invalidStage = {
        ...validStage,
        type: 'invalid_type',
      }

      const result = JourneyStageConfigSchema.safeParse(invalidStage)
      expect(result.success).toBe(false)
    })

    it('should validate optional fields', () => {
      const stageWithOptionals = {
        ...validStage,
        channels: ['email', 'social_media'],
        objectives: ['Build awareness', 'Generate leads'],
        metrics: ['impressions', 'clicks'],
        duration: 7,
        automations: [],
      }

      const result = JourneyStageConfigSchema.safeParse(stageWithOptionals)
      expect(result.success).toBe(true)
    })
  })

  describe('JourneyTemplateFiltersSchema validation', () => {
    it('should validate empty filters', () => {
      const result = JourneyTemplateFiltersSchema.safeParse({})
      expect(result.success).toBe(true)
    })

    it('should validate industry filter', () => {
      const filters = {
        industry: ['TECHNOLOGY', 'SAAS'],
      }

      const result = JourneyTemplateFiltersSchema.safeParse(filters)
      expect(result.success).toBe(true)
    })

    it('should validate category filter', () => {
      const filters = {
        category: ['CUSTOMER_ACQUISITION', 'RETENTION'],
      }

      const result = JourneyTemplateFiltersSchema.safeParse(filters)
      expect(result.success).toBe(true)
    })

    it('should validate difficulty filter', () => {
      const filters = {
        difficulty: ['beginner', 'intermediate'],
      }

      const result = JourneyTemplateFiltersSchema.safeParse(filters)
      expect(result.success).toBe(true)
    })

    it('should validate rating filter', () => {
      const filters = {
        minRating: 4.0,
      }

      const result = JourneyTemplateFiltersSchema.safeParse(filters)
      expect(result.success).toBe(true)
    })

    it('should fail for invalid rating range', () => {
      const filters = {
        minRating: 6.0, // Invalid: above 5
      }

      const result = JourneyTemplateFiltersSchema.safeParse(filters)
      expect(result.success).toBe(false)
    })

    it('should validate complex filters', () => {
      const filters = {
        industry: ['TECHNOLOGY'],
        category: ['CUSTOMER_ACQUISITION'],
        difficulty: ['intermediate'],
        tags: ['saas', 'conversion'],
        channels: ['email', 'social_media'],
        minRating: 4.0,
        isPublic: true,
        searchQuery: 'customer acquisition',
      }

      const result = JourneyTemplateFiltersSchema.safeParse(filters)
      expect(result.success).toBe(true)
    })
  })

  describe('Display name utilities', () => {
    it('should return correct industry display names', () => {
      expect(getIndustryDisplayName('TECHNOLOGY')).toBe('Technology')
      expect(getIndustryDisplayName('REAL_ESTATE')).toBe('Real Estate')
      expect(getIndustryDisplayName('FOOD_BEVERAGE')).toBe('Food & Beverage')
      expect(getIndustryDisplayName('OTHER')).toBe('Other')
    })

    it('should return correct category display names', () => {
      expect(getCategoryDisplayName('CUSTOMER_ACQUISITION')).toBe('Customer Acquisition')
      expect(getCategoryDisplayName('LEAD_NURTURING')).toBe('Lead Nurturing')
      expect(getCategoryDisplayName('UPSELL_CROSS_SELL')).toBe('Upsell/Cross-sell')
      expect(getCategoryDisplayName('CRISIS_COMMUNICATION')).toBe('Crisis Communication')
    })

    it('should return correct stage type display names', () => {
      expect(getStageTypeDisplayName('awareness')).toBe('Awareness')
      expect(getStageTypeDisplayName('consideration')).toBe('Consideration')
      expect(getStageTypeDisplayName('conversion')).toBe('Conversion')
      expect(getStageTypeDisplayName('retention')).toBe('Retention')
      expect(getStageTypeDisplayName('advocacy')).toBe('Advocacy')
    })

    it('should handle unknown values gracefully', () => {
      expect(getIndustryDisplayName('UNKNOWN' as any)).toBe('UNKNOWN')
      expect(getCategoryDisplayName('UNKNOWN' as any)).toBe('UNKNOWN')
      expect(getStageTypeDisplayName('unknown' as any)).toBe('unknown')
    })
  })

  describe('createDefaultStageConfig utility', () => {
    it('should create awareness stage with correct defaults', () => {
      const stage = createDefaultStageConfig('awareness', { x: 100, y: 100 })

      expect(stage.type).toBe('awareness')
      expect(stage.title).toBe('Awareness')
      expect(stage.description).toBe('Build brand awareness and attract potential customers')
      expect(stage.contentTypes).toContain('Blog Posts')
      expect(stage.contentTypes).toContain('Social Media')
      expect(stage.messagingSuggestions).toContain('Introduce your brand values')
      expect(stage.channels).toContain('social_media')
      expect(stage.position).toEqual({ x: 100, y: 100 })
      expect(stage.duration).toBe(7)
      expect(stage.id).toBeDefined()
      expect(stage.objectives).toEqual([])
      expect(stage.metrics).toEqual([])
      expect(stage.automations).toEqual([])
    })

    it('should create consideration stage with correct defaults', () => {
      const stage = createDefaultStageConfig('consideration', { x: 200, y: 200 })

      expect(stage.type).toBe('consideration')
      expect(stage.title).toBe('Consideration')
      expect(stage.description).toBe('Educate prospects and build trust')
      expect(stage.contentTypes).toContain('Whitepapers')
      expect(stage.contentTypes).toContain('Webinars')
      expect(stage.messagingSuggestions).toContain('Demonstrate expertise')
      expect(stage.channels).toContain('email')
      expect(stage.position).toEqual({ x: 200, y: 200 })
    })

    it('should create conversion stage with correct defaults', () => {
      const stage = createDefaultStageConfig('conversion', { x: 300, y: 300 })

      expect(stage.type).toBe('conversion')
      expect(stage.title).toBe('Conversion')
      expect(stage.description).toBe('Convert prospects into customers')
      expect(stage.contentTypes).toContain('Product Demos')
      expect(stage.contentTypes).toContain('Free Trials')
      expect(stage.messagingSuggestions).toContain('Create urgency')
      expect(stage.channels).toContain('sales_outreach')
      expect(stage.position).toEqual({ x: 300, y: 300 })
    })

    it('should create retention stage with correct defaults', () => {
      const stage = createDefaultStageConfig('retention', { x: 400, y: 400 })

      expect(stage.type).toBe('retention')
      expect(stage.title).toBe('Retention')
      expect(stage.description).toBe('Keep customers engaged and satisfied')
      expect(stage.contentTypes).toContain('Email Newsletters')
      expect(stage.messagingSuggestions).toContain('Provide ongoing value')
      expect(stage.channels).toContain('community')
      expect(stage.position).toEqual({ x: 400, y: 400 })
    })

    it('should create advocacy stage with correct defaults', () => {
      const stage = createDefaultStageConfig('advocacy', { x: 500, y: 500 })

      expect(stage.type).toBe('advocacy')
      expect(stage.title).toBe('Advocacy')
      expect(stage.description).toBe('Turn customers into brand advocates')
      expect(stage.contentTypes).toContain('Referral Programs')
      expect(stage.messagingSuggestions).toContain('Celebrate customer success')
      expect(stage.channels).toContain('referral_programs')
      expect(stage.position).toEqual({ x: 500, y: 500 })
    })

    it('should generate unique stage IDs', () => {
      const stage1 = createDefaultStageConfig('awareness', { x: 0, y: 0 })
      const stage2 = createDefaultStageConfig('awareness', { x: 0, y: 0 })

      expect(stage1.id).not.toBe(stage2.id)
      expect(stage1.id).toMatch(/^stage-\d+-[a-z0-9]+$/)
      expect(stage2.id).toMatch(/^stage-\d+-[a-z0-9]+$/)
    })
  })

  describe('Enum values', () => {
    it('should have correct industry enum values', () => {
      expect(JourneyIndustry.TECHNOLOGY).toBe('TECHNOLOGY')
      expect(JourneyIndustry.HEALTHCARE).toBe('HEALTHCARE')
      expect(JourneyIndustry.SAAS).toBe('SAAS')
      expect(JourneyIndustry.OTHER).toBe('OTHER')
    })

    it('should have correct category enum values', () => {
      expect(JourneyCategory.CUSTOMER_ACQUISITION).toBe('CUSTOMER_ACQUISITION')
      expect(JourneyCategory.LEAD_NURTURING).toBe('LEAD_NURTURING')
      expect(JourneyCategory.RETENTION).toBe('RETENTION')
      expect(JourneyCategory.REFERRAL).toBe('REFERRAL')
    })

    it('should have correct stage type enum values', () => {
      expect(JourneyStageType.AWARENESS).toBe('awareness')
      expect(JourneyStageType.CONSIDERATION).toBe('consideration')
      expect(JourneyStageType.CONVERSION).toBe('conversion')
      expect(JourneyStageType.RETENTION).toBe('retention')
      expect(JourneyStageType.ADVOCACY).toBe('advocacy')
    })
  })
})