"use client"

import * as React from "react"
import Image from "next/image"

import { AlertCircle,File, FileImage, FileText, Link, Upload, X } from "lucide-react"

import { Alert, AlertDescription } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { cn } from "@/lib/utils"

export interface FileUploadFile {
  id: string
  file?: File
  url?: string
  name: string
  size?: number
  type: string
  preview?: string
  status: "pending" | "uploading" | "success" | "error"
  progress?: number
  error?: string
}

interface FileUploadProps {
  value?: FileUploadFile[]
  onChange?: (files: FileUploadFile[]) => void
  onUpload?: (files: File[]) => Promise<void>
  accept?: string
  multiple?: boolean
  maxSize?: number // in bytes
  maxFiles?: number
  disabled?: boolean
  className?: string
  children?: React.ReactNode
}

const ACCEPTED_FILE_TYPES = {
  "image/jpeg": [".jpg", ".jpeg"],
  "image/png": [".png"],
  "image/svg+xml": [".svg"],
  "application/pdf": [".pdf"],
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document": [".docx"],
  "application/msword": [".doc"],
}

const DEFAULT_MAX_SIZE = 10 * 1024 * 1024 // 10MB

export function FileUpload({
  value = [],
  onChange,
  onUpload,
  accept = Object.keys(ACCEPTED_FILE_TYPES).join(","),
  multiple = true,
  maxSize = DEFAULT_MAX_SIZE,
  maxFiles = 10,
  disabled = false,
  className,
  children,
}: FileUploadProps) {
  const [isDragOver, setIsDragOver] = React.useState(false)
  const [uploadProgress, setUploadProgress] = React.useState<Record<string, number>>({})
  const [errors, setErrors] = React.useState<string[]>([])
  const fileInputRef = React.useRef<HTMLInputElement>(null)

  const validateFile = (file: File): string | null => {
    // Check file size
    if (file.size > maxSize) {
      return `File "${file.name}" is too large. Maximum size is ${Math.round(maxSize / 1024 / 1024)}MB`
    }

    // Check file type
    const acceptedTypes = accept.split(",").map(type => type.trim())
    if (!acceptedTypes.includes(file.type) && !acceptedTypes.includes("*")) {
      return `File type "${file.type}" is not supported`
    }

    return null
  }

  const createFileUploadFile = (file: File): FileUploadFile => {
    const id = Math.random().toString(36).substring(7)
    return {
      id,
      file,
      name: file.name,
      size: file.size,
      type: file.type,
      status: "pending",
      preview: file.type.startsWith("image/") ? URL.createObjectURL(file) : undefined,
    }
  }

  const handleFiles = async (files: File[]) => {
    if (disabled) return

    const newErrors: string[] = []
    const validFiles: File[] = []

    // Validate each file
    for (const file of files) {
      const error = validateFile(file)
      if (error) {
        newErrors.push(error)
      } else {
        validFiles.push(file)
      }
    }

    // Check total file count
    if (value.length + validFiles.length > maxFiles) {
      newErrors.push(`Cannot upload more than ${maxFiles} files`)
      setErrors(newErrors)
      return
    }

    setErrors(newErrors)

    if (validFiles.length === 0) return

    const newFileUploadFiles = validFiles.map(createFileUploadFile)
    const updatedFiles = [...value, ...newFileUploadFiles]
    onChange?.(updatedFiles)

    // Start upload if onUpload is provided
    if (onUpload) {
      try {
        // Update status to uploading
        const uploadingFiles = updatedFiles.map(f => 
          newFileUploadFiles.find(nf => nf.id === f.id) 
            ? { ...f, status: "uploading" as const, progress: 0 }
            : f
        )
        onChange?.(uploadingFiles)

        // Simulate upload progress (replace with actual upload logic)
        for (const fileUploadFile of newFileUploadFiles) {
          for (let i = 0; i <= 100; i += 10) {
            setUploadProgress(prev => ({ ...prev, [fileUploadFile.id]: i }))
            await new Promise(resolve => setTimeout(resolve, 100))
          }
        }

        await onUpload(validFiles)

        // Update status to success
        const successFiles = updatedFiles.map(f => 
          newFileUploadFiles.find(nf => nf.id === f.id) 
            ? { ...f, status: "success" as const, progress: 100 }
            : f
        )
        onChange?.(successFiles)
      } catch (error) {
        // Update status to error
        const errorFiles = updatedFiles.map(f => 
          newFileUploadFiles.find(nf => nf.id === f.id) 
            ? { ...f, status: "error" as const, error: error instanceof Error ? error.message : "Upload failed" }
            : f
        )
        onChange?.(errorFiles)
      }
    }
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    if (!disabled) {
      setIsDragOver(true)
    }
  }

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragOver(false)
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragOver(false)
    
    if (disabled) return

    const files = Array.from(e.dataTransfer.files)
    handleFiles(files)
  }

  const handleFileInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || [])
    handleFiles(files)
    
    // Reset input value to allow selecting the same file again
    if (fileInputRef.current) {
      fileInputRef.current.value = ""
    }
  }

  const removeFile = (id: string) => {
    const updatedFiles = value.filter(f => f.id !== id)
    onChange?.(updatedFiles)
  }

  const handleAddUrlFile = (url: string, name?: string) => {
    if (disabled) return

    const fileUploadFile: FileUploadFile = {
      id: Math.random().toString(36).substring(7),
      url,
      name: name || url.split("/").pop() || "URL Link",
      type: "url",
      status: "success",
    }

    onChange?.([...value, fileUploadFile])
  }

  const getFileIcon = (type: string) => {
    if (type.startsWith("image/")) return <FileImage className="h-4 w-4" />
    if (type === "application/pdf") return <FileText className="h-4 w-4" />
    if (type === "url") return <Link className="h-4 w-4" />
    return <File className="h-4 w-4" />
  }

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }

  return (
    <div className={cn("space-y-4", className)}>
      {/* Error Messages */}
      {errors.length > 0 && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            <ul className="list-disc list-inside space-y-1">
              {errors.map((error, index) => (
                <li key={index}>{error}</li>
              ))}
            </ul>
          </AlertDescription>
        </Alert>
      )}

      {/* Drop Zone */}
      <div
        className={cn(
          "relative border-2 border-dashed rounded-lg p-6 transition-colors",
          isDragOver
            ? "border-primary bg-primary/5"
            : "border-muted-foreground/25 hover:border-muted-foreground/50",
          disabled && "opacity-50 cursor-not-allowed"
        )}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
      >
        <input
          ref={fileInputRef}
          type="file"
          accept={accept}
          multiple={multiple}
          onChange={handleFileInput}
          disabled={disabled}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer disabled:cursor-not-allowed"
        />
        
        <div className="flex flex-col items-center justify-center text-center">
          <Upload className="h-10 w-10 text-muted-foreground mb-4" />
          <div className="space-y-2">
            <p className="text-sm font-medium">
              {children || "Drop files here or click to browse"}
            </p>
            <p className="text-xs text-muted-foreground">
              Supports PDF, DOCX, PNG, JPG, SVG up to {Math.round(maxSize / 1024 / 1024)}MB
            </p>
          </div>
        </div>
      </div>

      {/* File List */}
      {value.length > 0 && (
        <div className="space-y-2">
          <h4 className="text-sm font-medium">Uploaded Files ({value.length})</h4>
          <div className="space-y-2">
            {value.map((fileUpload) => (
              <div
                key={fileUpload.id}
                className="flex items-center justify-between p-3 border rounded-lg bg-muted/50"
              >
                <div className="flex items-center space-x-3 flex-1 min-w-0">
                  {fileUpload.preview ? (
                    <Image
                      src={fileUpload.preview}
                      alt={fileUpload.name}
                      width={40}
                      height={40}
                      className="h-10 w-10 object-cover rounded"
                    />
                  ) : (
                    <div className="h-10 w-10 bg-muted rounded flex items-center justify-center">
                      {getFileIcon(fileUpload.type)}
                    </div>
                  )}
                  
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{fileUpload.name}</p>
                    <div className="flex items-center space-x-2 text-xs text-muted-foreground">
                      {fileUpload.size && <span>{formatFileSize(fileUpload.size)}</span>}
                      <span className={cn(
                        "px-1.5 py-0.5 rounded-full text-xs font-medium",
                        fileUpload.status === "success" && "bg-green-100 text-green-800",
                        fileUpload.status === "error" && "bg-red-100 text-red-800",
                        fileUpload.status === "uploading" && "bg-blue-100 text-blue-800",
                        fileUpload.status === "pending" && "bg-gray-100 text-gray-800"
                      )}>
                        {fileUpload.status}
                      </span>
                    </div>
                    
                    {fileUpload.status === "uploading" && (
                      <Progress
                        value={uploadProgress[fileUpload.id] || fileUpload.progress || 0}
                        className="mt-2 h-1"
                      />
                    )}
                    
                    {fileUpload.error && (
                      <p className="text-xs text-red-600 mt-1">{fileUpload.error}</p>
                    )}
                  </div>
                </div>
                
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => removeFile(fileUpload.id)}
                  disabled={disabled}
                  className="ml-2"
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

// URL File Upload Component
interface UrlFileUploadProps {
  onAdd: (url: string, name?: string) => void
  disabled?: boolean
}

export function UrlFileUpload({ onAdd, disabled }: UrlFileUploadProps) {
  const [url, setUrl] = React.useState("")
  const [name, setName] = React.useState("")

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (url.trim()) {
      onAdd(url.trim(), name.trim() || undefined)
      setUrl("")
      setName("")
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-3 p-4 border rounded-lg">
      <h4 className="text-sm font-medium">Add URL Link</h4>
      <div className="space-y-2">
        <input
          type="url"
          placeholder="Enter URL..."
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          disabled={disabled}
          className="w-full px-3 py-2 border rounded-md text-sm"
          required
        />
        <input
          type="text"
          placeholder="Display name (optional)"
          value={name}
          onChange={(e) => setName(e.target.value)}
          disabled={disabled}
          className="w-full px-3 py-2 border rounded-md text-sm"
        />
      </div>
      <Button type="submit" disabled={disabled || !url.trim()} size="sm">
        Add URL
      </Button>
    </form>
  )
}