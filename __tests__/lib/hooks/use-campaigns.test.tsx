import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { toast } from 'sonner'
import {
  useCampaigns,
  useCampaign,
  useCreateCampaign,
  useUpdateCampaign,
  useDeleteCampaign,
  useDuplicateCampaign,
  useJourneyTemplates,
  useCreateJourneyFromTemplate
} from '@/lib/hooks/use-campaigns'

// Mock dependencies
jest.mock('sonner', () => ({
  toast: {
    success: jest.fn(),
    error: jest.fn(),
    info: jest.fn(),
    warning: jest.fn(),
  }
}))

jest.mock('@/lib/api/campaigns', () => ({
  campaignApi: {
    getCampaigns: jest.fn(),
    getCampaign: jest.fn(),
    createCampaign: jest.fn(),
    updateCampaign: jest.fn(),
    deleteCampaign: jest.fn(),
    duplicateCampaign: jest.fn(),
    getJourneyTemplates: jest.fn(),
    createJourneyFromTemplate: jest.fn(),
  }
}))

const mockToast = toast as jest.MockedObjectDeep<typeof toast>

// Import after mocking
const { campaignApi } = require('@/lib/api/campaigns')
const mockCampaignApi = campaignApi as jest.MockedObjectDeep<typeof campaignApi>

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  )
}

describe.skip('Campaign Hooks', () => {
  const mockCampaign = {
    id: 'campaign-123',
    name: 'Test Campaign',
    purpose: 'Test purpose',
    goals: { target: 'awareness' },
    status: 'DRAFT' as const,
    brandId: 'brand-123',
    userId: 'user-123',
    startDate: '2023-01-01',
    endDate: '2023-12-31',
    createdAt: '2023-01-01T00:00:00Z',
    updatedAt: '2023-01-01T00:00:00Z',
    brand: { id: 'brand-123', name: 'Test Brand' },
    journeys: [],
    _count: { journeys: 0 }
  }

  const mockCampaignListResponse = {
    campaigns: [mockCampaign],
    pagination: { page: 1, limit: 10, total: 1, pages: 1 }
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('useCampaigns', () => {
    it('should fetch campaigns successfully', async () => {
      mockCampaignApi.getCampaigns.mockResolvedValue(mockCampaignListResponse)

      const { result } = renderHook(() => useCampaigns(), {
        wrapper: createWrapper(),
      })

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(result.current.data).toEqual(mockCampaignListResponse)
      expect(mockCampaignApi.getCampaigns).toHaveBeenCalledWith({})
    })

    it('should pass query parameters correctly', async () => {
      mockCampaignApi.getCampaigns.mockResolvedValue(mockCampaignListResponse)

      const params = { page: 2, limit: 5, status: 'ACTIVE' as const }
      const { result } = renderHook(() => useCampaigns(params), {
        wrapper: createWrapper(),
      })

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(mockCampaignApi.getCampaigns).toHaveBeenCalledWith(params)
    })

    it('should handle errors gracefully', async () => {
      mockCampaignApi.getCampaigns.mockRejectedValue(new Error('API Error'))

      const { result } = renderHook(() => useCampaigns(), {
        wrapper: createWrapper(),
      })

      await waitFor(() => {
        expect(result.current.isError).toBe(true)
      })

      expect(result.current.error).toBeInstanceOf(Error)
    })
  })

  describe('useCampaign', () => {
    it('should fetch single campaign successfully', async () => {
      mockCampaignApi.getCampaign.mockResolvedValue(mockCampaign)

      const { result } = renderHook(() => useCampaign('campaign-123'), {
        wrapper: createWrapper(),
      })

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(result.current.data).toEqual(mockCampaign)
      expect(mockCampaignApi.getCampaign).toHaveBeenCalledWith('campaign-123')
    })

    it('should not fetch when id is empty', () => {
      const { result } = renderHook(() => useCampaign(''), {
        wrapper: createWrapper(),
      })

      expect(result.current.isFetching).toBe(false)
      expect(mockCampaignApi.getCampaign).not.toHaveBeenCalled()
    })
  })

  describe('useCreateCampaign', () => {
    it('should create campaign and show success toast', async () => {
      mockCampaignApi.createCampaign.mockResolvedValue(mockCampaign)

      const { result } = renderHook(() => useCreateCampaign(), {
        wrapper: createWrapper(),
      })

      const campaignData = {
        name: 'New Campaign',
        brandId: 'brand-123'
      }

      result.current.mutate(campaignData)

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(mockCampaignApi.createCampaign).toHaveBeenCalledWith(campaignData)
      expect(mockToast.success).toHaveBeenCalledWith('Campaign created successfully!')
    })

    it('should show error toast on failure', async () => {
      const error = new Error('Creation failed')
      mockCampaignApi.createCampaign.mockRejectedValue(error)

      const { result } = renderHook(() => useCreateCampaign(), {
        wrapper: createWrapper(),
      })

      result.current.mutate({ name: 'Test', brandId: 'brand-123' })

      await waitFor(() => {
        expect(result.current.isError).toBe(true)
      })

      expect(mockToast.error).toHaveBeenCalledWith('Failed to create campaign: Creation failed')
    })
  })

  describe('useUpdateCampaign', () => {
    it('should update campaign with optimistic updates', async () => {
      mockCampaignApi.updateCampaign.mockResolvedValue({
        ...mockCampaign,
        name: 'Updated Campaign'
      })

      const { result } = renderHook(() => useUpdateCampaign(), {
        wrapper: createWrapper(),
      })

      const updateData = { name: 'Updated Campaign' }
      result.current.mutate({ id: 'campaign-123', data: updateData })

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(mockCampaignApi.updateCampaign).toHaveBeenCalledWith('campaign-123', updateData)
      expect(mockToast.success).toHaveBeenCalledWith('Campaign updated successfully!')
    })

    it('should show error toast and revert optimistic updates on failure', async () => {
      const error = new Error('Update failed')
      mockCampaignApi.updateCampaign.mockRejectedValue(error)

      const { result } = renderHook(() => useUpdateCampaign(), {
        wrapper: createWrapper(),
      })

      result.current.mutate({ id: 'campaign-123', data: { name: 'Updated' } })

      await waitFor(() => {
        expect(result.current.isError).toBe(true)
      })

      expect(mockToast.error).toHaveBeenCalledWith('Failed to update campaign: Update failed')
    })
  })

  describe('useDeleteCampaign', () => {
    it('should delete campaign with optimistic updates', async () => {
      mockCampaignApi.deleteCampaign.mockResolvedValue()

      const { result } = renderHook(() => useDeleteCampaign(), {
        wrapper: createWrapper(),
      })

      result.current.mutate('campaign-123')

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(mockCampaignApi.deleteCampaign).toHaveBeenCalledWith('campaign-123')
      expect(mockToast.success).toHaveBeenCalledWith('Campaign deleted successfully!')
    })

    it('should show error toast and revert optimistic updates on failure', async () => {
      const error = new Error('Delete failed')
      mockCampaignApi.deleteCampaign.mockRejectedValue(error)

      const { result } = renderHook(() => useDeleteCampaign(), {
        wrapper: createWrapper(),
      })

      result.current.mutate('campaign-123')

      await waitFor(() => {
        expect(result.current.isError).toBe(true)
      })

      expect(mockToast.error).toHaveBeenCalledWith('Failed to delete campaign: Delete failed')
    })
  })

  describe('useDuplicateCampaign', () => {
    it('should duplicate campaign successfully', async () => {
      const duplicatedCampaign = {
        ...mockCampaign,
        id: 'campaign-456',
        name: 'Duplicated Campaign'
      }
      mockCampaignApi.duplicateCampaign.mockResolvedValue(duplicatedCampaign)

      const { result } = renderHook(() => useDuplicateCampaign(), {
        wrapper: createWrapper(),
      })

      result.current.mutate({ id: 'campaign-123', name: 'Duplicated Campaign' })

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(mockCampaignApi.duplicateCampaign).toHaveBeenCalledWith('campaign-123', 'Duplicated Campaign')
      expect(mockToast.success).toHaveBeenCalledWith('Campaign duplicated successfully!')
    })

    it('should show error toast on failure', async () => {
      const error = new Error('Duplication failed')
      mockCampaignApi.duplicateCampaign.mockRejectedValue(error)

      const { result } = renderHook(() => useDuplicateCampaign(), {
        wrapper: createWrapper(),
      })

      result.current.mutate({ id: 'campaign-123', name: 'Duplicated' })

      await waitFor(() => {
        expect(result.current.isError).toBe(true)
      })

      expect(mockToast.error).toHaveBeenCalledWith('Failed to duplicate campaign: Duplication failed')
    })
  })

  describe('useJourneyTemplates', () => {
    it('should fetch journey templates successfully', async () => {
      const mockTemplates = {
        templates: [
          { id: 'welcome-series', name: 'Welcome Series', stages: [] }
        ]
      }
      mockCampaignApi.getJourneyTemplates.mockResolvedValue(mockTemplates)

      const { result } = renderHook(() => useJourneyTemplates(), {
        wrapper: createWrapper(),
      })

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(result.current.data).toEqual(mockTemplates)
      expect(mockCampaignApi.getJourneyTemplates).toHaveBeenCalled()
    })
  })

  describe('useCreateJourneyFromTemplate', () => {
    it('should create journey from template successfully', async () => {
      const mockJourney = {
        id: 'journey-123',
        campaignId: 'campaign-123',
        stages: []
      }
      mockCampaignApi.createJourneyFromTemplate.mockResolvedValue(mockJourney)

      const { result } = renderHook(() => useCreateJourneyFromTemplate(), {
        wrapper: createWrapper(),
      })

      const templateData = {
        templateId: 'welcome-series',
        campaignId: 'campaign-123',
        customizations: {}
      }

      result.current.mutate(templateData)

      await waitFor(() => {
        expect(result.current.isSuccess).toBe(true)
      })

      expect(mockCampaignApi.createJourneyFromTemplate).toHaveBeenCalledWith(
        'welcome-series',
        'campaign-123',
        {}
      )
      expect(mockToast.success).toHaveBeenCalledWith('Journey created from template successfully!')
    })

    it('should show error toast on failure', async () => {
      const error = new Error('Template creation failed')
      mockCampaignApi.createJourneyFromTemplate.mockRejectedValue(error)

      const { result } = renderHook(() => useCreateJourneyFromTemplate(), {
        wrapper: createWrapper(),
      })

      result.current.mutate({
        templateId: 'welcome-series',
        campaignId: 'campaign-123'
      })

      await waitFor(() => {
        expect(result.current.isError).toBe(true)
      })

      expect(mockToast.error).toHaveBeenCalledWith('Failed to create journey: Template creation failed')
    })
  })
})