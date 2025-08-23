import { beforeEach, afterEach, describe, expect, it, jest } from '@jest/globals'
import { getServerSession } from 'next-auth'
import { NextRequest } from 'next/server'

// Mock dependencies before importing the route and services

// Create mock functions for OpenAI service
const mockIsReady = jest.fn()
const mockGenerateText = jest.fn()
const mockStreamText = jest.fn()
const mockGetConfig = jest.fn()

// Create a mock stream result
const mockStreamResult = {
  toAIStream: jest.fn().mockReturnValue({
    pipeThrough: jest.fn().mockReturnValue('mock-stream-data')
  })
}

// Create a mock instance
const mockOpenAIInstance = {
  isReady: mockIsReady,
  generateText: mockGenerateText,
  streamText: mockStreamText,
  getConfig: mockGetConfig,
}

jest.mock('@/lib/services/openai-service', () => ({
  openAIService: {
    get instance() {
      return mockOpenAIInstance
    },
  },
  OpenAIService: jest.fn().mockImplementation(() => mockOpenAIInstance),
  OpenAIServiceError: class OpenAIServiceError extends Error {
    constructor(message: string, public code: string, public statusCode?: number, public originalError?: Error) {
      super(message)
      this.name = 'OpenAIServiceError'
    }
  },
}))

// Mock the generated Prisma client
const mockBrandFindFirst = jest.fn()

// Mock Prisma directly with a simple object
const mockPrismaInstance = {
  brand: {
    findFirst: mockBrandFindFirst,
  },
  $connect: jest.fn().mockResolvedValue(undefined),
  $disconnect: jest.fn().mockResolvedValue(undefined),
}

jest.mock('@/lib/db', () => ({
  prisma: mockPrismaInstance
}))

// Mock next-auth
jest.mock('next-auth', () => ({
  getServerSession: jest.fn(),
}))

// Mock auth options
jest.mock('@/lib/auth', () => ({
  authOptions: {},
}))

// Import after mocking
import { openAIService } from '@/lib/services/openai-service'
import { prisma } from '@/lib/db'
import { GET, POST } from './route'

const mockGetServerSession = getServerSession as jest.MockedFunction<typeof getServerSession>

// Test data
const mockUser = {
  id: 'user123',
  email: 'test@example.com',
  name: 'Test User'
}

const mockBrand = {
  id: 'cm1a2b3c4d5e6f7g8h9i0j1k',
  name: 'Test Brand',
  userId: 'cm1a2b3c4d5e6f7g8h9i0j1k',
  tagline: 'Innovation at its best',
  voiceDescription: 'Professional, friendly, and approachable',
  communicationStyle: 'Clear and concise',
  toneAttributes: { professional: true, friendly: true },
  targetAudience: { segment: 'young professionals', age: '25-35' },
  values: ['innovation', 'quality', 'customer-first'],
  messagingFramework: [
    { pillar: 'innovation', description: 'Leading edge technology', keywords: ['innovative', 'cutting-edge'] },
    { pillar: 'quality', description: 'Premium standards', keywords: ['quality', 'premium'] }
  ],
  restrictedTerms: ['cheap', 'low-cost'],
  deletedAt: null
}

const mockContentGenerationRequest = {
  brandId: 'cm1a2b3c4d5e6f7g8h9i0j1k',
  contentType: 'EMAIL' as const,
  prompt: 'Create an email about our new product launch',
  targetAudience: 'Young professionals',
  tone: 'professional' as const,
  channel: 'email',
  callToAction: 'Learn more',
  includeVariants: false,
  variantCount: 1,
  maxLength: 1000,
  keywords: ['innovative', 'quality'],
  brandCompliance: {
    enforceBrandVoice: true,
    checkRestrictedTerms: true,
    validateMessaging: true
  }
}

const mockGeneratedContent = {
  text: 'Dear valued customer, we are excited to announce our innovative new product that brings quality and cutting-edge technology to your daily life. Learn more about how this premium solution can benefit you.'
}

// Helper function to create mock NextRequest
function createMockRequest(body: any, method: string = 'POST'): NextRequest {
  const url = 'http://localhost:3000/api/ai/content-generation'
  const init: RequestInit = {
    method,
    headers: {
      'Content-Type': 'application/json',
    },
  }

  if (method === 'POST' && body) {
    init.body = JSON.stringify(body)
  }

  return new NextRequest(url, init)
}

describe('/api/ai/content-generation', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    
    // Set environment variable to prevent OpenAI service from failing
    process.env.OPENAI_API_KEY = 'test-key'
    
    // Default mock implementations
    mockGetServerSession.mockResolvedValue({
      user: mockUser,
      expires: '2024-12-31'
    })

    mockBrandFindFirst.mockResolvedValue(mockBrand)
    
    mockIsReady.mockReturnValue(true)
    mockGenerateText.mockResolvedValue(mockGeneratedContent)
    mockStreamText.mockResolvedValue(mockStreamResult)
    mockGetConfig.mockReturnValue({
      model: 'gpt-4o',
      maxTokens: 2048,
      temperature: 0.7,
      hasApiKey: true
    })

    // Force override methods directly since Jest mocks aren't applying correctly
    prisma.brand.findFirst = mockBrandFindFirst
    
    // Override the openAI service instance methods after ensuring it can be created
    const instance = openAIService.instance
    instance.isReady = mockIsReady
    instance.generateText = mockGenerateText
    instance.streamText = mockStreamText
    instance.getConfig = mockGetConfig
  })

  afterEach(() => {
    jest.clearAllMocks()
    // Clean up environment variable
    delete process.env.OPENAI_API_KEY
  })

  describe('POST /api/ai/content-generation', () => {
    it('should generate content successfully with valid request', async () => {
      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.content).toBeDefined()
      expect(data.brandCompliance).toBeDefined()
      expect(data.metadata).toBeDefined()
      expect(data.metadata.brandId).toBe('cm1a2b3c4d5e6f7g8h9i0j1k')
      expect(data.metadata.contentType).toBe('EMAIL')
    })

    it('should reject request without authentication', async () => {
      mockGetServerSession.mockResolvedValue(null)
      
      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(401)
      expect(data.error).toBe('Authentication required')
    })

    it('should validate request body and reject invalid data', async () => {
      const invalidRequest = {
        ...mockContentGenerationRequest,
        brandId: 'invalid-id', // Not a valid CUID
        prompt: 'short', // Too short
        contentType: 'INVALID_TYPE'
      }

      const request = createMockRequest(invalidRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data.error).toBe('Validation error')
      expect(data.details).toBeDefined()
      expect(Array.isArray(data.details)).toBe(true)
    })

    it('should reject request for non-existent brand', async () => {
      mockBrandFindFirst.mockResolvedValue(null)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(404)
      expect(data.error).toBe('Brand not found or access denied')
    })

    it('should reject request when AI service is not ready', async () => {
      mockIsReady.mockReturnValue(false)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.error).toBe('AI service not available. Please check configuration.')
    })

    it('should handle OpenAI service errors gracefully', async () => {
      const serviceError = new Error('OpenAI API Error')
      serviceError.name = 'OpenAIServiceError'
      
      mockGenerateText.mockRejectedValue(serviceError)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(502)
      expect(data.error).toBe('AI service error')
      expect(data.message).toBe('OpenAI API Error')
    }, 10000)

    it('should detect brand compliance violations', async () => {
      // Mock content that contains restricted terms
      const nonCompliantContent = {
        text: 'Check out our cheap and low-cost solution that saves you money!'
      }
      
      mockGenerateText.mockResolvedValue(nonCompliantContent)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.brandCompliance.isCompliant).toBe(false)
      expect(data.brandCompliance.violations.length).toBeGreaterThan(0)
      expect(data.brandCompliance.violations[0]).toContain('restricted term')
    })

    it('should generate content variants when requested', async () => {
      const requestWithVariants = {
        ...mockContentGenerationRequest,
        includeVariants: true,
        variantCount: 3
      }

      // Mock multiple AI service calls for variants
      mockGenerateText
        .mockResolvedValueOnce(mockGeneratedContent) // Main content
        .mockResolvedValueOnce({ text: 'Variant 1 content' }) // Variant 1
        .mockResolvedValueOnce({ text: 'Variant 2 content' }) // Variant 2

      const request = createMockRequest(requestWithVariants)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.variants).toBeDefined()
      expect(Array.isArray(data.variants)).toBe(true)
      expect(data.variants?.length).toBe(2) // variantCount - 1
    })

    it('should respect max length constraints', async () => {
      const requestWithMaxLength = {
        ...mockContentGenerationRequest,
        maxLength: 100
      }

      const request = createMockRequest(requestWithMaxLength)
      const response = await POST(request)

      expect(response.status).toBe(200)
      
      // Verify that the AI service was called with appropriate maxTokens
      expect(mockGenerateText).toHaveBeenCalledWith(
        expect.objectContaining({
          maxTokens: expect.any(Number)
        })
      )
    })

    it('should include keywords in generated content context', async () => {
      const requestWithKeywords = {
        ...mockContentGenerationRequest,
        keywords: ['innovation', 'technology', 'future']
      }

      const request = createMockRequest(requestWithKeywords)
      const response = await POST(request)

      expect(response.status).toBe(200)
      
      // Verify that keywords were included in the prompt
      const generateTextCall = (mockGenerateText as jest.Mock).mock.calls[0][0]
      expect(generateTextCall.prompt).toContain('innovation, technology, future')
    })

    it('should handle missing optional fields gracefully', async () => {
      const minimalRequest = {
        brandId: 'cm1a2b3c4d5e6f7g8h9i0j1k',
        contentType: 'EMAIL' as const,
        prompt: 'Create a simple email message'
      }

      const request = createMockRequest(minimalRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.content).toBeDefined()
    })

    it('should calculate content metrics correctly', async () => {
      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.metadata.wordCount).toBeGreaterThan(0)
      expect(data.metadata.charCount).toBeGreaterThan(0)
      expect(data.metadata.generatedAt).toBeDefined()
      expect(new Date(data.metadata.generatedAt)).toBeInstanceOf(Date)
    })

    it('should include processing time and model info in metadata', async () => {
      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.metadata.processingTime).toBeDefined()
      expect(typeof data.metadata.processingTime).toBe('number')
      expect(data.metadata.model).toBeDefined()
      expect(data.metadata.tokensUsed).toBeDefined()
    })

    it('should include enhanced compliance scoring', async () => {
      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.brandCompliance.score).toBeDefined()
      expect(typeof data.brandCompliance.score).toBe('number')
      expect(data.brandCompliance.score).toBeGreaterThanOrEqual(0)
      expect(data.brandCompliance.score).toBeLessThanOrEqual(100)
    })

    it('should support streaming requests', async () => {
      const streamingRequest = {
        ...mockContentGenerationRequest,
        streaming: true
      }

      const request = createMockRequest(streamingRequest)
      const response = await POST(request)

      expect(response.status).toBe(200)
      expect(response.headers.get('content-type')).toContain('text/plain')
      expect(response.headers.get('transfer-encoding')).toBe('chunked')
    })

    it('should include content analysis when requested', async () => {
      const analysisRequest = {
        ...mockContentGenerationRequest,
        includeAnalysis: true
      }

      // Mock additional AI calls for analysis
      mockGenerateText
        .mockResolvedValueOnce(mockGeneratedContent) // Main content
        .mockResolvedValueOnce({ text: 'SENTIMENT: positive\nBRAND_ALIGNMENT: 85\nTONE_ASSESSMENT: Professional and engaging' }) // Analysis

      const request = createMockRequest(analysisRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.analysis).toBeDefined()
      expect(data.analysis.sentiment).toBeDefined()
      expect(data.analysis.readabilityScore).toBeDefined()
      expect(data.analysis.brandAlignment).toBeDefined()
      expect(data.analysis.keywordDensity).toBeDefined()
      expect(data.analysis.suggestions).toBeDefined()
    })

    it('should handle brand voice analysis errors gracefully', async () => {
      // Mock AI service to fail on voice analysis but succeed on content generation
      mockGenerateText
        .mockResolvedValueOnce(mockGeneratedContent) // Main content generation
        .mockRejectedValueOnce(new Error('Voice analysis failed')) // Voice analysis failure

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      // Should continue without voice analysis
    })
  })

  describe('GET /api/ai/content-generation', () => {
    it('should return service health status', async () => {
      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.status).toBe('healthy')
      expect(data.aiService).toBeDefined()
      expect(data.aiService.ready).toBe(true)
      expect(data.supportedContentTypes).toBeDefined()
      expect(Array.isArray(data.supportedContentTypes)).toBe(true)
    })

    it('should return unhealthy status when AI service is not ready', async () => {
      mockIsReady.mockReturnValue(false)

      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.aiService.ready).toBe(false)
    })

    it('should handle health check errors', async () => {
      mockIsReady.mockImplementation(() => {
        throw new Error('Service check failed')
      })

      const response = await GET()
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.status).toBe('unhealthy')
      expect(data.error).toBe('Service check failed')
    })
  })

  describe('Brand Compliance Validation', () => {
    it('should detect restricted terms case-insensitively', async () => {
      const contentWithRestrictedTerms = {
        text: 'Our CHEAP solution offers Low-Cost benefits!'
      }
      
      mockGenerateText.mockResolvedValue(contentWithRestrictedTerms)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(data.brandCompliance.isCompliant).toBe(false)
      expect(data.brandCompliance.violations.some((v: string) => v.includes('cheap'))).toBe(true)
      expect(data.brandCompliance.violations.some((v: string) => v.includes('low-cost'))).toBe(true)
    })

    it('should validate messaging framework alignment', async () => {
      // Content that doesn't align with brand messaging
      const contentWithoutMessaging = {
        text: 'Just another ordinary product with basic features.'
      }
      
      mockGenerateText.mockResolvedValue(contentWithoutMessaging)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(data.brandCompliance.violations.some((v: string) => 
        v.includes('messaging framework')
      )).toBe(true)
    })

    it('should provide compliance suggestions', async () => {
      const nonCompliantContent = {
        text: 'Buy our cheap product now!'
      }
      
      mockGenerateText.mockResolvedValue(nonCompliantContent)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(data.brandCompliance.suggestions).toBeDefined()
      expect(Array.isArray(data.brandCompliance.suggestions)).toBe(true)
      expect(data.brandCompliance.suggestions?.length).toBeGreaterThan(0)
    })
  })

  describe('Error Handling', () => {
    it('should handle malformed JSON in request body', async () => {
      const request = new NextRequest('http://localhost:3000/api/ai/content-generation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: 'invalid json{'
      })

      const response = await POST(request)
      
      expect(response.status).toBe(500)
    })

    it('should handle database connection errors with specific error code', async () => {
      mockBrandFindFirst.mockRejectedValue(new Error('PrismaClient connection failed'))

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.error).toBe('Database error')
      expect(data.code).toBe('DATABASE_ERROR')
    })

    it('should handle rate limit errors with retry headers', async () => {
      const rateLimitError = new Error('Rate limit exceeded')
      rateLimitError.name = 'OpenAIServiceError'
      ;(rateLimitError as any).code = 'RATE_LIMIT'
      ;(rateLimitError as any).statusCode = 429
      
      mockGenerateText.mockRejectedValue(rateLimitError)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(429)
      expect(data.code).toBe('RATE_LIMIT_ERROR')
      expect(data.retryAfter).toBe(60)
      expect(response.headers.get('Retry-After')).toBe('60')
    }, 10000)

    it('should handle timeout errors specifically', async () => {
      mockGenerateText.mockRejectedValue(new Error('Request timeout occurred'))

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(408)
      expect(data.code).toBe('TIMEOUT_ERROR')
      expect(data.error).toBe('Request timeout')
    }, 10000)

    it('should handle API key errors as service unavailable', async () => {
      const authError = new Error('Invalid API key')
      authError.name = 'OpenAIServiceError'
      ;(authError as any).code = 'INVALID_API_KEY'
      ;(authError as any).statusCode = 401
      
      mockGenerateText.mockRejectedValue(authError)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.code).toBe('SERVICE_UNAVAILABLE')
    })

    it('should handle model not found errors', async () => {
      const modelError = new Error('Model not found')
      modelError.name = 'OpenAIServiceError'
      ;(modelError as any).statusCode = 404
      
      mockGenerateText.mockRejectedValue(modelError)

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(503)
      expect(data.code).toBe('MODEL_UNAVAILABLE')
    })

    it('should provide request ID for generic errors', async () => {
      mockGenerateText.mockRejectedValue(new Error('Unexpected error'))

      const request = createMockRequest(mockContentGenerationRequest)
      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data.code).toBe('INTERNAL_ERROR')
      expect(data.requestId).toBeDefined()
      expect(data.requestId).toMatch(/^req_\d+_[a-z0-9]+$/)
    }, 10000)
  })
})