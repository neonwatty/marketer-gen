import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="inline-edit"
export default class extends Controller {
  static targets = ["field", "display", "editor", "input"]
  static values = { url: String }

  connect() {
    console.log("Inline edit controller connected")
    this.originalValues = new Map()
    this.isEditing = false
  }

  // Start editing a field
  startEdit(event) {
    event.preventDefault()
    
    if (this.isEditing) {return}
    
    const field = event.target.closest('[data-inline-edit-target="field"]')
    if (!field) {return}
    
    const display = field.querySelector('[data-inline-edit-target="display"]')
    const editor = field.querySelector('[data-inline-edit-target="editor"]')
    const input = field.querySelector('[data-inline-edit-target="input"]')
    
    if (!display || !editor || !input) {return}
    
    // Store original value
    const fieldName = field.dataset.field
    this.originalValues.set(fieldName, input.value)
    
    // Switch to edit mode
    display.classList.add('hidden')
    editor.classList.remove('hidden')
    
    // Focus input and select content
    input.focus()
    if (input.type === 'text') {
      input.select()
    }
    
    this.isEditing = true
    
    // Add escape key listener
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.handleKeydown)
    
    // Add click outside listener
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.handleClickOutside)
  }

  // Save the edited value
  async save(event) {
    event.preventDefault()
    
    const field = event.target.closest('[data-inline-edit-target="field"]')
    if (!field) {return}
    
    const input = field.querySelector('[data-inline-edit-target="input"]')
    const fieldName = field.dataset.field
    const newValue = input.value.trim()
    
    // Validate input
    if (!this.validateField(fieldName, newValue)) {
      this.showFieldError(field, 'Invalid value')
      return
    }
    
    // Show loading state
    this.showLoadingState(field, true)
    
    try {
      await this.updateField(fieldName, newValue)
      this.commitEdit(field, newValue)
      this.showSuccess('Updated successfully')
    } catch (error) {
      console.error('Save error:', error)
      this.showFieldError(field, error.message || 'Failed to update')
    } finally {
      this.showLoadingState(field, false)
    }
  }

  // Cancel editing
  cancel(event) {
    event.preventDefault()
    
    const field = event.target.closest('[data-inline-edit-target="field"]')
    if (!field) {return}
    
    const input = field.querySelector('[data-inline-edit-target="input"]')
    const fieldName = field.dataset.field
    
    // Restore original value
    if (this.originalValues.has(fieldName)) {
      input.value = this.originalValues.get(fieldName)
    }
    
    this.exitEditMode(field)
  }

  // Commit the edit and update display
  commitEdit(field, newValue) {
    const display = field.querySelector('[data-inline-edit-target="display"]')
    const fieldName = field.dataset.field
    
    // Update display text
    if (display) {
      const displayElement = display.querySelector('[data-action*="startEdit"]')
      if (displayElement) {
        this.updateDisplayValue(displayElement, fieldName, newValue)
      }
    }
    
    // Clear original value
    this.originalValues.delete(fieldName)
    
    this.exitEditMode(field)
  }

  // Exit edit mode and return to display
  exitEditMode(field) {
    const display = field.querySelector('[data-inline-edit-target="display"]')
    const editor = field.querySelector('[data-inline-edit-target="editor"]')
    
    if (display && editor) {
      editor.classList.add('hidden')
      display.classList.remove('hidden')
    }
    
    this.isEditing = false
    this.clearFieldError(field)
    
    // Remove event listeners
    document.removeEventListener('keydown', this.handleKeydown)
    document.removeEventListener('click', this.handleClickOutside)
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    if (!this.isEditing) {return}
    
    if (event.key === 'Escape') {
      event.preventDefault()
      const activeField = document.querySelector('[data-inline-edit-target="editor"]:not(.hidden)')
      if (activeField) {
        const field = activeField.closest('[data-inline-edit-target="field"]')
        this.cancel({ preventDefault: () => {}, target: activeField })
      }
    } else if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      const activeInput = document.activeElement
      if (activeInput && activeInput.matches('[data-inline-edit-target="input"]')) {
        const field = activeInput.closest('[data-inline-edit-target="field"]')
        this.save({ preventDefault: () => {}, target: activeInput })
      }
    }
  }

  // Handle clicking outside the editor
  handleClickOutside(event) {
    if (!this.isEditing) {return}
    
    const activeEditor = document.querySelector('[data-inline-edit-target="editor"]:not(.hidden)')
    if (activeEditor && !activeEditor.contains(event.target)) {
      const field = activeEditor.closest('[data-inline-edit-target="field"]')
      this.cancel({ preventDefault: () => {}, target: activeEditor })
    }
  }

  // Update field value on server
  async updateField(fieldName, value) {
    if (!this.urlValue) {
      throw new Error('No update URL configured')
    }

    const formData = new FormData()
    formData.append('_method', 'PATCH')
    formData.append(`campaign[${fieldName}]`, value)
    
    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      formData.append('authenticity_token', csrfToken)
    }

    const response = await fetch(this.urlValue, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json'
      }
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ error: 'Update failed' }))
      throw new Error(errorData.error || `HTTP ${response.status}`)
    }

    return response.json()
  }

  // Validate field value
  validateField(fieldName, value) {
    switch (fieldName) {
      case 'name':
        return value.length > 0 && value.length <= 255
      case 'status':
        return ['draft', 'active', 'paused', 'completed', 'archived'].includes(value)
      case 'campaign_type':
        return value === '' || this.isValidCampaignType(value)
      default:
        return true
    }
  }

  // Check if campaign type is valid
  isValidCampaignType(type) {
    const validTypes = [
      'product_launch', 'brand_awareness', 'lead_generation', 'customer_retention',
      'seasonal_promotion', 'content_marketing', 'email_nurture', 'social_media',
      'event_promotion', 'customer_onboarding', 're_engagement', 'cross_sell',
      'upsell', 'referral', 'awareness', 'consideration', 'conversion', 'advocacy',
      'b2b_lead_generation'
    ]
    return validTypes.includes(type)
  }

  // Update display value based on field type
  updateDisplayValue(element, fieldName, value) {
    switch (fieldName) {
      case 'status':
        this.updateStatusDisplay(element, value)
        break
      case 'campaign_type':
        element.textContent = value ? this.humanize(value) : 'Not set'
        break
      default:
        element.textContent = value || 'Not set'
    }
  }

  // Update status display with proper styling
  updateStatusDisplay(element, status) {
    // Remove old status classes
    element.className = element.className.replace(/bg-\w+-100 text-\w+-800/g, '')
    
    // Add new status classes
    const statusClasses = this.getStatusClasses(status)
    element.className += ` ${statusClasses}`
    
    // Update text content
    const textElement = element.querySelector('span:last-child')
    if (textElement) {
      textElement.textContent = this.humanize(status)
    } else {
      element.innerHTML = `${this.getStatusIcon(status)}<span class="ml-1">${this.humanize(status)}</span>`
    }
  }

  // Get status CSS classes
  getStatusClasses(status) {
    const classes = {
      'active': 'bg-green-100 text-green-800',
      'draft': 'bg-gray-100 text-gray-800',
      'paused': 'bg-yellow-100 text-yellow-800',
      'completed': 'bg-blue-100 text-blue-800',
      'archived': 'bg-purple-100 text-purple-800'
    }
    return classes[status] || 'bg-gray-100 text-gray-800'
  }

  // Get status icon
  getStatusIcon(status) {
    // Return appropriate SVG icon based on status
    switch (status) {
      case 'active':
        return `<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>`
      case 'paused':
        return `<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/>
        </svg>`
      default:
        return '<span class="w-3 h-3 mr-1">•</span>'
    }
  }

  // Show loading state
  showLoadingState(field, loading) {
    const buttons = field.querySelectorAll('button')
    buttons.forEach(button => {
      button.disabled = loading
      if (loading) {
        button.style.opacity = '0.6'
      } else {
        button.style.opacity = '1'
      }
    })
  }

  // Show field-specific error
  showFieldError(field, message) {
    this.clearFieldError(field)
    
    const error = document.createElement('div')
    error.className = 'inline-edit-error text-xs text-red-600 mt-1'
    error.textContent = message
    
    const editor = field.querySelector('[data-inline-edit-target="editor"]')
    if (editor) {
      editor.appendChild(error)
    }
  }

  // Clear field error
  clearFieldError(field) {
    const error = field.querySelector('.inline-edit-error')
    if (error) {
      error.remove()
    }
  }

  // Show success message
  showSuccess(message) {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = 'fixed top-4 right-4 bg-green-600 text-white px-4 py-2 rounded-lg shadow-lg z-50 transform translate-x-full transition-transform'
    toast.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <span>${message}</span>
      </div>
    `
    
    document.body.appendChild(toast)
    
    // Slide in
    setTimeout(() => {
      toast.style.transform = 'translateX(0)'
    }, 100)
    
    // Slide out and remove
    setTimeout(() => {
      toast.style.transform = 'translateX(full)'
      setTimeout(() => {
        if (toast.parentElement) {
          toast.remove()
        }
      }, 300)
    }, 3000)
  }

  // Humanize string (convert underscore to title case)
  humanize(str) {
    return str.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }
}