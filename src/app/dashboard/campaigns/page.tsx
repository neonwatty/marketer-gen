import { Metadata } from 'next'

import { DashboardBreadcrumb } from '@/components/features/dashboard/DashboardBreadcrumb'

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
        </div>

        {/* Placeholder for campaigns content - will be implemented in subsequent tasks */}
        <div className="rounded-lg border bg-card text-card-foreground shadow-sm p-6">
          <div className="flex items-center space-x-2">
            <div className="h-2 w-2 bg-green-500 rounded-full animate-pulse" />
            <p className="text-sm text-muted-foreground">
              Campaign listing and management components will be added in task 4.3
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}