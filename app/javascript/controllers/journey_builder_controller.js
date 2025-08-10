import { Controller } from "@hotwired/stimulus"

// Journey Builder Controller for drag-and-drop stage management
export default class extends Controller {
  static targets = [
    "canvas", "stagesContainer", "configPanel", "configForm", "connectionLines",
    "stageTemplate", "stageLibrary", "canvasInstructions",
    "stageNameInput", "stageDescriptionInput", "stageDurationInput",
    "stageCount", "averageDuration"
  ]

  static values = {
    campaignId: Number,
    existingStages: Array
  }

  connect() {
    this.stages = []
    this.connections = []
    this.draggedElement = null
    this.selectedStage = null
    this.stageCounter = 0
    
    // Load existing stages if available
    if (this.existingStagesValue && this.existingStagesValue.length > 0) {
      this.loadExistingStages()
    }

    this.updateStatistics()
    this.setupDragAndDrop()
  }

  disconnect() {
    this.cleanup()
  }

  // Load existing stages from the campaign
  loadExistingStages() {
    this.stages = [...this.existingStagesValue]
    this.stageCounter = this.stages.length
    this.renderStages()
    this.showStagesContainer()
  }

  // Setup drag and drop event listeners
  setupDragAndDrop() {
    // Setup drag start for stage templates
    this.stageTemplateTargets.forEach(template => {
      template.addEventListener('dragstart', this.handleTemplateDragStart.bind(this))
    })

    // Prevent default drag behaviors
    this.canvasTarget.addEventListener('dragenter', this.preventDefault)
    this.canvasTarget.addEventListener('dragleave', this.preventDefault)
  }

  // Handle template drag start
  handleTemplateDragStart(event) {
    this.draggedElement = event.currentTarget
    event.dataTransfer.setData('text/plain', '')
    event.dataTransfer.effectAllowed = 'copy'
  }

  // Handle canvas drag over
  handleCanvasDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
    
    // Visual feedback
    this.canvasTarget.classList.add('drag-over')
  }

  // Handle canvas drop
  handleCanvasDrop(event) {
    event.preventDefault()
    this.canvasTarget.classList.remove('drag-over')

    if (!this.draggedElement) return

    // Get drop position
    const rect = this.canvasTarget.getBoundingClientRect()
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top

    // Create new stage
    this.createStageFromTemplate(this.draggedElement, x, y)
    
    this.draggedElement = null
  }

  // Create stage from template
  createStageFromTemplate(template, x, y) {
    const stageType = template.dataset.stageType
    const stageConfig = this.getStageTypeConfig(stageType)
    
    const newStage = {
      id: `stage-${++this.stageCounter}`,
      name: stageConfig.name,
      type: stageType,
      description: stageConfig.description,
      duration_days: stageConfig.defaultDuration,
      position: { x: Math.max(0, x - 100), y: Math.max(0, y - 50) },
      color: stageConfig.color
    }

    this.stages.push(newStage)
    this.renderStages()
    this.showStagesContainer()
    this.updateStatistics()
    this.drawConnections()
  }

  // Get stage type configuration
  getStageTypeConfig(type) {
    const configs = {
      awareness: {
        name: 'Awareness Stage',
        description: 'Customer becomes aware of your brand or product',
        defaultDuration: 7,
        color: 'blue'
      },
      consideration: {
        name: 'Consideration Stage', 
        description: 'Customer evaluates your product against alternatives',
        defaultDuration: 14,
        color: 'yellow'
      },
      conversion: {
        name: 'Conversion Stage',
        description: 'Customer makes a purchase or commitment',
        defaultDuration: 3,
        color: 'green'
      },
      retention: {
        name: 'Retention Stage',
        description: 'Building customer loyalty and repeat business',
        defaultDuration: 30,
        color: 'purple'
      },
      advocacy: {
        name: 'Advocacy Stage',
        description: 'Customer becomes a brand advocate and promoter',
        defaultDuration: 90,
        color: 'indigo'
      }
    }
    
    return configs[type] || configs.awareness
  }

  // Render stages on canvas
  renderStages() {
    this.stagesContainerTarget.innerHTML = ''
    
    this.stages.forEach(stage => {
      const stageElement = this.createStageElement(stage)
      this.stagesContainerTarget.appendChild(stageElement)
    })
  }

  // Create stage DOM element
  createStageElement(stage) {
    const div = document.createElement('div')
    div.className = `journey-stage bg-white rounded-lg shadow-lg border-2 border-${stage.color}-200 p-4 cursor-move select-none relative`
    div.style.position = 'absolute'
    div.style.left = `${stage.position.x}px`
    div.style.top = `${stage.position.y}px`
    div.style.width = '200px'
    div.style.minHeight = '120px'
    div.style.zIndex = '10'
    div.dataset.stageId = stage.id
    div.draggable = true

    div.innerHTML = `
      <div class="flex items-center space-x-3 mb-3">
        <div class="w-10 h-10 bg-${stage.color}-100 rounded-lg flex items-center justify-center flex-shrink-0">
          ${this.getStageIcon(stage.type)}
        </div>
        <div class="flex-1 min-w-0">
          <h4 class="font-semibold text-gray-900 text-sm truncate">${stage.name}</h4>
          <p class="text-xs text-${stage.color}-600 capitalize">${stage.type}</p>
        </div>
      </div>
      
      <p class="text-xs text-gray-600 mb-3 line-clamp-2">${stage.description}</p>
      
      <div class="flex items-center justify-between text-xs text-gray-500">
        <div class="flex items-center space-x-1">
          <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clip-rule="evenodd"/>
          </svg>
          <span>${stage.duration_days} days</span>
        </div>
        <button class="text-gray-400 hover:text-gray-600" data-action="click->journey-builder#configureStage" data-stage-id="${stage.id}">
          <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
            <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z"/>
          </svg>
        </button>
      </div>
      
      <!-- Connection points -->
      <div class="stage-connection-points">
        <div class="connection-point input absolute -left-2 top-1/2 transform -translate-y-1/2 w-4 h-4 bg-gray-300 rounded-full border-2 border-white shadow-sm"></div>
        <div class="connection-point output absolute -right-2 top-1/2 transform -translate-y-1/2 w-4 h-4 bg-gray-300 rounded-full border-2 border-white shadow-sm"></div>
      </div>
    `

    // Add event listeners
    div.addEventListener('dragstart', this.handleStageDragStart.bind(this))
    div.addEventListener('dragend', this.handleStageDragEnd.bind(this))
    div.addEventListener('click', this.selectStage.bind(this))

    return div
  }

  // Get stage icon based on type
  getStageIcon(type) {
    const icons = {
      awareness: '<svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20"><path d="M10 12a2 2 0 100-4 2 2 0 000 4z"/><path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd"/></svg>',
      consideration: '<svg class="w-5 h-5 text-yellow-600" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd"/></svg>',
      conversion: '<svg class="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>',
      retention: '<svg class="w-5 h-5 text-purple-600" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/></svg>',
      advocacy: '<svg class="w-5 h-5 text-indigo-600" fill="currentColor" viewBox="0 0 20 20"><path d="M2 10.5a1.5 1.5 0 113 0v6a1.5 1.5 0 01-3 0v-6zM6 10.333v5.43a2 2 0 001.106 1.79l.05.025A4 4 0 008.943 18h5.416a2 2 0 001.962-1.608l1.2-6A2 2 0 0015.56 8H12V4a2 2 0 00-2-2 1 1 0 00-1 1v.667a4 4 0 01-.8 2.4L6.8 7.933a4 4 0 00-.8 2.4z"/></svg>'
    }
    return icons[type] || icons.awareness
  }

  // Handle stage drag start (for repositioning)
  handleStageDragStart(event) {
    this.draggedStage = event.currentTarget
    event.dataTransfer.setData('text/plain', '')
    event.dataTransfer.effectAllowed = 'move'
    event.currentTarget.style.opacity = '0.5'
  }

  // Handle stage drag end
  handleStageDragEnd(event) {
    event.currentTarget.style.opacity = '1'
    this.draggedStage = null
  }

  // Show stages container and hide instructions
  showStagesContainer() {
    this.canvasInstructionsTarget.style.display = 'none'
    this.stagesContainerTarget.style.display = 'block'
  }

  // Select stage for configuration
  selectStage(event) {
    // Remove selection from other stages
    document.querySelectorAll('.journey-stage').forEach(stage => {
      stage.classList.remove('ring-2', 'ring-blue-500')
    })
    
    // Add selection to clicked stage
    event.currentTarget.classList.add('ring-2', 'ring-blue-500')
    this.selectedStage = event.currentTarget.dataset.stageId
  }

  // Configure stage
  configureStage(event) {
    event.stopPropagation()
    const stageId = event.currentTarget.dataset.stageId
    const stage = this.stages.find(s => s.id === stageId)
    
    if (stage) {
      this.openConfigPanel(stage)
    }
  }

  // Open configuration panel
  openConfigPanel(stage) {
    this.selectedStage = stage.id
    
    // Populate form
    this.stageNameInputTarget.value = stage.name
    this.stageDescriptionInputTarget.value = stage.description || ''
    this.stageDurationInputTarget.value = stage.duration_days || ''
    
    // Show panel
    this.configPanelTarget.style.display = 'block'
  }

  // Close configuration panel
  closeConfigPanel() {
    this.configPanelTarget.style.display = 'none'
    this.selectedStage = null
    
    // Remove selection highlight
    document.querySelectorAll('.journey-stage').forEach(stage => {
      stage.classList.remove('ring-2', 'ring-blue-500')
    })
  }

  // Save stage configuration
  saveStageConfig(event) {
    event.preventDefault()
    
    if (!this.selectedStage) return
    
    const stage = this.stages.find(s => s.id === this.selectedStage)
    if (!stage) return
    
    // Update stage with form data
    stage.name = this.stageNameInputTarget.value
    stage.description = this.stageDescriptionInputTarget.value
    stage.duration_days = parseInt(this.stageDurationInputTarget.value) || 1
    
    // Re-render stages and update statistics
    this.renderStages()
    this.updateStatistics()
    this.closeConfigPanel()
    this.drawConnections()
  }

  // Delete stage
  deleteStage(event) {
    event.preventDefault()
    
    if (!this.selectedStage) return
    
    if (confirm('Are you sure you want to delete this stage?')) {
      this.stages = this.stages.filter(s => s.id !== this.selectedStage)
      this.renderStages()
      this.updateStatistics()
      this.closeConfigPanel()
      this.drawConnections()
      
      // Show instructions if no stages left
      if (this.stages.length === 0) {
        this.canvasInstructionsTarget.style.display = 'flex'
        this.stagesContainerTarget.style.display = 'none'
      }
    }
  }

  // Load predefined templates
  loadTemplate(event) {
    const templateType = event.currentTarget.dataset.template
    
    if (this.stages.length > 0) {
      if (!confirm('This will replace your current journey. Continue?')) {
        return
      }
    }
    
    this.stages = this.getTemplateStages(templateType)
    this.stageCounter = this.stages.length
    this.renderStages()
    this.showStagesContainer()
    this.updateStatistics()
    this.drawConnections()
  }

  // Get template stage configurations
  getTemplateStages(templateType) {
    const templates = {
      'product-launch': [
        { id: 'stage-1', type: 'awareness', name: 'Product Awareness', description: 'Introduce new product to market', duration_days: 14, position: { x: 50, y: 100 }, color: 'blue' },
        { id: 'stage-2', type: 'consideration', name: 'Feature Evaluation', description: 'Showcase product benefits and features', duration_days: 21, position: { x: 300, y: 100 }, color: 'yellow' },
        { id: 'stage-3', type: 'conversion', name: 'Launch Purchase', description: 'Drive initial sales and adoption', duration_days: 7, position: { x: 550, y: 100 }, color: 'green' }
      ],
      'lead-generation': [
        { id: 'stage-1', type: 'awareness', name: 'Content Discovery', description: 'Attract prospects with valuable content', duration_days: 7, position: { x: 50, y: 100 }, color: 'blue' },
        { id: 'stage-2', type: 'consideration', name: 'Lead Qualification', description: 'Nurture and qualify potential customers', duration_days: 14, position: { x: 300, y: 100 }, color: 'yellow' },
        { id: 'stage-3', type: 'conversion', name: 'Sales Conversion', description: 'Convert qualified leads to customers', duration_days: 10, position: { x: 550, y: 100 }, color: 'green' },
        { id: 'stage-4', type: 'retention', name: 'Customer Success', description: 'Ensure customer satisfaction and retention', duration_days: 30, position: { x: 800, y: 100 }, color: 'purple' }
      ],
      'full-funnel': [
        { id: 'stage-1', type: 'awareness', name: 'Brand Awareness', description: 'Build initial brand recognition', duration_days: 14, position: { x: 50, y: 100 }, color: 'blue' },
        { id: 'stage-2', type: 'consideration', name: 'Solution Research', description: 'Prospect evaluates solutions', duration_days: 21, position: { x: 300, y: 100 }, color: 'yellow' },
        { id: 'stage-3', type: 'conversion', name: 'Purchase Decision', description: 'Customer makes purchase', duration_days: 7, position: { x: 550, y: 100 }, color: 'green' },
        { id: 'stage-4', type: 'retention', name: 'Ongoing Engagement', description: 'Maintain customer relationship', duration_days: 60, position: { x: 800, y: 100 }, color: 'purple' },
        { id: 'stage-5', type: 'advocacy', name: 'Brand Advocacy', description: 'Customer promotes brand to others', duration_days: 90, position: { x: 1050, y: 100 }, color: 'indigo' }
      ]
    }
    
    return templates[templateType] || []
  }

  // Draw connection lines between stages
  drawConnections() {
    const svg = this.connectionLinesTarget
    svg.innerHTML = '' // Clear existing lines
    
    if (this.stages.length < 2) return
    
    // Sort stages by x position to create logical flow
    const sortedStages = [...this.stages].sort((a, b) => a.position.x - b.position.x)
    
    for (let i = 0; i < sortedStages.length - 1; i++) {
      const fromStage = sortedStages[i]
      const toStage = sortedStages[i + 1]
      
      // Calculate connection points
      const fromX = fromStage.position.x + 200 // Right edge of from stage
      const fromY = fromStage.position.y + 60  // Middle of from stage
      const toX = toStage.position.x           // Left edge of to stage
      const toY = toStage.position.y + 60      // Middle of to stage
      
      // Create curved path
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
      const midX = (fromX + toX) / 2
      const d = `M ${fromX} ${fromY} Q ${midX} ${fromY} ${midX} ${(fromY + toY) / 2} Q ${midX} ${toY} ${toX} ${toY}`
      
      path.setAttribute('d', d)
      path.setAttribute('stroke', '#9CA3AF')
      path.setAttribute('stroke-width', '2')
      path.setAttribute('fill', 'none')
      path.setAttribute('marker-end', 'url(#arrowhead)')
      
      svg.appendChild(path)
    }
    
    // Add arrowhead marker if it doesn't exist
    if (!svg.querySelector('#arrowhead')) {
      const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs')
      const marker = document.createElementNS('http://www.w3.org/2000/svg', 'marker')
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
      
      marker.setAttribute('id', 'arrowhead')
      marker.setAttribute('markerWidth', '10')
      marker.setAttribute('markerHeight', '7')
      marker.setAttribute('refX', '9')
      marker.setAttribute('refY', '3.5')
      marker.setAttribute('orient', 'auto')
      
      path.setAttribute('d', 'M 0 0 L 10 3.5 L 0 7 z')
      path.setAttribute('fill', '#9CA3AF')
      
      marker.appendChild(path)
      defs.appendChild(marker)
      svg.appendChild(defs)
    }
  }

  // Update journey statistics
  updateStatistics() {
    const stageCount = this.stages.length
    const totalDuration = this.stages.reduce((sum, stage) => sum + (stage.duration_days || 0), 0)
    const averageDuration = stageCount > 0 ? Math.round(totalDuration / stageCount) : 0
    
    this.stageCountTarget.textContent = stageCount
    this.averageDurationTarget.textContent = averageDuration
  }

  // Reset journey
  resetJourney() {
    if (this.stages.length > 0) {
      if (confirm('This will delete all stages. Are you sure?')) {
        this.stages = []
        this.stageCounter = 0
        this.renderStages()
        this.updateStatistics()
        this.closeConfigPanel()
        this.canvasInstructionsTarget.style.display = 'flex'
        this.stagesContainerTarget.style.display = 'none'
        this.connectionLinesTarget.innerHTML = ''
      }
    }
  }

  // Save journey to backend
  async saveJourney() {
    if (this.stages.length === 0) {
      alert('Please add some stages before saving.')
      return
    }
    
    try {
      const response = await fetch(`/campaigns/${this.campaignIdValue}/customer_journey`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          customer_journey: {
            stages: this.stages,
            name: 'Customer Journey',
            content_types: this.extractContentTypes()
          }
        })
      })
      
      if (response.ok) {
        this.showNotification('Journey saved successfully!', 'success')
      } else {
        throw new Error('Failed to save journey')
      }
    } catch (error) {
      this.showNotification('Error saving journey. Please try again.', 'error')
      console.error('Save error:', error)
    }
  }

  // Extract content types from stages
  extractContentTypes() {
    const typeMap = {
      awareness: ['blog_post', 'social_media', 'advertisement'],
      consideration: ['whitepaper', 'case_study', 'webinar'],
      conversion: ['landing_page', 'email', 'infographic'],
      retention: ['newsletter', 'email'],
      advocacy: ['social_media', 'case_study']
    }
    
    const contentTypes = new Set()
    this.stages.forEach(stage => {
      const types = typeMap[stage.type] || []
      types.forEach(type => contentTypes.add(type))
    })
    
    return Array.from(contentTypes)
  }

  // Show notification
  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg ${
      type === 'success' ? 'bg-green-100 text-green-800' : 
      type === 'error' ? 'bg-red-100 text-red-800' : 
      'bg-blue-100 text-blue-800'
    }`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }

  // Utility methods
  preventDefault(event) {
    event.preventDefault()
  }

  cleanup() {
    // Remove event listeners and clean up
    this.stageTemplateTargets.forEach(template => {
      template.removeEventListener('dragstart', this.handleTemplateDragStart)
    })
  }
}