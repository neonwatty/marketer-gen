import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="status-management"
export default class extends Controller {
  static targets = [
    "statusIndicator", "statusText", "statusDescription", "quickActions",
    "timeline", "timelineStep", "changeForm", "statusSelect", "submitButton",
    "warnings", "warningText", "historyModal", "historyContent",
    "workflowModal", "workflowContent"
  ]
  static values = { 
    currentStatus: String, 
    campaignId: String, 
    updateUrl: String 
  }

  connect() {
    console.log("Status management controller connected")
    this.initializeStatusManagement()
  }

  // Initialize status management
  initializeStatusManagement() {
    this.statusTransitions = this.getStatusTransitions()
    this.milestoneChecks = new Map()
    this.automatedRules = []
    
    // Setup periodic milestone checking
    this.setupMilestoneChecking()
    
    // Load automated rules
    this.loadAutomatedRules()
    
    // Setup real-time updates
    this.setupRealTimeUpdates()
  }

  // Get allowed status transitions
  getStatusTransitions() {
    return {
      'draft': ['active', 'archived'],
      'active': ['paused', 'completed', 'archived'],
      'paused': ['active', 'completed', 'archived'],
      'completed': ['archived'],
      'archived': ['draft'] // Can restore to draft
    }
  }

  // Validate status transition
  validateTransition(event) {
    const selectedStatus = event.target.value
    const currentStatus = this.currentStatusValue
    
    if (selectedStatus === currentStatus) {
      this.hideWarnings()
      return
    }
    
    const allowedTransitions = this.statusTransitions[currentStatus] || []
    
    if (!allowedTransitions.includes(selectedStatus)) {
      this.showWarning(`Cannot transition from ${currentStatus} to ${selectedStatus}`)
      event.target.value = currentStatus // Reset selection
      return
    }
    
    // Show warnings for specific transitions
    this.showTransitionWarnings(currentStatus, selectedStatus)
  }

  // Show transition-specific warnings
  showTransitionWarnings(fromStatus, toStatus) {
    let warningMessage = null
    
    switch (toStatus) {
      case 'active':
        if (fromStatus === 'draft') {
          warningMessage = "Activating this campaign will start all scheduled activities and begin tracking performance metrics."
        } else if (fromStatus === 'paused') {
          warningMessage = "Resuming this campaign will restart all paused activities."
        }
        break
        
      case 'paused':
        warningMessage = "Pausing this campaign will temporarily stop all active activities. You can resume it later."
        break
        
      case 'completed':
        warningMessage = "Marking this campaign as completed will end all activities and finalize performance tracking."
        break
        
      case 'archived':
        warningMessage = "Archiving this campaign will move it to the archive section. You can restore it later if needed."
        break
    }
    
    if (warningMessage) {
      this.showWarning(warningMessage)
    } else {
      this.hideWarnings()
    }
  }

  // Show warning message
  showWarning(message) {
    if (this.hasWarningsTarget && this.hasWarningTextTarget) {
      this.warningTextTarget.textContent = message
      this.warningsTarget.classList.remove('hidden')
    }
  }

  // Hide warnings
  hideWarnings() {
    if (this.hasWarningsTarget) {
      this.warningsTarget.classList.add('hidden')
    }
  }

  // Handle status change form submission
  async handleStatusChange(event) {
    event.preventDefault()
    
    if (!this.updateUrlValue) {
      console.error('No update URL configured')
      return
    }
    
    const formData = new FormData(event.target)
    const newStatus = formData.get('campaign[status]')
    
    // Show loading state
    this.showLoadingState()
    
    try {
      const response = await fetch(this.updateUrlValue, {
        method: 'PATCH',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const result = await response.json()
        await this.handleStatusChangeSuccess(result, newStatus)
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
      
    } catch (error) {
      console.error('Status change failed:', error)
      this.handleStatusChangeError(error)
    } finally {
      this.hideLoadingState()
    }
  }

  // Handle successful status change
  async handleStatusChangeSuccess(result, newStatus) {
    // Update current status
    this.currentStatusValue = newStatus
    
    // Update UI elements
    this.updateStatusDisplay(newStatus)
    this.updateTimeline(newStatus)
    this.updateQuickActions(newStatus)
    
    // Hide warnings
    this.hideWarnings()
    
    // Show success message
    this.showSuccessMessage(`Campaign status updated to ${newStatus}`)
    
    // Check for automated rule triggers
    this.checkAutomatedRules(newStatus)
    
    // Record status change in history
    this.recordStatusChange(newStatus, result.reason)
    
    // Trigger milestone checks
    this.triggerMilestoneChecks()
  }

  // Handle status change error
  handleStatusChangeError(_error) {
    this.showErrorMessage('Failed to update campaign status. Please try again.')
  }

  // Update status display
  updateStatusDisplay(newStatus) {
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = this.humanizeStatus(newStatus)
    }
    
    if (this.hasStatusIndicatorTarget) {
      // Update status indicator classes
      const indicator = this.statusIndicatorTarget.querySelector('.w-4.h-4.rounded-full')
      if (indicator) {
        indicator.className = `w-4 h-4 rounded-full mr-3 ${this.getStatusDotColor(newStatus)}`
      }
      
      const text = this.statusIndicatorTarget.querySelector('[data-status-management-target="statusText"]')
      if (text) {
        text.className = `text-2xl font-bold ${this.getStatusTextColor(newStatus)}`
      }
    }
    
    if (this.hasStatusDescriptionTarget) {
      this.statusDescriptionTarget.innerHTML = `
        <p class="text-sm text-gray-600">
          ${this.getStatusDescription(newStatus)}
        </p>
      `
    }
  }

  // Update timeline
  updateTimeline(newStatus) {
    if (!this.hasTimelineTarget) {return}
    
    this.timelineStepTargets.forEach(step => {
      const stepStatus = step.dataset.status
      const isReached = this.isStatusReached(newStatus, stepStatus)
      const isCurrent = newStatus === stepStatus
      
      // Update step classes
      step.className = `timeline-step relative z-10 w-10 h-10 rounded-full flex items-center justify-center border-2 transition-all duration-300 ${this.getTimelineStepClasses(newStatus, stepStatus)}`
      
      // Update step content
      if (isReached && !isCurrent) {
        // Completed step
        step.innerHTML = `
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
            <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
          </svg>
        `
      } else if (isCurrent) {
        // Current step
        step.innerHTML = '<div class="w-3 h-3 rounded-full bg-current animate-pulse"></div>'
      } else {
        // Future step
        const stepIndex = ['draft', 'active', 'paused', 'completed', 'archived'].indexOf(stepStatus)
        step.innerHTML = `<span class="text-xs font-medium">${stepIndex + 1}</span>`
      }
    })
  }

  // Update quick actions
  async updateQuickActions(newStatus) {
    if (!this.hasQuickActionsTarget) {return}
    
    try {
      const response = await fetch(`${this.updateUrlValue}/quick_actions?status=${newStatus}`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'text/html'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.quickActionsTarget.innerHTML = html
      }
    } catch (error) {
      console.error('Failed to update quick actions:', error)
    }
  }

  // Show status history modal
  async showHistory(event) {
    event.preventDefault()
    
    if (!this.hasHistoryModalTarget) {return}
    
    this.historyModalTarget.classList.remove('hidden')
    this.historyModalTarget.setAttribute('aria-hidden', 'false')
    
    // Load history content
    await this.loadStatusHistory()
  }

  // Hide status history modal
  hideHistory(event) {
    event.preventDefault()
    
    if (this.hasHistoryModalTarget) {
      this.historyModalTarget.classList.add('hidden')
      this.historyModalTarget.setAttribute('aria-hidden', 'true')
    }
  }

  // Load status history
  async loadStatusHistory() {
    if (!this.hasHistoryContentTarget) {return}
    
    try {
      const response = await fetch(`${this.updateUrlValue}/status_history`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'text/html'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.historyContentTarget.innerHTML = html
      } else {
        this.historyContentTarget.innerHTML = '<p class="text-gray-500">Failed to load status history.</p>'
      }
    } catch (error) {
      console.error('Failed to load status history:', error)
      this.historyContentTarget.innerHTML = '<p class="text-gray-500">Error loading status history.</p>'
    }
  }

  // Show workflow modal
  async showWorkflow(event) {
    event.preventDefault()
    
    if (!this.hasWorkflowModalTarget) {return}
    
    this.workflowModalTarget.classList.remove('hidden')
    this.workflowModalTarget.setAttribute('aria-hidden', 'false')
    
    // Load workflow content
    await this.loadWorkflowVisualization()
  }

  // Hide workflow modal
  hideWorkflow(event) {
    event.preventDefault()
    
    if (this.hasWorkflowModalTarget) {
      this.workflowModalTarget.classList.add('hidden')
      this.workflowModalTarget.setAttribute('aria-hidden', 'true')
    }
  }

  // Load workflow visualization
  async loadWorkflowVisualization() {
    if (!this.hasWorkflowContentTarget) {return}
    
    try {
      const response = await fetch(`${this.updateUrlValue}/workflow`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'text/html'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.workflowContentTarget.innerHTML = html
        
        // Initialize the workflow visualization controller if it exists
        const workflowElement = this.workflowContentTarget.querySelector('[data-controller*="workflow-visualization"]')
        if (workflowElement) {
          // Manually trigger Stimulus controller connection if needed
          const application = this.application
          application.start()
        }
      } else {
        this.workflowContentTarget.innerHTML = '<p class="text-gray-500">Failed to load workflow visualization.</p>'
      }
    } catch (error) {
      console.error('Failed to load workflow:', error)
      this.workflowContentTarget.innerHTML = '<p class="text-gray-500">Error loading workflow visualization.</p>'
    }
  }

  // Setup milestone checking
  setupMilestoneChecking() {
    // Check milestones every 5 minutes
    this.milestoneInterval = setInterval(() => {
      this.checkMilestones()
    }, 5 * 60 * 1000)
    
    // Initial check
    this.checkMilestones()
  }

  // Check campaign milestones
  async checkMilestones() {
    try {
      const response = await fetch(`${this.updateUrlValue}/check_milestones`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const milestones = await response.json()
        this.processMilestones(milestones)
      }
    } catch (error) {
      console.error('Failed to check milestones:', error)
    }
  }

  // Process milestone results
  processMilestones(milestones) {
    milestones.forEach(milestone => {
      if (milestone.triggered && !this.milestoneChecks.has(milestone.id)) {
        this.milestoneChecks.set(milestone.id, true)
        this.handleMilestoneReached(milestone)
      }
    })
  }

  // Handle milestone reached
  handleMilestoneReached(milestone) {
    // Show milestone notification
    this.showMilestoneNotification(milestone)
    
    // Trigger automated actions if configured
    if (milestone.automated_action) {
      this.executeMilestoneAction(milestone.automated_action)
    }
  }

  // Show milestone notification
  showMilestoneNotification(milestone) {
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 bg-blue-600 text-white px-4 py-3 rounded-lg shadow-lg z-50 max-w-sm'
    notification.innerHTML = `
      <div class="flex items-start">
        <svg class="w-5 h-5 mt-0.5 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <div class="flex-1">
          <p class="text-sm font-medium">Milestone Reached</p>
          <p class="text-xs mt-1 opacity-90">${milestone.name}</p>
          <button class="text-xs underline hover:no-underline mt-2" onclick="this.parentElement.parentElement.parentElement.remove()">
            Dismiss
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Auto-hide after 10 seconds
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove()
      }
    }, 10000)
  }

  // Load automated rules
  async loadAutomatedRules() {
    try {
      const response = await fetch(`${this.updateUrlValue}/automated_rules`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        this.automatedRules = await response.json()
      }
    } catch (error) {
      console.error('Failed to load automated rules:', error)
    }
  }

  // Check automated rules
  checkAutomatedRules(newStatus) {
    this.automatedRules.forEach(rule => {
      if (rule.enabled && this.shouldTriggerRule(rule, newStatus)) {
        this.executeAutomatedRule(rule)
      }
    })
  }

  // Check if rule should trigger
  shouldTriggerRule(rule, newStatus) {
    // Simple rule evaluation - in a real app this would be more sophisticated
    return rule.trigger.status_change && 
           rule.trigger.from_status === this.currentStatusValue &&
           rule.trigger.to_status === newStatus
  }

  // Execute automated rule
  async executeAutomatedRule(rule) {
    try {
      const response = await fetch(`${this.updateUrlValue}/execute_rule`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ rule_id: rule.id })
      })
      
      if (response.ok) {
        const result = await response.json()
        this.showRuleExecutionResult(rule, result)
      }
    } catch (error) {
      console.error('Failed to execute automated rule:', error)
    }
  }

  // Show rule execution result
  showRuleExecutionResult(rule, result) {
    const message = result.success 
      ? `Automated rule "${rule.name}" executed successfully`
      : `Automated rule "${rule.name}" failed: ${result.error}`
    
    const messageType = result.success ? 'success' : 'error'
    this.showMessage(message, messageType)
  }

  // Setup real-time updates
  setupRealTimeUpdates() {
    // This would integrate with ActionCable or similar real-time system
    // For now, poll for updates every 30 seconds
    this.updateInterval = setInterval(() => {
      this.checkForUpdates()
    }, 30 * 1000)
  }

  // Check for updates
  async checkForUpdates() {
    try {
      const response = await fetch(`${this.updateUrlValue}/status`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        if (data.status !== this.currentStatusValue) {
          this.handleExternalStatusChange(data.status)
        }
      }
    } catch (error) {
      console.error('Failed to check for updates:', error)
    }
  }

  // Handle external status change
  handleExternalStatusChange(newStatus) {
    this.showExternalChangeNotification(newStatus)
    this.currentStatusValue = newStatus
    this.updateStatusDisplay(newStatus)
    this.updateTimeline(newStatus)
  }

  // Show external change notification
  showExternalChangeNotification(newStatus) {
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 bg-yellow-600 text-white px-4 py-3 rounded-lg shadow-lg z-50 max-w-sm'
    notification.innerHTML = `
      <div class="flex items-start">
        <svg class="w-5 h-5 mt-0.5 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
        </svg>
        <div class="flex-1">
          <p class="text-sm font-medium">Status Updated</p>
          <p class="text-xs mt-1 opacity-90">Campaign status changed to ${this.humanizeStatus(newStatus)}</p>
          <button class="text-xs underline hover:no-underline mt-2" onclick="this.parentElement.parentElement.parentElement.remove()">
            Dismiss
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove()
      }
    }, 8000)
  }

  // Utility methods
  showLoadingState() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = 'Updating...'
    }
  }

  hideLoadingState() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = 'Update Status'
    }
  }

  showSuccessMessage(message) {
    this.showMessage(message, 'success')
  }

  showErrorMessage(message) {
    this.showMessage(message, 'error')
  }

  showMessage(message, type = 'info') {
    const bgColor = type === 'error' ? 'bg-red-600' : 'bg-green-600'
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 ${bgColor} text-white px-4 py-2 rounded-lg shadow-lg z-50`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      if (toast.parentElement) {
        toast.remove()
      }
    }, 5000)
  }

  recordStatusChange(newStatus, reason) {
    // Record in local storage for history
    const historyKey = `campaign_${this.campaignIdValue}_status_history`
    const history = JSON.parse(localStorage.getItem(historyKey) || '[]')
    
    history.unshift({
      from_status: this.currentStatusValue,
      to_status: newStatus,
      reason,
      timestamp: new Date().toISOString(),
      user: 'current_user' // Would be actual user data
    })
    
    // Keep only last 50 entries
    history.splice(50)
    
    localStorage.setItem(historyKey, JSON.stringify(history))
  }

  triggerMilestoneChecks() {
    // Force milestone check after status change
    setTimeout(() => {
      this.checkMilestones()
    }, 1000)
  }

  humanizeStatus(status) {
    return status.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  getStatusDotColor(status) {
    const colors = {
      'draft': 'bg-gray-400',
      'active': 'bg-green-500',
      'paused': 'bg-yellow-500',
      'completed': 'bg-blue-500',
      'archived': 'bg-purple-500'
    }
    return colors[status] || 'bg-gray-400'
  }

  getStatusTextColor(status) {
    const colors = {
      'draft': 'text-gray-700',
      'active': 'text-green-700',
      'paused': 'text-yellow-700',
      'completed': 'text-blue-700',
      'archived': 'text-purple-700'
    }
    return colors[status] || 'text-gray-700'
  }

  getStatusDescription(status) {
    const descriptions = {
      'draft': 'Campaign is being prepared and not yet active',
      'active': 'Campaign is live and actively running',
      'paused': 'Campaign is temporarily stopped and can be resumed',
      'completed': 'Campaign has finished and achieved its goals',
      'archived': 'Campaign is stored in the archive for future reference'
    }
    return descriptions[status] || 'Status description not available'
  }

  getTimelineStepClasses(currentStatus, stepStatus) {
    const isReached = this.isStatusReached(currentStatus, stepStatus)
    const isCurrent = currentStatus === stepStatus
    
    if (isReached && !isCurrent) {
      return 'bg-green-600 border-green-600 text-white'
    } else if (isCurrent) {
      return 'bg-blue-600 border-blue-600 text-white'
    } else {
      return 'bg-white border-gray-300 text-gray-500'
    }
  }

  isStatusReached(currentStatus, targetStatus) {
    const statusOrder = ['draft', 'active', 'paused', 'completed', 'archived']
    const currentIndex = statusOrder.indexOf(currentStatus)
    const targetIndex = statusOrder.indexOf(targetStatus)
    
    // Special case for paused - it's not "reached" in linear progression
    if (targetStatus === 'paused') {
      return currentStatus === 'paused'
    }
    
    return currentIndex >= targetIndex
  }

  // Cleanup
  disconnect() {
    if (this.milestoneInterval) {
      clearInterval(this.milestoneInterval)
    }
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  }
}