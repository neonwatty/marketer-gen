import {
  validateBrandData,
  ASSET_CATEGORIES,
  TONE_ATTRIBUTES,
  INDUSTRIES,
  BrandAssetType,
  ToneAttribute,
  Industry,
  CreateBrandData,
  BrandWithRelations,
  BrandSummary,
  CreateBrandAssetData,
  UpdateBrandAssetData,
  CreateColorPaletteData,
  CreateTypographyData,
  BrandIdentityData,
  BrandVoiceData,
  BrandGuidelinesData,
  BrandComplianceData,
} from '@/lib/types/brand'

describe('Brand Types and Validation', () => {
  describe('validateBrandData', () => {
    it('validates required brand name', () => {
      const invalidData = {} as Partial<CreateBrandData>
      const errors = validateBrandData(invalidData)
      
      expect(errors).toContain('Brand name is required')
    })

    it('validates empty brand name', () => {
      const invalidData = { name: '   ' } as Partial<CreateBrandData>
      const errors = validateBrandData(invalidData)
      
      expect(errors).toContain('Brand name is required')
    })

    it('accepts valid brand name', () => {
      const validData = { name: 'Test Brand' } as Partial<CreateBrandData>
      const errors = validateBrandData(validData)
      
      expect(errors).not.toContain('Brand name is required')
    })

    it('validates website URL format', () => {
      const invalidData = {
        name: 'Test Brand',
        website: 'not-a-url'
      } as Partial<CreateBrandData>
      const errors = validateBrandData(invalidData)
      
      expect(errors).toContain('Website must be a valid URL')
    })

    it('accepts valid website URLs', () => {
      const validData = {
        name: 'Test Brand',
        website: 'https://example.com'
      } as Partial<CreateBrandData>
      const errors = validateBrandData(validData)
      
      expect(errors).not.toContain('Website must be a valid URL')
    })

    it('accepts empty website string', () => {
      const validData = {
        name: 'Test Brand',
        website: ''
      } as Partial<CreateBrandData>
      const errors = validateBrandData(validData)
      
      expect(errors).not.toContain('Website must be a valid URL')
    })

    it('accepts undefined website', () => {
      const validData = {
        name: 'Test Brand',
        website: undefined
      } as Partial<CreateBrandData>
      const errors = validateBrandData(validData)
      
      expect(errors).not.toContain('Website must be a valid URL')
    })

    it('validates brand values array length', () => {
      const invalidData = {
        name: 'Test Brand',
        values: Array(11).fill('value') // Max is 10
      } as Partial<CreateBrandData>
      const errors = validateBrandData(invalidData)
      
      expect(errors).toContain('Maximum 10 brand values allowed')
    })

    it('accepts valid brand values array', () => {
      const validData = {
        name: 'Test Brand',
        values: ['quality', 'innovation', 'trust']
      } as Partial<CreateBrandData>
      const errors = validateBrandData(validData)
      
      expect(errors).not.toContain('Maximum 10 brand values allowed')
    })

    it('validates personality array length', () => {
      const invalidData = {
        name: 'Test Brand',
        personality: Array(9).fill('trait') // Max is 8
      } as Partial<CreateBrandData>
      const errors = validateBrandData(invalidData)
      
      expect(errors).toContain('Maximum 8 personality traits allowed')
    })

    it('accepts valid personality array', () => {
      const validData = {
        name: 'Test Brand',
        personality: ['professional', 'friendly', 'innovative']
      } as Partial<CreateBrandData>
      const errors = validateBrandData(validData)
      
      expect(errors).not.toContain('Maximum 8 personality traits allowed')
    })

    it('validates brand pillars array length', () => {
      const invalidData = {
        name: 'Test Brand',
        brandPillars: Array(7).fill('pillar') // Max is 6
      } as Partial<CreateBrandData>
      const errors = validateBrandData(invalidData)
      
      expect(errors).toContain('Maximum 6 brand pillars allowed')
    })

    it('accepts valid brand pillars array', () => {
      const validData = {
        name: 'Test Brand',
        brandPillars: ['Quality', 'Innovation', 'Trust']
      } as Partial<CreateBrandData>
      const errors = validateBrandData(validData)
      
      expect(errors).not.toContain('Maximum 6 brand pillars allowed')
    })

    it('handles null/undefined arrays gracefully', () => {
      const validData = {
        name: 'Test Brand',
        values: null,
        personality: undefined,
        brandPillars: null
      } as any
      const errors = validateBrandData(validData)
      
      expect(errors).toHaveLength(0)
    })

    it('handles non-array values gracefully', () => {
      const invalidData = {
        name: 'Test Brand',
        values: 'not-an-array',
        personality: 123,
        brandPillars: 'also-not-an-array'
      } as any
      const errors = validateBrandData(invalidData)
      
      expect(errors).toHaveLength(0) // Should not crash, just ignore invalid array types
    })

    it('returns multiple validation errors', () => {
      const invalidData = {
        name: '',
        website: 'invalid-url',
        values: Array(11).fill('value'),
        personality: Array(9).fill('trait'),
        brandPillars: Array(7).fill('pillar')
      } as Partial<CreateBrandData>
      const errors = validateBrandData(invalidData)
      
      expect(errors).toHaveLength(5)
      expect(errors).toContain('Brand name is required')
      expect(errors).toContain('Website must be a valid URL')
      expect(errors).toContain('Maximum 10 brand values allowed')
      expect(errors).toContain('Maximum 8 personality traits allowed')
      expect(errors).toContain('Maximum 6 brand pillars allowed')
    })

    it('returns empty array for valid data', () => {
      const validData = {
        name: 'Test Brand',
        description: 'A test brand',
        industry: 'Technology',
        website: 'https://example.com',
        tagline: 'Innovation at its best',
        mission: 'To innovate',
        vision: 'A better future',
        values: ['quality', 'innovation'],
        personality: ['professional', 'innovative'],
        voiceDescription: 'Professional and friendly',
        toneAttributes: { formal: 7, friendly: 8 },
        communicationStyle: 'Clear and direct',
        messagingFramework: { primary: 'Quality first' },
        brandPillars: ['Quality', 'Innovation'],
        targetAudience: { primary: 'Tech professionals' },
        competitivePosition: 'Premium provider',
        brandPromise: 'Reliable solutions',
        complianceRules: {},
        usageGuidelines: {},
        restrictedTerms: []
      } as Partial<CreateBrandData>
      const errors = validateBrandData(validData)
      
      expect(errors).toHaveLength(0)
    })
  })

  describe('ASSET_CATEGORIES', () => {
    it('contains all expected asset types', () => {
      const expectedTypes: BrandAssetType[] = [
        'LOGO', 'BRAND_MARK', 'COLOR_PALETTE', 'TYPOGRAPHY', 'BRAND_GUIDELINES',
        'IMAGERY', 'ICON', 'PATTERN', 'TEMPLATE', 'DOCUMENT', 'VIDEO', 'AUDIO', 'OTHER'
      ]
      
      expectedTypes.forEach(type => {
        expect(ASSET_CATEGORIES[type]).toBeDefined()
        expect(Array.isArray(ASSET_CATEGORIES[type])).toBe(true)
        expect(ASSET_CATEGORIES[type].length).toBeGreaterThan(0)
      })
    })

    it('has valid categories for LOGO', () => {
      expect(ASSET_CATEGORIES.LOGO).toEqual([
        'Primary Logo', 'Secondary Logo', 'Logo Variations', 'Logo Marks'
      ])
    })

    it('has valid categories for COLOR_PALETTE', () => {
      expect(ASSET_CATEGORIES.COLOR_PALETTE).toEqual([
        'Primary Colors', 'Secondary Colors', 'Accent Colors'
      ])
    })

    it('has valid categories for TYPOGRAPHY', () => {
      expect(ASSET_CATEGORIES.TYPOGRAPHY).toEqual([
        'Primary Fonts', 'Secondary Fonts', 'Display Fonts'
      ])
    })

    it('has Other category for miscellaneous assets', () => {
      expect(ASSET_CATEGORIES.OTHER).toEqual([
        'Miscellaneous', 'Custom Assets'
      ])
    })
  })

  describe('TONE_ATTRIBUTES', () => {
    it('contains all expected tone attributes', () => {
      const expectedAttributes: ToneAttribute[] = [
        'formal', 'friendly', 'authoritative', 'innovative', 'trustworthy',
        'playful', 'sophisticated', 'approachable', 'professional', 'energetic'
      ]
      
      expectedAttributes.forEach(attr => {
        expect(TONE_ATTRIBUTES[attr]).toBeDefined()
        expect(typeof TONE_ATTRIBUTES[attr]).toBe('string')
      })
    })

    it('has proper display names for tone attributes', () => {
      expect(TONE_ATTRIBUTES.formal).toBe('Formal')
      expect(TONE_ATTRIBUTES.friendly).toBe('Friendly')
      expect(TONE_ATTRIBUTES.authoritative).toBe('Authoritative')
      expect(TONE_ATTRIBUTES.professional).toBe('Professional')
    })

    it('has all keys as valid ToneAttribute types', () => {
      Object.keys(TONE_ATTRIBUTES).forEach(key => {
        expect(['formal', 'friendly', 'authoritative', 'innovative', 'trustworthy',
                'playful', 'sophisticated', 'approachable', 'professional', 'energetic'])
          .toContain(key)
      })
    })
  })

  describe('INDUSTRIES', () => {
    it('contains expected industries', () => {
      const expectedIndustries = [
        'Technology', 'Healthcare', 'Finance', 'Education', 'Retail',
        'Manufacturing', 'Consulting', 'Media', 'Non-profit', 'Government',
        'Real Estate', 'Food & Beverage', 'Travel & Tourism', 'Automotive',
        'Energy', 'Consumer Goods', 'B2B Services', 'E-commerce',
        'Entertainment', 'Other'
      ]
      
      expectedIndustries.forEach(industry => {
        expect(INDUSTRIES).toContain(industry as Industry)
      })
    })

    it('includes "Other" as fallback option', () => {
      expect(INDUSTRIES).toContain('Other')
    })

    it('has reasonable industry coverage', () => {
      expect(INDUSTRIES.length).toBeGreaterThan(15)
      expect(INDUSTRIES).toContain('Technology')
      expect(INDUSTRIES).toContain('Healthcare')
      expect(INDUSTRIES).toContain('Finance')
    })
  })

  describe('Type Definitions', () => {
    it('BrandWithRelations includes all expected fields', () => {
      // This test ensures the type is well-formed (compilation test)
      const brand: BrandWithRelations = {
        id: 'brand-1',
        name: 'Test Brand',
        description: 'Test description',
        industry: 'Technology',
        website: 'https://example.com',
        tagline: 'Test tagline',
        mission: 'Test mission',
        vision: 'Test vision',
        values: ['quality'],
        personality: ['professional'],
        voiceDescription: 'Professional',
        toneAttributes: { formal: 7 },
        communicationStyle: 'Direct',
        messagingFramework: { primary: 'Quality' },
        brandPillars: ['Quality'],
        targetAudience: { primary: 'Professionals' },
        competitivePosition: 'Premium',
        brandPromise: 'Quality service',
        complianceRules: {},
        usageGuidelines: {},
        restrictedTerms: [],
        userId: 'user-1',
        createdAt: new Date(),
        updatedAt: new Date(),
        deletedAt: null,
        createdBy: 'user-1',
        updatedBy: 'user-1',
        user: {
          id: 'user-1',
          name: 'Test User',
          email: 'test@example.com'
        },
        campaigns: [],
        brandAssets: [],
        colorPalette: [],
        typography: [],
        _count: {
          campaigns: 0,
          brandAssets: 0,
          colorPalette: 0,
          typography: 0
        }
      }
      
      expect(brand.id).toBe('brand-1')
      expect(brand.user.email).toBe('test@example.com')
      expect(brand._count.campaigns).toBe(0)
    })

    it('BrandSummary includes required fields only', () => {
      const summary: BrandSummary = {
        id: 'brand-1',
        name: 'Test Brand',
        description: 'Test description',
        industry: 'Technology',
        tagline: 'Test tagline',
        createdAt: new Date(),
        updatedAt: new Date(),
        user: {
          id: 'user-1',
          name: 'Test User',
          email: 'test@example.com'
        },
        _count: {
          campaigns: 5,
          brandAssets: 10
        }
      }
      
      expect(summary.id).toBe('brand-1')
      expect(summary._count.campaigns).toBe(5)
    })

    it('CreateBrandAssetData excludes system fields', () => {
      const assetData: CreateBrandAssetData = {
        name: 'Test Asset',
        description: 'Test description',
        type: 'LOGO',
        fileName: 'logo.png',
        fileUrl: 'https://example.com/logo.png',
        fileSize: 12345,
        mimeType: 'image/png',
        category: 'Primary Logo',
        tags: ['logo'],
        metadata: { width: 400 },
        version: '1.0',
        isActive: true
      }
      
      expect(assetData.name).toBe('Test Asset')
      expect(assetData.type).toBe('LOGO')
      // Should not have system fields like id, createdAt, etc.
    })

    it('CreateColorPaletteData includes colors array', () => {
      const paletteData: CreateColorPaletteData = {
        name: 'Primary Palette',
        description: 'Main brand colors',
        isPrimary: true,
        isActive: true,
        colors: [
          {
            name: 'Primary Blue',
            hex: '#007bff',
            rgb: 'rgb(0, 123, 255)',
            usage: 'Primary buttons and links'
          }
        ]
      }
      
      expect(paletteData.colors).toHaveLength(1)
      expect(paletteData.colors[0].hex).toBe('#007bff')
    })

    it('BrandIdentityData captures core brand information', () => {
      const identity: BrandIdentityData = {
        name: 'Test Brand',
        description: 'A test brand',
        industry: 'Technology',
        website: 'https://example.com',
        tagline: 'Innovation first',
        mission: 'To innovate',
        vision: 'Better future',
        values: ['quality', 'trust'],
        personality: ['professional', 'innovative']
      }
      
      expect(identity.name).toBe('Test Brand')
      expect(identity.values).toContain('quality')
      expect(identity.personality).toContain('professional')
    })

    it('BrandVoiceData captures voice and tone', () => {
      const voice: BrandVoiceData = {
        voiceDescription: 'Professional and approachable',
        toneAttributes: {
          formal: 7,
          friendly: 8,
          professional: 9
        },
        communicationStyle: 'Clear and direct',
        messagingFramework: {
          primary: 'Quality first',
          secondary: ['Innovation', 'Trust'],
          support: ['Customer focus']
        }
      }
      
      expect(voice.toneAttributes?.formal).toBe(7)
      expect(voice.messagingFramework?.primary).toBe('Quality first')
    })

    it('BrandGuidelinesData captures strategic information', () => {
      const guidelines: BrandGuidelinesData = {
        brandPillars: ['Quality', 'Innovation'],
        targetAudience: {
          primary: 'Tech professionals',
          secondary: 'Decision makers',
          demographics: {
            age_range: '25-45',
            job_titles: ['Developer', 'Manager'],
            company_size: '50-500',
            industry: ['Technology']
          }
        },
        competitivePosition: 'Premium provider',
        brandPromise: 'Reliable solutions'
      }
      
      expect(guidelines.brandPillars).toContain('Quality')
      expect(guidelines.targetAudience?.demographics.age_range).toBe('25-45')
    })

    it('BrandComplianceData captures usage rules', () => {
      const compliance: BrandComplianceData = {
        complianceRules: {
          legal: 'Include disclaimers',
          accessibility: 'Meet WCAG 2.1 AA'
        },
        usageGuidelines: {
          do: ['Use official colors', 'Maintain spacing'],
          dont: ['Distort logo', 'Use unofficial colors']
        },
        restrictedTerms: ['competitor1', 'competitor2']
      }
      
      expect(compliance.usageGuidelines?.do).toContain('Use official colors')
      expect(compliance.restrictedTerms).toContain('competitor1')
    })
  })

  describe('Edge Cases', () => {
    it('handles empty arrays in validation', () => {
      const data = {
        name: 'Test Brand',
        values: [],
        personality: [],
        brandPillars: []
      } as Partial<CreateBrandData>
      const errors = validateBrandData(data)
      
      expect(errors).toHaveLength(0)
    })

    it('handles maximum valid array lengths', () => {
      const data = {
        name: 'Test Brand',
        values: Array(10).fill('value'),      // Max is 10
        personality: Array(8).fill('trait'),  // Max is 8
        brandPillars: Array(6).fill('pillar') // Max is 6
      } as Partial<CreateBrandData>
      const errors = validateBrandData(data)
      
      expect(errors).toHaveLength(0)
    })

    it('handles various URL formats', () => {
      const validUrls = [
        'https://example.com',
        'http://example.com',
        'https://subdomain.example.com',
        'https://example.com/path',
        'https://example.com:8080',
        'https://example.co.uk'
      ]
      
      validUrls.forEach(url => {
        const data = { name: 'Test', website: url } as Partial<CreateBrandData>
        const errors = validateBrandData(data)
        expect(errors).not.toContain('Website must be a valid URL')
      })
    })

    it('rejects invalid URL formats', () => {
      const invalidUrls = [
        'not-a-url',
        'example.com',
        'www.example.com',
        'https://',
        'invalid-url-format'
      ]
      
      invalidUrls.forEach(url => {
        const data = { name: 'Test', website: url } as Partial<CreateBrandData>
        const errors = validateBrandData(data)
        expect(errors).toContain('Website must be a valid URL')
      })
    })

    it('accepts URLs that are technically valid but might seem unusual', () => {
      const technicallyValidUrls = [
        'ftp://example.com', // Valid URL, just different protocol
        'javascript:alert(1)', // Valid URL syntax, though not recommended
      ]
      
      technicallyValidUrls.forEach(url => {
        const data = { name: 'Test', website: url } as Partial<CreateBrandData>
        const errors = validateBrandData(data)
        // Should not contain URL error since URL constructor accepts these
        expect(errors).not.toContain('Website must be a valid URL')
      })
    })
  })
})