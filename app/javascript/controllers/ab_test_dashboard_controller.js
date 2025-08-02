import { Controller } from "@hotwired/stimulus"

// A/B Testing Dashboard Controller
// Handles dashboard interactions, real-time updates, and data refresh
export default class extends Controller {
  static targets = [
    "totalTests", "runningTests", "testsWithWinners", "averageConversionRate",
    "refreshButton", "lastUpdated"
  ]
  
  static values = {
    refreshInterval: Number,
    autoRefresh: { type: Boolean, default: true }
  }

  connect() {
    console.log("A/B Testing Dashboard connected")
    this.setupAutoRefresh()
  }

  disconnect() {
    this.teardownAutoRefresh()
  }

  // Manual refresh triggered by user
  refresh() {
    this.showRefreshLoading()
    this.fetchDashboardData()
  }

  // Setup automatic refresh interval
  setupAutoRefresh() {
    if (this.autoRefreshValue && this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.fetchDashboardData()
      }, this.refreshIntervalValue)
    }
  }

  // Cleanup refresh timer
  teardownAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  // Show loading state on refresh button
  showRefreshLoading() {
    if (this.hasRefreshButtonTarget) {
      const button = this.refreshButtonTarget
      const originalContent = button.innerHTML
      
      button.innerHTML = `
        <svg class="animate-spin w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        Refreshing...
      `
      button.disabled = true
      
      // Reset button after delay
      setTimeout(() => {
        button.innerHTML = originalContent
        button.disabled = false
      }, 1500)
    }
  }

  // Fetch updated dashboard data
  async fetchDashboardData() {
    try {
      const response = await fetch(window.location.pathname, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      this.updateDashboardMetrics(data.metrics)
      this.updateLastRefreshTime()
      
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error)
      this.showErrorMessage('Failed to refresh dashboard data')
    }
  }

  // Update dashboard metrics
  updateDashboardMetrics(metrics) {
    if (this.hasTotalTestsTarget) {
      this.animateCountUpdate(this.totalTestsTarget, metrics.total_tests)
    }
    
    if (this.hasRunningTestsTarget) {
      this.animateCountUpdate(this.runningTestsTarget, metrics.running_tests)
    }
    
    if (this.hasTestsWithWinnersTarget) {
      this.animateCountUpdate(this.testsWithWinnersTarget, metrics.tests_with_winners)
    }
    
    if (this.hasAverageConversionRateTarget) {
      const formattedRate = `${metrics.average_conversion_rate.toFixed(1)}%`
      this.animateValueUpdate(this.averageConversionRateTarget, formattedRate)
    }
  }

  // Animate count updates
  animateCountUpdate(target, newValue) {
    const currentValue = parseInt(target.textContent) || 0
    
    if (currentValue !== newValue) {
      target.classList.add('animate-pulse')
      
      // Animate from current to new value
      let step = Math.ceil(Math.abs(newValue - currentValue) / 10)
      if (newValue < currentValue) {step = -step}
      
      let current = currentValue
      const animate = () => {
        current += step
        
        if ((step > 0 && current >= newValue) || (step < 0 && current <= newValue)) {
          current = newValue
          target.textContent = current.toLocaleString()
          target.classList.remove('animate-pulse')
          return
        }
        
        target.textContent = current.toLocaleString()
        requestAnimationFrame(animate)
      }
      
      requestAnimationFrame(animate)
    }
  }

  // Animate value updates (for non-numeric values)
  animateValueUpdate(target, newValue) {
    if (target.textContent !== newValue) {
      target.classList.add('animate-pulse')
      setTimeout(() => {
        target.textContent = newValue
        target.classList.remove('animate-pulse')
      }, 200)
    }
  }

  // Update last refresh timestamp
  updateLastRefreshTime() {
    if (this.hasLastUpdatedTarget) {
      const now = new Date()
      this.lastUpdatedTarget.textContent = `Last updated: ${now.toLocaleTimeString()}`
    }
  }

  // Show error message
  showErrorMessage(message) {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = 'fixed top-4 right-4 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg shadow-lg z-50'
    toast.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.864-.833-2.464 0L5.232 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>
        <span>${message}</span>
        <button class="ml-3 text-red-500 hover:text-red-700" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `
    
    document.body.appendChild(toast)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentElement) {
        toast.remove()
      }
    }, 5000)
  }

  // Toggle auto-refresh
  toggleAutoRefresh() {
    this.autoRefreshValue = !this.autoRefreshValue
    
    if (this.autoRefreshValue) {
      this.setupAutoRefresh()
    } else {
      this.teardownAutoRefresh()
    }
  }

  // Handle visibility change to pause/resume refresh when tab is not visible
  handleVisibilityChange() {
    if (document.hidden) {
      this.teardownAutoRefresh()
    } else if (this.autoRefreshValue) {
      this.setupAutoRefresh()
      // Refresh immediately when tab becomes visible
      this.fetchDashboardData()
    }
  }
}