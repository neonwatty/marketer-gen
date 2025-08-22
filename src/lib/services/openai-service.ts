import { openai } from '@ai-sdk/openai'
import { streamText, generateText, GenerateTextResult, StreamTextResult } from 'ai'
import { z } from 'zod'

/**
 * Configuration options for OpenAI service
 */
export interface OpenAIServiceConfig {
  apiKey?: string
  model?: string
  maxTokens?: number
  temperature?: number
  maxRetries?: number
  retryDelay?: number
}

/**
 * Message type for conversation history
 */
export interface ConversationMessage {
  role: 'user' | 'assistant' | 'system'
  content: string
}

/**
 * Request schema for text generation
 */
const TextGenerationRequestSchema = z.object({
  prompt: z.string().min(1, 'Prompt is required'),
  system: z.string().optional(),
  messages: z.array(z.object({
    role: z.enum(['user', 'assistant', 'system']),
    content: z.string()
  })).optional(),
  temperature: z.number().min(0).max(2).optional(),
  maxTokens: z.number().min(1).max(4096).optional(),
  stream: z.boolean().optional().default(false)
})

export type TextGenerationRequest = {
  prompt: string
  system?: string
  messages?: ConversationMessage[]
  temperature?: number
  maxTokens?: number
  stream?: boolean
}

/**
 * Error types for OpenAI service
 */
export class OpenAIServiceError extends Error {
  constructor(
    message: string, 
    public code: string,
    public statusCode?: number,
    public originalError?: Error
  ) {
    super(message)
    this.name = 'OpenAIServiceError'
  }
}

/**
 * OpenAI Service for handling AI text generation with streaming support
 */
export class OpenAIService {
  private config: Required<OpenAIServiceConfig>
  private isInitialized = false

  constructor(config: OpenAIServiceConfig = {}) {
    this.config = {
      apiKey: config.apiKey || process.env.OPENAI_API_KEY || '',
      model: config.model || 'gpt-4o',
      maxTokens: config.maxTokens || 2048,
      temperature: config.temperature || 0.7,
      maxRetries: config.maxRetries || 3,
      retryDelay: config.retryDelay || 1000
    }
    
    this.validateConfig()
  }

  /**
   * Validate the service configuration
   */
  private validateConfig(): void {
    if (!this.config.apiKey) {
      throw new OpenAIServiceError(
        'OpenAI API key is required. Set OPENAI_API_KEY environment variable or pass apiKey in config.',
        'MISSING_API_KEY'
      )
    }

    if (this.config.temperature < 0 || this.config.temperature > 2) {
      throw new OpenAIServiceError(
        'Temperature must be between 0 and 2',
        'INVALID_TEMPERATURE'
      )
    }

    this.isInitialized = true
  }

  /**
   * Check if the service is properly initialized
   */
  public isReady(): boolean {
    return this.isInitialized && !!this.config.apiKey
  }

  /**
   * Generate text with streaming support
   */
  public async streamText(request: TextGenerationRequest) {
    if (!this.isReady()) {
      throw new OpenAIServiceError('Service not initialized', 'NOT_INITIALIZED')
    }

    // Validate request
    const validatedRequest = TextGenerationRequestSchema.parse(request)

    try {
      // Use either prompt mode or messages mode, but not both
      const streamConfig = validatedRequest.messages && validatedRequest.messages.length > 0 
        ? {
            model: openai(this.config.model),
            messages: validatedRequest.messages.map(msg => ({
              role: msg.role,
              content: msg.content
            })),
            system: validatedRequest.system,
            temperature: validatedRequest.temperature ?? this.config.temperature,
            maxOutputTokens: validatedRequest.maxTokens ?? this.config.maxTokens,
            maxRetries: this.config.maxRetries,
          }
        : {
            model: openai(this.config.model),
            prompt: validatedRequest.prompt,
            system: validatedRequest.system,
            temperature: validatedRequest.temperature ?? this.config.temperature,
            maxOutputTokens: validatedRequest.maxTokens ?? this.config.maxTokens,
            maxRetries: this.config.maxRetries,
          }

      const result = await streamText(streamConfig)
      return result
    } catch (error) {
      throw this.handleError(error)
    }
  }

  /**
   * Generate text without streaming
   */
  public async generateText(request: Omit<TextGenerationRequest, 'stream'>) {
    if (!this.isReady()) {
      throw new OpenAIServiceError('Service not initialized', 'NOT_INITIALIZED')
    }

    // Validate request
    const validatedRequest = TextGenerationRequestSchema.omit({ stream: true }).parse(request)

    try {
      // Use either prompt mode or messages mode, but not both
      const generateConfig = validatedRequest.messages && validatedRequest.messages.length > 0 
        ? {
            model: openai(this.config.model),
            messages: validatedRequest.messages.map(msg => ({
              role: msg.role,
              content: msg.content
            })),
            system: validatedRequest.system,
            temperature: validatedRequest.temperature ?? this.config.temperature,
            maxOutputTokens: validatedRequest.maxTokens ?? this.config.maxTokens,
            maxRetries: this.config.maxRetries,
          }
        : {
            model: openai(this.config.model),
            prompt: validatedRequest.prompt,
            system: validatedRequest.system,
            temperature: validatedRequest.temperature ?? this.config.temperature,
            maxOutputTokens: validatedRequest.maxTokens ?? this.config.maxTokens,
            maxRetries: this.config.maxRetries,
          }

      const result = await generateText(generateConfig)
      return result
    } catch (error) {
      throw this.handleError(error)
    }
  }

  /**
   * Handle and transform errors from the OpenAI API
   */
  private handleError(error: unknown): OpenAIServiceError {
    if (error instanceof OpenAIServiceError) {
      return error
    }

    if (error instanceof Error) {
      // Check for specific OpenAI error patterns
      const message = error.message.toLowerCase()
      
      if (message.includes('api key') || message.includes('unauthorized')) {
        return new OpenAIServiceError(
          'Invalid or missing API key',
          'INVALID_API_KEY',
          401,
          error
        )
      }
      
      if (message.includes('rate limit') || message.includes('quota')) {
        return new OpenAIServiceError(
          'Rate limit exceeded or quota exhausted',
          'RATE_LIMIT',
          429,
          error
        )
      }
      
      if (message.includes('timeout')) {
        return new OpenAIServiceError(
          'Request timeout',
          'TIMEOUT',
          408,
          error
        )
      }

      if (message.includes('model') && message.includes('not found')) {
        return new OpenAIServiceError(
          `Model ${this.config.model} not found or not available`,
          'MODEL_NOT_FOUND',
          404,
          error
        )
      }

      return new OpenAIServiceError(
        `OpenAI API error: ${error.message}`,
        'API_ERROR',
        undefined,
        error
      )
    }

    return new OpenAIServiceError(
      'Unknown error occurred',
      'UNKNOWN_ERROR',
      undefined,
      error instanceof Error ? error : new Error(String(error))
    )
  }

  /**
   * Test the service connection
   */
  public async testConnection(): Promise<boolean> {
    try {
      const result = await this.generateText({
        prompt: 'Hello, this is a test. Please respond with just "Test successful".',
        maxTokens: 10
      })
      
      return result.text.toLowerCase().includes('test')
    } catch (error) {
      console.error('OpenAI service test connection failed:', error)
      return false
    }
  }

  /**
   * Get current configuration (without API key for security)
   */
  public getConfig(): Omit<OpenAIServiceConfig, 'apiKey'> & { hasApiKey: boolean } {
    return {
      model: this.config.model,
      maxTokens: this.config.maxTokens,
      temperature: this.config.temperature,
      maxRetries: this.config.maxRetries,
      retryDelay: this.config.retryDelay,
      hasApiKey: !!this.config.apiKey
    }
  }

  /**
   * Update service configuration
   */
  public updateConfig(newConfig: Partial<OpenAIServiceConfig>): void {
    this.config = { ...this.config, ...newConfig }
    this.validateConfig()
  }
}

// Default service instance factory - avoids initialization errors in tests
export const createOpenAIService = (config?: OpenAIServiceConfig) => new OpenAIService(config)

// Default service instance (lazy initialization)
let _defaultService: OpenAIService | null = null
export const openAIService = {
  get instance() {
    if (!_defaultService) {
      _defaultService = new OpenAIService()
    }
    return _defaultService
  }
}

// Export types for external use
export { TextGenerationRequestSchema }