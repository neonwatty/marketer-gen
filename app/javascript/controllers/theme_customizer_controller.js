// =============================================================================
// THEME CUSTOMIZER CONTROLLER - COMPREHENSIVE CUSTOMIZATION INTERFACE
// =============================================================================
// Advanced theme customization with brand color picker, font selection,
// logo upload, layout preferences, and white-label customization
// =============================================================================

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "primaryColor", "secondaryColor", "accentColor", "neutralColor",
    "fontPrimary", "fontSecondary", "fontHeading", "fontDisplay",
    "logoUpload", "logoPreview", "companyName", "brandName",
    "layoutStyle", "sidebarStyle", "headerStyle", "navigationStyle",
    "customCSS", "preview", "exportButton", "resetButton",
    "colorSuggestions", "fontSuggestions", "presetThemes"
  ]
  
  static values = {
    theme: { type: Object, default: {} },
    presets: { type: Array, default: [] },
    googleFonts: { type: Array, default: [] },
    brandColors: { type: Object, default: {} }
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  connect() {
    console.log("Theme customizer controller connected")
    this.initializeCustomizer()
    this.loadGoogleFonts()
    this.loadPresetThemes()
    this.setupColorPicker()
    this.setupFontSelector()
    this.setupLogoUpload()
    this.bindEventListeners()
    this.updatePreview()
  }

  initializeCustomizer() {
    // Initialize default theme if none exists
    this.currentTheme = {
      colors: {
        primary: "#3b82f6",
        secondary: "#6366f1", 
        accent: "#10b981",
        neutral: "#6b7280"
      },
      fonts: {
        primary: "Inter",
        secondary: "Work Sans",
        heading: "Inter",
        display: "Playfair Display"
      },
      branding: {
        logo: null,
        companyName: "",
        brandName: "",
        favicon: null
      },
      layout: {
        style: "modern",
        sidebar: "expanded",
        header: "fixed",
        navigation: "horizontal"
      },
      customCSS: "",
      ...this.themeValue
    }

    // Load saved theme from localStorage
    const savedTheme = localStorage.getItem("theme-customizer-settings")
    if (savedTheme) {
      try {
        this.currentTheme = { ...this.currentTheme, ...JSON.parse(savedTheme) }
      } catch (error) {
        console.warn("Failed to load saved theme:", error)
      }
    }

    this.applyThemeToForm()
  }

  // ==========================================================================
  // GOOGLE FONTS INTEGRATION
  // ==========================================================================

  async loadGoogleFonts() {
    // Popular Google Fonts for UI design
    this.googleFontsValue = [
      // Sans-serif fonts
      { name: "Inter", category: "sans-serif", popularity: 100 },
      { name: "Roboto", category: "sans-serif", popularity: 95 },
      { name: "Open Sans", category: "sans-serif", popularity: 90 },
      { name: "Lato", category: "sans-serif", popularity: 85 },
      { name: "Source Sans Pro", category: "sans-serif", popularity: 80 },
      { name: "Nunito", category: "sans-serif", popularity: 75 },
      { name: "Poppins", category: "sans-serif", popularity: 70 },
      { name: "Montserrat", category: "sans-serif", popularity: 65 },
      { name: "Work Sans", category: "sans-serif", popularity: 60 },
      { name: "Fira Sans", category: "sans-serif", popularity: 55 },
      
      // Serif fonts
      { name: "Merriweather", category: "serif", popularity: 85 },
      { name: "Playfair Display", category: "serif", popularity: 80 },
      { name: "Source Serif Pro", category: "serif", popularity: 75 },
      { name: "Lora", category: "serif", popularity: 70 },
      { name: "Crimson Text", category: "serif", popularity: 65 },
      { name: "Libre Baskerville", category: "serif", popularity: 60 },
      
      // Display fonts
      { name: "Oswald", category: "display", popularity: 80 },
      { name: "Bebas Neue", category: "display", popularity: 75 },
      { name: "Raleway", category: "display", popularity: 70 },
      { name: "Dancing Script", category: "display", popularity: 65 },
      
      // Monospace fonts
      { name: "Fira Code", category: "monospace", popularity: 85 },
      { name: "Source Code Pro", category: "monospace", popularity: 80 },
      { name: "JetBrains Mono", category: "monospace", popularity: 75 },
      { name: "Inconsolata", category: "monospace", popularity: 70 }
    ]

    this.renderFontOptions()
    this.loadSelectedFonts()
  }

  renderFontOptions() {
    const fontSelectors = ["fontPrimary", "fontSecondary", "fontHeading", "fontDisplay"]
    
    fontSelectors.forEach(selectorName => {
      if (this.hasTarget(selectorName)) {
        const target = this.targets.find(selectorName)[0]
        if (target) {
          this.populateFontSelect(target)
        }
      }
    })
  }

  populateFontSelect(selectElement) {
    const categories = ["sans-serif", "serif", "display", "monospace"]
    
    // Clear existing options except the first one
    const placeholder = selectElement.querySelector("option[value='']")
    selectElement.innerHTML = ""
    if (placeholder) {
      selectElement.appendChild(placeholder)
    }

    categories.forEach(category => {
      const optgroup = document.createElement("optgroup")
      optgroup.label = this.formatCategoryName(category)
      
      const fontsInCategory = this.googleFontsValue
        .filter(font => font.category === category)
        .sort((a, b) => b.popularity - a.popularity)
      
      fontsInCategory.forEach(font => {
        const option = document.createElement("option")
        option.value = font.name
        option.textContent = font.name
        option.style.fontFamily = `'${font.name}', ${category}`
        optgroup.appendChild(option)
      })
      
      selectElement.appendChild(optgroup)
    })
  }

  formatCategoryName(category) {
    const names = {
      "sans-serif": "Sans Serif",
      "serif": "Serif", 
      "display": "Display",
      "monospace": "Monospace"
    }
    return names[category] || category
  }

  loadSelectedFonts() {
    const fontsToLoad = new Set()
    
    // Add current theme fonts
    Object.values(this.currentTheme.fonts).forEach(fontName => {
      if (fontName && fontName !== "system-ui") {
        fontsToLoad.add(fontName)
      }
    })

    // Load fonts via Google Fonts API
    if (fontsToLoad.size > 0) {
      this.loadGoogleFontsCSS(Array.from(fontsToLoad))
    }
  }

  loadGoogleFontsCSS(fontNames) {
    // Create font URL with multiple weights
    const weights = "300,400,500,600,700"
    const fontParams = fontNames
      .map(name => `${name.replace(/\s+/g, "+")}:wght@${weights}`)
      .join("&family=")
    
    const fontURL = `https://fonts.googleapis.com/css2?family=${fontParams}&display=swap`
    
    // Check if already loaded
    const existingLink = document.querySelector(`link[href*="${fontNames[0]}"]`)
    if (existingLink) {return}

    // Load the fonts
    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = fontURL
    document.head.appendChild(link)
  }

  // ==========================================================================
  // COLOR CUSTOMIZATION
  // ==========================================================================

  setupColorPicker() {
    const colorInputs = ["primaryColor", "secondaryColor", "accentColor", "neutralColor"]
    
    colorInputs.forEach(inputName => {
      if (this.hasTarget(inputName)) {
        const input = this.targets.find(inputName)[0]
        if (input) {
          input.addEventListener("input", (e) => this.handleColorChange(e))
          input.addEventListener("change", (e) => this.handleColorChange(e))
        }
      }
    })

    this.generateColorSuggestions()
  }

  handleColorChange(event) {
    const colorType = event.target.dataset.colorType || 
                     event.target.id.replace("Color", "").toLowerCase()
    const color = event.target.value

    this.currentTheme.colors[colorType] = color
    this.updatePreview()
    this.generateHarmonySuggestions(color, colorType)
    this.checkColorAccessibility()
    this.saveTheme()
  }

  generateColorSuggestions() {
    if (!this.hasColorSuggestionsTarget) {return}

    const suggestions = [
      // Brand color palettes
      { name: "Professional Blue", colors: { primary: "#2563eb", secondary: "#3b82f6", accent: "#10b981" } },
      { name: "Modern Purple", colors: { primary: "#7c3aed", secondary: "#a855f7", accent: "#f59e0b" } },
      { name: "Creative Orange", colors: { primary: "#ea580c", secondary: "#f97316", accent: "#10b981" } },
      { name: "Tech Green", colors: { primary: "#059669", secondary: "#10b981", accent: "#3b82f6" } },
      { name: "Elegant Rose", colors: { primary: "#e11d48", secondary: "#f43f5e", accent: "#8b5cf6" } },
      { name: "Corporate Gray", colors: { primary: "#374151", secondary: "#6b7280", accent: "#3b82f6" } }
    ]

    this.renderColorSuggestions(suggestions)
  }

  renderColorSuggestions(suggestions) {
    const container = this.colorSuggestionsTarget
    container.innerHTML = ""

    suggestions.forEach((suggestion, _index) => {
      const item = document.createElement("div")
      item.className = "color-suggestion cursor-pointer p-3 rounded-lg border border-gray-200 hover:border-gray-300 transition-colors"
      item.innerHTML = `
        <div class="flex items-center space-x-2 mb-2">
          ${Object.values(suggestion.colors).map(color => `
            <div class="w-4 h-4 rounded-full border border-gray-200" style="background-color: ${color}"></div>
          `).join("")}
        </div>
        <p class="text-sm font-medium text-gray-700">${suggestion.name}</p>
      `
      
      item.addEventListener("click", () => this.applySuggestedColors(suggestion.colors))
      container.appendChild(item)
    })
  }

  applySuggestedColors(colors) {
    Object.entries(colors).forEach(([type, color]) => {
      this.currentTheme.colors[type] = color
      
      // Update form inputs
      const input = this.element.querySelector(`[data-color-type="${type}"]`)
      if (input) {
        input.value = color
      }
    })

    this.updatePreview()
    this.saveTheme()
    this.showNotification("Color palette applied successfully!")
  }

  generateHarmonySuggestions(baseColor, _colorType) {
    // Generate harmonious color suggestions based on color theory
    const harmony = this.calculateColorHarmony(baseColor)
    
    if (this.hasColorSuggestionsTarget) {
      const harmonyContainer = document.createElement("div")
      harmonyContainer.className = "mt-4 p-3 bg-blue-50 rounded-lg"
      harmonyContainer.innerHTML = `
        <h4 class="text-sm font-medium text-blue-900 mb-2">Suggested harmony colors:</h4>
        <div class="flex space-x-2">
          ${harmony.map(color => `
            <button 
              type="button"
              class="w-8 h-8 rounded-full border-2 border-white shadow-sm hover:scale-110 transition-transform"
              style="background-color: ${color}"
              data-action="click->theme-customizer#applyHarmonyColor"
              data-color="${color}"
              title="${color}"
            ></button>
          `).join("")}
        </div>
      `
      
      // Replace existing harmony suggestions
      const existingHarmony = this.colorSuggestionsTarget.querySelector(".harmony-suggestions")
      if (existingHarmony) {
        existingHarmony.remove()
      }
      
      harmonyContainer.classList.add("harmony-suggestions")
      this.colorSuggestionsTarget.appendChild(harmonyContainer)
    }
  }

  calculateColorHarmony(hexColor) {
    // Convert hex to HSL for color harmony calculations
    const hsl = this.hexToHsl(hexColor)
    if (!hsl) {return []}

    const harmonies = []
    const { h, s, l } = hsl

    // Complementary
    harmonies.push(this.hslToHex((h + 180) % 360, s, l))
    
    // Triadic
    harmonies.push(this.hslToHex((h + 120) % 360, s, l))
    harmonies.push(this.hslToHex((h + 240) % 360, s, l))
    
    // Analogous
    harmonies.push(this.hslToHex((h + 30) % 360, s, l))
    harmonies.push(this.hslToHex((h - 30 + 360) % 360, s, l))

    return harmonies.slice(0, 5) // Return top 5 suggestions
  }

  checkColorAccessibility() {
    const { primary, secondary, accent } = this.currentTheme.colors
    const backgroundColor = "#ffffff"
    
    const results = {
      primaryContrast: this.calculateContrastRatio(primary, backgroundColor),
      secondaryContrast: this.calculateContrastRatio(secondary, backgroundColor),
      accentContrast: this.calculateContrastRatio(accent, backgroundColor)
    }

    this.displayAccessibilityResults(results)
  }

  displayAccessibilityResults(results) {
    // Create or update accessibility indicator
    let indicator = this.element.querySelector(".accessibility-indicator")
    if (!indicator) {
      indicator = document.createElement("div")
      indicator.className = "accessibility-indicator mt-4 p-3 rounded-lg"
      this.colorSuggestionsTarget.appendChild(indicator)
    }

    const passCount = Object.values(results).filter(ratio => ratio >= 4.5).length
    const isAccessible = passCount >= 2

    indicator.className = `accessibility-indicator mt-4 p-3 rounded-lg ${
      isAccessible ? "bg-green-50 border border-green-200" : "bg-yellow-50 border border-yellow-200"
    }`
    
    indicator.innerHTML = `
      <div class="flex items-center">
        <div class="flex-shrink-0 mr-2">
          ${isAccessible ? "✓" : "⚠️"}
        </div>
        <div>
          <p class="text-sm font-medium ${isAccessible ? "text-green-800" : "text-yellow-800"}">
            ${isAccessible ? "Colors meet WCAG AA standards" : "Some colors may have contrast issues"}
          </p>
          <p class="text-xs ${isAccessible ? "text-green-600" : "text-yellow-600"} mt-1">
            ${Object.entries(results).map(([color, ratio]) => 
              `${color}: ${ratio.toFixed(1)}:1`
            ).join(" • ")}
          </p>
        </div>
      </div>
    `
  }

  // ==========================================================================
  // FONT CUSTOMIZATION
  // ==========================================================================

  setupFontSelector() {
    const fontSelectors = ["fontPrimary", "fontSecondary", "fontHeading", "fontDisplay"]
    
    fontSelectors.forEach(selectorName => {
      if (this.hasTarget(selectorName)) {
        const select = this.targets.find(selectorName)[0]
        if (select) {
          select.addEventListener("change", (e) => this.handleFontChange(e))
        }
      }
    })

    this.generateFontSuggestions()
  }

  handleFontChange(event) {
    const fontType = event.target.dataset.fontType || 
                    event.target.id.replace("font", "").toLowerCase()
    const fontName = event.target.value

    this.currentTheme.fonts[fontType] = fontName
    
    // Load the font if it's a Google Font
    if (fontName && fontName !== "system-ui") {
      this.loadGoogleFontsCSS([fontName])
    }

    this.updatePreview()
    this.saveTheme()
  }

  generateFontSuggestions() {
    if (!this.hasFontSuggestionsTarget) {return}

    const suggestions = [
      { name: "Modern Professional", fonts: { primary: "Inter", heading: "Inter", display: "Playfair Display" } },
      { name: "Clean & Minimal", fonts: { primary: "Roboto", heading: "Roboto", display: "Oswald" } },
      { name: "Elegant Editorial", fonts: { primary: "Source Sans Pro", heading: "Merriweather", display: "Playfair Display" } },
      { name: "Tech Startup", fonts: { primary: "Nunito", heading: "Montserrat", display: "Bebas Neue" } },
      { name: "Creative Agency", fonts: { primary: "Lato", heading: "Poppins", display: "Raleway" } },
      { name: "Corporate Classic", fonts: { primary: "Open Sans", heading: "Source Serif Pro", display: "Montserrat" } }
    ]

    this.renderFontSuggestions(suggestions)
  }

  renderFontSuggestions(suggestions) {
    const container = this.fontSuggestionsTarget
    container.innerHTML = ""

    suggestions.forEach(suggestion => {
      const item = document.createElement("div")
      item.className = "font-suggestion cursor-pointer p-3 rounded-lg border border-gray-200 hover:border-gray-300 transition-colors"
      item.innerHTML = `
        <h4 class="text-sm font-medium text-gray-900 mb-2">${suggestion.name}</h4>
        <div class="space-y-1 text-xs text-gray-600">
          <div>Body: <span style="font-family: '${suggestion.fonts.primary}'">${suggestion.fonts.primary}</span></div>
          <div>Heading: <span style="font-family: '${suggestion.fonts.heading}'">${suggestion.fonts.heading}</span></div>
          <div>Display: <span style="font-family: '${suggestion.fonts.display}'">${suggestion.fonts.display}</span></div>
        </div>
      `
      
      item.addEventListener("click", () => this.applySuggestedFonts(suggestion.fonts))
      container.appendChild(item)
    })
  }

  applySuggestedFonts(fonts) {
    Object.entries(fonts).forEach(([type, fontName]) => {
      this.currentTheme.fonts[type] = fontName
      
      // Update form selects
      const select = this.element.querySelector(`[data-font-type="${type}"]`)
      if (select) {
        select.value = fontName
      }
    })

    // Load the fonts
    const uniqueFonts = [...new Set(Object.values(fonts))]
    this.loadGoogleFontsCSS(uniqueFonts)

    this.updatePreview()
    this.saveTheme()
    this.showNotification("Font combination applied successfully!")
  }

  // ==========================================================================
  // LOGO UPLOAD
  // ==========================================================================

  setupLogoUpload() {
    if (this.hasLogoUploadTarget) {
      this.logoUploadTarget.addEventListener("change", (e) => this.handleLogoUpload(e))
    }
  }

  async handleLogoUpload(event) {
    const file = event.target.files[0]
    if (!file) {return}

    // Validate file type
    if (!file.type.startsWith("image/")) {
      this.showNotification("Please select an image file", "error")
      return
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      this.showNotification("File size must be less than 5MB", "error")
      return
    }

    try {
      // Create preview
      const reader = new FileReader()
      reader.onload = (e) => {
        const imageData = e.target.result
        this.currentTheme.branding.logo = imageData
        
        if (this.hasLogoPreviewTarget) {
          this.logoPreviewTarget.src = imageData
          this.logoPreviewTarget.classList.remove("hidden")
        }
        
        this.updatePreview()
        this.saveTheme()
      }
      
      reader.readAsDataURL(file)
      
      // Auto-resize if needed
      await this.optimizeLogo(file)
      
    } catch (error) {
      console.error("Logo upload error:", error)
      this.showNotification("Failed to upload logo", "error")
    }
  }

  async optimizeLogo(file) {
    // Create canvas for image optimization
    const canvas = document.createElement("canvas")
    const ctx = canvas.getContext("2d")
    const img = new Image()
    
    return new Promise((resolve) => {
      img.onload = () => {
        // Calculate optimal dimensions
        const maxWidth = 200
        const maxHeight = 80
        
        let { width, height } = img
        
        if (width > maxWidth || height > maxHeight) {
          const ratio = Math.min(maxWidth / width, maxHeight / height)
          width *= ratio
          height *= ratio
        }
        
        canvas.width = width
        canvas.height = height
        
        // Draw optimized image
        ctx.drawImage(img, 0, 0, width, height)
        
        // Convert to optimized data URL
        const optimizedData = canvas.toDataURL("image/png", 0.9)
        this.currentTheme.branding.logoOptimized = optimizedData
        
        resolve()
      }
      
      img.src = URL.createObjectURL(file)
    })
  }

  // ==========================================================================
  // LAYOUT CUSTOMIZATION
  // ==========================================================================

  handleLayoutChange(event) {
    const layoutType = event.target.dataset.layoutType
    const value = event.target.value

    this.currentTheme.layout[layoutType] = value
    this.updatePreview()
    this.saveTheme()
  }

  // ==========================================================================
  // PRESET THEMES
  // ==========================================================================

  loadPresetThemes() {
    this.presetsValue = [
      {
        name: "Default",
        colors: { primary: "#3b82f6", secondary: "#6366f1", accent: "#10b981", neutral: "#6b7280" },
        fonts: { primary: "Inter", heading: "Inter", display: "Playfair Display" },
        layout: { style: "modern", sidebar: "expanded", header: "fixed" }
      },
      {
        name: "Dark Professional",
        colors: { primary: "#6366f1", secondary: "#8b5cf6", accent: "#06b6d4", neutral: "#64748b" },
        fonts: { primary: "Roboto", heading: "Montserrat", display: "Oswald" },
        layout: { style: "dark", sidebar: "collapsed", header: "static" }
      },
      {
        name: "Creative Agency",
        colors: { primary: "#f59e0b", secondary: "#ef4444", accent: "#8b5cf6", neutral: "#6b7280" },
        fonts: { primary: "Lato", heading: "Poppins", display: "Bebas Neue" },
        layout: { style: "colorful", sidebar: "expanded", header: "floating" }
      },
      {
        name: "Minimal Clean",
        colors: { primary: "#374151", secondary: "#6b7280", accent: "#10b981", neutral: "#9ca3af" },
        fonts: { primary: "Source Sans Pro", heading: "Source Sans Pro", display: "Merriweather" },
        layout: { style: "minimal", sidebar: "hidden", header: "static" }
      }
    ]

    this.renderPresetThemes()
  }

  renderPresetThemes() {
    if (!this.hasPresetThemesTarget) {return}

    const container = this.presetThemesTarget
    container.innerHTML = ""

    this.presetsValue.forEach(preset => {
      const item = document.createElement("div")
      item.className = "preset-theme cursor-pointer p-4 rounded-lg border border-gray-200 hover:border-gray-300 transition-colors"
      item.innerHTML = `
        <div class="flex justify-between items-start mb-3">
          <h3 class="font-medium text-gray-900">${preset.name}</h3>
          <div class="flex space-x-1">
            ${Object.values(preset.colors).map(color => `
              <div class="w-3 h-3 rounded-full" style="background-color: ${color}"></div>
            `).join("")}
          </div>
        </div>
        <div class="text-xs text-gray-600 space-y-1">
          <div>Primary Font: ${preset.fonts.primary}</div>
          <div>Layout: ${preset.layout.style}</div>
        </div>
      `
      
      item.addEventListener("click", () => this.applyPresetTheme(preset))
      container.appendChild(item)
    })
  }

  applyPresetTheme(preset) {
    // Apply colors
    Object.entries(preset.colors).forEach(([type, color]) => {
      this.currentTheme.colors[type] = color
      const input = this.element.querySelector(`[data-color-type="${type}"]`)
      if (input) {input.value = color}
    })

    // Apply fonts
    Object.entries(preset.fonts).forEach(([type, font]) => {
      this.currentTheme.fonts[type] = font
      const select = this.element.querySelector(`[data-font-type="${type}"]`)
      if (select) {select.value = font}
    })

    // Apply layout
    Object.entries(preset.layout).forEach(([type, value]) => {
      this.currentTheme.layout[type] = value
      const input = this.element.querySelector(`[data-layout-type="${type}"]`)
      if (input) {input.value = value}
    })

    // Load fonts and update
    const uniqueFonts = [...new Set(Object.values(preset.fonts))]
    this.loadGoogleFontsCSS(uniqueFonts)

    this.updatePreview()
    this.saveTheme()
    this.showNotification(`${preset.name} theme applied successfully!`)
  }

  // ==========================================================================
  // PREVIEW & APPLICATION
  // ==========================================================================

  updatePreview() {
    if (!this.hasPreviewTarget) {return}

    const preview = this.previewTarget
    const { colors, fonts, branding, layout } = this.currentTheme

    // Apply colors
    Object.entries(colors).forEach(([type, color]) => {
      preview.style.setProperty(`--preview-${type}`, color)
    })

    // Apply fonts
    Object.entries(fonts).forEach(([type, font]) => {
      preview.style.setProperty(`--preview-font-${type}`, `'${font}', sans-serif`)
    })

    // Apply branding
    if (branding.logo) {
      const logoElement = preview.querySelector(".preview-logo")
      if (logoElement) {
        logoElement.src = branding.logo
        logoElement.style.display = "block"
      }
    }

    if (branding.companyName) {
      const nameElement = preview.querySelector(".preview-company-name")
      if (nameElement) {
        nameElement.textContent = branding.companyName
      }
    }

    // Apply layout styles
    preview.className = `theme-preview layout-${layout.style} sidebar-${layout.sidebar} header-${layout.header}`

    // Update live theme if enabled
    if (this.isLivePreviewEnabled) {
      this.applyThemeToDocument()
    }
  }

  applyThemeToDocument() {
    const root = document.documentElement
    const { colors, fonts } = this.currentTheme

    // Apply colors to CSS custom properties
    Object.entries(colors).forEach(([type, color]) => {
      root.style.setProperty(`--brand-${type}-500`, color)
      root.style.setProperty(`--color-${type}`, color)
    })

    // Apply fonts
    Object.entries(fonts).forEach(([type, font]) => {
      root.style.setProperty(`--font-family-${type}`, `'${font}', sans-serif`)
    })
  }

  // ==========================================================================
  // SAVE & EXPORT
  // ==========================================================================

  saveTheme() {
    try {
      localStorage.setItem("theme-customizer-settings", JSON.stringify(this.currentTheme))
      this.dispatchThemeChangeEvent()
    } catch (error) {
      console.error("Failed to save theme:", error)
    }
  }

  exportTheme() {
    const exportData = {
      theme: this.currentTheme,
      timestamp: new Date().toISOString(),
      version: "1.0.0",
      css: this.generateThemeCSS(),
      scss: this.generateThemeSCSS()
    }

    this.downloadJSON(exportData, `theme-${Date.now()}.json`)
    this.showNotification("Theme exported successfully!")
  }

  generateThemeCSS() {
    const { colors, fonts } = this.currentTheme
    
    let css = ":root {\n"
    
    // Colors
    Object.entries(colors).forEach(([type, color]) => {
      css += `  --brand-${type}-500: ${color};\n`
      css += `  --color-${type}: ${color};\n`
    })
    
    // Fonts
    Object.entries(fonts).forEach(([type, font]) => {
      css += `  --font-family-${type}: '${font}', sans-serif;\n`
    })
    
    css += "}"
    return css
  }

  generateThemeSCSS() {
    const { colors, fonts } = this.currentTheme
    
    let scss = "// Theme Variables\n"
    
    // Colors
    Object.entries(colors).forEach(([type, color]) => {
      scss += `$color-${type}: ${color};\n`
    })
    
    scss += "\n// Fonts\n"
    Object.entries(fonts).forEach(([type, font]) => {
      scss += `$font-${type}: '${font}', sans-serif;\n`
    })
    
    return scss
  }

  resetTheme() {
    if (confirm("Are you sure you want to reset all customizations?")) {
      localStorage.removeItem("theme-customizer-settings")
      this.initializeCustomizer()
      this.showNotification("Theme reset to defaults")
    }
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  applyThemeToForm() {
    // Apply colors to form inputs
    Object.entries(this.currentTheme.colors).forEach(([type, color]) => {
      const input = this.element.querySelector(`[data-color-type="${type}"]`)
      if (input) {input.value = color}
    })

    // Apply fonts to selects
    Object.entries(this.currentTheme.fonts).forEach(([type, font]) => {
      const select = this.element.querySelector(`[data-font-type="${type}"]`)
      if (select) {select.value = font}
    })

    // Apply branding
    if (this.currentTheme.branding.companyName && this.hasCompanyNameTarget) {
      this.companyNameTarget.value = this.currentTheme.branding.companyName
    }

    if (this.currentTheme.branding.brandName && this.hasBrandNameTarget) {
      this.brandNameTarget.value = this.currentTheme.branding.brandName
    }

    // Apply layout
    Object.entries(this.currentTheme.layout).forEach(([type, value]) => {
      const input = this.element.querySelector(`[data-layout-type="${type}"]`)
      if (input) {input.value = value}
    })
  }

  bindEventListeners() {
    // Branding inputs
    if (this.hasCompanyNameTarget) {
      this.companyNameTarget.addEventListener("input", (e) => {
        this.currentTheme.branding.companyName = e.target.value
        this.updatePreview()
        this.saveTheme()
      })
    }

    if (this.hasBrandNameTarget) {
      this.brandNameTarget.addEventListener("input", (e) => {
        this.currentTheme.branding.brandName = e.target.value
        this.updatePreview()
        this.saveTheme()
      })
    }

    // Layout inputs
    const layoutInputs = this.element.querySelectorAll("[data-layout-type]")
    layoutInputs.forEach(input => {
      input.addEventListener("change", (e) => this.handleLayoutChange(e))
    })

    // Custom CSS
    if (this.hasCustomCSSTarget) {
      this.customCSSTarget.addEventListener("input", (e) => {
        this.currentTheme.customCSS = e.target.value
        this.saveTheme()
      })
    }
  }

  dispatchThemeChangeEvent() {
    const event = new CustomEvent("theme:customized", {
      detail: { theme: this.currentTheme },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  showNotification(message, type = "success") {
    // Create toast notification
    const toast = document.createElement("div")
    toast.className = `fixed top-4 right-4 z-50 p-3 rounded-lg shadow-lg text-white text-sm max-w-sm transition-all duration-300 ${
      type === "error" ? "bg-red-500" : "bg-green-500"
    }`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    // Animate in
    setTimeout(() => toast.classList.add("translate-x-0"), 10)
    
    // Remove after delay
    setTimeout(() => {
      toast.classList.add("translate-x-full", "opacity-0")
      setTimeout(() => document.body.removeChild(toast), 300)
    }, 3000)
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

  // Color utility methods
  hexToHsl(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
    if (!result) {return null}
    
    const r = parseInt(result[1], 16) / 255
    const g = parseInt(result[2], 16) / 255
    const b = parseInt(result[3], 16) / 255
    
    const max = Math.max(r, g, b)
    const min = Math.min(r, g, b)
    let h, s
    const l = (max + min) / 2
    
    if (max === min) {
      h = s = 0
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
  }

  hslToHex(h, s, l) {
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
      r = g = b = l
    } else {
      const q = l < 0.5 ? l * (1 + s) : l + s - l * s
      const p = 2 * l - q
      r = hue2rgb(p, q, h + 1/3)
      g = hue2rgb(p, q, h)
      b = hue2rgb(p, q, h - 1/3)
    }
    
    const toHex = (c) => {
      const hex = Math.round(c * 255).toString(16)
      return hex.length === 1 ? `0${  hex}` : hex
    }
    
    return `#${toHex(r)}${toHex(g)}${toHex(b)}`
  }

  calculateContrastRatio(color1, color2) {
    const getLuminance = (hex) => {
      const rgb = hex.match(/\w\w/g).map(x => parseInt(x, 16) / 255)
      const [r, g, b] = rgb.map(c => c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4))
      return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    const l1 = getLuminance(color1)
    const l2 = getLuminance(color2)
    
    const lighter = Math.max(l1, l2)
    const darker = Math.min(l1, l2)
    
    return (lighter + 0.05) / (darker + 0.05)
  }

  // ==========================================================================
  // STIMULUS ACTION METHODS
  // ==========================================================================

  applyHarmonyColor(event) {
    const color = event.target.dataset.color
    // Apply to the currently focused color input or primary by default
    const focusedInput = this.element.querySelector("input[type='color']:focus") || 
                        this.primaryColorTarget
    
    if (focusedInput) {
      focusedInput.value = color
      focusedInput.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  toggleLivePreview() {
    this.isLivePreviewEnabled = !this.isLivePreviewEnabled
    
    if (this.isLivePreviewEnabled) {
      this.applyThemeToDocument()
    } else {
      // Reset to default theme
      location.reload()
    }
  }
}