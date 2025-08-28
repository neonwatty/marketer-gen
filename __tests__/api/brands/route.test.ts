import { GET, POST } from '@/app/api/brands/route'
import { NextRequest } from 'next/server'
import { prisma } from '@/lib/database'

// Mock NextRequest to avoid URL property issues
const createMockRequest = (url: string, options: RequestInit = {}) => {
  const headers = new Headers(options.headers)
  
  // Automatically set content-type for POST requests with JSON body
  if (options.method === 'POST' && options.body && !headers.get('content-type')) {
    headers.set('content-type', 'application/json')
  }
  
  const parsedUrl = new URL(url)
  
  const mockRequest = {
    url,
    method: options.method || 'GET',
    headers,
    json: jest.fn().mockResolvedValue(JSON.parse(options.body as string || '{}')),
    nextUrl: parsedUrl,
    // Add searchParams getter for compatibility
    get searchParams() {
      return parsedUrl.searchParams
    }
  } as unknown as NextRequest
  return mockRequest
}

// Mock the database
jest.mock('@/lib/database', () => ({
  prisma: {
    brand: {
      findMany: jest.fn(),
      create: jest.fn(),
      count: jest.fn(),
    },
    $transaction: jest.fn().mockImplementation(async (queries) => {
      // Execute the queries and return their results
      const results = []
      for (const query of queries) {
        results.push(await query)
      }
      return results
    }),
  },
}))

// Mock NextAuth
jest.mock('next-auth/next', () => ({
  getServerSession: jest.fn().mockResolvedValue({
    user: {
      id: 'test-user-id',
      name: 'Test User',
      email: 'test@example.com',
    },
  }),
}))

// Mock NextResponse
jest.mock('next/server', () => ({
  NextResponse: {
    json: jest.fn((data, init) => {
      const mockHeaders = {
        set: jest.fn(),
        get: jest.fn(),
        has: jest.fn(),
        delete: jest.fn(),
        forEach: jest.fn(),
        entries: jest.fn(),
        keys: jest.fn(),
        values: jest.fn(),
      }
      
      return {
        json: () => Promise.resolve(data),
        status: init?.status || 200,
        headers: mockHeaders,
      }
    }),
  },
}))

const mockPrisma = prisma as jest.Mocked<typeof prisma>

describe('/api/brands', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GET /api/brands', () => {
    it('should return brands with pagination', async () => {
      const mockBrands = [
        {
          id: 'brand1',
          name: 'Test Brand 1',
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
          _count: {
            campaigns: 5,
            brandAssets: 10,
          },
        },
      ]

      mockPrisma.brand.findMany.mockResolvedValue(mockBrands as any)
      mockPrisma.brand.count.mockResolvedValue(1)

      const request = createMockRequest('http://localhost/api/brands')
      const response = await GET(request)
      const data = await response.json()


      expect(response.status).toBe(200)
      expect(data.brands).toHaveLength(1)
      expect(data.brands[0].name).toBe('Test Brand 1')
      expect(data.pagination).toEqual({
        page: 1,
        limit: 10,
        total: 1,
        pages: 1,
      })
    })

    it('should handle search parameter', async () => {
      mockPrisma.brand.findMany.mockResolvedValue([])
      mockPrisma.brand.count.mockResolvedValue(0)

      const request = createMockRequest('http://localhost/api/brands?search=tech')
      await GET(request)

      expect(mockPrisma.brand.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            OR: expect.arrayContaining([
              expect.objectContaining({
                name: expect.objectContaining({
                  contains: 'tech',
                }),
              }),
            ]),
          }),
        })
      )
    })

    it('should handle industry filter', async () => {
      mockPrisma.brand.findMany.mockResolvedValue([])
      mockPrisma.brand.count.mockResolvedValue(0)

      const request = createMockRequest('http://localhost/api/brands?industry=Technology')
      await GET(request)

      expect(mockPrisma.brand.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            industry: { contains: 'Technology', mode: 'insensitive' },
          }),
        })
      )
    })

    it('should handle pagination parameters', async () => {
      mockPrisma.brand.findMany.mockResolvedValue([])
      mockPrisma.brand.count.mockResolvedValue(0)

      const request = createMockRequest('http://localhost/api/brands?page=2&limit=5')
      await GET(request)

      expect(mockPrisma.brand.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 5, // (page - 1) * limit = (2 - 1) * 5
          take: 5,
        })
      )
    })

    it('should handle database errors gracefully', async () => {
      mockPrisma.brand.findMany.mockRejectedValue(new Error('Database error'))

      const request = createMockRequest('http://localhost/api/brands')
      const response = await GET(request)

      expect(response.status).toBe(500)
      const data = await response.json()
      expect(data.error).toBe('Internal server error')
    })
  })

  describe('POST /api/brands', () => {
    const mockSession = {
      user: {
        id: 'test-user-id',
        email: 'test@example.com',
      },
    }

    beforeEach(() => {
      const { getServerSession } = require('next-auth/next')
      getServerSession.mockResolvedValue(mockSession)
    })

    it('should create a brand with valid data', async () => {
      const brandData = {
        name: 'New Brand',
        description: 'A new test brand',
        industry: 'Technology',
        website: 'https://example.com',
        tagline: 'Test tagline',
      }

      const mockCreatedBrand = {
        id: 'brand1',
        ...brandData,
        userId: 'test-user-id',
        createdAt: new Date('2024-01-01'),
        updatedAt: new Date('2024-01-01'),
        user: mockSession.user,
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

      mockPrisma.brand.create.mockResolvedValue(mockCreatedBrand as any)

      const request = createMockRequest('http://localhost/api/brands', {
        method: 'POST',
        body: JSON.stringify(brandData),
      })
      
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(201)
      expect(data.name).toBe(brandData.name)
      expect(data.userId).toBe('test-user-id')
      expect(mockPrisma.brand.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            name: brandData.name,
            userId: 'test-user-id',
            createdBy: 'test-user-id',
          }),
        })
      )
    })

    it('should create brand with hardcoded user ID (current implementation)', async () => {
      const mockBrand = {
        id: 'brand1',
        name: 'Test Brand',
        userId: 'test-user-id',
      }
      
      mockPrisma.brand.create.mockResolvedValue(mockBrand as any)

      const request = createMockRequest('http://localhost/api/brands', {
        method: 'POST',
        body: JSON.stringify({ name: 'Test Brand' }),
      })

      const response = await POST(request)

      expect(response.status).toBe(201)
      const data = await response.json()
      expect(data.name).toBe('Test Brand')
    })

    it('should validate required fields', async () => {
      const request = createMockRequest('http://localhost/api/brands', {
        method: 'POST',
        body: JSON.stringify({}), // Missing required name field
      })

      const response = await POST(request)

      expect(response.status).toBe(400)
      const data = await response.json()
      expect(data.error).toBe('Validation error')
    })

    it('should validate website URL format', async () => {
      const request = createMockRequest('http://localhost/api/brands', {
        method: 'POST',
        body: JSON.stringify({
          name: 'Test Brand',
          website: 'invalid-url',
        }),
      })

      const response = await POST(request)

      expect(response.status).toBe(400)
      const data = await response.json()
      expect(data.error).toBe('Validation error')
    })

    it('should handle JSON arrays for values and personality', async () => {
      const brandData = {
        name: 'Test Brand',
        values: ['Innovation', 'Quality', 'Trust'],
        personality: ['Professional', 'Innovative'],
      }

      const mockCreatedBrand = {
        id: 'brand1',
        ...brandData,
        userId: 'user1',
        createdAt: new Date(),
        updatedAt: new Date(),
        user: mockSession.user,
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

      mockPrisma.brand.create.mockResolvedValue(mockCreatedBrand as any)

      const request = createMockRequest('http://localhost/api/brands', {
        method: 'POST',
        body: JSON.stringify(brandData),
      })

      const response = await POST(request)

      expect(response.status).toBe(201)
      expect(mockPrisma.brand.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            values: brandData.values,
            personality: brandData.personality,
          }),
        })
      )
    })

    it('should handle database errors gracefully', async () => {
      mockPrisma.brand.create.mockRejectedValue(new Error('Database error'))

      const request = createMockRequest('http://localhost/api/brands', {
        method: 'POST',
        body: JSON.stringify({
          name: 'Test Brand',
        }),
      })

      const response = await POST(request)

      expect(response.status).toBe(500)
      const data = await response.json()
      expect(data.error).toBe('Internal server error')
    })

    it.skip('should handle invalid JSON gracefully (requires real Request implementation)', async () => {
      // This test would require actual Request/JSON parsing behavior
      // Current mock doesn't simulate this properly
      const request = createMockRequest('http://localhost/api/brands', {
        method: 'POST',
        body: 'invalid json',
      })

      const response = await POST(request)

      expect(response.status).toBe(500)
      const data = await response.json()
      expect(data.error).toBe('Internal server error')
    })
  })
})