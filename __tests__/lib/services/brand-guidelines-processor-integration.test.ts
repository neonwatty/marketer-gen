import { BrandGuidelinesProcessor } from '@/lib/services/brand-guidelines-processor'
import pdf from 'pdf-parse'
import mammoth from 'mammoth'

// Mock external dependencies
jest.mock('pdf-parse')
jest.mock('mammoth')

describe('BrandGuidelinesProcessor Integration Tests', () => {
  const mockAssetId = 'test-asset-123'
  const mockBrandId = 'test-brand-456'

  const comprehensiveBrandText = `
    # XYZ Company Brand Guidelines
    ## Brand Overview
    XYZ Company is an innovative technology leader focused on reliability and customer success.
    Our mission is to transform how businesses operate through cutting-edge solutions.

    ## Visual Identity
    ### Logo Usage
    Our logo represents innovation and reliability. Use the primary logo wherever possible.
    
    Minimum size: 24px height for digital, 0.5 inches for print
    Clear space: Maintain clear space equal to the height of the logo on all sides
    
    ### Color Palette
    Primary Colors:
    - Brand Blue: #007BFF (RGB: 0, 123, 255) (Pantone: 2925 C)
    - Success Green: #28A745 (RGB: 40, 167, 69) (HSL: 134, 61%, 41%)
    - Warning Orange: #FF8C00 (HSL: 33, 100%, 50%) - For attention-grabbing elements
    - Error Red: #DC3545 (CMYK: 0, 75, 67, 14) - For error states

    Secondary Colors:
    - Neutral Gray: #6C757D - For text and backgrounds
    - Light Background: #F8F9FA - For page backgrounds

    ### Typography
    Primary Typeface: "Helvetica Neue", Arial, sans-serif
    Use for all headlines, titles, and primary navigation
    
    Body Text: "Source Sans Pro", Georgia, serif
    Use for all body copy, descriptions, and secondary text
    
    Monospace: "Courier New", Monaco, monospace
    Use for code examples and technical specifications

    ## Brand Voice & Tone
    Our brand voice is professional yet approachable, confident but not arrogant.
    We communicate in a conversational style that builds trust with our audience.
    
    Brand personality traits:
    - Innovative: We embrace new technologies and forward-thinking approaches
    - Reliable: Our solutions are dependable and consistently deliver results  
    - Trustworthy: We build long-term relationships based on transparency
    - Modern: We stay current with industry trends and best practices
    - Customer-focused: Every decision prioritizes our customers' success

    Communication Style Guidelines:
    - Use active voice whenever possible
    - Keep sentences concise and clear
    - Avoid technical jargon when speaking to general audiences
    - Include concrete examples to illustrate concepts
    - Always lead with benefits before features

    ## Usage Guidelines
    ### Do's and Don'ts
    DO: Use high contrast colors for accessibility
    DO: Maintain consistent spacing and alignment
    DO: Test all designs on multiple devices
    
    DON'T: Stretch or distort the logo
    DON'T: Use colors outside the approved palette
    DON'T: Mix different font families in the same design

    ## Compliance Requirements
    All brand materials must:
    - Meet WCAG 2.1 AA accessibility standards
    - Include proper copyright notices
    - Follow industry-specific regulations where applicable
    
    Review Process:
    - All external materials require brand team approval
    - Internal materials should follow these guidelines consistently
    - Regular audits ensure compliance across all touchpoints

    ## Target Audience
    Primary audience: Technology decision-makers who value innovation and reliability
    
    Demographics:
    - Age range: 35-55 years
    - Job titles: C-level executives, IT Directors, Technology Managers
    - Company size: 500-10,000 employees
    - Industries: Healthcare, Financial Services, Manufacturing, Retail
  `

  describe('Document Content Parsing', () => {
    beforeEach(() => {
      jest.clearAllMocks()
    })

    it('should parse PDF documents successfully', async () => {
      const mockPdfData = { text: 'PDF content with brand guidelines' }
      ;(pdf as jest.MockedFunction<typeof pdf>).mockResolvedValue(mockPdfData)

      const buffer = Buffer.from('mock pdf data')
      const result = await BrandGuidelinesProcessor.parseDocumentContent(buffer, 'application/pdf')

      expect(pdf).toHaveBeenCalledWith(buffer)
      expect(result).toBe('PDF content with brand guidelines')
    })

    it('should parse DOCX documents successfully', async () => {
      const mockDocxResult = { value: 'DOCX content with brand guidelines' }
      ;(mammoth.extractRawText as jest.MockedFunction<typeof mammoth.extractRawText>)
        .mockResolvedValue(mockDocxResult)

      const buffer = Buffer.from('mock docx data')
      const result = await BrandGuidelinesProcessor.parseDocumentContent(
        buffer, 
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )

      expect(mammoth.extractRawText).toHaveBeenCalledWith({ buffer })
      expect(result).toBe('DOCX content with brand guidelines')
    })

    it('should parse DOC documents successfully', async () => {
      const mockDocResult = { value: 'DOC content with brand guidelines' }
      ;(mammoth.extractRawText as jest.MockedFunction<typeof mammoth.extractRawText>)
        .mockResolvedValue(mockDocResult)

      const buffer = Buffer.from('mock doc data')
      const result = await BrandGuidelinesProcessor.parseDocumentContent(buffer, 'application/msword')

      expect(mammoth.extractRawText).toHaveBeenCalledWith({ buffer })
      expect(result).toBe('DOC content with brand guidelines')
    })

    it('should handle parsing errors gracefully', async () => {
      ;(pdf as jest.MockedFunction<typeof pdf>).mockRejectedValue(new Error('PDF parsing failed'))

      const buffer = Buffer.from('invalid pdf data')
      
      await expect(
        BrandGuidelinesProcessor.parseDocumentContent(buffer, 'application/pdf')
      ).rejects.toThrow('PDF parsing failed: PDF parsing failed')
    })

    it('should parse plain text documents', async () => {
      const buffer = Buffer.from('Plain text brand guidelines', 'utf-8')
      const result = await BrandGuidelinesProcessor.parseDocumentContent(buffer, 'text/plain')

      expect(result).toBe('Plain text brand guidelines')
    })

    it('should default to text parsing for unknown MIME types', async () => {
      const buffer = Buffer.from('Unknown format content', 'utf-8')
      const result = await BrandGuidelinesProcessor.parseDocumentContent(buffer, 'unknown/format')

      expect(result).toBe('Unknown format content')
    })
  })

  describe('Comprehensive Brand Processing', () => {
    const comprehensiveBrandText = `
      # XYZ Company Brand Guidelines

      ## Brand Overview
      XYZ Company is an innovative technology leader focused on reliability and customer success.
      Our mission is to transform how businesses operate through cutting-edge solutions.

      ## Visual Identity

      ### Color Palette
      Primary Brand Colors:
      - Brand Blue: #0066CC (Pantone 286 C) - Use for primary branding elements
      - Success Green: #28A745 (RGB: 40, 167, 69) - For positive messaging
      - Warning Orange: #FF8C00 (HSL: 33, 100%, 50%) - For attention-grabbing elements
      - Error Red: #DC3545 (CMYK: 0, 75, 67, 14) - For error states

      Secondary Colors:
      - Neutral Gray: #6C757D - For text and backgrounds
      - Light Background: #F8F9FA - For page backgrounds

      ### Typography
      Primary Typeface: "Helvetica Neue", Arial, sans-serif
      Use for all headlines, titles, and primary navigation
      
      Body Text: "Source Sans Pro", Georgia, serif
      Use for all body copy, descriptions, and secondary text
      
      Monospace: "Courier New", Monaco, monospace
      Use for code examples and technical specifications

      ## Brand Voice & Tone
      Our brand voice is professional yet approachable, confident but not arrogant.
      We communicate in a conversational style that builds trust with our audience.
      
      Brand personality traits:
      - Innovative: We embrace new technologies and forward-thinking approaches
      - Reliable: Our solutions are dependable and consistently deliver results  
      - Trustworthy: We build long-term relationships based on transparency
      - Modern: We stay current with industry trends and best practices
      - Customer-focused: Every decision prioritizes our customers' success

      Communication Style Guidelines:
      - Use active voice whenever possible
      - Write in a conversational, friendly tone
      - Avoid jargon and technical terms when addressing general audiences
      - Be direct and clear in all communications
      - Show enthusiasm for innovation and problem-solving

      ## Usage Guidelines
      
      ### Logo Usage
      Always use the primary logo on white or light backgrounds.
      Maintain minimum clear space of 20px around all sides of the logo.
      The logo should never be smaller than 120px in width for digital use.
      
      ### Do's and Don'ts
      DO:
      - Always maintain consistent color usage across all materials
      - Use approved fonts for all branded communications
      - Ensure proper contrast ratios for accessibility
      - Include copyright notices on all published materials
      
      DON'T:
      - Never distort or modify the logo proportions
      - Do not use competitor names in marketing copy without approval
      - Avoid using colors outside the approved palette
      - Never use Comic Sans or other inappropriate fonts

      ## Compliance Requirements
      
      ### Legal Requirements
      All marketing materials must be approved by the brand team before publication.
      Copyright notices must appear on all published materials: "© 2023 XYZ Company. All rights reserved."
      Trademark symbols must be used correctly on first mention of branded terms.
      
      ### Restricted Terms
      Avoid using superlatives like "best," "perfect," or "ultimate" without substantiation.
      Do not use competitor names in marketing copy without legal review.
      Prohibited phrases: "world's leading," "industry standard," "revolutionary breakthrough"
      
      ### Approval Process
      All brand materials require approval from the Brand Manager before external use.
      Social media posts must be reviewed by the Marketing team.
      Press releases require Legal and Executive approval.

      ## Target Audience
      Primary: Technology decision-makers in enterprise organizations (CTOs, IT Directors)
      Secondary: Business leaders seeking digital transformation solutions (CEOs, COOs)
      
      Demographics:
      - Age range: 35-55 years
      - Job titles: C-level executives, IT Directors, Technology Managers
      - Company size: 500-10,000 employees
      - Industries: Healthcare, Financial Services, Manufacturing, Retail
    `

    it('should extract comprehensive brand data with high confidence', async () => {
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        comprehensiveBrandText,
        mockAssetId,
        mockBrandId
      )

      // Test comprehensive extraction
      expect(result.colors).toBeDefined()
      expect(result.colors!.length).toBeGreaterThan(5)
      expect(result.fonts).toBeDefined()
      expect(result.fonts!.length).toBeGreaterThan(2)
      expect(result.voice).toBeDefined()
      expect(result.guidelines).toBeDefined()
      expect(result.compliance).toBeDefined()

      // Test confidence scores
      expect(result.confidence.overall).toBeGreaterThan(70)
      expect(result.confidence.colors).toBeGreaterThan(80)
      expect(result.confidence.fonts).toBeGreaterThan(70)
      expect(result.confidence.voice).toBeGreaterThan(60)

      // Test structured guidelines
      expect(result.guidelines!.sections.length).toBeGreaterThan(4)
      expect(result.guidelines!.sections.some(s => s.type === 'overview')).toBe(true)
      expect(result.guidelines!.sections.some(s => s.type === 'visual')).toBe(true)
      expect(result.guidelines!.sections.some(s => s.type === 'voice')).toBe(true)
      expect(result.guidelines!.sections.some(s => s.type === 'compliance')).toBe(true)
    })

    it('should categorize colors correctly', async () => {
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        comprehensiveBrandText,
        mockAssetId,
        mockBrandId,
        { extractColors: true, extractFonts: false, extractVoice: false, extractGuidelines: false, extractCompliance: false }
      )

      const colors = result.colors!
      
      // Check for different color formats
      expect(colors.some(c => c.hex && c.hex.startsWith('#'))).toBe(true)
      expect(colors.some(c => c.pantone)).toBe(true)
      expect(colors.some(c => c.rgb)).toBe(true)
      expect(colors.some(c => c.hsl)).toBe(true)
      expect(colors.some(c => c.cmyk)).toBe(true)

      // Check categorization
      expect(colors.some(c => c.category === 'primary')).toBe(true)
      expect(colors.some(c => c.category === 'success')).toBe(true)
      expect(colors.some(c => c.category === 'warning')).toBe(true)
      expect(colors.some(c => c.category === 'error')).toBe(true)
      expect(colors.some(c => c.category === 'neutral')).toBe(true)
    })

    it('should categorize fonts correctly', async () => {
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        comprehensiveBrandText,
        mockAssetId,
        mockBrandId,
        { extractColors: false, extractFonts: true, extractVoice: false, extractGuidelines: false, extractCompliance: false }
      )

      const fonts = result.fonts!
      
      // Check font categories
      expect(fonts.some(f => f.category === 'sans-serif')).toBe(true)
      expect(fonts.some(f => f.category === 'serif')).toBe(true)
      expect(fonts.some(f => f.category === 'monospace')).toBe(true)

      // Check usage categorization
      expect(fonts.some(f => f.usage === 'heading')).toBe(true)
      expect(fonts.some(f => f.usage === 'body')).toBe(true)

      // Check specific fonts
      expect(fonts.some(f => f.family.includes('Helvetica'))).toBe(true)
      expect(fonts.some(f => f.family.includes('Source Sans Pro'))).toBe(true)
      expect(fonts.some(f => f.family.includes('Courier'))).toBe(true)
    })

    it('should extract comprehensive voice analysis', async () => {
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        comprehensiveBrandText,
        mockAssetId,
        mockBrandId,
        { extractColors: false, extractFonts: false, extractVoice: true, extractGuidelines: false, extractCompliance: false }
      )

      const voice = result.voice!
      
      expect(voice.voiceDescription).toBeTruthy()
      expect(voice.communicationStyle).toBe('conversational')
      expect(voice.personality).toContain('innovative')
      expect(voice.personality).toContain('reliable')
      expect(voice.personality).toContain('trustworthy')
      expect(voice.personality).toContain('modern')

      // Check tone attributes
      expect(voice.toneAttributes.professional).toBeGreaterThan(0)
      expect(voice.toneAttributes.friendly).toBeGreaterThan(0)
      expect(voice.toneAttributes.innovative).toBeGreaterThan(0)
      expect(voice.toneAttributes.trustworthy).toBeGreaterThan(0)
    })

    it('should extract compliance rules comprehensively', async () => {
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        comprehensiveBrandText,
        mockAssetId,
        mockBrandId,
        { extractColors: false, extractFonts: false, extractVoice: false, extractGuidelines: false, extractCompliance: true }
      )

      const compliance = result.compliance!
      
      expect(compliance.usageRules.do.length).toBeGreaterThan(3)
      expect(compliance.usageRules.dont.length).toBeGreaterThan(3)
      expect(compliance.legalRequirements.length).toBeGreaterThan(2)
      expect(compliance.restrictedTerms.length).toBeGreaterThan(0)

      // Check specific rules
      expect(compliance.usageRules.do.some(rule => rule.includes('consistent'))).toBe(true)
      expect(compliance.usageRules.dont.some(rule => rule.includes('distort'))).toBe(true)
      expect(compliance.legalRequirements.some(req => req.includes('copyright'))).toBe(true)
    })

    it('should provide meaningful suggestions for incomplete guidelines', async () => {
      const minimalText = "Our brand is blue and uses Arial font."
      
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        minimalText,
        mockAssetId,
        mockBrandId
      )

      expect(result.suggestions.length).toBeGreaterThan(2)
      expect(result.suggestions.some(s => s.includes('voice'))).toBe(true)
      expect(result.suggestions.some(s => s.includes('usage'))).toBe(true)
    })
  })

  describe('Edge Cases and Error Handling', () => {
    it('should handle empty text gracefully', async () => {
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        '',
        mockAssetId,
        mockBrandId
      )

      expect(result.rawText).toBe('')
      expect(result.colors || []).toHaveLength(0)
      expect(result.fonts || []).toHaveLength(0)
      expect(result.confidence.overall).toBeLessThan(50)
      expect(result.suggestions.length).toBeGreaterThan(0)
    })

    it('should handle malformed color codes', async () => {
      const textWithBadColors = "Colors: #gggggg, rgb(300, 400, 500), invalid-color"
      
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        textWithBadColors,
        mockAssetId,
        mockBrandId,
        { extractColors: true }
      )

      // Should not crash and should have low confidence
      expect(result.confidence.colors).toBeLessThan(50)
    })

    it('should handle very large text documents', async () => {
      const largeText = "Brand guidelines ".repeat(10000) + "Primary color: #007bff"
      
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        largeText,
        mockAssetId,
        mockBrandId
      )

      expect(result.rawText.length).toBeGreaterThan(100000)
      expect(result.colors!.some(c => c.hex === '#007BFF')).toBe(true)
    })

    it('should handle text with special characters and unicode', async () => {
      const unicodeText = `
        Brand: Café™ ©2023
        Colors: #007bff 🎨, Pantone 286 C
        Fonts: "Helvetica Neue" 💫
        Voice: Professional & friendly! 😊
      `
      
      const result = await BrandGuidelinesProcessor.processBrandGuidelines(
        unicodeText,
        mockAssetId,
        mockBrandId
      )

      expect(result.colors!.length).toBeGreaterThan(0)
      expect(result.fonts!.length).toBeGreaterThan(0)
    })
  })

  describe('Performance and Scalability', () => {
    it('should process guidelines within reasonable time', async () => {
      const start = Date.now()
      
      await BrandGuidelinesProcessor.processBrandGuidelines(
        comprehensiveBrandText,
        mockAssetId,
        mockBrandId
      )
      
      const duration = Date.now() - start
      expect(duration).toBeLessThan(5000) // Should complete within 5 seconds
    })

    it('should handle concurrent processing requests', async () => {
      const promises = Array.from({ length: 5 }, (_, i) =>
        BrandGuidelinesProcessor.processBrandGuidelines(
          `Brand ${i} guidelines with color #${i}${i}${i}${i}${i}${i}`,
          `asset-${i}`,
          `brand-${i}`
        )
      )

      const results = await Promise.all(promises)
      
      expect(results).toHaveLength(5)
      results.forEach((result, i) => {
        expect(result.assetId).toBe(`asset-${i}`)
        expect(result.brandId).toBe(`brand-${i}`)
      })
    })
  })
})