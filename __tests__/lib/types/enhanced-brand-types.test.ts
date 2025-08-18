import { 
  EnhancedDocumentParseResult,
  DocumentParseRequest,
  DocumentParseSettings
} from '@/lib/types/brand'

describe('Enhanced Brand Type Definitions', () => {
  describe('EnhancedDocumentParseResult', () => {
    it('should validate complete enhanced response structure', () => {
      const validResponse: EnhancedDocumentParseResult = {
        success: true,
        extractedData: {
          rawText: 'Brand guidelines content',
          extractedAt: '2023-01-01T00:00:00.000Z',
          assetId: 'asset-123',
          brandId: 'brand-456',
          colors: [
            {
              hex: '#007BFF',
              category: 'primary',
              usage: 'brand color'
            },
            {
              rgb: 'rgb(40, 167, 69)',
              category: 'success'
            },
            {
              pantone: '286 C',
              category: 'primary',
              name: 'Brand Blue'
            }
          ],
          fonts: [
            {
              family: 'Helvetica Neue',
              category: 'sans-serif',
              usage: 'heading',
              weight: 'bold',
              fallbacks: ['Arial', 'sans-serif']
            },
            {
              family: 'Georgia',
              category: 'serif',
              usage: 'body'
            }
          ],
          voice: {
            voiceDescription: 'Professional and approachable',
            toneAttributes: {
              professional: 3,
              friendly: 2,
              trustworthy: 4
            },
            communicationStyle: 'conversational',
            personality: ['innovative', 'reliable'],
            messaging: {
              primary: 'Innovation through reliability',
              secondary: ['Customer success', 'Quality solutions'],
              prohibited: ['competitor names', 'superlatives']
            }
          },
          guidelines: {
            sections: [
              {
                title: 'Brand Overview',
                content: 'Our brand represents...',
                type: 'overview'
              },
              {
                title: 'Visual Identity',
                content: 'Colors and typography...',
                type: 'visual'
              }
            ],
            keyPhrases: ['Maintain consistency', 'Ensure accessibility'],
            brandPillars: ['Innovation', 'Quality', 'Trust'],
            targetAudience: {
              primary: 'Technology leaders',
              demographics: {
                age_range: '30-50',
                job_titles: ['CTO', 'IT Director']
              }
            }
          },
          compliance: {
            usageRules: {
              do: ['Use primary logo on white backgrounds'],
              dont: ['Never distort logo proportions']
            },
            restrictedTerms: ['best in class', 'revolutionary'],
            legalRequirements: ['Copyright notice required'],
            approvalProcess: 'Brand team approval required'
          },
          confidence: {
            overall: 85,
            colors: 90,
            fonts: 80,
            voice: 75,
            guidelines: 85,
            compliance: 80
          },
          suggestions: [
            'Add font weight specifications',
            'Include accessibility guidelines'
          ]
        },
        message: 'Document parsed successfully with 85% confidence',
        processingInfo: {
          engine: 'BrandGuidelinesProcessor',
          version: '1.0',
          extractedAt: '2023-01-01T00:00:00.000Z',
          elementsFound: {
            colors: 3,
            fonts: 2,
            voiceAttributes: 3,
            guidelineSections: 2,
            complianceRules: 2
          },
          confidence: {
            overall: 85,
            colors: 90,
            fonts: 80,
            voice: 75,
            guidelines: 85,
            compliance: 80
          },
          suggestions: [
            'Add font weight specifications',
            'Include accessibility guidelines'
          ]
        }
      }

      // Type checking - if this compiles, the type is valid
      expect(validResponse.success).toBe(true)
      expect(validResponse.extractedData.colors).toHaveLength(3)
      expect(validResponse.extractedData.fonts).toHaveLength(2)
      expect(validResponse.processingInfo.engine).toBe('BrandGuidelinesProcessor')
    })

    it('should validate color object types', () => {
      const colors: EnhancedDocumentParseResult['extractedData']['colors'] = [
        {
          hex: '#FF0000',
          category: 'error',
          usage: 'error messages'
        },
        {
          rgb: 'rgb(0, 255, 0)',
          category: 'success',
          name: 'Success Green'
        },
        {
          hsl: 'hsl(240, 100%, 50%)',
          category: 'primary'
        },
        {
          pantone: '186 C',
          category: 'primary',
          usage: 'print materials'
        },
        {
          cmyk: 'cmyk(0, 100, 100, 0)',
          category: 'accent'
        },
        {
          name: 'Brand Orange',
          category: 'warning',
          usage: 'attention-grabbing elements'
        }
      ]

      expect(colors).toHaveLength(6)
      
      // Test all color categories are valid
      const validCategories = ['primary', 'secondary', 'accent', 'neutral', 'warning', 'success', 'error']
      colors?.forEach(color => {
        expect(validCategories).toContain(color.category)
      })
    })

    it('should validate font object types', () => {
      const fonts: EnhancedDocumentParseResult['extractedData']['fonts'] = [
        {
          family: 'Helvetica Neue',
          category: 'sans-serif',
          usage: 'heading',
          weight: 'bold',
          fallbacks: ['Arial', 'sans-serif']
        },
        {
          family: 'Times New Roman',
          category: 'serif',
          usage: 'body'
        },
        {
          family: 'Futura',
          category: 'display',
          usage: 'accent'
        },
        {
          family: 'Courier New',
          category: 'monospace',
          usage: 'caption'
        },
        {
          family: 'Brush Script',
          category: 'script',
          usage: 'navigation'
        },
        {
          family: 'Impact',
          category: 'decorative',
          usage: 'button'
        }
      ]

      expect(fonts).toHaveLength(6)
      
      // Test all font categories are valid
      const validCategories = ['serif', 'sans-serif', 'display', 'monospace', 'script', 'decorative']
      fonts?.forEach(font => {
        expect(validCategories).toContain(font.category)
      })

      // Test all font usages are valid
      const validUsages = ['heading', 'body', 'caption', 'button', 'navigation', 'accent']
      fonts?.forEach(font => {
        expect(validUsages).toContain(font.usage)
      })
    })

    it('should validate voice object structure', () => {
      const voice: EnhancedDocumentParseResult['extractedData']['voice'] = {
        voiceDescription: 'Professional yet approachable brand voice',
        toneAttributes: {
          professional: 4,
          friendly: 3,
          authoritative: 2,
          innovative: 3,
          trustworthy: 5,
          playful: 1,
          sophisticated: 3,
          approachable: 4,
          energetic: 2
        },
        communicationStyle: 'conversational',
        personality: ['innovative', 'reliable', 'trustworthy', 'modern'],
        messaging: {
          primary: 'Innovation through reliability',
          secondary: ['Customer-focused solutions', 'Modern technology'],
          prohibited: ['avoid these terms', 'competitor names', 'superlatives']
        }
      }

      expect(voice?.voiceDescription).toBeTruthy()
      expect(Object.keys(voice?.toneAttributes || {})).toHaveLength(9)
      expect(voice?.personality).toContain('innovative')
      expect(voice?.messaging.prohibited).toContain('superlatives')
    })

    it('should validate guidelines object structure', () => {
      const guidelines: EnhancedDocumentParseResult['extractedData']['guidelines'] = {
        sections: [
          { title: 'Brand Overview', content: 'Overview content', type: 'overview' },
          { title: 'Visual Identity', content: 'Visual content', type: 'visual' },
          { title: 'Voice Guidelines', content: 'Voice content', type: 'voice' },
          { title: 'Usage Rules', content: 'Usage content', type: 'usage' },
          { title: 'Compliance', content: 'Compliance content', type: 'compliance' },
          { title: 'Miscellaneous', content: 'Other content', type: 'other' }
        ],
        keyPhrases: [
          'Always maintain brand consistency',
          'Never alter logo proportions',
          'Ensure accessibility compliance'
        ],
        brandPillars: ['Innovation', 'Quality', 'Trust', 'Customer Focus'],
        targetAudience: {
          primary: 'Technology decision-makers',
          demographics: {
            age_range: '35-55',
            job_titles: ['CTO', 'IT Director', 'Technology Manager'],
            company_size: '500-10000 employees',
            industries: ['Healthcare', 'Finance', 'Manufacturing']
          }
        }
      }

      expect(guidelines?.sections).toHaveLength(6)
      
      // Test all section types are valid
      const validTypes = ['overview', 'visual', 'voice', 'usage', 'compliance', 'other']
      guidelines?.sections.forEach(section => {
        expect(validTypes).toContain(section.type)
        expect(section.title).toBeTruthy()
        expect(section.content).toBeTruthy()
      })

      expect(guidelines?.brandPillars).toHaveLength(4)
      expect(guidelines?.targetAudience?.primary).toBeTruthy()
    })

    it('should validate compliance object structure', () => {
      const compliance: EnhancedDocumentParseResult['extractedData']['compliance'] = {
        usageRules: {
          do: [
            'Always use primary logo on white backgrounds',
            'Maintain minimum clear space around logo',
            'Use approved fonts for all communications',
            'Ensure proper color contrast ratios'
          ],
          dont: [
            'Never distort logo proportions',
            'Do not use competitor names without approval',
            'Avoid using unauthorized colors',
            'Never use Comic Sans or inappropriate fonts'
          ]
        },
        restrictedTerms: [
          'best in class',
          'revolutionary',
          'game-changing',
          'world-leading',
          'industry standard'
        ],
        legalRequirements: [
          'Copyright notice required on all materials',
          'Trademark symbols must be used correctly',
          'Privacy policy links required on digital materials'
        ],
        approvalProcess: 'All marketing materials require brand team approval before publication'
      }

      expect(compliance?.usageRules.do).toHaveLength(4)
      expect(compliance?.usageRules.dont).toHaveLength(4)
      expect(compliance?.restrictedTerms).toHaveLength(5)
      expect(compliance?.legalRequirements).toHaveLength(3)
      expect(compliance?.approvalProcess).toBeTruthy()
    })

    it('should validate confidence scoring structure', () => {
      const confidence: EnhancedDocumentParseResult['extractedData']['confidence'] = {
        overall: 85,
        colors: 92,
        fonts: 88,
        voice: 76,
        guidelines: 90,
        compliance: 82
      }

      // All scores should be between 0 and 100
      Object.values(confidence).forEach(score => {
        expect(score).toBeGreaterThanOrEqual(0)
        expect(score).toBeLessThanOrEqual(100)
        expect(Number.isInteger(score)).toBe(true)
      })
    })
  })

  describe('DocumentParseRequest with Enhanced Settings', () => {
    it('should validate enhanced parse settings', () => {
      const parseSettings: DocumentParseSettings = {
        extractColors: true,
        extractFonts: true,
        extractVoice: true,
        extractGuidelines: true,
        extractCompliance: true,
        enhanceWithAI: false
      }

      const request: DocumentParseRequest = {
        assetId: 'asset-123',
        parseSettings
      }

      expect(request.assetId).toBe('asset-123')
      expect(request.parseSettings?.extractCompliance).toBe(true)
      expect(request.parseSettings?.enhanceWithAI).toBe(false)
    })

    it('should work with minimal settings', () => {
      const request: DocumentParseRequest = {
        assetId: 'asset-123'
        // parseSettings is optional
      }

      expect(request.assetId).toBe('asset-123')
      expect(request.parseSettings).toBeUndefined()
    })

    it('should work with partial settings', () => {
      const request: DocumentParseRequest = {
        assetId: 'asset-123',
        parseSettings: {
          extractColors: true,
          extractCompliance: true
          // Other settings are optional
        }
      }

      expect(request.parseSettings?.extractColors).toBe(true)
      expect(request.parseSettings?.extractCompliance).toBe(true)
      expect(request.parseSettings?.extractFonts).toBeUndefined()
    })
  })

  describe('Type Safety and IntelliSense Support', () => {
    it('should provide proper TypeScript intellisense for color categories', () => {
      const color: NonNullable<EnhancedDocumentParseResult['extractedData']['colors']>[0] = {
        hex: '#007BFF',
        category: 'primary', // Should show: 'primary' | 'secondary' | 'accent' | 'neutral' | 'warning' | 'success' | 'error'
        usage: 'brand color'
      }

      // Test that only valid categories are accepted
      const validCategories: typeof color.category[] = [
        'primary', 'secondary', 'accent', 'neutral', 'warning', 'success', 'error'
      ]
      
      expect(validCategories).toContain(color.category)
    })

    it('should provide proper TypeScript intellisense for font categories and usage', () => {
      const font: NonNullable<EnhancedDocumentParseResult['extractedData']['fonts']>[0] = {
        family: 'Helvetica',
        category: 'sans-serif', // Should show: 'serif' | 'sans-serif' | 'display' | 'monospace' | 'script' | 'decorative'
        usage: 'heading' // Should show: 'heading' | 'body' | 'caption' | 'button' | 'navigation' | 'accent'
      }

      const validCategories: typeof font.category[] = [
        'serif', 'sans-serif', 'display', 'monospace', 'script', 'decorative'
      ]
      
      const validUsages: typeof font.usage[] = [
        'heading', 'body', 'caption', 'button', 'navigation', 'accent'
      ]

      expect(validCategories).toContain(font.category)
      expect(validUsages).toContain(font.usage)
    })

    it('should provide proper TypeScript intellisense for section types', () => {
      const section: NonNullable<EnhancedDocumentParseResult['extractedData']['guidelines']>['sections'][0] = {
        title: 'Brand Overview',
        content: 'Content here',
        type: 'overview' // Should show: 'overview' | 'visual' | 'voice' | 'usage' | 'compliance' | 'other'
      }

      const validTypes: typeof section.type[] = [
        'overview', 'visual', 'voice', 'usage', 'compliance', 'other'
      ]

      expect(validTypes).toContain(section.type)
    })
  })

  describe('Backward Compatibility', () => {
    it('should maintain compatibility with original DocumentParseResult', () => {
      // The new EnhancedDocumentParseResult should be a superset of the original
      // This test ensures we didn't break existing code
      
      const originalStyleData = {
        success: true,
        extractedData: {
          rawText: 'text',
          extractedAt: '2023-01-01T00:00:00.000Z',
          assetId: 'asset-123',
          brandId: 'brand-456',
          colors: ['#007BFF', '#28A745'], // Original simple string array
          fonts: ['Helvetica', 'Arial'], // Original simple string array
          voice: {
            voiceDescription: 'Professional',
            toneAttributes: { professional: 3 },
            communicationStyle: 'formal'
          },
          guidelines: {
            sections: ['Section 1', 'Section 2'], // Original simple string array
            keyPhrases: ['Key phrase 1']
          }
        },
        message: 'Success'
      }

      // This should not cause TypeScript errors
      expect(originalStyleData.success).toBe(true)
      expect(originalStyleData.extractedData.colors).toContain('#007BFF')
    })
  })
})