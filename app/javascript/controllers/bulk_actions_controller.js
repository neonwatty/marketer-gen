import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-actions"
export default class extends Controller {
  static targets = ["count", "checkbox", "selectAllCheckbox", "form", "deleteForm", "idsInput", "deleteIdsInput"]

  connect() {
    console.log("Bulk actions controller connected")
    this.selectedIds = new Set()
    this.updateUI()
  }

  // Toggle individual campaign selection
  toggleSelect(event) {
    const checkbox = event.target
    const campaignId = checkbox.dataset.campaignId
    
    if (checkbox.checked) {
      this.selectedIds.add(campaignId)
    } else {
      this.selectedIds.delete(campaignId)
    }
    
    this.updateUI()
  }

  // Toggle select all campaigns on current page
  toggleSelectAll(event) {
    const selectAll = event.target.checked
    const checkboxes = this.checkboxTargets
    
    checkboxes.forEach(checkbox => {
      const campaignId = checkbox.dataset.campaignId
      checkbox.checked = selectAll
      
      if (selectAll) {
        this.selectedIds.add(campaignId)
      } else {
        this.selectedIds.delete(campaignId)
      }
    })
    
    this.updateUI()
  }

  // Select all campaigns (current page)
  selectAll(event) {
    event.preventDefault()
    
    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.checked = true
      this.toggleSelectAll({ target: this.selectAllCheckboxTarget })
    }
  }

  // Clear all selections
  clearSelection(event) {
    event.preventDefault()
    
    this.selectedIds.clear()
    
    // Uncheck all checkboxes
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    
    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.checked = false
    }
    
    this.updateUI()
  }

  // Update bulk status
  updateStatus(event) {
    const status = event.target.value
    
    if (status && this.selectedIds.size > 0) {
      this.updateHiddenFields()
      
      // Show confirmation dialog
      const message = `Are you sure you want to update ${this.selectedIds.size} campaign(s) to "${status}"?`
      if (confirm(message)) {
        if (this.hasFormTarget) {
          this.formTarget.submit()
        }
      }
    }
  }

  // Export selected campaigns
  exportSelected(event) {
    event.preventDefault()
    
    if (this.selectedIds.size === 0) {
      alert('Please select at least one campaign to export.')
      return
    }

    const format = event.target.dataset.format || 'csv'
    const link = event.target
    const url = new URL(link.href)
    
    // Add selected IDs to the export URL
    url.searchParams.set('ids', Array.from(this.selectedIds).join(','))
    
    // Create hidden link and trigger download
    const downloadLink = document.createElement('a')
    downloadLink.href = url.toString()
    downloadLink.download = ''
    document.body.appendChild(downloadLink)
    downloadLink.click()
    document.body.removeChild(downloadLink)
  }

  // Delete selected campaigns
  deleteSelected(event) {
    if (this.selectedIds.size === 0) {
      event.preventDefault()
      alert('Please select at least one campaign to delete.')
      return
    }

    this.updateHiddenFields()
    
    const message = `Are you sure you want to delete ${this.selectedIds.size} campaign(s)? This action cannot be undone.`
    if (!confirm(message)) {
      event.preventDefault()
    }
  }

  // Update UI based on selection state
  updateUI() {
    const selectedCount = this.selectedIds.size
    const hasSelection = selectedCount > 0
    
    // Update selection count
    if (this.hasCountTarget) {
      this.countTarget.textContent = selectedCount
    }
    
    // Show/hide bulk actions toolbar
    const toolbar = document.getElementById('bulk-actions-toolbar')
    if (toolbar) {
      if (hasSelection) {
        toolbar.classList.remove('hidden')
        // Add slide-down animation
        toolbar.style.maxHeight = '0'
        toolbar.style.overflow = 'hidden'
        toolbar.style.transition = 'max-height 0.3s ease-out'
        
        // Trigger reflow
        toolbar.offsetHeight
        
        toolbar.style.maxHeight = '200px'
      } else {
        toolbar.style.maxHeight = '0'
        setTimeout(() => {
          toolbar.classList.add('hidden')
          toolbar.style.maxHeight = ''
          toolbar.style.overflow = ''
          toolbar.style.transition = ''
        }, 300)
      }
    }
    
    // Update select all checkbox state
    if (this.hasSelectAllCheckboxTarget) {
      const allCheckboxes = this.checkboxTargets
      const checkedCheckboxes = allCheckboxes.filter(cb => cb.checked)
      
      if (checkedCheckboxes.length === 0) {
        this.selectAllCheckboxTarget.checked = false
        this.selectAllCheckboxTarget.indeterminate = false
      } else if (checkedCheckboxes.length === allCheckboxes.length) {
        this.selectAllCheckboxTarget.checked = true
        this.selectAllCheckboxTarget.indeterminate = false
      } else {
        this.selectAllCheckboxTarget.checked = false
        this.selectAllCheckboxTarget.indeterminate = true
      }
    }
    
    // Update hidden form fields
    this.updateHiddenFields()
  }

  // Update hidden form fields with selected IDs
  updateHiddenFields() {
    const idsArray = Array.from(this.selectedIds)
    
    // Update bulk update form
    if (this.hasIdsInputTarget) {
      this.idsInputTarget.value = idsArray.join(',')
    }
    
    // Update bulk delete form
    if (this.hasDeleteIdsInputTarget) {
      this.deleteIdsInputTarget.value = idsArray.join(',')
    }
  }

  // Handle campaign row updates (when campaigns are added/removed)
  campaignUpdated(event) {
    const { action, campaignId } = event.detail
    
    if (action === 'removed') {
      this.selectedIds.delete(campaignId)
      this.updateUI()
    }
  }

  // Handle page navigation (preserve selections across pages)
  preserveSelections() {
    // Store selections in session storage for cross-page persistence
    if (this.selectedIds.size > 0) {
      sessionStorage.setItem('selectedCampaignIds', JSON.stringify(Array.from(this.selectedIds)))
    } else {
      sessionStorage.removeItem('selectedCampaignIds')
    }
  }

  // Restore selections from session storage
  restoreSelections() {
    const stored = sessionStorage.getItem('selectedCampaignIds')
    if (stored) {
      try {
        const ids = JSON.parse(stored)
        this.selectedIds = new Set(ids)
        
        // Check corresponding checkboxes on current page
        this.checkboxTargets.forEach(checkbox => {
          const campaignId = checkbox.dataset.campaignId
          if (this.selectedIds.has(campaignId)) {
            checkbox.checked = true
          }
        })
        
        this.updateUI()
      } catch (error) {
        console.error('Error restoring selections:', error)
        sessionStorage.removeItem('selectedCampaignIds')
      }
    }
  }

  // Listen for Turbo navigation events
  disconnect() {
    this.preserveSelections()
  }

  // Restore selections when navigating back to page
  turboLoad() {
    this.restoreSelections()
  }

  // Show selection summary
  showSelectionSummary() {
    if (this.selectedIds.size === 0) return

    const summary = document.createElement('div')
    summary.className = 'fixed bottom-4 right-4 bg-blue-600 text-white px-4 py-2 rounded-lg shadow-lg z-50'
    summary.innerHTML = `
      <div class="flex items-center space-x-2">
        <span>${this.selectedIds.size} campaign(s) selected</span>
        <button type="button" 
                class="text-blue-200 hover:text-white"
                onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
          </svg>
        </button>
      </div>
    `
    
    document.body.appendChild(summary)
    
    // Auto-hide after 3 seconds
    setTimeout(() => {
      if (summary.parentElement) {
        summary.remove()
      }
    }, 3000)
  }

  // Keyboard shortcuts
  handleKeydown(event) {
    // Ctrl/Cmd + A to select all
    if ((event.ctrlKey || event.metaKey) && event.key === 'a') {
      event.preventDefault()
      this.selectAll(event)
    }
    
    // Escape to clear selection
    if (event.key === 'Escape') {
      this.clearSelection(event)
    }
    
    // Delete key to delete selected
    if (event.key === 'Delete' && this.selectedIds.size > 0) {
      if (this.hasDeleteFormTarget) {
        this.deleteSelected(event)
        if (!event.defaultPrevented) {
          this.deleteFormTarget.submit()
        }
      }
    }
  }
}