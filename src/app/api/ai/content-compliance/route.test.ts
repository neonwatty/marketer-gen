import { NextRequest } from 'next/server'

import { beforeEach,describe, expect, it, jest } from '@jest/globals'

// Create mocks first
const mockValidateContent = jest.fn()
const mockTestConnection = jest.fn()

// Mock the brand compliance service
jest.mock('@/lib/services/brand-compliance', () => ({
  brandComplianceService: {
    instance: {
      validateContent: mockValidateContent,
      testConnection: mockTestConnection
    }
  }
}))

import { GET,POST } from './route'

describe('/api/ai/content-compliance', () => {
  beforeEach(() => {
    jest.clearAllMocks()
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
      expect(data.error).toContain('Content moderation failed')
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

      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.status).toBe('healthy')
      expect(data.service).toBe('content-compliance')
      expect(data.timestamp).toBeDefined()
    })

    it('should return unhealthy status when service fails', async () => {
      // Use the pre-created mock

      mockTestConnection.mockResolvedValueOnce(false)

      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.status).toBe('unhealthy')
      expect(data.service).toBe('content-compliance')
      expect(data.error).toContain('Failed to connect to OpenAI Moderation API')
    })

    it('should handle service connection errors', async () => {
      // Use the pre-created mock

      mockTestConnection.mockRejectedValueOnce(new Error('Network error'))

      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.status).toBe('unhealthy')
      expect(data.error).toBe('Failed to connect to OpenAI Moderation API')
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
})