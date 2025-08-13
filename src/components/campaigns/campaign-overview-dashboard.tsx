"use client"

import React, { useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Progress } from "@/components/ui/progress"
import { 
  BarChart, 
  LineChart, 
  PieChart, 
  TrendingUp, 
  TrendingDown, 
  Activity, 
  DollarSign, 
  Users, 
  Target, 
  Mail, 
  MessageCircle, 
  Globe, 
  Eye,
  Clock,
  Calendar,
  Download,
  Share2
} from "lucide-react"
import { type CampaignStatus } from "@/components/ui/campaign-card"

export interface CampaignOverviewData {
  id: string
  title: string
  description: string
  status: CampaignStatus
  createdAt: string
  startDate: string
  endDate: string
  budget: {
    total: number
    spent: number
    currency: string
  }
  objectives: string[]
  channels: string[]
  metrics: {
    progress: number
    contentPieces: number
    impressions: number
    engagement: number
    conversions: number
    clickThroughRate: number
    costPerConversion: number
    roi: number
  }
  journey: {
    stages: Array<{
      id: string
      name: string
      status: string
      channels: string[]
      contentCount: number
      metrics: { impressions: number; engagement: number }
    }>
  }
}

interface CampaignOverviewDashboardProps {
  campaign: CampaignOverviewData
  onExport?: () => void
  onShare?: () => void
}

function StatCard({
  title,
  value,
  icon: Icon,
  trend,
  trendLabel,
  className = "",
  variant = "default"
}: {
  title: string
  value: string | number
  icon: React.ElementType
  trend?: number
  trendLabel?: string
  className?: string
  variant?: "default" | "success" | "warning" | "danger"
}) {
  const isPositiveTrend = trend && trend > 0
  const isNegativeTrend = trend && trend < 0

  const variantStyles = {
    default: "border-border",
    success: "border-green-200 bg-green-50/50",
    warning: "border-yellow-200 bg-yellow-50/50", 
    danger: "border-red-200 bg-red-50/50"
  }

  return (
    <Card className={`${variantStyles[variant]} ${className}`}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
        <Icon className={`h-4 w-4 ${
          variant === "success" ? "text-green-600" :
          variant === "warning" ? "text-yellow-600" :
          variant === "danger" ? "text-red-600" :
          "text-muted-foreground"
        }`} />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        {trend !== undefined && (
          <div className="flex items-center space-x-1 text-xs text-muted-foreground">
            {isPositiveTrend && <TrendingUp className="h-3 w-3 text-green-500" />}
            {isNegativeTrend && <TrendingDown className="h-3 w-3 text-red-500" />}
            <span
              className={
                isPositiveTrend
                  ? "text-green-500"
                  : isNegativeTrend
                  ? "text-red-500"
                  : ""
              }
            >
              {trend > 0 ? "+" : ""}{trend}%
            </span>
            {trendLabel && <span>{trendLabel}</span>}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function ChannelBreakdown({ channels, journey }: { channels: string[], journey: CampaignOverviewData['journey'] }) {
  const channelMetrics = channels.map(channel => {
    const stagesWithChannel = journey.stages.filter(stage => stage.channels.includes(channel))
    const totalImpressions = stagesWithChannel.reduce((sum, stage) => sum + stage.metrics.impressions, 0)
    const avgEngagement = stagesWithChannel.reduce((sum, stage) => sum + stage.metrics.engagement, 0) / stagesWithChannel.length || 0
    const contentCount = stagesWithChannel.reduce((sum, stage) => sum + stage.contentCount, 0)

    return {
      channel,
      impressions: totalImpressions,
      engagement: avgEngagement,
      contentCount
    }
  })

  const getChannelIcon = (channel: string) => {
    switch (channel.toLowerCase()) {
      case 'email': return Mail
      case 'social media': case 'social': return MessageCircle
      case 'blog': return Globe
      default: return Eye
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Channel Performance</CardTitle>
        <CardDescription>Breakdown by marketing channel</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {channelMetrics.map((channel) => {
          const Icon = getChannelIcon(channel.channel)
          return (
            <div key={channel.channel} className="flex items-center justify-between p-3 rounded-lg border">
              <div className="flex items-center gap-3">
                <Icon className="h-5 w-5 text-muted-foreground" />
                <div>
                  <div className="font-medium">{channel.channel}</div>
                  <div className="text-sm text-muted-foreground">
                    {channel.contentCount} content pieces
                  </div>
                </div>
              </div>
              <div className="text-right">
                <div className="text-sm font-medium">
                  {channel.impressions.toLocaleString()} impressions
                </div>
                <div className="text-sm text-muted-foreground">
                  {channel.engagement.toFixed(1)}% engagement
                </div>
              </div>
            </div>
          )
        })}
      </CardContent>
    </Card>
  )
}

function JourneyProgress({ journey }: { journey: CampaignOverviewData['journey'] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Customer Journey Progress</CardTitle>
        <CardDescription>Progress through campaign stages</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {journey.stages.map((stage, index) => {
          const isCompleted = stage.status === 'completed'
          const isActive = stage.status === 'active'
          const progressValue = isCompleted ? 100 : isActive ? 60 : 0

          return (
            <div key={stage.id} className="space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className={`w-3 h-3 rounded-full ${
                    isCompleted ? 'bg-green-500' : 
                    isActive ? 'bg-blue-500' : 
                    'bg-gray-300'
                  }`} />
                  <span className="font-medium">{stage.name}</span>
                  <Badge variant={isCompleted ? "default" : isActive ? "secondary" : "outline"}>
                    {stage.status}
                  </Badge>
                </div>
                <div className="text-sm text-muted-foreground">
                  {stage.contentCount} pieces
                </div>
              </div>
              <Progress value={progressValue} className="h-2" />
              <div className="text-xs text-muted-foreground">
                {stage.metrics.impressions.toLocaleString()} impressions • {stage.metrics.engagement}% engagement
              </div>
            </div>
          )
        })}
      </CardContent>
    </Card>
  )
}

export function CampaignOverviewDashboard({ 
  campaign, 
  onExport, 
  onShare 
}: CampaignOverviewDashboardProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: campaign.budget.currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const formatNumber = (num: number): string => {
    if (num >= 1000000) {
      return `${(num / 1000000).toFixed(1)}M`
    }
    if (num >= 1000) {
      return `${(num / 1000).toFixed(1)}K`
    }
    return num.toString()
  }

  const budgetUtilization = (campaign.budget.spent / campaign.budget.total) * 100
  const daysRemaining = Math.ceil((new Date(campaign.endDate).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24))

  return (
    <div className="space-y-6">
      {/* Header with Actions */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">{campaign.title}</h2>
          <p className="text-muted-foreground">{campaign.description}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={onShare}>
            <Share2 className="h-4 w-4 mr-2" />
            Share
          </Button>
          <Button variant="outline" onClick={onExport}>
            <Download className="h-4 w-4 mr-2" />
            Export
          </Button>
        </div>
      </div>

      {/* Key Performance Metrics */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Campaign Progress"
          value={`${campaign.metrics.progress}%`}
          icon={Target}
          trend={15}
          trendLabel="on track"
          variant="success"
        />
        <StatCard
          title="Budget Spent"
          value={formatCurrency(campaign.budget.spent)}
          icon={DollarSign}
          trend={budgetUtilization > 90 ? -5 : 8}
          trendLabel="of budget"
          variant={budgetUtilization > 90 ? "warning" : "default"}
        />
        <StatCard
          title="Total Impressions"
          value={formatNumber(campaign.metrics.impressions)}
          icon={Users}
          trend={12}
          trendLabel="vs target"
          variant="success"
        />
        <StatCard
          title="Engagement Rate"
          value={`${campaign.metrics.engagement}%`}
          icon={Activity}
          trend={campaign.metrics.engagement > 4 ? 5 : -2}
          trendLabel="above avg"
          variant={campaign.metrics.engagement > 4 ? "success" : "warning"}
        />
      </div>

      {/* Secondary Metrics */}
      <div className="grid gap-4 md:grid-cols-3">
        <StatCard
          title="Conversions"
          value={formatNumber(campaign.metrics.conversions)}
          icon={Target}
          trend={18}
          trendLabel="this month"
        />
        <StatCard
          title="CTR"
          value={`${campaign.metrics.clickThroughRate}%`}
          icon={Eye}
          trend={3}
          trendLabel="industry avg"
        />
        <StatCard
          title="ROI"
          value={`${campaign.metrics.roi}%`}
          icon={TrendingUp}
          trend={campaign.metrics.roi > 200 ? 25 : 10}
          trendLabel="expected"
          variant={campaign.metrics.roi > 200 ? "success" : "default"}
        />
      </div>

      {/* Main Content */}
      <Tabs defaultValue="overview" className="space-y-4">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="performance">Performance</TabsTrigger>
          <TabsTrigger value="timeline">Timeline</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-4">
          <div className="grid gap-6 lg:grid-cols-2">
            <JourneyProgress journey={campaign.journey} />
            <ChannelBreakdown channels={campaign.channels} journey={campaign.journey} />
          </div>

          {/* Campaign Details Summary */}
          <div className="grid gap-6 lg:grid-cols-3">
            <Card>
              <CardHeader>
                <CardTitle>Timeline</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center gap-2">
                  <Calendar className="h-4 w-4 text-muted-foreground" />
                  <span className="text-sm">Start: {new Date(campaign.startDate).toLocaleDateString()}</span>
                </div>
                <div className="flex items-center gap-2">
                  <Calendar className="h-4 w-4 text-muted-foreground" />
                  <span className="text-sm">End: {new Date(campaign.endDate).toLocaleDateString()}</span>
                </div>
                <div className="flex items-center gap-2">
                  <Clock className="h-4 w-4 text-muted-foreground" />
                  <span className="text-sm">
                    {daysRemaining > 0 ? `${daysRemaining} days remaining` : 'Campaign ended'}
                  </span>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Budget Breakdown</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Spent</span>
                    <span className="font-medium">{formatCurrency(campaign.budget.spent)}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Remaining</span>
                    <span className="font-medium">{formatCurrency(campaign.budget.total - campaign.budget.spent)}</span>
                  </div>
                  <Progress value={budgetUtilization} className="h-2" />
                  <div className="text-xs text-muted-foreground">
                    {budgetUtilization.toFixed(0)}% of total budget used
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Objectives</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex flex-wrap gap-2">
                  {campaign.objectives.map((objective) => (
                    <Badge key={objective} variant="secondary">
                      {objective.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                    </Badge>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="performance" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Cost Efficiency</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="text-2xl font-bold">
                  {formatCurrency(campaign.metrics.costPerConversion)}
                </div>
                <div className="text-sm text-muted-foreground">Cost per conversion</div>
                <div className="flex items-center gap-1 text-xs">
                  <TrendingUp className="h-3 w-3 text-green-500" />
                  <span className="text-green-500">12% below target</span>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Content Performance</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="text-2xl font-bold">{campaign.metrics.contentPieces}</div>
                <div className="text-sm text-muted-foreground">Total content pieces</div>
                <div className="flex items-center gap-1 text-xs">
                  <TrendingUp className="h-3 w-3 text-green-500" />
                  <span className="text-green-500">On schedule</span>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Reach</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="text-2xl font-bold">{formatNumber(campaign.metrics.impressions)}</div>
                <div className="text-sm text-muted-foreground">Total impressions</div>
                <div className="flex items-center gap-1 text-xs">
                  <TrendingUp className="h-3 w-3 text-green-500" />
                  <span className="text-green-500">25% above target</span>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="timeline" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Campaign Timeline</CardTitle>
              <CardDescription>Key milestones and progress tracking</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-sm text-muted-foreground">
                Interactive timeline and calendar view will be available in the dedicated Timeline section
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}