import mammoth from "mammoth"

// Types for the processing engine
export interface BrandGuidelinesProcessingSettings {
  extractColors?: boolean
  extractFonts?: boolean
  extractVoice?: boolean
  extractGuidelines?: boolean
  extractCompliance?: boolean
  enhanceWithAI?: boolean
}

export interface ColorExtraction {
  hex?: string
  rgb?: string
  hsl?: string
  pantone?: string
  cmyk?: string
  name?: string
  usage?: string
  category: 'primary' | 'secondary' | 'accent' | 'neutral' | 'warning' | 'success' | 'error'
}

export interface FontExtraction {
  family: string
  category: 'serif' | 'sans-serif' | 'display' | 'monospace' | 'script' | 'decorative'
  usage: 'heading' | 'body' | 'caption' | 'button' | 'navigation' | 'accent'
  weight?: string
  fallbacks?: string[]
}

export interface VoiceExtraction {
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

export interface GuidelinesExtraction {
  sections: {
    title: string
    content: string
    type: 'overview' | 'visual' | 'voice' | 'usage' | 'compliance' | 'other'
  }[]
  keyPhrases: string[]
  brandPillars: string[]
  targetAudience?: {
    primary: string
    demographics: Record<string, any>
  }
}

export interface ComplianceExtraction {
  usageRules: {
    do: string[]
    dont: string[]
  }
  restrictedTerms: string[]
  legalRequirements: string[]
  approvalProcess?: string
}

export interface ProcessedBrandData {
  rawText: string
  extractedAt: string
  assetId: string
  brandId: string
  colors?: ColorExtraction[]
  fonts?: FontExtraction[]
  voice?: VoiceExtraction
  guidelines?: GuidelinesExtraction
  compliance?: ComplianceExtraction
  confidence: {
    overall: number
    colors: number
    fonts: number
    voice: number
    guidelines: number
    compliance: number
  }
  suggestions: string[]
  [key: string]: any
}

export class BrandGuidelinesProcessor {
  // Enhanced color extraction patterns
  private static readonly COLOR_PATTERNS = {
    hex: /#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\b/g,
    rgb: /(?:rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)|RGB:\s*(\d+),\s*(\d+),\s*(\d+))/gi,
    rgba: /rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)/gi,
    hsl: /(?:hsl\s*\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)|HSL:\s*(\d+),\s*(\d+)%,\s*(\d+)%)/gi,
    pantone: /pantone\s+(\w+(?:\s+\w+)*)/gi,
    cmyk: /(?:cmyk\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)|CMYK:\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+))/gi,
    named: /(primary|secondary|brand|accent)\s+colou?r\s*:\s*([^;\n]+)/gi,
  }

  // Enhanced font detection patterns
  private static readonly FONT_PATTERNS = {
    family: /font-family\s*:\s*([^;]+)/gi,
    typeface: /typeface\s*:\s*([^\n\r.]+)/gi,
    fontDeclaration: /font\s*:\s*([^\n\r.;,]+)/gi,
    quoted: /"([^"]+)"|'([^']+)'/g,
    webfonts: /(google\s+fonts?|typekit|fonts\.com|myfonts)\s*:\s*([^\n\r.;,]+)/gi,
    commonFonts: /(arial|helvetica|times|georgia|verdana|trebuchet|impact|comic sans|courier|palatino|garamond|futura|avant garde|optima|gill sans|franklin gothic|century gothic|lucida|tahoma|calibri|cambria|segoe|roboto|open sans|lato|montserrat|source sans|ubuntu|droid|noto|poppins|nunito|inter|work sans|playfair|crimson|merriweather|pt serif|source serif|bitter|vollkorn|gentium|eb garamond|libre baskerville|fira code)(?:\s+(?:pro|light|bold|black|thin|extra|ultra|semi|demi|condensed|extended|italic|oblique|regular|medium|normal))*\b/gi,
  }

  // Voice and tone indicators
  private static readonly VOICE_INDICATORS = {
    toneKeywords: {
      formal: ['formal', 'professional', 'corporate', 'business', 'official'],
      friendly: ['friendly', 'warm', 'welcoming', 'approachable', 'personable'],
      authoritative: ['authoritative', 'expert', 'credible', 'commanding', 'confident'],
      innovative: ['innovative', 'cutting-edge', 'modern', 'forward-thinking', 'progressive'],
      trustworthy: ['trustworthy', 'reliable', 'dependable', 'honest', 'authentic'],
      playful: ['playful', 'fun', 'whimsical', 'lighthearted', 'cheerful'],
      sophisticated: ['sophisticated', 'elegant', 'refined', 'polished', 'premium'],
      approachable: ['approachable', 'accessible', 'down-to-earth', 'relatable', 'human'],
      professional: ['professional', 'competent', 'skilled', 'experienced', 'qualified'],
      energetic: ['energetic', 'dynamic', 'vibrant', 'enthusiastic', 'passionate'],
    },
    communicationStyles: ['conversational', 'formal', 'casual', 'technical', 'storytelling', 'direct'],
    personalityTraits: ['innovative', 'reliable', 'trustworthy', 'modern', 'traditional', 'bold', 'subtle', 'authentic'],
  }

  // Section type classifiers
  private static readonly SECTION_CLASSIFIERS = {
    overview: ['introduction', 'overview', 'about', 'mission', 'vision', 'values', 'purpose'],
    visual: ['visual', 'color', 'typography', 'logo', 'imagery', 'design', 'aesthetic'],
    voice: ['voice', 'tone', 'messaging', 'communication', 'language', 'style'],
    usage: ['usage', 'application', 'implementation', 'guidelines', 'examples'],
    compliance: ['compliance', 'legal', 'copyright', 'trademark', 'restrictions', 'approval'],
  }

  /**
   * Parse document content from buffer based on MIME type
   */
  static async parseDocumentContent(buffer: Buffer, mimeType: string): Promise<string> {
    switch (mimeType) {
      case 'application/pdf':
        try {
          // Dynamic import to avoid build-time issues with pdf-parse debug code
          const pdf = await import('pdf-parse').then(module => module.default)
          const pdfData = await pdf(buffer)
          return pdfData?.text || ''
        } catch (pdfError) {
          throw new Error(`PDF parsing failed: ${pdfError instanceof Error ? pdfError.message : 'Unknown error'}`)
        }

      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      case 'application/msword':
        try {
          const docxResult = await mammoth.extractRawText({ buffer })
          return docxResult?.value || ''
        } catch (docxError) {
          throw new Error(`DOCX parsing failed: ${docxError instanceof Error ? docxError.message : 'Unknown error'}`)
        }

      case 'text/plain':
        return buffer.toString('utf-8')

      default:
        // Try to parse as text for unknown types
        return buffer.toString('utf-8')
    }
  }

  /**
   * Extract and categorize colors from text
   */
  private static extractColors(text: string): ColorExtraction[] {
    const colors: ColorExtraction[] = []
    const foundColors = new Set<string>()

    // Extract hex colors
    const hexMatches = text.match(this.COLOR_PATTERNS.hex)
    if (hexMatches) {
      hexMatches.forEach(match => {
        if (!foundColors.has(match.toLowerCase())) {
          foundColors.add(match.toLowerCase())
          colors.push({
            hex: match.toUpperCase(),
            category: this.categorizeColor(match, text),
            usage: this.extractColorUsage(match, text)
          })
        }
      })
    }

    // Extract RGB colors
    let rgbMatch
    const rgbPattern = new RegExp(this.COLOR_PATTERNS.rgb.source, 'gi')
    while ((rgbMatch = rgbPattern.exec(text)) !== null) {
      // Handle both rgb(r, g, b) and RGB: r, g, b formats
      const [full, r1, g1, b1, r2, g2, b2] = rgbMatch
      const r = r1 || r2
      const g = g1 || g2
      const b = b1 || b2
      
      if (r && g && b) {
        const rgbString = `rgb(${r}, ${g}, ${b})`
        if (!foundColors.has(rgbString.toLowerCase())) {
          foundColors.add(rgbString.toLowerCase())
          colors.push({
            rgb: rgbString,
            hex: this.rgbToHex(parseInt(r), parseInt(g), parseInt(b)),
            category: this.categorizeColor(full, text),
            usage: this.extractColorUsage(full, text)
          })
        }
      }
    }

    // Extract Pantone colors
    const pantoneMatches = text.match(this.COLOR_PATTERNS.pantone)
    if (pantoneMatches) {
      pantoneMatches.forEach(match => {
        const pantoneValue = match.replace(/pantone\s+/gi, '').trim()
        if (!foundColors.has(pantoneValue.toLowerCase())) {
          foundColors.add(pantoneValue.toLowerCase())
          
          // Look for hex value near the pantone color in the text
          const lines = text.split('\n')
          const matchingLine = lines.find(line => line.toLowerCase().includes(match.toLowerCase()))
          const hexInLine = matchingLine?.match(/#[A-Fa-f0-9]{6}|#[A-Fa-f0-9]{3}/)
          
          colors.push({
            pantone: pantoneValue,
            hex: hexInLine ? hexInLine[0].toUpperCase() : undefined,
            category: this.categorizeColor(match, text),
            usage: this.extractColorUsage(match, text)
          })
        }
      })
    }

    // Extract named colors
    const namedMatches = text.match(this.COLOR_PATTERNS.named)
    if (namedMatches) {
      namedMatches.forEach(match => {
        const [, category, colorName] = match.match(/(\w+)\s+colou?r\s*:\s*([^;\n]+)/i) || []
        if (category && colorName && !foundColors.has(colorName.toLowerCase())) {
          foundColors.add(colorName.toLowerCase())
          
          // Try to extract hex from the color name if it contains one
          const hexInName = colorName.match(/#[A-Fa-f0-9]{6}|#[A-Fa-f0-9]{3}/)
          
          colors.push({
            name: colorName.trim(),
            hex: hexInName ? hexInName[0].toUpperCase() : undefined,
            category: category.toLowerCase() as any || 'primary',
            usage: this.extractColorUsage(match, text)
          })
        }
      })
    }

    // Extract HSL colors
    let hslMatch
    const hslPattern = new RegExp(this.COLOR_PATTERNS.hsl.source, 'gi')
    while ((hslMatch = hslPattern.exec(text)) !== null) {
      // Handle both hsl(h, s%, l%) and HSL: h, s%, l% formats
      const [full, h1, s1, l1, h2, s2, l2] = hslMatch
      const h = h1 || h2
      const s = s1 || s2
      const l = l1 || l2
      
      if (h && s && l) {
        const hslString = `hsl(${h}, ${s}%, ${l}%)`
        if (!foundColors.has(hslString.toLowerCase())) {
          foundColors.add(hslString.toLowerCase())
          colors.push({
            hsl: hslString,
            hex: this.hslToHex(parseInt(h), parseInt(s), parseInt(l)),
            category: this.categorizeColor(full, text),
            usage: this.extractColorUsage(full, text)
          })
        }
      }
    }

    // Extract CMYK colors
    let cmykMatch
    const cmykPattern = new RegExp(this.COLOR_PATTERNS.cmyk.source, 'gi')
    while ((cmykMatch = cmykPattern.exec(text)) !== null) {
      // Handle both cmyk(c, m, y, k) and CMYK: c, m, y, k formats
      const [full, c1, m1, y1, k1, c2, m2, y2, k2] = cmykMatch
      const c = c1 || c2
      const m = m1 || m2
      const y = y1 || y2
      const k = k1 || k2
      
      if (c !== undefined && m !== undefined && y !== undefined && k !== undefined) {
        const cmykString = `cmyk(${c}, ${m}, ${y}, ${k})`
        if (!foundColors.has(cmykString.toLowerCase())) {
          foundColors.add(cmykString.toLowerCase())
          colors.push({
            cmyk: cmykString,
            hex: this.cmykToHex(parseInt(c), parseInt(m), parseInt(y), parseInt(k)),
            category: this.categorizeColor(full, text),
            usage: this.extractColorUsage(full, text)
          })
        }
      }
    }

    return colors
  }

  /**
   * Extract and categorize fonts from text
   */
  private static extractFonts(text: string): FontExtraction[] {
    const fonts: FontExtraction[] = []
    const foundFonts = new Set<string>()

    // Extract from font-family declarations
    const familyMatches = text.match(this.FONT_PATTERNS.family)
    if (familyMatches) {
      familyMatches.forEach(match => {
        const fontFamily = match.replace(/font-family\s*:\s*/gi, '').replace(/['"]/g, '').trim()
        this.processFontFamily(fontFamily, text, fonts, foundFonts)
      })
    }

    // Extract from typeface declarations
    const typefaceMatches = text.match(this.FONT_PATTERNS.typeface)
    if (typefaceMatches) {
      typefaceMatches.forEach(match => {
        const typeface = match.replace(/typeface\s*:\s*/gi, '').trim()
        this.processFontFamily(typeface, text, fonts, foundFonts)
      })
    }

    // Extract common fonts
    const commonMatches = text.match(this.FONT_PATTERNS.commonFonts)
    if (commonMatches) {
      commonMatches.forEach(match => {
        if (!foundFonts.has(match.toLowerCase())) {
          foundFonts.add(match.toLowerCase())
          fonts.push({
            family: this.cleanFontName(match),
            category: this.categorizeFontFamily(match),
            usage: this.extractFontUsage(match, text)
          })
        }
      })
    }

    return fonts
  }

  /**
   * Extract voice and tone information
   */
  private static extractVoice(text: string): VoiceExtraction {
    const voiceDescriptions: string[] = []
    const toneAttributes: Record<string, number> = {}
    const personality: string[] = []
    const messaging = { prohibited: [] as string[] }

    // Split text into sentences for analysis
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 10)

    sentences.forEach(sentence => {
      const lowerSentence = sentence.toLowerCase()

      // Analyze tone attributes
      Object.entries(this.VOICE_INDICATORS.toneKeywords).forEach(([tone, keywords]) => {
        keywords.forEach(keyword => {
          if (lowerSentence.includes(keyword)) {
            toneAttributes[tone] = (toneAttributes[tone] || 0) + 1
          }
        })
      })

      // Extract personality traits
      this.VOICE_INDICATORS.personalityTraits.forEach(trait => {
        if (lowerSentence.includes(trait) && !personality.includes(trait)) {
          personality.push(trait)
        }
      })

      // Extract voice descriptions
      if (lowerSentence.includes('voice') || lowerSentence.includes('tone')) {
        voiceDescriptions.push(sentence.trim())
      }

      // Extract prohibited terms
      if (lowerSentence.includes('do not') || lowerSentence.includes('avoid') || lowerSentence.includes('never')) {
        messaging.prohibited.push(sentence.trim())
      }
    })

    // Determine communication style with context priority
    let communicationStyle: string | null = null
    const textLower = text.toLowerCase()
    
    // Check for communication styles with context awareness
    // Prioritize styles that appear in specific voice/tone contexts
    for (const style of this.VOICE_INDICATORS.communicationStyles) {
      if (textLower.includes(style)) {
        // Check if this style appears in a voice/tone context
        const lines = text.split('\n')
        for (const line of lines) {
          const lineLower = line.toLowerCase()
          if (lineLower.includes(style) && 
              (lineLower.includes('tone') || lineLower.includes('voice') || 
               lineLower.includes('communicate') || lineLower.includes('writing'))) {
            communicationStyle = style
            break
          }
        }
        // If found in specific context, break out of outer loop too
        if (communicationStyle) {
          break
        }
        // If not found in specific context, still set it as fallback
        if (!communicationStyle) {
          communicationStyle = style
        }
      }
    }

    return {
      voiceDescription: voiceDescriptions.length > 0 ? voiceDescriptions.join(' | ') : null,
      toneAttributes,
      communicationStyle,
      personality,
      messaging
    }
  }

  /**
   * Extract structured guidelines
   */
  private static extractGuidelines(text: string): GuidelinesExtraction {
    const sections: GuidelinesExtraction['sections'] = []
    const keyPhrases: string[] = []
    const brandPillars: string[] = []

    // Split text into logical sections
    const rawSections = text.split(/\n\s*\n/).filter(section => section.trim().length > 20)

    rawSections.forEach(section => {
      const title = this.extractSectionTitle(section)
      const type = this.classifySection(title || section)
      
      sections.push({
        title: title || 'Untitled Section',
        content: section.trim(),
        type
      })
    })

    // Extract key phrases (sentences that likely contain important guidelines)
    const sentences = text.match(/[A-Z][^.!?]*[.!?]/g) || []
    
    // Also split by lines and process them as potential key phrases
    const lines = text.split('\n').filter(line => line.trim().length > 15)
    
    // Combine sentences and lines for key phrase extraction
    const allCandidates = [...sentences, ...lines]
    
    allCandidates.forEach(candidate => {
      if (this.isKeyPhrase(candidate)) {
        const cleanPhrase = candidate.trim().replace(/^[#\-\*\s]+/, '') // Remove markdown formatting
        if (cleanPhrase.length > 10 && !keyPhrases.includes(cleanPhrase)) {
          keyPhrases.push(cleanPhrase)
        }
      }
    })

    // Extract brand pillars
    const pillarMatches = text.match(/(?:brand\s+pillars?|core\s+values?|principles?)\s*:?\s*([^.\n]+)/gi)
    if (pillarMatches) {
      pillarMatches.forEach(match => {
        const pillars = match.split(/[,;]/).map(p => p.trim()).filter(p => p.length > 2)
        brandPillars.push(...pillars)
      })
    }

    return { sections, keyPhrases, brandPillars }
  }

  /**
   * Extract compliance and usage rules
   */
  private static extractCompliance(text: string): ComplianceExtraction {
    const usageRules = { do: [] as string[], dont: [] as string[] }
    const restrictedTerms: string[] = []
    const legalRequirements: string[] = []

    // First, look for structured DO/DON'T sections
    const doSectionMatch = text.match(/DO:\s*([\s\S]*?)(?=DON'T:|$)/i)
    if (doSectionMatch) {
      const doSection = doSectionMatch[1]
      const doItems = doSection.split(/\n\s*-\s*/).filter(item => item.trim().length > 5)
      doItems.forEach(item => {
        const cleanItem = item.trim().replace(/^-\s*/, '')
        if (cleanItem.length > 10) {
          usageRules.do.push(cleanItem)
        }
      })
    }

    const dontSectionMatch = text.match(/DON'T:\s*([\s\S]*?)(?=\n\n|\n###|\n##|$)/i)
    if (dontSectionMatch) {
      const dontSection = dontSectionMatch[1]
      const dontItems = dontSection.split(/\n\s*-\s*/).filter(item => item.trim().length > 5)
      dontItems.forEach(item => {
        const cleanItem = item.trim().replace(/^-\s*/, '')
        if (cleanItem.length > 10) {
          usageRules.dont.push(cleanItem)
        }
      })
    }

    // Then, also look for general sentences with compliance keywords
    const sentences = text.split(/[.!?\n]+/).filter(s => s.trim().length > 10)

    sentences.forEach(sentence => {
      const lowerSentence = sentence.toLowerCase()

      // Do rules (if not already captured from structured section)
      if ((lowerSentence.includes('must') || lowerSentence.includes('should') || lowerSentence.includes('always')) &&
          !usageRules.do.some(existing => existing.toLowerCase().includes(sentence.toLowerCase().slice(0, 20)))) {
        usageRules.do.push(sentence.trim())
      }

      // Don't rules (if not already captured from structured section)
      if ((lowerSentence.includes('do not') || lowerSentence.includes('never') || lowerSentence.includes('avoid')) &&
          !usageRules.dont.some(existing => existing.toLowerCase().includes(sentence.toLowerCase().slice(0, 20)))) {
        usageRules.dont.push(sentence.trim())
      }

      // Legal requirements - be more inclusive
      if (lowerSentence.includes('copyright') || lowerSentence.includes('trademark') || lowerSentence.includes('legal') ||
          lowerSentence.includes('privacy') || lowerSentence.includes('required') || lowerSentence.includes('policy') ||
          lowerSentence.includes('notice') || lowerSentence.includes('symbol') || lowerSentence.includes('disclaimer')) {
        const cleanSentence = sentence.trim().replace(/^[-•]\s*/, '')
        if (cleanSentence.length > 5) {
          legalRequirements.push(cleanSentence)
        }
      }
    })

    // Also look for structured "Legal Requirements" section
    const legalSectionMatch = text.match(/### Legal Requirements\s*([\s\S]*?)(?=\n\s*###|\n\s*##|$)/i)
    if (legalSectionMatch) {
      const legalSection = legalSectionMatch[1]
      // Split by lines first, then look for items that start with - or bullet points
      const lines = legalSection.split('\n').filter(line => line.trim().length > 5)
      lines.forEach(line => {
        const trimmedLine = line.trim()
        if (trimmedLine.startsWith('-') || trimmedLine.startsWith('•')) {
          const cleanItem = trimmedLine.replace(/^[-•]\s*/, '')
          if (cleanItem.length > 10 && !legalRequirements.some(existing => existing.includes(cleanItem.slice(0, 20)))) {
            legalRequirements.push(cleanItem)
          }
        }
      })
    }

    // Look for "Restricted Terms" section
    const restrictedSectionMatch = text.match(/### Restricted Terms\s*([\s\S]*?)(?=\n\s*###|\n\s*##|$)/i)
    if (restrictedSectionMatch) {
      const restrictedSection = restrictedSectionMatch[1]
      const lines = restrictedSection.split('\n').filter(line => line.trim().length > 5)
      lines.forEach(line => {
        const cleanLine = line.trim().replace(/^-\s*/, '').replace(/["""]/g, '"')
        if (cleanLine.length > 5 && !restrictedTerms.includes(cleanLine)) {
          restrictedTerms.push(cleanLine)
        }
      })
    }

    // Also look for restricted terms in sentences
    sentences.forEach(sentence => {
      const restrictedPattern = /(?:restricted|prohibited|banned)\s+(?:terms?|words?|language)\s*:?\s*([^.\n]+)/gi
      const restrictedMatch = sentence.match(restrictedPattern)
      if (restrictedMatch) {
        const terms = restrictedMatch[0].split(/[,;]/).map(t => t.trim())
        restrictedTerms.push(...terms)
      }
    })

    // Extract approval process
    let approvalProcess = ''
    const approvalSectionMatch = text.match(/### Approval Process\s*([\s\S]*?)(?=\n\s*###|\n\s*##|$)/i)
    if (approvalSectionMatch) {
      approvalProcess = approvalSectionMatch[1].trim()
    } else {
      // Look for general approval mentions
      const approvalSentences = sentences.filter(s => s.toLowerCase().includes('approval'))
      if (approvalSentences.length > 0) {
        approvalProcess = approvalSentences.join(' ')
      }
    }

    return { usageRules, restrictedTerms, legalRequirements, approvalProcess }
  }

  /**
   * Calculate confidence scores for extracted data
   */
  private static calculateConfidenceScores(
    colors: ColorExtraction[],
    fonts: FontExtraction[],
    voice: VoiceExtraction,
    guidelines: GuidelinesExtraction,
    compliance: ComplianceExtraction
  ) {
    const colorConfidence = Math.min(colors.length * 20, 100)
    const fontConfidence = Math.min(fonts.length * 25, 100)
    const voiceConfidence = Object.keys(voice.toneAttributes).length * 15 + (voice.voiceDescription ? 30 : 0)
    const guidelinesConfidence = Math.min(guidelines.sections.length * 10 + guidelines.keyPhrases.length * 2, 100)
    const complianceConfidence = compliance.usageRules.do.length * 10 + compliance.usageRules.dont.length * 10

    const overall = Math.round((colorConfidence + fontConfidence + voiceConfidence + guidelinesConfidence + complianceConfidence) / 5)

    return {
      overall: Math.min(overall, 100),
      colors: Math.min(colorConfidence, 100),
      fonts: Math.min(fontConfidence, 100),
      voice: Math.min(voiceConfidence, 100),
      guidelines: Math.min(guidelinesConfidence, 100),
      compliance: Math.min(complianceConfidence, 100)
    }
  }

  /**
   * Generate suggestions for improving brand guidelines
   */
  private static generateSuggestions(processedData: Partial<ProcessedBrandData>): string[] {
    const suggestions: string[] = []

    if (!processedData.colors || processedData.colors.length === 0) {
      suggestions.push("Consider adding specific color codes (hex, RGB, or Pantone) to ensure consistent brand colors")
    }

    if (!processedData.fonts || processedData.fonts.length === 0) {
      suggestions.push("Include specific typography guidelines with font families and usage instructions")
    }

    if (!processedData.voice?.voiceDescription) {
      suggestions.push("Add a clear brand voice description to guide content creation")
    }

    if (!processedData.compliance?.usageRules.do.length && !processedData.compliance?.usageRules.dont.length) {
      suggestions.push("Include usage guidelines and compliance rules with do's and don'ts for brand consistency")
    }

    if (processedData.confidence && processedData.confidence.overall < 60) {
      suggestions.push("Consider expanding the brand guidelines with more detailed specifications")
    }

    return suggestions
  }

  /**
   * Main processing method
   */
  static async processBrandGuidelines(
    text: string,
    assetId: string,
    brandId: string,
    settings: BrandGuidelinesProcessingSettings = {}
  ): Promise<ProcessedBrandData> {
    const extractedData: Partial<ProcessedBrandData> = {
      rawText: text,
      extractedAt: new Date().toISOString(),
      assetId,
      brandId,
    }

    // Extract each type of data based on settings
    if (settings.extractColors !== false) {
      extractedData.colors = this.extractColors(text)
    }

    if (settings.extractFonts !== false) {
      extractedData.fonts = this.extractFonts(text)
    }

    if (settings.extractVoice !== false) {
      extractedData.voice = this.extractVoice(text)
    }

    if (settings.extractGuidelines !== false) {
      extractedData.guidelines = this.extractGuidelines(text)
    }

    if (settings.extractCompliance !== false) {
      extractedData.compliance = this.extractCompliance(text)
    }

    // Calculate confidence scores
    const confidence = this.calculateConfidenceScores(
      extractedData.colors || [],
      extractedData.fonts || [],
      extractedData.voice || { voiceDescription: null, toneAttributes: {}, communicationStyle: null, personality: [], messaging: { prohibited: [] } },
      extractedData.guidelines || { sections: [], keyPhrases: [], brandPillars: [] },
      extractedData.compliance || { usageRules: { do: [], dont: [] }, restrictedTerms: [], legalRequirements: [] }
    )

    // Generate suggestions
    const suggestions = this.generateSuggestions(extractedData)

    return {
      ...extractedData,
      confidence,
      suggestions
    } as ProcessedBrandData
  }

  // Helper methods
  private static categorizeColor(colorMatch: string, context: string): ColorExtraction['category'] {
    // Find the line containing the color match for better context
    const lines = context.split('\n')
    const matchingLine = lines.find(line => line.includes(colorMatch))
    const localContext = (matchingLine || '').toLowerCase()
    
    // Also check a broader context but with less priority
    const contextLower = context.toLowerCase()

    // Check local context first (more specific)
    if (localContext.includes('success') || localContext.includes('green')) return 'success'
    if (localContext.includes('warning') || localContext.includes('orange') || localContext.includes('yellow')) return 'warning'
    if (localContext.includes('error') || localContext.includes('danger') || localContext.includes('red')) return 'error'
    if (localContext.includes('neutral') || localContext.includes('gray') || localContext.includes('grey')) return 'neutral'
    if (localContext.includes('secondary')) return 'secondary'
    if (localContext.includes('accent')) return 'accent'
    if (localContext.includes('primary') || localContext.includes('brand')) return 'primary'

    // Fallback to broader context if local context doesn't match
    if (contextLower.includes('success') || contextLower.includes('green')) return 'success'
    if (contextLower.includes('warning') || contextLower.includes('yellow')) return 'warning'
    if (contextLower.includes('error') || contextLower.includes('danger') || contextLower.includes('red')) return 'error'
    if (contextLower.includes('neutral') || contextLower.includes('gray') || contextLower.includes('grey')) return 'neutral'
    if (contextLower.includes('secondary')) return 'secondary'
    if (contextLower.includes('accent')) return 'accent'

    return 'primary'
  }

  private static extractColorUsage(colorMatch: string, context: string): string {
    const lines = context.split('\n')
    const matchingLine = lines.find(line => line.includes(colorMatch))
    if (matchingLine) {
      const usagePattern = /(?:for|used|usage|use)\s+([^.\n]+)/i
      const match = matchingLine.match(usagePattern)
      if (match) return match[1].trim()
    }
    return ''
  }

  private static rgbToHex(r: number, g: number, b: number): string {
    return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1).toUpperCase()
  }

  private static hslToHex(h: number, s: number, l: number): string {
    h = h % 360
    s = s / 100
    l = l / 100

    const c = (1 - Math.abs(2 * l - 1)) * s
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1))
    const m = l - c / 2

    let r, g, b

    if (h >= 0 && h < 60) {
      r = c; g = x; b = 0
    } else if (h >= 60 && h < 120) {
      r = x; g = c; b = 0
    } else if (h >= 120 && h < 180) {
      r = 0; g = c; b = x
    } else if (h >= 180 && h < 240) {
      r = 0; g = x; b = c
    } else if (h >= 240 && h < 300) {
      r = x; g = 0; b = c
    } else {
      r = c; g = 0; b = x
    }

    r = Math.round((r + m) * 255)
    g = Math.round((g + m) * 255)
    b = Math.round((b + m) * 255)

    return this.rgbToHex(r, g, b)
  }

  private static cmykToHex(c: number, m: number, y: number, k: number): string {
    // Convert CMYK to RGB
    c = c / 100
    m = m / 100
    y = y / 100
    k = k / 100

    const r = Math.round(255 * (1 - c) * (1 - k))
    const g = Math.round(255 * (1 - m) * (1 - k))
    const b = Math.round(255 * (1 - y) * (1 - k))

    return this.rgbToHex(r, g, b)
  }

  private static processFontFamily(fontFamily: string, context: string, fonts: FontExtraction[], foundFonts: Set<string>) {
    const families = fontFamily.split(',').map(f => f.trim().replace(/['"]/g, ''))
    families.forEach(family => {
      if (family && !foundFonts.has(family.toLowerCase()) && family.length > 2) {
        foundFonts.add(family.toLowerCase())
        fonts.push({
          family: this.cleanFontName(family),
          category: this.categorizeFontFamily(family),
          usage: this.extractFontUsage(family, context),
          fallbacks: families.slice(1)
        })
      }
    })
  }

  private static cleanFontName(fontName: string): string {
    return fontName.replace(/['"]/g, '').trim()
  }

  private static categorizeFontFamily(fontName: string): FontExtraction['category'] {
    const lowerName = fontName.toLowerCase()
    
    // Check for explicit serif fonts first
    if (lowerName.includes('georgia') || lowerName.includes('times') || lowerName.includes('garamond') || 
        lowerName.includes('baskerville') || lowerName.includes('caslon') || lowerName.includes('minion') ||
        (lowerName.includes('serif') && !lowerName.includes('sans'))) {
      return 'serif'
    }
    
    if (lowerName.includes('sans') || lowerName.includes('arial') || lowerName.includes('helvetica')) return 'sans-serif'
    if (lowerName.includes('mono') || lowerName.includes('courier') || lowerName.includes('code')) return 'monospace'
    if (lowerName.includes('script') || lowerName.includes('cursive')) return 'script'
    if (lowerName.includes('display') || lowerName.includes('decorative')) return 'decorative'
    
    return 'sans-serif'
  }

  private static extractFontUsage(fontName: string, context: string): FontExtraction['usage'] {
    const lines = context.split('\n')
    const matchingLineIndex = lines.findIndex(line => line.toLowerCase().includes(fontName.toLowerCase()))
    
    if (matchingLineIndex !== -1) {
      // Check the current line and the next few lines for usage context
      const currentLine = lines[matchingLineIndex]?.toLowerCase() || ''
      const nextLine = lines[matchingLineIndex + 1]?.toLowerCase() || ''
      const combinedContext = `${currentLine} ${nextLine}`.toLowerCase()
      
      // Also check if the line starts with common section headers
      if (currentLine.includes('primary typeface') || currentLine.includes('heading') || 
          combinedContext.includes('headlines') || combinedContext.includes('titles') ||
          combinedContext.includes('navigation')) return 'heading'
      
      if (currentLine.includes('body text') || currentLine.includes('body') || 
          combinedContext.includes('body copy') || combinedContext.includes('descriptions') ||
          combinedContext.includes('paragraph')) return 'body'
          
      if (currentLine.includes('monospace') || combinedContext.includes('code')) return 'accent'
      if (combinedContext.includes('caption') || combinedContext.includes('small')) return 'caption'
      if (combinedContext.includes('button') || combinedContext.includes('cta')) return 'button'
    }
    
    // Fallback to broader context analysis
    const contextLower = context.toLowerCase()
    if (contextLower.includes('heading') || contextLower.includes('title') || contextLower.includes('h1') || contextLower.includes('h2')) return 'heading'
    if (contextLower.includes('body') || contextLower.includes('paragraph') || contextLower.includes('text')) return 'body'
    if (contextLower.includes('caption') || contextLower.includes('small')) return 'caption'
    if (contextLower.includes('button') || contextLower.includes('cta')) return 'button'
    if (contextLower.includes('navigation') || contextLower.includes('menu')) return 'navigation'
    if (contextLower.includes('accent') || contextLower.includes('highlight')) return 'accent'
    
    return 'body'
  }

  private static extractSectionTitle(section: string): string | null {
    const lines = section.split('\n').filter(line => line.trim().length > 0)
    if (lines.length === 0) return null
    
    const firstLine = lines[0].trim()
    // Check if first line looks like a title (short, often capitalized)
    if (firstLine.length < 100 && firstLine.match(/^[A-Z][^.]*$/)) {
      return firstLine
    }
    
    return null
  }

  private static classifySection(title: string): GuidelinesExtraction['sections'][0]['type'] {
    const lowerTitle = title.toLowerCase()
    
    for (const [type, keywords] of Object.entries(this.SECTION_CLASSIFIERS)) {
      if (keywords.some(keyword => lowerTitle.includes(keyword))) {
        return type as GuidelinesExtraction['sections'][0]['type']
      }
    }
    
    return 'other'
  }

  private static isKeyPhrase(sentence: string): boolean {
    const lowerSentence = sentence.toLowerCase()
    const keywordIndicators = [
      'must', 'should', 'always', 'never', 'avoid', 'ensure', 'maintain',
      'brand', 'guideline', 'rule', 'requirement', 'standard', 'use', 'include',
      'required', 'recommended', 'primary', 'secondary', 'important', 'essential',
      'corporate', 'company', 'organization', 'style', 'design', 'consistent',
      'compliance', 'legal', 'approved', 'authorized', 'professional', 'techcorp',
      'color', 'font', 'typeface', 'logo', 'voice', 'tone', 'messaging', 'do:',
      'don\'t:', 'copyright', 'trademark', 'approval', 'review', 'accessible'
    ]
    
    return keywordIndicators.some(keyword => lowerSentence.includes(keyword)) &&
           sentence.length > 10 && sentence.length < 400
  }
}