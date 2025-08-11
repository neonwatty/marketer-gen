import { FileWithPreview } from '@/components/ui/file-upload'

export interface BrandAsset {
  id: string
  name: string
  originalName: string
  fileName: string
  type: 'image' | 'video' | 'audio' | 'document'
  mimeType: string
  size: number
  url: string
  category: string
  tags: string[]
  version: number
  uploadedAt: string
  updatedAt?: string
  metadata: {
    lastModified?: number
    width?: number | null
    height?: number | null
    duration?: number | null
    [key: string]: any
  }
}

export interface AssetUploadOptions {
  brandId: string
  category?: string
  tags?: string[]
}

export interface AssetFilterOptions {
  brandId: string
  category?: string
  type?: string
  search?: string
  tags?: string[]
}

export class BrandAssetManager {
  private baseUrl = '/api/brand-assets'

  async uploadAssets(files: FileWithPreview[], options: AssetUploadOptions): Promise<BrandAsset[]> {
    const formData = new FormData()

    files.forEach(file => {
      formData.append('files', file)
    })

    formData.append('brandId', options.brandId)
    
    if (options.category) {
      formData.append('category', options.category)
    }
    
    if (options.tags && options.tags.length > 0) {
      formData.append('tags', options.tags.join(', '))
    }

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      body: formData,
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to upload assets')
    }

    const result = await response.json()
    return result.assets
  }

  async getAssets(filters: AssetFilterOptions): Promise<BrandAsset[]> {
    const params = new URLSearchParams()
    params.append('brandId', filters.brandId)

    if (filters.category) {
      params.append('category', filters.category)
    }

    if (filters.type) {
      params.append('type', filters.type)
    }

    if (filters.search) {
      params.append('search', filters.search)
    }

    const response = await fetch(`${this.baseUrl}?${params}`)

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to fetch assets')
    }

    const result = await response.json()
    return result.assets
  }

  async getAsset(assetId: string, brandId: string): Promise<BrandAsset> {
    const params = new URLSearchParams({ brandId })
    const response = await fetch(`${this.baseUrl}/${assetId}?${params}`)

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to fetch asset')
    }

    const result = await response.json()
    return result.asset
  }

  async updateAsset(
    assetId: string, 
    updates: Partial<Pick<BrandAsset, 'name' | 'category' | 'tags' | 'metadata'>>,
    brandId: string
  ): Promise<BrandAsset> {
    const response = await fetch(`${this.baseUrl}/${assetId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        brandId,
        ...updates,
      }),
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to update asset')
    }

    const result = await response.json()
    return result.asset
  }

  async deleteAsset(assetId: string, brandId: string): Promise<void> {
    const params = new URLSearchParams({ brandId })
    const response = await fetch(`${this.baseUrl}/${assetId}?${params}`, {
      method: 'DELETE',
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to delete asset')
    }
  }

  async createVersion(assetId: string, brandId: string, file: File, changeNote: string): Promise<BrandAsset> {
    const asset = await this.getAsset(assetId, brandId)
    const formData = new FormData()
    formData.append('files', file)
    formData.append('brandId', brandId)
    formData.append('assetId', assetId)
    formData.append('changeNote', changeNote)
    formData.append('version', (asset.version + 1).toString())

    const response = await fetch('/api/brand-assets/version', {
      method: 'POST',
      body: formData,
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to create version')
    }

    const result = await response.json()
    return result.asset
  }

  async getVersionHistory(assetId: string, brandId: string): Promise<BrandAsset[]> {
    const params = new URLSearchParams({ brandId, assetId })
    const response = await fetch(`/api/brand-assets/versions?${params}`)

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to fetch version history')
    }

    const result = await response.json()
    return result.versions
  }

  async restoreVersion(assetId: string, versionId: string, brandId: string): Promise<BrandAsset> {
    const response = await fetch('/api/brand-assets/restore', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        assetId,
        versionId,
        brandId,
      }),
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to restore version')
    }

    const result = await response.json()
    return result.asset
  }

  // Utility methods
  static formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  static getAssetIcon(asset: BrandAsset): string {
    switch (asset.type) {
      case 'image':
        return '🖼️'
      case 'video':
        return '🎥'
      case 'audio':
        return '🎵'
      case 'document':
        return '📄'
      default:
        return '📎'
    }
  }

  static categorizeAssets(assets: BrandAsset[]): Record<string, BrandAsset[]> {
    return assets.reduce((acc, asset) => {
      const category = asset.category || 'uncategorized'
      if (!acc[category]) {
        acc[category] = []
      }
      acc[category].push(asset)
      return acc
    }, {} as Record<string, BrandAsset[]>)
  }

  static filterByTags(assets: BrandAsset[], tags: string[]): BrandAsset[] {
    if (tags.length === 0) return assets
    
    return assets.filter(asset =>
      tags.some(tag =>
        asset.tags.some(assetTag =>
          assetTag.toLowerCase().includes(tag.toLowerCase())
        )
      )
    )
  }

  static sortAssets(assets: BrandAsset[], sortBy: 'name' | 'date' | 'size' | 'type'): BrandAsset[] {
    return [...assets].sort((a, b) => {
      switch (sortBy) {
        case 'name':
          return a.name.localeCompare(b.name)
        case 'date':
          return new Date(b.uploadedAt).getTime() - new Date(a.uploadedAt).getTime()
        case 'size':
          return b.size - a.size
        case 'type':
          return a.type.localeCompare(b.type)
        default:
          return 0
      }
    })
  }
}

// Default instance for easy usage
export const brandAssetManager = new BrandAssetManager()