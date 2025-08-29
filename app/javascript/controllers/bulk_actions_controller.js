import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-actions"
export default class extends Controller {
  static targets = ["checkbox", "toolbar", "selectAllCheckbox", "bulkButton", "selectedCount"]
  static values = { 
    resource: String,
    archiveUrl: String,
    duplicateUrl: String,
    deleteUrl: String
  }

  connect() {
    this.updateToolbar()
  }

  selectAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
      this.updateRowHighlight(checkbox)
    })
    this.updateToolbar()
  }

  toggleSelection(event) {
    this.updateRowHighlight(event.target)
    this.updateToolbar()
    this.updateSelectAllState()
  }

  updateRowHighlight(checkbox) {
    const row = checkbox.closest('[data-bulk-actions-target="row"]')
    if (row) {
      if (checkbox.checked) {
        row.classList.add('ring-2', 'ring-blue-500', 'bg-blue-50')
      } else {
        row.classList.remove('ring-2', 'ring-blue-500', 'bg-blue-50')
      }
    }
  }

  updateSelectAllState() {
    if (!this.hasSelectAllCheckboxTarget) return

    const totalCheckboxes = this.checkboxTargets.length
    const checkedCheckboxes = this.selectedItems.length

    if (checkedCheckboxes === 0) {
      this.selectAllCheckboxTarget.indeterminate = false
      this.selectAllCheckboxTarget.checked = false
    } else if (checkedCheckboxes === totalCheckboxes) {
      this.selectAllCheckboxTarget.indeterminate = false
      this.selectAllCheckboxTarget.checked = true
    } else {
      this.selectAllCheckboxTarget.indeterminate = true
      this.selectAllCheckboxTarget.checked = false
    }
  }

  updateToolbar() {
    const selectedCount = this.selectedItems.length
    
    if (this.hasToolbarTarget) {
      if (selectedCount > 0) {
        this.toolbarTarget.classList.remove('hidden')
      } else {
        this.toolbarTarget.classList.add('hidden')
      }
    }

    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = selectedCount
    }

    // Enable/disable bulk action buttons based on selection
    this.bulkButtonTargets.forEach(button => {
      const minSelection = parseInt(button.dataset.minSelection || '1')
      const maxSelection = parseInt(button.dataset.maxSelection || '999')
      
      if (selectedCount >= minSelection && selectedCount <= maxSelection) {
        button.disabled = false
        button.classList.remove('opacity-50', 'cursor-not-allowed')
      } else {
        button.disabled = true
        button.classList.add('opacity-50', 'cursor-not-allowed')
      }
    })
  }

  clearSelection() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
      this.updateRowHighlight(checkbox)
    })
    this.updateToolbar()
    this.updateSelectAllState()
  }

  get selectedItems() {
    return this.checkboxTargets.filter(checkbox => checkbox.checked)
  }

  get selectedIds() {
    return this.selectedItems.map(checkbox => checkbox.value)
  }

  // Bulk action handlers
  bulkArchive() {
    if (!this.confirmBulkAction('archive')) return

    this.performBulkAction('archive', this.archiveUrlValue)
  }

  bulkDuplicate() {
    if (!this.confirmBulkAction('duplicate')) return

    this.performBulkAction('duplicate', this.duplicateUrlValue)
  }

  bulkDelete() {
    if (!this.confirmBulkAction('delete')) return

    this.performBulkAction('delete', this.deleteUrlValue)
  }

  confirmBulkAction(action) {
    const selectedCount = this.selectedItems.length
    const resource = this.resourceValue || 'items'
    
    const message = `Are you sure you want to ${action} ${selectedCount} ${resource}? This action cannot be undone.`
    return confirm(message)
  }

  performBulkAction(action, url) {
    if (!url) {
      console.error(`No URL configured for bulk ${action}`)
      return
    }

    const selectedIds = this.selectedIds
    if (selectedIds.length === 0) return

    // Show loading state
    this.setLoadingState(true)

    // Create form data
    const formData = new FormData()
    formData.append('_method', 'PATCH') // Rails expects PATCH for bulk updates
    formData.append('action', action)
    selectedIds.forEach(id => formData.append('ids[]', id))

    // Add CSRF token
    const token = document.querySelector('meta[name="csrf-token"]')
    if (token) {
      formData.append('authenticity_token', token.getAttribute('content'))
    }

    fetch(url, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => {
      if (response.ok) {
        // Refresh the page or remove items from DOM
        window.location.reload()
      } else {
        throw new Error('Network response was not ok')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      alert(`Failed to ${action} selected ${this.resourceValue}. Please try again.`)
    })
    .finally(() => {
      this.setLoadingState(false)
    })
  }

  setLoadingState(loading) {
    this.bulkButtonTargets.forEach(button => {
      if (loading) {
        button.disabled = true
        button.classList.add('opacity-50')
        button.innerHTML = button.innerHTML.replace(/^/, '<span class="animate-spin inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full mr-2"></span>')
      } else {
        button.disabled = false
        button.classList.remove('opacity-50')
        button.innerHTML = button.innerHTML.replace(/<span class="animate-spin[^>]*><\/span>/, '')
      }
    })
  }
}