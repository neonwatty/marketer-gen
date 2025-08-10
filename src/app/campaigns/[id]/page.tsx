import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Separator } from "@/components/ui/separator"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { 
  ArrowLeft, 
  Edit, 
  Play, 
  Pause, 
  Copy, 
  Trash2, 
  MoreHorizontal,
  Calendar,
  DollarSign,
  Target,
  TrendingUp,
  Users,
  MessageCircle,
  Mail,
  Share2
} from "lucide-react"
import Link from "next/link"
import { CampaignJourneyVisualization } from "@/components/campaigns/campaign-journey-visualization"
import { CampaignMetricsPanel } from "@/components/campaigns/campaign-metrics-panel"
import { CampaignContentList } from "@/components/campaigns/campaign-content-list"
import { CampaignTimelineActivity } from "@/components/campaigns/campaign-timeline-activity"
import { 
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { type CampaignStatus } from "@/components/ui/campaign-card"

// Mock campaign data - in a real app, this would come from an API
const mockCampaign = {
  id: "1",
  title: "Summer Product Launch",
  description: "Multi-channel campaign for new product line launch targeting millennials with focus on sustainability and lifestyle integration",
  status: "active" as CampaignStatus,
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
  targetAudience: {
    demographics: {
      ageRange: "25-34",
      gender: "all",
      location: "United States, Canada"
    },
    description: "Environmentally conscious millennials interested in sustainable living, outdoor activities, and premium lifestyle products"
  },
  contentStrategy: {
    contentTypes: ["blog-post", "social-post", "email-newsletter", "landing-page"],
    frequency: "weekly",
    tone: "friendly"
  },
  messaging: {
    primaryMessage: "Discover sustainable living with our eco-friendly product line designed for the modern lifestyle",
    callToAction: "Shop Sustainable",
    valueProposition: "Premium quality meets environmental responsibility"
  },
  metrics: {
    progress: 75,
    contentPieces: 12,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850,
    clickThroughRate: 3.1,
    costPerConversion: 22.06
  },
  journey: {
    stages: [
      {
        id: "awareness",
        name: "Awareness",
        description: "Brand introduction and problem recognition",
        status: "completed",
        channels: ["Blog", "Social Media", "Display Ads"],
        contentCount: 8,
        metrics: { impressions: 75000, engagement: 3.8 }
      },
      {
        id: "consideration",
        name: "Consideration",
        description: "Product evaluation and comparison",
        status: "active",
        channels: ["Email", "Social Media", "Blog"],
        contentCount: 6,
        metrics: { impressions: 40000, engagement: 5.2 }
      },
      {
        id: "conversion",
        name: "Conversion",
        description: "Purchase decision and action",
        status: "active",
        channels: ["Email", "Landing Pages"],
        contentCount: 4,
        metrics: { impressions: 10000, engagement: 6.8 }
      },
      {
        id: "retention",
        name: "Retention",
        description: "Post-purchase engagement and loyalty",
        status: "pending",
        channels: ["Email", "Social Media"],
        contentCount: 0,
        metrics: { impressions: 0, engagement: 0 }
      }
    ]
  }
}

interface CampaignDetailPageProps {
  params: { id: string }
}

export default function CampaignDetailPage({ params }: CampaignDetailPageProps) {
  const campaign = mockCampaign // In real app, fetch by params.id

  const handleStatusChange = (newStatus: CampaignStatus) => {
    console.log("Status change to:", newStatus)
  }

  const handleEdit = () => {
    console.log("Edit campaign:", params.id)
  }

  const handleCopy = () => {
    console.log("Copy campaign:", params.id)
  }

  const handleDelete = () => {
    console.log("Delete campaign:", params.id)
  }

  const getStatusColor = (status: CampaignStatus) => {
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

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: campaign.budget.currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/campaigns">
            <Button variant="ghost" size="sm">
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Campaigns
            </Button>
          </Link>
          <div>
            <div className="flex items-center gap-3">
              <h1 className="text-2xl font-bold tracking-tight">{campaign.title}</h1>
              <Badge className={getStatusColor(campaign.status)}>
                {campaign.status.charAt(0).toUpperCase() + campaign.status.slice(1)}
              </Badge>
            </div>
            <p className="text-muted-foreground mt-1">{campaign.description}</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={handleEdit}>
            <Edit className="h-4 w-4 mr-2" />
            Edit Campaign
          </Button>
          
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="icon">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {campaign.status === "active" && (
                <DropdownMenuItem onClick={() => handleStatusChange("paused")}>
                  <Pause className="h-4 w-4 mr-2" />
                  Pause Campaign
                </DropdownMenuItem>
              )}
              {campaign.status === "paused" && (
                <DropdownMenuItem onClick={() => handleStatusChange("active")}>
                  <Play className="h-4 w-4 mr-2" />
                  Resume Campaign
                </DropdownMenuItem>
              )}
              {campaign.status === "draft" && (
                <DropdownMenuItem onClick={() => handleStatusChange("active")}>
                  <Play className="h-4 w-4 mr-2" />
                  Launch Campaign
                </DropdownMenuItem>
              )}
              <DropdownMenuItem onClick={handleCopy}>
                <Copy className="h-4 w-4 mr-2" />
                Duplicate Campaign
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem 
                onClick={handleDelete}
                className="text-red-600 focus:text-red-600"
              >
                <Trash2 className="h-4 w-4 mr-2" />
                Delete Campaign
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {/* Campaign Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Budget</p>
                <div className="flex items-baseline gap-2">
                  <p className="text-2xl font-bold">{formatCurrency(campaign.budget.spent)}</p>
                  <p className="text-sm text-muted-foreground">/ {formatCurrency(campaign.budget.total)}</p>
                </div>
              </div>
              <DollarSign className="h-8 w-8 text-green-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Impressions</p>
                <p className="text-2xl font-bold">{campaign.metrics.impressions.toLocaleString()}</p>
              </div>
              <Users className="h-8 w-8 text-blue-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Engagement Rate</p>
                <p className="text-2xl font-bold">{campaign.metrics.engagement}%</p>
              </div>
              <TrendingUp className="h-8 w-8 text-orange-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Conversions</p>
                <p className="text-2xl font-bold">{campaign.metrics.conversions}</p>
              </div>
              <Target className="h-8 w-8 text-purple-600" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Content Tabs */}
      <Tabs defaultValue="overview" className="space-y-6">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="journey">Customer Journey</TabsTrigger>
          <TabsTrigger value="content">Content</TabsTrigger>
          <TabsTrigger value="metrics">Analytics</TabsTrigger>
          <TabsTrigger value="settings">Settings</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Campaign Details */}
            <div className="lg:col-span-2 space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle>Campaign Information</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="text-sm font-medium text-muted-foreground">Start Date</label>
                      <div className="flex items-center gap-2 mt-1">
                        <Calendar className="h-4 w-4 text-muted-foreground" />
                        <span>{new Date(campaign.startDate).toLocaleDateString()}</span>
                      </div>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-muted-foreground">End Date</label>
                      <div className="flex items-center gap-2 mt-1">
                        <Calendar className="h-4 w-4 text-muted-foreground" />
                        <span>{new Date(campaign.endDate).toLocaleDateString()}</span>
                      </div>
                    </div>
                  </div>

                  <Separator />

                  <div>
                    <label className="text-sm font-medium text-muted-foreground">Objectives</label>
                    <div className="flex flex-wrap gap-2 mt-2">
                      {campaign.objectives.map((objective) => (
                        <Badge key={objective} variant="secondary">
                          {objective.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                        </Badge>
                      ))}
                    </div>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-muted-foreground">Channels</label>
                    <div className="flex flex-wrap gap-2 mt-2">
                      {campaign.channels.map((channel) => (
                        <Badge key={channel} variant="outline">
                          {channel}
                        </Badge>
                      ))}
                    </div>
                  </div>

                  <Separator />

                  <div>
                    <label className="text-sm font-medium text-muted-foreground">Primary Message</label>
                    <p className="mt-1 text-sm">{campaign.messaging.primaryMessage}</p>
                  </div>

                  <div>
                    <label className="text-sm font-medium text-muted-foreground">Call to Action</label>
                    <p className="mt-1 text-sm font-medium">&ldquo;{campaign.messaging.callToAction}&rdquo;</p>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Target Audience</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                      <label className="text-sm font-medium text-muted-foreground">Age Range</label>
                      <p className="mt-1">{campaign.targetAudience.demographics.ageRange} years</p>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-muted-foreground">Gender</label>
                      <p className="mt-1 capitalize">{campaign.targetAudience.demographics.gender}</p>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-muted-foreground">Location</label>
                      <p className="mt-1">{campaign.targetAudience.demographics.location}</p>
                    </div>
                  </div>
                  
                  <div>
                    <label className="text-sm font-medium text-muted-foreground">Description</label>
                    <p className="mt-1 text-sm">{campaign.targetAudience.description}</p>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Activity Timeline */}
            <div>
              <CampaignTimelineActivity campaignId={campaign.id} />
            </div>
          </div>
        </TabsContent>

        <TabsContent value="journey" className="space-y-6">
          <CampaignJourneyVisualization journey={campaign.journey} />
        </TabsContent>

        <TabsContent value="content" className="space-y-6">
          <CampaignContentList campaignId={campaign.id} />
        </TabsContent>

        <TabsContent value="metrics" className="space-y-6">
          <CampaignMetricsPanel campaign={campaign} />
        </TabsContent>

        <TabsContent value="settings" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Campaign Settings</CardTitle>
              <CardDescription>
                Manage campaign configuration and preferences
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-muted-foreground">Campaign settings panel will be implemented here.</p>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}