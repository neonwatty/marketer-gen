import { POST } from "@/app/api/brands/[id]/assets/parse/route"
import { NextRequest } from "next/server"
import { prisma } from "@/lib/database"
import { BrandGuidelinesProcessor } from "@/lib/services/brand-guidelines-processor"

// Mock dependencies
jest.mock("@/lib/database", () => ({
  prisma: {
    brand: { findFirst: jest.fn() },
    brandAsset: { findFirst: jest.fn(), update: jest.fn() },
  },
}))

jest.mock("@/lib/services/brand-guidelines-processor", () => ({
  BrandGuidelinesProcessor: {
    parseDocumentContent: jest.fn(),
    processBrandGuidelines: jest.fn(),
  },
}))

const createMockRequest = (url: string, options: RequestInit = {}) => {
  return {
    url,
    method: options.method || 'GET',
    headers: new Headers(options.headers),
    json: jest.fn().mockResolvedValue(JSON.parse(options.body as string || '{}')),
    nextUrl: new URL(url),
  } as unknown as NextRequest
}

describe("Enhanced Document Parser API", () => {
  const mockBrand = { id: "brand-1", name: "Test Brand", deletedAt: null }
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

  const mockProcessedData = {
    rawText: "Sample text",
    extractedAt: "2023-01-01T00:00:00.000Z",
    assetId: "asset-1",
    brandId: "brand-1",
    colors: [
      { hex: "#007BFF", category: "primary", usage: "brand color" },
      { hex: "#28A745", category: "success", usage: "success messages" }
    ],
    fonts: [
      { family: "Helvetica Neue", category: "sans-serif", usage: "heading" },
      { family: "Georgia", category: "serif", usage: "body" }
    ],
    voice: {
      voiceDescription: "Professional yet approachable",
      toneAttributes: { professional: 3, friendly: 2 },
      communicationStyle: "conversational",
      personality: ["innovative", "trustworthy"],
      messaging: { prohibited: ["avoid these terms"] }
    },
    guidelines: {
      sections: [
        { title: "Brand Overview", content: "Our brand...", type: "overview" },
        { title: "Colors", content: "Primary colors...", type: "visual" }
      ],
      keyPhrases: ["Always maintain consistency", "Never alter the logo"],
      brandPillars: ["Innovation", "Trust", "Quality"]
    },
    compliance: {
      usageRules: {
        do: ["Always use primary logo on white backgrounds"],
        dont: ["Never distort logo proportions"]
      },
      restrictedTerms: ["competitor names"],
      legalRequirements: ["Copyright notice required"]
    },
    confidence: {
      overall: 85,
      colors: 90,
      fonts: 80,
      voice: 75,
      guidelines: 85,
      compliance: 80
    },
    suggestions: ["Add more color specifications", "Include font weights"]
  }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(prisma.brand.findFirst as jest.Mock).mockResolvedValue(mockBrand)
    ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(mockAsset)
    ;(prisma.brandAsset.update as jest.Mock).mockResolvedValue(mockAsset)
    ;(BrandGuidelinesProcessor.parseDocumentContent as jest.Mock).mockResolvedValue("Sample text")
    ;(BrandGuidelinesProcessor.processBrandGuidelines as jest.Mock).mockResolvedValue(mockProcessedData)
  })

  describe("Enhanced Processing Features", () => {
    it("should support new extractCompliance setting", async () => {
      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({
          assetId: "asset-1",
          parseSettings: {
            extractColors: true,
            extractFonts: true,
            extractVoice: true,
            extractGuidelines: true,
            extractCompliance: true,
            enhanceWithAI: false,
          },
        }),
        headers: { "Content-Type": "application/json" },
      })

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)),
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      
      expect(BrandGuidelinesProcessor.processBrandGuidelines).toHaveBeenCalledWith(
        "Sample text",
        "asset-1",
        "brand-1",
        expect.objectContaining({
          extractCompliance: true,
          enhanceWithAI: false,
        })
      )
    })

    it("should return enhanced response structure", async () => {
      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({ assetId: "asset-1" }),
        headers: { "Content-Type": "application/json" },
      })

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)),
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      const body = await response.json()

      expect(body).toMatchObject({
        success: true,
        extractedData: mockProcessedData,
        message: expect.stringContaining("85% confidence"),
        processingInfo: {
          engine: "BrandGuidelinesProcessor",
          version: "1.0",
          extractedAt: mockProcessedData.extractedAt,
          elementsFound: {
            colors: 2,
            fonts: 2,
            voiceAttributes: 2,
            guidelineSections: 2,
            complianceRules: 2,
          },
          confidence: mockProcessedData.confidence,
          suggestions: mockProcessedData.suggestions,
        },
      })
    })

    it("should update asset metadata with processing engine info", async () => {
      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({ assetId: "asset-1" }),
        headers: { "Content-Type": "application/json" },
      })

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)),
      })

      await POST(request, { params: Promise.resolve({ id: "brand-1" }) })

      expect(prisma.brandAsset.update).toHaveBeenCalledWith({
        where: { id: "asset-1" },
        data: {
          metadata: expect.objectContaining({
            parsed: true,
            parsedAt: mockProcessedData.extractedAt,
            extractedElements: mockProcessedData,
            processingEngine: "BrandGuidelinesProcessor",
            version: "1.0",
          }),
          updatedBy: expect.any(String),
        },
      })
    })

    it("should handle processor errors gracefully", async () => {
      ;(BrandGuidelinesProcessor.parseDocumentContent as jest.Mock).mockRejectedValue(
        new Error("Processing failed")
      )

      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({ assetId: "asset-1" }),
        headers: { "Content-Type": "application/json" },
      })

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)),
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })

      // Should fall back to sample data processing
      expect(BrandGuidelinesProcessor.processBrandGuidelines).toHaveBeenCalledWith(
        expect.stringContaining("Brand Guidelines Sample"),
        "asset-1",
        "brand-1",
        expect.any(Object)
      )
    })

    it("should support all MIME types through processor", async () => {
      const testCases = [
        { mimeType: "application/pdf", description: "PDF document" },
        { mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", description: "DOCX document" },
        { mimeType: "application/msword", description: "DOC document" },
        { mimeType: "text/plain", description: "Plain text" },
      ]

      for (const testCase of testCases) {
        const asset = { ...mockAsset, mimeType: testCase.mimeType }
        ;(prisma.brandAsset.findFirst as jest.Mock).mockResolvedValue(asset)

        const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
          method: "POST",
          body: JSON.stringify({ assetId: "asset-1" }),
          headers: { "Content-Type": "application/json" },
        })

        global.fetch = jest.fn().mockResolvedValue({
          ok: true,
          arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)),
        })

        await POST(request, { params: Promise.resolve({ id: "brand-1" }) })

        expect(BrandGuidelinesProcessor.parseDocumentContent).toHaveBeenCalledWith(
          expect.any(Buffer),
          testCase.mimeType
        )
      }
    })
  })

  describe("Confidence Scoring Integration", () => {
    it("should include confidence scores in response", async () => {
      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({ assetId: "asset-1" }),
        headers: { "Content-Type": "application/json" },
      })

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)),
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      const body = await response.json()

      expect(body.processingInfo.confidence).toEqual({
        overall: 85,
        colors: 90,
        fonts: 80,
        voice: 75,
        guidelines: 85,
        compliance: 80
      })
      expect(body.message).toContain("85% confidence")
    })

    it("should include processing suggestions", async () => {
      const request = createMockRequest("http://localhost/api/brands/brand-1/assets/parse", {
        method: "POST",
        body: JSON.stringify({ assetId: "asset-1" }),
        headers: { "Content-Type": "application/json" },
      })

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)),
      })

      const response = await POST(request, { params: Promise.resolve({ id: "brand-1" }) })
      const body = await response.json()

      expect(body.processingInfo.suggestions).toEqual([
        "Add more color specifications",
        "Include font weights"
      ])
    })
  })
})