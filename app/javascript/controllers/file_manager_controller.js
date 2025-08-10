import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "fileGrid",
    "fileList", 
    "viewToggle",
    "gridView",
    "listView",
    "searchInput",
    "fileTypeFilter",
    "scanStatusFilter",
    "sortSelect",
    "selectedCount",
    "bulkActions",
    "selectAll",
    "previewModal",
    "previewContent",
    "metadataModal",
    "metadataForm",
    "paginationContainer"
  ]

  static values = {
    currentView: { type: String, default: "grid" },
    selectedFiles: { type: Array, default: [] },
    currentPage: { type: Number, default: 1 },
    totalPages: { type: Number, default: 1 }
  }

  static classes = [
    "selected",
    "gridActive", 
    "listActive"
  ]

  connect() {
    this.initializeView()
    this.setupKeyboardShortcuts()
    this.loadViewPreference()
  }

  // View Management
  toggleView(event) {
    const newView = event.currentTarget.dataset.view
    this.currentViewValue = newView
    this.updateViewDisplay()
    this.saveViewPreference()
  }

  updateViewDisplay() {
    if (this.currentViewValue === "grid") {
      this.showGridView()
    } else {
      this.showListView()
    }
    this.updateViewToggleButtons()
  }

  showGridView() {
    if (this.hasFileGridTarget) this.fileGridTarget.classList.remove("hidden")
    if (this.hasFileListTarget) this.fileListTarget.classList.add("hidden")
    
    // Update grid classes for responsive layout
    const fileCards = this.element.querySelectorAll('.file-card')
    fileCards.forEach(card => {
      card.className = card.className.replace(/grid-cols-\d+/, 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4')
    })
  }

  showListView() {
    if (this.hasFileGridTarget) this.fileGridTarget.classList.add("hidden") 
    if (this.hasFileListTarget) this.fileListTarget.classList.remove("hidden")
  }

  updateViewToggleButtons() {
    const buttons = this.viewToggleTargets || this.element.querySelectorAll('[data-view]')
    buttons.forEach(button => {
      const isActive = button.dataset.view === this.currentViewValue
      if (isActive) {
        button.classList.add(...this.gridActiveClasses)
        button.classList.remove(...this.listActiveClasses)
      } else {
        button.classList.remove(...this.gridActiveClasses)  
        button.classList.add(...this.listActiveClasses)
      }
    })
  }

  // File Selection Management
  selectFile(event) {
    const checkbox = event.currentTarget
    const fileId = checkbox.value
    const isChecked = checkbox.checked

    if (isChecked) {
      if (!this.selectedFilesValue.includes(fileId)) {
        this.selectedFilesValue = [...this.selectedFilesValue, fileId]
      }
    } else {
      this.selectedFilesValue = this.selectedFilesValue.filter(id => id !== fileId)
    }

    this.updateFileSelection(fileId, isChecked)
    this.updateBulkActionsUI()
  }

  selectAllFiles(event) {
    const selectAll = event.currentTarget
    const isChecked = selectAll.checked
    const fileCheckboxes = this.element.querySelectorAll('.file-checkbox')

    fileCheckboxes.forEach(checkbox => {
      checkbox.checked = isChecked
      const fileId = checkbox.value
      
      if (isChecked) {
        if (!this.selectedFilesValue.includes(fileId)) {
          this.selectedFilesValue = [...this.selectedFilesValue, fileId]
        }
        this.updateFileSelection(fileId, true)
      } else {
        this.selectedFilesValue = this.selectedFilesValue.filter(id => id !== fileId)
        this.updateFileSelection(fileId, false)
      }
    })

    this.updateBulkActionsUI()
  }

  updateFileSelection(fileId, isSelected) {
    const fileElement = this.element.querySelector(`[data-file-id="${fileId}"]`)
    if (fileElement) {
      if (isSelected) {
        fileElement.classList.add(...this.selectedClasses)
      } else {
        fileElement.classList.remove(...this.selectedClasses)
      }
    }
  }

  clearSelection() {
    this.selectedFilesValue = []
    const checkboxes = this.element.querySelectorAll('.file-checkbox')
    checkboxes.forEach(checkbox => {
      checkbox.checked = false
    })
    
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
    }

    // Remove selection styling
    const selectedElements = this.element.querySelectorAll('[data-file-id]')
    selectedElements.forEach(element => {
      element.classList.remove(...this.selectedClasses)
    })

    this.updateBulkActionsUI()
  }

  updateBulkActionsUI() {
    const count = this.selectedFilesValue.length
    
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = count
    }
    
    if (this.hasBulkActionsTarget) {
      if (count > 0) {
        this.bulkActionsTarget.classList.remove("hidden")
      } else {
        this.bulkActionsTarget.classList.add("hidden")
      }
    }

    // Update select all checkbox state
    if (this.hasSelectAllTarget) {
      const fileCheckboxes = this.element.querySelectorAll('.file-checkbox')
      const checkedCount = this.element.querySelectorAll('.file-checkbox:checked').length
      
      if (checkedCount === 0) {
        this.selectAllTarget.checked = false
        this.selectAllTarget.indeterminate = false
      } else if (checkedCount === fileCheckboxes.length) {
        this.selectAllTarget.checked = true
        this.selectAllTarget.indeterminate = false
      } else {
        this.selectAllTarget.checked = false
        this.selectAllTarget.indeterminate = true
      }
    }
  }

  // Bulk Actions
  async bulkDelete() {
    if (this.selectedFilesValue.length === 0) return

    const confirmMessage = `Are you sure you want to delete ${this.selectedFilesValue.length} selected file(s)?`
    if (!confirm(confirmMessage)) return

    this.showBulkActionProgress("Deleting files...")

    try {
      const results = await Promise.allSettled(
        this.selectedFilesValue.map(fileId => this.deleteFile(fileId))
      )

      const successful = results.filter(r => r.status === 'fulfilled').length
      const failed = results.filter(r => r.status === 'rejected').length

      if (failed > 0) {
        this.showNotification(`${successful} files deleted, ${failed} failed`, "warning")
      } else {
        this.showNotification(`${successful} files deleted successfully`, "success")
      }

      this.clearSelection()
      this.refreshFileList()
    } catch (error) {
      this.showNotification("Bulk delete failed", "error")
    } finally {
      this.hideBulkActionProgress()
    }
  }

  async bulkDownload() {
    if (this.selectedFilesValue.length === 0) return

    this.showBulkActionProgress("Preparing download...")

    try {
      // Create and trigger download for each file
      for (const fileId of this.selectedFilesValue) {
        const fileElement = this.element.querySelector(`[data-file-id="${fileId}"]`)
        const downloadUrl = fileElement?.dataset.downloadUrl
        
        if (downloadUrl) {
          const link = document.createElement('a')
          link.href = downloadUrl
          link.download = ''
          document.body.appendChild(link)
          link.click()
          document.body.removeChild(link)
          
          // Small delay between downloads
          await new Promise(resolve => setTimeout(resolve, 100))
        }
      }

      this.showNotification(`${this.selectedFilesValue.length} files download started`, "success")
    } catch (error) {
      this.showNotification("Bulk download failed", "error")
    } finally {
      this.hideBulkActionProgress()
    }
  }

  async bulkCategorize() {
    if (this.selectedFilesValue.length === 0) return

    const fileType = prompt("Enter new file type for selected files:")
    if (!fileType) return

    this.showBulkActionProgress("Updating file categories...")

    try {
      const results = await Promise.allSettled(
        this.selectedFilesValue.map(fileId => 
          this.updateFileMetadata(fileId, { file_type: fileType })
        )
      )

      const successful = results.filter(r => r.status === 'fulfilled').length
      const failed = results.filter(r => r.status === 'rejected').length

      if (failed > 0) {
        this.showNotification(`${successful} files updated, ${failed} failed`, "warning")
      } else {
        this.showNotification(`${successful} files categorized successfully`, "success")
      }

      this.clearSelection()
      this.refreshFileList()
    } catch (error) {
      this.showNotification("Bulk categorization failed", "error")
    } finally {
      this.hideBulkActionProgress()
    }
  }

  // File Preview
  async previewFile(event) {
    const fileId = event.currentTarget.dataset.fileId
    const fileElement = this.element.querySelector(`[data-file-id="${fileId}"]`)
    
    if (!fileElement) return

    const fileName = fileElement.dataset.fileName
    const fileUrl = fileElement.dataset.fileUrl
    const fileType = fileElement.dataset.fileType
    const contentType = fileElement.dataset.contentType

    this.openPreviewModal(fileName, fileUrl, fileType, contentType)
  }

  openPreviewModal(fileName, fileUrl, fileType, contentType) {
    if (!this.hasPreviewModalTarget) return

    // Set modal title
    const titleElement = this.previewModalTarget.querySelector('.modal-title')
    if (titleElement) {
      titleElement.textContent = fileName
    }

    // Generate preview content
    let previewHtml = ''

    if (contentType.startsWith('image/')) {
      previewHtml = `
        <div class="text-center">
          <img src="${fileUrl}" alt="${fileName}" class="max-w-full max-h-96 mx-auto rounded-lg shadow-lg">
        </div>
      `
    } else if (contentType === 'application/pdf') {
      previewHtml = `
        <div class="w-full h-96">
          <embed src="${fileUrl}" type="application/pdf" width="100%" height="100%" class="rounded-lg">
        </div>
        <div class="mt-4 text-center">
          <a href="${fileUrl}" target="_blank" class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
            </svg>
            Open in New Tab
          </a>
        </div>
      `
    } else {
      previewHtml = `
        <div class="text-center py-8">
          <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">Preview not available</h3>
          <p class="text-gray-500 mb-4">This file type cannot be previewed in the browser.</p>
          <a href="${fileUrl}" target="_blank" class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3M3 17V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z"></path>
            </svg>
            Download File
          </a>
        </div>
      `
    }

    if (this.hasPreviewContentTarget) {
      this.previewContentTarget.innerHTML = previewHtml
    }

    this.showModal(this.previewModalTarget)
  }

  // Metadata Editing
  editMetadata(event) {
    const fileId = event.currentTarget.dataset.fileId
    const fileElement = this.element.querySelector(`[data-file-id="${fileId}"]`)
    
    if (!fileElement || !this.hasMetadataModalTarget) return

    // Populate form with current metadata
    this.populateMetadataForm(fileElement)
    this.metadataModalTarget.dataset.fileId = fileId
    
    this.showModal(this.metadataModalTarget)
  }

  populateMetadataForm(fileElement) {
    const form = this.metadataFormTarget
    if (!form) return

    // Basic file info
    const fileName = fileElement.dataset.fileName
    const fileType = fileElement.dataset.fileType
    const purpose = fileElement.dataset.purpose || ''
    
    form.querySelector('[name="file_name"]').value = fileName
    form.querySelector('[name="file_type"]').value = fileType  
    form.querySelector('[name="purpose"]').value = purpose

    // Custom metadata
    const metadata = JSON.parse(fileElement.dataset.metadata || '{}')
    const tagsInput = form.querySelector('[name="tags"]')
    const descriptionInput = form.querySelector('[name="description"]')
    
    if (tagsInput && metadata.tags) {
      tagsInput.value = Array.isArray(metadata.tags) ? metadata.tags.join(', ') : metadata.tags
    }
    
    if (descriptionInput && metadata.description) {
      descriptionInput.value = metadata.description
    }
  }

  async saveMetadata(event) {
    event.preventDefault()
    
    const fileId = this.metadataModalTarget.dataset.fileId
    const formData = new FormData(this.metadataFormTarget)
    
    // Convert form data to metadata object
    const metadata = {
      file_type: formData.get('file_type'),
      purpose: formData.get('purpose'),
      tags: formData.get('tags') ? formData.get('tags').split(',').map(tag => tag.trim()) : [],
      description: formData.get('description')
    }

    try {
      await this.updateFileMetadata(fileId, metadata)
      this.showNotification('Metadata updated successfully', 'success')
      this.closeModal(this.metadataModalTarget)
      this.refreshFileList()
    } catch (error) {
      this.showNotification('Failed to update metadata', 'error')
    }
  }

  // Search and Filtering
  performSearch() {
    const query = this.hasSearchInputTarget ? this.searchInputTarget.value : ''
    const fileType = this.hasFileTypeFilterTarget ? this.fileTypeFilterTarget.value : ''
    const scanStatus = this.hasScanStatusFilterTarget ? this.scanStatusFilterTarget.value : ''
    const sort = this.hasSortSelectTarget ? this.sortSelectTarget.value : 'recent'
    
    this.applyFilters({ query, file_type: fileType, scan_status: scanStatus, sort })
  }

  async applyFilters(filters) {
    const params = new URLSearchParams()
    
    Object.entries(filters).forEach(([key, value]) => {
      if (value) params.append(key, value)
    })
    
    params.append('page', this.currentPageValue)

    try {
      const response = await fetch(`${window.location.pathname}?${params.toString()}`, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.updateFileListContent(html)
      }
    } catch (error) {
      this.showNotification('Filter update failed', 'error')
    }
  }

  updateFileListContent(html) {
    const parser = new DOMParser()
    const doc = parser.parseFromString(html, 'text/html')
    
    // Update file grid/list
    const newFileGrid = doc.querySelector('[data-file-manager-target="fileGrid"]')
    const newFileList = doc.querySelector('[data-file-manager-target="fileList"]')
    
    if (newFileGrid && this.hasFileGridTarget) {
      this.fileGridTarget.innerHTML = newFileGrid.innerHTML
    }
    
    if (newFileList && this.hasFileListTarget) {
      this.fileListTarget.innerHTML = newFileList.innerHTML
    }

    // Update pagination
    const newPagination = doc.querySelector('[data-file-manager-target="paginationContainer"]')
    if (newPagination && this.hasPaginationContainerTarget) {
      this.paginationContainerTarget.innerHTML = newPagination.innerHTML
    }

    this.clearSelection()
  }

  // Pagination
  goToPage(event) {
    event.preventDefault()
    const page = parseInt(event.currentTarget.dataset.page)
    this.currentPageValue = page
    this.performSearch()
  }

  // Utility Methods
  async deleteFile(fileId) {
    const response = await fetch(`/brand_assets/${fileId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': this.getCsrfToken(),
        'Accept': 'application/json'
      }
    })
    
    if (!response.ok) {
      throw new Error(`Delete failed: ${response.statusText}`)
    }
    
    return response.json()
  }

  async updateFileMetadata(fileId, metadata) {
    const response = await fetch(`/brand_assets/${fileId}/update_metadata`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCsrfToken(),
        'Accept': 'application/json'
      },
      body: JSON.stringify({ metadata })
    })
    
    if (!response.ok) {
      throw new Error(`Metadata update failed: ${response.statusText}`)
    }
    
    return response.json()
  }

  refreshFileList() {
    this.performSearch()
  }

  // Modal Management
  showModal(modal) {
    modal.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }

  closeModal(modal) {
    modal.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }

  closePreviewModal() {
    if (this.hasPreviewModalTarget) {
      this.closeModal(this.previewModalTarget)
    }
  }

  closeMetadataModal() {
    if (this.hasMetadataModalTarget) {
      this.closeModal(this.metadataModalTarget)
    }
  }

  // Progress and Notifications
  showBulkActionProgress(message) {
    // Implementation for showing progress indicator
    console.log(message)
  }

  hideBulkActionProgress() {
    // Implementation for hiding progress indicator
  }

  showNotification(message, type = 'info') {
    // Create and show notification
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 ${this.getNotificationClasses(type)}`
    notification.innerHTML = `
      <div class="flex items-center">
        <span class="mr-2">${this.getNotificationIcon(type)}</span>
        <span>${message}</span>
        <button class="ml-4 text-white hover:text-gray-200" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove()
      }
    }, 5000)
  }

  getNotificationClasses(type) {
    const classes = {
      success: 'bg-green-600 text-white',
      error: 'bg-red-600 text-white',
      warning: 'bg-yellow-600 text-white',
      info: 'bg-blue-600 text-white'
    }
    return classes[type] || classes.info
  }

  getNotificationIcon(type) {
    const icons = {
      success: '✓',
      error: '✕',
      warning: '⚠',
      info: 'ℹ'
    }
    return icons[type] || icons.info
  }

  // Keyboard Shortcuts
  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (event) => {
      if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') return
      
      switch (event.key) {
        case 'g':
          if (!event.ctrlKey && !event.metaKey) {
            this.currentViewValue = 'grid'
            this.updateViewDisplay()
            event.preventDefault()
          }
          break
        case 'l':
          if (!event.ctrlKey && !event.metaKey) {
            this.currentViewValue = 'list'
            this.updateViewDisplay()
            event.preventDefault()
          }
          break
        case 'a':
          if (event.ctrlKey || event.metaKey) {
            if (this.hasSelectAllTarget) {
              this.selectAllTarget.checked = !this.selectAllTarget.checked
              this.selectAllFiles({ currentTarget: this.selectAllTarget })
              event.preventDefault()
            }
          }
          break
        case 'Delete':
          if (this.selectedFilesValue.length > 0) {
            this.bulkDelete()
            event.preventDefault()
          }
          break
      }
    })
  }

  // Preferences
  loadViewPreference() {
    const saved = localStorage.getItem('file-manager-view')
    if (saved) {
      this.currentViewValue = saved
      this.updateViewDisplay()
    }
  }

  saveViewPreference() {
    localStorage.setItem('file-manager-view', this.currentViewValue)
  }

  initializeView() {
    this.updateViewDisplay()
    this.updateBulkActionsUI()
  }

  getCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ''
  }
}