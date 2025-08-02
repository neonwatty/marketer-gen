import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["complianceModal", "complianceScore", "violationsList", "suggestionsPanel", "complianceInput", "progressBar", "analysisResults"]
  static values = { brandId: Number, sessionId: String }

  connect() {
    console.log("Brand compliance controller connected")
    this.initializeWebSocket()
    this.activeTab = "dashboard"
    this.complianceResults = null
    this.violations = []
    this.isChecking = false
    
    // Generate session ID if not provided
    if (!this.sessionIdValue) {
      this.sessionIdValue = this.generateSessionId()
    }
    
    this.setupKeyboardShortcuts()
  }

  disconnect() {
    console.log("Brand compliance controller disconnected")
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  // WebSocket Integration
  initializeWebSocket() {
    if (!this.brandIdValue) {
      console.error("Brand ID not found for compliance channel")
      return
    }

    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: "BrandComplianceChannel",
        brand_id: this.brandIdValue,
        session_id: this.sessionIdValue
      },
      {
        connected: this.channelConnected.bind(this),
        disconnected: this.channelDisconnected.bind(this),
        received: this.channelReceived.bind(this)
      }
    )
  }

  channelConnected() {
    console.log("Connected to brand compliance channel")
    this.showNotification("Connected to real-time brand compliance", "success")
  }

  channelDisconnected() {
    console.log("Disconnected from brand compliance channel")
    this.showNotification("Disconnected from real-time compliance", "warning")
  }

  channelReceived(data) {
    console.log("Received compliance data:", data)
    
    switch (data.event) {
      case "subscription_confirmed":
        this.handleSubscriptionConfirmed(data)
        break
      case "check_started":
        this.handleCheckStarted(data)
        break
      case "check_complete":
        this.handleCheckComplete(data)
        break
      case "check_progress":
        this.handleCheckProgress(data)
        break
      case "aspect_validated":
        this.handleAspectValidated(data)
        break
      case "fix_preview":
        this.handleFixPreview(data)
        break
      case "suggestions_generated":
        this.handleSuggestionsGenerated(data)
        break
      case "error":
        this.handleError(data)
        break
      default:
        console.log("Unknown event received:", data.event)
    }
  }

  // Tab Management
  switchTab(event) {
    const targetTab = event.currentTarget.dataset.tab
    this.activateTab(targetTab)
  }

  switchTabMobile(event) {
    const targetTab = event.target.value
    this.activateTab(targetTab)
  }

  activateTab(tabName) {
    // Update active tab
    this.activeTab = tabName
    
    // Update tab buttons
    const tabButtons = this.element.querySelectorAll(".tab-button")
    tabButtons.forEach(button => {
      const isActive = button.dataset.tab === tabName
      button.classList.toggle("active", isActive)
      button.classList.toggle("border-indigo-500", isActive)
      button.classList.toggle("text-indigo-600", isActive)
      button.classList.toggle("border-transparent", !isActive)
      button.classList.toggle("text-gray-500", !isActive)
    })
    
    // Update tab content
    const tabPanes = this.element.querySelectorAll(".tab-pane")
    tabPanes.forEach(pane => {
      const isActive = pane.dataset.tabContent === tabName
      pane.classList.toggle("active", isActive)
      pane.classList.toggle("hidden", !isActive)
    })
    
    // Trigger tab-specific initialization
    this.initializeTabContent(tabName)
  }

  initializeTabContent(tabName) {
    switch (tabName) {
      case "dashboard":
        this.refreshDashboard()
        break
      case "assets":
        this.initializeAssetManagement()
        break
      case "analysis":
        this.refreshAnalysisResults()
        break
      case "messaging":
        this.initializeMessagingFramework()
        break
      case "compliance":
        this.initializeComplianceChecker()
        break
    }
  }

  // Compliance Modal Management
  openComplianceChecker() {
    if (this.hasComplianceModalTarget) {
      this.complianceModalTarget.classList.remove("hidden")
      document.body.style.overflow = 'hidden'
      
      // Focus on the input field
      const input = this.complianceModalTarget.querySelector('[data-brand-compliance-target="complianceInput"]')
      if (input) {
        setTimeout(() => input.focus(), 100)
      }
      
      this.initializeComplianceChecker()
    }
  }

  closeComplianceChecker() {
    if (this.hasComplianceModalTarget) {
      this.complianceModalTarget.classList.add("hidden")
      document.body.style.overflow = ''
      
      // Clear any ongoing checks
      this.resetComplianceChecker()
    }
  }

  // Real-time Compliance Checking
  checkCompliance(event) {
    const content = event.target.value.trim()
    
    if (content.length < 10) {
      this.clearComplianceResults()
      return
    }
    
    // Debounce the compliance check
    clearTimeout(this.complianceTimeout)
    this.complianceTimeout = setTimeout(() => {
      this.performComplianceCheck(content)
    }, 500)
  }

  performComplianceCheck(content, options = {}) {
    if (this.isChecking) {
      return
    }
    
    this.isChecking = true
    this.showProgressBar()
    
    const checkData = {
      content,
      content_type: options.content_type || "general",
      compliance_level: options.compliance_level || "standard",
      generate_suggestions: options.generate_suggestions !== false,
      async: content.length > 1000 // Use async for longer content
    }
    
    if (this.subscription) {
      this.subscription.perform("check_compliance", checkData)
    }
  }

  validateAspect(aspect, content) {
    if (this.subscription) {
      this.subscription.perform("validate_aspect", {
        aspect,
        content
      })
    }
  }

  previewFix(violationId, content) {
    if (this.subscription) {
      this.subscription.perform("preview_fix", {
        violation_id: violationId,
        content
      })
    }
  }

  getSuggestions(violationIds) {
    if (this.subscription) {
      this.subscription.perform("get_suggestions", {
        violation_ids: violationIds
      })
    }
  }

  // Event Handlers
  handleSubscriptionConfirmed(data) {
    console.log("Subscription confirmed for brand:", data.brand_id)
  }

  handleCheckStarted(data) {
    this.showProgressBar()
    this.updateProgressBar(10)
    this.showNotification(`Compliance check started (${data.mode} mode)`, "info")
  }

  handleCheckComplete(data) {
    this.isChecking = false
    this.hideProgressBar()
    this.complianceResults = data.results
    this.violations = data.results.violations || []
    
    this.displayComplianceResults(data.results)
    this.showNotification("Compliance check completed", "success")
  }

  handleCheckProgress(data) {
    this.updateProgressBar(data.progress || 50)
    if (data.stage) {
      this.updateProgressStage(data.stage)
    }
  }

  handleAspectValidated(data) {
    this.displayAspectResult(data.aspect, data.result)
  }

  handleFixPreview(data) {
    this.displayFixPreview(data.violation_id, data.fix)
  }

  handleSuggestionsGenerated(data) {
    this.displaySuggestions(data.suggestions)
  }

  handleError(data) {
    this.isChecking = false
    this.hideProgressBar()
    this.showNotification(data.message, "error")
  }

  // UI Update Methods
  displayComplianceResults(results) {
    if (this.hasComplianceScoreTarget) {
      this.updateComplianceScore(results.score, results.compliant)
    }
    
    if (this.hasViolationsListTarget) {
      this.updateViolationsList(results.violations || [])
    }
    
    if (this.hasSuggestionsPanelTarget) {
      this.updateSuggestionsPanel(results.suggestions || [])
    }
    
    // Update analysis results tab if active
    if (this.activeTab === "analysis" && this.hasAnalysisResultsTarget) {
      this.updateAnalysisDisplay(results)
    }
  }

  updateComplianceScore(score, isCompliant) {
    if (!this.hasComplianceScoreTarget) {return}
    
    const scoreElement = this.complianceScoreTarget
    const percentage = Math.round(score * 100)
    
    scoreElement.textContent = `${percentage}%`
    scoreElement.className = `text-2xl font-bold ${isCompliant ? 'text-green-600' : 'text-red-600'}`
    
    // Update progress circle if present
    const progressCircle = scoreElement.parentElement.querySelector('.progress-circle')
    if (progressCircle) {
      this.updateProgressCircle(progressCircle, percentage, isCompliant)
    }
  }

  updateViolationsList(violations) {
    if (!this.hasViolationsListTarget) {return}
    
    const container = this.violationsListTarget
    container.innerHTML = ''
    
    if (violations.length === 0) {
      container.innerHTML = `
        <div class="text-center py-8 text-gray-500">
          <svg class="mx-auto h-12 w-12 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <p class="mt-2">No brand compliance violations found!</p>
        </div>
      `
      return
    }
    
    violations.forEach((violation, index) => {
      const violationElement = this.createViolationElement(violation, index)
      container.appendChild(violationElement)
    })
  }

  createViolationElement(violation, _index) {
    const div = document.createElement('div')
    div.className = 'bg-red-50 border border-red-200 rounded-lg p-4 mb-3'
    div.innerHTML = `
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
        </div>
        <div class="ml-3 flex-1">
          <h4 class="text-sm font-medium text-red-800">${violation.type} Violation</h4>
          <p class="text-sm text-red-700 mt-1">${violation.message}</p>
          ${violation.suggestion ? `<p class="text-xs text-red-600 mt-2 italic">Suggestion: ${violation.suggestion}</p>` : ''}
          <div class="mt-3 flex space-x-2">
            <button data-action="click->brand-compliance#previewViolationFix" 
                    data-violation-id="${violation.id}"
                    class="text-xs bg-red-100 hover:bg-red-200 text-red-800 px-2 py-1 rounded transition-colors">
              Preview Fix
            </button>
            <button data-action="click->brand-compliance#ignoreViolation" 
                    data-violation-id="${violation.id}"
                    class="text-xs bg-gray-100 hover:bg-gray-200 text-gray-800 px-2 py-1 rounded transition-colors">
              Ignore
            </button>
          </div>
        </div>
      </div>
    `
    return div
  }

  updateSuggestionsPanel(suggestions) {
    if (!this.hasSuggestionsPanelTarget) {return}
    
    const container = this.suggestionsPanelTarget
    container.innerHTML = ''
    
    if (suggestions.length === 0) {
      container.innerHTML = `
        <div class="text-center py-4 text-gray-500">
          <p>No suggestions available</p>
        </div>
      `
      return
    }
    
    suggestions.forEach(suggestion => {
      const suggestionElement = this.createSuggestionElement(suggestion)
      container.appendChild(suggestionElement)
    })
  }

  createSuggestionElement(suggestion) {
    const div = document.createElement('div')
    div.className = 'bg-blue-50 border border-blue-200 rounded-lg p-3 mb-2'
    div.innerHTML = `
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <svg class="h-4 w-4 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
        </div>
        <div class="ml-2 flex-1">
          <p class="text-sm text-blue-800">${suggestion.text}</p>
          ${suggestion.action ? `
            <button data-action="click->brand-compliance#applySuggestion" 
                    data-suggestion='${JSON.stringify(suggestion)}'
                    class="text-xs bg-blue-100 hover:bg-blue-200 text-blue-800 px-2 py-1 rounded mt-2 transition-colors">
              Apply Suggestion
            </button>
          ` : ''}
        </div>
      </div>
    `
    return div
  }

  // Progress and Loading States
  showProgressBar() {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.remove("hidden")
      this.updateProgressBar(0)
    }
  }

  hideProgressBar() {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.add("hidden")
    }
  }

  updateProgressBar(percentage) {
    if (!this.hasProgressBarTarget) {return}
    
    const progressFill = this.progressBarTarget.querySelector('.progress-fill')
    if (progressFill) {
      progressFill.style.width = `${percentage}%`
    }
    
    const progressText = this.progressBarTarget.querySelector('.progress-text')
    if (progressText) {
      progressText.textContent = `${percentage}%`
    }
  }

  updateProgressStage(stage) {
    const stageElement = this.element.querySelector('.progress-stage')
    if (stageElement) {
      stageElement.textContent = stage
    }
  }

  // Dashboard Methods
  refreshDashboard() {
    // Refresh dashboard statistics and charts
    this.updateDashboardStats()
    this.updateBrandHealthChart()
  }

  updateDashboardStats() {
    // Update real-time dashboard statistics
    const statsElements = this.element.querySelectorAll('[data-stat]')
    statsElements.forEach(element => {
      const stat = element.dataset.stat
      this.fetchStatValue(stat).then(value => {
        element.textContent = value
      })
    })
  }

  async fetchStatValue(stat) {
    try {
      const response = await fetch(`/api/v1/brands/${this.brandIdValue}/stats/${stat}`)
      const data = await response.json()
      return data.value
    } catch (error) {
      console.error(`Error fetching stat ${stat}:`, error)
      return 'N/A'
    }
  }

  // Asset Management Methods
  initializeAssetManagement() {
    // Initialize asset upload and management features
    this.refreshAssetList()
  }

  refreshAssetList() {
    // Refresh the brand assets list
    const assetContainer = this.element.querySelector('[data-asset-list]')
    if (assetContainer) {
      // This would typically fetch and update the asset list
      console.log("Refreshing asset list")
    }
  }

  // Analysis Results Methods
  refreshAnalysisResults() {
    if (this.complianceResults) {
      this.updateAnalysisDisplay(this.complianceResults)
    }
  }

  updateAnalysisDisplay(results) {
    // Update the analysis results display with charts and insights
    console.log("Updating analysis display with:", results)
  }

  // Messaging Framework Methods
  initializeMessagingFramework() {
    // Initialize messaging framework editor and validation
    console.log("Initializing messaging framework")
  }

  // Compliance Checker Methods
  initializeComplianceChecker() {
    // Initialize real-time compliance checker
    this.clearComplianceResults()
    
    // Set up input handlers
    const input = this.element.querySelector('[data-brand-compliance-target="complianceInput"]')
    if (input) {
      input.addEventListener('input', this.checkCompliance.bind(this))
      input.addEventListener('paste', (event) => {
        setTimeout(() => this.checkCompliance(event), 10)
      })
    }
  }

  resetComplianceChecker() {
    this.isChecking = false
    this.complianceResults = null
    this.violations = []
    
    clearTimeout(this.complianceTimeout)
    this.hideProgressBar()
    this.clearComplianceResults()
  }

  clearComplianceResults() {
    if (this.hasComplianceScoreTarget) {
      this.complianceScoreTarget.textContent = '--'
      this.complianceScoreTarget.className = 'text-2xl font-bold text-gray-400'
    }
    
    if (this.hasViolationsListTarget) {
      this.violationsListTarget.innerHTML = `
        <div class="text-center py-8 text-gray-400">
          <p>Type content above to check brand compliance</p>
        </div>
      `
    }
    
    if (this.hasSuggestionsPanelTarget) {
      this.suggestionsPanelTarget.innerHTML = ''
    }
  }

  // Action Handlers
  previewViolationFix(event) {
    const violationId = event.currentTarget.dataset.violationId
    const content = this.element.querySelector('[data-brand-compliance-target="complianceInput"]')?.value
    
    if (violationId && content) {
      this.previewFix(violationId, content)
    }
  }

  ignoreViolation(event) {
    const violationId = event.currentTarget.dataset.violationId
    const violationElement = event.currentTarget.closest('.bg-red-50')
    
    if (violationElement) {
      violationElement.style.opacity = '0.5'
      violationElement.style.pointerEvents = 'none'
    }
    
    // Remove from violations array
    this.violations = this.violations.filter(v => v.id !== violationId)
  }

  applySuggestion(event) {
    const suggestion = JSON.parse(event.currentTarget.dataset.suggestion)
    const input = this.element.querySelector('[data-brand-compliance-target="complianceInput"]')
    
    if (input && suggestion.replacement) {
      input.value = suggestion.replacement
      input.dispatchEvent(new Event('input', { bubbles: true }))
    }
  }

  // Utility Methods
  generateSessionId() {
    return `compliance_${  Date.now()  }_${  Math.random().toString(36).substr(2, 9)}`
  }

  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (event) => {
      // Escape key closes compliance modal
      if (event.key === 'Escape' && !this.complianceModalTarget.classList.contains('hidden')) {
        this.closeComplianceChecker()
      }
      
      // Ctrl/Cmd + Enter triggers compliance check
      if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
        const input = this.element.querySelector('[data-brand-compliance-target="complianceInput"]')
        if (input && input.value.trim()) {
          this.performComplianceCheck(input.value.trim(), { force: true })
        }
      }
    })
  }

  showNotification(message, type = "info") {
    // Create a toast notification
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg transition-all duration-300 transform translate-x-full opacity-0 ${
      type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' :
      type === 'error' ? 'bg-red-100 text-red-800 border border-red-200' :
      type === 'warning' ? 'bg-yellow-100 text-yellow-800 border border-yellow-200' :
      'bg-blue-100 text-blue-800 border border-blue-200'
    }`
    
    notification.innerHTML = `
      <div class="flex items-center">
        <div class="flex-shrink-0">
          ${type === 'success' ? 
            '<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>' :
            type === 'error' ?
            '<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>' :
            '<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'
          }
        </div>
        <div class="ml-3">
          <p class="text-sm font-medium">${message}</p>
        </div>
        <div class="ml-auto pl-3">
          <button onclick="this.parentElement.parentElement.remove()" class="text-current hover:opacity-75">
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
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

  updateProgressCircle(circle, percentage, isCompliant) {
    const circumference = 2 * Math.PI * 45 // radius = 45
    const strokeDasharray = circumference
    const strokeDashoffset = circumference - (percentage / 100) * circumference
    
    circle.style.strokeDasharray = strokeDasharray
    circle.style.strokeDashoffset = strokeDashoffset
    circle.style.stroke = isCompliant ? '#10b981' : '#ef4444'
  }

  displayFixPreview(violationId, fix) {
    // Find the violation element and show fix preview
    const violationElement = this.element.querySelector(`[data-violation-id="${violationId}"]`)?.closest('.bg-red-50')
    if (violationElement && fix) {
      const previewElement = document.createElement('div')
      previewElement.className = 'mt-3 p-3 bg-green-50 border border-green-200 rounded'
      previewElement.innerHTML = `
        <h5 class="text-sm font-medium text-green-800">Suggested Fix:</h5>
        <p class="text-sm text-green-700 mt-1">${fix.text || fix}</p>
        <button data-action="click->brand-compliance#applyFix" 
                data-fix='${JSON.stringify(fix)}'
                class="text-xs bg-green-100 hover:bg-green-200 text-green-800 px-2 py-1 rounded mt-2 transition-colors">
          Apply Fix
        </button>
      `
      
      // Remove existing preview
      const existingPreview = violationElement.querySelector('.bg-green-50')
      if (existingPreview) {
        existingPreview.remove()
      }
      
      violationElement.appendChild(previewElement)
    }
  }

  displaySuggestions(suggestions) {
    if (this.hasSuggestionsPanelTarget) {
      this.updateSuggestionsPanel(suggestions)
    }
  }

  applyFix(event) {
    const fix = JSON.parse(event.currentTarget.dataset.fix)
    const input = this.element.querySelector('[data-brand-compliance-target="complianceInput"]')
    
    if (input && fix.replacement) {
      // Apply the fix to the input
      if (fix.start !== undefined && fix.end !== undefined) {
        const currentValue = input.value
        const newValue = currentValue.substring(0, fix.start) + fix.replacement + currentValue.substring(fix.end)
        input.value = newValue
      } else {
        input.value = fix.replacement
      }
      
      input.dispatchEvent(new Event('input', { bubbles: true }))
      this.showNotification("Fix applied successfully", "success")
    }
  }
}