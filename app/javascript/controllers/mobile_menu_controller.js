import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "overlay", "hamburger", "drawer"]
  static classes = ["open"]
  static values = {
    direction: { type: String, default: "right" },
    closeOnNavigation: { type: Boolean, default: true }
  }

  connect() {
    // Bind click outside handler to the controller instance
    this.clickOutsideHandler = this.clickOutside.bind(this)
    
    // Initialize mobile navigation
    this.initializeMobileNav()
    
    // Handle orientation changes
    this.handleOrientationChange = this.handleOrientationChange.bind(this)
    window.addEventListener('orientationchange', this.handleOrientationChange)
    window.addEventListener('resize', this.handleOrientationChange)
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener("click", this.clickOutsideHandler)
    window.removeEventListener('orientationchange', this.handleOrientationChange)
    window.removeEventListener('resize', this.handleOrientationChange)
  }
  
  initializeMobileNav() {
    // Set up mobile navigation attributes
    if (this.hasMenuTarget) {
      this.menuTarget.setAttribute('role', 'navigation')
      this.menuTarget.setAttribute('aria-label', 'Mobile navigation')
    }
    
    if (this.hasHamburgerTarget) {
      this.hamburgerTarget.setAttribute('aria-expanded', 'false')
      this.hamburgerTarget.setAttribute('aria-controls', this.menuTarget?.id || 'mobile-menu')
    }
    
    // Initialize touch gestures for mobile devices
    if ('ontouchstart' in window) {
      this.initializeTouchGestures()
    }
  }
  
  initializeTouchGestures() {
    if (!this.hasMenuTarget) {return}
    
    let startX = 0
    let currentX = 0
    let isDragging = false
    
    this.menuTarget.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX
      isDragging = true
      this.menuTarget.style.transition = 'none'
    }, { passive: true })
    
    this.menuTarget.addEventListener('touchmove', (e) => {
      if (!isDragging) {return}
      
      currentX = e.touches[0].clientX
      const diffX = currentX - startX
      
      // Only allow swipe to close
      if (this.directionValue === 'right' && diffX > 0) {
        const translateX = Math.min(diffX, this.menuTarget.offsetWidth)
        this.menuTarget.style.transform = `translateX(${translateX}px)`
      } else if (this.directionValue === 'left' && diffX < 0) {
        const translateX = Math.max(diffX, -this.menuTarget.offsetWidth)
        this.menuTarget.style.transform = `translateX(${translateX}px)`
      }
    }, { passive: true })
    
    this.menuTarget.addEventListener('touchend', (_e) => {
      if (!isDragging) {return}
      
      isDragging = false
      this.menuTarget.style.transition = ''
      
      const diffX = Math.abs(currentX - startX)
      const threshold = this.menuTarget.offsetWidth * 0.3
      
      if (diffX > threshold) {
        this.close()
      } else {
        this.menuTarget.style.transform = ''
      }
    }, { passive: true })
  }
  
  handleOrientationChange() {
    // Close menu on orientation change to prevent layout issues
    if (this.isOpen()) {
      setTimeout(() => this.close(), 100)
    }
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }
  
  isOpen() {
    return this.hasMenuTarget && 
           (this.menuTarget.classList.contains("translate-x-0") || 
            this.menuTarget.classList.contains("open"))
  }

  open() {
    // Prevent multiple opens
    if (this.isOpen()) {return}
    
    // Show overlay with animation
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
      // Force reflow for animation
      this.overlayTarget.offsetHeight
      this.overlayTarget.classList.add("open")
    }
    
    // Show menu with direction-aware animation
    if (this.hasMenuTarget) {
      if (this.directionValue === 'right') {
        this.menuTarget.classList.remove("translate-x-full")
        this.menuTarget.classList.add("translate-x-0")
      } else {
        this.menuTarget.classList.remove("-translate-x-full")
        this.menuTarget.classList.add("translate-x-0")
      }
      this.menuTarget.classList.add("open")
    }
    
    // Update hamburger state
    if (this.hasHamburgerTarget) {
      this.hamburgerTarget.classList.add("active")
      this.hamburgerTarget.setAttribute("aria-expanded", "true")
    }
    
    // Add click outside listener with delay to prevent immediate close
    setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 100)
    
    // Prevent body scroll and handle safe areas
    document.body.style.overflow = "hidden"
    document.body.style.position = "fixed"
    document.body.style.width = "100%"
    
    // Focus management for accessibility
    this.trapFocus()
    
    // Dispatch custom event
    this.dispatch('opened')
  }

  close() {
    // Prevent multiple closes
    if (!this.isOpen()) {return}
    
    // Hide overlay
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("open")
      setTimeout(() => {
        this.overlayTarget.classList.add("hidden")
      }, 300) // Match transition duration
    }
    
    // Hide menu with direction-aware animation
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove("open", "translate-x-0")
      if (this.directionValue === 'right') {
        this.menuTarget.classList.add("translate-x-full")
      } else {
        this.menuTarget.classList.add("-translate-x-full")
      }
      
      // Reset transform for touch gestures
      this.menuTarget.style.transform = ''
    }
    
    // Update hamburger state
    if (this.hasHamburgerTarget) {
      this.hamburgerTarget.classList.remove("active")
      this.hamburgerTarget.setAttribute("aria-expanded", "false")
    }
    
    // Remove click outside listener
    document.removeEventListener("click", this.clickOutsideHandler)
    
    // Restore body scroll
    document.body.style.overflow = ""
    document.body.style.position = ""
    document.body.style.width = ""
    
    // Release focus trap
    this.releaseFocus()
    
    // Dispatch custom event
    this.dispatch('closed')
  }
  
  trapFocus() {
    if (!this.hasMenuTarget) {return}
    
    const focusableElements = this.menuTarget.querySelectorAll(
      'a[href], button, textarea, input[type="text"], input[type="radio"], input[type="checkbox"], select'
    )
    
    if (focusableElements.length > 0) {
      this.firstFocusableElement = focusableElements[0]
      this.lastFocusableElement = focusableElements[focusableElements.length - 1]
      
      // Focus first element
      this.firstFocusableElement.focus()
      
      // Add tab trap
      this.menuTarget.addEventListener('keydown', this.handleTabKey.bind(this))
    }
  }
  
  releaseFocus() {
    if (this.hasMenuTarget) {
      this.menuTarget.removeEventListener('keydown', this.handleTabKey.bind(this))
    }
    
    // Return focus to trigger element
    if (this.hasHamburgerTarget) {
      this.hamburgerTarget.focus()
    }
  }
  
  handleTabKey(e) {
    if (e.key !== 'Tab') {return}
    
    if (e.shiftKey) {
      // Shift + Tab
      if (document.activeElement === this.firstFocusableElement) {
        this.lastFocusableElement.focus()
        e.preventDefault()
      }
    } else {
      // Tab
      if (document.activeElement === this.lastFocusableElement) {
        this.firstFocusableElement.focus()
        e.preventDefault()
      }
    }
  }

  clickOutside(event) {
    // Don't close if clicking on the menu itself or the hamburger button
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  // Handle escape key and other keyboard interactions
  keydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
  
  // Handle navigation link clicks
  navigate(_event) {
    if (this.closeOnNavigationValue) {
      // Small delay to ensure navigation happens before close
      setTimeout(() => this.close(), 50)
    }
  }
  
  // Handle swipe gestures on mobile
  handleSwipe(direction) {
    if (direction === 'right' && this.directionValue === 'left') {
      this.close()
    } else if (direction === 'left' && this.directionValue === 'right') {
      this.close()
    }
  }
  
  // Utility method to check if device supports touch
  isTouchDevice() {
    return 'ontouchstart' in window || navigator.maxTouchPoints > 0
  }
  
  // Handle resize events (orientation change, etc.)
  handleResize() {
    // Close menu if window becomes too wide (desktop view)
    if (window.innerWidth >= 768 && this.isOpen()) {
      this.close()
    }
  }
}