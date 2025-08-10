"use client"

import React, { useCallback, useState, useRef } from "react"
import { Upload, File, X, AlertCircle, CheckCircle2 } from "lucide-react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"

interface AccessibleFileUploadProps {
  onFilesChange?: (files: File[]) => void
  onUpload?: (files: File[]) => Promise<void>
  maxFiles?: number
  maxSize?: number
  acceptedFileTypes?: string[]
  disabled?: boolean
  className?: string
  multiple?: boolean
  id?: string
  'aria-label'?: string
  'aria-describedby'?: string
}

export function AccessibleFileUpload({
  onFilesChange,
  onUpload,
  maxFiles = 10,
  maxSize = 10 * 1024 * 1024, // 10MB
  acceptedFileTypes = ['image/*', 'application/pdf'],
  disabled = false,
  className,
  multiple = true,
  id,
  'aria-label': ariaLabel,
  'aria-describedby': ariaDescribedBy,
}: AccessibleFileUploadProps) {
  const [files, setFiles] = useState<File[]>([])
  const [isUploading, setIsUploading] = useState(false)
  const [dragActive, setDragActive] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const dropRef = useRef<HTMLDivElement>(null)

  const validateFile = useCallback((file: File): string | null => {
    if (file.size > maxSize) {
      return `File "${file.name}" is too large. Maximum size is ${Math.round(maxSize / 1024 / 1024)}MB.`
    }
    
    const isValidType = acceptedFileTypes.some(type => {
      if (type.includes('*')) {
        const baseType = type.split('/')[0]
        return file.type.startsWith(baseType + '/')
      }
      return file.type === type
    })
    
    if (!isValidType) {
      return `File "${file.name}" has an invalid type. Accepted types: ${acceptedFileTypes.join(', ')}`
    }
    
    return null
  }, [maxSize, acceptedFileTypes])

  const handleFiles = useCallback(
    (newFiles: FileList | File[]) => {
      const fileArray = Array.from(newFiles)
      const validFiles: File[] = []
      const errors: string[] = []

      fileArray.forEach(file => {
        const error = validateFile(file)
        if (error) {
          errors.push(error)
        } else {
          validFiles.push(file)
        }
      })

      if (errors.length > 0) {
        // Announce errors to screen readers
        const announcement = `${errors.length} file(s) rejected: ${errors.join(' ')}`
        const ariaLive = document.createElement('div')
        ariaLive.setAttribute('aria-live', 'polite')
        ariaLive.setAttribute('aria-atomic', 'true')
        ariaLive.className = 'sr-only'
        ariaLive.textContent = announcement
        document.body.appendChild(ariaLive)
        setTimeout(() => document.body.removeChild(ariaLive), 1000)
      }

      const totalFiles = [...files, ...validFiles]
      const finalFiles = multiple 
        ? totalFiles.slice(0, maxFiles)
        : validFiles.slice(0, 1)

      setFiles(finalFiles)
      onFilesChange?.(finalFiles)

      // Announce successful file addition
      if (validFiles.length > 0) {
        const announcement = `${validFiles.length} file(s) added successfully`
        const ariaLive = document.createElement('div')
        ariaLive.setAttribute('aria-live', 'polite')
        ariaLive.setAttribute('aria-atomic', 'true')
        ariaLive.className = 'sr-only'
        ariaLive.textContent = announcement
        document.body.appendChild(ariaLive)
        setTimeout(() => document.body.removeChild(ariaLive), 1000)
      }
    },
    [files, maxFiles, multiple, validateFile, onFilesChange]
  )

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true)
    } else if (e.type === 'dragleave') {
      setDragActive(false)
    }
  }, [])

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault()
      e.stopPropagation()
      setDragActive(false)

      if (disabled) return

      const droppedFiles = e.dataTransfer.files
      handleFiles(droppedFiles)
    },
    [disabled, handleFiles]
  )

  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (e.target.files) {
        handleFiles(e.target.files)
      }
    },
    [handleFiles]
  )

  const removeFile = useCallback(
    (index: number) => {
      const newFiles = files.filter((_, i) => i !== index)
      setFiles(newFiles)
      onFilesChange?.(newFiles)

      // Announce file removal
      const announcement = `File removed. ${newFiles.length} file(s) remaining`
      const ariaLive = document.createElement('div')
      ariaLive.setAttribute('aria-live', 'polite')
      ariaLive.setAttribute('aria-atomic', 'true')
      ariaLive.className = 'sr-only'
      ariaLive.textContent = announcement
      document.body.appendChild(ariaLive)
      setTimeout(() => document.body.removeChild(ariaLive), 1000)
    },
    [files, onFilesChange]
  )

  const handleUpload = useCallback(async () => {
    if (!onUpload || files.length === 0) return

    setIsUploading(true)
    setUploadProgress(0)

    try {
      // Simulate upload progress
      const interval = setInterval(() => {
        setUploadProgress(prev => {
          if (prev >= 90) {
            clearInterval(interval)
            return prev
          }
          return prev + 10
        })
      }, 200)

      await onUpload(files)
      setUploadProgress(100)

      // Announce successful upload
      const announcement = `Upload complete. ${files.length} file(s) uploaded successfully`
      const ariaLive = document.createElement('div')
      ariaLive.setAttribute('aria-live', 'polite')
      ariaLive.setAttribute('aria-atomic', 'true')
      ariaLive.className = 'sr-only'
      ariaLive.textContent = announcement
      document.body.appendChild(ariaLive)
      setTimeout(() => document.body.removeChild(ariaLive), 1000)
    } catch (error) {
      // Announce upload error
      const announcement = `Upload failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      const ariaLive = document.createElement('div')
      ariaLive.setAttribute('aria-live', 'assertive')
      ariaLive.setAttribute('aria-atomic', 'true')
      ariaLive.className = 'sr-only'
      ariaLive.textContent = announcement
      document.body.appendChild(ariaLive)
      setTimeout(() => document.body.removeChild(ariaLive), 1000)
    } finally {
      setIsUploading(false)
    }
  }, [files, onUpload])

  const acceptAttr = acceptedFileTypes.join(',')

  return (
    <div className={cn("w-full space-y-4", className)}>
      {/* File Input and Drop Zone */}
      <div
        ref={dropRef}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
        className={cn(
          "relative border-2 border-dashed rounded-lg p-8 text-center transition-colors",
          "focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/20",
          dragActive && "border-primary bg-primary/5",
          disabled && "cursor-not-allowed opacity-50"
        )}
      >
        <input
          ref={inputRef}
          id={id}
          type="file"
          multiple={multiple}
          accept={acceptAttr}
          onChange={handleInputChange}
          disabled={disabled}
          className="sr-only"
          aria-label={ariaLabel || "Choose files to upload"}
          aria-describedby={ariaDescribedBy}
        />

        <div className="space-y-4">
          <div className="flex justify-center">
            <Upload className="size-12 text-muted-foreground" />
          </div>
          
          <div className="space-y-2">
            <h3 className="text-lg font-medium">
              Drop files here or click to browse
            </h3>
            <p className="text-sm text-muted-foreground">
              {multiple ? `Up to ${maxFiles} files` : 'Single file'}, 
              maximum {Math.round(maxSize / 1024 / 1024)}MB each
            </p>
            <p className="text-xs text-muted-foreground">
              Accepted formats: {acceptedFileTypes.join(', ')}
            </p>
          </div>

          <Button
            type="button"
            variant="outline"
            onClick={() => inputRef.current?.click()}
            disabled={disabled}
          >
            Choose Files
          </Button>
        </div>
      </div>

      {/* File List */}
      {files.length > 0 && (
        <div className="space-y-4">
          <h4 className="font-medium">
            Selected Files ({files.length}/{maxFiles})
          </h4>

          <ul className="space-y-2" role="list">
            {files.map((file, index) => (
              <li
                key={`${file.name}-${file.size}-${index}`}
                className="flex items-center justify-between p-3 border rounded-lg"
              >
                <div className="flex items-center gap-3">
                  <File className="size-5 text-muted-foreground" />
                  <div>
                    <p className="font-medium">{file.name}</p>
                    <p className="text-sm text-muted-foreground">
                      {(file.size / 1024 / 1024).toFixed(1)} MB
                    </p>
                  </div>
                </div>

                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => removeFile(index)}
                  disabled={isUploading}
                  aria-label={`Remove ${file.name}`}
                >
                  <X className="size-4" />
                </Button>
              </li>
            ))}
          </ul>

          {/* Upload Progress */}
          {isUploading && (
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span>Upload Progress</span>
                <span>{uploadProgress}%</span>
              </div>
              <Progress 
                value={uploadProgress} 
                aria-label="Upload progress"
                aria-valuenow={uploadProgress}
                aria-valuemin={0}
                aria-valuemax={100}
              />
            </div>
          )}

          {/* Upload Button */}
          {onUpload && (
            <Button
              onClick={handleUpload}
              disabled={isUploading || files.length === 0}
              className="w-full"
            >
              {isUploading ? 'Uploading...' : `Upload ${files.length} file(s)`}
            </Button>
          )}
        </div>
      )}
    </div>
  )
}