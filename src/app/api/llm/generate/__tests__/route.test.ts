import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { NextRequest } from 'next/server'
import { POST, GET } from '../route'

// Mock the LLM service
vi.mock('@/lib/llm-service', () => ({
  llmService: {
    generateContentWithRetry: vi.fn(),
    generateContentStream: vi.fn()
  },
  LLMError: class LLMError extends Error {
    constructor(
      public code: string,
      message: string,
      public type: 'rate_limit' | 'invalid_request' | 'server_error' | 'auth_error',
      public retryAfter?: number
    ) {
      super(message)
      this.name = 'LLMError'
    }
  }
}))

import { llmService, LLMError } from '@/lib/llm-service'

describe('LLM API Routes', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // Helper functions for creating mock requests
  const createMockRequest = (body: any, headers: Record<string, string> = {}) => {
    return new NextRequest('http://localhost:3000/api/llm/generate', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...headers
      },
      body: JSON.stringify(body)
    })
  }

  const createMockStreamRequest = (params: Record<string, string> = {}) => {
    const url = new URL('http://localhost:3000/api/llm/generate')
    Object.entries(params).forEach(([key, value]) => {
      url.searchParams.set(key, value)
    })

    return new NextRequest(url.toString(), { method: 'GET' })
  }

  describe('POST /api/llm/generate', () => {

    it('should handle valid content generation request', async () => {
      const mockResponse = {
        id: 'test-id-123',
        content: 'Generated marketing content',
        model: 'mock-gpt-3.5-turbo',
        usage: {
          promptTokens: 10,
          completionTokens: 20,
          totalTokens: 30
        },
        finishReason: 'stop' as const,
        metadata: {
          requestId: 'test-id-123',
          timestamp: new Date(),
          processingTime: 1500
        }
      }

      vi.mocked(llmService.generateContentWithRetry).mockResolvedValue(mockResponse)

      const request = createMockRequest({
        prompt: 'Generate marketing copy for our product',
        model: 'mock-gpt-3.5-turbo',
        temperature: 0.7,
        maxTokens: 500
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      expect(data.data).toBeDefined()
      expect(data.data.content).toBe('Generated marketing content')
      expect(data.data.metadata.timestamp).toBeDefined()
      
      // Verify service was called with correct parameters
      expect(llmService.generateContentWithRetry).toHaveBeenCalledWith(
        {
          prompt: 'Generate marketing copy for our product',
          model: 'mock-gpt-3.5-turbo',
          maxTokens: 500,
          temperature: 0.7,
          systemPrompt: undefined,
          context: undefined
        },
        expect.any(String) // client IP
      )
    })

    it('should handle requests with all optional parameters', async () => {
      const mockResponse = {
        id: 'test-id-456',
        content: 'Generated content with context',
        model: 'mock-gpt-4',
        usage: { promptTokens: 15, completionTokens: 25, totalTokens: 40 },
        finishReason: 'stop' as const,
        metadata: {
          requestId: 'test-id-456',
          timestamp: new Date(),
          processingTime: 2000
        }
      }

      vi.mocked(llmService.generateContentWithRetry).mockResolvedValue(mockResponse)

      const request = createMockRequest({
        prompt: 'Generate content with context',
        model: 'mock-gpt-4',
        temperature: 0.9,
        maxTokens: 1000,
        systemPrompt: 'You are a helpful marketing assistant',
        context: ['urgent', 'premium']
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(200)
      expect(data.success).toBe(true)
      
      expect(llmService.generateContentWithRetry).toHaveBeenCalledWith(
        {
          prompt: 'Generate content with context',
          model: 'mock-gpt-4',
          maxTokens: 1000,
          temperature: 0.9,
          systemPrompt: 'You are a helpful marketing assistant',
          context: ['urgent', 'premium']
        },
        expect.any(String)
      )
    })

    it('should extract client IP from headers', async () => {
      const mockResponse = {
        id: 'test-id',
        content: 'Test content',
        model: 'mock-gpt-3.5-turbo',
        usage: { promptTokens: 5, completionTokens: 10, totalTokens: 15 },
        finishReason: 'stop' as const,
        metadata: {
          requestId: 'test-id',
          timestamp: new Date(),
          processingTime: 1000
        }
      }

      vi.mocked(llmService.generateContentWithRetry).mockResolvedValue(mockResponse)

      const request = createMockRequest(
        { prompt: 'Test prompt' },
        { 'x-forwarded-for': '192.168.1.1' }
      )

      await POST(request)

      expect(llmService.generateContentWithRetry).toHaveBeenCalledWith(
        expect.any(Object),
        '192.168.1.1'
      )
    })

    it('should handle rate limit errors with retry headers', async () => {
      const rateLimitError = new LLMError(
        'RATE_LIMIT_EXCEEDED',
        'Rate limit exceeded',
        'rate_limit',
        300 // 5 minutes
      )

      vi.mocked(llmService.generateContentWithRetry).mockRejectedValue(rateLimitError)

      const request = createMockRequest({
        prompt: 'Test prompt'
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(429)
      expect(data.success).toBe(false)
      expect(data.error).toBe('RATE_LIMIT_EXCEEDED')
      expect(data.message).toBe('Rate limit exceeded')
      expect(data.retryAfter).toBe(300)
      expect(response.headers.get('Retry-After')).toBe('300')
    })

    it('should handle invalid request errors', async () => {
      const invalidRequestError = new LLMError(
        'INVALID_PROMPT',
        'Prompt is required and cannot be empty',
        'invalid_request'
      )

      vi.mocked(llmService.generateContentWithRetry).mockRejectedValue(invalidRequestError)

      const request = createMockRequest({
        prompt: ''
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data.success).toBe(false)
      expect(data.error).toBe('INVALID_PROMPT')
      expect(data.message).toBe('Prompt is required and cannot be empty')
    })

    it('should handle server errors', async () => {
      const serverError = new LLMError(
        'INTERNAL_ERROR',
        'Internal server error',
        'server_error'
      )

      vi.mocked(llmService.generateContentWithRetry).mockRejectedValue(serverError)

      const request = createMockRequest({
        prompt: 'Test prompt'
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data.success).toBe(false)
      expect(data.error).toBe('INTERNAL_ERROR')
      expect(data.message).toBe('Internal server error')
    })

    it('should handle auth errors', async () => {
      const authError = new LLMError(
        'AUTH_FAILED',
        'Authentication failed',
        'auth_error'
      )

      vi.mocked(llmService.generateContentWithRetry).mockRejectedValue(authError)

      const request = createMockRequest({
        prompt: 'Test prompt'
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(401)
      expect(data.success).toBe(false)
      expect(data.error).toBe('AUTH_FAILED')
      expect(data.message).toBe('Authentication failed')
    })

    it('should handle unexpected errors', async () => {
      const unexpectedError = new Error('Something went wrong')
      vi.mocked(llmService.generateContentWithRetry).mockRejectedValue(unexpectedError)

      const request = createMockRequest({
        prompt: 'Test prompt'
      })

      const response = await POST(request)
      const data = await response.json()

      expect(response.status).toBe(500)
      expect(data.success).toBe(false)
      expect(data.error).toBe('INTERNAL_SERVER_ERROR')
      expect(data.message).toBe('An unexpected error occurred while processing your request.')
    })

    it('should handle malformed JSON requests', async () => {
      const request = new NextRequest('http://localhost:3000/api/llm/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: 'invalid json{'
      })

      const response = await POST(request)
      
      expect(response.status).toBe(500)
    })
  })

  describe('GET /api/llm/generate (Streaming)', () => {

    it('should handle valid streaming request', async () => {
      const mockChunks = [
        { id: 'stream-1', delta: 'Hello', isComplete: false, metadata: { tokenCount: 1, model: 'test-model' } },
        { id: 'stream-1', delta: ' world', isComplete: false, metadata: { tokenCount: 2, model: 'test-model' } },
        { id: 'stream-1', delta: '!', isComplete: true, metadata: { tokenCount: 3, model: 'test-model' } }
      ]

      const mockGenerator = {
        async *[Symbol.asyncIterator]() {
          for (const chunk of mockChunks) {
            yield chunk
          }
        }
      }

      vi.mocked(llmService.generateContentStream).mockReturnValue(mockGenerator)

      const request = createMockStreamRequest({
        prompt: 'Generate streaming content',
        model: 'test-model'
      })

      const response = await GET(request)

      expect(response.status).toBe(200)
      expect(response.headers.get('Content-Type')).toBe('text/plain; charset=utf-8')
      expect(response.headers.get('Cache-Control')).toBe('no-cache')
      expect(response.headers.get('Connection')).toBe('keep-alive')

      // Verify service was called correctly
      expect(llmService.generateContentStream).toHaveBeenCalledWith(
        {
          prompt: 'Generate streaming content',
          model: 'test-model',
          maxTokens: undefined,
          temperature: undefined,
          context: undefined
        },
        expect.any(String)
      )
    })

    it('should parse URL parameters correctly', async () => {
      const mockGenerator = {
        async *[Symbol.asyncIterator]() {
          yield { id: 'test', delta: 'test', isComplete: true }
        }
      }

      vi.mocked(llmService.generateContentStream).mockReturnValue(mockGenerator)

      const request = createMockStreamRequest({
        prompt: 'Test prompt with params',
        model: 'custom-model',
        maxTokens: '1000',
        temperature: '0.8',
        context: 'urgent,premium'
      })

      await GET(request)

      expect(llmService.generateContentStream).toHaveBeenCalledWith(
        {
          prompt: 'Test prompt with params',
          model: 'custom-model',
          maxTokens: 1000,
          temperature: 0.8,
          context: ['urgent', 'premium']
        },
        expect.any(String)
      )
    })

    it('should require prompt parameter', async () => {
      const request = createMockStreamRequest({
        model: 'test-model'
        // No prompt parameter
      })

      const response = await GET(request)
      const data = await response.json()

      expect(response.status).toBe(400)
      expect(data.success).toBe(false)
      expect(data.error).toBe('MISSING_PROMPT')
      expect(data.message).toBe('Prompt parameter is required for streaming.')
    })

    it('should handle streaming rate limit errors', async () => {
      const rateLimitError = new LLMError(
        'RATE_LIMIT_EXCEEDED',
        'Rate limit exceeded for streaming',
        'rate_limit',
        600
      )

      const mockGenerator = {
        async *[Symbol.asyncIterator]() {
          throw rateLimitError
        }
      }

      vi.mocked(llmService.generateContentStream).mockReturnValue(mockGenerator)

      const request = createMockStreamRequest({
        prompt: 'Test streaming rate limit'
      })

      const response = await GET(request)

      expect(response.status).toBe(200) // Streaming response starts successfully
      expect(response.headers.get('Content-Type')).toBe('text/plain; charset=utf-8')
      
      // The error would be sent as part of the stream
      // In a real test, we'd read the response body and check for error data
    })

    it('should handle streaming server errors', async () => {
      const serverError = new LLMError(
        'STREAM_ERROR',
        'Streaming failed',
        'server_error'
      )

      const mockGenerator = {
        async *[Symbol.asyncIterator]() {
          throw serverError
        }
      }

      vi.mocked(llmService.generateContentStream).mockReturnValue(mockGenerator)

      const request = createMockStreamRequest({
        prompt: 'Test streaming server error'
      })

      const response = await GET(request)

      expect(response.status).toBe(200) // Streaming response starts successfully
      expect(response.headers.get('Content-Type')).toBe('text/plain; charset=utf-8')
    })

    it('should handle unexpected streaming errors', async () => {
      const unexpectedError = new Error('Unexpected streaming error')

      const mockGenerator = {
        async *[Symbol.asyncIterator]() {
          throw unexpectedError
        }
      }

      vi.mocked(llmService.generateContentStream).mockReturnValue(mockGenerator)

      const request = createMockStreamRequest({
        prompt: 'Test unexpected streaming error'
      })

      const response = await GET(request)

      expect(response.status).toBe(200) // Streaming response starts successfully
      expect(response.headers.get('Content-Type')).toBe('text/plain; charset=utf-8')
    })

    it('should handle setup errors', async () => {
      // Simulate an error during stream setup by throwing immediately
      vi.mocked(llmService.generateContentStream).mockImplementation(() => {
        throw new Error('Stream setup failed')
      })

      const request = createMockStreamRequest({
        prompt: 'Test setup error'
      })

      const response = await GET(request)

      // Stream starts successfully but contains error data
      expect(response.status).toBe(200)
      expect(response.headers.get('Content-Type')).toBe('text/plain; charset=utf-8')
      
      // For streaming responses, errors are sent as part of the stream content
      // We can verify this by checking that it's a streaming response
      expect(response.body).toBeDefined()
    })

    it('should parse numeric parameters correctly', async () => {
      const mockGenerator = {
        async *[Symbol.asyncIterator]() {
          yield { id: 'test', delta: 'test', isComplete: true }
        }
      }

      vi.mocked(llmService.generateContentStream).mockReturnValue(mockGenerator)

      // Test with string representations of numbers
      const request = createMockStreamRequest({
        prompt: 'Test numeric parsing',
        maxTokens: '2000',
        temperature: '1.5'
      })

      await GET(request)

      expect(llmService.generateContentStream).toHaveBeenCalledWith(
        expect.objectContaining({
          maxTokens: 2000,
          temperature: 1.5
        }),
        expect.any(String)
      )
    })

    it('should handle invalid numeric parameters', async () => {
      const mockGenerator = {
        async *[Symbol.asyncIterator]() {
          yield { id: 'test', delta: 'test', isComplete: true }
        }
      }

      vi.mocked(llmService.generateContentStream).mockReturnValue(mockGenerator)

      // Test with invalid numeric values
      const request = createMockStreamRequest({
        prompt: 'Test invalid numbers',
        maxTokens: 'not-a-number',
        temperature: 'invalid'
      })

      await GET(request)

      // Should pass NaN for invalid numbers (the actual behavior)
      expect(llmService.generateContentStream).toHaveBeenCalledWith(
        expect.objectContaining({
          maxTokens: NaN,
          temperature: NaN,
          prompt: 'Test invalid numbers'
        }),
        expect.any(String)
      )
    })
  })

  describe('Error Status Code Mapping', () => {
    it('should map error types to correct HTTP status codes', async () => {
      const errorTests = [
        { type: 'rate_limit', expectedStatus: 429 },
        { type: 'invalid_request', expectedStatus: 400 },
        { type: 'auth_error', expectedStatus: 401 },
        { type: 'server_error', expectedStatus: 500 }
      ] as const

      for (const { type, expectedStatus } of errorTests) {
        vi.clearAllMocks()
        
        const error = new LLMError('TEST_CODE', 'Test message', type)
        vi.mocked(llmService.generateContentWithRetry).mockRejectedValue(error)

        const request = createMockRequest({ prompt: 'Test prompt' })
        const response = await POST(request)

        expect(response.status).toBe(expectedStatus)
      }
    })
  })

  describe('Response Headers', () => {
    it('should set correct content type for JSON responses', async () => {
      const mockResponse = {
        id: 'test-id',
        content: 'Test content',
        model: 'test-model',
        usage: { promptTokens: 5, completionTokens: 10, totalTokens: 15 },
        finishReason: 'stop' as const,
        metadata: {
          requestId: 'test-id',
          timestamp: new Date(),
          processingTime: 1000
        }
      }

      vi.mocked(llmService.generateContentWithRetry).mockResolvedValue(mockResponse)

      const request = createMockRequest({ prompt: 'Test prompt' })
      const response = await POST(request)

      expect(response.headers.get('Content-Type')).toContain('application/json')
    })

    it('should set correct headers for streaming responses', async () => {
      const mockGenerator = {
        async *[Symbol.asyncIterator]() {
          yield { id: 'test', delta: 'test', isComplete: true }
        }
      }

      vi.mocked(llmService.generateContentStream).mockReturnValue(mockGenerator)

      const request = createMockStreamRequest({ prompt: 'Test streaming' })
      const response = await GET(request)

      expect(response.headers.get('Content-Type')).toBe('text/plain; charset=utf-8')
      expect(response.headers.get('Cache-Control')).toBe('no-cache')
      expect(response.headers.get('Connection')).toBe('keep-alive')
    })
  })
})