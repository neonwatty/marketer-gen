/**
 * Enhanced Journey Builder - Drag and Drop Journey Creation Interface
 * Provides visual journey building with step management and real-time updates
 */

class JourneyBuilderEnhanced {
  constructor() {
    this.journeyId = document.querySelector('.journey-builder-container')?.dataset.journeyId;
    this.steps = new Map();
    this.connections = new Map();
    this.selectedStep = null;
    this.canvas = document.getElementById('journey-flow');
    this.zoomLevel = 1;
    this.undoStack = [];
    this.redoStack = [];
    this.isDragging = false;
    this.hasUnsavedChanges = false;
    
    this.init();
  }
  
  init() {
    this.setupEventListeners();
    this.setupDragAndDrop();
    this.loadExistingJourney();
    this.setupKeyboardShortcuts();
    this.setupAutoSave();
  }
  
  setupEventListeners() {
    // Toolbar buttons
    document.getElementById('save-draft-btn')?.addEventListener('click', () => this.saveJourney('draft'));
    document.getElementById('publish-btn')?.addEventListener('click', () => this.saveJourney('published'));
    document.getElementById('preview-btn')?.addEventListener('click', () => this.showPreview());
    document.getElementById('ai-suggestions-btn')?.addEventListener('click', () => this.showAISuggestions());
    
    // Zoom controls
    document.getElementById('zoom-in-btn')?.addEventListener('click', () => this.zoomIn());
    document.getElementById('zoom-out-btn')?.addEventListener('click', () => this.zoomOut());
    document.getElementById('fit-to-screen-btn')?.addEventListener('click', () => this.fitToScreen());
    
    // Undo/Redo
    document.getElementById('undo-btn')?.addEventListener('click', () => this.undo());
    document.getElementById('redo-btn')?.addEventListener('click', () => this.redo());
    
    // Modal controls
    document.getElementById('close-ai-modal')?.addEventListener('click', () => this.hideAISuggestions());
    document.getElementById('close-preview-modal')?.addEventListener('click', () => this.hidePreview());
    
    // Template cards
    document.querySelectorAll('.template-card').forEach(card => {
      card.addEventListener('click', (e) => this.loadTemplate(e.target.closest('.template-card').dataset.template));
    });
    
    // Step properties form
    document.getElementById('step-properties-form')?.addEventListener('submit', (e) => {
      e.preventDefault();
      this.saveStepProperties();
    });
    
    // Delete and duplicate buttons
    document.getElementById('delete-step-btn')?.addEventListener('click', () => this.deleteSelectedStep());
    document.getElementById('duplicate-step-btn')?.addEventListener('click', () => this.duplicateSelectedStep());
    
    // Brand compliance check
    document.getElementById('check-compliance-btn')?.addEventListener('click', () => this.checkBrandCompliance());
  }
  
  setupDragAndDrop() {
    // Make step components draggable
    document.querySelectorAll('.step-component').forEach(component => {
      component.addEventListener('dragstart', (e) => this.handleDragStart(e));
    });
    
    // Canvas drop zone
    const canvas = document.getElementById('canvas-container');
    canvas.addEventListener('dragover', (e) => this.handleDragOver(e));
    canvas.addEventListener('drop', (e) => this.handleDrop(e));
    canvas.addEventListener('dragenter', (e) => this.handleDragEnter(e));
    canvas.addEventListener('dragleave', (e) => this.handleDragLeave(e));
  }
  
  handleDragStart(e) {
    const stepType = e.target.closest('.step-component').dataset.stepType;
    const stage = e.target.closest('.step-component').dataset.stage;
    
    e.dataTransfer.setData('application/json', JSON.stringify({
      stepType: stepType,
      stage: stage
    }));
    
    e.dataTransfer.effectAllowed = 'copy';
  }
  
  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
  }
  
  handleDragEnter(e) {
    e.preventDefault();
    document.getElementById('drop-zone-overlay').classList.remove('hidden');
  }
  
  handleDragLeave(e) {
    // Only hide overlay if leaving the canvas container
    if (!e.currentTarget.contains(e.relatedTarget)) {
      document.getElementById('drop-zone-overlay').classList.add('hidden');
    }
  }
  
  handleDrop(e) {
    e.preventDefault();
    document.getElementById('drop-zone-overlay').classList.add('hidden');
    
    try {
      const data = JSON.parse(e.dataTransfer.getData('application/json'));
      const rect = e.currentTarget.getBoundingClientRect();
      const x = (e.clientX - rect.left) / this.zoomLevel;
      const y = (e.clientY - rect.top) / this.zoomLevel;
      
      this.createStep(data.stepType, data.stage, { x, y });
      this.hideEmptyState();
    } catch (error) {
      console.error('Error handling drop:', error);
    }
  }
  
  createStep(stepType, stage, position) {
    const stepId = `step-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const stepData = {
      id: stepId,
      type: stepType,
      stage: stage,
      name: this.getStepTypeName(stepType),
      description: '',
      position: position,
      config: this.getDefaultStepConfig(stepType),
      conditions: {},
      metadata: {}
    };
    
    this.steps.set(stepId, stepData);
    this.renderStep(stepData);
    this.markUnsavedChanges();
    this.pushToUndoStack();
    
    // Auto-select the new step
    this.selectStep(stepId);
  }
  
  renderStep(stepData) {
    const stepElement = document.createElement('div');
    stepElement.className = 'journey-step-node';
    stepElement.dataset.stepId = stepData.id;
    stepElement.style.left = `${stepData.position.x}px`;
    stepElement.style.top = `${stepData.position.y}px`;
    
    const stageColors = {
      awareness: 'blue',
      consideration: 'green', 
      conversion: 'amber',
      retention: 'purple',
      advocacy: 'pink'
    };
    
    const color = stageColors[stepData.stage] || 'gray';
    
    stepElement.innerHTML = `
      <div class="journey-step-card bg-white rounded-lg shadow-md border border-${color}-200 hover:shadow-lg transition-all duration-200 cursor-move">
        <div class="bg-${color}-500 text-white px-4 py-2 rounded-t-lg">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-2">
              ${this.getStepIcon(stepData.type)}
              <span class="text-sm font-medium">${stepData.name}</span>
            </div>
            <button class="step-delete-btn text-${color}-200 hover:text-white p-1 rounded">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
        <div class="p-4">
          <p class="text-sm text-gray-600 mb-2">${stepData.description || 'Click to add description'}</p>
          <div class="flex items-center justify-between text-xs text-gray-500">
            <span class="inline-flex items-center px-2 py-1 rounded-full bg-${color}-100 text-${color}-800">
              ${stepData.stage}
            </span>
            <div class="flex items-center space-x-1">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <span>${stepData.config?.timing || 'Immediate'}</span>
            </div>
          </div>
        </div>
      </div>
    `;
    
    // Add event listeners
    stepElement.addEventListener('click', (e) => {
      e.stopPropagation();
      this.selectStep(stepData.id);
    });
    
    stepElement.addEventListener('mousedown', (e) => this.startDragStep(e, stepData.id));
    
    stepElement.querySelector('.step-delete-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      this.deleteStep(stepData.id);
    });
    
    this.canvas.appendChild(stepElement);
  }
  
  startDragStep(e, stepId) {
    if (e.target.closest('.step-delete-btn')) return;
    
    this.isDragging = true;
    this.selectStep(stepId);
    
    const stepElement = document.querySelector(`[data-step-id="${stepId}"]`);
    const rect = stepElement.getBoundingClientRect();
    const canvasRect = this.canvas.getBoundingClientRect();
    
    const offsetX = e.clientX - rect.left;
    const offsetY = e.clientY - rect.top;
    
    const handleMouseMove = (e) => {
      if (!this.isDragging) return;
      
      const newX = (e.clientX - canvasRect.left - offsetX) / this.zoomLevel;
      const newY = (e.clientY - canvasRect.top - offsetY) / this.zoomLevel;
      
      stepElement.style.left = `${newX}px`;
      stepElement.style.top = `${newY}px`;
      
      this.steps.get(stepId).position = { x: newX, y: newY };
      this.markUnsavedChanges();
    };
    
    const handleMouseUp = () => {
      this.isDragging = false;
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
      this.pushToUndoStack();
    };
    
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
    
    e.preventDefault();
  }
  
  selectStep(stepId) {
    // Remove previous selection
    document.querySelectorAll('.journey-step-node').forEach(node => {
      node.classList.remove('selected');
    });
    
    // Add selection to new step
    const stepElement = document.querySelector(`[data-step-id="${stepId}"]`);
    if (stepElement) {
      stepElement.classList.add('selected');
      this.selectedStep = stepId;
      this.showStepProperties(stepId);
    }
  }
  
  showStepProperties(stepId) {
    const stepData = this.steps.get(stepId);
    if (!stepData) return;
    
    // Hide no-selection state
    document.getElementById('no-selection-state').classList.add('hidden');
    document.getElementById('step-properties-form').classList.remove('hidden');
    
    // Populate form fields
    document.getElementById('step-name').value = stepData.name || '';
    document.getElementById('step-description').value = stepData.description || '';
    document.getElementById('step-stage').value = stepData.stage || 'awareness';
    document.getElementById('step-channel').value = stepData.config?.channel || 'email';
    document.getElementById('step-timing').value = stepData.config?.timing || 'immediate';
    
    // Show dynamic content settings based on step type
    this.updateContentSettings(stepData.type);
    
    // Update brand compliance status if available
    this.updateBrandComplianceStatus(stepData);
  }
  
  updateContentSettings(stepType) {
    const contentSettings = document.getElementById('content-settings');
    let html = '';
    
    switch (stepType) {
      case 'email_sequence':
        html = `
          <div>
            <label for="email-subject" class="block text-sm font-medium text-gray-700">Email Subject</label>
            <input type="text" id="email-subject" name="email-subject" 
                   class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                   placeholder="Enter email subject line">
          </div>
          <div>
            <label for="email-template" class="block text-sm font-medium text-gray-700">Email Template</label>
            <select id="email-template" name="email-template" 
                    class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm">
              <option value="">Choose template...</option>
              <option value="welcome">Welcome Email</option>
              <option value="newsletter">Newsletter</option>
              <option value="promotional">Promotional</option>
            </select>
          </div>
        `;
        break;
      case 'blog_post':
        html = `
          <div>
            <label for="blog-title" class="block text-sm font-medium text-gray-700">Blog Post Title</label>
            <input type="text" id="blog-title" name="blog-title" 
                   class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                   placeholder="Enter blog post title">
          </div>
          <div>
            <label for="blog-topic" class="block text-sm font-medium text-gray-700">Topic/Category</label>
            <input type="text" id="blog-topic" name="blog-topic" 
                   class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                   placeholder="e.g., Marketing Tips, Product Updates">
          </div>
        `;
        break;
      case 'social_media':
        html = `
          <div>
            <label for="social-platform" class="block text-sm font-medium text-gray-700">Platform</label>
            <select id="social-platform" name="social-platform" 
                    class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm">
              <option value="facebook">Facebook</option>
              <option value="instagram">Instagram</option>
              <option value="twitter">Twitter</option>
              <option value="linkedin">LinkedIn</option>
            </select>
          </div>
          <div>
            <label for="social-content" class="block text-sm font-medium text-gray-700">Post Content</label>
            <textarea id="social-content" name="social-content" rows="3" 
                      class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                      placeholder="Enter social media post content"></textarea>
          </div>
        `;
        break;
      case 'webinar':
        html = `
          <div>
            <label for="webinar-title" class="block text-sm font-medium text-gray-700">Webinar Title</label>
            <input type="text" id="webinar-title" name="webinar-title" 
                   class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                   placeholder="Enter webinar title">
          </div>
          <div>
            <label for="webinar-duration" class="block text-sm font-medium text-gray-700">Duration (minutes)</label>
            <input type="number" id="webinar-duration" name="webinar-duration" 
                   class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                   placeholder="60" min="15" max="180">
          </div>
        `;
        break;
      default:
        html = `
          <div>
            <label for="generic-content" class="block text-sm font-medium text-gray-700">Content</label>
            <textarea id="generic-content" name="generic-content" rows="3" 
                      class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                      placeholder="Enter content details"></textarea>
          </div>
        `;
    }
    
    contentSettings.innerHTML = html;
  }
  
  saveStepProperties() {
    if (!this.selectedStep) return;
    
    const stepData = this.steps.get(this.selectedStep);
    if (!stepData) return;
    
    // Update step data
    stepData.name = document.getElementById('step-name').value;
    stepData.description = document.getElementById('step-description').value;
    stepData.stage = document.getElementById('step-stage').value;
    
    stepData.config = stepData.config || {};
    stepData.config.channel = document.getElementById('step-channel').value;
    stepData.config.timing = document.getElementById('step-timing').value;
    
    // Update conditions
    stepData.conditions = {
      opened: document.getElementById('condition-opened')?.checked || false,
      clicked: document.getElementById('condition-clicked')?.checked || false,
      visited: document.getElementById('condition-visited')?.checked || false
    };
    
    // Update step-specific content
    this.saveStepSpecificContent(stepData);
    
    // Re-render the step
    this.reRenderStep(this.selectedStep);
    this.markUnsavedChanges();
    this.pushToUndoStack();
    
    this.showNotification('Step properties saved successfully', 'success');
  }
  
  saveStepSpecificContent(stepData) {
    const contentConfig = stepData.config.content = stepData.config.content || {};
    
    switch (stepData.type) {
      case 'email_sequence':
        contentConfig.subject = document.getElementById('email-subject')?.value || '';
        contentConfig.template = document.getElementById('email-template')?.value || '';
        break;
      case 'blog_post':
        contentConfig.title = document.getElementById('blog-title')?.value || '';
        contentConfig.topic = document.getElementById('blog-topic')?.value || '';
        break;
      case 'social_media':
        contentConfig.platform = document.getElementById('social-platform')?.value || '';
        contentConfig.content = document.getElementById('social-content')?.value || '';
        break;
      case 'webinar':
        contentConfig.title = document.getElementById('webinar-title')?.value || '';
        contentConfig.duration = parseInt(document.getElementById('webinar-duration')?.value) || 60;
        break;
      default:
        contentConfig.content = document.getElementById('generic-content')?.value || '';
    }
  }
  
  reRenderStep(stepId) {
    const stepElement = document.querySelector(`[data-step-id="${stepId}"]`);
    const stepData = this.steps.get(stepId);
    
    if (stepElement && stepData) {
      stepElement.remove();
      this.renderStep(stepData);
      
      // Re-select the step
      setTimeout(() => this.selectStep(stepId), 50);
    }
  }
  
  deleteStep(stepId) {
    if (confirm('Are you sure you want to delete this step?')) {
      const stepElement = document.querySelector(`[data-step-id="${stepId}"]`);
      if (stepElement) {
        stepElement.remove();
      }
      
      this.steps.delete(stepId);
      
      if (this.selectedStep === stepId) {
        this.selectedStep = null;
        this.hideStepProperties();
      }
      
      this.markUnsavedChanges();
      this.pushToUndoStack();
      
      if (this.steps.size === 0) {
        this.showEmptyState();
      }
    }
  }
  
  deleteSelectedStep() {
    if (this.selectedStep) {
      this.deleteStep(this.selectedStep);
    }
  }
  
  duplicateSelectedStep() {
    if (!this.selectedStep) return;
    
    const originalStep = this.steps.get(this.selectedStep);
    if (!originalStep) return;
    
    const duplicatedStep = {
      ...originalStep,
      id: `step-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      name: `${originalStep.name} (Copy)`,
      position: {
        x: originalStep.position.x + 50,
        y: originalStep.position.y + 50
      }
    };
    
    this.steps.set(duplicatedStep.id, duplicatedStep);
    this.renderStep(duplicatedStep);
    this.selectStep(duplicatedStep.id);
    this.markUnsavedChanges();
    this.pushToUndoStack();
  }
  
  hideStepProperties() {
    document.getElementById('no-selection-state').classList.remove('hidden');
    document.getElementById('step-properties-form').classList.add('hidden');
  }
  
  // Canvas click to deselect
  setupCanvasClickToDeselect() {
    this.canvas.addEventListener('click', (e) => {
      if (e.target === this.canvas || e.target.id === 'canvas-container') {
        this.selectedStep = null;
        document.querySelectorAll('.journey-step-node').forEach(node => {
          node.classList.remove('selected');
        });
        this.hideStepProperties();
      }
    });
  }
  
  // Zoom functionality
  zoomIn() {
    this.zoomLevel = Math.min(this.zoomLevel * 1.1, 3);
    this.applyZoom();
  }
  
  zoomOut() {
    this.zoomLevel = Math.max(this.zoomLevel * 0.9, 0.1);
    this.applyZoom();
  }
  
  applyZoom() {
    this.canvas.style.transform = `scale(${this.zoomLevel})`;
    this.canvas.style.transformOrigin = '50% 50%';
    document.getElementById('zoom-level').textContent = `${Math.round(this.zoomLevel * 100)}%`;
  }
  
  fitToScreen() {
    if (this.steps.size === 0) {
      this.zoomLevel = 1;
      this.applyZoom();
      return;
    }
    
    const canvasRect = document.getElementById('canvas-container').getBoundingClientRect();
    const stepElements = document.querySelectorAll('.journey-step-node');
    
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    
    stepElements.forEach(element => {
      const rect = element.getBoundingClientRect();
      minX = Math.min(minX, rect.left);
      minY = Math.min(minY, rect.top);
      maxX = Math.max(maxX, rect.right);
      maxY = Math.max(maxY, rect.bottom);
    });
    
    const contentWidth = maxX - minX;
    const contentHeight = maxY - minY;
    
    const scaleX = (canvasRect.width * 0.8) / contentWidth;
    const scaleY = (canvasRect.height * 0.8) / contentHeight;
    
    this.zoomLevel = Math.min(scaleX, scaleY, 1);
    this.applyZoom();
  }
  
  // Undo/Redo functionality
  pushToUndoStack() {
    const state = {
      steps: new Map(this.steps),
      connections: new Map(this.connections)
    };
    
    this.undoStack.push(state);
    this.redoStack = []; // Clear redo stack when new action is performed
    
    // Limit undo stack size
    if (this.undoStack.length > 50) {
      this.undoStack.shift();
    }
    
    this.updateUndoRedoButtons();
  }
  
  undo() {
    if (this.undoStack.length === 0) return;
    
    const currentState = {
      steps: new Map(this.steps),
      connections: new Map(this.connections)
    };
    
    this.redoStack.push(currentState);
    
    const previousState = this.undoStack.pop();
    this.steps = previousState.steps;
    this.connections = previousState.connections;
    
    this.reRenderCanvas();
    this.updateUndoRedoButtons();
    this.markUnsavedChanges();
  }
  
  redo() {
    if (this.redoStack.length === 0) return;
    
    const currentState = {
      steps: new Map(this.steps),
      connections: new Map(this.connections)
    };
    
    this.undoStack.push(currentState);
    
    const nextState = this.redoStack.pop();
    this.steps = nextState.steps;
    this.connections = nextState.connections;
    
    this.reRenderCanvas();
    this.updateUndoRedoButtons();
    this.markUnsavedChanges();
  }
  
  updateUndoRedoButtons() {
    const undoBtn = document.getElementById('undo-btn');
    const redoBtn = document.getElementById('redo-btn');
    
    if (undoBtn) {
      undoBtn.disabled = this.undoStack.length === 0;
      undoBtn.classList.toggle('opacity-50', this.undoStack.length === 0);
    }
    
    if (redoBtn) {
      redoBtn.disabled = this.redoStack.length === 0;
      redoBtn.classList.toggle('opacity-50', this.redoStack.length === 0);
    }
  }
  
  reRenderCanvas() {
    // Clear canvas
    this.canvas.innerHTML = '';
    
    // Re-render all steps
    this.steps.forEach(stepData => {
      this.renderStep(stepData);
    });
    
    // Show empty state if no steps
    if (this.steps.size === 0) {
      this.showEmptyState();
    } else {
      this.hideEmptyState();
    }
    
    // Clear selection
    this.selectedStep = null;
    this.hideStepProperties();
  }
  
  // Template loading
  loadTemplate(templateName) {
    if (this.steps.size > 0 && !confirm('Loading a template will replace your current journey. Continue?')) {
      return;
    }
    
    const templates = {
      'welcome-series': [
        { type: 'email_sequence', stage: 'awareness', name: 'Welcome Email', position: { x: 100, y: 100 } },
        { type: 'email_sequence', stage: 'consideration', name: 'Getting Started Tips', position: { x: 350, y: 100 } },
        { type: 'email_sequence', stage: 'consideration', name: 'Success Stories', position: { x: 600, y: 100 } }
      ],
      'nurture-campaign': [
        { type: 'lead_magnet', stage: 'awareness', name: 'Free Guide Offer', position: { x: 100, y: 100 } },
        { type: 'email_sequence', stage: 'consideration', name: 'Educational Series', position: { x: 350, y: 100 } },
        { type: 'webinar', stage: 'consideration', name: 'Expert Webinar', position: { x: 600, y: 100 } },
        { type: 'sales_call', stage: 'conversion', name: 'Consultation Call', position: { x: 850, y: 100 } }
      ],
      'conversion-funnel': [
        { type: 'blog_post', stage: 'awareness', name: 'Educational Content', position: { x: 100, y: 100 } },
        { type: 'lead_magnet', stage: 'awareness', name: 'Lead Capture', position: { x: 350, y: 100 } },
        { type: 'email_sequence', stage: 'consideration', name: 'Nurture Sequence', position: { x: 600, y: 100 } },
        { type: 'demo', stage: 'conversion', name: 'Product Demo', position: { x: 850, y: 100 } },
        { type: 'trial_offer', stage: 'conversion', name: 'Free Trial', position: { x: 1100, y: 100 } }
      ]
    };
    
    const template = templates[templateName];
    if (!template) return;
    
    this.steps.clear();
    this.canvas.innerHTML = '';
    
    template.forEach((stepTemplate, index) => {
      const stepId = `step-${Date.now()}-${index}`;
      const stepData = {
        id: stepId,
        type: stepTemplate.type,
        stage: stepTemplate.stage,
        name: stepTemplate.name,
        description: '',
        position: stepTemplate.position,
        config: this.getDefaultStepConfig(stepTemplate.type),
        conditions: {},
        metadata: {}
      };
      
      this.steps.set(stepId, stepData);
      this.renderStep(stepData);
    });
    
    this.hideEmptyState();
    this.markUnsavedChanges();
    this.pushToUndoStack();
    this.fitToScreen();
    
    this.showNotification(`${templateName.replace('-', ' ')} template loaded successfully`, 'success');
  }
  
  // Utility functions
  getStepTypeName(stepType) {
    const names = {
      blog_post: 'Blog Post',
      email_sequence: 'Email Sequence',
      social_media: 'Social Media Post',
      lead_magnet: 'Lead Magnet',
      webinar: 'Webinar',
      case_study: 'Case Study',
      sales_call: 'Sales Call',
      demo: 'Product Demo',
      trial_offer: 'Free Trial',
      onboarding: 'Customer Onboarding',
      newsletter: 'Newsletter',
      feedback_survey: 'Feedback Survey'
    };
    
    return names[stepType] || stepType.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());
  }
  
  getStepIcon(stepType) {
    const icons = {
      blog_post: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/></svg>',
      email_sequence: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>',
      social_media: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 0h10m-10 0a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V6a2 2 0 00-2-2"/></svg>',
      webinar: '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'
    };
    
    return icons[stepType] || '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>';
  }
  
  getDefaultStepConfig(stepType) {
    const configs = {
      email_sequence: { timing: 'immediate', channel: 'email', content: {} },
      blog_post: { timing: 'immediate', channel: 'website', content: {} },
      social_media: { timing: 'immediate', channel: 'social_media', content: {} },
      webinar: { timing: '1_week', channel: 'website', content: { duration: 60 } },
      sales_call: { timing: '3_days', channel: 'phone', content: {} },
      demo: { timing: '1_day', channel: 'website', content: {} }
    };
    
    return configs[stepType] || { timing: 'immediate', channel: 'email', content: {} };
  }
  
  showEmptyState() {
    document.getElementById('empty-canvas-state').classList.remove('hidden');
  }
  
  hideEmptyState() {
    document.getElementById('empty-canvas-state').classList.add('hidden');
  }
  
  // Auto-save functionality  
  setupAutoSave() {
    setInterval(() => {
      if (this.hasUnsavedChanges) {
        this.autoSave();
      }
    }, 30000); // Auto-save every 30 seconds
  }
  
  autoSave() {
    if (!this.journeyId || this.steps.size === 0) return;
    
    this.saveJourney('draft', true);
  }
  
  markUnsavedChanges() {
    this.hasUnsavedChanges = true;
    document.getElementById('unsaved-indicator').classList.remove('hidden');
  }
  
  clearUnsavedChanges() {
    this.hasUnsavedChanges = false;
    document.getElementById('unsaved-indicator').classList.add('hidden');
  }
  
  // Save journey to backend
  async saveJourney(status = 'draft', isAutoSave = false) {
    const journeyData = this.serializeJourney();
    
    try {
      const response = await fetch(`/journeys${this.journeyId ? '/' + this.journeyId : ''}`, {
        method: this.journeyId ? 'PATCH' : 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
        },
        body: JSON.stringify({
          journey: {
            ...journeyData,
            status: status
          }
        })
      });
      
      if (response.ok) {
        const result = await response.json();
        
        if (!this.journeyId) {
          this.journeyId = result.id;
          // Update URL without reload
          window.history.replaceState({}, '', `/journeys/${result.id}/builder`);
        }
        
        this.clearUnsavedChanges();
        
        if (!isAutoSave) {
          this.showNotification(
            status === 'published' ? 'Journey published successfully!' : 'Journey saved successfully!',
            'success'
          );
          
          if (status === 'published') {
            setTimeout(() => {
              window.location.href = `/journeys/${this.journeyId}`;
            }, 1500);
          }
        }
      } else {
        throw new Error('Failed to save journey');
      }
    } catch (error) {
      console.error('Error saving journey:', error);
      this.showNotification('Failed to save journey. Please try again.', 'error');
    }
  }
  
  serializeJourney() {
    const steps = Array.from(this.steps.values());
    const connections = Array.from(this.connections.values());
    
    return {
      name: document.getElementById('journey-name-display').textContent || 'New Journey',
      steps: steps,
      connections: connections,
      metadata: {
        canvas_settings: {
          zoom_level: this.zoomLevel
        }
      }
    };
  }
  
  // Load existing journey
  async loadExistingJourney() {
    if (!this.journeyId) return;
    
    try {
      const response = await fetch(`/journeys/${this.journeyId}.json`);
      if (response.ok) {
        const journey = await response.json();
        this.deserializeJourney(journey);
      }
    } catch (error) {
      console.error('Error loading journey:', error);
    }
  }
  
  deserializeJourney(journeyData) {
    this.steps.clear();
    this.connections.clear();
    this.canvas.innerHTML = '';
    
    // Load steps
    if (journeyData.steps) {
      journeyData.steps.forEach(stepData => {
        this.steps.set(stepData.id, stepData);
        this.renderStep(stepData);
      });
    }
    
    // Load connections
    if (journeyData.connections) {
      journeyData.connections.forEach(connectionData => {
        this.connections.set(connectionData.id, connectionData);
        // Render connections would go here
      });
    }
    
    // Update journey name display
    if (journeyData.name) {
      document.getElementById('journey-name-display').textContent = journeyData.name;
    }
    
    // Apply canvas settings
    if (journeyData.metadata?.canvas_settings?.zoom_level) {
      this.zoomLevel = journeyData.metadata.canvas_settings.zoom_level;
      this.applyZoom();
    }
    
    if (this.steps.size === 0) {
      this.showEmptyState();
    } else {
      this.hideEmptyState();
    }
    
    this.clearUnsavedChanges();
  }
  
  // Keyboard shortcuts
  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      if (e.ctrlKey || e.metaKey) {
        switch (e.key) {
          case 'z':
            if (e.shiftKey) {
              this.redo();
            } else {
              this.undo();
            }
            e.preventDefault();
            break;
          case 's':
            this.saveJourney('draft');
            e.preventDefault();
            break;
          case 'Delete':
          case 'Backspace':
            if (this.selectedStep) {
              this.deleteSelectedStep();
              e.preventDefault();
            }
            break;
          case 'd':
            if (this.selectedStep) {
              this.duplicateSelectedStep();
              e.preventDefault();
            }
            break;
        }
      }
    });
  }
  
  // AI Suggestions
  showAISuggestions() {
    document.getElementById('ai-suggestions-modal').classList.remove('hidden');
    // Load AI suggestions would go here
  }
  
  hideAISuggestions() {
    document.getElementById('ai-suggestions-modal').classList.add('hidden');
  }
  
  // Preview functionality
  showPreview() {
    document.getElementById('preview-modal').classList.remove('hidden');
    this.generatePreview();
  }
  
  hidePreview() {
    document.getElementById('preview-modal').classList.add('hidden');
  }
  
  generatePreview() {
    const previewContent = document.getElementById('preview-content');
    const steps = Array.from(this.steps.values()).sort((a, b) => a.position.x - b.position.x);
    
    let html = '<div class="journey-preview">';
    html += '<h3 class="text-lg font-medium text-gray-900 mb-4">Journey Flow Preview</h3>';
    
    if (steps.length === 0) {
      html += '<p class="text-gray-500">No steps in journey yet.</p>';
    } else {
      html += '<div class="space-y-4">';
      
      steps.forEach((step, index) => {
        html += `
          <div class="flex items-center space-x-4">
            <div class="flex-shrink-0 w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
              <span class="text-sm font-medium text-blue-600">${index + 1}</span>
            </div>
            <div class="flex-1">
              <h4 class="font-medium text-gray-900">${step.name}</h4>
              <p class="text-sm text-gray-600">${step.description || 'No description'}</p>
              <div class="flex items-center space-x-2 mt-1">
                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs bg-gray-100 text-gray-800">
                  ${step.stage}
                </span>
                <span class="text-xs text-gray-500">${step.config?.timing || 'Immediate'}</span>
              </div>
            </div>
          </div>
        `;
      });
      
      html += '</div>';
    }
    
    html += '</div>';
    previewContent.innerHTML = html;
  }
  
  // Brand compliance check
  async checkBrandCompliance() {
    if (!this.selectedStep) return;
    
    const stepData = this.steps.get(this.selectedStep);
    if (!stepData) return;
    
    try {
      const response = await fetch('/api/v1/brand_compliance/check', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
        },
        body: JSON.stringify({
          content: stepData.description,
          context: {
            step_type: stepData.type,
            stage: stepData.stage
          }
        })
      });
      
      if (response.ok) {
        const result = await response.json();
        this.updateBrandComplianceStatus(stepData, result);
      }
    } catch (error) {
      console.error('Error checking brand compliance:', error);
      this.showNotification('Failed to check brand compliance', 'error');
    }
  }
  
  updateBrandComplianceStatus(stepData, complianceResult = null) {
    const statusElement = document.getElementById('brand-compliance-status');
    
    if (complianceResult) {
      statusElement.classList.remove('hidden');
      
      const isCompliant = complianceResult.compliant;
      const score = complianceResult.score || 0;
      
      statusElement.className = `p-3 rounded-md border ${
        isCompliant ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'
      }`;
      
      statusElement.innerHTML = `
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 ${isCompliant ? 'text-green-400' : 'text-red-400'}" fill="currentColor" viewBox="0 0 20 20">
              ${isCompliant ? 
                '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>' :
                '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>'
              }
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm font-medium ${isCompliant ? 'text-green-800' : 'text-red-800'}">
              ${isCompliant ? 'Brand compliant' : 'Brand compliance issues'} (${Math.round(score * 100)}%)
            </p>
            <p class="text-sm ${isCompliant ? 'text-green-700' : 'text-red-700'}">
              ${complianceResult.summary || (isCompliant ? 'This content follows your brand guidelines.' : 'This content needs review.')}
            </p>
          </div>
        </div>
      `;
    }
  }
  
  // Notifications
  showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 z-50 max-w-sm p-4 rounded-md shadow-lg transition-all duration-300 ${
      type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' :
      type === 'error' ? 'bg-red-100 text-red-800 border border-red-200' :
      'bg-blue-100 text-blue-800 border border-blue-200'
    }`;
    
    notification.innerHTML = `
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
            ${type === 'success' ? 
              '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>' :
              type === 'error' ?
              '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>' :
              '<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>'
            }
          </svg>
        </div>
        <div class="ml-3 flex-1">
          <p class="text-sm font-medium">${message}</p>
        </div>
        <div class="ml-4 flex-shrink-0">
          <button class="text-current hover:opacity-75" onclick="this.parentElement.parentElement.parentElement.remove()">
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
      </div>
    `;
    
    document.body.appendChild(notification);
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      notification.style.opacity = '0';
      setTimeout(() => notification.remove(), 300);
    }, 5000);
  }
}

// Initialize the Journey Builder when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  if (document.querySelector('.journey-builder-container')) {
    window.journeyBuilder = new JourneyBuilderEnhanced();
  }
});

// Prevent accidental page unload with unsaved changes
window.addEventListener('beforeunload', (e) => {
  if (window.journeyBuilder?.hasUnsavedChanges) {
    e.preventDefault();
    e.returnValue = 'You have unsaved changes. Are you sure you want to leave?';
    return e.returnValue;
  }
});