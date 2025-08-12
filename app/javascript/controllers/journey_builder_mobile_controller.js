import { Controller } from "@hotwired/stimulus"

// Journey Builder Mobile Controller for touch-optimized interactions
export default class extends Controller {
  static targets = [
    "mobileHeader", "mobileTabs", "mobileContent", "stageLibraryPanel", "canvasPanel", 
    "configPanel", "mobileStageTemplate", "mobileStageCard", "quickActions", 
    "bottomSheet", "fullscreenModal", "swipeIndicator", "notification"
  ]

  static values = {
    currentPanel: { type: String, default: "canvas" },
    isTablet: { type: Boolean, default: false },
    isMobile: { type: Boolean, default: false },
    touchStartX: { type: Number, default: 0 },
    touchStartY: { type: Number, default: 0 },
    swipeThreshold: { type: Number, default: 100 },
    longPressDelay: { type: Number, default: 500 }
  }

  static classes = [
    "active", "show", "hidden", "selected", "dragging", "dropping"
  ]

  connect() {
    this.initializeResponsiveLayout()
    this.setupTouchGestures()
    this.setupResizeObserver()
    this.initializeMobileTabs()
    this.setupKeyboardHandlers()
    this.setupAccessibility()
  }

  disconnect() {
    this.cleanup()
  }

  // Initialize responsive layout based on screen size
  initializeResponsiveLayout() {
    this.checkScreenSize()
    this.adaptLayoutForDevice()
    this.setupOrientationChange()
  }

  // Check current screen size and set device type
  checkScreenSize() {
    const width = window.innerWidth
    
    if (width <= 640) {
      this.isMobileValue = true
      this.isTabletValue = false
    } else if (width <= 1024) {
      this.isMobileValue = false
      this.isTabletValue = true
    } else {
      this.isMobileValue = false
      this.isTabletValue = false
    }
  }

  // Adapt layout based on device type
  adaptLayoutForDevice() {
    if (this.isMobileValue) {
      this.enableMobileLayout()
    } else if (this.isTabletValue) {
      this.enableTabletLayout()
    } else {
      this.enableDesktopLayout()
    }
  }

  // Enable mobile-specific layout
  enableMobileLayout() {
    document.body.classList.add('mobile-layout')
    document.body.classList.remove('tablet-layout', 'desktop-layout')
    
    // Show mobile tabs
    if (this.hasMobileTabsTarget) {
      this.mobileTabsTarget.classList.remove('hidden')
    }
    
    // Initialize mobile panels
    this.initializeMobilePanels()
    
    // Show current panel
    this.showPanel(this.currentPanelValue)
  }

  // Enable tablet-specific layout  
  enableTabletLayout() {
    document.body.classList.add('tablet-layout')
    document.body.classList.remove('mobile-layout', 'desktop-layout')
    
    // Hide mobile tabs on tablet
    if (this.hasMobileTabsTarget) {
      this.mobileTabsTarget.classList.add('hidden')
    }
  }

  // Enable desktop layout
  enableDesktopLayout() {
    document.body.classList.add('desktop-layout')
    document.body.classList.remove('mobile-layout', 'tablet-layout')
    
    // Hide mobile tabs on desktop
    if (this.hasMobileTabsTarget) {
      this.mobileTabsTarget.classList.add('hidden')
    }
  }

  // Initialize mobile tab system
  initializeMobileTabs() {
    if (!this.hasMobileTabsTarget) return
    
    const tabs = [
      { id: 'stages', label: 'Stages', icon: '🎯' },
      { id: 'canvas', label: 'Journey', icon: '🗺️' },
      { id: 'config', label: 'Config', icon: '⚙️' }
    ]
    
    const tabsHTML = tabs.map(tab => `
      <button type="button" 
              class="mobile-tab ${tab.id === this.currentPanelValue ? 'active' : ''}"
              data-action="click->journey-builder-mobile#switchPanel"
              data-panel="${tab.id}">
        <span class="tab-icon">${tab.icon}</span>
        <span class="tab-label">${tab.label}</span>
      </button>
    `).join('')
    
    this.mobileTabsTarget.innerHTML = tabsHTML
  }

  // Initialize mobile panels
  initializeMobilePanels() {
    const panels = ['stageLibraryPanel', 'canvasPanel', 'configPanel']
    
    panels.forEach(panelName => {
      const target = `${panelName}Target`
      if (this[`has${panelName.charAt(0).toUpperCase() + panelName.slice(1)}`]) {
        const panel = this[target]
        panel.classList.add('mobile-panel')
        
        if (panelName.includes(this.currentPanelValue)) {
          panel.classList.add('active')
        }
      }
    })
  }

  // Setup touch gesture recognition
  setupTouchGestures() {
    this.element.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
    this.element.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
    this.element.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false })
    
    // Setup long press detection
    this.longPressTimer = null
    this.isLongPress = false
  }

  // Handle touch start events
  handleTouchStart(event) {
    if (!this.isMobileValue) return
    
    this.touchStartX = event.touches[0].clientX
    this.touchStartY = event.touches[0].clientY
    this.touchStartTime = Date.now()
    this.isLongPress = false
    
    // Start long press timer
    this.longPressTimer = setTimeout(() => {
      this.handleLongPress(event)
    }, this.longPressDelayValue)
    
    // Handle stage selection
    const stageCard = event.target.closest('[data-journey-builder-mobile-target="mobileStageCard"]')
    if (stageCard) {
      this.handleStageTouch(stageCard, event)
    }
  }

  // Handle touch move events
  handleTouchMove(event) {
    if (!this.isMobileValue) return
    
    const deltaX = event.touches[0].clientX - this.touchStartX
    const deltaY = event.touches[0].clientY - this.touchStartY
    
    // Cancel long press if finger moves too much
    if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
      this.cancelLongPress()
    }
    
    // Handle swipe gestures
    this.handleSwipeGesture(deltaX, deltaY, event)
  }

  // Handle touch end events
  handleTouchEnd(event) {
    if (!this.isMobileValue) return
    
    this.cancelLongPress()
    
    const deltaX = event.changedTouches[0].clientX - this.touchStartX
    const deltaY = event.changedTouches[0].clientY - this.touchStartY
    const deltaTime = Date.now() - this.touchStartTime
    
    // Detect swipe gestures
    if (Math.abs(deltaX) > this.swipeThresholdValue && deltaTime < 300) {
      this.handleSwipe(deltaX > 0 ? 'right' : 'left')
    }
    
    // Detect tap gestures
    if (Math.abs(deltaX) < 10 && Math.abs(deltaY) < 10 && deltaTime < 300 && !this.isLongPress) {
      this.handleTap(event)
    }
  }

  // Handle long press gestures
  handleLongPress(event) {
    this.isLongPress = true
    const stageCard = event.target.closest('[data-journey-builder-mobile-target="mobileStageCard"]')
    
    if (stageCard) {
      this.showStageContextMenu(stageCard, event)
    }
    
    // Provide haptic feedback if available
    if (navigator.vibrate) {
      navigator.vibrate(50)
    }
  }

  // Cancel long press detection
  cancelLongPress() {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer)
      this.longPressTimer = null
    }
  }

  // Handle tap gestures
  handleTap(event) {
    const stageTemplate = event.target.closest('[data-journey-builder-mobile-target="mobileStageTemplate"]')
    const stageCard = event.target.closest('[data-journey-builder-mobile-target="mobileStageCard"]')
    
    if (stageTemplate) {
      this.addStageFromTemplate(stageTemplate)
    } else if (stageCard) {
      this.selectStage(stageCard)
    }
  }

  // Handle swipe gestures
  handleSwipe(direction) {
    if (direction === 'left') {
      // Swipe left - next panel
      this.switchToNextPanel()
    } else if (direction === 'right') {
      // Swipe right - previous panel  
      this.switchToPreviousPanel()
    }
    
    this.showSwipeIndicator(direction)
  }

  // Handle continuous swipe gestures during move
  handleSwipeGesture(deltaX, deltaY, event) {
    // Show swipe indicators
    if (Math.abs(deltaX) > 50) {
      const direction = deltaX > 0 ? 'right' : 'left'
      this.showSwipeIndicator(direction)
    }
  }

  // Show swipe direction indicator
  showSwipeIndicator(direction) {
    if (!this.hasSwipeIndicatorTarget) return
    
    const indicator = this.swipeIndicatorTarget
    indicator.classList.add('show', direction)
    
    setTimeout(() => {
      indicator.classList.remove('show', direction)
    }, 300)
  }

  // Switch between mobile panels
  switchPanel(event) {
    const panel = event.currentTarget.dataset.panel
    this.showPanel(panel)
  }

  // Show specific panel
  showPanel(panelName) {
    this.currentPanelValue = panelName
    
    // Update tab states
    this.updateTabStates(panelName)
    
    // Update panel visibility
    this.updatePanelVisibility(panelName)
    
    // Dispatch panel change event
    this.dispatchPanelChangeEvent(panelName)
  }

  // Update tab active states
  updateTabStates(activePanel) {
    if (!this.hasMobileTabsTarget) return
    
    const tabs = this.mobileTabsTarget.querySelectorAll('.mobile-tab')
    tabs.forEach(tab => {
      if (tab.dataset.panel === activePanel) {
        tab.classList.add('active')
      } else {
        tab.classList.remove('active')
      }
    })
  }

  // Update panel visibility
  updatePanelVisibility(activePanel) {
    const panelMap = {
      'stages': 'stageLibraryPanel',
      'canvas': 'canvasPanel', 
      'config': 'configPanel'
    }
    
    Object.entries(panelMap).forEach(([panelId, targetName]) => {
      const target = `${targetName}Target`
      if (this[`has${targetName.charAt(0).toUpperCase() + targetName.slice(1)}`]) {
        const panel = this[target]
        if (panelId === activePanel) {
          panel.classList.add('active')
        } else {
          panel.classList.remove('active')
        }
      }
    })
  }

  // Switch to next panel in sequence
  switchToNextPanel() {
    const panels = ['stages', 'canvas', 'config']
    const currentIndex = panels.indexOf(this.currentPanelValue)
    const nextIndex = (currentIndex + 1) % panels.length
    this.showPanel(panels[nextIndex])
  }

  // Switch to previous panel in sequence
  switchToPreviousPanel() {
    const panels = ['stages', 'canvas', 'config']
    const currentIndex = panels.indexOf(this.currentPanelValue)
    const prevIndex = currentIndex === 0 ? panels.length - 1 : currentIndex - 1
    this.showPanel(panels[prevIndex])
  }

  // Add stage from template with mobile-optimized interaction
  addStageFromTemplate(templateElement) {
    const stageType = templateElement.dataset.stageType
    
    // Add visual feedback
    templateElement.classList.add('adding')
    
    // Dispatch stage add event to main journey builder
    this.dispatchStageEvent('journey:addStageFromMobile', {
      stageType: stageType,
      source: 'mobile'
    })
    
    // Remove visual feedback after animation
    setTimeout(() => {
      templateElement.classList.remove('adding')
    }, 300)
    
    // Auto-switch to canvas to show the new stage
    if (this.isMobileValue) {
      setTimeout(() => {
        this.showPanel('canvas')
      }, 500)
    }
    
    // Show success notification
    this.showMobileNotification('Stage added to journey!', 'success')
  }

  // Select stage with mobile-optimized interaction
  selectStage(stageCard) {
    // Remove selection from other stages
    this.mobileStageCardTargets.forEach(card => {
      card.classList.remove('selected')
    })
    
    // Select current stage
    stageCard.classList.add('selected')
    
    // Get stage data
    const stageId = stageCard.dataset.stageId
    const stageData = this.getStageData(stageId)
    
    // Dispatch selection event
    this.dispatchStageEvent('journey:stageSelected', {
      stageId: stageId,
      stageData: stageData,
      source: 'mobile'
    })
    
    // Show configuration panel on mobile
    if (this.isMobileValue) {
      this.showPanel('config')
    } else {
      // On tablet/desktop, show config panel
      this.showConfigPanel(stageData)
    }
  }

  // Show stage context menu for long press
  showStageContextMenu(stageCard, event) {
    const stageId = stageCard.dataset.stageId
    
    const menuOptions = [
      { label: 'Edit Stage', action: 'edit', icon: '✏️' },
      { label: 'Duplicate', action: 'duplicate', icon: '📄' },
      { label: 'Delete', action: 'delete', icon: '🗑️' }
    ]
    
    this.showBottomSheet('Stage Actions', menuOptions, (action) => {
      this.handleStageAction(stageId, action)
    })
  }

  // Handle stage actions from context menu
  handleStageAction(stageId, action) {
    switch (action) {
      case 'edit':
        this.editStage(stageId)
        break
      case 'duplicate':
        this.duplicateStage(stageId)
        break
      case 'delete':
        this.deleteStage(stageId)
        break
    }
  }

  // Show mobile bottom sheet
  showBottomSheet(title, options, callback) {
    if (!this.hasBottomSheetTarget) return
    
    const optionsHTML = options.map(option => `
      <button type="button" 
              class="w-full text-left px-4 py-3 hover:bg-gray-50 flex items-center space-x-3 border-b border-gray-100 last:border-b-0"
              data-action="${option.action}">
        <span class="text-xl">${option.icon}</span>
        <span class="flex-1">${option.label}</span>
      </button>
    `).join('')
    
    this.bottomSheetTarget.innerHTML = `
      <div class="sheet-handle"></div>
      <div class="sheet-header">
        <h3 class="text-lg font-semibold text-gray-900">${title}</h3>
      </div>
      <div class="sheet-content">
        <div class="space-y-0">
          ${optionsHTML}
        </div>
      </div>
    `
    
    // Add event listeners
    const buttons = this.bottomSheetTarget.querySelectorAll('button[data-action]')
    buttons.forEach(button => {
      button.addEventListener('click', () => {
        const action = button.dataset.action
        callback(action)
        this.hideBottomSheet()
      })
    })
    
    this.bottomSheetTarget.classList.add('show')
  }

  // Hide bottom sheet
  hideBottomSheet() {
    if (this.hasBottomSheetTarget) {
      this.bottomSheetTarget.classList.remove('show')
    }
  }

  // Show fullscreen modal for stage configuration
  showFullscreenModal(title, content) {
    if (!this.hasFullscreenModalTarget) return
    
    this.fullscreenModalTarget.innerHTML = `
      <div class="modal-header">
        <button type="button" class="modal-back" data-action="click->journey-builder-mobile#hideFullscreenModal">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
          </svg>
        </button>
        <h1 class="modal-title">${title}</h1>
        <button type="button" class="modal-action" data-action="click->journey-builder-mobile#saveModalConfig">
          Save
        </button>
      </div>
      <div class="modal-content">
        ${content}
      </div>
    `
    
    this.fullscreenModalTarget.classList.add('show')
  }

  // Hide fullscreen modal
  hideFullscreenModal() {
    if (this.hasFullscreenModalTarget) {
      this.fullscreenModalTarget.classList.remove('show')
    }
  }

  // Show mobile notification
  showMobileNotification(message, type = 'info') {
    if (!this.hasNotificationTarget) return
    
    const icons = {
      success: '✅',
      error: '❌', 
      warning: '⚠️',
      info: 'ℹ️'
    }
    
    this.notificationTarget.innerHTML = `
      <div class="flex items-center space-x-3">
        <span class="text-xl">${icons[type] || icons.info}</span>
        <span class="flex-1 text-sm font-medium text-gray-900">${message}</span>
      </div>
    `
    
    this.notificationTarget.classList.add('show', type)
    
    // Auto-hide after 3 seconds
    setTimeout(() => {
      this.notificationTarget.classList.remove('show', type)
    }, 3000)
  }

  // Setup resize observer for responsive behavior
  setupResizeObserver() {
    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver(entries => {
        this.handleResize()
      })
      
      this.resizeObserver.observe(this.element)
    } else {
      // Fallback for older browsers
      window.addEventListener('resize', this.handleResize.bind(this))
    }
  }

  // Handle window resize
  handleResize() {
    this.checkScreenSize()
    this.adaptLayoutForDevice()
  }

  // Setup orientation change handling
  setupOrientationChange() {
    window.addEventListener('orientationchange', () => {
      // Delay to allow orientation change to complete
      setTimeout(() => {
        this.handleResize()
      }, 100)
    })
  }

  // Setup keyboard shortcuts for mobile
  setupKeyboardHandlers() {
    document.addEventListener('keydown', (event) => {
      if (this.isMobileValue && event.key === 'Escape') {
        this.hideBottomSheet()
        this.hideFullscreenModal()
      }
    })
  }

  // Setup accessibility features
  setupAccessibility() {
    // Add ARIA labels
    if (this.hasMobileTabsTarget) {
      this.mobileTabsTarget.setAttribute('role', 'tablist')
      this.mobileTabsTarget.setAttribute('aria-label', 'Journey builder sections')
    }
    
    // Add focus management
    this.setupFocusManagement()
  }

  // Setup focus management for accessibility
  setupFocusManagement() {
    // Focus trap for modals
    this.element.addEventListener('keydown', (event) => {
      if (event.key === 'Tab') {
        this.handleTabNavigation(event)
      }
    })
  }

  // Handle tab navigation in modals
  handleTabNavigation(event) {
    const modal = this.element.querySelector('.mobile-fullscreen-modal.show, .mobile-bottom-sheet.show')
    if (modal) {
      const focusableElements = modal.querySelectorAll(
        'button, input, select, textarea, [href], [tabindex]:not([tabindex="-1"])'
      )
      
      if (focusableElements.length > 0) {
        const firstElement = focusableElements[0]
        const lastElement = focusableElements[focusableElements.length - 1]
        
        if (event.shiftKey && document.activeElement === firstElement) {
          event.preventDefault()
          lastElement.focus()
        } else if (!event.shiftKey && document.activeElement === lastElement) {
          event.preventDefault()
          firstElement.focus()
        }
      }
    }
  }

  // Utility methods

  // Get stage data by ID
  getStageData(stageId) {
    // This would typically fetch from the journey builder controller
    return {
      id: stageId,
      name: `Stage ${stageId}`,
      type: 'awareness'
    }
  }

  // Dispatch stage-related events
  dispatchStageEvent(eventName, detail) {
    const event = new CustomEvent(eventName, { 
      detail: detail,
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  // Dispatch panel change events
  dispatchPanelChangeEvent(panel) {
    this.dispatchStageEvent('journey:panelChanged', { 
      panel: panel,
      device: this.isMobileValue ? 'mobile' : 'tablet'
    })
  }

  // Performance optimization methods
  
  // Throttle function for performance
  throttle(func, limit) {
    let inThrottle
    return function() {
      const args = arguments
      const context = this
      if (!inThrottle) {
        func.apply(context, args)
        inThrottle = true
        setTimeout(() => inThrottle = false, limit)
      }
    }
  }

  // Cleanup
  cleanup() {
    this.cancelLongPress()
    
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    
    // Remove event listeners
    window.removeEventListener('resize', this.handleResize)
    window.removeEventListener('orientationchange', this.handleResize)
  }
}