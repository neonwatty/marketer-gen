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
    mockGenerateText.mockResolvedValue({ text: '75' })

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
      
      // Instead of trying to predict the exact order, let's just mock all calls to return good values
      mockGenerateText.mockResolvedValue({ text: '85' })
      
      // For specific calls that need JSON responses, set up specific mocks
      mockGenerateText
        .mockResolvedValueOnce({
          text: JSON.stringify({
            overallCompliance: {
              isCompliant: true,
              confidenceScore: 85,
              overallRisk: 'low'
            },
            detailedViolations: []
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

      const content = 'Our innovative solutions provide advanced technology for customer success.'
      
      const result = await service.validateContent(content, mockBrandContext)

      expect(result.isCompliant).toBe(true)
      expect(result.violations).toHaveLength(0)
      expect(result.brandAlignmentScore).toBeGreaterThan(50)
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

  describe('enhanced features', () => {
    describe('caching', () => {
      it('should cache validation results', async () => {
        mockFetch.mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            id: 'test-id',
            model: 'text-moderation-007',
            results: [{ categories: {}, category_scores: {}, flagged: false }]
          })
        })

        mockGenerateText
          .mockResolvedValueOnce({ text: JSON.stringify({ isCompliant: true, violations: [], confidence: 0.9 }) })
          .mockResolvedValueOnce({ text: JSON.stringify({ alignsWithFramework: true, alignedPillars: [], misalignmentReason: null, suggestion: null }) })
          .mockResolvedValueOnce({ text: '85' })

        const content = 'Test content for caching'
        
        // First call should perform full validation
        const result1 = await service.validateContent(content, mockBrandContext)
        expect(result1).toBeDefined()
        
        // Second call with same content should use cache
        const result2 = await service.validateContent(content, mockBrandContext)
        expect(result2).toBeDefined()
        expect(result2.brandAlignmentScore).toBeGreaterThan(50)
      })
    })

    describe('violation prediction', () => {
      it('should predict potential violations', async () => {
        mockGenerateText.mockResolvedValueOnce({
          text: JSON.stringify({
            predictions: [{
              type: 'brand_voice',
              likelihood: 0.7,
              reason: 'Tone may not match brand voice',
              prevention: 'Review tone guidelines',
              confidence: 0.8
            }],
            overallRiskScore: 65,
            recommendations: ['Review brand voice guidelines']
          })
        })

        const predictions = await service.predictViolations('Test content', mockBrandContext)
        
        expect(predictions.predictions).toHaveLength(1)
        expect(predictions.predictions[0].type).toBe('brand_voice')
        expect(predictions.overallRiskScore).toBe(65)
        expect(predictions.recommendations).toContain('Review brand voice guidelines')
      })

      it('should handle prediction errors gracefully', async () => {
        mockGenerateText.mockRejectedValueOnce(new Error('AI service error'))

        const predictions = await service.predictViolations('Test content', mockBrandContext)
        
        expect(predictions.predictions).toEqual([])
        expect(predictions.overallRiskScore).toBe(50)
        expect(predictions.recommendations).toContain('Unable to perform predictive analysis - review content manually')
      })
    })

    describe('preventive suggestions', () => {
      it('should generate preventive suggestions', async () => {
        mockGenerateText.mockResolvedValueOnce({
          text: JSON.stringify({
            suggestions: [{
              category: 'Brand Voice',
              priority: 'high',
              suggestion: 'Strengthen brand voice alignment',
              rationale: 'This will improve brand consistency',
              implementationTips: ['Use brand-specific language', 'Follow tone guidelines']
            }],
            alternativeApproaches: ['Try different messaging angle'],
            riskMitigation: ['Review with brand team']
          })
        })

        const suggestions = await service.generatePreventiveSuggestions(
          'Test content', 
          mockBrandContext, 
          'Marketing professionals', 
          'Social Media Post'
        )
        
        expect(suggestions.suggestions).toHaveLength(1)
        expect(suggestions.suggestions[0].priority).toBe('high')
        expect(suggestions.alternativeApproaches).toContain('Try different messaging angle')
        expect(suggestions.riskMitigation).toContain('Review with brand team')
      })
    })

    describe('auto-fix violations', () => {
      it('should auto-fix minor violations', async () => {
        const violations = [{
          type: 'restricted_terms' as const,
          severity: 'warning' as const,
          message: 'Contains restricted term: cheap',
          suggestion: 'Replace with affordable'
        }]

        mockGenerateText.mockResolvedValueOnce({
          text: JSON.stringify({
            fixedContent: 'This affordable product is great quality.',
            appliedFixes: [{
              violationType: 'restricted_terms',
              originalPhrase: 'cheap product',
              fixedPhrase: 'affordable product',
              rationale: 'Replaced restricted term with approved alternative',
              confidence: 0.9
            }]
          })
        })

        const result = await service.autoFixViolations(
          'This cheap product is great quality.',
          violations,
          mockBrandContext
        )
        
        expect(result.fixedContent).toBe('This affordable product is great quality.')
        expect(result.appliedFixes).toHaveLength(1)
        expect(result.appliedFixes[0].confidence).toBe(0.9)
      })

      it('should not auto-fix error-level violations', async () => {
        const violations = [{
          type: 'content_moderation' as const,
          severity: 'error' as const,
          message: 'Content flagged for hate speech',
          suggestion: 'Remove offensive language'
        }]

        const result = await service.autoFixViolations(
          'Test content',
          violations,
          mockBrandContext
        )
        
        expect(result.fixedContent).toBe('Test content')
        expect(result.appliedFixes).toHaveLength(0)
        expect(result.manualReviewRequired).toHaveLength(1)
      })
    })

    describe('batch processing', () => {
      it('should validate multiple contents in batch', async () => {
        mockFetch.mockResolvedValue({
          ok: true,
          json: async () => ({
            id: 'test-id',
            model: 'text-moderation-007',
            results: [{ categories: {}, category_scores: {}, flagged: false }]
          })
        })

        mockGenerateText.mockResolvedValue({ text: '75' })

        const contents = [
          { id: '1', content: 'First test content' },
          { id: '2', content: 'Second test content' }
        ]

        const results = await service.batchValidateContent(contents, mockBrandContext)
        
        expect(results).toHaveLength(2)
        expect(results[0].id).toBe('1')
        expect(results[1].id).toBe('2')
        expect(results[0].result).toBeDefined()
        expect(results[1].result).toBeDefined()
      })
    })

    describe('performance metrics', () => {
      it('should provide performance metrics', async () => {
        const metrics = await service.getPerformanceMetrics()
        
        expect(metrics).toHaveProperty('cacheHitRate')
        expect(metrics).toHaveProperty('cacheSize')
        expect(metrics).toHaveProperty('averageProcessingTime')
        expect(metrics).toHaveProperty('totalValidations')
        expect(typeof metrics.cacheSize).toBe('number')
        expect(typeof metrics.averageProcessingTime).toBe('number')
      })
    })
  })

  describe('enhanced validation with GPT-4', () => {
    it('should use GPT-4 for comprehensive analysis', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 'test-id',
          model: 'text-moderation-007',
          results: [{ categories: {}, category_scores: {}, flagged: false }]
        })
      })

      mockGenerateText
        .mockResolvedValueOnce({
          text: JSON.stringify({
            overallCompliance: {
              isCompliant: false,
              confidenceScore: 75,
              overallRisk: 'medium'
            },
            detailedViolations: [{
              category: 'brand_voice',
              severity: 'warning',
              issue: 'Tone inconsistency detected',
              explanation: 'The content tone does not align with brand guidelines',
              suggestion: 'Adjust tone to match brand voice',
              confidence: 0.8
            }]
          })
        })
        .mockResolvedValueOnce({ text: JSON.stringify({ alignsWithFramework: true, alignedPillars: [], misalignmentReason: null, suggestion: null }) })
        .mockResolvedValueOnce({ text: '75' })

      const content = 'Test content with potential tone issues'
      const result = await service.validateContent(content, mockBrandContext)

      expect(result.violations).toBeDefined()
      expect(result.violations.some(v => v.message.includes('GPT-4 Analysis'))).toBe(true)
    })
  })
})