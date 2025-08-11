import { Controller } from "@hotwired/stimulus"

// Journey Templates Library Controller
export default class extends Controller {
  static targets = [
    "templatesGrid", "loadingState", "emptyState", "totalCount",
    "searchInput", "categoryFilter", "typeFilter", "sortFilter",
    "loadMoreContainer", "loadMoreButton",
    "previewModal", "previewTitle", "previewSubtitle", "previewContent", "applyTemplateButton",
    "applyModal", "applyForm", "campaignSelect", "journeyNameInput", "applyButton",
    "notificationArea"
  ]

  static values = {
    templatesUrl: String,
    categoriesUrl: String,
    searchUrl: String
  }

  connect() {
    this.currentPage = 1
    this.totalPages = 1
    this.currentTemplates = []
    this.selectedTemplate = null
    this.filters = {
      search: '',
      category: '',
      template_type: '',
      sort: 'recent'
    }
    this.searchTimeout = null
    
    this.loadTemplates()
    this.loadCampaigns()
    this.setupEventListeners()
  }

  // Load templates with current filters
  async loadTemplates(page = 1, append = false) {
    try {
      this.showLoading(!append)
      
      const params = new URLSearchParams({
        page: page,
        ...this.filters
      })

      const response = await fetch(`${this.templatesUrlValue}?${params}`)
      if (!response.ok) throw new Error('Failed to load templates')
      
      const data = await response.json()
      
      if (append) {
        this.currentTemplates = [...this.currentTemplates, ...data.templates]
      } else {
        this.currentTemplates = data.templates
      }
      
      this.currentPage = data.pagination.current_page
      this.totalPages = data.pagination.total_pages
      
      this.updateTotalCount(data.pagination.total_count)
      this.renderTemplates()
      this.updateLoadMoreButton()
      
    } catch (error) {
      console.error('Error loading templates:', error)
      this.showNotification('Failed to load templates. Please try again.', 'error')
      this.showEmpty()
    } finally {
      this.hideLoading()
    }
  }

  // Load available campaigns for template application
  async loadCampaigns() {
    try {
      const response = await fetch('/campaigns.json')
      if (!response.ok) return
      
      const campaigns = await response.json()
      this.populateCampaignSelect(campaigns)
    } catch (error) {
      console.warn('Could not load campaigns:', error)
    }
  }

  // Populate campaign select options
  populateCampaignSelect(campaigns) {
    const select = this.campaignSelectTarget
    select.innerHTML = '<option value="">Choose a campaign...</option>'
    
    campaigns.forEach(campaign => {
      const option = document.createElement('option')
      option.value = campaign.id
      option.textContent = campaign.name
      select.appendChild(option)
    })
  }

  // Setup additional event listeners
  setupEventListeners() {
    // ESC key to close modals
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        this.closePreviewModal()
        this.closeApplyModal()
      }
    })
  }

  // Handle search input with debouncing
  handleSearchInput(event) {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      this.filters.search = event.target.value.trim()
      this.currentPage = 1
      this.loadTemplates()
    }, 500)
  }

  // Handle filter changes
  handleFilterChange(event) {
    const filterType = event.target.dataset.journeyTemplatesTarget.replace('Filter', '')
    
    switch (filterType) {
      case 'category':
        this.filters.category = event.target.value
        break
      case 'type':
        this.filters.template_type = event.target.value
        break
      case 'sort':
        this.filters.sort = event.target.value
        break
    }
    
    this.currentPage = 1
    this.loadTemplates()
  }

  // Load more templates (pagination)
  loadMore() {
    if (this.currentPage < this.totalPages) {
      this.loadTemplates(this.currentPage + 1, true)
    }
  }

  // Preview template
  async previewTemplate(event) {
    const templateId = event.currentTarget.dataset.templateId
    
    try {
      const response = await fetch(`/journey_templates/${templateId}/preview`)
      if (!response.ok) throw new Error('Failed to load template preview')
      
      const data = await response.json()
      this.selectedTemplate = data.template
      
      this.populatePreviewModal(data)
      this.showPreviewModal()
      
    } catch (error) {
      console.error('Error loading template preview:', error)
      this.showNotification('Failed to load template preview.', 'error')
    }
  }

  // Populate preview modal with template data
  populatePreviewModal(data) {
    const { template, stages, variables, metadata } = data
    
    this.previewTitleTarget.textContent = template.name
    this.previewSubtitleTarget.textContent = `${template.category_humanized} • ${template.template_type_humanized} • ${template.stage_count} stages`
    
    // Generate preview content HTML
    const contentHTML = `
      <div class="p-6 space-y-6">
        <!-- Template Overview -->
        <div>
          <h3 class="text-lg font-medium text-gray-900 mb-3">Overview</h3>
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span class="font-medium text-gray-700">Type:</span>
              <span class="ml-2 text-gray-600">${template.template_type_humanized}</span>
            </div>
            <div>
              <span class="font-medium text-gray-700">Category:</span>
              <span class="ml-2 text-gray-600">${template.category_humanized}</span>
            </div>
            <div>
              <span class="font-medium text-gray-700">Stages:</span>
              <span class="ml-2 text-gray-600">${template.stage_count} stages</span>
            </div>
            <div>
              <span class="font-medium text-gray-700">Duration:</span>
              <span class="ml-2 text-gray-600">${template.estimated_duration_days} days</span>
            </div>
            <div>
              <span class="font-medium text-gray-700">Usage Count:</span>
              <span class="ml-2 text-gray-600">${template.usage_count} times</span>
            </div>
            <div>
              <span class="font-medium text-gray-700">Version:</span>
              <span class="ml-2 text-gray-600">v${template.version}</span>
            </div>
          </div>
          ${template.description ? `
            <div class="mt-4">
              <span class="font-medium text-gray-700">Description:</span>
              <p class="mt-1 text-gray-600">${template.description}</p>
            </div>
          ` : ''}
          ${template.tags && template.tags.length > 0 ? `
            <div class="mt-4">
              <span class="font-medium text-gray-700">Tags:</span>
              <div class="mt-2 flex flex-wrap gap-2">
                ${template.tags.map(tag => `
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    ${tag}
                  </span>
                `).join('')}
              </div>
            </div>
          ` : ''}
        </div>

        <!-- Journey Stages -->
        <div>
          <h3 class="text-lg font-medium text-gray-900 mb-3">Journey Stages</h3>
          <div class="space-y-3">
            ${stages.map((stage, index) => `
              <div class="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg">
                <div class="flex items-center justify-center w-8 h-8 bg-blue-100 rounded-full text-blue-600 font-medium text-sm">
                  ${index + 1}
                </div>
                <div class="flex-1">
                  <div class="flex items-center justify-between">
                    <h4 class="font-medium text-gray-900">${stage.name}</h4>
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-${this.getStageColor(stage.stage_type)}-100 text-${this.getStageColor(stage.stage_type)}-800">
                      ${stage.stage_type}
                    </span>
                  </div>
                  ${stage.description ? `
                    <p class="mt-1 text-sm text-gray-600">${stage.description}</p>
                  ` : ''}
                  <div class="mt-2 flex items-center space-x-4 text-xs text-gray-500">
                    <span>Duration: ${stage.duration_days} days</span>
                    ${stage.configuration && stage.configuration.channels ? `
                      <span>Channels: ${stage.configuration.channels.join(', ')}</span>
                    ` : ''}
                  </div>
                </div>
              </div>
            `).join('')}
          </div>
        </div>

        ${variables && variables.length > 0 ? `
          <!-- Variables -->
          <div>
            <h3 class="text-lg font-medium text-gray-900 mb-3">Template Variables</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              ${variables.map(variable => `
                <div class="p-3 bg-gray-50 rounded-lg">
                  <div class="flex items-center justify-between">
                    <span class="font-medium text-gray-900">${variable.name}</span>
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${variable.required ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'}">
                      ${variable.required ? 'Required' : 'Optional'}
                    </span>
                  </div>
                  <p class="mt-1 text-sm text-gray-600">${variable.description || 'No description'}</p>
                  <p class="mt-1 text-xs text-gray-500">Type: ${variable.type}</p>
                  ${variable.default_value ? `
                    <p class="mt-1 text-xs text-gray-500">Default: ${variable.default_value}</p>
                  ` : ''}
                </div>
              `).join('')}
            </div>
          </div>
        ` : ''}
      </div>
    `
    
    this.previewContentTarget.innerHTML = contentHTML
  }

  // Show preview modal
  showPreviewModal() {
    this.previewModalTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }

  // Close preview modal
  closePreviewModal() {
    this.previewModalTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
    this.selectedTemplate = null
  }

  // Show apply modal
  showApplyModal() {
    if (!this.selectedTemplate) return
    
    // Pre-fill journey name
    this.journeyNameInputTarget.value = `${this.selectedTemplate.name} Journey`
    
    this.closePreviewModal()
    this.applyModalTarget.classList.remove('hidden')
  }

  // Close apply modal
  closeApplyModal() {
    this.applyModalTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }

  // Apply template to campaign
  async applyTemplate(event) {
    event.preventDefault()
    
    if (!this.selectedTemplate) return
    
    const formData = new FormData(this.applyFormTarget)
    const campaignId = formData.get('campaign_id')
    const journeyName = formData.get('name')
    
    if (!campaignId) {
      this.showNotification('Please select a campaign.', 'error')
      return
    }
    
    try {
      this.applyButtonTarget.disabled = true
      this.applyButtonTarget.textContent = 'Applying...'
      
      const response = await fetch(`/journey_templates/${this.selectedTemplate.id}/apply_to_campaign`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          campaign_id: campaignId,
          name: journeyName || `${this.selectedTemplate.name} Journey`
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.showNotification(data.message, 'success')
        this.closeApplyModal()
        
        // Optionally redirect to the campaign or journey builder
        setTimeout(() => {
          window.location.href = `/campaigns/${campaignId}/customer_journey/builder`
        }, 2000)
      } else {
        throw new Error(data.message || 'Failed to apply template')
      }
      
    } catch (error) {
      console.error('Error applying template:', error)
      this.showNotification(error.message || 'Failed to apply template to campaign.', 'error')
    } finally {
      this.applyButtonTarget.disabled = false
      this.applyButtonTarget.textContent = 'Apply Template'
    }
  }

  // Render templates in grid
  renderTemplates() {
    if (this.currentTemplates.length === 0) {
      this.showEmpty()
      return
    }

    const gridHTML = this.currentTemplates.map(template => this.renderTemplateCard(template)).join('')
    this.templatesGridTarget.innerHTML = gridHTML
    this.templatesGridTarget.style.display = 'grid'
    this.hideEmpty()
  }

  // Render individual template card
  renderTemplateCard(template) {
    return `
      <div class="template-card bg-white rounded-lg shadow-sm border border-gray-200 hover:shadow-md hover:border-blue-300 transition-all cursor-pointer"
           data-template-id="${template.id}"
           data-action="click->journey-templates#previewTemplate">
        
        <!-- Card Header -->
        <div class="p-4 border-b border-gray-100">
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <h3 class="font-semibold text-gray-900 text-sm truncate" title="${template.name}">
                ${template.name}
              </h3>
              <p class="text-xs text-gray-500 mt-1">
                ${template.category_humanized} • ${template.template_type_humanized}
              </p>
            </div>
            <span class="flex-shrink-0 inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
              v${template.version}
            </span>
          </div>
        </div>

        <!-- Card Body -->
        <div class="p-4">
          ${template.description ? `
            <p class="text-sm text-gray-600 mb-3 line-clamp-2">${template.description}</p>
          ` : ''}
          
          <!-- Template Stats -->
          <div class="grid grid-cols-2 gap-3 text-xs text-gray-500 mb-3">
            <div class="flex items-center space-x-1">
              <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z"/>
              </svg>
              <span>${template.stage_count} stages</span>
            </div>
            <div class="flex items-center space-x-1">
              <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clip-rule="evenodd"/>
              </svg>
              <span>${template.estimated_duration_days} days</span>
            </div>
          </div>

          <!-- Usage Stats -->
          <div class="flex items-center justify-between text-xs text-gray-500">
            <span>${template.usage_count} times used</span>
            ${template.adoption_rate > 0 ? `
              <span>${template.adoption_rate}% adoption</span>
            ` : ''}
          </div>

          <!-- Tags -->
          ${template.tags && template.tags.length > 0 ? `
            <div class="mt-3 flex flex-wrap gap-1">
              ${template.tags.slice(0, 3).map(tag => `
                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-700">
                  ${tag}
                </span>
              `).join('')}
              ${template.tags.length > 3 ? `
                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-500">
                  +${template.tags.length - 3}
                </span>
              ` : ''}
            </div>
          ` : ''}
        </div>

        <!-- Card Footer -->
        <div class="px-4 py-3 bg-gray-50 border-t border-gray-100">
          <div class="flex items-center justify-between">
            <div class="text-xs text-gray-500">
              By ${template.author || 'System'}
            </div>
            <div class="flex items-center space-x-1 text-xs text-blue-600">
              <span>Preview</span>
              <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
              </svg>
            </div>
          </div>
        </div>
      </div>
    `
  }

  // Utility methods
  getStageColor(stageType) {
    const colors = {
      'Awareness': 'blue',
      'Consideration': 'yellow',
      'Conversion': 'green',
      'Retention': 'purple',
      'Advocacy': 'indigo'
    }
    return colors[stageType] || 'gray'
  }

  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
  }

  // UI State Management
  showLoading(replace = true) {
    if (replace) {
      this.loadingStateTarget.style.display = 'block'
      this.templatesGridTarget.style.display = 'none'
      this.emptyStateTarget.classList.add('hidden')
    }
    this.loadMoreButtonTarget.disabled = true
  }

  hideLoading() {
    this.loadingStateTarget.style.display = 'none'
    this.loadMoreButtonTarget.disabled = false
  }

  showEmpty() {
    this.templatesGridTarget.style.display = 'none'
    this.emptyStateTarget.classList.remove('hidden')
    this.loadMoreContainer?.classList.add('hidden')
  }

  hideEmpty() {
    this.emptyStateTarget.classList.add('hidden')
  }

  updateTotalCount(count) {
    this.totalCountTarget.textContent = count.toLocaleString()
  }

  updateLoadMoreButton() {
    if (this.hasLoadMoreContainerTarget) {
      if (this.currentPage < this.totalPages) {
        this.loadMoreContainerTarget.classList.remove('hidden')
      } else {
        this.loadMoreContainerTarget.classList.add('hidden')
      }
    }
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `notification p-4 rounded-lg shadow-lg text-sm font-medium transition-all transform translate-x-full opacity-0 ${
      type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' : 
      type === 'error' ? 'bg-red-100 text-red-800 border border-red-200' : 
      'bg-blue-100 text-blue-800 border border-blue-200'
    }`
    notification.textContent = message
    
    this.notificationAreaTarget.appendChild(notification)
    
    // Animate in
    requestAnimationFrame(() => {
      notification.classList.remove('translate-x-full', 'opacity-0')
    })
    
    // Remove after delay
    setTimeout(() => {
      notification.classList.add('translate-x-full', 'opacity-0')
      setTimeout(() => notification.remove(), 300)
    }, 4000)
  }
}