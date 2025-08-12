import type { LLMRequest, LLMResponse, LLMStreamChunk } from '@/types'

export class LLMError extends Error {
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

// Mock response templates for different content types
const MOCK_RESPONSES = {
  marketing_copy: [
    "Transform your business with our innovative solutions that deliver real results. Experience the difference quality makes.",
    "Discover how industry leaders are revolutionizing their operations with cutting-edge technology and expert guidance.",
    "Unlock your potential with proven strategies that drive growth, enhance productivity, and maximize your competitive advantage."
  ],
  subject_line: [
    "🚀 Your Success Starts Here",
    "Don't Miss This Game-Changing Opportunity",
    "Exclusive Insights Inside - Open Now"
  ],
  headline: [
    "Revolutionary Solutions for Modern Businesses",
    "The Future of Innovation is Here",
    "Transform Your Vision into Reality"
  ],
  description: [
    "Our comprehensive platform combines cutting-edge technology with expert insights to deliver measurable results for businesses of all sizes.",
    "Streamline operations, boost productivity, and achieve your goals with our proven methodology and dedicated support team.",
    "Join thousands of satisfied customers who have transformed their business outcomes through our innovative approach."
  ]
}

// Rate limiting configuration
interface RateLimitState {
  requests: number
  resetTime: number
}

class RateLimiter {
  private limits: Map<string, RateLimitState> = new Map()
  private readonly maxRequests = 100 // per hour
  private readonly windowMs = 60 * 60 * 1000 // 1 hour

  checkLimit(clientId: string): { allowed: boolean; retryAfter?: number } {
    const now = Date.now()
    const state = this.limits.get(clientId)

    if (!state || now > state.resetTime) {
      this.limits.set(clientId, {
        requests: 1,
        resetTime: now + this.windowMs
      })
      return { allowed: true }
    }

    if (state.requests >= this.maxRequests) {
      const retryAfter = Math.ceil((state.resetTime - now) / 1000)
      return { allowed: false, retryAfter }
    }

    state.requests++
    return { allowed: true }
  }
}

const rateLimiter = new RateLimiter()

export class LLMService {
  private static instance: LLMService
  private requestCount = 0

  static getInstance(): LLMService {
    if (!LLMService.instance) {
      LLMService.instance = new LLMService()
    }
    return LLMService.instance
  }

  async generateContent(request: LLMRequest, clientId = 'default'): Promise<LLMResponse> {
    // Check rate limiting
    const rateLimitCheck = rateLimiter.checkLimit(clientId)
    if (!rateLimitCheck.allowed) {
      throw new LLMError(
        'RATE_LIMIT_EXCEEDED',
        'Rate limit exceeded. Please try again later.',
        'rate_limit',
        rateLimitCheck.retryAfter
      )
    }

    // Validate request
    this.validateRequest(request)

    // Simulate API call delay (realistic response time)
    const processingTime = Math.random() * 2000 + 500 // 0.5-2.5 seconds
    await new Promise(resolve => setTimeout(resolve, processingTime))

    // Generate mock response
    const requestId = this.generateRequestId()
    const content = this.generateMockContent(request.prompt, request.context)
    const usage = this.calculateTokenUsage(request.prompt, content)

    return {
      id: requestId,
      content,
      model: request.model || 'mock-gpt-3.5-turbo',
      usage,
      finishReason: 'stop',
      metadata: {
        requestId,
        timestamp: new Date(),
        processingTime: Math.round(processingTime)
      }
    }
  }

  async *generateContentStream(request: LLMRequest, clientId = 'default'): AsyncGenerator<LLMStreamChunk> {
    // Check rate limiting
    const rateLimitCheck = rateLimiter.checkLimit(clientId)
    if (!rateLimitCheck.allowed) {
      throw new LLMError(
        'RATE_LIMIT_EXCEEDED',
        'Rate limit exceeded. Please try again later.',
        'rate_limit',
        rateLimitCheck.retryAfter
      )
    }

    // Validate request
    this.validateRequest(request)

    const requestId = this.generateRequestId()
    const fullContent = this.generateMockContent(request.prompt, request.context)
    const words = fullContent.split(' ')
    
    // Stream words with realistic timing
    for (let i = 0; i < words.length; i++) {
      const delta = i === 0 ? words[i] : ` ${words[i]}`
      const isComplete = i === words.length - 1
      
      yield {
        id: requestId,
        delta,
        isComplete,
        metadata: {
          tokenCount: i + 1,
          model: request.model || 'mock-gpt-3.5-turbo'
        }
      }

      // Simulate streaming delay
      await new Promise(resolve => setTimeout(resolve, Math.random() * 100 + 50))
    }
  }

  private validateRequest(request: LLMRequest): void {
    if (!request.prompt || request.prompt.trim().length === 0) {
      throw new LLMError(
        'INVALID_PROMPT',
        'Prompt is required and cannot be empty.',
        'invalid_request'
      )
    }

    if (request.prompt.length > 10000) {
      throw new LLMError(
        'PROMPT_TOO_LONG',
        'Prompt exceeds maximum length of 10,000 characters.',
        'invalid_request'
      )
    }

    if (request.maxTokens && (request.maxTokens < 1 || request.maxTokens > 4096)) {
      throw new LLMError(
        'INVALID_MAX_TOKENS',
        'maxTokens must be between 1 and 4096.',
        'invalid_request'
      )
    }

    if (request.temperature && (request.temperature < 0 || request.temperature > 2)) {
      throw new LLMError(
        'INVALID_TEMPERATURE',
        'Temperature must be between 0 and 2.',
        'invalid_request'
      )
    }
  }

  private generateMockContent(prompt: string, context?: string[]): string {
    // Determine content type based on prompt keywords
    let contentType = 'marketing_copy'
    
    const lowerPrompt = prompt.toLowerCase()
    if (lowerPrompt.includes('subject') || lowerPrompt.includes('email title')) {
      contentType = 'subject_line'
    } else if (lowerPrompt.includes('headline') || lowerPrompt.includes('title')) {
      contentType = 'headline'
    } else if (lowerPrompt.includes('description') || lowerPrompt.includes('summary')) {
      contentType = 'description'
    }

    const templates = MOCK_RESPONSES[contentType as keyof typeof MOCK_RESPONSES]
    const selectedTemplate = templates[Math.floor(Math.random() * templates.length)]

    // Add context-aware modifications
    if (context && context.length > 0) {
      const contextString = context.join(' ')
      if (contextString.includes('urgent')) {
        return `⚡ ${selectedTemplate} - Act now!`
      }
      if (contextString.includes('premium')) {
        return `Premium ${selectedTemplate}`
      }
    }

    return selectedTemplate
  }

  private calculateTokenUsage(prompt: string, content: string): { promptTokens: number; completionTokens: number; totalTokens: number } {
    // Simple token estimation (approximately 4 characters per token)
    const promptTokens = Math.ceil(prompt.length / 4)
    const completionTokens = Math.ceil(content.length / 4)
    
    return {
      promptTokens,
      completionTokens,
      totalTokens: promptTokens + completionTokens
    }
  }

  private generateRequestId(): string {
    const timestamp = Date.now()
    const random = Math.random().toString(36).substring(2, 15)
    this.requestCount++
    return `mock_req_${timestamp}_${this.requestCount}_${random}`
  }

  // Retry logic for handling transient errors
  async generateContentWithRetry(
    request: LLMRequest,
    clientId = 'default',
    maxRetries = 3,
    baseDelay = 1000
  ): Promise<LLMResponse> {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await this.generateContent(request, clientId)
      } catch (error) {
        if (error instanceof LLMError && error.type === 'rate_limit' && attempt < maxRetries) {
          const delay = error.retryAfter ? error.retryAfter * 1000 : baseDelay * Math.pow(2, attempt - 1)
          await new Promise(resolve => setTimeout(resolve, delay))
          continue
        }
        
        if (error instanceof LLMError && error.type === 'server_error' && attempt < maxRetries) {
          const delay = baseDelay * Math.pow(2, attempt - 1)
          await new Promise(resolve => setTimeout(resolve, delay))
          continue
        }
        
        throw error
      }
    }
    
    throw new LLMError(
      'MAX_RETRIES_EXCEEDED',
      'Maximum retry attempts exceeded.',
      'server_error'
    )
  }
}

// Export singleton instance
export const llmService = LLMService.getInstance()