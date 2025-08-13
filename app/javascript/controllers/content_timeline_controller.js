import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeline", "filters", "sidebar", "item"]
  static values = { 
    eventsUrl: String,
    timeRange: { type: String, default: "7d" },
    groupBy: { type: String, default: "platform" },
    autoRefresh: { type: Boolean, default: false },
    refreshInterval: { type: Number, default: 300000 } // 5 minutes
  }

  connect() {
    this.loadTimelineData()
    this.setupFilters()
    this.setupAutoRefresh()
    this.bindEventHandlers()
  }

  disconnect() {
    this.clearAutoRefresh()
  }

  async loadTimelineData() {
    try {
      this.showLoading()
      
      const params = new URLSearchParams({
        time_range: this.timeRangeValue,
        group_by: this.groupByValue
      })
      
      const response = await fetch(`${this.eventsUrlValue}?${params}`)
      const data = await response.json()
      
      this.renderTimeline(data)
      this.hideLoading()
    } catch (error) {
      console.error('Error loading timeline data:', error)
      this.showError('Failed to load timeline data')
    }
  }

  renderTimeline(data) {
    if (!this.hasTimelineTarget) return
    
    const timeline = this.timelineTarget
    timeline.innerHTML = ''
    
    // Create timeline header
    const header = this.createTimelineHeader(data.dateRange)
    timeline.appendChild(header)
    
    // Create timeline content based on grouping
    const content = this.createTimelineContent(data)
    timeline.appendChild(content)
    
    // Update sidebar with statistics
    this.updateSidebar(data.statistics)
  }

  createTimelineHeader(dateRange) {
    const header = document.createElement('div')
    header.className = 'timeline-header flex items-center justify-between p-4 bg-gray-50 border-b'
    
    const dateLabels = this.generateDateLabels(dateRange)
    
    header.innerHTML = `
      <div class="timeline-group-label w-48 font-semibold text-gray-700">
        ${this.groupByValue.charAt(0).toUpperCase() + this.groupByValue.slice(1)}
      </div>
      <div class="timeline-dates flex-1 flex">
        ${dateLabels.map(date => `
          <div class="timeline-date flex-1 text-center text-sm font-medium text-gray-600 border-l border-gray-200">
            <div class="date-label">${date.label}</div>
            <div class="day-label text-xs text-gray-400">${date.day}</div>
          </div>
        `).join('')}
      </div>
    `
    
    return header
  }

  createTimelineContent(data) {
    const content = document.createElement('div')
    content.className = 'timeline-content'
    
    // Group events by the specified grouping
    const groupedEvents = this.groupEvents(data.events, this.groupByValue)
    
    Object.entries(groupedEvents).forEach(([groupKey, events]) => {
      const groupRow = this.createTimelineGroupRow(groupKey, events, data.dateRange)
      content.appendChild(groupRow)
    })
    
    return content
  }

  createTimelineGroupRow(groupKey, events, dateRange) {
    const row = document.createElement('div')
    row.className = 'timeline-row flex items-stretch border-b border-gray-100 hover:bg-gray-50'
    
    // Group label
    const label = document.createElement('div')
    label.className = 'timeline-group-label w-48 p-4 flex items-center'
    label.innerHTML = `
      <div class="flex items-center">
        <div class="platform-icon mr-2">${this.getGroupIcon(groupKey, this.groupByValue)}</div>
        <div>
          <div class="font-medium text-gray-900">${this.formatGroupLabel(groupKey)}</div>
          <div class="text-sm text-gray-500">${events.length} scheduled</div>
        </div>
      </div>
    `
    
    // Timeline slots
    const slots = document.createElement('div')
    slots.className = 'timeline-slots flex-1 flex relative'
    slots.style.minHeight = '80px'
    
    // Create date slots
    const dateLabels = this.generateDateLabels(dateRange)
    dateLabels.forEach((date, index) => {
      const slot = document.createElement('div')
      slot.className = 'timeline-slot flex-1 border-l border-gray-200 p-2 relative'
      slot.dataset.date = date.date
      slot.dataset.group = groupKey
      
      // Add events for this date and group
      const dayEvents = events.filter(event => {
        const eventDate = new Date(event.scheduled_at).toISOString().split('T')[0]
        return eventDate === date.date
      })
      
      dayEvents.forEach(event => {
        const eventElement = this.createTimelineEvent(event)
        slot.appendChild(eventElement)
      })
      
      // Make slot droppable
      this.makeSlotDroppable(slot)
      
      slots.appendChild(slot)
    })
    
    row.appendChild(label)
    row.appendChild(slots)
    
    return row
  }

  createTimelineEvent(event) {
    const eventEl = document.createElement('div')
    eventEl.className = `timeline-event mb-1 p-2 rounded text-xs cursor-pointer ${this.getEventStatusClass(event.status)}`
    eventEl.draggable = true
    eventEl.dataset.eventId = event.id
    eventEl.dataset.platform = event.platform
    eventEl.dataset.status = event.status
    
    const time = new Date(event.scheduled_at).toLocaleTimeString([], { 
      hour: '2-digit', 
      minute: '2-digit' 
    })
    
    eventEl.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="truncate flex-1">
          <div class="font-medium">${this.truncateText(event.title || event.content_preview, 25)}</div>
          <div class="text-xs opacity-75">${time}</div>
        </div>
        <div class="ml-1 flex items-center">
          ${this.getPriorityIndicator(event.priority)}
          ${this.getStatusIcon(event.status)}
        </div>
      </div>
    `
    
    // Add event listeners
    eventEl.addEventListener('click', () => this.showEventDetails(event))
    eventEl.addEventListener('dragstart', (e) => this.handleDragStart(e, event))
    
    return eventEl
  }

  generateDateLabels(dateRange) {
    const labels = []
    const start = new Date(dateRange.start)
    const end = new Date(dateRange.end)
    const current = new Date(start)
    
    while (current <= end) {
      labels.push({
        date: current.toISOString().split('T')[0],
        label: current.toLocaleDateString([], { month: 'short', day: 'numeric' }),
        day: current.toLocaleDateString([], { weekday: 'short' })
      })
      current.setDate(current.getDate() + 1)
    }
    
    return labels
  }

  groupEvents(events, groupBy) {
    const grouped = {}
    
    events.forEach(event => {
      let groupKey
      
      switch (groupBy) {
        case 'platform':
          groupKey = event.platform || 'Unknown'
          break
        case 'channel':
          groupKey = event.channel || 'Unknown'
          break
        case 'campaign':
          groupKey = event.campaign_name || 'No Campaign'
          break
        case 'status':
          groupKey = event.status || 'Unknown'
          break
        default:
          groupKey = 'All'
      }
      
      if (!grouped[groupKey]) {
        grouped[groupKey] = []
      }
      grouped[groupKey].push(event)
    })
    
    return grouped
  }

  // Drag and Drop functionality
  makeSlotDroppable(slot) {
    slot.addEventListener('dragover', (e) => {
      e.preventDefault()
      slot.classList.add('drag-over')
    })
    
    slot.addEventListener('dragleave', () => {
      slot.classList.remove('drag-over')
    })
    
    slot.addEventListener('drop', (e) => {
      e.preventDefault()
      slot.classList.remove('drag-over')
      this.handleDrop(e, slot)
    })
  }

  handleDragStart(e, event) {
    e.dataTransfer.setData('text/plain', JSON.stringify({
      eventId: event.id,
      originalDate: event.scheduled_at,
      platform: event.platform
    }))
    
    e.target.classList.add('dragging')
  }

  async handleDrop(e, slot) {
    try {
      const dragData = JSON.parse(e.dataTransfer.getData('text/plain'))
      const newDate = slot.dataset.date
      const newGroup = slot.dataset.group
      
      // Calculate new datetime (preserve time, change date)
      const originalDateTime = new Date(dragData.originalDate)
      const newDateTime = new Date(newDate)
      newDateTime.setHours(originalDateTime.getHours())
      newDateTime.setMinutes(originalDateTime.getMinutes())
      
      // Update event
      await this.updateEventSchedule(dragData.eventId, {
        scheduled_at: newDateTime.toISOString(),
        platform: newGroup
      })
      
      // Refresh timeline
      this.loadTimelineData()
      
      this.showNotification('Event moved successfully', 'success')
    } catch (error) {
      console.error('Error moving event:', error)
      this.showNotification('Error moving event', 'error')
    }
    
    // Clean up drag state
    document.querySelectorAll('.dragging').forEach(el => {
      el.classList.remove('dragging')
    })
  }

  // Filtering and view management
  changeTimeRange(range) {
    this.timeRangeValue = range
    this.loadTimelineData()
  }

  changeGroupBy(groupBy) {
    this.groupByValue = groupBy
    this.loadTimelineData()
  }

  filterByStatus(status) {
    const events = this.timelineTarget.querySelectorAll('.timeline-event')
    events.forEach(event => {
      if (!status || event.dataset.status === status) {
        event.style.display = 'block'
      } else {
        event.style.display = 'none'
      }
    })
  }

  filterByPlatform(platform) {
    const rows = this.timelineTarget.querySelectorAll('.timeline-row')
    rows.forEach(row => {
      const groupLabel = row.querySelector('.timeline-group-label')
      const shouldShow = !platform || groupLabel.textContent.toLowerCase().includes(platform.toLowerCase())
      row.style.display = shouldShow ? 'flex' : 'none'
    })
  }

  // Event details and actions
  showEventDetails(event) {
    // Create or show modal with event details
    const modal = this.createEventModal(event)
    document.body.appendChild(modal)
  }

  createEventModal(event) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'
    modal.innerHTML = `
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-semibold">Content Schedule Details</h3>
          <button class="close-modal text-gray-400 hover:text-gray-600">×</button>
        </div>
        
        <div class="space-y-3">
          <div>
            <label class="block text-sm font-medium text-gray-700">Title</label>
            <div class="mt-1 text-sm text-gray-900">${event.title || 'Untitled'}</div>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Platform</label>
            <div class="mt-1 text-sm text-gray-900">${event.platform}</div>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Scheduled Time</label>
            <div class="mt-1 text-sm text-gray-900">${new Date(event.scheduled_at).toLocaleString()}</div>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Status</label>
            <div class="mt-1">
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${this.getEventStatusClass(event.status)}">
                ${event.status}
              </span>
            </div>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">Priority</label>
            <div class="mt-1 text-sm text-gray-900">${event.priority}/5</div>
          </div>
          
          ${event.content_preview ? `
            <div>
              <label class="block text-sm font-medium text-gray-700">Content Preview</label>
              <div class="mt-1 text-sm text-gray-900">${event.content_preview}</div>
            </div>
          ` : ''}
        </div>
        
        <div class="mt-6 flex justify-end space-x-3">
          <button class="close-modal px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200">
            Close
          </button>
          <button class="edit-event px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700" data-event-id="${event.id}">
            Edit
          </button>
        </div>
      </div>
    `
    
    // Add event listeners
    modal.addEventListener('click', (e) => {
      if (e.target === modal || e.target.classList.contains('close-modal')) {
        modal.remove()
      }
      if (e.target.classList.contains('edit-event')) {
        this.editEvent(event.id)
        modal.remove()
      }
    })
    
    return modal
  }

  // Utility methods
  getGroupIcon(groupKey, groupBy) {
    switch (groupBy) {
      case 'platform':
        return this.getPlatformIcon(groupKey)
      case 'channel':
        return this.getChannelIcon(groupKey)
      case 'status':
        return this.getStatusIcon(groupKey)
      default:
        return '📅'
    }
  }

  getPlatformIcon(platform) {
    const icons = {
      'twitter': '🐦',
      'instagram': '📷',
      'linkedin': '💼',
      'facebook': '👥',
      'youtube': '📹',
      'tiktok': '🎵'
    }
    return icons[platform?.toLowerCase()] || '📝'
  }

  getChannelIcon(channel) {
    const icons = {
      'social_media': '📱',
      'email': '📧',
      'web': '🌐',
      'ads': '📢'
    }
    return icons[channel?.toLowerCase()] || '📢'
  }

  getStatusIcon(status) {
    const icons = {
      'draft': '📝',
      'scheduled': '⏰',
      'published': '✅',
      'failed': '❌',
      'cancelled': '🚫',
      'paused': '⏸️'
    }
    return icons[status] || '❓'
  }

  getEventStatusClass(status) {
    const classes = {
      'draft': 'bg-gray-100 text-gray-800 border-gray-200',
      'scheduled': 'bg-blue-100 text-blue-800 border-blue-200',
      'published': 'bg-green-100 text-green-800 border-green-200',
      'failed': 'bg-red-100 text-red-800 border-red-200',
      'cancelled': 'bg-gray-100 text-gray-600 border-gray-200',
      'paused': 'bg-yellow-100 text-yellow-800 border-yellow-200'
    }
    return classes[status] || 'bg-gray-100 text-gray-800 border-gray-200'
  }

  getPriorityIndicator(priority) {
    if (priority >= 4) {
      return '<span class="w-2 h-2 bg-red-500 rounded-full" title="High Priority"></span>'
    } else if (priority === 3) {
      return '<span class="w-2 h-2 bg-yellow-500 rounded-full" title="Medium Priority"></span>'
    } else {
      return '<span class="w-2 h-2 bg-green-500 rounded-full" title="Low Priority"></span>'
    }
  }

  formatGroupLabel(groupKey) {
    return groupKey.charAt(0).toUpperCase() + groupKey.slice(1).replace(/_/g, ' ')
  }

  truncateText(text, maxLength) {
    if (!text || text.length <= maxLength) return text
    return text.substring(0, maxLength) + '...'
  }

  // API calls
  async updateEventSchedule(eventId, updates) {
    const formData = new FormData()
    Object.entries(updates).forEach(([key, value]) => {
      formData.append(key, value)
    })
    formData.append('_method', 'PATCH')
    
    const response = await fetch(`/content_schedules/${eventId}`, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
    
    if (!response.ok) {
      throw new Error('Failed to update event')
    }
    
    return response.json()
  }

  editEvent(eventId) {
    // Redirect to edit page or open edit modal
    window.location.href = `/content_schedules/${eventId}/edit`
  }

  // Auto-refresh functionality
  setupAutoRefresh() {
    if (this.autoRefreshValue) {
      this.refreshTimer = setInterval(() => {
        this.loadTimelineData()
      }, this.refreshIntervalValue)
    }
  }

  clearAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  // UI state management
  showLoading() {
    if (this.hasTimelineTarget) {
      this.timelineTarget.innerHTML = `
        <div class="flex items-center justify-center p-8">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <span class="ml-2 text-gray-600">Loading timeline...</span>
        </div>
      `
    }
  }

  hideLoading() {
    // Loading is hidden when content is rendered
  }

  showError(message) {
    if (this.hasTimelineTarget) {
      this.timelineTarget.innerHTML = `
        <div class="flex items-center justify-center p-8 text-red-600">
          <span>❌ ${message}</span>
        </div>
      `
    }
  }

  updateSidebar(statistics) {
    if (!this.hasSidebarTarget) return
    
    this.sidebarTarget.innerHTML = `
      <div class="space-y-4">
        <div class="bg-white p-4 rounded-lg shadow">
          <h3 class="font-semibold text-gray-900 mb-3">Statistics</h3>
          <div class="space-y-2">
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Total Scheduled:</span>
              <span class="font-medium">${statistics.total || 0}</span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Published:</span>
              <span class="font-medium text-green-600">${statistics.published || 0}</span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Pending:</span>
              <span class="font-medium text-blue-600">${statistics.scheduled || 0}</span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Failed:</span>
              <span class="font-medium text-red-600">${statistics.failed || 0}</span>
            </div>
          </div>
        </div>
        
        <div class="bg-white p-4 rounded-lg shadow">
          <h3 class="font-semibold text-gray-900 mb-3">Distribution</h3>
          <div class="space-y-2">
            ${Object.entries(statistics.by_platform || {}).map(([platform, count]) => `
              <div class="flex justify-between text-sm">
                <span class="text-gray-600">${this.formatGroupLabel(platform)}:</span>
                <span class="font-medium">${count}</span>
              </div>
            `).join('')}
          </div>
        </div>
      </div>
    `
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `notification notification-${type} fixed top-4 right-4 px-4 py-2 rounded shadow-lg z-50`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 5000)
  }

  setupFilters() {
    // Setup any filter UI if filters target exists
    if (this.hasFiltersTarget) {
      // Add event listeners for filter controls
    }
  }

  bindEventHandlers() {
    // Bind any additional event handlers
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        // Close any open modals
        document.querySelectorAll('.fixed.inset-0').forEach(modal => modal.remove())
      }
    })
  }
}