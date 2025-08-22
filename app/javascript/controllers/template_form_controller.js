import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="template-form"
export default class extends Controller {
  static targets = ["journeyName", "journeyDescription", "templateType"]

  connect() {
    console.log("Template form controller connected")
  }

  showCustomization(event) {
    // Prevent default form submission
    event.preventDefault()

    const form = event.target
    const formData = new FormData(form)
    
    // Get template information
    const templateId = formData.get("template_id")
    const journeyName = formData.get("journey_name")
    
    // Show confirmation modal or customization panel
    if (this.shouldShowCustomization()) {
      this.displayCustomizationModal(templateId, journeyName, form)
    } else {
      // Submit directly if no customization needed
      this.submitForm(form)
    }
  }

  shouldShowCustomization() {
    // Show customization if user hasn't filled in optional fields
    // or if this is an advanced template
    return true // For now, always show customization
  }

  displayCustomizationModal(templateId, journeyName, originalForm) {
    // Create modal HTML
    const modalHTML = this.createCustomizationModal(templateId, journeyName, originalForm)
    
    // Add modal to page
    document.body.insertAdjacentHTML("beforeend", modalHTML)
    
    // Focus on first input
    const modal = document.getElementById("template-customization-modal")
    const firstInput = modal.querySelector("input, textarea, select")
    if (firstInput) {
      firstInput.focus()
    }
    
    // Setup modal event listeners
    this.setupModalEventListeners(modal, originalForm)
  }

  createCustomizationModal(templateId, journeyName, originalForm) {
    return `
      <div id="template-customization-modal" 
           class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
        <div class="relative top-20 mx-auto p-5 border w-11/12 md:w-2/3 lg:w-1/2 shadow-lg rounded-md bg-white">
          <div class="mt-3">
            <div class="flex items-center justify-between mb-6">
              <h3 class="text-lg font-medium text-gray-900">Customize Your Journey</h3>
              <button type="button" 
                      class="text-gray-400 hover:text-gray-600"
                      onclick="this.closest('#template-customization-modal').remove()">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
            
            <form id="customization-form" action="/journeys/create_from_template" method="post" class="space-y-4">
              <input type="hidden" name="authenticity_token" value="${this.getCSRFToken()}">
              <input type="hidden" name="template_id" value="${templateId}">
              
              <div>
                <label for="journey_name" class="block text-sm font-medium text-gray-700 mb-2">
                  Journey Name
                </label>
                <input type="text" 
                       id="journey_name" 
                       name="journey_name" 
                       value="${journeyName}"
                       class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                       placeholder="Enter a name for your journey">
              </div>
              
              <div>
                <label for="journey_description" class="block text-sm font-medium text-gray-700 mb-2">
                  Description (Optional)
                </label>
                <textarea id="journey_description" 
                         name="journey_description" 
                         rows="3"
                         class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                         placeholder="Describe the purpose and goals of this journey"></textarea>
              </div>
              
              <div>
                <label for="template_type" class="block text-sm font-medium text-gray-700 mb-2">
                  Template Type
                </label>
                <select id="template_type" 
                        name="template_type"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500">
                  <option value="custom">Custom Template</option>
                  <option value="email">Email Campaign</option>
                  <option value="social_media">Social Media Campaign</option>
                  <option value="content">Content Marketing</option>
                  <option value="event">Event Promotion</option>
                </select>
              </div>
              
              <div class="flex justify-end space-x-3 pt-6 border-t border-gray-200">
                <button type="button" 
                        onclick="this.closest('#template-customization-modal').remove()"
                        class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-4 rounded-lg transition-colors">
                  Cancel
                </button>
                <button type="submit"
                        class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors">
                  Create Journey
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    `
  }

  setupModalEventListeners(modal, originalForm) {
    // Handle form submission
    const customizationForm = modal.querySelector("#customization-form")
    customizationForm.addEventListener("submit", (event) => {
      event.preventDefault()
      
      // Add loading state
      const submitButton = event.target.querySelector('[type="submit"]')
      submitButton.disabled = true
      submitButton.textContent = "Creating..."
      
      // Submit with form data
      this.submitCustomizedForm(event.target)
    })
    
    // Handle escape key
    const escapeHandler = (event) => {
      if (event.key === "Escape") {
        modal.remove()
        document.removeEventListener("keydown", escapeHandler)
      }
    }
    document.addEventListener("keydown", escapeHandler)
    
    // Handle backdrop click
    modal.addEventListener("click", (event) => {
      if (event.target === modal) {
        modal.remove()
        document.removeEventListener("keydown", escapeHandler)
      }
    })
  }

  submitCustomizedForm(form) {
    const formData = new FormData(form)
    
    fetch(form.action, {
      method: "POST",
      body: formData,
      headers: {
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => {
      if (response.redirected) {
        window.location.href = response.url
      } else {
        return response.text()
      }
    })
    .then(text => {
      if (text) {
        // Handle any response text (errors, etc.)
        console.log("Response:", text)
      }
    })
    .catch(error => {
      console.error("Error creating journey:", error)
      // Re-enable submit button
      const submitButton = form.querySelector('[type="submit"]')
      submitButton.disabled = false
      submitButton.textContent = "Create Journey"
    })
  }

  submitForm(form) {
    // Add loading state
    const submitButton = form.querySelector('[type="submit"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.textContent = "Creating..."
    }
    
    // Submit the form normally
    form.submit()
  }

  getCSRFToken() {
    const metaTag = document.querySelector('meta[name="csrf-token"]')
    return metaTag ? metaTag.getAttribute("content") : ""
  }
}