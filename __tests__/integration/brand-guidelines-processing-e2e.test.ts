import { BrandService } from '@/lib/api/brands'
import { BrandGuidelinesProcessor } from '@/lib/services/brand-guidelines-processor'

// Integration test that validates the complete flow
describe('Brand Guidelines Processing End-to-End', () => {
  // Mock the actual network calls for integration testing
  const mockFetch = jest.fn()
  global.fetch = mockFetch

  const testBrandGuidelines = `
    # TechCorp Brand Guidelines

    ## Company Overview
    TechCorp is a leading provider of innovative technology solutions for enterprise clients.
    Our mission is to empower businesses through reliable, cutting-edge technology.

    ## Visual Identity

    ### Brand Colors
    Primary Colors:
    - TechCorp Blue: #0066CC (Pantone 286 C) - Primary brand color for logos and headers
    - Innovation Green: #28A745 (RGB: 40, 167, 69) - Success states and positive messaging
    - Alert Orange: #FF8C00 (HSL: 33, 100%, 50%) - Warning states and call-to-action elements
    - Error Red: #DC3545 (CMYK: 0, 75, 67, 14) - Error states and critical alerts

    Supporting Colors:
    - Neutral Gray: #6C757D - Text and secondary elements
    - Light Background: #F8F9FA - Page backgrounds and content areas
    - Dark Text: #212529 - Primary text color

    ### Typography System
    Primary Typeface: "Inter", "Helvetica Neue", Arial, sans-serif
    - Use for headlines, navigation, and primary UI elements
    - Weights: 400 (Regular), 500 (Medium), 600 (Semi-Bold), 700 (Bold)

    Secondary Typeface: "Source Sans Pro", Georgia, serif
    - Use for body text, descriptions, and secondary content
    - Weights: 400 (Regular), 600 (Semi-Bold)

    Monospace: "Fira Code", "Courier New", Monaco, monospace
    - Use for code blocks, technical specifications, and data displays

    ## Brand Voice & Personality

    ### Voice Description
    TechCorp's brand voice is professional yet approachable, authoritative but not intimidating.
    We communicate with confidence while maintaining accessibility for all audience levels.

    ### Tone Attributes
    - Professional: Demonstrates expertise and competence
    - Innovative: Shows forward-thinking and cutting-edge approaches
    - Trustworthy: Builds confidence through transparency and reliability
    - Approachable: Remains accessible and human-centered
    - Confident: Speaks with authority about our capabilities

    ### Communication Style
    We use a conversational tone that balances technical accuracy with clear communication.
    Our style is direct and informative while remaining engaging and supportive.

    ### Brand Personality
    - Innovative: Embracing new technologies and methodologies
    - Reliable: Consistently delivering on promises and commitments
    - Trustworthy: Building long-term relationships through transparency
    - Expert: Demonstrating deep technical knowledge and industry insight
    - Customer-focused: Prioritizing client success and satisfaction

    ## Usage Guidelines

    ### Logo Requirements
    - Always use the primary logo on white or light backgrounds
    - Maintain minimum clear space of 32px on all sides
    - Never scale the logo smaller than 120px width in digital applications
    - Never scale the logo smaller than 1 inch width in print applications

    ### Color Usage Rules
    - Use TechCorp Blue for primary brand elements and headers
    - Use Innovation Green for success states and positive messaging
    - Maintain WCAG AA contrast ratios for accessibility
    - Never use colors outside the approved palette without approval

    ### Typography Guidelines
    - Always use approved fonts for all branded communications
    - Maintain consistent hierarchy with font weights and sizes
    - Ensure proper line spacing for readability (1.5x minimum)
    - Never use decorative or script fonts for body text

    ## Compliance & Legal

    ### Usage Rules
    DO:
    - Always maintain brand consistency across all touchpoints
    - Use approved fonts and colors for all communications
    - Include proper copyright notices on all materials
    - Ensure accessibility compliance in all digital products
    - Get brand team approval before launching new campaigns

    DON'T:
    - Never distort, rotate, or modify the logo proportions
    - Do not use competitor names in marketing materials without legal review
    - Avoid using unauthorized colors or fonts
    - Never use trademarked terms without proper attribution
    - Do not create unauthorized brand extensions or variations

    ### Legal Requirements
    - Copyright notice required: "© 2023 TechCorp. All rights reserved."
    - Trademark symbols must be used on first mention of branded terms
    - Privacy policy links required on all digital communications
    - Data protection disclaimers required for forms and surveys

    ### Restricted Terms
    Avoid using these terms without substantiation:
    - "Best in class" or "industry leading" without supporting data
    - "Revolutionary" or "game-changing" without context
    - "Guaranteed" or "100% effective" without qualifications
    - Competitor product names without legal approval

    ### Approval Process
    All brand materials require review and approval:
    - Marketing materials: Brand Manager approval required
    - External communications: Marketing Director approval required
    - Press releases: Legal and Executive team approval required
    - Social media: Marketing team review and approval required

    ## Target Audience

    ### Primary Audience
    Technology decision-makers in enterprise organizations seeking reliable solutions.

    ### Demographics
    - Age range: 35-55 years
    - Job titles: Chief Technology Officer, IT Director, Technology Manager, Systems Administrator
    - Company size: 500-10,000+ employees
    - Industries: Healthcare, Financial Services, Manufacturing, Professional Services, Government

    ### Psychographics
    - Value reliability and proven track records
    - Seek innovative solutions to complex problems
    - Require detailed technical specifications and documentation
    - Prioritize security, compliance, and scalability
    - Prefer working with established, trustworthy vendors
  `

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Complete Processing Workflow', () => {
    it('should process comprehensive brand guidelines through the entire pipeline', async () => {
      // Mock successful API responses
      mockFetch
        .mockResolvedValueOnce({
          // Mock file fetch
          ok: true,
          arrayBuffer: () => Promise.resolve(Buffer.from(testBrandGuidelines).buffer)
        })
        .mockResolvedValueOnce({
          // Mock API parse response
          ok: true,
          json: () => Promise.resolve({
            success: true,
            extractedData: expect.any(Object),
            message: expect.stringContaining('confidence'),
            processingInfo: expect.any(Object)
          })
        })

      // Test direct processor
      const processorResult = await BrandGuidelinesProcessor.processBrandGuidelines(
        testBrandGuidelines,
        'test-asset-123',
        'test-brand-456'
      )

      // Validate comprehensive extraction
      expect(processorResult).toMatchObject({
        rawText: testBrandGuidelines,
        assetId: 'test-asset-123',
        brandId: 'test-brand-456',
        extractedAt: expect.any(String),
        confidence: expect.objectContaining({
          overall: expect.any(Number),
          colors: expect.any(Number),
          fonts: expect.any(Number),
          voice: expect.any(Number),
          guidelines: expect.any(Number),
          compliance: expect.any(Number)
        }),
        suggestions: expect.any(Array)
      })

      // Validate color extraction
      expect(processorResult.colors).toBeDefined()
      expect(processorResult.colors!.length).toBeGreaterThan(6)
      
      const colors = processorResult.colors!
      expect(colors.some(c => c.hex === '#0066CC')).toBe(true)
      expect(colors.some(c => c.pantone === '286 C')).toBe(true)
      // Check that colors have at least hex values
      expect(colors.every(c => c.hex)).toBe(true)

      // Validate font extraction
      expect(processorResult.fonts).toBeDefined()
      expect(processorResult.fonts!.length).toBeGreaterThan(2)
      
      const fonts = processorResult.fonts!
      expect(fonts.some(f => f.family.includes('Inter'))).toBe(true)
      expect(fonts.some(f => f.family.includes('Source Sans Pro'))).toBe(true)
      expect(fonts.some(f => f.family.includes('Fira Code'))).toBe(true)
      expect(fonts.some(f => f.category === 'sans-serif')).toBe(true)
      expect(fonts.some(f => f.category === 'serif')).toBe(true)
      expect(fonts.some(f => f.category === 'monospace')).toBe(true)

      // Validate voice extraction
      expect(processorResult.voice).toBeDefined()
      const voice = processorResult.voice!
      expect(voice.voiceDescription).toContain('professional')
      expect(voice.voiceDescription).toContain('approachable')
      expect(voice.communicationStyle).toBe('conversational')
      expect(voice.personality).toContain('innovative')
      expect(voice.personality).toContain('reliable')
      expect(voice.personality).toContain('trustworthy')
      expect(voice.toneAttributes.professional).toBeGreaterThan(0)
      expect(voice.toneAttributes.innovative).toBeGreaterThan(0)
      expect(voice.toneAttributes.trustworthy).toBeGreaterThan(0)

      // Validate guidelines extraction
      expect(processorResult.guidelines).toBeDefined()
      const guidelines = processorResult.guidelines!
      expect(guidelines.sections.length).toBeGreaterThan(5)
      expect(guidelines.sections.some(s => s.type === 'overview')).toBe(true)
      expect(guidelines.sections.some(s => s.type === 'visual')).toBe(true)
      expect(guidelines.sections.some(s => s.type === 'voice')).toBe(true)
      expect(guidelines.sections.some(s => s.type === 'usage')).toBe(true)
      expect(guidelines.sections.some(s => s.type === 'compliance')).toBe(true)
      expect(guidelines.keyPhrases.length).toBeGreaterThan(5)

      // Validate compliance extraction
      expect(processorResult.compliance).toBeDefined()
      const compliance = processorResult.compliance!
      expect(compliance.usageRules.do.length).toBeGreaterThan(4)
      expect(compliance.usageRules.dont.length).toBeGreaterThan(4)
      expect(compliance.legalRequirements.length).toBeGreaterThan(3)
      expect(compliance.restrictedTerms.length).toBeGreaterThan(3)
      expect(compliance.approvalProcess).toContain('approval')

      // Validate confidence scores
      expect(processorResult.confidence.overall).toBeGreaterThan(80)
      expect(processorResult.confidence.colors).toBeGreaterThan(75)
      expect(processorResult.confidence.fonts).toBeGreaterThan(70)
      expect(processorResult.confidence.voice).toBeGreaterThan(70)
      expect(processorResult.confidence.guidelines).toBeGreaterThan(75)
      expect(processorResult.confidence.compliance).toBeGreaterThan(75)
    })

    it('should handle selective extraction settings', async () => {
      // Test only color extraction
      const colorOnlyResult = await BrandGuidelinesProcessor.processBrandGuidelines(
        testBrandGuidelines,
        'test-asset-123',
        'test-brand-456',
        {
          extractColors: true,
          extractFonts: false,
          extractVoice: false,
          extractGuidelines: false,
          extractCompliance: false
        }
      )

      expect(colorOnlyResult.colors).toBeDefined()
      expect(colorOnlyResult.fonts).toBeUndefined()
      expect(colorOnlyResult.voice).toBeUndefined()
      expect(colorOnlyResult.guidelines).toBeUndefined()
      expect(colorOnlyResult.compliance).toBeUndefined()

      // Test only voice extraction
      const voiceOnlyResult = await BrandGuidelinesProcessor.processBrandGuidelines(
        testBrandGuidelines,
        'test-asset-123',
        'test-brand-456',
        {
          extractColors: false,
          extractFonts: false,
          extractVoice: true,
          extractGuidelines: false,
          extractCompliance: false
        }
      )

      expect(voiceOnlyResult.colors).toBeUndefined()
      expect(voiceOnlyResult.voice).toBeDefined()
      expect(voiceOnlyResult.voice!.personality.length).toBeGreaterThan(3)
    })

    it('should provide meaningful confidence scores based on content quality', async () => {
      // Test with comprehensive content
      const comprehensiveResult = await BrandGuidelinesProcessor.processBrandGuidelines(
        testBrandGuidelines,
        'test-asset-123',
        'test-brand-456'
      )

      // Test with minimal content
      const minimalContent = "Our brand is blue. We use Arial font."
      const minimalResult = await BrandGuidelinesProcessor.processBrandGuidelines(
        minimalContent,
        'test-asset-456',
        'test-brand-789'
      )

      // Comprehensive content should have higher confidence
      expect(comprehensiveResult.confidence.overall).toBeGreaterThan(
        minimalResult.confidence.overall + 30
      )
      expect(comprehensiveResult.confidence.colors).toBeGreaterThan(
        minimalResult.confidence.colors + 20
      )
      expect(comprehensiveResult.confidence.voice).toBeGreaterThan(
        minimalResult.confidence.voice + 40
      )

      // Minimal content should have more suggestions
      expect(minimalResult.suggestions.length).toBeGreaterThan(
        comprehensiveResult.suggestions.length
      )
    })

    it('should generate contextual suggestions for improvement', async () => {
      const testCases = [
        {
          content: "Our brand uses blue color.",
          expectedSuggestions: ['typography', 'font', 'voice', 'usage', 'compliance']
        },
        {
          content: "Colors: #007bff. Fonts: Arial. Voice: professional.",
          expectedSuggestions: ['usage', 'compliance', 'guidelines']
        },
        {
          content: testBrandGuidelines,
          expectedSuggestions: [] // Comprehensive content should have fewer suggestions
        }
      ]

      for (const testCase of testCases) {
        const result = await BrandGuidelinesProcessor.processBrandGuidelines(
          testCase.content,
          'test-asset',
          'test-brand'
        )

        if (testCase.expectedSuggestions.length === 0) {
          expect(result.suggestions.length).toBeLessThan(3)
        } else {
          const suggestionText = result.suggestions.join(' ').toLowerCase()
          testCase.expectedSuggestions.forEach(keyword => {
            expect(suggestionText).toContain(keyword)
          })
        }
      }
    })
  })

  describe('Error Handling and Edge Cases', () => {
    it('should handle parsing errors gracefully', async () => {
      // Mock parsing error
      jest.spyOn(BrandGuidelinesProcessor, 'parseDocumentContent')
        .mockRejectedValueOnce(new Error('Parsing failed'))

      // Should fall back to sample data processing
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        'fallback content',
        'test-asset',
        'test-brand'
      )

      expect(result.rawText).toBe('fallback content')
      expect(result.confidence.overall).toBeGreaterThanOrEqual(0)
    })

    it('should handle malformed input gracefully', async () => {
      const malformedInputs = [
        '', // Empty string
        '   ', // Whitespace only
        'Invalid color: #gggggg and bad font: 123font', // Invalid patterns
        'A'.repeat(100000), // Very large input
        '🎨🎭🎪🎯🎲🎸🎺🎻', // Unicode/emoji only
      ]

      for (const input of malformedInputs) {
        const result = await BrandGuidelinesProcessor.processBrandGuidelines(
          input,
          'test-asset',
          'test-brand'
        )

        expect(result).toBeDefined()
        expect(result.rawText).toBe(input)
        expect(result.confidence).toBeDefined()
        expect(result.suggestions).toBeDefined()
        expect(Array.isArray(result.suggestions)).toBe(true)
      }
    })

    it('should maintain performance with large documents', async () => {
      // Create large document
      const largeDocument = testBrandGuidelines.repeat(100) // ~500KB document

      const startTime = Date.now()
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        largeDocument,
        'test-asset',
        'test-brand'
      )
      const endTime = Date.now()

      // Should complete within reasonable time (5 seconds)
      expect(endTime - startTime).toBeLessThan(5000)
      expect(result).toBeDefined()
      expect(result.rawText.length).toBeGreaterThan(100000)
    })
  })

  describe('API Integration', () => {
    it('should work end-to-end through BrandService API', async () => {
      // Clear any previous mocks
      jest.clearAllMocks()
      
      const mockEnhancedResponse = {
        success: true,
        extractedData: {
          rawText: testBrandGuidelines,
          extractedAt: '2023-01-01T00:00:00.000Z',
          assetId: 'asset-123',
          brandId: 'brand-456',
          colors: [{ hex: '#0066CC', category: 'primary' }],
          fonts: [{ family: 'Inter', category: 'sans-serif', usage: 'heading' }],
          confidence: { overall: 85, colors: 90, fonts: 80, voice: 75, guidelines: 85, compliance: 80 },
          suggestions: ['Consider adding more detailed specifications']
        },
        message: 'Document parsed successfully with 85% confidence',
        processingInfo: {
          engine: 'BrandGuidelinesProcessor',
          version: '1.0',
          extractedAt: '2023-01-01T00:00:00.000Z',
          elementsFound: { colors: 1, fonts: 1, voiceAttributes: 0, guidelineSections: 0, complianceRules: 0 }
        }
      }

      // Use a simpler mock approach
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockEnhancedResponse)
      })

      const result = await BrandService.parseDocument('brand-456', {
        assetId: 'asset-123',
        parseSettings: {
          extractColors: true,
          extractFonts: true,
          extractVoice: true,
          extractGuidelines: true,
          extractCompliance: true,
          enhanceWithAI: false
        }
      })

      expect(result).toEqual(mockEnhancedResponse)
      expect(result.processingInfo.engine).toBe('BrandGuidelinesProcessor')
      expect(result.extractedData.confidence.overall).toBe(85)
    })
  })
})