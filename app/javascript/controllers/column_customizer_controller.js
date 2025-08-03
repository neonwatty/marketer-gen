import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="column-customizer"  
export default class extends Controller {
  static targets = ["panel", "columnList"]

  connect() {
    console.log("Column customizer controller connected")
    this.defaultColumns = ['select', 'name', 'status', 'type', 'persona', 'created_at', 'performance', 'actions']
    this.requiredColumns = ['select', 'name', 'status', 'actions']
    this.loadColumnPreferences()
  }

  // Toggle the customization panel
  toggle(event) {
    event.preventDefault()
    
    if (this.hasPanelTarget) {
      const isHidden = this.panelTarget.classList.contains('hidden')
      
      if (isHidden) {
        this.panelTarget.classList.remove('hidden')
        // Add slide-down animation
        this.panelTarget.style.maxHeight = '0'
        this.panelTarget.style.overflow = 'hidden'
        this.panelTarget.style.transition = 'max-height 0.3s ease-out'
        
        // Trigger reflow
        this.panelTarget.offsetHeight
        
        this.panelTarget.style.maxHeight = '300px'
      } else {
        this.panelTarget.style.maxHeight = '0'
        setTimeout(() => {
          this.panelTarget.classList.add('hidden')
          this.panelTarget.style.maxHeight = ''
          this.panelTarget.style.overflow = ''
          this.panelTarget.style.transition = ''
        }, 300)
      }
    }
  }

  // Toggle column visibility
  toggleColumn(event) {
    const checkbox = event.target
    const columnName = checkbox.dataset.column
    const isVisible = checkbox.checked
    
    // Don't allow hiding required columns
    if (!isVisible && this.requiredColumns.includes(columnName)) {
      checkbox.checked = true
      this.showError(`${this.humanize(columnName)} column is required and cannot be hidden.`)
      return
    }
    
    // Update column visibility
    this.updateColumnVisibility(columnName, isVisible)
    
    // Save preferences
    this.saveColumnPreferences()
    
    // Show feedback
    this.showFeedback(`${this.humanize(columnName)} column ${isVisible ? 'shown' : 'hidden'}`)
  }

  // Update column visibility in the table
  updateColumnVisibility(columnName, isVisible) {
    const table = this.element.querySelector('table')
    if (!table) {return}
    
    // Update header
    const headerCell = table.querySelector(`th[data-column="${columnName}"]`)
    if (headerCell) {
      if (isVisible) {
        headerCell.classList.remove('hidden')
      } else {
        headerCell.classList.add('hidden')
      }
    }
    
    // Update all body cells in this column
    const bodyCells = table.querySelectorAll(`td[data-column="${columnName}"]`)
    bodyCells.forEach(cell => {
      if (isVisible) {
        cell.classList.remove('hidden')
      } else {
        cell.classList.add('hidden')
      }
    })
  }

  // Reset to default columns
  reset(event) {
    event.preventDefault()
    
    if (confirm('Reset to default column layout?')) {
      // Reset all checkboxes
      const checkboxes = this.columnListTarget.querySelectorAll('input[type="checkbox"]')
      checkboxes.forEach(checkbox => {
        const columnName = checkbox.dataset.column
        const shouldBeChecked = this.defaultColumns.includes(columnName)
        
        checkbox.checked = shouldBeChecked
        this.updateColumnVisibility(columnName, shouldBeChecked)
      })
      
      // Clear saved preferences
      localStorage.removeItem('campaignTableColumns')
      
      this.showFeedback('Column layout reset to default')
    }
  }

  // Save column preferences to localStorage
  saveColumnPreferences() {
    const preferences = {}
    
    const checkboxes = this.columnListTarget.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => {
      preferences[checkbox.dataset.column] = checkbox.checked
    })
    
    localStorage.setItem('campaignTableColumns', JSON.stringify(preferences))
  }

  // Load column preferences from localStorage
  loadColumnPreferences() {
    const saved = localStorage.getItem('campaignTableColumns')
    if (!saved) {return}
    
    try {
      const preferences = JSON.parse(saved)
      
      const checkboxes = this.columnListTarget.querySelectorAll('input[type="checkbox"]')
      checkboxes.forEach(checkbox => {
        const columnName = checkbox.dataset.column
        
        if (preferences.hasOwnProperty(columnName)) {
          const isVisible = preferences[columnName]
          checkbox.checked = isVisible
          this.updateColumnVisibility(columnName, isVisible)
        }
      })
    } catch (error) {
      console.error('Error loading column preferences:', error)
      localStorage.removeItem('campaignTableColumns')
    }
  }

  // Make columns sortable with drag and drop
  initializeDragAndDrop() {
    if (!this.hasColumnListTarget) {return}
    
    // This would integrate with a library like Sortable.js
    // For now, we'll implement basic reordering
    
    const items = this.columnListTarget.querySelectorAll('label')
    items.forEach((item, index) => {
      item.draggable = true
      item.dataset.originalIndex = index
      
      item.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', index)
        item.classList.add('opacity-50')
      })
      
      item.addEventListener('dragend', (e) => {
        item.classList.remove('opacity-50')
      })
      
      item.addEventListener('dragover', (e) => {
        e.preventDefault()
        item.classList.add('border-blue-500', 'bg-blue-50')
      })
      
      item.addEventListener('dragleave', (e) => {
        item.classList.remove('border-blue-500', 'bg-blue-50')
      })
      
      item.addEventListener('drop', (e) => {
        e.preventDefault()
        item.classList.remove('border-blue-500', 'bg-blue-50')
        
        const draggedIndex = parseInt(e.dataTransfer.getData('text/plain'))
        const dropIndex = parseInt(item.dataset.originalIndex)
        
        if (draggedIndex !== dropIndex) {
          this.reorderColumns(draggedIndex, dropIndex)
        }
      })
    })
  }

  // Reorder columns based on drag and drop
  reorderColumns(fromIndex, toIndex) {
    const items = Array.from(this.columnListTarget.children)
    const draggedItem = items[fromIndex]
    
    // Remove the dragged item
    draggedItem.remove()
    
    // Insert at new position
    if (toIndex >= items.length) {
      this.columnListTarget.appendChild(draggedItem)
    } else {
      this.columnListTarget.insertBefore(draggedItem, items[toIndex])
    }
    
    // Update table column order
    this.updateTableColumnOrder()
    
    // Save new order
    this.saveColumnOrder()
    
    this.showFeedback('Column order updated')
  }

  // Update table column order based on customizer order
  updateTableColumnOrder() {
    const table = this.element.querySelector('table')
    if (!table) {return}
    
    const thead = table.querySelector('thead tr')
    const tbody = table.querySelector('tbody')
    
    if (!thead || !tbody) {return}
    
    // Get new column order from customizer
    const newOrder = Array.from(this.columnListTarget.children).map(item => {
      return item.querySelector('input').dataset.column
    })
    
    // Reorder header cells
    const headerCells = Array.from(thead.children)
    const orderedHeaders = newOrder.map(columnName => {
      return headerCells.find(cell => cell.dataset.column === columnName)
    }).filter(Boolean)
    
    // Clear and rebuild header
    thead.innerHTML = ''
    orderedHeaders.forEach(cell => thead.appendChild(cell))
    
    // Reorder body cells in each row
    const rows = tbody.querySelectorAll('tr')
    rows.forEach(row => {
      const cells = Array.from(row.children)
      const orderedCells = newOrder.map(columnName => {
        return cells.find(cell => cell.dataset.column === columnName)
      }).filter(Boolean)
      
      // Clear and rebuild row
      row.innerHTML = ''
      orderedCells.forEach(cell => row.appendChild(cell))
    })
  }

  // Save column order to localStorage
  saveColumnOrder() {
    const order = Array.from(this.columnListTarget.children).map(item => {
      return item.querySelector('input').dataset.column
    })
    
    localStorage.setItem('campaignTableColumnOrder', JSON.stringify(order))
  }

  // Load column order from localStorage
  loadColumnOrder() {
    const saved = localStorage.getItem('campaignTableColumnOrder')
    if (!saved) {return}
    
    try {
      const order = JSON.parse(saved)
      
      // Reorder items in customizer
      const items = Array.from(this.columnListTarget.children)
      const orderedItems = order.map(columnName => {
        return items.find(item => item.querySelector('input').dataset.column === columnName)
      }).filter(Boolean)
      
      // Add any missing items at the end
      items.forEach(item => {
        if (!orderedItems.includes(item)) {
          orderedItems.push(item)
        }
      })
      
      // Clear and rebuild list
      this.columnListTarget.innerHTML = ''
      orderedItems.forEach(item => this.columnListTarget.appendChild(item))
      
      // Update table order
      this.updateTableColumnOrder()
      
    } catch (error) {
      console.error('Error loading column order:', error)
      localStorage.removeItem('campaignTableColumnOrder')
    }
  }

  // Show feedback message
  showFeedback(message) {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = 'fixed bottom-4 left-4 bg-gray-800 text-white px-4 py-2 rounded-lg shadow-lg z-50 transform -translate-x-full transition-transform'
    toast.innerHTML = `
      <div class="flex items-center">
        <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <span class="text-sm">${message}</span>
      </div>
    `
    
    document.body.appendChild(toast)
    
    // Slide in
    setTimeout(() => {
      toast.style.transform = 'translateX(0)'
    }, 100)
    
    // Slide out and remove
    setTimeout(() => {
      toast.style.transform = 'translateX(-100%)'
      setTimeout(() => {
        if (toast.parentElement) {
          toast.remove()
        }
      }, 300)
    }, 2000)
  }

  // Show error message
  showError(message) {
    const toast = document.createElement('div')
    toast.className = 'fixed bottom-4 left-4 bg-red-600 text-white px-4 py-2 rounded-lg shadow-lg z-50 transform -translate-x-full transition-transform'
    toast.innerHTML = `
      <div class="flex items-center">
        <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
        </svg>
        <span class="text-sm">${message}</span>
      </div>
    `
    
    document.body.appendChild(toast)
    
    // Slide in
    setTimeout(() => {
      toast.style.transform = 'translateX(0)'
    }, 100)
    
    // Slide out and remove
    setTimeout(() => {
      toast.style.transform = 'translateX(-100%)'
      setTimeout(() => {
        if (toast.parentElement) {
          toast.remove()
        }
      }, 3000)
    }, 100)
  }

  // Humanize column names
  humanize(str) {
    return str.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  // Export current column configuration
  exportConfiguration() {
    const config = {
      visibility: {},
      order: []
    }
    
    // Get visibility preferences
    const checkboxes = this.columnListTarget.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => {
      config.visibility[checkbox.dataset.column] = checkbox.checked
    })
    
    // Get column order
    config.order = Array.from(this.columnListTarget.children).map(item => {
      return item.querySelector('input').dataset.column
    })
    
    // Download as JSON
    const blob = new Blob([JSON.stringify(config, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = 'campaign-table-config.json'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  // Import column configuration
  importConfiguration(event) {
    const file = event.target.files[0]
    if (!file) {return}
    
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const config = JSON.parse(e.target.result)
        
        // Apply visibility settings
        if (config.visibility) {
          const checkboxes = this.columnListTarget.querySelectorAll('input[type="checkbox"]')
          checkboxes.forEach(checkbox => {
            const columnName = checkbox.dataset.column
            if (config.visibility.hasOwnProperty(columnName)) {
              checkbox.checked = config.visibility[columnName]
              this.updateColumnVisibility(columnName, config.visibility[columnName])
            }
          })
        }
        
        // Apply column order
        if (config.order) {
          const items = Array.from(this.columnListTarget.children)
          const orderedItems = config.order.map(columnName => {
            return items.find(item => item.querySelector('input').dataset.column === columnName)
          }).filter(Boolean)
          
          // Clear and rebuild
          this.columnListTarget.innerHTML = ''
          orderedItems.forEach(item => this.columnListTarget.appendChild(item))
          
          this.updateTableColumnOrder()
        }
        
        // Save preferences
        this.saveColumnPreferences()
        this.saveColumnOrder()
        
        this.showFeedback('Configuration imported successfully')
        
      } catch (error) {
        console.error('Error importing configuration:', error)
        this.showError('Failed to import configuration. Please check the file format.')
      }
    }
    
    reader.readAsText(file)
  }
}