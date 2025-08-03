// =============================================================================
// ACCESSIBILITY CONTROLLER - COMPREHENSIVE A11Y SUPPORT
// =============================================================================
// Advanced accessibility features including keyboard navigation, screen reader
// support, focus management, and ARIA live regions
// =============================================================================

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "skipLink", "mainContent", "navigation", "search",
    "liveRegion", "announcements", "focusTrap",
    "modal", "dropdown", "tooltip"
  ]
  
  static values = {
    announcePageChanges: { type: Boolean, default: true },
    trapFocus: { type: Boolean, default: true },
    enhanceKeyboardNav: { type: Boolean, default: true }
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  connect() {
    console.log("Accessibility controller connected")
    this.setupAccessibilityFeatures()
    this.setupKeyboardNavigation()
    this.setupScreenReaderSupport()
    this.setupFocusManagement()
    this.setupARIALiveRegions()
    this.bindEventListeners()
    this.announcePageLoad()
  }

  disconnect() {
    this.cleanupEventListeners()
  }

  setupAccessibilityFeatures() {
    // Set up global accessibility state
    this.keyboardNavigation = false
    this.currentFocusTrap = null
    this.focusableElements = []
    this.lastFocusedElement = null
    
    // Create announcement queue
    this.announcementQueue = []
    this.isAnnouncing = false
    
    // Detect keyboard navigation
    this.detectKeyboardNavigation()
    
    // Setup accessibility preferences
    this.setupAccessibilityPreferences()
  }

  // ==========================================================================
  // KEYBOARD NAVIGATION
  // ==========================================================================

  setupKeyboardNavigation() {
    if (!this.enhanceKeyboardNavValue) {return}

    // Global keyboard event handlers
    document.addEventListener("keydown", this.handleGlobalKeyDown.bind(this))
    document.addEventListener("keyup", this.handleGlobalKeyUp.bind(this))
    
    // Focus visible indicators
    document.addEventListener("focusin", this.handleFocusIn.bind(this))
    document.addEventListener("focusout", this.handleFocusOut.bind(this))
    
    // Skip link functionality
    this.setupSkipLinks()
    
    // Enhanced navigation shortcuts
    this.setupNavigationShortcuts()
  }

  detectKeyboardNavigation() {
    document.addEventListener("keydown", (e) => {
      if (e.key === "Tab") {
        this.keyboardNavigation = true
        document.documentElement.classList.add("keyboard-navigation")
      }
    })
    
    document.addEventListener("mousedown", () => {
      this.keyboardNavigation = false
      document.documentElement.classList.remove("keyboard-navigation")
    })
  }

  handleGlobalKeyDown(event) {
    const { key, ctrlKey, metaKey, altKey, shiftKey } = event
    const modifierPressed = ctrlKey || metaKey || altKey
    
    // Handle escape key
    if (key === "Escape") {
      this.handleEscapeKey(event)
    }
    
    // Handle tab navigation
    if (key === "Tab") {
      this.handleTabNavigation(event)
    }
    
    // Handle arrow key navigation
    if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(key)) {
      this.handleArrowNavigation(event)
    }
    
    // Handle enter and space activation
    if (key === "Enter" || key === " ") {
      this.handleActivation(event)
    }
    
    // Handle global shortcuts
    if (modifierPressed) {
      this.handleGlobalShortcuts(event)
    }
    
    // Handle modal navigation
    if (this.currentFocusTrap) {
      this.handleTrapNavigation(event)
    }
  }

  handleGlobalKeyUp(event) {
    // Handle any key up events
    this.announceKeyboardShortcuts(event)
  }

  handleEscapeKey(event) {
    // Close modals, dropdowns, tooltips
    this.closeOverlays()
    
    // Clear focus traps
    this.releaseFocusTrap()
    
    // Return focus to trigger element
    this.returnFocusToTrigger()
    
    this.announce("Closed overlay")
  }

  handleTabNavigation(event) {
    // Enhanced tab navigation with focus management
    if (this.currentFocusTrap) {
      this.handleTrapTabNavigation(event)
      return
    }
    
    // Skip over hidden or disabled elements
    const focusableElements = this.getFocusableElements()
    const currentIndex = focusableElements.indexOf(event.target)
    
    if (currentIndex !== -1) {
      let nextIndex = event.shiftKey ? currentIndex - 1 : currentIndex + 1
      
      // Wrap around
      if (nextIndex < 0) {
        nextIndex = focusableElements.length - 1
      } else if (nextIndex >= focusableElements.length) {
        nextIndex = 0
      }
      
      const nextElement = focusableElements[nextIndex]
      if (nextElement && this.isElementVisible(nextElement)) {
        event.preventDefault()
        nextElement.focus()
        this.announceElementInfo(nextElement)
      }
    }
  }

  handleArrowNavigation(event) {
    const target = event.target
    const role = target.getAttribute("role")
    
    // Handle specific ARIA patterns
    if (role === "menuitem" || role === "option" || role === "tab") {
      this.handleArrowNavInGroup(event, target)
    }
    
    // Handle grid/table navigation
    if (role === "gridcell" || target.closest("[role='grid']")) {
      this.handleGridNavigation(event, target)
    }
  }

  handleArrowNavInGroup(event, element) {
    const container = element.closest("[role='menu'], [role='listbox'], [role='tablist']")
    if (!container) {return}
    
    const items = Array.from(container.querySelectorAll("[role='menuitem'], [role='option'], [role='tab']"))
    const currentIndex = items.indexOf(element)
    
    if (currentIndex === -1) {return}
    
    let nextIndex
    if (event.key === "ArrowDown" || event.key === "ArrowRight") {
      nextIndex = (currentIndex + 1) % items.length
    } else {
      nextIndex = (currentIndex - 1 + items.length) % items.length
    }
    
    event.preventDefault()
    items[nextIndex].focus()
    this.announceElementInfo(items[nextIndex])
  }

  handleGridNavigation(event, element) {
    const grid = element.closest("[role='grid']")
    if (!grid) {return}
    
    const cells = Array.from(grid.querySelectorAll("[role='gridcell']"))
    const currentIndex = cells.indexOf(element)
    const gridRect = this.getGridDimensions(grid)
    
    if (currentIndex === -1) {return}
    
    let nextIndex
    switch (event.key) {
      case "ArrowRight":
        nextIndex = currentIndex + 1
        break
      case "ArrowLeft":
        nextIndex = currentIndex - 1
        break
      case "ArrowDown":
        nextIndex = currentIndex + gridRect.cols
        break
      case "ArrowUp":
        nextIndex = currentIndex - gridRect.cols
        break
      default:
        return
    }
    
    if (nextIndex >= 0 && nextIndex < cells.length) {
      event.preventDefault()
      cells[nextIndex].focus()
      this.announceElementInfo(cells[nextIndex])
    }
  }

  handleActivation(event) {
    const target = event.target
    const role = target.getAttribute("role")
    
    // Handle button-like elements
    if (role === "button" || target.tagName === "BUTTON") {
      if (event.key === " " || event.key === "Enter") {
        event.preventDefault()
        target.click()
      }
    }
    
    // Handle link-like elements
    if (role === "link" || target.tagName === "A") {
      if (event.key === "Enter") {
        event.preventDefault()
        target.click()
      }
    }
    
    // Handle checkboxes and radio buttons
    if (target.type === "checkbox" || target.type === "radio") {
      if (event.key === " ") {
        event.preventDefault()
        target.click()
      }
    }
  }

  // ==========================================================================
  // SKIP LINKS
  // ==========================================================================

  setupSkipLinks() {
    if (!this.hasSkipLinkTarget) {return}
    
    this.skipLinkTargets.forEach(link => {
      link.addEventListener("click", (e) => {
        e.preventDefault()
        const targetId = link.getAttribute("href").substring(1)
        const target = document.getElementById(targetId)
        
        if (target) {
          target.focus()
          target.scrollIntoView({ behavior: "smooth", block: "start" })
          this.announce(`Skipped to ${target.getAttribute("aria-label") || targetId}`)
        }
      })
    })
  }

  setupNavigationShortcuts() {
    // Common keyboard shortcuts
    this.shortcuts = {
      "Alt+1": () => this.focusMainContent(),
      "Alt+2": () => this.focusNavigation(),
      "Alt+3": () => this.focusSearch(),
      "Alt+H": () => this.showKeyboardHelp(),
      "Alt+S": () => this.focusSearch(),
      "Alt+M": () => this.focusMainContent(),
      "Ctrl+/": () => this.showKeyboardHelp(),
      "?": () => this.showKeyboardHelp()
    }
  }

  handleGlobalShortcuts(event) {
    const shortcutKey = this.getShortcutKey(event)
    const handler = this.shortcuts[shortcutKey]
    
    if (handler) {
      event.preventDefault()
      handler()
    }
  }

  getShortcutKey(event) {
    const parts = []
    if (event.ctrlKey) {parts.push("Ctrl")}
    if (event.altKey) {parts.push("Alt")}
    if (event.shiftKey) {parts.push("Shift")}
    parts.push(event.key)
    return parts.join("+")
  }

  // ==========================================================================
  // FOCUS MANAGEMENT
  // ==========================================================================

  setupFocusManagement() {
    if (!this.trapFocusValue) {return}
    
    // Track focus for restoration
    document.addEventListener("focusin", (e) => {
      if (!this.currentFocusTrap) {
        this.lastFocusedElement = e.target
      }
    })
  }

  handleFocusIn(event) {
    const element = event.target
    
    // Announce element info for screen readers
    if (this.keyboardNavigation) {
      this.announceElementInfo(element)
    }
    
    // Ensure element is visible
    this.ensureElementVisible(element)
  }

  handleFocusOut(event) {
    // Clean up any focus-related state
  }

  createFocusTrap(container) {
    if (!container) {return null}
    
    const focusableElements = this.getFocusableElements(container)
    if (focusableElements.length === 0) {return null}
    
    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]
    
    const focusTrap = {
      container,
      firstElement,
      lastElement,
      focusableElements,
      previousFocus: document.activeElement
    }
    
    // Focus first element
    firstElement.focus()
    
    return focusTrap
  }

  handleTrapNavigation(event) {
    if (!this.currentFocusTrap || event.key !== "Tab") {return}
    
    const { firstElement, lastElement } = this.currentFocusTrap
    
    if (event.shiftKey) {
      // Shift+Tab - moving backwards
      if (document.activeElement === firstElement) {
        event.preventDefault()
        lastElement.focus()
      }
    } else {
      // Tab - moving forwards
      if (document.activeElement === lastElement) {
        event.preventDefault()
        firstElement.focus()
      }
    }
  }

  handleTrapTabNavigation(event) {
    const focusableElements = this.currentFocusTrap.focusableElements
    const currentIndex = focusableElements.indexOf(event.target)
    
    if (currentIndex === -1) {return}
    
    let nextIndex
    if (event.shiftKey) {
      nextIndex = currentIndex === 0 ? focusableElements.length - 1 : currentIndex - 1
    } else {
      nextIndex = currentIndex === focusableElements.length - 1 ? 0 : currentIndex + 1
    }
    
    event.preventDefault()
    focusableElements[nextIndex].focus()
  }

  trapFocus(container) {
    this.currentFocusTrap = this.createFocusTrap(container)
    if (this.currentFocusTrap) {
      container.setAttribute("aria-modal", "true")
      this.announce("Dialog opened")
    }
  }

  releaseFocusTrap() {
    if (this.currentFocusTrap) {
      const { container, previousFocus } = this.currentFocusTrap
      
      container.removeAttribute("aria-modal")
      
      // Restore focus
      if (previousFocus && this.isElementVisible(previousFocus)) {
        previousFocus.focus()
      }
      
      this.currentFocusTrap = null
      this.announce("Dialog closed")
    }
  }

  // ==========================================================================
  // SCREEN READER SUPPORT
  // ==========================================================================

  setupScreenReaderSupport() {
    // Create live regions if they don't exist
    this.ensureLiveRegions()
    
    // Setup ARIA labels and descriptions
    this.enhanceARIALabels()
    
    // Setup landmark roles
    this.setupLandmarkRoles()
    
    // Monitor DOM changes for screen reader updates
    this.setupMutationObserver()
  }

  setupARIALiveRegions() {
    // Create polite live region
    if (!this.hasLiveRegionTarget) {
      this.createLiveRegion("polite")
    }
    
    // Create assertive live region for urgent announcements
    if (!this.hasAnnouncementsTarget) {
      this.createLiveRegion("assertive")
    }
  }

  createLiveRegion(level = "polite") {
    const liveRegion = document.createElement("div")
    liveRegion.setAttribute("aria-live", level)
    liveRegion.setAttribute("aria-atomic", "true")
    liveRegion.className = "sr-only live-region"
    liveRegion.id = `live-region-${level}`
    
    document.body.appendChild(liveRegion)
    
    return liveRegion
  }

  ensureLiveRegions() {
    if (!document.getElementById("live-region-polite")) {
      this.createLiveRegion("polite")
    }
    
    if (!document.getElementById("live-region-assertive")) {
      this.createLiveRegion("assertive")
    }
  }

  announce(message, level = "polite", delay = 100) {
    if (!message) {return}
    
    // Add to queue to prevent overwhelming screen readers
    this.announcementQueue.push({ message, level, delay })
    
    if (!this.isAnnouncing) {
      this.processAnnouncementQueue()
    }
  }

  processAnnouncementQueue() {
    if (this.announcementQueue.length === 0) {
      this.isAnnouncing = false
      return
    }
    
    this.isAnnouncing = true
    const { message, level, delay } = this.announcementQueue.shift()
    
    setTimeout(() => {
      this.makeAnnouncement(message, level)
      setTimeout(() => this.processAnnouncementQueue(), delay)
    }, 50)
  }

  makeAnnouncement(message, level = "polite") {
    const targetId = `live-region-${level}`
    const liveRegion = document.getElementById(targetId) || 
                      this.liveRegionTarget || 
                      this.createLiveRegion(level)
    
    if (liveRegion) {
      // Clear and set new message
      liveRegion.textContent = ""
      setTimeout(() => {
        liveRegion.textContent = message
      }, 10)
      
      // Clear after announcement
      setTimeout(() => {
        liveRegion.textContent = ""
      }, 5000)
    }
  }

  announceElementInfo(element) {
    if (!element) {return}
    
    const info = this.getElementDescription(element)
    if (info) {
      this.announce(info, "polite", 50)
    }
  }

  getElementDescription(element) {
    const tagName = element.tagName.toLowerCase()
    const role = element.getAttribute("role")
    const ariaLabel = element.getAttribute("aria-label")
    const ariaLabelledby = element.getAttribute("aria-labelledby")
    const title = element.getAttribute("title")
    const alt = element.getAttribute("alt")
    
    let description = ""
    
    // Get element name
    if (ariaLabel) {
      description += ariaLabel
    } else if (ariaLabelledby) {
      const labelElement = document.getElementById(ariaLabelledby)
      if (labelElement) {
        description += labelElement.textContent.trim()
      }
    } else if (alt) {
      description += alt
    } else if (title) {
      description += title
    } else if (element.textContent && element.textContent.trim()) {
      description += element.textContent.trim().substring(0, 100)
    }
    
    // Add role information
    if (role) {
      description += `, ${role}`
    } else {
      const roleFromTag = this.getImplicitRole(tagName)
      if (roleFromTag) {
        description += `, ${roleFromTag}`
      }
    }
    
    // Add state information
    const states = this.getElementStates(element)
    if (states.length > 0) {
      description += `, ${states.join(", ")}`
    }
    
    // Add position information for lists and grids
    const position = this.getElementPosition(element)
    if (position) {
      description += `, ${position}`
    }
    
    return description.trim()
  }

  getImplicitRole(tagName) {
    const roles = {
      "button": "button",
      "a": "link",
      "input": "textbox",
      "textarea": "textbox",
      "select": "combobox",
      "h1": "heading level 1",
      "h2": "heading level 2",
      "h3": "heading level 3",
      "h4": "heading level 4",
      "h5": "heading level 5",
      "h6": "heading level 6",
      "nav": "navigation",
      "main": "main",
      "aside": "complementary",
      "header": "banner",
      "footer": "contentinfo"
    }
    
    return roles[tagName]
  }

  getElementStates(element) {
    const states = []
    
    if (element.getAttribute("aria-expanded") === "true") {states.push("expanded")}
    if (element.getAttribute("aria-expanded") === "false") {states.push("collapsed")}
    if (element.getAttribute("aria-checked") === "true") {states.push("checked")}
    if (element.getAttribute("aria-checked") === "false") {states.push("not checked")}
    if (element.getAttribute("aria-selected") === "true") {states.push("selected")}
    if (element.hasAttribute("disabled")) {states.push("disabled")}
    if (element.hasAttribute("required")) {states.push("required")}
    if (element.getAttribute("aria-invalid") === "true") {states.push("invalid")}
    
    return states
  }

  getElementPosition(element) {
    // Get position in lists
    const listItem = element.closest("li")
    if (listItem) {
      const list = listItem.closest("ul, ol")
      if (list) {
        const items = Array.from(list.children)
        const index = items.indexOf(listItem) + 1
        return `${index} of ${items.length}`
      }
    }
    
    // Get position in grids
    const gridCell = element.closest("[role='gridcell']")
    if (gridCell) {
      const grid = gridCell.closest("[role='grid']")
      if (grid) {
        const gridRect = this.getGridDimensions(grid)
        const cells = Array.from(grid.querySelectorAll("[role='gridcell']"))
        const index = cells.indexOf(gridCell)
        const row = Math.floor(index / gridRect.cols) + 1
        const col = (index % gridRect.cols) + 1
        return `row ${row}, column ${col}`
      }
    }
    
    return null
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  getFocusableElements(container = document) {
    const focusableSelectors = [
      'a[href]',
      'button:not([disabled])',
      'input:not([disabled])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"])',
      '[role="button"]:not([disabled])',
      '[role="link"]',
      '[role="menuitem"]',
      '[role="option"]',
      '[role="tab"]'
    ].join(", ")
    
    return Array.from(container.querySelectorAll(focusableSelectors))
      .filter(el => this.isElementVisible(el) && !el.hasAttribute("disabled"))
  }

  isElementVisible(element) {
    if (!element) {return false}
    
    const style = window.getComputedStyle(element)
    return style.display !== "none" && 
           style.visibility !== "hidden" && 
           style.opacity !== "0" &&
           element.offsetWidth > 0 && 
           element.offsetHeight > 0
  }

  ensureElementVisible(element) {
    if (!element) {return}
    
    const rect = element.getBoundingClientRect()
    const isVisible = rect.top >= 0 && 
                     rect.left >= 0 && 
                     rect.bottom <= window.innerHeight && 
                     rect.right <= window.innerWidth
    
    if (!isVisible) {
      element.scrollIntoView({
        behavior: "smooth",
        block: "nearest",
        inline: "nearest"
      })
    }
  }

  getGridDimensions(grid) {
    const rows = grid.querySelectorAll("[role='row']")
    if (rows.length > 0) {
      const firstRow = rows[0]
      const cells = firstRow.querySelectorAll("[role='gridcell'], [role='columnheader']")
      return { rows: rows.length, cols: cells.length }
    }
    
    // Fallback: count all cells and estimate
    const allCells = grid.querySelectorAll("[role='gridcell']")
    const estimatedCols = Math.ceil(Math.sqrt(allCells.length))
    return { rows: Math.ceil(allCells.length / estimatedCols), cols: estimatedCols }
  }

  setupLandmarkRoles() {
    // Ensure proper landmark roles are set
    const main = document.querySelector("main")
    if (main && !main.getAttribute("role")) {
      main.setAttribute("role", "main")
    }
    
    const nav = document.querySelector("nav")
    if (nav && !nav.getAttribute("role")) {
      nav.setAttribute("role", "navigation")
    }
    
    const header = document.querySelector("header")
    if (header && !header.getAttribute("role")) {
      header.setAttribute("role", "banner")
    }
    
    const footer = document.querySelector("footer")
    if (footer && !footer.getAttribute("role")) {
      footer.setAttribute("role", "contentinfo")
    }
  }

  enhanceARIALabels() {
    // Auto-generate aria-labels for common elements
    const buttons = document.querySelectorAll("button:not([aria-label]):not([aria-labelledby])")
    buttons.forEach(button => {
      if (!button.textContent.trim()) {
        const icon = button.querySelector("svg, i, .icon")
        if (icon) {
          button.setAttribute("aria-label", "Button")
        }
      }
    })
    
    // Enhance form labels
    const inputs = document.querySelectorAll("input:not([aria-label]):not([aria-labelledby])")
    inputs.forEach(input => {
      const label = document.querySelector(`label[for="${input.id}"]`)
      if (label && input.id) {
        input.setAttribute("aria-labelledby", label.id || `label-${input.id}`)
        if (!label.id) {
          label.id = `label-${input.id}`
        }
      }
    })
  }

  setupMutationObserver() {
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === "childList") {
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              this.enhanceNewElement(node)
            }
          })
        }
      })
    })
    
    observer.observe(document.body, {
      childList: true,
      subtree: true
    })
    
    this.mutationObserver = observer
  }

  enhanceNewElement(element) {
    // Enhance newly added elements with accessibility features
    if (element.matches && element.matches("button:not([aria-label]):not([aria-labelledby])")) {
      if (!element.textContent.trim()) {
        element.setAttribute("aria-label", "Button")
      }
    }
    
    // Add focus management for new interactive elements
    if (element.matches && element.matches("input, button, select, textarea, [tabindex]")) {
      element.addEventListener("focus", (e) => this.handleFocusIn(e))
      element.addEventListener("blur", (e) => this.handleFocusOut(e))
    }
  }

  // ==========================================================================
  // ACCESSIBILITY PREFERENCES
  // ==========================================================================

  setupAccessibilityPreferences() {
    // Detect and apply user preferences
    this.detectMotionPreference()
    this.detectContrastPreference()
    this.detectFontSizePreference()
  }

  detectMotionPreference() {
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
    
    const handleMotionChange = (e) => {
      document.documentElement.classList.toggle("reduced-motion", e.matches)
      
      if (e.matches) {
        this.announce("Reduced motion enabled")
      }
    }
    
    handleMotionChange(prefersReducedMotion)
    prefersReducedMotion.addEventListener("change", handleMotionChange)
  }

  detectContrastPreference() {
    const prefersHighContrast = window.matchMedia("(prefers-contrast: high)")
    
    const handleContrastChange = (e) => {
      document.documentElement.classList.toggle("high-contrast", e.matches)
      
      if (e.matches) {
        this.announce("High contrast mode enabled")
      }
    }
    
    handleContrastChange(prefersHighContrast)
    prefersHighContrast.addEventListener("change", handleContrastChange)
  }

  detectFontSizePreference() {
    // This is a hypothetical media query - browsers may implement this in the future
    if (window.matchMedia) {
      const prefersLargeText = window.matchMedia("(prefers-font-size: large)")
      
      const handleFontSizeChange = (e) => {
        document.documentElement.classList.toggle("large-text", e.matches)
        
        if (e.matches) {
          this.announce("Large text preference detected")
        }
      }
      
      if (prefersLargeText.matches !== undefined) {
        handleFontSizeChange(prefersLargeText)
        prefersLargeText.addEventListener("change", handleFontSizeChange)
      }
    }
  }

  // ==========================================================================
  // PAGE NAVIGATION HELPERS
  // ==========================================================================

  focusMainContent() {
    const main = this.hasMainContentTarget ? 
                 this.mainContentTarget : 
                 document.querySelector("main, #main, [role='main']")
    
    if (main) {
      main.focus()
      main.scrollIntoView({ behavior: "smooth", block: "start" })
      this.announce("Focused main content")
    }
  }

  focusNavigation() {
    const nav = this.hasNavigationTarget ? 
                this.navigationTarget : 
                document.querySelector("nav, [role='navigation']")
    
    if (nav) {
      const firstLink = nav.querySelector("a, button, [tabindex='0']")
      if (firstLink) {
        firstLink.focus()
        this.announce("Focused navigation")
      }
    }
  }

  focusSearch() {
    const search = this.hasSearchTarget ? 
                   this.searchTarget : 
                   document.querySelector("[role='search'] input, input[type='search'], #search")
    
    if (search) {
      search.focus()
      this.announce("Focused search")
    }
  }

  showKeyboardHelp() {
    const helpModal = document.getElementById("keyboard-help-modal")
    if (helpModal) {
      // Show existing help modal
      helpModal.style.display = "block"
      this.trapFocus(helpModal)
    } else {
      // Create and show help modal
      this.createKeyboardHelpModal()
    }
  }

  createKeyboardHelpModal() {
    const modal = document.createElement("div")
    modal.id = "keyboard-help-modal"
    modal.className = "modal-overlay modal-open"
    modal.setAttribute("role", "dialog")
    modal.setAttribute("aria-labelledby", "keyboard-help-title")
    modal.innerHTML = `
      <div class="modal modal-md">
        <div class="modal-header">
          <h2 id="keyboard-help-title" class="modal-title">Keyboard Shortcuts</h2>
          <button type="button" class="modal-close" aria-label="Close keyboard help">×</button>
        </div>
        <div class="modal-body">
          <dl class="space-y-2">
            <dt class="font-medium">Alt + 1</dt>
            <dd class="text-sm text-gray-600">Focus main content</dd>
            <dt class="font-medium">Alt + 2</dt>
            <dd class="text-sm text-gray-600">Focus navigation</dd>
            <dt class="font-medium">Alt + 3 or Alt + S</dt>
            <dd class="text-sm text-gray-600">Focus search</dd>
            <dt class="font-medium">Escape</dt>
            <dd class="text-sm text-gray-600">Close modals and dropdowns</dd>
            <dt class="font-medium">Tab / Shift + Tab</dt>
            <dd class="text-sm text-gray-600">Navigate between elements</dd>
            <dt class="font-medium">Arrow Keys</dt>
            <dd class="text-sm text-gray-600">Navigate within menus and grids</dd>
            <dt class="font-medium">Enter or Space</dt>
            <dd class="text-sm text-gray-600">Activate buttons and links</dd>
          </dl>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    
    // Add event listeners
    const closeBtn = modal.querySelector(".modal-close")
    closeBtn.addEventListener("click", () => this.closeKeyboardHelp())
    
    modal.addEventListener("click", (e) => {
      if (e.target === modal) {
        this.closeKeyboardHelp()
      }
    })
    
    this.trapFocus(modal)
    this.announce("Keyboard help opened")
  }

  closeKeyboardHelp() {
    const modal = document.getElementById("keyboard-help-modal")
    if (modal) {
      modal.remove()
      this.releaseFocusTrap()
    }
  }

  // ==========================================================================
  // OVERLAY MANAGEMENT
  // ==========================================================================

  closeOverlays() {
    // Close all open overlays
    const overlays = document.querySelectorAll(".modal-open, .dropdown-open, [aria-expanded='true']")
    overlays.forEach(overlay => {
      if (overlay.classList.contains("modal-open")) {
        overlay.classList.remove("modal-open")
      }
      if (overlay.classList.contains("dropdown-open")) {
        overlay.classList.remove("dropdown-open")
      }
      if (overlay.getAttribute("aria-expanded") === "true") {
        overlay.setAttribute("aria-expanded", "false")
      }
    })
  }

  returnFocusToTrigger() {
    if (this.lastFocusedElement && this.isElementVisible(this.lastFocusedElement)) {
      this.lastFocusedElement.focus()
    }
  }

  // ==========================================================================
  // EVENT CLEANUP
  // ==========================================================================

  bindEventListeners() {
    // Store bound methods for cleanup
    this.boundHandleGlobalKeyDown = this.handleGlobalKeyDown.bind(this)
    this.boundHandleGlobalKeyUp = this.handleGlobalKeyUp.bind(this)
    this.boundHandleFocusIn = this.handleFocusIn.bind(this)
    this.boundHandleFocusOut = this.handleFocusOut.bind(this)
  }

  cleanupEventListeners() {
    if (this.boundHandleGlobalKeyDown) {
      document.removeEventListener("keydown", this.boundHandleGlobalKeyDown)
    }
    if (this.boundHandleGlobalKeyUp) {
      document.removeEventListener("keyup", this.boundHandleGlobalKeyUp)
    }
    if (this.boundHandleFocusIn) {
      document.removeEventListener("focusin", this.boundHandleFocusIn)
    }
    if (this.boundHandleFocusOut) {
      document.removeEventListener("focusout", this.boundHandleFocusOut)
    }
    
    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
    }
  }

  // ==========================================================================
  // PUBLIC API METHODS
  // ==========================================================================

  announcePageLoad() {
    if (this.announcePageChangesValue) {
      const title = document.title
      const main = document.querySelector("main, [role='main']")
      const headingLevel1 = document.querySelector("h1")
      
      let announcement = `Page loaded: ${title}`
      
      if (headingLevel1) {
        announcement += `. Main heading: ${headingLevel1.textContent.trim()}`
      }
      
      this.announce(announcement, "polite", 1000)
    }
  }

  announcePageChange(newTitle, newHeading) {
    if (this.announcePageChangesValue) {
      let announcement = `Page changed: ${newTitle}`
      if (newHeading) {
        announcement += `. Main heading: ${newHeading}`
      }
      this.announce(announcement, "assertive", 500)
    }
  }

  announceFormError(message) {
    this.announce(`Form error: ${message}`, "assertive")
  }

  announceFormSuccess(message) {
    this.announce(`Success: ${message}`, "polite")
  }

  announceKeyboardShortcuts(event) {
    // Announce available shortcuts in current context
    if (event.key === "?" && !event.ctrlKey && !event.altKey) {
      this.announce("Press Alt + H for keyboard shortcuts", "polite")
    }
  }
}