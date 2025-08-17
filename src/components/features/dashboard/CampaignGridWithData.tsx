'use client'

import { useState } from 'react'
import { Plus, Search } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

import { useCampaigns, useDeleteCampaign, useDuplicateCampaign, useUpdateCampaign } from '@/lib/hooks/use-campaigns'
import { CampaignStatus } from '@/generated/prisma'
import { CampaignGrid } from './CampaignGrid'
import { CampaignCardSkeletonGrid } from './CampaignCardSkeleton'
import { DuplicateCampaignDialog } from './DuplicateCampaignDialog'

interface CampaignGridWithDataProps {
  onCreateCampaign?: () => void
  onEditCampaign?: (id: string) => void
  onViewCampaign?: (id: string) => void
  // Accept query params as props for testing and external control
  status?: CampaignStatus
  brandId?: string
}

export function CampaignGridWithData({
  onCreateCampaign,
  onEditCampaign,
  onViewCampaign,
  status: propsStatus,
  brandId: propsBrandId,
}: CampaignGridWithDataProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<CampaignStatus | 'all'>('all')
  const [currentPage, setCurrentPage] = useState(1)
  const [duplicateDialogOpen, setDuplicateDialogOpen] = useState(false)
  const [campaignToDuplicate, setCampaignToDuplicate] = useState<string | null>(null)

  // Build query parameters
  const queryParams = {
    page: currentPage,
    limit: 12,
    ...(propsStatus && { status: propsStatus }),
    ...(propsBrandId && { brandId: propsBrandId }),
    ...(statusFilter !== 'all' && { status: statusFilter as CampaignStatus }),
  }

  // Fetch campaigns
  const {
    data: campaignData,
    isLoading,
    isError,
    error,
    refetch,
  } = useCampaigns(queryParams)

  // Mutations
  const updateCampaign = useUpdateCampaign()
  const deleteCampaign = useDeleteCampaign()
  const duplicateCampaign = useDuplicateCampaign()

  // Filter campaigns by search query (client-side for better UX)
  const filteredCampaigns = campaignData?.campaigns?.filter((campaign) =>
    campaign.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    campaign.purpose?.toLowerCase().includes(searchQuery.toLowerCase())
  ) ?? []

  const handleStatusChange = async (campaignId: string, newStatus: CampaignStatus) => {
    updateCampaign.mutate({
      id: campaignId,
      data: { status: newStatus },
    })
  }

  const handleArchive = (campaignId: string) => {
    deleteCampaign.mutate(campaignId)
  }

  const handleDuplicate = (campaignId: string) => {
    setCampaignToDuplicate(campaignId)
    setDuplicateDialogOpen(true)
  }

  const handleConfirmDuplicate = (name: string) => {
    if (campaignToDuplicate) {
      duplicateCampaign.mutate({
        id: campaignToDuplicate,
        name,
      })
    }
    setDuplicateDialogOpen(false)
    setCampaignToDuplicate(null)
  }

  // Transform campaigns to match CampaignCard interface
  const transformedCampaigns = filteredCampaigns.map((campaign) => ({
    id: campaign.id,
    title: campaign.name,
    description: campaign.purpose || 'No description available',
    status: campaign.status.toLowerCase() as any,
    metrics: {
      engagementRate: Math.floor(Math.random() * 30) + 10, // Mock data
      conversionRate: Math.floor(Math.random() * 15) + 2,
      contentPieces: campaign._count.journeys,
      totalReach: Math.floor(Math.random() * 10000) + 1000,
      activeUsers: Math.floor(Math.random() * 1000) + 100,
    },
    progress: Math.floor(Math.random() * 100),
    createdAt: new Date(campaign.createdAt),
    updatedAt: new Date(campaign.updatedAt),
  }))

  const EmptyState = () => (
    <div className="flex min-h-[400px] flex-col items-center justify-center space-y-4">
      <div className="text-center">
        <h3 className="text-lg font-medium">No campaigns found</h3>
        <p className="text-muted-foreground text-sm">
          {searchQuery || statusFilter !== 'all'
            ? 'Try adjusting your search or filters'
            : 'Create your first campaign to get started with your marketing journey.'}
        </p>
      </div>
      {!searchQuery && statusFilter === 'all' && (
        <Button onClick={onCreateCampaign} className="mt-4">
          <Plus className="mr-2 h-4 w-4" />
          Create Your First Campaign
        </Button>
      )}
    </div>
  )

  if (isError) {
    return (
      <div className="flex min-h-[400px] items-center justify-center">
        <div className="text-center">
          <h3 className="text-lg font-medium text-destructive">Failed to load campaigns</h3>
          <p className="text-muted-foreground text-sm mt-2">
            {error instanceof Error ? error.message : 'Something went wrong'}
          </p>
          <Button
            variant="outline"
            onClick={() => refetch()}
            className="mt-4"
          >
            Try Again
          </Button>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header with Search and Filters */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-1 items-center gap-4">
          <div className="relative flex-1 max-w-sm">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search campaigns..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
          </div>
          <Select
            value={statusFilter}
            onValueChange={(value) => setStatusFilter(value as CampaignStatus | 'all')}
          >
            <SelectTrigger className="w-[140px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Status</SelectItem>
              <SelectItem value="DRAFT">Draft</SelectItem>
              <SelectItem value="ACTIVE">Active</SelectItem>
              <SelectItem value="PAUSED">Paused</SelectItem>
              <SelectItem value="COMPLETED">Completed</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <Button onClick={onCreateCampaign}>
          <Plus className="mr-2 h-4 w-4" />
          New Campaign
        </Button>
      </div>

      {/* Loading State */}
      {isLoading && <CampaignCardSkeletonGrid count={6} />}

      {/* Campaigns Grid */}
      {!isLoading && (
        <CampaignGrid
          campaigns={transformedCampaigns}
          isLoading={false}
          onView={onViewCampaign}
          onEdit={onEditCampaign}
          onDuplicate={handleDuplicate}
          onArchive={handleArchive}
          emptyStateComponent={<EmptyState />}
        />
      )}

      {/* Pagination */}
      {!isLoading && campaignData && campaignData.pagination.pages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <Button
            variant="outline"
            onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
            disabled={currentPage === 1}
          >
            Previous
          </Button>
          <span className="text-sm text-muted-foreground">
            Page {currentPage} of {campaignData.pagination.pages}
          </span>
          <Button
            variant="outline"
            onClick={() => setCurrentPage(p => Math.min(campaignData.pagination.pages, p + 1))}
            disabled={currentPage === campaignData.pagination.pages}
          >
            Next
          </Button>
        </div>
      )}

      {/* Duplicate Dialog */}
      <DuplicateCampaignDialog
        open={duplicateDialogOpen}
        onOpenChange={setDuplicateDialogOpen}
        onConfirm={handleConfirmDuplicate}
        isLoading={duplicateCampaign.isPending}
      />
    </div>
  )
}