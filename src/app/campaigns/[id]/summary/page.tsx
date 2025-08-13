"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { ArrowLeft, Download, Share2, FileText, Presentation } from "lucide-react"
import Link from "next/link"
import { CampaignOverviewDashboard, type CampaignOverviewData } from "@/components/campaigns/campaign-overview-dashboard"
// Toast functionality - using alerts for now, replace with proper toast system later

// Extended mock campaign data for summary view
const mockCampaignData: CampaignOverviewData = {
  id: "1",
  title: "Summer Product Launch",
  description: "Multi-channel campaign for new product line launch targeting millennials with focus on sustainability and lifestyle integration",
  status: "active",
  createdAt: "2024-01-15",
  startDate: "2024-02-01", 
  endDate: "2024-04-30",
  budget: {
    total: 25000,
    spent: 18750,
    currency: "USD"
  },
  objectives: ["brand-awareness", "lead-generation", "sales-conversion"],
  channels: ["Email", "Social Media", "Blog", "Display Ads"],
  metrics: {
    progress: 75,
    contentPieces: 12,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850,
    clickThroughRate: 3.1,
    costPerConversion: 22.06,
    roi: 185
  },
  journey: {
    stages: [
      {
        id: "awareness",
        name: "Awareness",
        status: "completed",
        channels: ["Blog", "Social Media", "Display Ads"],
        contentCount: 8,
        metrics: { impressions: 75000, engagement: 3.8 }
      },
      {
        id: "consideration", 
        name: "Consideration",
        status: "active",
        channels: ["Email", "Social Media", "Blog"],
        contentCount: 6,
        metrics: { impressions: 40000, engagement: 5.2 }
      },
      {
        id: "conversion",
        name: "Conversion", 
        status: "active",
        channels: ["Email", "Landing Pages"],
        contentCount: 4,
        metrics: { impressions: 10000, engagement: 6.8 }
      },
      {
        id: "retention",
        name: "Retention",
        status: "pending", 
        channels: ["Email", "Social Media"],
        contentCount: 0,
        metrics: { impressions: 0, engagement: 0 }
      }
    ]
  }
}

interface CampaignSummaryPageProps {
  params: { id: string }
}

export default function CampaignSummaryPage({ params }: CampaignSummaryPageProps) {
  const [isExporting, setIsExporting] = useState(false)
  const campaign = mockCampaignData // In real app, fetch by params.id

  const handleExportSummary = async () => {
    setIsExporting(true)
    try {
      // Simulate export process
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      // In real implementation, this would generate and download a PDF/Excel file
      alert("Campaign summary exported successfully!")
    } catch (error) {
      alert("Failed to export campaign summary")
    } finally {
      setIsExporting(false)
    }
  }

  const handleShareSummary = () => {
    // In real implementation, this would open a share modal or copy link to clipboard
    navigator.clipboard.writeText(window.location.href)
    alert("Summary link copied to clipboard!")
  }

  const handlePresentationMode = () => {
    // In real implementation, this would open a presentation view
    alert("Presentation mode will be available soon!")
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case "active":
        return "bg-green-100 text-green-800 border-green-200"
      case "draft":
        return "bg-slate-100 text-slate-800 border-slate-200"
      case "paused":
        return "bg-yellow-100 text-yellow-800 border-yellow-200"
      case "completed":
        return "bg-blue-100 text-blue-800 border-blue-200"
      case "cancelled":
        return "bg-red-100 text-red-800 border-red-200"
      default:
        return "bg-slate-100 text-slate-800 border-slate-200"
    }
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container mx-auto px-4">
          <div className="flex h-14 items-center justify-between">
            <div className="flex items-center gap-4">
              <Link href={`/campaigns/${params.id}`}>
                <Button variant="ghost" size="sm">
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  Back to Campaign
                </Button>
              </Link>
              <div className="flex items-center gap-3">
                <h1 className="text-lg font-semibold">Campaign Summary</h1>
                <Badge className={getStatusColor(campaign.status)}>
                  {campaign.status.charAt(0).toUpperCase() + campaign.status.slice(1)}
                </Badge>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Button 
                variant="outline" 
                size="sm"
                onClick={handlePresentationMode}
              >
                <Presentation className="h-4 w-4 mr-2" />
                Present
              </Button>
              <Button 
                variant="outline" 
                size="sm"
                onClick={handleShareSummary}
              >
                <Share2 className="h-4 w-4 mr-2" />
                Share
              </Button>
              <Button 
                size="sm"
                onClick={handleExportSummary}
                disabled={isExporting}
              >
                <FileText className="h-4 w-4 mr-2" />
                {isExporting ? "Exporting..." : "Export Report"}
              </Button>
            </div>
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 py-8">
        <CampaignOverviewDashboard 
          campaign={campaign}
          onExport={handleExportSummary}
          onShare={handleShareSummary}
        />
      </div>
    </div>
  )
}