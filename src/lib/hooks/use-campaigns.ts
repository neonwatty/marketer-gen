import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

import {
  campaignApi,
  type Campaign,
  type CampaignQueryParams,
  type CreateCampaignData,
  type UpdateCampaignData,
} from '@/lib/api/campaigns'

// Query keys
export const campaignKeys = {
  all: ['campaigns'] as const,
  lists: () => [...campaignKeys.all, 'list'] as const,
  list: (params: CampaignQueryParams) => [...campaignKeys.lists(), params] as const,
  details: () => [...campaignKeys.all, 'detail'] as const,
  detail: (id: string) => [...campaignKeys.details(), id] as const,
  templates: () => ['campaign-templates'] as const,
}

// Get campaigns list
export function useCampaigns(params: CampaignQueryParams = {}) {
  return useQuery({
    queryKey: campaignKeys.list(params),
    queryFn: () => campaignApi.getCampaigns(params),
    staleTime: 2 * 60 * 1000, // 2 minutes
  })
}

// Get single campaign
export function useCampaign(id: string) {
  return useQuery({
    queryKey: campaignKeys.detail(id),
    queryFn: () => campaignApi.getCampaign(id),
    enabled: !!id,
  })
}

// Create campaign mutation
export function useCreateCampaign() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: campaignApi.createCampaign,
    onSuccess: (newCampaign) => {
      // Invalidate campaigns list
      queryClient.invalidateQueries({ queryKey: campaignKeys.lists() })
      
      // Add to cache
      queryClient.setQueryData(campaignKeys.detail(newCampaign.id), newCampaign)
      
      toast.success('Campaign created successfully!')
    },
    onError: (error: Error) => {
      toast.error(`Failed to create campaign: ${error.message}`)
    },
  })
}

// Update campaign mutation with optimistic updates
export function useUpdateCampaign() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateCampaignData }) =>
      campaignApi.updateCampaign(id, data),
    onMutate: async ({ id, data }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: campaignKeys.detail(id) })
      await queryClient.cancelQueries({ queryKey: campaignKeys.lists() })

      // Snapshot previous values
      const previousCampaign = queryClient.getQueryData<Campaign>(campaignKeys.detail(id))
      const previousCampaigns = queryClient.getQueriesData({ queryKey: campaignKeys.lists() })

      // Optimistically update campaign detail
      if (previousCampaign) {
        queryClient.setQueryData(campaignKeys.detail(id), {
          ...previousCampaign,
          ...data,
          updatedAt: new Date().toISOString(),
        })
      }

      // Optimistically update campaigns list
      previousCampaigns.forEach(([queryKey, queryData]) => {
        if (queryData && typeof queryData === 'object' && 'campaigns' in queryData && Array.isArray(queryData.campaigns)) {
          const updatedCampaigns = queryData.campaigns.map((campaign: Campaign) =>
            campaign.id === id
              ? { ...campaign, ...data, updatedAt: new Date().toISOString() }
              : campaign
          )
          queryClient.setQueryData(queryKey, {
            ...queryData,
            campaigns: updatedCampaigns,
          })
        }
      })

      return { previousCampaign, previousCampaigns }
    },
    onError: (error: Error, { id }, context) => {
      // Revert optimistic updates on error
      if (context?.previousCampaign) {
        queryClient.setQueryData(campaignKeys.detail(id), context.previousCampaign)
      }
      
      if (context?.previousCampaigns) {
        context.previousCampaigns.forEach(([queryKey, queryData]) => {
          queryClient.setQueryData(queryKey, queryData)
        })
      }

      toast.error(`Failed to update campaign: ${error.message}`)
    },
    onSuccess: () => {
      toast.success('Campaign updated successfully!')
    },
    onSettled: (data, error, { id }) => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: campaignKeys.detail(id) })
      queryClient.invalidateQueries({ queryKey: campaignKeys.lists() })
    },
  })
}

// Delete campaign mutation with optimistic updates
export function useDeleteCampaign() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: campaignApi.deleteCampaign,
    onMutate: async (id: string) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: campaignKeys.lists() })

      // Snapshot previous values
      const previousCampaigns = queryClient.getQueriesData({ queryKey: campaignKeys.lists() })

      // Optimistically remove campaign from lists
      previousCampaigns.forEach(([queryKey, queryData]) => {
        if (queryData && typeof queryData === 'object' && 'campaigns' in queryData && Array.isArray(queryData.campaigns)) {
          const filteredCampaigns = queryData.campaigns.filter((campaign: Campaign) => campaign.id !== id)
          queryClient.setQueryData(queryKey, {
            ...queryData,
            campaigns: filteredCampaigns,
            pagination: 'pagination' in queryData && queryData.pagination && typeof queryData.pagination === 'object' && 'total' in queryData.pagination ? {
              ...queryData.pagination,
              total: (queryData.pagination.total as number) - 1,
            } : undefined,
          })
        }
      })

      return { previousCampaigns }
    },
    onError: (error: Error, id, context) => {
      // Revert optimistic updates on error
      if (context?.previousCampaigns) {
        context.previousCampaigns.forEach(([queryKey, queryData]) => {
          queryClient.setQueryData(queryKey, queryData)
        })
      }

      toast.error(`Failed to delete campaign: ${error.message}`)
    },
    onSuccess: () => {
      toast.success('Campaign deleted successfully!')
    },
    onSettled: () => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: campaignKeys.lists() })
    },
  })
}

// Duplicate campaign mutation
export function useDuplicateCampaign() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, name }: { id: string; name: string }) =>
      campaignApi.duplicateCampaign(id, name),
    onSuccess: (newCampaign) => {
      // Invalidate campaigns list
      queryClient.invalidateQueries({ queryKey: campaignKeys.lists() })
      
      // Add to cache
      queryClient.setQueryData(campaignKeys.detail(newCampaign.id), newCampaign)
      
      toast.success('Campaign duplicated successfully!')
    },
    onError: (error: Error) => {
      toast.error(`Failed to duplicate campaign: ${error.message}`)
    },
  })
}

// Get journey templates
export function useJourneyTemplates() {
  return useQuery({
    queryKey: campaignKeys.templates(),
    queryFn: campaignApi.getJourneyTemplates,
    staleTime: 10 * 60 * 1000, // 10 minutes - templates don't change often
  })
}

// Create journey from template
export function useCreateJourneyFromTemplate() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ templateId, campaignId, customizations }: {
      templateId: string
      campaignId: string
      customizations?: any
    }) => campaignApi.createJourneyFromTemplate(templateId, campaignId, customizations),
    onSuccess: (_, { campaignId }) => {
      // Invalidate campaign detail to refetch with new journey
      queryClient.invalidateQueries({ queryKey: campaignKeys.detail(campaignId) })
      queryClient.invalidateQueries({ queryKey: campaignKeys.lists() })
      
      toast.success('Journey created from template successfully!')
    },
    onError: (error: Error) => {
      toast.error(`Failed to create journey: ${error.message}`)
    },
  })
}