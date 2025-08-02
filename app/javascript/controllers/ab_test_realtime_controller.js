import { Controller } from "@hotwired/stimulus"
import { getCollaborationWebSocket } from "../utils/collaborationWebSocket"
import { getPresenceSystem } from "../utils/presenceSystem"

export default class extends Controller {
  static targets = [
    "testStatus",
    "metricsContainer", 
    "variantCard",
    "alertsContainer",
    "monitorsList",
    "winnerBanner",
    "progressBar",
    "chartContainer",
    "trafficSlider",
    "pauseButton",
    "stopButton",
    "loadingOverlay"
  ]
  
  static values = {
    abTestId: Number,
    currentUser: Object,
    autoRefreshInterval: { type: Number, default: 30000 },
    chartType: { type: String, default: 'line' }
  }

  connect() {
    console.log("A/B Test real-time monitoring controller connected")
    
    this.websocket = getCollaborationWebSocket()
    this.presenceSystem = getPresenceSystem()
    this.subscription = null
    this.metricsHistory = new Map()
    this.chartInstances = new Map()
    this.autoRefreshTimer = null
    this.isUpdating = false
    this.alertSounds = new Map()
    
    this.setupCollaboration()
    this.setupPresenceSystem()
    this.setupEventListeners()
    this.initializeCharts()
    this.startAutoRefresh()
  }

  disconnect() {
    console.log("A/B Test real-time monitoring controller disconnected")
    
    if (this.subscription) {
      this.websocket.unsubscribe(this.subscription.identifier)
    }
    
    this.presenceSystem.destroy()
    this.cleanup()
  }

  setupCollaboration() {
    this.subscription = this.websocket.subscribe(
      'AbTestMonitoringChannel',
      { ab_test_id: this.abTestIdValue }
    )

    // Set up message handlers
    this.websocket.on('test:metric_updated', (data) => this.handleMetricUpdate(data))
    this.websocket.on('test:status_changed', (data) => this.handleStatusChange(data))
    this.websocket.on('test:alert', (data) => this.handleAlert(data))
    this.websocket.on('test:winner_declared', (data) => this.handleWinnerDeclared(data))
    this.websocket.on('user:joined', (data) => this.handleUserJoined(data))
    this.websocket.on('user:left', (data) => this.handleUserLeft(data))
  }

  setupPresenceSystem() {
    this.presenceSystem.initialize(
      this.currentUserValue,
      `ab_test_${this.abTestIdValue}`
    )

    this.presenceSystem.setCallbacks({
      onUserJoined: (_presence) => this.updateMonitorsList(),
      onUserLeft: (_presence) => this.updateMonitorsList(),
      onUserStatusChanged: (_presence) => this.updateMonitorsList()
    })
  }

  setupEventListeners() {
    // Test control buttons
    this.pauseButtonTargets.forEach(btn => {
      btn.addEventListener('click', () => this.pauseTest())
    })
    
    this.stopButtonTargets.forEach(btn => {
      btn.addEventListener('click', () => this.stopTest())
    })

    // Traffic allocation sliders
    this.trafficSliderTargets.forEach(slider => {
      slider.addEventListener('input', this.debounce((e) => {
        this.handleTrafficChange(e)
      }, 1000))
    })

    // Chart type toggles
    document.addEventListener('click', (e) => {
      if (e.target.matches('[data-chart-toggle]')) {
        this.toggleChartType(e.target.dataset.chartToggle)
      }
    })

    // Alert acknowledgment
    document.addEventListener('click', (e) => {
      if (e.target.matches('[data-acknowledge-alert]')) {
        this.acknowledgeAlert(e.target.dataset.acknowledgeAlert)
      }
    })
  }

  initializeCharts() {
    this.variantCardTargets.forEach(card => {
      const variantId = card.dataset.variantId
      const chartContainer = card.querySelector('[data-chart]')
      
      if (chartContainer) {
        this.createChart(variantId, chartContainer)
      }
    })
  }

  createChart(variantId, container) {
    // Simple chart implementation - in production, use Chart.js or similar
    const chartData = this.metricsHistory.get(variantId) || []
    
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    svg.setAttribute('width', '100%')
    svg.setAttribute('height', '200')
    svg.classList.add('metrics-chart')
    
    container.innerHTML = ''
    container.appendChild(svg)
    
    this.chartInstances.set(variantId, { svg, container, data: chartData })
    this.updateChart(variantId)
  }

  updateChart(variantId) {
    const chart = this.chartInstances.get(variantId)
    if (!chart) {return}

    const data = this.metricsHistory.get(variantId) || []
    if (data.length < 2) {return}

    const svg = chart.svg
    const width = svg.clientWidth || 300
    const height = 200
    const margin = { top: 20, right: 20, bottom: 30, left: 40 }

    // Clear previous chart
    svg.innerHTML = ''

    // Create scales
    const maxValue = Math.max(...data.map(d => d.conversion_rate))
    const minValue = Math.min(...data.map(d => d.conversion_rate))
    
    const xScale = (index) => margin.left + (index / (data.length - 1)) * (width - margin.left - margin.right)
    const yScale = (value) => height - margin.bottom - ((value - minValue) / (maxValue - minValue || 1)) * (height - margin.top - margin.bottom)

    // Draw line
    const pathData = data.map((d, i) => 
      `${i === 0 ? 'M' : 'L'} ${xScale(i)} ${yScale(d.conversion_rate)}`
    ).join(' ')

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    path.setAttribute('d', pathData)
    path.setAttribute('stroke', '#3b82f6')
    path.setAttribute('stroke-width', '2')
    path.setAttribute('fill', 'none')
    
    svg.appendChild(path)

    // Draw points
    data.forEach((d, i) => {
      const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle')
      circle.setAttribute('cx', xScale(i))
      circle.setAttribute('cy', yScale(d.conversion_rate))
      circle.setAttribute('r', '3')
      circle.setAttribute('fill', '#3b82f6')
      
      // Add tooltip
      circle.addEventListener('mouseenter', (e) => {
        this.showTooltip(e, `${d.conversion_rate.toFixed(2)}% at ${d.timestamp}`)
      })
      
      svg.appendChild(circle)
    })
  }

  startAutoRefresh() {
    if (this.autoRefreshTimer) {
      clearInterval(this.autoRefreshTimer)
    }

    this.autoRefreshTimer = setInterval(() => {
      this.requestMetricsUpdate()
    }, this.autoRefreshIntervalValue)
  }

  async requestMetricsUpdate() {
    if (this.isUpdating) {return}

    try {
      await this.websocket.sendMessage({
        id: this.generateMessageId(),
        type: 'request_metrics_update',
        channel: 'ab_test_monitoring',
        data: {
          ab_test_id: this.abTestIdValue
        },
        timestamp: new Date().toISOString(),
        retry_count: 0,
        max_retries: 2
      })
    } catch (error) {
      console.error('Failed to request metrics update:', error)
    }
  }

  handleMetricUpdate(data) {
    console.log('Received metrics update:', data)
    
    this.isUpdating = true
    
    try {
      // Update test status
      this.updateTestStatus(data.test_data)
      
      // Update variant metrics
      data.variants.forEach(variant => {
        this.updateVariantCard(variant)
        this.updateMetricsHistory(variant)
      })
      
      // Update overall metrics
      this.updateOverallMetrics(data.metrics)
      
      // Process alerts
      if (data.metrics.alerts) {
        data.metrics.alerts.forEach(alert => {
          this.handleAlert({ alert })
        })
      }
      
      // Update charts
      this.updateAllCharts()
      
      // Update progress bar
      this.updateProgressBar(data.test_data.progress_percentage)
      
    } catch (error) {
      console.error('Error handling metrics update:', error)
    } finally {
      this.isUpdating = false
    }
  }

  updateTestStatus(testData) {
    this.testStatusTargets.forEach(element => {
      element.textContent = testData.status
      element.className = `test-status status-${testData.status}`
    })
  }

  updateVariantCard(variantData) {
    const card = this.variantCardTargets.find(card => 
      card.dataset.variantId === variantData.variant_id.toString()
    )
    
    if (!card) {return}

    // Update metrics display
    const visitorsElement = card.querySelector('[data-metric="visitors"]')
    const conversionsElement = card.querySelector('[data-metric="conversions"]')
    const rateElement = card.querySelector('[data-metric="conversion_rate"]')
    const changeElement = card.querySelector('[data-metric="change"]')
    
    if (visitorsElement) {
      visitorsElement.textContent = this.formatNumber(variantData.current_visitors)
      this.animateValueChange(visitorsElement, variantData.change_since_last_update.visitors_change)
    }
    
    if (conversionsElement) {
      conversionsElement.textContent = this.formatNumber(variantData.current_conversions)
      this.animateValueChange(conversionsElement, variantData.change_since_last_update.conversions_change)
    }
    
    if (rateElement) {
      rateElement.textContent = `${variantData.current_conversion_rate.toFixed(2)}%`
      this.animateValueChange(rateElement, variantData.change_since_last_update.conversion_rate_change)
    }
    
    if (changeElement) {
      const change = variantData.change_since_last_update.conversion_rate_change
      changeElement.textContent = `${change >= 0 ? '+' : ''}${change.toFixed(2)}%`
      changeElement.className = `metric-change ${change >= 0 ? 'positive' : 'negative'}`
    }

    // Update confidence interval
    const confidenceElement = card.querySelector('[data-metric="confidence"]')
    if (confidenceElement && variantData.confidence_interval) {
      const [lower, upper] = variantData.confidence_interval
      confidenceElement.textContent = `${lower.toFixed(1)}% - ${upper.toFixed(1)}%`
    }

    // Update statistical significance
    const significanceElement = card.querySelector('[data-metric="significance"]')
    if (significanceElement && variantData.statistical_significance !== undefined) {
      significanceElement.textContent = `${variantData.statistical_significance.toFixed(1)}%`
      significanceElement.className = `significance ${variantData.statistical_significance >= 95 ? 'significant' : 'not-significant'}`
    }
  }

  updateMetricsHistory(variantData) {
    const variantId = variantData.variant_id
    const history = this.metricsHistory.get(variantId) || []
    
    // Add new data point
    history.push({
      timestamp: new Date().toISOString(),
      visitors: variantData.current_visitors,
      conversions: variantData.current_conversions,
      conversion_rate: variantData.current_conversion_rate
    })
    
    // Keep only last 50 data points
    if (history.length > 50) {
      history.shift()
    }
    
    this.metricsHistory.set(variantId, history)
  }

  updateOverallMetrics(metrics) {
    const container = this.metricsContainerTarget
    if (!container) {return}

    // Update overall statistics
    const overallStats = container.querySelector('[data-overall-stats]')
    if (overallStats) {
      overallStats.innerHTML = `
        <div class="stat-item">
          <label>Total Visitors</label>
          <span class="stat-value">${this.formatNumber(metrics.overall_visitors)}</span>
        </div>
        <div class="stat-item">
          <label>Total Conversions</label>
          <span class="stat-value">${this.formatNumber(metrics.overall_conversions)}</span>
        </div>
        <div class="stat-item">
          <label>Overall Rate</label>
          <span class="stat-value">${metrics.overall_conversion_rate.toFixed(2)}%</span>
        </div>
        <div class="stat-item">
          <label>Duration</label>
          <span class="stat-value">${metrics.test_duration_hours.toFixed(1)}h</span>
        </div>
      `
    }
  }

  updateAllCharts() {
    this.chartInstances.forEach((chart, variantId) => {
      this.updateChart(variantId)
    })
  }

  updateProgressBar(percentage) {
    this.progressBarTargets.forEach(bar => {
      const fill = bar.querySelector('.progress-fill')
      if (fill) {
        fill.style.width = `${Math.min(percentage, 100)}%`
      }
      
      const text = bar.querySelector('.progress-text')
      if (text) {
        text.textContent = `${percentage.toFixed(1)}% Complete`
      }
    })
  }

  handleStatusChange(data) {
    console.log('Test status changed:', data)
    
    this.updateTestStatus(data.test_data)
    
    // Show notification
    this.showNotification(`Test status changed to: ${data.test_data.status}`)
    
    // Update button states
    this.updateControlButtons(data.test_data.status)
  }

  updateControlButtons(status) {
    this.pauseButtonTargets.forEach(btn => {
      btn.disabled = status !== 'running'
      btn.textContent = status === 'paused' ? 'Resume' : 'Pause'
    })
    
    this.stopButtonTargets.forEach(btn => {
      btn.disabled = !['running', 'paused'].includes(status)
    })
  }

  handleAlert(data) {
    console.log('Received alert:', data)
    
    const alert = data.alert
    this.showAlert(alert)
    
    // Play sound for important alerts
    if (alert.level === 'error' || alert.action_required) {
      this.playAlertSound(alert.level)
    }
  }

  showAlert(alert) {
    const container = this.alertsContainerTarget
    if (!container) {return}

    const alertElement = document.createElement('div')
    alertElement.className = `alert alert-${alert.level}`
    alertElement.innerHTML = `
      <div class="alert-icon">
        ${this.getAlertIcon(alert.level)}
      </div>
      <div class="alert-content">
        <div class="alert-message">${alert.message}</div>
        ${alert.variant_id ? `<div class="alert-variant">Variant: ${alert.variant_id}</div>` : ''}
        ${alert.action_required ? '<div class="alert-action">Action Required</div>' : ''}
      </div>
      <button class="alert-dismiss" data-acknowledge-alert="${Date.now()}">×</button>
    `
    
    container.appendChild(alertElement)
    
    // Auto-dismiss info alerts after 5 seconds
    if (alert.level === 'info') {
      setTimeout(() => {
        alertElement.remove()
      }, 5000)
    }
  }

  getAlertIcon(level) {
    const icons = {
      'info': 'ℹ️',
      'warning': '⚠️',
      'error': '❌',
      'success': '✅'
    }
    return icons[level] || '•'
  }

  acknowledgeAlert(alertId) {
    const alertElement = document.querySelector(`[data-acknowledge-alert="${alertId}"]`)?.closest('.alert')
    if (alertElement) {
      alertElement.remove()
    }
  }

  handleWinnerDeclared(data) {
    console.log('Winner declared:', data)
    
    this.showWinnerBanner(data.winner)
    this.playAlertSound('success')
    this.showNotification(`Winner declared: ${data.winner.name}!`)
  }

  showWinnerBanner(winner) {
    this.winnerBannerTargets.forEach(banner => {
      banner.classList.add('show')
      banner.innerHTML = `
        <div class="winner-content">
          <h3>🎉 Winner Declared!</h3>
          <p><strong>${winner.name}</strong> is the winning variant</p>
          <p>Conversion Rate: ${winner.conversion_rate.toFixed(2)}%</p>
          <p>Lift: +${winner.lift_percentage.toFixed(1)}%</p>
        </div>
      `
    })
  }

  handleUserJoined(data) {
    this.updateMonitorsList()
    this.showNotification(`${data.user.name} is now monitoring this test`)
  }

  handleUserLeft(_data) {
    this.updateMonitorsList()
  }

  updateMonitorsList() {
    if (!this.hasMonitorsListTarget) {return}

    const monitors = this.presenceSystem.getOnlineUsers()
    const list = this.monitorsListTarget
    
    list.innerHTML = monitors.map(presence => `
      <div class="monitor-item" data-user-id="${presence.user.id}">
        <img src="${presence.user.avatar_url || '/default-avatar.png'}" alt="" class="user-avatar">
        <span class="user-name">${presence.user.name}</span>
        <span class="monitor-status status-${presence.status}"></span>
      </div>
    `).join('')
  }

  async handleTrafficChange(event) {
    const slider = event.target
    const variantId = slider.dataset.variantId
    const newPercentage = parseFloat(slider.value)
    
    try {
      await this.websocket.sendMessage({
        id: this.generateMessageId(),
        type: 'update_traffic_allocation',
        channel: 'ab_test_monitoring',
        data: {
          variant_id: variantId,
          new_percentage: newPercentage
        },
        timestamp: new Date().toISOString(),
        retry_count: 0,
        max_retries: 2
      })
      
      this.showNotification(`Updated traffic allocation for variant ${variantId}`)
    } catch (error) {
      console.error('Failed to update traffic allocation:', error)
      this.showNotification('Failed to update traffic allocation', 'error')
    }
  }

  async pauseTest() {
    try {
      const response = await fetch(`/ab_tests/${this.abTestIdValue}/pause`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        }
      })
      
      if (response.ok) {
        this.showNotification('Test paused successfully')
      } else {
        throw new Error('Failed to pause test')
      }
    } catch (error) {
      console.error('Error pausing test:', error)
      this.showNotification('Failed to pause test', 'error')
    }
  }

  async stopTest() {
    if (!confirm('Are you sure you want to stop this test? This action cannot be undone.')) {
      return
    }
    
    try {
      const response = await fetch(`/ab_tests/${this.abTestIdValue}/complete`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        }
      })
      
      if (response.ok) {
        this.showNotification('Test completed successfully')
      } else {
        throw new Error('Failed to complete test')
      }
    } catch (error) {
      console.error('Error completing test:', error)
      this.showNotification('Failed to complete test', 'error')
    }
  }

  toggleChartType(chartType) {
    this.chartTypeValue = chartType
    
    // Recreate all charts with new type
    this.chartInstances.forEach((chart, variantId) => {
      this.createChart(variantId, chart.container)
    })
  }

  animateValueChange(element, change) {
    if (change === 0) {return}
    
    element.classList.remove('value-up', 'value-down')
    
    setTimeout(() => {
      element.classList.add(change > 0 ? 'value-up' : 'value-down')
      
      setTimeout(() => {
        element.classList.remove('value-up', 'value-down')
      }, 1000)
    }, 10)
  }

  playAlertSound(level) {
    // Simple beep - in production, use proper audio files
    if ('AudioContext' in window) {
      const audioContext = new AudioContext()
      const oscillator = audioContext.createOscillator()
      const gainNode = audioContext.createGain()
      
      oscillator.connect(gainNode)
      gainNode.connect(audioContext.destination)
      
      oscillator.frequency.value = level === 'error' ? 800 : 600
      gainNode.gain.setValueAtTime(0.1, audioContext.currentTime)
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.2)
      
      oscillator.start(audioContext.currentTime)
      oscillator.stop(audioContext.currentTime + 0.2)
    }
  }

  showNotification(message, type = 'info') {
    const toast = document.createElement('div')
    toast.className = `notification notification-${type}`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    setTimeout(() => toast.classList.add('show'), 100)
    setTimeout(() => {
      toast.classList.remove('show')
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  showTooltip(event, text) {
    const tooltip = document.createElement('div')
    tooltip.className = 'chart-tooltip'
    tooltip.textContent = text
    tooltip.style.cssText = `
      position: absolute;
      left: ${event.pageX + 10}px;
      top: ${event.pageY - 30}px;
      background: #333;
      color: white;
      padding: 5px 10px;
      border-radius: 4px;
      font-size: 12px;
      pointer-events: none;
      z-index: 1000;
    `
    
    document.body.appendChild(tooltip)
    
    setTimeout(() => tooltip.remove(), 2000)
  }

  formatNumber(num) {
    return new Intl.NumberFormat().format(num)
  }

  generateMessageId() {
    return `abtest_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  debounce(func, delay) {
    let timeoutId
    return (...args) => {
      clearTimeout(timeoutId)
      timeoutId = setTimeout(() => func.apply(this, args), delay)
    }
  }

  cleanup() {
    if (this.autoRefreshTimer) {
      clearInterval(this.autoRefreshTimer)
    }
    
    this.chartInstances.clear()
    this.metricsHistory.clear()
    this.alertSounds.clear()
  }
}