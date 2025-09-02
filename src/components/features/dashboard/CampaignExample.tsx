'use client'

import { useEffect,useState } from 'react'
import { useRouter } from 'next/navigation'

import { LoadingButton } from '@/components/ui/loading-button'

import { CampaignDataTable } from '../campaigns/CampaignDataTable'

import { type Campaign } from './CampaignCard'

export function CampaignExample() {
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(true)
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [refreshing, setRefreshing] = useState(false)

  const handleView = (id: string) => {
    console.log('View campaign:', id)
    router.push(`/dashboard/campaigns/${id}`)
  }

  const handleEdit = (id: string) => {
    console.log('Edit campaign:', id)
    router.push(`/dashboard/campaigns/${id}?mode=edit`)
  }

  const handleDuplicate = (id: string) => {
    console.log('Duplicate campaign:', id)
    // For now, just log - could implement duplication logic later
  }

  const handleArchive = (id: string) => {
    console.log('Archive campaign:', id)
    // For now, just log - could implement archive logic later
  }

  // Fetch real campaign data
  useEffect(() => {
    const loadCampaigns = async () => {
      setIsLoading(true)
      try {
        const response = await fetch('/api/campaigns', {
          credentials: 'include',
        })
        
        if (response.ok) {
          const data = await response.json()
          // Transform database campaigns to match the Campaign interface
          const transformedCampaigns: Campaign[] = data.campaigns.map((campaign: any) => {
            // Calculate real progress based on content completion
            const calculateProgress = (campaign: any) => {
              if (campaign.status === 'COMPLETED') return 100
              
              // Get journey count and content count for this campaign
              const journeyCount = campaign._count?.journeys || 0
              const contentCount = campaign.journeys?.reduce((total: number, journey: any) => 
                total + (journey._count?.content || 0), 0) || 0
              
              // Base progress calculation
              let baseProgress = 0
              
              // Campaign setup phase (0-25%)
              if (campaign.name && campaign.purpose) baseProgress += 15
              if (campaign.goals) baseProgress += 10
              
              // Journey creation phase (25-50%)  
              if (journeyCount > 0) baseProgress += 25
              
              // Content creation phase (50-90%)
              const expectedContentPieces = Math.max(journeyCount * 3, 5) // Expect 3 pieces per journey, minimum 5
              const contentProgress = Math.min((contentCount / expectedContentPieces) * 40, 40)
              baseProgress += contentProgress
              
              // Activation phase (90-100%)
              if (campaign.status === 'ACTIVE') baseProgress += 10
              
              return Math.min(Math.max(baseProgress, 0), 100)
            }
            
            return {
              id: campaign.id,
              title: campaign.name,
              description: campaign.purpose || `${campaign.brand?.name} campaign`,
              status: campaign.status?.toLowerCase() || 'draft',
              metrics: {
                engagementRate: Math.random() * 10, // Mock metrics for now
                conversionRate: Math.random() * 5,
                contentPieces: campaign._count?.journeys || 0,
                totalReach: Math.floor(Math.random() * 100000),
                activeUsers: Math.floor(Math.random() * 10000),
              },
              progress: calculateProgress(campaign),
              createdAt: new Date(campaign.createdAt),
              updatedAt: new Date(campaign.updatedAt),
            }
          })
          setCampaigns(transformedCampaigns)
        } else {
          console.warn('Failed to fetch campaigns, using fallback data')
          setCampaigns([]) // Use empty array if API fails
        }
      } catch (error) {
        console.error('Error fetching campaigns:', error)
        setCampaigns([]) // Use empty array if API fails
      }
      setIsLoading(false)
    }
    
    loadCampaigns()
  }, [])

  const handleRefresh = async () => {
    setRefreshing(true)
    try {
      const response = await fetch('/api/campaigns', {
        credentials: 'include',
      })
      
      if (response.ok) {
        const data = await response.json()
        const transformedCampaigns: Campaign[] = data.campaigns.map((campaign: any) => {
          // Calculate real progress based on content completion
          const calculateProgress = (campaign: any) => {
            if (campaign.status === 'COMPLETED') return 100
            
            // Get journey count and content count for this campaign
            const journeyCount = campaign._count?.journeys || 0
            const contentCount = campaign.journeys?.reduce((total: number, journey: any) => 
              total + (journey._count?.content || 0), 0) || 0
            
            // Base progress calculation
            let baseProgress = 0
            
            // Campaign setup phase (0-25%)
            if (campaign.name && campaign.purpose) baseProgress += 15
            if (campaign.goals) baseProgress += 10
            
            // Journey creation phase (25-50%)  
            if (journeyCount > 0) baseProgress += 25
            
            // Content creation phase (50-90%)
            const expectedContentPieces = Math.max(journeyCount * 3, 5) // Expect 3 pieces per journey, minimum 5
            const contentProgress = Math.min((contentCount / expectedContentPieces) * 40, 40)
            baseProgress += contentProgress
            
            // Activation phase (90-100%)
            if (campaign.status === 'ACTIVE') baseProgress += 10
            
            return Math.min(Math.max(baseProgress, 0), 100)
          }
          
          return {
            id: campaign.id,
            title: campaign.name,
            description: campaign.purpose || `${campaign.brand?.name} campaign`,
            status: campaign.status?.toLowerCase() || 'draft',
            metrics: {
              engagementRate: Math.random() * 10,
              conversionRate: Math.random() * 5,
              contentPieces: campaign._count?.journeys || 0,
              totalReach: Math.floor(Math.random() * 100000),
              activeUsers: Math.floor(Math.random() * 10000),
            },
            progress: calculateProgress(campaign),
            createdAt: new Date(campaign.createdAt),
            updatedAt: new Date(campaign.updatedAt),
          }
        })
        setCampaigns(transformedCampaigns)
      }
    } catch (error) {
      console.error('Error refreshing campaigns:', error)
    }
    setRefreshing(false)
  }

  const toggleLoading = () => {
    setIsLoading(!isLoading)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Campaign Management</h2>
          <p className="text-muted-foreground">
            Comprehensive campaign listing with advanced filtering and sorting
          </p>
        </div>
        <div className="flex items-center gap-2">
          <LoadingButton
            onClick={handleRefresh}
            loading={refreshing}
            loadingText="Refreshing..."
            variant="outline"
            size="sm"
          >
            Refresh Data
          </LoadingButton>
          <LoadingButton
            onClick={toggleLoading}
            variant="secondary"
            size="sm"
          >
            Toggle Loading State
          </LoadingButton>
        </div>
      </div>

      <CampaignDataTable
        campaigns={isLoading ? [] : campaigns}
        isLoading={isLoading || refreshing}
        onView={handleView}
        onEdit={handleEdit}
        onDuplicate={handleDuplicate}
        onArchive={handleArchive}
      />
    </div>
  )
}