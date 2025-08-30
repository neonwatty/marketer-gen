import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="smart-suggestions"
export default class extends Controller {
  static targets = ["input", "suggestionsList", "suggestionItem", "loadingIndicator"]
  static values = { 
    endpoint: String,
    fieldName: String,
    minLength: { type: Number, default: 2 },
    maxSuggestions: { type: Number, default: 5 },
    showOnFocus: { type: Boolean, default: true }
  }

  connect() {
    console.log("Smart suggestions controller connected for field:", this.fieldNameValue)
    this.isVisible = false
    this.currentFocus = -1
    this.suggestions = []
    
    // Load initial suggestions if configured
    if (this.showOnFocusValue) {
      this.loadInitialSuggestions()
    }
  }

  disconnect() {
    // Clean up event listeners on disconnect
    if (this.boundHandleOutsideClick) {
      document.removeEventListener('click', this.boundHandleOutsideClick, { capture: true })
    }
  }

  async loadInitialSuggestions() {
    if (!this.endpointValue) return

    try {
      const response = await fetch(`${this.endpointValue}?field=${this.fieldNameValue}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.suggestions = data.suggestions || []
      }
    } catch (error) {
      console.error('Failed to load initial suggestions:', error)
    }
  }

  inputFocus() {
    if (this.showOnFocusValue && this.suggestions.length > 0) {
      this.showSuggestions(this.suggestions)
    }
    
    // Hide suggestions when clicking outside - use bound method for proper removal
    this.boundHandleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener('click', this.boundHandleOutsideClick, { capture: true })
  }

  inputBlur(event) {
    // Delay hiding to allow clicking on suggestions
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) {
        this.hideSuggestions()
      }
    }, 150)
  }

  // Hide suggestions when clicking outside the component
  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions()
    }
  }

  async inputKeyup(event) {
    const query = event.target.value.trim()
    
    // Handle keyboard navigation
    if (this.isVisible) {
      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault()
          this.navigateDown()
          return
        case 'ArrowUp':
          event.preventDefault()
          this.navigateUp()
          return
        case 'Enter':
          if (this.currentFocus >= 0) {
            event.preventDefault()
            this.selectSuggestion(this.currentFocus)
            return
          }
          break
        case 'Escape':
          this.hideSuggestions()
          return
      }
    }

    // Load dynamic suggestions based on input
    if (query.length >= this.minLengthValue) {
      this.debounce(() => this.searchSuggestions(query), 300)
    } else if (query.length === 0 && this.showOnFocusValue) {
      this.showSuggestions(this.suggestions)
    } else {
      this.hideSuggestions()
    }
  }

  async searchSuggestions(query) {
    if (!this.endpointValue) return

    this.showLoading()

    try {
      const response = await fetch(`${this.endpointValue}?field=${this.fieldNameValue}&query=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.showSuggestions(data.suggestions || [])
      } else {
        this.hideSuggestions()
      }
    } catch (error) {
      console.error('Suggestion search failed:', error)
      this.hideSuggestions()
    } finally {
      this.hideLoading()
    }
  }

  showSuggestions(suggestions) {
    if (!suggestions || suggestions.length === 0) {
      this.hideSuggestions()
      return
    }

    const limitedSuggestions = suggestions.slice(0, this.maxSuggestionsValue)
    
    // Build suggestions HTML
    const suggestionsHtml = limitedSuggestions.map((suggestion, index) => {
      const text = typeof suggestion === 'string' ? suggestion : suggestion.text
      const description = typeof suggestion === 'object' ? suggestion.description : null
      
      return `
        <div class="suggestion-item px-3 py-2 cursor-pointer hover:bg-blue-50 border-b border-gray-100 last:border-b-0" 
             data-index="${index}"
             data-action="click->smart-suggestions#selectSuggestionByClick">
          <div class="font-medium text-gray-900">${this.escapeHtml(text)}</div>
          ${description ? `<div class="text-sm text-gray-600">${this.escapeHtml(description)}</div>` : ''}
        </div>
      `
    }).join('')

    if (this.hasSuggestionsListTarget) {
      this.suggestionsListTarget.innerHTML = suggestionsHtml
      this.adjustSuggestionsPosition()
      this.suggestionsListTarget.classList.remove('hidden')
      this.isVisible = true
      this.currentFocus = -1
    }
  }
  
  adjustSuggestionsPosition() {
    if (!this.hasSuggestionsListTarget) return
    
    const suggestionsList = this.suggestionsListTarget
    const inputRect = this.inputTarget.getBoundingClientRect()
    const viewportHeight = window.innerHeight
    const suggestionsHeight = 200 // Approximate max height
    
    // Check if suggestions would extend below viewport or overlap important elements
    const spaceBelow = viewportHeight - inputRect.bottom
    const spaceAbove = inputRect.top
    
    if (spaceBelow < suggestionsHeight && spaceAbove > suggestionsHeight) {
      // Show suggestions above input
      suggestionsList.style.bottom = '100%'
      suggestionsList.style.top = 'auto'
      suggestionsList.style.marginTop = '0'
      suggestionsList.style.marginBottom = '0.25rem'
    } else {
      // Show suggestions below input (default)
      suggestionsList.style.top = '100%'
      suggestionsList.style.bottom = 'auto'
      suggestionsList.style.marginTop = '0.25rem'
      suggestionsList.style.marginBottom = '0'
    }
  }

  hideSuggestions() {
    if (this.hasSuggestionsListTarget) {
      this.suggestionsListTarget.classList.add('hidden')
      this.isVisible = false
      this.currentFocus = -1
    }
    
    // Remove the event listener properly
    if (this.boundHandleOutsideClick) {
      document.removeEventListener('click', this.boundHandleOutsideClick, { capture: true })
      this.boundHandleOutsideClick = null
    }
  }

  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
    }
  }

  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('hidden')
    }
  }

  selectSuggestionByClick(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.selectSuggestion(index)
  }

  selectSuggestion(index) {
    const suggestionElements = this.suggestionsListTarget.querySelectorAll('.suggestion-item')
    if (index >= 0 && index < suggestionElements.length) {
      const selectedElement = suggestionElements[index]
      const text = selectedElement.querySelector('.font-medium').textContent
      
      if (this.hasInputTarget) {
        this.inputTarget.value = text
        this.inputTarget.focus()
        
        // Trigger input event for other controllers
        this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }))
      }
    }
    
    this.hideSuggestions()
  }

  navigateDown() {
    const suggestionElements = this.suggestionsListTarget.querySelectorAll('.suggestion-item')
    
    if (this.currentFocus < suggestionElements.length - 1) {
      this.currentFocus++
    } else {
      this.currentFocus = 0
    }
    
    this.updateFocusHighlight(suggestionElements)
  }

  navigateUp() {
    const suggestionElements = this.suggestionsListTarget.querySelectorAll('.suggestion-item')
    
    if (this.currentFocus > 0) {
      this.currentFocus--
    } else {
      this.currentFocus = suggestionElements.length - 1
    }
    
    this.updateFocusHighlight(suggestionElements)
  }

  updateFocusHighlight(suggestionElements) {
    suggestionElements.forEach((element, index) => {
      if (index === this.currentFocus) {
        element.classList.add('bg-blue-100')
        element.classList.remove('hover:bg-blue-50')
      } else {
        element.classList.remove('bg-blue-100')
        element.classList.add('hover:bg-blue-50')
      }
    })
  }

  // Helper methods
  debounce(func, wait) {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(func, wait)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}