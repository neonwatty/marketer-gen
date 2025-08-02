import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="content-library"
export default class extends Controller {
  static targets = [
    "searchInput", "statusFilter", "typeFilter", "formatFilter", "dateFilter",
    "contentContainer", "gridView", "listView", "gridViewBtn", "listViewBtn",
    "loadingOverlay"
  ]
  
  static values = {
    searchUrl: String
  }

  connect() {
    console.log("Content library controller connected")
    this.debounceTimeout = null
    this.currentView = 'grid'
  }

  // Search functionality with debouncing
  debounceSearch() {
    clearTimeout(this.debounceTimeout)
    this.debounceTimeout = setTimeout(() => {
      this.performSearch()
    }, 300)
  }

  filterChanged() {
    this.performSearch()
  }

  async performSearch() {
    this.showLoading()
    
    try {
      const formData = new FormData()
      
      // Get search term
      if (this.hasSearchInputTarget) {
        formData.append('q[title_or_description_cont]', this.searchInputTarget.value)
      }
      
      // Get filter values
      if (this.hasStatusFilterTarget && this.statusFilterTarget.value) {
        formData.append('q[status_eq]', this.statusFilterTarget.value)
      }
      
      if (this.hasTypeFilterTarget && this.typeFilterTarget.value) {
        formData.append('q[content_type_eq]', this.typeFilterTarget.value)
      }
      
      if (this.hasFormatFilterTarget && this.formatFilterTarget.value) {
        formData.append('q[format_eq]', this.formatFilterTarget.value)
      }
      
      if (this.hasDateFilterTarget && this.dateFilterTarget.value) {
        formData.append('date_range', this.dateFilterTarget.value)
      }

      const response = await fetch(this.searchUrlValue, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateContentDisplay(data)
      } else {
        console.error('Search failed:', response.status)
      }
    } catch (error) {
      console.error('Search error:', error)
    } finally {
      this.hideLoading()
    }
  }

  updateContentDisplay(data) {
    // This would update the content display with new results
    // For now, we'll just log the data
    console.log('Search results:', data)
    
    // In a real implementation, you would:
    // 1. Parse the JSON response
    // 2. Update the grid/list view with new content
    // 3. Update pagination if needed
    // 4. Update the stats counters
  }

  // View switching
  setGridView() {
    this.currentView = 'grid'
    this.updateViewDisplay()
    this.updateViewButtons()
  }

  setListView() {
    this.currentView = 'list'
    this.updateViewDisplay()
    this.updateViewButtons()
  }

  updateViewDisplay() {
    if (this.hasGridViewTarget && this.hasListViewTarget) {
      if (this.currentView === 'grid') {
        this.gridViewTarget.classList.remove('hidden')
        this.listViewTarget.classList.add('hidden')
      } else {
        this.gridViewTarget.classList.add('hidden')
        this.listViewTarget.classList.remove('hidden')
      }
    }
  }

  updateViewButtons() {
    if (this.hasGridViewBtnTarget && this.hasListViewBtnTarget) {
      // Remove active class from both
      this.gridViewBtnTarget.classList.remove('active')
      this.listViewBtnTarget.classList.remove('active')
      
      // Add active class to current view
      if (this.currentView === 'grid') {
        this.gridViewBtnTarget.classList.add('active')
      } else {
        this.listViewBtnTarget.classList.add('active')
      }
    }
  }

  // Bulk operations
  toggleBulkMode() {
    // Toggle bulk selection mode
    console.log('Toggling bulk mode')
    
    // This would:
    // 1. Show/hide checkboxes on content items
    // 2. Show/hide bulk action toolbar
    // 3. Update UI state
  }

  // Loading states
  showLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.remove('hidden')
    }
  }

  hideLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add('hidden')
    }
  }

  // Keyboard shortcuts
  keydown(event) {
    // Handle keyboard shortcuts
    if (event.key === 'Escape') {
      this.clearSearch()
    } else if (event.key === 'Enter' && event.target === this.searchInputTarget) {
      event.preventDefault()
      this.performSearch()
    }
  }

  clearSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
      this.performSearch()
    }
  }

  disconnect() {
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout)
    }
  }
}