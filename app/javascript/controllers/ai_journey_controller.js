import { Controller } from "@hotwired/stimulus"

// AI Journey Controller - Handles AI-powered journey suggestions
export default class extends Controller {
  static targets = ["loading", "suggestions", "customizeModal", "feedbackMessage"]

  connect() {
    console.log("AI Journey controller connected")
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  }

  // Refresh AI suggestions with brand context
  async refreshSuggestions(event) {
    event.preventDefault()
    
    // Show loading state
    this.showLoading()
    
    try {
      const response = await fetch(`/journeys/${this.getJourneyId()}/suggestions.json`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (!response.ok) throw new Error('Failed to fetch suggestions')
      
      const data = await response.json()
      
      // Update suggestions in UI
      this.updateSuggestions(data.suggestions)
      
      // Show success message
      this.showFeedback('New AI suggestions generated!', 'success')
    } catch (error) {
      console.error('Error fetching AI suggestions:', error)
      this.showFeedback('Failed to generate suggestions. Please try again.', 'error')
    } finally {
      this.hideLoading()
    }
  }

  // Apply a suggestion to the journey
  async applySuggestion(event) {
    const button = event.currentTarget
    const suggestionData = button.dataset.suggestionData
    
    // Disable button to prevent double submission
    button.disabled = true
    button.textContent = 'Applying...'
    
    try {
      const response = await fetch(`/journeys/${this.getJourneyId()}/apply_ai_suggestion`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          suggestion: JSON.parse(suggestionData)
        })
      })

      if (!response.ok) throw new Error('Failed to apply suggestion')
      
      const result = await response.json()
      
      if (result.success) {
        // Track acceptance
        this.trackSuggestionAcceptance(suggestionData)
        
        // Show success and redirect
        this.showFeedback('Suggestion applied successfully!', 'success')
        
        // Reload page to show new step
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      }
    } catch (error) {
      console.error('Error applying suggestion:', error)
      this.showFeedback('Failed to apply suggestion. Please try again.', 'error')
      
      // Re-enable button
      button.disabled = false
      button.textContent = 'Apply to Journey'
    }
  }

  // Customize a suggestion before applying
  customizeSuggestion(event) {
    const suggestionIndex = event.currentTarget.dataset.suggestionIndex
    const suggestionCard = document.querySelector(`[data-suggestion-id="${suggestionIndex}"]`)
    
    // Toggle edit mode
    if (suggestionCard.classList.contains('editing')) {
      this.saveCustomization(suggestionIndex)
    } else {
      this.enableEditMode(suggestionCard)
    }
  }

  // Enable edit mode for a suggestion
  enableEditMode(card) {
    card.classList.add('editing', 'ring-2', 'ring-purple-500')
    
    // Make title and description editable
    const title = card.querySelector('h3')
    const description = card.querySelector('.text-gray-600')
    
    if (title) {
      title.contentEditable = true
      title.classList.add('bg-yellow-50', 'px-2', 'rounded')
    }
    
    if (description) {
      description.contentEditable = true
      description.classList.add('bg-yellow-50', 'px-2', 'rounded')
    }
    
    // Change button text
    const customizeBtn = card.querySelector('[data-action*="customizeSuggestion"]')
    if (customizeBtn) {
      customizeBtn.textContent = 'Save Changes'
      customizeBtn.classList.add('bg-green-600', 'text-white', 'hover:bg-green-700')
    }
  }

  // Save customization
  saveCustomization(suggestionIndex) {
    const card = document.querySelector(`[data-suggestion-id="${suggestionIndex}"]`)
    card.classList.remove('editing', 'ring-2', 'ring-purple-500')
    
    // Disable editing
    const editables = card.querySelectorAll('[contenteditable="true"]')
    editables.forEach(el => {
      el.contentEditable = false
      el.classList.remove('bg-yellow-50', 'px-2', 'rounded')
    })
    
    // Reset button
    const customizeBtn = card.querySelector('[data-action*="customizeSuggestion"]')
    if (customizeBtn) {
      customizeBtn.textContent = 'Customize'
      customizeBtn.classList.remove('bg-green-600', 'text-white', 'hover:bg-green-700')
    }
    
    this.showFeedback('Customization saved!', 'success')
  }

  // Provide feedback on a suggestion
  async provideFeedback(event) {
    const button = event.currentTarget
    const feedback = button.dataset.feedback
    const suggestionIndex = button.dataset.suggestionIndex
    
    // Visual feedback
    button.classList.add('scale-125')
    setTimeout(() => button.classList.remove('scale-125'), 200)
    
    try {
      const response = await fetch(`/journeys/${this.getJourneyId()}/ai_feedback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          suggestion_index: suggestionIndex,
          feedback: feedback
        })
      })

      if (!response.ok) throw new Error('Failed to save feedback')
      
      // Update UI to show feedback was recorded
      if (feedback === 'helpful') {
        button.classList.add('text-green-600')
        this.showFeedback('Thanks for the feedback! This helps improve future suggestions.', 'success')
      } else {
        button.classList.add('text-red-600')
        this.showFeedback('Thanks for the feedback! We\'ll work on better suggestions.', 'info')
      }
    } catch (error) {
      console.error('Error saving feedback:', error)
    }
  }

  // Track suggestion acceptance for learning
  async trackSuggestionAcceptance(suggestionData) {
    try {
      await fetch('/api/v1/ai_analytics/suggestion_accepted', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          journey_id: this.getJourneyId(),
          suggestion: suggestionData,
          timestamp: new Date().toISOString()
        })
      })
    } catch (error) {
      console.error('Error tracking acceptance:', error)
    }
  }

  // Update suggestions in the UI
  updateSuggestions(suggestions) {
    if (!this.hasSuggestionsTarget) return
    
    // Clear current suggestions
    this.suggestionsTarget.innerHTML = ''
    
    // Add new suggestions
    suggestions.forEach((suggestion, index) => {
      const card = this.createSuggestionCard(suggestion, index)
      this.suggestionsTarget.appendChild(card)
    })
  }

  // Create a suggestion card element
  createSuggestionCard(suggestion, index) {
    const template = document.querySelector('#suggestion-card-template')
    if (template) {
      const clone = template.content.cloneNode(true)
      // Populate with suggestion data
      return clone
    }
    
    // Fallback: create basic card
    const div = document.createElement('div')
    div.className = 'bg-white rounded-lg border p-4'
    div.innerHTML = `
      <h3 class="font-semibold">${suggestion.title}</h3>
      <p class="text-gray-600">${suggestion.description}</p>
    `
    return div
  }

  // Show loading state
  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
    if (this.hasSuggestionsTarget) {
      this.suggestionsTarget.classList.add('opacity-50')
    }
  }

  // Hide loading state
  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
    if (this.hasSuggestionsTarget) {
      this.suggestionsTarget.classList.remove('opacity-50')
    }
  }

  // Show feedback message
  showFeedback(message, type) {
    // Create or update feedback element
    let feedback = document.getElementById('ai-feedback-message')
    if (!feedback) {
      feedback = document.createElement('div')
      feedback.id = 'ai-feedback-message'
      feedback.className = 'fixed top-4 right-4 z-50 transition-all duration-300'
      document.body.appendChild(feedback)
    }
    
    // Set message and style based on type
    const bgColor = type === 'success' ? 'bg-green-500' : 
                   type === 'error' ? 'bg-red-500' : 
                   'bg-blue-500'
    
    feedback.innerHTML = `
      <div class="${bgColor} text-white px-6 py-3 rounded-lg shadow-lg flex items-center gap-2">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                d="${type === 'success' ? 'M5 13l4 4L19 7' : 
                     type === 'error' ? 'M6 18L18 6M6 6l12 12' : 
                     'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'}" />
        </svg>
        <span>${message}</span>
      </div>
    `
    
    // Auto-hide after 3 seconds
    setTimeout(() => {
      feedback.classList.add('opacity-0')
      setTimeout(() => feedback.remove(), 300)
    }, 3000)
  }

  // Get journey ID from URL or data attribute
  getJourneyId() {
    // Try to get from URL
    const pathMatch = window.location.pathname.match(/journeys\/(\d+)/)
    if (pathMatch) return pathMatch[1]
    
    // Try to get from data attribute
    return this.element.dataset.journeyId
  }
}