import { Controller } from "@hotwired/stimulus"

// Global search controller with intelligent suggestions and keyboard navigation
export default class extends Controller {
  static targets = ["input", "results", "resultsList", "loading", "noResults"]
  static values = { 
    debounce: { type: Number, default: 300 },
    minLength: { type: Number, default: 2 },
    maxResults: { type: Number, default: 8 }
  }

  connect() {
    console.log("Global search controller connected")
    this.setupKeyboardShortcuts()
    this.selectedIndex = -1
    this.currentQuery = ""
    this.searchResults = []
  }

  disconnect() {
    this.cleanupKeyboardShortcuts()
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  setupKeyboardShortcuts() {
    // Global keyboard shortcut (Cmd/Ctrl + K)
    this.handleGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener('keydown', this.handleGlobalKeydown)
  }

  cleanupKeyboardShortcuts() {
    document.removeEventListener('keydown', this.handleGlobalKeydown)
  }

  handleGlobalKeydown(event) {
    // Check for Cmd+K or Ctrl+K
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault()
      this.focusSearch()
    }
    
    // Escape to close search
    if (event.key === 'Escape' && this.inputTarget === document.activeElement) {
      this.hideResults()
      this.inputTarget.blur()
    }
  }

  focusSearch() {
    this.inputTarget.focus()
    this.inputTarget.select()
    this.showResults()
  }

  search(event) {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    const query = event.target.value.trim()
    this.currentQuery = query

    if (query.length < this.minLengthValue) {
      this.hideResults()
      return
    }

    // Show loading state
    this.showLoading()

    // Debounce the search
    this.debounceTimer = setTimeout(() => {
      this.performSearch(query)
    }, this.debounceValue)
  }

  async performSearch(query) {
    try {
      // In a real application, this would be an API call
      const results = await this.mockSearchAPI(query)
      
      if (query === this.currentQuery) { // Only update if query hasn't changed
        this.searchResults = results
        this.displayResults(results)
        this.hideLoading()
        this.selectedIndex = -1
      }
    } catch (error) {
      console.error('Search error:', error)
      this.hideLoading()
      this.showNoResults()
    }
  }

  async mockSearchAPI(query) {
    // Mock API delay
    await new Promise(resolve => setTimeout(resolve, 200))

    const mockData = [
      // Campaigns
      { type: 'campaign', title: 'Summer Sale 2024', description: 'Email campaign with 25% discount', url: '/campaigns/1', icon: 'campaign' },
      { type: 'campaign', title: 'Holiday Promotion', description: 'Multi-channel holiday campaign', url: '/campaigns/2', icon: 'campaign' },
      { type: 'campaign', title: 'Product Launch', description: 'New product announcement campaign', url: '/campaigns/3', icon: 'campaign' },
      
      // Content
      { type: 'content', title: 'Email Template: Welcome Series', description: 'Onboarding email template', url: '/content/templates/1', icon: 'content' },
      { type: 'content', title: 'Social Media Graphics', description: 'Brand assets for social platforms', url: '/content/assets/1', icon: 'content' },
      { type: 'content', title: 'Landing Page Copy', description: 'Conversion-optimized page content', url: '/content/copy/1', icon: 'content' },
      
      // Analytics
      { type: 'analytics', title: 'Monthly Performance Report', description: 'Campaign performance overview', url: '/analytics/reports/1', icon: 'analytics' },
      { type: 'analytics', title: 'Conversion Funnel Analysis', description: 'User journey breakdown', url: '/analytics/funnels/1', icon: 'analytics' },
      
      // Users
      { type: 'user', title: 'John Smith', description: 'Marketing Manager', url: '/users/1', icon: 'user' },
      { type: 'user', title: 'Sarah Wilson', description: 'Content Creator', url: '/users/2', icon: 'user' },
      
      // Brand
      { type: 'brand', title: 'TechStart Inc Guidelines', description: 'Brand style guide and assets', url: '/brands/1', icon: 'brand' },
      { type: 'brand', title: 'Logo Variations', description: 'Brand logo in different formats', url: '/brands/assets/1', icon: 'brand' }
    ]

    // Filter results based on query
    const filtered = mockData.filter(item => 
      item.title.toLowerCase().includes(query.toLowerCase()) ||
      item.description.toLowerCase().includes(query.toLowerCase())
    )

    return filtered.slice(0, this.maxResultsValue)
  }

  displayResults(results) {
    if (results.length === 0) {
      this.showNoResults()
      return
    }

    const html = results.map((result, index) => {
      const iconSvg = this.getIconSvg(result.icon)
      const typeColor = this.getTypeColor(result.type)
      
      return `
        <div class="search-result-item flex items-center px-4 py-3 hover:bg-gray-50 cursor-pointer transition-colors ${index === this.selectedIndex ? 'bg-blue-50' : ''}"
             data-search-index="${index}"
             data-search-url="${result.url}"
             data-action="click->global-search#selectResult">
          <div class="flex-shrink-0 mr-3">
            <div class="w-8 h-8 ${typeColor} rounded-lg flex items-center justify-center">
              ${iconSvg}
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 truncate">${this.highlightQuery(result.title, this.currentQuery)}</p>
            <p class="text-sm text-gray-500 truncate">${this.highlightQuery(result.description, this.currentQuery)}</p>
          </div>
          <div class="flex-shrink-0 ml-2">
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
              ${result.type}
            </span>
          </div>
        </div>
      `
    }).join('')

    this.resultsListTarget.innerHTML = html
    this.showResults()
  }

  getIconSvg(iconType) {
    const icons = {
      campaign: '<svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path></svg>',
      content: '<svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14-7v12a2 2 0 01-2 2H7a2 2 0 01-2-2V4a2 2 0 012-2h10a2 2 0 012 2zM9 11h6"></path></svg>',
      analytics: '<svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"></path></svg>',
      user: '<svg class="w-4 h-4 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg>',
      brand: '<svg class="w-4 h-4 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v14a4 4 0 01-4 4zM21 5a2 2 0 00-2-2h-4a2 2 0 00-2 2v14a4 4 0 004-4V5z"></path></svg>'
    }
    return icons[iconType] || icons.campaign
  }

  getTypeColor(type) {
    const colors = {
      campaign: 'bg-blue-100',
      content: 'bg-green-100',
      analytics: 'bg-purple-100',
      user: 'bg-indigo-100',
      brand: 'bg-orange-100'
    }
    return colors[type] || 'bg-gray-100'
  }

  highlightQuery(text, query) {
    if (!query) {return text}
    
    const regex = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi')
    return text.replace(regex, '<mark class="bg-yellow-200 px-1 rounded">$1</mark>')
  }

  handleKeydown(event) {
    const results = this.resultsListTarget.querySelectorAll('[data-search-index]')
    
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, results.length - 1)
        this.updateSelection()
        break
        
      case 'ArrowUp':
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
        this.updateSelection()
        break
        
      case 'Enter':
        event.preventDefault()
        if (this.selectedIndex >= 0 && results[this.selectedIndex]) {
          const url = results[this.selectedIndex].dataset.searchUrl
          this.navigateTo(url)
        }
        break
        
      case 'Escape':
        this.hideResults()
        this.inputTarget.blur()
        break
    }
  }

  updateSelection() {
    const results = this.resultsListTarget.querySelectorAll('[data-search-index]')
    
    results.forEach((result, index) => {
      if (index === this.selectedIndex) {
        result.classList.add('bg-blue-50')
        result.scrollIntoView({ block: 'nearest' })
      } else {
        result.classList.remove('bg-blue-50')
      }
    })
  }

  selectResult(event) {
    const url = event.currentTarget.dataset.searchUrl
    this.navigateTo(url)
  }

  navigateTo(url) {
    this.hideResults()
    this.inputTarget.value = ""
    this.dispatch('navigate', { detail: { url } })
    
    // Navigate using Turbo if available, otherwise use window.location
    if (window.Turbo) {
      window.Turbo.visit(url)
    } else {
      window.location.href = url
    }
  }

  showResults() {
    this.resultsTarget.classList.remove('hidden')
    this.inputTarget.setAttribute('aria-expanded', 'true')
  }

  hideResults() {
    this.resultsTarget.classList.add('hidden')
    this.inputTarget.setAttribute('aria-expanded', 'false')
    this.selectedIndex = -1
  }

  showLoading() {
    this.loadingTarget.classList.remove('hidden')
    this.resultsListTarget.classList.add('hidden')
    this.noResultsTarget.classList.add('hidden')
    this.showResults()
  }

  hideLoading() {
    this.loadingTarget.classList.add('hidden')
    this.resultsListTarget.classList.remove('hidden')
  }

  showNoResults() {
    this.noResultsTarget.classList.remove('hidden')
    this.resultsListTarget.classList.add('hidden')
    this.loadingTarget.classList.add('hidden')
    this.showResults()
  }

  // Focus and blur handlers
  showResults(event) {
    if (this.currentQuery.length >= this.minLengthValue) {
      this.resultsTarget.classList.remove('hidden')
      this.inputTarget.setAttribute('aria-expanded', 'true')
    }
  }

  hideResults(event) {
    // Delay hiding to allow for click events on results
    setTimeout(() => {
      this.resultsTarget.classList.add('hidden')
      this.inputTarget.setAttribute('aria-expanded', 'false')
    }, 150)
  }
}