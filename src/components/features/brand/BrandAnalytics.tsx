"use client"

import * as React from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Progress } from "@/components/ui/progress"
import { 
  BarChart3, 
  Download, 
  Eye, 
  Calendar, 
  TrendingUp, 
  TrendingDown,
  Users,
  Activity,
  Clock
} from "lucide-react"
import { BrandWithRelations } from "@/lib/types/brand"

interface BrandAnalyticsProps {
  brand: BrandWithRelations
}

export function BrandAnalytics({ brand }: BrandAnalyticsProps) {
  // Calculate analytics from brand assets
  const analytics = calculateBrandAnalytics(brand)

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <BarChart3 className="h-5 w-5" />
        <h2 className="text-2xl font-bold tracking-tight">Usage Analytics</h2>
      </div>

      <Tabs defaultValue="overview" className="space-y-6">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="assets">Asset Usage</TabsTrigger>
          <TabsTrigger value="campaigns">Campaign Performance</TabsTrigger>
          <TabsTrigger value="trends">Trends</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-6">
          {/* Key Metrics */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Total Downloads</p>
                    <p className="text-2xl font-bold">{analytics.totalDownloads}</p>
                  </div>
                  <Download className="h-4 w-4 text-muted-foreground" />
                </div>
                <div className="mt-2 flex items-center text-xs">
                  <TrendingUp className="h-3 w-3 text-green-500 mr-1" />
                  <span className="text-green-500">+12%</span>
                  <span className="text-muted-foreground ml-1">vs last month</span>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Asset Views</p>
                    <p className="text-2xl font-bold">{analytics.totalViews}</p>
                  </div>
                  <Eye className="h-4 w-4 text-muted-foreground" />
                </div>
                <div className="mt-2 flex items-center text-xs">
                  <TrendingUp className="h-3 w-3 text-green-500 mr-1" />
                  <span className="text-green-500">+8%</span>
                  <span className="text-muted-foreground ml-1">vs last month</span>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Active Assets</p>
                    <p className="text-2xl font-bold">{analytics.activeAssets}</p>
                  </div>
                  <Activity className="h-4 w-4 text-muted-foreground" />
                </div>
                <div className="mt-2 flex items-center text-xs">
                  <span className="text-muted-foreground">
                    {Math.round((analytics.activeAssets / brand._count.brandAssets) * 100)}% of total
                  </span>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">Avg. Usage</p>
                    <p className="text-2xl font-bold">{analytics.averageUsage}</p>
                  </div>
                  <Clock className="h-4 w-4 text-muted-foreground" />
                </div>
                <div className="mt-2 text-xs text-muted-foreground">
                  downloads per asset
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Asset Type Performance */}
          <Card>
            <CardHeader>
              <CardTitle>Asset Type Performance</CardTitle>
              <CardDescription>
                Usage breakdown by asset type
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {analytics.assetTypeStats.map((stat) => (
                  <div key={stat.type} className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Badge variant="outline">{stat.type.replace("_", " ")}</Badge>
                        <span className="text-sm text-muted-foreground">
                          {stat.count} assets
                        </span>
                      </div>
                      <div className="text-sm font-medium">
                        {stat.downloads} downloads
                      </div>
                    </div>
                    <Progress 
                      value={(stat.downloads / analytics.totalDownloads) * 100} 
                      className="h-2"
                    />
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Recent Activity */}
          <Card>
            <CardHeader>
              <CardTitle>Recent Activity</CardTitle>
              <CardDescription>
                Latest asset usage and interactions
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {analytics.recentActivity.map((activity, index) => (
                  <div key={index} className="flex items-center gap-4">
                    <div className="w-2 h-2 bg-primary rounded-full" />
                    <div className="flex-1">
                      <p className="text-sm font-medium">{activity.action}</p>
                      <p className="text-xs text-muted-foreground">
                        {activity.asset} • {activity.timeAgo}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="assets" className="space-y-6">
          <AssetUsageAnalytics brand={brand} analytics={analytics} />
        </TabsContent>

        <TabsContent value="campaigns" className="space-y-6">
          <CampaignPerformanceAnalytics brand={brand} />
        </TabsContent>

        <TabsContent value="trends" className="space-y-6">
          <TrendsAnalytics brand={brand} />
        </TabsContent>
      </Tabs>
    </div>
  )
}

function AssetUsageAnalytics({ 
  brand, 
  analytics 
}: { 
  brand: BrandWithRelations
  analytics: ReturnType<typeof calculateBrandAnalytics>
}) {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Top Performing Assets</CardTitle>
          <CardDescription>
            Most downloaded and viewed brand assets
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {analytics.topAssets.map((asset, index) => (
              <div key={asset.id} className="flex items-center gap-4">
                <div className="w-8 h-8 bg-muted rounded flex items-center justify-center text-sm font-medium">
                  #{index + 1}
                </div>
                <div className="flex-1">
                  <p className="font-medium">{asset.name}</p>
                  <p className="text-sm text-muted-foreground">
                    {asset.type.replace("_", " ")} • {asset.category}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-medium">{asset.downloadCount} downloads</p>
                  <p className="text-sm text-muted-foreground">
                    Last used {new Date(asset.lastUsed || asset.updatedAt).toLocaleDateString()}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Asset Utilization</CardTitle>
          <CardDescription>
            Which assets are being used and which are not
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="text-center p-4 bg-green-50 rounded-lg">
                <div className="text-2xl font-bold text-green-700">
                  {analytics.activeAssets}
                </div>
                <div className="text-sm text-green-600">Active Assets</div>
              </div>
              <div className="text-center p-4 bg-yellow-50 rounded-lg">
                <div className="text-2xl font-bold text-yellow-700">
                  {analytics.underutilizedAssets}
                </div>
                <div className="text-sm text-yellow-600">Underutilized</div>
              </div>
              <div className="text-center p-4 bg-red-50 rounded-lg">
                <div className="text-2xl font-bold text-red-700">
                  {analytics.unusedAssets}
                </div>
                <div className="text-sm text-red-600">Unused Assets</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

function CampaignPerformanceAnalytics({ brand }: { brand: BrandWithRelations }) {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Campaign Asset Usage</CardTitle>
          <CardDescription>
            How brand assets are being used across campaigns
          </CardDescription>
        </CardHeader>
        <CardContent>
          {brand.campaigns.length > 0 ? (
            <div className="space-y-4">
              {brand.campaigns.map((campaign) => (
                <div key={campaign.id} className="p-4 border rounded-lg">
                  <div className="flex items-center justify-between mb-2">
                    <h4 className="font-medium">{campaign.name}</h4>
                    <Badge variant="outline">{campaign.status}</Badge>
                  </div>
                  <div className="text-sm text-muted-foreground">
                    Brand asset integration analysis would appear here
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8">
              <Users className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <p className="text-muted-foreground">No campaigns found</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

function TrendsAnalytics({ brand }: { brand: BrandWithRelations }) {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Usage Trends</CardTitle>
          <CardDescription>
            Asset usage patterns over time
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h4 className="font-medium mb-3">Weekly Downloads</h4>
                <div className="h-32 bg-muted rounded-lg flex items-center justify-center">
                  <span className="text-muted-foreground">Chart placeholder</span>
                </div>
              </div>
              <div>
                <h4 className="font-medium mb-3">Asset Type Trends</h4>
                <div className="h-32 bg-muted rounded-lg flex items-center justify-center">
                  <span className="text-muted-foreground">Chart placeholder</span>
                </div>
              </div>
            </div>
            
            <div className="text-center py-4 text-muted-foreground">
              <Calendar className="h-8 w-8 mx-auto mb-2" />
              <p>Trends analysis coming soon</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

// Helper function to calculate analytics
function calculateBrandAnalytics(brand: BrandWithRelations) {
  const assets = brand.brandAssets
  
  const totalDownloads = assets.reduce((sum, asset) => sum + (asset.downloadCount || 0), 0)
  const totalViews = Math.round(totalDownloads * 3.2) // Estimated views based on downloads
  const activeAssets = assets.filter(asset => (asset.downloadCount || 0) > 0).length
  const unusedAssets = assets.filter(asset => (asset.downloadCount || 0) === 0).length
  const underutilizedAssets = assets.filter(asset => {
    const downloads = asset.downloadCount || 0
    return downloads > 0 && downloads < 10
  }).length
  
  const averageUsage = assets.length > 0 ? Math.round(totalDownloads / assets.length) : 0

  // Asset type statistics
  const assetTypeStats = Object.entries(
    assets.reduce((acc, asset) => {
      if (!acc[asset.type]) {
        acc[asset.type] = { count: 0, downloads: 0 }
      }
      acc[asset.type].count++
      acc[asset.type].downloads += asset.downloadCount || 0
      return acc
    }, {} as Record<string, { count: number; downloads: number }>)
  ).map(([type, stats]) => ({
    type,
    count: stats.count,
    downloads: stats.downloads
  })).sort((a, b) => b.downloads - a.downloads)

  // Top performing assets
  const topAssets = [...assets]
    .sort((a, b) => (b.downloadCount || 0) - (a.downloadCount || 0))
    .slice(0, 5)

  // Recent activity (mock data)
  const recentActivity = [
    { action: "Asset downloaded", asset: assets[0]?.name || "Logo", timeAgo: "2 hours ago" },
    { action: "Asset viewed", asset: assets[1]?.name || "Brand Guidelines", timeAgo: "4 hours ago" },
    { action: "Asset downloaded", asset: assets[2]?.name || "Color Palette", timeAgo: "1 day ago" },
  ]

  return {
    totalDownloads,
    totalViews,
    activeAssets,
    unusedAssets,
    underutilizedAssets,
    averageUsage,
    assetTypeStats,
    topAssets,
    recentActivity
  }
}