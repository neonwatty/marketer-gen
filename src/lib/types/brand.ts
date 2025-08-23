import { Brand, BrandAsset, BrandAssetType,ColorPalette, Typography } from "@/generated/prisma"

// Base brand types from Prisma
export type { Brand, BrandAsset, BrandAssetType,ColorPalette, Typography }

// Extended brand types with relationships
export type BrandWithRelations = Brand & {
  user: {
    id: string
    name: string | null
    email: string
  }
  campaigns: {
    id: string
    name: string
    status: string
  }[]
  brandAssets: BrandAsset[]
  colorPalette: ColorPalette[]
  typography: Typography[]
  _count: {
    campaigns: number
    brandAssets: number
    colorPalette: number
    typography: number
  }
}

export type BrandSummary = Pick<Brand, 
  "id" | "name" | "description" | "industry" | "tagline" | "createdAt" | "updatedAt"
> & {
  user: {
    id: string
    name: string | null
    email: string
  }
  _count: {
    campaigns: number
    brandAssets: number
  }
}

// Brand creation and update types
export type CreateBrandData = Omit<Brand, 
  "id" | "userId" | "createdAt" | "updatedAt" | "deletedAt" | "createdBy" | "updatedBy"
>

export type UpdateBrandData = Partial<CreateBrandData>

// Brand asset types
export type CreateBrandAssetData = Omit<BrandAsset,
  "id" | "brandId" | "createdAt" | "updatedAt" | "deletedAt" | "createdBy" | "updatedBy" | "downloadCount" | "lastUsed"
>

export type UpdateBrandAssetData = Partial<CreateBrandAssetData & {
  isActive: boolean
}>

// Color palette types
export type ColorInfo = {
  name: string
  hex: string
  rgb: string
  usage: string
}

export type CreateColorPaletteData = Omit<ColorPalette,
  "id" | "brandId" | "createdAt" | "updatedAt" | "deletedAt" | "createdBy" | "updatedBy"
> & {
  colors: ColorInfo[]
}

// Typography types
export type CreateTypographyData = Omit<Typography,
  "id" | "brandId" | "createdAt" | "updatedAt" | "deletedAt" | "createdBy" | "updatedBy"
> & {
  fallbackFonts?: string[]
}

// Brand profile sections for form organization
export type BrandIdentityData = {
  name: string
  description?: string
  industry?: string
  website?: string
  tagline?: string
  mission?: string
  vision?: string
  values?: string[]
  personality?: string[]
}

export type BrandVoiceData = {
  voiceDescription?: string
  toneAttributes?: Record<string, number>
  communicationStyle?: string
  messagingFramework?: {
    primary: string
    secondary: string[]
    support: string[]
  }
}

export type BrandGuidelinesData = {
  brandPillars?: string[]
  targetAudience?: {
    primary: string
    secondary: string
    demographics: {
      age_range: string
      job_titles: string[]
      company_size: string
      industry: string[]
    }
  }
  competitivePosition?: string
  brandPromise?: string
}

export type BrandComplianceData = {
  complianceRules?: Record<string, string>
  usageGuidelines?: {
    do: string[]
    dont: string[]
  }
  restrictedTerms?: string[]
}

// Asset category types
export const ASSET_CATEGORIES = {
  LOGO: ["Primary Logo", "Secondary Logo", "Logo Variations", "Logo Marks"],
  BRAND_MARK: ["Brand Mark", "Icon", "Symbol"],
  COLOR_PALETTE: ["Primary Colors", "Secondary Colors", "Accent Colors"],
  TYPOGRAPHY: ["Primary Fonts", "Secondary Fonts", "Display Fonts"],
  BRAND_GUIDELINES: ["Brand Book", "Style Guide", "Usage Guidelines"],
  IMAGERY: ["Photography", "Illustrations", "Graphics"],
  ICON: ["UI Icons", "Social Icons", "Custom Icons"],
  PATTERN: ["Background Patterns", "Decorative Elements"],
  TEMPLATE: ["Document Templates", "Presentation Templates"],
  DOCUMENT: ["Brand Documents", "Legal Documents"],
  VIDEO: ["Brand Videos", "Promotional Videos"],
  AUDIO: ["Brand Audio", "Jingles", "Voice Recordings"],
  OTHER: ["Miscellaneous", "Custom Assets"],
} as const

// Tone attribute ranges (0-10 scale)
export type ToneAttribute = 
  | "formal"
  | "friendly" 
  | "authoritative"
  | "innovative"
  | "trustworthy"
  | "playful"
  | "sophisticated"
  | "approachable"
  | "professional"
  | "energetic"

export const TONE_ATTRIBUTES: Record<ToneAttribute, string> = {
  formal: "Formal",
  friendly: "Friendly",
  authoritative: "Authoritative", 
  innovative: "Innovative",
  trustworthy: "Trustworthy",
  playful: "Playful",
  sophisticated: "Sophisticated",
  approachable: "Approachable",
  professional: "Professional",
  energetic: "Energetic",
}

// Industry options
export const INDUSTRIES = [
  "Technology",
  "Healthcare",
  "Finance",
  "Education",
  "Retail",
  "Manufacturing",
  "Consulting",
  "Media",
  "Non-profit",
  "Government",
  "Real Estate",
  "Food & Beverage",
  "Travel & Tourism",
  "Automotive",
  "Energy",
  "Consumer Goods",
  "B2B Services",
  "E-commerce",
  "Entertainment",
  "Other",
] as const

export type Industry = typeof INDUSTRIES[number]

// Brand validation helpers
// Document parsing types
export type DocumentParseSettings = {
  extractColors?: boolean
  extractFonts?: boolean
  extractVoice?: boolean
  extractGuidelines?: boolean
}

export type ExtractedVoiceData = {
  voiceDescription: string | null
  toneAttributes: Record<string, number>
  communicationStyle: string | null
}

export type ExtractedGuidelinesData = {
  sections: string[]
  keyPhrases: string[]
}

export type DocumentParseResult = {
  success: boolean
  extractedData: {
    rawText: string
    extractedAt: string
    assetId: string
    brandId: string
    colors?: string[]
    fonts?: string[]
    voice?: ExtractedVoiceData
    guidelines?: ExtractedGuidelinesData
  }
  message: string
}

// Enhanced processing result types
export type EnhancedDocumentParseResult = {
  success: boolean
  extractedData: {
    rawText: string
    extractedAt: string
    assetId: string
    brandId: string
    colors?: Array<{
      hex?: string
      rgb?: string
      hsl?: string
      pantone?: string
      cmyk?: string
      name?: string
      usage?: string
      category: 'primary' | 'secondary' | 'accent' | 'neutral' | 'warning' | 'success' | 'error'
    }>
    fonts?: Array<{
      family: string
      category: 'serif' | 'sans-serif' | 'display' | 'monospace' | 'script' | 'decorative'
      usage: 'heading' | 'body' | 'caption' | 'button' | 'navigation' | 'accent'
      weight?: string
      fallbacks?: string[]
    }>
    voice?: {
      voiceDescription: string | null
      toneAttributes: Record<string, number>
      communicationStyle: string | null
      personality: string[]
      messaging: {
        primary?: string
        secondary?: string[]
        prohibited?: string[]
      }
    }
    guidelines?: {
      sections: Array<{
        title: string
        content: string
        type: 'overview' | 'visual' | 'voice' | 'usage' | 'compliance' | 'other'
      }>
      keyPhrases: string[]
      brandPillars: string[]
      targetAudience?: {
        primary: string
        demographics: Record<string, any>
      }
    }
    compliance?: {
      usageRules: {
        do: string[]
        dont: string[]
      }
      restrictedTerms: string[]
      legalRequirements: string[]
      approvalProcess?: string
    }
    confidence: {
      overall: number
      colors: number
      fonts: number
      voice: number
      guidelines: number
      compliance: number
    }
    suggestions: string[]
  }
  message: string
  processingInfo: {
    engine: string
    version: string
    extractedAt: string
    elementsFound: {
      colors: number
      fonts: number
      voiceAttributes: number
      guidelineSections: number
      complianceRules: number
    }
    confidence: {
      overall: number
      colors: number
      fonts: number
      voice: number
      guidelines: number
      compliance: number
    }
    suggestions: string[]
  }
}

export type DocumentParseRequest = {
  assetId: string
  parseSettings?: DocumentParseSettings
}

// Supported document types for parsing
export const PARSEABLE_ASSET_TYPES = ['BRAND_GUIDELINES', 'DOCUMENT'] as const
export const PARSEABLE_MIME_TYPES = [
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/msword',
  'text/plain'
] as const

export type ParseableAssetType = typeof PARSEABLE_ASSET_TYPES[number]
export type ParseableMimeType = typeof PARSEABLE_MIME_TYPES[number]

export const validateBrandData = (data: Partial<CreateBrandData>): string[] => {
  const errors: string[] = []

  if (!data.name || data.name.trim().length === 0) {
    errors.push("Brand name is required")
  }

  if (data.website && data.website.length > 0) {
    try {
      new URL(data.website)
    } catch {
      errors.push("Website must be a valid URL")
    }
  }

  if (data.values && Array.isArray(data.values) && data.values.length > 10) {
    errors.push("Maximum 10 brand values allowed")
  }

  if (data.personality && Array.isArray(data.personality) && data.personality.length > 8) {
    errors.push("Maximum 8 personality traits allowed")
  }

  if (data.brandPillars && Array.isArray(data.brandPillars) && data.brandPillars.length > 6) {
    errors.push("Maximum 6 brand pillars allowed")
  }

  return errors
}