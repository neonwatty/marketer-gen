"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { CampaignCard, type CampaignStatus } from "@/components/ui/campaign-card"
import { CampaignCardSkeleton } from "@/components/ui/campaign-card-skeleton"
import { CampaignStats } from "@/components/ui/campaign-stats"
import { CampaignStatsSkeleton } from "@/components/ui/campaign-stats-skeleton"
import { ErrorBoundary } from "@/components/ui/error-boundary"
import { ErrorDisplay } from "@/components/ui/error-display"
import { Plus, Search, Filter, LayoutGrid, List } from "lucide-react"
import { Input } from "@/components/ui/input"
import Link from "next/link"

// Sample campaign data - in a real app, this would come from an API or database
const sampleCampaigns = [
  {
    id: "1",
    title: "Summer Product Launch",
    description: "Multi-channel campaign for new product line launch",
    status: "active" as CampaignStatus,
    createdAt: "Jan 15, 2024",
    metrics: {
      progress: 75,
      contentPieces: 12,
      channels: ["Email", "Social", "Blog"],
      budget: 25000,
      impressions: 125000,
      engagement: 4.2,
      conversions: 850
    }
  },
  {
    id: "2", 
    title: "Holiday Sale Campaign",
    description: "Black Friday and Cyber Monday promotional campaign",
    status: "draft" as CampaignStatus,
    createdAt: "Jan 20, 2024",
    metrics: {
      progress: 25,
      contentPieces: 3,
      channels: ["Email", "Social"],
      budget: 15000
    }
  },
  {
    id: "3",
    title: "Brand Awareness Q1",
    description: "Multi-touch brand awareness campaign targeting millennials",
    status: "paused" as CampaignStatus,
    createdAt: "Dec 10, 2023",
    metrics: {
      progress: 60,
      contentPieces: 8,
      channels: ["Social", "Display", "YouTube"],
      budget: 40000,
      impressions: 300000,
      engagement: 3.8,
      conversions: 420
    }
  },
  {
    id: "4",
    title: "Customer Retention Email Series",
    description: "Automated email sequence for customer lifecycle management",
    status: "completed" as CampaignStatus,
    createdAt: "Nov 5, 2023",
    metrics: {
      progress: 100,
      contentPieces: 15,
      channels: ["Email"],
      budget: 5000,
      impressions: 75000,
      engagement: 8.5,
      conversions: 1200
    }
  }
]

// Calculate stats from sample campaigns
const campaignStats = {
  totalCampaigns: sampleCampaigns.length,
  activeCampaigns: sampleCampaigns.filter(c => c.status === 'active').length,
  totalBudget: sampleCampaigns.reduce((sum, c) => sum + (c.metrics.budget || 0), 0),
  totalImpressions: sampleCampaigns.reduce((sum, c) => sum + (c.metrics.impressions || 0), 0),
  avgEngagement: sampleCampaigns.reduce((sum, c) => sum + (c.metrics.engagement || 0), 0) / 
    sampleCampaigns.filter(c => c.metrics.engagement).length,
  totalConversions: sampleCampaigns.reduce((sum, c) => sum + (c.metrics.conversions || 0), 0),
  conversionTrend: 8.5, // mock trend data
  budgetUtilization: 75 // mock utilization data
}

export default function CampaignsPage() {
  const [isLoading, setIsLoading] = useState(false)
  const [loadingCampaigns, setLoadingCampaigns] = useState<Set<string>>(new Set())
  const [error, setError] = useState<Error | null>(null)

  const handleEdit = (id: string) => {
    console.log("Edit campaign:", id)
  }

  const handleStatusChange = async (id: string, newStatus: CampaignStatus) => {
    console.log("Status change for campaign:", id, "to:", newStatus)
    
    setLoadingCampaigns(prev => new Set(prev).add(id))
    
    try {
      // Simulate API call
      await new Promise((resolve, reject) => {
        setTimeout(() => {
          // Simulate occasional failures for demonstration
          if (Math.random() > 0.8) {
            reject(new Error("Network error occurred"))
          } else {
            resolve(undefined)
          }
        }, 1000)
      })
      
      // Update would happen here in real implementation
      setError(null)
    } catch (err) {
      setError(err as Error)
      throw err // Re-throw to let optimistic UI handle rollback
    } finally {
      setLoadingCampaigns(prev => {
        const next = new Set(prev)
        next.delete(id)
        return next
      })
    }
  }

  const handleCopy = (id: string) => {
    console.log("Copy campaign:", id)
  }

  const handleDelete = (id: string) => {
    console.log("Delete campaign:", id)
  }

  return (
    <ErrorBoundary>
      <div className="space-y-6">
        {/* Page Header */}
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Campaigns</h1>
            <p className="text-muted-foreground">
              Manage and organize your marketing campaigns
            </p>
          </div>
          <div className="flex items-center gap-2">
            <div className="flex items-center border rounded-lg p-1">
              <Button variant="default" size="sm" className="h-7 px-2">
                <LayoutGrid className="h-4 w-4" />
              </Button>
              <Link href="/campaigns/list">
                <Button variant="ghost" size="sm" className="h-7 px-2">
                  <List className="h-4 w-4" />
                </Button>
              </Link>
            </div>
            <Button>
              <Plus className="h-4 w-4 mr-2" />
              New Campaign
            </Button>
          </div>
        </div>

        {/* Error Display */}
        {error && (
          <ErrorDisplay
            error={error}
            title="Failed to update campaign"
            onDismiss={() => setError(null)}
            onRetry={() => setError(null)}
          />
        )}

        {/* Campaign Stats */}
        {isLoading ? <CampaignStatsSkeleton /> : <CampaignStats stats={campaignStats} />}

      {/* Search and Filters */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search campaigns..."
            className="pl-8"
          />
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm">
            <Filter className="h-4 w-4 mr-2" />
            Filter
          </Button>
        </div>
      </div>

        {/* Campaigns Grid */}
        <div className="grid gap-6">
          {isLoading ? (
            Array.from({ length: 3 }).map((_, i) => (
              <CampaignCardSkeleton key={i} />
            ))
          ) : (
            sampleCampaigns.map((campaign) => (
              <CampaignCard
                key={campaign.id}
                id={campaign.id}
                title={campaign.title}
                description={campaign.description}
                status={campaign.status}
                createdAt={campaign.createdAt}
                metrics={campaign.metrics}
                onEdit={handleEdit}
                onStatusChange={handleStatusChange}
                onCopy={handleCopy}
                onDelete={handleDelete}
                isLoading={loadingCampaigns.has(campaign.id)}
                loadingActions={loadingCampaigns.has(campaign.id) ? [`status-${campaign.status}`] : []}
              />
            ))
          )}
        </div>

        {/* Empty State (shown when no campaigns) */}
        {/* <div className="flex flex-col items-center justify-center py-12 text-center">
          <Target className="h-12 w-12 text-muted-foreground mb-4" />
          <h3 className="text-lg font-semibold mb-2">No campaigns yet</h3>
          <p className="text-muted-foreground mb-6 max-w-sm">
            Get started by creating your first marketing campaign with AI-powered content generation.
          </p>
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            Create Your First Campaign
          </Button>
        </div> */}
      </div>
    </ErrorBoundary>
  )
}