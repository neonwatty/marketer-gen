import { Controller } from "@hotwired/stimulus"

// Widget controller for individual widget functionality and data management
export default class extends Controller {
  static targets = ["loading", "error", "content"]
  static values = { 
    type: String,
    refreshInterval: { type: Number, default: 0 },
    autoRefresh: { type: Boolean, default: false },
    apiEndpoint: String
  }

  connect() {
    console.log(`Widget controller connected: ${this.typeValue}`)
    this.initializeWidget()
    this.setupAutoRefresh()
  }

  disconnect() {
    this.cleanupAutoRefresh()
  }

  initializeWidget() {
    // Widget-specific initialization
    switch (this.typeValue) {
      case 'campaign-overview':
        this.initializeCampaignOverview()
        break
      case 'performance-metrics':
        this.initializePerformanceMetrics()
        break
      case 'quick-stats':
        this.initializeQuickStats()
        break
      case 'recent-activity':
        this.initializeRecentActivity()
        break
      case 'task-progress':
        this.initializeTaskProgress()
        break
      case 'admin-overview':
        this.initializeAdminOverview()
        break
    }

    // Mark widget as initialized
    this.element.classList.add('widget-initialized')
    this.dispatch('initialized', { detail: { type: this.typeValue } })
  }

  // Campaign Overview Widget
  initializeCampaignOverview() {
    this.loadCampaignData()
    this.initializeChartPlaceholder()
  }

  loadCampaignData() {
    // In a real app, this would fetch from an API
    const metrics = {
      activeCampaigns: this.getActiveCampaignsCount(),
      totalReach: this.getTotalReach(),
      conversionRate: this.getConversionRate(),
      avgROI: this.getAverageROI()
    }

    this.updateCampaignMetrics(metrics)
  }

  getActiveCampaignsCount() {
    // Mock data - replace with actual API call
    return Math.floor(Math.random() * 20) + 5
  }

  getTotalReach() {
    return Math.floor(Math.random() * 100000) + 50000
  }

  getConversionRate() {
    return (Math.random() * 5 + 1).toFixed(2)
  }

  getAverageROI() {
    return (Math.random() * 3 + 2).toFixed(1)
  }

  updateCampaignMetrics(metrics) {
    const elements = {
      activeCampaigns: this.element.querySelector('[data-widget-target="activeCampaigns"]'),
      totalReach: this.element.querySelector('[data-widget-target="totalReach"]'),
      conversionRate: this.element.querySelector('[data-widget-target="conversionRate"]'),
      avgROI: this.element.querySelector('[data-widget-target="avgROI"]')
    }

    if (elements.activeCampaigns) {
      this.animateValue(elements.activeCampaigns, metrics.activeCampaigns)
    }
    if (elements.totalReach) {
      elements.totalReach.textContent = this.formatNumber(metrics.totalReach)
    }
    if (elements.conversionRate) {
      elements.conversionRate.textContent = `${metrics.conversionRate}%`
    }
    if (elements.avgROI) {
      elements.avgROI.textContent = `${metrics.avgROI}x`
    }
  }

  initializeChartPlaceholder() {
    // In a real implementation, this would initialize Chart.js or another charting library
    const chartContainer = this.element.querySelector('.chart-container')
    if (chartContainer) {
      // Add loading state
      chartContainer.innerHTML = `
        <div class="flex items-center justify-center h-48">
          <div class="text-center">
            <div class="animate-spin w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full mx-auto mb-2"></div>
            <p class="text-sm text-gray-500">Loading chart data...</p>
          </div>
        </div>
      `
      
      // Simulate chart loading
      setTimeout(() => {
        this.renderMockChart(chartContainer)
      }, 1500)
    }
  }

  renderMockChart(container) {
    container.innerHTML = `
      <div class="h-48 bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg flex items-center justify-center">
        <div class="text-center">
          <svg class="w-16 h-16 text-blue-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
          </svg>
          <p class="text-blue-600 font-medium">Performance Chart</p>
          <p class="text-blue-500 text-sm">Chart.js integration ready</p>
        </div>
      </div>
    `
  }

  // Performance Metrics Widget
  initializePerformanceMetrics() {
    this.loadPerformanceData()
  }

  loadPerformanceData() {
    const metrics = {
      ctr: (Math.random() * 2 + 1).toFixed(2),
      conversion: (Math.random() * 3 + 2).toFixed(2),
      cpc: (Math.random() * 2 + 0.5).toFixed(2),
      roas: (Math.random() * 3 + 3).toFixed(1)
    }

    this.updatePerformanceMetrics(metrics)
  }

  updatePerformanceMetrics(metrics) {
    const ctrElement = this.element.querySelector('[data-widget-target="ctrValue"]')
    const conversionElement = this.element.querySelector('[data-widget-target="conversionValue"]')

    if (ctrElement) {
      ctrElement.textContent = `${metrics.ctr}%`
    }
    if (conversionElement) {
      conversionElement.textContent = `${metrics.conversion}%`
    }
  }

  updateMetricType(event) {
    const metricType = event.target.value
    this.dispatch('metricTypeChanged', { detail: { type: metricType } })
    
    // Update metrics based on type
    this.loadPerformanceData()
  }

  showDetails(event) {
    const metric = event.currentTarget.dataset.metric
    this.dispatch('showMetricDetails', { detail: { metric } })
  }

  // Quick Stats Widget
  initializeQuickStats() {
    this.loadQuickStatsData()
  }

  loadQuickStatsData() {
    const stats = {
      todayVisitors: Math.floor(Math.random() * 1000) + 500,
      todayClicks: Math.floor(Math.random() * 200) + 100,
      todayConversions: Math.floor(Math.random() * 50) + 10
    }

    this.updateQuickStats(stats)
  }

  updateQuickStats(stats) {
    const elements = {
      visitors: this.element.querySelector('[data-widget-target="todayVisitors"]'),
      clicks: this.element.querySelector('[data-widget-target="todayClicks"]'),
      conversions: this.element.querySelector('[data-widget-target="todayConversions"]')
    }

    Object.entries(elements).forEach(([key, element]) => {
      if (element && stats[`today${key.charAt(0).toUpperCase() + key.slice(1)}`]) {
        this.animateValue(element, stats[`today${key.charAt(0).toUpperCase() + key.slice(1)}`])
      }
    })
  }

  exportData() {
    this.dispatch('exportData', { detail: { widget: this.typeValue } })
    
    // Show feedback
    const button = this.element.querySelector('[data-action*="exportData"]')
    if (button) {
      const originalText = button.textContent
      button.textContent = 'Exporting...'
      button.disabled = true
      
      setTimeout(() => {
        button.textContent = 'Exported!'
        setTimeout(() => {
          button.textContent = originalText
          button.disabled = false
        }, 1000)
      }, 1000)
    }
  }

  // Recent Activity Widget - handled by activity-feed controller

  // Task Progress Widget - handled by task-progress controller

  // Admin Overview Widget
  initializeAdminOverview() {
    this.loadSystemHealth()
  }

  loadSystemHealth() {
    // Mock system health data
    const health = {
      uptime: 99.8,
      responseTime: Math.floor(Math.random() * 100) + 100,
      activeUsers: Math.floor(Math.random() * 50) + 20,
      errors: Math.floor(Math.random() * 5)
    }

    this.updateSystemHealth(health)
  }

  updateSystemHealth(health) {
    // Update system health indicators
    const uptimeElement = this.element.querySelector('.uptime-value')
    const responseElement = this.element.querySelector('.response-value')

    if (uptimeElement) {
      uptimeElement.textContent = `${health.uptime}%`
    }
    if (responseElement) {
      responseElement.textContent = `${health.responseTime}ms`
    }
  }

  dismissAlert(event) {
    const alertId = event.currentTarget.dataset.alertId
    const alertElement = event.currentTarget.closest('.alert-item') || event.currentTarget.closest('[class*="border-l-4"]')
    
    if (alertElement) {
      alertElement.style.opacity = '0'
      alertElement.style.transform = 'translateX(20px)'
      
      setTimeout(() => {
        alertElement.remove()
      }, 300)
    }
    
    this.dispatch('alertDismissed', { detail: { alertId } })
  }

  viewSystemLogs() {
    this.dispatch('viewSystemLogs')
  }

  // Common Methods
  refresh() {
    this.showLoading()
    
    // Refresh widget data based on type
    setTimeout(() => {
      switch (this.typeValue) {
        case 'campaign-overview':
          this.loadCampaignData()
          break
        case 'performance-metrics':
          this.loadPerformanceData()
          break
        case 'quick-stats':
          this.loadQuickStatsData()
          break
        case 'admin-overview':
          this.loadSystemHealth()
          break
      }
      this.hideLoading()
    }, 1000)
  }

  showLoading() {
    this.element.classList.add('widget-loading')
    this.dispatch('loadingStarted')
  }

  hideLoading() {
    this.element.classList.remove('widget-loading')
    this.dispatch('loadingCompleted')
  }

  updateTimeRange(event) {
    const timeRange = event.target.value
    this.dispatch('timeRangeChanged', { detail: { range: timeRange } })
    this.refresh()
  }

  // Auto-refresh functionality
  setupAutoRefresh() {
    if (this.autoRefreshValue && this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refresh()
      }, this.refreshIntervalValue)
    }
  }

  cleanupAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  // Utility methods
  animateValue(element, targetValue, duration = 1000) {
    const start = parseInt(element.textContent.replace(/\D/g, '')) || 0
    const increment = (targetValue - start) / (duration / 16)
    let current = start

    const timer = setInterval(() => {
      current += increment
      if ((increment > 0 && current >= targetValue) || (increment < 0 && current <= targetValue)) {
        current = targetValue
        clearInterval(timer)
      }
      element.textContent = Math.floor(current).toLocaleString()
    }, 16)
  }

  formatNumber(number) {
    if (number >= 1000000) {
      return `${(number / 1000000).toFixed(1)  }M`
    } else if (number >= 1000) {
      return `${(number / 1000).toFixed(1)  }K`
    }
    return number.toLocaleString()
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount)
  }

  formatPercentage(value) {
    return `${value.toFixed(1)}%`
  }
}