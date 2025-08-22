/**
 * @jest-environment node
 */
import { describe, expect, it, jest, beforeEach, afterEach } from '@jest/globals'

// Mock functions
const mockOpenaiFunction = jest.fn()
const mockStreamText = jest.fn()
const mockGenerateText = jest.fn()

// Use module mock with factory function
jest.mock('@ai-sdk/openai', () => {
  return {
    openai: jest.fn()
  }
})

jest.mock('ai', () => {
  return {
    streamText: jest.fn(),
    generateText: jest.fn()
  }
})

// Import modules after mocking
import { OpenAIService, OpenAIServiceError, TextGenerationRequestSchema } from './openai-service'
import { openai } from '@ai-sdk/openai'
import { streamText, generateText } from 'ai'

// Cast imported modules to jest mocks for proper typing
const mockOpenai = openai as jest.MockedFunction<typeof openai>
const mockStreamTextFunc = streamText as jest.MockedFunction<typeof streamText>
const mockGenerateTextFunc = generateText as jest.MockedFunction<typeof generateText>

describe('OpenAIService', () => {
  let service: OpenAIService
  let originalApiKey: string | undefined

  beforeEach(() => {
    // Store original API key
    originalApiKey = process.env.OPENAI_API_KEY
    
    // Set test API key
    process.env.OPENAI_API_KEY = 'test-api-key-123'
    
    // Clear all mocks
    jest.clearAllMocks()
    
    // Mock the openai function to return a model object
    mockOpenai.mockReturnValue({
      modelId: 'gpt-4o',
      provider: 'openai'
    } as any)
    
    // Mock streamText to return a proper stream result
    mockStreamTextFunc.mockResolvedValue({
      textStream: {
        [Symbol.asyncIterator]: async function* () {
          yield 'Hello'
          yield ' world'
        }
      },
      finishReason: 'stop',
      usage: { promptTokens: 10, completionTokens: 15 }
    } as any)
    
    // Mock generateText to return proper result
    mockGenerateTextFunc.mockResolvedValue({
      text: 'Generated text',
      usage: { promptTokens: 10, completionTokens: 15 },
      finishReason: 'stop'
    } as any)
    
    // Initialize service
    service = new OpenAIService()
  })

  afterEach(() => {
    // Restore original API key
    if (originalApiKey === undefined) {
      delete process.env.OPENAI_API_KEY
    } else {
      process.env.OPENAI_API_KEY = originalApiKey
    }
  })

  describe('Constructor and Initialization', () => {
    it('should initialize with default config when API key is provided', () => {
      expect(service.isReady()).toBe(true)
      
      const config = service.getConfig()
      expect(config).toEqual({
        model: 'gpt-4o',
        maxTokens: 2048,
        temperature: 0.7,
        maxRetries: 3,
        retryDelay: 1000,
        hasApiKey: true
      })
    })

    it('should accept custom configuration', () => {
      const customService = new OpenAIService({
        model: 'gpt-3.5-turbo',
        maxTokens: 1024,
        temperature: 0.5,
        maxRetries: 5
      })

      const config = customService.getConfig()
      expect(config.model).toBe('gpt-3.5-turbo')
      expect(config.maxTokens).toBe(1024)
      expect(config.temperature).toBe(0.5)
      expect(config.maxRetries).toBe(5)
    })

    it('should throw error when API key is missing', () => {
      delete process.env.OPENAI_API_KEY
      
      expect(() => new OpenAIService()).toThrow(OpenAIServiceError)
      expect(() => new OpenAIService()).toThrow('OpenAI API key is required')
    })

    it('should throw error for invalid temperature', () => {
      expect(() => new OpenAIService({ temperature: -0.1 })).toThrow(OpenAIServiceError)
      expect(() => new OpenAIService({ temperature: 2.1 })).toThrow(OpenAIServiceError)
    })
  })

  describe('TextGenerationRequestSchema', () => {
    it('should validate correct request', () => {
      const validRequest = {
        prompt: 'Test prompt',
        system: 'You are a helpful assistant',
        temperature: 0.8,
        maxTokens: 100
      }

      const result = TextGenerationRequestSchema.parse(validRequest)
      expect(result).toEqual({ ...validRequest, stream: false })
    })

    it('should reject empty prompt', () => {
      const invalidRequest = { prompt: '' }
      
      expect(() => TextGenerationRequestSchema.parse(invalidRequest)).toThrow()
    })

    it('should reject invalid temperature', () => {
      const invalidRequest = { prompt: 'Test', temperature: 3 }
      
      expect(() => TextGenerationRequestSchema.parse(invalidRequest)).toThrow()
    })

    it('should reject invalid maxTokens', () => {
      const invalidRequest = { prompt: 'Test', maxTokens: 0 }
      
      expect(() => TextGenerationRequestSchema.parse(invalidRequest)).toThrow()
    })
  })

  describe('streamText', () => {
    it('should stream text successfully', async () => {
      const request = {
        prompt: 'Say hello',
        system: 'You are helpful',
        temperature: 0.5
      }

      const result = await service.streamText(request)
      expect(result).toBeDefined()

      // Verify correct parameters were passed
      expect(mockStreamTextFunc).toHaveBeenCalledWith({
        model: { modelId: 'gpt-4o', provider: 'openai' },
        prompt: 'Say hello',
        system: 'You are helpful',
        temperature: 0.5,
        maxOutputTokens: 2048,
        maxRetries: 3
      })
    })

    it('should throw error when service not initialized', async () => {
      // Temporarily remove API key from environment
      delete process.env.OPENAI_API_KEY
      
      // Create service without API key should throw in constructor
      expect(() => new OpenAIService({ apiKey: '' })).toThrow(OpenAIServiceError)
      
      // Restore API key for other tests
      process.env.OPENAI_API_KEY = 'test-api-key-123'
    })

    it('should validate request parameters', async () => {
      await expect(
        service.streamText({ prompt: '' } as any)
      ).rejects.toThrow()
    })

    it('should handle API errors gracefully', async () => {
      const apiError = new Error('Rate limit exceeded')
      mockStreamTextFunc.mockRejectedValue(apiError)

      await expect(
        service.streamText({ prompt: 'test' })
      ).rejects.toThrow(OpenAIServiceError)
    })
  })

  describe('generateText', () => {
    it('should generate text successfully', async () => {
      const request = {
        prompt: 'Generate response',
        maxTokens: 100
      }

      const result = await service.generateText(request)
      expect(result).toBeDefined()
      expect(result.text).toBe('Generated text')

      // Verify correct parameters were passed
      expect(mockGenerateTextFunc).toHaveBeenCalledWith({
        model: { modelId: 'gpt-4o', provider: 'openai' },
        prompt: 'Generate response',
        system: undefined,
        temperature: 0.7,
        maxOutputTokens: 100,
        maxRetries: 3
      })
    })

    it('should use default maxTokens when not specified', async () => {
      await service.generateText({ prompt: 'test' })

      expect(mockGenerateTextFunc).toHaveBeenCalledWith(
        expect.objectContaining({
          maxOutputTokens: 2048 // default value
        })
      )
    })
  })

  describe('Error Handling', () => {
    it('should handle API key errors', async () => {
      const error = new Error('Invalid API key')
      mockGenerateTextFunc.mockRejectedValue(error)

      const thrown = await service.generateText({ prompt: 'test' }).catch(e => e)
      expect(thrown).toBeInstanceOf(OpenAIServiceError)
      expect(thrown.message).toContain('Invalid or missing API key')
    })

    it('should handle rate limit errors', async () => {
      const error = new Error('Rate limit exceeded')
      mockGenerateTextFunc.mockRejectedValue(error)

      const thrown = await service.generateText({ prompt: 'test' }).catch(e => e)
      expect(thrown).toBeInstanceOf(OpenAIServiceError)
      expect(thrown.code).toBe('RATE_LIMIT')
      expect(thrown.statusCode).toBe(429)
    })

    it('should handle timeout errors', async () => {
      const error = new Error('Request timeout')
      mockGenerateTextFunc.mockRejectedValue(error)

      const thrown = await service.generateText({ prompt: 'test' }).catch(e => e)
      expect(thrown).toBeInstanceOf(OpenAIServiceError)
      expect(thrown.code).toBe('TIMEOUT')
      expect(thrown.statusCode).toBe(408)
    })

    it('should handle model not found errors', async () => {
      const error = new Error('Model gpt-5 not found')
      mockGenerateTextFunc.mockRejectedValue(error)

      const thrown = await service.generateText({ prompt: 'test' }).catch(e => e)
      expect(thrown).toBeInstanceOf(OpenAIServiceError)
      expect(thrown.code).toBe('MODEL_NOT_FOUND')
      expect(thrown.statusCode).toBe(404)
    })

    it('should handle unknown errors', async () => {
      const error = 'Unknown error string'
      mockGenerateTextFunc.mockRejectedValue(error)

      const thrown = await service.generateText({ prompt: 'test' }).catch(e => e)
      expect(thrown).toBeInstanceOf(OpenAIServiceError)
      expect(thrown.code).toBe('UNKNOWN_ERROR')
    })
  })

  describe('testConnection', () => {
    it('should return true for successful connection', async () => {
      mockGenerateTextFunc.mockResolvedValue({ text: 'Test successful' })

      const result = await service.testConnection()
      expect(result).toBe(true)
    })

    it('should return false for failed connection', async () => {
      mockGenerateTextFunc.mockRejectedValue(new Error('Connection failed'))

      const result = await service.testConnection()
      expect(result).toBe(false)
    })

    it('should return false for unexpected response', async () => {
      mockGenerateTextFunc.mockResolvedValue({ text: 'Unexpected response' })

      const result = await service.testConnection()
      expect(result).toBe(false)
    })
  })

  describe('Configuration Management', () => {
    it('should update configuration', () => {
      service.updateConfig({
        model: 'gpt-3.5-turbo',
        temperature: 0.9
      })

      const config = service.getConfig()
      expect(config.model).toBe('gpt-3.5-turbo')
      expect(config.temperature).toBe(0.9)
    })

    it('should validate updated configuration', () => {
      expect(() => {
        service.updateConfig({ temperature: 3 })
      }).toThrow(OpenAIServiceError)
    })

    it('should not expose API key in getConfig', () => {
      const config = service.getConfig()
      expect(config).not.toHaveProperty('apiKey')
      expect(config.hasApiKey).toBe(true)
    })
  })

  describe('Request Validation', () => {
    it('should handle messages array correctly', async () => {
      const request = {
        prompt: 'test',
        messages: [
          { role: 'user' as const, content: 'Hello' },
          { role: 'assistant' as const, content: 'Hi there!' }
        ]
      }

      await service.generateText(request)

      expect(mockGenerateTextFunc).toHaveBeenCalledWith(
        expect.objectContaining({
          messages: request.messages
        })
      )
    })

    it('should reject invalid message roles', async () => {
      const request = {
        prompt: 'test',
        messages: [
          { role: 'invalid' as any, content: 'Hello' }
        ]
      }

      await expect(
        service.generateText(request)
      ).rejects.toThrow()
    })
  })
})