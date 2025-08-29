import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-validation"
export default class extends Controller {
  static targets = ["field", "error", "submit"]
  static values = { 
    debounce: { type: Number, default: 300 },
    serverValidation: { type: Boolean, default: false }
  }

  connect() {
    console.log("Form validation controller connected")
    this.validationCache = new Map()
    this.abortController = null
    this.validateOnInput()
  }

  disconnect() {
    if (this.abortController) {
      this.abortController.abort()
    }
  }

  validateOnInput() {
    this.fieldTargets.forEach(field => {
      // Mark field as pristine initially
      field.dataset.pristine = "true"
      
      if (this.serverValidationValue && field.dataset.serverValidation) {
        // Use debounced validation for server validation
        field.addEventListener('input', this.debounce(() => {
          if (field.dataset.pristine !== "true") {
            this.validateField(field, 'input')
          }
        }))
        field.addEventListener('blur', () => {
          field.dataset.pristine = "false"
          this.validateField(field, 'blur')
        })
      } else {
        // Use immediate validation for client-side only
        field.addEventListener('input', () => this.validateField(field, 'input'))
        field.addEventListener('blur', () => this.validateField(field, 'blur'))
      }
    })
  }

  async validateField(field, eventType = null) {
    const errors = []
    const fieldName = field.getAttribute('name') || field.id
    const value = field.value.trim()

    // Clear previous errors
    this.clearFieldErrors(field)

    // Client-side validation first
    const clientErrors = this.performClientValidation(field)
    errors.push(...clientErrors)

    // If client-side validation passes and server validation is enabled
    if (errors.length === 0 && 
        this.serverValidationValue && 
        field.dataset.serverValidation && 
        value !== "") {
      
      try {
        this.showLoadingState(field)
        const serverResult = await this.performServerValidation(field)
        
        if (!serverResult.valid) {
          errors.push(...serverResult.errors)
        }
      } catch (error) {
        console.error('Server validation error:', error)
        // Don't show server errors to user, just log them
      } finally {
        this.clearLoadingState(field)
      }
    }

    // Display results
    if (errors.length > 0) {
      this.showFieldErrors(field, errors)
      this.markFieldInvalid(field)
    } else if (value !== "") {
      this.markFieldValid(field)
    } else {
      this.markFieldNeutral(field)
    }

    this.updateSubmitButton()
  }

  performClientValidation(field) {
    const errors = []
    const fieldName = field.getAttribute('name') || field.id
    const value = field.value.trim()

    // Required field validation
    if (field.hasAttribute('required') && !value) {
      errors.push(`${this.getFieldLabel(field)} is required`)
      return errors // Stop here if required field is empty
    }

    // Skip other validations if field is empty and not required
    if (!value) return errors

    // Email validation
    if (field.type === 'email') {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      if (!emailRegex.test(value)) {
        errors.push('Please enter a valid email address')
      }
    }

    // Password validation
    if (field.type === 'password') {
      if (value.length < 8) {
        errors.push('Password must be at least 8 characters long')
      }
    }

    // Password confirmation validation
    if (fieldName?.includes('confirmation')) {
      const originalField = this.element.querySelector(`[name="${fieldName.replace('_confirmation', '')}"]`)
      if (originalField && value !== originalField.value) {
        errors.push('Password confirmation does not match')
      }
    }

    // Custom pattern validation
    const pattern = field.dataset.pattern
    if (pattern && !new RegExp(pattern).test(value)) {
      errors.push(field.dataset.patternMessage || 'Invalid format')
    }

    // Length validation
    const minLength = field.dataset.minLength
    const maxLength = field.dataset.maxLength
    if (minLength && value.length < parseInt(minLength)) {
      errors.push(`Must be at least ${minLength} characters`)
    }
    if (maxLength && value.length > parseInt(maxLength)) {
      errors.push(`Must be no more than ${maxLength} characters`)
    }

    return errors
  }

  async performServerValidation(field) {
    const value = field.value.trim()
    const tableName = field.dataset.tableName
    const fieldName = field.dataset.fieldName || field.name
    const recordId = field.dataset.recordId

    // Check cache first
    const cacheKey = `${tableName}-${fieldName}-${value}-${recordId || ''}`
    if (this.validationCache.has(cacheKey)) {
      return this.validationCache.get(cacheKey)
    }

    // Cancel previous request
    if (this.abortController) {
      this.abortController.abort()
    }
    this.abortController = new AbortController()

    const endpoint = this.getValidationEndpoint(tableName, fieldName)
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        value: value,
        field_name: fieldName,
        table_name: tableName,
        record_id: recordId,
        context: {
          user_scoped: field.dataset.userScoped === 'true'
        }
      }),
      signal: this.abortController.signal
    })

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`)
    }

    const result = await response.json()

    // Cache result for 30 seconds
    this.validationCache.set(cacheKey, result)
    setTimeout(() => this.validationCache.delete(cacheKey), 30000)

    return result
  }

  getValidationEndpoint(tableName, fieldName) {
    // Use specific endpoints for better performance
    if (tableName === 'users' && fieldName === 'email_address') {
      return '/api/v1/validations/users/email_address'
    } else if (tableName === 'campaign_plans' && fieldName === 'name') {
      return '/api/v1/validations/campaign_plans/name'
    } else if (tableName === 'journeys' && fieldName === 'name') {
      return '/api/v1/validations/journeys/name'
    }
    
    return '/api/v1/validations/validate_field'
  }

  validateForm() {
    let isValid = true
    
    this.fieldTargets.forEach(field => {
      this.validateField(field)
      if (field.classList.contains('border-red-500')) {
        isValid = false
      }
    })

    return isValid
  }

  showFieldErrors(field, errors) {
    const errorContainer = this.createErrorContainer(field)
    errorContainer.innerHTML = errors.map(error => 
      `<div class="text-red-600 text-sm mt-1" role="alert">${error}</div>`
    ).join('')
  }

  clearFieldErrors(field) {
    const existingError = field.parentNode.querySelector('.field-errors')
    if (existingError) {
      existingError.remove()
    }
  }

  createErrorContainer(field) {
    let errorContainer = field.parentNode.querySelector('.field-errors')
    if (!errorContainer) {
      errorContainer = document.createElement('div')
      errorContainer.className = 'field-errors'
      field.parentNode.appendChild(errorContainer)
    }
    return errorContainer
  }

  markFieldValid(field) {
    field.classList.remove('border-gray-300', 'border-red-500')
    field.classList.add('border-green-500')
    
    // Add success icon
    this.addFieldIcon(field, 'success')
  }

  markFieldInvalid(field) {
    field.classList.remove('border-gray-300', 'border-green-500')
    field.classList.add('border-red-500')
    
    // Add error icon
    this.addFieldIcon(field, 'error')
  }

  markFieldNeutral(field) {
    field.classList.remove('border-green-500', 'border-red-500')
    field.classList.add('border-gray-300')
    
    // Remove icon
    this.removeFieldIcon(field)
  }

  addFieldIcon(field, type) {
    this.removeFieldIcon(field)
    
    const icon = document.createElement('div')
    icon.className = 'absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none field-icon'
    
    if (type === 'success') {
      icon.innerHTML = `
        <svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
        </svg>
      `
    } else if (type === 'error') {
      icon.innerHTML = `
        <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
        </svg>
      `
    } else if (type === 'loading') {
      icon.innerHTML = `
        <svg class="w-5 h-5 text-gray-400 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      `
    }

    // Make field container relative if it isn't already
    if (!field.parentNode.classList.contains('relative')) {
      field.parentNode.classList.add('relative')
    }

    field.parentNode.appendChild(icon)
  }

  showLoadingState(field) {
    this.addFieldIcon(field, 'loading')
    const errorContainer = field.parentNode.querySelector('.field-errors')
    if (errorContainer) {
      errorContainer.innerHTML = '<div class="text-gray-500 text-sm mt-1">Checking...</div>'
    }
  }

  clearLoadingState(field) {
    // Loading state will be cleared when we show success/error state
  }

  // Debounce helper
  debounce(func) {
    let timeoutId
    return (...args) => {
      clearTimeout(timeoutId)
      timeoutId = setTimeout(() => func.apply(this, args), this.debounceValue)
    }
  }

  removeFieldIcon(field) {
    const existingIcon = field.parentNode.querySelector('.field-icon')
    if (existingIcon) {
      existingIcon.remove()
    }
  }

  updateSubmitButton() {
    if (!this.hasSubmitTarget) return

    const hasErrors = this.fieldTargets.some(field => 
      field.classList.contains('border-red-500')
    )

    if (hasErrors) {
      this.submitTarget.disabled = true
      this.submitTarget.classList.add('opacity-50', 'cursor-not-allowed')
    } else {
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  getFieldLabel(field) {
    const label = this.element.querySelector(`label[for="${field.id}"]`) || 
                  this.element.querySelector(`label[for="${field.getAttribute('name')}"]`)
    return label ? label.textContent.replace('*', '').trim() : 'Field'
  }

  // Form submit handler
  submit(event) {
    if (!this.validateForm()) {
      event.preventDefault()
      event.stopPropagation()
      
      // Focus first invalid field
      const firstInvalidField = this.fieldTargets.find(field => 
        field.classList.contains('border-red-500')
      )
      if (firstInvalidField) {
        firstInvalidField.focus()
      }
    }
  }
}