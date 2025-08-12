import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { LLMClient, llmClient } from '../llm-client'
import type { LLMApiRequest, LLMApiResponse } from '@/types/api'

// Mock fetch globally
const mockFetch = vi.fn()
global.fetch = mockFetch

describe('LLM Client', () => {
  const mockSuccessResponse: LLMApiResponse = {
    id: 'test-id-123',
    content: 'Generated test content',
    model: 'mock-gpt-3.5-turbo',
    usage: {
      promptTokens: 10,
      completionTokens: 20,
      totalTokens: 30
    },
    finishReason: 'stop',
    metadata: {
      requestId: 'test-id-123',
      timestamp: '2024-01-01T00:00:00.000Z',
      processingTime: 1500
    }
  }

  beforeEach(() => {
    vi.clearAllMocks()
    mockFetch.mockClear()
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  describe('Singleton Pattern', () => {
    it('should return the same instance', () => {
      const instance1 = LLMClient.getInstance()
      const instance2 = LLMClient.getInstance()
      expect(instance1).toBe(instance2)
    })

    it('should match exported singleton', () => {
      const instance = LLMClient.getInstance()
      expect(instance).toBe(llmClient)
    })
  })

  describe('generateContent', () => {
    it('should successfully generate content', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: true,
          data: mockSuccessResponse
        })
      })

      const client = LLMClient.getInstance()
      const request: LLMApiRequest = {
        prompt: 'Generate test content',
        model: 'mock-gpt-3.5-turbo'
      }

      const result = await client.generateContent(request)

      expect(result).toEqual(mockSuccessResponse)
      expect(mockFetch).toHaveBeenCalledWith('/api/llm/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(request)
      })
    })

    it('should handle API errors', async () => {
      const errorResponse = {
        error: 'INVALID_PROMPT',
        message: 'Prompt is required',
        type: 'invalid_request'
      }

      mockFetch.mockResolvedValueOnce({
        ok: false,
        json: async () => errorResponse
      })

      const client = LLMClient.getInstance()

      await expect(client.generateContent({
        prompt: '',
        model: 'test-model'
      })).rejects.toThrow('Prompt is required')
    })

    it('should handle network errors', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'))

      const client = LLMClient.getInstance()

      await expect(client.generateContent({
        prompt: 'Test prompt',
        model: 'test-model'
      })).rejects.toThrow('Network error')
    })

    it('should handle invalid server responses', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: false,
          // Missing data field
        })
      })

      const client = LLMClient.getInstance()

      await expect(client.generateContent({
        prompt: 'Test prompt',
        model: 'test-model'
      })).rejects.toThrow('Invalid response from LLM API')
    })
  })

  describe('Convenience Methods', () => {
    beforeEach(() => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({
          success: true,
          data: mockSuccessResponse
        })
      })
    })

    it('should generate marketing copy with correct parameters', async () => {
      const client = LLMClient.getInstance()
      
      const result = await client.generateMarketingCopy('Test product', {
        temperature: 0.8,
        context: ['urgent']
      })

      expect(result).toBe(mockSuccessResponse.content)
      expect(mockFetch).toHaveBeenCalledWith('/api/llm/generate', expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          prompt: 'Generate marketing copy: Test product',
          temperature: 0.8,
          context: ['urgent'],
          maxTokens: 500
        })
      }))
    })

    it('should generate subject lines with urgent flag', async () => {
      const client = LLMClient.getInstance()
      
      const result = await client.generateSubjectLine('New product launch', true)

      expect(result).toBe(mockSuccessResponse.content)
      expect(mockFetch).toHaveBeenCalledWith('/api/llm/generate', expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          prompt: 'Generate an email subject line for: New product launch. Make it urgent and action-oriented.',
          temperature: 0.8,
          maxTokens: 50
        })
      }))
    })

    it('should generate headlines with different styles', async () => {
      const client = LLMClient.getInstance()
      
      // Test creative style
      await client.generateHeadline('Product launch', 'creative')
      expect(mockFetch).toHaveBeenLastCalledWith('/api/llm/generate', expect.objectContaining({
        body: JSON.stringify({
          prompt: 'Generate a headline for: Product launch. Make it creative and attention-grabbing.',
          temperature: 0.9,
          maxTokens: 100
        })
      }))

      // Test professional style
      await client.generateHeadline('Product launch', 'professional')
      expect(mockFetch).toHaveBeenLastCalledWith('/api/llm/generate', expect.objectContaining({
        body: JSON.stringify({
          prompt: 'Generate a headline for: Product launch. Keep it professional and clear.',
          temperature: 0.6,
          maxTokens: 100
        })
      }))
    })

    it('should generate descriptions with different lengths', async () => {
      const client = LLMClient.getInstance()
      
      const lengths: Array<'short' | 'medium' | 'long'> = ['short', 'medium', 'long']
      const expectedTokens = { short: 100, medium: 200, long: 400 }

      for (const length of lengths) {
        await client.generateDescription('Test product', length)
        expect(mockFetch).toHaveBeenLastCalledWith('/api/llm/generate', expect.objectContaining({
          body: JSON.stringify({
            prompt: `Generate a ${length} description for: Test product`,
            temperature: 0.7,
            maxTokens: expectedTokens[length]
          })
        }))
      }
    })
  })

  describe('Batch Operations', () => {
    it('should generate multiple variations', async () => {
      const mockResponses = [
        { ...mockSuccessResponse, content: 'Variation 1' },
        { ...mockSuccessResponse, content: 'Variation 2' },
        { ...mockSuccessResponse, content: 'Variation 3' }
      ]

      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ success: true, data: mockResponses[0] })
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ success: true, data: mockResponses[1] })
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ success: true, data: mockResponses[2] })
        })

      const client = LLMClient.getInstance()
      
      const results = await client.generateMultipleVariations('Test prompt', 3, 'copy')

      expect(results).toEqual(['Variation 1', 'Variation 2', 'Variation 3'])
      expect(mockFetch).toHaveBeenCalledTimes(3)

      // Check that temperature increases for variety
      const calls = mockFetch.mock.calls
      const parsedBodies = calls.map(call => JSON.parse(call[1].body))
      
      expect(parsedBodies[0].temperature).toBe(0.8)
      expect(parsedBodies[1].temperature).toBe(0.9)
      expect(parsedBodies[2].temperature).toBe(1.0)
    })

    it('should handle different content types in batch generation', async () => {
      const mockResponse = { ...mockSuccessResponse, content: 'Test content' }
      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({ success: true, data: mockResponse })
      })

      const client = LLMClient.getInstance()
      
      // Test different content types
      await client.generateMultipleVariations('Test', 2, 'headline')
      expect(mockFetch).toHaveBeenLastCalledWith('/api/llm/generate', expect.objectContaining({
        body: expect.stringContaining('Generate variation 2 of headline for: Test')
      }))

      await client.generateMultipleVariations('Test', 2, 'subject_line')
      expect(mockFetch).toHaveBeenLastCalledWith('/api/llm/generate', expect.objectContaining({
        body: expect.stringContaining('Generate variation 2 of subject line for: Test')
      }))
    })
  })

  describe('Error Handling Utilities', () => {
    it('should identify retryable errors', () => {
      const client = LLMClient.getInstance()
      
      const rateLimitError = new Error('Rate limit') as any
      rateLimitError.type = 'rate_limit'
      
      const serverError = new Error('Server error') as any
      serverError.type = 'server_error'
      
      const authError = new Error('Auth error') as any
      authError.type = 'auth_error'

      expect(client.isRetryableError(rateLimitError)).toBe(true)
      expect(client.isRetryableError(serverError)).toBe(true)
      expect(client.isRetryableError(authError)).toBe(false)
    })

    it('should calculate correct retry delays', () => {
      const client = LLMClient.getInstance()
      
      const rateLimitError = new Error('Rate limit') as any
      rateLimitError.type = 'rate_limit'
      rateLimitError.retryAfter = 300

      const serverError = new Error('Server error') as any
      serverError.type = 'server_error'

      expect(client.getRetryDelay(rateLimitError)).toBe(300000) // 5 minutes in ms
      expect(client.getRetryDelay(serverError)).toBe(5000) // 5 seconds
    })
  })

  describe('withRetry', () => {
    it('should retry failed operations', async () => {
      const client = LLMClient.getInstance()
      let callCount = 0

      const operation = vi.fn().mockImplementation(async () => {
        callCount++
        if (callCount < 3) {
          const error = new Error('Temporary failure') as any
          error.type = 'server_error'
          throw error
        }
        return 'success'
      })

      const result = await client.withRetry(operation, 3, 100)

      expect(result).toBe('success')
      expect(operation).toHaveBeenCalledTimes(3)
    }, 15000)

    it('should give up after max retries', async () => {
      const client = LLMClient.getInstance()
      
      const operation = vi.fn().mockImplementation(async () => {
        const error = new Error('Persistent failure') as any
        error.type = 'server_error'
        throw error
      })

      await expect(client.withRetry(operation, 2, 100)).rejects.toThrow('Persistent failure')
      expect(operation).toHaveBeenCalledTimes(2)
    }, 10000)

    it('should not retry non-retryable errors', async () => {
      const client = LLMClient.getInstance()
      
      const operation = vi.fn().mockImplementation(async () => {
        const error = new Error('Auth failure') as any
        error.type = 'auth_error'
        throw error
      })

      await expect(client.withRetry(operation, 3, 100)).rejects.toThrow('Auth failure')
      expect(operation).toHaveBeenCalledTimes(1)
    })
  })

  describe('Streaming (Basic Structure)', () => {
    it('should build correct streaming URL', async () => {
      // Mock the streaming response
      const mockStream = {
        ok: true,
        body: {
          getReader: () => ({
            read: async () => ({ done: true, value: undefined }),
            releaseLock: () => {}
          })
        }
      }

      mockFetch.mockResolvedValueOnce(mockStream)

      const client = LLMClient.getInstance()
      
      const generator = client.generateContentStream({
        prompt: 'Test streaming',
        model: 'test-model',
        maxTokens: 1000,
        temperature: 0.8,
        context: ['urgent', 'premium']
      })

      // Start the generator to trigger the fetch
      try {
        await generator.next()
      } catch {
        // Expected to fail due to mock limitations, but we can check the fetch call
      }

      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/llm/generate'),
        expect.objectContaining({ method: 'GET' })
      )

      const callUrl = mockFetch.mock.calls[0][0] as string
      expect(callUrl).toContain('prompt=Test+streaming')
      expect(callUrl).toContain('model=test-model')
      expect(callUrl).toContain('maxTokens=1000')
      expect(callUrl).toContain('temperature=0.8')
      expect(callUrl).toContain('context=urgent%2Cpremium')
    })
  })
})