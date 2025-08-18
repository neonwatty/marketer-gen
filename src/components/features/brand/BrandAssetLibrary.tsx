"use client"

import * as React from "react"
import { useState, useMemo } from "react"
import Image from "next/image"
import { Search, Filter, Grid, List, Download, Eye, MoreHorizontal, Plus, Tag, Calendar, FileType, SortAsc, SortDesc } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import { BrandAsset, BrandAssetType } from "@/lib/types/brand"

interface BrandAssetLibraryProps {
  brandId: string
  assets: BrandAsset[]
  onUpload?: () => void
  onEdit?: (asset: BrandAsset) => void
  onDelete?: (assetId: string) => void
  onDownload?: (asset: BrandAsset) => void
  onPreview?: (asset: BrandAsset) => void
  isLoading?: boolean
}

type ViewMode = "grid" | "list"
type SortField = "name" | "createdAt" | "type" | "fileSize"
type SortOrder = "asc" | "desc"

const ASSET_TYPE_LABELS: Record<BrandAssetType, string> = {
  LOGO: "Logo",
  BRAND_MARK: "Brand Mark",
  COLOR_PALETTE: "Color Palette",
  TYPOGRAPHY: "Typography",
  BRAND_GUIDELINES: "Brand Guidelines",
  IMAGERY: "Imagery",
  ICON: "Icon",
  PATTERN: "Pattern",
  TEMPLATE: "Template",
  DOCUMENT: "Document",
  VIDEO: "Video",
  AUDIO: "Audio",
  OTHER: "Other",
}

const ASSET_TYPE_COLORS: Record<BrandAssetType, string> = {
  LOGO: "bg-blue-100 text-blue-800",
  BRAND_MARK: "bg-indigo-100 text-indigo-800",
  COLOR_PALETTE: "bg-purple-100 text-purple-800",
  TYPOGRAPHY: "bg-pink-100 text-pink-800",
  BRAND_GUIDELINES: "bg-green-100 text-green-800",
  IMAGERY: "bg-yellow-100 text-yellow-800",
  ICON: "bg-cyan-100 text-cyan-800",
  PATTERN: "bg-orange-100 text-orange-800",
  TEMPLATE: "bg-red-100 text-red-800",
  DOCUMENT: "bg-gray-100 text-gray-800",
  VIDEO: "bg-emerald-100 text-emerald-800",
  AUDIO: "bg-violet-100 text-violet-800",
  OTHER: "bg-slate-100 text-slate-800",
}

export function BrandAssetLibrary({
  brandId,
  assets,
  onUpload,
  onEdit,
  onDelete,
  onDownload,
  onPreview,
  isLoading = false,
}: BrandAssetLibraryProps) {
  const [viewMode, setViewMode] = useState<ViewMode>("grid")
  const [searchQuery, setSearchQuery] = useState("")
  const [selectedType, setSelectedType] = useState<BrandAssetType | "all">("all")
  const [selectedCategory, setSelectedCategory] = useState<string>("all")
  const [sortField, setSortField] = useState<SortField>("createdAt")
  const [sortOrder, setSortOrder] = useState<SortOrder>("desc")
  const [selectedAsset, setSelectedAsset] = useState<BrandAsset | null>(null)

  // Get unique categories from assets
  const categories = useMemo(() => {
    const cats = new Set(assets.map(asset => asset.category).filter((cat): cat is string => Boolean(cat)))
    return Array.from(cats).sort()
  }, [assets])

  // Filter and sort assets
  const filteredAssets = useMemo(() => {
    let filtered = assets.filter(asset => {
      // Search filter
      if (searchQuery) {
        const query = searchQuery.toLowerCase()
        const matchesSearch = 
          asset.name.toLowerCase().includes(query) ||
          asset.description?.toLowerCase().includes(query) ||
          asset.fileName.toLowerCase().includes(query) ||
          (asset.tags && Array.isArray(asset.tags) && asset.tags.some(tag => typeof tag === 'string' && tag.toLowerCase().includes(query)))
        if (!matchesSearch) return false
      }

      // Type filter
      if (selectedType !== "all" && asset.type !== selectedType) {
        return false
      }

      // Category filter
      if (selectedCategory !== "all" && asset.category !== selectedCategory) {
        return false
      }

      return true
    })

    // Sort assets
    filtered.sort((a, b) => {
      let aValue: any
      let bValue: any

      switch (sortField) {
        case "name":
          aValue = a.name.toLowerCase()
          bValue = b.name.toLowerCase()
          break
        case "type":
          aValue = a.type
          bValue = b.type
          break
        case "fileSize":
          aValue = a.fileSize || 0
          bValue = b.fileSize || 0
          break
        case "createdAt":
        default:
          aValue = new Date(a.createdAt).getTime()
          bValue = new Date(b.createdAt).getTime()
          break
      }

      if (aValue < bValue) return sortOrder === "asc" ? -1 : 1
      if (aValue > bValue) return sortOrder === "asc" ? 1 : -1
      return 0
    })

    return filtered
  }, [assets, searchQuery, selectedType, selectedCategory, sortField, sortOrder])

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortOrder(sortOrder === "asc" ? "desc" : "asc")
    } else {
      setSortField(field)
      setSortOrder("asc")
    }
  }

  const formatFileSize = (bytes?: number) => {
    if (!bytes) return "Unknown"
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(1024))
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + " " + sizes[i]
  }

  const formatDate = (date: string | Date) => {
    return new Date(date).toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    })
  }

  const getAssetIcon = (asset: BrandAsset) => {
    if (asset.type === "VIDEO") return "🎥"
    if (asset.type === "AUDIO") return "🎵"
    if (asset.type === "LOGO" || asset.type === "BRAND_MARK") return "🏷️"
    if (asset.type === "COLOR_PALETTE") return "🎨"
    if (asset.type === "TYPOGRAPHY") return "📝"
    if (asset.type === "IMAGERY") return "🖼️"
    if (asset.type === "ICON") return "⭐"
    if (asset.type === "PATTERN") return "🔸"
    if (asset.type === "TEMPLATE") return "📋"
    if (asset.type === "BRAND_GUIDELINES") return "📚"
    return "📄"
  }

  if (isLoading) {
    return (
      <div className="space-y-4">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-4"></div>
          <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="h-48 bg-gray-200 rounded" data-testid="loading-skeleton"></div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Brand Asset Library</h2>
          <p className="text-muted-foreground">
            Manage and organize your brand assets
          </p>
        </div>
        {onUpload && (
          <Button onClick={onUpload} className="gap-2">
            <Plus className="h-4 w-4" />
            Upload Assets
          </Button>
        )}
      </div>

      {/* Filters and Controls */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            {/* Search */}
            <div className="relative flex-1 max-w-sm">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search assets..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9"
              />
            </div>

            <div className="flex items-center gap-2">
              {/* Type Filter */}
              <Select value={selectedType} onValueChange={(value) => setSelectedType(value as BrandAssetType | "all")}>
                <SelectTrigger className="w-40" aria-label="Filter by asset type">
                  <SelectValue placeholder="All Types" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Types</SelectItem>
                  {Object.entries(ASSET_TYPE_LABELS).map(([key, label]) => (
                    <SelectItem key={key} value={key}>
                      {label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              {/* Category Filter */}
              {categories.length > 0 && (
                <Select value={selectedCategory} onValueChange={setSelectedCategory}>
                  <SelectTrigger className="w-40" aria-label="Filter by category">
                    <SelectValue placeholder="All Categories" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Categories</SelectItem>
                    {categories.map((category) => (
                      <SelectItem key={category} value={category}>
                        {category}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}

              {/* View Mode Toggle */}
              <div className="flex border rounded-md">
                <Button
                  variant={viewMode === "grid" ? "default" : "ghost"}
                  size="sm"
                  onClick={() => setViewMode("grid")}
                  className="rounded-r-none"
                  aria-label="grid-view"
                  aria-pressed={viewMode === "grid"}
                  title="Grid View"
                >
                  <Grid className="h-4 w-4" />
                  <span className="sr-only">Grid View</span>
                </Button>
                <Button
                  variant={viewMode === "list" ? "default" : "ghost"}
                  size="sm"
                  onClick={() => setViewMode("list")}
                  className="rounded-l-none"
                  aria-label="list-view"
                  aria-pressed={viewMode === "list"}
                  title="List View"
                >
                  <List className="h-4 w-4" />
                  <span className="sr-only">List View</span>
                </Button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Results Summary */}
      <div className="flex items-center justify-between text-sm text-muted-foreground">
        <span>
          {filteredAssets.length} of {assets.length} assets
        </span>
        <div className="flex items-center gap-2">
          <span>Sort by:</span>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="sm" className="gap-1">
                {sortField === "name" && "Name"}
                {sortField === "createdAt" && "Date"}
                {sortField === "type" && "Type"}
                {sortField === "fileSize" && "Size"}
                {sortOrder === "asc" ? <SortAsc className="h-3 w-3" /> : <SortDesc className="h-3 w-3" />}
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={() => handleSort("name")}>Name</DropdownMenuItem>
              <DropdownMenuItem onClick={() => handleSort("createdAt")}>Date Created</DropdownMenuItem>
              <DropdownMenuItem onClick={() => handleSort("type")}>Type</DropdownMenuItem>
              <DropdownMenuItem onClick={() => handleSort("fileSize")}>File Size</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {/* Asset Display */}
      {filteredAssets.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-16">
            <div className="text-4xl mb-4">📁</div>
            <h3 className="text-lg font-medium mb-2">No assets found</h3>
            <p className="text-muted-foreground text-center max-w-sm">
              {searchQuery || selectedType !== "all" || selectedCategory !== "all"
                ? "Try adjusting your filters or search terms"
                : "Upload your first brand asset to get started"}
            </p>
            {onUpload && !searchQuery && selectedType === "all" && selectedCategory === "all" && (
              <Button onClick={onUpload} className="mt-4 gap-2">
                <Plus className="h-4 w-4" />
                Upload Assets
              </Button>
            )}
          </CardContent>
        </Card>
      ) : viewMode === "grid" ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {filteredAssets.map((asset) => (
            <AssetCard
              key={asset.id}
              asset={asset}
              onPreview={() => {
                setSelectedAsset(asset)
                onPreview?.(asset)
              }}
              onEdit={onEdit}
              onDelete={onDelete}
              onDownload={onDownload}
            />
          ))}
        </div>
      ) : (
        <AssetTable
          assets={filteredAssets}
          onPreview={(asset) => setSelectedAsset(asset)}
          onEdit={onEdit}
          onDelete={onDelete}
          onDownload={onDownload}
        />
      )}

      {/* Asset Preview Modal */}
      <AssetPreviewModal
        asset={selectedAsset}
        open={!!selectedAsset}
        onOpenChange={(open) => !open && setSelectedAsset(null)}
        onEdit={onEdit}
        onDelete={onDelete}
        onDownload={onDownload}
      />
    </div>
  )
}

// Asset Card Component for Grid View
function AssetCard({
  asset,
  onPreview,
  onEdit,
  onDelete,
  onDownload,
}: {
  asset: BrandAsset
  onPreview?: () => void
  onEdit?: (asset: BrandAsset) => void
  onDelete?: (assetId: string) => void
  onDownload?: (asset: BrandAsset) => void
}) {
  const formatFileSize = (bytes?: number) => {
    if (!bytes) return "Unknown"
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(1024))
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + " " + sizes[i]
  }

  return (
    <Card className="group hover:shadow-md transition-shadow" role="article">
      <CardContent className="p-4">
        <div className="space-y-3">
          {/* Preview Area */}
          <div 
            className="aspect-square bg-muted rounded-lg flex items-center justify-center cursor-pointer hover:bg-muted/80 transition-colors"
            onClick={onPreview}
            data-testid="asset-preview"
          >
            {asset.mimeType?.startsWith("image/") ? (
              <div className="relative w-full h-full">
                <Image
                  src={asset.fileUrl}
                  alt={asset.name}
                  fill
                  className="object-cover rounded-lg"
                />
              </div>
            ) : (
              <div className="text-4xl opacity-60">
                {asset.type === "VIDEO" && "🎥"}
                {asset.type === "AUDIO" && "🎵"}
                {asset.type === "DOCUMENT" && "📄"}
                {asset.type === "BRAND_GUIDELINES" && "📚"}
                {!["VIDEO", "AUDIO", "DOCUMENT", "BRAND_GUIDELINES"].includes(asset.type) && "📄"}
              </div>
            )}
          </div>

          {/* Asset Info */}
          <div className="space-y-2">
            <div className="flex items-start justify-between">
              <h3 className="font-medium text-sm leading-none truncate pr-2">{asset.name}</h3>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                    <MoreHorizontal className="h-3 w-3" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  {onPreview && (
                    <DropdownMenuItem onClick={onPreview}>
                      <Eye className="h-4 w-4 mr-2" />
                      Preview
                    </DropdownMenuItem>
                  )}
                  {onDownload && (
                    <DropdownMenuItem onClick={() => onDownload(asset)}>
                      <Download className="h-4 w-4 mr-2" />
                      Download
                    </DropdownMenuItem>
                  )}
                  {onEdit && (
                    <DropdownMenuItem onClick={() => onEdit(asset)}>
                      Edit
                    </DropdownMenuItem>
                  )}
                  {onDelete && (
                    <>
                      <DropdownMenuSeparator />
                      <DropdownMenuItem 
                        onClick={() => onDelete(asset.id)}
                        className="text-destructive"
                      >
                        Delete
                      </DropdownMenuItem>
                    </>
                  )}
                </DropdownMenuContent>
              </DropdownMenu>
            </div>

            <div className="flex flex-wrap gap-1">
              <Badge 
                variant="secondary" 
                className={`text-xs ${ASSET_TYPE_COLORS[asset.type]}`}
              >
                {ASSET_TYPE_LABELS[asset.type]}
              </Badge>
              {asset.category && (
                <Badge variant="outline" className="text-xs">
                  {asset.category}
                </Badge>
              )}
            </div>

            <div className="text-xs text-muted-foreground">
              <div>{formatFileSize(asset.fileSize ?? undefined)}</div>
              <div>{new Date(asset.createdAt).toLocaleDateString()}</div>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// Asset Table Component for List View  
function AssetTable({
  assets,
  onPreview,
  onEdit,
  onDelete,
  onDownload,
}: {
  assets: BrandAsset[]
  onPreview?: (asset: BrandAsset) => void
  onEdit?: (asset: BrandAsset) => void
  onDelete?: (assetId: string) => void
  onDownload?: (asset: BrandAsset) => void
}) {
  const formatFileSize = (bytes?: number) => {
    if (!bytes) return "Unknown"
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(1024))
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + " " + sizes[i]
  }

  return (
    <Card>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Type</TableHead>
            <TableHead>Category</TableHead>
            <TableHead>Size</TableHead>
            <TableHead>Modified</TableHead>
            <TableHead className="w-10"></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {assets.map((asset) => (
            <TableRow key={asset.id} className="cursor-pointer hover:bg-muted/50">
              <TableCell className="font-medium">
                <div className="flex items-center gap-3">
                  <div className="h-8 w-8 bg-muted rounded flex items-center justify-center text-sm">
                    {asset.mimeType?.startsWith("image/") ? (
                      <Image
                        src={asset.fileUrl}
                        alt={asset.name}
                        width={32}
                        height={32}
                        className="object-cover rounded"
                      />
                    ) : (
                      <span>
                        {asset.type === "VIDEO" && "🎥"}
                        {asset.type === "AUDIO" && "🎵"}
                        {asset.type === "DOCUMENT" && "📄"}
                        {asset.type === "BRAND_GUIDELINES" && "📚"}
                        {!["VIDEO", "AUDIO", "DOCUMENT", "BRAND_GUIDELINES"].includes(asset.type) && "📄"}
                      </span>
                    )}
                  </div>
                  <div>
                    <div className="font-medium">{asset.name}</div>
                    <div className="text-sm text-muted-foreground">{asset.fileName}</div>
                  </div>
                </div>
              </TableCell>
              <TableCell>
                <Badge 
                  variant="secondary" 
                  className={ASSET_TYPE_COLORS[asset.type]}
                >
                  {ASSET_TYPE_LABELS[asset.type]}
                </Badge>
              </TableCell>
              <TableCell>
                {asset.category ? (
                  <Badge variant="outline">{asset.category}</Badge>
                ) : (
                  <span className="text-muted-foreground">—</span>
                )}
              </TableCell>
              <TableCell>{formatFileSize(asset.fileSize ?? undefined)}</TableCell>
              <TableCell>{new Date(asset.createdAt).toLocaleDateString()}</TableCell>
              <TableCell>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                      <MoreHorizontal className="h-3 w-3" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    {onPreview && (
                      <DropdownMenuItem onClick={() => onPreview(asset)}>
                        <Eye className="h-4 w-4 mr-2" />
                        Preview
                      </DropdownMenuItem>
                    )}
                    {onDownload && (
                      <DropdownMenuItem onClick={() => onDownload(asset)}>
                        <Download className="h-4 w-4 mr-2" />
                        Download
                      </DropdownMenuItem>
                    )}
                    {onEdit && (
                      <DropdownMenuItem onClick={() => onEdit(asset)}>
                        Edit
                      </DropdownMenuItem>
                    )}
                    {onDelete && (
                      <>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem 
                          onClick={() => onDelete(asset.id)}
                          className="text-destructive"
                        >
                          Delete
                        </DropdownMenuItem>
                      </>
                    )}
                  </DropdownMenuContent>
                </DropdownMenu>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </Card>
  )
}

// Asset Preview Modal Component
function AssetPreviewModal({
  asset,
  open,
  onOpenChange,
  onEdit,
  onDelete,
  onDownload,
}: {
  asset: BrandAsset | null
  open: boolean
  onOpenChange: (open: boolean) => void
  onEdit?: (asset: BrandAsset) => void
  onDelete?: (assetId: string) => void
  onDownload?: (asset: BrandAsset) => void
}) {
  if (!asset) return null

  const formatFileSize = (bytes?: number) => {
    if (!bytes) return "Unknown"
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(1024))
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + " " + sizes[i]
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{asset.name}</DialogTitle>
          <DialogDescription>{asset.description}</DialogDescription>
        </DialogHeader>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Preview */}
          <div className="space-y-4">
            <div className="aspect-square bg-muted rounded-lg flex items-center justify-center overflow-hidden">
              {asset.mimeType?.startsWith("image/") ? (
                <Image
                  src={asset.fileUrl}
                  alt={asset.name}
                  width={400}
                  height={400}
                  className="object-contain max-w-full max-h-full"
                />
              ) : (
                <div className="text-6xl opacity-60">
                  {asset.type === "VIDEO" && "🎥"}
                  {asset.type === "AUDIO" && "🎵"}
                  {asset.type === "DOCUMENT" && "📄"}
                  {asset.type === "BRAND_GUIDELINES" && "📚"}
                  {!["VIDEO", "AUDIO", "DOCUMENT", "BRAND_GUIDELINES"].includes(asset.type) && "📄"}
                </div>
              )}
            </div>

            {/* Actions */}
            <div className="flex gap-2">
              {onDownload && (
                <Button onClick={() => onDownload(asset)} className="gap-2">
                  <Download className="h-4 w-4" />
                  Download
                </Button>
              )}
              {onEdit && (
                <Button variant="outline" onClick={() => onEdit(asset)}>
                  Edit
                </Button>
              )}
              {onDelete && (
                <Button 
                  variant="destructive" 
                  onClick={() => onDelete(asset.id)}
                >
                  Delete
                </Button>
              )}
            </div>
          </div>

          {/* Metadata */}
          <div className="space-y-6">
            <div>
              <h4 className="font-medium mb-3">Details</h4>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Type:</dt>
                  <dd>
                    <Badge className={ASSET_TYPE_COLORS[asset.type]}>
                      {ASSET_TYPE_LABELS[asset.type]}
                    </Badge>
                  </dd>
                </div>
                {asset.category && (
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Category:</dt>
                    <dd>{asset.category}</dd>
                  </div>
                )}
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">File name:</dt>
                  <dd className="font-mono text-xs">{asset.fileName}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">File size:</dt>
                  <dd>{formatFileSize(asset.fileSize ?? undefined)}</dd>
                </div>
                {asset.mimeType && (
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">MIME type:</dt>
                    <dd className="font-mono text-xs">{asset.mimeType}</dd>
                  </div>
                )}
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Created:</dt>
                  <dd>{new Date(asset.createdAt).toLocaleString()}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Modified:</dt>
                  <dd>{new Date(asset.updatedAt).toLocaleString()}</dd>
                </div>
                {asset.version && (
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Version:</dt>
                    <dd>{asset.version}</dd>
                  </div>
                )}
              </dl>
            </div>

            {/* Tags */}
            {asset.tags && Array.isArray(asset.tags) && asset.tags.length > 0 && (
              <div>
                <h4 className="font-medium mb-3">Tags</h4>
                <div className="flex flex-wrap gap-2">
                  {asset.tags.map((tag, index) => (
                    <Badge key={index} variant="outline" className="gap-1">
                      <Tag className="h-3 w-3" />
                      {String(tag)}
                    </Badge>
                  ))}
                </div>
              </div>
            )}

            {/* Usage Stats */}
            <div>
              <h4 className="font-medium mb-3">Usage</h4>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Downloads:</dt>
                  <dd>{asset.downloadCount || 0}</dd>
                </div>
                {asset.lastUsed && (
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Last used:</dt>
                    <dd>{new Date(asset.lastUsed).toLocaleString()}</dd>
                  </div>
                )}
              </dl>
            </div>

            {/* Metadata */}
            {asset.metadata && typeof asset.metadata === 'object' && Object.keys(asset.metadata).length > 0 && (
              <div>
                <h4 className="font-medium mb-3">Metadata</h4>
                <dl className="space-y-2 text-sm">
                  {Object.entries(asset.metadata).map(([key, value]) => (
                    <div key={key} className="flex justify-between">
                      <dt className="text-muted-foreground capitalize">{key.replace(/_/g, ' ')}:</dt>
                      <dd className="text-right">{String(value)}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}