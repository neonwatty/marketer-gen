import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "content"]
  static values = {
    threshold: { type: Number, default: 80 },
    url: { type: String, default: "" },
    method: { type: String, default: "GET" },
    enabled: { type: Boolean, default: true }
  }

  connect() {
    this.isRefreshing = false
    this.startY = 0
    this.currentY = 0
    this.pullDistance = 0
    this.isAtTop = true
    
    // Initialize pull-to-refresh
    this.initializePullToRefresh()
    
    // Check if we're at the top initially
    this.checkScrollPosition()
  }

  disconnect() {
    // Clean up event listeners
    if (this.hasContentTarget) {
      this.contentTarget.removeEventListener('touchstart', this.handleTouchStart)
      this.contentTarget.removeEventListener('touchmove', this.handleTouchMove)
      this.contentTarget.removeEventListener('touchend', this.handleTouchEnd)
      this.contentTarget.removeEventListener('scroll', this.handleScroll)
    }
  }

  initializePullToRefresh() {
    if (!this.enabledValue || !this.hasContentTarget) {return}
    
    // Bind event handlers
    this.handleTouchStart = this.handleTouchStart.bind(this)
    this.handleTouchMove = this.handleTouchMove.bind(this)
    this.handleTouchEnd = this.handleTouchEnd.bind(this)
    this.handleScroll = this.handleScroll.bind(this)
    
    // Set up container styles
    this.element.style.overscrollBehaviorY = 'contain'
    this.element.style.position = 'relative'
    
    // Add event listeners
    this.contentTarget.addEventListener('touchstart', this.handleTouchStart, { passive: true })
    this.contentTarget.addEventListener('touchmove', this.handleTouchMove, { passive: false })
    this.contentTarget.addEventListener('touchend', this.handleTouchEnd, { passive: true })
    this.contentTarget.addEventListener('scroll', this.handleScroll, { passive: true })
    
    // Initialize indicator
    this.initializeIndicator()
  }

  initializeIndicator() {
    if (!this.hasIndicatorTarget) {return}
    
    // Set initial indicator styles
    this.indicatorTarget.style.position = 'absolute'
    this.indicatorTarget.style.top = '-60px'
    this.indicatorTarget.style.left = '50%'
    this.indicatorTarget.style.transform = 'translateX(-50%)'
    this.indicatorTarget.style.opacity = '0'
    this.indicatorTarget.style.transition = 'opacity 0.3s ease, transform 0.3s ease'
    this.indicatorTarget.style.zIndex = '10'
    
    // Add default content if empty
    if (this.indicatorTarget.innerHTML.trim() === '') {
      this.indicatorTarget.innerHTML = `
        <div class="flex items-center justify-center p-4">
          <div class="refresh-icon w-6 h-6 text-blue-500">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
            </svg>
          </div>
          <span class="ml-2 text-sm font-medium text-gray-600">Pull to refresh</span>
        </div>
      `
    }
  }

  handleTouchStart(event) {
    if (this.isRefreshing || !this.enabledValue) {return}
    
    this.startY = event.touches[0].clientY
    this.checkScrollPosition()
  }

  handleTouchMove(event) {
    if (this.isRefreshing || !this.enabledValue || !this.isAtTop) {return}
    
    this.currentY = event.touches[0].clientY
    this.pullDistance = Math.max(0, this.currentY - this.startY)
    
    // Only handle pull-to-refresh if pulling down from the top
    if (this.pullDistance > 0 && this.isAtTop) {
      event.preventDefault() // Prevent default scroll behavior
      
      // Calculate indicator position and opacity
      const progress = Math.min(this.pullDistance / this.thresholdValue, 1)
      const translateY = Math.min(this.pullDistance * 0.5, 60)
      
      // Update indicator
      this.updateIndicator(progress, translateY)
      
      // Add resistance to content scrolling
      if (this.hasContentTarget) {
        const resistance = Math.max(0.3, 1 - (this.pullDistance / 200))
        this.contentTarget.style.transform = `translateY(${this.pullDistance * resistance}px)`
        this.contentTarget.style.transition = 'none'
      }
    }
  }

  handleTouchEnd(_event) {
    if (this.isRefreshing || !this.enabledValue) {return}
    
    // Reset content position
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = ''
      this.contentTarget.style.transition = ''
    }
    
    // Check if we should trigger refresh
    if (this.pullDistance >= this.thresholdValue && this.isAtTop) {
      this.triggerRefresh()
    } else {
      this.resetIndicator()
    }
    
    this.pullDistance = 0
  }

  handleScroll(_event) {
    this.checkScrollPosition()
  }

  checkScrollPosition() {
    if (!this.hasContentTarget) {return}
    
    this.isAtTop = this.contentTarget.scrollTop <= 5
  }

  updateIndicator(progress, translateY) {
    if (!this.hasIndicatorTarget) {return}
    
    const opacity = Math.min(progress, 1)
    const rotation = progress * 180
    
    this.indicatorTarget.style.opacity = opacity
    this.indicatorTarget.style.transform = `translateX(-50%) translateY(${translateY}px)`
    
    // Update icon rotation
    const icon = this.indicatorTarget.querySelector('.refresh-icon')
    if (icon) {
      icon.style.transform = `rotate(${rotation}deg)`
      icon.style.transition = 'transform 0.1s ease'
    }
    
    // Update text based on progress
    const text = this.indicatorTarget.querySelector('span')
    if (text) {
      if (progress >= 1) {
        text.textContent = 'Release to refresh'
        text.classList.add('text-blue-600', 'font-semibold')
      } else {
        text.textContent = 'Pull to refresh'
        text.classList.remove('text-blue-600', 'font-semibold')
      }
    }
  }

  async triggerRefresh() {
    if (this.isRefreshing) {return}
    
    this.isRefreshing = true
    
    // Show refreshing state
    this.showRefreshingState()
    
    try {
      // Dispatch refresh event
      const refreshResult = this.dispatch('refresh', {
        detail: { controller: this },
        cancelable: true
      })
      
      // If event was not cancelled, perform default refresh
      if (!refreshResult.defaultPrevented) {
        await this.performRefresh()
      }
      
      // Show success state briefly
      this.showSuccessState()
      
    } catch (error) {
      console.error('Refresh failed:', error)
      
      // Show error state
      this.showErrorState()
      
      // Dispatch error event
      this.dispatch('refreshError', {
        detail: { error, controller: this }
      })
    } finally {
      // Reset after delay
      setTimeout(() => {
        this.resetIndicator()
        this.isRefreshing = false
      }, 1000)
    }
  }

  async performRefresh() {
    if (!this.urlValue) {
      // Just reload the page if no URL specified
      window.location.reload()
      return
    }
    
    // Perform fetch request
    const response = await fetch(this.urlValue, {
      method: this.methodValue,
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'text/html, application/json'
      }
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    // Handle response based on content type
    const contentType = response.headers.get('content-type')
    
    if (contentType && contentType.includes('application/json')) {
      const data = await response.json()
      
      // Dispatch data received event
      this.dispatch('dataReceived', {
        detail: { data, controller: this }
      })
    } else {
      // For HTML responses, you might want to update specific parts of the page
      const html = await response.text()
      
      // Dispatch HTML received event
      this.dispatch('htmlReceived', {
        detail: { html, controller: this }
      })
    }
  }

  showRefreshingState() {
    if (!this.hasIndicatorTarget) {return}
    
    this.indicatorTarget.style.opacity = '1'
    this.indicatorTarget.style.transform = 'translateX(-50%) translateY(20px)'
    
    // Update icon to show spinning animation
    const icon = this.indicatorTarget.querySelector('.refresh-icon')
    if (icon) {
      icon.style.animation = 'spin 1s linear infinite'
    }
    
    // Update text
    const text = this.indicatorTarget.querySelector('span')
    if (text) {
      text.textContent = 'Refreshing...'
      text.classList.add('text-blue-600')
    }
  }

  showSuccessState() {
    if (!this.hasIndicatorTarget) {return}
    
    // Update icon to show checkmark
    const icon = this.indicatorTarget.querySelector('.refresh-icon')
    if (icon) {
      icon.style.animation = 'none'
      icon.innerHTML = `
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
      `
      icon.classList.add('text-green-500')
    }
    
    // Update text
    const text = this.indicatorTarget.querySelector('span')
    if (text) {
      text.textContent = 'Refreshed!'
      text.classList.add('text-green-600')
    }
  }

  showErrorState() {
    if (!this.hasIndicatorTarget) {return}
    
    // Update icon to show error
    const icon = this.indicatorTarget.querySelector('.refresh-icon')
    if (icon) {
      icon.style.animation = 'none'
      icon.innerHTML = `
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
      `
      icon.classList.add('text-red-500')
    }
    
    // Update text
    const text = this.indicatorTarget.querySelector('span')
    if (text) {
      text.textContent = 'Refresh failed'
      text.classList.add('text-red-600')
    }
  }

  resetIndicator() {
    if (!this.hasIndicatorTarget) {return}
    
    this.indicatorTarget.style.opacity = '0'
    this.indicatorTarget.style.transform = 'translateX(-50%)'
    
    // Reset icon
    const icon = this.indicatorTarget.querySelector('.refresh-icon')
    if (icon) {
      icon.style.animation = 'none'
      icon.style.transform = 'rotate(0deg)'
      icon.classList.remove('text-green-500', 'text-red-500')
      icon.innerHTML = `
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
      `
    }
    
    // Reset text
    const text = this.indicatorTarget.querySelector('span')
    if (text) {
      text.textContent = 'Pull to refresh'
      text.classList.remove('text-blue-600', 'font-semibold', 'text-green-600', 'text-red-600')
    }
  }

  // Public API methods
  enable() {
    this.enabledValue = true
  }

  disable() {
    this.enabledValue = false
    this.resetIndicator()
  }

  isEnabled() {
    return this.enabledValue
  }

  // Manual refresh trigger
  refresh() {
    if (this.enabledValue && !this.isRefreshing && this.isAtTop) {
      this.triggerRefresh()
    }
  }
}