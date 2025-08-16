'use client'

import { useState } from 'react'
import { CampaignCard, type Campaign } from './CampaignCard'
import { CampaignCardSkeletonGrid } from './CampaignCardSkeleton'

export interface CampaignGridProps {
  campaigns: Campaign[]
  isLoading?: boolean
  onView?: (id: string) => void
  onEdit?: (id: string) => void
  onDuplicate?: (id: string) => void
  onArchive?: (id: string) => void
  emptyStateComponent?: React.ReactNode
}

export function CampaignGrid({
  campaigns,
  isLoading = false,
  onView,
  onEdit,
  onDuplicate,
  onArchive,
  emptyStateComponent,
}: CampaignGridProps) {
  if (isLoading) {
    return <CampaignCardSkeletonGrid count={6} />
  }

  if (campaigns.length === 0) {
    return (
      <div className="flex min-h-[400px] items-center justify-center">
        {emptyStateComponent || (
          <div className="text-center">
            <div className="text-muted-foreground mb-2 text-lg">No campaigns found</div>
            <p className="text-muted-foreground text-sm">
              Create your first campaign to get started with your marketing journey.
            </p>
          </div>
        )}
      </div>
    )
  }

  return (
    <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      {campaigns.map((campaign) => (
        <CampaignCard
          key={campaign.id}
          campaign={campaign}
          onView={onView}
          onEdit={onEdit}
          onDuplicate={onDuplicate}
          onArchive={onArchive}
        />
      ))}
    </div>
  )
}