import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-validation"
export default class extends Controller {
  static targets = [
    "emailField",
    "passwordField", 
    "passwordConfirmationField",
    "submitButton",
    "emailError",
    "passwordError",
    "passwordConfirmationError",
    "passwordStrength"
  ]

  static values = {
    mode: String // "login" or "registration"
  }

  connect() {
    this.validateForm()
  }

  validateEmail() {
    const email = this.emailFieldTarget.value
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    
    if (email === "") {
      this.clearFieldValidation(this.emailFieldTarget)
      this.hideError(this.emailErrorTarget)
      this.validateForm()
      return
    }

    if (emailRegex.test(email)) {
      this.showFieldSuccess(this.emailFieldTarget)
      this.hideError(this.emailErrorTarget)
    } else {
      this.showFieldError(this.emailFieldTarget)
      this.showError(this.emailErrorTarget, "Please enter a valid email address")
    }
    
    this.validateForm()
  }

  validatePassword() {
    const password = this.passwordFieldTarget.value
    
    if (password === "") {
      this.clearFieldValidation(this.passwordFieldTarget)
      this.hideError(this.passwordErrorTarget)
      if (this.hasPasswordStrengthTarget) {
        this.hidePasswordStrength()
      }
      this.validateForm()
      return
    }

    // For login, just check minimum length
    if (this.modeValue === "login") {
      if (password.length >= 6) {
        this.showFieldSuccess(this.passwordFieldTarget)
        this.hideError(this.passwordErrorTarget)
      } else {
        this.showFieldError(this.passwordFieldTarget)
        this.showError(this.passwordErrorTarget, "Password must be at least 6 characters")
      }
    } else {
      // For registration, show strength indicator
      this.updatePasswordStrength(password)
      
      if (password.length >= 6) {
        this.showFieldSuccess(this.passwordFieldTarget)
        this.hideError(this.passwordErrorTarget)
      } else {
        this.showFieldError(this.passwordFieldTarget)
        this.showError(this.passwordErrorTarget, "Password must be at least 6 characters")
      }
    }
    
    // Also validate password confirmation if it exists and has a value
    if (this.hasPasswordConfirmationFieldTarget && this.passwordConfirmationFieldTarget.value !== "") {
      this.validatePasswordConfirmation()
    }
    
    this.validateForm()
  }

  validatePasswordConfirmation() {
    if (!this.hasPasswordConfirmationFieldTarget) {return}
    
    const password = this.passwordFieldTarget.value
    const confirmation = this.passwordConfirmationFieldTarget.value
    
    if (confirmation === "") {
      this.clearFieldValidation(this.passwordConfirmationFieldTarget)
      this.hideError(this.passwordConfirmationErrorTarget)
      this.validateForm()
      return
    }

    if (password === confirmation) {
      this.showFieldSuccess(this.passwordConfirmationFieldTarget)
      this.hideError(this.passwordConfirmationErrorTarget)
    } else {
      this.showFieldError(this.passwordConfirmationFieldTarget)
      this.showError(this.passwordConfirmationErrorTarget, "Passwords do not match")
    }
    
    this.validateForm()
  }

  updatePasswordStrength(password) {
    if (!this.hasPasswordStrengthTarget) {return}

    const strength = this.calculatePasswordStrength(password)
    const strengthElement = this.passwordStrengthTarget
    
    // Remove existing classes
    strengthElement.classList.remove('hidden', 'text-red-500', 'text-yellow-500', 'text-green-500')
    
    if (password.length === 0) {
      this.hidePasswordStrength()
      return
    }

    strengthElement.classList.remove('hidden')
    
    if (strength.level === 'weak') {
      strengthElement.classList.add('text-red-500')
      strengthElement.textContent = `Weak - ${strength.message}`
    } else if (strength.level === 'medium') {
      strengthElement.classList.add('text-yellow-500')
      strengthElement.textContent = `Medium - ${strength.message}`
    } else {
      strengthElement.classList.add('text-green-500')
      strengthElement.textContent = `Strong - ${strength.message}`
    }
  }

  hidePasswordStrength() {
    if (this.hasPasswordStrengthTarget) {
      this.passwordStrengthTarget.classList.add('hidden')
    }
  }

  calculatePasswordStrength(password) {
    const length = password.length
    const hasLower = /[a-z]/.test(password)
    const hasUpper = /[A-Z]/.test(password)
    const hasNumber = /\d/.test(password)
    const hasSpecial = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)

    if (length < 8) {
      return { level: 'weak', message: 'Use at least 8 characters' }
    }

    const criteriaMet = [hasLower, hasUpper, hasNumber, hasSpecial].filter(Boolean).length

    if (criteriaMet >= 3) {
      return { level: 'strong', message: 'Great password!' }
    } else if (criteriaMet >= 2 && length >= 8) {
      return { level: 'medium', message: 'Add special characters for better security' }
    } else {
      return { level: 'weak', message: 'Use a mix of letters and numbers' }
    }
  }

  validateForm() {
    let isValid = true

    // Check email
    const email = this.emailFieldTarget.value
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!email || !emailRegex.test(email)) {
      isValid = false
    }

    // Check password
    const password = this.passwordFieldTarget.value
    if (!password || password.length < 6) {
      isValid = false
    }

    // Check password confirmation for registration
    if (this.modeValue === "registration" && this.hasPasswordConfirmationFieldTarget) {
      const confirmation = this.passwordConfirmationFieldTarget.value
      if (!confirmation || password !== confirmation) {
        isValid = false
      }
    }

    // Enable/disable submit button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !isValid
      
      if (isValid) {
        this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
        this.submitButtonTarget.classList.add('cursor-pointer')
      } else {
        this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
        this.submitButtonTarget.classList.remove('cursor-pointer')
      }
    }
  }

  showFieldSuccess(field) {
    field.classList.remove('border-red-500', 'border-gray-400')
    field.classList.add('border-green-500')
  }

  showFieldError(field) {
    field.classList.remove('border-green-500', 'border-gray-400')
    field.classList.add('border-red-500')
  }

  clearFieldValidation(field) {
    field.classList.remove('border-green-500', 'border-red-500')
    field.classList.add('border-gray-400')
  }

  showError(errorElement, message) {
    errorElement.textContent = message
    errorElement.classList.remove('hidden')
  }

  hideError(errorElement) {
    errorElement.classList.add('hidden')
  }
}