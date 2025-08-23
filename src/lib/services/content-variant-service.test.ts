import { ContentType } from '@/lib/types/content-generation'

import { ContentVariantService } from './content-variant-service'
import { openAIService } from './openai-service'

// Mock the OpenAI service
jest.mock('./openai-service', () => ({
  openAIService: {
    instance: {
      generateText: jest.fn()
    }
  }
}))

const mockGenerateText = openAIService.instance.generateText as jest.MockedFunction<typeof openAIService.instance.generateText>

describe('ContentVariantService', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('generateEnhancedVariants', () => {
    it('should generate enhanced variants with different strategies', async () => {
      // Mock OpenAI responses
      mockGenerateText
        .mockResolvedValueOnce({ text: 'Style variation content for email marketing.' })
        .mockResolvedValueOnce({ text: 'Angle variation content with different perspective.' })

      const originalContent = 'Original email content with great value proposition.'
      const brandContext = 'Brand: Test Company\nVoice: Professional\nValues: Innovation'

      const variants = await ContentVariantService.generateEnhancedVariants(
        originalContent,
        ContentType.EMAIL,
        3, // Original + 2 variants
        brandContext,
        {
          strategies: ['style_variation', 'angle_variation'],
          currentTone: 'professional',
          businessGoal: 'engagement',
          targetAudience: 'professionals'
        }
      )

      expect(variants).toHaveLength(2)
      expect(variants[0].content).toBe('Style variation content for email marketing.')
      expect(variants[0].strategy).toBe('style_variation')
      expect(variants[1].content).toBe('Angle variation content with different perspective.')
      expect(variants[1].strategy).toBe('angle_variation')
      
      // Check that metrics are calculated
      expect(variants[0].metrics).toBeDefined()
      expect(variants[0].metrics?.readabilityScore).toBeGreaterThanOrEqual(0)
      expect(variants[0].metrics?.estimatedEngagement).toBeGreaterThanOrEqual(0)
      
      // Check format optimizations
      expect(variants[0].formatOptimizations).toBeDefined()
      expect(variants[0].formatOptimizations?.characterCount).toBeGreaterThan(0)
      expect(variants[0].formatOptimizations?.wordCount).toBeGreaterThan(0)
    })

    it('should return empty array when variantCount is 1 or less', async () => {
      const variants = await ContentVariantService.generateEnhancedVariants(
        'Test content',
        ContentType.EMAIL,
        1,
        'Brand context'
      )

      expect(variants).toHaveLength(0)
      expect(mockGenerateText).not.toHaveBeenCalled()
    })

    it('should handle OpenAI service errors gracefully', async () => {
      mockGenerateText.mockRejectedValue(new Error('API Error'))

      const variants = await ContentVariantService.generateEnhancedVariants(
        'Original content',
        ContentType.SOCIAL_POST,
        2,
        'Brand context'
      )

      expect(variants).toHaveLength(0)
    })

    it('should use default strategies when none provided', async () => {
      mockGenerateText.mockResolvedValueOnce({ text: 'Generated variant' })

      const variants = await ContentVariantService.generateEnhancedVariants(
        'Original content',
        ContentType.BLOG_POST,
        2,
        'Brand context'
      )

      expect(mockGenerateText).toHaveBeenCalledWith(
        expect.objectContaining({
          prompt: expect.stringContaining('style variation'),
          temperature: 0.8
        })
      )
    })

    it('should generate multiple variants when requested count exceeds strategy count', async () => {
      mockGenerateText
        .mockResolvedValueOnce({ text: 'First variant' })
        .mockResolvedValueOnce({ text: 'Second variant' })
        .mockResolvedValueOnce({ text: 'Third variant' })

      const variants = await ContentVariantService.generateEnhancedVariants(
        'Original content',
        ContentType.SOCIAL_POST,
        4, // Original + 3 variants
        'Brand context',
        {
          strategies: ['style_variation', 'tone_variation'] // Only 2 strategies but need 3 variants
        }
      )

      expect(variants).toHaveLength(3)
      expect(mockGenerateText).toHaveBeenCalledTimes(3)
    })
  })

  describe('generateTemplatedContent', () => {
    it('should generate content using format-specific templates', async () => {
      mockGenerateText.mockResolvedValueOnce({ 
        text: 'Subject: Welcome to our service\n\nHi there,\n\nWelcome to our amazing platform!\n\nClick here to get started\n\nBest regards,\nThe Team'
      })

      const content = await ContentVariantService.generateTemplatedContent(
        ContentType.EMAIL,
        'Generate a welcome email',
        'Brand: Test Company\nVoice: Friendly'
      )

      expect(mockGenerateText).toHaveBeenCalledWith(
        expect.objectContaining({
          prompt: expect.stringContaining('TEMPLATE:'),
          temperature: 0.7,
          maxTokens: expect.any(Number)
        })
      )
      
      expect(content).toContain('Subject:')
      expect(content).toContain('Welcome')
    })

    it('should handle template generation errors', async () => {
      mockGenerateText.mockRejectedValue(new Error('Template generation failed'))

      await expect(
        ContentVariantService.generateTemplatedContent(
          ContentType.SOCIAL_POST,
          'Generate social post',
          'Brand context'
        )
      ).rejects.toThrow('Template generation failed')
    })
  })

  describe('getFormatTemplate', () => {
    it('should return correct template for EMAIL content type', () => {
      const template = ContentVariantService.getFormatTemplate(ContentType.EMAIL)
      
      expect(template.type).toBe(ContentType.EMAIL)
      expect(template.name).toBe('Email Marketing Template')
      expect(template.template).toContain('{{subject}}')
      expect(template.placeholders).toContain('subject')
      expect(template.optimizations.maxCharacters).toBe(3000)
      expect(template.optimizations.requiredElements).toContain('subject')
    })

    it('should return correct template for SOCIAL_POST content type', () => {
      const template = ContentVariantService.getFormatTemplate(ContentType.SOCIAL_POST)
      
      expect(template.type).toBe(ContentType.SOCIAL_POST)
      expect(template.optimizations.maxCharacters).toBe(280)
      expect(template.optimizations.requiredElements).toContain('engaging_hook')
      expect(template.optimizations.platforms).toContain('twitter')
    })

    it('should return templates for all supported content types', () => {
      const contentTypes = [
        ContentType.EMAIL, ContentType.SOCIAL_POST, ContentType.SOCIAL_AD,
        ContentType.SEARCH_AD, ContentType.BLOG_POST, ContentType.LANDING_PAGE,
        ContentType.VIDEO_SCRIPT, ContentType.INFOGRAPHIC, ContentType.NEWSLETTER,
        ContentType.PRESS_RELEASE
      ]

      contentTypes.forEach(type => {
        const template = ContentVariantService.getFormatTemplate(type)
        expect(template.type).toBe(type)
        expect(template.template).toBeDefined()
        expect(template.optimizations).toBeDefined()
        expect(Array.isArray(template.placeholders)).toBe(true)
        expect(Array.isArray(template.examples)).toBe(true)
      })
    })
  })

  describe('getVariantStrategies', () => {
    it('should return all available variant strategies', () => {
      const strategies = ContentVariantService.getVariantStrategies()
      
      expect(strategies).toHaveProperty('style_variation')
      expect(strategies).toHaveProperty('length_variation')
      expect(strategies).toHaveProperty('angle_variation')
      expect(strategies).toHaveProperty('tone_variation')
      expect(strategies).toHaveProperty('cta_variation')

      // Check strategy structure
      const styleVariation = strategies.style_variation
      expect(styleVariation.name).toBe('style_variation')
      expect(styleVariation.description).toBeDefined()
      expect(styleVariation.prompt).toBeDefined()
      expect(styleVariation.temperature).toBeGreaterThan(0)
      expect(styleVariation.temperature).toBeLessThanOrEqual(2)
    })

    it('should have unique prompts for each strategy', () => {
      const strategies = ContentVariantService.getVariantStrategies()
      const prompts = Object.values(strategies).map(s => s.prompt)
      const uniquePrompts = new Set(prompts)
      
      expect(uniquePrompts.size).toBe(prompts.length)
    })

    it('should have appropriate temperature settings for each strategy', () => {
      const strategies = ContentVariantService.getVariantStrategies()
      
      // Style variation should have higher temperature for creativity
      expect(strategies.style_variation.temperature).toBe(0.8)
      
      // Length variation should be more controlled
      expect(strategies.length_variation.temperature).toBe(0.6)
      
      // Angle variation should be most creative
      expect(strategies.angle_variation.temperature).toBe(0.9)
    })
  })

  describe('metrics calculation', () => {
    it('should calculate engagement scores based on content characteristics', async () => {
      // Mock with content that should score well on engagement
      mockGenerateText.mockResolvedValueOnce({ 
        text: 'Did you know? This amazing offer is exclusively for you! Click here to save 50% today!' 
      })

      const variants = await ContentVariantService.generateEnhancedVariants(
        'Original content',
        ContentType.SOCIAL_AD,
        2,
        'Brand context'
      )

      const metrics = variants[0].metrics
      expect(metrics?.estimatedEngagement).toBeGreaterThan(50) // Should score well due to question, personalization, value words, CTA
    })

    it('should calculate readability scores appropriately', async () => {
      // Mock with simple, readable content
      mockGenerateText.mockResolvedValueOnce({ 
        text: 'This is simple. Easy to read. Short words. Clear message.' 
      })

      const variants = await ContentVariantService.generateEnhancedVariants(
        'Original content',
        ContentType.EMAIL,
        2,
        'Brand context'
      )

      const metrics = variants[0].metrics
      expect(metrics?.readabilityScore).toBeGreaterThan(50) // Should be readable
    })

    it('should identify format optimizations correctly', async () => {
      // Mock social media content with hashtags and CTA
      mockGenerateText.mockResolvedValueOnce({ 
        text: 'Check out our new product! #innovation #tech Click here to learn more' 
      })

      const variants = await ContentVariantService.generateEnhancedVariants(
        'Original content',
        ContentType.SOCIAL_POST,
        2,
        'Brand context'
      )

      const formatOpt = variants[0].formatOptimizations
      expect(formatOpt?.hasHashtags).toBe(true)
      expect(formatOpt?.hasCTA).toBe(true)
      expect(formatOpt?.characterCount).toBeGreaterThan(0)
      expect(formatOpt?.wordCount).toBeGreaterThan(0)
    })
  })

  describe('error handling and edge cases', () => {
    it('should handle empty or invalid content gracefully', async () => {
      mockGenerateText.mockResolvedValueOnce({ text: '' })

      const variants = await ContentVariantService.generateEnhancedVariants(
        '',
        ContentType.EMAIL,
        2,
        'Brand context'
      )

      expect(variants).toHaveLength(1) // Should still create a variant entry even if empty
      expect(variants[0].metrics?.estimatedEngagement).toBeLessThan(50) // Low score for empty content
    })

    it('should handle missing brand context', async () => {
      mockGenerateText.mockResolvedValueOnce({ text: 'Generated content without brand context' })

      const variants = await ContentVariantService.generateEnhancedVariants(
        'Original content',
        ContentType.BLOG_POST,
        2,
        '' // Empty brand context
      )

      expect(variants).toHaveLength(1)
      expect(mockGenerateText).toHaveBeenCalledWith(
        expect.objectContaining({
          prompt: expect.stringContaining('Brand context: ')
        })
      )
    })

    it('should validate content against format requirements', async () => {
      // Mock content that exceeds social post limits
      const longContent = 'A'.repeat(300)
      mockGenerateText.mockResolvedValueOnce({ text: longContent })

      const variants = await ContentVariantService.generateEnhancedVariants(
        'Original content',
        ContentType.SOCIAL_POST, // Max 280 characters
        2,
        'Brand context'
      )

      const formatOpt = variants[0].formatOptimizations
      expect(formatOpt?.characterCount).toBe(300)
      
      // Format optimization score should be lower due to length violation
      const metrics = variants[0].metrics
      expect(metrics?.formatOptimization).toBeLessThan(100)
    })
  })
})