import { Controller } from "@hotwired/stimulus"

// Journey Visualizer Controller for enhanced flow diagrams and visualization
export default class extends Controller {
  static targets = [
    "canvas", "svg", "viewport", "minimap", "minimapCanvas", "minimapViewport",
    "zoomControls", "zoomLevel", "stageContainer", "connectionContainer",
    "statusIndicators", "validationErrors"
  ]

  static values = {
    stages: Array,
    connections: Array,
    scale: { type: Number, default: 1 },
    panX: { type: Number, default: 0 },
    panY: { type: Number, default: 0 },
    showMinimap: { type: Boolean, default: false },
    enableAnimations: { type: Boolean, default: true }
  }

  static classes = [
    "stage", "connection", "activeStage", "completedStage", "scheduledStage",
    "errorStage", "warningStage", "flowIndicator", "minimapStage"
  ]

  connect() {
    this.initializeVisualization()
    this.setupEventListeners()
    this.setupPanAndZoom()
    this.setupMinimap()
    this.renderStages()
    this.renderConnections()
    this.startAnimations()
  }

  disconnect() {
    this.cleanup()
  }

  // Initialize the visualization canvas and viewport
  initializeVisualization() {
    this.isPanning = false
    this.isSelecting = false
    this.lastMousePos = { x: 0, y: 0 }
    this.selectedStages = new Set()
    this.animationFrame = null
    this.flowAnimations = []
    
    // Set up canvas dimensions
    this.updateCanvasDimensions()
    
    // Initialize viewport transform
    this.updateViewportTransform()
  }

  // Setup event listeners for interaction
  setupEventListeners() {
    // Mouse events for pan and selection
    this.canvasTarget.addEventListener('mousedown', this.handleMouseDown.bind(this))
    this.canvasTarget.addEventListener('mousemove', this.handleMouseMove.bind(this))
    this.canvasTarget.addEventListener('mouseup', this.handleMouseUp.bind(this))
    this.canvasTarget.addEventListener('wheel', this.handleWheel.bind(this))
    
    // Touch events for mobile support
    this.canvasTarget.addEventListener('touchstart', this.handleTouchStart.bind(this))
    this.canvasTarget.addEventListener('touchmove', this.handleTouchMove.bind(this))
    this.canvasTarget.addEventListener('touchend', this.handleTouchEnd.bind(this))
    
    // Keyboard shortcuts
    document.addEventListener('keydown', this.handleKeyDown.bind(this))
    
    // Window resize
    window.addEventListener('resize', this.handleResize.bind(this))
  }

  // Setup pan and zoom functionality
  setupPanAndZoom() {
    this.minScale = 0.1
    this.maxScale = 3
    this.zoomSensitivity = 0.001
    
    // Initialize zoom controls if they exist
    if (this.hasZoomControlsTarget) {
      this.updateZoomControls()
    }
  }

  // Setup minimap navigation
  setupMinimap() {
    if (!this.hasMiniMapCanvasTarget) return
    
    this.minimapScale = 0.1
    this.minimapWidth = 200
    this.minimapHeight = 150
    
    this.minimapCanvasTarget.width = this.minimapWidth
    this.minimapCanvasTarget.height = this.minimapHeight
    
    // Minimap interaction
    this.minimapCanvasTarget.addEventListener('click', this.handleMinimapClick.bind(this))
    this.minimapCanvasTarget.addEventListener('mousedown', this.handleMinimapDrag.bind(this))
  }

  // Render stages with status indicators
  renderStages() {
    if (!this.hasStageContainerTarget) return
    
    this.stageContainerTarget.innerHTML = ''
    
    this.stagesValue.forEach((stage, index) => {
      const stageElement = this.createStageElement(stage, index)
      this.stageContainerTarget.appendChild(stageElement)
    })
    
    this.updateStageStatusIndicators()
    this.renderMinimap()
  }

  // Create enhanced stage element with status indicators
  createStageElement(stage, index) {
    const div = document.createElement('div')
    div.className = `${this.stageClass} journey-stage-visualization`
    div.style.position = 'absolute'
    div.style.left = `${stage.position.x}px`
    div.style.top = `${stage.position.y}px`
    div.style.width = '200px'
    div.style.minHeight = '120px'
    div.style.transform = 'translate(-50%, -50%)'
    div.style.cursor = 'pointer'
    div.dataset.stageId = stage.id
    div.dataset.stageIndex = index

    // Add status-based classes
    if (stage.status) {
      switch (stage.status) {
        case 'active':
          div.classList.add(this.activeStageClass || 'stage-active')
          break
        case 'completed':
          div.classList.add(this.completedStageClass || 'stage-completed')
          break
        case 'scheduled':
          div.classList.add(this.scheduledStageClass || 'stage-scheduled')
          break
        case 'error':
          div.classList.add(this.errorStageClass || 'stage-error')
          break
        case 'warning':
          div.classList.add(this.warningStageClass || 'stage-warning')
          break
      }
    }

    div.innerHTML = `
      <div class="stage-content bg-white rounded-lg shadow-lg border-2 border-${stage.color}-200 p-4 relative overflow-hidden">
        <!-- Status indicator overlay -->
        <div class="stage-status-indicator absolute top-2 right-2">
          ${this.getStatusIndicator(stage)}
        </div>
        
        <!-- Stage header -->
        <div class="flex items-center space-x-3 mb-3">
          <div class="w-10 h-10 bg-${stage.color}-100 rounded-lg flex items-center justify-center flex-shrink-0">
            ${this.getStageIcon(stage.type)}
          </div>
          <div class="flex-1 min-w-0">
            <h4 class="font-semibold text-gray-900 text-sm truncate">${stage.name}</h4>
            <p class="text-xs text-${stage.color}-600 capitalize">${stage.type}</p>
          </div>
        </div>
        
        <!-- Stage description -->
        <p class="text-xs text-gray-600 mb-3 line-clamp-2">${stage.description || ''}</p>
        
        <!-- Stage metrics -->
        <div class="flex items-center justify-between text-xs text-gray-500 mb-2">
          <div class="flex items-center space-x-1">
            <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clip-rule="evenodd"/>
            </svg>
            <span>${stage.duration_days || 0} days</span>
          </div>
          <div class="stage-progress-indicator">
            ${this.getProgressIndicator(stage)}
          </div>
        </div>
        
        <!-- Validation indicators -->
        <div class="stage-validation-indicators">
          ${this.getValidationIndicators(stage)}
        </div>
        
        <!-- Connection points -->
        <div class="stage-connection-points">
          <div class="connection-point input absolute -left-2 top-1/2 transform -translate-y-1/2 w-4 h-4 bg-white rounded-full border-2 shadow-sm ${this.getConnectionPointClass(stage, 'input')}"></div>
          <div class="connection-point output absolute -right-2 top-1/2 transform -translate-y-1/2 w-4 h-4 bg-white rounded-full border-2 shadow-sm ${this.getConnectionPointClass(stage, 'output')}"></div>
        </div>
        
        <!-- Click-to-edit overlay -->
        <div class="stage-edit-overlay absolute inset-0 bg-blue-500 bg-opacity-10 opacity-0 hover:opacity-100 transition-opacity cursor-pointer rounded-lg flex items-center justify-center">
          <div class="bg-white bg-opacity-90 rounded-full p-2">
            <svg class="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
              <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z"/>
            </svg>
          </div>
        </div>
      </div>
    `

    // Add event listeners
    div.addEventListener('click', (e) => this.handleStageClick(e, stage, index))
    div.addEventListener('dblclick', (e) => this.handleStageDoubleClick(e, stage, index))
    div.addEventListener('contextmenu', (e) => this.handleStageContextMenu(e, stage, index))

    return div
  }

  // Get status indicator HTML based on stage status
  getStatusIndicator(stage) {
    if (!stage.status) return ''
    
    const indicators = {
      active: '<div class="w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>',
      completed: '<div class="w-3 h-3 bg-green-600 rounded-full"><svg class="w-2 h-2 text-white m-0.5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg></div>',
      scheduled: '<div class="w-3 h-3 bg-yellow-400 rounded-full"></div>',
      error: '<div class="w-3 h-3 bg-red-500 rounded-full"><svg class="w-2 h-2 text-white m-0.5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/></svg></div>',
      warning: '<div class="w-3 h-3 bg-orange-400 rounded-full"><svg class="w-2 h-2 text-white m-0.5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg></div>'
    }
    
    return indicators[stage.status] || ''
  }

  // Get progress indicator based on stage completion
  getProgressIndicator(stage) {
    if (!stage.progress) return ''
    
    const progress = Math.min(Math.max(stage.progress || 0, 0), 100)
    return `
      <div class="w-16 h-1 bg-gray-200 rounded-full overflow-hidden">
        <div class="h-full bg-blue-500 rounded-full transition-all duration-300" style="width: ${progress}%"></div>
      </div>
    `
  }

  // Get validation indicators for stage errors/warnings
  getValidationIndicators(stage) {
    if (!stage.validation || stage.validation.length === 0) return ''
    
    const hasErrors = stage.validation.some(v => v.type === 'error')
    const hasWarnings = stage.validation.some(v => v.type === 'warning')
    
    let indicators = []
    
    if (hasErrors) {
      indicators.push(`
        <div class="inline-flex items-center px-2 py-1 rounded-full text-xs bg-red-100 text-red-800 mr-1">
          <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
          </svg>
          Errors
        </div>
      `)
    }
    
    if (hasWarnings) {
      indicators.push(`
        <div class="inline-flex items-center px-2 py-1 rounded-full text-xs bg-yellow-100 text-yellow-800">
          <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
          </svg>
          Warnings
        </div>
      `)
    }
    
    return indicators.length > 0 ? `<div class="mt-2">${indicators.join('')}</div>` : ''
  }

  // Get connection point styling based on stage status
  getConnectionPointClass(stage, type) {
    const baseClass = 'border-gray-300'
    
    if (stage.status === 'error') {
      return 'border-red-400 bg-red-100'
    } else if (stage.status === 'warning') {
      return 'border-yellow-400 bg-yellow-100'
    } else if (stage.status === 'active') {
      return 'border-blue-400 bg-blue-100'
    } else if (stage.status === 'completed') {
      return 'border-green-400 bg-green-100'
    }
    
    return baseClass
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

  // Render enhanced connection lines with animations
  renderConnections() {
    if (!this.hasSvgTarget) return
    
    // Clear existing connections
    this.svgTarget.innerHTML = ''
    
    // Add definitions for arrows and flow animations
    this.createSVGDefinitions()
    
    // Render connections
    this.connectionsValue.forEach((connection, index) => {
      this.createConnectionLine(connection, index)
    })
    
    // Start flow animations
    if (this.enableAnimationsValue) {
      this.startFlowAnimations()
    }
  }

  // Create SVG definitions for markers and patterns
  createSVGDefinitions() {
    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs')
    
    // Arrow marker
    const arrowMarker = document.createElementNS('http://www.w3.org/2000/svg', 'marker')
    arrowMarker.setAttribute('id', 'arrowhead')
    arrowMarker.setAttribute('markerWidth', '10')
    arrowMarker.setAttribute('markerHeight', '7')
    arrowMarker.setAttribute('refX', '9')
    arrowMarker.setAttribute('refY', '3.5')
    arrowMarker.setAttribute('orient', 'auto')
    arrowMarker.setAttribute('markerUnits', 'strokeWidth')
    
    const arrowPath = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    arrowPath.setAttribute('d', 'M 0 0 L 10 3.5 L 0 7 z')
    arrowPath.setAttribute('fill', '#6B7280')
    arrowMarker.appendChild(arrowPath)
    
    // Flow animation pattern
    const flowPattern = document.createElementNS('http://www.w3.org/2000/svg', 'pattern')
    flowPattern.setAttribute('id', 'flowPattern')
    flowPattern.setAttribute('patternUnits', 'userSpaceOnUse')
    flowPattern.setAttribute('width', '20')
    flowPattern.setAttribute('height', '20')
    
    const flowCircle = document.createElementNS('http://www.w3.org/2000/svg', 'circle')
    flowCircle.setAttribute('cx', '10')
    flowCircle.setAttribute('cy', '10')
    flowCircle.setAttribute('r', '2')
    flowCircle.setAttribute('fill', '#3B82F6')
    flowCircle.setAttribute('opacity', '0.7')
    flowPattern.appendChild(flowCircle)
    
    defs.appendChild(arrowMarker)
    defs.appendChild(flowPattern)
    this.svgTarget.appendChild(defs)
  }

  // Create individual connection line with enhanced features
  createConnectionLine(connection, index) {
    const fromStage = this.stagesValue.find(s => s.id === connection.from)
    const toStage = this.stagesValue.find(s => s.id === connection.to)
    
    if (!fromStage || !toStage) return
    
    // Calculate connection points
    const fromX = fromStage.position.x + 100 // Right edge
    const fromY = fromStage.position.y
    const toX = toStage.position.x - 100     // Left edge  
    const toY = toStage.position.y
    
    // Create connection group
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g')
    group.setAttribute('class', 'connection-group')
    group.setAttribute('data-connection-id', connection.id || `connection-${index}`)
    
    // Create main connection path
    const path = this.createConnectionPath(fromX, fromY, toX, toY, connection)
    group.appendChild(path)
    
    // Add flow indicators if enabled
    if (this.enableAnimationsValue && connection.status === 'active') {
      const flowIndicator = this.createFlowIndicator(fromX, fromY, toX, toY)
      group.appendChild(flowIndicator)
    }
    
    // Add connection label if it exists
    if (connection.label) {
      const label = this.createConnectionLabel(fromX, fromY, toX, toY, connection.label)
      group.appendChild(label)
    }
    
    this.svgTarget.appendChild(group)
  }

  // Create connection path with bezier curves
  createConnectionPath(fromX, fromY, toX, toY, connection) {
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    
    // Calculate control points for smooth curve
    const dx = toX - fromX
    const dy = toY - fromY
    const controlOffset = Math.min(Math.abs(dx) * 0.5, 100)
    
    const controlX1 = fromX + controlOffset
    const controlY1 = fromY
    const controlX2 = toX - controlOffset
    const controlY2 = toY
    
    const pathData = `M ${fromX} ${fromY} C ${controlX1} ${controlY1}, ${controlX2} ${controlY2}, ${toX} ${toY}`
    path.setAttribute('d', pathData)
    path.setAttribute('stroke', this.getConnectionColor(connection))
    path.setAttribute('stroke-width', this.getConnectionWidth(connection))
    path.setAttribute('fill', 'none')
    path.setAttribute('marker-end', 'url(#arrowhead)')
    path.setAttribute('class', 'connection-line')
    
    // Add status-based styling
    if (connection.status) {
      path.classList.add(`connection-${connection.status}`)
    }
    
    return path
  }

  // Create animated flow indicator
  createFlowIndicator(fromX, fromY, toX, toY) {
    const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle')
    circle.setAttribute('r', '3')
    circle.setAttribute('fill', '#3B82F6')
    circle.setAttribute('class', this.flowIndicatorClass || 'flow-indicator')
    
    // Create animation path
    const animatePath = document.createElementNS('http://www.w3.org/2000/svg', 'animateMotion')
    
    const dx = toX - fromX
    const dy = toY - fromY
    const controlOffset = Math.min(Math.abs(dx) * 0.5, 100)
    const controlX1 = fromX + controlOffset
    const controlY1 = fromY
    const controlX2 = toX - controlOffset  
    const controlY2 = toY
    
    const pathData = `M ${fromX} ${fromY} C ${controlX1} ${controlY1}, ${controlX2} ${controlY2}, ${toX} ${toY}`
    
    animatePath.setAttribute('path', pathData)
    animatePath.setAttribute('dur', '2s')
    animatePath.setAttribute('repeatCount', 'indefinite')
    
    circle.appendChild(animatePath)
    return circle
  }

  // Create connection label
  createConnectionLabel(fromX, fromY, toX, toY, label) {
    const text = document.createElementNS('http://www.w3.org/2000/svg', 'text')
    
    // Position label at midpoint
    const midX = (fromX + toX) / 2
    const midY = (fromY + toY) / 2 - 10
    
    text.setAttribute('x', midX)
    text.setAttribute('y', midY)
    text.setAttribute('text-anchor', 'middle')
    text.setAttribute('class', 'connection-label text-xs fill-current text-gray-600')
    text.textContent = label
    
    // Add background for better readability
    const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
    rect.setAttribute('x', midX - (label.length * 3))
    rect.setAttribute('y', midY - 8)
    rect.setAttribute('width', label.length * 6)
    rect.setAttribute('height', 12)
    rect.setAttribute('fill', 'white')
    rect.setAttribute('stroke', '#E5E7EB')
    rect.setAttribute('rx', '2')
    
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g')
    group.appendChild(rect)
    group.appendChild(text)
    
    return group
  }

  // Get connection color based on status
  getConnectionColor(connection) {
    const colors = {
      active: '#3B82F6',
      completed: '#10B981',
      error: '#EF4444',
      warning: '#F59E0B',
      scheduled: '#6B7280'
    }
    return colors[connection.status] || '#9CA3AF'
  }

  // Get connection width based on importance
  getConnectionWidth(connection) {
    const widths = {
      primary: '3',
      secondary: '2',
      weak: '1'
    }
    return widths[connection.strength] || '2'
  }

  // Handle stage interactions
  handleStageClick(event, stage, index) {
    event.stopPropagation()
    
    if (event.ctrlKey || event.metaKey) {
      // Multi-select
      if (this.selectedStages.has(stage.id)) {
        this.selectedStages.delete(stage.id)
      } else {
        this.selectedStages.add(stage.id)
      }
    } else {
      // Single select
      this.selectedStages.clear()
      this.selectedStages.add(stage.id)
    }
    
    this.updateStageSelection()
    this.dispatchStageEvent('stage:selected', { stage, selectedStages: Array.from(this.selectedStages) })
  }

  // Handle stage double-click for editing
  handleStageDoubleClick(event, stage, index) {
    event.stopPropagation()
    this.dispatchStageEvent('stage:edit', { stage })
  }

  // Handle stage context menu
  handleStageContextMenu(event, stage, index) {
    event.preventDefault()
    this.dispatchStageEvent('stage:contextmenu', { 
      stage, 
      position: { x: event.clientX, y: event.clientY }
    })
  }

  // Update stage selection visual feedback
  updateStageSelection() {
    const stageElements = this.stageContainerTarget.querySelectorAll('.journey-stage-visualization')
    
    stageElements.forEach(element => {
      const stageId = element.dataset.stageId
      if (this.selectedStages.has(stageId)) {
        element.classList.add('stage-selected')
        element.style.transform = 'translate(-50%, -50%) scale(1.05)'
        element.style.zIndex = '20'
      } else {
        element.classList.remove('stage-selected')
        element.style.transform = 'translate(-50%, -50%) scale(1)'
        element.style.zIndex = '10'
      }
    })
  }

  // Zoom functionality
  zoomIn() {
    this.scaleValue = Math.min(this.scaleValue * 1.2, this.maxScale)
    this.updateViewportTransform()
    this.updateZoomControls()
  }

  zoomOut() {
    this.scaleValue = Math.max(this.scaleValue / 1.2, this.minScale)
    this.updateViewportTransform()
    this.updateZoomControls()
  }

  zoomToFit() {
    if (this.stagesValue.length === 0) return
    
    // Calculate bounding box of all stages
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    
    this.stagesValue.forEach(stage => {
      const x = stage.position.x
      const y = stage.position.y
      minX = Math.min(minX, x - 100)
      minY = Math.min(minY, y - 60)
      maxX = Math.max(maxX, x + 100)
      maxY = Math.max(maxY, y + 60)
    })
    
    // Calculate scale and position to fit all stages
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    const contentWidth = maxX - minX
    const contentHeight = maxY - minY
    const padding = 50
    
    const scaleX = (canvasRect.width - padding * 2) / contentWidth
    const scaleY = (canvasRect.height - padding * 2) / contentHeight
    const scale = Math.min(scaleX, scaleY, this.maxScale)
    
    this.scaleValue = Math.max(scale, this.minScale)
    this.panXValue = -(minX + contentWidth / 2) * this.scaleValue + canvasRect.width / 2
    this.panYValue = -(minY + contentHeight / 2) * this.scaleValue + canvasRect.height / 2
    
    this.updateViewportTransform()
    this.updateZoomControls()
  }

  // Update viewport transform
  updateViewportTransform() {
    if (this.hasViewportTarget) {
      this.viewportTarget.style.transform = `translate(${this.panXValue}px, ${this.panYValue}px) scale(${this.scaleValue})`
    }
    this.renderMinimap()
  }

  // Update zoom control UI
  updateZoomControls() {
    if (this.hasZoomLevelTarget) {
      this.zoomLevelTarget.textContent = `${Math.round(this.scaleValue * 100)}%`
    }
  }

  // Mouse and touch event handlers
  handleMouseDown(event) {
    if (event.button !== 0) return // Only left mouse button
    
    this.isPanning = true
    this.lastMousePos = { x: event.clientX, y: event.clientY }
    this.canvasTarget.style.cursor = 'grabbing'
  }

  handleMouseMove(event) {
    if (!this.isPanning) return
    
    const deltaX = event.clientX - this.lastMousePos.x
    const deltaY = event.clientY - this.lastMousePos.y
    
    this.panXValue += deltaX
    this.panYValue += deltaY
    
    this.lastMousePos = { x: event.clientX, y: event.clientY }
    this.updateViewportTransform()
  }

  handleMouseUp(event) {
    this.isPanning = false
    this.canvasTarget.style.cursor = 'default'
  }

  handleWheel(event) {
    event.preventDefault()
    
    const rect = this.canvasTarget.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top
    
    // Calculate zoom
    const delta = -event.deltaY * this.zoomSensitivity
    const newScale = Math.min(Math.max(this.scaleValue * (1 + delta), this.minScale), this.maxScale)
    
    if (newScale !== this.scaleValue) {
      // Zoom towards mouse position
      const scaleDiff = newScale - this.scaleValue
      this.panXValue -= (mouseX - this.panXValue) * scaleDiff / this.scaleValue
      this.panYValue -= (mouseY - this.panYValue) * scaleDiff / this.scaleValue
      this.scaleValue = newScale
      
      this.updateViewportTransform()
      this.updateZoomControls()
    }
  }

  // Touch event handlers
  handleTouchStart(event) {
    if (event.touches.length === 1) {
      this.isPanning = true
      this.lastMousePos = { x: event.touches[0].clientX, y: event.touches[0].clientY }
    }
  }

  handleTouchMove(event) {
    event.preventDefault()
    
    if (this.isPanning && event.touches.length === 1) {
      const deltaX = event.touches[0].clientX - this.lastMousePos.x
      const deltaY = event.touches[0].clientY - this.lastMousePos.y
      
      this.panXValue += deltaX
      this.panYValue += deltaY
      
      this.lastMousePos = { x: event.touches[0].clientX, y: event.touches[0].clientY }
      this.updateViewportTransform()
    }
  }

  handleTouchEnd(event) {
    this.isPanning = false
  }

  // Keyboard shortcuts
  handleKeyDown(event) {
    if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') return
    
    switch (event.key) {
      case '=':
      case '+':
        event.preventDefault()
        this.zoomIn()
        break
      case '-':
        event.preventDefault()
        this.zoomOut()
        break
      case '0':
        if (event.ctrlKey || event.metaKey) {
          event.preventDefault()
          this.zoomToFit()
        }
        break
      case 'Escape':
        this.selectedStages.clear()
        this.updateStageSelection()
        break
    }
  }

  // Window resize handler
  handleResize() {
    this.updateCanvasDimensions()
    this.renderMinimap()
  }

  // Minimap functionality
  renderMinimap() {
    if (!this.hasMinimapCanvasTarget || !this.showMinimapValue) return
    
    const ctx = this.minimapCanvasTarget.getContext('2d')
    ctx.clearRect(0, 0, this.minimapWidth, this.minimapHeight)
    
    // Calculate minimap scale
    if (this.stagesValue.length === 0) return
    
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    this.stagesValue.forEach(stage => {
      minX = Math.min(minX, stage.position.x)
      minY = Math.min(minY, stage.position.y)
      maxX = Math.max(maxX, stage.position.x)
      maxY = Math.max(maxY, stage.position.y)
    })
    
    const contentWidth = maxX - minX + 200
    const contentHeight = maxY - minY + 120
    const scaleX = this.minimapWidth / contentWidth
    const scaleY = this.minimapHeight / contentHeight
    const scale = Math.min(scaleX, scaleY)
    
    // Draw stages on minimap
    this.stagesValue.forEach(stage => {
      const x = (stage.position.x - minX + 100) * scale
      const y = (stage.position.y - minY + 60) * scale
      
      ctx.fillStyle = this.getMinimapStageColor(stage)
      ctx.fillRect(x - 2, y - 2, 4, 4)
    })
    
    // Draw viewport indicator
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    const viewportX = (-this.panXValue / this.scaleValue - minX + 100) * scale
    const viewportY = (-this.panYValue / this.scaleValue - minY + 60) * scale
    const viewportWidth = (canvasRect.width / this.scaleValue) * scale
    const viewportHeight = (canvasRect.height / this.scaleValue) * scale
    
    ctx.strokeStyle = '#3B82F6'
    ctx.lineWidth = 1
    ctx.strokeRect(viewportX, viewportY, viewportWidth, viewportHeight)
  }

  getMinimapStageColor(stage) {
    const colors = {
      active: '#10B981',
      completed: '#059669',
      error: '#DC2626',
      warning: '#D97706',
      scheduled: '#6B7280'
    }
    return colors[stage.status] || '#9CA3AF'
  }

  // Handle minimap interactions
  handleMinimapClick(event) {
    const rect = this.minimapCanvasTarget.getBoundingClientRect()
    const clickX = event.clientX - rect.left
    const clickY = event.clientY - rect.top
    
    // Convert minimap coordinates to canvas coordinates
    // This is a simplified implementation
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    const targetPanX = -(clickX / this.minimapWidth - 0.5) * canvasRect.width
    const targetPanY = -(clickY / this.minimapHeight - 0.5) * canvasRect.height
    
    this.panXValue = targetPanX
    this.panYValue = targetPanY
    this.updateViewportTransform()
  }

  handleMinimapDrag(event) {
    // Implement minimap dragging if needed
  }

  // Animation management
  startAnimations() {
    if (!this.enableAnimationsValue) return
    this.startFlowAnimations()
  }

  startFlowAnimations() {
    // Flow animations are handled via SVG animations
    // Additional JavaScript animations can be added here if needed
  }

  stopAnimations() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
      this.animationFrame = null
    }
  }

  // Update stage status indicators
  updateStageStatusIndicators() {
    if (this.hasStatusIndicatorsTarget) {
      const counts = { active: 0, completed: 0, error: 0, warning: 0, scheduled: 0 }
      
      this.stagesValue.forEach(stage => {
        if (stage.status && counts.hasOwnProperty(stage.status)) {
          counts[stage.status]++
        }
      })
      
      this.statusIndicatorsTarget.innerHTML = `
        <div class="flex items-center space-x-4 text-sm text-gray-600">
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-green-400 rounded-full"></div>
            <span>Active: ${counts.active}</span>
          </div>
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-green-600 rounded-full"></div>
            <span>Completed: ${counts.completed}</span>
          </div>
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-red-500 rounded-full"></div>
            <span>Errors: ${counts.error}</span>
          </div>
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-yellow-400 rounded-full"></div>
            <span>Warnings: ${counts.warning}</span>
          </div>
        </div>
      `
    }
  }

  // Update validation error display
  updateValidationErrors(errors) {
    if (this.hasValidationErrorsTarget) {
      if (errors.length === 0) {
        this.validationErrorsTarget.innerHTML = ''
        return
      }
      
      const errorsHTML = errors.map(error => `
        <div class="flex items-start space-x-2 p-3 bg-red-50 border border-red-200 rounded-lg">
          <svg class="w-4 h-4 text-red-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
          </svg>
          <div>
            <p class="text-sm font-medium text-red-800">${error.message}</p>
            ${error.stage ? `<p class="text-xs text-red-600 mt-1">Stage: ${error.stage.name}</p>` : ''}
          </div>
        </div>
      `).join('')
      
      this.validationErrorsTarget.innerHTML = errorsHTML
    }
  }

  // Canvas dimension management
  updateCanvasDimensions() {
    if (this.hasSvgTarget) {
      const rect = this.canvasTarget.getBoundingClientRect()
      this.svgTarget.setAttribute('width', rect.width)
      this.svgTarget.setAttribute('height', rect.height)
      this.svgTarget.setAttribute('viewBox', `0 0 ${rect.width} ${rect.height}`)
    }
  }

  // Event dispatching
  dispatchStageEvent(eventName, detail) {
    this.dispatch(eventName, { detail })
  }

  // Cleanup
  cleanup() {
    this.stopAnimations()
    
    // Remove event listeners
    window.removeEventListener('resize', this.handleResize)
    document.removeEventListener('keydown', this.handleKeyDown)
    
    if (this.minimapCanvasTarget) {
      this.minimapCanvasTarget.removeEventListener('click', this.handleMinimapClick)
      this.minimapCanvasTarget.removeEventListener('mousedown', this.handleMinimapDrag)
    }
  }

  // Public API for external updates
  updateStages(stages) {
    this.stagesValue = stages
    this.renderStages()
  }

  updateConnections(connections) {
    this.connectionsValue = connections
    this.renderConnections()
  }

  setStageStatus(stageId, status, progress = null) {
    const stage = this.stagesValue.find(s => s.id === stageId)
    if (stage) {
      stage.status = status
      if (progress !== null) stage.progress = progress
      this.renderStages()
      this.updateStageStatusIndicators()
    }
  }

  addValidationError(stageId, error) {
    const stage = this.stagesValue.find(s => s.id === stageId)
    if (stage) {
      if (!stage.validation) stage.validation = []
      stage.validation.push(error)
      this.renderStages()
    }
  }

  clearValidationErrors(stageId) {
    const stage = this.stagesValue.find(s => s.id === stageId)
    if (stage) {
      stage.validation = []
      this.renderStages()
    }
  }

  // Toggle minimap visibility
  toggleMinimap() {
    this.showMinimapValue = !this.showMinimapValue
    if (this.showMinimapValue) {
      this.renderMinimap()
    }
  }

  // Enable/disable animations
  toggleAnimations() {
    this.enableAnimationsValue = !this.enableAnimationsValue
    if (this.enableAnimationsValue) {
      this.startAnimations()
    } else {
      this.stopAnimations()
    }
    this.renderConnections()
  }
}