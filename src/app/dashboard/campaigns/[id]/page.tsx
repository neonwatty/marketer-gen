import { Metadata } from 'next'

import { DashboardBreadcrumb } from '@/components/features/dashboard/DashboardBreadcrumb'

interface CampaignPageProps {
  params: Promise<{
    id: string
  }>
}

export async function generateMetadata({ params }: CampaignPageProps): Promise<Metadata> {
  const { id } = await params
  return {
    title: `Campaign ${id} | Dashboard`,
    description: `Campaign details and management for campaign ${id}`,
  }
}

/**
 * Individual campaign detail page with journey builder and analytics
 */
export default async function CampaignPage({ params }: CampaignPageProps) {
  const { id } = await params
  return (
    <div className="space-y-6">
      <DashboardBreadcrumb 
        items={[
          { label: 'Dashboard', href: '/dashboard' },
          { label: 'Campaigns', href: '/dashboard/campaigns' },
          { label: `Campaign ${id}`, href: `/dashboard/campaigns/${id}` }
        ]} 
      />
      
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Campaign {id}</h1>
            <p className="text-muted-foreground">
              Campaign details, journey builder, and performance analytics
            </p>
          </div>
        </div>

        {/* Placeholder for campaign detail content - will be implemented in subsequent tasks */}
        <div className="rounded-lg border bg-card text-card-foreground shadow-sm p-6">
          <div className="flex items-center space-x-2">
            <div className="h-2 w-2 bg-purple-500 rounded-full animate-pulse" />
            <p className="text-sm text-muted-foreground">
              Journey builder and campaign details will be added in tasks 4.4 and 4.5
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}