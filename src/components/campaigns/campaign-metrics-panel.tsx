"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { 
  TrendingUp, 
  TrendingDown, 
  Users, 
  Target, 
  DollarSign, 
  Eye,
  MousePointer,
  BarChart3,
  PieChart,
  Activity
} from "lucide-react"

interface CampaignMetrics {
  progress: number
  contentPieces: number
  impressions: number
  engagement: number
  conversions: number
  clickThroughRate: number
  costPerConversion: number
}

interface CampaignBudget {
  total: number
  spent: number
  currency: string
}

interface Campaign {
  id: string
  title: string
  status: string
  budget: CampaignBudget
  metrics: CampaignMetrics
  channels: string[]
}

interface CampaignMetricsPanelProps {
  campaign: Campaign
}

// Mock time-series data for charts
const mockPerformanceData = [
  { date: "2024-02-01", impressions: 8500, engagement: 3.2, conversions: 45 },
  { date: "2024-02-08", impressions: 12000, engagement: 3.8, conversions: 68 },
  { date: "2024-02-15", impressions: 15200, engagement: 4.1, conversions: 89 },
  { date: "2024-02-22", impressions: 18700, engagement: 4.3, conversions: 112 },
  { date: "2024-03-01", impressions: 22100, engagement: 4.2, conversions: 138 },
  { date: "2024-03-08", impressions: 24800, engagement: 4.0, conversions: 156 },
  { date: "2024-03-15", impressions: 27500, engagement: 4.5, conversions: 192 },
  { date: "2024-03-22", impressions: 30200, engagement: 4.2, conversions: 225 },
]

const mockChannelPerformance = [
  { channel: "Email", impressions: 45000, engagement: 8.2, conversions: 340, spend: 8500 },
  { channel: "Social Media", impressions: 38000, engagement: 3.8, conversions: 285, spend: 6200 },
  { channel: "Blog", impressions: 22000, engagement: 6.1, conversions: 125, spend: 2800 },
  { channel: "Display Ads", impressions: 20000, engagement: 2.1, conversions: 100, spend: 2250 },
]

export function CampaignMetricsPanel({ campaign }: CampaignMetricsPanelProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: campaign.budget.currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const formatNumber = (num: number) => {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M'
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K'
    }
    return num.toString()
  }

  const budgetUtilization = (campaign.budget.spent / campaign.budget.total) * 100
  const averageCPC = campaign.budget.spent / campaign.metrics.conversions
  const roi = ((campaign.metrics.conversions * 50) - campaign.budget.spent) / campaign.budget.spent * 100 // Assuming $50 per conversion

  return (
    <div className="space-y-6">
      {/* Key Performance Indicators */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Total Impressions</p>
                <p className="text-2xl font-bold">{formatNumber(campaign.metrics.impressions)}</p>
                <div className="flex items-center gap-1 mt-1">
                  <TrendingUp className="h-3 w-3 text-green-600" />
                  <span className="text-xs text-green-600">+12.5%</span>
                </div>
              </div>
              <Eye className="h-8 w-8 text-blue-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Click-through Rate</p>
                <p className="text-2xl font-bold">{campaign.metrics.clickThroughRate}%</p>
                <div className="flex items-center gap-1 mt-1">
                  <TrendingUp className="h-3 w-3 text-green-600" />
                  <span className="text-xs text-green-600">+0.3%</span>
                </div>
              </div>
              <MousePointer className="h-8 w-8 text-orange-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Cost per Conversion</p>
                <p className="text-2xl font-bold">{formatCurrency(campaign.metrics.costPerConversion)}</p>
                <div className="flex items-center gap-1 mt-1">
                  <TrendingDown className="h-3 w-3 text-green-600" />
                  <span className="text-xs text-green-600">-8.2%</span>
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
                <p className="text-sm text-muted-foreground">ROI</p>
                <p className="text-2xl font-bold">{roi > 0 ? '+' : ''}{Math.round(roi)}%</p>
                <div className="flex items-center gap-1 mt-1">
                  {roi > 0 ? (
                    <>
                      <TrendingUp className="h-3 w-3 text-green-600" />
                      <span className="text-xs text-green-600">Profitable</span>
                    </>
                  ) : (
                    <>
                      <TrendingDown className="h-3 w-3 text-red-600" />
                      <span className="text-xs text-red-600">At Loss</span>
                    </>
                  )}
                </div>
              </div>
              <BarChart3 className="h-8 w-8 text-purple-600" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Detailed Analytics Tabs */}
      <Tabs defaultValue="performance" className="space-y-4">
        <TabsList>
          <TabsTrigger value="performance">Performance</TabsTrigger>
          <TabsTrigger value="channels">Channels</TabsTrigger>
          <TabsTrigger value="budget">Budget</TabsTrigger>
          <TabsTrigger value="audience">Audience</TabsTrigger>
        </TabsList>

        <TabsContent value="performance" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Activity className="h-5 w-5" />
                Performance Trends
              </CardTitle>
              <CardDescription>
                Weekly performance metrics over time
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                {/* Simple performance timeline */}
                <div className="space-y-4">
                  {mockPerformanceData.slice(-4).map((data, index) => (
                    <div key={data.date} className="flex items-center justify-between p-4 bg-slate-50 rounded-lg">
                      <div>
                        <p className="font-medium">{new Date(data.date).toLocaleDateString()}</p>
                        <p className="text-sm text-muted-foreground">Week {index + 5}</p>
                      </div>
                      <div className="text-right">
                        <div className="flex items-center gap-6">
                          <div>
                            <p className="text-sm text-muted-foreground">Impressions</p>
                            <p className="font-medium">{formatNumber(data.impressions)}</p>
                          </div>
                          <div>
                            <p className="text-sm text-muted-foreground">Engagement</p>
                            <p className="font-medium">{data.engagement}%</p>
                          </div>
                          <div>
                            <p className="text-sm text-muted-foreground">Conversions</p>
                            <p className="font-medium">{data.conversions}</p>
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>

                <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
                  <h4 className="font-medium text-green-900 mb-2">📈 Performance Insights</h4>
                  <ul className="text-sm text-green-800 space-y-1">
                    <li>• Impressions have grown by 45% over the last 4 weeks</li>
                    <li>• Engagement rate peaked at 4.5% last week</li>
                    <li>• Conversion growth is accelerating (+28% this week)</li>
                  </ul>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="channels" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <PieChart className="h-5 w-5" />
                Channel Performance
              </CardTitle>
              <CardDescription>
                Compare performance across marketing channels
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {mockChannelPerformance.map((channel) => {
                  const conversionRate = (channel.conversions / channel.impressions * 100).toFixed(2)
                  const cpc = channel.spend / channel.conversions
                  
                  return (
                    <div key={channel.channel} className="p-4 border rounded-lg">
                      <div className="flex items-center justify-between mb-3">
                        <h3 className="font-medium">{channel.channel}</h3>
                        <Badge variant="outline">{formatCurrency(channel.spend)} spent</Badge>
                      </div>
                      
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <p className="text-muted-foreground">Impressions</p>
                          <p className="font-medium">{formatNumber(channel.impressions)}</p>
                        </div>
                        <div>
                          <p className="text-muted-foreground">Engagement</p>
                          <p className="font-medium">{channel.engagement}%</p>
                        </div>
                        <div>
                          <p className="text-muted-foreground">Conversions</p>
                          <p className="font-medium">{channel.conversions}</p>
                        </div>
                        <div>
                          <p className="text-muted-foreground">Cost/Conversion</p>
                          <p className="font-medium">{formatCurrency(cpc)}</p>
                        </div>
                      </div>

                      <div className="mt-3">
                        <div className="flex items-center justify-between text-xs text-muted-foreground mb-1">
                          <span>Conversion Rate</span>
                          <span>{conversionRate}%</span>
                        </div>
                        <Progress value={parseFloat(conversionRate) * 10} className="h-2" />
                      </div>
                    </div>
                  )
                })}

                <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
                  <h4 className="font-medium text-blue-900 mb-2">🎯 Channel Insights</h4>
                  <ul className="text-sm text-blue-800 space-y-1">
                    <li>• Email has the highest engagement rate at 8.2%</li>
                    <li>• Social Media generates the most volume but lower conversion rate</li>
                    <li>• Blog content has strong mid-funnel performance</li>
                    <li>• Consider reducing Display Ads budget and reallocating to Email</li>
                  </ul>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="budget" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Card>
              <CardHeader>
                <CardTitle>Budget Utilization</CardTitle>
                <CardDescription>
                  Track spending against budget allocation
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm">Spent</span>
                    <span className="font-medium">{formatCurrency(campaign.budget.spent)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm">Remaining</span>
                    <span className="font-medium">{formatCurrency(campaign.budget.total - campaign.budget.spent)}</span>
                  </div>
                </div>
                
                <Progress value={budgetUtilization} className="h-3" />
                
                <div className="text-center">
                  <p className="text-2xl font-bold">{Math.round(budgetUtilization)}%</p>
                  <p className="text-sm text-muted-foreground">Budget utilized</p>
                </div>

                <div className="p-3 bg-orange-50 border border-orange-200 rounded-lg">
                  <p className="text-sm text-orange-800">
                    <strong>Budget Alert:</strong> You've spent 75% of your budget with 30 days remaining.
                    Consider optimizing spend or requesting budget increase.
                  </p>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Cost Analysis</CardTitle>
                <CardDescription>
                  Breakdown of campaign costs and efficiency
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-sm">Average CPC</span>
                    <span className="font-medium">{formatCurrency(averageCPC)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm">Cost per Conversion</span>
                    <span className="font-medium">{formatCurrency(campaign.metrics.costPerConversion)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm">Daily Spend Rate</span>
                    <span className="font-medium">{formatCurrency(campaign.budget.spent / 60)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm">Projected Total Spend</span>
                    <span className="font-medium">{formatCurrency(campaign.budget.spent * 1.33)}</span>
                  </div>
                </div>

                <div className="p-3 bg-green-50 border border-green-200 rounded-lg">
                  <p className="text-sm text-green-800">
                    <strong>Efficiency:</strong> Your cost per conversion is 15% below industry average.
                    Campaign is performing efficiently.
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="audience" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="h-5 w-5" />
                Audience Insights
              </CardTitle>
              <CardDescription>
                Demographics and behavior of your campaign audience
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <h4 className="font-medium">Demographics</h4>
                  <div className="space-y-3">
                    <div>
                      <div className="flex items-center justify-between text-sm mb-1">
                        <span>25-34 years</span>
                        <span>42%</span>
                      </div>
                      <Progress value={42} className="h-2" />
                    </div>
                    <div>
                      <div className="flex items-center justify-between text-sm mb-1">
                        <span>35-44 years</span>
                        <span>28%</span>
                      </div>
                      <Progress value={28} className="h-2" />
                    </div>
                    <div>
                      <div className="flex items-center justify-between text-sm mb-1">
                        <span>18-24 years</span>
                        <span>20%</span>
                      </div>
                      <Progress value={20} className="h-2" />
                    </div>
                    <div>
                      <div className="flex items-center justify-between text-sm mb-1">
                        <span>45+ years</span>
                        <span>10%</span>
                      </div>
                      <Progress value={10} className="h-2" />
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <h4 className="font-medium">Engagement by Segment</h4>
                  <div className="space-y-3">
                    <div className="p-3 border rounded-lg">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-sm font-medium">High Intent Users</span>
                        <Badge variant="secondary">24%</Badge>
                      </div>
                      <p className="text-xs text-muted-foreground">Users who engaged with multiple touchpoints</p>
                    </div>
                    <div className="p-3 border rounded-lg">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-sm font-medium">New Visitors</span>
                        <Badge variant="secondary">68%</Badge>
                      </div>
                      <p className="text-xs text-muted-foreground">First-time interaction with your brand</p>
                    </div>
                    <div className="p-3 border rounded-lg">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-sm font-medium">Returning Users</span>
                        <Badge variant="secondary">8%</Badge>
                      </div>
                      <p className="text-xs text-muted-foreground">Previously engaged with your campaigns</p>
                    </div>
                  </div>
                </div>
              </div>

              <div className="mt-6 p-4 bg-purple-50 border border-purple-200 rounded-lg">
                <h4 className="font-medium text-purple-900 mb-2">👥 Audience Insights</h4>
                <ul className="text-sm text-purple-800 space-y-1">
                  <li>• Your primary audience (25-34) shows the highest conversion rate</li>
                  <li>• New visitors make up the majority but have lower engagement</li>
                  <li>• Consider creating retargeting campaigns for high-intent users</li>
                </ul>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}