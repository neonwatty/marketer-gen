import { useState, useCallback, useRef } from 'react'
import type { LLMApiRequest, LLMApiResponse } from '@/types/api'

interface UseLLMOptions {
  onSuccess?: (response: LLMApiResponse) => void
  onError?: (error: LLMError) => void
  onProgress?: (chunk: string) => void
}

interface LLMError {
  code: string
  message: string
  type: string
  retryAfter?: number
}

interface UseLLMState {
  isLoading: boolean
  error: LLMError | null
  response: LLMApiResponse | null
  progress: {
    isStreaming: boolean
    currentContent: string
    tokenCount: number
  }
}

export function useLLM(options: UseLLMOptions = {}) {
  const [state, setState] = useState<UseLLMState>({
    isLoading: false,
    error: null,
    response: null,
    progress: {
      isStreaming: false,
      currentContent: '',
      tokenCount: 0
    }
  })

  const abortControllerRef = useRef<AbortController | null>(null)

  const generateContent = useCallback(async (request: LLMApiRequest) => {
    // Cancel any ongoing request
    if (abortControllerRef.current) {
      abortControllerRef.current.abort()
    }

    const abortController = new AbortController()
    abortControllerRef.current = abortController

    setState(prev => ({
      ...prev,
      isLoading: true,
      error: null,
      response: null,
      progress: {
        isStreaming: false,
        currentContent: '',
        tokenCount: 0
      }
    }))

    try {
      const response = await fetch('/api/llm/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(request),
        signal: abortController.signal
      })

      const data = await response.json()

      if (!response.ok) {
        const error: LLMError = {
          code: data.error || 'REQUEST_FAILED',
          message: data.message || 'Request failed',
          type: data.type || 'server_error',
          retryAfter: data.retryAfter
        }
        
        setState(prev => ({
          ...prev,
          isLoading: false,
          error
        }))

        options.onError?.(error)
        return
      }

      if (!data.success || !data.data) {
        const error: LLMError = {
          code: 'INVALID_RESPONSE',
          message: 'Invalid response from server',
          type: 'server_error'
        }
        
        setState(prev => ({
          ...prev,
          isLoading: false,
          error
        }))

        options.onError?.(error)
        return
      }

      setState(prev => ({
        ...prev,
        isLoading: false,
        response: data.data
      }))

      options.onSuccess?.(data.data)

    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        // Request was cancelled
        return
      }

      const llmError: LLMError = {
        code: 'NETWORK_ERROR',
        message: error instanceof Error ? error.message : 'Network error occurred',
        type: 'server_error'
      }

      setState(prev => ({
        ...prev,
        isLoading: false,
        error: llmError
      }))

      options.onError?.(llmError)
    }
  }, [options])

  const generateContentStream = useCallback(async (request: Omit<LLMApiRequest, 'stream'>) => {
    // Cancel any ongoing request
    if (abortControllerRef.current) {
      abortControllerRef.current.abort()
    }

    const abortController = new AbortController()
    abortControllerRef.current = abortController

    setState(prev => ({
      ...prev,
      isLoading: true,
      error: null,
      response: null,
      progress: {
        isStreaming: true,
        currentContent: '',
        tokenCount: 0
      }
    }))

    try {
      const url = new URL('/api/llm/generate', window.location.origin)
      url.searchParams.set('prompt', request.prompt)
      if (request.model) url.searchParams.set('model', request.model)
      if (request.maxTokens) url.searchParams.set('maxTokens', request.maxTokens.toString())
      if (request.temperature) url.searchParams.set('temperature', request.temperature.toString())
      if (request.context) url.searchParams.set('context', request.context.join(','))

      const response = await fetch(url.toString(), {
        method: 'GET',
        signal: abortController.signal
      })

      if (!response.ok) {
        const errorData = await response.json()
        const error: LLMError = {
          code: errorData.error || 'STREAM_FAILED',
          message: errorData.message || 'Streaming request failed',
          type: errorData.type || 'server_error'
        }
        
        setState(prev => ({
          ...prev,
          isLoading: false,
          error,
          progress: { ...prev.progress, isStreaming: false }
        }))

        options.onError?.(error)
        return
      }

      const reader = response.body?.getReader()
      if (!reader) {
        throw new Error('Failed to get stream reader')
      }

      const decoder = new TextDecoder()
      let currentContent = ''

      try {
        while (true) {
          const { done, value } = await reader.read()
          
          if (done) break

          const chunk = decoder.decode(value, { stream: true })
          const lines = chunk.split('\n').filter(line => line.trim())

          for (const line of lines) {
            try {
              const data = JSON.parse(line)
              
              if (data.error) {
                const error: LLMError = {
                  code: data.error,
                  message: data.message,
                  type: data.type || 'server_error'
                }
                
                setState(prev => ({
                  ...prev,
                  isLoading: false,
                  error,
                  progress: { ...prev.progress, isStreaming: false }
                }))

                options.onError?.(error)
                return
              }

              if (data.delta) {
                currentContent += data.delta
                
                setState(prev => ({
                  ...prev,
                  progress: {
                    ...prev.progress,
                    currentContent,
                    tokenCount: data.metadata?.tokenCount || prev.progress.tokenCount
                  }
                }))

                options.onProgress?.(data.delta)

                if (data.isComplete) {
                  // Create final response object
                  const finalResponse: LLMApiResponse = {
                    id: data.id,
                    content: currentContent,
                    model: data.metadata?.model || 'mock-gpt-3.5-turbo',
                    usage: {
                      promptTokens: Math.ceil(request.prompt.length / 4),
                      completionTokens: Math.ceil(currentContent.length / 4),
                      totalTokens: Math.ceil((request.prompt.length + currentContent.length) / 4)
                    },
                    finishReason: 'stop',
                    metadata: {
                      requestId: data.id,
                      timestamp: new Date().toISOString(),
                      processingTime: 0
                    }
                  }

                  setState(prev => ({
                    ...prev,
                    isLoading: false,
                    response: finalResponse,
                    progress: { ...prev.progress, isStreaming: false }
                  }))

                  options.onSuccess?.(finalResponse)
                  break
                }
              }
            } catch (parseError) {
              console.error('Error parsing stream chunk:', parseError, 'Chunk:', line)
            }
          }
        }
      } finally {
        reader.releaseLock()
      }

    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        // Request was cancelled
        return
      }

      const llmError: LLMError = {
        code: 'STREAM_ERROR',
        message: error instanceof Error ? error.message : 'Stream error occurred',
        type: 'server_error'
      }

      setState(prev => ({
        ...prev,
        isLoading: false,
        error: llmError,
        progress: { ...prev.progress, isStreaming: false }
      }))

      options.onError?.(llmError)
    }
  }, [options])

  const cancel = useCallback(() => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort()
      
      setState(prev => ({
        ...prev,
        isLoading: false,
        progress: { ...prev.progress, isStreaming: false }
      }))
    }
  }, [])

  const retry = useCallback((request: LLMApiRequest) => {
    if (state.progress.isStreaming) {
      return generateContentStream(request)
    } else {
      return generateContent(request)
    }
  }, [generateContent, generateContentStream, state.progress.isStreaming])

  const reset = useCallback(() => {
    setState({
      isLoading: false,
      error: null,
      response: null,
      progress: {
        isStreaming: false,
        currentContent: '',
        tokenCount: 0
      }
    })
  }, [])

  return {
    ...state,
    generateContent,
    generateContentStream,
    cancel,
    retry,
    reset
  }
}