import { Controller } from "@hotwired/stimulus"
import { getCollaborationWebSocket } from "../utils/collaborationWebSocket"
import { getPresenceSystem } from "../utils/presenceSystem"

export default class extends Controller {
  static targets = [
    "planField",
    "presenceIndicator", 
    "conflictModal",
    "commentsSidebar",
    "loadingOverlay",
    "errorMessage",
    "versionInfo",
    "collaboratorsList",
    "conflictResolution"
  ]
  
  static values = {
    campaignPlanId: Number,
    currentUser: Object,
    initialVersion: Number
  }

  connect() {
    console.log("Campaign collaboration controller connected")
    
    this.websocket = getCollaborationWebSocket()
    this.presenceSystem = getPresenceSystem()
    this.subscription = null
    this.pendingUpdates = new Map()
    this.conflictQueue = []
    this.currentVersion = this.initialVersionValue || 1.0
    this.isUpdating = false
    this.cursorPositions = new Map()
    
    this.setupCollaboration()
    this.setupPresenceSystem()
    this.setupEventListeners()
    this.setupConflictResolution()
  }

  disconnect() {
    console.log("Campaign collaboration controller disconnected")
    
    if (this.subscription) {
      this.websocket.unsubscribe(this.subscription.identifier)
    }
    
    this.presenceSystem.destroy()
    this.cleanup()
  }

  setupCollaboration() {
    this.subscription = this.websocket.subscribe(
      'CampaignCollaborationChannel',
      { campaign_plan_id: this.campaignPlanIdValue }
    )

    // Set up message handlers
    this.websocket.on('plan:updated', (data) => this.handlePlanUpdate(data))
    this.websocket.on('plan:comment_added', (data) => this.handleCommentAdded(data))
    this.websocket.on('user:joined', (data) => this.handleUserJoined(data))
    this.websocket.on('user:left', (data) => this.handleUserLeft(data))
    this.websocket.on('conflict:detected', (data) => this.handleConflictDetected(data))
    this.websocket.on('optimistic:confirmed', (data) => this.handleOptimisticConfirmed(data))
    this.websocket.on('optimistic:failed', (data) => this.handleOptimisticFailed(data))
  }

  setupPresenceSystem() {
    this.presenceSystem.initialize(
      this.currentUserValue,
      `campaign_plan_${this.campaignPlanIdValue}`
    )

    this.presenceSystem.setCallbacks({
      onUserJoined: (_presence) => this.updateCollaboratorsList(),
      onUserLeft: (_presence) => this.updateCollaboratorsList(),
      onUserStatusChanged: (_presence) => this.updateCollaboratorsList(),
      onCursorMoved: (userId, position) => this.updateCursorPosition(userId, position)
    })
  }

  setupEventListeners() {
    // Listen for field changes
    this.planFieldTargets.forEach(field => {
      field.addEventListener('input', this.debounce((e) => {
        this.handleFieldChange(e)
      }, 500))
      
      field.addEventListener('focus', (e) => {
        this.handleFieldFocus(e)
      })
      
      field.addEventListener('blur', (e) => {
        this.handleFieldBlur(e)
      })
      
      // Track cursor position for text inputs and textareas
      if (field.tagName === 'INPUT' || field.tagName === 'TEXTAREA') {
        field.addEventListener('selectionchange', (e) => {
          this.handleSelectionChange(e)
        })
      }
    })

    // Listen for keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault()
        this.saveChanges()
      }
    })
  }

  setupConflictResolution() {
    // Set up conflict resolution modal handlers
    if (this.hasConflictModalTarget) {
      const acceptLocalBtn = this.conflictModalTarget.querySelector('[data-action="accept-local"]')
      const acceptRemoteBtn = this.conflictModalTarget.querySelector('[data-action="accept-remote"]')
      const mergeBtn = this.conflictModalTarget.querySelector('[data-action="merge"]')

      acceptLocalBtn?.addEventListener('click', () => this.resolveConflict('local_wins'))
      acceptRemoteBtn?.addEventListener('click', () => this.resolveConflict('remote_wins'))
      mergeBtn?.addEventListener('click', () => this.resolveConflict('merge'))
    }
  }

  handleFieldChange(event) {
    const field = event.target
    const fieldName = field.dataset.field
    const newValue = this.getFieldValue(field)
    const oldValue = field.dataset.originalValue

    if (newValue === oldValue) {return}

    console.log(`Field ${fieldName} changed:`, { oldValue, newValue })

    // Show optimistic update immediately
    this.showOptimisticUpdate(field, newValue)
    
    // Send update to server
    this.sendPlanUpdate(fieldName, oldValue, newValue)
  }

  getFieldValue(field) {
    if (field.type === 'checkbox') {
      return field.checked
    } else if (field.dataset.jsonField) {
      try {
        return JSON.parse(field.value)
      } catch (_e) {
        return field.value
      }
    }
    return field.value
  }

  showOptimisticUpdate(field, newValue) {
    // Add visual indicator for optimistic update
    field.classList.add('updating')
    field.dataset.originalValue = newValue
    
    // Update version info
    this.updateVersionInfo(`Updating... (v${this.currentVersion})`)
  }

  async sendPlanUpdate(fieldName, oldValue, newValue) {
    const updateId = this.generateUpdateId()
    
    this.pendingUpdates.set(updateId, {
      field: fieldName,
      oldValue,
      newValue,
      timestamp: new Date().toISOString()
    })

    try {
      await this.websocket.sendMessage({
        id: updateId,
        type: 'plan_update',
        channel: 'campaign_collaboration',
        data: {
          field: fieldName,
          old_value: oldValue,
          new_value: newValue,
          version: this.currentVersion,
          update_id: updateId
        },
        timestamp: new Date().toISOString(),
        retry_count: 0,
        max_retries: 3
      })
    } catch (error) {
      console.error('Failed to send plan update:', error)
      this.handleUpdateError(updateId, error)
    }
  }

  handlePlanUpdate(data) {
    console.log('Received plan update:', data)
    
    // Don't process our own updates
    if (data.user.id === this.currentUserValue.id) {
      this.handleOptimisticConfirmed({ update_id: data.message_id })
      return
    }

    const field = this.findFieldByName(data.field)
    if (!field) {return}

    // Check for conflicts
    if (data.conflict_resolution?.conflict_detected) {
      this.handleConflictDetected(data)
      return
    }

    // Apply remote update
    this.applyRemoteUpdate(field, data.new_value, data.version)
    
    // Update version
    this.currentVersion = data.version
    this.updateVersionInfo(`v${this.currentVersion} (updated by ${data.user.name})`)
    
    // Show update notification
    this.showUpdateNotification(`${data.user.name} updated ${data.field}`)
  }

  applyRemoteUpdate(field, newValue, _version) {
    // Apply the update with visual feedback
    field.classList.add('remote-update')
    
    if (field.type === 'checkbox') {
      field.checked = newValue
    } else if (field.dataset.jsonField && typeof newValue === 'object') {
      field.value = JSON.stringify(newValue, null, 2)
    } else {
      field.value = newValue
    }
    
    field.dataset.originalValue = newValue
    
    // Remove visual feedback after animation
    setTimeout(() => {
      field.classList.remove('remote-update')
    }, 1000)
  }

  handleConflictDetected(data) {
    console.log('Conflict detected:', data)
    
    this.conflictQueue.push(data)
    this.showConflictModal(data)
  }

  showConflictModal(conflictData) {
    if (!this.hasConflictModalTarget) {return}

    const modal = this.conflictModalTarget
    const _field = this.findFieldByName(conflictData.field)
    
    // Populate conflict information
    modal.querySelector('[data-field-name]').textContent = conflictData.field
    modal.querySelector('[data-local-value]').textContent = this.formatValue(conflictData.conflict_resolution.client_value)
    modal.querySelector('[data-remote-value]').textContent = this.formatValue(conflictData.conflict_resolution.server_value)
    modal.querySelector('[data-remote-user]').textContent = conflictData.user.name
    
    // Store conflict data for resolution
    modal.dataset.conflictData = JSON.stringify(conflictData)
    
    // Show modal
    modal.classList.add('active')
  }

  resolveConflict(resolution) {
    const modal = this.conflictModalTarget
    const conflictData = JSON.parse(modal.dataset.conflictData)
    
    let resolvedValue
    
    switch (resolution) {
      case 'local_wins':
        resolvedValue = conflictData.conflict_resolution.client_value
        break
      case 'remote_wins':
        resolvedValue = conflictData.conflict_resolution.server_value
        break
      case 'merge':
        resolvedValue = this.mergeValues(
          conflictData.conflict_resolution.client_value,
          conflictData.conflict_resolution.server_value,
          conflictData.field
        )
        break
    }

    // Apply resolution
    const field = this.findFieldByName(conflictData.field)
    if (field) {
      this.applyRemoteUpdate(field, resolvedValue, conflictData.version)
    }

    // Send resolution to server
    this.sendConflictResolution(conflictData, resolution, resolvedValue)
    
    // Hide modal
    modal.classList.remove('active')
    
    // Process next conflict if any
    this.conflictQueue.shift()
    if (this.conflictQueue.length > 0) {
      setTimeout(() => this.showConflictModal(this.conflictQueue[0]), 100)
    }
  }

  mergeValues(localValue, remoteValue, _fieldName) {
    // Simple merge logic - can be enhanced based on field type
    if (Array.isArray(localValue) && Array.isArray(remoteValue)) {
      // Merge arrays by combining unique items
      const combined = [...localValue, ...remoteValue]
      return combined.filter((item, index, arr) => 
        arr.findIndex(i => JSON.stringify(i) === JSON.stringify(item)) === index
      )
    } else if (typeof localValue === 'object' && typeof remoteValue === 'object') {
      // Merge objects
      return { ...remoteValue, ...localValue }
    } else {
      // For simple values, prefer local
      return localValue
    }
  }

  async sendConflictResolution(conflictData, resolution, resolvedValue) {
    await this.websocket.sendMessage({
      id: this.generateUpdateId(),
      type: 'conflict_resolution',
      channel: 'campaign_collaboration',
      data: {
        conflict_id: conflictData.message_id,
        field: conflictData.field,
        resolution_strategy: resolution,
        resolved_value: resolvedValue,
        version: conflictData.version
      },
      timestamp: new Date().toISOString(),
      retry_count: 0,
      max_retries: 2
    })
  }

  handleCommentAdded(data) {
    console.log('Comment added:', data)
    
    if (this.hasCommentsSidebarTarget) {
      this.addCommentToSidebar(data.comment)
    }
    
    // Show notification if comment is not from current user
    if (data.user.id !== this.currentUserValue.id) {
      this.showUpdateNotification(`${data.user.name} added a comment`)
    }
  }

  addCommentToSidebar(comment) {
    const sidebar = this.commentsSidebarTarget
    const commentElement = document.createElement('div')
    commentElement.className = 'comment-item'
    commentElement.innerHTML = `
      <div class="comment-header">
        <img src="${comment.user.avatar_url || '/default-avatar.png'}" alt="" class="user-avatar">
        <span class="user-name">${comment.user.name}</span>
        <span class="comment-time">${this.formatTime(comment.created_at)}</span>
      </div>
      <div class="comment-content">${this.escapeHtml(comment.content)}</div>
      ${comment.field_reference ? `<div class="field-reference">Re: ${comment.field_reference}</div>` : ''}
    `
    
    sidebar.appendChild(commentElement)
    sidebar.scrollTop = sidebar.scrollHeight
  }

  handleUserJoined(data) {
    console.log('User joined:', data)
    this.updateCollaboratorsList()
    this.showUpdateNotification(`${data.user.name} joined the collaboration`)
  }

  handleUserLeft(data) {
    console.log('User left:', data)
    this.updateCollaboratorsList()
    this.removeCursorPosition(data.user.id)
  }

  updateCollaboratorsList() {
    if (!this.hasCollaboratorsListTarget) {return}

    const collaborators = this.presenceSystem.getOnlineUsers()
    const list = this.collaboratorsListTarget
    
    list.innerHTML = collaborators.map(presence => `
      <div class="collaborator-item" data-user-id="${presence.user.id}">
        <img src="${presence.user.avatar_url || '/default-avatar.png'}" alt="" class="user-avatar">
        <span class="user-name">${presence.user.name}</span>
        <span class="user-status status-${presence.status}"></span>
      </div>
    `).join('')
  }

  handleFieldFocus(event) {
    const field = event.target
    const fieldName = field.dataset.field
    
    // Send cursor position update
    this.presenceSystem.updateCursorPosition({
      x: event.clientX,
      y: event.clientY,
      element_id: field.id,
      selection_start: field.selectionStart,
      selection_end: field.selectionEnd
    })
  }

  handleFieldBlur(event) {
    // Clear cursor position
    this.presenceSystem.updateCursorPosition({
      x: 0,
      y: 0,
      element_id: null
    })
  }

  handleSelectionChange(event) {
    const field = event.target
    
    // Throttled cursor position updates
    if (field.selectionStart !== undefined) {
      this.presenceSystem.updateCursorPosition({
        x: event.clientX || 0,
        y: event.clientY || 0,
        element_id: field.id,
        selection_start: field.selectionStart,
        selection_end: field.selectionEnd
      })
    }
  }

  updateCursorPosition(userId, position) {
    // Remove existing cursor for this user
    this.removeCursorPosition(userId)
    
    if (!position.element_id) {return}
    
    const element = document.getElementById(position.element_id)
    if (!element) {return}
    
    // Create cursor indicator
    const cursor = document.createElement('div')
    cursor.className = 'collaboration-cursor'
    cursor.dataset.userId = userId
    cursor.style.left = `${position.x}px`
    cursor.style.top = `${position.y}px`
    
    // Add user info tooltip
    const userPresence = this.presenceSystem.getUserPresence(userId)
    if (userPresence) {
      cursor.innerHTML = `
        <div class="cursor-pointer"></div>
        <div class="cursor-label">${userPresence.user.name}</div>
      `
    }
    
    document.body.appendChild(cursor)
    this.cursorPositions.set(userId, cursor)
    
    // Auto-remove after 5 seconds of inactivity
    setTimeout(() => {
      if (this.cursorPositions.get(userId) === cursor) {
        this.removeCursorPosition(userId)
      }
    }, 5000)
  }

  removeCursorPosition(userId) {
    const cursor = this.cursorPositions.get(userId)
    if (cursor) {
      cursor.remove()
      this.cursorPositions.delete(userId)
    }
  }

  handleOptimisticConfirmed(data) {
    const updateId = data.update_id
    const pendingUpdate = this.pendingUpdates.get(updateId)
    
    if (pendingUpdate) {
      const field = this.findFieldByName(pendingUpdate.field)
      if (field) {
        field.classList.remove('updating')
        field.classList.add('confirmed')
        setTimeout(() => field.classList.remove('confirmed'), 1000)
      }
      
      this.pendingUpdates.delete(updateId)
    }
  }

  handleOptimisticFailed(data) {
    const updateId = data.update_id
    const pendingUpdate = this.pendingUpdates.get(updateId)
    
    if (pendingUpdate) {
      const field = this.findFieldByName(pendingUpdate.field)
      if (field) {
        field.classList.remove('updating')
        field.classList.add('failed')
        
        // Revert to original value
        field.value = pendingUpdate.oldValue
        field.dataset.originalValue = pendingUpdate.oldValue
        
        setTimeout(() => field.classList.remove('failed'), 3000)
      }
      
      this.pendingUpdates.delete(updateId)
      this.showErrorMessage(`Failed to update ${pendingUpdate.field}: ${data.error_message}`)
    }
  }

  handleUpdateError(updateId, error) {
    this.handleOptimisticFailed({
      update_id: updateId,
      error_message: error.message
    })
  }

  findFieldByName(fieldName) {
    return this.planFieldTargets.find(field => field.dataset.field === fieldName)
  }

  updateVersionInfo(text) {
    if (this.hasVersionInfoTarget) {
      this.versionInfoTarget.textContent = text
    }
  }

  showUpdateNotification(message) {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = 'collaboration-toast'
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    // Animate in
    setTimeout(() => toast.classList.add('show'), 100)
    
    // Remove after 3 seconds
    setTimeout(() => {
      toast.classList.remove('show')
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  showErrorMessage(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.add('show')
      
      setTimeout(() => {
        this.errorMessageTarget.classList.remove('show')
      }, 5000)
    }
  }

  saveChanges() {
    // Force save all pending changes
    this.planFieldTargets.forEach(field => {
      if (field.classList.contains('updating')) {
        const event = new Event('input', { bubbles: true })
        field.dispatchEvent(event)
      }
    })
  }

  formatValue(value) {
    if (typeof value === 'object') {
      return JSON.stringify(value, null, 2)
    }
    return String(value)
  }

  formatTime(timestamp) {
    return new Date(timestamp).toLocaleTimeString()
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  generateUpdateId() {
    return `update_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  debounce(func, delay) {
    let timeoutId
    return (...args) => {
      clearTimeout(timeoutId)
      timeoutId = setTimeout(() => func.apply(this, args), delay)
    }
  }

  cleanup() {
    // Clear any running timers
    this.cursorPositions.forEach(cursor => cursor.remove())
    this.cursorPositions.clear()
    
    // Clear pending updates
    this.pendingUpdates.clear()
    this.conflictQueue.length = 0
  }
}