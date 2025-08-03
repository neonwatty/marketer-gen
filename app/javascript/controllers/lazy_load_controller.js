import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "component", "placeholder"]
  static values = {
    rootMargin: { type: String, default: "50px" },
    threshold: { type: Number, default: 0.1 },
    fadeIn: { type: Boolean, default: true },
    retryAttempts: { type: Number, default: 3 },
    retryDelay: { type: Number, default: 1000 }
  }

  connect() {
    // Check if Intersection Observer is supported
    if (!this.supportsIntersectionObserver()) {
      this.loadAllImmediately()
      return
    }

    // Initialize Intersection Observer
    this.initializeObserver()
    
    // Observe all lazy load targets
    this.observeTargets()
    
    // Handle network status changes
    this.handleOnline = this.handleOnline.bind(this)
    this.handleOffline = this.handleOffline.bind(this)
    window.addEventListener('online', this.handleOnline)
    window.addEventListener('offline', this.handleOffline)
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    
    window.removeEventListener('online', this.handleOnline)
    window.removeEventListener('offline', this.handleOffline)
  }

  supportsIntersectionObserver() {
    return 'IntersectionObserver' in window &&
           'IntersectionObserverEntry' in window &&
           'intersectionRatio' in window.IntersectionObserverEntry.prototype
  }

  initializeObserver() {
    const options = {
      rootMargin: this.rootMarginValue,
      threshold: this.thresholdValue
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.loadElement(entry.target)
          this.observer.unobserve(entry.target)
        }
      })
    }, options)
  }

  observeTargets() {
    // Observe image targets
    this.imageTargets.forEach(img => {
      if (!this.isLoaded(img)) {
        this.observer.observe(img)
        this.initializeImageElement(img)
      }
    })

    // Observe component targets
    this.componentTargets.forEach(component => {
      if (!this.isLoaded(component)) {
        this.observer.observe(component)
        this.initializeComponentElement(component)
      }
    })
  }

  initializeImageElement(img) {
    // Add loading class
    img.classList.add('lazy-loading')
    
    // Set initial styles for fade-in effect
    if (this.fadeInValue) {
      img.style.opacity = '0'
      img.style.transition = 'opacity 0.3s ease-in-out'
    }
    
    // Store original src in data attribute if not already done
    if (img.src && !img.dataset.src) {
      img.dataset.src = img.src
      img.src = this.generatePlaceholder(img)
    }
    
    // Add error handling
    img.addEventListener('error', (e) => this.handleImageError(e, img))
    img.addEventListener('load', (e) => this.handleImageLoad(e, img))
  }

  initializeComponentElement(component) {
    // Add loading class
    component.classList.add('lazy-loading')
    
    // Set initial styles
    if (this.fadeInValue) {
      component.style.opacity = '0'
      component.style.transition = 'opacity 0.3s ease-in-out'
    }
    
    // Show loading placeholder if provided
    this.showComponentPlaceholder(component)
  }

  async loadElement(element) {
    try {
      if (element.dataset.lazyType === 'component' || this.componentTargets.includes(element)) {
        await this.loadComponent(element)
      } else {
        await this.loadImage(element)
      }
    } catch (error) {
      console.error('Failed to load lazy element:', error)
      this.handleLoadError(element, error)
    }
  }

  async loadImage(img) {
    const src = img.dataset.src || img.getAttribute('data-src')
    if (!src) {return}

    // Create a new image to preload
    const imageLoader = new Image()
    
    return new Promise((resolve, reject) => {
      imageLoader.onload = () => {
        // Update the actual image
        img.src = src
        img.classList.remove('lazy-loading')
        img.classList.add('lazy-loaded')
        
        // Apply fade-in effect
        if (this.fadeInValue) {
          img.style.opacity = '1'
        }
        
        // Remove data-src to prevent re-loading
        delete img.dataset.src
        
        // Dispatch load event
        this.dispatch('imageLoaded', {
          detail: { element: img, src }
        })
        
        resolve()
      }
      
      imageLoader.onerror = (error) => {
        reject(new Error(`Failed to load image: ${src}`))
      }
      
      // Start loading
      imageLoader.src = src
    })
  }

  async loadComponent(component) {
    const url = component.dataset.src || component.getAttribute('data-src')
    const method = component.dataset.method || 'GET'
    
    if (!url) {return}

    try {
      // Show loading state
      this.showComponentLoading(component)
      
      // Fetch component content
      const response = await fetch(url, {
        method,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'text/html, application/json'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const contentType = response.headers.get('content-type')
      let content
      
      if (contentType && contentType.includes('application/json')) {
        const data = await response.json()
        content = data.html || data.content || JSON.stringify(data)
      } else {
        content = await response.text()
      }
      
      // Update component content
      component.innerHTML = content
      component.classList.remove('lazy-loading')
      component.classList.add('lazy-loaded')
      
      // Apply fade-in effect
      if (this.fadeInValue) {
        component.style.opacity = '1'
      }
      
      // Initialize any Stimulus controllers in the loaded content
      if (window.Stimulus) {
        window.Stimulus.start()
      }
      
      // Dispatch load event
      this.dispatch('componentLoaded', {
        detail: { element: component, url, content }
      })
      
    } catch (error) {
      this.showComponentError(component, error)
      throw error
    }
  }

  generatePlaceholder(img) {
    const width = img.width || img.getAttribute('width') || 300
    const height = img.height || img.getAttribute('height') || 200
    
    // Generate a simple SVG placeholder
    const svg = `
      <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f3f4f6"/>
        <text x="50%" y="50%" fill="#9ca3af" text-anchor="middle" dy=".3em" font-family="system-ui, sans-serif" font-size="14">
          Loading...
        </text>
      </svg>
    `
    
    return `data:image/svg+xml;base64,${btoa(svg)}`
  }

  showComponentPlaceholder(component) {
    const placeholder = component.querySelector('.lazy-placeholder') || 
                       this.placeholderTargets.find(p => component.contains(p))
    
    if (placeholder) {
      placeholder.style.display = 'block'
    } else {
      // Create default placeholder
      const defaultPlaceholder = document.createElement('div')
      defaultPlaceholder.className = 'lazy-placeholder flex items-center justify-center p-8 bg-gray-100 rounded'
      defaultPlaceholder.innerHTML = `
        <div class="text-center">
          <div class="animate-spin w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full mx-auto mb-2"></div>
          <p class="text-sm text-gray-600">Loading...</p>
        </div>
      `
      component.appendChild(defaultPlaceholder)
    }
  }

  showComponentLoading(component) {
    const loadingEl = component.querySelector('.lazy-loading-state')
    if (loadingEl) {
      loadingEl.style.display = 'block'
    }
  }

  showComponentError(component, error) {
    component.classList.remove('lazy-loading')
    component.classList.add('lazy-error')
    
    // Hide loading elements
    const placeholder = component.querySelector('.lazy-placeholder')
    const loading = component.querySelector('.lazy-loading-state')
    
    if (placeholder) {placeholder.style.display = 'none'}
    if (loading) {loading.style.display = 'none'}
    
    // Show error message
    const errorEl = component.querySelector('.lazy-error-state')
    if (errorEl) {
      errorEl.style.display = 'block'
      const errorMsg = errorEl.querySelector('.error-message')
      if (errorMsg) {
        errorMsg.textContent = error.message || 'Failed to load content'
      }
    } else {
      // Create default error state
      const defaultError = document.createElement('div')
      defaultError.className = 'lazy-error-state flex items-center justify-center p-8 bg-red-50 rounded border border-red-200'
      defaultError.innerHTML = `
        <div class="text-center">
          <svg class="w-8 h-8 text-red-500 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <p class="text-sm text-red-600 mb-2">Failed to load content</p>
          <button class="text-xs text-red-600 underline hover:no-underline" onclick="this.closest('[data-controller*=lazy-load]').dispatchEvent(new CustomEvent('retry'))">
            Try again
          </button>
        </div>
      `
      component.appendChild(defaultError)
    }
    
    // Dispatch error event
    this.dispatch('componentError', {
      detail: { element: component, error }
    })
  }

  handleImageError(event, img) {
    const retryCount = parseInt(img.dataset.retryCount || '0')
    
    if (retryCount < this.retryAttemptsValue) {
      // Retry loading after delay
      setTimeout(() => {
        img.dataset.retryCount = (retryCount + 1).toString()
        const src = img.dataset.src || img.src
        img.src = ''
        img.src = src
      }, this.retryDelayValue * (retryCount + 1))
    } else {
      // Show error state
      img.classList.remove('lazy-loading')
      img.classList.add('lazy-error')
      
      // Use error placeholder
      img.src = this.generateErrorPlaceholder(img)
      
      // Dispatch error event
      this.dispatch('imageError', {
        detail: { element: img, error: 'Failed to load after retries' }
      })
    }
  }

  handleImageLoad(event, img) {
    img.classList.remove('lazy-loading')
    img.classList.add('lazy-loaded')
    
    if (this.fadeInValue) {
      img.style.opacity = '1'
    }
  }

  generateErrorPlaceholder(img) {
    const width = img.width || img.getAttribute('width') || 300
    const height = img.height || img.getAttribute('height') || 200
    
    const svg = `
      <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#fef2f2"/>
        <text x="50%" y="50%" fill="#ef4444" text-anchor="middle" dy=".3em" font-family="system-ui, sans-serif" font-size="14">
          Failed to load
        </text>
      </svg>
    `
    
    return `data:image/svg+xml;base64,${btoa(svg)}`
  }

  handleLoadError(element, error) {
    if (this.imageTargets.includes(element)) {
      this.handleImageError({ error }, element)
    } else {
      this.showComponentError(element, error)
    }
  }

  loadAllImmediately() {
    // Fallback for browsers without Intersection Observer
    this.imageTargets.forEach(img => this.loadImage(img))
    this.componentTargets.forEach(component => this.loadComponent(component))
  }

  isLoaded(element) {
    return element.classList.contains('lazy-loaded') || 
           element.classList.contains('lazy-error')
  }

  handleOnline() {
    // Retry failed elements when coming back online
    const failedElements = [
      ...this.imageTargets.filter(img => img.classList.contains('lazy-error')),
      ...this.componentTargets.filter(comp => comp.classList.contains('lazy-error'))
    ]
    
    failedElements.forEach(element => {
      element.classList.remove('lazy-error')
      element.classList.add('lazy-loading')
      
      if (this.observer) {
        this.observer.observe(element)
      } else {
        this.loadElement(element)
      }
    })
  }

  handleOffline() {
    // Could pause loading or show offline message
    this.dispatch('offline', {
      detail: { controller: this }
    })
  }

  // Action method to retry loading
  retry(event) {
    const element = event.target.closest('[data-lazy-load-target]') || 
                   event.target.closest('.lazy-error')
    
    if (element) {
      element.classList.remove('lazy-error')
      element.classList.add('lazy-loading')
      element.dataset.retryCount = '0'
      
      // Hide error states
      const errorEls = element.querySelectorAll('.lazy-error-state')
      errorEls.forEach(el => el.style.display = 'none')
      
      this.loadElement(element)
    }
  }

  // Public API methods
  forceLoad(element) {
    if (this.observer) {
      this.observer.unobserve(element)
    }
    this.loadElement(element)
  }

  forceLoadAll() {
    const unloadedElements = [
      ...this.imageTargets.filter(img => !this.isLoaded(img)),
      ...this.componentTargets.filter(comp => !this.isLoaded(comp))
    ]
    
    unloadedElements.forEach(element => this.forceLoad(element))
  }

  refresh() {
    // Re-observe all targets
    if (this.observer) {
      this.observer.disconnect()
      this.initializeObserver()
      this.observeTargets()
    }
  }
}