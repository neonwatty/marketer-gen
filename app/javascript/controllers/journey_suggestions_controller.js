import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suggestionsContainer", "loadingSpinner", "stageSelect", "refreshButton"]
  static values = { journeyId: Number, currentStage: String }

  connect() {
    this.loadSuggestions()
  }

  // Refresh suggestions when stage changes
  stageChanged() {
    const selectedStage = this.stageSelectTarget.value
    this.currentStageValue = selectedStage
    this.loadSuggestions()
  }

  // Manual refresh button
  refresh() {
    this.loadSuggestions()
  }

  // Load suggestions from the backend
  async loadSuggestions() {
    this.showLoading()
    
    try {
      const url = new URL(`/journeys/${this.journeyIdValue}/suggestions`, window.location.origin)
      if (this.currentStageValue) {
        url.searchParams.set('stage', this.currentStageValue)
      }
      url.searchParams.set('limit', '5')

      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      this.renderSuggestions(data.suggestions)
      this.hideLoading()
    } catch (error) {
      console.error('Error loading suggestions:', error)
      this.showError('Failed to load suggestions. Please try again.')
      this.hideLoading()
    }
  }

  // Render suggestions in the UI
  renderSuggestions(suggestions) {
    if (!suggestions || suggestions.length === 0) {
      this.suggestionsContainerTarget.innerHTML = `
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-center">
          <p class="text-yellow-700">No new suggestions available for the current stage and existing steps.</p>
          <p class="text-sm text-yellow-600 mt-2">Try changing the stage or adding more steps to get new suggestions.</p>
        </div>
      `
      return
    }

    const suggestionsHtml = suggestions.map(suggestion => this.createSuggestionCard(suggestion)).join('')
    this.suggestionsContainerTarget.innerHTML = `
      <div class="space-y-4">
        ${suggestionsHtml}
      </div>
    `
  }

  // Create individual suggestion card HTML
  createSuggestionCard(suggestion) {
    const priorityColor = this.getPriorityColor(suggestion.priority)
    const effortBadge = this.getEffortBadge(suggestion.estimated_effort)
    const channelsList = suggestion.suggested_channels?.slice(0, 3).join(', ') || 'Not specified'
    
    return `
      <div class="bg-white border border-gray-200 rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow">
        <div class="flex items-start justify-between mb-3">
          <div class="flex-1">
            <h4 class="text-lg font-medium text-gray-900 mb-1">${this.escapeHtml(suggestion.title)}</h4>
            <p class="text-sm text-gray-600 mb-2">${this.escapeHtml(suggestion.description)}</p>
            <div class="flex items-center space-x-3 text-xs">
              <span class="inline-flex items-center px-2 py-1 rounded-full bg-${priorityColor}-100 text-${priorityColor}-800">
                ${this.escapeHtml(suggestion.priority)} priority
              </span>
              ${effortBadge}
              <span class="text-gray-500">Type: ${this.escapeHtml(suggestion.step_type)}</span>
            </div>
          </div>
          <button 
            class="ml-4 bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            data-action="click->journey-suggestions#addSuggestion"
            data-suggestion='${JSON.stringify(suggestion).replace(/'/g, "&apos;")}'
          >
            Add Step
          </button>
        </div>
        
        ${this.renderSuggestionDetails(suggestion)}
      </div>
    `
  }

  // Render additional suggestion details
  renderSuggestionDetails(suggestion) {
    let detailsHtml = ''

    // Suggested channels
    if (suggestion.suggested_channels && suggestion.suggested_channels.length > 0) {
      const channelsList = suggestion.suggested_channels.map(channel => 
        `<span class="inline-block bg-gray-100 text-gray-700 px-2 py-1 rounded text-xs mr-2 mb-1">${this.escapeHtml(channel)}</span>`
      ).join('')
      
      detailsHtml += `
        <div class="mt-3 pt-3 border-t border-gray-100">
          <h5 class="text-sm font-medium text-gray-700 mb-2">Suggested Channels:</h5>
          <div>${channelsList}</div>
        </div>
      `
    }

    // Content suggestions
    if (suggestion.content_suggestions && Object.keys(suggestion.content_suggestions).length > 0) {
      detailsHtml += this.renderContentSuggestions(suggestion.content_suggestions)
    }

    return detailsHtml
  }

  // Render content suggestions
  renderContentSuggestions(contentSuggestions) {
    let contentHtml = `
      <div class="mt-3 pt-3 border-t border-gray-100">
        <h5 class="text-sm font-medium text-gray-700 mb-2">Content Suggestions:</h5>
        <div class="space-y-2 text-sm text-gray-600">
    `

    if (contentSuggestions.subject_line_ideas) {
      contentHtml += `
        <div>
          <span class="font-medium">Subject Lines:</span> 
          ${contentSuggestions.subject_line_ideas.slice(0, 2).map(idea => `"${this.escapeHtml(idea)}"`).join(', ')}
        </div>
      `
    }

    if (contentSuggestions.content_structure) {
      contentHtml += `
        <div>
          <span class="font-medium">Structure:</span> 
          ${this.escapeHtml(contentSuggestions.content_structure)}
        </div>
      `
    }

    if (contentSuggestions.call_to_action) {
      contentHtml += `
        <div>
          <span class="font-medium">Call to Action:</span> 
          ${this.escapeHtml(contentSuggestions.call_to_action)}
        </div>
      `
    }

    contentHtml += `
        </div>
      </div>
    `

    return contentHtml
  }

  // Add a suggested step to the journey
  async addSuggestion(event) {
    const button = event.target
    const suggestionData = JSON.parse(button.dataset.suggestion.replace(/&apos;/g, "'"))
    
    // Disable button to prevent double-clicks
    button.disabled = true
    button.textContent = 'Adding...'

    try {
      // Create the journey step
      const formData = new FormData()
      formData.append('journey_step[title]', suggestionData.title)
      formData.append('journey_step[description]', suggestionData.description)
      formData.append('journey_step[step_type]', suggestionData.step_type)
      
      // Add suggested channel if available
      if (suggestionData.suggested_channels && suggestionData.suggested_channels.length > 0) {
        formData.append('journey_step[channel]', suggestionData.suggested_channels[0])
      }

      const response = await fetch(`/journeys/${this.journeyIdValue}/journey_steps`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: formData
      })

      if (response.ok) {
        // Success - reload the page to show the new step
        window.location.reload()
      } else {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
    } catch (error) {
      console.error('Error adding suggestion:', error)
      alert('Failed to add step. Please try again.')
      
      // Re-enable button
      button.disabled = false
      button.textContent = 'Add Step'
    }
  }

  // Show loading spinner
  showLoading() {
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.remove('hidden')
    }
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.disabled = true
    }
  }

  // Hide loading spinner
  hideLoading() {
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.add('hidden')
    }
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.disabled = false
    }
  }

  // Show error message
  showError(message) {
    this.suggestionsContainerTarget.innerHTML = `
      <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-center">
        <p class="text-red-700">${this.escapeHtml(message)}</p>
        <button 
          class="mt-2 text-red-600 hover:text-red-800 underline text-sm"
          data-action="click->journey-suggestions#refresh"
        >
          Try Again
        </button>
      </div>
    `
  }

  // Helper methods
  getPriorityColor(priority) {
    switch (priority) {
      case 'high': return 'red'
      case 'medium': return 'yellow'
      case 'low': return 'green'
      default: return 'gray'
    }
  }

  getEffortBadge(effort) {
    const colors = {
      'low': 'green',
      'medium': 'yellow',
      'high': 'red'
    }
    const color = colors[effort] || 'gray'
    return `<span class="inline-flex items-center px-2 py-1 rounded-full bg-${color}-100 text-${color}-800">${this.escapeHtml(effort)} effort</span>`
  }

  escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}