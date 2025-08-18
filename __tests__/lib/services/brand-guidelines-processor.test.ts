import { BrandGuidelinesProcessor, BrandGuidelinesProcessingSettings } from '@/lib/services/brand-guidelines-processor'

describe('BrandGuidelinesProcessor', () => {
  const mockText = `
    Brand Guidelines Document
    
    Brand Overview
    Our brand represents innovation and reliability in the technology sector.
    
    Color Palette
    Primary Colors: #007bff (Brand Blue), #28a745 (Success Green), #dc3545 (Alert Red)
    Secondary Colors: #6c757d (Neutral Gray), #f8f9fa (Light Background)
    Pantone 286 C for print materials
    
    Typography Guidelines
    Primary font is "Helvetica Neue", Arial, sans-serif for headers
    Body text should use "Source Sans Pro", Georgia, serif for body content
    
    Voice and Tone
    Our brand voice is professional yet approachable, confident but not arrogant.
    We communicate in a conversational style that builds trust with our audience.
    Brand personality: Innovative, reliable, trustworthy, modern, and customer-focused.
    
    Usage Guidelines
    Always use the primary logo on white backgrounds.
    Never distort or modify the logo proportions.
    Maintain minimum clear space of 20px around the logo.
    
    Compliance Requirements
    All marketing materials must be approved by the brand team.
    Copyright notice must appear on all published materials.
    Do not use competitor names in marketing copy.
    Avoid terms like "best" or "perfect" without substantiation.
  `

  const mockAssetId = 'test-asset-123'
  const mockBrandId = 'test-brand-456'

  describe('processBrandGuidelines', () => {
    it('should extract colors with proper categorization', async () => {
      const settings: BrandGuidelinesProcessingSettings = {
        extractColors: true,
        extractFonts: false,
        extractVoice: false,
        extractGuidelines: false,
        extractCompliance: false,
      }

      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        mockText,
        mockAssetId,
        mockBrandId,
        settings
      )

      expect(result.colors).toBeDefined()
      expect(result.colors!.length).toBeGreaterThan(0)
      
      // Check for hex colors
      const hexColors = result.colors!.filter(c => c.hex)
      expect(hexColors.length).toBeGreaterThan(0)
      expect(hexColors.some(c => c.hex === '#007BFF')).toBe(true)
      
      // Check for Pantone colors
      const pantoneColors = result.colors!.filter(c => c.pantone)
      expect(pantoneColors.length).toBeGreaterThan(0)
    })

    it('should extract fonts with categorization', async () => {
      const settings: BrandGuidelinesProcessingSettings = {
        extractColors: false,
        extractFonts: true,
        extractVoice: false,
        extractGuidelines: false,
        extractCompliance: false,
      }

      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        mockText,
        mockAssetId,
        mockBrandId,
        settings
      )

      expect(result.fonts).toBeDefined()
      expect(result.fonts!.length).toBeGreaterThan(0)
      
      const helveticaFont = result.fonts!.find(f => f.family.includes('Helvetica'))
      expect(helveticaFont).toBeDefined()
      expect(helveticaFont!.category).toBe('sans-serif')
      
      const georgiaFont = result.fonts!.find(f => f.family.includes('Georgia'))
      expect(georgiaFont).toBeDefined()
      expect(georgiaFont!.category).toBe('serif')
    })

    it('should extract voice and tone attributes', async () => {
      const settings: BrandGuidelinesProcessingSettings = {
        extractColors: false,
        extractFonts: false,
        extractVoice: true,
        extractGuidelines: false,
        extractCompliance: false,
      }

      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        mockText,
        mockAssetId,
        mockBrandId,
        settings
      )

      expect(result.voice).toBeDefined()
      expect(result.voice!.voiceDescription).toBeTruthy()
      expect(result.voice!.toneAttributes).toBeDefined()
      expect(Object.keys(result.voice!.toneAttributes).length).toBeGreaterThan(0)
      expect(result.voice!.personality).toContain('innovative')
      expect(result.voice!.personality).toContain('reliable')
      expect(result.voice!.communicationStyle).toBe('conversational')
    })

    it('should extract structured guidelines', async () => {
      const settings: BrandGuidelinesProcessingSettings = {
        extractColors: false,
        extractFonts: false,
        extractVoice: false,
        extractGuidelines: true,
        extractCompliance: false,
      }

      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        mockText,
        mockAssetId,
        mockBrandId,
        settings
      )

      expect(result.guidelines).toBeDefined()
      expect(result.guidelines!.sections).toBeDefined()
      expect(result.guidelines!.sections.length).toBeGreaterThan(0)
      
      const overviewSection = result.guidelines!.sections.find(s => s.type === 'overview')
      expect(overviewSection).toBeDefined()
      
      const visualSection = result.guidelines!.sections.find(s => s.type === 'visual')
      expect(visualSection).toBeDefined()
      
      expect(result.guidelines!.keyPhrases.length).toBeGreaterThan(0)
    })

    it('should extract compliance rules', async () => {
      const settings: BrandGuidelinesProcessingSettings = {
        extractColors: false,
        extractFonts: false,
        extractVoice: false,
        extractGuidelines: false,
        extractCompliance: true,
      }

      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        mockText,
        mockAssetId,
        mockBrandId,
        settings
      )

      expect(result.compliance).toBeDefined()
      expect(result.compliance!.usageRules.do.length).toBeGreaterThan(0)
      expect(result.compliance!.usageRules.dont.length).toBeGreaterThan(0)
      expect(result.compliance!.legalRequirements.length).toBeGreaterThan(0)
    })

    it('should calculate confidence scores', async () => {
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        mockText,
        mockAssetId,
        mockBrandId
      )

      expect(result.confidence).toBeDefined()
      expect(result.confidence.overall).toBeGreaterThan(0)
      expect(result.confidence.overall).toBeLessThanOrEqual(100)
      expect(result.confidence.colors).toBeGreaterThan(0)
      expect(result.confidence.fonts).toBeGreaterThan(0)
      expect(result.confidence.voice).toBeGreaterThan(0)
      expect(result.confidence.guidelines).toBeGreaterThan(0)
      expect(result.confidence.compliance).toBeGreaterThan(0)
    })

    it('should generate improvement suggestions', async () => {
      const minimalText = "Just a short brand description."
      
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        minimalText,
        mockAssetId,
        mockBrandId
      )

      expect(result.suggestions).toBeDefined()
      expect(result.suggestions.length).toBeGreaterThan(0)
      expect(result.suggestions.some(s => s.includes('color'))).toBe(true)
      expect(result.suggestions.some(s => s.includes('typography') || s.includes('font'))).toBe(true)
    })

    it('should include all required fields in result', async () => {
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        mockText,
        mockAssetId,
        mockBrandId
      )

      expect(result.rawText).toBe(mockText)
      expect(result.extractedAt).toBeTruthy()
      expect(result.assetId).toBe(mockAssetId)
      expect(result.brandId).toBe(mockBrandId)
      expect(result.confidence).toBeDefined()
      expect(result.suggestions).toBeDefined()
    })
  })

  describe('parseDocumentContent', () => {
    it('should parse plain text', async () => {
      const buffer = Buffer.from('Test content', 'utf-8')
      const result = await BrandGuidelinesProcessor.parseDocumentContent(buffer, 'text/plain')
      expect(result).toBe('Test content')
    })

    it('should handle unknown mime types as text', async () => {
      const buffer = Buffer.from('Test content', 'utf-8')
      const result = await BrandGuidelinesProcessor.parseDocumentContent(buffer, 'unknown/type')
      expect(result).toBe('Test content')
    })

    it('should throw error for unsupported operations', async () => {
      const buffer = Buffer.from('invalid pdf data')
      await expect(
        BrandGuidelinesProcessor.parseDocumentContent(buffer, 'application/pdf')
      ).rejects.toThrow()
    })
  })
})