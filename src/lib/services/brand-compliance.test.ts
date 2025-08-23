import { afterEach,beforeEach, describe, expect, it, jest } from '@jest/globals'

import { BrandContext } from '@/lib/types/content-generation'

// Mock fetch globally
const mockFetch = jest.fn()
global.fetch = mockFetch as any

// Create a mock for the entire module
const mockGenerateText = jest.fn()
const mockStreamText = jest.fn()
const mockIsReady = jest.fn(() => true)

jest.mock('./openai-service', () => {
  const mockInstance = {
    generateText: mockGenerateText,
    streamText: mockStreamText,
    isReady: mockIsReady
  }
  
  return {
    openAIService: {
      instance: mockInstance
    },
    OpenAIService: jest.fn(() => mockInstance),
    createOpenAIService: jest.fn(() => mockInstance)
  }
})

// Import after the mock is set up
import { BrandComplianceError, BrandComplianceService } from './brand-compliance'

describe('BrandComplianceService', () => {
  let service: BrandComplianceService
  let mockBrandContext: BrandContext
  let mockOpenAIInstance: any

  beforeEach(() => {
    jest.clearAllMocks()
    
    // Create a mock OpenAI service instance
    mockOpenAIInstance = {
      generateText: mockGenerateText,
      streamText: mockStreamText,
      isReady: mockIsReady
    }
    
    // Set up test environment
    process.env.OPENAI_API_KEY = 'test-api-key'
    service = new BrandComplianceService('test-api-key', mockOpenAIInstance)
    
    // Reset mock and ensure clean state
    mockGenerateText.mockReset()
    
    // Setup default mock behavior - ensure all calls return valid responses
    mockGenerateText.mockResolvedValue({ text: '50' })

    // Mock brand context
    mockBrandContext = {
      name: 'TestBrand',
      tagline: 'Innovation First',
      voiceDescription: 'Professional, approachable, and innovative',
      communicationStyle: 'Clear, concise, and expert-driven',
      values: ['Innovation', 'Quality', 'Customer Success'],
      restrictedTerms: ['cheap', 'terrible', 'worst'],
      messagingFramework: [
        {
          pillar: 'Innovation',
          description: 'Leading edge technology solutions',
          keywords: ['cutting-edge', 'advanced', 'breakthrough']
        }
      ],
      complianceRules: [
        {
          rule: 'No negative language',
          severity: 'warning',
          description: 'Avoid negative terms that could harm brand perception'
        }
      ]
    }
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('constructor', () => {
    it('should initialize with API key', () => {
      expect(() => new BrandComplianceService('test-key')).not.toThrow()
    })

    it('should throw error without API key', () => {
      // Temporarily clear the environment variable
      const originalApiKey = process.env.OPENAI_API_KEY
      delete process.env.OPENAI_API_KEY
      
      expect(() => new BrandComplianceService('')).toThrow(BrandComplianceError)
      expect(() => new BrandComplianceService('')).toThrow('OpenAI API key is required')
      
      // Restore the environment variable
      process.env.OPENAI_API_KEY = originalApiKey
    })
  })

  describe('validateContent', () => {
    it('should validate compliant content successfully', async () => {
      // Mock successful moderation response
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 'test-id',
          model: 'text-moderation-latest',
          results: [{
            categories: {
              hate: false,
              'hate/threatening': false,
              harassment: false,
              'harassment/threatening': false,
              'self-harm': false,
              'self-harm/intent': false,
              'self-harm/instructions': false,
              sexual: false,
              'sexual/minors': false,
              violence: false,
              'violence/graphic': false
            },
            category_scores: {
              hate: 0.001,
              'hate/threatening': 0.001,
              harassment: 0.001,
              'harassment/threatening': 0.001,
              'self-harm': 0.001,
              'self-harm/intent': 0.001,
              'self-harm/instructions': 0.001,
              sexual: 0.001,
              'sexual/minors': 0.001,
              violence: 0.001,
              'violence/graphic': 0.001
            },
            flagged: false
          }]
        })
      })

      // Clear default mock and set specific responses for this test
      mockGenerateText.mockReset()
      
      // Mock AI responses for brand analysis
      // The service calls generateText in this order:
      // 1. Brand voice validation
      // 2. Messaging framework validation  
      // 3. Brand alignment calculation
      mockGenerateText
        .mockResolvedValueOnce({
          text: JSON.stringify({
            isCompliant: true,
            violations: [],
            confidence: 0.9
          })
        })
        .mockResolvedValueOnce({
          text: JSON.stringify({
            alignsWithFramework: true,
            alignedPillars: ['Innovation'],
            misalignmentReason: null,
            suggestion: null
          })
        })
        .mockResolvedValueOnce({
          text: '85'
        })

      const content = 'Our innovative solutions provide advanced technology for customer success.'
      
      const result = await service.validateContent(content, mockBrandContext)

      expect(result.isCompliant).toBe(true)
      expect(result.violations).toHaveLength(0)
      expect(result.brandAlignmentScore).toBe(85)
      expect(result.score).toBeGreaterThan(0)
      expect(result.processing.duration).toBeGreaterThanOrEqual(0)
    })

    it('should detect restricted terms violations', async () => {
      // Mock moderation response (clean)
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 'test-id',
          model: 'text-moderation-latest',
          results: [{ categories: {}, category_scores: {}, flagged: false }]
        })
      })

      mockGenerateText
        .mockResolvedValueOnce({ text: JSON.stringify({ isCompliant: true, violations: [], confidence: 0.9 }) })
        .mockResolvedValueOnce({ text: JSON.stringify({ alignsWithFramework: true, alignedPillars: [], misalignmentReason: null, suggestion: null }) })
        .mockResolvedValueOnce({ text: '75' })

      const content = 'This cheap product is terrible quality.'
      const result = await service.validateContent(content, mockBrandContext)

      expect(result.isCompliant).toBe(false)
      expect(result.violations.some(v => v.message.includes('cheap'))).toBe(true)
      expect(result.violations.some(v => v.message.includes('terrible'))).toBe(true)
    })

    it('should detect content moderation violations', async () => {
      // Mock flagged moderation response
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 'test-id',
          model: 'text-moderation-latest',
          results: [{
            categories: {
              hate: true,
              harassment: false,
              'self-harm': false,
              sexual: false,
              violence: false
            },
            category_scores: {
              hate: 0.8,
              harassment: 0.1,
              'self-harm': 0.1,
              sexual: 0.1,
              violence: 0.1
            },
            flagged: true
          }]
        })
      })

      mockGenerateText
        .mockResolvedValueOnce({ text: JSON.stringify({ isCompliant: true, violations: [], confidence: 0.9 }) })
        .mockResolvedValueOnce({ text: JSON.stringify({ alignsWithFramework: true, alignedPillars: [], misalignmentReason: null, suggestion: null }) })
        .mockResolvedValueOnce({ text: '50' })

      const content = 'Offensive content that would be flagged'
      const result = await service.validateContent(content, mockBrandContext)

      expect(result.isCompliant).toBe(false)
      expect(result.violations.some(v => v.message.includes('hate'))).toBe(true)
      expect(result.moderationResult?.results[0].flagged).toBe(true)
    })

    it('should handle API errors gracefully', async () => {
      // Mock API error
      mockFetch.mockRejectedValueOnce(new Error('Network error'))

      await expect(
        service.validateContent('test content', mockBrandContext)
      ).rejects.toThrow(BrandComplianceError)
    })

    it('should validate with custom config', async () => {
      // Mock responses
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 'test-id',
          model: 'text-moderation-latest',
          results: [{ categories: {}, category_scores: {}, flagged: false }]
        })
      })

      mockGenerateText.mockResolvedValueOnce({ text: '80' })

      const content = 'Test content'
      const config = {
        enforceBrandVoice: false,
        checkRestrictedTerms: false,
        validateMessaging: false
      }

      const result = await service.validateContent(content, mockBrandContext, config)

      expect(result).toBeDefined()
      expect(result.processing.duration).toBeGreaterThanOrEqual(0)
    })
  })

  describe('testConnection', () => {
    it('should return true for successful connection', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 'test-id',
          model: 'text-moderation-latest',
          results: [{ categories: {}, category_scores: {}, flagged: false }]
        })
      })

      const result = await service.testConnection()
      expect(result).toBe(true)
    })

    it('should return false for failed connection', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Connection failed'))

      const result = await service.testConnection()
      expect(result).toBe(false)
    })
  })

  describe('getComplianceRules', () => {
    it('should extract rules from brand context', () => {
      const rules = service.getComplianceRules(mockBrandContext)

      expect(rules).toContainEqual(
        expect.objectContaining({
          rule: 'No restricted terms',
          severity: 'error'
        })
      )

      expect(rules).toContainEqual(
        expect.objectContaining({
          rule: 'Brand voice alignment',
          severity: 'warning'
        })
      )

      expect(rules).toContainEqual(
        expect.objectContaining({
          rule: 'Messaging framework alignment',
          severity: 'warning'
        })
      )
    })

    it('should handle empty brand context', () => {
      const emptyContext: BrandContext = {
        name: 'Empty Brand'
      }

      const rules = service.getComplianceRules(emptyContext)
      expect(rules).toHaveLength(0)
    })
  })

  describe('error handling', () => {
    it('should handle malformed JSON responses', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 'test-id',
          model: 'text-moderation-latest',
          results: [{ categories: {}, category_scores: {}, flagged: false }]
        })
      })

      // Mock malformed JSON response
      mockGenerateText.mockResolvedValueOnce({ text: 'invalid json' })

      const content = 'Test content without restricted terms'
      
      // Should not throw but should handle gracefully
      const result = await service.validateContent(content, mockBrandContext)
      expect(result).toBeDefined()
      // Brand voice validation should be skipped due to JSON parse error, but other validations may still run
      // The exact count depends on what other validation rules are triggered
    })

    it('should handle rate limiting errors', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 429,
        statusText: 'Too Many Requests'
      })

      await expect(
        service.validateContent('test', mockBrandContext)
      ).rejects.toThrow(BrandComplianceError)
    })
  })

  describe('service factory functions', () => {
    it('should create service with factory function', () => {
      const { createBrandComplianceService } = require('./brand-compliance')
      const newService = createBrandComplianceService('test-key')
      expect(newService).toBeInstanceOf(BrandComplianceService)
    })

    it('should provide singleton instance', () => {
      const { brandComplianceService } = require('./brand-compliance')
      const instance1 = brandComplianceService.instance
      const instance2 = brandComplianceService.instance
      expect(instance1).toBe(instance2)
    })
  })
})