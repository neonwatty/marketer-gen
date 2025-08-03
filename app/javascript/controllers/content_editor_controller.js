import { Controller } from "@hotwired/stimulus"
import React from "react"
import { createRoot } from "react-dom/client"
import ContentEditorInterface from "../components/ContentEditorInterface"

// Connects to data-controller="content-editor"
export default class extends Controller {
  static targets = [
    "form", "titleField", "contentTypeField", "formatField", "contentField",
    "editorView", "previewView", "previewContent", "previewToggle",
    "autoSaveStatus", "wordCount", "saveButton", "loadingOverlay", "loadingMessage",
    "reactMount"
  ]
  
  static values = {
    autoSaveUrl: String,
    contentType: { type: String, default: "rich" },
    collaborative: { type: Boolean, default: false },
    showTemplates: { type: Boolean, default: true },
    showMediaManager: { type: Boolean, default: true },
    showLivePreview: { type: Boolean, default: true },
    maxLength: Number,
    brandColors: Array,
    collaborators: Array
  }

  connect() {
    console.log("Content editor controller connected")
    this.autoSaveTimeout = null
    this.isPreviewMode = false
    this.lastSavedContent = ''
    
    // Initialize React component if mount target exists
    if (this.hasReactMountTarget) {
      this.initializeReactEditor()
    } else {
      // Fallback to legacy editor
      this.initializeLegacyEditor()
    }
  }

  disconnect() {
    if (this.reactRoot) {
      this.reactRoot.unmount()
    }
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout)
    }
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
  }

  initializeReactEditor() {
    const initialContent = this.hasContentFieldTarget ? this.contentFieldTarget.value : ''
    
    const props = {
      initialContent,
      contentType: this.contentTypeValue,
      onSave: this.handleReactSave.bind(this),
      onAutoSave: this.handleReactAutoSave.bind(this),
      autoSaveEnabled: Boolean(this.autoSaveUrlValue),
      autoSaveDelay: 2000,
      showTemplates: this.showTemplatesValue,
      showMediaManager: this.showMediaManagerValue,
      showLivePreview: this.showLivePreviewValue,
      collaborative: this.collaborativeValue,
      collaborators: this.collaboratorsValue || [],
      brand: {
        colors: this.brandColorsValue || []
      },
      onContentChange: this.handleContentChange.bind(this),
      maxLength: this.maxLengthValue,
      showCharacterCount: Boolean(this.maxLengthValue),
      showWordCount: true,
      editorHeight: '400px',
      enableAccessibility: true
    }

    this.reactRoot = createRoot(this.reactMountTarget)
    this.reactRoot.render(React.createElement(ContentEditorInterface, props))
  }

  initializeLegacyEditor() {
    // Initialize auto-save
    this.setupAutoSave()
    
    // Initialize word count
    this.updateWordCount()
    
    // Initialize preview content
    this.updatePreview()
  }

  async handleReactSave(content, metadata) {
    if (this.hasContentFieldTarget) {
      this.contentFieldTarget.value = content
    }
    
    if (this.hasFormTarget) {
      // Submit the form
      this.formTarget.submit()
    }
  }

  async handleReactAutoSave(content) {
    if (!this.autoSaveUrlValue) {return}

    try {
      const formData = new FormData()
      formData.append('content', content)
      
      if (this.hasTitleFieldTarget) {
        formData.append('title', this.titleFieldTarget.value)
      }
      
      const response = await fetch(this.autoSaveUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })

      if (!response.ok) {
        throw new Error('Auto-save failed')
      }

      this.lastSavedContent = content
    } catch (error) {
      console.error('Auto-save error:', error)
      throw error
    }
  }

  handleContentChange(content) {
    if (this.hasContentFieldTarget) {
      this.contentFieldTarget.value = content
    }
  }

  // Content change handlers
  titleChanged() {
    this.triggerAutoSave()
  }

  contentTypeChanged() {
    this.triggerAutoSave()
    this.updateEditorMode()
  }

  formatChanged() {
    this.triggerAutoSave()
    this.updateEditorMode()
  }

  contentChanged() {
    this.updateWordCount()
    this.updatePreview()
    this.triggerAutoSave()
  }

  // Auto-save functionality
  setupAutoSave() {
    // Set up periodic auto-save every 30 seconds
    this.autoSaveInterval = setInterval(() => {
      if (this.hasUnsavedChanges()) {
        this.performAutoSave()
      }
    }, 30000)
  }

  triggerAutoSave() {
    // Debounced auto-save triggered by user input
    clearTimeout(this.autoSaveTimeout)
    this.autoSaveTimeout = setTimeout(() => {
      this.performAutoSave()
    }, 2000)
  }

  async performAutoSave() {
    if (!this.hasUnsavedChanges()) {return}

    this.updateAutoSaveStatus('Saving...', 'text-yellow-600')
    
    try {
      const formData = new FormData(this.formTarget)
      
      const response = await fetch(this.autoSaveUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })

      if (response.ok) {
        this.lastSavedContent = this.getCurrentContent()
        this.updateAutoSaveStatus('Saved', 'text-green-600')
        
        // Clear the status after 3 seconds
        setTimeout(() => {
          this.updateAutoSaveStatus('', '')
        }, 3000)
      } else {
        throw new Error('Auto-save failed')
      }
    } catch (error) {
      console.error('Auto-save error:', error)
      this.updateAutoSaveStatus('Save failed', 'text-red-600')
    }
  }

  hasUnsavedChanges() {
    return this.getCurrentContent() !== this.lastSavedContent
  }

  getCurrentContent() {
    const formData = new FormData(this.formTarget)
    return JSON.stringify(Object.fromEntries(formData))
  }

  updateAutoSaveStatus(message, className) {
    if (this.hasAutoSaveStatusTarget) {
      this.autoSaveStatusTarget.textContent = message
      
      // Remove all color classes and add the new one
      this.autoSaveStatusTarget.className = this.autoSaveStatusTarget.className
        .replace(/text-(green|yellow|red)-600/g, '')
      
      if (className) {
        this.autoSaveStatusTarget.classList.add(className)
      }
    }
  }

  // Preview functionality
  togglePreview() {
    this.isPreviewMode = !this.isPreviewMode
    this.updatePreviewDisplay()
  }

  updatePreviewDisplay() {
    if (this.hasEditorViewTarget && this.hasPreviewViewTarget && this.hasPreviewToggleTarget) {
      if (this.isPreviewMode) {
        this.editorViewTarget.classList.add('hidden')
        this.previewViewTarget.classList.remove('hidden')
        this.previewToggleTarget.textContent = 'Edit'
        this.updatePreview()
      } else {
        this.editorViewTarget.classList.remove('hidden')
        this.previewViewTarget.classList.add('hidden')
        this.previewToggleTarget.textContent = 'Preview'
      }
    }
  }

  updatePreview() {
    if (this.hasPreviewContentTarget && this.hasContentFieldTarget) {
      const content = this.contentFieldTarget.value
      
      if (content.trim()) {
        // Simple markdown-like formatting
        const formattedContent = content
          .replace(/\n\n/g, '</p><p>')
          .replace(/\n/g, '<br>')
          .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
          .replace(/\*(.*?)\*/g, '<em>$1</em>')
        
        this.previewContentTarget.innerHTML = `<p>${formattedContent}</p>`
      } else {
        this.previewContentTarget.innerHTML = '<p class="text-gray-500 italic">Start typing to see preview...</p>'
      }
    }
  }

  // Word count
  updateWordCount() {
    if (this.hasWordCountTarget && this.hasContentFieldTarget) {
      const content = this.contentFieldTarget.value
      const wordCount = content.trim().split(/\s+/).filter(word => word.length > 0).length
      this.wordCountTarget.textContent = wordCount
    }
  }

  // Editor mode updates based on content type and format
  updateEditorMode() {
    const contentType = this.hasContentTypeFieldTarget ? this.contentTypeFieldTarget.value : ''
    const format = this.hasFormatFieldTarget ? this.formatFieldTarget.value : ''
    
    // Update editor behavior based on content type and format
    if (this.hasContentFieldTarget) {
      if (format === 'html') {
        this.contentFieldTarget.placeholder = 'Enter HTML content...'
      } else if (format === 'markdown') {
        this.contentFieldTarget.placeholder = 'Enter Markdown content...'
      } else {
        this.contentFieldTarget.placeholder = 'Enter your content...'
      }
    }
  }

  // AI-powered features
  async generateWithAI() {
    this.showLoading('Generating content with AI...')
    
    try {
      const contentType = this.hasContentTypeFieldTarget ? this.contentTypeFieldTarget.value : ''
      const title = this.hasTitleFieldTarget ? this.titleFieldTarget.value : ''
      
      // This would integrate with an AI service
      const response = await fetch('/api/v1/content/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          content_type: contentType,
          title,
          prompt: 'Generate engaging content'
        })
      })

      if (response.ok) {
        const data = await response.json()
        if (this.hasContentFieldTarget) {
          this.contentFieldTarget.value = data.content
          this.contentChanged()
        }
      } else {
        throw new Error('AI generation failed')
      }
    } catch (error) {
      console.error('AI generation error:', error)
      alert('Failed to generate content. Please try again.')
    } finally {
      this.hideLoading()
    }
  }

  async improveContent() {
    if (!this.hasContentFieldTarget || !this.contentFieldTarget.value.trim()) {
      alert('Please enter some content first.')
      return
    }

    this.showLoading('Improving content with AI...')
    
    try {
      const response = await fetch('/api/v1/content/improve', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          content: this.contentFieldTarget.value
        })
      })

      if (response.ok) {
        const data = await response.json()
        this.contentFieldTarget.value = data.improved_content
        this.contentChanged()
      } else {
        throw new Error('Content improvement failed')
      }
    } catch (error) {
      console.error('Content improvement error:', error)
      alert('Failed to improve content. Please try again.')
    } finally {
      this.hideLoading()
    }
  }

  async generateVariations() {
    if (!this.hasContentFieldTarget || !this.contentFieldTarget.value.trim()) {
      alert('Please enter some content first.')
      return
    }

    this.showLoading('Generating variations...')
    
    try {
      const response = await fetch('/api/v1/content/variations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          content: this.contentFieldTarget.value,
          count: 3
        })
      })

      if (response.ok) {
        const data = await response.json()
        // Show variations in a modal or sidebar
        this.showVariationsModal(data.variations)
      } else {
        throw new Error('Variation generation failed')
      }
    } catch (error) {
      console.error('Variation generation error:', error)
      alert('Failed to generate variations. Please try again.')
    } finally {
      this.hideLoading()
    }
  }

  showVariationsModal(variations) {
    // This would show a modal with the generated variations
    console.log('Generated variations:', variations)
    
    // For demonstration, just show an alert
    const variationText = variations.map((v, i) => `${i + 1}. ${v}`).join('\n\n')
    alert(`Generated Variations:\n\n${variationText}`)
  }

  // Form submission handlers
  handleSubmit(event) {
    // Perform final auto-save before submission
    this.performAutoSave()
  }

  saveDraft() {
    this.showLoading('Saving draft...')
    // Form will submit normally with status as draft
  }

  saveForReview() {
    this.showLoading('Submitting for review...')
    
    // Add a hidden field to indicate review submission
    const reviewInput = document.createElement('input')
    reviewInput.type = 'hidden'
    reviewInput.name = 'submit_for_review'
    reviewInput.value = 'true'
    this.formTarget.appendChild(reviewInput)
    
    // Submit the form
    this.formTarget.submit()
  }

  // Loading states
  showLoading(message = 'Processing...') {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.remove('hidden')
    }
    
    if (this.hasLoadingMessageTarget) {
      this.loadingMessageTarget.textContent = message
    }
  }

  hideLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add('hidden')
    }
  }

  // Utility methods
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  // Cleanup
  disconnect() {
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout)
    }
    
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
  }

  // Keyboard shortcuts
  keydown(event) {
    // Cmd/Ctrl + S for save
    if ((event.metaKey || event.ctrlKey) && event.key === 's') {
      event.preventDefault()
      this.performAutoSave()
    }
    
    // Cmd/Ctrl + P for preview
    if ((event.metaKey || event.ctrlKey) && event.key === 'p') {
      event.preventDefault()
      this.togglePreview()
    }
  }
}