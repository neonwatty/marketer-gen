import { Metadata } from 'next'
import Link from 'next/link'

import { Plus } from 'lucide-react'

import { CampaignExample } from '@/components/features/dashboard/CampaignExample'
import { Button } from '@/components/ui/button'

export const metadata: Metadata = {
  title: 'Campaigns | Dashboard',
  description: 'Manage your marketing campaigns',
}

/**
 * Campaigns listing page with filters and campaign management
 */
export default function CampaignsPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Campaigns</h1>
          <p className="text-muted-foreground">
            Manage and monitor your marketing campaigns
          </p>
        </div>
        <Button asChild>
          <Link href="/dashboard/campaigns/new" className="flex items-center gap-2" data-testid="new-campaign-button">
            <Plus className="h-4 w-4" />
            New Campaign
          </Link>
        </Button>
      </div>

      <CampaignExample />
    </div>
  )
}