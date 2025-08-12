import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { renderHook, act, waitFor } from '@testing-library/react'
import { useLLM } from '../useLLM'
import type { LLMApiRequest, LLMApiResponse } from '@/types/api'

// Mock fetch globally
const mockFetch = vi.fn()
global.fetch = mockFetch

// Mock ReadableStream for streaming tests
global.ReadableStream = vi.fn() as any

describe('useLLM Hook', () => {
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

  describe('Initial State', () => {
    it('should have correct initial state', () => {
      const { result } = renderHook(() => useLLM())

      expect(result.current.isLoading).toBe(false)
      expect(result.current.error).toBe(null)
      expect(result.current.response).toBe(null)
      expect(result.current.progress.isStreaming).toBe(false)
      expect(result.current.progress.currentContent).toBe('')
      expect(result.current.progress.tokenCount).toBe(0)
    })

    it('should accept options without crashing', () => {
      const onSuccess = vi.fn()
      const onError = vi.fn()
      const onProgress = vi.fn()

      const { result } = renderHook(() => useLLM({
        onSuccess,
        onError,
        onProgress
      }))

      expect(result.current).toBeDefined()
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

      const onSuccess = vi.fn()
      const { result } = renderHook(() => useLLM({ onSuccess }))

      expect(result.current.isLoading).toBe(false)

      const request: LLMApiRequest = {
        prompt: 'Generate test content',
        model: 'mock-gpt-3.5-turbo'
      }

      await act(async () => {
        await result.current.generateContent(request)
      })

      expect(result.current.isLoading).toBe(false)
      expect(result.current.error).toBe(null)
      expect(result.current.response).toEqual(mockSuccessResponse)
      expect(onSuccess).toHaveBeenCalledWith(mockSuccessResponse)

      // Check fetch was called correctly
      expect(mockFetch).toHaveBeenCalledWith('/api/llm/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(request),
        signal: expect.any(AbortSignal)
      })
    })

    it('should set loading state during generation', async () => {
      let resolvePromise: (value: any) => void
      const mockPromise = new Promise((resolve) => {
        resolvePromise = resolve
      })

      mockFetch.mockReturnValue(mockPromise)

      const { result } = renderHook(() => useLLM())

      act(() => {
        result.current.generateContent({
          prompt: 'Test prompt',
          model: 'test-model'
        })
      })

      // Should be loading immediately
      expect(result.current.isLoading).toBe(true)
      expect(result.current.error).toBe(null)
      expect(result.current.response).toBe(null)

      // Resolve the promise
      act(() => {
        resolvePromise!({
          ok: true,
          json: async () => ({
            success: true,
            data: mockSuccessResponse
          })
        })
      })

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false)
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

      const onError = vi.fn()
      const { result } = renderHook(() => useLLM({ onError }))

      await act(async () => {
        await result.current.generateContent({
          prompt: '',
          model: 'test-model'
        })
      })

      expect(result.current.isLoading).toBe(false)
      expect(result.current.error).toEqual({
        code: 'INVALID_PROMPT',
        message: 'Prompt is required',
        type: 'invalid_request'
      })
      expect(result.current.response).toBe(null)
      expect(onError).toHaveBeenCalledWith(expect.objectContaining({
        code: 'INVALID_PROMPT',
        message: 'Prompt is required',
        type: 'invalid_request'
      }))
    })

    it('should handle rate limit errors with retry after', async () => {
      const rateLimitResponse = {
        error: 'RATE_LIMIT_EXCEEDED',
        message: 'Rate limit exceeded',
        type: 'rate_limit',
        retryAfter: 300
      }

      mockFetch.mockResolvedValueOnce({
        ok: false,
        json: async () => rateLimitResponse
      })

      const { result } = renderHook(() => useLLM())

      await act(async () => {
        await result.current.generateContent({
          prompt: 'Test prompt',
          model: 'test-model'
        })
      })

      expect(result.current.error).toEqual({
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Rate limit exceeded',
        type: 'rate_limit',
        retryAfter: 300
      })
    })

    it('should handle network errors', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'))

      const { result } = renderHook(() => useLLM())

      await act(async () => {
        await result.current.generateContent({
          prompt: 'Test prompt',
          model: 'test-model'
        })
      })

      expect(result.current.error).toEqual({
        code: 'NETWORK_ERROR',
        message: 'Network error',
        type: 'server_error'
      })
    })

    it('should handle invalid server responses', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: false,
          // Missing data field
        })
      })

      const { result } = renderHook(() => useLLM())

      await act(async () => {
        await result.current.generateContent({
          prompt: 'Test prompt',
          model: 'test-model'
        })
      })

      expect(result.current.error).toEqual({
        code: 'INVALID_RESPONSE',
        message: 'Invalid response from server',
        type: 'server_error'
      })
    })

    it('should cancel previous request when new one is made', async () => {
      const abortSpy = vi.fn()
      const mockAbortController = {
        signal: { addEventListener: vi.fn(), removeEventListener: vi.fn() },
        abort: abortSpy
      }
      vi.spyOn(window, 'AbortController').mockImplementation(() => mockAbortController as any)

      let firstResolve: (value: any) => void
      const firstPromise = new Promise((resolve) => {
        firstResolve = resolve
      })

      mockFetch.mockReturnValueOnce(firstPromise)

      const { result } = renderHook(() => useLLM())

      // Start first request
      act(() => {
        result.current.generateContent({
          prompt: 'First request',
          model: 'test-model'
        })
      })

      // Start second request before first completes
      act(() => {
        result.current.generateContent({
          prompt: 'Second request',
          model: 'test-model'
        })
      })

      // Should have aborted first request
      expect(abortSpy).toHaveBeenCalled()
    })

    it('should handle request cancellation', async () => {
      mockFetch.mockRejectedValueOnce(new DOMException('Request cancelled', 'AbortError'))

      const { result } = renderHook(() => useLLM())

      await act(async () => {
        await result.current.generateContent({
          prompt: 'Test prompt',
          model: 'test-model'
        })
      })

      // Should not set error for cancelled requests
      expect(result.current.error).toBe(null)
      expect(result.current.isLoading).toBe(false)
    })
  })

  describe('generateContentStream', () => {
    const createMockStream = (chunks: any[]) => {
      const encoder = new TextEncoder()
      let index = 0

      return {
        ok: true,
        body: {
          getReader: () => ({
            read: async () => {
              if (index >= chunks.length) {
                return { done: true, value: undefined }
              }
              
              const chunk = chunks[index++]
              const data = JSON.stringify(chunk) + '\n'
              return { done: false, value: encoder.encode(data) }
            },
            releaseLock: () => {}
          })
        }
      }
    }

    it('should handle streaming content generation', async () => {
      const streamChunks = [
        { id: 'stream-1', delta: 'Hello', isComplete: false, metadata: { tokenCount: 1 } },
        { id: 'stream-1', delta: ' world', isComplete: false, metadata: { tokenCount: 2 } },
        { id: 'stream-1', delta: '!', isComplete: true, metadata: { tokenCount: 3 } }
      ]

      mockFetch.mockResolvedValueOnce(createMockStream(streamChunks))

      const onProgress = vi.fn()
      const onSuccess = vi.fn()
      const { result } = renderHook(() => useLLM({ onProgress, onSuccess }))

      await act(async () => {
        await result.current.generateContentStream({
          prompt: 'Generate streaming content',
          model: 'test-model'
        })
      })

      // Should have processed all chunks
      expect(result.current.progress.currentContent).toBe('Hello world!')
      expect(result.current.progress.tokenCount).toBe(3)
      expect(result.current.progress.isStreaming).toBe(false)
      expect(result.current.isLoading).toBe(false)

      // Should have called progress callback for each delta
      expect(onProgress).toHaveBeenCalledTimes(3)
      expect(onProgress).toHaveBeenNthCalledWith(1, 'Hello')
      expect(onProgress).toHaveBeenNthCalledWith(2, ' world')
      expect(onProgress).toHaveBeenNthCalledWith(3, '!')

      // Should have called success with final response
      expect(onSuccess).toHaveBeenCalledWith(expect.objectContaining({
        id: 'stream-1',
        content: 'Hello world!',
        finishReason: 'stop'
      }))
    })

    it('should set streaming state correctly', async () => {
      let resolveStream: (value: any) => void
      const streamPromise = new Promise((resolve) => {
        resolveStream = resolve
      })

      mockFetch.mockReturnValue(streamPromise)

      const { result } = renderHook(() => useLLM())

      act(() => {
        result.current.generateContentStream({
          prompt: 'Test streaming',
          model: 'test-model'
        })
      })

      // Should be in streaming state
      expect(result.current.isLoading).toBe(true)
      expect(result.current.progress.isStreaming).toBe(true)
      expect(result.current.progress.currentContent).toBe('')

      // Resolve with empty stream
      act(() => {
        resolveStream!(createMockStream([]))
      })

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false)
        expect(result.current.progress.isStreaming).toBe(false)
      })
    })

    it('should handle streaming errors in response', async () => {
      const streamChunks = [
        { error: 'STREAM_ERROR', message: 'Stream failed', type: 'server_error' }
      ]

      mockFetch.mockResolvedValueOnce(createMockStream(streamChunks))

      const onError = vi.fn()
      const { result } = renderHook(() => useLLM({ onError }))

      await act(async () => {
        await result.current.generateContentStream({
          prompt: 'Test streaming error',
          model: 'test-model'
        })
      })

      expect(result.current.error).toEqual({
        code: 'STREAM_ERROR',
        message: 'Stream failed',
        type: 'server_error'
      })
      expect(result.current.progress.isStreaming).toBe(false)
      expect(onError).toHaveBeenCalled()
    })

    it('should handle invalid JSON in stream', async () => {
      const encoder = new TextEncoder()
      const invalidStream = {
        ok: true,
        body: {
          getReader: () => ({
            read: async () => {
              return { done: false, value: encoder.encode('invalid json\n') }
            },
            releaseLock: () => {}
          })
        }
      }

      mockFetch.mockResolvedValueOnce(invalidStream)

      const { result } = renderHook(() => useLLM())

      // Should not crash with invalid JSON
      await act(async () => {
        await result.current.generateContentStream({
          prompt: 'Test invalid JSON',
          model: 'test-model'
        })
      })

      // Should handle gracefully (exact behavior depends on implementation)
      expect(result.current.progress.isStreaming).toBe(false)
    })

    it('should build correct streaming URL with parameters', async () => {
      mockFetch.mockResolvedValueOnce(createMockStream([]))

      const { result } = renderHook(() => useLLM())

      await act(async () => {
        await result.current.generateContentStream({
          prompt: 'Test with params',
          model: 'custom-model',
          maxTokens: 1000,
          temperature: 0.8,
          context: ['urgent', 'premium']
        })
      })

      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/llm/generate'),
        expect.objectContaining({ method: 'GET' })
      )

      const callArgs = mockFetch.mock.calls[0][0] as string
      expect(callArgs).toContain('prompt=Test+with+params')
      expect(callArgs).toContain('model=custom-model')
      expect(callArgs).toContain('maxTokens=1000')
      expect(callArgs).toContain('temperature=0.8')
      expect(callArgs).toContain('context=urgent%2Cpremium')
    })
  })

  describe('cancel', () => {
    it('should cancel ongoing requests', async () => {
      const abortSpy = vi.fn()
      const mockAbortController = {
        signal: { addEventListener: vi.fn(), removeEventListener: vi.fn() },
        abort: abortSpy
      }
      vi.spyOn(window, 'AbortController').mockImplementation(() => mockAbortController as any)

      const { result } = renderHook(() => useLLM())

      // Start a request
      act(() => {
        result.current.generateContent({
          prompt: 'Test prompt',
          model: 'test-model'
        })
      })

      expect(result.current.isLoading).toBe(true)

      // Cancel the request
      act(() => {
        result.current.cancel()
      })

      expect(abortSpy).toHaveBeenCalled()
      expect(result.current.isLoading).toBe(false)
    })

    it('should reset streaming state when cancelled', async () => {
      const { result } = renderHook(() => useLLM())

      // Set up streaming state
      act(() => {
        result.current.generateContentStream({
          prompt: 'Test streaming',
          model: 'test-model'
        })
      })

      expect(result.current.progress.isStreaming).toBe(true)

      // Cancel
      act(() => {
        result.current.cancel()
      })

      expect(result.current.isLoading).toBe(false)
      expect(result.current.progress.isStreaming).toBe(false)
    })
  })

  describe('retry', () => {
    it('should retry with same parameters', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({
          success: true,
          data: mockSuccessResponse
        })
      })

      const { result } = renderHook(() => useLLM())

      const request: LLMApiRequest = {
        prompt: 'Test retry',
        model: 'test-model'
      }

      // First request
      await act(async () => {
        await result.current.generateContent(request)
      })

      expect(mockFetch).toHaveBeenCalledTimes(1)

      // Retry
      await act(async () => {
        await result.current.retry(request)
      })

      expect(mockFetch).toHaveBeenCalledTimes(2)
      expect(mockFetch).toHaveBeenLastCalledWith(
        '/api/llm/generate',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(request)
        })
      )
    })

    it('should use streaming retry when was streaming', async () => {
      mockFetch.mockResolvedValue(createMockStream([]))

      const { result } = renderHook(() => useLLM())

      const request = {
        prompt: 'Test streaming retry',
        model: 'test-model'
      }

      // First streaming request
      await act(async () => {
        await result.current.generateContentStream(request)
      })

      expect(mockFetch).toHaveBeenCalledTimes(1)
      expect(mockFetch).toHaveBeenLastCalledWith(
        expect.stringContaining('/api/llm/generate'),
        expect.objectContaining({ method: 'GET' })
      )

      // Retry should also use streaming
      await act(async () => {
        await result.current.retry(request)
      })

      expect(mockFetch).toHaveBeenCalledTimes(2)
      expect(mockFetch).toHaveBeenLastCalledWith(
        expect.stringContaining('/api/llm/generate'),
        expect.objectContaining({ method: 'GET' })
      )
    })
  })

  describe('reset', () => {
    it('should reset all state', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: true,
          data: mockSuccessResponse
        })
      })

      const { result } = renderHook(() => useLLM())

      // Generate content to set state
      await act(async () => {
        await result.current.generateContent({
          prompt: 'Test content',
          model: 'test-model'
        })
      })

      expect(result.current.response).toEqual(mockSuccessResponse)

      // Reset
      act(() => {
        result.current.reset()
      })

      expect(result.current.isLoading).toBe(false)
      expect(result.current.error).toBe(null)
      expect(result.current.response).toBe(null)
      expect(result.current.progress.isStreaming).toBe(false)
      expect(result.current.progress.currentContent).toBe('')
      expect(result.current.progress.tokenCount).toBe(0)
    })
  })

  describe('Error Handling Edge Cases', () => {
    it('should handle fetch throwing synchronously', async () => {
      mockFetch.mockImplementation(() => {
        throw new Error('Fetch failed immediately')
      })

      const { result } = renderHook(() => useLLM())

      await act(async () => {
        await result.current.generateContent({
          prompt: 'Test sync error',
          model: 'test-model'
        })
      })

      expect(result.current.error).toEqual({
        code: 'NETWORK_ERROR',
        message: 'Fetch failed immediately',
        type: 'server_error'
      })
    })

    it('should handle JSON parsing errors', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => {
          throw new Error('Invalid JSON')
        }
      })

      const { result } = renderHook(() => useLLM())

      await act(async () => {
        await result.current.generateContent({
          prompt: 'Test JSON error',
          model: 'test-model'
        })
      })

      expect(result.current.error).toEqual({
        code: 'NETWORK_ERROR',
        message: 'Invalid JSON',
        type: 'server_error'
      })
    })

    it('should handle stream reader creation failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        body: null // No body
      })

      const { result } = renderHook(() => useLLM())

      await act(async () => {
        await result.current.generateContentStream({
          prompt: 'Test no body',
          model: 'test-model'
        })
      })

      expect(result.current.error).toEqual({
        code: 'STREAM_ERROR',
        message: 'Failed to get stream reader',
        type: 'server_error'
      })
    })
  })
})