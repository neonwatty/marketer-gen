"use client"

import React, { useCallback, useState } from "react"
import { useDropzone } from "react-dropzone"
import { 
  Upload, 
  File, 
  Image, 
  FileText, 
  X, 
  AlertCircle, 
  CheckCircle2,
  RotateCw
} from "lucide-react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"

// File type configurations
const ACCEPTED_FILE_TYPES = {
  'image/*': ['.jpeg', '.jpg', '.png', '.gif', '.webp', '.svg'],
  'application/pdf': ['.pdf'],
  'application/msword': ['.doc'],
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
  'text/plain': ['.txt'],
  'text/csv': ['.csv'],
}

const MAX_FILE_SIZE = 10 * 1024 * 1024 // 10MB
const MAX_FILES = 10

export interface FileWithPreview extends File {
  preview?: string | undefined
  uploadProgress?: number | undefined
  uploadStatus?: 'pending' | 'uploading' | 'success' | 'error' | undefined
  error?: string | undefined
  id: string
}

interface FileUploadProps {
  value?: FileWithPreview[]
  onFilesChange?: (files: FileWithPreview[]) => void
  onUpload?: (files: FileWithPreview[]) => Promise<void>
  maxFiles?: number
  maxSize?: number
  acceptedFileTypes?: Record<string, string[]>
  disabled?: boolean
  className?: string
  showPreview?: boolean
  multiple?: boolean
}

function getFileIcon(file: File) {
  if (file.type.startsWith('image/')) {
    return <Image className="size-8 text-blue-500" />
  } else if (file.type === 'application/pdf') {
    return <FileText className="size-8 text-red-500" />
  } else if (file.type.includes('word') || file.type.includes('document')) {
    return <FileText className="size-8 text-blue-600" />
  } else {
    return <File className="size-8 text-gray-500" />
  }
}

function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

export function FileUpload({
  value,
  onFilesChange,
  onUpload,
  maxFiles = MAX_FILES,
  maxSize = MAX_FILE_SIZE,
  acceptedFileTypes = ACCEPTED_FILE_TYPES,
  disabled = false,
  className,
  showPreview = true,
  multiple = true,
}: FileUploadProps) {
  const [internalFiles, setInternalFiles] = useState<FileWithPreview[]>([])
  const [isUploading, setIsUploading] = useState(false)
  
  // Use controlled value if provided, otherwise use internal state
  const files = value !== undefined ? value : internalFiles
  const setFiles = value !== undefined ? 
    (newFiles: FileWithPreview[]) => onFilesChange?.(newFiles) : 
    setInternalFiles

  const onDrop = useCallback(
    (acceptedFiles: File[], rejectedFiles: any[]) => {
      // Handle rejected files
      if (rejectedFiles.length > 0) {
        console.warn('Some files were rejected:', rejectedFiles)
      }

      // Process accepted files
      const newFiles: FileWithPreview[] = acceptedFiles.map(file => {
        const fileWithPreview: FileWithPreview = Object.assign(file, {
          preview: file.type.startsWith('image/') ? URL.createObjectURL(file) : undefined,
          uploadProgress: 0,
          uploadStatus: 'pending' as const,
          id: Math.random().toString(36).substring(7),
        })
        return fileWithPreview
      })

      const updatedFiles = multiple 
        ? [...files, ...newFiles].slice(0, maxFiles)
        : newFiles.slice(0, 1)

      if (value !== undefined) {
        onFilesChange?.(updatedFiles)
      } else {
        setInternalFiles(updatedFiles)
        onFilesChange?.(updatedFiles)
      }
    },
    [files, maxFiles, multiple, onFilesChange, value]
  )

  const { getRootProps, getInputProps, isDragActive, isDragReject } = useDropzone({
    onDrop,
    accept: acceptedFileTypes,
    maxSize,
    maxFiles: multiple ? maxFiles : 1,
    multiple,
    disabled: disabled || isUploading,
  })

  const removeFile = useCallback(
    (fileId: string) => {
      const updatedFiles = files.filter(file => file.id !== fileId)
      if (value !== undefined) {
        onFilesChange?.(updatedFiles)
      } else {
        setInternalFiles(updatedFiles)
        onFilesChange?.(updatedFiles)
      }
    },
    [files, onFilesChange, value]
  )

  const handleUpload = useCallback(async () => {
    if (!onUpload || files.length === 0) return

    setIsUploading(true)

    try {
      // Simulate upload progress for demo
      const uploadFiles = files.map(file => ({
        ...file,
        uploadStatus: 'uploading' as const,
      }))
      
      if (value !== undefined) {
        onFilesChange?.(uploadFiles)
      } else {
        setInternalFiles(uploadFiles)
      }

      // Simulate progress updates
      for (let progress = 0; progress <= 100; progress += 10) {
        await new Promise(resolve => setTimeout(resolve, 100))
        const progressFiles = files.map(file => ({
          ...file,
          uploadProgress: progress,
        }))
        if (value !== undefined) {
          onFilesChange?.(progressFiles)
        } else {
          setInternalFiles(progressFiles)
        }
      }

      // Mark as success
      const successFiles = files.map(file => ({
        ...file,
        uploadStatus: 'success' as const,
        uploadProgress: 100,
      }))
      
      if (value !== undefined) {
        onFilesChange?.(successFiles)
      } else {
        setInternalFiles(successFiles)
      }

      await onUpload(successFiles)
    } catch (error) {
      // Mark as error
      const errorFiles = files.map(file => ({
        ...file,
        uploadStatus: 'error' as const,
        error: error instanceof Error ? error.message : 'Upload failed',
      }))
      
      if (value !== undefined) {
        onFilesChange?.(errorFiles)
      } else {
        setInternalFiles(errorFiles)
      }
    } finally {
      setIsUploading(false)
    }
  }, [files, onUpload, value, onFilesChange])

  const clearAll = useCallback(() => {
    // Clean up object URLs to prevent memory leaks
    files.forEach(file => {
      if (file.preview) {
        URL.revokeObjectURL(file.preview)
      }
    })
    if (value !== undefined) {
      onFilesChange?.([])
    } else {
      setInternalFiles([])
      onFilesChange?.([])
    }
  }, [files, onFilesChange, value])

  // Clean up object URLs on unmount
  React.useEffect(() => {
    return () => {
      files.forEach(file => {
        if (file.preview) {
          URL.revokeObjectURL(file.preview)
        }
      })
    }
  }, [files])

  return (
    <div className={cn("w-full space-y-4", className)}>
      {/* Dropzone */}
      <div
        {...getRootProps()}
        className={cn(
          "relative border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors",
          "hover:border-primary/50 hover:bg-muted/25",
          isDragActive && "border-primary bg-primary/5",
          isDragReject && "border-destructive bg-destructive/5",
          disabled && "cursor-not-allowed opacity-50",
          files.length > 0 && "border-muted"
        )}
        role="button"
        aria-label="Upload files"
      >
        <input {...getInputProps()} />
        
        <div className="flex flex-col items-center gap-4">
          <div className="p-4 rounded-full bg-muted">
            <Upload className="size-8 text-muted-foreground" />
          </div>
          
          <div className="space-y-2">
            <h3 className="text-lg font-medium">
              {isDragActive
                ? "Drop files here"
                : "Drag & drop files here"
              }
            </h3>
            <p className="text-sm text-muted-foreground">
              or click to browse files
            </p>
            <p className="text-xs text-muted-foreground">
              Maximum {maxFiles} files, up to {formatFileSize(maxSize)} each
            </p>
          </div>
        </div>

        {isDragReject && (
          <div className="absolute inset-0 flex items-center justify-center bg-destructive/10 rounded-lg">
            <div className="flex items-center gap-2 text-destructive">
              <AlertCircle className="size-5" />
              <span>Some files cannot be uploaded</span>
            </div>
          </div>
        )}
      </div>

      {/* File List */}
      {files.length > 0 && showPreview && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h4 className="font-medium">
              Files ({files.length}/{maxFiles})
            </h4>
            <Button
              variant="outline"
              size="sm"
              onClick={clearAll}
              disabled={isUploading}
            >
              Clear All
            </Button>
          </div>

          <div className="space-y-2">
            {files.map((file) => (
              <div
                key={file.id}
                className="flex items-center gap-3 p-3 border rounded-lg bg-muted/25"
              >
                {/* File Icon/Preview */}
                <div className="flex-shrink-0">
                  {file.preview ? (
                    <img
                      src={file.preview}
                      alt={file.name}
                      className="size-12 object-cover rounded"
                      onLoad={() => URL.revokeObjectURL(file.preview!)}
                    />
                  ) : (
                    getFileIcon(file)
                  )}
                </div>

                {/* File Info */}
                <div className="flex-1 min-w-0 space-y-1">
                  <div className="flex items-center justify-between">
                    <h5 className="font-medium truncate">{file.name}</h5>
                    <span className="text-sm text-muted-foreground">
                      {formatFileSize(file.size)}
                    </span>
                  </div>

                  {/* Upload Progress */}
                  {file.uploadStatus === 'uploading' && (
                    <div className="space-y-1">
                      <Progress value={file.uploadProgress} className="h-1" />
                      <p className="text-xs text-muted-foreground">
                        Uploading... {file.uploadProgress}%
                      </p>
                    </div>
                  )}

                  {/* Status Messages */}
                  {file.uploadStatus === 'success' && (
                    <div className="flex items-center gap-1 text-green-600">
                      <CheckCircle2 className="size-3" />
                      <span className="text-xs">Upload complete</span>
                    </div>
                  )}

                  {file.uploadStatus === 'error' && (
                    <div className="flex items-center gap-1 text-destructive">
                      <AlertCircle className="size-3" />
                      <span className="text-xs">{file.error || 'Upload failed'}</span>
                    </div>
                  )}
                </div>

                {/* Remove Button */}
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => removeFile(file.id)}
                  disabled={isUploading}
                  className="flex-shrink-0"
                >
                  <X className="size-4" />
                </Button>
              </div>
            ))}
          </div>

          {/* Upload Button */}
          {onUpload && files.length > 0 && (
            <div className="flex justify-end">
              <Button
                onClick={handleUpload}
                disabled={isUploading || files.every(f => f.uploadStatus === 'success')}
                className="min-w-24"
              >
                {isUploading ? (
                  <>
                    <RotateCw className="size-4 animate-spin mr-2" />
                    Uploading...
                  </>
                ) : (
                  'Upload Files'
                )}
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  )
}