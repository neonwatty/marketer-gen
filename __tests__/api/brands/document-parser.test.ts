import { POST } from "@/app/api/brands/[id]/assets/parse/route"
import { NextRequest } from "next/server"
import { prisma } from "@/lib/database"

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

// Mock the external dependencies
jest.mock("@/lib/database", () => ({
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

jest.mock("pdf-parse", () => jest.fn())
jest.mock("mammoth", () => ({
  extractRawText: jest.fn(),
}))

// Mock NextResponse
jest.mock('next/server', () => ({
  NextResponse: {
    json: jest.fn((data, init) => ({
      json: () => Promise.resolve(data),
      status: init?.status || 200,
    })),
  },
}))

describe("/api/brands/[id]/assets/parse", () => {
  const mockBrand = {
    id: "brand-1",
    name: "Test Brand",
    deletedAt: null,
  }

  const mockAsset = {
    id: "asset-1",
    brandId: "brand-1",
    name: "Brand Guidelines.pdf",
    type: "BRAND_GUIDELINES",
    mimeType: "application/pdf",
    fileUrl: "https://example.com/brand-guidelines.pdf",
    metadata: {},
    deletedAt: null,
  }

  beforeEach(() => {
    jest.clearAllMocks()
    // Mock successful database queries
    ;(prisma.brand.findFirst as jest.Mock).mockResolvedValue(mockBrand)
    ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(mockAsset)
    ;(prisma.brandAsset.update as jest.Mock).mockResolvedValue(mockAsset)
  })

  describe("POST", () => {
    it("should validate request body", async () => {
      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({}),
        headers: { "Content-Type": "application/json" },
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      
      expect(response.status).toBe(400)
      const body = await response.json()
      expect(body.error).toBe("Validation error")
    })

    it("should return 404 for non-existent brand", async () => {
      ;(prisma.brand.findFirst as jest.Mock).mockResolvedValue(null)

      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({
          assetId: "asset-1",
        }),
        headers: { "Content-Type": "application/json" },
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      
      expect(response.status).toBe(404)
      const body = await response.json()
      expect(body.error).toBe("Brand not found")
    })

    it("should return 404 for non-existent asset", async () => {
      ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(null)

      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({
          assetId: "asset-1",
        }),
        headers: { "Content-Type": "application/json" },
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      
      expect(response.status).toBe(404)
      const body = await response.json()
      expect(body.error).toBe("Asset not found")
    })

    it("should return 400 for unsupported asset type", async () => {
      const unsupportedAsset = {
        ...mockAsset,
        type: "IMAGE",
        mimeType: "image/jpeg",
      }
      ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(unsupportedAsset)

      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({
          assetId: "asset-1",
        }),
        headers: { "Content-Type": "application/json" },
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      
      expect(response.status).toBe(400)
      const body = await response.json()
      expect(body.error).toBe("Asset type not supported for parsing")
    })

    it("should successfully parse document with sample data", async () => {
      // Mock fetch to fail so it uses sample data
      global.fetch = jest.fn().mockRejectedValue(new Error("Network error"))

      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({
          assetId: "asset-1",
          parseSettings: {
            extractColors: true,
            extractFonts: true,
            extractVoice: true,
            extractGuidelines: true,
          },
        }),
        headers: { "Content-Type": "application/json" },
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      
      expect(response.status).toBe(200)
      const body = await response.json()
      
      expect(body.success).toBe(true)
      expect(body.extractedData).toBeDefined()
      expect(body.extractedData.colors).toBeDefined()
      expect(body.extractedData.fonts).toBeDefined()
      expect(body.extractedData.voice).toBeDefined()
      expect(body.extractedData.guidelines).toBeDefined()
      
      // Check that colors were extracted
      expect(body.extractedData.colors.some((color: any) => 
        color.hex === "#007BFF"
      )).toBe(true)
      expect(body.extractedData.colors.some((color: any) => 
        color.hex === "#28A745"
      )).toBe(true)
      
      // Check that fonts were extracted
      expect(body.extractedData.fonts.some((font: any) => 
        font.family.toLowerCase().includes("helvetica")
      )).toBe(true)
      
      // Check that voice data was extracted
      expect(body.extractedData.voice.voiceDescription).toBeTruthy()
      expect(body.extractedData.voice.communicationStyle).toBeTruthy()
    })

    it("should extract colors correctly", async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error("Network error"))

      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({
          assetId: "asset-1",
          parseSettings: { extractColors: true },
        }),
        headers: { "Content-Type": "application/json" },
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      const body = await response.json()
      
      expect(body.extractedData.colors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ hex: "#007BFF" }),
          expect.objectContaining({ hex: "#28A745" }),
          expect.objectContaining({ hex: "#DC3545" }),
          expect.objectContaining({ hex: "#6C757D" }),
          expect.objectContaining({ hex: "#F8F9FA" })
        ])
      )
    })

    it("should extract fonts correctly", async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error("Network error"))

      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({
          assetId: "asset-1",
          parseSettings: { extractFonts: true },
        }),
        headers: { "Content-Type": "application/json" },
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      const body = await response.json()
      
      expect(body.extractedData.fonts.some((font: any) => 
        font.family.toLowerCase().includes("helvetica")
      )).toBe(true)
      expect(body.extractedData.fonts.some((font: any) => 
        font.family.toLowerCase().includes("source sans")
      )).toBe(true)
    })

    it("should update asset metadata after parsing", async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error("Network error"))

      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({
          assetId: "asset-1",
        }),
        headers: { "Content-Type": "application/json" },
      })

      await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      
      expect(prisma.brandAsset.update).toHaveBeenCalledWith({
        where: { id: "asset-1" },
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
})