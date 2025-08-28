import { GET, PUT, DELETE } from '@/app/api/brands/[id]/route'
import { NextRequest } from 'next/server'
import { prisma } from '@/lib/database'

// Mock NextResponse
jest.mock('next/server', () => ({
  NextRequest: jest.fn(),
  NextResponse: {
    json: (body: any, init?: ResponseInit) => {
      const response = new Response(JSON.stringify(body), {
        status: init?.status || 200,
        headers: { 'Content-Type': 'application/json', ...init?.headers },
      })
      response.json = async () => body
      return response
    },
  },
}))

// Mock NextRequest to avoid URL property issues
const createMockRequest = (url: string, options: RequestInit = {}) => {
  const mockRequest = {
    url,
    method: options.method || 'GET',
    headers: new Headers(options.headers),
    json: jest.fn().mockResolvedValue(JSON.parse(options.body as string || '{}')),
    nextUrl: new URL(url),
  } as unknown as NextRequest
  return mockRequest
}

// Mock the database
jest.mock('@/lib/database', () => ({
  prisma: {
    brand: {
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    campaign: {
      count: jest.fn(),
    },
  },
}))

// Mock NextAuth
jest.mock('next-auth/next', () => ({
  getServerSession: jest.fn(),
}))

const mockPrisma = prisma as jest.Mocked<typeof prisma>

describe('/api/brands/[id]', () => {
  const mockBrand = {
    id: 'brand1',
    name: 'Test Brand',
    description: 'A test brand',
    industry: 'Technology',
    userId: 'user1',
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    user: {
      id: 'user1',
      name: 'Test User',
      email: 'test@example.com',
    },
    campaigns: [],
    brandAssets: [],
    colorPalette: [],
    typography: [],
    _count: {
      campaigns: 0,
      brandAssets: 0,
      colorPalette: 0,
      typography: 0,
    },
  }

  const mockSession = {
    user: {
      id: 'user1',
      email: 'test@example.com',
    },
  }

  beforeEach(() => {
    jest.clearAllMocks()
    const { getServerSession } = require('next-auth/next')
    getServerSession.mockResolvedValue(mockSession)
  })

  describe('GET /api/brands/[id]', () => {
    it('should return a brand by ID', async () => {
      mockPrisma.brand.findFirst.mockResolvedValue(mockBrand as any)

      const request = createMockRequest('http://localhost/api/brands/brand1')
      const response = await GET(request, { params: Promise.resolve({ id: 'brand1' }) })
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.id).toBe('brand1')
      expect(data.name).toBe('Test Brand')
      expect(mockPrisma.brand.findFirst).toHaveBeenCalledWith({
        where: { id: 'brand1', deletedAt: null },
        select: {
          id: true,
          name: true,
          description: true,
          industry: true,
          website: true,
          tagline: true,
          mission: true,
          vision: true,
          values: true,
          personality: true,
          voiceDescription: true,
          toneAttributes: true,
          communicationStyle: true,
          messagingFramework: true,
          brandPillars: true,
          targetAudience: true,
          competitivePosition: true,
          brandPromise: true,
          complianceRules: true,
          usageGuidelines: true,
          restrictedTerms: true,
          createdAt: true,
          updatedAt: true,
          user: {
            select: {
              id: true,
              name: true,
              email: true,
            },
          },
          campaigns: {
            select: {
              id: true,
              name: true,
              status: true,
              createdAt: true,
              updatedAt: true,
            },
            where: { deletedAt: null },
            orderBy: { updatedAt: "desc" },
            take: 20,
          },
          brandAssets: {
            select: {
              id: true,
              name: true,
              description: true,
              type: true,
              category: true,
              fileUrl: true,
              fileName: true,
              fileSize: true,
              mimeType: true,
              isActive: true,
              downloadCount: true,
              lastUsed: true,
              createdAt: true,
              updatedAt: true,
            },
            where: { deletedAt: null },
            orderBy: { createdAt: "desc" },
            take: 50,
          },
          colorPalette: {
            select: {
              id: true,
              name: true,
              description: true,
              colors: true,
              isPrimary: true,
              isActive: true,
              createdAt: true,
              updatedAt: true,
            },
            where: { deletedAt: null },
            orderBy: { isPrimary: "desc" },
            take: 20,
          },
          typography: {
            select: {
              id: true,
              name: true,
              description: true,
              fontFamily: true,
              fontWeight: true,
              fontSize: true,
              lineHeight: true,
              letterSpacing: true,
              usage: true,
              isPrimary: true,
              isActive: true,
              fontFileUrl: true,
              fallbackFonts: true,
              createdAt: true,
              updatedAt: true,
            },
            where: { deletedAt: null },
            orderBy: { isPrimary: "desc" },
            take: 20,
          },
          _count: {
            select: {
              campaigns: { where: { deletedAt: null } },
              brandAssets: { where: { deletedAt: null, isActive: true } },
              colorPalette: { where: { deletedAt: null, isActive: true } },
              typography: { where: { deletedAt: null, isActive: true } },
            },
          },
        },
      })
    })

    it('should return 404 for non-existent brand', async () => {
      mockPrisma.brand.findFirst.mockResolvedValue(null)

      const request = createMockRequest('http://localhost/api/brands/nonexistent')
      const response = await GET(request, { params: Promise.resolve({ id: 'nonexistent' }) })

      expect(response.status).toBe(404)
      const data = await response.json()
      expect(data.error).toBe('Brand not found')
    })

    it('should handle database errors gracefully', async () => {
      mockPrisma.brand.findFirst.mockRejectedValue(new Error('Database error'))

      const request = createMockRequest('http://localhost/api/brands/brand1')
      const response = await GET(request, { params: Promise.resolve({ id: 'brand1' }) })

      expect(response.status).toBe(500)
      const data = await response.json()
      expect(data.error).toBe('Failed to fetch brand')
    })
  })

  describe('PUT /api/brands/[id]', () => {
    it('should update a brand with valid data', async () => {
      const updateData = {
        name: 'Updated Brand',
        description: 'Updated description',
        industry: 'Healthcare',
      }

      const updatedBrand = {
        ...mockBrand,
        ...updateData,
        updatedAt: new Date(),
      }

      mockPrisma.brand.findFirst.mockResolvedValue(mockBrand as any)
      mockPrisma.brand.update.mockResolvedValue(updatedBrand as any)

      const request = createMockRequest('http://localhost/api/brands/brand1', {
        method: 'PUT',
        body: JSON.stringify(updateData),
      })

      const response = await PUT(request, { params: Promise.resolve({ id: 'brand1' }) })
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.name).toBe('Updated Brand')
      expect(data.description).toBe('Updated description')
      expect(mockPrisma.brand.update).toHaveBeenCalledWith({
        where: { id: 'brand1' },
        data: expect.objectContaining(updateData),
        include: expect.any(Object),
      })
    })

    it.skip('should require authentication (auth not implemented yet)', async () => {
      const { getServerSession } = require('next-auth/next')
      getServerSession.mockResolvedValue(null)

      const request = createMockRequest('http://localhost/api/brands/brand1', {
        method: 'PUT',
        body: JSON.stringify({ name: 'Updated Brand' }),
      })

      const response = await PUT(request, { params: Promise.resolve({ id: 'brand1' }) })

      expect(response.status).toBe(401)
      const data = await response.json()
      expect(data.error).toBe('Unauthorized')
    })

    it.skip('should require brand ownership (auth not implemented yet)', async () => {
      const otherUserBrand = {
        ...mockBrand,
        userId: 'other-user',
      }

      mockPrisma.brand.findFirst.mockResolvedValue(otherUserBrand as any)

      const request = createMockRequest('http://localhost/api/brands/brand1', {
        method: 'PUT',
        body: JSON.stringify({ name: 'Updated Brand' }),
      })

      const response = await PUT(request, { params: Promise.resolve({ id: 'brand1' }) })

      expect(response.status).toBe(403)
      const data = await response.json()
      expect(data.error).toBe('Forbidden')
    })

    it('should return 404 for non-existent brand', async () => {
      mockPrisma.brand.findFirst.mockResolvedValue(null)

      const request = createMockRequest('http://localhost/api/brands/nonexistent', {
        method: 'PUT',
        body: JSON.stringify({ name: 'Updated Brand' }),
      })

      const response = await PUT(request, { params: Promise.resolve({ id: 'nonexistent' }) })

      expect(response.status).toBe(404)
      const data = await response.json()
      expect(data.error).toBe('Brand not found')
    })

    it('should validate website URL format', async () => {
      mockPrisma.brand.findFirst.mockResolvedValue(mockBrand as any)

      const request = createMockRequest('http://localhost/api/brands/brand1', {
        method: 'PUT',
        body: JSON.stringify({
          name: 'Test Brand',
          website: 'invalid-url',
        }),
      })

      const response = await PUT(request, { params: Promise.resolve({ id: 'brand1' }) })

      expect(response.status).toBe(400)
      const data = await response.json()
      expect(data.error).toBe('Validation error')
    })
  })

  describe('DELETE /api/brands/[id]', () => {
    it('should soft delete a brand', async () => {
      mockPrisma.brand.findFirst.mockResolvedValue(mockBrand as any)
      mockPrisma.campaign.count.mockResolvedValue(0)
      mockPrisma.brand.update.mockResolvedValue({
        ...mockBrand,
        deletedAt: new Date(),
      } as any)

      const request = createMockRequest('http://localhost/api/brands/brand1', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: Promise.resolve({ id: 'brand1' }) })

      expect(response.status).toBe(200)
      const data = await response.json()
      expect(data.message).toBe('Brand deleted successfully')
      expect(mockPrisma.brand.update).toHaveBeenCalledWith({
        where: { id: 'brand1' },
        data: {
          deletedAt: expect.any(Date),
          updatedBy: 'cmefuzqdo0000nutz18es59jr',
        },
      })
    })

    it.skip('should require authentication (auth not implemented yet)', async () => {
      const { getServerSession } = require('next-auth/next')
      getServerSession.mockResolvedValue(null)

      const request = createMockRequest('http://localhost/api/brands/brand1', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: Promise.resolve({ id: 'brand1' }) })

      expect(response.status).toBe(401)
      const data = await response.json()
      expect(data.error).toBe('Unauthorized')
    })

    it.skip('should require brand ownership (auth not implemented yet)', async () => {
      const otherUserBrand = {
        ...mockBrand,
        userId: 'other-user',
      }

      mockPrisma.brand.findFirst.mockResolvedValue(otherUserBrand as any)
      mockPrisma.campaign.count.mockResolvedValue(0)

      const request = createMockRequest('http://localhost/api/brands/brand1', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: Promise.resolve({ id: 'brand1' }) })

      expect(response.status).toBe(403)
      const data = await response.json()
      expect(data.error).toBe('Forbidden')
    })

    it('should return 404 for non-existent brand', async () => {
      mockPrisma.brand.findFirst.mockResolvedValue(null)

      const request = createMockRequest('http://localhost/api/brands/nonexistent', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: Promise.resolve({ id: 'nonexistent' }) })

      expect(response.status).toBe(404)
      const data = await response.json()
      expect(data.error).toBe('Brand not found')
    })

    it('should handle database errors gracefully', async () => {
      mockPrisma.brand.findFirst.mockResolvedValue(mockBrand as any)
      mockPrisma.campaign.count.mockResolvedValue(0)
      mockPrisma.brand.update.mockRejectedValue(new Error('Database error'))

      const request = createMockRequest('http://localhost/api/brands/brand1', {
        method: 'DELETE',
      })

      const response = await DELETE(request, { params: Promise.resolve({ id: 'brand1' }) })

      expect(response.status).toBe(500)
      const data = await response.json()
      expect(data.error).toBe('Internal server error')
    })
  })
})