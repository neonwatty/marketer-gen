"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { Separator } from "@/components/ui/separator"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { 
  ArrowUpDown,
  BarChart3,
  TrendingUp,
  TrendingDown,
  Target,
  Users,
  DollarSign,
  Calendar,
  Eye,
  MousePointer,
  Heart,
  Share2,
  Mail,
  MessageCircle,
  CheckCircle,
  AlertTriangle,
  Info,
  Plus,
  Minus,
  Equal,
  ArrowRight,
  Filter,
  Download,
  RefreshCw,
  Zap,
  Activity
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
  metrics: {
    impressions: number
    clicks: number
    conversions: number
    engagement: number
    clickThroughRate: number
    conversionRate: number
    costPerClick: number
    costPerConversion: number
    returnOnAdSpend: number
  }
  channels: string[]
  targetAudience: {
    ageRange: string
    location: string
    interests: string[]
  }
  abTestVariant?: string
}

interface ComparisonMetric {
  key: string
  label: string
  format: 'number' | 'percentage' | 'currency' | 'decimal'
  category: 'performance' | 'engagement' | 'financial' | 'reach'
}

interface ABTestResult {
  metric: string
  campaignA: number
  campaignB: number
  difference: number
  percentageChange: number
  significance: number
  isSignificant: boolean
  winner: 'A' | 'B' | 'tie'
  confidence: number
}

interface CampaignComparisonProps {
  campaigns?: Campaign[]
  selectedCampaigns?: string[]
  onCampaignSelect?: (campaignIds: string[]) => void
  className?: string
}

// Mock campaign data
const mockCampaigns: Campaign[] = [
  {
    id: "1",
    title: "Summer Product Launch",
    description: "Multi-channel campaign for new product line launch",
    status: "active",
    startDate: "2024-02-01",
    endDate: "2024-04-30",
    budget: { total: 25000, spent: 18750, currency: "USD" },
    metrics: {
      impressions: 125000,
      clicks: 3875,
      conversions: 850,
      engagement: 4.2,
      clickThroughRate: 3.1,
      conversionRate: 21.9,
      costPerClick: 4.84,
      costPerConversion: 22.06,
      returnOnAdSpend: 3.2
    },
    channels: ["Email", "Social Media", "Blog", "Display Ads"],
    targetAudience: {
      ageRange: "25-34",
      location: "United States, Canada",
      interests: ["sustainability", "lifestyle", "premium products"]
    }
  },
  {
    id: "2", 
    title: "Holiday Sale Campaign",
    description: "Black Friday and Cyber Monday promotional campaign",
    status: "completed",
    startDate: "2024-11-15",
    endDate: "2024-12-02",
    budget: { total: 35000, spent: 33200, currency: "USD" },
    metrics: {
      impressions: 185000,
      clicks: 5920,
      conversions: 1240,
      engagement: 5.8,
      clickThroughRate: 3.2,
      conversionRate: 20.9,
      costPerClick: 5.61,
      costPerConversion: 26.77,
      returnOnAdSpend: 4.1
    },
    channels: ["Email", "Social Media", "Search Ads", "Display Ads"],
    targetAudience: {
      ageRange: "25-45",
      location: "United States",
      interests: ["shopping", "deals", "gifts"]
    }
  },
  {
    id: "3",
    title: "Summer Launch - Variant A",
    description: "Email-focused version of summer campaign",
    status: "active",
    startDate: "2024-02-01", 
    endDate: "2024-04-30",
    budget: { total: 12500, spent: 9375, currency: "USD" },
    metrics: {
      impressions: 75000,
      clicks: 2625,
      conversions: 525,
      engagement: 6.2,
      clickThroughRate: 3.5,
      conversionRate: 20.0,
      costPerClick: 3.57,
      costPerConversion: 17.86,
      returnOnAdSpend: 3.8
    },
    channels: ["Email", "Blog"],
    targetAudience: {
      ageRange: "25-34",
      location: "United States, Canada", 
      interests: ["sustainability", "lifestyle"]
    },
    abTestVariant: "A"
  },
  {
    id: "4",
    title: "Summer Launch - Variant B", 
    description: "Social-focused version of summer campaign",
    status: "active",
    startDate: "2024-02-01",
    endDate: "2024-04-30", 
    budget: { total: 12500, spent: 9375, currency: "USD" },
    metrics: {
      impressions: 95000,
      clicks: 2850,
      conversions: 456,
      engagement: 4.8,
      clickThroughRate: 3.0,
      conversionRate: 16.0,
      costPerClick: 3.29,
      costPerConversion: 20.56,
      returnOnAdSpend: 2.9
    },
    channels: ["Social Media", "Display Ads"],
    targetAudience: {
      ageRange: "25-34", 
      location: "United States, Canada",
      interests: ["sustainability", "lifestyle"]
    },
    abTestVariant: "B"
  }
]

const comparisonMetrics: ComparisonMetric[] = [
  { key: 'impressions', label: 'Impressions', format: 'number', category: 'reach' },
  { key: 'clicks', label: 'Clicks', format: 'number', category: 'engagement' },
  { key: 'conversions', label: 'Conversions', format: 'number', category: 'performance' },
  { key: 'clickThroughRate', label: 'Click-through Rate', format: 'percentage', category: 'engagement' },
  { key: 'conversionRate', label: 'Conversion Rate', format: 'percentage', category: 'performance' },
  { key: 'costPerClick', label: 'Cost per Click', format: 'currency', category: 'financial' },
  { key: 'costPerConversion', label: 'Cost per Conversion', format: 'currency', category: 'financial' },
  { key: 'returnOnAdSpend', label: 'ROAS', format: 'decimal', category: 'financial' },
  { key: 'engagement', label: 'Engagement Rate', format: 'percentage', category: 'engagement' }
]

export function CampaignComparison({ 
  campaigns = mockCampaigns,
  selectedCampaigns = ["1", "2"],
  onCampaignSelect,
  className 
}: CampaignComparisonProps) {
  const [selectedCampaignIds, setSelectedCampaignIds] = React.useState<string[]>(selectedCampaigns)
  const [comparisonMode, setComparisonMode] = React.useState<'general' | 'ab-test'>('general')
  const [selectedMetricCategory, setSelectedMetricCategory] = React.useState<string>('all')

  const selectedCampaignData = campaigns.filter(c => selectedCampaignIds.includes(c.id))

  const handleCampaignSelection = (campaignId: string, isSelected: boolean) => {
    let newSelection: string[]
    
    if (isSelected) {
      newSelection = [...selectedCampaignIds, campaignId].slice(0, 3) // Max 3 campaigns
    } else {
      newSelection = selectedCampaignIds.filter(id => id !== campaignId)
    }
    
    setSelectedCampaignIds(newSelection)
    onCampaignSelect?.(newSelection)
  }

  const formatMetricValue = (value: number, format: ComparisonMetric['format']): string => {
    switch (format) {
      case 'percentage':
        return `${value.toFixed(1)}%`
      case 'currency':
        return `$${value.toFixed(2)}`
      case 'decimal':
        return value.toFixed(1)
      case 'number':
      default:
        return value.toLocaleString()
    }
  }

  const calculateDifference = (value1: number, value2: number): { 
    absolute: number, 
    percentage: number, 
    trend: 'up' | 'down' | 'neutral' 
  } => {
    const absolute = value1 - value2
    const percentage = value2 !== 0 ? ((value1 - value2) / value2) * 100 : 0
    const trend = absolute > 0 ? 'up' : absolute < 0 ? 'down' : 'neutral'
    
    return { absolute, percentage, trend }
  }

  const calculateABTestResults = (): ABTestResult[] => {
    if (selectedCampaignData.length !== 2) return []
    
    const [campaignA, campaignB] = selectedCampaignData
    const results: ABTestResult[] = []

    comparisonMetrics.forEach(metric => {
      const valueA = (campaignA.metrics as any)[metric.key] as number
      const valueB = (campaignB.metrics as any)[metric.key] as number
      
      const difference = valueA - valueB
      const percentageChange = valueB !== 0 ? ((valueA - valueB) / valueB) * 100 : 0
      
      // Mock statistical significance calculation
      const significance = Math.random() * 0.1 // 0-10% p-value
      const isSignificant = significance < 0.05
      const confidence = (1 - significance) * 100
      
      let winner: 'A' | 'B' | 'tie' = 'tie'
      if (isSignificant) {
        // For metrics where higher is better
        if (['impressions', 'clicks', 'conversions', 'clickThroughRate', 'conversionRate', 'returnOnAdSpend', 'engagement'].includes(metric.key)) {
          winner = valueA > valueB ? 'A' : 'B'
        } else {
          // For metrics where lower is better (costs)
          winner = valueA < valueB ? 'A' : 'B'
        }
      }

      results.push({
        metric: metric.label,
        campaignA: valueA,
        campaignB: valueB,
        difference,
        percentageChange,
        significance,
        isSignificant,
        winner,
        confidence
      })
    })

    return results
  }

  const abTestResults = calculateABTestResults()
  const filteredMetrics = selectedMetricCategory === 'all' 
    ? comparisonMetrics 
    : comparisonMetrics.filter(m => m.category === selectedMetricCategory)

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header & Controls */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Campaign Comparison</h2>
          <p className="text-muted-foreground">
            Compare performance metrics across campaigns and analyze A/B test results
          </p>
        </div>
        
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <Label htmlFor="comparison-mode">Mode:</Label>
            <Select value={comparisonMode} onValueChange={(value: 'general' | 'ab-test') => setComparisonMode(value)}>
              <SelectTrigger className="w-40">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="general">General Comparison</SelectItem>
                <SelectItem value="ab-test">A/B Test Analysis</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <Button variant="outline" size="sm">
            <Download className="h-4 w-4 mr-2" />
            Export Report
          </Button>
        </div>
      </div>

      {/* Campaign Selection */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Target className="h-5 w-5" />
            Select Campaigns to Compare
          </CardTitle>
          <CardDescription>
            Choose 2-3 campaigns for comparison. Select campaigns with similar time periods for better insights.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {campaigns.map((campaign) => {
              const isSelected = selectedCampaignIds.includes(campaign.id)
              const canSelect = !isSelected && selectedCampaignIds.length < 3
              
              return (
                <Card 
                  key={campaign.id}
                  className={cn(
                    "cursor-pointer transition-all border-2",
                    isSelected ? "border-blue-500 bg-blue-50" : "border-gray-200 hover:border-gray-300",
                    !canSelect && !isSelected && "opacity-50 cursor-not-allowed"
                  )}
                  onClick={() => (canSelect || isSelected) && handleCampaignSelection(campaign.id, !isSelected)}
                >
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between mb-2">
                      <h4 className="font-medium text-sm">{campaign.title}</h4>
                      {isSelected && <CheckCircle className="h-4 w-4 text-blue-600" />}
                    </div>
                    
                    <p className="text-xs text-gray-600 mb-3 line-clamp-2">{campaign.description}</p>
                    
                    <div className="space-y-2 text-xs">
                      <div className="flex justify-between">
                        <span className="text-gray-500">Status:</span>
                        <Badge variant={campaign.status === 'active' ? 'default' : 'secondary'} className="text-xs">
                          {campaign.status}
                        </Badge>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Conversions:</span>
                        <span className="font-medium">{campaign.metrics.conversions.toLocaleString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">ROAS:</span>
                        <span className="font-medium">{campaign.metrics.returnOnAdSpend.toFixed(1)}x</span>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </CardContent>
      </Card>

      {selectedCampaignData.length >= 2 && (
        <Tabs defaultValue="overview">
          <TabsList>
            <TabsTrigger value="overview">Overview</TabsTrigger>
            <TabsTrigger value="metrics">Detailed Metrics</TabsTrigger>
            {comparisonMode === 'ab-test' && <TabsTrigger value="ab-analysis">A/B Test Analysis</TabsTrigger>}
            <TabsTrigger value="audience">Audience Comparison</TabsTrigger>
          </TabsList>

          <TabsContent value="overview" className="space-y-6">
            {/* Campaign Overview Cards */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {selectedCampaignData.map((campaign, index) => (
                <Card key={campaign.id}>
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <CardTitle className="text-lg">{campaign.title}</CardTitle>
                      <Badge variant={campaign.status === 'active' ? 'default' : 'secondary'}>
                        {campaign.status}
                      </Badge>
                    </div>
                    <CardDescription>{campaign.description}</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div className="text-center p-3 bg-blue-50 rounded">
                        <Users className="h-6 w-6 text-blue-600 mx-auto mb-1" />
                        <p className="text-2xl font-bold text-blue-900">{campaign.metrics.impressions.toLocaleString()}</p>
                        <p className="text-xs text-blue-600">Impressions</p>
                      </div>
                      <div className="text-center p-3 bg-green-50 rounded">
                        <Target className="h-6 w-6 text-green-600 mx-auto mb-1" />
                        <p className="text-2xl font-bold text-green-900">{campaign.metrics.conversions.toLocaleString()}</p>
                        <p className="text-xs text-green-600">Conversions</p>
                      </div>
                    </div>

                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span>CTR:</span>
                        <span className="font-medium">{campaign.metrics.clickThroughRate}%</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span>Conversion Rate:</span>
                        <span className="font-medium">{campaign.metrics.conversionRate}%</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span>ROAS:</span>
                        <span className="font-medium">{campaign.metrics.returnOnAdSpend.toFixed(1)}x</span>
                      </div>
                    </div>

                    <Separator />

                    <div>
                      <p className="text-sm font-medium mb-2">Channels:</p>
                      <div className="flex flex-wrap gap-1">
                        {campaign.channels.map((channel) => (
                          <Badge key={channel} variant="outline" className="text-xs">
                            {channel}
                          </Badge>
                        ))}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>

            {/* Quick Comparison */}
            {selectedCampaignData.length === 2 && (
              <Card>
                <CardHeader>
                  <CardTitle>Quick Comparison</CardTitle>
                  <CardDescription>
                    Side-by-side comparison of key metrics
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {filteredMetrics.slice(0, 6).map((metric) => {
                      const metrics1 = selectedCampaignData[0].metrics
                      const metrics2 = selectedCampaignData[1].metrics
                      const value1 = (metrics1 as any)[metric.key] as number
                      const value2 = (metrics2 as any)[metric.key] as number
                      const diff = calculateDifference(value1, value2)

                      return (
                        <div key={metric.key} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                          <div className="font-medium text-sm">{metric.label}</div>
                          <div className="flex items-center gap-4 text-sm">
                            <span>{formatMetricValue(value1, metric.format)}</span>
                            <div className="flex items-center gap-1">
                              {diff.trend === 'up' && <TrendingUp className="h-4 w-4 text-green-600" />}
                              {diff.trend === 'down' && <TrendingDown className="h-4 w-4 text-red-600" />}
                              {diff.trend === 'neutral' && <Equal className="h-4 w-4 text-gray-600" />}
                              <span className={cn(
                                "font-medium",
                                diff.trend === 'up' ? "text-green-600" : diff.trend === 'down' ? "text-red-600" : "text-gray-600"
                              )}>
                                {Math.abs(diff.percentage).toFixed(1)}%
                              </span>
                            </div>
                            <span>{formatMetricValue(value2, metric.format)}</span>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                </CardContent>
              </Card>
            )}
          </TabsContent>

          <TabsContent value="metrics" className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-medium">Detailed Metrics Comparison</h3>
              <Select value={selectedMetricCategory} onValueChange={setSelectedMetricCategory}>
                <SelectTrigger className="w-48">
                  <SelectValue placeholder="Filter by category" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Categories</SelectItem>
                  <SelectItem value="performance">Performance</SelectItem>
                  <SelectItem value="engagement">Engagement</SelectItem>
                  <SelectItem value="financial">Financial</SelectItem>
                  <SelectItem value="reach">Reach</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <Card>
              <CardContent className="p-0">
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="text-left p-4 font-medium">Metric</th>
                        {selectedCampaignData.map((campaign) => (
                          <th key={campaign.id} className="text-center p-4 font-medium">
                            {campaign.title}
                          </th>
                        ))}
                        {selectedCampaignData.length === 2 && (
                          <th className="text-center p-4 font-medium">Difference</th>
                        )}
                      </tr>
                    </thead>
                    <tbody>
                      {filteredMetrics.map((metric) => {
                        const values = selectedCampaignData.map(campaign => 
                          (campaign.metrics as any)[metric.key] as number
                        )
                        const diff = values.length === 2 ? calculateDifference(values[0], values[1]) : null

                        return (
                          <tr key={metric.key} className="border-t">
                            <td className="p-4 font-medium">{metric.label}</td>
                            {values.map((value, index) => (
                              <td key={index} className="p-4 text-center">
                                {formatMetricValue(value, metric.format)}
                              </td>
                            ))}
                            {diff && (
                              <td className="p-4 text-center">
                                <div className="flex items-center justify-center gap-1">
                                  {diff.trend === 'up' && <TrendingUp className="h-4 w-4 text-green-600" />}
                                  {diff.trend === 'down' && <TrendingDown className="h-4 w-4 text-red-600" />}
                                  {diff.trend === 'neutral' && <Equal className="h-4 w-4 text-gray-600" />}
                                  <span className={cn(
                                    "font-medium",
                                    diff.trend === 'up' ? "text-green-600" : diff.trend === 'down' ? "text-red-600" : "text-gray-600"
                                  )}>
                                    {diff.percentage > 0 ? '+' : ''}{diff.percentage.toFixed(1)}%
                                  </span>
                                </div>
                              </td>
                            )}
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {comparisonMode === 'ab-test' && (
            <TabsContent value="ab-analysis" className="space-y-6">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-lg font-medium">A/B Test Statistical Analysis</h3>
                  <p className="text-sm text-muted-foreground">
                    Statistical significance testing for campaign variants
                  </p>
                </div>
                <Button variant="outline" size="sm">
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Refresh Analysis
                </Button>
              </div>

              {/* A/B Test Summary */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <Card>
                  <CardContent className="p-4 text-center">
                    <CheckCircle className="h-8 w-8 text-green-600 mx-auto mb-2" />
                    <p className="text-2xl font-bold text-green-900">
                      {abTestResults.filter(r => r.isSignificant).length}
                    </p>
                    <p className="text-sm text-green-600">Significant Results</p>
                  </CardContent>
                </Card>

                <Card>
                  <CardContent className="p-4 text-center">
                    <AlertTriangle className="h-8 w-8 text-yellow-600 mx-auto mb-2" />
                    <p className="text-2xl font-bold text-yellow-900">
                      {abTestResults.filter(r => !r.isSignificant).length}
                    </p>
                    <p className="text-sm text-yellow-600">Inconclusive</p>
                  </CardContent>
                </Card>

                <Card>
                  <CardContent className="p-4 text-center">
                    <Activity className="h-8 w-8 text-blue-600 mx-auto mb-2" />
                    <p className="text-2xl font-bold text-blue-900">
                      {abTestResults.length ? Math.round(abTestResults.reduce((sum, r) => sum + r.confidence, 0) / abTestResults.length) : 0}%
                    </p>
                    <p className="text-sm text-blue-600">Avg. Confidence</p>
                  </CardContent>
                </Card>
              </div>

              {/* Detailed A/B Test Results */}
              <Card>
                <CardHeader>
                  <CardTitle>Statistical Test Results</CardTitle>
                  <CardDescription>
                    Detailed breakdown of statistical significance for each metric
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {abTestResults.map((result, index) => (
                      <div key={index} className="border rounded-lg p-4">
                        <div className="flex items-center justify-between mb-3">
                          <h4 className="font-medium">{result.metric}</h4>
                          <div className="flex items-center gap-2">
                            {result.isSignificant ? (
                              <Badge className="bg-green-100 text-green-800">
                                Significant
                              </Badge>
                            ) : (
                              <Badge variant="secondary">
                                Not Significant
                              </Badge>
                            )}
                            <Badge variant="outline">
                              {result.confidence.toFixed(1)}% confidence
                            </Badge>
                          </div>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 text-sm">
                          <div>
                            <p className="text-gray-500 mb-1">Campaign A</p>
                            <p className="font-medium">{formatMetricValue(result.campaignA, 
                              comparisonMetrics.find(m => m.label === result.metric)?.format || 'number'
                            )}</p>
                          </div>
                          <div>
                            <p className="text-gray-500 mb-1">Campaign B</p>
                            <p className="font-medium">{formatMetricValue(result.campaignB,
                              comparisonMetrics.find(m => m.label === result.metric)?.format || 'number'
                            )}</p>
                          </div>
                          <div>
                            <p className="text-gray-500 mb-1">Change</p>
                            <div className="flex items-center gap-1">
                              {result.percentageChange > 0 && <TrendingUp className="h-4 w-4 text-green-600" />}
                              {result.percentageChange < 0 && <TrendingDown className="h-4 w-4 text-red-600" />}
                              {result.percentageChange === 0 && <Equal className="h-4 w-4 text-gray-600" />}
                              <span className={cn(
                                "font-medium",
                                result.percentageChange > 0 ? "text-green-600" : 
                                result.percentageChange < 0 ? "text-red-600" : "text-gray-600"
                              )}>
                                {result.percentageChange > 0 ? '+' : ''}{result.percentageChange.toFixed(1)}%
                              </span>
                            </div>
                          </div>
                          <div>
                            <p className="text-gray-500 mb-1">Winner</p>
                            <p className="font-medium">
                              {result.isSignificant ? 
                                `Campaign ${result.winner.toUpperCase()}` : 
                                'No winner'
                              }
                            </p>
                          </div>
                        </div>

                        {result.isSignificant && (
                          <div className="mt-3 p-3 bg-blue-50 rounded text-sm">
                            <Info className="h-4 w-4 text-blue-600 inline mr-2" />
                            <span className="text-blue-800">
                              This result is statistically significant with {result.confidence.toFixed(1)}% confidence.
                              Campaign {result.winner.toUpperCase()} performs significantly better for this metric.
                            </span>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </TabsContent>
          )}

          <TabsContent value="audience" className="space-y-6">
            <h3 className="text-lg font-medium">Audience Comparison</h3>
            
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {selectedCampaignData.map((campaign) => (
                <Card key={campaign.id}>
                  <CardHeader>
                    <CardTitle>{campaign.title}</CardTitle>
                    <CardDescription>Target audience profile</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div>
                      <Label className="text-sm font-medium">Age Range</Label>
                      <p className="text-sm text-gray-600">{campaign.targetAudience.ageRange} years</p>
                    </div>
                    
                    <div>
                      <Label className="text-sm font-medium">Location</Label>
                      <p className="text-sm text-gray-600">{campaign.targetAudience.location}</p>
                    </div>
                    
                    <div>
                      <Label className="text-sm font-medium">Interests</Label>
                      <div className="flex flex-wrap gap-1 mt-1">
                        {campaign.targetAudience.interests.map((interest) => (
                          <Badge key={interest} variant="secondary" className="text-xs">
                            {interest}
                          </Badge>
                        ))}
                      </div>
                    </div>
                    
                    <div>
                      <Label className="text-sm font-medium">Channels</Label>
                      <div className="flex flex-wrap gap-1 mt-1">
                        {campaign.channels.map((channel) => (
                          <Badge key={channel} variant="outline" className="text-xs">
                            {channel}
                          </Badge>
                        ))}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </TabsContent>
        </Tabs>
      )}

      {selectedCampaignData.length < 2 && (
        <Card>
          <CardContent className="p-12 text-center">
            <BarChart3 className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">Select Campaigns to Compare</h3>
            <p className="text-gray-600">
              Choose at least 2 campaigns from the selection above to start comparing their performance.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  )
}