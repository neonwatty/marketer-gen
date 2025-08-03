import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="campaigns-table"
export default class extends Controller {
  static targets = ["tbody", "loading"]
  static values = { url: String }

  connect() {
    console.log("Campaigns table controller connected")
    this.debounceTimer = null
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  // Handle column sorting
  sort(event) {
    event.preventDefault()
    
    const column = event.currentTarget.dataset.sortField
    const currentSort = new URLSearchParams(window.location.search).get('sort')
    const currentDirection = new URLSearchParams(window.location.search).get('direction') || 'desc'
    
    // Determine new direction
    let newDirection = 'asc'
    if (currentSort === column && currentDirection === 'asc') {
      newDirection = 'desc'
    }

    // Update URL with new sort parameters
    const url = new URL(window.location)
    url.searchParams.set('sort', column)
    url.searchParams.set('direction', newDirection)
    
    // Show loading state
    this.showLoading()
    
    // Navigate to sorted URL
    Turbo.visit(url.toString(), { action: "replace" })
  }

  // Show loading indicator
  showLoading() {
    if (this.hasLoadingTarget && this.hasTbodyTarget) {
      this.tbodyTarget.style.opacity = '0.5'
      this.loadingTarget.classList.remove('hidden')
    }
  }

  // Hide loading indicator
  hideLoading() {
    if (this.hasLoadingTarget && this.hasTbodyTarget) {
      this.tbodyTarget.style.opacity = '1'
      this.loadingTarget.classList.add('hidden')
    }
  }

  // Handle AJAX updates
  async updateTable(params = {}) {
    if (!this.urlValue) {return}

    this.showLoading()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      
      // Add current URL params
      const currentParams = new URLSearchParams(window.location.search)
      currentParams.forEach((value, key) => {
        url.searchParams.set(key, value)
      })

      // Add new params
      Object.entries(params).forEach(([key, value]) => {
        if (value) {
          url.searchParams.set(key, value)
        } else {
          url.searchParams.delete(key)
        }
      })

      const response = await fetch(url.toString(), {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      this.updateTableContent(data)
      
    } catch (error) {
      console.error('Error updating table:', error)
      this.showError('Failed to update table. Please refresh the page.')
    } finally {
      this.hideLoading()
    }
  }

  // Update table content with new data
  updateTableContent(data) {
    if (this.hasTbodyTarget && data.campaigns) {
      // Update table body with new campaign rows
      const newContent = data.campaigns.map(campaign => 
        this.renderCampaignRow(campaign)
      ).join('')
      
      this.tbodyTarget.innerHTML = newContent
      
      // Update pagination if available
      this.updatePagination(data.pagination)
      
      // Dispatch event for other controllers
      this.dispatch('updated', { detail: data })
    }
  }

  // Render a single campaign row
  renderCampaignRow(campaign) {
    // This would typically be handled by a partial render
    // For now, return basic HTML structure
    return `
      <tr class="hover:bg-gray-50 transition-colors" data-campaign-id="${campaign.id}">
        <td class="w-12 px-6 py-4">
          <input type="checkbox" 
                 class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" 
                 data-action="change->bulk-actions#toggleSelect"
                 data-bulk-actions-target="checkbox"
                 data-campaign-id="${campaign.id}">
        </td>
        <td class="px-6 py-4">
          <div class="text-sm font-medium text-gray-900">${campaign.name}</div>
        </td>
        <td class="px-6 py-4">
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-${this.getStatusColor(campaign.status)}-100 text-${this.getStatusColor(campaign.status)}-800">
            ${campaign.status}
          </span>
        </td>
        <td class="px-6 py-4 text-sm text-gray-900">${campaign.type || 'N/A'}</td>
        <td class="px-6 py-4 text-sm text-gray-900">${campaign.persona}</td>
        <td class="px-6 py-4 text-sm text-gray-500">${campaign.created_at}</td>
        <td class="px-6 py-4">
          ${campaign.performance ? this.renderPerformance(campaign.performance) : 'No data'}
        </td>
        <td class="px-6 py-4 text-right">
          ${campaign.actions}
        </td>
      </tr>
    `
  }

  // Get status color class
  getStatusColor(status) {
    const colors = {
      'active': 'green',
      'draft': 'gray',
      'paused': 'yellow',
      'completed': 'blue',
      'archived': 'purple'
    }
    return colors[status] || 'gray'
  }

  // Render performance metrics
  renderPerformance(performance) {
    return `
      <div class="flex items-center">
        <div class="flex-1">
          <div class="flex items-center justify-between mb-1">
            <span class="text-xs text-gray-500">Completion</span>
            <span class="text-xs font-medium text-gray-900">${performance.completion_rate || 0}%</span>
          </div>
          <div class="w-full bg-gray-200 rounded-full h-1.5">
            <div class="bg-blue-600 h-1.5 rounded-full" style="width: ${Math.min(performance.completion_rate || 0, 100)}%"></div>
          </div>
        </div>
      </div>
    `
  }

  // Update pagination
  updatePagination(pagination) {
    // Update pagination controls if they exist
    const paginationElement = document.querySelector('.pagination')
    if (paginationElement && pagination) {
      // Update page numbers and navigation
      this.dispatch('pagination-updated', { detail: pagination })
    }
  }

  // Show error message
  showError(message) {
    // Create or update error display
    let errorElement = document.querySelector('.table-error-message')
    if (!errorElement) {
      errorElement = document.createElement('div')
      errorElement.className = 'table-error-message bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-4'
      this.element.insertBefore(errorElement, this.element.firstChild)
    }
    
    errorElement.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
        </svg>
        <span>${message}</span>
        <button type="button" class="ml-auto text-red-500 hover:text-red-700" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
          </svg>
        </button>
      </div>
    `
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
      if (errorElement.parentElement) {
        errorElement.remove()
      }
    }, 5000)
  }

  // Handle real-time search
  search(event) {
    const query = event.target.value
    
    // Debounce search requests
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    
    this.debounceTimer = setTimeout(() => {
      this.updateTable({ search: query })
    }, 300)
  }

  // Handle filter changes
  filter(event) {
    const filterType = event.target.name
    const filterValue = event.target.value
    
    this.updateTable({ [filterType]: filterValue })
  }
}