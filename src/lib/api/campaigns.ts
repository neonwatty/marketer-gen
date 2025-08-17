import { CampaignStatus } from '@/generated/prisma'

export interface Campaign {
  id: string
  name: string
  purpose?: string
  goals?: any
  status: CampaignStatus
  brandId: string
  userId: string
  startDate?: string
  endDate?: string
  createdAt: string
  updatedAt: string
  brand: {
    id: string
    name: string
  }
  journeys: Array<{
    id: string
    status: string
  }>
  _count: {
    journeys: number
  }
}

export interface CampaignListResponse {
  campaigns: Campaign[]
  pagination: {
    page: number
    limit: number
    total: number
    pages: number
  }
}

export interface CreateCampaignData {
  name: string
  purpose?: string
  goals?: any
  brandId: string
  startDate?: string
  endDate?: string
  status?: CampaignStatus
}

export interface UpdateCampaignData {
  name?: string
  purpose?: string
  goals?: any
  brandId?: string
  startDate?: string
  endDate?: string
  status?: CampaignStatus
}

export interface CampaignQueryParams {
  page?: number
  limit?: number
  status?: CampaignStatus
  brandId?: string
}

// Campaign API functions
export const campaignApi = {
  // Get campaigns list
  async getCampaigns(params: CampaignQueryParams = {}): Promise<CampaignListResponse> {
    const searchParams = new URLSearchParams()
    
    if (params.page) searchParams.set('page', params.page.toString())
    if (params.limit) searchParams.set('limit', params.limit.toString())
    if (params.status) searchParams.set('status', params.status)
    if (params.brandId) searchParams.set('brandId', params.brandId)

    const response = await fetch(`/api/campaigns?${searchParams.toString()}`)
    
    if (!response.ok) {
      throw new Error(`Failed to fetch campaigns: ${response.statusText}`)
    }
    
    return response.json()
  },

  // Get single campaign
  async getCampaign(id: string): Promise<Campaign> {
    const response = await fetch(`/api/campaigns/${id}`)
    
    if (!response.ok) {
      throw new Error(`Failed to fetch campaign: ${response.statusText}`)
    }
    
    return response.json()
  },

  // Create campaign
  async createCampaign(data: CreateCampaignData): Promise<Campaign> {
    const response = await fetch('/api/campaigns', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to create campaign: ${response.statusText}`)
    }
    
    return response.json()
  },

  // Update campaign
  async updateCampaign(id: string, data: UpdateCampaignData): Promise<Campaign> {
    const response = await fetch(`/api/campaigns/${id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to update campaign: ${response.statusText}`)
    }
    
    return response.json()
  },

  // Delete campaign
  async deleteCampaign(id: string): Promise<void> {
    const response = await fetch(`/api/campaigns/${id}`, {
      method: 'DELETE',
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to delete campaign: ${response.statusText}`)
    }
  },

  // Duplicate campaign
  async duplicateCampaign(id: string, name: string): Promise<Campaign> {
    const response = await fetch(`/api/campaigns/${id}/duplicate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ name }),
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to duplicate campaign: ${response.statusText}`)
    }
    
    return response.json()
  },

  // Get journey templates
  async getJourneyTemplates() {
    const response = await fetch('/api/campaigns/templates')
    
    if (!response.ok) {
      throw new Error(`Failed to fetch journey templates: ${response.statusText}`)
    }
    
    return response.json()
  },

  // Create journey from template
  async createJourneyFromTemplate(templateId: string, campaignId: string, customizations = {}) {
    const response = await fetch('/api/campaigns/templates', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        templateId,
        campaignId,
        customizations,
      }),
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to create journey from template: ${response.statusText}`)
    }
    
    return response.json()
  },
}