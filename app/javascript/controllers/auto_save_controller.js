import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="auto-save"
export default class extends Controller {
  static targets = ["form", "input", "status", "message", "spinner", "checkmark"]
  static values = { url: String, interval: { type: Number, default: 30000 } }

  connect() {
    console.log("Auto-save controller connected")
    this.initializeAutoSave()
  }

  disconnect() {
    this.cleanup()
  }

  // Initialize auto-save functionality
  initializeAutoSave() {
    this.isEnabled = true
    this.isDirty = false
    this.isSaving = false
    this.lastSaveData = null
    this.conflictResolution = 'user_wins' // 'user_wins', 'server_wins', 'merge'
    
    // Setup auto-save timer
    this.setupAutoSaveTimer()
    
    // Setup change detection
    this.setupChangeDetection()
    
    // Setup conflict detection
    this.setupConflictDetection()
    
    // Load any existing draft
    this.loadExistingDraft()
  }

  // Setup auto-save timer
  setupAutoSaveTimer() {
    this.autoSaveTimer = setInterval(() => {
      if (this.isDirty && !this.isSaving && this.isEnabled) {
        this.autoSave()
      }
    }, this.intervalValue)
  }

  // Setup change detection
  setupChangeDetection() {
    if (!this.hasFormTarget) {return}
    
    // Listen for input changes
    this.inputTargets.forEach(input => {
      input.addEventListener('input', this.handleInputChange.bind(this))
      input.addEventListener('change', this.handleInputChange.bind(this))
    })
    
    // Use MutationObserver for dynamically added inputs
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1) { // Element node
            const newInputs = node.querySelectorAll('[data-auto-save-target="input"]')
            newInputs.forEach(input => {
              input.addEventListener('input', this.handleInputChange.bind(this))
              input.addEventListener('change', this.handleInputChange.bind(this))
            })
          }
        })
      })
    })
    
    this.observer.observe(this.formTarget, {
      childList: true,
      subtree: true
    })
  }

  // Handle input changes
  handleInputChange(event) {
    if (!this.isEnabled || this.isSaving) {return}
    
    this.isDirty = true
    this.showDirtyState()
    
    // Debounce for text inputs
    if (event.target.type === 'text' || event.target.type === 'textarea') {
      this.debounceAutoSave()
    }
  }

  // Debounced auto-save for text inputs
  debounceAutoSave() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    
    this.debounceTimer = setTimeout(() => {
      if (this.isDirty && !this.isSaving) {
        this.autoSave()
      }
    }, 2000) // 2 second debounce
  }

  // Perform auto-save
  async autoSave() {
    if (!this.urlValue || !this.hasFormTarget || this.isSaving) {return}
    
    this.isSaving = true
    this.showSavingState()
    
    try {
      const formData = this.getFormData()
      const currentDataHash = this.hashFormData(formData)
      
      // Skip save if data hasn't actually changed
      if (currentDataHash === this.lastSaveData) {
        this.isSaving = false
        this.hideSavingState()
        return
      }
      
      const response = await this.sendSaveRequest(formData)
      
      if (response.ok) {
        const result = await response.json()
        await this.handleSaveSuccess(result, currentDataHash)
      } else {
        await this.handleSaveError(response)
      }
      
    } catch (error) {
      console.error('Auto-save error:', error)
      this.handleSaveError(error)
    } finally {
      this.isSaving = false
      this.hideSavingState()
    }
  }

  // Get form data for saving
  getFormData() {
    const formData = new FormData(this.formTarget)
    
    // Add auto-save specific parameters
    formData.append('_method', 'PATCH')
    formData.append('auto_save', 'true')
    formData.append('timestamp', Date.now().toString())
    
    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      formData.append('authenticity_token', csrfToken)
    }
    
    return formData
  }

  // Hash form data to detect changes
  hashFormData(formData) {
    const dataArray = Array.from(formData.entries())
      .filter(([key]) => !['_method', 'auto_save', 'timestamp', 'authenticity_token'].includes(key))
      .sort(([a], [b]) => a.localeCompare(b))
    
    return btoa(JSON.stringify(dataArray))
  }

  // Send save request
  async sendSaveRequest(formData) {
    return fetch(this.urlValue, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json'
      }
    })
  }

  // Handle successful save
  async handleSaveSuccess(result, dataHash) {
    this.isDirty = false
    this.lastSaveData = dataHash
    
    // Check for conflicts
    if (result.conflict) {
      await this.handleConflict(result)
    } else {
      this.showSavedState()
      this.storeLocalDraft(result.data)
    }
    
    // Update form with any server-side changes
    if (result.updates) {
      this.applyServerUpdates(result.updates)
    }
  }

  // Handle save error
  async handleSaveError(error) {
    console.error('Save failed:', error)
    
    // Store locally as backup
    this.storeLocalBackup()
    
    this.showErrorState(error.message || 'Failed to save. Data stored locally.')
    
    // Retry logic
    this.scheduleRetry()
  }

  // Handle data conflicts
  async handleConflict(conflictData) {
    const resolution = await this.resolveConflict(conflictData)
    
    switch (resolution.action) {
      case 'use_server':
        this.applyServerUpdates(conflictData.server_data)
        this.showConflictResolvedState('Server version applied')
        break
      case 'use_local':
        // Re-save with override flag
        await this.forceSave()
        this.showConflictResolvedState('Your changes saved')
        break
      case 'merge':
        const mergedData = this.mergeData(conflictData.server_data, conflictData.local_data)
        this.applyServerUpdates(mergedData)
        await this.forceSave()
        this.showConflictResolvedState('Changes merged')
        break
    }
  }

  // Resolve conflicts based on strategy
  async resolveConflict(conflictData) {
    switch (this.conflictResolution) {
      case 'user_wins':
        return { action: 'use_local' }
      case 'server_wins':
        return { action: 'use_server' }
      case 'merge':
        return { action: 'merge' }
      default:
        // Show user dialog
        return await this.showConflictDialog(conflictData)
    }
  }

  // Show conflict resolution dialog
  async showConflictDialog(conflictData) {
    return new Promise((resolve) => {
      const modal = this.createConflictModal(conflictData, resolve)
      document.body.appendChild(modal)
    })
  }

  // Create conflict resolution modal
  createConflictModal(conflictData, resolve) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50'
    modal.innerHTML = `
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-900">Data Conflict Detected</h3>
          <svg class="w-6 h-6 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
          </svg>
        </div>
        
        <p class="text-gray-600 mb-6">
          The form data has been modified by another user or session. Choose how to resolve this conflict:
        </p>
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div class="border rounded-lg p-4">
            <h4 class="font-medium text-gray-900 mb-2">Your Changes</h4>
            <div class="text-sm text-gray-600 bg-gray-50 rounded p-3 max-h-32 overflow-y-auto">
              ${this.formatConflictData(conflictData.local_data)}
            </div>
          </div>
          
          <div class="border rounded-lg p-4">
            <h4 class="font-medium text-gray-900 mb-2">Server Changes</h4>
            <div class="text-sm text-gray-600 bg-gray-50 rounded p-3 max-h-32 overflow-y-auto">
              ${this.formatConflictData(conflictData.server_data)}
            </div>
          </div>
        </div>
        
        <div class="flex flex-col sm:flex-row gap-3">
          <button class="btn btn-primary flex-1" data-action="use_local">
            Keep My Changes
          </button>
          <button class="btn btn-outline flex-1" data-action="use_server">
            Use Server Version
          </button>
          <button class="btn btn-outline flex-1" data-action="merge">
            Try to Merge
          </button>
        </div>
      </div>
    `
    
    // Add event listeners
    modal.querySelectorAll('button[data-action]').forEach(button => {
      button.addEventListener('click', () => {
        const action = button.dataset.action
        resolve({ action })
        document.body.removeChild(modal)
      })
    })
    
    return modal
  }

  // Format conflict data for display
  formatConflictData(data) {
    if (!data) {return 'No changes'}
    
    return Object.entries(data)
      .map(([key, value]) => `${this.humanizeKey(key)}: ${value}`)
      .join('<br>')
  }

  // Humanize form field keys
  humanizeKey(key) {
    return key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  // Force save with override
  async forceSave() {
    const formData = this.getFormData()
    formData.append('force_save', 'true')
    
    try {
      const response = await this.sendSaveRequest(formData)
      if (response.ok) {
        const result = await response.json()
        this.handleSaveSuccess(result, this.hashFormData(formData))
      }
    } catch (error) {
      console.error('Force save failed:', error)
    }
  }

  // Apply server updates to form
  applyServerUpdates(updates) {
    if (!updates) {return}
    
    Object.entries(updates).forEach(([name, value]) => {
      const field = this.formTarget.querySelector(`[name="${name}"]`)
      if (field && field.value !== value) {
        field.value = value
        this.highlightUpdatedField(field)
      }
    })
  }

  // Highlight updated fields
  highlightUpdatedField(field) {
    field.classList.add('bg-yellow-50', 'border-yellow-300')
    
    setTimeout(() => {
      field.classList.remove('bg-yellow-50', 'border-yellow-300')
    }, 3000)
  }

  // Merge data (simple strategy)
  mergeData(serverData, localData) {
    // Simple merge: local data takes precedence for conflicts
    return { ...serverData, ...localData }
  }

  // Store local draft
  storeLocalDraft(data) {
    try {
      const draftKey = this.getDraftKey()
      localStorage.setItem(draftKey, JSON.stringify({
        data,
        timestamp: Date.now()
      }))
    } catch (error) {
      console.error('Failed to store local draft:', error)
    }
  }

  // Store local backup on error
  storeLocalBackup() {
    try {
      const formData = new FormData(this.formTarget)
      const data = Object.fromEntries(formData.entries())
      
      const backupKey = `${this.getDraftKey()  }_backup`
      localStorage.setItem(backupKey, JSON.stringify({
        data,
        timestamp: Date.now(),
        error: true
      }))
    } catch (error) {
      console.error('Failed to store local backup:', error)
    }
  }

  // Load existing draft
  loadExistingDraft() {
    try {
      const draftKey = this.getDraftKey()
      const stored = localStorage.getItem(draftKey)
      
      if (stored) {
        const draft = JSON.parse(stored)
        
        // Check if draft is recent (within last hour)
        const ageMinutes = (Date.now() - draft.timestamp) / (1000 * 60)
        if (ageMinutes < 60) {
          this.showDraftAvailable(draft)
        }
      }
    } catch (error) {
      console.error('Failed to load existing draft:', error)
    }
  }

  // Show draft available notification
  showDraftAvailable(draft) {
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 bg-blue-600 text-white px-4 py-3 rounded-lg shadow-lg z-50 max-w-sm'
    notification.innerHTML = `
      <div class="flex items-start">
        <svg class="w-5 h-5 mt-0.5 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
        </svg>
        <div class="flex-1">
          <p class="text-sm font-medium">Draft available</p>
          <p class="text-xs mt-1 opacity-90">
            Saved ${this.formatTime(draft.timestamp)}
          </p>
          <div class="flex space-x-2 mt-2">
            <button class="text-xs underline hover:no-underline" onclick="this.parentElement.parentElement.parentElement.parentElement.remove()">
              Dismiss
            </button>
            <button class="text-xs underline hover:no-underline" data-action="load-draft">
              Load Draft
            </button>
          </div>
        </div>
      </div>
    `
    
    // Add load draft functionality
    notification.querySelector('[data-action="load-draft"]').addEventListener('click', () => {
      this.loadDraft(draft)
      notification.remove()
    })
    
    document.body.appendChild(notification)
    
    // Auto-hide after 10 seconds
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove()
      }
    }, 10000)
  }

  // Load draft data into form
  loadDraft(draft) {
    if (!draft.data) {return}
    
    Object.entries(draft.data).forEach(([name, value]) => {
      const field = this.formTarget.querySelector(`[name="${name}"]`)
      if (field) {
        field.value = value
        this.highlightUpdatedField(field)
      }
    })
    
    this.showMessage('Draft loaded successfully', 'success')
  }

  // Get draft storage key
  getDraftKey() {
    const formId = this.formTarget.id || 'campaign_form'
    const userId = document.querySelector('meta[name="current-user-id"]')?.content || 'anonymous'
    return `autosave_${formId}_${userId}`
  }

  // Schedule retry on failure
  scheduleRetry() {
    if (this.retryTimer) {
      clearTimeout(this.retryTimer)
    }
    
    this.retryTimer = setTimeout(() => {
      if (this.isDirty && this.isEnabled) {
        this.autoSave()
      }
    }, 10000) // Retry after 10 seconds
  }

  // Setup conflict detection
  setupConflictDetection() {
    // Poll server for updates every 60 seconds
    this.conflictTimer = setInterval(() => {
      this.checkForConflicts()
    }, 60000)
  }

  // Check for conflicts with server
  async checkForConflicts() {
    if (!this.urlValue || this.isSaving) {return}
    
    try {
      const response = await fetch(`${this.urlValue}/check_conflicts`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const result = await response.json()
        if (result.has_conflicts) {
          this.showConflictWarning(result)
        }
      }
    } catch (error) {
      console.error('Conflict check failed:', error)
    }
  }

  // Show conflict warning
  showConflictWarning(conflictData) {
    const warning = document.createElement('div')
    warning.className = 'fixed bottom-4 right-4 bg-yellow-600 text-white px-4 py-3 rounded-lg shadow-lg z-50 max-w-sm'
    warning.innerHTML = `
      <div class="flex items-start">
        <svg class="w-5 h-5 mt-0.5 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
        </svg>
        <div class="flex-1">
          <p class="text-sm font-medium">Data conflicts detected</p>
          <p class="text-xs mt-1 opacity-90">
            Form has been modified elsewhere
          </p>
          <button class="text-xs underline hover:no-underline mt-2" onclick="this.parentElement.parentElement.parentElement.remove()">
            Dismiss
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(warning)
    
    setTimeout(() => {
      if (warning.parentElement) {
        warning.remove()
      }
    }, 8000)
  }

  // State management methods
  showDirtyState() {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.remove('hidden')
      this.updateStatusMessage('Unsaved changes')
    }
  }

  showSavingState() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove('hidden')
    }
    if (this.hasCheckmarkTarget) {
      this.checkmarkTarget.classList.add('hidden')
    }
    this.updateStatusMessage('Saving...')
  }

  showSavedState() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('hidden')
    }
    if (this.hasCheckmarkTarget) {
      this.checkmarkTarget.classList.remove('hidden')
    }
    this.updateStatusMessage('All changes saved')
    
    // Hide status after 3 seconds
    setTimeout(() => {
      if (this.hasStatusTarget && !this.isDirty) {
        this.statusTarget.classList.add('hidden')
      }
    }, 3000)
  }

  showErrorState(message) {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('hidden')
    }
    if (this.hasCheckmarkTarget) {
      this.checkmarkTarget.classList.add('hidden')
    }
    this.updateStatusMessage(message, 'error')
  }

  showConflictResolvedState(message) {
    this.updateStatusMessage(message, 'success')
    setTimeout(() => {
      this.showSavedState()
    }, 2000)
  }

  hideSavingState() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('hidden')
    }
  }

  updateStatusMessage(message, type = 'info') {
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = message
      
      // Update styling based on type
      const statusElement = this.hasStatusTarget ? this.statusTarget : null
      if (statusElement) {
        statusElement.className = statusElement.className.replace(/bg-\w+-\d+/g, '')
        switch (type) {
          case 'error':
            statusElement.classList.add('bg-red-50')
            break
          case 'success':
            statusElement.classList.add('bg-green-50')
            break
          default:
            statusElement.classList.add('bg-gray-25')
        }
      }
    }
  }

  showMessage(message, type = 'info') {
    const toast = document.createElement('div')
    const bgColor = type === 'error' ? 'bg-red-600' : 'bg-green-600'
    toast.className = `fixed top-4 right-4 ${bgColor} text-white px-4 py-2 rounded-lg shadow-lg z-50`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      if (toast.parentElement) {
        toast.remove()
      }
    }, 3000)
  }

  formatTime(timestamp) {
    const date = new Date(timestamp)
    const now = new Date()
    const diffMinutes = Math.floor((now - date) / (1000 * 60))
    
    if (diffMinutes < 1) {return 'just now'}
    if (diffMinutes < 60) {return `${diffMinutes}m ago`}
    
    const diffHours = Math.floor(diffMinutes / 60)
    if (diffHours < 24) {return `${diffHours}h ago`}
    
    return date.toLocaleDateString()
  }

  // Public methods for external control
  enable() {
    this.isEnabled = true
  }

  disable() {
    this.isEnabled = false
  }

  forceSaveNow() {
    if (this.isDirty) {
      this.autoSave()
    }
  }

  // Cleanup
  cleanup() {
    if (this.autoSaveTimer) {
      clearInterval(this.autoSaveTimer)
    }
    if (this.conflictTimer) {
      clearInterval(this.conflictTimer)
    }
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.retryTimer) {
      clearTimeout(this.retryTimer)
    }
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}