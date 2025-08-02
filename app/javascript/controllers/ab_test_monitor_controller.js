import { Controller } from "@hotwired/stimulus"

// A/B Test Monitor Controller
// Handles real-time monitoring of active tests with live metric updates
export default class extends Controller {
  static targets = [
    "progressBar", "daysRunning", "totalVisitors", "totalConversions", 
    "confidenceLevel", "conversionRate", "significance"
  ]
  
  static values = {
    testId: Number,
    pollingInterval: { type: Number, default: 30000 }, // 30 seconds
    isActive: { type: Boolean, default: true }
  }

  connect() {
    console.log("A/B Test Monitor connected for test", this.testIdValue)
    this.setupMonitoring()
  }

  disconnect() {
    this.stopMonitoring()
  }

  // Setup real-time monitoring
  setupMonitoring() {
    if (this.isActiveValue && this.testIdValue) {
      this.startPolling()
      this.setupVisibilityHandling()
    }
  }

  // Start polling for updates
  startPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
    }
    
    this.pollingTimer = setInterval(() => {
      this.fetchLiveMetrics()
    }, this.pollingIntervalValue)
    
    // Fetch immediately
    this.fetchLiveMetrics()
  }

  // Stop polling
  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
      this.pollingTimer = null
    }
  }

  // Stop all monitoring
  stopMonitoring() {
    this.stopPolling()
    this.removeVisibilityHandlers()
  }

  // Fetch live metrics from server
  async fetchLiveMetrics() {
    try {
      const response = await fetch(`/ab-tests/${this.testIdValue}/live_metrics`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'Cache-Control': 'no-cache'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      this.updateMetrics(data.metrics)
      this.updateTestStatus(data.status)
      
    } catch (error) {
      console.error('Failed to fetch live metrics:', error)
      this.handleFetchError(error)
    }
  }

  // Update metrics in the UI
  updateMetrics(metrics) {
    if (!metrics) {return}

    // Update progress bar
    if (this.hasProgressBarTarget && metrics.progress_percentage !== undefined) {
      this.updateProgressBar(metrics.progress_percentage)
    }

    // Update days running
    if (this.hasDaysRunningTarget && metrics.days_running !== undefined) {
      this.animateNumberUpdate(this.daysRunningTarget, metrics.days_running)
    }

    // Update total visitors
    if (this.hasTotalVisitorsTarget && metrics.total_visitors !== undefined) {
      this.animateNumberUpdate(this.totalVisitorsTarget, metrics.total_visitors, true)
    }

    // Update total conversions
    if (this.hasTotalConversionsTarget && metrics.total_conversions !== undefined) {
      this.animateNumberUpdate(this.totalConversionsTarget, metrics.total_conversions, true)
    }

    // Update confidence level
    if (this.hasConfidenceLevelTarget && metrics.confidence_level !== undefined) {
      this.updateConfidenceLevel(metrics.confidence_level, metrics.is_significant)
    }

    // Update conversion rates for variants
    this.updateVariantMetrics(metrics.variants || [])
  }

  // Update progress bar with animation
  updateProgressBar(percentage) {
    const currentWidth = parseFloat(this.progressBarTarget.style.width) || 0
    
    if (Math.abs(currentWidth - percentage) > 0.1) {
      this.progressBarTarget.style.width = `${percentage}%`
      
      // Add pulse animation for significant changes
      if (Math.abs(currentWidth - percentage) > 5) {
        this.progressBarTarget.classList.add('animate-pulse')
        setTimeout(() => {
          this.progressBarTarget.classList.remove('animate-pulse')
        }, 1000)
      }
    }
  }

  // Update confidence level with color coding
  updateConfidenceLevel(level, isSignificant) {
    const target = this.confidenceLevelTarget
    const newText = isSignificant ? `${level}%` : '--'
    
    if (target.textContent !== newText) {
      target.textContent = newText
      
      // Update color based on significance
      target.className = isSignificant 
        ? 'text-xl font-bold text-green-600'
        : 'text-xl font-bold text-gray-900'
      
      // Add flash animation for significance changes
      target.classList.add('animate-pulse')
      setTimeout(() => {
        target.classList.remove('animate-pulse')
      }, 1500)
    }
  }

  // Update variant-specific metrics
  updateVariantMetrics(variants) {
    variants.forEach(variant => {
      const variantCard = this.element.querySelector(`[data-variant-id="${variant.id}"]`)
      if (variantCard) {
        this.updateVariantCard(variantCard, variant)
      }
    })
  }

  // Update individual variant card
  updateVariantCard(card, variant) {
    // Update visitors count
    const visitorsElement = card.querySelector('[data-metric="visitors"]')
    if (visitorsElement) {
      this.animateNumberUpdate(visitorsElement, variant.total_visitors, true)
    }

    // Update conversions count
    const conversionsElement = card.querySelector('[data-metric="conversions"]')
    if (conversionsElement) {
      this.animateNumberUpdate(conversionsElement, variant.conversions, true)
    }

    // Update conversion rate
    const rateElement = card.querySelector('[data-metric="conversion-rate"]')
    if (rateElement) {
      const newRate = `${variant.conversion_rate.toFixed(1)}%`
      if (rateElement.textContent !== newRate) {
        rateElement.textContent = newRate
        rateElement.classList.add('animate-pulse')
        setTimeout(() => {
          rateElement.classList.remove('animate-pulse')
        }, 800)
      }
    }

    // Update lift (for non-control variants)
    if (!variant.is_control) {
      const liftElement = card.querySelector('[data-metric="lift"]')
      if (liftElement && variant.lift_vs_control !== undefined) {
        const lift = variant.lift_vs_control
        const liftText = `${lift > 0 ? '+' : ''}${lift.toFixed(1)}%`
        
        if (liftElement.textContent !== liftText) {
          liftElement.textContent = liftText
          
          // Update color based on lift direction
          if (lift > 0) {
            liftElement.className = 'font-medium text-green-600';
          } else if (lift < 0) {
            liftElement.className = 'font-medium text-red-600';
          } else {
            liftElement.className = 'font-medium text-gray-900';
          }
          
          liftElement.classList.add('animate-pulse')
          setTimeout(() => {
            liftElement.classList.remove('animate-pulse')
          }, 800)
        }
      }
    }
  }

  // Animate number updates
  animateNumberUpdate(element, newValue, useCommas = false) {
    const currentValue = parseInt(element.textContent.replace(/,/g, '')) || 0
    
    if (currentValue !== newValue) {
      const duration = 1000 // 1 second
      const steps = 20
      const stepValue = (newValue - currentValue) / steps
      const stepDuration = duration / steps
      
      let current = currentValue
      let step = 0
      
      const animate = () => {
        step++
        current += stepValue
        
        if (step >= steps) {
          current = newValue
        }
        
        const displayValue = useCommas 
          ? Math.round(current).toLocaleString()
          : Math.round(current).toString()
        
        element.textContent = displayValue
        
        if (step < steps) {
          setTimeout(animate, stepDuration)
        }
      }
      
      animate()
    }
  }

  // Update test status
  updateTestStatus(status) {
    // Update any status indicators
    const statusElements = this.element.querySelectorAll('[data-test-status]')
    statusElements.forEach(element => {
      if (element.dataset.testStatus !== status) {
        element.dataset.testStatus = status
        // Trigger any status-specific UI updates
        this.handleStatusChange(status)
      }
    })
  }

  // Handle test status changes
  handleStatusChange(newStatus) {
    switch (newStatus) {
      case 'completed':
        this.stopPolling()
        this.showStatusNotification('Test completed', 'success')
        break
      case 'paused':
        this.showStatusNotification('Test paused', 'warning')
        break
      case 'running':
        this.showStatusNotification('Test resumed', 'info')
        break
    }
  }

  // Show status notification
  showStatusNotification(message, type = 'info') {
    const colors = {
      success: 'bg-green-100 border-green-400 text-green-700',
      warning: 'bg-yellow-100 border-yellow-400 text-yellow-700',
      error: 'bg-red-100 border-red-400 text-red-700',
      info: 'bg-blue-100 border-blue-400 text-blue-700'
    }
    
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 ${colors[type]} px-4 py-3 rounded-lg shadow-lg z-50 transition-all duration-300 transform translate-x-full`
    notification.innerHTML = `
      <div class="flex items-center">
        <span>${message}</span>
        <button class="ml-3 text-current hover:text-opacity-75" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full')
    }, 10)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      notification.classList.add('translate-x-full')
      setTimeout(() => {
        if (notification.parentElement) {
          notification.remove()
        }
      }, 300)
    }, 5000)
  }

  // Handle fetch errors
  handleFetchError(error) {
    console.error('Live metrics fetch error:', error)
    
    // Reduce polling frequency on repeated errors
    if (this.errorCount === undefined) {
      this.errorCount = 0
    }
    
    this.errorCount++
    
    if (this.errorCount >= 3) {
      // Stop polling after 3 consecutive errors
      this.stopPolling()
      this.showStatusNotification('Lost connection to test metrics', 'error')
    } else if (this.errorCount >= 2) {
      // Reduce polling frequency
      this.pollingIntervalValue = Math.min(this.pollingIntervalValue * 2, 300000) // Max 5 minutes
      this.startPolling()
    }
  }

  // Setup visibility change handling to pause/resume polling
  setupVisibilityHandling() {
    this.visibilityHandler = () => {
      if (document.hidden) {
        this.stopPolling()
      } else {
        this.startPolling()
      }
    }
    
    document.addEventListener('visibilitychange', this.visibilityHandler)
  }

  // Remove visibility handlers
  removeVisibilityHandlers() {
    if (this.visibilityHandler) {
      document.removeEventListener('visibilitychange', this.visibilityHandler)
      this.visibilityHandler = null
    }
  }

  // Manual refresh trigger
  refresh() {
    this.errorCount = 0 // Reset error count
    this.fetchLiveMetrics()
  }

  // Pause monitoring
  pause() {
    this.isActiveValue = false
    this.stopPolling()
  }

  // Resume monitoring
  resume() {
    this.isActiveValue = true
    this.startPolling()
  }
}