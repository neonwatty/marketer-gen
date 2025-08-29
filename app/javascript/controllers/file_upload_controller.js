import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-upload"
export default class extends Controller {
  static targets = ["input", "preview", "count"]
  static values = { maxFiles: Number, maxSize: Number }

  connect() {
    this.maxFilesValue = this.maxFilesValue || 10
    this.maxSizeValue = this.maxSizeValue || 10 * 1024 * 1024 // 10MB default
  }

  change(event) {
    const files = Array.from(event.target.files)
    this.updatePreview(files)
    this.validateFiles(files)
  }

  updatePreview(files) {
    if (!this.hasPreviewTarget) return

    const previewContainer = this.previewTarget
    previewContainer.innerHTML = ""

    if (files.length === 0) {
      this.updateCount(0)
      return
    }

    files.forEach((file, index) => {
      const fileItem = this.createFilePreview(file, index)
      previewContainer.appendChild(fileItem)
    })

    this.updateCount(files.length)
  }

  createFilePreview(file, index) {
    const fileItem = document.createElement("div")
    fileItem.className = "flex items-center justify-between p-2 bg-gray-50 rounded border"

    const fileInfo = document.createElement("div")
    fileInfo.className = "flex items-center space-x-2"

    const fileIcon = this.getFileIcon(file.type)
    const fileName = document.createElement("span")
    fileName.className = "text-sm text-gray-700 truncate max-w-xs"
    fileName.textContent = file.name

    const fileSize = document.createElement("span")
    fileSize.className = "text-xs text-gray-500"
    fileSize.textContent = this.formatFileSize(file.size)

    fileInfo.appendChild(fileIcon)
    fileInfo.appendChild(fileName)
    fileInfo.appendChild(fileSize)

    const removeButton = document.createElement("button")
    removeButton.type = "button"
    removeButton.className = "text-red-500 hover:text-red-700 p-1"
    removeButton.innerHTML = `
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
      </svg>
    `
    removeButton.addEventListener("click", () => this.removeFile(index))

    fileItem.appendChild(fileInfo)
    fileItem.appendChild(removeButton)

    return fileItem
  }

  getFileIcon(mimeType) {
    const icon = document.createElement("div")
    icon.className = "w-8 h-8 flex items-center justify-center rounded"

    if (mimeType.startsWith("image/")) {
      icon.className += " bg-green-100 text-green-600"
      icon.innerHTML = `
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
        </svg>
      `
    } else if (mimeType === "application/pdf") {
      icon.className += " bg-red-100 text-red-600"
      icon.innerHTML = `
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
        </svg>
      `
    } else {
      icon.className += " bg-blue-100 text-blue-600"
      icon.innerHTML = `
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
        </svg>
      `
    }

    return icon
  }

  removeFile(index) {
    const input = this.inputTarget
    const dt = new DataTransfer()
    const files = Array.from(input.files)

    files.forEach((file, i) => {
      if (i !== index) dt.items.add(file)
    })

    input.files = dt.files
    this.updatePreview(Array.from(dt.files))
  }

  validateFiles(files) {
    let hasErrors = false
    const errors = []

    if (files.length > this.maxFilesValue) {
      errors.push(`Maximum ${this.maxFilesValue} files allowed`)
      hasErrors = true
    }

    files.forEach(file => {
      if (file.size > this.maxSizeValue) {
        errors.push(`${file.name} is too large (max ${this.formatFileSize(this.maxSizeValue)})`)
        hasErrors = true
      }
    })

    this.displayValidationErrors(errors)
    return !hasErrors
  }

  displayValidationErrors(errors) {
    // Remove existing error messages
    this.element.querySelectorAll('.file-upload-error').forEach(el => el.remove())

    if (errors.length === 0) return

    const errorContainer = document.createElement("div")
    errorContainer.className = "file-upload-error mt-2 p-2 bg-red-50 border border-red-200 rounded text-red-700 text-sm"
    
    const errorList = document.createElement("ul")
    errorList.className = "list-disc list-inside"

    errors.forEach(error => {
      const errorItem = document.createElement("li")
      errorItem.textContent = error
      errorList.appendChild(errorItem)
    })

    errorContainer.appendChild(errorList)
    this.element.appendChild(errorContainer)
  }

  updateCount(count) {
    if (this.hasCountTarget) {
      this.countTarget.textContent = count === 0 ? "No files selected" : 
        count === 1 ? "1 file selected" : `${count} files selected`
    }
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
}