import { Controller } from "@hotwired/stimulus"

// Collapsible controller for widget collapse/expand functionality
export default class extends Controller {
  static targets = ["trigger", "content"]
  static values = { 
    collapsed: { type: Boolean, default: false },
    animated: { type: Boolean, default: true },
    saveState: { type: Boolean, default: true }
  }

  connect() {
    console.log("Collapsible controller connected")
    this.initializeState()
    this.setupAnimations()
  }

  initializeState() {
    // Load saved state if enabled
    if (this.saveStateValue) {
      const savedState = this.getSavedState()
      if (savedState !== null) {
        this.collapsedValue = savedState
      }
    }

    // Apply initial state
    if (this.collapsedValue) {
      this.collapse(false) // Don't animate on initial load
    } else {
      this.expand(false)
    }

    this.updateTriggerState()
  }

  setupAnimations() {
    if (this.animatedValue && this.hasContentTarget) {
      // Set initial state for CSS transitions
      this.contentTarget.style.transition = 'max-height 0.3s ease-in-out, opacity 0.2s ease-in-out'
      this.contentTarget.style.overflow = 'hidden'
    }
  }

  toggle() {
    if (this.collapsedValue) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  collapse(animated = this.animatedValue) {
    this.collapsedValue = true
    this.element.classList.add('collapsed')

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute('aria-expanded', 'false')
    }

    if (this.hasContentTarget) {
      if (animated) {
        // Get current height
        const currentHeight = this.contentTarget.scrollHeight
        this.contentTarget.style.maxHeight = `${currentHeight}px`
        
        // Force reflow
        this.contentTarget.offsetHeight
        
        // Animate to collapsed
        this.contentTarget.style.maxHeight = '0'
        this.contentTarget.style.opacity = '0'
        
        // Handle transition end
        const handleTransitionEnd = () => {
          this.contentTarget.style.display = 'none'
          this.contentTarget.removeEventListener('transitionend', handleTransitionEnd)
        }
        this.contentTarget.addEventListener('transitionend', handleTransitionEnd)
      } else {
        this.contentTarget.style.maxHeight = '0'
        this.contentTarget.style.opacity = '0'
        this.contentTarget.style.display = 'none'
      }
    }

    this.updateTriggerState()
    this.saveState()
    this.dispatch('collapsed')
  }

  expand(animated = this.animatedValue) {
    this.collapsedValue = false
    this.element.classList.remove('collapsed')

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute('aria-expanded', 'true')
    }

    if (this.hasContentTarget) {
      this.contentTarget.style.display = 'block'
      
      if (animated) {
        // Get target height
        const targetHeight = this.contentTarget.scrollHeight
        
        // Start from collapsed state
        this.contentTarget.style.maxHeight = '0'
        this.contentTarget.style.opacity = '0'
        
        // Force reflow
        this.contentTarget.offsetHeight
        
        // Animate to expanded
        this.contentTarget.style.maxHeight = `${targetHeight}px`
        this.contentTarget.style.opacity = '1'
        
        // Clean up after animation
        const handleTransitionEnd = () => {
          this.contentTarget.style.maxHeight = 'none'
          this.contentTarget.removeEventListener('transitionend', handleTransitionEnd)
        }
        this.contentTarget.addEventListener('transitionend', handleTransitionEnd)
      } else {
        this.contentTarget.style.maxHeight = 'none'
        this.contentTarget.style.opacity = '1'
      }
    }

    this.updateTriggerState()
    this.saveState()
    this.dispatch('expanded')
  }

  updateTriggerState() {
    if (!this.hasTriggerTarget) {return}

    // Update aria-expanded
    this.triggerTarget.setAttribute('aria-expanded', (!this.collapsedValue).toString())

    // Update trigger icon rotation
    const icon = this.triggerTarget.querySelector('svg')
    if (icon) {
      if (this.collapsedValue) {
        icon.style.transform = 'rotate(180deg)'
      } else {
        icon.style.transform = 'rotate(0deg)'
      }
    }

    // Update trigger text if it has text content indicating state
    const triggerText = this.triggerTarget.querySelector('.collapse-text')
    if (triggerText) {
      triggerText.textContent = this.collapsedValue ? 'Expand' : 'Collapse'
    }
  }

  // State Management
  saveState() {
    if (!this.saveStateValue) {return}

    try {
      const widgetType = this.element.dataset.widgetType
      if (!widgetType) {return}

      const key = `collapsible-${widgetType}`
      localStorage.setItem(key, this.collapsedValue.toString())
    } catch (error) {
      console.warn('Failed to save collapsible state:', error)
    }
  }

  getSavedState() {
    if (!this.saveStateValue) {return null}

    try {
      const widgetType = this.element.dataset.widgetType
      if (!widgetType) {return null}

      const key = `collapsible-${widgetType}`
      const saved = localStorage.getItem(key)
      return saved !== null ? saved === 'true' : null
    } catch (error) {
      console.warn('Failed to load collapsible state:', error)
      return null
    }
  }

  // Keyboard Support
  handleKeydown(event) {
    // Handle Enter and Space keys for accessibility
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      this.toggle()
    }
  }

  // Touch Support for Mobile
  handleTouchStart(event) {
    this.touchStartY = event.touches[0].clientY
  }

  handleTouchEnd(event) {
    if (!this.touchStartY) {return}

    const touchEndY = event.changedTouches[0].clientY
    const deltaY = this.touchStartY - touchEndY

    // Swipe up to collapse, swipe down to expand
    if (Math.abs(deltaY) > 50) {
      if (deltaY > 0 && !this.collapsedValue) {
        // Swipe up - collapse
        this.collapse()
      } else if (deltaY < 0 && this.collapsedValue) {
        // Swipe down - expand
        this.expand()
      }
    }

    this.touchStartY = null
  }

  // Public API Methods
  forceCollapse() {
    this.collapse(false)
  }

  forceExpand() {
    this.expand(false)
  }

  isCollapsed() {
    return this.collapsedValue
  }

  // Responsive Behavior
  collapsedValueChanged() {
    // This will be called whenever the collapsed value changes
    this.dispatch('stateChanged', { 
      detail: { 
        collapsed: this.collapsedValue,
        widget: this.element.dataset.widgetType
      } 
    })
  }

  // Handle window resize
  handleResize() {
    if (!this.collapsedValue && this.hasContentTarget) {
      // Recalculate height for responsive content
      const currentMaxHeight = this.contentTarget.style.maxHeight
      if (currentMaxHeight && currentMaxHeight !== 'none') {
        this.contentTarget.style.maxHeight = 'none'
        const newHeight = this.contentTarget.scrollHeight
        this.contentTarget.style.maxHeight = `${newHeight}px`
      }
    }
  }

  // Cleanup
  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  }
}