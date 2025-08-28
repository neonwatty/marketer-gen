import { PrismaClient } from '@/generated/prisma'
import { withQueryMetrics } from '../database'

// Query optimization utilities
export class QueryOptimizer {
  private prisma: PrismaClient

  constructor(prisma: PrismaClient) {
    this.prisma = prisma
  }

  // Optimized brand queries
  async getBrandsOptimized(params: {
    page?: number
    limit?: number
    search?: string
    industry?: string
    userId?: string
  }) {
    return withQueryMetrics('getBrandsOptimized', async () => {
      const { page = 1, limit = 10, search, industry, userId } = params
      const skip = (page - 1) * limit

      // Build optimized where clause
      const where: any = {
        deletedAt: null,
        ...(userId && { userId }),
      }

      // Use full-text search if available, otherwise fallback to LIKE
      if (search) {
        where.OR = [
          { name: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
          { tagline: { contains: search, mode: 'insensitive' } },
        ]
      }

      if (industry) {
        where.industry = { contains: industry, mode: 'insensitive' }
      }

      // Use Promise.all for concurrent queries
      const [brands, total] = await Promise.all([
        this.prisma.brand.findMany({
          where,
          select: {
            id: true,
            name: true,
            description: true,
            industry: true,
            tagline: true,
            website: true,
            createdAt: true,
            updatedAt: true,
            user: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
            // Use count instead of loading all related records
            _count: {
              select: {
                campaigns: { where: { deletedAt: null } },
                brandAssets: { where: { deletedAt: null, isActive: true } },
                colorPalette: { where: { deletedAt: null, isActive: true } },
                typography: { where: { deletedAt: null, isActive: true } },
              },
            },
          },
          orderBy: { updatedAt: 'desc' },
          skip,
          take: limit,
        }),
        this.prisma.brand.count({ where }),
      ])

      return {
        brands,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
      }
    })
  }

  // Optimized brand detail query
  async getBrandWithRelationsOptimized(id: string) {
    return withQueryMetrics('getBrandWithRelationsOptimized', async () => {
      return this.prisma.brand.findUnique({
        where: { id, deletedAt: null },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
            },
          },
          campaigns: {
            where: { deletedAt: null },
            select: {
              id: true,
              name: true,
              status: true,
              createdAt: true,
              updatedAt: true,
            },
            orderBy: { updatedAt: 'desc' },
            take: 10, // Limit related records
          },
          brandAssets: {
            where: { deletedAt: null, isActive: true },
            select: {
              id: true,
              name: true,
              type: true,
              category: true,
              fileUrl: true,
              fileName: true,
              fileSize: true,
              mimeType: true,
              createdAt: true,
            },
            orderBy: { createdAt: 'desc' },
            take: 20, // Limit related records
          },
          colorPalette: {
            where: { deletedAt: null, isActive: true },
            select: {
              id: true,
              name: true,
              colors: true,
              isPrimary: true,
            },
            take: 10,
          },
          typography: {
            where: { deletedAt: null, isActive: true },
            select: {
              id: true,
              name: true,
              fontFamily: true,
              fontSize: true,
              fontWeight: true,
              isPrimary: true,
            },
            take: 10,
          },
          _count: {
            select: {
              campaigns: { where: { deletedAt: null } },
              brandAssets: { where: { deletedAt: null, isActive: true } },
            },
          },
        },
      })
    })
  }

  // Optimized campaign queries
  async getCampaignsOptimized(params: {
    page?: number
    limit?: number
    search?: string
    status?: string
    brandId?: string
    userId?: string
  }) {
    return withQueryMetrics('getCampaignsOptimized', async () => {
      const { page = 1, limit = 10, search, status, brandId, userId } = params
      const skip = (page - 1) * limit

      const where: any = {
        deletedAt: null,
        ...(brandId && { brandId }),
        ...(userId && { userId }),
        ...(status && { status }),
      }

      if (search) {
        where.OR = [
          { name: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
        ]
      }

      const [campaigns, total] = await Promise.all([
        this.prisma.campaign.findMany({
          where,
          select: {
            id: true,
            name: true,
            status: true,
            createdAt: true,
            updatedAt: true,
            brand: {
              select: {
                id: true,
                name: true,
              },
            },
            user: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
          },
          orderBy: { updatedAt: 'desc' },
          skip,
          take: limit,
        }),
        this.prisma.campaign.count({ where }),
      ])

      return {
        campaigns,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
      }
    })
  }

  // Optimized journey template queries
  async getJourneyTemplatesOptimized(params: {
    page?: number
    limit?: number
    search?: string
    category?: string
    industry?: string
    difficulty?: string
    isPublic?: boolean
    userId?: string
  }) {
    return withQueryMetrics('getJourneyTemplatesOptimized', async () => {
      const { 
        page = 1, 
        limit = 10, 
        search, 
        category, 
        industry, 
        difficulty, 
        isPublic, 
        userId 
      } = params
      const skip = (page - 1) * limit

      const where: any = {
        deletedAt: null,
        ...(category && { category }),
        ...(industry && { industry }),
        ...(difficulty && { difficulty }),
        ...(isPublic !== undefined && { isPublic }),
        ...(userId && { userId }),
      }

      if (search) {
        where.OR = [
          { name: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
          { targetAudience: { contains: search, mode: 'insensitive' } },
        ]
      }

      const [templates, total] = await Promise.all([
        this.prisma.journeyTemplate.findMany({
          where,
          select: {
            id: true,
            name: true,
            description: true,
            industry: true,
            createdAt: true,
            updatedAt: true,
          },
          orderBy: [
            { isPublic: 'desc' },
            { updatedAt: 'desc' },
          ],
          skip,
          take: limit,
        }),
        this.prisma.journeyTemplate.count({ where }),
      ])

      return {
        templates,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
      }
    })
  }

  // Batch operations for performance
  async batchUpdateBrandAssets(
    brandId: string,
    updates: Array<{ id: string; data: any }>
  ) {
    return withQueryMetrics('batchUpdateBrandAssets', async () => {
      const operations = updates.map(update => 
        this.prisma.brandAsset.update({
          where: { id: update.id, brandId },
          data: update.data,
        })
      )

      return this.prisma.$transaction(operations)
    })
  }

  // Efficient existence checks
  async checkResourceExists(
    model: string,
    id: string,
    additionalWhere: any = {}
  ): Promise<boolean> {
    return withQueryMetrics(`checkResourceExists:${model}`, async () => {
      const count = await (this.prisma as any)[model].count({
        where: {
          id,
          deletedAt: null,
          ...additionalWhere,
        },
      })
      return count > 0
    })
  }

  // Optimized aggregation queries
  async getBrandAnalytics(brandId: string) {
    return withQueryMetrics('getBrandAnalytics', async () => {
      const [
        campaignStats,
        assetStats,
        recentActivity,
      ] = await Promise.all([
        // Campaign statistics
        this.prisma.campaign.groupBy({
          by: ['status'],
          where: { brandId, deletedAt: null },
          _count: true,
        }),
        
        // Asset statistics
        this.prisma.brandAsset.groupBy({
          by: ['type'],
          where: { brandId, deletedAt: null, isActive: true },
          _count: true,
        }),
        
        // Recent activity (last 30 days)
        this.prisma.campaign.findMany({
          where: {
            brandId,
            deletedAt: null,
            updatedAt: {
              gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
            },
          },
          select: {
            id: true,
            name: true,
            status: true,
            updatedAt: true,
          },
          orderBy: { updatedAt: 'desc' },
          take: 10,
        }),
      ])

      return {
        campaigns: {
          total: campaignStats.reduce((sum, stat) => sum + stat._count, 0),
          byStatus: campaignStats.reduce((acc, stat) => {
            acc[stat.status] = stat._count
            return acc
          }, {} as Record<string, number>),
        },
        assets: {
          total: assetStats.reduce((sum, stat) => sum + stat._count, 0),
          byType: assetStats.reduce((acc, stat) => {
            acc[stat.type] = stat._count
            return acc
          }, {} as Record<string, number>),
        },
        recentActivity,
      }
    })
  }

  // Database health and performance metrics
  async getDatabaseMetrics() {
    return withQueryMetrics('getDatabaseMetrics', async () => {
      const [
        userCount,
        brandCount,
        campaignCount,
        assetCount,
        templateCount,
      ] = await Promise.all([
        this.prisma.user.count({ where: { deletedAt: null } }),
        this.prisma.brand.count({ where: { deletedAt: null } }),
        this.prisma.campaign.count({ where: { deletedAt: null } }),
        this.prisma.brandAsset.count({ where: { deletedAt: null } }),
        this.prisma.journeyTemplate.count({ where: { deletedAt: null } }),
      ])

      return {
        counts: {
          users: userCount,
          brands: brandCount,
          campaigns: campaignCount,
          assets: assetCount,
          templates: templateCount,
        },
        timestamp: new Date().toISOString(),
      }
    })
  }
}

// Connection query patterns for common operations
export const queryPatterns = {
  // Efficient user check with minimal data
  userExists: (prisma: PrismaClient, id: string) =>
    prisma.user.findUnique({
      where: { id, deletedAt: null },
      select: { id: true },
    }),

  // Brand ownership verification
  verifyBrandOwnership: (prisma: PrismaClient, brandId: string, userId: string) =>
    prisma.brand.findUnique({
      where: { id: brandId, userId, deletedAt: null },
      select: { id: true },
    }),

  // Campaign ownership verification
  verifyCampaignOwnership: (prisma: PrismaClient, campaignId: string, userId: string) =>
    prisma.campaign.findFirst({
      where: {
        id: campaignId,
        OR: [
          { userId },
          { brand: { userId } },
        ],
        deletedAt: null,
      },
      select: { id: true },
    }),

  // Get user's accessible brands (owned or shared)
  getUserBrands: (prisma: PrismaClient, userId: string) =>
    prisma.brand.findMany({
      where: {
        userId,
        deletedAt: null,
      },
      select: {
        id: true,
        name: true,
      },
      orderBy: { name: 'asc' },
    }),

  // Soft delete pattern
  softDelete: (prisma: PrismaClient, model: string, id: string, userId?: string) =>
    (prisma as any)[model].update({
      where: {
        id,
        ...(userId && { userId }),
        deletedAt: null,
      },
      data: { deletedAt: new Date() },
    }),
}

// Create optimizer instance
export const createQueryOptimizer = (prisma: PrismaClient) => new QueryOptimizer(prisma)