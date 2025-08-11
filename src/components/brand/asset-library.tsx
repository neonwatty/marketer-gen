"use client"

import React, { useState, useEffect, useMemo } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { AssetPreview } from './asset-preview'
import { BrandAssetUpload } from '@/components/ui/brand-asset-upload'
import { 
  Search, 
  Filter, 
  Grid3X3, 
  List, 
  SortAsc, 
  SortDesc,
  Plus,
  Tag,
  Calendar,
  Download,
  Trash2,
  Edit,
  Upload,
  RefreshCw,
  FileImage,
  FileVideo,
  FileAudio,
  FileText,
  FolderOpen,
  MoreHorizontal,
  Settings
} from 'lucide-react'
import { BrandAsset, brandAssetManager, AssetFilterOptions } from '@/lib/brand-assets'
import { FileWithPreview } from '@/components/ui/file-upload'
import { cn } from '@/lib/utils'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'

interface AssetLibraryProps {
  brandId: string
  onAssetSelect?: (asset: BrandAsset) => void
  onAssetEdit?: (asset: BrandAsset) => void
  onAssetDelete?: (asset: BrandAsset) => void
  selectionMode?: boolean
  selectedAssets?: string[]
  onSelectionChange?: (assetIds: string[]) => void
  showUpload?: boolean
  className?: string
}

type ViewMode = 'grid' | 'list'
type SortBy = 'name' | 'date' | 'size' | 'type'
type SortOrder = 'asc' | 'desc'
type FilterType = 'all' | 'image' | 'video' | 'audio' | 'document'

const CATEGORIES = [
  { value: 'all', label: 'All Categories' },
  { value: 'logos', label: 'Logos' },
  { value: 'images', label: 'Images' },
  { value: 'documents', label: 'Documents' },
  { value: 'videos', label: 'Videos' },
  { value: 'audio', label: 'Audio' },
  { value: 'templates', label: 'Templates' },
  { value: 'guidelines', label: 'Guidelines' },
  { value: 'other', label: 'Other' }
]

const TYPE_FILTERS = [
  { value: 'all', label: 'All Types', icon: FolderOpen },
  { value: 'image', label: 'Images', icon: FileImage },
  { value: 'video', label: 'Videos', icon: FileVideo },
  { value: 'audio', label: 'Audio', icon: FileAudio },
  { value: 'document', label: 'Documents', icon: FileText }
]

export function AssetLibrary({
  brandId,
  onAssetSelect,
  onAssetEdit,
  onAssetDelete,
  selectionMode = false,
  selectedAssets = [],
  onSelectionChange,
  showUpload = true,
  className
}: AssetLibraryProps) {
  const [assets, setAssets] = useState<BrandAsset[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('all')
  const [selectedType, setSelectedType] = useState<FilterType>('all')
  const [selectedTags, setSelectedTags] = useState<string[]>([])
  const [sortBy, setSortBy] = useState<SortBy>('date')
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc')
  const [viewMode, setViewMode] = useState<ViewMode>('grid')
  const [showFilters, setShowFilters] = useState(false)
  const [uploadDialogOpen, setUploadDialogOpen] = useState(false)
  const [editingAsset, setEditingAsset] = useState<BrandAsset | null>(null)

  // Load assets
  const loadAssets = async () => {
    setIsLoading(true)
    try {
      const filters: AssetFilterOptions = {
        brandId,
        category: selectedCategory === 'all' ? undefined : selectedCategory,
        type: selectedType === 'all' ? undefined : selectedType,
        search: searchTerm || undefined
      }
      const loadedAssets = await brandAssetManager.getAssets(filters)
      setAssets(loadedAssets)
    } catch (error) {
      console.error('Failed to load assets:', error)
    } finally {
      setIsLoading(false)
    }
  }

  // Load assets on mount and when filters change
  useEffect(() => {
    loadAssets()
  }, [brandId, selectedCategory, selectedType, searchTerm])

  // Get unique tags from all assets
  const allTags = useMemo(() => {
    const tags = new Set<string>()
    assets.forEach(asset => {
      asset.tags.forEach(tag => tags.add(tag))
    })
    return Array.from(tags).sort()
  }, [assets])

  // Filter and sort assets
  const filteredAssets = useMemo(() => {
    let filtered = [...assets]

    // Filter by tags
    if (selectedTags.length > 0) {
      filtered = brandAssetManager.filterByTags(filtered, selectedTags)
    }

    // Sort assets
    filtered = brandAssetManager.sortAssets(filtered, sortBy)
    
    if (sortOrder === 'desc') {
      filtered.reverse()
    }

    return filtered
  }, [assets, selectedTags, sortBy, sortOrder])

  // Handle asset upload
  const handleUpload = async (files: FileWithPreview[]) => {
    try {
      await brandAssetManager.uploadAssets(files, {
        brandId,
        category: selectedCategory === 'all' ? 'general' : selectedCategory
      })
      await loadAssets()
      setUploadDialogOpen(false)
    } catch (error) {
      console.error('Upload failed:', error)
    }
  }

  // Handle asset selection
  const handleAssetToggle = (assetId: string) => {
    if (!selectionMode) return

    const newSelection = selectedAssets.includes(assetId)
      ? selectedAssets.filter(id => id !== assetId)
      : [...selectedAssets, assetId]
    
    onSelectionChange?.(newSelection)
  }

  // Handle asset edit
  const handleEdit = (asset: BrandAsset) => {
    setEditingAsset(asset)
    onAssetEdit?.(asset)
  }

  // Handle asset delete
  const handleDelete = async (asset: BrandAsset) => {
    try {
      await brandAssetManager.deleteAsset(asset.id, brandId)
      await loadAssets()
      onAssetDelete?.(asset)
    } catch (error) {
      console.error('Delete failed:', error)
    }
  }

  // Toggle tag selection
  const toggleTag = (tag: string) => {
    setSelectedTags(prev =>
      prev.includes(tag)
        ? prev.filter(t => t !== tag)
        : [...prev, tag]
    )
  }

  const clearFilters = () => {
    setSearchTerm('')
    setSelectedCategory('all')
    setSelectedType('all')
    setSelectedTags([])
  }

  const renderAssetGrid = () => (
    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-4">
      {filteredAssets.map((asset) => (
        <div key={asset.id} className="relative group">
          {selectionMode && (
            <div className="absolute top-2 left-2 z-10">
              <input
                type="checkbox"
                checked={selectedAssets.includes(asset.id)}
                onChange={() => handleAssetToggle(asset.id)}
                className="w-4 h-4 text-primary bg-white border-2 border-gray-300 rounded focus:ring-primary"
              />
            </div>
          )}
          <AssetPreview
            asset={asset}
            size="sm"
            onEdit={handleEdit}
            onDelete={() => handleDelete(asset)}
            showActions={!selectionMode}
          />
          {!selectionMode && onAssetSelect && (
            <Button
              variant="ghost"
              size="sm"
              className="absolute inset-0 opacity-0 group-hover:opacity-100 bg-black/20"
              onClick={() => onAssetSelect(asset)}
            >
              Select
            </Button>
          )}
        </div>
      ))}
    </div>
  )

  const renderAssetList = () => (
    <div className="space-y-2">
      {filteredAssets.map((asset) => (
        <Card key={asset.id} className="p-4">
          <div className="flex items-center gap-4">
            {selectionMode && (
              <input
                type="checkbox"
                checked={selectedAssets.includes(asset.id)}
                onChange={() => handleAssetToggle(asset.id)}
                className="w-4 h-4 text-primary bg-white border-2 border-gray-300 rounded"
              />
            )}
            
            {/* Thumbnail */}
            <div className="w-16 h-16 flex-shrink-0">
              <AssetPreview asset={asset} size="sm" showActions={false} />
            </div>
            
            {/* Asset Info */}
            <div className="flex-1 min-w-0">
              <div className="flex items-start justify-between">
                <div className="min-w-0 flex-1">
                  <h4 className="font-medium truncate">{asset.name}</h4>
                  <p className="text-sm text-muted-foreground">
                    {brandAssetManager.formatFileSize(asset.size)} • {asset.type}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {new Date(asset.uploadedAt).toLocaleDateString()}
                  </p>
                </div>
                
                <div className="flex items-center gap-2">
                  <Badge variant="secondary" className="text-xs">
                    {asset.category}
                  </Badge>
                  
                  {!selectionMode && (
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="sm">
                          <MoreHorizontal className="size-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent>
                        <DropdownMenuItem onClick={() => onAssetSelect?.(asset)}>
                          Select Asset
                        </DropdownMenuItem>
                        <DropdownMenuItem onClick={() => handleEdit(asset)}>
                          <Edit className="size-4 mr-2" />
                          Edit
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem 
                          onClick={() => handleDelete(asset)}
                          className="text-destructive"
                        >
                          <Trash2 className="size-4 mr-2" />
                          Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  )}
                </div>
              </div>
              
              {asset.tags.length > 0 && (
                <div className="flex flex-wrap gap-1 mt-2">
                  {asset.tags.slice(0, 3).map((tag) => (
                    <Badge key={tag} variant="outline" className="text-xs">
                      {tag}
                    </Badge>
                  ))}
                  {asset.tags.length > 3 && (
                    <Badge variant="outline" className="text-xs">
                      +{asset.tags.length - 3}
                    </Badge>
                  )}
                </div>
              )}
            </div>
          </div>
        </Card>
      ))}
    </div>
  )

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Asset Library</h2>
          <p className="text-muted-foreground">
            {filteredAssets.length} assets found
          </p>
        </div>
        <div className="flex items-center gap-2">
          {showUpload && (
            <Dialog open={uploadDialogOpen} onOpenChange={setUploadDialogOpen}>
              <DialogTrigger asChild>
                <Button>
                  <Upload className="size-4 mr-2" />
                  Upload Assets
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-2xl">
                <DialogHeader>
                  <DialogTitle>Upload Brand Assets</DialogTitle>
                  <DialogDescription>
                    Add new assets to your brand library
                  </DialogDescription>
                </DialogHeader>
                <BrandAssetUpload
                  onUpload={handleUpload}
                  cardWrapper={false}
                  title=""
                  description=""
                />
              </DialogContent>
            </Dialog>
          )}
          
          <Button
            variant="outline"
            size="sm"
            onClick={() => loadAssets()}
            disabled={isLoading}
          >
            <RefreshCw className={cn("size-4", isLoading && "animate-spin")} />
          </Button>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="space-y-4">
        {/* Search Bar */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 size-4 text-muted-foreground" />
          <Input
            placeholder="Search assets by name or tags..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>

        {/* Filter Controls */}
        <div className="flex items-center gap-4 flex-wrap">
          <Select value={selectedCategory} onValueChange={setSelectedCategory}>
            <SelectTrigger className="w-48">
              <SelectValue placeholder="Category" />
            </SelectTrigger>
            <SelectContent>
              {CATEGORIES.map((category) => (
                <SelectItem key={category.value} value={category.value}>
                  {category.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          <div className="flex items-center gap-2">
            {TYPE_FILTERS.map((filter) => (
              <Button
                key={filter.value}
                variant={selectedType === filter.value ? "default" : "outline"}
                size="sm"
                onClick={() => setSelectedType(filter.value as FilterType)}
                className="flex items-center gap-2"
              >
                <filter.icon className="size-4" />
                {filter.label}
              </Button>
            ))}
          </div>

          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowFilters(!showFilters)}
          >
            <Filter className="size-4 mr-2" />
            Filters
          </Button>

          {(searchTerm || selectedCategory !== 'all' || selectedType !== 'all' || selectedTags.length > 0) && (
            <Button variant="ghost" size="sm" onClick={clearFilters}>
              Clear Filters
            </Button>
          )}
        </div>

        {/* Advanced Filters */}
        {showFilters && (
          <Card>
            <CardContent className="pt-6">
              <div className="space-y-4">
                <div>
                  <Label className="text-sm font-medium mb-2 block">Tags</Label>
                  <div className="flex flex-wrap gap-2">
                    {allTags.map((tag) => (
                      <Button
                        key={tag}
                        variant={selectedTags.includes(tag) ? "default" : "outline"}
                        size="sm"
                        onClick={() => toggleTag(tag)}
                        className="text-xs"
                      >
                        <Tag className="size-3 mr-1" />
                        {tag}
                      </Button>
                    ))}
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        )}
      </div>

      {/* View Controls and Sort */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Button
            variant={viewMode === 'grid' ? "default" : "outline"}
            size="sm"
            onClick={() => setViewMode('grid')}
          >
            <Grid3X3 className="size-4" />
          </Button>
          <Button
            variant={viewMode === 'list' ? "default" : "outline"}
            size="sm"
            onClick={() => setViewMode('list')}
          >
            <List className="size-4" />
          </Button>
        </div>

        <div className="flex items-center gap-2">
          <Select value={sortBy} onValueChange={(value) => setSortBy(value as SortBy)}>
            <SelectTrigger className="w-32">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="name">Name</SelectItem>
              <SelectItem value="date">Date</SelectItem>
              <SelectItem value="size">Size</SelectItem>
              <SelectItem value="type">Type</SelectItem>
            </SelectContent>
          </Select>
          
          <Button
            variant="outline"
            size="sm"
            onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
          >
            {sortOrder === 'asc' ? <SortAsc className="size-4" /> : <SortDesc className="size-4" />}
          </Button>
        </div>
      </div>

      {/* Assets Display */}
      {isLoading ? (
        <div className="text-center py-12">
          <RefreshCw className="size-8 animate-spin mx-auto mb-4 text-muted-foreground" />
          <p className="text-muted-foreground">Loading assets...</p>
        </div>
      ) : filteredAssets.length === 0 ? (
        <div className="text-center py-12">
          <FolderOpen className="size-12 mx-auto mb-4 text-muted-foreground" />
          <p className="text-muted-foreground">No assets found</p>
          {showUpload && (
            <Button
              className="mt-4"
              onClick={() => setUploadDialogOpen(true)}
            >
              <Upload className="size-4 mr-2" />
              Upload Your First Asset
            </Button>
          )}
        </div>
      ) : viewMode === 'grid' ? (
        renderAssetGrid()
      ) : (
        renderAssetList()
      )}

      {/* Selection Summary */}
      {selectionMode && selectedAssets.length > 0 && (
        <div className="fixed bottom-4 right-4 bg-primary text-primary-foreground p-4 rounded-lg shadow-lg">
          <p className="text-sm">
            {selectedAssets.length} asset{selectedAssets.length > 1 ? 's' : ''} selected
          </p>
        </div>
      )}
    </div>
  )
}