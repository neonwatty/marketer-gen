import type { LLMApiRequest, LLMApiResponse } from '@/types/api'

export interface LLMClientError extends Error {
  code: string
  type: string
  retryAfter?: number
}

export class LLMClient {
  private static instance: LLMClient
  private baseUrl: string

  constructor(baseUrl = '/api/llm') {
    this.baseUrl = baseUrl
  }

  static getInstance(baseUrl?: string): LLMClient {
    if (!LLMClient.instance) {
      LLMClient.instance = new LLMClient(baseUrl)
    }
    return LLMClient.instance
  }

  async generateContent(request: LLMApiRequest): Promise<LLMApiResponse> {
    const response = await fetch(`${this.baseUrl}/generate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request)
    })

    const data = await response.json()

    if (!response.ok) {
      const error = new Error(data.message || 'LLM API request failed') as LLMClientError
      error.code = data.error || 'REQUEST_FAILED'
      error.type = data.type || 'server_error'
      error.retryAfter = data.retryAfter
      throw error
    }

    if (!data.success || !data.data) {
      const error = new Error('Invalid response from LLM API') as LLMClientError
      error.code = 'INVALID_RESPONSE'
      error.type = 'server_error'
      throw error
    }

    return data.data
  }

  async *generateContentStream(request: Omit<LLMApiRequest, 'stream'>): AsyncGenerator<string, LLMApiResponse> {
    const url = new URL(`${this.baseUrl}/generate`, window.location.origin)
    url.searchParams.set('prompt', request.prompt)
    if (request.model) url.searchParams.set('model', request.model)
    if (request.maxTokens) url.searchParams.set('maxTokens', request.maxTokens.toString())
    if (request.temperature) url.searchParams.set('temperature', request.temperature.toString())
    if (request.context) url.searchParams.set('context', request.context.join(','))

    const response = await fetch(url.toString(), {
      method: 'GET'
    })

    if (!response.ok) {
      const errorData = await response.json()
      const error = new Error(errorData.message || 'Stream request failed') as LLMClientError
      error.code = errorData.error || 'STREAM_FAILED'
      error.type = errorData.type || 'server_error'
      throw error
    }

    const reader = response.body?.getReader()
    if (!reader) {
      throw new Error('Failed to get stream reader')
    }

    const decoder = new TextDecoder()
    let fullContent = ''
    let finalResponse: LLMApiResponse | null = null

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
              const error = new Error(data.message) as LLMClientError
              error.code = data.error
              error.type = data.type || 'server_error'
              throw error
            }

            if (data.delta) {
              fullContent += data.delta
              yield data.delta

              if (data.isComplete) {
                finalResponse = {
                  id: data.id,
                  content: fullContent,
                  model: data.metadata?.model || 'mock-gpt-3.5-turbo',
                  usage: {
                    promptTokens: Math.ceil(request.prompt.length / 4),
                    completionTokens: Math.ceil(fullContent.length / 4),
                    totalTokens: Math.ceil((request.prompt.length + fullContent.length) / 4)
                  },
                  finishReason: 'stop',
                  metadata: {
                    requestId: data.id,
                    timestamp: new Date().toISOString(),
                    processingTime: 0
                  }
                }
                break
              }
            }
          } catch (parseError) {
            console.error('Error parsing stream chunk:', parseError)
          }
        }
      }
    } finally {
      reader.releaseLock()
    }

    if (!finalResponse) {
      const error = new Error('Stream ended without completion') as LLMClientError
      error.code = 'INCOMPLETE_STREAM'
      error.type = 'server_error'
      throw error
    }

    return finalResponse
  }

  // Convenience methods for common operations
  async generateMarketingCopy(
    prompt: string,
    options?: Partial<Pick<LLMApiRequest, 'tone' | 'length' | 'context' | 'temperature'>>
  ): Promise<string> {
    const request: LLMApiRequest = {
      prompt: `Generate marketing copy: ${prompt}`,
      temperature: options?.temperature || 0.7,
      context: options?.context,
      maxTokens: 500
    }

    const response = await this.generateContent(request)
    return response.content
  }

  async generateSubjectLine(prompt: string, urgent = false): Promise<string> {
    const urgencyContext = urgent ? 'Make it urgent and action-oriented.' : ''
    const request: LLMApiRequest = {
      prompt: `Generate an email subject line for: ${prompt}. ${urgencyContext}`,
      temperature: 0.8,
      maxTokens: 50
    }

    const response = await this.generateContent(request)
    return response.content
  }

  async generateHeadline(prompt: string, style: 'creative' | 'professional' = 'professional'): Promise<string> {
    const styleContext = style === 'creative' 
      ? 'Make it creative and attention-grabbing.' 
      : 'Keep it professional and clear.'
    
    const request: LLMApiRequest = {
      prompt: `Generate a headline for: ${prompt}. ${styleContext}`,
      temperature: style === 'creative' ? 0.9 : 0.6,
      maxTokens: 100
    }

    const response = await this.generateContent(request)
    return response.content
  }

  async generateDescription(prompt: string, length: 'short' | 'medium' | 'long' = 'medium'): Promise<string> {
    const lengthTokens = {
      short: 100,
      medium: 200,
      long: 400
    }

    const request: LLMApiRequest = {
      prompt: `Generate a ${length} description for: ${prompt}`,
      temperature: 0.7,
      maxTokens: lengthTokens[length]
    }

    const response = await this.generateContent(request)
    return response.content
  }

  // Batch operations
  async generateMultipleVariations(
    prompt: string,
    count: number = 3,
    type: 'copy' | 'headline' | 'subject_line' = 'copy'
  ): Promise<string[]> {
    const promises = Array.from({ length: count }, (_, i) => {
      const variationPrompt = `Generate variation ${i + 1} of ${type.replace('_', ' ')} for: ${prompt}`
      const request: LLMApiRequest = {
        prompt: variationPrompt,
        temperature: 0.8 + (i * 0.1), // Increase temperature for more variety
        maxTokens: type === 'subject_line' ? 50 : type === 'headline' ? 100 : 300
      }
      return this.generateContent(request)
    })

    const responses = await Promise.all(promises)
    return responses.map(response => response.content)
  }

  // Error handling utilities
  isRetryableError(error: LLMClientError): boolean {
    return error.type === 'rate_limit' || error.type === 'server_error'
  }

  getRetryDelay(error: LLMClientError): number {
    if (error.retryAfter) {
      return error.retryAfter * 1000
    }
    return error.type === 'rate_limit' ? 60000 : 5000 // 1 minute for rate limit, 5 seconds for server error
  }

  async withRetry<T>(
    operation: () => Promise<T>,
    maxRetries = 3,
    baseDelay = 1000
  ): Promise<T> {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation()
      } catch (error) {
        if (!(error instanceof Error) || !this.isRetryableError(error as LLMClientError)) {
          throw error
        }

        if (attempt === maxRetries) {
          throw error
        }

        const delay = this.getRetryDelay(error as LLMClientError) || baseDelay * Math.pow(2, attempt - 1)
        await new Promise(resolve => setTimeout(resolve, delay))
      }
    }

    throw new Error('Max retries exceeded')
  }
}

// Export singleton instance
export const llmClient = LLMClient.getInstance()