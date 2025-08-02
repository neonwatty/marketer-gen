import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["plansContainer", "planCard"]

  connect() {
    console.log("Campaign plans list controller connected")
    this.currentTab = "all"
    this.initializeList()
  }

  initializeList() {
    // Set up any initial list functionality
    this.updateTabCounts()
  }

  showTab(event) {
    const newTab = event.target.dataset.tab
    
    // Update active tab styling
    this.updateActiveTab(event.target)
    
    // Filter plan cards based on selected tab
    this.filterPlansByStatus(newTab)
    
    this.currentTab = newTab
  }

  updateActiveTab(activeButton) {
    // Remove active styling from all tabs
    const tabs = document.querySelectorAll('.plan-status-tab')
    tabs.forEach(tab => {
      tab.classList.remove('active', 'border-blue-500', 'text-blue-600')
      tab.classList.add('text-gray-500', 'hover:text-gray-700', 'border-transparent', 'hover:border-gray-300')
    })
    
    // Add active styling to clicked tab
    activeButton.classList.remove('text-gray-500', 'hover:text-gray-700', 'border-transparent', 'hover:border-gray-300')
    activeButton.classList.add('active', 'border-blue-500', 'text-blue-600')
  }

  filterPlansByStatus(status) {
    const planCards = this.planCardTargets
    
    planCards.forEach(card => {
      const planStatus = card.dataset.planStatus
      let shouldShow = false
      
      switch(status) {
        case 'all':
          shouldShow = true
          break
        case 'draft':
          shouldShow = planStatus === 'draft'
          break
        case 'review':
          shouldShow = planStatus === 'in_review'
          break
        case 'approved':
          shouldShow = planStatus === 'approved'
          break
        default:
          shouldShow = true
      }
      
      if (shouldShow) {
        card.style.display = 'block'
        this.animateCardIn(card)
      } else {
        this.animateCardOut(card)
      }
    })
    
    // Update empty state if needed
    this.updateEmptyState(status)
  }

  animateCardIn(card) {
    card.style.opacity = '0'
    card.style.transform = 'translateY(10px)'
    card.style.display = 'block'
    
    // Force reflow
    card.offsetHeight
    
    card.style.transition = 'opacity 0.3s ease, transform 0.3s ease'
    card.style.opacity = '1'
    card.style.transform = 'translateY(0)'
  }

  animateCardOut(card) {
    card.style.transition = 'opacity 0.3s ease, transform 0.3s ease'
    card.style.opacity = '0'
    card.style.transform = 'translateY(-10px)'
    
    setTimeout(() => {
      card.style.display = 'none'
    }, 300)
  }

  updateEmptyState(status) {
    const visibleCards = this.planCardTargets.filter(card => 
      card.style.display !== 'none'
    )
    
    const existingEmptyState = this.plansContainerTarget.querySelector('.empty-state-filtered')
    
    if (visibleCards.length === 0 && status !== 'all') {
      if (!existingEmptyState) {
        this.showFilteredEmptyState(status)
      }
    } else if (existingEmptyState) {
      existingEmptyState.remove()
    }
  }

  showFilteredEmptyState(status) {
    const statusLabels = {
      draft: 'draft plans',
      review: 'plans in review',
      approved: 'approved plans'
    }
    
    const emptyStateHtml = `
      <div class="empty-state-filtered col-span-full text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No ${statusLabels[status]}</h3>
        <p class="mt-1 text-sm text-gray-500">Try switching to a different tab to see other plans.</p>
      </div>
    `
    
    this.plansContainerTarget.insertAdjacentHTML('beforeend', emptyStateHtml)
  }

  updateTabCounts() {
    // Count plans by status
    const statusCounts = {
      all: this.planCardTargets.length,
      draft: this.planCardTargets.filter(card => card.dataset.planStatus === 'draft').length,
      review: this.planCardTargets.filter(card => card.dataset.planStatus === 'in_review').length,
      approved: this.planCardTargets.filter(card => card.dataset.planStatus === 'approved').length
    }
    
    // Update tab count badges
    Object.keys(statusCounts).forEach(status => {
      const tab = document.querySelector(`[data-tab="${status}"]`)
      const badge = tab?.querySelector('span')
      if (badge) {
        badge.textContent = statusCounts[status]
        // Hide badge if count is 0
        badge.style.display = statusCounts[status] > 0 ? 'inline-block' : 'none'
      }
    })
  }

  showFilters() {
    // Show mobile filter modal
    const filterModal = this.createFilterModal()
    document.body.appendChild(filterModal)
  }

  createFilterModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50 lg:hidden'
    modal.innerHTML = `
      <div class="relative top-20 mx-auto p-5 border w-11/12 max-w-md shadow-lg rounded-md bg-white">
        <div class="mt-3">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium text-gray-900">Filter Plans</h3>
            <button type="button" 
                    class="text-gray-400 hover:text-gray-600 transition-colors"
                    onclick="this.closest('.fixed').remove()">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          
          <div class="space-y-3">
            <button type="button" 
                    class="w-full text-left px-4 py-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors ${this.currentTab === 'all' ? 'bg-blue-50 border-blue-200' : ''}"
                    onclick="this.filterTab('all'); this.closest('.fixed').remove()">
              <div class="flex justify-between items-center">
                <span class="font-medium text-gray-900">All Plans</span>
                <span class="text-sm text-gray-500">${this.planCardTargets.length}</span>
              </div>
            </button>
            
            <button type="button" 
                    class="w-full text-left px-4 py-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors ${this.currentTab === 'draft' ? 'bg-blue-50 border-blue-200' : ''}"
                    onclick="this.filterTab('draft'); this.closest('.fixed').remove()">
              <div class="flex justify-between items-center">
                <span class="font-medium text-gray-900">Draft</span>
                <span class="text-sm text-gray-500">${this.planCardTargets.filter(card => card.dataset.planStatus === 'draft').length}</span>
              </div>
            </button>
            
            <button type="button" 
                    class="w-full text-left px-4 py-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors ${this.currentTab === 'review' ? 'bg-blue-50 border-blue-200' : ''}"
                    onclick="this.filterTab('review'); this.closest('.fixed').remove()">
              <div class="flex justify-between items-center">
                <span class="font-medium text-gray-900">In Review</span>
                <span class="text-sm text-gray-500">${this.planCardTargets.filter(card => card.dataset.planStatus === 'in_review').length}</span>
              </div>
            </button>
            
            <button type="button" 
                    class="w-full text-left px-4 py-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors ${this.currentTab === 'approved' ? 'bg-blue-50 border-blue-200' : ''}"
                    onclick="this.filterTab('approved'); this.closest('.fixed').remove()">
              <div class="flex justify-between items-center">
                <span class="font-medium text-gray-900">Approved</span>
                <span class="text-sm text-gray-500">${this.planCardTargets.filter(card => card.dataset.planStatus === 'approved').length}</span>
              </div>
            </button>
          </div>
        </div>
      </div>
    `
    
    // Bind filter methods to modal buttons
    const controller = this
    modal.querySelectorAll('button[onclick*="filterTab"]').forEach(button => {
      button.onclick = function() {
        const tab = this.getAttribute('onclick').match(/'([^']+)'/)[1]
        controller.filterPlansByStatus(tab)
        controller.updateActiveTabForModal(tab)
        modal.remove()
      }
    })
    
    return modal
  }

  updateActiveTabForModal(status) {
    // Update the desktop tabs to match mobile selection
    const desktopTab = document.querySelector(`[data-tab="${status}"]`)
    if (desktopTab) {
      this.updateActiveTab(desktopTab)
      this.currentTab = status
    }
  }

  searchPlans(query) {
    // Search functionality for plan names and descriptions
    const searchQuery = query.toLowerCase().trim()
    
    this.planCardTargets.forEach(card => {
      const planName = card.querySelector('h3').textContent.toLowerCase()
      const matches = planName.includes(searchQuery)
      
      if (matches || searchQuery === '') {
        card.style.display = 'block'
      } else {
        card.style.display = 'none'
      }
    })
  }

  sortPlans(sortBy) {
    // Sort plans by different criteria
    const container = this.plansContainerTarget
    const cards = Array.from(this.planCardTargets)
    
    cards.sort((a, b) => {
      switch(sortBy) {
        case 'name':
          const nameA = a.querySelector('h3').textContent.toLowerCase()
          const nameB = b.querySelector('h3').textContent.toLowerCase()
          return nameA.localeCompare(nameB)
          
        case 'status':
          const statusA = a.dataset.planStatus
          const statusB = b.dataset.planStatus
          return statusA.localeCompare(statusB)
          
        case 'completion':
          const completionA = parseInt(a.querySelector('.text-2xl').textContent)
          const completionB = parseInt(b.querySelector('.text-2xl').textContent)
          return completionB - completionA // Descending order
          
        case 'updated':
        default:
          // Default to updated time (newest first)
          // This would require timestamps in data attributes in a real implementation
          return 0
      }
    })
    
    // Reorder DOM elements
    cards.forEach(card => {
      container.appendChild(card)
    })
  }

  refreshPlans() {
    // Refresh the plans list (useful for real-time updates)
    const currentUrl = window.location.href
    
    fetch(currentUrl, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      // Parse the response and update the plans container
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      const newPlansContainer = doc.querySelector('[data-campaign-plans-list-target="plansContainer"]')
      
      if (newPlansContainer) {
        this.plansContainerTarget.innerHTML = newPlansContainer.innerHTML
        this.updateTabCounts()
        this.filterPlansByStatus(this.currentTab)
      }
    })
    .catch(error => {
      console.error('Error refreshing plans:', error)
    })
  }

  // Keyboard shortcuts
  handleKeydown(event) {
    switch(event.key) {
      case 'n':
        if (event.ctrlKey || event.metaKey) {
          event.preventDefault()
          // Navigate to new plan creation
          const newPlanLink = document.querySelector('[href*="new"]')
          if (newPlanLink) {
            newPlanLink.click()
          }
        }
        break
        
      case 'r':
        if (event.ctrlKey || event.metaKey) {
          event.preventDefault()
          this.refreshPlans()
        }
        break
        
      case '1':
      case '2':
      case '3':
      case '4':
        if (event.ctrlKey || event.metaKey) {
          event.preventDefault()
          const tabs = ['all', 'draft', 'review', 'approved']
          const tabIndex = parseInt(event.key) - 1
          if (tabs[tabIndex]) {
            this.filterPlansByStatus(tabs[tabIndex])
            const tabButton = document.querySelector(`[data-tab="${tabs[tabIndex]}"]`)
            if (tabButton) {
              this.updateActiveTab(tabButton)
            }
          }
        }
        break
    }
  }

  connect() {
    super.connect()
    
    // Bind keyboard shortcuts
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener('keydown', this.handleKeydown.bind(this))
  }
}