import { NextRequest } from 'next/server'

import { beforeEach,describe, expect, it, jest } from '@jest/globals'

// Mock the AI library to prevent real API calls
jest.mock('ai')
import { generateText } from 'ai'
const mockGenerateText = generateText as jest.MockedFunction<typeof generateText>

// Mock fetch for OpenAI Moderation API
const mockFetch = jest.fn()
global.fetch = mockFetch as any

// Mock the brand compliance service
const mockValidateContent = jest.fn()
const mockTestConnection = jest.fn()

jest.mock('@/lib/services/brand-compliance', () => ({
  brandComplianceService: {
    instance: {
      validateContent: mockValidateContent,
      testConnection: mockTestConnection
    }
  },
  BrandComplianceService: jest.fn(),
  BrandComplianceError: class extends Error {
    constructor(message: string, public code?: string, public violations?: any[]) {
      super(message)
      this.name = 'BrandComplianceError'
    }
  }
}))

// Import the service so we can monkey-patch it
import { brandComplianceService } from '@/lib/services/brand-compliance'

import { GET,POST } from './route'

describe('/api/ai/content-compliance', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    
    // Make sure we have a clean mock state
    mockValidateContent.mockReset()
    mockTestConnection.mockReset()
    
    // Force the singleton instance to use our mocks
    Object.defineProperty(brandComplianceService, 'instance', {
      value: {
        validateContent: mockValidateContent,
        testConnection: mockTestConnection
      },
      configurable: true
    })
  })

  describe('POST', () => {
    it('should validate content successfully', async () => {
      // Mock successful validation response
      mockValidateContent.mockResolvedValueOnce({
        isCompliant: true,
        violations: [],
        suggestions: ['Consider adding more engaging language'],
        score: 85,
        brandAlignmentScore: 90,
        processing: {
          duration: 250,
          timestamp: '2025-01-01T00:00:00Z',
          model: 'text-moderation-latest'
        }
      })

      const requestBody = {
        content: 'This is professional and innovative content that aligns with our brand.',
        brandContext: {
          name: 'TestBrand',
          voiceDescription: 'Professional and approachable',
          values: ['Innovation', 'Quality'],
          restrictedTerms: ['cheap']
        },
        config: {
          enforceBrandVoice: true,
          checkRestrictedTerms: true,
          validateMessaging: true
        }
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.compliance.isCompliant).toBe(true)
      expect(data.compliance.score).toBe(85)
      expect(data.compliance.brandAlignmentScore).toBe(90)
      expect(data.compliance.processing).toBeDefined()
      expect(mockValidateContent).toHaveBeenCalledWith(
        requestBody.content,
        requestBody.brandContext,
        requestBody.config
      )
    })

    it('should handle non-compliant content', async () => {
      // Use the pre-created mock

      mockValidateContent.mockResolvedValueOnce({
        isCompliant: false,
        violations: [
          {
            type: 'restricted_terms',
            severity: 'error',
            message: 'Content contains restricted term: "cheap"',
            suggestion: 'Remove restricted terms'
          },
          {
            type: 'brand_voice',
            severity: 'warning',
            message: 'Brand voice mismatch detected',
            suggestion: 'Adjust tone to match brand voice'
          }
        ],
        suggestions: ['Remove restricted terms', 'Adjust tone to match brand voice'],
        score: 35,
        brandAlignmentScore: 40,
        processing: {
          duration: 300,
          timestamp: '2025-01-01T00:00:00Z'
        }
      })

      const requestBody = {
        content: 'This cheap product is not good quality.',
        brandContext: {
          name: 'TestBrand',
          voiceDescription: 'Professional and premium',
          restrictedTerms: ['cheap']
        }
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.compliance.isCompliant).toBe(false)
      expect(data.compliance.violations).toHaveLength(2)
      expect(data.compliance.suggestions).toHaveLength(2)
      expect(data.compliance.score).toBe(35)
    })

    it('should validate request body and return 400 for invalid data', async () => {
      const invalidRequestBody = {
        content: '', // Empty content should fail validation
        brandContext: {
          name: 'TestBrand'
        }
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(invalidRequestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data.success).toBe(false)
      expect(data.error).toContain('Invalid request')
      expect(data.error).toContain('Content is required')
    })

    it('should handle malformed JSON', async () => {
      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: 'invalid json',
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data.success).toBe(false)
      expect(data.error).toBeDefined()
    })

    it('should handle service errors gracefully', async () => {
      // Use the pre-created mock

      mockValidateContent.mockRejectedValueOnce(new Error('OpenAI API error'))

      const requestBody = {
        content: 'Test content',
        brandContext: {
          name: 'TestBrand'
        }
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data.success).toBe(false)
      expect(data.error).toContain('Compliance validation failed')
      expect(data.error).toContain('OpenAI API error')
    })

    it('should use default config when not provided', async () => {
      // Use the pre-created mock

      mockValidateContent.mockResolvedValueOnce({
        isCompliant: true,
        violations: [],
        suggestions: [],
        score: 80,
        brandAlignmentScore: 85,
        processing: {
          duration: 200,
          timestamp: '2025-01-01T00:00:00Z'
        }
      })

      const requestBody = {
        content: 'Test content',
        brandContext: {
          name: 'TestBrand'
        }
        // No config provided - should use defaults
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(mockValidateContent).toHaveBeenCalledWith(
        'Test content',
        { name: 'TestBrand' },
        {
          enforceBrandVoice: true,
          checkRestrictedTerms: true,
          validateMessaging: true
        }
      )
    })

    it('should handle content length validation', async () => {
      const longContent = 'A'.repeat(10001) // Exceeds max length

      const requestBody = {
        content: longContent,
        brandContext: {
          name: 'TestBrand'
        }
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data.success).toBe(false)
      expect(data.error).toContain('Content too long')
    })
  })

  describe('GET', () => {
    it('should return healthy status when service is working', async () => {
      // Use the pre-created mock

      mockTestConnection.mockResolvedValueOnce(true)

      const mockRequest = new NextRequest('http://localhost:3000/api/ai/content-compliance/health')
      const response = await GET(mockRequest)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.status).toBe('healthy')
      expect(data.service).toBe('content-compliance')
      expect(data.timestamp).toBeDefined()
    })

    it('should return unhealthy status when service fails', async () => {
      // Use the pre-created mock

      mockTestConnection.mockResolvedValueOnce(false)

      const mockRequest = new NextRequest('http://localhost:3000/api/ai/content-compliance/health')
      const response = await GET(mockRequest)
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.status).toBe('unhealthy')
      expect(data.service).toBe('content-compliance')
      expect(data.error).toContain('Failed to connect to OpenAI Moderation API')
    })

    it('should handle service connection errors', async () => {
      // Use the pre-created mock

      mockTestConnection.mockRejectedValueOnce(new Error('Network error'))

      const mockRequest = new NextRequest('http://localhost:3000/api/ai/content-compliance/health')
      const response = await GET(mockRequest)
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.status).toBe('unhealthy')
      expect(data.error).toBe('Network error')
    })
  })

  describe('request validation edge cases', () => {
    it('should handle missing brandContext', async () => {
      const requestBody = {
        content: 'Test content'
        // Missing brandContext
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data.success).toBe(false)
      expect(data.error).toContain('Invalid request')
    })

    it('should handle invalid config values', async () => {
      const requestBody = {
        content: 'Test content',
        brandContext: {
          name: 'TestBrand'
        },
        config: {
          enforceBrandVoice: 'invalid', // Should be boolean
          checkRestrictedTerms: true,
          validateMessaging: true
        }
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data.success).toBe(false)
      expect(data.error).toContain('Invalid request')
    })

    it('should handle empty request body', async () => {
      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify({}),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data.success).toBe(false)
      expect(data.error).toContain('Invalid request')
    })
  })

  describe('enhanced API features', () => {
    it('should support advanced options in request', async () => {
      mockValidateContent.mockResolvedValueOnce({
        isCompliant: true,
        violations: [],
        suggestions: ['Consider adding more engaging language'],
        score: 85,
        brandAlignmentScore: 90,
        processing: {
          duration: 250,
          timestamp: '2025-01-01T00:00:00Z',
          model: 'text-moderation-007'
        }
      })

      const mockPredictViolations = jest.fn().mockResolvedValue({
        predictions: [{
          type: 'brand_voice',
          likelihood: 0.3,
          reason: 'Minor tone inconsistency',
          prevention: 'Review tone guidelines',
          confidence: 0.8
        }],
        overallRiskScore: 25,
        recommendations: ['Consider tone alignment']
      })

      const mockGeneratePreventiveSuggestions = jest.fn().mockResolvedValue({
        suggestions: [{
          category: 'Brand Voice',
          priority: 'low',
          suggestion: 'Fine-tune brand voice',
          rationale: 'Improves consistency',
          implementationTips: ['Use brand keywords']
        }],
        alternativeApproaches: ['Try different approach'],
        riskMitigation: ['Review with team']
      })

      // Add these methods to the mock instance
      Object.assign(brandComplianceService.instance, {
        predictViolations: mockPredictViolations,
        generatePreventiveSuggestions: mockGeneratePreventiveSuggestions
      })

      const requestBody = {
        content: 'This is professional and innovative content that aligns with our brand.',
        brandContext: {
          name: 'TestBrand',
          voiceDescription: 'Professional and approachable',
          values: ['Innovation', 'Quality'],
          restrictedTerms: ['cheap']
        },
        config: {
          enforceBrandVoice: true,
          checkRestrictedTerms: true,
          validateMessaging: true
        },
        options: {
          includePredictions: true,
          includePreventiveSuggestions: true,
          enableAutoFix: false,
          targetAudience: 'Business professionals',
          contentType: 'Email'
        }
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.compliance.isCompliant).toBe(true)
      expect(data.predictions).toBeDefined()
      expect(data.predictions.overallRiskScore).toBe(25)
      expect(data.preventiveSuggestions).toBeDefined()
      expect(data.preventiveSuggestions.suggestions).toHaveLength(1)
    })

    it('should handle batch validation endpoint', async () => {
      const mockBatchValidateContent = jest.fn().mockResolvedValue([
        {
          id: 'content1',
          result: {
            isCompliant: true,
            violations: [],
            suggestions: [],
            score: 90,
            brandAlignmentScore: 85,
            processing: {
              duration: 200,
              timestamp: '2025-01-01T00:00:00Z',
              model: 'text-moderation-007'
            }
          }
        },
        {
          id: 'content2',
          result: {
            isCompliant: false,
            violations: [{
              type: 'restricted_terms',
              severity: 'error',
              message: 'Contains restricted term',
              suggestion: 'Remove restricted term'
            }],
            suggestions: ['Remove restricted term'],
            score: 30,
            brandAlignmentScore: 40,
            processing: {
              duration: 250,
              timestamp: '2025-01-01T00:00:00Z',
              model: 'text-moderation-007'
            }
          }
        }
      ])

      Object.assign(brandComplianceService.instance, {
        batchValidateContent: mockBatchValidateContent
      })

      const requestBody = {
        contents: [
          { id: 'content1', content: 'Good content example' },
          { id: 'content2', content: 'Bad content with cheap quality' }
        ],
        brandContext: {
          name: 'TestBrand',
          restrictedTerms: ['cheap']
        },
        maxConcurrency: 2
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance/batch', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.results).toHaveLength(2)
      expect(data.summary.total).toBe(2)
      expect(data.summary.compliant).toBe(1)
      expect(data.summary.nonCompliant).toBe(1)
    })

    it('should handle prediction analysis endpoint', async () => {
      const mockPredictViolations = jest.fn().mockResolvedValue({
        predictions: [{
          type: 'messaging_framework',
          likelihood: 0.6,
          reason: 'May not align with messaging pillars',
          prevention: 'Review messaging framework',
          confidence: 0.75
        }],
        overallRiskScore: 60,
        recommendations: ['Check messaging alignment', 'Review brand guidelines']
      })

      const mockGeneratePreventiveSuggestions = jest.fn().mockResolvedValue({
        suggestions: [{
          category: 'Messaging',
          priority: 'medium',
          suggestion: 'Align with messaging pillars',
          rationale: 'Ensures brand consistency',
          implementationTips: ['Use pillar keywords', 'Reference brand values']
        }],
        alternativeApproaches: ['Focus on different pillar', 'Adjust messaging angle'],
        riskMitigation: ['Validate with brand team', 'A/B test different versions']
      })

      Object.assign(brandComplianceService.instance, {
        predictViolations: mockPredictViolations,
        generatePreventiveSuggestions: mockGeneratePreventiveSuggestions
      })

      const requestBody = {
        content: 'Marketing content to analyze',
        brandContext: {
          name: 'TestBrand',
          voiceDescription: 'Professional and approachable'
        },
        options: {
          targetAudience: 'B2B customers',
          contentType: 'Blog Post'
        }
      }

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance/predict', {
        method: 'POST',
        body: JSON.stringify(requestBody),
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.predictions).toBeDefined()
      expect(data.predictions.overallRiskScore).toBe(60)
      expect(data.preventiveSuggestions).toBeDefined()
      expect(data.preventiveSuggestions.suggestions[0].priority).toBe('medium')
    })

    it('should return enhanced health status with metrics', async () => {
      mockTestConnection.mockResolvedValueOnce(true)

      const mockGetPerformanceMetrics = jest.fn().mockResolvedValue({
        cacheHitRate: 0.75,
        cacheSize: 150,
        averageProcessingTime: 285,
        totalValidations: 1250
      })

      Object.assign(brandComplianceService.instance, {
        getPerformanceMetrics: mockGetPerformanceMetrics
      })

      const request = new NextRequest('http://localhost:3000/api/ai/content-compliance?metrics=true')
      const response = await GET(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.status).toBe('healthy')
      expect(data.version).toBe('2.0')
      expect(data.features).toContain('gpt4-compliance-analysis')
      expect(data.features).toContain('violation-prediction')
      expect(data.performanceMetrics).toBeDefined()
      expect(data.performanceMetrics.cacheHitRate).toBe(0.75)
      expect(data.performanceMetrics.totalValidations).toBe(1250)
    })
  })
})