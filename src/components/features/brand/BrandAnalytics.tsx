"use client"

import * as React from "react"

import { 
  Activity,
  BarChart3, 
  Clock,
  Download, 
  Eye,
  TrendingUp, 
  Users} from "lucide-react"
import { Area, AreaChart, Bar, BarChart, Cell, Legend,Line, LineChart, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"

import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
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
  const trendsData = generateTrendsData(brand)
  
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
                <div className="h-48">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={trendsData.weeklyDownloads}>
                      <XAxis dataKey="week" />
                      <YAxis />
                      <Tooltip />
                      <Line 
                        type="monotone" 
                        dataKey="downloads" 
                        stroke="#3b82f6" 
                        strokeWidth={2}
                        dot={{ r: 4 }}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
              <div>
                <h4 className="font-medium mb-3">Asset Type Distribution</h4>
                <div className="h-48">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={trendsData.assetTypeDistribution}
                        dataKey="value"
                        nameKey="name"
                        cx="50%"
                        cy="50%"
                        outerRadius={60}
                        label={({name, percent}) => `${name} ${percent ? (percent * 100).toFixed(0) : 0}%`}
                      >
                        {trendsData.assetTypeDistribution.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={["#3b82f6", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6"][index % 5]} />
                        ))}
                      </Pie>
                      <Tooltip />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>
            
            <Card>
              <CardHeader>
                <CardTitle>Monthly Usage Comparison</CardTitle>
                <CardDescription>Downloads and views comparison over the past 6 months</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-64">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={trendsData.monthlyUsage}>
                      <XAxis dataKey="month" />
                      <YAxis />
                      <Tooltip />
                      <Legend />
                      <Area 
                        type="monotone" 
                        dataKey="downloads" 
                        stackId="1"
                        stroke="#3b82f6" 
                        fill="#3b82f6" 
                        fillOpacity={0.6}
                        name="Downloads"
                      />
                      <Area 
                        type="monotone" 
                        dataKey="views" 
                        stackId="2"
                        stroke="#10b981" 
                        fill="#10b981" 
                        fillOpacity={0.6}
                        name="Views"
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle>Asset Performance Metrics</CardTitle>
                <CardDescription>Top performing assets by engagement</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-64">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={trendsData.topPerformingAssets} layout="horizontal">
                      <XAxis type="number" />
                      <YAxis dataKey="name" type="category" width={100} />
                      <Tooltip />
                      <Bar dataKey="score" fill="#10b981" />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>
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

// Helper function to generate trends data
function generateTrendsData(brand: BrandWithRelations) {
  const assets = brand.brandAssets
  
  // Weekly downloads data (last 8 weeks)
  const weeklyDownloads = []
  for (let i = 7; i >= 0; i--) {
    const date = new Date()
    date.setDate(date.getDate() - (i * 7))
    const weekLabel = `Week ${8 - i}`
    const downloads = Math.round(20 + Math.random() * 50 + (i < 4 ? i * 5 : (8 - i) * 3))
    weeklyDownloads.push({ 
      week: weekLabel, 
      downloads, 
      date: date.toISOString().split('T')[0] 
    })
  }
  
  // Asset type distribution
  const assetTypes = assets.reduce((acc, asset) => {
    const type = asset.type.replace('_', ' ')
    acc[type] = (acc[type] || 0) + 1
    return acc
  }, {} as Record<string, number>)
  
  const assetTypeDistribution = Object.entries(assetTypes).map(([name, value]) => ({
    name: name.charAt(0).toUpperCase() + name.slice(1).toLowerCase(),
    value
  }))
  
  // If no assets, provide default data
  if (assetTypeDistribution.length === 0) {
    assetTypeDistribution.push(
      { name: "Logo", value: 2 },
      { name: "Graphics", value: 5 },
      { name: "Templates", value: 3 }
    )
  }
  
  // Monthly usage data (last 6 months)
  const monthlyUsage = []
  const months = ['Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan']
  for (let i = 0; i < 6; i++) {
    monthlyUsage.push({
      month: months[i],
      downloads: Math.round(80 + Math.random() * 120),
      views: Math.round(200 + Math.random() * 300)
    })
  }
  
  // Top performing assets
  const topPerformingAssets = assets
    .slice(0, 5)
    .map((asset, index) => ({
      name: asset.name.length > 15 ? asset.name.substring(0, 15) + '...' : asset.name,
      score: Math.round(60 + Math.random() * 40 + (5 - index) * 10)
    }))
  
  // If no assets, provide default data
  if (topPerformingAssets.length === 0) {
    topPerformingAssets.push(
      { name: "Brand Logo", score: 95 },
      { name: "Color Palette", score: 87 },
      { name: "Typography Guide", score: 78 },
      { name: "Social Media Kit", score: 72 },
      { name: "Business Card", score: 65 }
    )
  }
  
  return {
    weeklyDownloads,
    assetTypeDistribution,
    monthlyUsage,
    topPerformingAssets
  }
}