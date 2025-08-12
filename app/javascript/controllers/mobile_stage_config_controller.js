import { Controller } from "@hotwired/stimulus"

// Mobile Stage Configuration Controller for full-screen forms
export default class extends Controller {
  static targets = [
    "form", "formContent", "stageNameInput", "stageDescriptionInput", "stageDurationInput",
    "dynamicFields", "errorContainer", "saveButton", "loadingSpinner", "configTitle"
  ]

  static values = {
    stageId: String,
    stageType: String,
    stageData: Object,
    isNewStage: { type: Boolean, default: false },
    validationRules: Object
  }

  static classes = [
    "loading", "error", "success", "hidden", "visible", "invalid"
  ]

  connect() {
    this.initializeMobileForm()
    this.setupFormValidation()
    this.setupAutosave()
    this.loadStageConfiguration()
  }

  disconnect() {
    this.cleanup()
  }

  // Initialize mobile-optimized form
  initializeMobileForm() {
    this.form = this.hasFormTarget ? this.formTarget : null
    this.autosaveTimer = null
    this.validationTimer = null
    this.hasChanges = false
    
    // Configure form for mobile
    this.configureMobileForm()
  }

  // Configure form for mobile interaction
  configureMobileForm() {
    if (!this.form) return
    
    // Prevent zoom on form inputs (iOS)
    const inputs = this.form.querySelectorAll('input, textarea, select')
    inputs.forEach(input => {
      if (input.type === 'text' || input.type === 'email' || input.type === 'tel') {
        input.setAttribute('font-size', '16px')
      }
    })
    
    // Setup touch-friendly interactions
    this.setupTouchOptimizations()
  }

  // Setup touch optimizations
  setupTouchOptimizations() {
    // Increase touch targets
    const buttons = this.element.querySelectorAll('button')
    buttons.forEach(button => {
      if (button.clientHeight < 44) {
        button.style.minHeight = '44px'
      }
    })
    
    // Optimize for virtual keyboard
    this.setupVirtualKeyboardHandling()
  }

  // Handle virtual keyboard appearance/disappearance
  setupVirtualKeyboardHandling() {
    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', () => {
        this.handleViewportResize()
      })
    }
  }

  // Handle viewport resize for virtual keyboard
  handleViewportResize() {
    const viewport = window.visualViewport
    if (viewport) {
      const isKeyboardOpen = viewport.height < window.innerHeight * 0.75
      
      if (isKeyboardOpen) {
        this.adjustForKeyboard(true)
      } else {
        this.adjustForKeyboard(false)
      }
    }
  }

  // Adjust layout for virtual keyboard
  adjustForKeyboard(isOpen) {
    const modal = this.element.closest('.mobile-fullscreen-modal')
    if (modal) {
      if (isOpen) {
        modal.classList.add('keyboard-open')
        // Scroll to focused element
        const focusedElement = document.activeElement
        if (focusedElement && this.element.contains(focusedElement)) {
          setTimeout(() => {
            focusedElement.scrollIntoView({ behavior: 'smooth', block: 'center' })
          }, 300)
        }
      } else {
        modal.classList.remove('keyboard-open')
      }
    }
  }

  // Load stage configuration
  loadStageConfiguration() {
    if (this.stageDataValue && Object.keys(this.stageDataValue).length > 0) {
      this.populateForm(this.stageDataValue)
    } else if (this.stageIdValue) {
      this.fetchStageConfiguration()
    } else {
      this.setupNewStageForm()
    }
  }

  // Fetch stage configuration from server
  async fetchStageConfiguration() {
    try {
      this.showLoading(true)
      
      const response = await fetch(`/journeys/stages/${this.stageIdValue}/config`)
      if (response.ok) {
        const data = await response.json()
        this.stageDataValue = data.stage
        this.populateForm(data.stage)
      } else {
        throw new Error('Failed to load stage configuration')
      }
    } catch (error) {
      this.showError('Failed to load stage configuration')
      console.error('Stage config load error:', error)
    } finally {
      this.showLoading(false)
    }
  }

  // Setup form for new stage
  setupNewStageForm() {
    this.isNewStageValue = true
    
    // Set default values
    const defaultData = {
      name: `New ${this.stageTypeValue} Stage`,
      description: '',
      duration_days: 7,
      stage_type: this.stageTypeValue
    }
    
    this.populateForm(defaultData)
    this.generateDynamicFields()
  }

  // Populate form with stage data
  populateForm(stageData) {
    // Basic fields
    if (this.hasStageNameInputTarget) {
      this.stageNameInputTarget.value = stageData.name || ''
    }
    
    if (this.hasStageDescriptionInputTarget) {
      this.stageDescriptionInputTarget.value = stageData.description || ''
    }
    
    if (this.hasStageDurationInputTarget) {
      this.stageDurationInputTarget.value = stageData.duration_days || 7
    }
    
    // Update title
    if (this.hasConfigTitleTarget) {
      this.configTitleTarget.textContent = stageData.name || 'Stage Configuration'
    }
    
    // Generate dynamic fields based on stage type
    this.generateDynamicFields(stageData)
    
    // Mark form as clean initially
    this.hasChanges = false
  }

  // Generate dynamic fields based on stage type
  generateDynamicFields(stageData = {}) {
    if (!this.hasDynamicFieldsTarget) return
    
    const stageType = stageData.stage_type || this.stageTypeValue
    const fieldsHTML = this.getStageTypeFields(stageType, stageData)
    
    this.dynamicFieldsTarget.innerHTML = fieldsHTML
    
    // Setup event listeners for new fields
    this.setupDynamicFieldListeners()
  }

  // Get stage-type specific fields
  getStageTypeFields(stageType, stageData) {
    const templates = {
      awareness: this.getAwarenessFields(stageData),
      consideration: this.getConsiderationFields(stageData),
      conversion: this.getConversionFields(stageData),
      retention: this.getRetentionFields(stageData),
      advocacy: this.getAdvocacyFields(stageData)
    }
    
    return templates[stageType] || this.getGenericFields(stageData)
  }

  // Awareness stage specific fields
  getAwarenessFields(stageData) {
    const channels = stageData.channels || []
    const channelOptions = ['social_media', 'content_marketing', 'paid_ads', 'pr', 'partnerships']
    
    return `
      <div class="mobile-form-group">
        <label class="mobile-form-label">Marketing Channels</label>
        <div class="space-y-2">
          ${channelOptions.map(channel => `
            <label class="flex items-center space-x-3 py-2">
              <input type="checkbox" 
                     name="channels[]" 
                     value="${channel}"
                     ${channels.includes(channel) ? 'checked' : ''}
                     class="rounded border-gray-300 text-blue-600 focus:ring-blue-500">
              <span class="text-sm text-gray-700">${this.formatChannelName(channel)}</span>
            </label>
          `).join('')}
        </div>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Target Audience</label>
        <textarea name="target_audience" 
                  class="mobile-form-textarea"
                  placeholder="Describe your target audience for this stage..."
                  rows="3">${stageData.target_audience || ''}</textarea>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Key Messages</label>
        <textarea name="key_messages" 
                  class="mobile-form-textarea"
                  placeholder="What are the key messages for this awareness stage?"
                  rows="4">${stageData.key_messages || ''}</textarea>
      </div>
    `
  }

  // Consideration stage specific fields
  getConsiderationFields(stageData) {
    return `
      <div class="mobile-form-group">
        <label class="mobile-form-label">Content Types</label>
        <div class="grid grid-cols-2 gap-3">
          ${['blog_posts', 'whitepapers', 'case_studies', 'webinars', 'demos', 'comparisons'].map(type => `
            <label class="flex items-center space-x-2 py-2">
              <input type="checkbox" 
                     name="content_types[]" 
                     value="${type}"
                     ${(stageData.content_types || []).includes(type) ? 'checked' : ''}
                     class="rounded border-gray-300 text-blue-600">
              <span class="text-xs text-gray-700">${this.formatContentType(type)}</span>
            </label>
          `).join('')}
        </div>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Lead Scoring Criteria</label>
        <textarea name="lead_scoring" 
                  class="mobile-form-textarea"
                  placeholder="Define criteria for lead scoring in this stage..."
                  rows="3">${stageData.lead_scoring || ''}</textarea>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Nurturing Sequence</label>
        <input type="number" 
               name="nurturing_emails" 
               class="mobile-form-input"
               placeholder="Number of nurturing emails"
               value="${stageData.nurturing_emails || 5}">
      </div>
    `
  }

  // Conversion stage specific fields
  getConversionFields(stageData) {
    return `
      <div class="mobile-form-group">
        <label class="mobile-form-label">Conversion Goals</label>
        <div class="space-y-2">
          ${['purchase', 'signup', 'demo_request', 'consultation', 'download'].map(goal => `
            <label class="flex items-center space-x-3 py-2">
              <input type="radio" 
                     name="conversion_goal" 
                     value="${goal}"
                     ${stageData.conversion_goal === goal ? 'checked' : ''}
                     class="border-gray-300 text-blue-600 focus:ring-blue-500">
              <span class="text-sm text-gray-700">${this.formatGoalName(goal)}</span>
            </label>
          `).join('')}
        </div>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Incentives/Offers</label>
        <textarea name="incentives" 
                  class="mobile-form-textarea"
                  placeholder="Describe incentives or offers for this stage..."
                  rows="3">${stageData.incentives || ''}</textarea>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Conversion Rate Target (%)</label>
        <input type="number" 
               name="conversion_rate_target" 
               class="mobile-form-input"
               min="0" 
               max="100" 
               step="0.1"
               value="${stageData.conversion_rate_target || 2.5}">
      </div>
    `
  }

  // Retention stage specific fields
  getRetentionFields(stageData) {
    return `
      <div class="mobile-form-group">
        <label class="mobile-form-label">Retention Strategies</label>
        <div class="space-y-2">
          ${['email_campaigns', 'loyalty_program', 'personalization', 'customer_support', 'product_updates'].map(strategy => `
            <label class="flex items-center space-x-3 py-2">
              <input type="checkbox" 
                     name="retention_strategies[]" 
                     value="${strategy}"
                     ${(stageData.retention_strategies || []).includes(strategy) ? 'checked' : ''}
                     class="rounded border-gray-300 text-blue-600">
              <span class="text-sm text-gray-700">${this.formatStrategyName(strategy)}</span>
            </label>
          `).join('')}
        </div>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Engagement Frequency</label>
        <select name="engagement_frequency" class="mobile-form-select">
          <option value="daily" ${stageData.engagement_frequency === 'daily' ? 'selected' : ''}>Daily</option>
          <option value="weekly" ${stageData.engagement_frequency === 'weekly' ? 'selected' : ''}>Weekly</option>
          <option value="bi_weekly" ${stageData.engagement_frequency === 'bi_weekly' ? 'selected' : ''}>Bi-weekly</option>
          <option value="monthly" ${stageData.engagement_frequency === 'monthly' ? 'selected' : ''}>Monthly</option>
        </select>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Success Metrics</label>
        <textarea name="success_metrics" 
                  class="mobile-form-textarea"
                  placeholder="How will you measure retention success?"
                  rows="3">${stageData.success_metrics || ''}</textarea>
      </div>
    `
  }

  // Advocacy stage specific fields
  getAdvocacyFields(stageData) {
    return `
      <div class="mobile-form-group">
        <label class="mobile-form-label">Advocacy Programs</label>
        <div class="space-y-2">
          ${['referral_program', 'review_requests', 'case_study_participation', 'testimonials', 'ambassador_program'].map(program => `
            <label class="flex items-center space-x-3 py-2">
              <input type="checkbox" 
                     name="advocacy_programs[]" 
                     value="${program}"
                     ${(stageData.advocacy_programs || []).includes(program) ? 'checked' : ''}
                     class="rounded border-gray-300 text-blue-600">
              <span class="text-sm text-gray-700">${this.formatProgramName(program)}</span>
            </label>
          `).join('')}
        </div>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Incentive Structure</label>
        <textarea name="incentive_structure" 
                  class="mobile-form-textarea"
                  placeholder="Describe incentives for advocates..."
                  rows="3">${stageData.incentive_structure || ''}</textarea>
      </div>
      
      <div class="mobile-form-group">
        <label class="mobile-form-label">Advocacy Goal</label>
        <input type="text" 
               name="advocacy_goal" 
               class="mobile-form-input"
               placeholder="e.g., 50 referrals per month"
               value="${stageData.advocacy_goal || ''}">
      </div>
    `
  }

  // Generic fields for unknown stage types
  getGenericFields(stageData) {
    return `
      <div class="mobile-form-group">
        <label class="mobile-form-label">Stage Configuration</label>
        <textarea name="custom_config" 
                  class="mobile-form-textarea"
                  placeholder="Add any custom configuration for this stage..."
                  rows="4">${stageData.custom_config || ''}</textarea>
      </div>
    `
  }

  // Setup event listeners for dynamic fields
  setupDynamicFieldListeners() {
    const inputs = this.dynamicFieldsTarget.querySelectorAll('input, textarea, select')
    
    inputs.forEach(input => {
      input.addEventListener('input', () => {
        this.markAsChanged()
        this.triggerAutosave()
        this.validateField(input)
      })
      
      input.addEventListener('change', () => {
        this.markAsChanged()
        this.triggerAutosave()
      })
    })
  }

  // Setup form validation
  setupFormValidation() {
    if (!this.form) return
    
    const inputs = this.form.querySelectorAll('input[required], textarea[required], select[required]')
    
    inputs.forEach(input => {
      input.addEventListener('blur', () => {
        this.validateField(input)
      })
    })
  }

  // Validate individual field
  validateField(field) {
    const isValid = this.isFieldValid(field)
    
    if (isValid) {
      field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
      field.classList.add('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
    } else {
      field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
      field.classList.remove('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
    }
    
    return isValid
  }

  // Check if field is valid
  isFieldValid(field) {
    if (field.hasAttribute('required')) {
      if (!field.value.trim()) return false
    }
    
    if (field.type === 'email') {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      return !field.value || emailRegex.test(field.value)
    }
    
    if (field.type === 'number') {
      const min = field.getAttribute('min')
      const max = field.getAttribute('max')
      const value = parseFloat(field.value)
      
      if (isNaN(value)) return !field.hasAttribute('required')
      if (min && value < parseFloat(min)) return false
      if (max && value > parseFloat(max)) return false
    }
    
    return true
  }

  // Setup autosave functionality
  setupAutosave() {
    if (!this.form) return
    
    const inputs = this.form.querySelectorAll('input, textarea, select')
    inputs.forEach(input => {
      input.addEventListener('input', () => {
        this.triggerAutosave()
      })
    })
  }

  // Trigger autosave with debouncing
  triggerAutosave() {
    clearTimeout(this.autosaveTimer)
    
    this.autosaveTimer = setTimeout(() => {
      if (this.hasChanges) {
        this.performAutosave()
      }
    }, 2000) // 2-second delay
  }

  // Perform autosave
  async performAutosave() {
    try {
      const formData = this.getFormData()
      
      // Show subtle saving indicator
      this.showSavingIndicator(true)
      
      await this.saveConfiguration(formData, { isAutosave: true })
      
    } catch (error) {
      console.error('Autosave failed:', error)
      // Don't show error for autosave failures
    } finally {
      this.showSavingIndicator(false)
    }
  }

  // Handle form submission
  async handleFormSubmit(event) {
    event.preventDefault()
    
    if (!this.validateForm()) {
      this.showError('Please fix the errors before saving')
      return
    }
    
    try {
      this.showLoading(true)
      
      const formData = this.getFormData()
      const result = await this.saveConfiguration(formData)
      
      if (result.success) {
        this.showSuccess('Stage configuration saved!')
        this.hasChanges = false
        
        // Dispatch success event
        this.dispatchConfigEvent('stage:configSaved', {
          stageId: this.stageIdValue,
          stageData: result.stage
        })
        
        // Auto-close after short delay
        setTimeout(() => {
          this.closeModal()
        }, 1500)
      } else {
        throw new Error(result.message || 'Save failed')
      }
      
    } catch (error) {
      this.showError(error.message || 'Failed to save configuration')
    } finally {
      this.showLoading(false)
    }
  }

  // Validate entire form
  validateForm() {
    if (!this.form) return false
    
    const requiredFields = this.form.querySelectorAll('input[required], textarea[required], select[required]')
    let isValid = true
    
    requiredFields.forEach(field => {
      if (!this.validateField(field)) {
        isValid = false
      }
    })
    
    return isValid
  }

  // Get form data
  getFormData() {
    if (!this.form) return {}
    
    const formData = new FormData(this.form)
    const data = {}
    
    // Handle basic fields
    for (let [key, value] of formData.entries()) {
      if (data[key]) {
        // Handle multiple values (checkboxes)
        if (Array.isArray(data[key])) {
          data[key].push(value)
        } else {
          data[key] = [data[key], value]
        }
      } else {
        data[key] = value
      }
    }
    
    // Add metadata
    data.stage_id = this.stageIdValue
    data.stage_type = this.stageTypeValue
    data.is_new_stage = this.isNewStageValue
    
    return data
  }

  // Save configuration
  async saveConfiguration(formData, options = {}) {
    const url = this.isNewStageValue ? '/journeys/stages' : `/journeys/stages/${this.stageIdValue}`
    const method = this.isNewStageValue ? 'POST' : 'PUT'
    
    const response = await fetch(url, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({
        stage: formData,
        options: options
      })
    })
    
    if (!response.ok) {
      throw new Error(`Server error: ${response.statusText}`)
    }
    
    return await response.json()
  }

  // Mark form as changed
  markAsChanged() {
    this.hasChanges = true
  }

  // Show loading state
  showLoading(show) {
    if (this.hasSaveButtonTarget) {
      if (show) {
        this.saveButtonTarget.disabled = true
        this.saveButtonTarget.innerHTML = `
          <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
          Saving...
        `
      } else {
        this.saveButtonTarget.disabled = false
        this.saveButtonTarget.innerHTML = `
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
          </svg>
          Save Configuration
        `
      }
    }
  }

  // Show saving indicator
  showSavingIndicator(show) {
    // Could add a subtle indicator in the header
  }

  // Show error message
  showError(message) {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.innerHTML = `
        <div class="bg-red-50 border border-red-200 rounded-lg p-3">
          <div class="flex items-center">
            <svg class="w-5 h-5 text-red-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
            </svg>
            <span class="text-sm text-red-800">${message}</span>
          </div>
        </div>
      `
      this.errorContainerTarget.classList.remove('hidden')
    }
  }

  // Show success message
  showSuccess(message) {
    // Could show in header or as toast
    this.dispatchConfigEvent('stage:notification', {
      message: message,
      type: 'success'
    })
  }

  // Close modal
  closeModal() {
    this.dispatchConfigEvent('stage:closeConfig')
  }

  // Utility methods

  formatChannelName(channel) {
    return channel.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  formatContentType(type) {
    return type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  formatGoalName(goal) {
    return goal.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  formatStrategyName(strategy) {
    return strategy.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  formatProgramName(program) {
    return program.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  getCSRFToken() {
    const metaTag = document.querySelector('meta[name="csrf-token"]')
    return metaTag ? metaTag.getAttribute('content') : ''
  }

  dispatchConfigEvent(eventName, detail = {}) {
    const event = new CustomEvent(eventName, { 
      detail: detail,
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  // Cleanup
  cleanup() {
    clearTimeout(this.autosaveTimer)
    clearTimeout(this.validationTimer)
    
    if (window.visualViewport) {
      window.visualViewport.removeEventListener('resize', this.handleViewportResize)
    }
  }
}