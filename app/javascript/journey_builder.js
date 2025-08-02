// Journey Builder JavaScript Components
// Handles drag-and-drop, canvas interactions, and step management

class JourneyBuilder {
  constructor() {
    this.canvas = document.getElementById('journey-canvas');
    this.flowContainer = document.getElementById('journey-flow');
    this.propertiesPanel = document.getElementById('properties-panel');
    this.selectedStep = null;
    this.draggedElement = null;
    this.steps = new Map();
    this.connections = new Map();
    
    this.init();
  }
  
  init() {
    this.setupDragAndDrop();
    this.setupCanvasInteractions();
    this.setupStepInteractions();
    this.setupPropertiesPanel();
    this.loadExistingSteps();
  }
  
  // Drag and Drop Setup
  setupDragAndDrop() {
    // Setup draggable step types from palette
    const stepTypes = document.querySelectorAll('.step-type[draggable="true"]');
    stepTypes.forEach(stepType => {
      stepType.addEventListener('dragstart', this.handleDragStart.bind(this));
      stepType.addEventListener('dragend', this.handleDragEnd.bind(this));
    });
    
    // Setup canvas as drop zone
    this.canvas.addEventListener('dragover', this.handleDragOver.bind(this));
    this.canvas.addEventListener('drop', this.handleDrop.bind(this));
    this.canvas.addEventListener('dragenter', this.handleDragEnter.bind(this));
    this.canvas.addEventListener('dragleave', this.handleDragLeave.bind(this));
  }
  
  handleDragStart(e) {
    this.draggedElement = e.target;
    e.dataTransfer.setData('text/plain', '');
    e.dataTransfer.effectAllowed = 'copy';
    
    // Add visual feedback
    e.target.style.opacity = '0.5';
    this.canvas.classList.add('canvas-drop-zone');
  }
  
  handleDragEnd(e) {
    // Clean up visual feedback
    e.target.style.opacity = '';
    this.canvas.classList.remove('canvas-drop-zone', 'drag-over');
    this.draggedElement = null;
  }
  
  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
  }
  
  handleDragEnter(e) {
    e.preventDefault();
    this.canvas.classList.add('drag-over');
  }
  
  handleDragLeave(e) {
    // Only remove if leaving the canvas entirely
    if (!this.canvas.contains(e.relatedTarget)) {
      this.canvas.classList.remove('drag-over');
    }
  }
  
  handleDrop(e) {
    e.preventDefault();
    this.canvas.classList.remove('canvas-drop-zone', 'drag-over');
    
    if (!this.draggedElement) {return;}
    
    // Get drop position relative to canvas
    const rect = this.canvas.getBoundingClientRect();
    const x = e.clientX - rect.left + this.canvas.scrollLeft;
    const y = e.clientY - rect.top + this.canvas.scrollTop;
    
    // Create new step at drop position
    this.createStep(
      this.draggedElement.dataset.stepType,
      this.draggedElement.dataset.stage,
      { x: Math.max(50, x - 80), y: Math.max(50, y - 40) }
    );
  }
  
  // Step Management
  createStep(stepType, stage, position) {
    const stepId = this.generateStepId();
    const stepElement = this.createStepElement(stepId, stepType, stage, position);
    
    this.flowContainer.appendChild(stepElement);
    this.steps.set(stepId, {
      id: stepId,
      type: stepType,
      stage,
      position,
      element: stepElement,
      data: this.getDefaultStepData(stepType)
    });
    
    // Select the new step
    this.selectStep(stepId);
    
    return stepId;
  }
  
  createStepElement(stepId, stepType, stage, position) {
    const stepElement = document.createElement('div');
    stepElement.className = 'journey-step';
    stepElement.dataset.stepId = stepId;
    stepElement.dataset.stage = stage;
    stepElement.style.left = `${position.x}px`;
    stepElement.style.top = `${position.y}px`;
    
    const stageColors = {
      awareness: { primary: '#3b82f6', bg: '#eff6ff' },
      consideration: { primary: '#10b981', bg: '#ecfdf5' },
      conversion: { primary: '#f59e0b', bg: '#fffbeb' },
      retention: { primary: '#8b5cf6', bg: '#f5f3ff' }
    };
    
    const color = stageColors[stage] || stageColors.awareness;
    const stepData = this.getDefaultStepData(stepType);
    
    stepElement.innerHTML = `
      <div class="journey-step-card">
        <div class="w-32 bg-white rounded-lg shadow-md border border-gray-200 hover:shadow-lg transition-shadow">
          <div class="px-3 py-2 rounded-t-lg text-white" style="background-color: ${color.primary}">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-1">
                ${this.getStepIcon(stepType)}
                <span class="text-xs font-medium">${this.getStepTypeLabel(stepType)}</span>
              </div>
              <button class="text-white/80 hover:text-white step-delete-btn" onclick="journeyBuilder.deleteStep('${stepId}')">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>
          <div class="p-3">
            <p class="text-xs font-medium text-gray-900 mb-1">${stepData.title}</p>
            <p class="text-xs text-gray-500">${stepData.description}</p>
            <div class="mt-2 flex items-center space-x-1 text-xs text-gray-400">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <span>${stepData.timing}</span>
            </div>
          </div>
        </div>
      </div>
    `;
    
    // Make step draggable
    stepElement.draggable = true;
    stepElement.addEventListener('dragstart', this.handleStepDragStart.bind(this));
    stepElement.addEventListener('dragend', this.handleStepDragEnd.bind(this));
    
    return stepElement;
  }
  
  // Canvas Interactions
  setupCanvasInteractions() {
    this.canvas.addEventListener('click', (e) => {
      // Deselect step if clicking on empty canvas
      if (e.target === this.canvas || e.target === this.flowContainer) {
        this.deselectStep();
      }
    });
  }
  
  setupStepInteractions() {
    // Use event delegation for step clicks
    this.flowContainer.addEventListener('click', (e) => {
      const stepElement = e.target.closest('.journey-step');
      if (stepElement && stepElement.dataset.stepId) {
        e.stopPropagation();
        this.selectStep(stepElement.dataset.stepId);
      }
    });
  }
  
  // Step Selection
  selectStep(stepId) {
    // Deselect previous step
    this.deselectStep();
    
    const step = this.steps.get(stepId);
    if (!step) {return;}
    
    this.selectedStep = stepId;
    step.element.classList.add('selected');
    this.updatePropertiesPanel(step);
  }
  
  deselectStep() {
    if (this.selectedStep) {
      const step = this.steps.get(this.selectedStep);
      if (step) {
        step.element.classList.remove('selected');
      }
      this.selectedStep = null;
      this.showNoSelectionState();
    }
  }
  
  deleteStep(stepId) {
    const step = this.steps.get(stepId);
    if (!step) {return;}
    
    // Remove from DOM
    step.element.remove();
    
    // Remove from data structure
    this.steps.delete(stepId);
    
    // Remove any connections
    this.removeStepConnections(stepId);
    
    // Deselect if this was the selected step
    if (this.selectedStep === stepId) {
      this.deselectStep();
    }
  }
  
  // Properties Panel
  setupPropertiesPanel() {
    const form = this.propertiesPanel.querySelector('#step-properties');
    if (form) {
      form.addEventListener('submit', this.handlePropertiesSubmit.bind(this));
      
      // Live updates
      const inputs = form.querySelectorAll('input, select, textarea');
      inputs.forEach(input => {
        input.addEventListener('change', this.handlePropertyChange.bind(this));
      });
    }
  }
  
  updatePropertiesPanel(step) {
    const noSelection = document.getElementById('no-selection');
    const stepProperties = document.getElementById('step-properties');
    
    if (noSelection) {noSelection.classList.add('hidden');}
    if (stepProperties) {
      stepProperties.classList.remove('hidden');
      this.populatePropertiesForm(step);
    }
  }
  
  showNoSelectionState() {
    const noSelection = document.getElementById('no-selection');
    const stepProperties = document.getElementById('step-properties');
    
    if (noSelection) {noSelection.classList.remove('hidden');}
    if (stepProperties) {stepProperties.classList.add('hidden');}
  }
  
  populatePropertiesForm(step) {
    const form = document.getElementById('step-properties');
    if (!form) {return;}
    
    // Populate form fields with step data
    const nameInput = form.querySelector('#step-name');
    const descInput = form.querySelector('#step-description');
    const stageSelect = form.querySelector('#step-stage');
    const timingSelect = form.querySelector('#step-timing');
    
    if (nameInput) {nameInput.value = step.data.title || '';}
    if (descInput) {descInput.value = step.data.description || '';}
    if (stageSelect) {stageSelect.value = step.stage || '';}
    if (timingSelect) {timingSelect.value = step.data.timing || 'immediate';}
    
    // Populate step-type specific fields
    this.populateStepTypeFields(form, step);
  }
  
  populateStepTypeFields(form, step) {
    // Handle email-specific fields
    const emailSubject = form.querySelector('#email-subject');
    const emailTemplate = form.querySelector('#email-template');
    
    if (step.type === 'email_sequence' || step.type === 'newsletter') {
      if (emailSubject) {emailSubject.value = step.data.subject || '';}
      if (emailTemplate) {emailTemplate.value = step.data.template || '';}
    }
  }
  
  handlePropertyChange(e) {
    if (!this.selectedStep) {return;}
    
    const step = this.steps.get(this.selectedStep);
    if (!step) {return;}
    
    const field = e.target.name || e.target.id;
    const value = e.target.value;
    
    // Update step data
    this.updateStepProperty(step, field, value);
    
    // Update visual representation if needed
    this.updateStepVisual(step);
  }
  
  updateStepProperty(step, field, value) {
    switch (field) {
      case 'step-name':
        step.data.title = value;
        break;
      case 'step-description':
        step.data.description = value;
        break;
      case 'step-stage':
        step.stage = value;
        step.element.dataset.stage = value;
        break;
      case 'step-timing':
        step.data.timing = value;
        break;
      case 'email-subject':
        step.data.subject = value;
        break;
      case 'email-template':
        step.data.template = value;
        break;
    }
  }
  
  updateStepVisual(step) {
    const titleElement = step.element.querySelector('.text-xs.font-medium.text-gray-900');
    const descElement = step.element.querySelector('.text-xs.text-gray-500');
    const timingElement = step.element.querySelector('.text-xs.text-gray-400 span');
    
    if (titleElement) {titleElement.textContent = step.data.title;}
    if (descElement) {descElement.textContent = step.data.description;}
    if (timingElement) {timingElement.textContent = step.data.timing;}
  }
  
  // Step Movement (for existing steps)
  handleStepDragStart(e) {
    const stepElement = e.target.closest('.journey-step');
    if (!stepElement) {return;}
    
    this.draggedStep = stepElement.dataset.stepId;
    stepElement.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
  }
  
  handleStepDragEnd(e) {
    const stepElement = e.target.closest('.journey-step');
    if (stepElement) {
      stepElement.classList.remove('dragging');
    }
    this.draggedStep = null;
  }
  
  // Utility Functions
  generateStepId() {
    return `step_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
  
  getStepIcon(stepType) {
    const icons = {
      blog_post: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/></svg>',
      email_sequence: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>',
      social_media: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 0h10m-10 0a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V6a2 2 0 00-2-2"/></svg>',
      webinar: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>',
      sales_call: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/></svg>'
    };
    return icons[stepType] || icons.email_sequence;
  }
  
  getStepTypeLabel(stepType) {
    const labels = {
      blog_post: 'Blog Post',
      email_sequence: 'Email',
      social_media: 'Social Media',
      webinar: 'Webinar',
      sales_call: 'Sales Call',
      lead_magnet: 'Lead Magnet',
      case_study: 'Case Study',
      demo: 'Demo',
      trial_offer: 'Free Trial',
      onboarding: 'Onboarding',
      newsletter: 'Newsletter',
      feedback_survey: 'Survey'
    };
    return labels[stepType] || 'Step';
  }
  
  getDefaultStepData(stepType) {
    const defaults = {
      blog_post: {
        title: 'Blog Post',
        description: 'Educational content',
        timing: 'Immediate'
      },
      email_sequence: {
        title: 'Email Sequence',
        description: 'Nurture email',
        timing: 'Immediate',
        subject: 'Welcome to our community!'
      },
      social_media: {
        title: 'Social Media',
        description: 'Social engagement',
        timing: 'Immediate'
      },
      webinar: {
        title: 'Webinar',
        description: 'Educational presentation',
        timing: '1 week'
      },
      sales_call: {
        title: 'Sales Call',
        description: 'Personal consultation',
        timing: '3 days'
      }
    };
    
    return defaults[stepType] || {
      title: 'New Step',
      description: 'Configure this step',
      timing: 'Immediate'
    };
  }
  
  // Load existing steps (for editing existing templates)
  loadExistingSteps() {
    // This would load existing template data if editing
    // For now, just ensure the canvas is ready
    console.log('Journey Builder initialized');
  }
  
  // Save/Export functionality
  exportJourneyData() {
    const journeyData = {
      steps: Array.from(this.steps.values()).map(step => ({
        id: step.id,
        type: step.type,
        stage: step.stage,
        position: step.position,
        data: step.data
      })),
      connections: Array.from(this.connections.values())
    };
    
    return journeyData;
  }
  
  // Connection management (basic implementation)
  removeStepConnections(stepId) {
    // Remove any connections involving this step
    for (const [connectionId, connection] of this.connections.entries()) {
      if (connection.from === stepId || connection.to === stepId) {
        this.connections.delete(connectionId);
      }
    }
  }
}

// Initialize journey builder when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('journey-canvas')) {
    window.journeyBuilder = new JourneyBuilder();
  }
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = JourneyBuilder;
}