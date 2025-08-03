// =============================================================================
// THEME CONTROLLER - COMPREHENSIVE THEME MANAGEMENT
// =============================================================================
// Advanced theme switching with accessibility support, smooth transitions,
// and persistent storage
// =============================================================================

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "themeIcon", "systemIcon", "lightIcon", "darkIcon"]
  static values = { 
    theme: String,
    storageKey: { type: String, default: "user-theme-preference" },
    transitionDuration: { type: Number, default: 200 }
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  connect() {
    console.log("Theme controller connected")
    this.initializeTheme()
    this.setupMediaQueryListener()
    this.setupAccessibilityFeatures()
    this.updateThemeIcons()
  }

  disconnect() {
    if (this.mediaQueryListener) {
      this.prefersDarkScheme.removeEventListener('change', this.mediaQueryListener)
    }
  }

  // ==========================================================================
  // THEME INITIALIZATION
  // ==========================================================================

  initializeTheme() {
    // Get theme preference from storage or system
    const storedTheme = localStorage.getItem(this.storageKeyValue)
    const systemTheme = this.getSystemTheme()
    
    // Priority: stored preference > system preference > light default
    let initialTheme = storedTheme || systemTheme || 'light'
    
    // Validate theme value
    if (!['light', 'dark', 'system'].includes(initialTheme)) {
      initialTheme = 'light'
    }
    
    this.themeValue = initialTheme
    this.applyTheme(this.themeValue)
    
    console.log(`Theme initialized: ${this.themeValue}`)
  }

  setupMediaQueryListener() {
    this.prefersDarkScheme = window.matchMedia('(prefers-color-scheme: dark)')
    this.mediaQueryListener = (_e) => {
      if (this.themeValue === 'system') {
        this.applySystemTheme()
      }
    }
    this.prefersDarkScheme.addEventListener('change', this.mediaQueryListener)
  }

  // ==========================================================================
  // THEME SWITCHING METHODS
  // ==========================================================================

  toggleTheme() {
    const themeOrder = ['light', 'dark', 'system']
    const currentIndex = themeOrder.indexOf(this.themeValue)
    const nextIndex = (currentIndex + 1) % themeOrder.length
    const nextTheme = themeOrder[nextIndex]
    
    this.setTheme(nextTheme)
    this.announceThemeChange(nextTheme)
  }

  // Action methods for direct theme setting
  setLightTheme() {
    this.setTheme('light')
  }

  setDarkTheme() {
    this.setTheme('dark')
  }

  setSystemTheme() {
    this.setTheme('system')
  }

  setTheme(theme) {
    if (!['light', 'dark', 'system'].includes(theme)) {
      console.warn(`Invalid theme: ${theme}. Using 'light' as fallback.`)
      theme = 'light'
    }

    const previousTheme = this.themeValue
    this.themeValue = theme
    
    // Store preference
    localStorage.setItem(this.storageKeyValue, theme)
    
    // Apply theme with smooth transition
    this.applyThemeWithTransition(theme)
    
    // Update UI
    this.updateThemeIcons()
    this.updateThemeToggleState()
    
    // Dispatch custom event
    this.dispatchThemeChangeEvent(previousTheme, theme)
    
    console.log(`Theme changed from ${previousTheme} to ${theme}`)
  }

  // ==========================================================================
  // THEME APPLICATION
  // ==========================================================================

  applyTheme(theme) {
    const effectiveTheme = theme === 'system' ? this.getSystemTheme() : theme
    
    // Remove existing theme classes
    document.documentElement.classList.remove('theme-light', 'theme-dark')
    document.documentElement.removeAttribute('data-theme')
    
    // Apply new theme
    document.documentElement.classList.add(`theme-${effectiveTheme}`)
    document.documentElement.setAttribute('data-theme', effectiveTheme)
    
    // Update CSS custom properties for theme-specific values
    this.updateThemeCustomProperties(effectiveTheme)
    
    // Update meta theme-color for mobile browsers
    this.updateMetaThemeColor(effectiveTheme)
  }

  applyThemeWithTransition(theme) {
    // Add transition class to enable smooth theme switching
    document.documentElement.classList.add('theme-transitioning')
    
    // Apply the theme
    this.applyTheme(theme)
    
    // Remove transition class after animation completes
    setTimeout(() => {
      document.documentElement.classList.remove('theme-transitioning')
    }, this.transitionDurationValue)
  }

  applySystemTheme() {
    const systemTheme = this.getSystemTheme()
    this.applyTheme(systemTheme)
    this.updateMetaThemeColor(systemTheme)
  }

  // ==========================================================================
  // THEME UTILITIES
  // ==========================================================================

  getSystemTheme() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  }

  getCurrentEffectiveTheme() {
    return this.themeValue === 'system' ? this.getSystemTheme() : this.themeValue
  }

  updateThemeCustomProperties(effectiveTheme) {
    const root = document.documentElement
    
    if (effectiveTheme === 'dark') {
      // Set dark theme specific properties
      root.style.setProperty('--theme-brand-primary', 'var(--brand-primary-400)')
      root.style.setProperty('--theme-brand-secondary', 'var(--brand-secondary-400)')
    } else {
      // Set light theme specific properties
      root.style.setProperty('--theme-brand-primary', 'var(--brand-primary-600)')
      root.style.setProperty('--theme-brand-secondary', 'var(--brand-secondary-600)')
    }
  }

  updateMetaThemeColor(effectiveTheme) {
    const metaThemeColor = document.querySelector('meta[name="theme-color"]')
    if (metaThemeColor) {
      const themeColors = {
        light: '#ffffff',
        dark: '#1f2937'
      }
      metaThemeColor.setAttribute('content', themeColors[effectiveTheme] || themeColors.light)
    }
  }

  // ==========================================================================
  // UI UPDATES
  // ==========================================================================

  updateThemeIcons() {
    const currentTheme = this.themeValue
    
    // Hide all icons first
    this.hideAllIcons()
    
    // Show appropriate icon based on current theme
    switch (currentTheme) {
      case 'light':
        this.showIcon('lightIcon')
        break
      case 'dark':
        this.showIcon('darkIcon')
        break
      case 'system':
        this.showIcon('systemIcon')
        break
    }
    
    // Update main theme icon if it exists
    if (this.hasThemeIconTarget) {
      this.themeIconTarget.setAttribute('data-theme', currentTheme)
    }
  }

  hideAllIcons() {
    ['systemIcon', 'lightIcon', 'darkIcon'].forEach(iconName => {
      if (this.hasTarget(iconName)) {
        this.targets.find(iconName).forEach(icon => {
          icon.classList.add('hidden')
          icon.setAttribute('aria-hidden', 'true')
        })
      }
    })
  }

  showIcon(iconName) {
    if (this.hasTarget(iconName)) {
      this.targets.find(iconName).forEach(icon => {
        icon.classList.remove('hidden')
        icon.setAttribute('aria-hidden', 'false')
      })
    }
  }

  updateThemeToggleState() {
    if (this.hasToggleTarget) {
      this.toggleTargets.forEach(toggle => {
        toggle.setAttribute('aria-pressed', this.themeValue === 'dark')
        toggle.setAttribute('data-theme', this.themeValue)
        
        // Update toggle button text for screen readers
        const themeLabels = {
          light: 'Switch to dark theme',
          dark: 'Switch to system theme',
          system: 'Switch to light theme'
        }
        
        const currentLabel = themeLabels[this.themeValue] || 'Toggle theme'
        toggle.setAttribute('aria-label', currentLabel)
        toggle.setAttribute('title', currentLabel)
      })
    }
  }

  // ==========================================================================
  // ACCESSIBILITY FEATURES
  // ==========================================================================

  setupAccessibilityFeatures() {
    // Set up high contrast detection
    this.setupHighContrastDetection()
    
    // Set up reduced motion detection
    this.setupReducedMotionDetection()
    
    // Set up focus management
    this.setupFocusManagement()
  }

  setupHighContrastDetection() {
    const prefersHighContrast = window.matchMedia('(prefers-contrast: high)')
    
    const handleHighContrastChange = (e) => {
      document.documentElement.classList.toggle('high-contrast', e.matches)
      
      if (e.matches) {
        console.log('High contrast mode detected')
        this.applyHighContrastAdjustments()
      }
    }
    
    // Initial check
    handleHighContrastChange(prefersHighContrast)
    
    // Listen for changes
    prefersHighContrast.addEventListener('change', handleHighContrastChange)
  }

  setupReducedMotionDetection() {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)')
    
    const handleReducedMotionChange = (e) => {
      document.documentElement.classList.toggle('reduced-motion', e.matches)
      
      if (e.matches) {
        console.log('Reduced motion preference detected')
        this.applyReducedMotionAdjustments()
      }
    }
    
    // Initial check
    handleReducedMotionChange(prefersReducedMotion)
    
    // Listen for changes
    prefersReducedMotion.addEventListener('change', handleReducedMotionChange)
  }

  setupFocusManagement() {
    // Enhance focus indicators for keyboard navigation
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        document.documentElement.classList.add('keyboard-navigation')
      }
    })
    
    document.addEventListener('mousedown', () => {
      document.documentElement.classList.remove('keyboard-navigation')
    })
  }

  applyHighContrastAdjustments() {
    // Additional high contrast adjustments can be applied here
    const root = document.documentElement
    root.style.setProperty('--shadow-lg', '0 10px 15px -3px rgba(0, 0, 0, 0.5)')
    root.style.setProperty('--shadow-xl', '0 20px 25px -5px rgba(0, 0, 0, 0.5)')
  }

  applyReducedMotionAdjustments() {
    // Reduce animation durations for users who prefer reduced motion
    const root = document.documentElement
    root.style.setProperty('--transition-duration', '0ms')
    root.style.setProperty('--animation-duration', '0ms')
  }

  // ==========================================================================
  // EVENT HANDLING
  // ==========================================================================

  dispatchThemeChangeEvent(previousTheme, newTheme) {
    const event = new CustomEvent('theme:changed', {
      detail: {
        previousTheme,
        newTheme,
        effectiveTheme: this.getCurrentEffectiveTheme()
      },
      bubbles: true
    })
    
    this.element.dispatchEvent(event)
  }

  announceThemeChange(newTheme) {
    // Announce theme change to screen readers
    const announcement = document.createElement('div')
    announcement.setAttribute('aria-live', 'polite')
    announcement.setAttribute('aria-atomic', 'true')
    announcement.className = 'sr-only'
    
    const themeNames = {
      light: 'light theme',
      dark: 'dark theme',
      system: 'system theme'
    }
    
    announcement.textContent = `Switched to ${themeNames[newTheme] || 'theme'}`
    
    document.body.appendChild(announcement)
    
    // Remove announcement after screen readers have time to read it
    setTimeout(() => {
      document.body.removeChild(announcement)
    }, 1000)
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  hasTarget(targetName) {
    return this.targets.find(targetName).length > 0
  }

  // Action for keyboard activation
  handleKeyDown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      this.toggleTheme()
    }
  }

  // ==========================================================================
  // STIMULUS VALUE CHANGE HANDLERS
  // ==========================================================================

  themeValueChanged() {
    if (this.themeValue && this.element) {
      this.updateThemeIcons()
      this.updateThemeToggleState()
    }
  }
}