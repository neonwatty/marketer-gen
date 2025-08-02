import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "gallery", "templateSection", "detailsSection", 
    "selectedTemplateId", "previewModal", "previewTitle", 
    "previewContent", "templatePreview", "templatePreviewContent"
  ]

  connect() {
    console.log("Template selector controller connected")
    this.selectedTemplate = null
    this.initializeFilters()
  }

  initializeFilters() {
    // Set up template filtering
    this.originalTemplates = Array.from(this.galleryTarget.querySelectorAll('.template-card'))
  }

  selectTemplate(event) {
    const templateCard = event.currentTarget
    const templateId = templateCard.dataset.templateId
    
    // Clear previous selections
    this.clearSelections()
    
    // Mark as selected
    templateCard.classList.add('ring-2', 'ring-blue-500', 'bg-blue-50')
    
    this.selectedTemplate = {
      id: templateId,
      name: templateCard.querySelector('h3').textContent,
      description: templateCard.querySelector('p').textContent,
      industry: templateCard.dataset.industry,
      type: templateCard.dataset.type
    }
    
    // Update hidden form field
    this.selectedTemplateIdTarget.value = templateId
    
    // Show template preview
    this.showTemplatePreview()
    
    // Move to next step
    setTimeout(() => {
      this.proceedToDetails()
    }, 500)
  }

  clearSelections() {
    const cards = this.galleryTarget.querySelectorAll('.template-card')
    cards.forEach(card => {
      card.classList.remove('ring-2', 'ring-blue-500', 'bg-blue-50')
    })
  }

  showTemplatePreview() {
    if (!this.selectedTemplate) {return}
    
    const previewHtml = `
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-blue-800">Template Selected: ${this.selectedTemplate.name}</h3>
            <div class="mt-2 text-sm text-blue-700">
              <p>${this.selectedTemplate.description}</p>
              <div class="mt-2 flex gap-2">
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                  ${this.selectedTemplate.industry}
                </span>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                  ${this.selectedTemplate.type}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
    
    this.templatePreviewContentTarget.innerHTML = previewHtml
    this.templatePreviewTarget.style.display = 'block'
  }

  proceedToDetails() {
    // Hide template section and show details form
    this.templateSectionTarget.style.display = 'none'
    this.detailsSectionTarget.style.display = 'block'
    
    // Update step indicator
    this.updateStepIndicator(2)
    
    // Pre-fill form if template is selected
    if (this.selectedTemplate && this.selectedTemplate.id) {
      this.prefillFormFromTemplate()
    }
  }

  goBack() {
    // Show template section and hide details form
    this.templateSectionTarget.style.display = 'block'
    this.detailsSectionTarget.style.display = 'none'
    
    // Update step indicator
    this.updateStepIndicator(1)
  }

  updateStepIndicator(activeStep) {
    const steps = document.querySelectorAll('[role="list"] li')
    
    steps.forEach((step, index) => {
      const stepNumber = index + 1
      const link = step.querySelector('a')
      const span = step.querySelector('span')
      
      if (stepNumber < activeStep) {
        // Completed step
        link.classList.remove('bg-white', 'border-gray-300')
        link.classList.add('bg-blue-600')
        span.classList.remove('text-gray-500')
        span.classList.add('text-white')
      } else if (stepNumber === activeStep) {
        // Current step
        link.classList.remove('bg-white', 'border-gray-300')
        link.classList.add('bg-blue-600')
        span.classList.remove('text-gray-500')
        span.classList.add('text-white')
        link.setAttribute('aria-current', 'step')
      } else {
        // Future step
        link.classList.remove('bg-blue-600')
        link.classList.add('bg-white', 'border-gray-300')
        span.classList.remove('text-white')
        span.classList.add('text-gray-500')
        link.removeAttribute('aria-current')
      }
    })
  }

  prefillFormFromTemplate() {
    if (!this.selectedTemplate.id) {return}
    
    // Fetch template data and prefill form
    fetch(`/plan_templates/${this.selectedTemplate.id}/preview`)
      .then(response => response.json())
      .then(data => {
        if (data.template_data) {
          this.applyTemplateDataToForm(data.template_data)
        }
      })
      .catch(error => {
        console.error('Error fetching template data:', error)
      })
  }

  applyTemplateDataToForm(templateData) {
    // Pre-fill form fields based on template data
    const nameField = document.querySelector('input[name="campaign_plan[name]"]')
    if (nameField && !nameField.value) {
      nameField.value = `${this.selectedTemplate.name} Plan`
    }
    
    // Show template insights
    this.showTemplateInsights(templateData)
  }

  showTemplateInsights(templateData) {
    const insights = this.generateTemplateInsights(templateData)
    const insightsHtml = `
      <div class="mt-4 bg-gray-50 border border-gray-200 rounded-lg p-4">
        <h4 class="text-sm font-medium text-gray-900 mb-2">Template Insights</h4>
        <ul class="text-sm text-gray-600 space-y-1">
          ${insights.map(insight => `<li>• ${insight}</li>`).join('')}
        </ul>
      </div>
    `
    
    const existingInsights = this.detailsSectionTarget.querySelector('.template-insights')
    if (existingInsights) {
      existingInsights.remove()
    }
    
    const insightsDiv = document.createElement('div')
    insightsDiv.className = 'template-insights'
    insightsDiv.innerHTML = insightsHtml
    
    this.templatePreviewTarget.appendChild(insightsDiv)
  }

  generateTemplateInsights(templateData) {
    const insights = []
    
    if (templateData.channel_strategy) {
      insights.push(`Includes ${templateData.channel_strategy.length} marketing channels`)
    }
    
    if (templateData.timeline_phases) {
      const totalWeeks = templateData.timeline_phases.reduce((sum, phase) => 
        sum + (phase.duration_weeks || 0), 0)
      insights.push(`Campaign timeline: ${totalWeeks} weeks across ${templateData.timeline_phases.length} phases`)
    }
    
    if (templateData.messaging_framework) {
      insights.push('Pre-built messaging framework included')
    }
    
    if (templateData.success_metrics) {
      const metricsCount = Object.keys(templateData.success_metrics).length
      insights.push(`${metricsCount} success metrics templates defined`)
    }
    
    return insights
  }

  previewTemplate(event) {
    event.stopPropagation() // Prevent template selection
    
    const templateId = event.target.dataset.templateId
    this.loadTemplatePreview(templateId)
  }

  loadTemplatePreview(templateId) {
    // Show loading state
    this.previewContentTarget.innerHTML = `
      <div class="flex justify-center items-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span class="ml-2 text-gray-600">Loading preview...</span>
      </div>
    `
    
    // Fetch and display template preview
    fetch(`/plan_templates/${templateId}/preview`)
      .then(response => response.json())
      .then(data => {
        this.displayTemplatePreview(data)
        this.showPreviewModal()
      })
      .catch(error => {
        console.error('Error loading template preview:', error)
        this.previewContentTarget.innerHTML = `
          <div class="text-center py-8">
            <p class="text-red-600">Error loading template preview</p>
          </div>
        `
      })
  }

  displayTemplatePreview(data) {
    const { template, template_data } = data
    
    this.previewTitleTarget.textContent = `${template.name} Preview`
    
    const previewHtml = `
      <div class="space-y-6">
        <!-- Template Info -->
        <div class="bg-gray-50 rounded-lg p-4">
          <div class="flex justify-between items-start mb-3">
            <div>
              <h4 class="font-medium text-gray-900">${template.name}</h4>
              <p class="text-sm text-gray-600 mt-1">${template.description}</p>
            </div>
            <div class="flex gap-2">
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                ${template.industry_type}
              </span>
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                ${template.template_type}
              </span>
            </div>
          </div>
        </div>
        
        <!-- Template Content Preview -->
        ${this.renderTemplateContent(template_data)}
      </div>
    `
    
    this.previewContentTarget.innerHTML = previewHtml
  }

  renderTemplateContent(templateData) {
    let content = ''
    
    if (templateData.strategic_rationale) {
      content += `
        <div class="border border-gray-200 rounded-lg p-4">
          <h5 class="font-medium text-gray-900 mb-2">Strategic Rationale</h5>
          <div class="text-sm text-gray-600 space-y-1">
            <p><strong>Market Analysis:</strong> ${templateData.strategic_rationale.market_analysis}</p>
            <p><strong>Value Proposition:</strong> ${templateData.strategic_rationale.value_proposition}</p>
          </div>
        </div>
      `
    }
    
    if (templateData.channel_strategy) {
      content += `
        <div class="border border-gray-200 rounded-lg p-4">
          <h5 class="font-medium text-gray-900 mb-2">Marketing Channels</h5>
          <div class="flex flex-wrap gap-2">
            ${templateData.channel_strategy.map(channel => `
              <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium bg-blue-100 text-blue-800">
                ${channel.replace('_', ' ').toUpperCase()}
              </span>
            `).join('')}
          </div>
        </div>
      `
    }
    
    if (templateData.timeline_phases) {
      content += `
        <div class="border border-gray-200 rounded-lg p-4">
          <h5 class="font-medium text-gray-900 mb-3">Timeline Phases</h5>
          <div class="space-y-2">
            ${templateData.timeline_phases.map((phase, index) => `
              <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                <span class="text-sm font-medium">${phase.phase}</span>
                <span class="text-xs text-gray-500">${phase.duration_weeks} weeks</span>
              </div>
            `).join('')}
          </div>
        </div>
      `
    }
    
    return content
  }

  showPreviewModal() {
    this.previewModalTarget.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
  }

  closePreview() {
    this.previewModalTarget.classList.add('hidden')
    document.body.style.overflow = ''
  }

  selectFromPreview() {
    // Get the template ID from the preview modal
    const templateId = this.previewTitleTarget.textContent.includes('Preview') ? 
      this.previewTitleTarget.dataset.templateId : null
    
    if (templateId) {
      // Find and select the template card
      const templateCard = this.galleryTarget.querySelector(`[data-template-id="${templateId}"]`)
      if (templateCard) {
        this.selectTemplate({ currentTarget: templateCard })
      }
    }
    
    this.closePreview()
  }

  filterByIndustry(event) {
    const selectedIndustry = event.target.value
    this.applyFilters({ industry: selectedIndustry })
  }

  filterByType(event) {
    const selectedType = event.target.value
    this.applyFilters({ type: selectedType })
  }

  applyFilters(filters) {
    const templates = this.galleryTarget.querySelectorAll('.template-card[data-template-id]')
    
    templates.forEach(template => {
      let shouldShow = true
      
      if (filters.industry && filters.industry !== '' && 
          template.dataset.industry !== filters.industry) {
        shouldShow = false
      }
      
      if (filters.type && filters.type !== '' && 
          template.dataset.type !== filters.type) {
        shouldShow = false
      }
      
      template.style.display = shouldShow ? 'block' : 'none'
    })
    
    // Show empty state if no templates match
    this.updateEmptyState()
  }

  updateEmptyState() {
    const visibleTemplates = this.galleryTarget.querySelectorAll('.template-card[data-template-id]:not([style*="none"])')
    const emptyState = this.galleryTarget.querySelector('.empty-state')
    
    if (visibleTemplates.length === 0) {
      if (!emptyState) {
        const emptyDiv = document.createElement('div')
        emptyDiv.className = 'empty-state col-span-full text-center py-8'
        emptyDiv.innerHTML = `
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No templates found</h3>
          <p class="mt-1 text-sm text-gray-500">Try adjusting your filters or start from scratch.</p>
        `
        this.galleryTarget.appendChild(emptyDiv)
      }
    } else if (emptyState) {
      emptyState.remove()
    }
  }

  disconnect() {
    document.body.style.overflow = ''
  }
}