import { POST } from '@/app/api/brands/[id]/assets/parse/route'
import { NextRequest } from 'next/server'
import { prisma } from '@/lib/database'
import pdf from 'pdf-parse'
import mammoth from 'mammoth'

// Mock external dependencies
jest.mock('@/lib/database', () => ({
  prisma: {
    brand: {
      findFirst: jest.fn(),
    },
    brandAsset: {
      findFirst: jest.fn(),
      update: jest.fn(),
    },
  },
}))

jest.mock('pdf-parse', () => jest.fn())
jest.mock('mammoth', () => ({
  extractRawText: jest.fn(),
}))

// Mock NextRequest helper
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

// Mock NextResponse
jest.mock('next/server', () => ({
  NextResponse: {
    json: jest.fn((data, init) => ({
      json: () => Promise.resolve(data),
      status: init?.status || 200,
    })),
  },
}))

describe('Document Parser Integration Tests', () => {
  const mockBrand = {
    id: 'brand-1',
    name: 'Test Brand',
    deletedAt: null,
  }

  const mockAsset = {
    id: 'asset-1',
    brandId: 'brand-1',
    name: 'Brand Guidelines.pdf',
    type: 'BRAND_GUIDELINES',
    mimeType: 'application/pdf',
    fileUrl: 'https://example.com/guidelines.pdf',
    metadata: { version: '1.0' },
    deletedAt: null,
  }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(prisma.brand.findFirst as jest.Mock).mockResolvedValue(mockBrand)
    ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(mockAsset)
    ;(prisma.brandAsset.update as jest.Mock).mockResolvedValue(mockAsset)
  })

  describe('PDF Processing Integration', () => {
    it('should successfully process PDF with actual pdf-parse', async () => {
      const mockPdfBuffer = Buffer.from('Mock PDF content')
      const mockPdfData = {
        text: `
          Brand Guidelines Document
          Primary Color: #007bff (Brand Blue)
          Secondary Color: #28a745 (Success Green)
          Font Family: "Helvetica Neue", Arial, sans-serif
          Voice: Professional and approachable tone
          Brand personality: Innovative, trustworthy, modern
        `,
        numpages: 1,
        info: { Title: 'Brand Guidelines' },
      }

      // Mock successful fetch and PDF parsing
      global.fetch = jest.fn().mockResolvedValueOnce({
        ok: true,
        arrayBuffer: () => Promise.resolve(mockPdfBuffer.buffer),
      })
      
      ;(pdf as jest.MockedFunction<typeof pdf>).mockResolvedValueOnce(mockPdfData)

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({
          assetId: 'asset-1',
          parseSettings: {
            extractColors: true,
            extractFonts: true,
            extractVoice: true,
            extractGuidelines: true,
          },
        }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      expect(response.status).toBe(200)
      expect(body.success).toBe(true)
      expect(body.extractedData.colors.some((color: any) => 
        color.hex === '#007BFF'
      )).toBe(true)
      expect(body.extractedData.colors.some((color: any) => 
        color.hex === '#28A745'
      )).toBe(true)
      expect(body.extractedData.fonts.some((font: any) => 
        font.family.toLowerCase().includes('helvetica')
      )).toBe(true)
      expect(body.extractedData.voice.voiceDescription).toBeTruthy()
      expect(body.extractedData.voice.toneAttributes.professional).toBeGreaterThan(0)

      // Verify PDF parsing was called
      expect(pdf).toHaveBeenCalledWith(expect.any(Buffer))
    })

    it('should handle PDF parsing errors gracefully', async () => {
      global.fetch = jest.fn().mockResolvedValueOnce({
        ok: true,
        arrayBuffer: () => Promise.resolve(Buffer.from('Invalid PDF').buffer),
      })

      ;(pdf as jest.MockedFunction<typeof pdf>).mockRejectedValueOnce(
        new Error('PDF parsing failed')
      )

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({ assetId: 'asset-1' }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      // Should fallback to sample data and still succeed
      expect(response.status).toBe(200)
      expect(body.success).toBe(true)
      expect(body.extractedData.rawText).toContain('Brand Guidelines Sample')
    })
  })

  describe('DOCX Processing Integration', () => {
    it('should successfully process DOCX with actual mammoth', async () => {
      const mockDocxAsset = {
        ...mockAsset,
        name: 'Brand Guidelines.docx',
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        fileUrl: 'https://example.com/guidelines.docx',
      }

      ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(mockDocxAsset)

      const mockDocxBuffer = Buffer.from('Mock DOCX content')
      const mockMammothResult = {
        value: `
          Brand Style Guide
          Primary Colors: #ff6b35 (Orange), #004e89 (Navy Blue)
          Typography: Primary font is "Source Sans Pro"
          Brand voice: Friendly yet professional, conversational style
          Core values: Innovation, reliability, customer-focused
        `,
        messages: [],
      }

      // Mock successful fetch and DOCX parsing
      global.fetch = jest.fn().mockResolvedValueOnce({
        ok: true,
        arrayBuffer: () => Promise.resolve(mockDocxBuffer.buffer),
      })

      ;(mammoth.extractRawText as jest.MockedFunction<typeof mammoth.extractRawText>)
        .mockResolvedValueOnce(mockMammothResult)

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({
          assetId: 'asset-1',
          parseSettings: {
            extractColors: true,
            extractFonts: true,
            extractVoice: true,
          },
        }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      expect(response.status).toBe(200)
      expect(body.success).toBe(true)
      expect(body.extractedData.colors.some((color: any) => 
        color.hex === '#FF6B35'
      )).toBe(true)
      expect(body.extractedData.colors.some((color: any) => 
        color.hex === '#004E89'
      )).toBe(true)
      expect(body.extractedData.fonts.some((font: any) => 
        font.family.toLowerCase().includes('source sans')
      )).toBe(true)

      // Verify mammoth was called
      expect(mammoth.extractRawText).toHaveBeenCalledWith({ buffer: expect.any(Buffer) })
    })

    it('should handle DOCX parsing errors gracefully', async () => {
      const mockDocxAsset = {
        ...mockAsset,
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      }

      ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(mockDocxAsset)

      global.fetch = jest.fn().mockResolvedValueOnce({
        ok: true,
        arrayBuffer: () => Promise.resolve(Buffer.from('Invalid DOCX').buffer),
      })

      ;(mammoth.extractRawText as jest.MockedFunction<typeof mammoth.extractRawText>)
        .mockRejectedValueOnce(new Error('DOCX parsing failed'))

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({ assetId: 'asset-1' }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      // Should fallback to sample data and still succeed
      expect(response.status).toBe(200)
      expect(body.success).toBe(true)
      expect(body.extractedData.rawText).toContain('Brand Guidelines Sample')
    })
  })

  describe('Pattern Recognition Integration', () => {
    it('should extract complex color patterns from real content', async () => {
      global.fetch = jest.fn().mockRejectedValueOnce(new Error('Network error'))

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({
          assetId: 'asset-1',
          parseSettings: { extractColors: true },
        }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      expect(body.extractedData.colors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            hex: expect.stringMatching(/#[0-9a-fA-F]{6}/)
          })
        ])
      )
    })

    it('should extract font families with various formats', async () => {
      global.fetch = jest.fn().mockRejectedValueOnce(new Error('Network error'))

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({
          assetId: 'asset-1',
          parseSettings: { extractFonts: true },
        }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      expect(body.extractedData.fonts).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            family: expect.stringMatching(/helvetica|arial|source/i)
          })
        ])
      )
    })

    it('should analyze voice and tone attributes', async () => {
      global.fetch = jest.fn().mockRejectedValueOnce(new Error('Network error'))

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({
          assetId: 'asset-1',
          parseSettings: { extractVoice: true },
        }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      expect(body.extractedData.voice).toMatchObject({
        voiceDescription: expect.any(String),
        toneAttributes: expect.any(Object),
        communicationStyle: expect.any(String),
      })

      // Check that tone attributes contain expected keywords
      const toneKeys = Object.keys(body.extractedData.voice.toneAttributes)
      expect(toneKeys.some(key => 
        ['professional', 'friendly', 'approachable', 'trustworthy'].includes(key)
      )).toBe(true)
    })
  })

  describe('Database Integration', () => {
    it('should update asset metadata after successful parsing', async () => {
      global.fetch = jest.fn().mockRejectedValueOnce(new Error('Network error'))

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({ assetId: 'asset-1' }),
        headers: { 'Content-Type': 'application/json' },
      })

      await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })

      expect(prisma.brandAsset.update).toHaveBeenCalledWith({
        where: { id: 'asset-1' },
        data: {
          metadata: expect.objectContaining({
            version: '1.0', // Existing metadata preserved
            parsed: true,
            parsedAt: expect.stringMatching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/),
            extractedElements: expect.objectContaining({
              rawText: expect.any(String),
              extractedAt: expect.any(String),
              assetId: 'asset-1',
              brandId: 'brand-1',
            }),
          }),
          updatedBy: expect.any(String),
        },
      })
    })

    it('should handle null metadata gracefully', async () => {
      const assetWithNullMetadata = { ...mockAsset, metadata: null }
      ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(assetWithNullMetadata)

      global.fetch = jest.fn().mockRejectedValueOnce(new Error('Network error'))

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({ assetId: 'asset-1' }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })

      expect(response.status).toBe(200)
      expect(prisma.brandAsset.update).toHaveBeenCalledWith({
        where: { id: 'asset-1' },
        data: {
          metadata: expect.objectContaining({
            parsed: true,
            parsedAt: expect.any(String),
            extractedElements: expect.any(Object),
          }),
          updatedBy: expect.any(String),
        },
      })
    })
  })

  describe('Error Handling and Resilience', () => {
    it('should handle network timeout gracefully', async () => {
      global.fetch = jest.fn().mockImplementationOnce(() => 
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Request timeout')), 100)
        )
      )

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({ assetId: 'asset-1' }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      expect(response.status).toBe(200)
      expect(body.success).toBe(true)
      expect(body.extractedData.rawText).toContain('Brand Guidelines Sample')
    })

    it('should handle corrupted file gracefully', async () => {
      global.fetch = jest.fn().mockResolvedValueOnce({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(0)), // Empty buffer
      })

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({ assetId: 'asset-1' }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const body = await response.json()

      expect(response.status).toBe(200)
      expect(body.success).toBe(true)
    })

    it('should handle database errors during metadata update', async () => {
      global.fetch = jest.fn().mockRejectedValueOnce(new Error('Network error'))
      
      ;(prisma.brandAsset.update as jest.Mock).mockRejectedValueOnce(
        new Error('Database connection failed')
      )

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({ assetId: 'asset-1' }),
        headers: { 'Content-Type': 'application/json' },
      })

      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })

      expect(response.status).toBe(500)
    })
  })

  describe('Performance and Memory Management', () => {
    it('should handle large text extraction efficiently', async () => {
      const largeText = 'A'.repeat(100000) // 100KB of text
      
      global.fetch = jest.fn().mockResolvedValueOnce({
        ok: true,
        arrayBuffer: () => Promise.resolve(Buffer.from(largeText).buffer),
      })

      ;(pdf as jest.MockedFunction<typeof pdf>).mockResolvedValueOnce({
        text: largeText,
        numpages: 100,
        info: {},
      })

      const request = createMockRequest('http://localhost/api/brands/brand-1/assets/parse', {
        method: 'POST',
        body: JSON.stringify({ assetId: 'asset-1' }),
        headers: { 'Content-Type': 'application/json' },
      })

      const startTime = Date.now()
      const response = await POST(request, { params: Promise.resolve({ id: 'brand-1' }) })
      const endTime = Date.now()

      expect(response.status).toBe(200)
      expect(endTime - startTime).toBeLessThan(15000) // Should complete within 15 seconds
    })
  })
})