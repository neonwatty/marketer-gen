import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "status", "results"]
  static values = {
    language: { type: String, default: "en-US" },
    continuous: { type: Boolean, default: false },
    interimResults: { type: Boolean, default: true },
    maxResults: { type: Number, default: 5 },
    timeout: { type: Number, default: 10000 }
  }

  connect() {
    this.recognition = null
    this.isListening = false
    this.speechSupported = this.checkSpeechSupport()
    
    // Initialize voice search if supported
    if (this.speechSupported) {
      this.initializeVoiceSearch()
    } else {
      this.showUnsupportedState()
    }
    
    // Handle visibility changes
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener('visibilitychange', this.handleVisibilityChange)
  }

  disconnect() {
    if (this.recognition) {
      this.recognition.stop()
    }
    document.removeEventListener('visibilitychange', this.handleVisibilityChange)
  }

  checkSpeechSupport() {
    return 'webkitSpeechRecognition' in window || 'SpeechRecognition' in window
  }

  initializeVoiceSearch() {
    // Initialize speech recognition
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    this.recognition = new SpeechRecognition()
    
    // Configure recognition settings
    this.recognition.continuous = this.continuousValue
    this.recognition.interimResults = this.interimResultsValue
    this.recognition.lang = this.languageValue
    this.recognition.maxAlternatives = this.maxResultsValue
    
    // Set up event handlers
    this.recognition.onstart = this.handleStart.bind(this)
    this.recognition.onresult = this.handleResult.bind(this)
    this.recognition.onerror = this.handleError.bind(this)
    this.recognition.onend = this.handleEnd.bind(this)
    this.recognition.onsoundstart = this.handleSoundStart.bind(this)
    this.recognition.onsoundend = this.handleSoundEnd.bind(this)
    this.recognition.onspeechstart = this.handleSpeechStart.bind(this)
    this.recognition.onspeechend = this.handleSpeechEnd.bind(this)
    
    // Initialize UI
    this.initializeUI()
  }

  initializeUI() {
    // Set up button state
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
      this.buttonTarget.setAttribute('aria-label', 'Start voice search')
      this.updateButtonState()
    }
    
    // Set up status display
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = 'Click microphone to start voice search'
      this.statusTarget.className = 'text-sm text-gray-600'
    }
  }

  showUnsupportedState() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.style.opacity = '0.5'
      this.buttonTarget.setAttribute('aria-label', 'Voice search not supported')
    }
    
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = 'Voice search is not supported in this browser'
      this.statusTarget.className = 'text-sm text-red-600'
    }
  }

  // Action method to toggle voice search
  toggleVoiceSearch() {
    if (!this.speechSupported || !this.recognition) {return}
    
    if (this.isListening) {
      this.stopListening()
    } else {
      this.startListening()
    }
  }

  startListening() {
    if (this.isListening || !this.recognition) {return}
    
    try {
      // Request microphone permission and start recognition
      this.recognition.start()
      
      // Set timeout to stop listening automatically
      this.timeoutId = setTimeout(() => {
        if (this.isListening) {
          this.stopListening()
          this.showStatus('Voice search timed out', 'error')
        }
      }, this.timeoutValue)
      
    } catch (error) {
      console.error('Failed to start voice recognition:', error)
      this.showStatus('Failed to start voice search', 'error')
    }
  }

  stopListening() {
    if (!this.isListening || !this.recognition) {return}
    
    this.recognition.stop()
    
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
      this.timeoutId = null
    }
  }

  handleStart() {
    this.isListening = true
    this.updateButtonState()
    this.showStatus('Listening... Speak now', 'listening')
    
    // Dispatch start event
    this.dispatch('started', {
      detail: { controller: this }
    })
  }

  handleResult(event) {
    let interimTranscript = ''
    let finalTranscript = ''
    
    // Process all results
    for (let i = event.resultIndex; i < event.results.length; i++) {
      const result = event.results[i]
      const transcript = result[0].transcript
      
      if (result.isFinal) {
        finalTranscript = transcript
      } else {
        interimTranscript = transcript
      }
    }
    
    // Update input with results
    if (this.hasInputTarget) {
      if (finalTranscript) {
        this.inputTarget.value = finalTranscript.trim()
        this.showStatus('Voice search completed', 'success')
        
        // Trigger input event for form handling
        this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }))
        
        // Auto-submit if configured
        if (this.inputTarget.form && this.inputTarget.form.dataset.autoSubmit === 'true') {
          this.inputTarget.form.submit()
        }
      } else if (interimTranscript && this.interimResultsValue) {
        // Show interim results in a subtle way
        this.showInterimResults(interimTranscript)
      }
    }
    
    // Dispatch result events
    if (finalTranscript) {
      this.dispatch('result', {
        detail: {
          transcript: finalTranscript,
          confidence: event.results[event.resultIndex][0].confidence,
          controller: this
        }
      })
    }
    
    if (interimTranscript) {
      this.dispatch('interimResult', {
        detail: {
          transcript: interimTranscript,
          controller: this
        }
      })
    }
  }

  handleError(event) {
    console.error('Speech recognition error:', event.error)
    
    let errorMessage = 'Voice search error'
    let shouldRetry = false
    
    switch (event.error) {
      case 'network':
        errorMessage = 'Network error - please check your connection'
        shouldRetry = true
        break
      case 'not-allowed':
        errorMessage = 'Microphone access denied'
        break
      case 'no-speech':
        errorMessage = 'No speech detected - try again'
        shouldRetry = true
        break
      case 'audio-capture':
        errorMessage = 'Microphone not available'
        break
      case 'service-not-allowed':
        errorMessage = 'Voice search service not available'
        break
      default:
        errorMessage = `Voice search error: ${event.error}`
    }
    
    this.showStatus(errorMessage, 'error')
    
    // Dispatch error event
    this.dispatch('error', {
      detail: {
        error: event.error,
        message: errorMessage,
        shouldRetry,
        controller: this
      }
    })
  }

  handleEnd() {
    this.isListening = false
    this.updateButtonState()
    
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
      this.timeoutId = null
    }
    
    // Clear interim results
    this.clearInterimResults()
    
    // Dispatch end event
    this.dispatch('ended', {
      detail: { controller: this }
    })
  }

  handleSoundStart() {
    this.showStatus('Sound detected...', 'listening')
  }

  handleSoundEnd() {
    this.showStatus('Processing...', 'processing')
  }

  handleSpeechStart() {
    this.showStatus('Speech detected - keep talking', 'listening')
  }

  handleSpeechEnd() {
    this.showStatus('Speech ended - processing...', 'processing')
  }

  updateButtonState() {
    if (!this.hasButtonTarget) {return}
    
    const button = this.buttonTarget
    const icon = button.querySelector('svg') || button.querySelector('.voice-icon')
    
    if (this.isListening) {
      button.classList.add('bg-red-500', 'text-white', 'animate-pulse')
      button.classList.remove('bg-gray-100', 'text-gray-600', 'hover:bg-gray-200')
      button.setAttribute('aria-label', 'Stop voice search')
      
      if (icon) {
        icon.innerHTML = `
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 10a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z"></path>
        `
      }
    } else {
      button.classList.remove('bg-red-500', 'text-white', 'animate-pulse')
      button.classList.add('bg-gray-100', 'text-gray-600', 'hover:bg-gray-200')
      button.setAttribute('aria-label', 'Start voice search')
      
      if (icon) {
        icon.innerHTML = `
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
        `
      }
    }
  }

  showStatus(message, type = 'info') {
    if (!this.hasStatusTarget) {return}
    
    this.statusTarget.textContent = message
    
    // Remove existing type classes
    this.statusTarget.classList.remove(
      'text-gray-600', 'text-blue-600', 'text-green-600', 
      'text-red-600', 'text-yellow-600'
    )
    
    // Add appropriate class based on type
    switch (type) {
      case 'success':
        this.statusTarget.classList.add('text-green-600')
        break
      case 'error':
        this.statusTarget.classList.add('text-red-600')
        break
      case 'listening':
        this.statusTarget.classList.add('text-blue-600')
        break
      case 'processing':
        this.statusTarget.classList.add('text-yellow-600')
        break
      default:
        this.statusTarget.classList.add('text-gray-600')
    }
    
    // Auto-clear success/error messages after delay
    if (type === 'success' || type === 'error') {
      setTimeout(() => {
        if (this.hasStatusTarget && !this.isListening) {
          this.statusTarget.textContent = 'Click microphone to start voice search'
          this.statusTarget.className = 'text-sm text-gray-600'
        }
      }, 3000)
    }
  }

  showInterimResults(transcript) {
    if (!this.hasInputTarget) {return}
    
    // Store original value if not already stored
    if (!this.originalValue) {
      this.originalValue = this.inputTarget.value
    }
    
    // Show interim results with different styling
    this.inputTarget.value = transcript
    this.inputTarget.style.fontStyle = 'italic'
    this.inputTarget.style.opacity = '0.7'
  }

  clearInterimResults() {
    if (!this.hasInputTarget) {return}
    
    // Reset styling
    this.inputTarget.style.fontStyle = ''
    this.inputTarget.style.opacity = ''
    
    // Clear stored original value
    this.originalValue = null
  }

  handleVisibilityChange() {
    // Stop listening when tab becomes hidden
    if (document.hidden && this.isListening) {
      this.stopListening()
      this.showStatus('Voice search stopped - tab became inactive', 'info')
    }
  }

  // Public API methods
  isSupported() {
    return this.speechSupported
  }

  isActive() {
    return this.isListening
  }

  // Keyboard shortcut support
  keydown(event) {
    // Support spacebar for push-to-talk style interaction
    if (event.code === 'Space' && event.target === this.buttonTarget) {
      event.preventDefault()
      if (!this.isListening) {
        this.startListening()
      }
    }
  }

  keyup(event) {
    // Stop listening when spacebar is released (push-to-talk)
    if (event.code === 'Space' && event.target === this.buttonTarget && this.isListening) {
      event.preventDefault()
      this.stopListening()
    }
  }

  // Method to set language dynamically
  setLanguage(language) {
    this.languageValue = language
    if (this.recognition) {
      this.recognition.lang = language
    }
  }

  // Method to get available languages (basic list)
  getAvailableLanguages() {
    return [
      { code: 'en-US', name: 'English (US)' },
      { code: 'en-GB', name: 'English (UK)' },
      { code: 'es-ES', name: 'Spanish (Spain)' },
      { code: 'es-MX', name: 'Spanish (Mexico)' },
      { code: 'fr-FR', name: 'French (France)' },
      { code: 'de-DE', name: 'German (Germany)' },
      { code: 'it-IT', name: 'Italian (Italy)' },
      { code: 'pt-BR', name: 'Portuguese (Brazil)' },
      { code: 'ja-JP', name: 'Japanese (Japan)' },
      { code: 'ko-KR', name: 'Korean (South Korea)' },
      { code: 'zh-CN', name: 'Chinese (Simplified)' },
      { code: 'zh-TW', name: 'Chinese (Traditional)' }
    ]
  }
}