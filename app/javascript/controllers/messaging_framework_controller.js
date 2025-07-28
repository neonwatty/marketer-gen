import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["content"]
  
  connect() {
    this.brandId = document.querySelector('[data-brand-id]').value
    this.frameworkId = document.querySelector('[data-framework-id]').value
    this.frameworkData = {}
    this.unsavedChanges = false
    
    this.initializeSortable()
    this.bindInputListeners()
    this.bindToneControls()
  }

  initializeSortable() {
    // Initialize sortable for key messages
    document.querySelectorAll('.sortable-messages').forEach(container => {
      new Sortable(container, {
        animation: 150,
        ghostClass: 'opacity-50',
        handle: '.cursor-move',
        onEnd: (evt) => {
          const category = container.dataset.category
          this.reorderKeyMessages(category, evt)
        }
      })
    })

    // Initialize sortable for value propositions
    document.querySelectorAll('.sortable-value-props').forEach(container => {
      new Sortable(container, {
        animation: 150,
        ghostClass: 'opacity-50',
        handle: '.cursor-move',
        onEnd: (evt) => {
          const type = container.dataset.type
          this.reorderValuePropositions(type, evt)
        }
      })
    })
  }

  bindInputListeners() {
    // Listen to all text inputs and textareas
    this.element.querySelectorAll('input[data-field], textarea[data-field]').forEach(input => {
      input.addEventListener('input', () => {
        this.unsavedChanges = true
        this.updateFrameworkData(input.dataset.field, input.value)
      })
    })
  }

  bindToneControls() {
    // Radio buttons for formality
    this.element.querySelectorAll('input[data-tone-attribute][type="radio"]').forEach(input => {
      input.addEventListener('change', () => {
        if (input.checked) {
          this.updateToneAttribute(input.dataset.toneAttribute, input.value)
        }
      })
    })

    // Checkboxes for voice characteristics
    this.element.querySelectorAll('input[data-tone-attribute][type="checkbox"]').forEach(input => {
      input.addEventListener('change', () => {
        this.updateToneAttribute(input.dataset.toneAttribute, input.checked)
      })
    })

    // Range slider for energy level
    const energySlider = this.element.querySelector('input[data-tone-attribute="energy_level"]')
    if (energySlider) {
      energySlider.addEventListener('input', (e) => {
        const display = this.element.querySelector('[data-energy-level-display]')
        if (display) display.textContent = e.target.value
        this.updateToneAttribute('energy_level', parseInt(e.target.value))
      })
    }
  }

  // Tab switching
  switchTab(event) {
    const tab = event.currentTarget.dataset.tab
    
    // Update tab buttons
    this.element.querySelectorAll('.tab-button').forEach(btn => {
      btn.classList.remove('active', 'border-indigo-500', 'text-indigo-600')
      btn.classList.add('border-transparent', 'text-gray-500')
    })
    
    event.currentTarget.classList.remove('border-transparent', 'text-gray-500')
    event.currentTarget.classList.add('active', 'border-indigo-500', 'text-indigo-600')
    
    // Update tab content
    this.element.querySelectorAll('.tab-pane').forEach(pane => {
      pane.classList.add('hidden')
    })
    
    const targetPane = this.element.querySelector(`[data-tab-content="${tab}"]`)
    if (targetPane) {
      targetPane.classList.remove('hidden')
    }
  }

  // Key Messages Management
  async addKeyMessageCategory(event) {
    const categoryName = prompt('Enter category name:')
    if (!categoryName) return

    const container = this.element.querySelector('[data-key-messages-container]')
    const categoryHtml = this.createKeyMessageCategoryHtml(categoryName, [])
    container.insertAdjacentHTML('beforeend', categoryHtml)
    
    // Re-initialize sortable for new category
    const newContainer = container.querySelector(`[data-category="${categoryName}"] .sortable-messages`)
    if (newContainer) {
      new Sortable(newContainer, {
        animation: 150,
        ghostClass: 'opacity-50',
        handle: '.cursor-move',
        onEnd: (evt) => {
          this.reorderKeyMessages(categoryName, evt)
        }
      })
    }
    
    this.unsavedChanges = true
  }

  createKeyMessageCategoryHtml(category, messages = []) {
    const messagesHtml = messages.map((message, index) => `
      <div class="message-item bg-gray-50 rounded-lg p-4 flex items-start space-x-3 cursor-move group" data-index="${index}">
        <svg class="h-5 w-5 text-gray-400 mt-0.5 opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
        </svg>
        <div class="flex-1">
          <p class="text-gray-800">${this.escapeHtml(message)}</p>
        </div>
        <button data-action="click->messaging-framework#removeKeyMessage"
                data-category="${category}"
                data-index="${index}"
                class="text-gray-400 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-all">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
          </svg>
        </button>
      </div>
    `).join('')

    return `
      <div class="key-message-category" data-category="${category}">
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-sm font-semibold text-gray-700 uppercase tracking-wider">${this.escapeHtml(category)}</h4>
          <button data-action="click->messaging-framework#removeKeyMessageCategory"
                  data-category="${category}"
                  class="text-gray-400 hover:text-red-600 transition-colors">
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        
        <div class="sortable-messages space-y-2" data-category="${category}">
          ${messagesHtml}
        </div>
        
        <div class="mt-3">
          <div class="flex space-x-2">
            <input type="text" 
                   data-new-message-input="${category}"
                   class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                   placeholder="Add a new message...">
            <button data-action="click->messaging-framework#addKeyMessage"
                    data-category="${category}"
                    class="px-3 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 transition-colors">
              Add
            </button>
          </div>
        </div>
      </div>
    `
  }

  async removeKeyMessageCategory(event) {
    const category = event.currentTarget.dataset.category
    if (!confirm(`Remove category "${category}" and all its messages?`)) return

    const categoryElement = this.element.querySelector(`.key-message-category[data-category="${category}"]`)
    if (categoryElement) {
      categoryElement.remove()
    }

    this.unsavedChanges = true
  }

  async addKeyMessage(event) {
    const category = event.currentTarget.dataset.category
    const input = this.element.querySelector(`[data-new-message-input="${category}"]`)
    const message = input.value.trim()
    
    if (!message) return

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/add_key_message`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ category, message })
      })

      const data = await response.json()
      
      if (data.success) {
        const container = this.element.querySelector(`.sortable-messages[data-category="${category}"]`)
        const index = container.children.length
        const messageHtml = `
          <div class="message-item bg-gray-50 rounded-lg p-4 flex items-start space-x-3 cursor-move group" data-index="${index}">
            <svg class="h-5 w-5 text-gray-400 mt-0.5 opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
            <div class="flex-1">
              <p class="text-gray-800">${this.escapeHtml(message)}</p>
            </div>
            <button data-action="click->messaging-framework#removeKeyMessage"
                    data-category="${category}"
                    data-index="${index}"
                    class="text-gray-400 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-all">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        `
        container.insertAdjacentHTML('beforeend', messageHtml)
        input.value = ''
        this.updateStatistics()
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to add message')
    }
  }

  async removeKeyMessage(event) {
    const category = event.currentTarget.dataset.category
    const index = event.currentTarget.dataset.index
    
    if (!confirm('Remove this message?')) return

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/remove_key_message`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ category, index })
      })

      const data = await response.json()
      
      if (data.success) {
        event.currentTarget.closest('.message-item').remove()
        this.updateStatistics()
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to remove message')
    }
  }

  async reorderKeyMessages(category, evt) {
    const container = evt.target
    const orderedIds = Array.from(container.children).map(child => child.dataset.index)
    
    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/reorder_key_messages`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ category, ordered_ids: orderedIds })
      })

      const data = await response.json()
      
      if (!data.success) {
        this.showError(data.errors.join(', '))
        // Revert the order
        evt.item.parentNode.insertBefore(evt.item, evt.item.parentNode.children[evt.oldIndex])
      }
    } catch (error) {
      this.showError('Failed to reorder messages')
    }
  }

  // Value Propositions Management
  async addValueProposition(event) {
    const type = event.currentTarget.dataset.type
    const input = this.element.querySelector(`[data-new-value-prop-input="${type}"]`)
    const proposition = input.value.trim()
    
    if (!proposition) return

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/add_value_proposition`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ proposition_type: type, proposition })
      })

      const data = await response.json()
      
      if (data.success) {
        const container = this.element.querySelector(`.sortable-value-props[data-type="${type}"]`)
        const index = container.children.length
        const bgClass = type === 'primary' ? 'bg-indigo-50 border border-indigo-200' : 'bg-gray-50'
        const iconClass = type === 'primary' ? 'text-indigo-400' : 'text-gray-400'
        
        const propHtml = `
          <div class="value-prop-item ${bgClass} rounded-lg p-4 flex items-start space-x-3 cursor-move group" data-index="${index}">
            <svg class="h-5 w-5 ${iconClass} mt-0.5 opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
            <div class="flex-1">
              <p class="text-gray-800">${this.escapeHtml(proposition)}</p>
            </div>
            <button data-action="click->messaging-framework#removeValueProposition"
                    data-type="${type}"
                    data-index="${index}"
                    class="${iconClass} hover:text-red-600 opacity-0 group-hover:opacity-100 transition-all">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        `
        container.insertAdjacentHTML('beforeend', propHtml)
        input.value = ''
        this.updateStatistics()
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to add value proposition')
    }
  }

  async removeValueProposition(event) {
    const type = event.currentTarget.dataset.type
    const index = event.currentTarget.dataset.index
    
    if (!confirm('Remove this value proposition?')) return

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/remove_value_proposition`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ proposition_type: type, index })
      })

      const data = await response.json()
      
      if (data.success) {
        event.currentTarget.closest('.value-prop-item').remove()
        this.updateStatistics()
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to remove value proposition')
    }
  }

  async reorderValuePropositions(type, evt) {
    const container = evt.target
    const orderedIds = Array.from(container.children).map(child => child.dataset.index)
    
    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/reorder_value_propositions`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ proposition_type: type, ordered_ids: orderedIds })
      })

      const data = await response.json()
      
      if (!data.success) {
        this.showError(data.errors.join(', '))
        // Revert the order
        evt.item.parentNode.insertBefore(evt.item, evt.item.parentNode.children[evt.oldIndex])
      }
    } catch (error) {
      this.showError('Failed to reorder value propositions')
    }
  }

  // Terminology Management
  async addTerminology(event) {
    const term = prompt('Enter the term:')
    if (!term) return
    
    const definition = prompt('Enter the definition:')
    if (!definition) return

    const container = this.element.querySelector('[data-terminology-container]')
    const termHtml = `
      <div class="terminology-item bg-gray-50 rounded-lg p-4 group relative">
        <button data-action="click->messaging-framework#removeTerminology"
                data-term="${this.escapeHtml(term)}"
                class="absolute top-2 right-2 text-gray-400 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-all">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
        
        <h5 class="font-semibold text-gray-900 mb-2">${this.escapeHtml(term)}</h5>
        <p class="text-sm text-gray-600">${this.escapeHtml(definition)}</p>
      </div>
    `
    
    // Remove empty state if it exists
    const emptyState = container.parentElement.querySelector('.text-center.py-12')
    if (emptyState) emptyState.remove()
    
    container.insertAdjacentHTML('beforeend', termHtml)
    this.unsavedChanges = true
  }

  async removeTerminology(event) {
    const term = event.currentTarget.dataset.term
    
    if (!confirm(`Remove term "${term}"?`)) return

    event.currentTarget.closest('.terminology-item').remove()
    this.unsavedChanges = true
  }

  // Approved Phrases Management
  async addApprovedPhrases(event) {
    const input = this.element.querySelector('[data-approved-phrases-input]')
    const phrases = input.value.split(',').map(p => p.trim()).filter(p => p)
    
    if (phrases.length === 0) return

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/update_approved_phrases`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ 
          approved_phrases: [...this.getCurrentApprovedPhrases(), ...phrases]
        })
      })

      const data = await response.json()
      
      if (data.success) {
        const container = this.element.querySelector('[data-approved-phrases-container]')
        
        // Remove empty state if it exists
        const emptyState = container.parentElement.querySelector('.text-center.py-12')
        if (emptyState) emptyState.remove()
        
        phrases.forEach(phrase => {
          const phraseHtml = `
            <span class="inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium bg-green-100 text-green-800 group">
              ${this.escapeHtml(phrase)}
              <button data-action="click->messaging-framework#removeApprovedPhrase"
                      data-phrase="${this.escapeHtml(phrase)}"
                      class="ml-2 text-green-600 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-all">
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </span>
          `
          container.insertAdjacentHTML('beforeend', phraseHtml)
        })
        
        input.value = ''
        this.updateStatistics()
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to add approved phrases')
    }
  }

  async removeApprovedPhrase(event) {
    const phrase = event.currentTarget.dataset.phrase
    
    if (!confirm(`Remove phrase "${phrase}"?`)) return

    const currentPhrases = this.getCurrentApprovedPhrases()
    const updatedPhrases = currentPhrases.filter(p => p !== phrase)

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/update_approved_phrases`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ approved_phrases: updatedPhrases })
      })

      const data = await response.json()
      
      if (data.success) {
        event.currentTarget.closest('span').remove()
        this.updateStatistics()
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to remove approved phrase')
    }
  }

  async searchApprovedPhrases(event) {
    const query = event.target.value
    
    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/search_approved_phrases?query=${encodeURIComponent(query)}`)
      const data = await response.json()
      
      // Update the display to show only matching phrases
      const container = this.element.querySelector('[data-approved-phrases-container]')
      const allPhrases = container.querySelectorAll('span')
      
      allPhrases.forEach(span => {
        const phraseText = span.textContent.trim()
        if (data.phrases.some(p => p === phraseText)) {
          span.style.display = 'inline-flex'
        } else {
          span.style.display = 'none'
        }
      })
    } catch (error) {
      console.error('Failed to search phrases:', error)
    }
  }

  getCurrentApprovedPhrases() {
    const phrases = []
    this.element.querySelectorAll('[data-approved-phrases-container] span').forEach(span => {
      const text = span.textContent.trim()
      if (text) phrases.push(text)
    })
    return phrases
  }

  // Banned Words Management
  async addBannedWords(event) {
    const input = this.element.querySelector('[data-banned-words-input]')
    const words = input.value.split(',').map(w => w.trim().toLowerCase()).filter(w => w)
    
    if (words.length === 0) return

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/update_banned_words`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ 
          banned_words: [...this.getCurrentBannedWords(), ...words]
        })
      })

      const data = await response.json()
      
      if (data.success) {
        const container = this.element.querySelector('[data-banned-words-container]')
        
        // Remove empty state if it exists
        const emptyState = container.parentElement.querySelector('.text-center.py-8')
        if (emptyState) emptyState.remove()
        
        words.forEach(word => {
          const wordHtml = `
            <span class="inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium bg-red-100 text-red-800 group">
              ${this.escapeHtml(word)}
              <button data-action="click->messaging-framework#removeBannedWord"
                      data-word="${this.escapeHtml(word)}"
                      class="ml-2 text-red-600 hover:text-red-800 opacity-0 group-hover:opacity-100 transition-all">
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </span>
          `
          container.insertAdjacentHTML('beforeend', wordHtml)
        })
        
        input.value = ''
        this.updateStatistics()
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to add banned words')
    }
  }

  async removeBannedWord(event) {
    const word = event.currentTarget.dataset.word
    
    if (!confirm(`Remove banned word "${word}"?`)) return

    const currentWords = this.getCurrentBannedWords()
    const updatedWords = currentWords.filter(w => w !== word)

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/update_banned_words`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ banned_words: updatedWords })
      })

      const data = await response.json()
      
      if (data.success) {
        event.currentTarget.closest('span').remove()
        this.updateStatistics()
        
        // Update the count display
        const countDisplay = this.element.querySelector('[data-banned-words-count]')
        if (countDisplay) {
          countDisplay.textContent = updatedWords.length
        }
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to remove banned word')
    }
  }

  getCurrentBannedWords() {
    const words = []
    this.element.querySelectorAll('[data-banned-words-container] span').forEach(span => {
      const text = span.textContent.trim()
      if (text) words.push(text)
    })
    return words
  }

  // Tone Attributes Management
  async updateToneAttribute(attribute, value) {
    this.frameworkData.tone_attributes = this.frameworkData.tone_attributes || {}
    this.frameworkData.tone_attributes[attribute] = value
    this.unsavedChanges = true
  }

  // Content Validation
  async validateContent(event) {
    const textarea = this.element.querySelector('[data-compliance-test-input]')
    const content = textarea.value.trim()
    
    if (!content) return

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/validate_content`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ content })
      })

      const data = await response.json()
      this.displayValidationResults(data)
    } catch (error) {
      this.showError('Failed to validate content')
    }
  }

  displayValidationResults(results) {
    const container = this.element.querySelector('[data-validation-results]')
    let html = ''

    // Banned words check
    if (results.contains_banned) {
      html += `
        <div class="bg-red-50 border border-red-200 rounded-lg p-4">
          <div class="flex items-start">
            <svg class="h-5 w-5 text-red-400 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <div class="ml-3">
              <h4 class="text-sm font-medium text-red-800">Banned Words Found</h4>
              <div class="mt-2 flex flex-wrap gap-2">
                ${results.banned_words.map(word => `
                  <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800">
                    ${this.escapeHtml(word)}
                  </span>
                `).join('')}
              </div>
            </div>
          </div>
        </div>
      `
    } else {
      html += `
        <div class="bg-green-50 border border-green-200 rounded-lg p-4">
          <div class="flex items-start">
            <svg class="h-5 w-5 text-green-400 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <div class="ml-3">
              <h4 class="text-sm font-medium text-green-800">No Banned Words</h4>
              <p class="text-sm text-green-700 mt-1">Content is free from banned words.</p>
            </div>
          </div>
        </div>
      `
    }

    // Approved phrases check
    if (results.approved_phrases_used.length > 0) {
      html += `
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mt-4">
          <div class="flex items-start">
            <svg class="h-5 w-5 text-blue-400 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <div class="ml-3">
              <h4 class="text-sm font-medium text-blue-800">Approved Phrases Used</h4>
              <div class="mt-2 flex flex-wrap gap-2">
                ${results.approved_phrases_used.map(phrase => `
                  <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800">
                    ${this.escapeHtml(phrase)}
                  </span>
                `).join('')}
              </div>
            </div>
          </div>
        </div>
      `
    }

    // Tone match
    html += `
      <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 mt-4">
        <div class="flex items-start">
          <svg class="h-5 w-5 text-gray-400 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
          </svg>
          <div class="ml-3">
            <h4 class="text-sm font-medium text-gray-800">Tone Analysis</h4>
            <p class="text-sm text-gray-700 mt-1">
              Formality: <span class="font-medium">${results.tone_match.formality}</span>
            </p>
          </div>
        </div>
      </div>
    `

    container.innerHTML = html
  }

  // AI Suggestions
  async getAISuggestions(event) {
    const contentType = event.currentTarget.dataset.contentType
    let currentContent = ''

    if (contentType === 'tagline') {
      currentContent = this.element.querySelector('[data-field="tagline"]').value
    } else if (contentType === 'value_propositions') {
      // Gather current value propositions
      currentContent = JSON.stringify(this.gatherValuePropositions())
    } else if (contentType === 'key_messages') {
      // Gather current key messages
      currentContent = JSON.stringify(this.gatherKeyMessages())
    }

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/ai_suggestions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ content_type: contentType, current_content: currentContent })
      })

      const data = await response.json()
      this.displayAISuggestions(data.suggestions)
    } catch (error) {
      this.showError('Failed to get AI suggestions')
    }
  }

  displayAISuggestions(suggestions) {
    const modal = this.element.querySelector('[data-ai-suggestions-modal]')
    const content = modal.querySelector('[data-suggestions-content]')
    
    content.innerHTML = suggestions.map((suggestion, index) => `
      <div class="bg-gray-50 rounded-lg p-4">
        <div class="flex items-start">
          <span class="flex-shrink-0 inline-flex items-center justify-center h-8 w-8 rounded-full bg-indigo-100 text-indigo-600 text-sm font-medium">
            ${index + 1}
          </span>
          <p class="ml-3 text-sm text-gray-700">${this.escapeHtml(suggestion)}</p>
        </div>
      </div>
    `).join('')
    
    modal.classList.remove('hidden')
  }

  closeSuggestionsModal(event) {
    const modal = this.element.querySelector('[data-ai-suggestions-modal]')
    modal.classList.add('hidden')
  }

  // Import/Export
  async exportFramework(event) {
    try {
      window.location.href = `/brands/${this.brandId}/messaging_framework/export.json`
    } catch (error) {
      this.showError('Failed to export framework')
    }
  }

  async importFramework(event) {
    const file = event.target.files[0]
    if (!file) return

    const formData = new FormData()
    formData.append('file', file)

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework/import`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: formData
      })

      const data = await response.json()
      
      if (data.success) {
        this.showSuccess('Framework imported successfully')
        setTimeout(() => window.location.reload(), 1500)
      } else {
        this.showError(data.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to import framework')
    }
  }

  // Save All Changes
  async saveAll(event) {
    if (!this.unsavedChanges && Object.keys(this.frameworkData).length === 0) {
      this.showInfo('No changes to save')
      return
    }

    // Gather all current data
    const data = {
      tagline: this.element.querySelector('[data-field="tagline"]').value,
      mission_statement: this.element.querySelector('[data-field="mission_statement"]').value,
      vision_statement: this.element.querySelector('[data-field="vision_statement"]').value,
      key_messages: this.gatherKeyMessages(),
      value_propositions: this.gatherValuePropositions(),
      terminology: this.gatherTerminology(),
      approved_phrases: this.getCurrentApprovedPhrases(),
      banned_words: this.getCurrentBannedWords(),
      tone_attributes: this.gatherToneAttributes()
    }

    try {
      const response = await fetch(`/brands/${this.brandId}/messaging_framework`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ messaging_framework: data })
      })

      const result = await response.json()
      
      if (result.success) {
        this.showSuccess('Framework saved successfully')
        this.unsavedChanges = false
        this.frameworkData = {}
      } else {
        this.showError(result.errors.join(', '))
      }
    } catch (error) {
      this.showError('Failed to save framework')
    }
  }

  // Helper methods
  gatherKeyMessages() {
    const messages = {}
    this.element.querySelectorAll('.key-message-category').forEach(category => {
      const categoryName = category.dataset.category
      messages[categoryName] = []
      
      category.querySelectorAll('.message-item p').forEach(p => {
        messages[categoryName].push(p.textContent.trim())
      })
    })
    return messages
  }

  gatherValuePropositions() {
    const propositions = {}
    this.element.querySelectorAll('.sortable-value-props').forEach(container => {
      const type = container.dataset.type
      propositions[type] = []
      
      container.querySelectorAll('.value-prop-item p').forEach(p => {
        propositions[type].push(p.textContent.trim())
      })
    })
    return propositions
  }

  gatherTerminology() {
    const terminology = {}
    this.element.querySelectorAll('.terminology-item').forEach(item => {
      const term = item.querySelector('h5').textContent.trim()
      const definition = item.querySelector('p').textContent.trim()
      terminology[term] = definition
    })
    return terminology
  }

  gatherToneAttributes() {
    const attributes = {}
    
    // Get formality
    const formalityInput = this.element.querySelector('input[name="formality"]:checked')
    if (formalityInput) {
      attributes.formality = formalityInput.value
    }
    
    // Get voice characteristics
    this.element.querySelectorAll('input[data-tone-attribute][type="checkbox"]').forEach(input => {
      attributes[input.dataset.toneAttribute] = input.checked
    })
    
    // Get energy level
    const energySlider = this.element.querySelector('input[data-tone-attribute="energy_level"]')
    if (energySlider) {
      attributes.energy_level = parseInt(energySlider.value)
    }
    
    return attributes
  }

  updateFrameworkData(field, value) {
    this.frameworkData[field] = value
  }

  updateStatistics() {
    // Update key messages count
    const keyMessagesCount = this.element.querySelectorAll('.message-item').length
    const keyMessagesDisplay = this.element.querySelector('[data-stat="key-messages-count"]')
    if (keyMessagesDisplay) keyMessagesDisplay.textContent = keyMessagesCount

    // Update value propositions count
    const valuePropsCount = this.element.querySelectorAll('.value-prop-item').length
    const valuePropsDisplay = this.element.querySelector('[data-stat="value-props-count"]')
    if (valuePropsDisplay) valuePropsDisplay.textContent = valuePropsCount

    // Update approved phrases count
    const approvedPhrasesCount = this.element.querySelectorAll('[data-approved-phrases-container] span').length
    const approvedPhrasesDisplay = this.element.querySelector('[data-stat="approved-phrases-count"]')
    if (approvedPhrasesDisplay) approvedPhrasesDisplay.textContent = approvedPhrasesCount

    // Update banned words count
    const bannedWordsCount = this.element.querySelectorAll('[data-banned-words-container] span').length
    const bannedWordsDisplay = this.element.querySelector('[data-stat="banned-words-count"]')
    if (bannedWordsDisplay) bannedWordsDisplay.textContent = bannedWordsCount
    
    const bannedWordsCountBadge = this.element.querySelector('[data-banned-words-count]')
    if (bannedWordsCountBadge) bannedWordsCountBadge.textContent = bannedWordsCount
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  showSuccess(message) {
    this.showNotification(message, 'success')
  }

  showError(message) {
    this.showNotification(message, 'error')
  }

  showInfo(message) {
    this.showNotification(message, 'info')
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 px-6 py-3 rounded-lg shadow-lg text-white z-50 ${
      type === 'success' ? 'bg-green-600' : 
      type === 'error' ? 'bg-red-600' : 
      'bg-blue-600'
    }`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
}