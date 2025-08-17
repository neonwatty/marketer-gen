"use client"

import * as React from "react"
import { useState } from "react"
import { BrandAssetLibrary } from "@/components/features/brand"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { BrandAsset, BrandAssetType } from "@/lib/types/brand"

// Mock brand asset data for demo
const mockAssets: BrandAsset[] = [
  {
    id: "asset_1",
    brandId: "brand_demo",
    name: "Primary Logo",
    description: "Main brand logo for use across all platforms",
    type: "LOGO" as BrandAssetType,
    category: "Primary Logo",
    fileUrl: "https://images.unsplash.com/photo-1611224923853-80b023f02d71?w=400&h=300&fit=crop",
    fileName: "primary-logo.svg",
    fileSize: 45320,
    mimeType: "image/svg+xml",
    metadata: {
      dimensions: "400x300",
      colorMode: "RGB",
      vectorFormat: true
    },
    tags: ["logo", "primary", "brand"],
    version: "v2.1",
    isActive: true,
    downloadCount: 127,
    lastUsed: new Date("2024-01-15T10:30:00Z"),
    createdAt: new Date("2024-01-01T09:00:00Z"),
    updatedAt: new Date("2024-01-15T10:30:00Z"),
    deletedAt: null,
    createdBy: "user_demo",
    updatedBy: "user_demo"
  },
  {
    id: "asset_2",
    brandId: "brand_demo",
    name: "Brand Colors Palette",
    description: "Complete color palette with primary and secondary colors",
    type: "COLOR_PALETTE" as BrandAssetType,
    category: "Primary Colors",
    fileUrl: "https://images.unsplash.com/photo-1541701494587-cb58502866ab?w=400&h=300&fit=crop",
    fileName: "brand-colors.pdf",
    fileSize: 892640,
    mimeType: "application/pdf",
    metadata: {
      pages: 3,
      colorCount: 12,
      format: "PDF"
    },
    tags: ["colors", "palette", "design"],
    version: "v1.0",
    isActive: true,
    downloadCount: 89,
    lastUsed: new Date("2024-01-14T15:20:00Z"),
    createdAt: new Date("2024-01-02T11:00:00Z"),
    updatedAt: new Date("2024-01-14T15:20:00Z"),
    deletedAt: null,
    createdBy: "user_demo",
    updatedBy: "user_demo"
  },
  {
    id: "asset_3",
    brandId: "brand_demo",
    name: "Brand Guidelines Document",
    description: "Comprehensive brand guidelines and usage instructions",
    type: "BRAND_GUIDELINES" as BrandAssetType,
    category: "Brand Book",
    fileUrl: "/demo/brand-guidelines.pdf",
    fileName: "brand-guidelines-2024.pdf",
    fileSize: 5628944,
    mimeType: "application/pdf",
    metadata: {
      pages: 24,
      lastRevision: "2024-01-10",
      format: "PDF"
    },
    tags: ["guidelines", "manual", "brand"],
    version: "v3.2",
    isActive: true,
    downloadCount: 234,
    lastUsed: new Date("2024-01-16T09:45:00Z"),
    createdAt: new Date("2023-12-15T14:00:00Z"),
    updatedAt: new Date("2024-01-16T09:45:00Z"),
    deletedAt: null,
    createdBy: "user_demo",
    updatedBy: "user_demo"
  },
  {
    id: "asset_4",
    brandId: "brand_demo",
    name: "Social Media Icons",
    description: "Icon set for social media platforms",
    type: "ICON" as BrandAssetType,
    category: "Social Icons",
    fileUrl: "https://images.unsplash.com/photo-1611224923853-80b023f02d71?w=200&h=200&fit=crop",
    fileName: "social-icons.zip",
    fileSize: 156780,
    mimeType: "application/zip",
    metadata: {
      iconCount: 16,
      formats: ["SVG", "PNG"],
      sizes: ["16x16", "32x32", "64x64"]
    },
    tags: ["icons", "social", "media"],
    version: "v1.2",
    isActive: true,
    downloadCount: 67,
    lastUsed: new Date("2024-01-12T13:15:00Z"),
    createdAt: new Date("2024-01-03T16:30:00Z"),
    updatedAt: new Date("2024-01-12T13:15:00Z"),
    deletedAt: null,
    createdBy: "user_demo",
    updatedBy: "user_demo"
  },
  {
    id: "asset_5",
    brandId: "brand_demo",
    name: "Typography Specimen",
    description: "Complete typography guide with font examples",
    type: "TYPOGRAPHY" as BrandAssetType,
    category: "Primary Fonts",
    fileUrl: "https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=400&h=300&fit=crop",
    fileName: "typography-guide.pdf",
    fileSize: 1245680,
    mimeType: "application/pdf",
    metadata: {
      fontFamilies: 3,
      weights: ["Regular", "Medium", "Bold"],
      format: "PDF"
    },
    tags: ["typography", "fonts", "specimen"],
    version: "v2.0",
    isActive: true,
    downloadCount: 145,
    lastUsed: new Date("2024-01-13T11:30:00Z"),
    createdAt: new Date("2024-01-01T12:00:00Z"),
    updatedAt: new Date("2024-01-13T11:30:00Z"),
    deletedAt: null,
    createdBy: "user_demo",
    updatedBy: "user_demo"
  },
  {
    id: "asset_6",
    brandId: "brand_demo",
    name: "Brand Video Intro",
    description: "Short brand introduction video for marketing",
    type: "VIDEO" as BrandAssetType,
    category: "Brand Videos",
    fileUrl: "/demo/brand-intro.mp4",
    fileName: "brand-intro-2024.mp4",
    fileSize: 45678912,
    mimeType: "video/mp4",
    metadata: {
      duration: "00:00:30",
      resolution: "1920x1080",
      framerate: "30fps"
    },
    tags: ["video", "intro", "marketing"],
    version: "v1.1",
    isActive: true,
    downloadCount: 56,
    lastUsed: new Date("2024-01-11T14:45:00Z"),
    createdAt: new Date("2024-01-05T10:15:00Z"),
    updatedAt: new Date("2024-01-11T14:45:00Z"),
    deletedAt: null,
    createdBy: "user_demo",
    updatedBy: "user_demo"
  }
]

export default function BrandAssetLibraryDemo() {
  const [selectedAssets, setSelectedAssets] = useState<BrandAsset[]>(mockAssets)

  const handleUpload = () => {
    console.log("Upload assets requested")
    // In a real app, this would open the file upload dialog
  }

  const handleEdit = (asset: BrandAsset) => {
    console.log("Edit asset:", asset.name)
    // In a real app, this would open the edit modal
  }

  const handleDelete = (assetId: string) => {
    console.log("Delete asset:", assetId)
    setSelectedAssets(prev => prev.filter(asset => asset.id !== assetId))
  }

  const handleDownload = (asset: BrandAsset) => {
    console.log("Download asset:", asset.name)
    // In a real app, this would trigger the download
  }

  const handlePreview = (asset: BrandAsset) => {
    console.log("Preview asset:", asset.name)
    // Preview is handled internally by the component
  }

  const assetStats = {
    total: selectedAssets.length,
    byType: selectedAssets.reduce((acc, asset) => {
      acc[asset.type] = (acc[asset.type] || 0) + 1
      return acc
    }, {} as Record<string, number>),
    totalDownloads: selectedAssets.reduce((sum, asset) => sum + asset.downloadCount, 0),
    totalSize: selectedAssets.reduce((sum, asset) => sum + (asset.fileSize || 0), 0)
  }

  const formatBytes = (bytes: number) => {
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    if (bytes === 0) return '0 Bytes'
    const i = Math.floor(Math.log(bytes) / Math.log(1024))
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i]
  }

  return (
    <div className="container mx-auto p-6 space-y-8">
      <div className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">Brand Asset Library Demo</h1>
        <p className="text-muted-foreground">
          Comprehensive brand asset management with search, filtering, and organization
        </p>
      </div>

      <Tabs defaultValue="library" className="space-y-6">
        <TabsList>
          <TabsTrigger value="library">Asset Library</TabsTrigger>
          <TabsTrigger value="stats">Statistics</TabsTrigger>
          <TabsTrigger value="features">Features</TabsTrigger>
        </TabsList>

        <TabsContent value="library" className="space-y-6">
          <BrandAssetLibrary
            brandId="brand_demo"
            assets={selectedAssets}
            onUpload={handleUpload}
            onEdit={handleEdit}
            onDelete={handleDelete}
            onDownload={handleDownload}
            onPreview={handlePreview}
            isLoading={false}
          />
        </TabsContent>

        <TabsContent value="stats" className="space-y-6">
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Assets</CardTitle>
                <Badge variant="secondary">{assetStats.total}</Badge>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{assetStats.total}</div>
                <p className="text-xs text-muted-foreground">
                  Across all asset types
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Downloads</CardTitle>
                <Badge variant="secondary">{assetStats.totalDownloads}</Badge>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{assetStats.totalDownloads}</div>
                <p className="text-xs text-muted-foreground">
                  Across all assets
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Size</CardTitle>
                <Badge variant="secondary">{formatBytes(assetStats.totalSize)}</Badge>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatBytes(assetStats.totalSize)}</div>
                <p className="text-xs text-muted-foreground">
                  Combined file size
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Asset Types</CardTitle>
                <Badge variant="secondary">{Object.keys(assetStats.byType).length}</Badge>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{Object.keys(assetStats.byType).length}</div>
                <p className="text-xs text-muted-foreground">
                  Different asset types
                </p>
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Assets by Type</CardTitle>
              <CardDescription>
                Distribution of assets across different types
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {Object.entries(assetStats.byType).map(([type, count]) => (
                  <div key={type} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Badge variant="outline">{type.replace('_', ' ')}</Badge>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="text-sm font-medium">{count} assets</div>
                      <div className="text-xs text-muted-foreground">
                        {Math.round((count / assetStats.total) * 100)}%
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="features" className="space-y-6">
          <div className="grid gap-6 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Key Features</CardTitle>
                <CardDescription>
                  Comprehensive asset management capabilities
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <h4 className="font-medium">🔍 Advanced Search & Filtering</h4>
                  <p className="text-sm text-muted-foreground">
                    Search by name, description, tags, or filename. Filter by asset type and custom categories.
                  </p>
                </div>
                <div className="space-y-2">
                  <h4 className="font-medium">📋 Multiple View Modes</h4>
                  <p className="text-sm text-muted-foreground">
                    Switch between grid and list views for optimal browsing experience.
                  </p>
                </div>
                <div className="space-y-2">
                  <h4 className="font-medium">🎯 Asset Preview</h4>
                  <p className="text-sm text-muted-foreground">
                    Quick preview with detailed metadata, usage stats, and version information.
                  </p>
                </div>
                <div className="space-y-2">
                  <h4 className="font-medium">📊 Usage Tracking</h4>
                  <p className="text-sm text-muted-foreground">
                    Track downloads, views, and last usage for better asset management.
                  </p>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Supported Asset Types</CardTitle>
                <CardDescription>
                  Organized by category for easy management
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid gap-3">
                  <div className="flex items-center gap-2">
                    <Badge className="bg-blue-100 text-blue-800">Logo</Badge>
                    <span className="text-sm">Primary & secondary logos</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge className="bg-purple-100 text-purple-800">Colors</Badge>
                    <span className="text-sm">Color palettes & schemes</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge className="bg-pink-100 text-pink-800">Typography</Badge>
                    <span className="text-sm">Font specimens & guides</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge className="bg-green-100 text-green-800">Guidelines</Badge>
                    <span className="text-sm">Brand guidelines & manuals</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge className="bg-cyan-100 text-cyan-800">Icons</Badge>
                    <span className="text-sm">Icon sets & symbols</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge className="bg-emerald-100 text-emerald-800">Media</Badge>
                    <span className="text-sm">Videos, audio & imagery</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Demo Actions</CardTitle>
              <CardDescription>
                Test the interactive features of the asset library
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <Button onClick={handleUpload} variant="default">
                  Test Upload Action
                </Button>
                <Button onClick={() => handleEdit(mockAssets[0])} variant="outline">
                  Test Edit Action
                </Button>
                <Button onClick={() => handleDownload(mockAssets[0])} variant="outline">
                  Test Download Action
                </Button>
                <Button 
                  onClick={() => setSelectedAssets(mockAssets.slice(0, 3))} 
                  variant="outline"
                >
                  Filter to 3 Assets
                </Button>
                <Button 
                  onClick={() => setSelectedAssets(mockAssets)} 
                  variant="outline"
                >
                  Reset All Assets
                </Button>
              </div>
              <p className="text-sm text-muted-foreground">
                These buttons demonstrate the component's callback functionality. 
                Check the browser console for action logs.
              </p>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}