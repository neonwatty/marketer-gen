import { Controller } from "@hotwired/stimulus"

// Journey Persistence Controller for auto-save, optimistic updates, and version history
export default class extends Controller {
  static targets = [
    "saveStatus", "syncIndicator", "conflictModal", "versionHistory", 
    "saveProgress", "recoveryBanner", "exportModal", "importModal"
  ]

  static values = {
    journeyId: Number,
    campaignId: Number,
    autoSaveEnabled: { type: Boolean, default: true },
    autoSaveInterval: { type: Number, default: 5000 }, // 5 seconds
    maxRetries: { type: Number, default: 3 },
    currentVersion: { type: Number, default: 1 },
    lastSavedData: Object,
    optimisticUpdates: { type: Boolean, default: true }
  }

  static classes = [
    "saving", "saved", "error", "conflict", "syncing", "offline",
    "loading", "success", "warning", "hidden", "visible"
  ]

  connect() {
    this.initializePersistence()
    this.setupEventListeners()
    this.startAutoSave()
    this.initializeConflictResolution()
    this.loadVersionHistory()
  }

  disconnect() {
    this.cleanup()
  }

  // Initialize persistence system
  initializePersistence() {
    this.pendingSaves = new Map()
    this.saveQueue = []
    this.isOnline = navigator.onLine
    this.retryCount = 0
    this.lastSaveTime = null
    this.optimisticOperations = new Map()
    this.versionHistory = []
    this.conflictResolutionMode = false
    this.autoSaveTimeout = null
    this.saveInProgress = false
    
    // Initialize save status
    this.updateSaveStatus('ready')
  }

  // Setup event listeners
  setupEventListeners() {
    // Listen for journey changes
    document.addEventListener('journey:stageAdded', this.handleJourneyChange.bind(this))
    document.addEventListener('journey:stageRemoved', this.handleJourneyChange.bind(this))
    document.addEventListener('journey:stageUpdated', this.handleJourneyChange.bind(this))
    document.addEventListener('journey:stageReordered', this.handleJourneyChange.bind(this))
    document.addEventListener('journey:configChanged', this.handleJourneyChange.bind(this))
    
    // Network status events
    window.addEventListener('online', this.handleOnline.bind(this))
    window.addEventListener('offline', this.handleOffline.bind(this))
    
    // Page visibility for aggressive saving
    document.addEventListener('visibilitychange', this.handleVisibilityChange.bind(this))
    
    // Before unload to prevent data loss
    window.addEventListener('beforeunload', this.handleBeforeUnload.bind(this))
    
    // Keyboard shortcuts
    document.addEventListener('keydown', this.handleKeyboard.bind(this))
  }

  // Start auto-save system
  startAutoSave() {
    if (!this.autoSaveEnabledValue) return
    
    this.scheduleAutoSave()
  }

  // Schedule next auto-save
  scheduleAutoSave() {
    clearTimeout(this.autoSaveTimeout)
    this.autoSaveTimeout = setTimeout(() => {
      this.performAutoSave()
    }, this.autoSaveIntervalValue)
  }

  // Handle journey changes for auto-save
  handleJourneyChange(event) {
    if (!this.autoSaveEnabledValue) return
    
    const changeData = {
      type: event.type,
      detail: event.detail,
      timestamp: Date.now()
    }
    
    // Apply optimistic update immediately
    if (this.optimisticUpdatesValue) {
      this.applyOptimisticUpdate(changeData)
    }
    
    // Debounce auto-save
    this.debounceAutoSave()
  }

  // Debounced auto-save
  debounceAutoSave() {
    clearTimeout(this.autoSaveDebounce)
    this.autoSaveDebounce = setTimeout(() => {
      this.performAutoSave()
    }, 2000) // 2 second debounce
  }

  // Perform auto-save
  async performAutoSave() {
    if (this.saveInProgress || !this.isOnline) {
      this.scheduleAutoSave()
      return
    }

    try {
      const journeyData = this.getJourneyData()
      
      // Skip save if no changes
      if (this.hasSameData(journeyData)) {
        this.scheduleAutoSave()
        return
      }

      await this.saveJourneyData(journeyData, { isAutoSave: true })
      this.scheduleAutoSave()
      
    } catch (error) {
      console.error('Auto-save failed:', error)
      this.handleSaveError(error, { isAutoSave: true })
      this.scheduleAutoSave()
    }
  }

  // Apply optimistic update
  applyOptimisticUpdate(changeData) {
    const operationId = this.generateOperationId()
    
    this.optimisticOperations.set(operationId, {
      changeData,
      timestamp: Date.now(),
      applied: true
    })
    
    this.updateSaveStatus('saving')
    
    // Remove after successful save or timeout
    setTimeout(() => {
      if (this.optimisticOperations.has(operationId)) {
        this.optimisticOperations.delete(operationId)
      }
    }, 30000) // 30 second timeout
  }

  // Save journey data with retry logic
  async saveJourneyData(journeyData, options = {}) {
    const saveId = this.generateOperationId()
    this.saveInProgress = true
    
    try {
      this.updateSaveStatus('saving')
      this.showSaveProgress(true)
      
      const response = await this.performSave(journeyData, options)
      
      if (response.conflict) {
        await this.handleSaveConflict(response, journeyData, options)
        return
      }
      
      // Update version and last saved data
      this.currentVersionValue = response.version || (this.currentVersionValue + 1)
      this.lastSavedDataValue = journeyData
      this.lastSaveTime = Date.now()
      this.retryCount = 0
      
      // Add to version history
      this.addToVersionHistory({
        version: this.currentVersionValue,
        timestamp: this.lastSaveTime,
        changeType: options.isAutoSave ? 'auto-save' : 'manual-save',
        data: journeyData
      })
      
      this.updateSaveStatus('saved')
      
      if (!options.isAutoSave) {
        this.showNotification('Journey saved successfully!', 'success')
      }
      
      // Dispatch success event
      this.dispatchSaveEvent('journey:saved', {
        version: this.currentVersionValue,
        timestamp: this.lastSaveTime,
        isAutoSave: options.isAutoSave
      })
      
    } catch (error) {
      await this.handleSaveError(error, options)
      throw error
    } finally {
      this.saveInProgress = false
      this.showSaveProgress(false)
    }
  }

  // Perform the actual save request
  async performSave(journeyData, options = {}) {
    const url = this.journeyIdValue ? 
      `/journeys/${this.journeyIdValue}` : 
      `/campaigns/${this.campaignIdValue}/customer_journey`
    
    const method = this.journeyIdValue ? 'PUT' : 'POST'
    
    const response = await fetch(url, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken(),
        'X-Journey-Version': this.currentVersionValue.toString(),
        'X-Optimistic-Update': this.optimisticUpdatesValue.toString()
      },
      body: JSON.stringify({
        journey: journeyData,
        metadata: {
          version: this.currentVersionValue,
          timestamp: Date.now(),
          isAutoSave: options.isAutoSave || false,
          changeType: options.changeType || 'update'
        }
      })
    })

    if (!response.ok) {
      if (response.status === 409) {
        // Conflict detected
        const conflictData = await response.json()
        return { conflict: true, conflictData }
      }
      throw new Error(`Save failed: ${response.statusText}`)
    }

    return await response.json()
  }

  // Handle save conflicts
  async handleSaveConflict(conflictResponse, localData, options) {
    this.conflictResolutionMode = true
    this.updateSaveStatus('conflict')
    
    const conflictData = conflictResponse.conflictData
    
    // Show conflict resolution modal
    await this.showConflictResolutionModal(conflictData, localData)
  }

  // Show conflict resolution modal
  async showConflictResolutionModal(remoteData, localData) {
    if (!this.hasConflictModalTarget) return
    
    const modalHTML = this.generateConflictModalHTML(remoteData, localData)
    this.conflictModalTarget.innerHTML = modalHTML
    this.conflictModalTarget.classList.remove(this.hiddenClass || 'hidden')
    
    // Return promise that resolves when user makes a choice
    return new Promise((resolve) => {
      this.conflictResolver = resolve
    })
  }

  // Generate conflict resolution modal HTML
  generateConflictModalHTML(remoteData, localData) {
    return `
      <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Resolve Conflict</h3>
            <p class="mt-1 text-sm text-gray-500">
              This journey has been modified by another user. Choose how to resolve the conflict.
            </p>
          </div>
          
          <div class="px-6 py-4 max-h-96 overflow-y-auto">
            <div class="grid grid-cols-2 gap-6">
              <div class="space-y-3">
                <h4 class="font-medium text-gray-900">Your Changes</h4>
                <div class="bg-blue-50 border border-blue-200 rounded p-3">
                  <pre class="text-sm text-gray-700 whitespace-pre-wrap">${JSON.stringify(localData, null, 2)}</pre>
                </div>
              </div>
              
              <div class="space-y-3">
                <h4 class="font-medium text-gray-900">Remote Changes</h4>
                <div class="bg-yellow-50 border border-yellow-200 rounded p-3">
                  <pre class="text-sm text-gray-700 whitespace-pre-wrap">${JSON.stringify(remoteData.journey, null, 2)}</pre>
                </div>
              </div>
            </div>
          </div>
          
          <div class="px-6 py-4 bg-gray-50 border-t border-gray-200 flex justify-end space-x-3">
            <button type="button" 
                    class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                    data-action="click->journey-persistence#resolveConflict"
                    data-resolution="use-remote">
              Use Remote Version
            </button>
            <button type="button" 
                    class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                    data-action="click->journey-persistence#resolveConflict"
                    data-resolution="merge">
              Merge Changes
            </button>
            <button type="button" 
                    class="px-4 py-2 border border-transparent rounded-md text-sm font-medium text-white bg-blue-600 hover:bg-blue-700"
                    data-action="click->journey-persistence#resolveConflict"
                    data-resolution="use-local">
              Use My Version
            </button>
          </div>
        </div>
      </div>
    `
  }

  // Resolve conflict based on user choice
  async resolveConflict(event) {
    const resolution = event.currentTarget.dataset.resolution
    
    try {
      let resolvedData
      
      switch (resolution) {
        case 'use-local':
          resolvedData = this.getJourneyData()
          break
        case 'use-remote':
          resolvedData = this.conflictData.journey
          await this.applyRemoteData(resolvedData)
          break
        case 'merge':
          resolvedData = await this.mergeConflictingData()
          await this.applyRemoteData(resolvedData)
          break
      }
      
      // Force save with conflict resolution
      await this.saveJourneyData(resolvedData, { 
        forceUpdate: true, 
        conflictResolution: resolution 
      })
      
      this.hideConflictModal()
      this.conflictResolutionMode = false
      
      if (this.conflictResolver) {
        this.conflictResolver(resolution)
      }
      
    } catch (error) {
      console.error('Conflict resolution failed:', error)
      this.showNotification('Failed to resolve conflict. Please try again.', 'error')
    }
  }

  // Merge conflicting data (simple merge strategy)
  async mergeConflictingData() {
    // This is a simplified merge - in production, you'd want more sophisticated merging
    const localData = this.getJourneyData()
    const remoteData = this.conflictData.journey
    
    // Merge stages by position, preferring local changes for conflicts
    const mergedStages = [...remoteData.stages]
    
    localData.stages.forEach(localStage => {
      const remoteIndex = mergedStages.findIndex(s => s.id === localStage.id)
      if (remoteIndex >= 0) {
        // Merge individual stage properties
        mergedStages[remoteIndex] = { ...mergedStages[remoteIndex], ...localStage }
      } else {
        // Add new local stages
        mergedStages.push(localStage)
      }
    })
    
    return {
      ...remoteData,
      ...localData,
      stages: mergedStages
    }
  }

  // Apply remote data to UI
  async applyRemoteData(remoteData) {
    // Dispatch event to update the journey builder
    this.dispatchSaveEvent('journey:loadRemoteData', { data: remoteData })
  }

  // Hide conflict modal
  hideConflictModal() {
    if (this.hasConflictModalTarget) {
      this.conflictModalTarget.classList.add(this.hiddenClass || 'hidden')
      this.conflictModalTarget.innerHTML = ''
    }
  }

  // Handle save errors with retry logic
  async handleSaveError(error, options = {}) {
    this.retryCount++
    
    if (this.retryCount <= this.maxRetriesValue) {
      this.updateSaveStatus('retrying')
      this.showNotification(`Save failed. Retrying... (${this.retryCount}/${this.maxRetriesValue})`, 'warning')
      
      // Exponential backoff
      const delay = Math.pow(2, this.retryCount) * 1000
      setTimeout(() => {
        this.performAutoSave()
      }, delay)
      
    } else {
      this.updateSaveStatus('error')
      this.showRecoveryOptions(error, options)
    }
  }

  // Show recovery options for failed saves
  showRecoveryOptions(error, options) {
    if (!this.hasRecoveryBannerTarget) return
    
    const recoveryHTML = `
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
            </svg>
          </div>
          <div class="ml-3 flex-1">
            <h3 class="text-sm font-medium text-red-800">Save Failed</h3>
            <p class="mt-1 text-sm text-red-700">
              Unable to save your changes after ${this.maxRetriesValue} attempts. Your work is preserved locally.
            </p>
            <div class="mt-3 flex space-x-3">
              <button type="button" 
                      class="text-sm bg-red-100 text-red-800 hover:bg-red-200 px-3 py-1 rounded"
                      data-action="click->journey-persistence#retryManualSave">
                Retry Save
              </button>
              <button type="button" 
                      class="text-sm bg-red-100 text-red-800 hover:bg-red-200 px-3 py-1 rounded"
                      data-action="click->journey-persistence#exportForRecovery">
                Export Data
              </button>
              <button type="button" 
                      class="text-sm text-red-600 hover:text-red-800"
                      data-action="click->journey-persistence#hideRecoveryBanner">
                Dismiss
              </button>
            </div>
          </div>
        </div>
      </div>
    `
    
    this.recoveryBannerTarget.innerHTML = recoveryHTML
    this.recoveryBannerTarget.classList.remove(this.hiddenClass || 'hidden')
  }

  // Retry manual save
  async retryManualSave() {
    this.retryCount = 0
    this.hideRecoveryBanner()
    
    try {
      const journeyData = this.getJourneyData()
      await this.saveJourneyData(journeyData, { isRetry: true })
    } catch (error) {
      this.showNotification('Manual retry failed. Please check your connection.', 'error')
    }
  }

  // Export data for recovery
  exportForRecovery() {
    const journeyData = this.getJourneyData()
    const exportData = {
      journey: journeyData,
      version: this.currentVersionValue,
      timestamp: Date.now(),
      recoveryInfo: 'This data was exported due to save failure'
    }
    
    this.downloadJSON(exportData, `journey-recovery-${Date.now()}.json`)
    this.showNotification('Journey data exported for recovery', 'info')
  }

  // Hide recovery banner
  hideRecoveryBanner() {
    if (this.hasRecoveryBannerTarget) {
      this.recoveryBannerTarget.classList.add(this.hiddenClass || 'hidden')
    }
  }

  // Journey duplication
  async duplicateJourney() {
    try {
      this.updateSaveStatus('duplicating')
      
      const response = await fetch(`/journeys/${this.journeyIdValue}/duplicate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (!response.ok) {
        throw new Error('Duplication failed')
      }
      
      const result = await response.json()
      this.showNotification('Journey duplicated successfully!', 'success')
      
      // Redirect to new journey or update UI
      if (result.journey_url) {
        window.location.href = result.journey_url
      }
      
    } catch (error) {
      console.error('Duplication error:', error)
      this.showNotification('Failed to duplicate journey', 'error')
    }
  }

  // Export journey
  async exportJourney(format = 'json') {
    try {
      const journeyData = this.getJourneyData()
      const versionHistory = this.versionHistory
      
      const exportData = {
        journey: journeyData,
        version: this.currentVersionValue,
        exported_at: new Date().toISOString(),
        format_version: '1.0',
        version_history: versionHistory
      }
      
      switch (format) {
        case 'json':
          this.downloadJSON(exportData, `journey-export-${Date.now()}.json`)
          break
        case 'csv':
          this.downloadCSV(this.convertToCSV(journeyData), `journey-export-${Date.now()}.csv`)
          break
        default:
          throw new Error(`Unsupported export format: ${format}`)
      }
      
      this.showNotification(`Journey exported as ${format.toUpperCase()}`, 'success')
      
    } catch (error) {
      console.error('Export error:', error)
      this.showNotification('Failed to export journey', 'error')
    }
  }

  // Import journey
  async importJourney(file) {
    try {
      this.updateSaveStatus('importing')
      
      const fileContent = await this.readFile(file)
      let importData
      
      if (file.name.endsWith('.json')) {
        importData = JSON.parse(fileContent)
      } else if (file.name.endsWith('.csv')) {
        importData = this.parseCSV(fileContent)
      } else {
        throw new Error('Unsupported file format')
      }
      
      // Validate import data
      if (!this.validateImportData(importData)) {
        throw new Error('Invalid import data format')
      }
      
      // Apply imported data
      await this.applyImportedData(importData)
      
      this.showNotification('Journey imported successfully!', 'success')
      
    } catch (error) {
      console.error('Import error:', error)
      this.showNotification(`Import failed: ${error.message}`, 'error')
    }
  }

  // Version history management
  addToVersionHistory(versionData) {
    this.versionHistory.unshift(versionData)
    
    // Keep only last 50 versions
    if (this.versionHistory.length > 50) {
      this.versionHistory = this.versionHistory.slice(0, 50)
    }
    
    this.updateVersionHistoryUI()
  }

  // Load version history
  async loadVersionHistory() {
    if (!this.journeyIdValue) return
    
    try {
      const response = await fetch(`/journeys/${this.journeyIdValue}/versions`)
      if (response.ok) {
        const data = await response.json()
        this.versionHistory = data.versions || []
        this.updateVersionHistoryUI()
      }
    } catch (error) {
      console.warn('Could not load version history:', error)
    }
  }

  // Update version history UI
  updateVersionHistoryUI() {
    if (!this.hasVersionHistoryTarget) return
    
    const historyHTML = this.versionHistory.map(version => `
      <div class="version-item p-3 border-b border-gray-100 hover:bg-gray-50">
        <div class="flex items-center justify-between">
          <div>
            <span class="text-sm font-medium">Version ${version.version}</span>
            <span class="text-xs text-gray-500 ml-2">${this.formatTimestamp(version.timestamp)}</span>
          </div>
          <div class="flex space-x-2">
            <button type="button" 
                    class="text-xs text-blue-600 hover:text-blue-800"
                    data-action="click->journey-persistence#previewVersion"
                    data-version="${version.version}">
              Preview
            </button>
            <button type="button" 
                    class="text-xs text-blue-600 hover:text-blue-800"
                    data-action="click->journey-persistence#restoreVersion"
                    data-version="${version.version}">
              Restore
            </button>
          </div>
        </div>
        <p class="text-xs text-gray-600 mt-1">${version.changeType}</p>
      </div>
    `).join('')
    
    this.versionHistoryTarget.innerHTML = historyHTML
  }

  // Restore version
  async restoreVersion(event) {
    const version = parseInt(event.currentTarget.dataset.version)
    const versionData = this.versionHistory.find(v => v.version === version)
    
    if (!versionData) {
      this.showNotification('Version data not found', 'error')
      return
    }
    
    if (confirm(`Restore to version ${version}? This will overwrite current changes.`)) {
      try {
        await this.applyRemoteData(versionData.data)
        await this.saveJourneyData(versionData.data, { 
          isRestore: true, 
          restoredFromVersion: version 
        })
        
        this.showNotification(`Restored to version ${version}`, 'success')
      } catch (error) {
        this.showNotification('Failed to restore version', 'error')
      }
    }
  }

  // Network status handlers
  handleOnline() {
    this.isOnline = true
    this.updateSaveStatus('online')
    
    // Attempt to save any pending changes
    if (this.autoSaveEnabledValue) {
      this.performAutoSave()
    }
  }

  handleOffline() {
    this.isOnline = false
    this.updateSaveStatus('offline')
    this.showNotification('Working offline. Changes will be saved when connection is restored.', 'warning')
  }

  // Page visibility change handler
  handleVisibilityChange() {
    if (document.hidden) {
      // Page is being hidden - aggressively save
      if (this.autoSaveEnabledValue && !this.saveInProgress) {
        this.performAutoSave()
      }
    }
  }

  // Before unload handler
  handleBeforeUnload(event) {
    if (this.hasUnsavedChanges()) {
      event.preventDefault()
      event.returnValue = 'You have unsaved changes. Are you sure you want to leave?'
      return event.returnValue
    }
  }

  // Keyboard shortcuts
  handleKeyboard(event) {
    if ((event.ctrlKey || event.metaKey) && event.key === 's') {
      event.preventDefault()
      this.forceSave()
    }
  }

  // Force save (Ctrl+S)
  async forceSave() {
    try {
      const journeyData = this.getJourneyData()
      await this.saveJourneyData(journeyData, { isManual: true })
    } catch (error) {
      console.error('Force save failed:', error)
    }
  }

  // Utility methods

  getJourneyData() {
    // Get journey data from the builder controller
    const builderController = this.element.querySelector('[data-controller*="journey-builder"]')
    if (builderController) {
      const controller = this.application.getControllerForElementAndIdentifier(builderController, 'journey-builder')
      if (controller && controller.stages) {
        return {
          name: controller.journeyName || 'Customer Journey',
          stages: controller.stages,
          content_types: controller.extractContentTypes?.() || []
        }
      }
    }
    
    return { stages: [], content_types: [] }
  }

  hasSameData(journeyData) {
    if (!this.lastSavedDataValue) return false
    return JSON.stringify(journeyData) === JSON.stringify(this.lastSavedDataValue)
  }

  hasUnsavedChanges() {
    const currentData = this.getJourneyData()
    return !this.hasSameData(currentData)
  }

  updateSaveStatus(status) {
    if (this.hasSaveStatusTarget) {
      const statusConfig = {
        ready: { text: 'Ready', class: 'text-gray-500' },
        saving: { text: 'Saving...', class: 'text-blue-600' },
        saved: { text: 'Saved', class: 'text-green-600' },
        error: { text: 'Save Failed', class: 'text-red-600' },
        conflict: { text: 'Conflict', class: 'text-yellow-600' },
        offline: { text: 'Offline', class: 'text-orange-600' },
        retrying: { text: 'Retrying...', class: 'text-yellow-600' }
      }
      
      const config = statusConfig[status] || statusConfig.ready
      this.saveStatusTarget.textContent = config.text
      this.saveStatusTarget.className = `text-sm font-medium ${config.class}`
    }
    
    this.dispatchSaveEvent('journey:saveStatusChanged', { status })
  }

  showSaveProgress(show) {
    if (this.hasSaveProgressTarget) {
      if (show) {
        this.saveProgressTarget.classList.remove(this.hiddenClass || 'hidden')
      } else {
        this.saveProgressTarget.classList.add(this.hiddenClass || 'hidden')
      }
    }
  }

  generateOperationId() {
    return `op_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  getCSRFToken() {
    const metaTag = document.querySelector('meta[name="csrf-token"]')
    return metaTag ? metaTag.getAttribute('content') : ''
  }

  dispatchSaveEvent(eventName, detail) {
    const event = new CustomEvent(eventName, { detail })
    document.dispatchEvent(event)
  }

  showNotification(message, type = 'info') {
    // Use existing notification system from journey builder
    const builderElement = document.querySelector('[data-controller*="journey-builder"]')
    if (builderElement) {
      const controller = this.application.getControllerForElementAndIdentifier(builderElement, 'journey-builder')
      if (controller && controller.showNotification) {
        controller.showNotification(message, type)
        return
      }
    }
    
    // Fallback notification
    console.log(`${type.toUpperCase()}: ${message}`)
  }

  // File utilities
  downloadJSON(data, filename) {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    this.downloadBlob(blob, filename)
  }

  downloadCSV(data, filename) {
    const blob = new Blob([data], { type: 'text/csv' })
    this.downloadBlob(blob, filename)
  }

  downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  readFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = (e) => resolve(e.target.result)
      reader.onerror = (e) => reject(new Error('File read failed'))
      reader.readAsText(file)
    })
  }

  formatTimestamp(timestamp) {
    return new Date(timestamp).toLocaleString()
  }

  // Cleanup
  cleanup() {
    clearTimeout(this.autoSaveTimeout)
    clearTimeout(this.autoSaveDebounce)
    
    document.removeEventListener('journey:stageAdded', this.handleJourneyChange)
    document.removeEventListener('journey:stageRemoved', this.handleJourneyChange)
    document.removeEventListener('journey:stageUpdated', this.handleJourneyChange)
    document.removeEventListener('journey:stageReordered', this.handleJourneyChange)
    document.removeEventListener('journey:configChanged', this.handleJourneyChange)
    
    window.removeEventListener('online', this.handleOnline)
    window.removeEventListener('offline', this.handleOffline)
    document.removeEventListener('visibilitychange', this.handleVisibilityChange)
    window.removeEventListener('beforeunload', this.handleBeforeUnload)
    document.removeEventListener('keydown', this.handleKeyboard)
  }
}