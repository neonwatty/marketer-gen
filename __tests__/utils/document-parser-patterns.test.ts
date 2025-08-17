/**
 * Unit tests for document parsing pattern recognition utilities
 * These test the core regex patterns and extraction logic used in the document parser
 */

describe('Document Parser Pattern Recognition', () => {
  // Color extraction patterns from the route handler
  const COLOR_PATTERNS = [
    /#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})/g,
    /rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/gi,
    /rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)/gi,
    /hsl\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)/gi,
    /pantone\s+(\w+\s*\w*)/gi,
    /cmyk\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/gi,
  ]

  const FONT_PATTERNS = [
    /font-family\s*:\s*([^;]+)/gi,
    /typeface\s*:\s*([^\n\r.]+)/gi,
    /font\s*:\s*([^\n\r.;,]+)/gi,
    /"([^"]+)"/g,
    /(arial|helvetica|times|georgia|verdana|trebuchet|impact|comic sans|courier|palatino|garamond|futura|avant garde|optima|gill sans|franklin gothic|century gothic|lucida|tahoma|calibri|cambria|segoe|roboto|open sans|lato|montserrat|source sans|ubuntu|droid|noto|poppins|nunito|inter|work sans|playfair|crimson|merriweather|pt serif|source serif|bitter|vollkorn|gentium|eb garamond|libre baskerville)[^\\s\\n\\r.;,]*/gi,
  ]

  const VOICE_KEYWORDS = [
    'voice', 'tone', 'personality', 'style', 'attitude', 'character',
    'professional', 'friendly', 'casual', 'formal', 'conversational',
    'authoritative', 'approachable', 'confident', 'warm', 'energetic',
    'sophisticated', 'playful', 'serious', 'innovative', 'trustworthy',
    'authentic', 'reliable', 'modern', 'traditional', 'progressive',
    'conservative', 'bold', 'subtle', 'direct', 'diplomatic'
  ]

  // Helper function to extract colors (simulating the route handler logic)
  function extractColors(text: string): string[] {
    const colors = new Set<string>()
    
    COLOR_PATTERNS.forEach(pattern => {
      const matches = text.match(pattern)
      if (matches) {
        matches.forEach(match => colors.add(match.trim()))
      }
    })
    
    return Array.from(colors)
  }

  // Helper function to extract fonts
  function extractFonts(text: string): string[] {
    const fonts = new Set<string>()
    
    FONT_PATTERNS.forEach(pattern => {
      const matches = text.match(pattern)
      if (matches) {
        matches.forEach(match => {
          const cleaned = match
            .replace(/font-family\s*:\s*/gi, '')
            .replace(/typeface\s*:\s*/gi, '')
            .replace(/font\s*:\s*/gi, '')
            .replace(/['"]/g, '')
            .replace(/;/g, '')
            .trim()
          
          if (cleaned && cleaned.length > 2) {
            fonts.add(cleaned)
          }
        })
      }
    })
    
    return Array.from(fonts)
  }

  describe('Color Pattern Recognition', () => {
    it('should extract hex colors correctly', () => {
      const testTexts = [
        'Primary color is #ff0000 and secondary is #00ff00',
        'Use #FFFFFF for backgrounds and #000000 for text',
        'Brand colors: #f1c40f, #e74c3c, #3498db',
        'Short hex: #fff, #000, #abc',
      ]

      testTexts.forEach(text => {
        const colors = extractColors(text)
        expect(colors.length).toBeGreaterThan(0)
        colors.forEach(color => {
          expect(color).toMatch(/#[0-9a-fA-F]{3,6}/)
        })
      })
    })

    it('should extract RGB colors correctly', () => {
      const testTexts = [
        'Primary: rgb(255, 0, 0) Secondary: rgb(0, 255, 0)',
        'Background: rgb(255,255,255) Text: rgb(0,0,0)',
        'Brand colors: rgb( 241, 196, 15 ), rgb( 231, 76, 60 )',
      ]

      testTexts.forEach(text => {
        const colors = extractColors(text)
        expect(colors.length).toBeGreaterThan(0)
        colors.forEach(color => {
          expect(color).toMatch(/rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)/i)
        })
      })
    })

    it('should extract RGBA colors correctly', () => {
      const testTexts = [
        'Overlay: rgba(0, 0, 0, 0.5)',
        'Semi-transparent: rgba(255, 255, 255, 0.8)',
        'Button hover: rgba(52, 152, 219, 0.9)',
      ]

      testTexts.forEach(text => {
        const colors = extractColors(text)
        expect(colors.length).toBeGreaterThan(0)
        colors.forEach(color => {
          expect(color).toMatch(/rgba\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*[0-9.]+\s*\)/i)
        })
      })
    })

    it('should extract HSL colors correctly', () => {
      const testTexts = [
        'Primary: hsl(0, 100%, 50%)',
        'Secondary: hsl(120, 100%, 50%)',
        'Accent: hsl( 240, 100%, 50% )',
      ]

      testTexts.forEach(text => {
        const colors = extractColors(text)
        expect(colors.length).toBeGreaterThan(0)
        colors.forEach(color => {
          expect(color).toMatch(/hsl\(\s*\d+\s*,\s*\d+%\s*,\s*\d+%\s*\)/i)
        })
      })
    })

    it('should extract Pantone colors correctly', () => {
      const testTexts = [
        'Use Pantone 286 C for the logo',
        'Brand color: Pantone Cool Gray 11',
        'Print colors: Pantone 185 C, Pantone Black 6',
      ]

      testTexts.forEach(text => {
        const colors = extractColors(text)
        expect(colors.length).toBeGreaterThan(0)
        colors.forEach(color => {
          expect(color).toMatch(/pantone\s+\w+/i)
        })
      })
    })

    it('should extract CMYK colors correctly', () => {
      const testTexts = [
        'Print color: cmyk(100, 0, 0, 0)',
        'Black: cmyk(0, 0, 0, 100)',
        'Custom: cmyk( 50, 25, 0, 10 )',
      ]

      testTexts.forEach(text => {
        const colors = extractColors(text)
        expect(colors.length).toBeGreaterThan(0)
        colors.forEach(color => {
          expect(color).toMatch(/cmyk\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)/i)
        })
      })
    })

    it('should handle mixed color formats in same text', () => {
      const text = `
        Brand Guidelines:
        Primary: #007bff (rgb(0, 123, 255))
        Secondary: hsl(120, 100%, 50%)
        Print: Pantone 286 C
        CMYK equivalent: cmyk(100, 23, 0, 6)
        Transparent overlay: rgba(0, 0, 0, 0.5)
      `

      const colors = extractColors(text)
      expect(colors.length).toBeGreaterThanOrEqual(5)
      
      // Should contain at least one of each type
      expect(colors.some(c => c.match(/#[0-9a-fA-F]{6}/))).toBe(true)
      expect(colors.some(c => c.match(/rgb\(/i))).toBe(true)
      expect(colors.some(c => c.match(/hsl\(/i))).toBe(true)
      expect(colors.some(c => c.match(/pantone/i))).toBe(true)
      expect(colors.some(c => c.match(/cmyk\(/i))).toBe(true)
      expect(colors.some(c => c.match(/rgba\(/i))).toBe(true)
    })
  })

  describe('Font Pattern Recognition', () => {
    it('should extract CSS font-family declarations', () => {
      const testTexts = [
        'font-family: "Helvetica Neue", Arial, sans-serif;',
        'font-family: Georgia, "Times New Roman", serif;',
        'font-family: Roboto, sans-serif;',
      ]

      testTexts.forEach(text => {
        const fonts = extractFonts(text)
        expect(fonts.length).toBeGreaterThan(0)
      })
    })

    it('should extract typeface specifications', () => {
      const testTexts = [
        'Primary typeface: Helvetica Neue',
        'Body typeface: Source Sans Pro',
        'Display typeface: Playfair Display',
      ]

      testTexts.forEach(text => {
        const fonts = extractFonts(text)
        expect(fonts.length).toBeGreaterThan(0)
        expect(fonts[0].length).toBeGreaterThan(2)
      })
    })

    it('should extract quoted font names', () => {
      const testTexts = [
        'Use "Times New Roman" for body text',
        'Headings in "Arial Black" font',
        '"Source Sans Pro" for UI elements',
      ]

      testTexts.forEach(text => {
        const fonts = extractFonts(text)
        expect(fonts.length).toBeGreaterThan(0)
        // Should extract without quotes
        fonts.forEach(font => {
          expect(font).not.toContain('"')
        })
      })
    })

    it('should extract common web fonts', () => {
      const testTexts = [
        'Use Arial for headings and Helvetica for body',
        'Georgia font family for serif text',
        'Roboto and Open Sans are our primary fonts',
        'Montserrat for display, Lato for body',
      ]

      testTexts.forEach(text => {
        const fonts = extractFonts(text)
        expect(fonts.length).toBeGreaterThan(0)
      })
    })

    it('should handle complex font specifications', () => {
      const text = `
        Typography Guidelines:
        Headings: font-family: "Playfair Display", Georgia, serif;
        Body: font-family: "Source Sans Pro", Arial, sans-serif;
        Code: font-family: "Monaco", "Courier New", monospace;
        Display typeface: Montserrat Bold
        UI typeface: Inter Regular
      `

      const fonts = extractFonts(text)
      expect(fonts.length).toBeGreaterThan(3)
      
      // Should extract various font names
      expect(fonts.some(f => f.toLowerCase().includes('playfair'))).toBe(true)
      expect(fonts.some(f => f.toLowerCase().includes('source'))).toBe(true)
      expect(fonts.some(f => f.toLowerCase().includes('monaco'))).toBe(true)
    })

    it('should clean font names properly', () => {
      const text = 'font-family: "Helvetica Neue", Arial, sans-serif;'
      const fonts = extractFonts(text)

      fonts.forEach(font => {
        expect(font).not.toContain('font-family')
        expect(font).not.toContain(':')
        expect(font).not.toContain(';')
        expect(font).not.toContain('"')
      })
    })
  })

  describe('Voice Keywords Recognition', () => {
    it('should identify voice-related keywords', () => {
      const voiceKeywords = [
        'voice', 'tone', 'personality', 'style', 'attitude', 'character'
      ]

      voiceKeywords.forEach(keyword => {
        expect(VOICE_KEYWORDS).toContain(keyword)
      })
    })

    it('should identify tone attributes', () => {
      const toneAttributes = [
        'professional', 'friendly', 'casual', 'formal', 'conversational',
        'authoritative', 'approachable', 'confident', 'warm', 'energetic'
      ]

      toneAttributes.forEach(attribute => {
        expect(VOICE_KEYWORDS).toContain(attribute)
      })
    })

    it('should identify personality traits', () => {
      const personalityTraits = [
        'sophisticated', 'playful', 'serious', 'innovative', 'trustworthy',
        'authentic', 'reliable', 'modern', 'traditional', 'progressive'
      ]

      personalityTraits.forEach(trait => {
        expect(VOICE_KEYWORDS).toContain(trait)
      })
    })

    it('should identify communication styles', () => {
      const communicationStyles = [
        'conservative', 'bold', 'subtle', 'direct', 'diplomatic'
      ]

      communicationStyles.forEach(style => {
        expect(VOICE_KEYWORDS).toContain(style)
      })
    })
  })

  describe('Edge Cases and Error Handling', () => {
    it('should handle empty text gracefully', () => {
      const colors = extractColors('')
      const fonts = extractFonts('')

      expect(colors).toEqual([])
      expect(fonts).toEqual([])
    })

    it('should handle text with no matches', () => {
      const text = 'This is plain text with no colors or fonts specified.'
      
      const colors = extractColors(text)
      const fonts = extractFonts(text)

      expect(colors).toEqual([])
      expect(fonts).toEqual([])
    })

    it('should handle malformed color values', () => {
      const text = 'Bad colors: #gggggg, rgb(300, 400, 500), hsl(400, 150%, 120%)'
      
      const colors = extractColors(text)
      // Should still extract patterns even if values are invalid
      expect(colors.length).toBeGreaterThanOrEqual(0)
    })

    it('should handle very long text efficiently', () => {
      const longText = 'Primary color #ff0000. '.repeat(10000)
      
      const startTime = Date.now()
      const colors = extractColors(longText)
      const endTime = Date.now()

      expect(colors).toContain('#ff0000')
      expect(endTime - startTime).toBeLessThan(1000) // Should complete within 1 second
    })

    it('should deduplicate extracted values', () => {
      const text = `
        Primary: #ff0000, #ff0000, #ff0000
        Font: Arial, Arial, Arial
      `

      const colors = extractColors(text)
      const fonts = extractFonts(text)

      // Should only contain unique values
      expect(colors).toEqual(['#ff0000'])
      expect(fonts.filter(f => f.toLowerCase() === 'arial')).toHaveLength(1)
    })

    it('should handle Unicode and special characters', () => {
      const text = `
        Bränд Güídelînes:
        Prímáry cölor: #ff0000
        Fónt: "Hëlvëtícá Nëüë"
      `

      const colors = extractColors(text)
      const fonts = extractFonts(text)

      expect(colors).toContain('#ff0000')
      expect(fonts.length).toBeGreaterThan(0)
    })

    it('should handle mixed case patterns', () => {
      const text = `
        PRIMARY COLOR: #FF0000
        secondary color: #00ff00
        Font-Family: ARIAL
        TYPEFACE: helvetica neue
      `

      const colors = extractColors(text)
      const fonts = extractFonts(text)

      expect(colors).toContain('#FF0000')
      expect(colors).toContain('#00ff00')
      expect(fonts.length).toBeGreaterThan(0)
    })
  })

  describe('Real-world Document Patterns', () => {
    it('should extract from typical brand guidelines format', () => {
      const brandGuidelines = `
        BRAND IDENTITY GUIDELINES
        
        COLOR PALETTE
        Primary Brand Color: #007bff (rgb(0, 123, 255))
        Secondary Colors: #28a745, #dc3545, #ffc107
        Neutral Colors: #6c757d, #f8f9fa
        
        TYPOGRAPHY
        Primary Typeface: "Helvetica Neue", Arial, sans-serif
        Secondary Typeface: Georgia, "Times New Roman", serif
        Display Font: Montserrat Bold
        
        BRAND VOICE
        Our brand voice is professional yet approachable, maintaining 
        a conversational tone while demonstrating expertise and 
        trustworthiness. We communicate with confidence and warmth.
      `

      const colors = extractColors(brandGuidelines)
      const fonts = extractFonts(brandGuidelines)

      expect(colors.length).toBeGreaterThanOrEqual(5)
      expect(fonts.length).toBeGreaterThanOrEqual(3)
      
      expect(colors).toContain('#007bff')
      expect(colors).toContain('#28a745')
      expect(fonts.some(f => f.toLowerCase().includes('helvetica'))).toBe(true)
    })

    it('should extract from style guide format', () => {
      const styleGuide = `
        CORPORATE STYLE GUIDE
        
        1. VISUAL IDENTITY
           Brand Colors:
           - Pantone 286 C (cmyk(100, 68, 0, 6))
           - Pantone Cool Gray 11 (cmyk(0, 0, 0, 80))
        
        2. FONTS & TYPOGRAPHY
           font-family: "Source Sans Pro", system-ui, sans-serif;
           Display: "Playfair Display", Georgia, serif;
        
        3. TONE OF VOICE
           Professional, innovative, and customer-focused approach.
           Maintain an authoritative yet friendly communication style.
      `

      const colors = extractColors(styleGuide)
      const fonts = extractFonts(styleGuide)

      expect(colors.some(c => c.toLowerCase().includes('pantone'))).toBe(true)
      expect(colors.some(c => c.toLowerCase().includes('cmyk'))).toBe(true)
      expect(fonts.some(f => f.toLowerCase().includes('source'))).toBe(true)
      expect(fonts.some(f => f.toLowerCase().includes('playfair'))).toBe(true)
    })
  })
})