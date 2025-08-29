import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-validation"
export default class extends Controller {
  static targets = ["field", "error", "submit"]

  connect() {
    console.log("Form validation controller connected")
    this.validateOnInput()
  }

  validateOnInput() {
    this.fieldTargets.forEach(field => {
      field.addEventListener('input', () => this.validateField(field))
      field.addEventListener('blur', () => this.validateField(field))
    })
  }

  validateField(field) {
    const errors = []
    const fieldName = field.getAttribute('name') || field.id

    // Clear previous errors
    this.clearFieldErrors(field)

    // Required field validation
    if (field.hasAttribute('required') && !field.value.trim()) {
      errors.push(`${this.getFieldLabel(field)} is required`)
    }

    // Email validation
    if (field.type === 'email' && field.value) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      if (!emailRegex.test(field.value)) {
        errors.push('Please enter a valid email address')
      }
    }

    // Password validation
    if (field.type === 'password' && field.value) {
      if (field.value.length < 8) {
        errors.push('Password must be at least 8 characters long')
      }
    }

    // Password confirmation validation
    if (field.getAttribute('name')?.includes('confirmation')) {
      const originalField = this.element.querySelector(`[name="${field.getAttribute('name').replace('_confirmation', '')}"]`)
      if (originalField && field.value !== originalField.value) {
        errors.push('Password confirmation does not match')
      }
    }

    // Display errors or success
    if (errors.length > 0) {
      this.showFieldErrors(field, errors)
      this.markFieldInvalid(field)
    } else if (field.value.trim()) {
      this.markFieldValid(field)
    } else {
      this.markFieldNeutral(field)
    }

    this.updateSubmitButton()
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
    }

    // Make field container relative if it isn't already
    if (!field.parentNode.classList.contains('relative')) {
      field.parentNode.classList.add('relative')
    }

    field.parentNode.appendChild(icon)
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