import { Controller } from "@hotwired/stimulus"

// Dashboard controller for managing widget layouts, drag-and-drop, and customization
export default class extends Controller {
  static targets = ["grid", "widget"]
  static values = { 
    layout: String,
    autoSave: { type: Boolean, default: true },
    refreshInterval: { type: Number, default: 60000 }
  }

  connect() {
    console.log("Dashboard controller connected")
    this.initializeLayout()
    this.setupAutoRefresh()
    this.initializeDragAndDrop()
    this.loadUserPreferences()
  }

  disconnect() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
    this.cleanupDragAndDrop()
  }

  // Layout Management
  initializeLayout() {
    this.applyLayout(this.layoutValue || 'default')
  }

  toggleLayout() {
    const currentLayout = this.layoutValue
    const layouts = ['default', 'compact', 'spacious']
    const currentIndex = layouts.indexOf(currentLayout)
    const nextLayout = layouts[(currentIndex + 1) % layouts.length]
    
    this.layoutValue = nextLayout
    this.applyLayout(nextLayout)
    
    if (this.autoSaveValue) {
      this.saveUserPreferences()
    }
  }

  applyLayout(layout) {
    const grid = this.gridTarget
    
    // Remove existing layout classes
    grid.classList.remove('layout-default', 'layout-compact', 'layout-spacious')
    
    // Apply new layout
    switch (layout) {
      case 'compact':
        grid.classList.add('layout-compact')
        this.adjustWidgetSizes('compact')
        break
      case 'spacious':
        grid.classList.add('layout-spacious')
        this.adjustWidgetSizes('spacious')
        break
      default:
        grid.classList.add('layout-default')
        this.adjustWidgetSizes('default')
    }
    
    this.dispatch('layoutChanged', { detail: { layout } })
  }

  adjustWidgetSizes(layout) {
    this.widgetTargets.forEach(widget => {
      const widgetType = widget.dataset.widgetType
      
      // Adjust widget spans based on layout and type
      switch (layout) {
        case 'compact':
          this.applyCompactLayout(widget, widgetType)
          break
        case 'spacious':
          this.applySpaciousLayout(widget, widgetType)
          break
        default:
          this.applyDefaultLayout(widget, widgetType)
      }
    })
  }

  applyCompactLayout(widget, type) {
    widget.classList.remove('col-span-2', 'col-span-3', 'col-span-4')
    if (['campaign-overview', 'performance-metrics'].includes(type)) {
      widget.classList.add('col-span-2')
    }
  }

  applySpaciousLayout(widget, type) {
    switch (type) {
      case 'campaign-overview':
        widget.classList.add('col-span-3')
        break
      case 'performance-metrics':
      case 'recent-activity':
        widget.classList.add('col-span-2')
        break
    }
  }

  applyDefaultLayout(widget, type) {
    // Reset to default spans
    widget.classList.remove('col-span-2', 'col-span-3', 'col-span-4')
    
    switch (type) {
      case 'campaign-overview':
        widget.classList.add('col-span-3')
        break
      case 'performance-metrics':
      case 'recent-activity':
      case 'task-progress':
        widget.classList.add('col-span-2')
        break
    }
  }

  // Drag and Drop Functionality
  initializeDragAndDrop() {
    if (!this.gridTarget) {return}

    this.widgetTargets.forEach(widget => {
      widget.draggable = true
      widget.addEventListener('dragstart', this.handleDragStart.bind(this))
      widget.addEventListener('dragend', this.handleDragEnd.bind(this))
    })

    this.gridTarget.addEventListener('dragover', this.handleDragOver.bind(this))
    this.gridTarget.addEventListener('drop', this.handleDrop.bind(this))
  }

  cleanupDragAndDrop() {
    this.widgetTargets.forEach(widget => {
      widget.removeEventListener('dragstart', this.handleDragStart.bind(this))
      widget.removeEventListener('dragend', this.handleDragEnd.bind(this))
    })

    if (this.gridTarget) {
      this.gridTarget.removeEventListener('dragover', this.handleDragOver.bind(this))
      this.gridTarget.removeEventListener('drop', this.handleDrop.bind(this))
    }
  }

  handleDragStart(event) {
    this.draggedWidget = event.target.closest('[data-widget-type]')
    this.draggedWidget.classList.add('dragging')
    
    // Store initial position for potential revert
    this.originalPosition = Array.from(this.gridTarget.children).indexOf(this.draggedWidget)
    
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', this.draggedWidget.outerHTML)
  }

  handleDragEnd(event) {
    if (this.draggedWidget) {
      this.draggedWidget.classList.remove('dragging')
      this.draggedWidget = null
    }
    
    // Remove drag-over classes from all widgets
    this.widgetTargets.forEach(widget => {
      widget.classList.remove('drag-over')
    })
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    
    const afterElement = this.getDragAfterElement(event.clientY)
    const dragOverWidget = event.target.closest('[data-widget-type]')
    
    if (dragOverWidget && dragOverWidget !== this.draggedWidget) {
      dragOverWidget.classList.add('drag-over')
    }
  }

  handleDrop(event) {
    event.preventDefault()
    
    const dropTarget = event.target.closest('[data-widget-type]')
    
    if (dropTarget && this.draggedWidget && dropTarget !== this.draggedWidget) {
      // Determine drop position
      const rect = dropTarget.getBoundingClientRect()
      const midY = rect.top + rect.height / 2
      
      if (event.clientY < midY) {
        // Insert before
        this.gridTarget.insertBefore(this.draggedWidget, dropTarget)
      } else {
        // Insert after
        this.gridTarget.insertBefore(this.draggedWidget, dropTarget.nextSibling)
      }
      
      if (this.autoSaveValue) {
        this.saveWidgetOrder()
      }
      
      this.dispatch('widgetMoved', { 
        detail: { 
          widget: this.draggedWidget.dataset.widgetType,
          newPosition: Array.from(this.gridTarget.children).indexOf(this.draggedWidget)
        } 
      })
    }
    
    // Clean up drag-over classes
    this.widgetTargets.forEach(widget => {
      widget.classList.remove('drag-over')
    })
  }

  getDragAfterElement(y) {
    const draggableElements = [...this.widgetTargets.filter(widget => 
      !widget.classList.contains('dragging')
    )]
    
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      
      if (offset < 0 && offset > closest.offset) {
        return { offset, element: child }
      } else {
        return closest
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element
  }

  // Data Management
  refreshData() {
    this.dispatch('refreshRequested')
    
    // Add visual feedback
    this.element.classList.add('refreshing')
    
    // Refresh all widgets
    this.widgetTargets.forEach(widget => {
      const widgetController = this.application.getControllerForElementAndIdentifier(widget, 'widget')
      if (widgetController && widgetController.refresh) {
        widgetController.refresh()
      }
    })
    
    // Remove visual feedback after delay
    setTimeout(() => {
      this.element.classList.remove('refreshing')
    }, 1000)
  }

  setupAutoRefresh() {
    if (this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refreshData()
      }, this.refreshIntervalValue)
    }
  }

  // User Preferences
  loadUserPreferences() {
    try {
      const preferences = localStorage.getItem('dashboard-preferences')
      if (preferences) {
        const parsed = JSON.parse(preferences)
        
        if (parsed.layout) {
          this.layoutValue = parsed.layout
          this.applyLayout(parsed.layout)
        }
        
        if (parsed.widgetOrder) {
          this.applyWidgetOrder(parsed.widgetOrder)
        }
        
        if (parsed.collapsedWidgets) {
          this.applyCollapsedStates(parsed.collapsedWidgets)
        }
      }
    } catch (error) {
      console.warn('Failed to load dashboard preferences:', error)
    }
  }

  saveUserPreferences() {
    try {
      const preferences = {
        layout: this.layoutValue,
        widgetOrder: this.getWidgetOrder(),
        collapsedWidgets: this.getCollapsedWidgets(),
        timestamp: Date.now()
      }
      
      localStorage.setItem('dashboard-preferences', JSON.stringify(preferences))
      this.dispatch('preferencesSaved', { detail: preferences })
    } catch (error) {
      console.warn('Failed to save dashboard preferences:', error)
    }
  }

  saveWidgetOrder() {
    const preferences = this.getCurrentPreferences()
    preferences.widgetOrder = this.getWidgetOrder()
    localStorage.setItem('dashboard-preferences', JSON.stringify(preferences))
  }

  getCurrentPreferences() {
    try {
      const stored = localStorage.getItem('dashboard-preferences')
      return stored ? JSON.parse(stored) : {}
    } catch {
      return {}
    }
  }

  getWidgetOrder() {
    return this.widgetTargets.map(widget => widget.dataset.widgetType)
  }

  applyWidgetOrder(order) {
    const widgets = new Map()
    this.widgetTargets.forEach(widget => {
      widgets.set(widget.dataset.widgetType, widget)
    })
    
    order.forEach(type => {
      const widget = widgets.get(type)
      if (widget) {
        this.gridTarget.appendChild(widget)
      }
    })
  }

  getCollapsedWidgets() {
    return this.widgetTargets
      .filter(widget => widget.classList.contains('collapsed'))
      .map(widget => widget.dataset.widgetType)
  }

  applyCollapsedStates(collapsedWidgets) {
    this.widgetTargets.forEach(widget => {
      if (collapsedWidgets.includes(widget.dataset.widgetType)) {
        const collapsibleController = this.application.getControllerForElementAndIdentifier(widget, 'collapsible')
        if (collapsibleController && collapsibleController.collapse) {
          collapsibleController.collapse()
        }
      }
    })
  }

  // Utility Actions
  exportData() {
    this.dispatch('exportRequested')
    
    // Collect data from all widgets
    const data = {
      timestamp: new Date().toISOString(),
      layout: this.layoutValue,
      widgets: this.widgetTargets.map(widget => ({
        type: widget.dataset.widgetType,
        data: this.extractWidgetData(widget)
      }))
    }
    
    // Create download
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `dashboard-export-${new Date().toISOString().split('T')[0]}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  extractWidgetData(widget) {
    // Extract displayable data from widget
    const data = {}
    
    // Get metrics
    const metrics = widget.querySelectorAll('[data-widget-target]')
    metrics.forEach(metric => {
      const target = metric.dataset.widgetTarget
      data[target] = metric.textContent.trim()
    })
    
    return data
  }

  toggleTheme() {
    document.documentElement.classList.toggle('dark')
    
    const isDark = document.documentElement.classList.contains('dark')
    localStorage.setItem('theme', isDark ? 'dark' : 'light')
    
    this.dispatch('themeChanged', { detail: { theme: isDark ? 'dark' : 'light' } })
  }

  showSettings() {
    this.dispatch('settingsRequested')
    // Implementation would show a settings modal
  }

  showHelp() {
    this.dispatch('helpRequested')
    // Implementation would show help/onboarding
  }
}