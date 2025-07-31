import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="loading"
export default class extends Controller {
  static targets = [
    "button", 
    "spinner", 
    "content", 
    "skeleton",
    "overlay",
    "progress",
    "progressBar",
    "progressText"
  ]
  
  static values = { 
    type: String, // "button", "page", "content", "form"
    delay: Number, // milliseconds to delay showing loader
    minDuration: Number, // minimum time to show loader
    progressSteps: Array // for multi-step processes
  }

  static classes = [
    "loading",
    "disabled"
  ]

  connect() {
    this.delayTimeout = null
    this.minDurationTimeout = null
    this.startTime = null
    this.currentStep = 0
    
    // Set default values
    if (!this.hasDelayValue) this.delayValue = 200
    if (!this.hasMinDurationValue) this.minDurationValue = 500
    if (!this.hasTypeValue) this.typeValue = "button"
    
    // Auto-setup based on type
    this.setupLoadingType()
    
    // Listen for Turbo events for page transitions
    this.boundHandleTurboStart = this.handleTurboStart.bind(this)
    this.boundHandleTurboEnd = this.handleTurboEnd.bind(this)
    
    document.addEventListener("turbo:submit-start", this.boundHandleTurboStart)
    document.addEventListener("turbo:submit-end", this.boundHandleTurboEnd)
    document.addEventListener("turbo:before-visit", this.boundHandleTurboStart)
    document.addEventListener("turbo:visit", this.boundHandleTurboEnd)
    document.addEventListener("turbo:before-frame-load", this.boundHandleTurboStart)
    document.addEventListener("turbo:frame-load", this.boundHandleTurboEnd)
  }

  disconnect() {
    this.clearTimeouts()
    
    document.removeEventListener("turbo:submit-start", this.boundHandleTurboStart)
    document.removeEventListener("turbo:submit-end", this.boundHandleTurboEnd)
    document.removeEventListener("turbo:before-visit", this.boundHandleTurboStart)
    document.removeEventListener("turbo:visit", this.boundHandleTurboEnd)
    document.removeEventListener("turbo:before-frame-load", this.boundHandleTurboStart)
    document.removeEventListener("turbo:frame-load", this.boundHandleTurboEnd)
  }

  setupLoadingType() {
    switch(this.typeValue) {
      case "button":
        this.setupButtonLoading()
        break
      case "page":
        this.setupPageLoading()
        break
      case "content":
        this.setupContentLoading()
        break
      case "form":
        this.setupFormLoading()
        break
    }
  }

  setupButtonLoading() {
    // Listen for form submissions if button is in a form
    const form = this.element.closest('form')
    if (form) {
      form.addEventListener('submit', (e) => {
        if (!e.defaultPrevented) {
          this.showButtonLoading()
        }
      })
    }
  }

  setupPageLoading() {
    // Page loading is handled by Turbo events
  }

  setupContentLoading() {
    // Content loading can be triggered manually or by data fetching
  }

  setupFormLoading() {
    // Form loading combines button and content loading
    const form = this.element.closest('form') || this.element
    if (form) {
      form.addEventListener('submit', (e) => {
        if (!e.defaultPrevented) {
          this.showFormLoading()
        }
      })
    }
  }

  // Manual loading triggers
  show() {
    this.showLoading()
  }

  hide() {
    this.hideLoading()
  }

  toggle() {
    if (this.isLoading()) {
      this.hideLoading()
    } else {
      this.showLoading()
    }
  }

  // Type-specific loading methods
  showButtonLoading() {
    if (this.hasButtonTarget) {
      const button = this.buttonTarget
      const textElement = button.querySelector('[data-loading-target="text"]')
      const contentElement = button.querySelector('[data-loading-target="content"]')
      const spinnerElement = button.querySelector('[data-loading-target="spinner"]')
      
      // Store original state
      button.dataset.originalDisabled = button.disabled
      if (textElement) {
        button.dataset.originalText = textElement.textContent.trim()
      }
      
      // Update button state
      button.disabled = true
      button.classList.add(...this.loadingClasses, ...this.disabledClasses)
      
      // Show spinner and hide content
      if (spinnerElement && contentElement) {
        spinnerElement.classList.remove('hidden')
        contentElement.classList.add('opacity-0')
      } else if (this.hasSpinnerTarget) {
        this.spinnerTarget.classList.remove('hidden')
      } else {
        // Create inline spinner if none exists
        const spinner = this.createInlineSpinner()
        button.prepend(spinner)
      }
      
      // Update button text if we have text element
      if (textElement) {
        const loadingText = button.dataset.loadingText || 'Loading...'
        textElement.textContent = loadingText
      }
    }
    
    this.startLoadingTimer()
  }

  hideButtonLoading() {
    if (this.hasButtonTarget) {
      const button = this.buttonTarget
      const textElement = button.querySelector('[data-loading-target="text"]')
      const contentElement = button.querySelector('[data-loading-target="content"]')
      const spinnerElement = button.querySelector('[data-loading-target="spinner"]')
      
      // Restore original state
      button.disabled = button.dataset.originalDisabled === 'true'
      button.classList.remove(...this.loadingClasses, ...this.disabledClasses)
      
      // Hide spinner and show content
      if (spinnerElement && contentElement) {
        spinnerElement.classList.add('hidden')
        contentElement.classList.remove('opacity-0')
      } else if (this.hasSpinnerTarget) {
        this.spinnerTarget.classList.add('hidden')
      } else {
        // Remove inline spinner
        const inlineSpinner = button.querySelector('.inline-spinner')
        if (inlineSpinner) {
          inlineSpinner.remove()
        }
      }
      
      // Restore original text
      if (textElement && button.dataset.originalText) {
        textElement.textContent = button.dataset.originalText
      }
    }
  }

  showPageLoading() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('hidden')
      // Trigger reflow for animation
      this.overlayTarget.offsetHeight
      this.overlayTarget.classList.add('opacity-100')
    }
    
    this.startLoadingTimer()
  }

  hidePageLoading() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('opacity-100')
      setTimeout(() => {
        this.overlayTarget.classList.add('hidden')
      }, 300) // Match transition duration
    }
  }

  showContentLoading() {
    if (this.hasContentTarget && this.hasSkeletonTarget) {
      this.contentTarget.classList.add('hidden')
      this.skeletonTarget.classList.remove('hidden')
    }
    
    this.startLoadingTimer()
  }

  hideContentLoading() {
    if (this.hasContentTarget && this.hasSkeletonTarget) {
      this.skeletonTarget.classList.add('hidden')
      this.contentTarget.classList.remove('hidden')
    }
  }

  showFormLoading() {
    // Disable all form inputs
    const form = this.element.closest('form') || this.element
    const inputs = form.querySelectorAll('input, select, textarea, button')
    
    inputs.forEach(input => {
      input.dataset.originalDisabled = input.disabled
      input.disabled = true
    })
    
    // Show form-wide loading indicator
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('hidden')
    }
    
    // Also show button loading if present
    this.showButtonLoading()
    
    this.startLoadingTimer()
  }

  hideFormLoading() {
    // Re-enable form inputs
    const form = this.element.closest('form') || this.element
    const inputs = form.querySelectorAll('input, select, textarea, button')
    
    inputs.forEach(input => {
      input.disabled = input.dataset.originalDisabled === 'true'
    })
    
    // Hide form overlay
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add('hidden')
    }
    
    // Hide button loading
    this.hideButtonLoading()
  }

  // Progress bar methods
  updateProgress(step, total = null) {
    if (!this.hasProgressTarget) return
    
    total = total || this.progressStepsValue.length || 100
    const percentage = Math.round((step / total) * 100)
    
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percentage}%`
      this.progressBarTarget.setAttribute('aria-valuenow', percentage)
    }
    
    if (this.hasProgressTextTarget) {
      if (this.progressStepsValue.length > 0 && step <= this.progressStepsValue.length) {
        this.progressTextTarget.textContent = this.progressStepsValue[step - 1]
      } else {
        this.progressTextTarget.textContent = `${percentage}% complete`
      }
    }
    
    this.currentStep = step
  }

  nextStep() {
    this.updateProgress(this.currentStep + 1)
  }

  resetProgress() {
    this.updateProgress(0)
  }

  // Utility methods
  showLoading() {
    switch(this.typeValue) {
      case "button":
        this.showButtonLoading()
        break
      case "page":
        this.showPageLoading()
        break
      case "content":
        this.showContentLoading()
        break
      case "form":
        this.showFormLoading()
        break
    }
  }

  hideLoading() {
    this.clearTimeouts()
    
    switch(this.typeValue) {
      case "button":
        this.hideButtonLoading()
        break
      case "page":
        this.hidePageLoading()
        break
      case "content":
        this.hideContentLoading()
        break
      case "form":
        this.hideFormLoading()
        break
    }
  }

  isLoading() {
    switch(this.typeValue) {
      case "button":
        return this.hasButtonTarget && this.buttonTarget.disabled
      case "page":
        return this.hasOverlayTarget && !this.overlayTarget.classList.contains('hidden')
      case "content":
        return this.hasSkeletonTarget && !this.skeletonTarget.classList.contains('hidden')
      case "form":
        return this.hasOverlayTarget && !this.overlayTarget.classList.contains('hidden')
      default:
        return false
    }
  }

  startLoadingTimer() {
    this.startTime = Date.now()
    
    // Clear any existing timeouts
    this.clearTimeouts()
    
    // Set minimum duration timeout
    this.minDurationTimeout = setTimeout(() => {
      this.element.classList.add('min-duration-met')
    }, this.minDurationValue)
  }

  clearTimeouts() {
    if (this.delayTimeout) {
      clearTimeout(this.delayTimeout)
      this.delayTimeout = null
    }
    
    if (this.minDurationTimeout) {
      clearTimeout(this.minDurationTimeout)
      this.minDurationTimeout = null
    }
  }

  createInlineSpinner() {
    const spinner = document.createElement('span')
    spinner.className = 'inline-spinner inline-block w-4 h-4 mr-2 border-2 border-white border-t-transparent rounded-full animate-spin'
    spinner.setAttribute('aria-hidden', 'true')
    return spinner
  }

  // Turbo event handlers
  handleTurboStart(event) {
    if (this.typeValue === "page" && this.element.contains(event.target)) {
      this.showPageLoading()
    }
  }

  handleTurboEnd(event) {
    if (this.typeValue === "page" && this.element.contains(event.target)) {
      // Ensure minimum duration before hiding
      const elapsed = Date.now() - (this.startTime || 0)
      const remaining = Math.max(0, this.minDurationValue - elapsed)
      
      setTimeout(() => {
        this.hidePageLoading()
      }, remaining)
    } else {
      // For other types, hide immediately on Turbo events
      this.hideLoading()
    }
  }

  // Event handlers for manual triggers
  click(event) {
    if (this.typeValue === "button") {
      // Let the normal form submission handle loading
      return
    }
    
    this.showLoading()
  }

  // Accessibility
  announceLoading(message = "Loading") {
    const announcement = document.createElement('div')
    announcement.setAttribute('aria-live', 'polite')
    announcement.setAttribute('aria-atomic', 'true')
    announcement.className = 'sr-only'
    announcement.textContent = message
    
    document.body.appendChild(announcement)
    
    setTimeout(() => {
      document.body.removeChild(announcement)
    }, 1000)
  }
}