import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="campaign-form"
export default class extends Controller {
  static targets = [
    "form", "step", "stepInput", "nextButton", "submitButton", 
    "conditionalContent", "personaPreview", "audienceSize", "helpModal"
  ]
  static values = { currentStep: String }

  connect() {
    console.log("Campaign form controller connected")
    this.initializeForm()
    this.loadConditionalContent()
    this.setupKeyboardNavigation()
  }

  // Initialize form state
  initializeForm() {
    this.currentStep = parseInt(this.currentStepValue) || 1
    this.maxStepReached = this.currentStep
    this.isSubmitting = false
    
    // Show current step
    this.showStep(this.currentStep)
    
    // Setup form validation
    this.setupValidation()
    
    // Load saved data if available
    this.loadSavedData()
  }

  // Navigate to next step
  async nextStep(event) {
    event.preventDefault()
    
    if (this.isSubmitting) {return}
    
    // Validate current step
    if (!await this.validateCurrentStep()) {
      this.showValidationErrors()
      return
    }
    
    // Save current step data
    await this.saveStepData()
    
    if (this.currentStep < 5) {
      this.currentStep++
      this.maxStepReached = Math.max(this.maxStepReached, this.currentStep)
      this.showStep(this.currentStep)
      this.updateProgress()
      this.loadConditionalContent()
    }
  }

  // Navigate to previous step
  previousStep(event) {
    event.preventDefault()
    
    if (this.currentStep > 1) {
      this.currentStep--
      this.showStep(this.currentStep)
      this.updateProgress()
      this.loadConditionalContent()
    }
  }

  // Show specific step
  showStep(stepNumber) {
    // Hide all steps
    this.stepTargets.forEach(step => {
      step.classList.add('hidden')
    })
    
    // Show target step
    const targetStep = this.stepTargets.find(step => 
      step.dataset.step === stepNumber.toString()
    )
    
    if (targetStep) {
      targetStep.classList.remove('hidden')
      
      // Update hidden input
      if (this.hasStepInputTarget) {
        this.stepInputTarget.value = stepNumber
      }
      
      // Focus first input in step
      const firstInput = targetStep.querySelector('input, select, textarea')
      if (firstInput) {
        setTimeout(() => firstInput.focus(), 100)
      }
      
      // Update URL without page reload
      const url = new URL(window.location)
      url.searchParams.set('step', stepNumber)
      window.history.replaceState({}, '', url)
      
      // Announce step change to screen readers
      this.announceStepChange(stepNumber)
    }
  }

  // Update progress bar
  updateProgress() {
    const progressBar = document.querySelector('[role="progressbar"]')
    if (progressBar) {
      progressBar.setAttribute('aria-valuenow', this.currentStep)
    }
    
    // Update step indicators
    const stepIndicators = document.querySelectorAll('.w-10.h-10.rounded-full')
    stepIndicators.forEach((indicator, index) => {
      const stepNum = index + 1
      const circle = indicator
      
      // Remove existing classes
      circle.className = circle.className.replace(/bg-\w+-\d+|border-\w+-\d+|text-\w+/g, '')
      
      if (stepNum < this.currentStep) {
        // Completed step
        circle.classList.add('bg-green-600', 'border-green-600', 'text-white')
        circle.innerHTML = `
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
            <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
          </svg>
        `
      } else if (stepNum === this.currentStep) {
        // Current step
        circle.classList.add('bg-blue-600', 'border-blue-600', 'text-white')
        circle.innerHTML = `<span class="text-sm font-medium">${stepNum}</span>`
      } else {
        // Future step
        circle.classList.add('bg-white', 'border-gray-300', 'text-gray-500')
        circle.innerHTML = `<span class="text-sm font-medium">${stepNum}</span>`
      }
    })
  }

  // Validate current step
  async validateCurrentStep() {
    const currentStepElement = this.stepTargets.find(step => 
      step.dataset.step === this.currentStep.toString()
    )
    
    if (!currentStepElement) {return true}
    
    let isValid = true
    const fields = currentStepElement.querySelectorAll('[data-form-validation-target="field"]')
    
    // Clear previous errors
    this.clearValidationErrors()
    
    // Validate each field
    for (const field of fields) {
      const fieldValid = await this.validateField(field)
      if (!fieldValid) {
        isValid = false
      }
    }
    
    // Custom step validation
    switch (this.currentStep) {
      case 1:
        isValid = isValid && this.validateStepOne()
        break
      case 2:
        isValid = isValid && this.validateStepTwo()
        break
      case 3:
        isValid = isValid && this.validateStepThree()
        break
      case 4:
        isValid = isValid && this.validateStepFour()
        break
    }
    
    return isValid
  }

  // Validate individual field
  async validateField(field) {
    const rules = field.dataset.validationRules
    if (!rules) {return true}
    
    const value = field.value.trim()
    const ruleArray = rules.split('|')
    
    for (const rule of ruleArray) {
      if (rule === 'required' && !value) {
        this.showFieldError(field, 'This field is required')
        return false
      }
      
      if (rule.startsWith('max:')) {
        const maxLength = parseInt(rule.split(':')[1])
        if (value.length > maxLength) {
          this.showFieldError(field, `Maximum ${maxLength} characters allowed`)
          return false
        }
      }
      
      if (rule.startsWith('min:')) {
        const minLength = parseInt(rule.split(':')[1])
        if (value.length > 0 && value.length < minLength) {
          this.showFieldError(field, `Minimum ${minLength} characters required`)
          return false
        }
      }
      
      if (rule === 'email' && value && !this.isValidEmail(value)) {
        this.showFieldError(field, 'Please enter a valid email address')
        return false
      }
    }
    
    return true
  }

  // Step-specific validation
  validateStepOne() {
    const nameField = document.getElementById('campaign_name')
    const typeField = document.getElementById('campaign_campaign_type')
    const goalField = document.getElementById('campaign_primary_goal')
    
    let isValid = true
    
    if (!nameField?.value.trim()) {
      this.showFieldError(nameField, 'Campaign name is required')
      isValid = false
    }
    
    if (!typeField?.value) {
      this.showFieldError(typeField, 'Campaign type is required')
      isValid = false
    }
    
    if (!goalField?.value) {
      this.showFieldError(goalField, 'Primary goal is required')
      isValid = false
    }
    
    return isValid
  }

  validateStepTwo() {
    const personaField = document.getElementById('campaign_persona_id')
    
    if (!personaField?.value) {
      this.showFieldError(personaField, 'Target persona is required')
      return false
    }
    
    return true
  }

  validateStepThree() {
    // Add step 3 specific validation
    return true
  }

  validateStepFour() {
    // Add step 4 specific validation
    return true
  }

  // Show field error
  showFieldError(field, message) {
    if (!field) {return}
    
    const errorElement = field.parentElement.querySelector('[data-form-validation-target="error"]')
    if (errorElement) {
      errorElement.textContent = message
      errorElement.classList.remove('hidden')
    }
    
    // Add error styling to field
    field.classList.add('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.remove('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
  }

  // Clear validation errors
  clearValidationErrors() {
    const errorElements = document.querySelectorAll('[data-form-validation-target="error"]')
    errorElements.forEach(element => {
      element.textContent = ''
      element.classList.add('hidden')
    })
    
    const fields = document.querySelectorAll('[data-form-validation-target="field"]')
    fields.forEach(field => {
      field.classList.remove('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')
      field.classList.add('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
    })
  }

  // Show validation errors summary
  showValidationErrors() {
    const errorSummary = document.createElement('div')
    errorSummary.className = 'bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6'
    errorSummary.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
        </svg>
        <span>Please correct the errors below before continuing.</span>
      </div>
    `
    
    const currentStepElement = this.stepTargets.find(step => 
      step.dataset.step === this.currentStep.toString()
    )
    
    if (currentStepElement) {
      const existingSummary = currentStepElement.querySelector('.bg-red-50')
      if (existingSummary) {
        existingSummary.remove()
      }
      
      currentStepElement.insertBefore(errorSummary, currentStepElement.firstChild)
      
      // Scroll to top of step
      currentStepElement.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }

  // Handle campaign type change
  handleTypeChange(event) {
    const campaignType = event.target.value
    this.loadConditionalContent(campaignType)
  }

  // Handle persona change
  handlePersonaChange(event) {
    const personaId = event.target.value
    if (personaId) {
      this.loadPersonaPreview(personaId)
      this.updateAudienceSize(personaId)
    } else {
      this.clearPersonaPreview()
    }
  }

  // Load conditional content based on campaign type
  loadConditionalContent(campaignType = null) {
    if (!this.hasConditionalContentTarget) {return}
    
    const typeField = document.getElementById('campaign_campaign_type')
    const selectedType = campaignType || typeField?.value
    
    if (!selectedType) {
      this.conditionalContentTarget.innerHTML = ''
      return
    }
    
    // Load type-specific form fields
    const content = this.getConditionalContent(selectedType)
    this.conditionalContentTarget.innerHTML = content
  }

  // Get conditional content based on campaign type
  getConditionalContent(campaignType) {
    const contentMap = {
      'product_launch': this.getProductLaunchContent(),
      'lead_generation': this.getLeadGenerationContent(),
      'brand_awareness': this.getBrandAwarenessContent(),
      'email_nurture': this.getEmailNurtureContent(),
      'social_media': this.getSocialMediaContent()
    }
    
    return contentMap[campaignType] || ''
  }

  // Product launch specific content
  getProductLaunchContent() {
    return `
      <div class="border-t pt-8">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Product Launch Details</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Product Name</label>
            <input type="text" 
                   name="campaign[metadata][product_name]" 
                   class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                   placeholder="Enter product name">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Launch Date</label>
            <input type="date" 
                   name="campaign[metadata][launch_date]" 
                   class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
          </div>
          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-2">Key Features</label>
            <textarea name="campaign[metadata][key_features]" 
                      rows="3"
                      class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
                      placeholder="List the key features and benefits of your product..."></textarea>
          </div>
        </div>
      </div>
    `
  }

  // Lead generation specific content
  getLeadGenerationContent() {
    return `
      <div class="border-t pt-8">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Lead Generation Settings</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Lead Magnet Type</label>
            <select name="campaign[metadata][lead_magnet_type]" 
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="">Select lead magnet type...</option>
              <option value="ebook">eBook/Guide</option>
              <option value="webinar">Webinar</option>
              <option value="template">Template/Checklist</option>
              <option value="trial">Free Trial</option>
              <option value="consultation">Free Consultation</option>
              <option value="course">Mini Course</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Target Lead Count</label>
            <input type="number" 
                   name="campaign[metadata][target_leads]" 
                   class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                   placeholder="e.g., 500">
          </div>
        </div>
      </div>
    `
  }

  // Load persona preview
  async loadPersonaPreview(personaId) {
    if (!this.hasPersonaPreviewTarget) {return}
    
    try {
      const response = await fetch(`/personas/${personaId}.json`)
      if (!response.ok) {throw new Error('Failed to load persona')}
      
      const persona = await response.json()
      this.displayPersonaPreview(persona)
      
    } catch (error) {
      console.error('Error loading persona:', error)
      this.showPersonaError()
    }
  }

  // Display persona preview
  displayPersonaPreview(persona) {
    this.personaPreviewTarget.innerHTML = `
      <div class="text-left">
        <div class="flex items-center mb-3">
          <div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
            <span class="text-blue-600 font-medium text-lg">${persona.name[0].toUpperCase()}</span>
          </div>
          <div class="ml-3">
            <h4 class="text-lg font-medium text-gray-900">${persona.name}</h4>
            <p class="text-sm text-gray-500">${persona.job_title || 'Target Persona'}</p>
          </div>
        </div>
        
        <div class="space-y-3 text-sm">
          ${persona.demographics ? `
            <div>
              <span class="font-medium text-gray-700">Demographics:</span>
              <p class="text-gray-600">${persona.demographics}</p>
            </div>
          ` : ''}
          
          ${persona.pain_points ? `
            <div>
              <span class="font-medium text-gray-700">Pain Points:</span>
              <p class="text-gray-600">${persona.pain_points}</p>
            </div>
          ` : ''}
          
          ${persona.goals ? `
            <div>
              <span class="font-medium text-gray-700">Goals:</span>
              <p class="text-gray-600">${persona.goals}</p>
            </div>
          ` : ''}
        </div>
      </div>
    `
  }

  // Clear persona preview
  clearPersonaPreview() {
    if (this.hasPersonaPreviewTarget) {
      this.personaPreviewTarget.innerHTML = `
        <div class="text-center text-gray-500">
          <svg class="w-12 h-12 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
          </svg>
          <p class="text-sm">Select a persona to see details</p>
        </div>
      `
    }
  }

  // Update audience size estimate
  updateAudienceSize(personaId) {
    if (!this.hasAudienceSizeTarget) {return}
    
    // Simulate audience size calculation
    // In a real app, this would be an API call
    const estimates = {
      '1': '12.5K',
      '2': '8.3K',
      '3': '15.2K',
      '4': '6.8K'
    }
    
    const size = estimates[personaId] || '10K'
    this.audienceSizeTarget.textContent = size
  }

  // Save step data
  async saveStepData() {
    if (!this.hasFormTarget) {return}
    
    const formData = new FormData(this.formTarget)
    formData.append('_method', 'PATCH')
    formData.append('step', this.currentStep)
    
    try {
      // Auto-save implementation would go here
      console.log('Saving step data:', this.currentStep)
    } catch (error) {
      console.error('Error saving step data:', error)
    }
  }

  // Save draft
  async saveDraft(event) {
    event.preventDefault()
    
    this.showSavingState()
    
    try {
      await this.saveStepData()
      this.showSavedState()
    } catch (error) {
      console.error('Error saving draft:', error)
      this.showSaveError()
    }
  }

  // Show saving state
  showSavingState() {
    const button = event.target
    const originalText = button.textContent
    button.textContent = 'Saving...'
    button.disabled = true
    
    setTimeout(() => {
      button.textContent = originalText
      button.disabled = false
    }, 2000)
  }

  // Setup form validation
  setupValidation() {
    // Add real-time validation listeners
    const fields = this.formTarget.querySelectorAll('[data-form-validation-target="field"]')
    fields.forEach(field => {
      field.addEventListener('blur', () => this.validateField(field))
      field.addEventListener('input', () => this.clearFieldError(field))
    })
  }

  // Clear individual field error
  clearFieldError(field) {
    const errorElement = field.parentElement.querySelector('[data-form-validation-target="error"]')
    if (errorElement) {
      errorElement.classList.add('hidden')
    }
    
    field.classList.remove('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.add('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
  }

  // Setup keyboard navigation
  setupKeyboardNavigation() {
    document.addEventListener('keydown', (event) => {
      // Alt + Right Arrow = Next step
      if (event.altKey && event.key === 'ArrowRight' && this.currentStep < 5) {
        event.preventDefault()
        this.nextStep(event)
      }
      
      // Alt + Left Arrow = Previous step
      if (event.altKey && event.key === 'ArrowLeft' && this.currentStep > 1) {
        event.preventDefault()
        this.previousStep(event)
      }
      
      // Escape = Close help modal
      if (event.key === 'Escape' && this.hasHelpModalTarget && !this.helpModalTarget.classList.contains('hidden')) {
        this.hideHelp(event)
      }
    })
  }

  // Announce step change for accessibility
  announceStepChange(stepNumber) {
    const stepTitles = {
      1: 'Campaign Details',
      2: 'Target Audience',
      3: 'Strategy & Content',
      4: 'Timeline & Budget',
      5: 'Review & Launch'
    }
    
    const announcement = document.createElement('div')
    announcement.setAttribute('aria-live', 'polite')
    announcement.setAttribute('aria-atomic', 'true')
    announcement.className = 'sr-only'
    announcement.textContent = `Now on step ${stepNumber}: ${stepTitles[stepNumber]}`
    
    document.body.appendChild(announcement)
    
    setTimeout(() => {
      document.body.removeChild(announcement)
    }, 1000)
  }

  // Show help modal
  showHelp(event) {
    event.preventDefault()
    if (this.hasHelpModalTarget) {
      this.helpModalTarget.classList.remove('hidden')
      this.helpModalTarget.setAttribute('aria-hidden', 'false')
      
      // Focus first focusable element
      const focusable = this.helpModalTarget.querySelector('button')
      if (focusable) {focusable.focus()}
    }
  }

  // Hide help modal
  hideHelp(event) {
    event.preventDefault()
    if (this.hasHelpModalTarget) {
      this.helpModalTarget.classList.add('hidden')
      this.helpModalTarget.setAttribute('aria-hidden', 'true')
    }
  }

  // Load saved data
  loadSavedData() {
    // Implementation for loading saved draft data
    const savedData = sessionStorage.getItem('campaignFormData')
    if (savedData) {
      try {
        const data = JSON.parse(savedData)
        this.populateFormData(data)
      } catch (error) {
        console.error('Error loading saved data:', error)
      }
    }
  }

  // Populate form with saved data
  populateFormData(data) {
    Object.entries(data).forEach(([name, value]) => {
      const field = this.formTarget.querySelector(`[name="${name}"]`)
      if (field) {
        field.value = value
      }
    })
  }

  // Utility functions
  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(email)
  }

  getBrandAwarenessContent() {
    return `
      <div class="border-t pt-8">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Brand Awareness Goals</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Awareness Metric</label>
            <select name="campaign[metadata][awareness_metric]" 
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="">Select metric...</option>
              <option value="brand_recall">Brand Recall</option>
              <option value="brand_recognition">Brand Recognition</option>
              <option value="share_of_voice">Share of Voice</option>
              <option value="reach">Reach</option>
              <option value="impressions">Impressions</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Target Increase</label>
            <input type="text" 
                   name="campaign[metadata][target_increase]" 
                   class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                   placeholder="e.g., 25%">
          </div>
        </div>
      </div>
    `
  }

  getEmailNurtureContent() {
    return `
      <div class="border-t pt-8">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Email Nurture Sequence</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Email Count</label>
            <input type="number" 
                   name="campaign[metadata][email_count]" 
                   class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                   placeholder="e.g., 5"
                   min="1">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Send Frequency</label>
            <select name="campaign[metadata][send_frequency]" 
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="">Select frequency...</option>
              <option value="daily">Daily</option>
              <option value="every_2_days">Every 2 Days</option>
              <option value="every_3_days">Every 3 Days</option>
              <option value="weekly">Weekly</option>
              <option value="bi_weekly">Bi-weekly</option>
            </select>
          </div>
        </div>
      </div>
    `
  }

  getSocialMediaContent() {
    return `
      <div class="border-t pt-8">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Social Media Strategy</h3>
        <div class="space-y-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Primary Platforms</label>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
              ${['Facebook', 'Instagram', 'Twitter', 'LinkedIn', 'TikTok', 'YouTube', 'Pinterest', 'Snapchat'].map(platform => `
                <label class="flex items-center space-x-2">
                  <input type="checkbox" 
                         name="campaign[metadata][platforms][]" 
                         value="${platform.toLowerCase()}"
                         class="rounded border-gray-300 text-blue-600 focus:ring-blue-500">
                  <span class="text-sm text-gray-700">${platform}</span>
                </label>
              `).join('')}
            </div>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Post Frequency</label>
              <select name="campaign[metadata][post_frequency]" 
                      class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                <option value="">Select frequency...</option>
                <option value="multiple_daily">Multiple times daily</option>
                <option value="daily">Daily</option>
                <option value="every_other_day">Every other day</option>
                <option value="3_times_week">3 times per week</option>
                <option value="weekly">Weekly</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Content Mix</label>
              <select name="campaign[metadata][content_mix]" 
                      class="w-full px-4 py-3 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                <option value="">Select content mix...</option>
                <option value="educational">Educational (80/20)</option>
                <option value="promotional">Promotional (60/40)</option>
                <option value="entertainment">Entertainment focused</option>
                <option value="mixed">Mixed content</option>
                <option value="community">Community building</option>
              </select>
            </div>
          </div>
        </div>
      </div>
    `
  }
}