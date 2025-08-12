// Mobile Journey Builder Tests
// Test suite for mobile-responsive journey builder functionality

import { Application } from "@hotwired/stimulus"
import JourneyBuilderController from "../../app/javascript/controllers/journey_builder_controller.js"
import JourneyBuilderMobileController from "../../app/javascript/controllers/journey_builder_mobile_controller.js"
import MobileStageConfigController from "../../app/javascript/controllers/mobile_stage_config_controller.js"

// Mock mobile environment
const mockMobileEnvironment = () => {
  // Mock window dimensions for mobile
  Object.defineProperty(window, 'innerWidth', {
    writable: true,
    configurable: true,
    value: 375 // iPhone SE width
  })
  
  Object.defineProperty(window, 'innerHeight', {
    writable: true,
    configurable: true,
    value: 667 // iPhone SE height
  })
  
  // Mock touch support
  Object.defineProperty(window, 'ontouchstart', {
    writable: true,
    configurable: true,
    value: {}
  })
  
  // Mock user agent
  Object.defineProperty(navigator, 'userAgent', {
    writable: true,
    configurable: true,
    value: 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1'
  })
  
  // Mock device memory for low-end device detection
  Object.defineProperty(navigator, 'deviceMemory', {
    writable: true,
    configurable: true,
    value: 2 // 2GB RAM - considered low-end
  })
  
  // Mock hardware concurrency
  Object.defineProperty(navigator, 'hardwareConcurrency', {
    writable: true,
    configurable: true,
    value: 2 // 2 CPU cores
  })
}

// Mock tablet environment
const mockTabletEnvironment = () => {
  Object.defineProperty(window, 'innerWidth', {
    writable: true,
    configurable: true,
    value: 768 // iPad width
  })
  
  Object.defineProperty(window, 'innerHeight', {
    writable: true,
    configurable: true,
    value: 1024 // iPad height
  })
}

// Mock desktop environment
const mockDesktopEnvironment = () => {
  Object.defineProperty(window, 'innerWidth', {
    writable: true,
    configurable: true,
    value: 1920 // Desktop width
  })
  
  Object.defineProperty(window, 'innerHeight', {
    writable: true,
    configurable: true,
    value: 1080 // Desktop height
  })
}

// Test suite
describe('Mobile Journey Builder', () => {
  let application, container, mobileController, builderController
  
  beforeEach(() => {
    // Setup DOM container
    container = document.createElement('div')
    container.innerHTML = `
      <div class="journey-builder" 
           data-controller="journey-builder journey-builder-mobile"
           data-journey-builder-mobile-current-panel-value="canvas">
        
        <div class="mobile-tabs" data-journey-builder-mobile-target="mobileTabs"></div>
        
        <div class="main-content" data-journey-builder-mobile-target="mobileContent">
          <div class="stage-library-panel mobile-panel" data-journey-builder-mobile-target="stageLibraryPanel">
            <div class="mobile-stage-template" data-stage-type="awareness" data-journey-builder-mobile-target="mobileStageTemplate">
              <div>Awareness Stage</div>
            </div>
          </div>
          
          <div class="canvas-panel mobile-panel canvas" data-journey-builder-mobile-target="canvasPanel">
            <div class="journey-canvas" data-journey-builder-target="canvas"></div>
            <div class="journey-stages" data-journey-builder-target="stagesContainer"></div>
          </div>
          
          <div class="config-panel mobile-panel" data-journey-builder-mobile-target="configPanel">
            <div>Configuration Panel</div>
          </div>
        </div>
        
        <div class="mobile-quick-actions" data-journey-builder-mobile-target="quickActions"></div>
        <div class="mobile-bottom-sheet" data-journey-builder-mobile-target="bottomSheet"></div>
        <div class="mobile-fullscreen-modal" data-journey-builder-mobile-target="fullscreenModal"></div>
        <div class="swipe-indicator" data-journey-builder-mobile-target="swipeIndicator"></div>
        <div class="mobile-notification" data-journey-builder-mobile-target="notification"></div>
      </div>
    `
    document.body.appendChild(container)
    
    // Setup Stimulus application
    application = Application.start()
    application.register("journey-builder", JourneyBuilderController)
    application.register("journey-builder-mobile", JourneyBuilderMobileController)
  })
  
  afterEach(() => {
    application.stop()
    document.body.removeChild(container)
  })
  
  describe('Mobile Device Detection', () => {
    test('detects mobile device correctly', () => {
      mockMobileEnvironment()
      
      const controller = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
      
      expect(controller.isMobileValue).toBe(true)
      expect(controller.isTabletValue).toBe(false)
    })
    
    test('detects tablet device correctly', () => {
      mockTabletEnvironment()
      
      const controller = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
      
      expect(controller.isMobileValue).toBe(false)
      expect(controller.isTabletValue).toBe(true)
    })
    
    test('detects desktop device correctly', () => {
      mockDesktopEnvironment()
      
      const controller = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
      
      expect(controller.isMobileValue).toBe(false)
      expect(controller.isTabletValue).toBe(false)
    })
  })
  
  describe('Mobile Layout Adaptation', () => {
    beforeEach(() => {
      mockMobileEnvironment()
      mobileController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
    })
    
    test('enables mobile layout on mobile devices', () => {
      expect(document.body.classList.contains('mobile-layout')).toBe(true)
    })
    
    test('shows mobile tabs on mobile devices', () => {
      const mobileTabs = container.querySelector('[data-journey-builder-mobile-target="mobileTabs"]')
      expect(mobileTabs.classList.contains('hidden')).toBe(false)
    })
    
    test('initializes mobile panels correctly', () => {
      const panels = container.querySelectorAll('.mobile-panel')
      expect(panels.length).toBeGreaterThan(0)
      
      // Canvas panel should be active by default
      const canvasPanel = container.querySelector('[data-journey-builder-mobile-target="canvasPanel"]')
      expect(canvasPanel.classList.contains('active')).toBe(true)
    })
  })
  
  describe('Touch Gesture Support', () => {
    beforeEach(() => {
      mockMobileEnvironment()
      mobileController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
    })
    
    test('handles tap gestures on stage templates', () => {
      const stageTemplate = container.querySelector('[data-journey-builder-mobile-target="mobileStageTemplate"]')
      const addStageFromTemplateSpy = jest.spyOn(mobileController, 'addStageFromTemplate')
      
      // Simulate tap
      const touchEvent = new TouchEvent('touchend', {
        touches: [],
        changedTouches: [{ clientX: 100, clientY: 100 }]
      })
      
      mobileController.touchStartX = 100
      mobileController.touchStartY = 100
      mobileController.touchStartTime = Date.now()
      
      stageTemplate.dispatchEvent(touchEvent)
      
      expect(addStageFromTemplateSpy).toHaveBeenCalled()
    })
    
    test('handles swipe gestures for panel navigation', () => {
      const switchToNextPanelSpy = jest.spyOn(mobileController, 'switchToNextPanel')
      
      // Simulate left swipe
      mobileController.touchStartX = 200
      mobileController.touchStartTime = Date.now()
      
      const touchEndEvent = new TouchEvent('touchend', {
        touches: [],
        changedTouches: [{ clientX: 50, clientY: 100 }] // 150px left swipe
      })
      
      mobileController.handleTouchEnd(touchEndEvent)
      
      expect(switchToNextPanelSpy).toHaveBeenCalled()
    })
    
    test('handles long press gestures', (done) => {
      const showStageContextMenuSpy = jest.spyOn(mobileController, 'showStageContextMenu')
      const stageCard = document.createElement('div')
      stageCard.setAttribute('data-journey-builder-mobile-target', 'mobileStageCard')
      container.appendChild(stageCard)
      
      // Simulate long press
      const touchEvent = new TouchEvent('touchstart', {
        touches: [{ clientX: 100, clientY: 100 }]
      })
      
      mobileController.handleTouchStart(touchEvent)
      
      // Wait for long press timer
      setTimeout(() => {
        expect(showStageContextMenuSpy).toHaveBeenCalled()
        done()
      }, 550) // Slightly longer than longPressDelay
    })
  })
  
  describe('Panel Navigation', () => {
    beforeEach(() => {
      mockMobileEnvironment()
      mobileController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
    })
    
    test('switches between panels correctly', () => {
      mobileController.showPanel('stages')
      expect(mobileController.currentPanelValue).toBe('stages')
      
      const stageLibraryPanel = container.querySelector('[data-journey-builder-mobile-target="stageLibraryPanel"]')
      expect(stageLibraryPanel.classList.contains('active')).toBe(true)
      
      const canvasPanel = container.querySelector('[data-journey-builder-mobile-target="canvasPanel"]')
      expect(canvasPanel.classList.contains('active')).toBe(false)
    })
    
    test('updates tab states when switching panels', () => {
      // Initialize tabs first
      mobileController.initializeMobileTabs()
      
      mobileController.showPanel('config')
      
      const configTab = container.querySelector('[data-panel="config"]')
      const canvasTab = container.querySelector('[data-panel="canvas"]')
      
      expect(configTab.classList.contains('active')).toBe(true)
      expect(canvasTab.classList.contains('active')).toBe(false)
    })
  })
  
  describe('Stage Management', () => {
    beforeEach(() => {
      mockMobileEnvironment()
      mobileController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
      builderController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder'
      )
    })
    
    test('adds stage from mobile template', () => {
      const stageTemplate = container.querySelector('[data-journey-builder-mobile-target="mobileStageTemplate"]')
      const dispatchStageEventSpy = jest.spyOn(mobileController, 'dispatchStageEvent')
      
      mobileController.addStageFromTemplate(stageTemplate)
      
      expect(dispatchStageEventSpy).toHaveBeenCalledWith('journey:addStageFromMobile', {
        stageType: 'awareness',
        source: 'mobile'
      })
    })
    
    test('shows mobile notification after adding stage', () => {
      const showMobileNotificationSpy = jest.spyOn(mobileController, 'showMobileNotification')
      const stageTemplate = container.querySelector('[data-journey-builder-mobile-target="mobileStageTemplate"]')
      
      mobileController.addStageFromTemplate(stageTemplate)
      
      expect(showMobileNotificationSpy).toHaveBeenCalledWith('Stage added to journey!', 'success')
    })
  })
  
  describe('Modal and Bottom Sheet', () => {
    beforeEach(() => {
      mockMobileEnvironment()
      mobileController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
    })
    
    test('shows bottom sheet with menu options', () => {
      const bottomSheet = container.querySelector('[data-journey-builder-mobile-target="bottomSheet"]')
      const options = [
        { label: 'Edit', action: 'edit', icon: '✏️' },
        { label: 'Delete', action: 'delete', icon: '🗑️' }
      ]
      
      mobileController.showBottomSheet('Stage Options', options, () => {})
      
      expect(bottomSheet.classList.contains('show')).toBe(true)
      expect(bottomSheet.innerHTML).toContain('Edit')
      expect(bottomSheet.innerHTML).toContain('Delete')
    })
    
    test('hides bottom sheet', () => {
      const bottomSheet = container.querySelector('[data-journey-builder-mobile-target="bottomSheet"]')
      bottomSheet.classList.add('show')
      
      mobileController.hideBottomSheet()
      
      expect(bottomSheet.classList.contains('show')).toBe(false)
    })
    
    test('shows fullscreen modal', () => {
      const modal = container.querySelector('[data-journey-builder-mobile-target="fullscreenModal"]')
      
      mobileController.showFullscreenModal('Test Title', '<p>Test content</p>')
      
      expect(modal.classList.contains('show')).toBe(true)
      expect(modal.innerHTML).toContain('Test Title')
      expect(modal.innerHTML).toContain('Test content')
    })
  })
  
  describe('Performance Optimizations', () => {
    beforeEach(() => {
      mockMobileEnvironment()
      builderController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder'
      )
    })
    
    test('enables mobile optimizations on mobile devices', () => {
      expect(builderController.element.classList.contains('mobile-optimized')).toBe(true)
    })
    
    test('enables low-end device optimizations', () => {
      // Mock low-end device
      Object.defineProperty(navigator, 'deviceMemory', { value: 1 })
      Object.defineProperty(navigator, 'hardwareConcurrency', { value: 1 })
      
      builderController.enableMobileOptimizations()
      
      expect(builderController.element.classList.contains('low-end-device')).toBe(true)
    })
    
    test('optimizes touch targets', () => {
      const button = document.createElement('button')
      button.style.height = '30px' // Less than 44px minimum
      builderController.element.appendChild(button)
      
      builderController.optimizeForTouch()
      
      expect(button.style.minHeight).toBe('44px')
    })
  })
  
  describe('Responsive Layout Changes', () => {
    beforeEach(() => {
      builderController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder'
      )
    })
    
    test('adapts layout when switching from desktop to mobile', () => {
      // Start with desktop
      mockDesktopEnvironment()
      builderController.handleResize()
      
      expect(builderController.isMobile).toBe(false)
      expect(builderController.element.classList.contains('mobile-optimized')).toBe(false)
      
      // Switch to mobile
      mockMobileEnvironment()
      builderController.handleResize()
      
      expect(builderController.isMobile).toBe(true)
      expect(builderController.element.classList.contains('mobile-optimized')).toBe(true)
    })
    
    test('adapts layout when switching from mobile to desktop', () => {
      // Start with mobile
      mockMobileEnvironment()
      builderController.handleResize()
      
      expect(builderController.isMobile).toBe(true)
      
      // Switch to desktop
      mockDesktopEnvironment()
      builderController.handleResize()
      
      expect(builderController.isMobile).toBe(false)
      expect(builderController.element.classList.contains('mobile-optimized')).toBe(false)
    })
    
    test('updates canvas layout for mobile', () => {
      mockMobileEnvironment()
      const stagesContainer = container.querySelector('[data-journey-builder-target="stagesContainer"]')
      
      builderController.updateCanvasLayout()
      
      expect(stagesContainer.classList.contains('flex-col')).toBe(true)
      expect(stagesContainer.classList.contains('flex-row')).toBe(false)
    })
  })
  
  describe('Accessibility', () => {
    beforeEach(() => {
      mockMobileEnvironment()
      mobileController = application.getControllerForElementAndIdentifier(
        container.querySelector('[data-controller]'), 
        'journey-builder-mobile'
      )
    })
    
    test('adds proper ARIA labels to mobile tabs', () => {
      const mobileTabs = container.querySelector('[data-journey-builder-mobile-target="mobileTabs"]')
      
      expect(mobileTabs.getAttribute('role')).toBe('tablist')
      expect(mobileTabs.getAttribute('aria-label')).toBe('Journey builder sections')
    })
    
    test('handles keyboard navigation in modals', () => {
      const modal = container.querySelector('[data-journey-builder-mobile-target="fullscreenModal"]')
      modal.classList.add('show')
      modal.innerHTML = `
        <button>First</button>
        <button>Second</button>
        <button>Last</button>
      `
      
      const buttons = modal.querySelectorAll('button')
      buttons[2].focus() // Focus on last button
      
      // Simulate Tab key
      const tabEvent = new KeyboardEvent('keydown', { 
        key: 'Tab', 
        bubbles: true 
      })
      
      mobileController.element.dispatchEvent(tabEvent)
      
      // Should focus trap within modal
      expect(document.activeElement).toBe(buttons[0])
    })
  })
})

// Performance tests
describe('Mobile Performance', () => {
  test('detects low-end devices correctly', () => {
    // Mock low-end device characteristics
    Object.defineProperty(navigator, 'hardwareConcurrency', { value: 2 })
    Object.defineProperty(navigator, 'deviceMemory', { value: 2 })
    
    const { mobilePerformance } = require('../../app/javascript/utils/mobile_performance.js')
    
    expect(mobilePerformance.isLowEndDevice).toBe(true)
  })
  
  test('throttles expensive operations', (done) => {
    const { mobilePerformance } = require('../../app/javascript/utils/mobile_performance.js')
    
    let callCount = 0
    const throttledFunction = mobilePerformance.throttle(() => {
      callCount++
    }, 100)
    
    // Call function multiple times quickly
    throttledFunction()
    throttledFunction()
    throttledFunction()
    
    // Only first call should execute immediately
    expect(callCount).toBe(1)
    
    // After throttle delay, function should be callable again
    setTimeout(() => {
      throttledFunction()
      expect(callCount).toBe(2)
      done()
    }, 150)
  })
  
  test('debounces user input', (done) => {
    const { mobilePerformance } = require('../../app/javascript/utils/mobile_performance.js')
    
    let callCount = 0
    const debouncedFunction = mobilePerformance.debounce(() => {
      callCount++
    }, 100)
    
    // Call function multiple times quickly
    debouncedFunction()
    debouncedFunction()
    debouncedFunction()
    
    // No calls should execute immediately
    expect(callCount).toBe(0)
    
    // After debounce delay, only last call should execute
    setTimeout(() => {
      expect(callCount).toBe(1)
      done()
    }, 150)
  })
})

// Integration tests
describe('Mobile Journey Builder Integration', () => {
  test('complete mobile workflow: add stage, configure, save', (done) => {
    mockMobileEnvironment()
    
    const container = document.createElement('div')
    container.innerHTML = `
      <div class="journey-builder" 
           data-controller="journey-builder journey-builder-mobile mobile-stage-config">
        <!-- Mobile UI elements -->
      </div>
    `
    document.body.appendChild(container)
    
    const application = Application.start()
    application.register("journey-builder", JourneyBuilderController)
    application.register("journey-builder-mobile", JourneyBuilderMobileController)
    application.register("mobile-stage-config", MobileStageConfigController)
    
    // Simulate complete workflow
    const mobileController = application.getControllerForElementAndIdentifier(
      container.querySelector('[data-controller]'), 
      'journey-builder-mobile'
    )
    
    // 1. Add stage from template
    const stageTemplate = document.createElement('div')
    stageTemplate.setAttribute('data-stage-type', 'awareness')
    mobileController.addStageFromTemplate(stageTemplate)
    
    // 2. Switch to config panel
    setTimeout(() => {
      mobileController.showPanel('config')
      expect(mobileController.currentPanelValue).toBe('config')
      
      // 3. Simulate stage configuration save
      const configEvent = new CustomEvent('stage:configSaved', {
        detail: { stageId: 'stage-1', stageData: { name: 'Updated Stage' } }
      })
      document.dispatchEvent(configEvent)
      
      // Cleanup
      application.stop()
      document.body.removeChild(container)
      done()
    }, 100)
  })
})