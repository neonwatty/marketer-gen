import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="auto-submit"
export default class extends Controller {
  static values = { 
    delay: { type: Number, default: 300 },
    skipFields: { type: Array, default: [] }
  }

  connect() {
    console.log("Auto submit controller connected")
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  submit(event) {
    // Clear any existing timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Skip auto-submit for certain field types
    const fieldName = event.target.name
    if (this.skipFieldsValue.includes(fieldName)) {
      return
    }

    // For text inputs, add a delay to avoid too many requests
    const isTextInput = event.target.type === "text" || event.target.type === "search"
    const delay = isTextInput ? this.delayValue : 0

    // Set timeout for delayed submission
    this.timeout = setTimeout(() => {
      this.performSubmit()
    }, delay)
  }

  performSubmit() {
    // Add loading state
    this.addLoadingState()
    
    // Submit the form
    this.element.requestSubmit()
  }

  addLoadingState() {
    const submitButton = this.element.querySelector('[type="submit"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.classList.add("opacity-50")
    }

    // Add loading indicator to form
    this.element.classList.add("pointer-events-none", "opacity-75")
  }

  removeLoadingState() {
    const submitButton = this.element.querySelector('[type="submit"]')
    if (submitButton) {
      submitButton.disabled = false
      submitButton.classList.remove("opacity-50")
    }

    this.element.classList.remove("pointer-events-none", "opacity-75")
  }

  // Called after Turbo response
  turbo:submit-end() {
    this.removeLoadingState()
  }
}