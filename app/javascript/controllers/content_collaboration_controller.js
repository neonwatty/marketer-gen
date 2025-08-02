import { Controller } from "@hotwired/stimulus"
import { getCollaborationWebSocket } from "../utils/collaborationWebSocket"
import { getPresenceSystem } from "../utils/presenceSystem"
import { OperationalTransformEngine, TextChangeDetector } from "../utils/operationalTransforms"

export default class extends Controller {
  static targets = [
    "editor", 
    "presenceIndicator",
    "versionInfo",
    "collaboratorsList",
    "loadingOverlay",
    "errorMessage",
    "conflictModal",
    "saveStatus"
  ]
  
  static values = {
    contentId: Number,
    currentUser: Object,
    initialContent: String,
    initialVersion: Number
  }

  connect() {
    console.log("Content collaboration controller connected")
    
    this.websocket = getCollaborationWebSocket()
    this.presenceSystem = getPresenceSystem()
    this.subscription = null
    this.changeDetector = new TextChangeDetector()
    this.pendingOperations = []
    this.serverOperations = []
    this.currentVersion = this.initialVersionValue || 1
    this.isApplyingRemoteChange = false
    this.cursorPositions = new Map()
    this.saveTimeout = null
    
    this.setupCollaboration()
    this.setupPresenceSystem()
    this.setupEditor()
    this.initializeChangeDetector()
  }

  disconnect() {
    console.log("Content collaboration controller disconnected")
    
    if (this.subscription) {
      this.websocket.unsubscribe(this.subscription.identifier)
    }
    
    this.presenceSystem.destroy()
    this.cleanup()
  }

  setupCollaboration() {
    this.subscription = this.websocket.subscribe(
      'ContentCollaborationChannel',
      { content_id: this.contentIdValue }
    )

    // Set up message handlers
    this.websocket.on('content:updated', (data) => this.handleContentUpdate(data))
    this.websocket.on('content:cursor_moved', (data) => this.handleCursorMoved(data))
    this.websocket.on('content:selection_changed', (data) => this.handleSelectionChanged(data))
    this.websocket.on('user:joined', (data) => this.handleUserJoined(data))
    this.websocket.on('user:left', (data) => this.handleUserLeft(data))
    this.websocket.on('operational_transform', (data) => this.handleOperationalTransform(data))
  }

  setupPresenceSystem() {
    this.presenceSystem.initialize(
      this.currentUserValue,
      `content_${this.contentIdValue}`
    )

    this.presenceSystem.setCallbacks({
      onUserJoined: (presence) => this.updateCollaboratorsList(),
      onUserLeft: (presence) => this.updateCollaboratorsList(),
      onUserStatusChanged: (presence) => this.updateCollaboratorsList(),
      onCursorMoved: (userId, position) => this.updateCursorPosition(userId, position)
    })
  }

  setupEditor() {
    if (!this.hasEditorTarget) {return}

    const editor = this.editorTarget
    
    // Set initial content
    editor.value = this.initialContentValue || ''
    
    // Set up event handlers
    editor.addEventListener('input', (e) => this.handleEditorInput(e))
    editor.addEventListener('selectionchange', (e) => this.handleSelectionChange(e))
    editor.addEventListener('focus', (e) => this.handleEditorFocus(e))
    editor.addEventListener('blur', (e) => this.handleEditorBlur(e))
    
    // Prevent browser's default undo/redo
    editor.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && (e.key === 'z' || e.key === 'y')) {
        e.preventDefault()
        // TODO: Implement collaborative undo/redo
      }
      
      // Save shortcut
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault()
        this.saveContent()
      }
    })
  }

  initializeChangeDetector() {
    const editor = this.editorTarget
    if (!editor) {return}

    this.changeDetector.reset(
      editor.value,
      { start: editor.selectionStart || 0, end: editor.selectionEnd || 0 }
    )
  }

  handleEditorInput(event) {
    if (this.isApplyingRemoteChange) {return}

    const editor = event.target
    const newText = editor.value
    const selection = {
      start: editor.selectionStart || 0,
      end: editor.selectionEnd || 0
    }

    // Detect what changed
    const operations = this.changeDetector.updateText(newText, selection)
    
    if (operations && operations.length > 0) {
      console.log('Local change detected:', operations)
      
      // Apply operation locally (optimistic update)
      this.applyLocalOperation(operations)
      
      // Send to server
      this.sendContentUpdate(operations)
      
      // Update save status
      this.updateSaveStatus('unsaved')
      
      // Schedule auto-save
      this.scheduleAutoSave()
    }
  }

  applyLocalOperation(operations) {
    // Add to pending operations queue
    this.pendingOperations.push({
      operations,
      timestamp: Date.now(),
      version: this.currentVersion
    })
    
    // Update version info
    this.updateVersionInfo(`v${this.currentVersion} (editing...)`)
  }

  async sendContentUpdate(operations) {
    try {
      await this.websocket.sendMessage({
        id: this.generateOperationId(),
        type: 'content_update',
        channel: 'content_collaboration',
        data: {
          operations,
          version: this.currentVersion,
          content_id: this.contentIdValue
        },
        timestamp: new Date().toISOString(),
        retry_count: 0,
        max_retries: 3
      })
    } catch (error) {
      console.error('Failed to send content update:', error)
      this.showError('Failed to sync changes')
    }
  }

  handleContentUpdate(data) {
    console.log('Received content update:', data)
    
    // Don't process our own updates
    if (data.user.id === this.currentUserValue.id) {
      this.handleOwnUpdateAcknowledged(data)
      return
    }

    this.applyRemoteOperation(data.operations, data.version, data.user)
  }

  handleOperationalTransform(data) {
    console.log('Received operational transform:', data)
    
    if (data.user.id !== this.currentUserValue.id) {
      this.applyRemoteOperation(data.operation.operations, data.version, data.user)
    }
  }

  applyRemoteOperation(operations, version, user) {
    this.isApplyingRemoteChange = true
    
    try {
      const editor = this.editorTarget
      if (!editor) {return}

      // Store current selection
      const currentSelection = {
        start: editor.selectionStart || 0,
        end: editor.selectionEnd || 0
      }

      // Transform remote operations against pending local operations
      let transformedOperations = operations
      
      if (this.pendingOperations.length > 0) {
        transformedOperations = this.transformRemoteOperations(operations)
      }

      // Apply transformed operations to editor
      const oldText = editor.value
      const newText = OperationalTransformEngine.apply(oldText, transformedOperations)
      
      editor.value = newText
      
      // Transform and restore selection
      const newSelection = this.transformSelection(currentSelection, transformedOperations)
      editor.setSelectionRange(newSelection.start, newSelection.end)
      
      // Update change detector
      this.changeDetector.reset(newText, newSelection)
      
      // Update version
      this.currentVersion = version
      this.updateVersionInfo(`v${version} (updated by ${user.name})`)
      
      // Show update notification
      this.showUpdateNotification(`${user.name} made changes`)
      
      // Store server operations for future transforms
      this.serverOperations.push({
        operations: transformedOperations,
        version,
        user,
        timestamp: Date.now()
      })
      
    } catch (error) {
      console.error('Error applying remote operation:', error)
      this.showError('Failed to apply remote changes')
    } finally {
      this.isApplyingRemoteChange = false
    }
  }

  transformRemoteOperations(remoteOperations) {
    let transformed = remoteOperations
    
    // Transform against each pending local operation
    for (const pending of this.pendingOperations) {
      const result = OperationalTransformEngine.transform(pending.operations, transformed)
      transformed = result.operationB
      pending.operations = result.operationA // Update pending operation
    }
    
    return transformed
  }

  transformSelection(selection, operations) {
    let newStart = selection.start
    let newEnd = selection.end
    let offset = 0
    
    for (const op of operations) {
      switch (op.type) {
        case 'retain':
          offset += op.length || 0
          break
          
        case 'insert':
          const insertLength = op.text?.length || 0
          if (offset <= newStart) {
            newStart += insertLength
            newEnd += insertLength
          } else if (offset < newEnd) {
            newEnd += insertLength
          }
          break
          
        case 'delete':
          const deleteLength = op.length || 0
          if (offset + deleteLength <= newStart) {
            newStart -= deleteLength
            newEnd -= deleteLength
          } else if (offset < newStart) {
            const deletedFromStart = Math.min(deleteLength, newStart - offset)
            newStart -= deletedFromStart
            newEnd -= deletedFromStart
            
            if (offset + deleteLength < newEnd) {
              newEnd -= (deleteLength - deletedFromStart)
            }
          } else if (offset < newEnd) {
            newEnd = Math.max(newStart, newEnd - Math.min(deleteLength, newEnd - offset))
          }
          offset += deleteLength
          break
      }
    }
    
    return {
      start: Math.max(0, newStart),
      end: Math.max(0, newEnd)
    }
  }

  handleOwnUpdateAcknowledged(data) {
    // Remove corresponding pending operation
    if (this.pendingOperations.length > 0) {
      this.pendingOperations.shift() // Remove oldest pending operation
    }
    
    // Update version
    this.currentVersion = data.version
    this.updateVersionInfo(`v${data.version}`)
    this.updateSaveStatus('saved')
  }

  handleSelectionChange(event) {
    if (this.isApplyingRemoteChange) {return}

    const editor = event.target || this.editorTarget
    if (!editor) {return}

    const selection = {
      start: editor.selectionStart || 0,
      end: editor.selectionEnd || 0
    }

    // Update presence system with cursor position
    this.presenceSystem.updateCursorPosition({
      x: 0, // We'll calculate this based on text position
      y: 0,
      element_id: editor.id,
      selection_start: selection.start,
      selection_end: selection.end
    })

    // Send selection change to other users
    this.sendSelectionChange(selection)
  }

  async sendSelectionChange(selection) {
    try {
      await this.websocket.sendMessage({
        id: this.generateOperationId(),
        type: 'selection_change',
        channel: 'content_collaboration',
        data: {
          start: selection.start,
          end: selection.end,
          direction: selection.start <= selection.end ? 'forward' : 'backward'
        },
        timestamp: new Date().toISOString(),
        retry_count: 0,
        max_retries: 1
      })
    } catch (error) {
      // Selection changes are not critical - don't show errors
      console.warn('Failed to send selection change:', error)
    }
  }

  handleCursorMoved(data) {
    if (data.user.id !== this.currentUserValue.id) {
      this.showUserCursor(data.user, data.cursor)
    }
  }

  handleSelectionChanged(data) {
    if (data.user.id !== this.currentUserValue.id) {
      this.showUserSelection(data.user, data.selection)
    }
  }

  showUserCursor(user, cursor) {
    const editor = this.editorTarget
    if (!editor) {return}

    // Remove existing cursor for this user
    this.removeUserCursor(user.id)

    // Calculate pixel position from text position
    const position = this.calculateCursorPosition(cursor.position)
    
    // Create cursor element
    const cursorElement = document.createElement('div')
    cursorElement.className = 'collaboration-cursor'
    cursorElement.dataset.userId = user.id
    cursorElement.style.cssText = `
      position: absolute;
      left: ${position.x}px;
      top: ${position.y}px;
      width: 2px;
      height: 20px;
      background-color: ${cursor.color};
      pointer-events: none;
      z-index: 1000;
    `
    
    // Add user label
    const label = document.createElement('div')
    label.className = 'cursor-label'
    label.textContent = user.name
    label.style.cssText = `
      position: absolute;
      left: 0;
      top: -25px;
      background: ${cursor.color};
      color: white;
      padding: 2px 6px;
      border-radius: 3px;
      font-size: 12px;
      white-space: nowrap;
    `
    
    cursorElement.appendChild(label)
    document.body.appendChild(cursorElement)
    
    this.cursorPositions.set(user.id, cursorElement)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (this.cursorPositions.get(user.id) === cursorElement) {
        this.removeUserCursor(user.id)
      }
    }, 5000)
  }

  showUserSelection(user, selection) {
    // TODO: Implement visual selection indicators
    console.log(`${user.name} selected text from ${selection.start} to ${selection.end}`)
  }

  calculateCursorPosition(textPosition) {
    const editor = this.editorTarget
    if (!editor) {return { x: 0, y: 0 }}

    // Create a temporary element to measure text
    const measureElement = document.createElement('div')
    measureElement.style.cssText = `
      position: absolute;
      visibility: hidden;
      white-space: pre-wrap;
      font-family: ${getComputedStyle(editor).fontFamily};
      font-size: ${getComputedStyle(editor).fontSize};
      line-height: ${getComputedStyle(editor).lineHeight};
      padding: ${getComputedStyle(editor).padding};
      border: ${getComputedStyle(editor).border};
      width: ${editor.offsetWidth}px;
    `
    
    const textBeforeCursor = editor.value.substring(0, textPosition)
    measureElement.textContent = textBeforeCursor
    
    document.body.appendChild(measureElement)
    
    const rect = editor.getBoundingClientRect()
    const measureRect = measureElement.getBoundingClientRect()
    
    const position = {
      x: rect.left + measureRect.width,
      y: rect.top + measureRect.height
    }
    
    document.body.removeChild(measureElement)
    
    return position
  }

  removeUserCursor(userId) {
    const cursor = this.cursorPositions.get(userId)
    if (cursor) {
      cursor.remove()
      this.cursorPositions.delete(userId)
    }
  }

  handleUserJoined(data) {
    console.log('User joined:', data)
    this.updateCollaboratorsList()
    this.showUpdateNotification(`${data.user.name} joined the editing session`)
  }

  handleUserLeft(data) {
    console.log('User left:', data)
    this.updateCollaboratorsList()
    this.removeUserCursor(data.user.id)
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

  handleEditorFocus(event) {
    // User started editing
    this.presenceSystem.setStatus('online')
  }

  handleEditorBlur(event) {
    // User stopped editing - set to idle after delay
    setTimeout(() => {
      if (document.activeElement !== this.editorTarget) {
        this.presenceSystem.setStatus('idle')
      }
    }, 1000)
  }

  scheduleAutoSave() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
    
    this.saveTimeout = setTimeout(() => {
      this.saveContent()
    }, 2000) // Auto-save every 2 seconds of inactivity
  }

  async saveContent() {
    const editor = this.editorTarget
    if (!editor) {return}

    this.updateSaveStatus('saving')
    
    try {
      const response = await fetch(`/content_repositories/${this.contentIdValue}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        },
        body: JSON.stringify({
          content_repository: {
            body: editor.value
          }
        })
      })
      
      if (response.ok) {
        this.updateSaveStatus('saved')
        console.log('Content saved successfully')
      } else {
        throw new Error('Save failed')
      }
    } catch (error) {
      console.error('Save error:', error)
      this.updateSaveStatus('error')
      this.showError('Failed to save content')
    }
  }

  updateVersionInfo(text) {
    if (this.hasVersionInfoTarget) {
      this.versionInfoTarget.textContent = text
    }
  }

  updateSaveStatus(status) {
    if (!this.hasSaveStatusTarget) {return}

    const statusElement = this.saveStatusTarget
    statusElement.className = `save-status status-${status}`
    
    const statusText = {
      'saved': 'All changes saved',
      'unsaved': 'Unsaved changes',
      'saving': 'Saving...',
      'error': 'Save failed'
    }
    
    statusElement.textContent = statusText[status] || status
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

  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.add('show')
      
      setTimeout(() => {
        this.errorMessageTarget.classList.remove('show')
      }, 5000)
    }
  }

  generateOperationId() {
    return `op_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  cleanup() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
    
    // Clear cursor positions
    this.cursorPositions.forEach(cursor => cursor.remove())
    this.cursorPositions.clear()
    
    // Clear pending operations
    this.pendingOperations.length = 0
    this.serverOperations.length = 0
  }
}