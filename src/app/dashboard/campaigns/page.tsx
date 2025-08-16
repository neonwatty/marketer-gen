import { Metadata } from 'next'
import Link from 'next/link'
import { Plus } from 'lucide-react'

import { CampaignExample } from '@/components/features/dashboard/CampaignExample'
import { DashboardBreadcrumb } from '@/components/features/dashboard/DashboardBreadcrumb'
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
      <DashboardBreadcrumb 
        items={[
          { label: 'Dashboard', href: '/dashboard' },
          { label: 'Campaigns', href: '/dashboard/campaigns' }
        ]} 
      />
      
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Campaigns</h1>
            <p className="text-muted-foreground">
              Manage and monitor your marketing campaigns
            </p>
          </div>
          <Button asChild>
            <Link href="/dashboard/campaigns/new" className="flex items-center gap-2">
              <Plus className="h-4 w-4" />
              Create Campaign
            </Link>
          </Button>
        </div>

        <CampaignExample />
      </div>
    </div>
  )
}