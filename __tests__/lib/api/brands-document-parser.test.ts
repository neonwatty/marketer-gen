import { BrandService } from '@/lib/api/brands'
import { BrandAsset, DocumentParseRequest } from '@/lib/types/brand'

// Mock fetch globally
const mockFetch = jest.fn()
global.fetch = mockFetch

describe('BrandService Document Parser Methods', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockFetch.mockClear()
  })

  describe('parseDocument', () => {
    const mockBrandId = 'brand-123'
    const mockRequest: DocumentParseRequest = {
      assetId: 'asset-456',
      parseSettings: {
        extractColors: true,
        extractFonts: true,
        extractVoice: false,
        extractGuidelines: true,
      },
    }

    const mockSuccessResponse = {
      success: true,
      extractedData: {
        rawText: 'Sample brand guidelines text',
        extractedAt: '2023-01-01T00:00:00.000Z',
        assetId: 'asset-456',
        brandId: 'brand-123',
        colors: ['#ff0000', '#00ff00'],
        fonts: ['Arial', 'Helvetica'],
        guidelines: {
          sections: ['Brand Overview', 'Color Palette'],
          keyPhrases: ['Professional tone', 'Modern design'],
        },
      },
      message: 'Document parsed successfully',
    }

    it('should successfully parse document with valid request', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockSuccessResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, mockRequest)

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/brands/brand-123/assets/parse',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(mockRequest),
        }
      )

      expect(result).toEqual(mockSuccessResponse)
    })

    it('should handle HTTP error responses', async () => {
      const errorResponse = {
        error: 'Asset not found',
      }

      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 404,
        statusText: 'Not Found',
        json: () => Promise.resolve(errorResponse),
      })

      await expect(
        BrandService.parseDocument(mockBrandId, mockRequest)
      ).rejects.toThrow('Asset not found')
    })

    it('should handle network errors', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'))

      await expect(
        BrandService.parseDocument(mockBrandId, mockRequest)
      ).rejects.toThrow('Network error')
    })

    it('should send minimal request when parseSettings is undefined', async () => {
      const minimalRequest = { assetId: 'asset-456' }

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockSuccessResponse),
      })

      await BrandService.parseDocument(mockBrandId, minimalRequest)

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/brands/brand-123/assets/parse',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(minimalRequest),
        }
      )
    })

    it('should handle malformed JSON response', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        statusText: 'Internal Server Error',
        json: () => Promise.reject(new Error('Invalid JSON')),
      })

      await expect(
        BrandService.parseDocument(mockBrandId, mockRequest)
      ).rejects.toThrow('Invalid JSON')
    })
  })

  describe('canParseAsset', () => {
    it('should return true for BRAND_GUIDELINES asset type', () => {
      const asset: BrandAsset = {
        id: 'asset-1',
        name: 'Brand Guidelines',
        type: 'BRAND_GUIDELINES',
        mimeType: null,
        fileUrl: 'https://example.com/guidelines.pdf',
        fileName: 'guidelines.pdf',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(true)
    })

    it('should return true for DOCUMENT asset type', () => {
      const asset: BrandAsset = {
        id: 'asset-2',
        name: 'Style Guide',
        type: 'DOCUMENT',
        mimeType: null,
        fileUrl: 'https://example.com/style.docx',
        fileName: 'style.docx',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(true)
    })

    it('should return true for supported PDF mime type', () => {
      const asset: BrandAsset = {
        id: 'asset-3',
        name: 'Logo Guide',
        type: 'LOGO',
        mimeType: 'application/pdf',
        fileUrl: 'https://example.com/logo.pdf',
        fileName: 'logo.pdf',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(true)
    })

    it('should return true for supported DOCX mime type', () => {
      const asset: BrandAsset = {
        id: 'asset-4',
        name: 'Brand Manual',
        type: 'OTHER',
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        fileUrl: 'https://example.com/manual.docx',
        fileName: 'manual.docx',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(true)
    })

    it('should return true for supported DOC mime type', () => {
      const asset: BrandAsset = {
        id: 'asset-5',
        name: 'Old Brand Guide',
        type: 'OTHER',
        mimeType: 'application/msword',
        fileUrl: 'https://example.com/old.doc',
        fileName: 'old.doc',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(true)
    })

    it('should return true for plain text mime type', () => {
      const asset: BrandAsset = {
        id: 'asset-6',
        name: 'Brand Notes',
        type: 'OTHER',
        mimeType: 'text/plain',
        fileUrl: 'https://example.com/notes.txt',
        fileName: 'notes.txt',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(true)
    })

    it('should return false for unsupported asset type and mime type', () => {
      const asset: BrandAsset = {
        id: 'asset-7',
        name: 'Logo Image',
        type: 'LOGO',
        mimeType: 'image/png',
        fileUrl: 'https://example.com/logo.png',
        fileName: 'logo.png',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(false)
    })

    it('should return false for unsupported type with null mime type', () => {
      const asset: BrandAsset = {
        id: 'asset-8',
        name: 'Video Asset',
        type: 'VIDEO',
        mimeType: null,
        fileUrl: 'https://example.com/video.mp4',
        fileName: 'video.mp4',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(false)
    })

    it('should return false for unsupported type with undefined mime type', () => {
      const asset: BrandAsset = {
        id: 'asset-9',
        name: 'Audio Asset',
        type: 'AUDIO',
        fileUrl: 'https://example.com/audio.mp3',
        fileName: 'audio.mp3',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(false)
    })

    it('should handle edge case with empty mime type string', () => {
      const asset: BrandAsset = {
        id: 'asset-10',
        name: 'Unknown File',
        type: 'OTHER',
        mimeType: '',
        fileUrl: 'https://example.com/unknown',
        fileName: 'unknown',
      } as BrandAsset

      expect(BrandService.canParseAsset(asset)).toBe(false)
    })
  })
})