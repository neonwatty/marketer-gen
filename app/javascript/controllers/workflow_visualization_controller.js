import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="workflow-visualization"
export default class extends Controller {
  static targets = [
    "flowchartView", "timelineView", "viewToggle", "zoomLevel", 
    "canvas", "flowChart", "nodeDetails", "nodeTitle", "nodeContent"
  ]
  static values = { 
    campaignId: String, 
    currentStatus: String,
    workflowUrl: String
  }

  connect() {
    console.log("Workflow visualization controller connected")
    this.currentView = "flowchart"
    this.zoomLevel = 100
    this.selectedNode = null
    
    // Initialize the visualization
    this.initializeVisualization()
    
    // Setup keyboard navigation
    this.setupKeyboardNavigation()
    
    // Setup pan and zoom
    this.setupPanZoom()
  }

  // Initialize workflow visualization
  initializeVisualization() {
    // Set initial view
    this.showFlowchartView()
    
    // Load workflow data
    this.loadWorkflowData()
    
    // Setup interactive elements
    this.setupInteractivity()
  }

  // Toggle between flowchart and timeline views
  toggleView(event) {
    const view = event.target.dataset.view
    
    // Update toggle buttons
    this.viewToggleTargets.forEach(button => {
      if (button.dataset.view === view) {
        button.className = button.className.replace(/bg-white text-gray-700/, 'bg-blue-600 text-white')
      } else {
        button.className = button.className.replace(/bg-blue-600 text-white/, 'bg-white text-gray-700')
      }
    })
    
    // Show the selected view
    if (view === "flowchart") {
      this.showFlowchartView()
    } else {
      this.showTimelineView()
    }
    
    this.currentView = view
  }

  // Show flowchart view
  showFlowchartView() {
    if (this.hasFlowchartViewTarget) {
      this.flowchartViewTarget.classList.remove('hidden')
    }
    if (this.hasTimelineViewTarget) {
      this.timelineViewTarget.classList.add('hidden')
    }
  }

  // Show timeline view
  showTimelineView() {
    if (this.hasTimelineViewTarget) {
      this.timelineViewTarget.classList.remove('hidden')
    }
    if (this.hasFlowchartViewTarget) {
      this.flowchartViewTarget.classList.add('hidden')
    }
  }

  // Zoom in
  zoomIn() {
    if (this.zoomLevel < 200) {
      this.zoomLevel += 25
      this.updateZoom()
    }
  }

  // Zoom out
  zoomOut() {
    if (this.zoomLevel > 50) {
      this.zoomLevel -= 25
      this.updateZoom()
    }
  }

  // Update zoom level
  updateZoom() {
    if (this.hasZoomLevelTarget) {
      this.zoomLevelTarget.textContent = `${this.zoomLevel}%`
    }
    
    if (this.hasFlowChartTarget) {
      this.flowChartTarget.style.transform = `scale(${this.zoomLevel / 100})`
    }
  }

  // Select a workflow node
  selectNode(event) {
    const node = event.currentTarget
    const nodeId = node.dataset.nodeId
    const nodeType = node.dataset.nodeType
    
    // Remove previous selection
    if (this.selectedNode) {
      this.selectedNode.classList.remove('ring-4', 'ring-blue-200')
    }
    
    // Add selection to new node
    node.classList.add('ring-4', 'ring-blue-200')
    this.selectedNode = node
    
    // Show node details
    this.showNodeDetails(nodeId, nodeType)
  }

  // Show details for selected node
  async showNodeDetails(nodeId, nodeType) {
    if (!this.hasNodeDetailsTarget) {return}
    
    // Show the details panel
    this.nodeDetailsTarget.classList.remove('hidden')
    
    // Update title
    if (this.hasNodeTitleTarget) {
      this.nodeTitleTarget.textContent = `${nodeId.charAt(0).toUpperCase() + nodeId.slice(1)} Details`
    }
    
    // Load node content
    await this.loadNodeContent(nodeId, nodeType)
  }

  // Load content for a specific node
  async loadNodeContent(nodeId, nodeType) {
    if (!this.hasNodeContentTarget) {return}
    
    try {
      const response = await fetch(`${this.workflowUrlValue}/node/${nodeId}`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'text/html'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.nodeContentTarget.innerHTML = html
      } else {
        // Show default node information
        this.showDefaultNodeContent(nodeId, nodeType)
      }
    } catch (error) {
      console.error('Failed to load node content:', error)
      this.showDefaultNodeContent(nodeId, nodeType)
    }
  }

  // Show default node content when API fails
  showDefaultNodeContent(nodeId, _nodeType) {
    const statusInfo = {
      'draft': {
        description: 'Campaign is being prepared and configured',
        actions: ['Edit campaign details', 'Set up targeting', 'Configure budget'],
        requirements: ['Campaign name', 'Target audience', 'Budget allocation']
      },
      'active': {
        description: 'Campaign is live and actively running',
        actions: ['Monitor performance', 'Adjust budget', 'Pause if needed'],
        requirements: ['Approved content', 'Sufficient budget', 'Active targeting']
      },
      'paused': {
        description: 'Campaign activities are temporarily stopped',
        actions: ['Resume campaign', 'Review performance', 'Make adjustments'],
        requirements: ['Resolve issues', 'Update content if needed']
      },
      'completed': {
        description: 'Campaign has finished and achieved its goals',
        actions: ['Review final metrics', 'Generate reports', 'Archive campaign'],
        requirements: ['Final approval', 'Performance documentation']
      },
      'archived': {
        description: 'Campaign is stored for future reference',
        actions: ['View historical data', 'Create new campaign from template'],
        requirements: ['Historical preservation', 'Data backup']
      }
    }
    
    const info = statusInfo[nodeId] || {
      description: 'Node information not available',
      actions: [],
      requirements: []
    }
    
    this.nodeContentTarget.innerHTML = `
      <div class="space-y-4">
        <div>
          <h6 class="text-sm font-medium text-gray-900 mb-2">Description</h6>
          <p class="text-sm text-gray-600">${info.description}</p>
        </div>
        
        ${info.actions.length > 0 ? `
          <div>
            <h6 class="text-sm font-medium text-gray-900 mb-2">Available Actions</h6>
            <ul class="text-sm text-gray-600 space-y-1">
              ${info.actions.map(action => `<li>• ${action}</li>`).join('')}
            </ul>
          </div>
        ` : ''}
        
        ${info.requirements.length > 0 ? `
          <div>
            <h6 class="text-sm font-medium text-gray-900 mb-2">Requirements</h6>
            <ul class="text-sm text-gray-600 space-y-1">
              ${info.requirements.map(req => `<li>• ${req}</li>`).join('')}
            </ul>
          </div>
        ` : ''}
      </div>
    `
  }

  // Close node details panel
  closeNodeDetails() {
    if (this.hasNodeDetailsTarget) {
      this.nodeDetailsTarget.classList.add('hidden')
    }
    
    // Remove selection from node
    if (this.selectedNode) {
      this.selectedNode.classList.remove('ring-4', 'ring-blue-200')
      this.selectedNode = null
    }
  }

  // Load workflow data from server
  async loadWorkflowData() {
    if (!this.workflowUrlValue) {return}
    
    try {
      const response = await fetch(`${this.workflowUrlValue}/data`, {
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.updateWorkflowDisplay(data)
      }
    } catch (error) {
      console.error('Failed to load workflow data:', error)
    }
  }

  // Update workflow display with fresh data
  updateWorkflowDisplay(data) {
    // Update node states based on current data
    const nodes = this.element.querySelectorAll('[data-node-id]')
    
    nodes.forEach(node => {
      const nodeId = node.dataset.nodeId
      const nodeData = data.nodes?.[nodeId]
      
      if (nodeData) {
        this.updateNodeAppearance(node, nodeData)
      }
    })
    
    // Update statistics if available
    if (data.stats) {
      this.updateWorkflowStats(data.stats)
    }
  }

  // Update individual node appearance
  updateNodeAppearance(node, nodeData) {
    const nodeCircle = node.querySelector('.w-20.h-20, .w-16.h-16')
    if (!nodeCircle) {return}
    
    // Remove existing classes
    nodeCircle.classList.remove(
      'bg-blue-600', 'bg-green-600', 'bg-gray-300', 'bg-purple-600',
      'text-white', 'text-gray-600', 'ring-4', 'ring-blue-200'
    )
    
    // Apply new classes based on state
    if (nodeData.current) {
      nodeCircle.classList.add('bg-blue-600', 'text-white', 'ring-4', 'ring-blue-200')
    } else if (nodeData.completed) {
      nodeCircle.classList.add('bg-green-600', 'text-white')
    } else {
      nodeCircle.classList.add('bg-gray-300', 'text-gray-600')
    }
  }

  // Update workflow statistics
  updateWorkflowStats(stats) {
    // This would update the stats cards at the top
    const statsMapping = {
      'completed_steps': stats.completedSteps,
      'pending_steps': stats.pendingSteps,
      'progress': stats.progress,
      'estimated_completion': stats.estimatedCompletion
    }
    
    Object.entries(statsMapping).forEach(([key, value]) => {
      const element = this.element.querySelector(`[data-stat="${key}"]`)
      if (element && value !== undefined) {
        element.textContent = value
      }
    })
  }

  // Setup keyboard navigation
  setupKeyboardNavigation() {
    document.addEventListener('keydown', (event) => {
      if (!this.element.contains(document.activeElement)) {return}
      
      switch (event.key) {
        case 'Escape':
          this.closeNodeDetails()
          break
        case 'ArrowLeft':
          this.navigateNode('left')
          break
        case 'ArrowRight':
          this.navigateNode('right')
          break
        case '+':
        case '=':
          event.preventDefault()
          this.zoomIn()
          break
        case '-':
          event.preventDefault()
          this.zoomOut()
          break
      }
    })
  }

  // Navigate between nodes using keyboard
  navigateNode(direction) {
    const nodes = Array.from(this.element.querySelectorAll('[data-node-id]'))
    if (nodes.length === 0) {return}
    
    const currentIndex = this.selectedNode ? nodes.indexOf(this.selectedNode) : -1
    
    if (direction === 'left' && currentIndex > 0) {
      nodes[currentIndex - 1].click()
    } else if (direction === 'right' && currentIndex < nodes.length - 1) {
      nodes[currentIndex + 1].click()
    } else if (currentIndex === -1 && nodes.length > 0) {
      // Select first node if none selected
      nodes[0].click()
    }
  }

  // Setup pan and zoom functionality
  setupPanZoom() {
    if (!this.hasCanvasTarget) {return}
    
    let isPanning = false
    let startX, startY, scrollLeft, scrollTop
    
    // Mouse down - start panning
    this.canvasTarget.addEventListener('mousedown', (e) => {
      if (e.target === this.canvasTarget || e.target.closest('.workflow-node')) {return}
      
      isPanning = true
      startX = e.pageX - this.canvasTarget.offsetLeft
      startY = e.pageY - this.canvasTarget.offsetTop
      scrollLeft = this.canvasTarget.scrollLeft
      scrollTop = this.canvasTarget.scrollTop
      
      this.canvasTarget.style.cursor = 'grabbing'
    })
    
    // Mouse move - pan if active
    this.canvasTarget.addEventListener('mousemove', (e) => {
      if (!isPanning) {return}
      
      e.preventDefault()
      const x = e.pageX - this.canvasTarget.offsetLeft
      const y = e.pageY - this.canvasTarget.offsetTop
      const walkX = (x - startX) * 1
      const walkY = (y - startY) * 1
      
      this.canvasTarget.scrollLeft = scrollLeft - walkX
      this.canvasTarget.scrollTop = scrollTop - walkY
    })
    
    // Mouse up - stop panning
    document.addEventListener('mouseup', () => {
      if (isPanning) {
        isPanning = false
        this.canvasTarget.style.cursor = 'grab'
      }
    })
    
    // Mouse leave - stop panning
    this.canvasTarget.addEventListener('mouseleave', () => {
      isPanning = false
      this.canvasTarget.style.cursor = 'default'
    })
    
    // Mouse wheel - zoom
    this.canvasTarget.addEventListener('wheel', (e) => {
      if (e.ctrlKey || e.metaKey) {
        e.preventDefault()
        
        if (e.deltaY < 0) {
          this.zoomIn()
        } else {
          this.zoomOut()
        }
      }
    })
  }

  // Export workflow as image
  async exportWorkflow(_format = 'png') {
    if (!this.hasFlowChartTarget) {return}
    
    try {
      // This would integrate with a library like html2canvas
      // For now, we'll show a placeholder
      this.showExportNotification('Export functionality would be implemented here')
    } catch (error) {
      console.error('Failed to export workflow:', error)
      this.showExportNotification('Export failed')
    }
  }

  // Show export notification
  showExportNotification(message) {
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 bg-blue-600 text-white px-4 py-2 rounded-lg shadow-lg z-50'
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove()
      }
    }, 3000)
  }

  // Cleanup
  disconnect() {
    // Remove event listeners and cleanup
    if (this.selectedNode) {
      this.selectedNode.classList.remove('ring-4', 'ring-blue-200')
    }
  }
}