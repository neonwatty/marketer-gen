import {
  DocumentParseSettings,
  ExtractedVoiceData,
  ExtractedGuidelinesData,
  DocumentParseResult,
  DocumentParseRequest,
  PARSEABLE_ASSET_TYPES,
  PARSEABLE_MIME_TYPES,
  ParseableAssetType,
  ParseableMimeType,
} from '@/lib/types/brand'

describe('Brand Document Parser Types', () => {
  describe('DocumentParseSettings', () => {
    it('should accept all optional boolean properties', () => {
      const settings: DocumentParseSettings = {
        extractColors: true,
        extractFonts: false,
        extractVoice: true,
        extractGuidelines: false,
      }

      expect(typeof settings.extractColors).toBe('boolean')
      expect(typeof settings.extractFonts).toBe('boolean')
      expect(typeof settings.extractVoice).toBe('boolean')
      expect(typeof settings.extractGuidelines).toBe('boolean')
    })

    it('should allow empty object', () => {
      const settings: DocumentParseSettings = {}
      expect(typeof settings).toBe('object')
    })

    it('should allow partial settings', () => {
      const settings: DocumentParseSettings = {
        extractColors: true,
        extractVoice: false,
      }
      expect(settings.extractColors).toBe(true)
      expect(settings.extractVoice).toBe(false)
      expect(settings.extractFonts).toBeUndefined()
      expect(settings.extractGuidelines).toBeUndefined()
    })
  })

  describe('ExtractedVoiceData', () => {
    it('should structure voice data correctly', () => {
      const voiceData: ExtractedVoiceData = {
        voiceDescription: 'Professional and approachable tone',
        toneAttributes: {
          professional: 8,
          friendly: 7,
          authoritative: 6,
        },
        communicationStyle: 'conversational',
      }

      expect(typeof voiceData.voiceDescription).toBe('string')
      expect(typeof voiceData.toneAttributes).toBe('object')
      expect(typeof voiceData.communicationStyle).toBe('string')
      expect(typeof voiceData.toneAttributes.professional).toBe('number')
    })

    it('should allow null values', () => {
      const voiceData: ExtractedVoiceData = {
        voiceDescription: null,
        toneAttributes: {},
        communicationStyle: null,
      }

      expect(voiceData.voiceDescription).toBeNull()
      expect(voiceData.communicationStyle).toBeNull()
      expect(Object.keys(voiceData.toneAttributes)).toHaveLength(0)
    })

    it('should handle complex tone attributes', () => {
      const voiceData: ExtractedVoiceData = {
        voiceDescription: 'Multi-faceted brand voice',
        toneAttributes: {
          'professional': 9,
          'friendly': 8,
          'innovative': 7,
          'trustworthy': 10,
          'sophisticated': 6,
        },
        communicationStyle: 'formal',
      }

      expect(Object.keys(voiceData.toneAttributes)).toHaveLength(5)
      expect(Math.max(...Object.values(voiceData.toneAttributes))).toBe(10)
      expect(Math.min(...Object.values(voiceData.toneAttributes))).toBe(6)
    })
  })

  describe('ExtractedGuidelinesData', () => {
    it('should structure guidelines data correctly', () => {
      const guidelines: ExtractedGuidelinesData = {
        sections: ['Brand Overview', 'Color Palette', 'Typography', 'Voice & Tone'],
        keyPhrases: ['Modern design', 'Professional communication', 'Consistent branding'],
      }

      expect(Array.isArray(guidelines.sections)).toBe(true)
      expect(Array.isArray(guidelines.keyPhrases)).toBe(true)
      expect(guidelines.sections).toHaveLength(4)
      expect(guidelines.keyPhrases).toHaveLength(3)
    })

    it('should handle empty arrays', () => {
      const guidelines: ExtractedGuidelinesData = {
        sections: [],
        keyPhrases: [],
      }

      expect(guidelines.sections).toHaveLength(0)
      expect(guidelines.keyPhrases).toHaveLength(0)
    })

    it('should handle large datasets', () => {
      const sections = Array.from({ length: 50 }, (_, i) => `Section ${i + 1}`)
      const keyPhrases = Array.from({ length: 100 }, (_, i) => `Key phrase ${i + 1}`)

      const guidelines: ExtractedGuidelinesData = {
        sections,
        keyPhrases,
      }

      expect(guidelines.sections).toHaveLength(50)
      expect(guidelines.keyPhrases).toHaveLength(100)
    })
  })

  describe('DocumentParseResult', () => {
    it('should structure complete parse result correctly', () => {
      const result: DocumentParseResult = {
        success: true,
        extractedData: {
          rawText: 'Complete brand guidelines document text...',
          extractedAt: '2023-01-01T12:00:00.000Z',
          assetId: 'asset-123',
          brandId: 'brand-456',
          colors: ['#ff0000', '#00ff00', '#0000ff'],
          fonts: ['Arial', 'Helvetica', 'Times New Roman'],
          voice: {
            voiceDescription: 'Professional and friendly',
            toneAttributes: { professional: 8, friendly: 7 },
            communicationStyle: 'conversational',
          },
          guidelines: {
            sections: ['Overview', 'Colors', 'Fonts'],
            keyPhrases: ['Modern', 'Clean', 'Professional'],
          },
        },
        message: 'Document parsed successfully',
      }

      expect(result.success).toBe(true)
      expect(typeof result.extractedData.rawText).toBe('string')
      expect(result.extractedData.colors).toHaveLength(3)
      expect(result.extractedData.fonts).toHaveLength(3)
      expect(result.extractedData.voice?.toneAttributes.professional).toBe(8)
      expect(result.extractedData.guidelines?.sections).toHaveLength(3)
    })

    it('should handle minimal parse result', () => {
      const result: DocumentParseResult = {
        success: false,
        extractedData: {
          rawText: '',
          extractedAt: '2023-01-01T12:00:00.000Z',
          assetId: 'asset-123',
          brandId: 'brand-456',
        },
        message: 'Failed to parse document',
      }

      expect(result.success).toBe(false)
      expect(result.extractedData.colors).toBeUndefined()
      expect(result.extractedData.fonts).toBeUndefined()
      expect(result.extractedData.voice).toBeUndefined()
      expect(result.extractedData.guidelines).toBeUndefined()
    })

    it('should validate required fields', () => {
      const result: DocumentParseResult = {
        success: true,
        extractedData: {
          rawText: 'Text content',
          extractedAt: new Date().toISOString(),
          assetId: 'required-asset-id',
          brandId: 'required-brand-id',
        },
        message: 'Success message',
      }

      expect(result.extractedData.assetId).toBeTruthy()
      expect(result.extractedData.brandId).toBeTruthy()
      expect(result.extractedData.rawText).toBeTruthy()
      expect(result.extractedData.extractedAt).toBeTruthy()
      expect(Date.parse(result.extractedData.extractedAt)).not.toBeNaN()
    })
  })

  describe('DocumentParseRequest', () => {
    it('should require assetId', () => {
      const request: DocumentParseRequest = {
        assetId: 'required-asset-id',
      }

      expect(request.assetId).toBeTruthy()
      expect(request.parseSettings).toBeUndefined()
    })

    it('should accept optional parseSettings', () => {
      const request: DocumentParseRequest = {
        assetId: 'asset-123',
        parseSettings: {
          extractColors: true,
          extractFonts: false,
        },
      }

      expect(request.assetId).toBe('asset-123')
      expect(request.parseSettings?.extractColors).toBe(true)
      expect(request.parseSettings?.extractFonts).toBe(false)
    })
  })

  describe('Constant Arrays', () => {
    it('should have correct parseable asset types', () => {
      expect(PARSEABLE_ASSET_TYPES).toEqual(['BRAND_GUIDELINES', 'DOCUMENT'])
      expect(PARSEABLE_ASSET_TYPES).toHaveLength(2)
    })

    it('should have correct parseable mime types', () => {
      const expectedMimeTypes = [
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/msword',
        'text/plain',
      ]

      expect(PARSEABLE_MIME_TYPES).toEqual(expectedMimeTypes)
      expect(PARSEABLE_MIME_TYPES).toHaveLength(4)
    })

    it('should have proper type inference for ParseableAssetType', () => {
      const assetType1: ParseableAssetType = 'BRAND_GUIDELINES'
      const assetType2: ParseableAssetType = 'DOCUMENT'

      expect(assetType1).toBe('BRAND_GUIDELINES')
      expect(assetType2).toBe('DOCUMENT')

      // TypeScript should prevent invalid assignments
      // const invalidType: ParseableAssetType = 'INVALID' // Would cause TS error
    })

    it('should have proper type inference for ParseableMimeType', () => {
      const mimeType1: ParseableMimeType = 'application/pdf'
      const mimeType2: ParseableMimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      const mimeType3: ParseableMimeType = 'application/msword'
      const mimeType4: ParseableMimeType = 'text/plain'

      expect(mimeType1).toBe('application/pdf')
      expect(mimeType2).toBe('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
      expect(mimeType3).toBe('application/msword')
      expect(mimeType4).toBe('text/plain')
    })
  })

  describe('Type Guards and Validation', () => {
    it('should validate DocumentParseSettings shape', () => {
      const isValidParseSettings = (obj: any): obj is DocumentParseSettings => {
        return (
          typeof obj === 'object' &&
          obj !== null &&
          (obj.extractColors === undefined || typeof obj.extractColors === 'boolean') &&
          (obj.extractFonts === undefined || typeof obj.extractFonts === 'boolean') &&
          (obj.extractVoice === undefined || typeof obj.extractVoice === 'boolean') &&
          (obj.extractGuidelines === undefined || typeof obj.extractGuidelines === 'boolean')
        )
      }

      expect(isValidParseSettings({})).toBe(true)
      expect(isValidParseSettings({ extractColors: true })).toBe(true)
      expect(isValidParseSettings({ extractColors: 'invalid' })).toBe(false)
      expect(isValidParseSettings(null)).toBe(false)
    })

    it('should validate ExtractedVoiceData shape', () => {
      const isValidVoiceData = (obj: any): obj is ExtractedVoiceData => {
        return (
          typeof obj === 'object' &&
          obj !== null &&
          (obj.voiceDescription === null || typeof obj.voiceDescription === 'string') &&
          typeof obj.toneAttributes === 'object' &&
          obj.toneAttributes !== null &&
          (obj.communicationStyle === null || typeof obj.communicationStyle === 'string')
        )
      }

      const validVoice: ExtractedVoiceData = {
        voiceDescription: 'Test',
        toneAttributes: { professional: 5 },
        communicationStyle: 'formal',
      }

      const invalidVoice = {
        voiceDescription: 123, // Invalid: should be string or null
        toneAttributes: 'invalid', // Invalid: should be object
        communicationStyle: true, // Invalid: should be string or null
      }

      expect(isValidVoiceData(validVoice)).toBe(true)
      expect(isValidVoiceData(invalidVoice)).toBe(false)
    })
  })
})