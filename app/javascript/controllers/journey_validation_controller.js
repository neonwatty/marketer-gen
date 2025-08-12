import { Controller } from "@hotwired/stimulus"

// Journey Validation Controller for displaying validation feedback and errors
export default class extends Controller {
  static targets = [
    "feedbackContainer", "validationSummary", "errorList", "warningList", 
    "successMessage", "validationProgress", "validateButton", "stageErrors",
    "criticalIssues", "recommendations", "validationDetails", "toggleDetails"
  ]

  static values = {
    journeyId: Number,
    autoValidate: { type: Boolean, default: false },
    validationTypes: { type: Array, default: ["completeness", "field_requirements", "business_rules"] },
    strictMode: { type: Boolean, default: false }
  }

  static classes = [
    "error", "warning", "success", "info", "loading", "hidden", "visible",
    "criticalIssue", "validationError", "validationWarning", "validationSuccess"
  ]

  connect() {
    this.validationResults = []
    this.validationInProgress = false
    this.setupEventListeners()
    
    if (this.autoValidateValue) {
      this.validateJourney()
    }
  }

  disconnect() {
    this.cleanup()
  }

  // Setup event listeners for validation triggers
  setupEventListeners() {
    // Listen for journey changes from builder
    document.addEventListener('journey:stageAdded', this.handleJourneyChange.bind(this))
    document.addEventListener('journey:stageRemoved', this.handleJourneyChange.bind(this))
    document.addEventListener('journey:stageUpdated', this.handleJourneyChange.bind(this))
    document.addEventListener('journey:stageReordered', this.handleJourneyChange.bind(this))
    
    // Listen for validation requests
    document.addEventListener('journey:validate', this.handleValidationRequest.bind(this))
  }

  // Handle journey changes for auto-validation
  handleJourneyChange(event) {
    if (this.autoValidateValue) {
      // Debounce validation to avoid excessive calls
      this.debounceValidation()
    }
  }

  // Handle explicit validation requests
  handleValidationRequest(event) {
    const options = event.detail || {}
    this.validateJourney(options)
  }

  // Debounced validation to avoid excessive API calls
  debounceValidation() {
    clearTimeout(this.validationTimeout)
    this.validationTimeout = setTimeout(() => {
      this.validateJourney({ silent: true })
    }, 1000)
  }

  // Main validation method
  async validateJourney(options = {}) {
    if (this.validationInProgress || !this.journeyIdValue) {
      return
    }

    this.validationInProgress = true
    this.showValidationProgress()

    try {
      const response = await fetch(`/journeys/${this.journeyIdValue}/validate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          validation_types: options.validationTypes || this.validationTypesValue,
          strict_mode: options.strictMode || this.strictModeValue,
          options: options
        })
      })

      if (!response.ok) {
        throw new Error(`Validation request failed: ${response.statusText}`)
      }

      const validationData = await response.json()
      this.handleValidationResults(validationData, options)
      
    } catch (error) {
      console.error('Journey validation error:', error)
      this.showValidationError(error.message)
    } finally {
      this.validationInProgress = false
      this.hideValidationProgress()
    }
  }

  // Handle validation results and update UI
  handleValidationResults(validationData, options = {}) {
    this.validationResults = validationData.validation_results || []
    
    // Update validation summary
    this.updateValidationSummary(validationData)
    
    // Update error and warning lists
    this.updateErrorList(validationData)
    this.updateWarningList(validationData)
    
    // Update recommendations
    this.updateRecommendations(validationData)
    
    // Show/hide appropriate feedback containers
    this.updateFeedbackVisibility(validationData)
    
    // Update stage-specific errors
    this.updateStageErrors(validationData)
    
    // Show success message if validation passed
    if (validationData.overall_status === 'pass') {
      this.showValidationSuccess(validationData)
    }
    
    // Dispatch validation complete event
    this.dispatchValidationEvent('validation:complete', {
      validationData: validationData,
      passed: validationData.overall_status === 'pass'
    })

    // Auto-hide success messages after delay
    if (!options.silent && validationData.overall_status === 'pass') {
      setTimeout(() => {
        this.hideValidationFeedback()
      }, 3000)
    }
  }

  // Update validation summary display
  updateValidationSummary(validationData) {
    if (!this.hasValidationSummaryTarget) return

    const summary = validationData.summary || 'Validation completed'
    const status = validationData.overall_status || 'unknown'
    const statusIcon = this.getStatusIcon(status)
    const statusColor = this.getStatusColor(status)

    this.validationSummaryTarget.innerHTML = `
      <div class="flex items-center space-x-3 p-4 rounded-lg ${statusColor}">
        <div class="flex-shrink-0">
          ${statusIcon}
        </div>
        <div class="flex-1">
          <h4 class="font-medium text-sm">${this.getStatusTitle(status)}</h4>
          <p class="text-sm mt-1">${summary}</p>
          ${this.renderValidationStats(validationData)}
        </div>
        ${this.hasToggleDetailsTarget ? this.renderToggleButton() : ''}
      </div>
    `
  }

  // Render validation statistics
  renderValidationStats(validationData) {
    const stats = []
    
    if (validationData.critical_issues > 0) {
      stats.push(`<span class="text-red-600 font-medium">${validationData.critical_issues} Critical</span>`)
    }
    
    if (validationData.errors > 0) {
      stats.push(`<span class="text-red-600">${validationData.errors} Errors</span>`)
    }
    
    if (validationData.warnings > 0) {
      stats.push(`<span class="text-yellow-600">${validationData.warnings} Warnings</span>`)
    }
    
    if (stats.length > 0) {
      return `<div class="flex space-x-4 mt-2 text-xs">${stats.join('')}</div>`
    }
    
    return ''
  }

  // Update error list display
  updateErrorList(validationData) {
    if (!this.hasErrorListTarget) return

    const errors = this.validationResults.filter(result => 
      ['critical', 'error'].includes(result.severity)
    )

    if (errors.length === 0) {
      this.errorListTarget.innerHTML = ''
      return
    }

    const errorsHTML = errors.map(error => this.renderValidationIssue(error, 'error')).join('')
    this.errorListTarget.innerHTML = `
      <div class="validation-errors space-y-2">
        <h4 class="font-medium text-red-800 text-sm mb-3">
          ${errors.length > 1 ? 'Errors' : 'Error'} (${errors.length})
        </h4>
        ${errorsHTML}
      </div>
    `
  }

  // Update warning list display
  updateWarningList(validationData) {
    if (!this.hasWarningListTarget) return

    const warnings = this.validationResults.filter(result => 
      result.severity === 'warning'
    )

    if (warnings.length === 0) {
      this.warningListTarget.innerHTML = ''
      return
    }

    const warningsHTML = warnings.map(warning => this.renderValidationIssue(warning, 'warning')).join('')
    this.warningListTarget.innerHTML = `
      <div class="validation-warnings space-y-2">
        <h4 class="font-medium text-yellow-800 text-sm mb-3">
          ${warnings.length > 1 ? 'Warnings' : 'Warning'} (${warnings.length})
        </h4>
        ${warningsHTML}
      </div>
    `
  }

  // Update recommendations display
  updateRecommendations(validationData) {
    if (!this.hasRecommendationsTarget) return

    const recommendations = validationData.recommendations || []
    
    if (recommendations.length === 0) {
      this.recommendationsTarget.innerHTML = ''
      return
    }

    const recommendationsHTML = recommendations.map(rec => `
      <li class="flex items-start space-x-2">
        <svg class="w-4 h-4 text-blue-500 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <span class="text-sm text-gray-700">${rec}</span>
      </li>
    `).join('')

    this.recommendationsTarget.innerHTML = `
      <div class="validation-recommendations">
        <h4 class="font-medium text-blue-800 text-sm mb-3">Recommendations</h4>
        <ul class="space-y-2">${recommendationsHTML}</ul>
      </div>
    `
  }

  // Update stage-specific error indicators
  updateStageErrors(validationData) {
    // Clear existing stage error indicators
    document.querySelectorAll('.journey-stage').forEach(stageElement => {
      stageElement.classList.remove('has-validation-errors', 'has-validation-warnings')
    })

    // Add error indicators to stages with issues
    this.validationResults.forEach(result => {
      if (result.stage_id) {
        const stageElement = document.querySelector(`[data-stage-id="${result.stage_id}"]`)
        if (stageElement) {
          if (['critical', 'error'].includes(result.severity)) {
            stageElement.classList.add('has-validation-errors')
          } else if (result.severity === 'warning') {
            stageElement.classList.add('has-validation-warnings')
          }

          // Add tooltip with error message
          this.addStageErrorTooltip(stageElement, result)
        }
      }
    })
  }

  // Add error tooltip to stage element
  addStageErrorTooltip(stageElement, validationResult) {
    const existingTooltip = stageElement.querySelector('.validation-tooltip')
    if (existingTooltip) {
      existingTooltip.remove()
    }

    const tooltip = document.createElement('div')
    tooltip.className = 'validation-tooltip absolute -top-2 -right-2 z-20'
    tooltip.innerHTML = `
      <div class="w-4 h-4 rounded-full ${this.getSeverityColor(validationResult.severity)} border-2 border-white shadow-sm cursor-help" 
           title="${validationResult.message}">
        ${this.getSeverityIcon(validationResult.severity)}
      </div>
    `

    stageElement.style.position = 'relative'
    stageElement.appendChild(tooltip)
  }

  // Render individual validation issue
  renderValidationIssue(issue, type) {
    const iconColor = type === 'error' ? 'text-red-500' : 'text-yellow-500'
    const bgColor = type === 'error' ? 'bg-red-50 border-red-200' : 'bg-yellow-50 border-yellow-200'
    
    return `
      <div class="validation-issue p-3 rounded-lg border ${bgColor}">
        <div class="flex items-start space-x-3">
          <div class="flex-shrink-0 mt-0.5">
            ${this.getIssueIcon(type, iconColor)}
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between">
              <h5 class="text-sm font-medium text-gray-900">
                ${issue.type ? this.formatValidationType(issue.type) : 'Validation Issue'}
              </h5>
              ${issue.score ? `<span class="text-xs text-gray-500">${issue.score}%</span>` : ''}
            </div>
            <p class="text-sm text-gray-700 mt-1">${issue.message}</p>
            ${issue.stage_name ? `<p class="text-xs text-gray-500 mt-1">Stage: ${issue.stage_name}</p>` : ''}
            ${issue.recommendation ? this.renderRecommendation(issue.recommendation) : ''}
          </div>
        </div>
      </div>
    `
  }

  // Render recommendation for an issue
  renderRecommendation(recommendation) {
    if (Array.isArray(recommendation)) {
      const items = recommendation.map(rec => `<li class="text-xs text-blue-700">• ${rec}</li>`).join('')
      return `<ul class="mt-2">${items}</ul>`
    } else {
      return `<p class="text-xs text-blue-700 mt-2">💡 ${recommendation}</p>`
    }
  }

  // Update feedback container visibility
  updateFeedbackVisibility(validationData) {
    if (!this.hasFeedbackContainerTarget) return

    const hasIssues = validationData.critical_issues > 0 || 
                     validationData.errors > 0 || 
                     validationData.warnings > 0

    if (hasIssues || validationData.overall_status === 'pass') {
      this.showFeedbackContainer()
    }
  }

  // Show validation success message
  showValidationSuccess(validationData) {
    if (!this.hasSuccessMessageTarget) return

    const message = validationData.warnings > 0 ? 
      `Journey validation passed with ${validationData.warnings} warnings to consider.` :
      'Journey validation passed successfully!'

    this.successMessageTarget.innerHTML = `
      <div class="flex items-center space-x-3 p-4 rounded-lg bg-green-50 border border-green-200">
        <div class="flex-shrink-0">
          <svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
          </svg>
        </div>
        <div class="flex-1">
          <p class="text-sm font-medium text-green-800">${message}</p>
        </div>
      </div>
    `
    this.successMessageTarget.classList.remove(this.hiddenClass || 'hidden')
  }

  // Show validation error
  showValidationError(errorMessage) {
    if (this.hasFeedbackContainerTarget) {
      this.feedbackContainerTarget.innerHTML = `
        <div class="flex items-center space-x-3 p-4 rounded-lg bg-red-50 border border-red-200">
          <div class="flex-shrink-0">
            <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
            </svg>
          </div>
          <div class="flex-1">
            <p class="text-sm font-medium text-red-800">Validation Error</p>
            <p class="text-sm text-red-700 mt-1">${errorMessage}</p>
          </div>
        </div>
      `
      this.showFeedbackContainer()
    }
  }

  // Show validation progress indicator
  showValidationProgress() {
    if (this.hasValidationProgressTarget) {
      this.validationProgressTarget.innerHTML = `
        <div class="flex items-center space-x-2 text-sm text-gray-600">
          <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
          <span>Validating journey...</span>
        </div>
      `
      this.validationProgressTarget.classList.remove(this.hiddenClass || 'hidden')
    }

    if (this.hasValidateButtonTarget) {
      this.validateButtonTarget.disabled = true
      this.validateButtonTarget.classList.add(this.loadingClass || 'loading')
    }
  }

  // Hide validation progress indicator
  hideValidationProgress() {
    if (this.hasValidationProgressTarget) {
      this.validationProgressTarget.classList.add(this.hiddenClass || 'hidden')
    }

    if (this.hasValidateButtonTarget) {
      this.validateButtonTarget.disabled = false
      this.validateButtonTarget.classList.remove(this.loadingClass || 'loading')
    }
  }

  // Show feedback container
  showFeedbackContainer() {
    if (this.hasFeedbackContainerTarget) {
      this.feedbackContainerTarget.classList.remove(this.hiddenClass || 'hidden')
      this.feedbackContainerTarget.classList.add(this.visibleClass || 'visible')
    }
  }

  // Hide validation feedback
  hideValidationFeedback() {
    if (this.hasSuccessMessageTarget) {
      this.successMessageTarget.classList.add(this.hiddenClass || 'hidden')
    }
  }

  // Toggle validation details
  toggleValidationDetails() {
    if (this.hasValidationDetailsTarget) {
      const isHidden = this.validationDetailsTarget.classList.contains(this.hiddenClass || 'hidden')
      if (isHidden) {
        this.validationDetailsTarget.classList.remove(this.hiddenClass || 'hidden')
        this.updateToggleButton(false)
      } else {
        this.validationDetailsTarget.classList.add(this.hiddenClass || 'hidden')
        this.updateToggleButton(true)
      }
    }
  }

  // Update toggle button
  updateToggleButton(collapsed) {
    if (this.hasToggleDetailsTarget) {
      const icon = collapsed ? 
        '<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd"/></svg>' :
        '<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd"/></svg>'
      
      this.toggleDetailsTarget.innerHTML = `${collapsed ? 'Show' : 'Hide'} Details ${icon}`
    }
  }

  // Render toggle button
  renderToggleButton() {
    return `
      <button type="button" 
              class="flex items-center space-x-1 text-xs text-gray-500 hover:text-gray-700"
              data-action="click->journey-validation#toggleValidationDetails"
              data-journey-validation-target="toggleDetails">
        Show Details
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd"/>
        </svg>
      </button>
    `
  }

  // UI Helper methods

  getStatusIcon(status) {
    const icons = {
      pass: '<svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>',
      warning: '<svg class="w-5 h-5 text-yellow-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>',
      fail: '<svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>',
      error: '<svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>'
    }
    return icons[status] || icons.error
  }

  getStatusColor(status) {
    const colors = {
      pass: 'bg-green-50 border-green-200',
      warning: 'bg-yellow-50 border-yellow-200',
      fail: 'bg-red-50 border-red-200',
      error: 'bg-red-50 border-red-200'
    }
    return colors[status] || colors.error
  }

  getStatusTitle(status) {
    const titles = {
      pass: 'Validation Passed',
      warning: 'Validation Warning',
      fail: 'Validation Failed',
      error: 'Validation Error'
    }
    return titles[status] || 'Validation Status'
  }

  getSeverityColor(severity) {
    const colors = {
      critical: 'bg-red-500',
      error: 'bg-red-500',
      warning: 'bg-yellow-500',
      info: 'bg-blue-500'
    }
    return colors[severity] || colors.info
  }

  getSeverityIcon(severity) {
    const icons = {
      critical: '!',
      error: '×',
      warning: '⚠',
      info: 'i'
    }
    return `<span class="text-white text-xs font-bold">${icons[severity] || '?'}</span>`
  }

  getIssueIcon(type, colorClass) {
    if (type === 'error') {
      return `<svg class="w-4 h-4 ${colorClass}" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>`
    } else {
      return `<svg class="w-4 h-4 ${colorClass}" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>`
    }
  }

  formatValidationType(type) {
    return type.split('_').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1)
    ).join(' ')
  }

  // Utility methods

  getCSRFToken() {
    const metaTag = document.querySelector('meta[name="csrf-token"]')
    return metaTag ? metaTag.getAttribute('content') : ''
  }

  dispatchValidationEvent(eventName, detail) {
    const event = new CustomEvent(eventName, { detail })
    document.dispatchEvent(event)
  }

  cleanup() {
    clearTimeout(this.validationTimeout)
    
    document.removeEventListener('journey:stageAdded', this.handleJourneyChange)
    document.removeEventListener('journey:stageRemoved', this.handleJourneyChange)
    document.removeEventListener('journey:stageUpdated', this.handleJourneyChange)
    document.removeEventListener('journey:stageReordered', this.handleJourneyChange)
    document.removeEventListener('journey:validate', this.handleValidationRequest)
  }

  // Public API for external calls

  // Trigger manual validation
  triggerValidation(options = {}) {
    this.validateJourney(options)
  }

  // Clear all validation feedback
  clearValidation() {
    this.validationResults = []
    
    if (this.hasFeedbackContainerTarget) {
      this.feedbackContainerTarget.innerHTML = ''
      this.feedbackContainerTarget.classList.add(this.hiddenClass || 'hidden')
    }

    // Clear stage error indicators
    document.querySelectorAll('.journey-stage').forEach(stageElement => {
      stageElement.classList.remove('has-validation-errors', 'has-validation-warnings')
      const tooltip = stageElement.querySelector('.validation-tooltip')
      if (tooltip) tooltip.remove()
    })
  }

  // Get current validation status
  getValidationStatus() {
    return {
      hasResults: this.validationResults.length > 0,
      results: this.validationResults,
      criticalIssues: this.validationResults.filter(r => r.severity === 'critical').length,
      errors: this.validationResults.filter(r => ['critical', 'error'].includes(r.severity)).length,
      warnings: this.validationResults.filter(r => r.severity === 'warning').length
    }
  }
}