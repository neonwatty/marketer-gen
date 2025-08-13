"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { Separator } from "@/components/ui/separator"
import { 
  ChevronLeft, 
  ChevronRight, 
  Maximize2, 
  Minimize2, 
  Download, 
  Printer, 
  Share2,
  FileText,
  Presentation,
  Calendar,
  DollarSign,
  Target,
  TrendingUp,
  Users,
  MessageCircle,
  CheckCircle,
  AlertTriangle,
  BarChart3,
  PieChart,
  Activity,
  Globe,
  Mail,
  MousePointer,
  Eye
} from "lucide-react"

interface Campaign {
  id: string
  title: string
  description: string
  status: string
  startDate: string
  endDate: string
  budget: {
    total: number
    spent: number
    currency: string
  }
  objectives: string[]
  channels: string[]
  targetAudience: {
    demographics: {
      ageRange: string
      gender: string
      location: string
    }
    description: string
  }
  messaging: {
    primaryMessage: string
    callToAction: string
    valueProposition: string
  }
  metrics: {
    progress: number
    contentPieces: number
    impressions: number
    engagement: number
    conversions: number
    clickThroughRate: number
    costPerConversion: number
  }
  journey: {
    stages: Array<{
      id: string
      name: string
      description: string
      status: string
      channels: string[]
      contentCount: number
      metrics: { impressions: number; engagement: number }
    }>
  }
}

interface StakeholderPresentationProps {
  campaign: Campaign
  className?: string
}

interface Slide {
  id: string
  title: string
  type: 'overview' | 'metrics' | 'journey' | 'budget' | 'audience' | 'performance' | 'recommendations'
  component: React.ComponentType<{ campaign: Campaign }>
}

// Slide Components
function OverviewSlide({ campaign }: { campaign: Campaign }) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: campaign.budget.currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case "active":
        return "bg-green-100 text-green-800 border-green-200"
      case "draft":
        return "bg-slate-100 text-slate-800 border-slate-200"
      case "paused":
        return "bg-yellow-100 text-yellow-800 border-yellow-200"
      case "completed":
        return "bg-blue-100 text-blue-800 border-blue-200"
      default:
        return "bg-slate-100 text-slate-800 border-slate-200"
    }
  }

  return (
    <div className="h-full flex flex-col justify-center space-y-8 p-16">
      <div className="text-center space-y-4">
        <div className="flex items-center justify-center gap-4">
          <h1 className="text-6xl font-bold text-gray-900">{campaign.title}</h1>
          <Badge className={cn("text-lg px-4 py-2", getStatusColor(campaign.status))}>
            {campaign.status.charAt(0).toUpperCase() + campaign.status.slice(1)}
          </Badge>
        </div>
        <p className="text-2xl text-gray-600 max-w-4xl mx-auto">{campaign.description}</p>
      </div>

      <div className="grid grid-cols-4 gap-8 max-w-6xl mx-auto">
        <Card className="text-center p-6">
          <CardContent className="p-0">
            <DollarSign className="h-12 w-12 text-green-600 mx-auto mb-4" />
            <p className="text-3xl font-bold text-gray-900">{formatCurrency(campaign.budget.spent)}</p>
            <p className="text-gray-600">of {formatCurrency(campaign.budget.total)} spent</p>
          </CardContent>
        </Card>

        <Card className="text-center p-6">
          <CardContent className="p-0">
            <Users className="h-12 w-12 text-blue-600 mx-auto mb-4" />
            <p className="text-3xl font-bold text-gray-900">{campaign.metrics.impressions.toLocaleString()}</p>
            <p className="text-gray-600">Total Impressions</p>
          </CardContent>
        </Card>

        <Card className="text-center p-6">
          <CardContent className="p-0">
            <TrendingUp className="h-12 w-12 text-orange-600 mx-auto mb-4" />
            <p className="text-3xl font-bold text-gray-900">{campaign.metrics.engagement}%</p>
            <p className="text-gray-600">Engagement Rate</p>
          </CardContent>
        </Card>

        <Card className="text-center p-6">
          <CardContent className="p-0">
            <Target className="h-12 w-12 text-purple-600 mx-auto mb-4" />
            <p className="text-3xl font-bold text-gray-900">{campaign.metrics.conversions}</p>
            <p className="text-gray-600">Conversions</p>
          </CardContent>
        </Card>
      </div>

      <div className="text-center">
        <Badge variant="outline" className="text-lg px-6 py-2">
          {new Date(campaign.startDate).toLocaleDateString()} - {new Date(campaign.endDate).toLocaleDateString()}
        </Badge>
      </div>
    </div>
  )
}

function MetricsSlide({ campaign }: { campaign: Campaign }) {
  const performanceMetrics = [
    {
      label: "Click-through Rate",
      value: `${campaign.metrics.clickThroughRate}%`,
      icon: <MousePointer className="h-8 w-8 text-blue-600" />,
      trend: "+12%",
      isPositive: true
    },
    {
      label: "Cost per Conversion",
      value: `$${campaign.metrics.costPerConversion}`,
      icon: <Target className="h-8 w-8 text-green-600" />,
      trend: "-8%",
      isPositive: true
    },
    {
      label: "Content Pieces",
      value: campaign.metrics.contentPieces.toString(),
      icon: <FileText className="h-8 w-8 text-purple-600" />,
      trend: "+25%",
      isPositive: true
    },
    {
      label: "Campaign Progress",
      value: `${campaign.metrics.progress}%`,
      icon: <Activity className="h-8 w-8 text-orange-600" />,
      trend: "On Track",
      isPositive: true
    }
  ]

  return (
    <div className="h-full p-16 space-y-12">
      <div className="text-center">
        <h2 className="text-5xl font-bold text-gray-900 mb-4">Performance Metrics</h2>
        <p className="text-xl text-gray-600">Key performance indicators and campaign progress</p>
      </div>

      <div className="grid grid-cols-2 gap-8 max-w-6xl mx-auto">
        {performanceMetrics.map((metric, index) => (
          <Card key={index} className="p-8 h-48 flex flex-col justify-center">
            <CardContent className="p-0 text-center space-y-4">
              <div className="flex items-center justify-center">
                {metric.icon}
              </div>
              <div>
                <p className="text-4xl font-bold text-gray-900">{metric.value}</p>
                <p className="text-gray-600 text-lg">{metric.label}</p>
              </div>
              <Badge 
                variant={metric.isPositive ? "default" : "destructive"}
                className="text-sm"
              >
                {metric.trend}
              </Badge>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="max-w-4xl mx-auto">
        <Card className="p-8">
          <CardContent className="p-0">
            <h3 className="text-2xl font-bold text-gray-900 mb-6 text-center">Campaign Progress</h3>
            <div className="space-y-4">
              <div className="flex justify-between text-lg">
                <span>Overall Completion</span>
                <span className="font-bold">{campaign.metrics.progress}%</span>
              </div>
              <Progress value={campaign.metrics.progress} className="h-4" />
              <div className="grid grid-cols-3 gap-4 text-center text-sm text-gray-600">
                <div>
                  <p className="font-medium">Started</p>
                  <p>{new Date(campaign.startDate).toLocaleDateString()}</p>
                </div>
                <div>
                  <p className="font-medium">Current</p>
                  <p>{new Date().toLocaleDateString()}</p>
                </div>
                <div>
                  <p className="font-medium">End Date</p>
                  <p>{new Date(campaign.endDate).toLocaleDateString()}</p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function JourneySlide({ campaign }: { campaign: Campaign }) {
  const getStageIcon = (stageId: string) => {
    switch (stageId) {
      case "awareness":
        return <Eye className="h-8 w-8" />
      case "consideration":
        return <MessageCircle className="h-8 w-8" />
      case "conversion":
        return <Target className="h-8 w-8" />
      case "retention":
        return <Users className="h-8 w-8" />
      default:
        return <Activity className="h-8 w-8" />
    }
  }

  const getStageColor = (status: string) => {
    switch (status) {
      case "completed":
        return "bg-green-100 text-green-800 border-green-200"
      case "active":
        return "bg-blue-100 text-blue-800 border-blue-200"
      case "pending":
        return "bg-gray-100 text-gray-800 border-gray-200"
      default:
        return "bg-gray-100 text-gray-800 border-gray-200"
    }
  }

  return (
    <div className="h-full p-16 space-y-12">
      <div className="text-center">
        <h2 className="text-5xl font-bold text-gray-900 mb-4">Customer Journey</h2>
        <p className="text-xl text-gray-600">Multi-stage campaign strategy and performance</p>
      </div>

      <div className="grid grid-cols-2 gap-8 max-w-6xl mx-auto">
        {campaign.journey.stages.map((stage, index) => (
          <Card key={stage.id} className="p-8 h-64">
            <CardContent className="p-0 h-full flex flex-col justify-between">
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className={cn("p-3 rounded-full", getStageColor(stage.status))}>
                      {getStageIcon(stage.id)}
                    </div>
                    <div>
                      <h3 className="text-2xl font-bold text-gray-900">{stage.name}</h3>
                      <Badge className={getStageColor(stage.status)}>
                        {stage.status.charAt(0).toUpperCase() + stage.status.slice(1)}
                      </Badge>
                    </div>
                  </div>
                </div>
                
                <p className="text-gray-600">{stage.description}</p>
                
                <div className="grid grid-cols-2 gap-4">
                  <div className="text-center">
                    <p className="text-2xl font-bold text-gray-900">{stage.metrics.impressions.toLocaleString()}</p>
                    <p className="text-sm text-gray-600">Impressions</p>
                  </div>
                  <div className="text-center">
                    <p className="text-2xl font-bold text-gray-900">{stage.metrics.engagement}%</p>
                    <p className="text-sm text-gray-600">Engagement</p>
                  </div>
                </div>
              </div>

              <div>
                <div className="flex flex-wrap gap-1 mb-2">
                  {stage.channels.slice(0, 3).map((channel) => (
                    <Badge key={channel} variant="outline" className="text-xs">
                      {channel}
                    </Badge>
                  ))}
                  {stage.channels.length > 3 && (
                    <Badge variant="outline" className="text-xs">
                      +{stage.channels.length - 3} more
                    </Badge>
                  )}
                </div>
                <p className="text-sm text-gray-600">{stage.contentCount} content pieces</p>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}

function BudgetSlide({ campaign }: { campaign: Campaign }) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: campaign.budget.currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const spentPercentage = (campaign.budget.spent / campaign.budget.total) * 100
  const remaining = campaign.budget.total - campaign.budget.spent

  // Mock budget breakdown data
  const budgetBreakdown = [
    { category: "Content Creation", amount: 8000, percentage: 32, color: "bg-blue-500" },
    { category: "Paid Advertising", amount: 7500, percentage: 30, color: "bg-green-500" },
    { category: "Design & Creative", amount: 4000, percentage: 16, color: "bg-purple-500" },
    { category: "Tools & Software", amount: 3000, percentage: 12, color: "bg-orange-500" },
    { category: "Personnel", amount: 2500, percentage: 10, color: "bg-red-500" }
  ]

  return (
    <div className="h-full p-16 space-y-12">
      <div className="text-center">
        <h2 className="text-5xl font-bold text-gray-900 mb-4">Budget Overview</h2>
        <p className="text-xl text-gray-600">Financial allocation and spending analysis</p>
      </div>

      <div className="grid grid-cols-3 gap-8 max-w-6xl mx-auto">
        <Card className="p-8 text-center">
          <CardContent className="p-0 space-y-4">
            <DollarSign className="h-16 w-16 text-blue-600 mx-auto" />
            <div>
              <p className="text-4xl font-bold text-gray-900">{formatCurrency(campaign.budget.total)}</p>
              <p className="text-gray-600 text-lg">Total Budget</p>
            </div>
          </CardContent>
        </Card>

        <Card className="p-8 text-center">
          <CardContent className="p-0 space-y-4">
            <TrendingUp className="h-16 w-16 text-green-600 mx-auto" />
            <div>
              <p className="text-4xl font-bold text-gray-900">{formatCurrency(campaign.budget.spent)}</p>
              <p className="text-gray-600 text-lg">Spent ({spentPercentage.toFixed(0)}%)</p>
            </div>
          </CardContent>
        </Card>

        <Card className="p-8 text-center">
          <CardContent className="p-0 space-y-4">
            <Activity className="h-16 w-16 text-orange-600 mx-auto" />
            <div>
              <p className="text-4xl font-bold text-gray-900">{formatCurrency(remaining)}</p>
              <p className="text-gray-600 text-lg">Remaining</p>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="max-w-4xl mx-auto space-y-8">
        <Card className="p-8">
          <CardContent className="p-0">
            <h3 className="text-2xl font-bold text-gray-900 mb-6 text-center">Budget Progress</h3>
            <div className="space-y-4">
              <Progress value={spentPercentage} className="h-6" />
              <div className="flex justify-between text-lg">
                <span className="text-gray-600">Spent: {formatCurrency(campaign.budget.spent)}</span>
                <span className="text-gray-600">Remaining: {formatCurrency(remaining)}</span>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="p-8">
          <CardContent className="p-0">
            <h3 className="text-2xl font-bold text-gray-900 mb-6 text-center">Budget Allocation</h3>
            <div className="space-y-4">
              {budgetBreakdown.map((item, index) => (
                <div key={index} className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-4">
                    <div className={cn("w-4 h-4 rounded", item.color)}></div>
                    <span className="font-medium text-gray-900">{item.category}</span>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-gray-900">{formatCurrency(item.amount)}</p>
                    <p className="text-sm text-gray-600">{item.percentage}%</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function AudienceSlide({ campaign }: { campaign: Campaign }) {
  return (
    <div className="h-full p-16 space-y-12">
      <div className="text-center">
        <h2 className="text-5xl font-bold text-gray-900 mb-4">Target Audience</h2>
        <p className="text-xl text-gray-600">Demographic profile and audience insights</p>
      </div>

      <div className="max-w-6xl mx-auto grid grid-cols-2 gap-12">
        <Card className="p-8 h-96">
          <CardContent className="p-0 h-full flex flex-col justify-center space-y-8">
            <h3 className="text-3xl font-bold text-gray-900 text-center">Demographics</h3>
            
            <div className="space-y-6">
              <div className="text-center p-6 bg-blue-50 rounded-lg">
                <Users className="h-12 w-12 text-blue-600 mx-auto mb-3" />
                <p className="text-2xl font-bold text-gray-900">{campaign.targetAudience.demographics.ageRange} years</p>
                <p className="text-gray-600">Age Range</p>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="text-center p-4 bg-purple-50 rounded-lg">
                  <p className="text-lg font-bold text-gray-900 capitalize">{campaign.targetAudience.demographics.gender}</p>
                  <p className="text-sm text-gray-600">Gender</p>
                </div>
                <div className="text-center p-4 bg-green-50 rounded-lg">
                  <Globe className="h-6 w-6 text-green-600 mx-auto mb-1" />
                  <p className="text-sm text-gray-600">Location</p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="p-8 h-96">
          <CardContent className="p-0 h-full flex flex-col justify-center space-y-6">
            <h3 className="text-3xl font-bold text-gray-900 text-center">Audience Profile</h3>
            
            <div className="space-y-6">
              <div className="p-6 bg-gray-50 rounded-lg">
                <MessageCircle className="h-8 w-8 text-blue-600 mb-4" />
                <p className="text-gray-700 leading-relaxed">{campaign.targetAudience.description}</p>
              </div>

              <div className="p-6 bg-orange-50 rounded-lg">
                <p className="text-sm font-medium text-gray-700 mb-2">Geographic Focus</p>
                <p className="text-lg font-bold text-gray-900">{campaign.targetAudience.demographics.location}</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="max-w-4xl mx-auto">
        <Card className="p-8">
          <CardContent className="p-0">
            <h3 className="text-2xl font-bold text-gray-900 mb-6 text-center">Campaign Channels</h3>
            <div className="grid grid-cols-4 gap-4">
              {campaign.channels.map((channel, index) => (
                <div key={index} className="text-center p-4 bg-blue-50 rounded-lg">
                  <div className="h-12 w-12 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-3">
                    {channel === "Email" && <Mail className="h-6 w-6 text-blue-600" />}
                    {channel === "Social Media" && <Share2 className="h-6 w-6 text-blue-600" />}
                    {channel === "Blog" && <FileText className="h-6 w-6 text-blue-600" />}
                    {channel === "Display Ads" && <MousePointer className="h-6 w-6 text-blue-600" />}
                  </div>
                  <p className="font-medium text-gray-900">{channel}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function RecommendationsSlide({ campaign }: { campaign: Campaign }) {
  const recommendations = [
    {
      title: "Increase Social Media Budget",
      description: "Social channels showing 23% higher engagement than projected. Consider reallocating 15% more budget.",
      priority: "High",
      impact: "Revenue +12%",
      icon: <TrendingUp className="h-8 w-8 text-green-600" />
    },
    {
      title: "Optimize Email Content",
      description: "Email open rates below benchmark. A/B test subject lines and personalization strategies.",
      priority: "Medium",
      impact: "Engagement +8%",
      icon: <Mail className="h-8 w-8 text-blue-600" />
    },
    {
      title: "Extend Campaign Duration",
      description: "Strong performance metrics suggest extending campaign by 2 weeks for optimal ROI.",
      priority: "Medium",
      impact: "Conversions +15%",
      icon: <Calendar className="h-8 w-8 text-purple-600" />
    },
    {
      title: "Create Lookalike Audiences",
      description: "High-performing audience segments identified. Create lookalike audiences for broader reach.",
      priority: "Low",
      impact: "Reach +25%",
      icon: <Users className="h-8 w-8 text-orange-600" />
    }
  ]

  const getPriorityColor = (priority: string) => {
    switch (priority.toLowerCase()) {
      case "high":
        return "bg-red-100 text-red-800 border-red-200"
      case "medium":
        return "bg-yellow-100 text-yellow-800 border-yellow-200"
      case "low":
        return "bg-green-100 text-green-800 border-green-200"
      default:
        return "bg-gray-100 text-gray-800 border-gray-200"
    }
  }

  return (
    <div className="h-full p-16 space-y-12">
      <div className="text-center">
        <h2 className="text-5xl font-bold text-gray-900 mb-4">Recommendations</h2>
        <p className="text-xl text-gray-600">AI-powered insights and optimization suggestions</p>
      </div>

      <div className="grid grid-cols-2 gap-8 max-w-6xl mx-auto">
        {recommendations.map((rec, index) => (
          <Card key={index} className="p-6 h-64">
            <CardContent className="p-0 h-full flex flex-col justify-between">
              <div className="space-y-4">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    {rec.icon}
                    <div>
                      <h3 className="text-xl font-bold text-gray-900">{rec.title}</h3>
                      <Badge className={getPriorityColor(rec.priority)}>
                        {rec.priority} Priority
                      </Badge>
                    </div>
                  </div>
                </div>
                
                <p className="text-gray-600 text-sm leading-relaxed">{rec.description}</p>
              </div>

              <div className="flex justify-between items-center pt-4 border-t">
                <Badge variant="outline" className="text-green-700 bg-green-50">
                  {rec.impact}
                </Badge>
                <Button size="sm" variant="outline">
                  Implement
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="max-w-4xl mx-auto">
        <Card className="p-8 bg-blue-50 border-blue-200">
          <CardContent className="p-0 text-center">
            <CheckCircle className="h-16 w-16 text-blue-600 mx-auto mb-4" />
            <h3 className="text-2xl font-bold text-gray-900 mb-4">Next Steps</h3>
            <p className="text-gray-700 text-lg mb-6">
              Implement high-priority recommendations within the next 2 weeks for optimal campaign performance.
            </p>
            <div className="flex justify-center gap-4">
              <Button className="bg-blue-600 hover:bg-blue-700">
                Schedule Review Meeting
              </Button>
              <Button variant="outline">
                Download Action Plan
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

// Main component
export function StakeholderPresentation({ campaign, className }: StakeholderPresentationProps) {
  const [currentSlide, setCurrentSlide] = React.useState(0)
  const [isFullscreen, setIsFullscreen] = React.useState(false)

  const slides: Slide[] = [
    { id: 'overview', title: 'Campaign Overview', type: 'overview', component: OverviewSlide },
    { id: 'metrics', title: 'Performance Metrics', type: 'metrics', component: MetricsSlide },
    { id: 'journey', title: 'Customer Journey', type: 'journey', component: JourneySlide },
    { id: 'budget', title: 'Budget Analysis', type: 'budget', component: BudgetSlide },
    { id: 'audience', title: 'Target Audience', type: 'audience', component: AudienceSlide },
    { id: 'recommendations', title: 'Recommendations', type: 'recommendations', component: RecommendationsSlide }
  ]

  const nextSlide = () => {
    setCurrentSlide((prev) => (prev + 1) % slides.length)
  }

  const prevSlide = () => {
    setCurrentSlide((prev) => (prev - 1 + slides.length) % slides.length)
  }

  const toggleFullscreen = () => {
    if (!isFullscreen) {
      document.documentElement.requestFullscreen?.()
    } else {
      document.exitFullscreen?.()
    }
    setIsFullscreen(!isFullscreen)
  }

  const handleExport = (format: string) => {
    console.log(`Exporting presentation as ${format}`)
    // Implementation would depend on specific export requirements
  }

  const handleKeyPress = React.useCallback((event: KeyboardEvent) => {
    if (event.key === 'ArrowRight' || event.key === ' ') {
      nextSlide()
    } else if (event.key === 'ArrowLeft') {
      prevSlide()
    } else if (event.key === 'Escape') {
      setIsFullscreen(false)
    }
  }, [nextSlide, prevSlide])

  React.useEffect(() => {
    if (isFullscreen) {
      document.addEventListener('keydown', handleKeyPress)
      return () => document.removeEventListener('keydown', handleKeyPress)
    }
  }, [isFullscreen, handleKeyPress])

  const CurrentSlideComponent = slides[currentSlide].component

  return (
    <div className={cn("bg-white", className)}>
      {/* Presentation Controls */}
      {!isFullscreen && (
        <div className="flex items-center justify-between p-6 border-b bg-gray-50">
          <div className="flex items-center gap-4">
            <Presentation className="h-6 w-6 text-blue-600" />
            <div>
              <h2 className="text-xl font-bold text-gray-900">Stakeholder Presentation</h2>
              <p className="text-sm text-gray-600">{campaign.title}</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={() => handleExport('pdf')}>
              <FileText className="h-4 w-4 mr-2" />
              Export PDF
            </Button>
            <Button variant="outline" size="sm" onClick={() => handleExport('pptx')}>
              <Presentation className="h-4 w-4 mr-2" />
              Export PowerPoint
            </Button>
            <Button variant="outline" size="sm" onClick={() => handleExport('print')}>
              <Printer className="h-4 w-4 mr-2" />
              Print
            </Button>
            <Separator orientation="vertical" className="h-6" />
            <Button variant="outline" size="sm" onClick={toggleFullscreen}>
              <Maximize2 className="h-4 w-4 mr-2" />
              Present
            </Button>
          </div>
        </div>
      )}

      {/* Slide Navigation */}
      <div className="flex items-center justify-between p-4 bg-gray-100">
        <Button 
          variant="ghost" 
          size="sm" 
          onClick={prevSlide}
          disabled={currentSlide === 0}
        >
          <ChevronLeft className="h-4 w-4 mr-2" />
          Previous
        </Button>

        <div className="flex items-center gap-2">
          {slides.map((_, index) => (
            <button
              key={index}
              onClick={() => setCurrentSlide(index)}
              className={cn(
                "w-3 h-3 rounded-full transition-colors",
                currentSlide === index ? "bg-blue-600" : "bg-gray-300"
              )}
            />
          ))}
        </div>

        <Button 
          variant="ghost" 
          size="sm" 
          onClick={nextSlide}
          disabled={currentSlide === slides.length - 1}
        >
          Next
          <ChevronRight className="h-4 w-4 ml-2" />
        </Button>
      </div>

      {/* Slide Content */}
      <div className={cn(
        "bg-white transition-all duration-300",
        isFullscreen ? "h-screen" : "h-[600px]"
      )}>
        <CurrentSlideComponent campaign={campaign} />
      </div>

      {/* Fullscreen Controls */}
      {isFullscreen && (
        <div className="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-50">
          <div className="flex items-center gap-2 bg-black/80 text-white px-4 py-2 rounded-lg">
            <Button 
              variant="ghost" 
              size="sm" 
              onClick={prevSlide}
              disabled={currentSlide === 0}
              className="text-white hover:bg-white/20"
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            
            <span className="text-sm px-4">
              {currentSlide + 1} / {slides.length}
            </span>
            
            <Button 
              variant="ghost" 
              size="sm" 
              onClick={nextSlide}
              disabled={currentSlide === slides.length - 1}
              className="text-white hover:bg-white/20"
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
            
            <Separator orientation="vertical" className="h-6 bg-white/30" />
            
            <Button 
              variant="ghost" 
              size="sm" 
              onClick={toggleFullscreen}
              className="text-white hover:bg-white/20"
            >
              <Minimize2 className="h-4 w-4" />
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}