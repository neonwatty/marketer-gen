import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeline", "exportMenu"]
  static values = { planId: Number }

  connect() {
    console.log("Campaign dashboard controller connected")
    this.initializeDashboard()
  }

  initializeDashboard() {
    // Initialize any dashboard-specific functionality
    this.setupAutoSave()
    this.loadNotifications()
  }

  setupAutoSave() {
    // Auto-save functionality for form changes
    this.autoSaveInterval = setInterval(() => {
      this.autoSave()
    }, 30000) // Auto-save every 30 seconds
  }

  autoSave() {
    // Get form data and save draft
    const forms = this.element.querySelectorAll('form[data-auto-save]')
    forms.forEach(form => {
      if (this.hasFormChanged(form)) {
        this.saveDraft(form)
      }
    })
  }

  hasFormChanged(form) {
    // Check if form has been modified
    const inputs = form.querySelectorAll('input, textarea, select')
    return Array.from(inputs).some(input => input.dataset.originalValue !== input.value)
  }

  saveDraft(form) {
    const formData = new FormData(form)
    fetch(`/campaign_plans/${this.planIdValue}/auto_save`, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showAutoSaveNotification()
      }
    })
    .catch(error => console.error('Auto-save error:', error))
  }

  showAutoSaveNotification() {
    // Show subtle auto-save notification
    const notification = document.createElement('div')
    notification.className = 'fixed bottom-4 right-4 bg-green-100 border border-green-400 text-green-700 px-4 py-2 rounded shadow-lg z-50'
    notification.textContent = 'Draft saved automatically'
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }

  loadNotifications() {
    // Load recent notifications
    fetch(`/campaign_plans/${this.planIdValue}/notifications`)
      .then(response => response.json())
      .then(data => {
        this.updateNotificationCount(data.count)
        this.populateNotifications(data.notifications)
      })
      .catch(error => console.error('Error loading notifications:', error))
  }

  updateNotificationCount(count) {
    const badge = document.querySelector('[data-notification-count]')
    if (badge) {
      badge.textContent = count
      badge.style.display = count > 0 ? 'inline' : 'none'
    }
  }

  populateNotifications(notifications) {
    const container = document.querySelector('[data-notification-center-target="notifications"]')
    if (!container) {return}

    if (notifications.length === 0) {
      container.innerHTML = '<div class="text-sm text-gray-500 italic">No new notifications</div>'
      return
    }

    container.innerHTML = notifications.map(notification => `
      <div class="flex items-start gap-3 p-2 hover:bg-gray-50 rounded transition-colors">
        <div class="w-2 h-2 bg-blue-500 rounded-full mt-2 flex-shrink-0"></div>
        <div class="flex-1 min-w-0">
          <p class="text-sm text-gray-900 line-clamp-2">${notification.message}</p>
          <p class="text-xs text-gray-500 mt-1">${notification.time_ago}</p>
        </div>
      </div>
    `).join('')
  }

  toggleTimelineView() {
    // Toggle between different timeline visualization modes
    const container = this.timelineTarget
    const currentView = container.dataset.view || 'gantt'
    const newView = currentView === 'gantt' ? 'kanban' : 'gantt'
    
    container.dataset.view = newView
    this.switchTimelineView(newView)
  }

  switchTimelineView(view) {
    const container = this.timelineTarget
    
    if (view === 'kanban') {
      container.classList.add('kanban-view')
      container.classList.remove('gantt-view')
      this.renderKanbanView()
    } else {
      container.classList.add('gantt-view')
      container.classList.remove('kanban-view')
      this.renderGanttView()
    }
  }

  renderKanbanView() {
    // Transform timeline into kanban board
    const phases = this.timelineTarget.querySelectorAll('.timeline-phase')
    phases.forEach(phase => {
      phase.style.width = '300px'
      phase.style.display = 'inline-block'
      phase.style.verticalAlign = 'top'
      phase.style.marginRight = '16px'
    })
  }

  renderGanttView() {
    // Restore timeline to gantt chart
    const phases = this.timelineTarget.querySelectorAll('.timeline-phase')
    phases.forEach(phase => {
      phase.style.width = ''
      phase.style.display = ''
      phase.style.verticalAlign = ''
      phase.style.marginRight = ''
    })
  }

  saveTemplate() {
    // Save current plan as template
    const templateData = this.extractTemplateData()
    
    fetch(`/campaign_plans/${this.planIdValue}/save_as_template`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify(templateData)
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showSuccessMessage('Template saved successfully!')
      } else {
        this.showErrorMessage('Failed to save template')
      }
    })
    .catch(error => {
      console.error('Error saving template:', error)
      this.showErrorMessage('An error occurred while saving template')
    })
  }

  extractTemplateData() {
    // Extract plan data that can be used as template
    return {
      name: `${document.querySelector('h1').textContent} Template`,
      description: 'Template generated from campaign plan',
      industry_type: 'General',
      template_type: 'custom'
    }
  }

  showExportMenu() {
    // Show mobile export menu
    const menu = document.createElement('div')
    menu.className = 'fixed inset-x-0 bottom-0 bg-white border-t border-gray-200 p-4 z-50 lg:hidden'
    menu.innerHTML = `
      <div class="space-y-2">
        <a href="/campaign_plans/${this.planIdValue}/export?format=pdf" 
           class="flex items-center justify-center w-full px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
          Export as PDF
        </a>
        <a href="/campaign_plans/${this.planIdValue}/export?format=pptx" 
           class="flex items-center justify-center w-full px-4 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
          Export as PowerPoint
        </a>
        <button type="button" 
                class="flex items-center justify-center w-full px-4 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
                onclick="this.parentElement.parentElement.remove()">
          Cancel
        </button>
      </div>
    `
    
    document.body.appendChild(menu)
  }

  showSuccessMessage(message) {
    this.showMessage(message, 'success')
  }

  showErrorMessage(message) {
    this.showMessage(message, 'error')
  }

  showMessage(message, type) {
    const colors = {
      success: 'bg-green-100 border-green-400 text-green-700',
      error: 'bg-red-100 border-red-400 text-red-700',
      info: 'bg-blue-100 border-blue-400 text-blue-700'
    }
    
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 ${colors[type]} px-4 py-3 rounded border shadow-lg z-50`
    notification.textContent = message
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 5000)
  }

  disconnect() {
    // Clean up intervals and event listeners
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
  }
}