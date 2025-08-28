import { beforeEach,describe, expect, it, jest } from '@jest/globals'

// Import the existing mock from the __mocks__ directory
jest.mock('ai')
import { generateText } from 'ai'
const mockGenerateText = generateText as jest.MockedFunction<typeof generateText>

import { BrandContext } from '@/lib/types/content-generation'

import {
  DocumentType,
  extractRestrictedTerms,
  mergeBrandContexts,
  parseFromText,
  validateBrandContext} from './brand-guideline-parser'

describe('BrandGuidelineParser', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    // Ensure mock is properly reset
    mockGenerateText.mockReset()
  })

  describe('parseFromText', () => {
    it('should parse brand guidelines from text content', async () => {
      // Mock document type detection - not needed since we're passing the type explicitly
      // Mock content extraction
      mockGenerateText.mockResolvedValueOnce({
        text: JSON.stringify({
          brandName: 'TestBrand',
          tagline: 'Innovation First',
          voiceDescription: 'Professional and approachable',
          communicationStyle: 'Clear and concise',
          voiceKeywords: ['professional', 'innovative'],
          styleAttributes: ['modern', 'clean'],
          values: ['Innovation', 'Quality'],
          targetAudience: {
            demographics: '25-45 professionals',
            psychographics: 'Tech-savvy early adopters'
          },
          messagingPillars: [{
            pillar: 'Innovation',
            description: 'Leading edge solutions',
            keywords: ['cutting-edge', 'advanced']
          }],
          restrictedTerms: ['cheap', 'basic'],
          complianceRules: [{
            rule: 'No negative language',
            severity: 'warning',
            description: 'Avoid negative terms'
          }]
        })
      })

      const content = `
        Brand Guidelines for TestBrand
        
        Our voice is professional and approachable.
        We value innovation and quality.
        Avoid using terms like cheap or basic.
      `

      const result = await parseFromText(content, DocumentType.BRAND_GUIDE)

      expect(result.success).toBe(true)
      expect(result.brandContext.name).toBe('TestBrand')
      expect(result.brandContext.voiceDescription).toBe('Professional and approachable')
      expect(result.brandContext.values).toContain('Innovation')
      expect(result.brandContext.restrictedTerms).toContain('cheap')
      expect(result.confidence).toBeGreaterThan(0)
      expect(result.processingTime).toBeGreaterThanOrEqual(0)
    })

    it('should handle parsing errors gracefully', async () => {
      // Mock error in parsing - with document type detection first, then error
      mockGenerateText
        .mockResolvedValueOnce({ text: 'brand_guide' })
        .mockRejectedValueOnce(new Error('AI service error'))

      const result = await parseFromText('test content')

      expect(result.success).toBe(false)
      expect(result.error).toBeDefined()
      expect(result.confidence).toBe(0)
    })

    it('should auto-detect document type when unknown', async () => {
      mockGenerateText
        .mockResolvedValueOnce({ text: 'voice_tone_guide' })
        .mockResolvedValueOnce({
          text: JSON.stringify({
            brandName: 'TestBrand',
            voiceDescription: 'Friendly and professional'
          })
        })

      const content = 'Voice and tone guidelines for TestBrand'
      const result = await parseFromText(content, DocumentType.UNKNOWN)

      expect(result.success).toBe(true)
      // The first call should be for document type detection, second should be extraction with the detected type
      expect(mockGenerateText).toHaveBeenNthCalledWith(2,
        expect.objectContaining({
          prompt: expect.stringContaining('voice tone_guide')
        })
      )
    })

    it('should handle malformed JSON response', async () => {
      mockGenerateText
        .mockResolvedValueOnce({ text: 'brand_guide' })
        .mockResolvedValueOnce({ text: 'invalid json response' })

      const result = await parseFromText('test content')

      expect(result.success).toBe(false)
      expect(result.error).toBeDefined()
    })
  })

  describe('validateBrandContext', () => {
    it('should validate complete brand context', () => {
      const brandContext: BrandContext = {
        name: 'TestBrand',
        tagline: 'Innovation First',
        voiceDescription: 'Professional and approachable tone',
        communicationStyle: 'Clear, concise, and expert-driven',
        values: ['Innovation', 'Quality'],
        targetAudience: {
          demographics: '25-45 professionals',
          psychographics: 'Tech-savvy early adopters'
        },
        messagingFramework: [{
          pillar: 'Innovation',
          description: 'Leading edge solutions',
          keywords: ['cutting-edge', 'advanced']
        }],
        restrictedTerms: ['cheap']
      }

      const validation = validateBrandContext(brandContext)

      expect(validation.hasVoiceDescription).toBe(true)
      expect(validation.hasCommunicationStyle).toBe(true)
      expect(validation.hasValues).toBe(true)
      expect(validation.hasMessagingFramework).toBe(true)
      expect(validation.hasTargetAudience).toBe(true)
      expect(validation.completenessScore).toBe(100)
    })

    it('should validate incomplete brand context', () => {
      const brandContext: BrandContext = {
        name: 'TestBrand',
        voiceDescription: 'Professional',
        values: ['Innovation']
      }

      const validation = validateBrandContext(brandContext)

      expect(validation.hasVoiceDescription).toBe(true)
      expect(validation.hasCommunicationStyle).toBe(false)
      expect(validation.hasValues).toBe(true)
      expect(validation.hasMessagingFramework).toBe(false)
      expect(validation.hasTargetAudience).toBe(false)
      expect(validation.completenessScore).toBe(40) // 2 out of 5 criteria met
    })

    it('should handle minimal brand context', () => {
      const brandContext: BrandContext = {
        name: 'MinimalBrand'
      }

      const validation = validateBrandContext(brandContext)

      expect(validation.completenessScore).toBe(0)
      expect(validation.hasVoiceDescription).toBe(false)
    })
  })

  describe('mergeBrandContexts', () => {
    it('should merge multiple brand contexts', () => {
      const context1: Partial<BrandContext> = {
        name: 'TestBrand',
        voiceDescription: 'Professional',
        values: ['Innovation', 'Quality'],
        restrictedTerms: ['cheap']
      }

      const context2: Partial<BrandContext> = {
        tagline: 'Innovation First',
        communicationStyle: 'Clear and concise',
        values: ['Quality', 'Excellence'], // Some overlap with context1
        restrictedTerms: ['terrible'],
        messagingFramework: [{
          pillar: 'Innovation',
          description: 'Leading solutions',
          keywords: ['advanced']
        }]
      }

      const merged = mergeBrandContexts([context1, context2])

      expect(merged.name).toBe('TestBrand')
      expect(merged.tagline).toBe('Innovation First')
      expect(merged.voiceDescription).toBe('Professional')
      expect(merged.communicationStyle).toBe('Clear and concise')
      expect(merged.values).toEqual(['Innovation', 'Quality', 'Excellence'])
      expect(merged.restrictedTerms).toEqual(['cheap', 'terrible'])
      expect(merged.messagingFramework).toHaveLength(1)
    })

    it('should handle empty contexts array', () => {
      const merged = mergeBrandContexts([])

      expect(merged.name).toBe('')
      expect(merged.values).toEqual([])
      expect(merged.restrictedTerms).toEqual([])
    })

    it('should merge objects correctly', () => {
      const context1: Partial<BrandContext> = {
        name: 'TestBrand',
        toneAttributes: {
          formal: 'true',
          friendly: 'moderate'
        },
        targetAudience: {
          demographics: '25-45 professionals'
        }
      }

      const context2: Partial<BrandContext> = {
        toneAttributes: {
          professional: 'high',
          playful: 'low'
        },
        targetAudience: {
          psychographics: 'Tech-savvy'
        }
      }

      const merged = mergeBrandContexts([context1, context2])

      expect(merged.toneAttributes).toEqual({
        formal: 'true',
        friendly: 'moderate',
        professional: 'high',
        playful: 'low'
      })

      expect(merged.targetAudience).toEqual({
        demographics: '25-45 professionals',
        psychographics: 'Tech-savvy'
      })
    })
  })

  describe('extractRestrictedTerms', () => {
    it('should extract restricted terms from content', async () => {
      mockGenerateText.mockResolvedValueOnce({
        text: JSON.stringify(['competitor-brand', 'low-quality', 'overpriced'])
      })

      const content = `
        Brand Guidelines:
        - Avoid mentioning competitor-brand in marketing materials
        - Don't use terms like low-quality or overpriced
      `

      const result = await extractRestrictedTerms(content, ['existing-term'])

      expect(result).toContain('existing-term')
      expect(result).toContain('competitor-brand')
      expect(result).toContain('low-quality')
      expect(result).toContain('overpriced')
    })

    it('should handle AI extraction errors gracefully', async () => {
      mockGenerateText.mockRejectedValueOnce(new Error('AI service error'))

      const existingTerms = ['existing-term']
      const result = await extractRestrictedTerms('test content', existingTerms)

      expect(result).toEqual(existingTerms)
    })

    it('should handle malformed JSON response', async () => {
      mockGenerateText.mockResolvedValueOnce({
        text: 'invalid json'
      })

      const existingTerms = ['existing-term']
      const result = await extractRestrictedTerms('test content', existingTerms)

      expect(result).toEqual(existingTerms)
    })
  })

  describe('DocumentType detection', () => {
    it('should detect document types correctly', async () => {
      // Test different document types
      const testCases = [
        { input: 'brand_guide', expected: DocumentType.BRAND_GUIDE },
        { input: 'voice_tone_guide', expected: DocumentType.VOICE_TONE_GUIDE },
        { input: 'unknown_type', expected: DocumentType.UNKNOWN }
      ]

      for (const testCase of testCases) {
        mockGenerateText
          .mockResolvedValueOnce({ text: testCase.input })
          .mockResolvedValueOnce({ text: JSON.stringify({ brandName: 'Test' }) })

        const result = await parseFromText('test content', DocumentType.UNKNOWN)

        if (testCase.expected !== DocumentType.UNKNOWN) {
          expect(result.success).toBe(true)
        }
      }
    })
  })

  describe('confidence calculation', () => {
    it('should calculate higher confidence for complete data', async () => {
      // Mock complete extraction result
      mockGenerateText
        .mockResolvedValueOnce({ text: 'brand_guide' })
        .mockResolvedValueOnce({
          text: JSON.stringify({
            brandName: 'Complete Brand',
            voiceDescription: 'Very detailed voice description',
            communicationStyle: 'Detailed communication style',
            values: ['Value1', 'Value2', 'Value3'],
            messagingPillars: [
              { pillar: 'Pillar1', description: 'Description', keywords: ['key1'] },
              { pillar: 'Pillar2', description: 'Description', keywords: ['key2'] }
            ],
            targetAudience: {
              demographics: 'Detailed demographics',
              psychographics: 'Detailed psychographics'
            }
          })
        })

      const longContent = 'A'.repeat(5000) // Long content for confidence boost
      const result = await parseFromText(longContent)

      expect(result.confidence).toBeGreaterThan(80)
    })

    it('should calculate lower confidence for sparse data', async () => {
      // Mock sparse extraction result
      mockGenerateText
        .mockResolvedValueOnce({ text: 'brand_guide' })
        .mockResolvedValueOnce({
          text: JSON.stringify({
            brandName: 'Brand'
            // Missing most fields
          })
        })

      const shortContent = 'Brief content'
      const result = await parseFromText(shortContent)

      expect(result.confidence).toBeLessThan(50)
    })
  })
})