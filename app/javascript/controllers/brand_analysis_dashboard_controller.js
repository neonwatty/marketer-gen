import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = [
    "progressCircle", "confidenceScore", "analysisStage", "characteristicsChart", 
    "brandHealthScore", "complianceScore", "assetsAnalyzed", "violationsCount",
    "analysisResults", "refreshButton", "statusIndicator", "timeRemaining",
    "detailsPanel", "insightsPanel", "recommendationsPanel", "trendsChart",
    "comparisonChart", "historicalData"
  ]
  
  static values = {
    brandId: Number,
    refreshInterval: { type: Number, default: 5000 },
    autoRefresh: { type: Boolean, default: true }
  }

  connect() {
    console.log("Brand analysis dashboard controller connected")
    this.initializeWebSocket()
    this.setupRefreshInterval()
    this.initializeCharts()
    this.loadInitialData()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  // WebSocket Integration
  initializeWebSocket() {
    if (!this.brandIdValue) {
      console.error("Brand ID not found for analysis dashboard")
      return
    }

    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: "BrandAnalysisChannel",
        brand_id: this.brandIdValue
      },
      {
        connected: this.channelConnected.bind(this),
        disconnected: this.channelDisconnected.bind(this),
        received: this.channelReceived.bind(this)
      }
    )
  }

  channelConnected() {
    console.log("Connected to brand analysis channel")
    this.updateConnectionStatus(true)
  }

  channelDisconnected() {
    console.log("Disconnected from brand analysis channel")
    this.updateConnectionStatus(false)
  }

  channelReceived(data) {
    console.log("Received analysis data:", data)
    
    switch (data.event) {
      case "analysis_started":
        this.handleAnalysisStarted(data)
        break
      case "analysis_progress":
        this.handleAnalysisProgress(data)
        break
      case "analysis_complete":
        this.handleAnalysisComplete(data)
        break
      case "analysis_error":
        this.handleAnalysisError(data)
        break
      case "compliance_update":
        this.handleComplianceUpdate(data)
        break
      case "brand_health_update":
        this.handleBrandHealthUpdate(data)
        break
      default:
        console.log("Unknown analysis event:", data.event)
    }
  }

  // Event Handlers
  handleAnalysisStarted(data) {
    this.showAnalysisInProgress()
    this.updateAnalysisStage(data.stage || "Starting analysis...")
    this.updateProgressCircle(0)
    
    if (data.estimated_duration) {
      this.startTimeCountdown(data.estimated_duration)
    }
  }

  handleAnalysisProgress(data) {
    this.updateProgressCircle(data.progress || 0)
    this.updateAnalysisStage(data.stage || "Analyzing...")
    this.updateConfidenceScore(data.confidence || 0)
    
    if (data.partial_results) {
      this.updatePartialResults(data.partial_results)
    }
  }

  handleAnalysisComplete(data) {
    this.updateProgressCircle(100)
    this.updateAnalysisStage("Analysis complete")
    this.hideAnalysisInProgress()
    this.loadAnalysisResults(data.results)
    this.updateDashboardMetrics(data.results)
    this.refreshCharts(data.results)
  }

  handleAnalysisError(data) {
    this.hideAnalysisInProgress()
    this.showError(`Analysis failed: ${data.error}`)
    this.updateAnalysisStage("Analysis failed")
  }

  handleComplianceUpdate(data) {
    this.updateComplianceScore(data.score)
    this.updateViolationsCount(data.violations_count)
    
    if (data.trends) {
      this.updateComplianceTrends(data.trends)
    }
  }

  handleBrandHealthUpdate(data) {
    this.updateBrandHealthScore(data.health_score)
    this.updateAssetsAnalyzed(data.assets_analyzed)
    
    if (data.recommendations) {
      this.updateRecommendations(data.recommendations)
    }
  }

  // Dashboard Updates
  updateProgressCircle(percentage) {
    if (!this.hasProgressCircleTarget) {return}

    const circle = this.progressCircleTarget
    const circumference = 2 * Math.PI * 45 // radius = 45
    const strokeDasharray = circumference
    const strokeDashoffset = circumference - (percentage / 100) * circumference

    circle.style.strokeDasharray = strokeDasharray
    circle.style.strokeDashoffset = strokeDashoffset
    
    // Update color based on progress
    if (percentage < 30) {
      circle.style.stroke = '#ef4444' // red
    } else if (percentage < 70) {
      circle.style.stroke = '#f59e0b' // amber
    } else {
      circle.style.stroke = '#10b981' // green
    }

    // Update progress percentage text
    const progressText = circle.parentElement.querySelector('.progress-percentage')
    if (progressText) {
      progressText.textContent = `${Math.round(percentage)}%`
    }
  }

  updateConfidenceScore(score) {
    if (!this.hasConfidenceScoreTarget) {return}

    const percentage = Math.round(score * 100)
    this.confidenceScoreTarget.textContent = `${percentage}%`
    
    // Update color based on confidence level
    const scoreElement = this.confidenceScoreTarget
    if (percentage < 50) {
      scoreElement.className = 'text-2xl font-bold text-red-600'
    } else if (percentage < 75) {
      scoreElement.className = 'text-2xl font-bold text-yellow-600'
    } else {
      scoreElement.className = 'text-2xl font-bold text-green-600'
    }
  }

  updateAnalysisStage(stage) {
    if (this.hasAnalysisStageTarget) {
      this.analysisStageTarget.textContent = stage
    }
  }

  updateBrandHealthScore(score) {
    if (!this.hasBrandHealthScoreTarget) {return}

    const percentage = Math.round(score * 100)
    this.brandHealthScoreTarget.textContent = `${percentage}%`
    
    // Animate the score change
    this.animateScoreChange(this.brandHealthScoreTarget, percentage)
  }

  updateComplianceScore(score) {
    if (!this.hasComplianceScoreTarget) {return}

    const percentage = Math.round(score * 100)
    this.complianceScoreTarget.textContent = `${percentage}%`
    
    // Update compliance indicator
    const indicator = this.complianceScoreTarget.parentElement.querySelector('.compliance-indicator')
    if (indicator) {
      let colorClass;
      if (percentage >= 90) {
        colorClass = 'bg-green-500';
      } else if (percentage >= 70) {
        colorClass = 'bg-yellow-500';
      } else {
        colorClass = 'bg-red-500';
      }
      indicator.className = `compliance-indicator w-3 h-3 rounded-full ${colorClass}`;
    }
  }

  updateAssetsAnalyzed(count) {
    if (this.hasAssetsAnalyzedTarget) {
      this.assetsAnalyzedTarget.textContent = count.toString()
      this.animateCountChange(this.assetsAnalyzedTarget, count)
    }
  }

  updateViolationsCount(count) {
    if (this.hasViolationsCountTarget) {
      this.violationsCountTarget.textContent = count.toString()
      
      // Update violations indicator color
      const indicator = this.violationsCountTarget.parentElement.querySelector('.violations-indicator')
      if (indicator) {
        indicator.className = `violations-indicator w-3 h-3 rounded-full ${
          count === 0 ? 'bg-green-500' :
          count <= 3 ? 'bg-yellow-500' : 'bg-red-500'
        }`
      }
    }
  }

  // Data Loading
  async loadInitialData() {
    try {
      const response = await fetch(`/api/v1/brands/${this.brandIdValue}/analysis_dashboard`)
      if (response.ok) {
        const data = await response.json()
        this.updateDashboardFromData(data)
      }
    } catch (error) {
      console.error("Error loading initial dashboard data:", error)
    }
  }

  async loadAnalysisResults(results) {
    if (!this.hasAnalysisResultsTarget) {return}

    try {
      // Update analysis results panel
      this.updateAnalysisResultsPanel(results)
      this.updateInsightsPanel(results.insights)
      this.updateRecommendations(results.recommendations)
      
      // Update historical data
      this.updateHistoricalData(results)
      
    } catch (error) {
      console.error("Error loading analysis results:", error)
    }
  }

  updateDashboardFromData(data) {
    if (data.current_analysis) {
      this.updateConfidenceScore(data.current_analysis.confidence_score || 0)
      this.updateBrandHealthScore(data.current_analysis.brand_health_score || 0)
    }

    if (data.compliance_data) {
      this.updateComplianceScore(data.compliance_data.score || 0)
      this.updateViolationsCount(data.compliance_data.violations_count || 0)
    }

    if (data.assets_count) {
      this.updateAssetsAnalyzed(data.assets_count)
    }

    if (data.analysis_in_progress) {
      this.showAnalysisInProgress()
      this.updateAnalysisStage(data.current_stage || "Analyzing...")
      this.updateProgressCircle(data.progress || 0)
    }
  }

  // Chart Management
  initializeCharts() {
    this.initializeCharacteristicsChart()
    this.initializeTrendsChart()
    this.initializeComparisonChart()
  }

  initializeCharacteristicsChart() {
    if (!this.hasCharacteristicsChartTarget) {return}

    // Simple bar chart for brand characteristics
    this.characteristicsChart = {
      element: this.characteristicsChartTarget,
      data: [],
      render: () => this.renderCharacteristicsChart()
    }
  }

  initializeTrendsChart() {
    if (!this.hasTrendsChartTarget) {return}

    // Line chart for trends over time
    this.trendsChart = {
      element: this.trendsChartTarget,
      data: [],
      render: () => this.renderTrendsChart()
    }
  }

  initializeComparisonChart() {
    if (!this.hasComparisonChartTarget) {return}

    // Comparison chart for different metrics
    this.comparisonChart = {
      element: this.comparisonChartTarget,
      data: [],
      render: () => this.renderComparisonChart()
    }
  }

  refreshCharts(data) {
    if (data.characteristics && this.characteristicsChart) {
      this.characteristicsChart.data = data.characteristics
      this.characteristicsChart.render()
    }

    if (data.trends && this.trendsChart) {
      this.trendsChart.data = data.trends
      this.trendsChart.render()
    }

    if (data.comparisons && this.comparisonChart) {
      this.comparisonChart.data = data.comparisons
      this.comparisonChart.render()
    }
  }

  renderCharacteristicsChart() {
    const container = this.characteristicsChart.element
    const data = this.characteristicsChart.data

    container.innerHTML = ''

    if (!data || data.length === 0) {
      container.innerHTML = '<p class="text-gray-500 text-center py-4">No characteristics data available</p>'
      return
    }

    // Create simple horizontal bar chart
    data.forEach(characteristic => {
      const barContainer = document.createElement('div')
      barContainer.className = 'mb-3'
      
      const percentage = Math.round(characteristic.score * 100)
      
      barContainer.innerHTML = `
        <div class="flex justify-between items-center mb-1">
          <span class="text-sm font-medium text-gray-700">${characteristic.name}</span>
          <span class="text-sm text-gray-500">${percentage}%</span>
        </div>
        <div class="w-full bg-gray-200 rounded-full h-2">
          <div class="bg-indigo-600 h-2 rounded-full transition-all duration-500" style="width: ${percentage}%"></div>
        </div>
      `
      
      container.appendChild(barContainer)
    })
  }

  renderTrendsChart() {
    const container = this.trendsChart.element
    const data = this.trendsChart.data

    container.innerHTML = ''

    if (!data || data.length === 0) {
      container.innerHTML = '<p class="text-gray-500 text-center py-4">No trends data available</p>'
      return
    }

    // Simple trend visualization
    const trendsHtml = data.map(trend => `
      <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg mb-2">
        <div>
          <span class="text-sm font-medium text-gray-900">${trend.metric}</span>
          <p class="text-xs text-gray-500">${trend.period}</p>
        </div>
        <div class="flex items-center">
          <span class="text-sm font-medium ${trend.change >= 0 ? 'text-green-600' : 'text-red-600'}">
            ${trend.change >= 0 ? '+' : ''}${trend.change}%
          </span>
          <svg class="w-4 h-4 ml-1 ${trend.change >= 0 ? 'text-green-500' : 'text-red-500'}" 
               fill="none" stroke="currentColor" viewBox="0 0 24 24">
            ${trend.change >= 0 ? 
              '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 14l9-9 3 3" />' :
              '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 10l-9 9-3-3" />'
            }
          </svg>
        </div>
      </div>
    `).join('')

    container.innerHTML = trendsHtml
  }

  renderComparisonChart() {
    const container = this.comparisonChart.element
    const data = this.comparisonChart.data

    container.innerHTML = ''

    if (!data || data.length === 0) {
      container.innerHTML = '<p class="text-gray-500 text-center py-4">No comparison data available</p>'
      return
    }

    // Simple comparison bars
    const maxValue = Math.max(...data.map(d => d.value))
    
    const comparisonHtml = data.map(item => {
      const percentage = Math.round((item.value / maxValue) * 100)
      
      return `
        <div class="mb-4">
          <div class="flex justify-between items-center mb-2">
            <span class="text-sm font-medium text-gray-700">${item.label}</span>
            <span class="text-sm text-gray-500">${item.value}</span>
          </div>
          <div class="w-full bg-gray-200 rounded-full h-3">
            <div class="bg-blue-600 h-3 rounded-full transition-all duration-500" 
                 style="width: ${percentage}%"></div>
          </div>
        </div>
      `
    }).join('')

    container.innerHTML = comparisonHtml
  }

  // Panel Updates
  updateAnalysisResultsPanel(results) {
    if (!this.hasAnalysisResultsTarget) {return}

    const summaryHtml = `
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="bg-blue-50 p-4 rounded-lg">
            <h4 class="text-sm font-medium text-blue-900">Brand Consistency</h4>
            <p class="text-2xl font-bold text-blue-600">${Math.round((results.consistency_score || 0) * 100)}%</p>
          </div>
          <div class="bg-green-50 p-4 rounded-lg">
            <h4 class="text-sm font-medium text-green-900">Asset Quality</h4>
            <p class="text-2xl font-bold text-green-600">${Math.round((results.quality_score || 0) * 100)}%</p>
          </div>
        </div>
        
        <div class="border-t pt-4">
          <h4 class="text-sm font-medium text-gray-900 mb-2">Key Findings</h4>
          <ul class="space-y-1">
            ${(results.key_findings || []).map(finding => 
              `<li class="text-sm text-gray-600">• ${finding}</li>`
            ).join('')}
          </ul>
        </div>
      </div>
    `

    this.analysisResultsTarget.innerHTML = summaryHtml
  }

  updateInsightsPanel(insights) {
    if (!this.hasInsightsPanelTarget || !insights) {return}

    const insightsHtml = insights.map(insight => `
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-3">
        <div class="flex items-start">
          <svg class="w-5 h-5 text-yellow-400 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
          <div class="ml-3">
            <h4 class="text-sm font-medium text-yellow-800">${insight.title}</h4>
            <p class="text-sm text-yellow-700 mt-1">${insight.description}</p>
            ${insight.impact ? `<p class="text-xs text-yellow-600 mt-2">Impact: ${insight.impact}</p>` : ''}
          </div>
        </div>
      </div>
    `).join('')

    this.insightsPanelTarget.innerHTML = insightsHtml
  }

  updateRecommendations(recommendations) {
    if (!this.hasRecommendationsPanelTarget || !recommendations) {return}

    const recommendationsHtml = recommendations.map((rec, index) => `
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-3">
        <div class="flex items-start">
          <span class="flex-shrink-0 w-6 h-6 bg-blue-100 text-blue-800 text-xs font-medium rounded-full flex items-center justify-center">
            ${index + 1}
          </span>
          <div class="ml-3">
            <h4 class="text-sm font-medium text-blue-900">${rec.title}</h4>
            <p class="text-sm text-blue-700 mt-1">${rec.description}</p>
            ${rec.priority ? `
              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium mt-2 ${
                rec.priority === 'high' ? 'bg-red-100 text-red-800' :
                rec.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                'bg-green-100 text-green-800'
              }">
                ${rec.priority} priority
              </span>
            ` : ''}
          </div>
        </div>
      </div>
    `).join('')

    this.recommendationsPanelTarget.innerHTML = recommendationsHtml
  }

  // Helper Methods
  showAnalysisInProgress() {
    const progressIndicators = this.element.querySelectorAll('.analysis-progress')
    progressIndicators.forEach(indicator => {
      indicator.classList.remove('hidden')
    })
  }

  hideAnalysisInProgress() {
    const progressIndicators = this.element.querySelectorAll('.analysis-progress')
    progressIndicators.forEach(indicator => {
      indicator.classList.add('hidden')
    })
  }

  updateConnectionStatus(connected) {
    if (this.hasStatusIndicatorTarget) {
      this.statusIndicatorTarget.className = `status-indicator w-3 h-3 rounded-full ${
        connected ? 'bg-green-500' : 'bg-red-500'
      }`
      
      const statusText = this.statusIndicatorTarget.parentElement.querySelector('.status-text')
      if (statusText) {
        statusText.textContent = connected ? 'Connected' : 'Disconnected'
        statusText.className = `status-text text-xs ${connected ? 'text-green-600' : 'text-red-600'}`
      }
    }
  }

  animateScoreChange(element, _newValue) {
    element.style.transform = 'scale(1.1)'
    element.style.transition = 'transform 0.2s ease'
    
    setTimeout(() => {
      element.style.transform = 'scale(1)'
    }, 200)
  }

  animateCountChange(element, newValue) {
    const currentValue = parseInt(element.textContent) || 0
    const increment = newValue > currentValue ? 1 : -1
    const step = Math.abs(newValue - currentValue) / 20
    
    let current = currentValue
    const timer = setInterval(() => {
      current += increment * step
      
      if ((increment > 0 && current >= newValue) || (increment < 0 && current <= newValue)) {
        current = newValue
        clearInterval(timer)
      }
      
      element.textContent = Math.round(current).toString()
    }, 50)
  }

  startTimeCountdown(duration) {
    if (!this.hasTimeRemainingTarget) {return}

    let remaining = duration
    
    this.countdownTimer = setInterval(() => {
      remaining -= 1000
      
      if (remaining <= 0) {
        clearInterval(this.countdownTimer)
        this.timeRemainingTarget.textContent = 'Completing...'
        return
      }
      
      const minutes = Math.floor(remaining / 60000)
      const seconds = Math.floor((remaining % 60000) / 1000)
      this.timeRemainingTarget.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`
    }, 1000)
  }

  // Auto-refresh functionality
  setupRefreshInterval() {
    if (!this.autoRefreshValue) {return}

    this.refreshTimer = setInterval(() => {
      this.refreshDashboard()
    }, this.refreshIntervalValue)
  }

  async refreshDashboard() {
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.disabled = true
      this.refreshButtonTarget.classList.add('animate-spin')
    }

    try {
      await this.loadInitialData()
    } catch (error) {
      console.error("Error refreshing dashboard:", error)
    } finally {
      if (this.hasRefreshButtonTarget) {
        this.refreshButtonTarget.disabled = false
        this.refreshButtonTarget.classList.remove('animate-spin')
      }
    }
  }

  // Action handlers
  triggerAnalysis() {
    if (this.subscription) {
      this.subscription.perform("trigger_analysis", {
        brand_id: this.brandIdValue,
        force_refresh: true
      })
    }
  }

  toggleAutoRefresh() {
    this.autoRefreshValue = !this.autoRefreshValue
    
    if (this.autoRefreshValue) {
      this.setupRefreshInterval()
    } else if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  showError(message) {
    // Create a toast notification for errors
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg bg-red-100 text-red-800 border border-red-200 transition-all duration-300 transform translate-x-full opacity-0'
    
    notification.innerHTML = `
      <div class="flex items-center">
        <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <p class="text-sm font-medium">${message}</p>
        <button onclick="this.parentElement.parentElement.remove()" class="ml-4 hover:opacity-75">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full', 'opacity-0')
    }, 10)
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      notification.classList.add('translate-x-full', 'opacity-0')
      setTimeout(() => {
        if (notification.parentElement) {
          notification.remove()
        }
      }, 300)
    }, 5000)
  }
}