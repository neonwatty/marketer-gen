import { 
  BrandWithRelations, 
  BrandSummary, 
  CreateBrandData, 
  UpdateBrandData,
  CreateBrandAssetData,
  UpdateBrandAssetData,
  BrandAsset 
} from "@/lib/types/brand"

const API_BASE = "/api/brands"

// Brand API service
export class BrandService {
  // Get all brands with optional filtering
  static async getBrands(params?: {
    page?: number
    limit?: number
    search?: string
    industry?: string
  }): Promise<{
    brands: BrandSummary[]
    pagination: {
      page: number
      limit: number
      total: number
      pages: number
    }
  }> {
    const url = new URL(API_BASE, window.location.origin)
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined) {
          url.searchParams.set(key, value.toString())
        }
      })
    }

    const response = await fetch(url.toString())
    
    if (!response.ok) {
      throw new Error(`Failed to fetch brands: ${response.statusText}`)
    }

    return response.json()
  }

  // Get a specific brand by ID
  static async getBrand(id: string): Promise<BrandWithRelations> {
    const response = await fetch(`${API_BASE}/${id}`)
    
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error("Brand not found")
      }
      throw new Error(`Failed to fetch brand: ${response.statusText}`)
    }

    return response.json()
  }

  // Create a new brand
  static async createBrand(data: CreateBrandData): Promise<BrandWithRelations> {
    const response = await fetch(API_BASE, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to create brand: ${response.statusText}`)
    }

    return response.json()
  }

  // Update an existing brand
  static async updateBrand(id: string, data: UpdateBrandData): Promise<BrandWithRelations> {
    const response = await fetch(`${API_BASE}/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to update brand: ${response.statusText}`)
    }

    return response.json()
  }

  // Delete a brand
  static async deleteBrand(id: string): Promise<void> {
    const response = await fetch(`${API_BASE}/${id}`, {
      method: "DELETE",
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to delete brand: ${response.statusText}`)
    }
  }

  // Get brand assets
  static async getBrandAssets(
    brandId: string,
    params?: {
      type?: string
      category?: string
      search?: string
    }
  ): Promise<{ assets: BrandAsset[] }> {
    const url = new URL(`${API_BASE}/${brandId}/assets`, window.location.origin)
    
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined) {
          url.searchParams.set(key, value.toString())
        }
      })
    }

    const response = await fetch(url.toString())
    
    if (!response.ok) {
      throw new Error(`Failed to fetch brand assets: ${response.statusText}`)
    }

    return response.json()
  }

  // Create brand asset
  static async createBrandAsset(
    brandId: string, 
    data: CreateBrandAssetData
  ): Promise<BrandAsset> {
    const response = await fetch(`${API_BASE}/${brandId}/assets`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to create brand asset: ${response.statusText}`)
    }

    return response.json()
  }

  // Update brand asset
  static async updateBrandAsset(
    brandId: string,
    assetId: string,
    data: UpdateBrandAssetData
  ): Promise<BrandAsset> {
    const response = await fetch(`${API_BASE}/${brandId}/assets/${assetId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to update brand asset: ${response.statusText}`)
    }

    return response.json()
  }

  // Delete brand asset
  static async deleteBrandAsset(brandId: string, assetId: string): Promise<void> {
    const response = await fetch(`${API_BASE}/${brandId}/assets/${assetId}`, {
      method: "DELETE",
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to delete brand asset: ${response.statusText}`)
    }
  }

  // Track asset usage
  static async trackAssetUsage(
    brandId: string, 
    assetId: string, 
    action: "download" | "view"
  ): Promise<void> {
    const response = await fetch(`${API_BASE}/${brandId}/assets/${assetId}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ action }),
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to track asset usage: ${response.statusText}`)
    }
  }
}

// React Query keys for caching
export const brandKeys = {
  all: ["brands"] as const,
  lists: () => [...brandKeys.all, "list"] as const,
  list: (filters: Record<string, any>) => [...brandKeys.lists(), { filters }] as const,
  details: () => [...brandKeys.all, "detail"] as const,
  detail: (id: string) => [...brandKeys.details(), id] as const,
  assets: (brandId: string) => [...brandKeys.detail(brandId), "assets"] as const,
  asset: (brandId: string, assetId: string) => [...brandKeys.assets(brandId), assetId] as const,
}

// Error types
export class BrandError extends Error {
  constructor(
    message: string,
    public statusCode?: number,
    public details?: any
  ) {
    super(message)
    this.name = "BrandError"
  }
}

// API response helpers
export const handleBrandApiError = (error: any): never => {
  if (error instanceof TypeError && error.message.includes("fetch")) {
    throw new BrandError("Network error - please check your connection")
  }
  
  if (error.message.includes("404")) {
    throw new BrandError("Brand not found", 404)
  }
  
  if (error.message.includes("400")) {
    throw new BrandError("Invalid request", 400)
  }
  
  throw new BrandError(error.message || "An unexpected error occurred")
}