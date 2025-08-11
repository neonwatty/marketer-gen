import React from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { TrendingUp, TrendingDown, Activity, DollarSign, Users, Target } from "lucide-react"

export interface CampaignStats {
  totalCampaigns: number
  activeCampaigns: number
  totalBudget: number
  totalImpressions: number
  avgEngagement: number
  totalConversions: number
  conversionTrend: number // percentage change
  budgetUtilization: number // percentage
}

export interface CampaignStatsProps {
  stats: CampaignStats
}

function StatCard({
  title,
  value,
  icon: Icon,
  trend,
  trendLabel,
  className = ""
}: {
  title: string
  value: string | number
  icon: React.ElementType
  trend?: number
  trendLabel?: string
  className?: string
}) {
  const isPositiveTrend = trend && trend > 0
  const isNegativeTrend = trend && trend < 0

  return (
    <Card className={className}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
        <Icon className="h-4 w-4 text-muted-foreground" />
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

function formatNumber(num: number): string {
  if (num >= 1000000) {
    return `${(num / 1000000).toFixed(1)}M`
  }
  if (num >= 1000) {
    return `${(num / 1000).toFixed(1)}K`
  }
  return num.toString()
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount)
}

export function CampaignStats({ stats }: CampaignStatsProps) {
  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      <StatCard
        title="Total Campaigns"
        value={stats.totalCampaigns}
        icon={Target}
      />
      <StatCard
        title="Active Campaigns"
        value={stats.activeCampaigns}
        icon={Activity}
        trend={stats.activeCampaigns > 0 ? 15 : undefined}
        trendLabel="from last month"
      />
      <StatCard
        title="Total Budget"
        value={formatCurrency(stats.totalBudget)}
        icon={DollarSign}
        trend={stats.budgetUtilization > 80 ? 5 : -2}
        trendLabel="from last month"
      />
      <StatCard
        title="Avg Engagement"
        value={`${stats.avgEngagement}%`}
        icon={Users}
        trend={stats.conversionTrend}
        trendLabel="from last month"
      />
    </div>
  )
}