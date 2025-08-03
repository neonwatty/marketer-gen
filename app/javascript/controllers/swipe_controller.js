import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "item", "indicator"]
  static values = {
    threshold: { type: Number, default: 50 },
    sensitivity: { type: Number, default: 0.3 },
    autoPlay: { type: Boolean, default: false },
    autoPlayInterval: { type: Number, default: 5000 },
    loop: { type: Boolean, default: true },
    showIndicators: { type: Boolean, default: true },
    snapToItems: { type: Boolean, default: true }
  }

  connect() {
    this.currentIndex = 0
    this.isTransitioning = false
    this.autoPlayTimer = null
    
    // Initialize swipe functionality
    this.initializeSwipe()
    
    // Set up indicators if enabled
    if (this.showIndicatorsValue) {
      this.setupIndicators()
    }
    
    // Start auto-play if enabled
    if (this.autoPlayValue) {
      this.startAutoPlay()
    }
    
    // Handle resize events
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener('resize', this.handleResize)
    
    // Handle visibility change (pause auto-play when tab is hidden)
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener('visibilitychange', this.handleVisibilityChange)
  }

  disconnect() {
    this.stopAutoPlay()
    window.removeEventListener('resize', this.handleResize)
    document.removeEventListener('visibilitychange', this.handleVisibilityChange)
  }

  initializeSwipe() {
    if (!this.hasContainerTarget) {return}
    
    let startX = 0
    let startY = 0
    let currentX = 0
    let currentY = 0
    let isDragging = false
    let startTime = 0
    
    // Touch events
    this.containerTarget.addEventListener('touchstart', (e) => {
      if (this.isTransitioning) {return}
      
      const touch = e.touches[0]
      startX = touch.clientX
      startY = touch.clientY
      startTime = Date.now()
      isDragging = true
      
      // Stop auto-play while dragging
      this.stopAutoPlay()
      
      // Remove scroll snapping temporarily
      if (this.snapToItemsValue) {
        this.containerTarget.style.scrollSnapType = 'none'
      }
    }, { passive: true })
    
    this.containerTarget.addEventListener('touchmove', (e) => {
      if (!isDragging || this.isTransitioning) {return}
      
      const touch = e.touches[0]
      currentX = touch.clientX
      currentY = touch.clientY
      
      const deltaX = currentX - startX
      const deltaY = currentY - startY
      
      // Determine if this is a horizontal swipe
      if (Math.abs(deltaX) > Math.abs(deltaY)) {
        // Prevent default scroll behavior for horizontal swipes
        e.preventDefault()
        
        // Provide visual feedback during swipe
        const translateX = deltaX * this.sensitivityValue
        this.containerTarget.style.transform = `translateX(${translateX}px)`
        this.containerTarget.style.transition = 'none'
      }
    }, { passive: false })
    
    this.containerTarget.addEventListener('touchend', (_e) => {
      if (!isDragging) {return}
      
      isDragging = false
      const deltaX = currentX - startX
      const deltaY = currentY - startY
      const deltaTime = Date.now() - startTime
      
      // Reset transform and transition
      this.containerTarget.style.transform = ''
      this.containerTarget.style.transition = ''
      
      // Restore scroll snapping
      if (this.snapToItemsValue) {
        this.containerTarget.style.scrollSnapType = 'x mandatory'
      }
      
      // Determine swipe direction and threshold
      const isHorizontalSwipe = Math.abs(deltaX) > Math.abs(deltaY)
      const isQuickSwipe = deltaTime < 300
      const exceedsThreshold = Math.abs(deltaX) > this.thresholdValue
      
      if (isHorizontalSwipe && (exceedsThreshold || isQuickSwipe)) {
        if (deltaX > 0) {
          // Swipe right - go to previous
          this.previous()
        } else {
          // Swipe left - go to next
          this.next()
        }
      }
      
      // Restart auto-play if enabled
      if (this.autoPlayValue && !document.hidden) {
        this.startAutoPlay()
      }
    }, { passive: true })
    
    // Mouse events for desktop testing
    this.containerTarget.addEventListener('mousedown', (e) => {
      if (this.isTransitioning) {return}
      
      startX = e.clientX
      startY = e.clientY
      startTime = Date.now()
      isDragging = true
      
      e.preventDefault() // Prevent text selection
    })
    
    this.containerTarget.addEventListener('mousemove', (e) => {
      if (!isDragging || this.isTransitioning) {return}
      
      currentX = e.clientX
      currentY = e.clientY
      
      const deltaX = currentX - startX
      const translateX = deltaX * this.sensitivityValue
      this.containerTarget.style.transform = `translateX(${translateX}px)`
      this.containerTarget.style.transition = 'none'
    })
    
    this.containerTarget.addEventListener('mouseup', (_e) => {
      if (!isDragging) {return}
      
      isDragging = false
      const deltaX = currentX - startX
      const deltaTime = Date.now() - startTime
      
      this.containerTarget.style.transform = ''
      this.containerTarget.style.transition = ''
      
      const isQuickSwipe = deltaTime < 300
      const exceedsThreshold = Math.abs(deltaX) > this.thresholdValue
      
      if (exceedsThreshold || isQuickSwipe) {
        if (deltaX > 0) {
          this.previous()
        } else {
          this.next()
        }
      }
    })
    
    // Prevent context menu on long press
    this.containerTarget.addEventListener('contextmenu', (e) => {
      if (isDragging) {
        e.preventDefault()
      }
    })
  }

  setupIndicators() {
    if (!this.hasIndicatorTarget || !this.hasItemTarget) {return}
    
    // Clear existing indicators
    this.indicatorTarget.innerHTML = ''
    
    // Create indicator for each item
    this.itemTargets.forEach((_, index) => {
      const indicator = document.createElement('button')
      indicator.className = 'w-2 h-2 rounded-full bg-gray-300 transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500'
      indicator.setAttribute('aria-label', `Go to slide ${index + 1}`)
      indicator.dataset.action = 'click->swipe#goToSlide'
      indicator.dataset.swipeSlideParam = index
      
      this.indicatorTarget.appendChild(indicator)
    })
    
    this.updateIndicators()
  }

  updateIndicators() {
    if (!this.hasIndicatorTarget) {return}
    
    const indicators = this.indicatorTarget.querySelectorAll('button')
    indicators.forEach((indicator, index) => {
      if (index === this.currentIndex) {
        indicator.classList.remove('bg-gray-300')
        indicator.classList.add('bg-blue-500')
        indicator.setAttribute('aria-pressed', 'true')
      } else {
        indicator.classList.remove('bg-blue-500')
        indicator.classList.add('bg-gray-300')
        indicator.setAttribute('aria-pressed', 'false')
      }
    })
  }

  next() {
    if (this.isTransitioning) {return}
    
    let nextIndex = this.currentIndex + 1
    
    if (nextIndex >= this.itemTargets.length) {
      if (this.loopValue) {
        nextIndex = 0
      } else {
        return
      }
    }
    
    this.goToSlide({ params: { slide: nextIndex } })
  }

  previous() {
    if (this.isTransitioning) {return}
    
    let prevIndex = this.currentIndex - 1
    
    if (prevIndex < 0) {
      if (this.loopValue) {
        prevIndex = this.itemTargets.length - 1
      } else {
        return
      }
    }
    
    this.goToSlide({ params: { slide: prevIndex } })
  }

  goToSlide(event) {
    const slideIndex = parseInt(event.params.slide)
    
    if (slideIndex === this.currentIndex || this.isTransitioning) {return}
    if (slideIndex < 0 || slideIndex >= this.itemTargets.length) {return}
    
    this.isTransitioning = true
    this.currentIndex = slideIndex
    
    // Scroll to the target slide
    if (this.hasContainerTarget) {
      const targetItem = this.itemTargets[slideIndex]
      const scrollLeft = targetItem.offsetLeft
      
      this.containerTarget.scrollTo({
        left: scrollLeft,
        behavior: 'smooth'
      })
    }
    
    // Update indicators
    this.updateIndicators()
    
    // Dispatch custom event
    this.dispatch('slideChanged', {
      detail: {
        currentIndex: this.currentIndex,
        previousIndex: event.previousIndex || this.currentIndex,
        currentSlide: this.itemTargets[this.currentIndex]
      }
    })
    
    // Reset transition flag after animation
    setTimeout(() => {
      this.isTransitioning = false
    }, 300)
  }

  startAutoPlay() {
    if (!this.autoPlayValue || this.autoPlayTimer) {return}
    
    this.autoPlayTimer = setInterval(() => {
      if (!document.hidden) {
        this.next()
      }
    }, this.autoPlayIntervalValue)
  }

  stopAutoPlay() {
    if (this.autoPlayTimer) {
      clearInterval(this.autoPlayTimer)
      this.autoPlayTimer = null
    }
  }

  // Pause auto-play on hover (desktop)
  pauseAutoPlay() {
    this.stopAutoPlay()
  }

  // Resume auto-play when not hovering
  resumeAutoPlay() {
    if (this.autoPlayValue && !document.hidden) {
      this.startAutoPlay()
    }
  }

  handleResize() {
    // Update scroll position on resize to maintain current slide
    if (this.hasContainerTarget && this.hasItemTarget) {
      const targetItem = this.itemTargets[this.currentIndex]
      if (targetItem) {
        this.containerTarget.scrollLeft = targetItem.offsetLeft
      }
    }
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.stopAutoPlay()
    } else if (this.autoPlayValue) {
      this.startAutoPlay()
    }
  }

  // Keyboard navigation
  keydown(event) {
    switch (event.key) {
      case 'ArrowLeft':
        this.previous()
        event.preventDefault()
        break
      case 'ArrowRight':
        this.next()
        event.preventDefault()
        break
      case 'Home':
        this.goToSlide({ params: { slide: 0 } })
        event.preventDefault()
        break
      case 'End':
        this.goToSlide({ params: { slide: this.itemTargets.length - 1 } })
        event.preventDefault()
        break
    }
  }

  // Public API methods
  getCurrentIndex() {
    return this.currentIndex
  }

  getTotalSlides() {
    return this.itemTargets.length
  }

  isFirstSlide() {
    return this.currentIndex === 0
  }

  isLastSlide() {
    return this.currentIndex === this.itemTargets.length - 1
  }
}