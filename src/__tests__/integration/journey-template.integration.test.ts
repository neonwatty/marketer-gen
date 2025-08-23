// Unmock Prisma for integration tests
jest.unmock('@prisma/client')
jest.unmock('@/generated/prisma')

import { PrismaClient } from '@/generated/prisma'
import { allJourneyTemplates } from '@/lib/data/journey-templates'
import { JourneyTemplateService } from '@/lib/services/journey-template-service'
import { JourneyTemplate } from '@/lib/types/journey'

// Use test database - override environment variable for this test
process.env.DATABASE_URL = 'file:./prisma/test.db'

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: 'file:./prisma/test.db',
    },
  },
})

describe('Journey Template Integration Tests', () => {
  // Clean up database before and after tests
  beforeAll(async () => {
    await prisma.$connect()
    // Clean up any existing data
    await prisma.journeyTemplate.deleteMany({})
  })

  afterAll(async () => {
    // Clean up test data
    await prisma.journeyTemplate.deleteMany({})
    await prisma.$disconnect()
  })

  beforeEach(async () => {
    // Clean up before each test
    await prisma.journeyTemplate.deleteMany({})
  })

  describe('Template CRUD Operations', () => {
    it('should create and retrieve a template with JSON fields', async () => {
      const templateData = allJourneyTemplates[0]
      
      const createdTemplate = await JourneyTemplateService.createTemplate(templateData)
      
      expect(createdTemplate.id).toBeDefined()
      expect(createdTemplate.name).toBe(templateData.name)
      expect(createdTemplate.industry).toBe(templateData.industry)
      expect(createdTemplate.category).toBe(templateData.category)
      expect(createdTemplate.stages).toEqual(templateData.stages)
      expect(createdTemplate.metadata).toEqual(templateData.metadata)
      expect(createdTemplate.customizationConfig).toEqual(templateData.customizationConfig)
      expect(createdTemplate.defaultSettings).toEqual(templateData.defaultSettings)

      // Retrieve the template
      const retrievedTemplate = await JourneyTemplateService.getTemplateById(createdTemplate.id)
      
      expect(retrievedTemplate).not.toBeNull()
      expect(retrievedTemplate!.id).toBe(createdTemplate.id)
      expect(retrievedTemplate!.stages).toEqual(templateData.stages)
      expect(retrievedTemplate!.metadata).toEqual(templateData.metadata)
    })

    it('should update template JSON fields correctly', async () => {
      const templateData = allJourneyTemplates[0]
      const createdTemplate = await JourneyTemplateService.createTemplate(templateData)

      // Update stages and metadata
      const updatedStages = [
        ...templateData.stages,
        {
          id: 'new-stage',
          type: 'advocacy' as const,
          title: 'New Advocacy Stage',
          description: 'Turn customers into advocates',
          position: { x: 1200, y: 100 },
          contentTypes: ['Referral Programs'],
          messagingSuggestions: ['Share your success'],
          channels: ['social_media'],
          objectives: ['Build advocacy'],
          metrics: ['referrals'],
          duration: 14,
          automations: [],
        },
      ]

      const updatedMetadata = {
        ...templateData.metadata,
        tags: [...(templateData.metadata?.tags || []), 'updated'],
        difficulty: 'advanced' as const,
      }

      const updatedTemplate = await JourneyTemplateService.updateTemplate(createdTemplate.id, {
        stages: updatedStages,
        metadata: updatedMetadata,
      })

      expect(updatedTemplate).not.toBeNull()
      expect(updatedTemplate!.stages).toHaveLength(templateData.stages.length + 1)
      expect(updatedTemplate!.stages[updatedTemplate!.stages.length - 1].title).toBe('New Advocacy Stage')
      expect(updatedTemplate!.metadata?.tags).toContain('updated')
      expect(updatedTemplate!.metadata?.difficulty).toBe('advanced')
    })

    it('should soft delete templates correctly', async () => {
      const templateData = allJourneyTemplates[0]
      const createdTemplate = await JourneyTemplateService.createTemplate(templateData)

      // Template should be retrievable
      let retrievedTemplate = await JourneyTemplateService.getTemplateById(createdTemplate.id)
      expect(retrievedTemplate).not.toBeNull()

      // Delete template
      const deleteResult = await JourneyTemplateService.deleteTemplate(createdTemplate.id)
      expect(deleteResult).toBe(true)

      // Template should no longer be retrievable
      retrievedTemplate = await JourneyTemplateService.getTemplateById(createdTemplate.id)
      expect(retrievedTemplate).toBeNull()

      // But should exist in database with deletedAt timestamp
      const deletedTemplate = await prisma.journeyTemplate.findUnique({
        where: { id: createdTemplate.id },
      })
      expect(deletedTemplate).not.toBeNull()
      expect(deletedTemplate!.deletedAt).not.toBeNull()
    })
  })

  describe('Template Filtering and Search', () => {
    beforeEach(async () => {
      // Seed multiple templates for filtering tests
      const templatePromises = allJourneyTemplates.slice(0, 4).map(template =>
        JourneyTemplateService.createTemplate(template)
      )
      await Promise.all(templatePromises)
    })

    it('should filter templates by industry', async () => {
      const { templates } = await JourneyTemplateService.getTemplates(
        { industry: ['SAAS'] },
        'createdAt',
        'desc',
        1,
        10
      )

      expect(templates.length).toBeGreaterThan(0)
      templates.forEach(template => {
        expect(template.industry).toBe('SAAS')
      })
    })

    it('should filter templates by category', async () => {
      const { templates } = await JourneyTemplateService.getTemplates(
        { category: ['CUSTOMER_ACQUISITION'] },
        'createdAt',
        'desc',
        1,
        10
      )

      expect(templates.length).toBeGreaterThan(0)
      templates.forEach(template => {
        expect(template.category).toBe('CUSTOMER_ACQUISITION')
      })
    })

    it('should search templates by name and description', async () => {
      const { templates } = await JourneyTemplateService.getTemplates(
        { searchQuery: 'saas' },
        'createdAt',
        'desc',
        1,
        10
      )

      expect(templates.length).toBeGreaterThan(0)
      templates.forEach(template => {
        const matchesName = template.name.toLowerCase().includes('saas')
        const matchesDescription = template.description?.toLowerCase().includes('saas')
        expect(matchesName || matchesDescription).toBe(true)
      })
    })

    it('should return paginated results correctly', async () => {
      const pageSize = 2
      const { templates, totalCount, pageCount } = await JourneyTemplateService.getTemplates(
        {},
        'createdAt',
        'desc',
        1,
        pageSize
      )

      expect(templates.length).toBeLessThanOrEqual(pageSize)
      expect(totalCount).toBeGreaterThan(0)
      expect(pageCount).toBe(Math.ceil(totalCount / pageSize))

      // Test second page
      if (totalCount > pageSize) {
        const { templates: page2Templates } = await JourneyTemplateService.getTemplates(
          {},
          'createdAt',
          'desc',
          2,
          pageSize
        )
        expect(page2Templates.length).toBeGreaterThan(0)
        
        // Ensure different results
        const page1Ids = templates.map(t => t.id)
        const page2Ids = page2Templates.map(t => t.id)
        expect(page1Ids).not.toEqual(page2Ids)
      }
    })

    it('should sort templates correctly', async () => {
      const { templates: byNameAsc } = await JourneyTemplateService.getTemplates(
        {},
        'name',
        'asc',
        1,
        10
      )

      const { templates: byNameDesc } = await JourneyTemplateService.getTemplates(
        {},
        'name',
        'desc',
        1,
        10
      )

      expect(byNameAsc.length).toBeGreaterThan(1)
      expect(byNameDesc.length).toBeGreaterThan(1)

      // Check ascending order
      for (let i = 1; i < byNameAsc.length; i++) {
        expect(byNameAsc[i].name.localeCompare(byNameAsc[i - 1].name)).toBeGreaterThanOrEqual(0)
      }

      // Check descending order
      for (let i = 1; i < byNameDesc.length; i++) {
        expect(byNameDesc[i].name.localeCompare(byNameDesc[i - 1].name)).toBeLessThanOrEqual(0)
      }
    })
  })

  describe('Template Usage and Rating', () => {
    let testTemplate: JourneyTemplate

    beforeEach(async () => {
      testTemplate = await JourneyTemplateService.createTemplate(allJourneyTemplates[0])
    })

    it('should increment usage count correctly', async () => {
      const initialUsage = testTemplate.usageCount
      
      await JourneyTemplateService.incrementUsageCount(testTemplate.id)
      
      const updatedTemplate = await JourneyTemplateService.getTemplateById(testTemplate.id)
      expect(updatedTemplate!.usageCount).toBe(initialUsage + 1)
    })

    it('should calculate average rating correctly', async () => {
      // Add first rating
      let ratedTemplate = await JourneyTemplateService.updateTemplateRating(testTemplate.id, 4.0)
      expect(ratedTemplate!.rating).toBe(4.0)
      expect(ratedTemplate!.ratingCount).toBe(1)

      // Add second rating
      ratedTemplate = await JourneyTemplateService.updateTemplateRating(testTemplate.id, 5.0)
      expect(ratedTemplate!.rating).toBe(4.5) // (4.0 + 5.0) / 2
      expect(ratedTemplate!.ratingCount).toBe(2)

      // Add third rating
      ratedTemplate = await JourneyTemplateService.updateTemplateRating(testTemplate.id, 3.0)
      expect(ratedTemplate!.rating).toBe(4.0) // (4.0 + 5.0 + 3.0) / 3
      expect(ratedTemplate!.ratingCount).toBe(3)
    })

    it('should get popular templates based on usage', async () => {
      // Create templates with different usage counts
      await JourneyTemplateService.incrementUsageCount(testTemplate.id)
      await JourneyTemplateService.incrementUsageCount(testTemplate.id)
      await JourneyTemplateService.incrementUsageCount(testTemplate.id)

      const template2 = await JourneyTemplateService.createTemplate(allJourneyTemplates[1])
      await JourneyTemplateService.incrementUsageCount(template2.id)

      const popularTemplates = await JourneyTemplateService.getPopularTemplates(10)
      
      expect(popularTemplates.length).toBeGreaterThan(0)
      expect(popularTemplates[0].usageCount).toBeGreaterThanOrEqual(popularTemplates[popularTemplates.length - 1].usageCount)
    })
  })

  describe('Template Duplication', () => {
    it('should duplicate template with new name and reset stats', async () => {
      const originalTemplate = await JourneyTemplateService.createTemplate(allJourneyTemplates[0])
      
      // Add some usage and rating to original
      await JourneyTemplateService.incrementUsageCount(originalTemplate.id)
      await JourneyTemplateService.updateTemplateRating(originalTemplate.id, 4.5)

      const duplicatedTemplate = await JourneyTemplateService.duplicateTemplate(
        originalTemplate.id,
        'Duplicated Template',
        'user-123'
      )

      expect(duplicatedTemplate).not.toBeNull()
      expect(duplicatedTemplate!.id).not.toBe(originalTemplate.id)
      expect(duplicatedTemplate!.name).toBe('Duplicated Template')
      expect(duplicatedTemplate!.industry).toBe(originalTemplate.industry)
      expect(duplicatedTemplate!.category).toBe(originalTemplate.category)
      expect(duplicatedTemplate!.stages).toEqual(originalTemplate.stages)
      expect(duplicatedTemplate!.metadata).toEqual(originalTemplate.metadata)
      
      // Stats should be reset
      expect(duplicatedTemplate!.usageCount).toBe(0)
      expect(duplicatedTemplate!.rating).toBeNull()
      expect(duplicatedTemplate!.ratingCount).toBe(0)
      expect(duplicatedTemplate!.isPublic).toBe(false) // Duplicates are private by default
      expect(duplicatedTemplate!.createdBy).toBe('user-123')
    })

    it('should return null when duplicating non-existent template', async () => {
      const result = await JourneyTemplateService.duplicateTemplate(
        'non-existent-id',
        'Duplicate',
        'user-123'
      )

      expect(result).toBeNull()
    })
  })

  describe('Template Statistics', () => {
    beforeEach(async () => {
      // Create templates with different properties for stats testing
      const templates = allJourneyTemplates.slice(0, 3).map((template, index) => ({
        ...template,
        isPublic: index < 2, // First 2 are public
      }))

      const createdTemplates = await Promise.all(
        templates.map(template => JourneyTemplateService.createTemplate(template))
      )

      // Add ratings to some templates
      await JourneyTemplateService.updateTemplateRating(createdTemplates[0].id, 4.5)
      await JourneyTemplateService.updateTemplateRating(createdTemplates[1].id, 3.5)

      // Add usage to templates
      await JourneyTemplateService.incrementUsageCount(createdTemplates[0].id)
      await JourneyTemplateService.incrementUsageCount(createdTemplates[1].id)
      await JourneyTemplateService.incrementUsageCount(createdTemplates[1].id)
    })

    it('should calculate template statistics correctly', async () => {
      const stats = await JourneyTemplateService.getTemplateStats()

      expect(stats.totalTemplates).toBe(3)
      expect(stats.publicTemplates).toBe(2)
      // Check the average rating - should only consider templates with ratings
      expect(stats.averageRating).toBeGreaterThan(0)
      expect(stats.totalUsage).toBe(3) // 1 + 2 + 0
      expect(stats.industriesCount).toBeDefined()
      expect(stats.categoriesCount).toBeDefined()
      
      // Check industry counts
      Object.values(stats.industriesCount).forEach(count => {
        expect(count).toBeGreaterThanOrEqual(0)
      })
      
      // Check category counts
      Object.values(stats.categoriesCount).forEach(count => {
        expect(count).toBeGreaterThanOrEqual(0)
      })
    })
  })

  describe('Database Constraints and Edge Cases', () => {
    it('should handle large JSON data correctly', async () => {
      const largeTemplate = {
        ...allJourneyTemplates[0],
        stages: Array.from({ length: 10 }, (_, i) => ({
          id: `stage-${i}`,
          type: 'awareness' as const,
          title: `Stage ${i}`,
          description: `Description for stage ${i}`,
          position: { x: i * 100, y: 100 },
          contentTypes: Array.from({ length: 5 }, (_, j) => `Content Type ${j}`),
          messagingSuggestions: Array.from({ length: 10 }, (_, j) => `Message ${j} for stage ${i}`),
          channels: ['email', 'social_media', 'webinars'],
          objectives: Array.from({ length: 3 }, (_, j) => `Objective ${j}`),
          metrics: Array.from({ length: 5 }, (_, j) => `Metric ${j}`),
          duration: 7,
          automations: [],
        })),
        metadata: {
          tags: Array.from({ length: 20 }, (_, i) => `tag-${i}`),
          difficulty: 'advanced' as const,
          estimatedDuration: 30,
          requiredChannels: ['email', 'social_media', 'webinars', 'phone', 'in_person'],
          targetAudience: Array.from({ length: 5 }, (_, i) => `Audience ${i}`),
          businessGoals: Array.from({ length: 10 }, (_, i) => `Goal ${i}`),
          kpis: Array.from({ length: 15 }, (_, i) => `KPI ${i}`),
        },
      }

      const createdTemplate = await JourneyTemplateService.createTemplate(largeTemplate)
      
      expect(createdTemplate.stages).toHaveLength(10)
      expect(createdTemplate.metadata?.tags).toHaveLength(20)
      expect(createdTemplate.metadata?.kpis).toHaveLength(15)
    })

    it('should handle concurrent template operations', async () => {
      const templateData = allJourneyTemplates[0]
      
      // Create multiple templates concurrently
      const createPromises = Array.from({ length: 5 }, () =>
        JourneyTemplateService.createTemplate({
          ...templateData,
          name: `Concurrent Template ${Math.random()}`,
        })
      )
      
      const createdTemplates = await Promise.all(createPromises)
      
      expect(createdTemplates).toHaveLength(5)
      const ids = createdTemplates.map(t => t.id)
      const uniqueIds = new Set(ids)
      expect(uniqueIds.size).toBe(5) // All IDs should be unique
    })

    it('should handle template with minimal required fields', async () => {
      const minimalTemplate = {
        name: 'Minimal Template',
        industry: 'OTHER' as const,
        category: 'CUSTOMER_ACQUISITION' as const,
        stages: [
          {
            id: 'stage-1',
            type: 'awareness' as const,
            title: 'Basic Stage',
            description: 'A basic stage',
            position: { x: 0, y: 0 },
            contentTypes: ['Email'],
            messagingSuggestions: ['Hello'],
            channels: [],
            objectives: [],
            metrics: [],
            duration: 1,
            automations: [],
          },
        ],
        isActive: true,
        isPublic: true,
        usageCount: 0,
        ratingCount: 0,
      }

      const createdTemplate = await JourneyTemplateService.createTemplate(minimalTemplate)
      
      expect(createdTemplate.id).toBeDefined()
      expect(createdTemplate.name).toBe('Minimal Template')
      expect(createdTemplate.stages).toHaveLength(1)
      expect(createdTemplate.metadata).toBeNull()
      expect(createdTemplate.customizationConfig).toBeNull()
      expect(createdTemplate.defaultSettings).toBeNull()
    })
  })
})