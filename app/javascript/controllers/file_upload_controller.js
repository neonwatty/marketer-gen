import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dropzone", "dropzoneContent", "fileInput", "fileList", "emptyState", 
    "fileCount", "clearButton", "uploadButton", "uploadButtonText",
    "progressContainer", "overallProgress", "overallProgressBar", "individualProgress",
    "messagesContainer", "fileItemTemplate", "progressItemTemplate"
  ]
  
  static values = {
    url: String,
    csrfToken: String
  }

  connect() {
    this.selectedFiles = []
    this.uploadedFiles = []
    this.updateUI()
  }

  // Drag and drop handlers
  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
    this.dropzoneTarget.classList.add("border-indigo-400", "bg-indigo-50")
  }

  handleDragEnter(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-indigo-400", "bg-indigo-50")
  }

  handleDragLeave(event) {
    event.preventDefault()
    // Only remove highlighting if we're leaving the dropzone entirely
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("border-indigo-400", "bg-indigo-50")
    }
  }

  handleDrop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-indigo-400", "bg-indigo-50")
    
    const files = Array.from(event.dataTransfer.files)
    this.addFiles(files)
  }

  // File selection handlers
  openFileSelector() {
    this.fileInputTarget.click()
  }

  handleFileSelect(event) {
    const files = Array.from(event.target.files)
    this.addFiles(files)
  }

  // File management
  addFiles(files) {
    const validFiles = files.filter(file => this.isValidFile(file))
    
    validFiles.forEach(file => {
      // Avoid duplicates
      if (!this.selectedFiles.find(f => f.name === file.name && f.size === file.size)) {
        const fileData = {
          file: file,
          id: this.generateId(),
          name: file.name,
          size: file.size,
          type: file.type,
          assetType: this.determineAssetType(file)
        }
        this.selectedFiles.push(fileData)
      }
    })

    this.updateUI()
    
    // Show validation errors for invalid files
    const invalidFiles = files.filter(file => !this.isValidFile(file))
    if (invalidFiles.length > 0) {
      this.showError(`Some files were skipped: ${invalidFiles.map(f => f.name).join(', ')}`)
    }
  }

  removeFile(event) {
    const fileItem = event.target.closest('[data-file-id]')
    const fileId = fileItem.dataset.fileId
    
    this.selectedFiles = this.selectedFiles.filter(f => f.id !== fileId)
    fileItem.remove()
    
    this.updateUI()
  }

  clearFiles() {
    this.selectedFiles = []
    this.fileListTarget.innerHTML = ''
    this.updateUI()
  }

  // Upload functionality
  async uploadFiles() {
    if (this.selectedFiles.length === 0) return

    this.showProgress()
    this.updateUploadButton('Uploading...', true)

    try {
      // Create FormData for batch upload
      const formData = new FormData()
      
      this.selectedFiles.forEach((fileData, index) => {
        formData.append('brand_asset[files][]', fileData.file)
      })
      
      formData.append('authenticity_token', this.csrfTokenValue)

      // Upload with progress tracking
      const response = await this.uploadWithProgress(formData)
      const result = await response.json()

      if (result.success) {
        this.handleUploadSuccess(result)
      } else {
        this.handleUploadError(result.errors || ['Upload failed'])
      }
    } catch (error) {
      console.error('Upload error:', error)
      this.handleUploadError(['Network error occurred during upload'])
    }
  }

  async uploadWithProgress(formData) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest()
      
      // Track overall upload progress
      xhr.upload.addEventListener('progress', (event) => {
        if (event.lengthComputable) {
          const percentComplete = Math.round((event.loaded / event.total) * 100)
          this.updateOverallProgress(percentComplete)
        }
      })

      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(xhr)
        } else {
          reject(new Error(`HTTP ${xhr.status}: ${xhr.statusText}`))
        }
      })

      xhr.addEventListener('error', () => {
        reject(new Error('Network error'))
      })

      xhr.open('POST', this.urlValue)
      xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
      xhr.setRequestHeader('Accept', 'application/json')
      
      xhr.send(formData)
    })
  }

  // Success/Error handling
  handleUploadSuccess(result) {
    this.showSuccess(`Successfully uploaded ${result.assets?.length || 0} file(s)`)
    
    // Clear the form
    this.selectedFiles = []
    this.fileListTarget.innerHTML = ''
    this.updateUI()
    
    // Redirect or refresh after a delay
    setTimeout(() => {
      window.location.href = this.urlValue.replace('/brand_assets', '/brand_assets')
    }, 2000)
  }

  handleUploadError(errors) {
    const errorMessages = Array.isArray(errors) ? errors : [errors]
    this.showError(`Upload failed: ${errorMessages.join(', ')}`)
    this.updateUploadButton('Upload Files', false)
    this.hideProgress()
  }

  // UI Updates
  updateUI() {
    const fileCount = this.selectedFiles.length
    
    // Update file count
    this.fileCountTarget.textContent = fileCount
    
    // Show/hide empty state
    if (fileCount === 0) {
      this.emptyStateTarget.classList.remove('hidden')
      this.clearButtonTarget.disabled = true
      this.uploadButtonTarget.disabled = true
    } else {
      this.emptyStateTarget.classList.add('hidden')
      this.clearButtonTarget.disabled = false
      this.uploadButtonTarget.disabled = false
    }
    
    // Render file list
    this.renderFileList()
  }

  renderFileList() {
    // Clear existing items
    this.fileListTarget.innerHTML = ''
    
    this.selectedFiles.forEach(fileData => {
      const fileItem = this.createFileItem(fileData)
      this.fileListTarget.appendChild(fileItem)
    })
  }

  createFileItem(fileData) {
    const template = this.fileItemTemplateTarget.content.cloneNode(true)
    const container = template.querySelector('[data-file-id]')
    
    // Set file ID
    container.dataset.fileId = fileData.id
    
    // Populate file info
    template.querySelector('[data-file-name]').textContent = fileData.name
    template.querySelector('[data-file-size]').textContent = this.formatFileSize(fileData.size)
    template.querySelector('[data-file-type]').textContent = fileData.type
    
    // Set asset type selector
    const assetTypeSelect = template.querySelector('[data-asset-type]')
    assetTypeSelect.value = fileData.assetType
    assetTypeSelect.addEventListener('change', (event) => {
      fileData.assetType = event.target.value
    })
    
    // Update icon based on file type
    const icon = template.querySelector('svg')
    this.updateFileIcon(icon, fileData.type)
    
    return template
  }

  updateFileIcon(iconElement, fileType) {
    if (fileType.startsWith('image/')) {
      iconElement.innerHTML = '<path fill-rule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z" clip-rule="evenodd" />'
    } else if (fileType.startsWith('video/')) {
      iconElement.innerHTML = '<path d="M2 6a2 2 0 012-2h6l2 2h6a2 2 0 012 2v6a2 2 0 01-2 2H4a2 2 0 01-2-2V6z" />'
    } else {
      iconElement.innerHTML = '<path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd" />'
    }
  }

  // Progress UI
  showProgress() {
    this.progressContainerTarget.classList.remove('hidden')
    this.updateOverallProgress(0)
  }

  hideProgress() {
    this.progressContainerTarget.classList.add('hidden')
  }

  updateOverallProgress(percent) {
    this.overallProgressTarget.textContent = `${percent}%`
    this.overallProgressBarTarget.style.width = `${percent}%`
  }

  updateUploadButton(text, disabled) {
    this.uploadButtonTextTarget.textContent = text
    this.uploadButtonTarget.disabled = disabled
  }

  // Messages
  showSuccess(message) {
    this.showMessage(message, 'success')
  }

  showError(message) {
    this.showMessage(message, 'error')
  }

  showMessage(message, type) {
    const bgColor = type === 'success' ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'
    const textColor = type === 'success' ? 'text-green-800' : 'text-red-800'
    const iconColor = type === 'success' ? 'text-green-400' : 'text-red-400'
    
    const icon = type === 'success' 
      ? '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />'
      : '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />'

    const messageHTML = `
      <div class="border rounded-lg p-4 ${bgColor}">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 ${iconColor}" fill="currentColor" viewBox="0 0 20 20">
              ${icon}
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm font-medium ${textColor}">${message}</p>
          </div>
        </div>
      </div>
    `
    
    this.messagesContainerTarget.innerHTML = messageHTML
  }

  // Utility functions
  isValidFile(file) {
    const maxSize = 50 * 1024 * 1024 // 50MB
    const allowedTypes = [
      'image/jpeg', 'image/png', 'image/gif', 'image/svg+xml', 'image/webp',
      'video/mp4', 'video/quicktime', 'video/x-msvideo',
      'application/pdf', 'application/msword', 
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain', 'text/rtf'
    ]
    
    return file.size <= maxSize && allowedTypes.includes(file.type)
  }

  determineAssetType(file) {
    const type = file.type
    const name = file.name.toLowerCase()
    
    if (type.startsWith('image/')) {
      return name.includes('logo') ? 'logo' : 'image'
    } else if (type.startsWith('video/')) {
      return 'video'
    } else if (type.includes('pdf') || type.includes('document')) {
      if (name.includes('guideline') || name.includes('brand')) {
        return 'brand_guidelines'
      } else if (name.includes('style')) {
        return 'style_guide'
      }
      return 'document'
    }
    
    return 'document'
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  generateId() {
    return Math.random().toString(36).substr(2, 9)
  }
}