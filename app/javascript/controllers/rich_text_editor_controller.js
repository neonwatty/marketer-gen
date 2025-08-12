import { Controller } from "@hotwired/stimulus"
import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'

export default class extends Controller {
  static targets = ["editor", "content", "toolbar", "preview", "channelSelector", "error"]
  static values = { 
    content: String, 
    channel: String,
    placeholder: String,
    editable: { type: Boolean, default: true }
  }

  connect() {
    this.initializeEditor()
    this.initializePreviewUpdates()
    this.updatePreview()
  }

  disconnect() {
    if (this.editor) {
      this.editor.destroy()
    }
  }

  initializeEditor() {
    try {
      this.editor = new Editor({
        element: this.editorTarget,
        extensions: [
          StarterKit.configure({
            heading: {
              levels: [1, 2, 3],
            },
          }),
        ],
        content: this.contentValue || this.placeholderValue || '<p>Start typing...</p>',
        editable: this.editableValue,
        onUpdate: ({ editor }) => {
          this.onEditorUpdate(editor)
        },
        onCreate: ({ editor }) => {
          this.onEditorCreate(editor)
        },
        onSelectionUpdate: ({ editor }) => {
          this.updateToolbar(editor)
        }
      })
    } catch (error) {
      this.showError(`Failed to initialize editor: ${error.message}`)
    }
  }

  onEditorCreate(editor) {
    this.updateToolbar(editor)
    this.updatePreview()
  }

  onEditorUpdate(editor) {
    const html = editor.getHTML()
    this.contentValue = html
    
    // Update hidden input if present
    if (this.hasContentTarget) {
      this.contentTarget.value = html
    }
    
    this.updatePreview()
    this.dispatch("content-changed", { detail: { content: html } })
  }

  updateToolbar(editor) {
    if (!this.hasToolbarTarget) return

    const toolbarButtons = this.toolbarTarget.querySelectorAll('[data-action]')
    
    toolbarButtons.forEach(button => {
      const action = button.dataset.action
      let isActive = false

      switch (action) {
        case 'rich-text-editor#toggleBold':
          isActive = editor.isActive('bold')
          break
        case 'rich-text-editor#toggleItalic':
          isActive = editor.isActive('italic')
          break
        case 'rich-text-editor#toggleStrike':
          isActive = editor.isActive('strike')
          break
        case 'rich-text-editor#toggleCode':
          isActive = editor.isActive('code')
          break
        case 'rich-text-editor#toggleBulletList':
          isActive = editor.isActive('bulletList')
          break
        case 'rich-text-editor#toggleOrderedList':
          isActive = editor.isActive('orderedList')
          break
        case 'rich-text-editor#toggleBlockquote':
          isActive = editor.isActive('blockquote')
          break
      }

      button.classList.toggle('is-active', isActive)
      button.classList.toggle('bg-blue-100', isActive)
      button.classList.toggle('text-blue-800', isActive)
    })
  }

  initializePreviewUpdates() {
    // Listen for channel changes
    if (this.hasChannelSelectorTarget) {
      this.channelSelectorTarget.addEventListener('change', () => {
        this.channelValue = this.channelSelectorTarget.value
        this.updatePreview()
      })
    }
  }

  updatePreview() {
    if (!this.hasPreviewTarget || !this.editor) return

    const content = this.editor.getHTML()
    const channel = this.channelValue || 'general'
    
    this.renderChannelPreview(content, channel)
  }

  renderChannelPreview(content, channel) {
    const previewContainer = this.previewTarget
    
    // Create channel-specific preview template
    const previewHTML = this.generateChannelPreviewHTML(content, channel)
    
    previewContainer.innerHTML = previewHTML
    previewContainer.classList.remove('hidden')
  }

  generateChannelPreviewHTML(content, channel) {
    const channelConfigs = {
      social_media: {
        title: 'Social Media Preview',
        containerClass: 'bg-white border rounded-lg p-4 max-w-md mx-auto shadow-sm',
        contentClass: 'text-gray-800 text-sm leading-relaxed',
        headerHTML: `
          <div class="flex items-center mb-3">
            <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-sm">
              B
            </div>
            <div class="ml-3">
              <div class="font-semibold text-sm text-gray-900">Brand Account</div>
              <div class="text-xs text-gray-500">Just now</div>
            </div>
          </div>
        `,
        footerHTML: `
          <div class="flex items-center justify-between mt-3 pt-2 border-t border-gray-100">
            <div class="flex space-x-4 text-gray-500">
              <button class="flex items-center space-x-1 text-xs hover:text-blue-600">
                <span>👍</span><span>Like</span>
              </button>
              <button class="flex items-center space-x-1 text-xs hover:text-blue-600">
                <span>💬</span><span>Comment</span>
              </button>
              <button class="flex items-center space-x-1 text-xs hover:text-blue-600">
                <span>↗️</span><span>Share</span>
              </button>
            </div>
          </div>
        `
      },
      email: {
        title: 'Email Preview',
        containerClass: 'bg-white border rounded-lg max-w-2xl mx-auto shadow-sm',
        contentClass: 'text-gray-800 text-sm leading-relaxed px-6 py-4',
        headerHTML: `
          <div class="border-b border-gray-200 px-6 py-3">
            <div class="flex items-center justify-between">
              <div>
                <div class="font-semibold text-sm text-gray-900">Campaign Email</div>
                <div class="text-xs text-gray-500">from: your-company@example.com</div>
              </div>
              <div class="text-xs text-gray-500">${new Date().toLocaleDateString()}</div>
            </div>
          </div>
        `,
        footerHTML: `
          <div class="border-t border-gray-200 px-6 py-3 bg-gray-50 text-xs text-gray-500">
            <div class="text-center">
              <p>This email was sent to subscriber@example.com</p>
              <p class="mt-1">
                <a href="#" class="text-blue-600 hover:underline">Unsubscribe</a> | 
                <a href="#" class="text-blue-600 hover:underline">View in browser</a>
              </p>
            </div>
          </div>
        `
      },
      ads: {
        title: 'Ad Preview',
        containerClass: 'bg-white border rounded-lg p-4 max-w-md mx-auto shadow-sm',
        contentClass: 'text-gray-800 text-sm leading-relaxed',
        headerHTML: `
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center">
              <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center text-white font-bold text-xs">
                AD
              </div>
              <div class="ml-2">
                <div class="font-semibold text-xs text-gray-900">Sponsored</div>
              </div>
            </div>
            <div class="text-xs text-gray-500">•••</div>
          </div>
        `,
        footerHTML: `
          <div class="mt-3">
            <button class="w-full bg-blue-600 text-white text-sm font-medium py-2 px-4 rounded hover:bg-blue-700 transition-colors">
              Learn More
            </button>
          </div>
        `
      },
      general: {
        title: 'Content Preview',
        containerClass: 'bg-white border rounded-lg p-6 max-w-2xl mx-auto shadow-sm',
        contentClass: 'prose prose-sm max-w-none',
        headerHTML: '',
        footerHTML: ''
      }
    }

    const config = channelConfigs[channel] || channelConfigs.general

    return `
      <div class="mb-2">
        <h3 class="text-lg font-semibold text-gray-900">${config.title}</h3>
      </div>
      <div class="${config.containerClass}">
        ${config.headerHTML}
        <div class="${config.contentClass}">
          ${content}
        </div>
        ${config.footerHTML}
      </div>
    `
  }

  // Toolbar actions
  toggleBold() {
    this.editor.chain().focus().toggleBold().run()
  }

  toggleItalic() {
    this.editor.chain().focus().toggleItalic().run()
  }

  toggleStrike() {
    this.editor.chain().focus().toggleStrike().run()
  }

  toggleCode() {
    this.editor.chain().focus().toggleCode().run()
  }

  toggleBulletList() {
    this.editor.chain().focus().toggleBulletList().run()
  }

  toggleOrderedList() {
    this.editor.chain().focus().toggleOrderedList().run()
  }

  toggleBlockquote() {
    this.editor.chain().focus().toggleBlockquote().run()
  }

  setHeading(event) {
    const level = parseInt(event.target.dataset.level) || 1
    this.editor.chain().focus().toggleHeading({ level }).run()
  }

  undo() {
    this.editor.chain().focus().undo().run()
  }

  redo() {
    this.editor.chain().focus().redo().run()
  }

  clearContent() {
    this.editor.commands.clearContent()
    this.updatePreview()
  }

  insertContent(event) {
    const content = event.target.dataset.content || ''
    this.editor.chain().focus().insertContent(content).run()
  }

  // Channel switching
  channelValueChanged() {
    this.updatePreview()
  }

  // Content management
  getContent() {
    return this.editor.getHTML()
  }

  getJSON() {
    return this.editor.getJSON()
  }

  getText() {
    return this.editor.getText()
  }

  setContent(content) {
    this.editor.commands.setContent(content)
    this.contentValue = content
    this.updatePreview()
  }

  // Mobile responsiveness
  toggleMobilePreview() {
    const preview = this.previewTarget
    preview.classList.toggle('mobile-preview')
    
    if (preview.classList.contains('mobile-preview')) {
      preview.style.maxWidth = '375px'
      preview.style.margin = '0 auto'
    } else {
      preview.style.maxWidth = ''
      preview.style.margin = ''
    }
  }

  // Error handling
  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove('hidden')
      
      // Auto-hide error after 5 seconds
      setTimeout(() => {
        this.errorTarget.classList.add('hidden')
      }, 5000)
    } else {
      console.error('Rich Text Editor Error:', message)
    }
  }

  // Export functionality
  exportHTML() {
    const content = this.getContent()
    this.downloadFile(content, 'content.html', 'text/html')
  }

  exportMarkdown() {
    // Basic HTML to Markdown conversion
    const html = this.getContent()
    const markdown = this.htmlToMarkdown(html)
    this.downloadFile(markdown, 'content.md', 'text/markdown')
  }

  htmlToMarkdown(html) {
    // Basic conversion - could be enhanced with a proper library
    return html
      .replace(/<h1>(.*?)<\/h1>/gi, '# $1\n\n')
      .replace(/<h2>(.*?)<\/h2>/gi, '## $1\n\n')
      .replace(/<h3>(.*?)<\/h3>/gi, '### $1\n\n')
      .replace(/<p>(.*?)<\/p>/gi, '$1\n\n')
      .replace(/<strong>(.*?)<\/strong>/gi, '**$1**')
      .replace(/<em>(.*?)<\/em>/gi, '*$1*')
      .replace(/<code>(.*?)<\/code>/gi, '`$1`')
      .replace(/<blockquote>(.*?)<\/blockquote>/gi, '> $1\n\n')
      .replace(/<ul><li>(.*?)<\/li><\/ul>/gi, '- $1\n')
      .replace(/<li>(.*?)<\/li>/gi, '- $1\n')
      .replace(/<br\s*\/?>/gi, '\n')
      .trim()
  }

  downloadFile(content, filename, mimeType) {
    const blob = new Blob([content], { type: mimeType })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }
}