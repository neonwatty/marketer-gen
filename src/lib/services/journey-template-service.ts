import { PrismaClient } from '@/generated/prisma'
import {
  JourneyCategoryValue,
  JourneyIndustryValue,
  JourneyTemplate,
  JourneyTemplateFilters,
  JourneyTemplateFiltersSchema,
  JourneyTemplateSchema,
  JourneyTemplateSortBy,
  JourneyTemplateSortOrder,
} from '@/lib/types/journey'

let prisma = new PrismaClient()

export class JourneyTemplateService {
  static setPrismaClient(client: PrismaClient) {
    prisma = client
  }
  /**
   * Create a new journey template
   */
  static async createTemplate(templateData: Omit<JourneyTemplate, 'id' | 'createdAt' | 'updatedAt' | 'usageCount' | 'ratingCount'>): Promise<JourneyTemplate> {
    // Validate the template data
    const validatedData = JourneyTemplateSchema.parse({
      ...templateData,
      usageCount: 0,
      ratingCount: 0,
    })

    const createdTemplate = await prisma.journeyTemplate.create({
      data: {
        name: validatedData.name,
        description: validatedData.description,
        industry: validatedData.industry,
        category: validatedData.category,
        stages: validatedData.stages as any, // Prisma Json type
        metadata: validatedData.metadata as any,
        isActive: validatedData.isActive,
        isPublic: validatedData.isPublic,
        customizationConfig: validatedData.customizationConfig as any,
        defaultSettings: validatedData.defaultSettings as any,
        usageCount: 0,
        rating: templateData.rating,
        ratingCount: 0,
        createdBy: templateData.createdBy,
        updatedBy: templateData.updatedBy,
      },
    })

    return this.mapPrismaToJourneyTemplate(createdTemplate)
  }

  /**
   * Get a journey template by ID
   */
  static async getTemplateById(id: string): Promise<JourneyTemplate | null> {
    const template = await prisma.journeyTemplate.findUnique({
      where: { 
        id,
        deletedAt: null // Exclude soft deleted templates
      },
    })

    return template ? this.mapPrismaToJourneyTemplate(template) : null
  }

  /**
   * Get multiple journey templates with filtering, sorting, and pagination
   */
  static async getTemplates(
    filters: JourneyTemplateFilters = {},
    sortBy: JourneyTemplateSortBy = 'createdAt',
    sortOrder: JourneyTemplateSortOrder = 'desc',
    page: number = 1,
    pageSize: number = 20
  ): Promise<{
    templates: JourneyTemplate[]
    totalCount: number
    pageCount: number
  }> {
    // Validate filters
    const validatedFilters = JourneyTemplateFiltersSchema.parse(filters)

    // Build where clause
    const whereClause: any = {
      deletedAt: null, // Exclude soft deleted templates
    }

    if (validatedFilters.industry && validatedFilters.industry.length > 0) {
      whereClause.industry = { in: validatedFilters.industry }
    }

    if (validatedFilters.category && validatedFilters.category.length > 0) {
      whereClause.category = { in: validatedFilters.category }
    }

    if (validatedFilters.isPublic !== undefined) {
      whereClause.isPublic = validatedFilters.isPublic
    }

    if (validatedFilters.minRating) {
      whereClause.rating = { gte: validatedFilters.minRating }
    }

    if (validatedFilters.searchQuery) {
      whereClause.OR = [
        { name: { contains: validatedFilters.searchQuery } },
        { description: { contains: validatedFilters.searchQuery } },
      ]
    }

    // Handle metadata-based filters (tags, difficulty, channels)
    if (validatedFilters.tags && validatedFilters.tags.length > 0) {
      whereClause.metadata = {
        path: ['tags'],
        array_contains: validatedFilters.tags,
      }
    }

    if (validatedFilters.difficulty && validatedFilters.difficulty.length > 0) {
      whereClause.metadata = {
        ...whereClause.metadata,
        path: ['difficulty'],
        in: validatedFilters.difficulty,
      }
    }

    if (validatedFilters.channels && validatedFilters.channels.length > 0) {
      whereClause.metadata = {
        ...whereClause.metadata,
        path: ['requiredChannels'],
        array_contains: validatedFilters.channels,
      }
    }

    // Get total count
    const totalCount = await prisma.journeyTemplate.count({ where: whereClause })

    // Get templates with pagination
    const templates = await prisma.journeyTemplate.findMany({
      where: whereClause,
      orderBy: { [sortBy]: sortOrder },
      skip: (page - 1) * pageSize,
      take: pageSize,
    })

    const pageCount = Math.ceil(totalCount / pageSize)

    return {
      templates: templates.map(this.mapPrismaToJourneyTemplate),
      totalCount,
      pageCount,
    }
  }

  /**
   * Get templates by industry
   */
  static async getTemplatesByIndustry(industry: JourneyIndustryValue): Promise<JourneyTemplate[]> {
    const { templates } = await this.getTemplates({ industry: [industry] })
    return templates
  }

  /**
   * Get templates by category
   */
  static async getTemplatesByCategory(category: JourneyCategoryValue): Promise<JourneyTemplate[]> {
    const { templates } = await this.getTemplates({ category: [category] })
    return templates
  }

  /**
   * Get popular templates (sorted by usage count)
   */
  static async getPopularTemplates(limit: number = 10): Promise<JourneyTemplate[]> {
    const { templates } = await this.getTemplates({}, 'usageCount', 'desc', 1, limit)
    return templates
  }

  /**
   * Get highly rated templates
   */
  static async getHighlyRatedTemplates(minRating: number = 4.0, limit: number = 10): Promise<JourneyTemplate[]> {
    const { templates } = await this.getTemplates({ minRating }, 'rating', 'desc', 1, limit)
    return templates
  }

  /**
   * Update a journey template
   */
  static async updateTemplate(
    id: string,
    updates: Partial<Omit<JourneyTemplate, 'id' | 'createdAt' | 'updatedAt'>>
  ): Promise<JourneyTemplate | null> {
    // Note: Skip validation for partial updates as they may not have all required fields

    const updatedTemplate = await prisma.journeyTemplate.update({
      where: { id },
      data: {
        ...(updates.name && { name: updates.name }),
        ...(updates.description !== undefined && { description: updates.description }),
        ...(updates.industry && { industry: updates.industry }),
        ...(updates.category && { category: updates.category }),
        ...(updates.stages && { stages: updates.stages as any }),
        ...(updates.metadata !== undefined && { metadata: updates.metadata as any }),
        ...(updates.isActive !== undefined && { isActive: updates.isActive }),
        ...(updates.isPublic !== undefined && { isPublic: updates.isPublic }),
        ...(updates.customizationConfig !== undefined && { customizationConfig: updates.customizationConfig as any }),
        ...(updates.defaultSettings !== undefined && { defaultSettings: updates.defaultSettings as any }),
        ...(updates.rating !== undefined && { rating: updates.rating }),
        ...(updates.updatedBy && { updatedBy: updates.updatedBy }),
      },
    })

    return this.mapPrismaToJourneyTemplate(updatedTemplate)
  }

  /**
   * Soft delete a journey template
   */
  static async deleteTemplate(id: string): Promise<boolean> {
    try {
      await prisma.journeyTemplate.update({
        where: { id },
        data: { deletedAt: new Date() },
      })
      return true
    } catch (error) {
      console.error('Error deleting template:', error)
      return false
    }
  }

  /**
   * Increment template usage count
   */
  static async incrementUsageCount(id: string): Promise<void> {
    await prisma.journeyTemplate.update({
      where: { id },
      data: { usageCount: { increment: 1 } },
    })
  }

  /**
   * Add or update template rating
   */
  static async updateTemplateRating(id: string, newRating: number): Promise<JourneyTemplate | null> {
    const template = await prisma.journeyTemplate.findUnique({
      where: { id },
    })

    if (!template) return null

    // Calculate new average rating
    const currentRating = template.rating || 0
    const currentRatingCount = template.ratingCount || 0
    const totalRating = currentRating * currentRatingCount + newRating
    const newRatingCount = currentRatingCount + 1
    const newAverageRating = totalRating / newRatingCount

    const updatedTemplate = await prisma.journeyTemplate.update({
      where: { id },
      data: {
        rating: newAverageRating,
        ratingCount: newRatingCount,
      },
    })

    return this.mapPrismaToJourneyTemplate(updatedTemplate)
  }

  /**
   * Duplicate a template (create a copy)
   */
  static async duplicateTemplate(
    id: string,
    newName: string,
    createdBy?: string
  ): Promise<JourneyTemplate | null> {
    const originalTemplate = await this.getTemplateById(id)
    if (!originalTemplate) return null

    const { id: _id, createdAt: _createdAt, updatedAt: _updatedAt, usageCount: _usageCount, ratingCount: _ratingCount, ...templateWithoutMeta } = originalTemplate
    
    const duplicatedTemplate = await this.createTemplate({
      ...templateWithoutMeta,
      name: newName,
      isPublic: false, // Duplicated templates are private by default
      rating: undefined,
      createdBy,
      updatedBy: createdBy,
    })

    return duplicatedTemplate
  }

  /**
   * Get template statistics
   */
  static async getTemplateStats(): Promise<{
    totalTemplates: number
    publicTemplates: number
    averageRating: number
    totalUsage: number
    industriesCount: Record<JourneyIndustryValue, number>
    categoriesCount: Record<JourneyCategoryValue, number>
  }> {
    const templates = await prisma.journeyTemplate.findMany({
      where: { deletedAt: null },
      select: {
        industry: true,
        category: true,
        rating: true,
        usageCount: true,
        isPublic: true,
      },
    })

    const stats = {
      totalTemplates: templates.length,
      publicTemplates: templates.filter(t => t.isPublic).length,
      averageRating: 0,
      totalUsage: 0,
      industriesCount: {} as Record<JourneyIndustryValue, number>,
      categoriesCount: {} as Record<JourneyCategoryValue, number>,
    }

    let totalRatingSum = 0
    let ratedTemplatesCount = 0

    templates.forEach((template: any) => {
      // Calculate average rating
      if (template.rating) {
        totalRatingSum += template.rating
        ratedTemplatesCount++
      }

      // Sum total usage
      stats.totalUsage += template.usageCount

      // Count industries
      const industryKey = template.industry as JourneyIndustryValue
      stats.industriesCount[industryKey] = (stats.industriesCount[industryKey] || 0) + 1

      // Count categories
      const categoryKey = template.category as JourneyCategoryValue
      stats.categoriesCount[categoryKey] = (stats.categoriesCount[categoryKey] || 0) + 1
    })

    stats.averageRating = ratedTemplatesCount > 0 ? totalRatingSum / ratedTemplatesCount : 0

    return stats
  }

  /**
   * Search templates by text query
   */
  static async searchTemplates(query: string, limit: number = 20): Promise<JourneyTemplate[]> {
    const { templates } = await this.getTemplates({ searchQuery: query }, 'rating', 'desc', 1, limit)
    return templates
  }

  /**
   * Get recommended templates based on industry and category preferences
   */
  static async getRecommendedTemplates(
    preferredIndustries: JourneyIndustryValue[] = [],
    preferredCategories: JourneyCategoryValue[] = [],
    limit: number = 10
  ): Promise<JourneyTemplate[]> {
    const filters: JourneyTemplateFilters = {}
    
    if (preferredIndustries.length > 0) {
      filters.industry = preferredIndustries
    }
    
    if (preferredCategories.length > 0) {
      filters.category = preferredCategories
    }

    const { templates } = await this.getTemplates(filters, 'rating', 'desc', 1, limit)
    
    // If we don't have enough results, get more popular templates
    if (templates.length < limit) {
      const additionalTemplates = await this.getPopularTemplates(limit - templates.length)
      return [...templates, ...additionalTemplates]
    }
    
    return templates
  }

  /**
   * Validate template JSON data structure
   */
  static validateTemplateData(templateData: any): { isValid: boolean; errors: string[] } {
    try {
      JourneyTemplateSchema.parse(templateData)
      return { isValid: true, errors: [] }
    } catch (error: any) {
      const errors = error.errors?.map((err: any) => err.message) || [error.message]
      return { isValid: false, errors }
    }
  }

  /**
   * Map Prisma model to JourneyTemplate interface
   */
  private static mapPrismaToJourneyTemplate(prismaTemplate: any): JourneyTemplate {
    return {
      id: prismaTemplate.id,
      name: prismaTemplate.name,
      description: prismaTemplate.description,
      industry: prismaTemplate.industry,
      category: prismaTemplate.category,
      stages: prismaTemplate.stages as any, // Cast from Prisma Json
      metadata: prismaTemplate.metadata as any,
      isActive: prismaTemplate.isActive,
      isPublic: prismaTemplate.isPublic,
      customizationConfig: prismaTemplate.customizationConfig as any,
      defaultSettings: prismaTemplate.defaultSettings as any,
      usageCount: prismaTemplate.usageCount,
      rating: prismaTemplate.rating,
      ratingCount: prismaTemplate.ratingCount,
      createdAt: prismaTemplate.createdAt.toISOString(),
      updatedAt: prismaTemplate.updatedAt.toISOString(),
      createdBy: prismaTemplate.createdBy,
      updatedBy: prismaTemplate.updatedBy,
    }
  }
}

export default JourneyTemplateService