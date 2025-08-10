"use client"

import React from "react"
import { FileUpload, FileWithPreview } from "./file-upload"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "./card"

// Brand asset specific file types and sizes
const BRAND_ASSET_TYPES = {
  'image/*': ['.jpeg', '.jpg', '.png', '.gif', '.webp', '.svg'],
  'application/pdf': ['.pdf'],
  'video/mp4': ['.mp4'],
  'video/quicktime': ['.mov'],
}

const BRAND_ASSET_MAX_SIZE = 50 * 1024 * 1024 // 50MB for brand assets

interface BrandAssetUploadProps {
  onFilesChange?: (files: FileWithPreview[]) => void
  onUpload?: (files: FileWithPreview[]) => Promise<void>
  disabled?: boolean
  className?: string
  title?: string
  description?: string
  maxFiles?: number
  cardWrapper?: boolean
}

export function BrandAssetUpload({
  onFilesChange,
  onUpload,
  disabled = false,
  className,
  title = "Upload Brand Assets",
  description = "Upload logos, images, videos, and other brand materials for your marketing campaigns",
  maxFiles = 20,
  cardWrapper = true,
}: BrandAssetUploadProps) {
  const uploadContent = (
    <FileUpload
      {...(onFilesChange && { onFilesChange })}
      {...(onUpload && { onUpload })}
      maxFiles={maxFiles}
      maxSize={BRAND_ASSET_MAX_SIZE}
      acceptedFileTypes={BRAND_ASSET_TYPES}
      disabled={disabled}
      multiple={true}
      showPreview={true}
      {...(className && { className })}
    />
  )

  if (cardWrapper) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>{title}</CardTitle>
          <CardDescription>{description}</CardDescription>
        </CardHeader>
        <CardContent>
          {uploadContent}
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-4">
      <div className="space-y-2">
        <h3 className="text-lg font-semibold">{title}</h3>
        <p className="text-sm text-muted-foreground">{description}</p>
      </div>
      {uploadContent}
    </div>
  )
}