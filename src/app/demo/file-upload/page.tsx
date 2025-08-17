"use client"

import { useState } from "react"

import { FileText,Upload } from "lucide-react"

import { BrandDocumentUpload } from "@/components/features/brand"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { FileUpload, FileUploadFile } from "@/components/ui/file-upload"
import { Separator } from "@/components/ui/separator"

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

export default function FileUploadDemoPage() {
  const [brandDocuments, setBrandDocuments] = useState<BrandDocument[]>([])
  const [basicFiles, setBasicFiles] = useState<FileUploadFile[]>([])

  const handleUpload = async (files: File[]) => {
    // Simulate upload delay
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    // In a real app, you would upload to your server/cloud storage here
    // eslint-disable-next-line no-console
    console.log("Uploading files:", files)
  }

  return (
    <div className="container mx-auto py-8 space-y-8">
      <div className="space-y-2">
        <h1 className="text-3xl font-bold">File Upload System Demo</h1>
        <p className="text-muted-foreground">
          Demonstration of the multi-format file upload system with drag-and-drop support.
        </p>
      </div>

      <Separator />

      {/* Basic File Upload */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Upload className="h-5 w-5" />
            Basic File Upload
          </CardTitle>
          <CardDescription>
            Simple file upload component with drag-and-drop, validation, and preview capabilities.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <FileUpload
            value={basicFiles}
            onChange={setBasicFiles}
            onUpload={handleUpload}
            accept="image/*,application/pdf,.pdf,.docx,.doc"
            maxSize={10 * 1024 * 1024} // 10MB
            maxFiles={5}
          />
        </CardContent>
      </Card>

      <Separator />

      {/* Brand Document Upload System */}
      <div className="space-y-4">
        <div>
          <h2 className="text-2xl font-semibold mb-2">Brand Document Management System</h2>
          <p className="text-muted-foreground">
            Specialized file upload system for brand identity management with categorized document types,
            file organization, and preview capabilities.
          </p>
        </div>

        <BrandDocumentUpload
          documents={brandDocuments}
          onDocumentsChange={setBrandDocuments}
          maxFileSize={15 * 1024 * 1024} // 15MB for brand assets
          maxFiles={25}
        />
      </div>

      {/* Features Overview */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <FileText className="h-5 w-5" />
            Features Implemented
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            <div className="space-y-2">
              <h4 className="font-medium">File Upload Features</h4>
              <ul className="space-y-1 text-muted-foreground">
                <li>• Drag-and-drop support</li>
                <li>• Multiple file selection</li>
                <li>• File type validation</li>
                <li>• File size limits</li>
                <li>• Upload progress indicators</li>
                <li>• Error handling</li>
                <li>• File preview (images)</li>
                <li>• URL link support</li>
              </ul>
            </div>
            <div className="space-y-2">
              <h4 className="font-medium">Brand System Features</h4>
              <ul className="space-y-1 text-muted-foreground">
                <li>• Categorized document types</li>
                <li>• Document organization</li>
                <li>• Metadata management</li>
                <li>• File library view</li>
                <li>• Type-specific validation</li>
                <li>• Batch operations</li>
                <li>• Preview & download</li>
                <li>• Document descriptions</li>
              </ul>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Supported File Types */}
      <Card>
        <CardHeader>
          <CardTitle>Supported File Types</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <h4 className="font-medium text-green-700">Images</h4>
              <ul className="text-muted-foreground space-y-1">
                <li>PNG</li>
                <li>JPEG/JPG</li>
                <li>SVG</li>
              </ul>
            </div>
            <div>
              <h4 className="font-medium text-blue-700">Documents</h4>
              <ul className="text-muted-foreground space-y-1">
                <li>PDF</li>
                <li>DOCX</li>
                <li>DOC</li>
              </ul>
            </div>
            <div>
              <h4 className="font-medium text-purple-700">Links</h4>
              <ul className="text-muted-foreground space-y-1">
                <li>URL Links</li>
                <li>External References</li>
              </ul>
            </div>
            <div>
              <h4 className="font-medium text-orange-700">Validation</h4>
              <ul className="text-muted-foreground space-y-1">
                <li>File size limits</li>
                <li>Type checking</li>
                <li>Count limits</li>
              </ul>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}