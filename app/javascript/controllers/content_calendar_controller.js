import { Controller } from "@hotwired/stimulus"
import { Calendar } from "@fullcalendar/core"
import dayGridPlugin from "@fullcalendar/daygrid"
import timeGridPlugin from "@fullcalendar/timegrid"
import interactionPlugin from "@fullcalendar/interaction"

export default class extends Controller {
  static targets = ["calendar", "sidebar", "modal", "form"]
  static values = { 
    eventsUrl: String,
    createUrl: String,
    updateUrl: String,
    deleteUrl: String,
    currentView: { type: String, default: "dayGridMonth" },
    editable: { type: Boolean, default: true },
    timezone: { type: String, default: "UTC" }
  }

  connect() {
    this.initializeCalendar()
    this.loadEvents()
    this.bindEventHandlers()
  }

  disconnect() {
    if (this.calendar) {
      this.calendar.destroy()
    }
  }

  initializeCalendar() {
    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [dayGridPlugin, timeGridPlugin, interactionPlugin],
      initialView: this.currentViewValue,
      timeZone: this.timezoneValue,
      editable: this.editableValue,
      selectable: true,
      selectMirror: true,
      dayMaxEvents: true,
      weekends: true,
      headerToolbar: {
        left: 'prev,next today',
        center: 'title',
        right: 'dayGridMonth,timeGridWeek,timeGridDay'
      },
      height: 'auto',
      
      // Event handlers
      select: this.handleDateSelect.bind(this),
      eventClick: this.handleEventClick.bind(this),
      eventDrop: this.handleEventDrop.bind(this),
      eventResize: this.handleEventResize.bind(this),
      datesSet: this.handleDatesSet.bind(this),
      
      // Event rendering
      eventDidMount: this.handleEventDidMount.bind(this),
      eventContent: this.handleEventContent.bind(this),
      
      // Business hours (optional)
      businessHours: {
        daysOfWeek: [1, 2, 3, 4, 5], // Monday - Friday
        startTime: '09:00',
        endTime: '18:00'
      }
    })

    this.calendar.render()
  }

  loadEvents() {
    if (this.eventsUrlValue) {
      fetch(this.eventsUrlValue)
        .then(response => response.json())
        .then(events => {
          this.calendar.removeAllEvents()
          this.calendar.addEventSource(events)
        })
        .catch(error => {
          console.error('Error loading events:', error)
          this.showNotification('Error loading calendar events', 'error')
        })
    }
  }

  // Event handlers
  handleDateSelect(selectInfo) {
    if (this.editableValue) {
      this.openCreateModal(selectInfo.start, selectInfo.end)
    }
    this.calendar.unselect()
  }

  handleEventClick(clickInfo) {
    this.openEventModal(clickInfo.event)
  }

  handleEventDrop(dropInfo) {
    if (!this.editableValue) {
      dropInfo.revert()
      return
    }

    const event = dropInfo.event
    this.updateEventDateTime(event.id, event.start, event.end)
      .then(() => {
        this.showNotification('Event moved successfully', 'success')
        this.updateEventDisplay(event)
      })
      .catch(error => {
        console.error('Error moving event:', error)
        dropInfo.revert()
        this.showNotification('Error moving event', 'error')
      })
  }

  handleEventResize(resizeInfo) {
    if (!this.editableValue) {
      resizeInfo.revert()
      return
    }

    const event = resizeInfo.event
    this.updateEventDateTime(event.id, event.start, event.end)
      .then(() => {
        this.showNotification('Event resized successfully', 'success')
        this.updateEventDisplay(event)
      })
      .catch(error => {
        console.error('Error resizing event:', error)
        resizeInfo.revert()
        this.showNotification('Error resizing event', 'error')
      })
  }

  handleDatesSet(dateInfo) {
    // Update current view when user navigates
    this.currentViewValue = dateInfo.view.type
    
    // Optionally load events for the new date range
    this.loadEventsForDateRange(dateInfo.start, dateInfo.end)
  }

  handleEventDidMount(info) {
    // Customize event appearance based on status
    const event = info.event
    const element = info.el
    
    // Add platform-specific styling
    if (event.extendedProps.platform) {
      element.classList.add(`platform-${event.extendedProps.platform.toLowerCase()}`)
    }
    
    // Add status-specific styling
    if (event.extendedProps.status) {
      element.classList.add(`status-${event.extendedProps.status}`)
    }
    
    // Add priority indicator
    if (event.extendedProps.priority >= 4) {
      element.classList.add('high-priority')
    }
    
    // Add tooltip
    this.addTooltip(element, event)
  }

  handleEventContent(arg) {
    // Custom event content rendering
    const event = arg.event
    const platform = event.extendedProps.platform
    const status = event.extendedProps.status
    
    const platformIcon = this.getPlatformIcon(platform)
    const statusIcon = this.getStatusIcon(status)
    
    return {
      html: `
        <div class="fc-event-content-wrapper">
          <div class="fc-event-title-container">
            ${platformIcon}
            <span class="fc-event-title">${event.title}</span>
            ${statusIcon}
          </div>
          <div class="fc-event-time">${this.formatEventTime(event)}</div>
        </div>
      `
    }
  }

  // Modal management
  openCreateModal(startDate, endDate = null) {
    if (this.hasModalTarget) {
      this.populateCreateForm(startDate, endDate)
      this.showModal()
    }
  }

  openEventModal(event) {
    if (this.hasModalTarget) {
      this.populateEditForm(event)
      this.showModal()
    }
  }

  showModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
      this.modalTarget.classList.add('flex')
    }
  }

  hideModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
      this.modalTarget.classList.remove('flex')
      this.clearForm()
    }
  }

  // Form management
  populateCreateForm(startDate, endDate) {
    if (this.hasFormTarget) {
      const form = this.formTarget
      
      // Set date/time fields
      form.querySelector('[name="scheduled_at"]').value = this.formatDateTimeLocal(startDate)
      if (endDate) {
        form.querySelector('[name="end_time"]').value = this.formatDateTimeLocal(endDate)
      }
      
      // Set form action for creation
      form.action = this.createUrlValue
      form.querySelector('[name="_method"]')?.remove()
    }
  }

  populateEditForm(event) {
    if (this.hasFormTarget) {
      const form = this.formTarget
      const props = event.extendedProps
      
      // Populate form fields
      form.querySelector('[name="title"]').value = event.title || ''
      form.querySelector('[name="scheduled_at"]').value = this.formatDateTimeLocal(event.start)
      form.querySelector('[name="platform"]').value = props.platform || ''
      form.querySelector('[name="channel"]').value = props.channel || ''
      form.querySelector('[name="priority"]').value = props.priority || 3
      form.querySelector('[name="auto_publish"]').checked = props.autoPublish || false
      
      // Set form action for update
      form.action = this.updateUrlValue.replace(':id', event.id)
      
      // Add method override for PATCH
      let methodInput = form.querySelector('[name="_method"]')
      if (!methodInput) {
        methodInput = document.createElement('input')
        methodInput.type = 'hidden'
        methodInput.name = '_method'
        form.appendChild(methodInput)
      }
      methodInput.value = 'PATCH'
    }
  }

  clearForm() {
    if (this.hasFormTarget) {
      this.formTarget.reset()
      this.formTarget.querySelector('[name="_method"]')?.remove()
    }
  }

  // CRUD operations
  async createEvent(formData) {
    try {
      const response = await fetch(this.createUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const event = await response.json()
        this.calendar.addEvent(event)
        this.hideModal()
        this.showNotification('Event created successfully', 'success')
      } else {
        throw new Error('Failed to create event')
      }
    } catch (error) {
      console.error('Error creating event:', error)
      this.showNotification('Error creating event', 'error')
    }
  }

  async updateEventDateTime(eventId, startDate, endDate) {
    const formData = new FormData()
    formData.append('scheduled_at', startDate.toISOString())
    if (endDate) {
      formData.append('end_time', endDate.toISOString())
    }
    formData.append('_method', 'PATCH')
    
    const response = await fetch(this.updateUrlValue.replace(':id', eventId), {
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

  async deleteEvent(eventId) {
    try {
      const response = await fetch(this.deleteUrlValue.replace(':id', eventId), {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const event = this.calendar.getEventById(eventId)
        if (event) {
          event.remove()
        }
        this.hideModal()
        this.showNotification('Event deleted successfully', 'success')
      } else {
        throw new Error('Failed to delete event')
      }
    } catch (error) {
      console.error('Error deleting event:', error)
      this.showNotification('Error deleting event', 'error')
    }
  }

  // View management
  changeView(viewName) {
    this.calendar.changeView(viewName)
    this.currentViewValue = viewName
  }

  goToDate(date) {
    this.calendar.gotoDate(date)
  }

  today() {
    this.calendar.today()
  }

  prev() {
    this.calendar.prev()
  }

  next() {
    this.calendar.next()
  }

  // Filtering and search
  filterByPlatform(platform) {
    this.calendar.getEvents().forEach(event => {
      const shouldShow = !platform || event.extendedProps.platform === platform
      event.setProp('display', shouldShow ? 'auto' : 'none')
    })
  }

  filterByStatus(status) {
    this.calendar.getEvents().forEach(event => {
      const shouldShow = !status || event.extendedProps.status === status
      event.setProp('display', shouldShow ? 'auto' : 'none')
    })
  }

  searchEvents(query) {
    if (!query) {
      this.calendar.getEvents().forEach(event => {
        event.setProp('display', 'auto')
      })
      return
    }
    
    const lowercaseQuery = query.toLowerCase()
    this.calendar.getEvents().forEach(event => {
      const title = event.title.toLowerCase()
      const content = event.extendedProps.content?.toLowerCase() || ''
      const shouldShow = title.includes(lowercaseQuery) || content.includes(lowercaseQuery)
      event.setProp('display', shouldShow ? 'auto' : 'none')
    })
  }

  // Utility methods
  formatDateTimeLocal(date) {
    const d = new Date(date)
    const offset = d.getTimezoneOffset() * 60000
    const localDate = new Date(d.getTime() - offset)
    return localDate.toISOString().slice(0, 16)
  }

  formatEventTime(event) {
    const start = event.start
    if (!start) return ''
    
    return start.toLocaleTimeString([], { 
      hour: '2-digit', 
      minute: '2-digit' 
    })
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

  getStatusIcon(status) {
    const icons = {
      'draft': '📝',
      'scheduled': '⏰',
      'published': '✅',
      'failed': '❌',
      'cancelled': '🚫',
      'paused': '⏸️'
    }
    return icons[status] || ''
  }

  addTooltip(element, event) {
    const tooltip = document.createElement('div')
    tooltip.className = 'calendar-tooltip hidden'
    tooltip.innerHTML = `
      <div class="font-semibold">${event.title}</div>
      <div class="text-sm">Platform: ${event.extendedProps.platform}</div>
      <div class="text-sm">Status: ${event.extendedProps.status}</div>
      <div class="text-sm">Priority: ${event.extendedProps.priority}/5</div>
      ${event.extendedProps.content ? `<div class="text-xs mt-1">${event.extendedProps.content.substring(0, 100)}...</div>` : ''}
    `
    
    element.addEventListener('mouseenter', () => {
      document.body.appendChild(tooltip)
      tooltip.classList.remove('hidden')
    })
    
    element.addEventListener('mouseleave', () => {
      tooltip.remove()
    })
    
    element.addEventListener('mousemove', (e) => {
      tooltip.style.left = e.pageX + 10 + 'px'
      tooltip.style.top = e.pageY + 10 + 'px'
    })
  }

  updateEventDisplay(event) {
    // Refresh event rendering to show updated information
    event.setProp('display', 'auto')
  }

  loadEventsForDateRange(start, end) {
    if (this.eventsUrlValue) {
      const params = new URLSearchParams({
        start: start.toISOString(),
        end: end.toISOString()
      })
      
      fetch(`${this.eventsUrlValue}?${params}`)
        .then(response => response.json())
        .then(events => {
          // Only replace events in the visible range
          this.calendar.getEvents().forEach(event => {
            if (event.start >= start && event.start <= end) {
              event.remove()
            }
          })
          
          events.forEach(eventData => {
            this.calendar.addEvent(eventData)
          })
        })
        .catch(error => {
          console.error('Error loading events for date range:', error)
        })
    }
  }

  showNotification(message, type = 'info') {
    // Simple notification system - could be enhanced with a proper notification library
    const notification = document.createElement('div')
    notification.className = `notification notification-${type} fixed top-4 right-4 px-4 py-2 rounded shadow-lg z-50`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 5000)
  }

  bindEventHandlers() {
    // Bind any additional event handlers for buttons, filters, etc.
    document.addEventListener('click', (e) => {
      if (e.target.matches('[data-action*="content-calendar#"]')) {
        // Handle button clicks that target this controller
        const action = e.target.dataset.action
        if (action.includes('hideModal')) {
          this.hideModal()
        }
      }
    })
    
    // Handle form submissions
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', (e) => {
        e.preventDefault()
        const formData = new FormData(this.formTarget)
        
        if (this.formTarget.action.includes(this.createUrlValue)) {
          this.createEvent(formData)
        } else {
          // Handle update via form submission
        }
      })
    }
  }

  // Conflict detection
  checkForConflicts(newEvent) {
    const conflicts = []
    const newStart = new Date(newEvent.start)
    const newEnd = new Date(newEvent.end || newStart)
    const platform = newEvent.platform
    
    this.calendar.getEvents().forEach(event => {
      if (event.id === newEvent.id) return // Skip self
      if (event.extendedProps.platform !== platform) return // Different platform
      
      const eventStart = new Date(event.start)
      const eventEnd = new Date(event.end || eventStart)
      
      // Check for time overlap
      if (newStart < eventEnd && newEnd > eventStart) {
        conflicts.push(event)
      }
    })
    
    return conflicts
  }

  highlightConflicts(conflicts) {
    conflicts.forEach(event => {
      const element = event.el
      if (element) {
        element.classList.add('conflict-highlight')
      }
    })
  }

  clearConflictHighlights() {
    this.calendar.getEvents().forEach(event => {
      const element = event.el
      if (element) {
        element.classList.remove('conflict-highlight')
      }
    })
  }
}