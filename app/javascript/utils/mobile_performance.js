// Mobile Performance Utilities for Journey Builder

export class MobilePerformanceManager {
  constructor() {
    this.isLowEndDevice = this.detectLowEndDevice()
    this.intersectionObserver = null
    this.mutationObserver = null
    this.lazyLoadQueue = new Set()
    this.virtualScrollContainers = new Map()
    this.rafCallbacks = new Set()
  }

  // Detect low-end devices for performance optimizations
  detectLowEndDevice() {
    // Check for navigator.hardwareConcurrency (number of CPU cores)
    if (navigator.hardwareConcurrency && navigator.hardwareConcurrency <= 2) {
      return true
    }
    
    // Check for navigator.deviceMemory (RAM in GB)
    if (navigator.deviceMemory && navigator.deviceMemory <= 4) {
      return true
    }
    
    // Check user agent for older devices
    const userAgent = navigator.userAgent.toLowerCase()
    const oldDevicePatterns = [
      /android [2-4]\./,
      /iphone os [5-9]_/,
      /ipad.*os [5-9]_/
    ]
    
    return oldDevicePatterns.some(pattern => pattern.test(userAgent))
  }

  // Initialize performance optimizations
  initialize() {
    this.setupIntersectionObserver()
    this.setupMutationObserver()
    this.optimizeImages()
    this.enablePassiveListeners()
    this.setupVirtualScrolling()
    
    if (this.isLowEndDevice) {
      this.enableLowEndOptimizations()
    }
  }

  // Setup intersection observer for lazy loading
  setupIntersectionObserver() {
    if (!window.IntersectionObserver) return
    
    this.intersectionObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.handleElementVisible(entry.target)
        }
      })
    }, {
      root: null,
      rootMargin: '100px', // Load content 100px before it comes into view
      threshold: 0.01
    })
  }

  // Setup mutation observer to watch for new elements
  setupMutationObserver() {
    if (!window.MutationObserver) return
    
    this.mutationObserver = new MutationObserver((mutations) => {
      mutations.forEach(mutation => {
        mutation.addedNodes.forEach(node => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            this.optimizeNewElement(node)
          }
        })
      })
    })
  }

  // Start observing a container for performance optimizations
  observeContainer(container) {
    if (this.mutationObserver) {
      this.mutationObserver.observe(container, {
        childList: true,
        subtree: true
      })
    }
    
    // Setup lazy loading for existing elements
    const lazyElements = container.querySelectorAll('[data-lazy]')
    lazyElements.forEach(element => {
      this.setupLazyLoading(element)
    })
  }

  // Setup lazy loading for an element
  setupLazyLoading(element) {
    if (!this.intersectionObserver) return
    
    this.lazyLoadQueue.add(element)
    this.intersectionObserver.observe(element)
  }

  // Handle element becoming visible
  handleElementVisible(element) {
    if (this.lazyLoadQueue.has(element)) {
      this.loadElement(element)
      this.lazyLoadQueue.delete(element)
      this.intersectionObserver.unobserve(element)
    }
  }

  // Load a lazy element
  loadElement(element) {
    const src = element.dataset.lazy
    const type = element.dataset.lazyType || 'image'
    
    switch (type) {
      case 'image':
        this.loadLazyImage(element, src)
        break
      case 'component':
        this.loadLazyComponent(element, src)
        break
      case 'template':
        this.loadLazyTemplate(element, src)
        break
    }
  }

  // Load lazy image with progressive enhancement
  loadLazyImage(img, src) {
    const image = new Image()
    
    image.onload = () => {
      img.src = src
      img.classList.add('loaded')
      img.classList.remove('loading')
    }
    
    image.onerror = () => {
      img.classList.add('error')
      img.classList.remove('loading')
    }
    
    img.classList.add('loading')
    image.src = src
  }

  // Load lazy component
  async loadLazyComponent(container, componentName) {
    try {
      container.classList.add('loading')
      
      // Dynamic import of component
      const module = await import(`../controllers/${componentName}_controller.js`)
      
      // Initialize component
      if (module.default) {
        // Stimulus controller
        const application = window.Stimulus
        if (application) {
          application.register(componentName, module.default)
        }
      }
      
      container.classList.remove('loading')
      container.classList.add('loaded')
      
    } catch (error) {
      console.error(`Failed to load component ${componentName}:`, error)
      container.classList.add('error')
      container.classList.remove('loading')
    }
  }

  // Load lazy template
  async loadLazyTemplate(container, templatePath) {
    try {
      container.classList.add('loading')
      
      const response = await fetch(templatePath)
      if (response.ok) {
        const html = await response.text()
        container.innerHTML = html
        container.classList.add('loaded')
      } else {
        throw new Error(`Template load failed: ${response.statusText}`)
      }
      
      container.classList.remove('loading')
      
    } catch (error) {
      console.error(`Failed to load template ${templatePath}:`, error)
      container.classList.add('error')
      container.classList.remove('loading')
    }
  }

  // Setup virtual scrolling for large lists
  setupVirtualScrolling() {
    const virtualContainers = document.querySelectorAll('[data-virtual-scroll]')
    
    virtualContainers.forEach(container => {
      this.initializeVirtualScroll(container)
    })
  }

  // Initialize virtual scrolling for a container
  initializeVirtualScroll(container) {
    const itemHeight = parseInt(container.dataset.itemHeight) || 60
    const bufferSize = parseInt(container.dataset.bufferSize) || 5
    const items = Array.from(container.children)
    
    if (items.length < 20) return // Don't virtualize small lists
    
    const virtualScroll = new VirtualScroll({
      container,
      items,
      itemHeight,
      bufferSize
    })
    
    this.virtualScrollContainers.set(container, virtualScroll)
  }

  // Optimize images for mobile
  optimizeImages() {
    const images = document.querySelectorAll('img')
    
    images.forEach(img => {
      // Add loading="lazy" for browser-native lazy loading
      if (!img.hasAttribute('loading')) {
        img.setAttribute('loading', 'lazy')
      }
      
      // Add decoding="async" for better performance
      if (!img.hasAttribute('decoding')) {
        img.setAttribute('decoding', 'async')
      }
      
      // Setup responsive images based on device pixel ratio
      if (img.dataset.srcHd && window.devicePixelRatio > 1) {
        img.src = img.dataset.srcHd
      }
    })
  }

  // Optimize new elements as they're added
  optimizeNewElement(element) {
    // Setup lazy loading
    if (element.hasAttribute('data-lazy')) {
      this.setupLazyLoading(element)
    }
    
    // Optimize images
    const images = element.querySelectorAll('img')
    images.forEach(img => {
      if (!img.hasAttribute('loading')) {
        img.setAttribute('loading', 'lazy')
      }
    })
    
    // Setup virtual scrolling
    if (element.hasAttribute('data-virtual-scroll')) {
      this.initializeVirtualScroll(element)
    }
  }

  // Enable passive event listeners for better scroll performance
  enablePassiveListeners() {
    // Override addEventListener to make touch events passive by default
    const originalAddEventListener = EventTarget.prototype.addEventListener
    
    EventTarget.prototype.addEventListener = function(type, listener, options) {
      const passiveEvents = ['touchstart', 'touchmove', 'wheel', 'mousewheel']
      
      if (passiveEvents.includes(type)) {
        if (typeof options === 'boolean') {
          options = { capture: options, passive: true }
        } else if (typeof options === 'object') {
          options = { ...options, passive: true }
        } else {
          options = { passive: true }
        }
      }
      
      return originalAddEventListener.call(this, type, listener, options)
    }
  }

  // Enable optimizations for low-end devices
  enableLowEndOptimizations() {
    // Reduce animation duration
    this.reduceAnimations()
    
    // Disable expensive effects
    this.disableExpensiveEffects()
    
    // Reduce update frequency
    this.reduceUpdateFrequency()
  }

  // Reduce animation durations for low-end devices
  reduceAnimations() {
    const style = document.createElement('style')
    style.textContent = `
      .low-end-device * {
        animation-duration: 0.1s !important;
        transition-duration: 0.1s !important;
      }
    `
    document.head.appendChild(style)
    document.body.classList.add('low-end-device')
  }

  // Disable expensive visual effects
  disableExpensiveEffects() {
    const style = document.createElement('style')
    style.textContent = `
      .low-end-device {
        --shadow-sm: none;
        --shadow: none;
        --shadow-lg: none;
        --shadow-xl: none;
      }
      
      .low-end-device .shadow-sm,
      .low-end-device .shadow,
      .low-end-device .shadow-lg,
      .low-end-device .shadow-xl {
        box-shadow: none !important;
      }
      
      .low-end-device .backdrop-blur,
      .low-end-device .backdrop-filter {
        backdrop-filter: none !important;
      }
    `
    document.head.appendChild(style)
  }

  // Reduce update frequency for animations and auto-save
  reduceUpdateFrequency() {
    // Extend auto-save interval
    const saveIntervals = document.querySelectorAll('[data-auto-save-interval]')
    saveIntervals.forEach(element => {
      const currentInterval = parseInt(element.dataset.autoSaveInterval) || 5000
      element.dataset.autoSaveInterval = Math.max(currentInterval * 2, 10000)
    })
  }

  // Throttle expensive operations
  throttle(func, limit = 16) { // 60fps = ~16ms
    let inThrottle
    return function(...args) {
      const context = this
      if (!inThrottle) {
        func.apply(context, args)
        inThrottle = true
        setTimeout(() => inThrottle = false, limit)
      }
    }
  }

  // Debounce for user input
  debounce(func, wait = 300, immediate = false) {
    let timeout
    return function(...args) {
      const context = this
      const later = function() {
        timeout = null
        if (!immediate) func.apply(context, args)
      }
      const callNow = immediate && !timeout
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
      if (callNow) func.apply(context, args)
    }
  }

  // Request animation frame with fallback
  requestAnimationFrame(callback) {
    if (this.rafCallbacks.has(callback)) return
    
    this.rafCallbacks.add(callback)
    
    const wrappedCallback = (timestamp) => {
      this.rafCallbacks.delete(callback)
      callback(timestamp)
    }
    
    if (window.requestAnimationFrame) {
      return window.requestAnimationFrame(wrappedCallback)
    } else {
      return setTimeout(wrappedCallback, 16) // ~60fps fallback
    }
  }

  // Memory management
  cleanup() {
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }
    
    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
    }
    
    this.virtualScrollContainers.forEach(virtualScroll => {
      virtualScroll.destroy()
    })
    
    this.lazyLoadQueue.clear()
    this.virtualScrollContainers.clear()
    this.rafCallbacks.clear()
  }
}

// Virtual Scrolling Implementation
class VirtualScroll {
  constructor({ container, items, itemHeight, bufferSize = 5 }) {
    this.container = container
    this.items = items
    this.itemHeight = itemHeight
    this.bufferSize = bufferSize
    this.scrollTop = 0
    this.containerHeight = container.clientHeight
    
    this.initialize()
  }

  initialize() {
    // Create virtual container
    this.createVirtualContainer()
    
    // Setup scroll listener
    this.container.addEventListener('scroll', this.handleScroll.bind(this), { passive: true })
    
    // Initial render
    this.updateVisibleItems()
  }

  createVirtualContainer() {
    const totalHeight = this.items.length * this.itemHeight
    
    // Hide original items
    this.items.forEach(item => {
      item.style.display = 'none'
    })
    
    // Create spacer elements
    this.topSpacer = document.createElement('div')
    this.bottomSpacer = document.createElement('div')
    this.visibleContainer = document.createElement('div')
    
    this.topSpacer.style.height = '0px'
    this.bottomSpacer.style.height = totalHeight + 'px'
    
    this.container.appendChild(this.topSpacer)
    this.container.appendChild(this.visibleContainer)
    this.container.appendChild(this.bottomSpacer)
  }

  handleScroll() {
    this.scrollTop = this.container.scrollTop
    this.updateVisibleItems()
  }

  updateVisibleItems() {
    const startIndex = Math.floor(this.scrollTop / this.itemHeight)
    const endIndex = Math.min(
      startIndex + Math.ceil(this.containerHeight / this.itemHeight) + this.bufferSize,
      this.items.length - 1
    )

    const visibleStartIndex = Math.max(0, startIndex - this.bufferSize)
    const visibleEndIndex = Math.min(this.items.length - 1, endIndex + this.bufferSize)

    // Update spacer heights
    this.topSpacer.style.height = (visibleStartIndex * this.itemHeight) + 'px'
    this.bottomSpacer.style.height = ((this.items.length - visibleEndIndex - 1) * this.itemHeight) + 'px'

    // Clear visible container
    this.visibleContainer.innerHTML = ''

    // Add visible items
    for (let i = visibleStartIndex; i <= visibleEndIndex; i++) {
      const item = this.items[i].cloneNode(true)
      item.style.display = 'block'
      this.visibleContainer.appendChild(item)
    }
  }

  destroy() {
    this.container.removeEventListener('scroll', this.handleScroll)
    
    // Restore original items
    this.items.forEach(item => {
      item.style.display = ''
    })
    
    // Remove virtual elements
    if (this.topSpacer) this.topSpacer.remove()
    if (this.bottomSpacer) this.bottomSpacer.remove()
    if (this.visibleContainer) this.visibleContainer.remove()
  }
}

// Export singleton instance
export const mobilePerformance = new MobilePerformanceManager()