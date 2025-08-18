import { BrandService } from '@/lib/api/brands'
import { DocumentParseRequest, EnhancedDocumentParseResult } from '@/lib/types/brand'

// Mock fetch globally
const mockFetch = jest.fn()
global.fetch = mockFetch

describe('BrandService Enhanced Document Parser', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockFetch.mockClear()
  })

  const mockBrandId = 'brand-123'
  const mockEnhancedResponse: EnhancedDocumentParseResult = {
    success: true,
    extractedData: {
      rawText: 'Enhanced brand guidelines text',
      extractedAt: '2023-01-01T00:00:00.000Z',
      assetId: 'asset-456',
      brandId: 'brand-123',
      colors: [
        {
          hex: '#007BFF',
          category: 'primary',
          usage: 'brand color',
        },
        {
          rgb: 'rgb(40, 167, 69)',
          category: 'success',
          usage: 'success messages',
        },
        {
          pantone: '286 C',
          category: 'primary',
          usage: 'print materials',
        }
      ],
      fonts: [
        {
          family: 'Helvetica Neue',
          category: 'sans-serif',
          usage: 'heading',
          fallbacks: ['Arial', 'sans-serif']
        },
        {
          family: 'Georgia',
          category: 'serif',
          usage: 'body',
          weight: 'regular'
        }
      ],
      voice: {
        voiceDescription: 'Professional yet approachable brand voice',
        toneAttributes: {
          professional: 3,
          friendly: 2,
          trustworthy: 4,
          innovative: 2
        },
        communicationStyle: 'conversational',
        personality: ['innovative', 'reliable', 'trustworthy'],
        messaging: {
          primary: 'Innovation through reliability',
          secondary: ['Customer-focused solutions', 'Modern technology'],
          prohibited: ['avoid these terms', 'competitor names']
        }
      },
      guidelines: {
        sections: [
          {
            title: 'Brand Overview',
            content: 'Our brand represents innovation...',
            type: 'overview'
          },
          {
            title: 'Visual Identity',
            content: 'Color palette and typography...',
            type: 'visual'
          },
          {
            title: 'Voice and Tone',
            content: 'Communication guidelines...',
            type: 'voice'
          },
          {
            title: 'Usage Guidelines',
            content: 'How to use brand elements...',
            type: 'usage'
          },
          {
            title: 'Compliance',
            content: 'Legal and compliance requirements...',
            type: 'compliance'
          }
        ],
        keyPhrases: [
          'Always maintain brand consistency',
          'Never alter logo proportions',
          'Ensure accessibility compliance'
        ],
        brandPillars: ['Innovation', 'Reliability', 'Customer Focus'],
        targetAudience: {
          primary: 'Technology decision-makers',
          demographics: {
            age_range: '35-55',
            job_titles: ['CTO', 'IT Director', 'Technology Manager'],
            company_size: '500-10000 employees',
            industries: ['Healthcare', 'Finance', 'Manufacturing']
          }
        }
      },
      compliance: {
        usageRules: {
          do: [
            'Always use primary logo on white backgrounds',
            'Maintain minimum clear space around logo',
            'Use approved fonts for all communications'
          ],
          dont: [
            'Never distort logo proportions',
            'Do not use competitor names without approval',
            'Avoid using unauthorized colors'
          ]
        },
        restrictedTerms: ['best in class', 'revolutionary', 'game-changing'],
        legalRequirements: [
          'Copyright notice required on all materials',
          'Trademark symbols must be used correctly'
        ],
        approvalProcess: 'All materials require brand team approval'
      },
      confidence: {
        overall: 87,
        colors: 92,
        fonts: 85,
        voice: 78,
        guidelines: 90,
        compliance: 83
      },
      suggestions: [
        'Consider adding font weight specifications',
        'Include more detailed color usage guidelines',
        'Add accessibility contrast ratios'
      ]
    },
    message: 'Document parsed successfully with 87% confidence',
    processingInfo: {
      engine: 'BrandGuidelinesProcessor',
      version: '1.0',
      extractedAt: '2023-01-01T00:00:00.000Z',
      elementsFound: {
        colors: 3,
        fonts: 2,
        voiceAttributes: 4,
        guidelineSections: 5,
        complianceRules: 6
      },
      confidence: {
        overall: 87,
        colors: 92,
        fonts: 85,
        voice: 78,
        guidelines: 90,
        compliance: 83
      },
      suggestions: [
        'Consider adding font weight specifications',
        'Include more detailed color usage guidelines',
        'Add accessibility contrast ratios'
      ]
    }
  }

  describe('Enhanced parseDocument method', () => {
    it('should successfully parse document with enhanced features', async () => {
      const mockRequest: DocumentParseRequest = {
        assetId: 'asset-456',
        parseSettings: {
          extractColors: true,
          extractFonts: true,
          extractVoice: true,
          extractGuidelines: true,
          extractCompliance: true,
          enhanceWithAI: false,
        },
      }

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
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

      expect(result).toEqual(mockEnhancedResponse)
    })

    it('should handle enhanced color extraction results', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, {
        assetId: 'asset-456',
        parseSettings: { extractColors: true }
      })

      const colors = result.extractedData.colors!
      expect(colors).toHaveLength(3)
      
      // Test hex color
      expect(colors[0]).toMatchObject({
        hex: '#007BFF',
        category: 'primary',
        usage: 'brand color'
      })

      // Test RGB color
      expect(colors[1]).toMatchObject({
        rgb: 'rgb(40, 167, 69)',
        category: 'success',
        usage: 'success messages'
      })

      // Test Pantone color
      expect(colors[2]).toMatchObject({
        pantone: '286 C',
        category: 'primary',
        usage: 'print materials'
      })
    })

    it('should handle enhanced font extraction results', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, {
        assetId: 'asset-456',
        parseSettings: { extractFonts: true }
      })

      const fonts = result.extractedData.fonts!
      expect(fonts).toHaveLength(2)
      
      // Test sans-serif font
      expect(fonts[0]).toMatchObject({
        family: 'Helvetica Neue',
        category: 'sans-serif',
        usage: 'heading',
        fallbacks: ['Arial', 'sans-serif']
      })

      // Test serif font
      expect(fonts[1]).toMatchObject({
        family: 'Georgia',
        category: 'serif',
        usage: 'body',
        weight: 'regular'
      })
    })

    it('should handle enhanced voice extraction results', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, {
        assetId: 'asset-456',
        parseSettings: { extractVoice: true }
      })

      const voice = result.extractedData.voice!
      expect(voice).toMatchObject({
        voiceDescription: 'Professional yet approachable brand voice',
        toneAttributes: {
          professional: 3,
          friendly: 2,
          trustworthy: 4,
          innovative: 2
        },
        communicationStyle: 'conversational',
        personality: ['innovative', 'reliable', 'trustworthy'],
        messaging: {
          primary: 'Innovation through reliability',
          secondary: ['Customer-focused solutions', 'Modern technology'],
          prohibited: ['avoid these terms', 'competitor names']
        }
      })
    })

    it('should handle enhanced guidelines extraction results', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, {
        assetId: 'asset-456',
        parseSettings: { extractGuidelines: true }
      })

      const guidelines = result.extractedData.guidelines!
      expect(guidelines.sections).toHaveLength(5)
      expect(guidelines.sections.map(s => s.type)).toEqual([
        'overview', 'visual', 'voice', 'usage', 'compliance'
      ])
      expect(guidelines.keyPhrases).toHaveLength(3)
      expect(guidelines.brandPillars).toEqual(['Innovation', 'Reliability', 'Customer Focus'])
      expect(guidelines.targetAudience).toBeDefined()
    })

    it('should handle compliance extraction results', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, {
        assetId: 'asset-456',
        parseSettings: { extractCompliance: true }
      })

      const compliance = result.extractedData.compliance!
      expect(compliance.usageRules.do).toHaveLength(3)
      expect(compliance.usageRules.dont).toHaveLength(3)
      expect(compliance.restrictedTerms).toHaveLength(3)
      expect(compliance.legalRequirements).toHaveLength(2)
      expect(compliance.approvalProcess).toBe('All materials require brand team approval')
    })

    it('should include confidence scores and suggestions', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, {
        assetId: 'asset-456'
      })

      expect(result.extractedData.confidence).toEqual({
        overall: 87,
        colors: 92,
        fonts: 85,
        voice: 78,
        guidelines: 90,
        compliance: 83
      })

      expect(result.extractedData.suggestions).toEqual([
        'Consider adding font weight specifications',
        'Include more detailed color usage guidelines',
        'Add accessibility contrast ratios'
      ])

      expect(result.processingInfo).toMatchObject({
        engine: 'BrandGuidelinesProcessor',
        version: '1.0',
        elementsFound: {
          colors: 3,
          fonts: 2,
          voiceAttributes: 4,
          guidelineSections: 5,
          complianceRules: 6
        }
      })
    })

    it('should support AI enhancement flag', async () => {
      const requestWithAI: DocumentParseRequest = {
        assetId: 'asset-456',
        parseSettings: {
          extractColors: true,
          extractFonts: true,
          extractVoice: true,
          extractGuidelines: true,
          extractCompliance: true,
          enhanceWithAI: true,
        },
      }

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
      })

      await BrandService.parseDocument(mockBrandId, requestWithAI)

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/brands/brand-123/assets/parse',
        expect.objectContaining({
          body: JSON.stringify(requestWithAI),
        })
      )
    })

    it('should handle parsing errors with detailed error information', async () => {
      const errorResponse = {
        error: 'Document processing failed',
        details: {
          step: 'color_extraction',
          reason: 'Invalid color format detected'
        }
      }

      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 422,
        statusText: 'Unprocessable Entity',
        json: () => Promise.resolve(errorResponse),
      })

      await expect(
        BrandService.parseDocument(mockBrandId, { assetId: 'asset-456' })
      ).rejects.toThrow('Document processing failed')
    })

    it('should handle timeout errors for large documents', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Request timeout'))

      await expect(
        BrandService.parseDocument(mockBrandId, { assetId: 'asset-456' })
      ).rejects.toThrow('Request timeout')
    })

    it('should validate response structure', async () => {
      const incompleteResponse = {
        success: true,
        extractedData: {
          rawText: 'Test',
          extractedAt: '2023-01-01T00:00:00.000Z',
          assetId: 'asset-456',
          brandId: 'brand-123',
          // Missing confidence and suggestions
        },
        message: 'Parsed',
        // Missing processingInfo
      }

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(incompleteResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, {
        assetId: 'asset-456'
      })

      // Should handle incomplete responses gracefully
      expect(result.extractedData.rawText).toBe('Test')
      expect(result.success).toBe(true)
    })
  })

  describe('Backward Compatibility', () => {
    it('should work with minimal parse settings', async () => {
      const minimalRequest: DocumentParseRequest = {
        assetId: 'asset-456'
        // No parseSettings provided
      }

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse),
      })

      const result = await BrandService.parseDocument(mockBrandId, minimalRequest)

      expect(result.success).toBe(true)
      expect(mockFetch).toHaveBeenCalledWith(
        '/api/brands/brand-123/assets/parse',
        expect.objectContaining({
          body: JSON.stringify(minimalRequest),
        })
      )
    })

    it('should maintain existing canParseAsset functionality', () => {
      // Test existing functionality is preserved
      const pdfAsset = {
        id: 'asset-1',
        type: 'BRAND_GUIDELINES',
        mimeType: 'application/pdf'
      } as any

      const imageAsset = {
        id: 'asset-2',
        type: 'IMAGE',
        mimeType: 'image/png'
      } as any

      expect(BrandService.canParseAsset(pdfAsset)).toBe(true)
      expect(BrandService.canParseAsset(imageAsset)).toBe(false)
    })
  })
})