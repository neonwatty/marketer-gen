import { JourneyCategoryValue,JourneyIndustryValue, JourneyTemplate } from '@/lib/types/journey'

import { JourneyTemplateService } from './journey-template-service'

// Mock the Prisma client
jest.mock('@/generated/prisma', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    journeyTemplate: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      update: jest.fn(),
    },
  })),
}))

// Import after mocking
import { PrismaClient } from '@/generated/prisma'
const mockPrisma = new PrismaClient() as jest.Mocked<PrismaClient>

const mockTemplate: Omit<JourneyTemplate, 'id' | 'createdAt' | 'updatedAt'> = {
  name: 'Test Template',
  description: 'A test journey template',
  industry: 'TECHNOLOGY' as JourneyIndustryValue,
  category: 'CUSTOMER_ACQUISITION' as JourneyCategoryValue,
  stages: [
    {
      id: 'stage-1',
      type: 'awareness',
      title: 'Awareness Stage',
      description: 'Build awareness',
      position: { x: 100, y: 100 },
      contentTypes: ['Blog Posts'],
      messagingSuggestions: ['Introduce your brand'],
      channels: ['email'],
      objectives: ['Build awareness'],
      metrics: ['impressions'],
      duration: 7,
      automations: [],
    },
  ],
  metadata: {
    tags: ['test'],
    difficulty: 'beginner',
    estimatedDuration: 7,
  },
  isActive: true,
  isPublic: true,
  customizationConfig: {
    allowStageReordering: true,
    allowStageAddition: true,
    allowStageDeletion: false,
    editableFields: ['title', 'description'],
    requiredFields: ['title'],
  },
  defaultSettings: {
    brandCompliance: true,
    autoOptimization: false,
    trackingSettings: {
      enableAnalytics: true,
      trackConversions: true,
    },
  },
  usageCount: 0,
  rating: undefined,
  ratingCount: 0,
  createdBy: 'user-123',
  updatedBy: 'user-123',
}

const mockPrismaTemplate = {
  id: 'template-123',
  ...mockTemplate,
  createdAt: new Date('2024-01-01'),
  updatedAt: new Date('2024-01-01'),
  deletedAt: null,
}

describe('JourneyTemplateService', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    JourneyTemplateService.setPrismaClient(mockPrisma as any)
  })

  describe('createTemplate', () => {
    it('should create a new template successfully', async () => {
      mockPrisma.journeyTemplate.create.mockResolvedValue(mockPrismaTemplate)

      const result = await JourneyTemplateService.createTemplate(mockTemplate)

      expect(mockPrisma.journeyTemplate.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          name: mockTemplate.name,
          description: mockTemplate.description,
          industry: mockTemplate.industry,
          category: mockTemplate.category,
          stages: mockTemplate.stages,
          metadata: mockTemplate.metadata,
          isActive: mockTemplate.isActive,
          isPublic: mockTemplate.isPublic,
          usageCount: 0,
          ratingCount: 0,
        }),
      })

      expect(result).toEqual(expect.objectContaining({
        id: 'template-123',
        name: mockTemplate.name,
        industry: mockTemplate.industry,
        category: mockTemplate.category,
      }))
    })

    it('should throw validation error for invalid template data', async () => {
      const invalidTemplate = {
        ...mockTemplate,
        name: '', // Invalid: empty name
        stages: [], // Invalid: no stages
      }

      await expect(JourneyTemplateService.createTemplate(invalidTemplate)).rejects.toThrow()
    })
  })

  describe('getTemplateById', () => {
    it('should return template when found', async () => {
      mockPrisma.journeyTemplate.findUnique.mockResolvedValue(mockPrismaTemplate)

      const result = await JourneyTemplateService.getTemplateById('template-123')

      expect(mockPrisma.journeyTemplate.findUnique).toHaveBeenCalledWith({
        where: {
          id: 'template-123',
          deletedAt: null,
        },
      })

      expect(result).toEqual(expect.objectContaining({
        id: 'template-123',
        name: mockTemplate.name,
      }))
    })

    it('should return null when template not found', async () => {
      mockPrisma.journeyTemplate.findUnique.mockResolvedValue(null)

      const result = await JourneyTemplateService.getTemplateById('non-existent')

      expect(result).toBeNull()
    })
  })

  describe('getTemplates', () => {
    const mockTemplates = [mockPrismaTemplate, { ...mockPrismaTemplate, id: 'template-456' }]

    it('should return paginated templates with default parameters', async () => {
      mockPrisma.journeyTemplate.count.mockResolvedValue(2)
      mockPrisma.journeyTemplate.findMany.mockResolvedValue(mockTemplates)

      const result = await JourneyTemplateService.getTemplates()

      expect(mockPrisma.journeyTemplate.count).toHaveBeenCalledWith({
        where: { deletedAt: null },
      })

      expect(mockPrisma.journeyTemplate.findMany).toHaveBeenCalledWith({
        where: { deletedAt: null },
        orderBy: { createdAt: 'desc' },
        skip: 0,
        take: 20,
      })

      expect(result).toEqual({
        templates: expect.arrayContaining([
          expect.objectContaining({ id: 'template-123' }),
          expect.objectContaining({ id: 'template-456' }),
        ]),
        totalCount: 2,
        pageCount: 1,
      })
    })

    it('should apply industry filter', async () => {
      mockPrisma.journeyTemplate.count.mockResolvedValue(1)
      mockPrisma.journeyTemplate.findMany.mockResolvedValue([mockPrismaTemplate])

      const filters = { industry: ['TECHNOLOGY' as JourneyIndustryValue] }
      await JourneyTemplateService.getTemplates(filters)

      expect(mockPrisma.journeyTemplate.findMany).toHaveBeenCalledWith({
        where: {
          deletedAt: null,
          industry: { in: ['TECHNOLOGY'] },
        },
        orderBy: { createdAt: 'desc' },
        skip: 0,
        take: 20,
      })
    })

    it('should apply search query filter', async () => {
      mockPrisma.journeyTemplate.count.mockResolvedValue(1)
      mockPrisma.journeyTemplate.findMany.mockResolvedValue([mockPrismaTemplate])

      const filters = { searchQuery: 'test' }
      await JourneyTemplateService.getTemplates(filters)

      expect(mockPrisma.journeyTemplate.findMany).toHaveBeenCalledWith({
        where: {
          deletedAt: null,
          OR: [
            { name: { contains: 'test' } },
            { description: { contains: 'test' } },
          ],
        },
        orderBy: { createdAt: 'desc' },
        skip: 0,
        take: 20,
      })
    })

    it('should handle pagination correctly', async () => {
      mockPrisma.journeyTemplate.count.mockResolvedValue(25)
      mockPrisma.journeyTemplate.findMany.mockResolvedValue(mockTemplates)

      const result = await JourneyTemplateService.getTemplates({}, 'name', 'asc', 2, 10)

      expect(mockPrisma.journeyTemplate.findMany).toHaveBeenCalledWith({
        where: { deletedAt: null },
        orderBy: { name: 'asc' },
        skip: 10, // (page - 1) * pageSize
        take: 10,
      })

      expect(result.pageCount).toBe(3) // Math.ceil(25 / 10)
    })
  })

  describe('updateTemplate', () => {
    it('should update template successfully', async () => {
      const updatedTemplate = { ...mockPrismaTemplate, name: 'Updated Template' }
      mockPrisma.journeyTemplate.update.mockResolvedValue(updatedTemplate)

      const updates = { name: 'Updated Template' }
      const result = await JourneyTemplateService.updateTemplate('template-123', updates)

      expect(mockPrisma.journeyTemplate.update).toHaveBeenCalledWith({
        where: { id: 'template-123' },
        data: expect.objectContaining({
          name: 'Updated Template',
        }),
      })

      expect(result?.name).toBe('Updated Template')
    })
  })

  describe('deleteTemplate', () => {
    it('should soft delete template', async () => {
      mockPrisma.journeyTemplate.update.mockResolvedValue(mockPrismaTemplate)

      const result = await JourneyTemplateService.deleteTemplate('template-123')

      expect(mockPrisma.journeyTemplate.update).toHaveBeenCalledWith({
        where: { id: 'template-123' },
        data: { deletedAt: expect.any(Date) },
      })

      expect(result).toBe(true)
    })

    it('should return false on error', async () => {
      mockPrisma.journeyTemplate.update.mockRejectedValue(new Error('Database error'))

      const result = await JourneyTemplateService.deleteTemplate('template-123')

      expect(result).toBe(false)
    })
  })

  describe('incrementUsageCount', () => {
    it('should increment usage count', async () => {
      mockPrisma.journeyTemplate.update.mockResolvedValue(mockPrismaTemplate)

      await JourneyTemplateService.incrementUsageCount('template-123')

      expect(mockPrisma.journeyTemplate.update).toHaveBeenCalledWith({
        where: { id: 'template-123' },
        data: { usageCount: { increment: 1 } },
      })
    })
  })

  describe('updateTemplateRating', () => {
    it('should calculate and update average rating', async () => {
      const templateWithRating = {
        ...mockPrismaTemplate,
        rating: 4.0,
        ratingCount: 2,
      }
      
      const updatedTemplate = {
        ...templateWithRating,
        rating: 4.33, // (4.0 * 2 + 5) / 3
        ratingCount: 3,
      }

      mockPrisma.journeyTemplate.findUnique.mockResolvedValue(templateWithRating)
      mockPrisma.journeyTemplate.update.mockResolvedValue(updatedTemplate)

      const result = await JourneyTemplateService.updateTemplateRating('template-123', 5)

      expect(mockPrisma.journeyTemplate.update).toHaveBeenCalledWith({
        where: { id: 'template-123' },
        data: {
          rating: expect.closeTo(4.33, 2),
          ratingCount: 3,
        },
      })

      expect(result?.rating).toBeCloseTo(4.33, 2)
      expect(result?.ratingCount).toBe(3)
    })

    it('should handle first rating', async () => {
      const templateWithoutRating = {
        ...mockPrismaTemplate,
        rating: null,
        ratingCount: 0,
      }
      
      const updatedTemplate = {
        ...templateWithoutRating,
        rating: 5.0,
        ratingCount: 1,
      }

      mockPrisma.journeyTemplate.findUnique.mockResolvedValue(templateWithoutRating)
      mockPrisma.journeyTemplate.update.mockResolvedValue(updatedTemplate)

      const result = await JourneyTemplateService.updateTemplateRating('template-123', 5)

      expect(mockPrisma.journeyTemplate.update).toHaveBeenCalledWith({
        where: { id: 'template-123' },
        data: {
          rating: 5.0,
          ratingCount: 1,
        },
      })

      expect(result?.rating).toBe(5.0)
      expect(result?.ratingCount).toBe(1)
    })
  })

  describe('duplicateTemplate', () => {
    it('should create a duplicate template', async () => {
      const duplicatedTemplate = {
        ...mockPrismaTemplate,
        id: 'template-duplicate',
        name: 'Test Template (Copy)',
        isPublic: false,
        usageCount: 0,
        rating: null,
        ratingCount: 0,
      }

      // Mock the service methods
      jest.spyOn(JourneyTemplateService, 'getTemplateById').mockResolvedValue({
        ...mockTemplate,
        id: 'template-123',
        createdAt: '2024-01-01T00:00:00.000Z',
        updatedAt: '2024-01-01T00:00:00.000Z',
      })

      jest.spyOn(JourneyTemplateService, 'createTemplate').mockResolvedValue({
        ...mockTemplate,
        id: 'template-duplicate',
        name: 'Test Template (Copy)',
        isPublic: false,
        usageCount: 0,
        rating: undefined,
        ratingCount: 0,
        createdAt: '2024-01-01T00:00:00.000Z',
        updatedAt: '2024-01-01T00:00:00.000Z',
      })

      const result = await JourneyTemplateService.duplicateTemplate(
        'template-123',
        'Test Template (Copy)',
        'user-456'
      )

      expect(result).toEqual(expect.objectContaining({
        id: 'template-duplicate',
        name: 'Test Template (Copy)',
        isPublic: false,
        usageCount: 0,
        ratingCount: 0,
      }))
    })

    it('should return null for non-existent template', async () => {
      jest.spyOn(JourneyTemplateService, 'getTemplateById').mockResolvedValue(null)

      const result = await JourneyTemplateService.duplicateTemplate(
        'non-existent',
        'Copy',
        'user-456'
      )

      expect(result).toBeNull()
    })
  })

  describe('validateTemplateData', () => {
    it('should validate correct template data', () => {
      const result = JourneyTemplateService.validateTemplateData(mockTemplate)

      expect(result.isValid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('should return validation errors for invalid data', () => {
      const invalidTemplate = {
        ...mockTemplate,
        name: '', // Invalid: empty name
        stages: [], // Invalid: no stages
        industry: 'INVALID_INDUSTRY',
      }

      const result = JourneyTemplateService.validateTemplateData(invalidTemplate)

      expect(result.isValid).toBe(false)
      expect(result.errors.length).toBeGreaterThan(0)
    })
  })

  describe('getTemplateStats', () => {
    it('should calculate template statistics correctly', async () => {
      const mockStats = [
        {
          industry: 'TECHNOLOGY',
          category: 'CUSTOMER_ACQUISITION',
          rating: 4.5,
          usageCount: 10,
          isPublic: true,
        },
        {
          industry: 'SAAS',
          category: 'ONBOARDING',
          rating: 3.8,
          usageCount: 15,
          isPublic: true,
        },
        {
          industry: 'TECHNOLOGY',
          category: 'RETENTION',
          rating: null,
          usageCount: 5,
          isPublic: false,
        },
      ]

      mockPrisma.journeyTemplate.findMany.mockResolvedValue(mockStats)

      const result = await JourneyTemplateService.getTemplateStats()

      expect(result).toEqual({
        totalTemplates: 3,
        publicTemplates: 2,
        averageRating: 4.15, // (4.5 + 3.8) / 2
        totalUsage: 30, // 10 + 15 + 5
        industriesCount: {
          TECHNOLOGY: 2,
          SAAS: 1,
        },
        categoriesCount: {
          CUSTOMER_ACQUISITION: 1,
          ONBOARDING: 1,
          RETENTION: 1,
        },
      })
    })
  })
})