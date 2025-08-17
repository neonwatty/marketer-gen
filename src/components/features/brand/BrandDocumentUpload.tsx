"use client"

import * as React from "react"
import Image from "next/image"

import { Download, Eye, FileText, Image as ImageIcon, Link, Upload } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { FileUpload, FileUploadFile,UrlFileUpload } from "@/components/ui/file-upload"
import { Separator } from "@/components/ui/separator"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

interface BrandDocument {
  id: string
  name: string
  type: "brand-guidelines" | "logo" | "color-palette" | "typography" | "imagery" | "other"
  files: FileUploadFile[]
  description?: string
  tags?: string[]
  createdAt: Date
  updatedAt: Date
}

interface BrandDocumentUploadProps {
  onDocumentsChange?: (documents: BrandDocument[]) => void
  documents?: BrandDocument[]
  maxFileSize?: number
  maxFiles?: number
  disabled?: boolean
}

const DOCUMENT_TYPES = [
  {
    id: "brand-guidelines" as const,
    label: "Brand Guidelines",
    description: "Complete brand guidelines and style guides",
    icon: FileText,
    acceptedTypes: "application/pdf,.pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document,.docx",
  },
  {
    id: "logo" as const,
    label: "Logos & Marks",
    description: "Logo files, brand marks, and variations",
    icon: ImageIcon,
    acceptedTypes: "image/png,.png,image/jpeg,.jpg,.jpeg,image/svg+xml,.svg",
  },
  {
    id: "color-palette" as const,
    label: "Color Palette",
    description: "Brand colors, swatches, and color guides",
    icon: ImageIcon,
    acceptedTypes: "image/png,.png,image/jpeg,.jpg,.jpeg,application/pdf,.pdf",
  },
  {
    id: "typography" as const,
    label: "Typography",
    description: "Font files and typography guidelines",
    icon: FileText,
    acceptedTypes: "application/pdf,.pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document,.docx",
  },
  {
    id: "imagery" as const,
    label: "Brand Imagery",
    description: "Stock photos, illustrations, and visual assets",
    icon: ImageIcon,
    acceptedTypes: "image/png,.png,image/jpeg,.jpg,.jpeg,image/svg+xml,.svg",
  },
  {
    id: "other" as const,
    label: "Other Documents",
    description: "Additional brand-related documents",
    icon: FileText,
    acceptedTypes: "application/pdf,.pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document,.docx,image/png,.png,image/jpeg,.jpg,.jpeg",
  },
] as const

export function BrandDocumentUpload({
  onDocumentsChange,
  documents = [],
  maxFileSize = 10 * 1024 * 1024, // 10MB
  maxFiles = 20,
  disabled = false,
}: BrandDocumentUploadProps) {
  const [selectedType, setSelectedType] = React.useState<typeof DOCUMENT_TYPES[number]["id"]>("brand-guidelines")
  const [currentFiles, setCurrentFiles] = React.useState<FileUploadFile[]>([])
  const [documentName, setDocumentName] = React.useState("")
  const [documentDescription, setDocumentDescription] = React.useState("")

  const selectedDocumentType = DOCUMENT_TYPES.find(type => type.id === selectedType)!

  const handleFilesChange = (files: FileUploadFile[]) => {
    setCurrentFiles(files)
  }

  const handleAddUrl = (url: string, name?: string) => {
    const urlFile: FileUploadFile = {
      id: Math.random().toString(36).substring(7),
      url,
      name: name || url.split("/").pop() || "URL Link",
      type: "url",
      status: "success",
    }
    setCurrentFiles(prev => [...prev, urlFile])
  }

  const handleSaveDocument = () => {
    if (currentFiles.length === 0) return

    const newDocument: BrandDocument = {
      id: Math.random().toString(36).substring(7),
      name: documentName || `${selectedDocumentType.label} Document`,
      type: selectedType,
      files: currentFiles,
      description: documentDescription || undefined,
      tags: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    }

    const updatedDocuments = [...documents, newDocument]
    onDocumentsChange?.(updatedDocuments)

    // Reset form
    setCurrentFiles([])
    setDocumentName("")
    setDocumentDescription("")
  }

  const handleDeleteDocument = (documentId: string) => {
    const updatedDocuments = documents.filter(doc => doc.id !== documentId)
    onDocumentsChange?.(updatedDocuments)
  }

  const getDocumentIcon = (type: BrandDocument["type"]) => {
    const docType = DOCUMENT_TYPES.find(t => t.id === type)
    return docType?.icon || FileText
  }

  const getFileTypeBadgeColor = (type: BrandDocument["type"]) => {
    switch (type) {
      case "brand-guidelines": return "bg-blue-100 text-blue-800"
      case "logo": return "bg-green-100 text-green-800"
      case "color-palette": return "bg-purple-100 text-purple-800"
      case "typography": return "bg-orange-100 text-orange-800"
      case "imagery": return "bg-pink-100 text-pink-800"
      default: return "bg-gray-100 text-gray-800"
    }
  }

  const totalFiles = documents.reduce((sum, doc) => sum + doc.files.length, 0)

  return (
    <div className="space-y-6">
      {/* Upload Section */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Upload className="h-5 w-5" />
            Upload Brand Documents
          </CardTitle>
          <CardDescription>
            Add brand guidelines, logos, color palettes, and other brand assets to build your brand identity system.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Tabs value={selectedType} onValueChange={(value) => setSelectedType(value as typeof DOCUMENT_TYPES[number]["id"])}>
            <TabsList className="grid w-full grid-cols-3 lg:grid-cols-6 mb-6">
              {DOCUMENT_TYPES.map((type) => {
                const Icon = type.icon
                return (
                  <TabsTrigger key={type.id} value={type.id} className="flex flex-col gap-1 h-auto py-2">
                    <Icon className="h-4 w-4" />
                    <span className="text-xs hidden sm:inline">{type.label.split(" ")[0]}</span>
                  </TabsTrigger>
                )
              })}
            </TabsList>

            {DOCUMENT_TYPES.map((type) => (
              <TabsContent key={type.id} value={type.id} className="space-y-4">
                <div className="text-center">
                  <h3 className="text-lg font-semibold">{type.label}</h3>
                  <p className="text-sm text-muted-foreground">{type.description}</p>
                </div>

                <div className="space-y-4">
                  <div className="space-y-2">
                    <label className="text-sm font-medium">Document Name (Optional)</label>
                    <input
                      type="text"
                      placeholder={`Enter name for ${type.label.toLowerCase()}...`}
                      value={documentName}
                      onChange={(e) => setDocumentName(e.target.value)}
                      disabled={disabled}
                      className="w-full px-3 py-2 border rounded-md text-sm"
                    />
                  </div>

                  <div className="space-y-2">
                    <label className="text-sm font-medium">Description (Optional)</label>
                    <textarea
                      placeholder="Add a description for this document..."
                      value={documentDescription}
                      onChange={(e) => setDocumentDescription(e.target.value)}
                      disabled={disabled}
                      rows={2}
                      className="w-full px-3 py-2 border rounded-md text-sm resize-none"
                    />
                  </div>

                  <FileUpload
                    value={currentFiles}
                    onChange={handleFilesChange}
                    accept={type.acceptedTypes}
                    maxSize={maxFileSize}
                    maxFiles={maxFiles}
                    disabled={disabled}
                  >
                    Drop {type.label.toLowerCase()} here or click to browse
                  </FileUpload>

                  <Separator />

                  <UrlFileUpload
                    onAdd={handleAddUrl}
                    disabled={disabled}
                  />

                  {currentFiles.length > 0 && (
                    <div className="flex justify-end">
                      <Button onClick={handleSaveDocument} disabled={disabled}>
                        Save {type.label}
                      </Button>
                    </div>
                  )}
                </div>
              </TabsContent>
            ))}
          </Tabs>
        </CardContent>
      </Card>

      {/* Document Library */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            <span className="flex items-center gap-2">
              <FileText className="h-5 w-5" />
              Brand Document Library
            </span>
            <Badge variant="secondary">
              {documents.length} document{documents.length !== 1 ? 's' : ''} · {totalFiles} file{totalFiles !== 1 ? 's' : ''}
            </Badge>
          </CardTitle>
          <CardDescription>
            Manage your uploaded brand documents and assets.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {documents.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <FileText className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>No brand documents uploaded yet.</p>
              <p className="text-sm">Start by uploading your brand guidelines or logos above.</p>
            </div>
          ) : (
            <div className="space-y-4">
              {documents.map((document) => {
                const Icon = getDocumentIcon(document.type)
                const typeInfo = DOCUMENT_TYPES.find(t => t.id === document.type)!
                
                return (
                  <div key={document.id} className="border rounded-lg p-4 space-y-3">
                    <div className="flex items-start justify-between">
                      <div className="flex items-start gap-3">
                        <div className="mt-1">
                          <Icon className="h-5 w-5 text-muted-foreground" />
                        </div>
                        <div className="space-y-1">
                          <h4 className="font-medium">{document.name}</h4>
                          <div className="flex items-center gap-2">
                            <Badge
                              variant="secondary"
                              className={getFileTypeBadgeColor(document.type)}
                            >
                              {typeInfo.label}
                            </Badge>
                            <span className="text-xs text-muted-foreground">
                              {document.files.length} file{document.files.length !== 1 ? 's' : ''}
                            </span>
                          </div>
                          {document.description && (
                            <p className="text-sm text-muted-foreground">{document.description}</p>
                          )}
                        </div>
                      </div>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleDeleteDocument(document.id)}
                        disabled={disabled}
                      >
                        Delete
                      </Button>
                    </div>

                    {/* File List */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
                      {document.files.map((file) => (
                        <div key={file.id} className="flex items-center gap-2 p-2 bg-muted/50 rounded">
                          {file.preview ? (
                            <Image
                              src={file.preview}
                              alt={file.name}
                              width={32}
                              height={32}
                              className="h-8 w-8 object-cover rounded"
                            />
                          ) : (
                            <div className="h-8 w-8 bg-muted rounded flex items-center justify-center">
                              {file.type === "url" ? <Link className="h-4 w-4" /> : <FileText className="h-4 w-4" />}
                            </div>
                          )}
                          <div className="flex-1 min-w-0">
                            <p className="text-xs font-medium truncate">{file.name}</p>
                            {file.size && (
                              <p className="text-xs text-muted-foreground">
                                {Math.round(file.size / 1024)} KB
                              </p>
                            )}
                          </div>
                          <div className="flex gap-1">
                            {file.url && (
                              <Button variant="ghost" size="sm" asChild>
                                <a href={file.url} target="_blank" rel="noopener noreferrer">
                                  <Eye className="h-3 w-3" />
                                </a>
                              </Button>
                            )}
                            <Button variant="ghost" size="sm">
                              <Download className="h-3 w-3" />
                            </Button>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}