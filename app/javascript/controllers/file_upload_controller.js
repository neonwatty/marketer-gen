import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = [
    "dropzone", "dropzoneContent", "fileInput", "fileList", "emptyState", 
    "fileCount", "clearButton", "uploadButton", "uploadButtonText",
    "progressContainer", "overallProgress", "overallProgressBar", "individualProgress",
    "messagesContainer", "fileItemTemplate", "progressItemTemplate", "uploadQueue",
    "brandAnalysisProgress", "processingStatus", "batchProgress"
  ]
  
  static values = {
    url: String,
    csrfToken: String,
    brandId: Number,
    chunkSize: { type: Number, default: 1024 * 1024 }, // 1MB chunks
    maxConcurrent: { type: Number, default: 3 },
    enableAnalysis: { type: Boolean, default: true }
  }

  connect() {
    console.log("Enhanced brand file upload controller connected")
    this.selectedFiles = []
    this.uploadedFiles = []
    this.uploadQueue = []
    this.activeUploads = 0
    this.totalBytes = 0
    this.uploadedBytes = 0
    
    this.initializeWebSocket()
    this.setupAdvancedDropzone()
    this.updateUI()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.dragoverTimeout) {
      clearTimeout(this.dragoverTimeout)
    }
  }

  // WebSocket for real-time processing updates
  initializeWebSocket() {
    if (!this.brandIdValue) {return}

    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: "BrandAssetProcessingChannel",
        brand_id: this.brandIdValue
      },
      {
        connected: this.wsConnected.bind(this),
        disconnected: this.wsDisconnected.bind(this),
        received: this.wsReceived.bind(this)
      }
    )
  }

  wsConnected() {
    console.log("Connected to brand asset processing channel")
  }

  wsDisconnected() {
    console.log("Disconnected from brand asset processing channel")
  }

  wsReceived(data) {
    switch (data.event) {
      case "processing_started":
        this.handleProcessingStarted(data)
        break
      case "processing_progress":
        this.handleProcessingProgress(data)
        break
      case "processing_complete":
        this.handleProcessingComplete(data)
        break
      case "analysis_complete":
        this.handleAnalysisComplete(data)
        break
      case "processing_error":
        this.handleProcessingError(data)
        break
    }
  }

  // Advanced drag and drop with visual feedback
  setupAdvancedDropzone() {
    this.dragCounter = 0
    
    // Global drag handlers to detect when files enter/leave window
    document.addEventListener('dragenter', this.handleGlobalDragEnter.bind(this))
    document.addEventListener('dragover', this.handleGlobalDragOver.bind(this))
    document.addEventListener('dragleave', this.handleGlobalDragLeave.bind(this))
    document.addEventListener('drop', this.handleGlobalDrop.bind(this))
  }

  handleGlobalDragEnter(event) {
    event.preventDefault()
    this.dragCounter++
    
    if (this.dragCounter === 1) {
      this.showGlobalDropOverlay()
    }
  }

  handleGlobalDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
  }

  handleGlobalDragLeave(event) {
    event.preventDefault()
    this.dragCounter--
    
    if (this.dragCounter === 0) {
      this.hideGlobalDropOverlay()
    }
  }

  handleGlobalDrop(event) {
    event.preventDefault()
    this.dragCounter = 0
    this.hideGlobalDropOverlay()
    
    // Only handle if dropped on our dropzone
    if (this.dropzoneTarget.contains(event.target)) {
      const files = Array.from(event.dataTransfer.files)
      this.addFiles(files)
    }
  }

  showGlobalDropOverlay() {
    this.dropzoneTarget.classList.add("border-indigo-400", "bg-indigo-50", "scale-105")
    this.dropzoneTarget.style.transform = "scale(1.02)"
    this.dropzoneTarget.style.transition = "all 0.2s ease"
  }

  hideGlobalDropOverlay() {
    this.dropzoneTarget.classList.remove("border-indigo-400", "bg-indigo-50", "scale-105")
    this.dropzoneTarget.style.transform = ""
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
          file,
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

  // Enhanced Upload functionality with chunking and concurrency
  async uploadFiles() {
    if (this.selectedFiles.length === 0) {return}

    this.showProgress()
    this.updateUploadButton('Uploading...', true)

    try {
      // Calculate total bytes for progress tracking
      this.totalBytes = this.selectedFiles.reduce((total, file) => total + file.file.size, 0)
      this.uploadedBytes = 0

      // Process files with chunking for large files
      const uploadPromises = this.selectedFiles.map((fileData, index) => {
        if (fileData.file.size > this.chunkSizeValue) {
          return this.uploadFileInChunks(fileData, index)
        } else {
          return this.uploadSingleFile(fileData, index)
        }
      })

      // Limit concurrent uploads using a queue
      const results = await this.processUploadQueue(uploadPromises)
      
      const successfulUploads = results.filter(r => r.success)
      const failedUploads = results.filter(r => !r.success)

      if (successfulUploads.length > 0) {
        this.handleUploadSuccess({
          assets: successfulUploads,
          total: this.selectedFiles.length,
          successful: successfulUploads.length,
          failed: failedUploads.length
        })
      }

      if (failedUploads.length > 0) {
        this.handlePartialUploadFailure(failedUploads)
      }

    } catch (error) {
      console.error('Upload error:', error)
      this.handleUploadError(['Network error occurred during upload'])
    }
  }

  async processUploadQueue(uploadPromises) {
    const results = []
    const queue = [...uploadPromises]
    const active = []

    while (queue.length > 0 || active.length > 0) {
      // Start new uploads up to max concurrent limit
      while (active.length < this.maxConcurrentValue && queue.length > 0) {
        const promise = queue.shift()
        active.push(promise)
      }

      // Wait for at least one upload to complete
      const result = await Promise.race(active)
      const index = active.indexOf(result)
      active.splice(index, 1)
      results.push(await result)

      // Update overall progress
      this.updateBatchProgress(results.length, uploadPromises.length)
    }

    return results
  }

  async uploadFileInChunks(fileData, index) {
    const file = fileData.file
    const chunkCount = Math.ceil(file.size / this.chunkSizeValue)
    const uploadId = this.generateUploadId()
    
    this.updateFileProgress(fileData.id, 0, 'Preparing chunks...')

    try {
      // Initialize chunked upload
      const initResponse = await fetch(`${this.urlValue}/init_chunked`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({
          filename: file.name,
          filesize: file.size,
          chunk_count: chunkCount,
          upload_id: uploadId,
          content_type: file.type,
          asset_type: fileData.assetType
        })
      })

      if (!initResponse.ok) {
        throw new Error('Failed to initialize chunked upload')
      }

      const initData = await initResponse.json()
      
      // Upload chunks sequentially with progress tracking
      for (let chunkIndex = 0; chunkIndex < chunkCount; chunkIndex++) {
        const start = chunkIndex * this.chunkSizeValue
        const end = Math.min(start + this.chunkSizeValue, file.size)
        const chunk = file.slice(start, end)

        await this.uploadChunk(uploadId, chunkIndex, chunk, fileData)
        
        const progress = Math.round(((chunkIndex + 1) / chunkCount) * 100)
        this.updateFileProgress(fileData.id, progress, `Uploading chunk ${chunkIndex + 1}/${chunkCount}`)
      }

      // Finalize upload
      const finalizeResponse = await fetch(`${this.urlValue}/finalize_chunked`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({
          upload_id: uploadId,
          brand_id: this.brandIdValue
        })
      })

      const result = await finalizeResponse.json()
      
      if (result.success) {
        this.updateFileProgress(fileData.id, 100, 'Upload complete')
        return { success: true, asset: result.asset, fileData }
      } else {
        throw new Error(result.error || 'Failed to finalize upload')
      }

    } catch (error) {
      this.updateFileProgress(fileData.id, 0, `Error: ${error.message}`)
      return { success: false, error: error.message, fileData }
    }
  }

  async uploadChunk(uploadId, chunkIndex, chunk, fileData) {
    const formData = new FormData()
    formData.append('upload_id', uploadId)
    formData.append('chunk_index', chunkIndex)
    formData.append('chunk', chunk)
    formData.append('authenticity_token', this.csrfTokenValue)

    const response = await fetch(`${this.urlValue}/upload_chunk`, {
      method: 'POST',
      body: formData
    })

    if (!response.ok) {
      throw new Error(`Failed to upload chunk ${chunkIndex}`)
    }

    // Update global progress
    this.uploadedBytes += chunk.size
    this.updateOverallProgress(Math.round((this.uploadedBytes / this.totalBytes) * 100))

    return response.json()
  }

  async uploadSingleFile(fileData, index) {
    try {
      const formData = new FormData()
      formData.append('brand_asset[file]', fileData.file)
      formData.append('brand_asset[asset_type]', fileData.assetType)
      formData.append('brand_asset[brand_id]', this.brandIdValue)
      formData.append('authenticity_token', this.csrfTokenValue)

      this.updateFileProgress(fileData.id, 0, 'Starting upload...')

      const response = await this.uploadWithProgressTracking(formData, fileData)
      const result = await response.json()

      if (result.success) {
        this.updateFileProgress(fileData.id, 100, 'Upload complete')
        return { success: true, asset: result.asset, fileData }
      } else {
        throw new Error(result.error || 'Upload failed')
      }

    } catch (error) {
      this.updateFileProgress(fileData.id, 0, `Error: ${error.message}`)
      return { success: false, error: error.message, fileData }
    }
  }

  async uploadWithProgressTracking(formData, fileData) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest()
      
      // Track individual file upload progress
      xhr.upload.addEventListener('progress', (event) => {
        if (event.lengthComputable) {
          const percentComplete = Math.round((event.loaded / event.total) * 100)
          this.updateFileProgress(fileData.id, percentComplete, 'Uploading...')
          
          // Update global progress
          this.uploadedBytes += (event.loaded - (fileData.lastLoaded || 0))
          fileData.lastLoaded = event.loaded
          this.updateOverallProgress(Math.round((this.uploadedBytes / this.totalBytes) * 100))
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

  // WebSocket event handlers for processing updates
  handleProcessingStarted(data) {
    if (this.hasProcessingStatusTarget) {
      this.processingStatusTarget.textContent = 'Processing started...'
      this.processingStatusTarget.className = 'text-blue-600'
    }
    
    this.showBrandAnalysisProgress()
  }

  handleProcessingProgress(data) {
    if (this.hasBrandAnalysisProgressTarget) {
      const progress = data.progress || 0
      const stage = data.stage || 'Processing...'
      
      this.updateBrandAnalysisProgress(progress, stage)
    }
  }

  handleProcessingComplete(data) {
    if (this.hasProcessingStatusTarget) {
      this.processingStatusTarget.textContent = 'Processing complete'
      this.processingStatusTarget.className = 'text-green-600'
    }
    
    this.hideBrandAnalysisProgress()
    
    if (data.asset) {
      this.showBrandAssetResult(data.asset)
    }
  }

  handleAnalysisComplete(data) {
    if (this.enableAnalysisValue && data.analysis) {
      this.showBrandAnalysisResult(data.analysis)
    }
  }

  handleProcessingError(data) {
    if (this.hasProcessingStatusTarget) {
      this.processingStatusTarget.textContent = `Processing error: ${data.error}`
      this.processingStatusTarget.className = 'text-red-600'
    }
    
    this.hideBrandAnalysisProgress()
    this.showError(`Processing failed: ${data.error}`)
  }

  // Success/Error handling
  handleUploadSuccess(result) {
    const message = result.failed > 0 
      ? `Uploaded ${result.successful}/${result.total} files (${result.failed} failed)`
      : `Successfully uploaded ${result.successful} file(s)`
    
    this.showSuccess(message)
    
    // Clear the form
    this.selectedFiles = []
    this.fileListTarget.innerHTML = ''
    this.updateUI()
    this.hideProgress()
    this.updateUploadButton('Upload Files', false)
    
    // Start brand analysis if enabled
    if (this.enableAnalysisValue && result.assets && result.assets.length > 0) {
      this.triggerBrandAnalysis(result.assets)
    }
    
    // Refresh the asset list after a delay
    setTimeout(() => {
      this.refreshAssetDisplay()
    }, 1000)
  }

  handlePartialUploadFailure(failedUploads) {
    const failedFiles = failedUploads.map(upload => upload.fileData.name).join(', ')
    this.showError(`Some uploads failed: ${failedFiles}`)
  }

  handleUploadError(errors) {
    const errorMessages = Array.isArray(errors) ? errors : [errors]
    this.showError(`Upload failed: ${errorMessages.join(', ')}`)
    this.updateUploadButton('Upload Files', false)
    this.hideProgress()
  }

  // Brand Analysis Integration
  async triggerBrandAnalysis(assets) {
    if (!this.brandIdValue) {return}

    try {
      const response = await fetch(`/api/v1/brands/${this.brandIdValue}/analyze_assets`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({
          asset_ids: assets.map(a => a.asset?.id || a.id).filter(Boolean)
        })
      })

      if (response.ok) {
        const result = await response.json()
        this.showSuccess('Brand analysis started for uploaded assets')
      } else {
        console.warn('Failed to trigger brand analysis:', response.statusText)
      }
    } catch (error) {
      console.error('Error triggering brand analysis:', error)
    }
  }

  refreshAssetDisplay() {
    // Trigger a refresh of the brand assets display
    const assetsContainer = document.querySelector('[data-brand-assets-list]')
    if (assetsContainer) {
      // Could trigger a Turbo refresh or custom event
      const event = new CustomEvent('brand:assets:refresh', {
        detail: { brandId: this.brandIdValue }
      })
      document.dispatchEvent(event)
    }
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
    if (bytes === 0) {return '0 Bytes'}
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))  } ${  sizes[i]}`
  }

  generateId() {
    return Math.random().toString(36).substr(2, 9)
  }

  generateUploadId() {
    return `upload_${  Date.now()  }_${  Math.random().toString(36).substr(2, 9)}`
  }

  // Enhanced Progress Methods
  updateFileProgress(fileId, percentage, status) {
    const fileElement = this.fileListTarget.querySelector(`[data-file-id="${fileId}"]`)
    if (!fileElement) {return}

    const progressBar = fileElement.querySelector('.file-progress-bar')
    const progressText = fileElement.querySelector('.file-progress-text')
    const statusText = fileElement.querySelector('.file-status-text')

    if (progressBar) {
      progressBar.style.width = `${percentage}%`
      progressBar.className = `file-progress-bar h-2 rounded transition-all duration-300 ${
        percentage === 100 ? 'bg-green-500' : 
        percentage === 0 ? 'bg-red-500' : 'bg-blue-500'
      }`
    }

    if (progressText) {
      progressText.textContent = `${percentage}%`
    }

    if (statusText) {
      statusText.textContent = status
      statusText.className = `file-status-text text-xs ${
        percentage === 100 ? 'text-green-600' : 
        percentage === 0 ? 'text-red-600' : 'text-blue-600'
      }`
    }
  }

  updateBatchProgress(completed, total) {
    if (this.hasBatchProgressTarget) {
      const percentage = Math.round((completed / total) * 100)
      const progressFill = this.batchProgressTarget.querySelector('.batch-progress-fill')
      const progressText = this.batchProgressTarget.querySelector('.batch-progress-text')

      if (progressFill) {
        progressFill.style.width = `${percentage}%`
      }

      if (progressText) {
        progressText.textContent = `${completed}/${total} files processed`
      }
    }
  }

  showBrandAnalysisProgress() {
    if (this.hasBrandAnalysisProgressTarget) {
      this.brandAnalysisProgressTarget.classList.remove('hidden')
    }
  }

  hideBrandAnalysisProgress() {
    if (this.hasBrandAnalysisProgressTarget) {
      this.brandAnalysisProgressTarget.classList.add('hidden')
    }
  }

  updateBrandAnalysisProgress(percentage, stage) {
    if (!this.hasBrandAnalysisProgressTarget) {return}

    const progressBar = this.brandAnalysisProgressTarget.querySelector('.analysis-progress-bar')
    const progressText = this.brandAnalysisProgressTarget.querySelector('.analysis-progress-text') 
    const stageText = this.brandAnalysisProgressTarget.querySelector('.analysis-stage-text')

    if (progressBar) {
      progressBar.style.width = `${percentage}%`
    }

    if (progressText) {
      progressText.textContent = `${percentage}%`
    }

    if (stageText) {
      stageText.textContent = stage
    }
  }

  showBrandAssetResult(asset) {
    const notification = this.createNotification(
      `Brand asset processed: ${asset.filename || asset.name}`,
      'success',
      {
        action: 'View Asset',
        actionUrl: `/brand_assets/${asset.id}`
      }
    )
    document.body.appendChild(notification)
  }

  showBrandAnalysisResult(analysis) {
    const notification = this.createNotification(
      `Brand analysis complete. Confidence: ${Math.round(analysis.confidence * 100)}%`,
      'info',
      {
        action: 'View Analysis',
        actionUrl: `/brands/${this.brandIdValue}#analysis`
      }
    )
    document.body.appendChild(notification)
  }

  createNotification(message, type, options = {}) {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg transition-all duration-300 transform translate-x-full opacity-0 max-w-sm ${
      type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' :
      type === 'error' ? 'bg-red-100 text-red-800 border border-red-200' :
      type === 'warning' ? 'bg-yellow-100 text-yellow-800 border border-yellow-200' :
      'bg-blue-100 text-blue-800 border border-blue-200'
    }`
    
    notification.innerHTML = `
      <div class="flex items-start">
        <div class="flex-shrink-0">
          ${type === 'success' ? 
            '<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>' :
            type === 'error' ?
            '<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>' :
            '<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'
          }
        </div>
        <div class="ml-3 flex-1">
          <p class="text-sm font-medium">${message}</p>
          ${options.action && options.actionUrl ? `
            <div class="mt-2">
              <a href="${options.actionUrl}" class="text-xs underline hover:no-underline">
                ${options.action}
              </a>
            </div>
          ` : ''}
        </div>
        <div class="ml-auto pl-3">
          <button onclick="this.parentElement.parentElement.remove()" class="text-current hover:opacity-75">
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>
    `
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full', 'opacity-0')
    }, 10)
    
    // Auto remove after 7 seconds
    setTimeout(() => {
      notification.classList.add('translate-x-full', 'opacity-0')
      setTimeout(() => {
        if (notification.parentElement) {
          notification.remove()
        }
      }, 300)
    }, 7000)
    
    return notification
  }
}