import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = [
    "fileInput", 
    "dropZone", 
    "progressBar", 
    "progressText", 
    "fileList",
    "errorMessages",
    "submitButton"
  ]

  static values = {
    url: String,
    maxFiles: { type: Number, default: 10 },
    maxSize: { type: Number, default: 10 * 1024 * 1024 }, // 10MB in bytes
    allowedTypes: Array
  }

  connect() {
    this.uploadQueue = []
    this.completedUploads = []
    this.setupEventListeners()
    this.updateUI()
  }

  setupEventListeners() {
    // Prevent default drag behaviors on document
    ;['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      document.addEventListener(eventName, this.preventDefaults, false)
    })

    // Highlight drop zone when item is dragged over it
    ;['dragenter', 'dragover'].forEach(eventName => {
      this.dropZoneTarget.addEventListener(eventName, this.highlight.bind(this), false)
    })

    ;['dragleave', 'drop'].forEach(eventName => {
      this.dropZoneTarget.addEventListener(eventName, this.unhighlight.bind(this), false)
    })

    // Handle dropped files
    this.dropZoneTarget.addEventListener('drop', this.handleDrop.bind(this), false)
  }

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  highlight(e) {
    this.dropZoneTarget.classList.add('border-blue-500', 'bg-blue-50')
    this.dropZoneTarget.classList.remove('border-gray-300')
  }

  unhighlight(e) {
    this.dropZoneTarget.classList.remove('border-blue-500', 'bg-blue-50')
    this.dropZoneTarget.classList.add('border-gray-300')
  }

  handleDrop(e) {
    const dt = e.dataTransfer
    const files = dt.files
    this.handleFiles(files)
  }

  // Handle browse button click
  browseFiles() {
    this.fileInputTarget.click()
  }

  // Handle file input change
  fileSelected(e) {
    const files = e.target.files
    this.handleFiles(files)
  }

  handleFiles(files) {
    this.clearErrors()
    
    // Convert FileList to Array
    const fileArray = Array.from(files)
    
    // Validate files
    const validFiles = fileArray.filter(file => this.validateFile(file))
    
    if (validFiles.length === 0) {
      return
    }

    // Check total file limit
    if (this.uploadQueue.length + validFiles.length > this.maxFilesValue) {
      this.showError(`Maximum ${this.maxFilesValue} files allowed`)
      return
    }

    // Add files to upload queue
    validFiles.forEach(file => {
      this.addFileToQueue(file)
    })

    this.updateUI()
  }

  validateFile(file) {
    // Check file size
    if (file.size > this.maxSizeValue) {
      this.showError(`File "${file.name}" is too large. Maximum size is ${this.formatFileSize(this.maxSizeValue)}`)
      return false
    }

    // Check file type if allowedTypes is specified
    if (this.allowedTypesValue && this.allowedTypesValue.length > 0) {
      const fileExtension = this.getFileExtension(file.name)
      const mimeType = file.type
      
      const isValidExtension = this.allowedTypesValue.some(type => 
        type.startsWith('.') ? type.toLowerCase() === `.${fileExtension}` : false
      )
      
      const isValidMimeType = this.allowedTypesValue.some(type => 
        !type.startsWith('.') ? type === mimeType : false
      )
      
      if (!isValidExtension && !isValidMimeType) {
        this.showError(`File "${file.name}" type not allowed. Allowed types: ${this.allowedTypesValue.join(', ')}`)
        return false
      }
    }

    return true
  }

  addFileToQueue(file) {
    const fileId = this.generateFileId()
    const fileItem = {
      id: fileId,
      file: file,
      status: 'pending', // pending, uploading, completed, error
      progress: 0,
      directUpload: null,
      signedId: null,
      error: null
    }

    this.uploadQueue.push(fileItem)
    this.renderFileItem(fileItem)
  }

  generateFileId() {
    return `file_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  renderFileItem(fileItem) {
    const fileItemHtml = `
      <div class="file-item flex items-center justify-between p-3 bg-gray-50 rounded-lg mb-2" data-file-id="${fileItem.id}">
        <div class="flex items-center space-x-3 flex-1">
          <div class="file-icon">
            ${this.getFileIcon(fileItem.file)}
          </div>
          <div class="file-info flex-1 min-w-0">
            <div class="file-name text-sm font-medium text-gray-900 truncate">
              ${fileItem.file.name}
            </div>
            <div class="file-details text-xs text-gray-500">
              ${this.formatFileSize(fileItem.file.size)} • ${this.getFileType(fileItem.file)}
            </div>
          </div>
        </div>
        <div class="file-actions flex items-center space-x-2">
          <div class="progress-container w-24 hidden" data-progress-container>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div class="progress-bar bg-blue-600 h-2 rounded-full transition-all duration-300" 
                   style="width: 0%" data-progress-bar></div>
            </div>
            <div class="text-xs text-gray-500 mt-1 text-center" data-progress-text>0%</div>
          </div>
          <button class="remove-file text-red-500 hover:text-red-700" 
                  data-action="click->file-upload#removeFile"
                  data-file-id="${fileItem.id}">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
      </div>
    `
    this.fileListTarget.insertAdjacentHTML('beforeend', fileItemHtml)
  }

  removeFile(e) {
    const fileId = e.currentTarget.dataset.fileId
    const fileIndex = this.uploadQueue.findIndex(item => item.id === fileId)
    
    if (fileIndex !== -1) {
      const fileItem = this.uploadQueue[fileIndex]
      
      // Cancel ongoing upload if any
      if (fileItem.directUpload) {
        // DirectUpload doesn't have a cancel method, but we can mark it as cancelled
        fileItem.status = 'cancelled'
      }
      
      this.uploadQueue.splice(fileIndex, 1)
      
      // Remove from DOM
      const fileElement = this.fileListTarget.querySelector(`[data-file-id="${fileId}"]`)
      if (fileElement) {
        fileElement.remove()
      }
      
      this.updateUI()
    }
  }

  // Start uploading all files in queue
  startUploads() {
    if (this.uploadQueue.length === 0) {
      this.showError('No files to upload')
      return
    }

    const pendingFiles = this.uploadQueue.filter(item => item.status === 'pending')
    
    if (pendingFiles.length === 0) {
      this.showError('No pending files to upload')
      return
    }

    // Disable submit button during upload
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = 'Uploading...'
    }

    // Start uploading files
    pendingFiles.forEach(fileItem => {
      this.uploadFile(fileItem)
    })

    this.updateOverallProgress()
  }

  uploadFile(fileItem) {
    fileItem.status = 'uploading'
    
    const fileElement = this.getFileElement(fileItem.id)
    const progressContainer = fileElement.querySelector('[data-progress-container]')
    const progressBar = fileElement.querySelector('[data-progress-bar]')
    const progressText = fileElement.querySelector('[data-progress-text]')
    
    // Show progress bar
    progressContainer.classList.remove('hidden')
    
    const directUpload = new DirectUpload(fileItem.file, this.urlValue, {
      directUploadWillStoreFileWithXHR: (request) => {
        request.upload.addEventListener('progress', (event) => {
          const progress = event.loaded / event.total * 100
          fileItem.progress = progress
          
          progressBar.style.width = `${progress}%`
          progressText.textContent = `${Math.round(progress)}%`
          
          this.updateOverallProgress()
        })
      }
    })

    fileItem.directUpload = directUpload

    directUpload.create((error, blob) => {
      if (error) {
        fileItem.status = 'error'
        fileItem.error = error.message || 'Upload failed'
        this.handleUploadError(fileItem)
      } else {
        fileItem.status = 'completed'
        fileItem.signedId = blob.signed_id
        fileItem.progress = 100
        this.handleUploadSuccess(fileItem)
        
        // Move to completed uploads
        this.completedUploads.push(fileItem)
      }
      
      this.updateOverallProgress()
      this.checkAllUploadsComplete()
    })
  }

  handleUploadSuccess(fileItem) {
    const fileElement = this.getFileElement(fileItem.id)
    fileElement.classList.add('border-green-200', 'bg-green-50')
    
    // Add success indicator
    const actionsContainer = fileElement.querySelector('.file-actions')
    actionsContainer.innerHTML = `
      <div class="text-green-600">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
      </div>
    `
  }

  handleUploadError(fileItem) {
    const fileElement = this.getFileElement(fileItem.id)
    fileElement.classList.add('border-red-200', 'bg-red-50')
    
    // Show error message
    const fileInfo = fileElement.querySelector('.file-info')
    fileInfo.insertAdjacentHTML('beforeend', `
      <div class="text-xs text-red-600 mt-1">
        Error: ${fileItem.error}
      </div>
    `)
    
    // Add retry button
    const actionsContainer = fileElement.querySelector('.file-actions')
    actionsContainer.innerHTML = `
      <button class="text-blue-500 hover:text-blue-700 text-xs" 
              data-action="click->file-upload#retryUpload"
              data-file-id="${fileItem.id}">
        Retry
      </button>
    `
    
    this.showError(`Upload failed for "${fileItem.file.name}": ${fileItem.error}`)
  }

  retryUpload(e) {
    const fileId = e.currentTarget.dataset.fileId
    const fileItem = this.uploadQueue.find(item => item.id === fileId)
    
    if (fileItem) {
      fileItem.status = 'pending'
      fileItem.progress = 0
      fileItem.error = null
      fileItem.directUpload = null
      
      // Reset file element styling
      const fileElement = this.getFileElement(fileId)
      fileElement.classList.remove('border-red-200', 'bg-red-50')
      fileElement.classList.add('bg-gray-50')
      
      // Remove error message
      const errorMsg = fileElement.querySelector('.text-red-600')
      if (errorMsg) {
        errorMsg.remove()
      }
      
      // Reset actions
      const actionsContainer = fileElement.querySelector('.file-actions')
      actionsContainer.innerHTML = `
        <div class="progress-container w-24 hidden" data-progress-container>
          <div class="w-full bg-gray-200 rounded-full h-2">
            <div class="progress-bar bg-blue-600 h-2 rounded-full transition-all duration-300" 
                 style="width: 0%" data-progress-bar></div>
          </div>
          <div class="text-xs text-gray-500 mt-1 text-center" data-progress-text>0%</div>
        </div>
        <button class="remove-file text-red-500 hover:text-red-700" 
                data-action="click->file-upload#removeFile"
                data-file-id="${fileId}">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      `
      
      this.uploadFile(fileItem)
    }
  }

  updateOverallProgress() {
    if (!this.hasProgressBarTarget) return
    
    const totalFiles = this.uploadQueue.length
    if (totalFiles === 0) return
    
    const totalProgress = this.uploadQueue.reduce((sum, item) => sum + item.progress, 0)
    const overallProgress = totalProgress / totalFiles
    
    this.progressBarTarget.style.width = `${overallProgress}%`
    
    if (this.hasProgressTextTarget) {
      const completedCount = this.uploadQueue.filter(item => item.status === 'completed').length
      this.progressTextTarget.textContent = `${completedCount} / ${totalFiles} files uploaded`
    }
  }

  checkAllUploadsComplete() {
    const pendingOrUploading = this.uploadQueue.filter(item => 
      item.status === 'pending' || item.status === 'uploading'
    )
    
    if (pendingOrUploading.length === 0) {
      // All uploads complete
      this.onAllUploadsComplete()
    }
  }

  onAllUploadsComplete() {
    const completedCount = this.uploadQueue.filter(item => item.status === 'completed').length
    const errorCount = this.uploadQueue.filter(item => item.status === 'error').length
    
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = 'Submit'
    }
    
    // Dispatch custom event with upload results
    const detail = {
      completed: this.completedUploads,
      errors: this.uploadQueue.filter(item => item.status === 'error'),
      totalFiles: this.uploadQueue.length,
      completedCount,
      errorCount
    }
    
    this.dispatch('completed', { detail })
    
    if (errorCount > 0) {
      this.showError(`${errorCount} file(s) failed to upload. Please check and retry.`)
    } else {
      this.showSuccess(`All ${completedCount} file(s) uploaded successfully!`)
    }
  }

  // Get completed file signed IDs for form submission
  getCompletedFileSignedIds() {
    return this.completedUploads.map(upload => upload.signedId)
  }

  // Utility methods
  getFileElement(fileId) {
    return this.fileListTarget.querySelector(`[data-file-id="${fileId}"]`)
  }

  getFileIcon(file) {
    const fileType = this.getFileType(file)
    const iconMap = {
      'image': '🖼️',
      'pdf': '📄',
      'document': '📝',
      'font': '🔤',
      'default': '📁'
    }
    
    if (file.type.startsWith('image/')) return iconMap.image
    if (file.type === 'application/pdf') return iconMap.pdf
    if (file.type.includes('document') || file.type.includes('word')) return iconMap.document
    if (file.type.startsWith('font/')) return iconMap.font
    
    return iconMap.default
  }

  getFileType(file) {
    if (file.type.startsWith('image/')) return 'Image'
    if (file.type === 'application/pdf') return 'PDF'
    if (file.type.includes('document') || file.type.includes('word')) return 'Document'
    if (file.type.includes('presentation') || file.type.includes('powerpoint')) return 'Presentation'
    if (file.type.startsWith('font/')) return 'Font'
    return 'File'
  }

  getFileExtension(filename) {
    return filename.toLowerCase().split('.').pop()
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  updateUI() {
    // Show/hide file list based on queue
    if (this.uploadQueue.length > 0) {
      this.fileListTarget.classList.remove('hidden')
    } else {
      this.fileListTarget.classList.add('hidden')
    }
    
    // Update submit button state
    if (this.hasSubmitButtonTarget) {
      const hasCompletedUploads = this.completedUploads.length > 0
      this.submitButtonTarget.disabled = !hasCompletedUploads
    }
  }

  clearErrors() {
    if (this.hasErrorMessagesTarget) {
      this.errorMessagesTarget.innerHTML = ''
      this.errorMessagesTarget.classList.add('hidden')
    }
  }

  showError(message) {
    if (this.hasErrorMessagesTarget) {
      this.errorMessagesTarget.innerHTML = `
        <div class="flex items-center p-4 mb-4 text-sm text-red-800 border border-red-300 rounded-lg bg-red-50">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <span>${message}</span>
        </div>
      `
      this.errorMessagesTarget.classList.remove('hidden')
    }
  }

  showSuccess(message) {
    if (this.hasErrorMessagesTarget) {
      this.errorMessagesTarget.innerHTML = `
        <div class="flex items-center p-4 mb-4 text-sm text-green-800 border border-green-300 rounded-lg bg-green-50">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
          </svg>
          <span>${message}</span>
        </div>
      `
      this.errorMessagesTarget.classList.remove('hidden')
    }
  }
}