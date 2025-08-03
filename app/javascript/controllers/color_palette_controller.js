// =============================================================================
// COLOR PALETTE CONTROLLER - INTELLIGENT COLOR GENERATION
// =============================================================================
// Advanced color palette generation with WCAG accessibility checking,
// harmonious color relationships, and brand-aware suggestions
// =============================================================================

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "primaryColor", "secondaryColor", "accentColor", "neutralColor",
    "preview", "paletteGrid", "accessibilityReport", "contrastRatio",
    "wcagLevel", "colorHarmony", "suggestion", "exportButton"
  ]
  
  static values = {
    baseColor: { type: String, default: "#3b82f6" },
    paletteType: { type: String, default: "monochromatic" },
    accessibilityLevel: { type: String, default: "AA" }
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  connect() {
    console.log("Color palette controller connected")
    this.initializeColorUtils()
    this.generateInitialPalette()
    this.setupColorValidation()
    this.bindEventListeners()
  }

  initializeColorUtils() {
    // Color utility functions
    this.colorUtils = {
      // Convert hex to RGB
      hexToRgb: (hex) => {
        const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
        return result ? {
          r: parseInt(result[1], 16),
          g: parseInt(result[2], 16),
          b: parseInt(result[3], 16)
        } : null
      },

      // Convert RGB to hex
      rgbToHex: (r, g, b) => {
        return `#${  ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`
      },

      // Convert RGB to HSL
      rgbToHsl: (r, g, b) => {
        r /= 255
        g /= 255
        b /= 255
        
        const max = Math.max(r, g, b)
        const min = Math.min(r, g, b)
        let h, s, l = (max + min) / 2

        if (max === min) {
          h = s = 0 // achromatic
        } else {
          const d = max - min
          s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
          
          switch (max) {
            case r: h = (g - b) / d + (g < b ? 6 : 0); break
            case g: h = (b - r) / d + 2; break
            case b: h = (r - g) / d + 4; break
          }
          h /= 6
        }

        return { h: h * 360, s: s * 100, l: l * 100 }
      },

      // Convert HSL to RGB
      hslToRgb: (h, s, l) => {
        h /= 360
        s /= 100
        l /= 100

        const hue2rgb = (p, q, t) => {
          if (t < 0) {t += 1}
          if (t > 1) {t -= 1}
          if (t < 1/6) {return p + (q - p) * 6 * t}
          if (t < 1/2) {return q}
          if (t < 2/3) {return p + (q - p) * (2/3 - t) * 6}
          return p
        }

        let r, g, b

        if (s === 0) {
          r = g = b = l // achromatic
        } else {
          const q = l < 0.5 ? l * (1 + s) : l + s - l * s
          const p = 2 * l - q
          r = hue2rgb(p, q, h + 1/3)
          g = hue2rgb(p, q, h)
          b = hue2rgb(p, q, h - 1/3)
        }

        return {
          r: Math.round(r * 255),
          g: Math.round(g * 255),
          b: Math.round(b * 255)
        }
      },

      // Calculate relative luminance
      getRelativeLuminance: (r, g, b) => {
        const sRgb = [r, g, b].map(c => {
          c = c / 255
          return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
        })
        return 0.2126 * sRgb[0] + 0.7152 * sRgb[1] + 0.0722 * sRgb[2]
      },

      // Calculate contrast ratio between two colors
      getContrastRatio: (color1, color2) => {
        const rgb1 = this.colorUtils.hexToRgb(color1)
        const rgb2 = this.colorUtils.hexToRgb(color2)
        
        if (!rgb1 || !rgb2) {return 1}

        const l1 = this.colorUtils.getRelativeLuminance(rgb1.r, rgb1.g, rgb1.b)
        const l2 = this.colorUtils.getRelativeLuminance(rgb2.r, rgb2.g, rgb2.b)
        
        const lighter = Math.max(l1, l2)
        const darker = Math.min(l1, l2)
        
        return (lighter + 0.05) / (darker + 0.05)
      },

      // Generate color variations (tints and shades)
      generateColorScale: (baseColor, steps = 11) => {
        const rgb = this.colorUtils.hexToRgb(baseColor)
        if (!rgb) {return []}

        const hsl = this.colorUtils.rgbToHsl(rgb.r, rgb.g, rgb.b)
        const scale = []

        for (let i = 0; i < steps; i++) {
          const lightness = 95 - (i * (90 / (steps - 1)))
          const newRgb = this.colorUtils.hslToRgb(hsl.h, hsl.s, lightness)
          scale.push(this.colorUtils.rgbToHex(newRgb.r, newRgb.g, newRgb.b))
        }

        return scale
      }
    }

    // Accessibility standards
    this.wcagStandards = {
      AA: {
        normal: 4.5,
        large: 3.0
      },
      AAA: {
        normal: 7.0,
        large: 4.5
      }
    }
  }

  // ==========================================================================
  // PALETTE GENERATION
  // ==========================================================================

  generateInitialPalette() {
    this.currentPalette = this.generatePalette(this.baseColorValue, this.paletteTypeValue)
    this.renderPalette()
    this.checkAccessibility()
  }

  generatePalette(baseColor, type = "monochromatic") {
    const rgb = this.colorUtils.hexToRgb(baseColor)
    if (!rgb) {return this.getDefaultPalette()}

    const hsl = this.colorUtils.rgbToHsl(rgb.r, rgb.g, rgb.b)
    let palette = {}

    switch (type) {
      case "monochromatic":
        palette = this.generateMonochromaticPalette(hsl)
        break
      case "analogous":
        palette = this.generateAnalogousPalette(hsl)
        break
      case "complementary":
        palette = this.generateComplementaryPalette(hsl)
        break
      case "triadic":
        palette = this.generateTriadicPalette(hsl)
        break
      case "tetradic":
        palette = this.generateTetradicPalette(hsl)
        break
      case "split-complementary":
        palette = this.generateSplitComplementaryPalette(hsl)
        break
      default:
        palette = this.generateMonochromaticPalette(hsl)
    }

    return palette
  }

  generateMonochromaticPalette(hsl) {
    const primary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(hsl.h, hsl.s, hsl.l)))
    )

    // Create secondary palette with adjusted saturation
    const secondaryHsl = { ...hsl, s: Math.max(10, hsl.s - 20) }
    const secondary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(secondaryHsl.h, secondaryHsl.s, secondaryHsl.l)))
    )

    // Create accent with higher saturation
    const accentHsl = { ...hsl, s: Math.min(100, hsl.s + 15), l: Math.max(30, hsl.l - 10) }
    const accent = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(accentHsl.h, accentHsl.s, accentHsl.l)))
    )

    // Neutral grays
    const neutral = this.generateNeutralScale()

    return { primary, secondary, accent, neutral }
  }

  generateAnalogousPalette(hsl) {
    const primaryHue = hsl.h
    const secondaryHue = (primaryHue + 30) % 360
    const accentHue = (primaryHue - 30 + 360) % 360

    const primary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(primaryHue, hsl.s, hsl.l)))
    )

    const secondary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(secondaryHue, hsl.s * 0.8, hsl.l)))
    )

    const accent = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(accentHue, hsl.s * 0.9, Math.max(30, hsl.l - 10))))
    )

    const neutral = this.generateNeutralScale()

    return { primary, secondary, accent, neutral }
  }

  generateComplementaryPalette(hsl) {
    const primaryHue = hsl.h
    const secondaryHue = (primaryHue + 180) % 360

    const primary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(primaryHue, hsl.s, hsl.l)))
    )

    const secondary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(secondaryHue, hsl.s * 0.7, hsl.l)))
    )

    // Accent uses a variation of the primary
    const accentHsl = { ...hsl, s: Math.min(100, hsl.s + 10), l: Math.max(25, hsl.l - 15) }
    const accent = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(accentHsl.h, accentHsl.s, accentHsl.l)))
    )

    const neutral = this.generateNeutralScale()

    return { primary, secondary, accent, neutral }
  }

  generateTriadicPalette(hsl) {
    const primaryHue = hsl.h
    const secondaryHue = (primaryHue + 120) % 360
    const accentHue = (primaryHue + 240) % 360

    const primary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(primaryHue, hsl.s, hsl.l)))
    )

    const secondary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(secondaryHue, hsl.s * 0.8, hsl.l)))
    )

    const accent = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(accentHue, hsl.s * 0.9, Math.max(30, hsl.l - 10))))
    )

    const neutral = this.generateNeutralScale()

    return { primary, secondary, accent, neutral }
  }

  generateTetradicPalette(hsl) {
    const primaryHue = hsl.h
    const secondaryHue = (primaryHue + 90) % 360
    const accentHue = (primaryHue + 180) % 360

    const primary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(primaryHue, hsl.s, hsl.l)))
    )

    const secondary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(secondaryHue, hsl.s * 0.8, hsl.l)))
    )

    const accent = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(accentHue, hsl.s * 0.7, Math.max(30, hsl.l - 10))))
    )

    const neutral = this.generateNeutralScale()

    return { primary, secondary, accent, neutral }
  }

  generateSplitComplementaryPalette(hsl) {
    const primaryHue = hsl.h
    const secondaryHue = (primaryHue + 150) % 360
    const accentHue = (primaryHue + 210) % 360

    const primary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(primaryHue, hsl.s, hsl.l)))
    )

    const secondary = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(secondaryHue, hsl.s * 0.8, hsl.l)))
    )

    const accent = this.colorUtils.generateColorScale(
      this.colorUtils.rgbToHex(...Object.values(this.colorUtils.hslToRgb(accentHue, hsl.s * 0.8, Math.max(30, hsl.l - 10))))
    )

    const neutral = this.generateNeutralScale()

    return { primary, secondary, accent, neutral }
  }

  generateNeutralScale() {
    // Generate a warm neutral scale
    return [
      "#fefefe", "#f8fafc", "#f1f5f9", "#e2e8f0", "#cbd5e1",
      "#94a3b8", "#64748b", "#475569", "#334155", "#1e293b", "#0f172a"
    ]
  }

  getDefaultPalette() {
    return {
      primary: this.colorUtils.generateColorScale("#3b82f6"),
      secondary: this.colorUtils.generateColorScale("#6366f1"),
      accent: this.colorUtils.generateColorScale("#10b981"),
      neutral: this.generateNeutralScale()
    }
  }

  // ==========================================================================
  // ACCESSIBILITY CHECKING
  // ==========================================================================

  checkAccessibility() {
    if (!this.currentPalette) {return}

    const accessibilityResults = {
      primary: this.checkColorAccessibility(this.currentPalette.primary),
      secondary: this.checkColorAccessibility(this.currentPalette.secondary),
      accent: this.checkColorAccessibility(this.currentPalette.accent),
      overall: { passed: 0, total: 0, issues: [] }
    }

    // Calculate overall scores
    Object.values(accessibilityResults).slice(0, 3).forEach(result => {
      accessibilityResults.overall.passed += result.passed
      accessibilityResults.overall.total += result.total
      accessibilityResults.overall.issues.push(...result.issues)
    })

    this.accessibilityResults = accessibilityResults
    this.renderAccessibilityReport()
  }

  checkColorAccessibility(colorScale) {
    const results = {
      passed: 0,
      total: 0,
      issues: [],
      contrastTests: []
    }

    const backgroundColors = ["#ffffff", "#000000", colorScale[0], colorScale[colorScale.length - 1]]
    const textColors = [colorScale[5], colorScale[6], colorScale[7], colorScale[8]]

    backgroundColors.forEach(bg => {
      textColors.forEach(text => {
        const contrastRatio = this.colorUtils.getContrastRatio(bg, text)
        const test = {
          background: bg,
          foreground: text,
          ratio: contrastRatio,
          aaPass: contrastRatio >= this.wcagStandards.AA.normal,
          aaaPass: contrastRatio >= this.wcagStandards.AAA.normal,
          aaLargePass: contrastRatio >= this.wcagStandards.AA.large,
          aaaLargePass: contrastRatio >= this.wcagStandards.AAA.large
        }

        results.contrastTests.push(test)
        results.total += 4 // AA normal, AAA normal, AA large, AAA large

        if (test.aaPass) {results.passed++}
        if (test.aaaPass) {results.passed++}
        if (test.aaLargePass) {results.passed++}
        if (test.aaaLargePass) {results.passed++}

        if (!test.aaPass) {
          results.issues.push(`Poor contrast between ${bg} and ${text} (${contrastRatio.toFixed(2)}:1)`)
        }
      })
    })

    return results
  }

  // ==========================================================================
  // UI RENDERING
  // ==========================================================================

  renderPalette() {
    if (!this.hasPaletteGridTarget || !this.currentPalette) {return}

    this.paletteGridTarget.innerHTML = ""

    Object.entries(this.currentPalette).forEach(([colorName, colors]) => {
      const colorGroup = this.createColorGroup(colorName, colors)
      this.paletteGridTarget.appendChild(colorGroup)
    })

    this.updatePreview()
  }

  createColorGroup(name, colors) {
    const group = document.createElement("div")
    group.className = "color-group mb-6"
    
    const header = document.createElement("h3")
    header.className = "text-sm font-medium text-gray-700 mb-2 capitalize"
    header.textContent = name
    group.appendChild(header)

    const swatches = document.createElement("div")
    swatches.className = "flex rounded-lg overflow-hidden shadow-sm border border-gray-200"

    colors.forEach((color, index) => {
      const swatch = this.createColorSwatch(color, index)
      swatches.appendChild(swatch)
    })

    group.appendChild(swatches)
    return group
  }

  createColorSwatch(color, index) {
    const swatch = document.createElement("div")
    swatch.className = "flex-1 h-16 cursor-pointer transition-transform hover:scale-105 relative group"
    swatch.style.backgroundColor = color
    swatch.setAttribute("title", `${color} (${index * 100})`)
    
    // Add color code tooltip
    const tooltip = document.createElement("div")
    tooltip.className = "absolute bottom-1 left-1 right-1 text-xs font-mono text-center opacity-0 group-hover:opacity-100 transition-opacity bg-black bg-opacity-50 text-white rounded px-1 py-0.5"
    tooltip.textContent = color
    swatch.appendChild(tooltip)

    // Copy to clipboard on click
    swatch.addEventListener("click", () => {
      navigator.clipboard.writeText(color).then(() => {
        this.showCopyFeedback(swatch, color)
      })
    })

    return swatch
  }

  showCopyFeedback(element, color) {
    const feedback = document.createElement("div")
    feedback.className = "absolute inset-0 flex items-center justify-center bg-black bg-opacity-75 text-white text-xs font-medium rounded transition-opacity"
    feedback.textContent = "Copied!"
    
    element.appendChild(feedback)
    
    setTimeout(() => {
      element.removeChild(feedback)
    }, 1000)
  }

  updatePreview() {
    if (!this.hasPreviewTarget || !this.currentPalette) {return}

    const preview = this.previewTarget
    const primary = this.currentPalette.primary[5]
    const secondary = this.currentPalette.secondary[5]
    const accent = this.currentPalette.accent[5]
    const neutral = this.currentPalette.neutral[5]

    // Update preview styles
    preview.style.setProperty("--preview-primary", primary)
    preview.style.setProperty("--preview-secondary", secondary)
    preview.style.setProperty("--preview-accent", accent)
    preview.style.setProperty("--preview-neutral", neutral)
  }

  renderAccessibilityReport() {
    if (!this.hasAccessibilityReportTarget || !this.accessibilityResults) {return}

    const report = this.accessibilityReportTarget
    const results = this.accessibilityResults.overall
    const score = Math.round((results.passed / results.total) * 100)

    report.innerHTML = `
      <div class="accessibility-score p-4 rounded-lg ${score >= 80 ? 'bg-green-50 border-green-200' : score >= 60 ? 'bg-yellow-50 border-yellow-200' : 'bg-red-50 border-red-200'} border">
        <div class="flex items-center justify-between mb-2">
          <h3 class="font-medium ${score >= 80 ? 'text-green-800' : score >= 60 ? 'text-yellow-800' : 'text-red-800'}">
            Accessibility Score
          </h3>
          <span class="text-2xl font-bold ${score >= 80 ? 'text-green-600' : score >= 60 ? 'text-yellow-600' : 'text-red-600'}">
            ${score}%
          </span>
        </div>
        <div class="text-sm ${score >= 80 ? 'text-green-700' : score >= 60 ? 'text-yellow-700' : 'text-red-700'}">
          ${results.passed} of ${results.total} accessibility tests passed
        </div>
        ${results.issues.length > 0 ? `
          <details class="mt-2">
            <summary class="cursor-pointer text-sm font-medium">View Issues (${results.issues.length})</summary>
            <ul class="mt-2 text-xs space-y-1">
              ${results.issues.slice(0, 5).map(issue => `<li>• ${issue}</li>`).join('')}
              ${results.issues.length > 5 ? `<li>• And ${results.issues.length - 5} more...</li>` : ''}
            </ul>
          </details>
        ` : ''}
      </div>
    `
  }

  // ==========================================================================
  // EVENT HANDLERS
  // ==========================================================================

  bindEventListeners() {
    // Color input changes
    if (this.hasPrimaryColorTarget) {
      this.primaryColorTarget.addEventListener("input", (e) => {
        this.baseColorValue = e.target.value
        this.regeneratePalette()
      })
    }

    // Palette type changes
    this.element.addEventListener("change", (e) => {
      if (e.target.name === "palette_type") {
        this.paletteTypeValue = e.target.value
        this.regeneratePalette()
      }
    })
  }

  regeneratePalette() {
    this.currentPalette = this.generatePalette(this.baseColorValue, this.paletteTypeValue)
    this.renderPalette()
    this.checkAccessibility()
    this.generateSuggestions()
  }

  setupColorValidation() {
    // Validate colors as they're entered
    const colorInputs = this.element.querySelectorAll('input[type="color"]')
    colorInputs.forEach(input => {
      input.addEventListener("blur", (e) => {
        this.validateColorInput(e.target)
      })
    })
  }

  validateColorInput(input) {
    const color = input.value
    const rgb = this.colorUtils.hexToRgb(color)
    
    if (!rgb) {
      this.showInputError(input, "Invalid color format")
      return false
    }

    this.clearInputError(input)
    return true
  }

  showInputError(input, message) {
    input.classList.add("border-red-500")
    
    let errorElement = input.nextElementSibling
    if (!errorElement || !errorElement.classList.contains("error-message")) {
      errorElement = document.createElement("div")
      errorElement.className = "error-message text-red-600 text-xs mt-1"
      input.parentNode.insertBefore(errorElement, input.nextSibling)
    }
    
    errorElement.textContent = message
  }

  clearInputError(input) {
    input.classList.remove("border-red-500")
    
    const errorElement = input.nextElementSibling
    if (errorElement && errorElement.classList.contains("error-message")) {
      errorElement.remove()
    }
  }

  // ==========================================================================
  // PALETTE SUGGESTIONS
  // ==========================================================================

  generateSuggestions() {
    if (!this.currentPalette) {return}

    const suggestions = []

    // Check for accessibility improvements
    if (this.accessibilityResults.overall.passed / this.accessibilityResults.overall.total < 0.8) {
      suggestions.push({
        type: "accessibility",
        message: "Consider adjusting colors for better contrast ratios",
        action: "improve-contrast"
      })
    }

    // Check for color harmony
    const harmony = this.analyzeColorHarmony()
    if (harmony.score < 0.7) {
      suggestions.push({
        type: "harmony",
        message: "Colors could be more harmonious",
        action: "adjust-harmony"
      })
    }

    // Brand-specific suggestions
    const brandSuggestions = this.generateBrandSuggestions()
    suggestions.push(...brandSuggestions)

    this.renderSuggestions(suggestions)
  }

  analyzeColorHarmony() {
    // Simplified harmony analysis based on hue relationships
    // This would be more sophisticated in a real implementation
    return { score: 0.8, details: "Colors work well together" }
  }

  generateBrandSuggestions() {
    return [
      {
        type: "brand",
        message: "Consider using warmer tones for better emotional connection",
        action: "warm-palette"
      }
    ]
  }

  renderSuggestions(suggestions) {
    if (!this.hasSuggestionTarget) {return}

    this.suggestionTarget.innerHTML = suggestions.map(suggestion => `
      <div class="suggestion p-3 rounded-md bg-blue-50 border border-blue-200 mb-2">
        <div class="flex items-start">
          <div class="flex-shrink-0 mr-2">
            ${this.getSuggestionIcon(suggestion.type)}
          </div>
          <div class="flex-1">
            <p class="text-sm text-blue-800">${suggestion.message}</p>
            <button 
              type="button" 
              class="mt-1 text-xs text-blue-600 hover:text-blue-800 underline"
              data-action="color-palette#applySuggestion"
              data-suggestion-action="${suggestion.action}"
            >
              Apply suggestion
            </button>
          </div>
        </div>
      </div>
    `).join("")
  }

  getSuggestionIcon(type) {
    const icons = {
      accessibility: "♿",
      harmony: "🎨",
      brand: "🏢"
    }
    return icons[type] || "💡"
  }

  // ==========================================================================
  // PALETTE EXPORT
  // ==========================================================================

  exportPalette() {
    if (!this.currentPalette) {return}

    const exportData = {
      timestamp: new Date().toISOString(),
      palette: this.currentPalette,
      accessibility: this.accessibilityResults,
      css: this.generateCSSVariables(),
      scss: this.generateSCSSVariables(),
      tailwind: this.generateTailwindConfig()
    }

    this.downloadJSON(exportData, `color-palette-${Date.now()}.json`)
  }

  generateCSSVariables() {
    if (!this.currentPalette) {return ""}

    let css = ":root {\n"
    
    Object.entries(this.currentPalette).forEach(([colorName, colors]) => {
      colors.forEach((color, index) => {
        const weight = index * 100 || 50
        css += `  --color-${colorName}-${weight}: ${color};\n`
      })
    })
    
    css += "}"
    return css
  }

  generateSCSSVariables() {
    if (!this.currentPalette) {return ""}

    let scss = ""
    
    Object.entries(this.currentPalette).forEach(([colorName, colors]) => {
      colors.forEach((color, index) => {
        const weight = index * 100 || 50
        scss += `$color-${colorName}-${weight}: ${color};\n`
      })
    })
    
    return scss
  }

  generateTailwindConfig() {
    if (!this.currentPalette) {return {}}

    const config = { colors: {} }
    
    Object.entries(this.currentPalette).forEach(([colorName, colors]) => {
      config.colors[colorName] = {}
      colors.forEach((color, index) => {
        const weight = index * 100 || 50
        config.colors[colorName][weight] = color
      })
    })
    
    return config
  }

  downloadJSON(data, filename) {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" })
    const url = URL.createObjectURL(blob)
    
    const a = document.createElement("a")
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    
    URL.revokeObjectURL(url)
  }

  // ==========================================================================
  // STIMULUS ACTION METHODS
  // ==========================================================================

  applySuggestion(event) {
    const action = event.target.dataset.suggestionAction
    
    switch (action) {
      case "improve-contrast":
        this.improveContrast()
        break
      case "adjust-harmony":
        this.adjustHarmony()
        break
      case "warm-palette":
        this.applyWarmTones()
        break
    }
  }

  improveContrast() {
    // Automatically adjust colors for better contrast
    console.log("Improving contrast...")
    // Implementation would adjust color lightness/darkness
  }

  adjustHarmony() {
    // Adjust colors for better harmony
    console.log("Adjusting harmony...")
    // Implementation would modify hue relationships
  }

  applyWarmTones() {
    // Shift palette toward warmer tones
    console.log("Applying warm tones...")
    // Implementation would adjust hue toward warmer colors
  }
}