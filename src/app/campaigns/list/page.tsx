"use client"

import { CampaignDataTable, type CampaignTableData } from "@/components/ui/campaign-data-table"
import { CampaignStats } from "@/components/ui/campaign-stats"
import { Button } from "@/components/ui/button"
import { Plus, LayoutGrid, List } from "lucide-react"
import Link from "next/link"

// Sample campaign data - in a real app, this would come from an API or database
const sampleCampaigns: CampaignTableData[] = [
  {
    id: "1",
    title: "Summer Product Launch",
    description: "Multi-channel campaign for new product line launch targeting millennials",
    status: "active",
    createdAt: "Jan 15, 2024",
    progress: 75,
    contentPieces: 12,
    channels: ["Email", "Social", "Blog", "Display"],
    budget: 25000,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850
  },
  {
    id: "2", 
    title: "Holiday Sale Campaign",
    description: "Black Friday and Cyber Monday promotional campaign with aggressive discounts",
    status: "draft",
    createdAt: "Jan 20, 2024",
    progress: 25,
    contentPieces: 3,
    channels: ["Email", "Social"],
    budget: 15000
  },
  {
    id: "3",
    title: "Brand Awareness Q1",
    description: "Multi-touch brand awareness campaign targeting millennials and Gen Z",
    status: "paused",
    createdAt: "Dec 10, 2023",
    progress: 60,
    contentPieces: 8,
    channels: ["Social", "Display", "YouTube", "Influencer"],
    budget: 40000,
    impressions: 300000,
    engagement: 3.8,
    conversions: 420
  },
  {
    id: "4",
    title: "Customer Retention Email Series",
    description: "Automated email sequence for customer lifecycle management and retention",
    status: "completed",
    createdAt: "Nov 5, 2023",
    progress: 100,
    contentPieces: 15,
    channels: ["Email"],
    budget: 5000,
    impressions: 75000,
    engagement: 8.5,
    conversions: 1200
  },
  {
    id: "5",
    title: "Product Demo Webinar Series",
    description: "Monthly webinar series showcasing product features and use cases",
    status: "active",
    createdAt: "Oct 15, 2023",
    progress: 90,
    contentPieces: 6,
    channels: ["Webinar", "Email", "Social"],
    budget: 8000,
    impressions: 45000,
    engagement: 12.3,
    conversions: 180
  },
  {
    id: "6",
    title: "Spring Newsletter Campaign",
    description: "Quarterly newsletter highlighting company updates and industry insights",
    status: "draft",
    createdAt: "Feb 1, 2024",
    progress: 10,
    contentPieces: 1,
    channels: ["Email"],
    budget: 2000
  },
  {
    id: "7",
    title: "Partnership Announcement",
    description: "Multi-channel announcement of strategic partnership with key industry player",
    status: "completed",
    createdAt: "Sep 20, 2023",
    progress: 100,
    contentPieces: 8,
    channels: ["Email", "Social", "Blog", "PR"],
    budget: 12000,
    impressions: 85000,
    engagement: 6.7,
    conversions: 320
  },
  {
    id: "8",
    title: "Mobile App Launch",
    description: "Comprehensive campaign for new mobile application launch across all channels",
    status: "cancelled",
    createdAt: "Aug 10, 2023",
    progress: 45,
    contentPieces: 5,
    channels: ["Social", "Display", "Influencer"],
    budget: 35000
  }
]

// Calculate stats from sample campaigns
const campaignStats = {
  totalCampaigns: sampleCampaigns.length,
  activeCampaigns: sampleCampaigns.filter(c => c.status === 'active').length,
  totalBudget: sampleCampaigns.reduce((sum, c) => sum + (c.budget || 0), 0),
  totalImpressions: sampleCampaigns.reduce((sum, c) => sum + (c.impressions || 0), 0),
  avgEngagement: sampleCampaigns.reduce((sum, c) => sum + (c.engagement || 0), 0) / 
    sampleCampaigns.filter(c => c.engagement).length,
  totalConversions: sampleCampaigns.reduce((sum, c) => sum + (c.conversions || 0), 0),
  conversionTrend: 8.5, // mock trend data
  budgetUtilization: 75 // mock utilization data
}

export default function CampaignsListPage() {
  const handleView = (campaign: CampaignTableData) => {
    console.log("View campaign:", campaign.id)
  }

  const handleEdit = (campaign: CampaignTableData) => {
    console.log("Edit campaign:", campaign.id)
  }

  const handleCopy = (campaign: CampaignTableData) => {
    console.log("Copy campaign:", campaign.id)
  }

  const handleDelete = (campaign: CampaignTableData) => {
    console.log("Delete campaign:", campaign.id)
  }

  const handleExport = () => {
    console.log("Export campaigns data")
    // In a real app, this would trigger a CSV/Excel export
  }

  return (
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
            <Link href="/campaigns">
              <Button variant="ghost" size="sm" className="h-7 px-2">
                <LayoutGrid className="h-4 w-4" />
              </Button>
            </Link>
            <Button variant="default" size="sm" className="h-7 px-2">
              <List className="h-4 w-4" />
            </Button>
          </div>
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            New Campaign
          </Button>
        </div>
      </div>

      {/* Campaign Stats */}
      <CampaignStats stats={campaignStats} />

      {/* Data Table */}
      <CampaignDataTable
        data={sampleCampaigns}
        onView={handleView}
        onEdit={handleEdit}
        onCopy={handleCopy}
        onDelete={handleDelete}
        onExport={handleExport}
      />
    </div>
  )
}