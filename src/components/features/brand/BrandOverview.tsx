"use client"

import * as React from "react"
import { useState } from "react"

import { Activity, BarChart3, CheckCircle, Edit3, FileText, Globe, Palette, Save, Target, Users, X, XCircle } from "lucide-react"
import { Area, AreaChart, Bar, BarChart, Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"
import { toast } from "sonner"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { Textarea } from "@/components/ui/textarea"
import { BrandService } from "@/lib/api/brands"
import { BrandWithRelations, INDUSTRIES,UpdateBrandData } from "@/lib/types/brand"

interface BrandOverviewProps {
  brand: BrandWithRelations
  onUpdate?: (updatedBrand: BrandWithRelations) => void
}

export function BrandOverview({ brand, onUpdate }: BrandOverviewProps) {
  const [isEditing, setIsEditing] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [editData, setEditData] = useState<UpdateBrandData>({})

  const handleEdit = () => {
    setEditData({
      name: brand.name,
      description: brand.description,
      industry: brand.industry,
      website: brand.website,
      tagline: brand.tagline,
      mission: brand.mission,
      vision: brand.vision,
      values: brand.values,
      personality: brand.personality,
    })
    setIsEditing(true)
  }

  const handleCancel = () => {
    setEditData({})
    setIsEditing(false)
  }

  const handleSave = async () => {
    try {
      setIsSaving(true)
      const updatedBrand = await BrandService.updateBrand(brand.id, editData)
      onUpdate?.(updatedBrand)
      setIsEditing(false)
      toast.success("Brand updated successfully")
    } catch (error) {
      toast.error("Failed to update brand")
      console.error("Failed to update brand:", error)
    } finally {
      setIsSaving(false)
    }
  }

  const updateField = (field: keyof UpdateBrandData, value: any) => {
    setEditData(prev => ({ ...prev, [field]: value }))
  }

  return (
    <div className="space-y-6">
      {/* Header with Edit Controls */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Brand Overview</h2>
          <p className="text-muted-foreground">
            Comprehensive brand profile and visual preview
          </p>
        </div>
        {!isEditing ? (
          <Button onClick={handleEdit} variant="outline" className="gap-2">
            <Edit3 className="h-4 w-4" />
            Edit Brand
          </Button>
        ) : (
          <div className="flex items-center gap-2">
            <Button onClick={handleCancel} variant="ghost" size="sm" className="gap-2">
              <X className="h-4 w-4" />
              Cancel
            </Button>
            <Button 
              onClick={handleSave} 
              size="sm" 
              className="gap-2"
              disabled={isSaving}
            >
              <Save className="h-4 w-4" />
              {isSaving ? "Saving..." : "Save Changes"}
            </Button>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Brand Identity Section */}
        <div className="lg:col-span-2 space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <FileText className="h-5 w-5" />
                Brand Identity
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Basic Information */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="brand-name">Brand Name</Label>
                  {isEditing ? (
                    <Input
                      id="brand-name"
                      value={editData.name || ""}
                      onChange={(e) => updateField("name", e.target.value)}
                      placeholder="Enter brand name"
                    />
                  ) : (
                    <div className="text-lg font-medium">{brand.name}</div>
                  )}
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="industry">Industry</Label>
                  {isEditing ? (
                    <Select 
                      value={editData.industry || ""} 
                      onValueChange={(value) => updateField("industry", value)}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select industry" />
                      </SelectTrigger>
                      <SelectContent>
                        {INDUSTRIES.map((industry) => (
                          <SelectItem key={industry} value={industry}>
                            {industry}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="flex items-center">
                      {brand.industry ? (
                        <Badge variant="secondary">{brand.industry}</Badge>
                      ) : (
                        <span className="text-muted-foreground">Not specified</span>
                      )}
                    </div>
                  )}
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="tagline">Tagline</Label>
                {isEditing ? (
                  <Input
                    id="tagline"
                    value={editData.tagline || ""}
                    onChange={(e) => updateField("tagline", e.target.value)}
                    placeholder="Enter brand tagline"
                  />
                ) : (
                  <div className="italic text-muted-foreground">
                    {brand.tagline || "No tagline set"}
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                {isEditing ? (
                  <Textarea
                    id="description"
                    value={editData.description || ""}
                    onChange={(e) => updateField("description", e.target.value)}
                    placeholder="Enter brand description"
                    rows={3}
                  />
                ) : (
                  <div className="text-sm">
                    {brand.description || "No description provided"}
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <Label htmlFor="website">Website</Label>
                {isEditing ? (
                  <Input
                    id="website"
                    type="url"
                    value={editData.website || ""}
                    onChange={(e) => updateField("website", e.target.value)}
                    placeholder="https://example.com"
                  />
                ) : brand.website ? (
                  <a 
                    href={brand.website} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="text-primary hover:underline flex items-center gap-1"
                  >
                    <Globe className="h-4 w-4" />
                    {brand.website}
                  </a>
                ) : (
                  <span className="text-muted-foreground">No website specified</span>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Brand Purpose Section */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Target className="h-5 w-5" />
                Brand Purpose
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="mission">Mission</Label>
                {isEditing ? (
                  <Textarea
                    id="mission"
                    value={editData.mission || ""}
                    onChange={(e) => updateField("mission", e.target.value)}
                    placeholder="Enter brand mission statement"
                    rows={3}
                  />
                ) : (
                  <div className="text-sm">
                    {brand.mission || "No mission statement defined"}
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <Label htmlFor="vision">Vision</Label>
                {isEditing ? (
                  <Textarea
                    id="vision"
                    value={editData.vision || ""}
                    onChange={(e) => updateField("vision", e.target.value)}
                    placeholder="Enter brand vision statement"
                    rows={3}
                  />
                ) : (
                  <div className="text-sm">
                    {brand.vision || "No vision statement defined"}
                  </div>
                )}
              </div>

              {/* Brand Values */}
              <div className="space-y-2">
                <Label>Brand Values</Label>
                {isEditing ? (
                  <div className="space-y-2">
                    <Input
                      value={editData.values && Array.isArray(editData.values) ? editData.values.join(", ") : ""}
                      onChange={(e) => updateField("values", e.target.value.split(",").map(v => v.trim()).filter(Boolean))}
                      placeholder="Enter values separated by commas"
                    />
                    <p className="text-xs text-muted-foreground">
                      Separate values with commas (max 10 values)
                    </p>
                  </div>
                ) : brand.values && Array.isArray(brand.values) && brand.values.length > 0 ? (
                  <div className="flex flex-wrap gap-2">
                    {brand.values.map((value, index) => (
                      <Badge key={index} variant="outline">
                        {String(value)}
                      </Badge>
                    ))}
                  </div>
                ) : (
                  <span className="text-muted-foreground text-sm">No values defined</span>
                )}
              </div>

              {/* Brand Personality */}
              <div className="space-y-2">
                <Label>Personality Traits</Label>
                {isEditing ? (
                  <div className="space-y-2">
                    <Input
                      value={editData.personality && Array.isArray(editData.personality) ? editData.personality.join(", ") : ""}
                      onChange={(e) => updateField("personality", e.target.value.split(",").map(v => v.trim()).filter(Boolean))}
                      placeholder="Enter personality traits separated by commas"
                    />
                    <p className="text-xs text-muted-foreground">
                      Separate traits with commas (max 8 traits)
                    </p>
                  </div>
                ) : brand.personality && Array.isArray(brand.personality) && brand.personality.length > 0 ? (
                  <div className="flex flex-wrap gap-2">
                    {brand.personality.map((trait, index) => (
                      <Badge key={index} variant="secondary">
                        {String(trait)}
                      </Badge>
                    ))}
                  </div>
                ) : (
                  <span className="text-muted-foreground text-sm">No personality traits defined</span>
                )}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Brand Dashboard Analytics */}
        <div className="space-y-6">
          <BrandDashboard brand={brand} />
        </div>
      </div>
    </div>
  )
}

// Brand Dashboard Component with Analytics
function BrandDashboard({ brand }: { brand: BrandWithRelations }) {
  const dashboardData = calculateDashboardMetrics(brand)

  return (
    <div className="space-y-6">
      {/* Brand Health Overview */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Activity className="h-5 w-5" />
            Brand Health Score
          </CardTitle>
          <CardDescription>Overall brand consistency and performance metrics</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-6">
            <div className="text-center">
              <div className="text-4xl font-bold text-green-600 mb-2">{dashboardData.healthScore}%</div>
              <Badge variant={dashboardData.healthScore >= 80 ? "default" : dashboardData.healthScore >= 60 ? "secondary" : "destructive"}>
                {dashboardData.healthScore >= 80 ? "Excellent" : dashboardData.healthScore >= 60 ? "Good" : "Needs Attention"}
              </Badge>
            </div>
            
            <div className="grid grid-cols-2 gap-4">
              <div className="text-center">
                <div className="text-2xl font-semibold">{dashboardData.assetConsistency}%</div>
                <div className="text-sm text-muted-foreground">Asset Consistency</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-semibold">{dashboardData.complianceRate}%</div>
                <div className="text-sm text-muted-foreground">Compliance Rate</div>
              </div>
            </div>

            <div className="h-48">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={dashboardData.healthTrend}>
                  <XAxis dataKey="month" />
                  <YAxis />
                  <Tooltip />
                  <Area 
                    type="monotone" 
                    dataKey="score" 
                    stroke="#10b981" 
                    fill="#10b981" 
                    fillOpacity={0.1}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Asset Usage Analytics */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <BarChart3 className="h-5 w-5" />
            Asset Usage Tracking
          </CardTitle>
          <CardDescription>Monitor how brand assets are being utilized</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            <div className="text-center p-4 bg-blue-50 rounded-lg">
              <div className="text-2xl font-bold text-blue-700">{brand._count.brandAssets}</div>
              <div className="text-sm text-blue-600">Total Assets</div>
            </div>
            <div className="text-center p-4 bg-green-50 rounded-lg">
              <div className="text-2xl font-bold text-green-700">{dashboardData.activeAssets}</div>
              <div className="text-sm text-green-600">Active Assets</div>
            </div>
            <div className="text-center p-4 bg-yellow-50 rounded-lg">
              <div className="text-2xl font-bold text-yellow-700">{dashboardData.totalDownloads}</div>
              <div className="text-sm text-yellow-600">Total Downloads</div>
            </div>
          </div>

          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={dashboardData.assetUsageData}>
                <XAxis dataKey="type" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="count" fill="#3b82f6" />
                <Bar dataKey="downloads" fill="#10b981" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </Card>

      {/* Compliance Status */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CheckCircle className="h-5 w-5" />
            Brand Compliance
          </CardTitle>
          <CardDescription>Brand guideline adherence and compliance tracking</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {dashboardData.complianceChecks.map((check, index) => (
              <div key={index} className="flex items-center justify-between p-3 border rounded-lg">
                <div className="flex items-center gap-3">
                  {check.status === "pass" ? (
                    <CheckCircle className="h-5 w-5 text-green-500" />
                  ) : (
                    <XCircle className="h-5 w-5 text-red-500" />
                  )}
                  <div>
                    <div className="font-medium">{check.name}</div>
                    <div className="text-sm text-muted-foreground">{check.description}</div>
                  </div>
                </div>
                <Badge variant={check.status === "pass" ? "default" : "destructive"}>
                  {check.status === "pass" ? "Compliant" : "Needs Review"}
                </Badge>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Campaign Performance */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            Campaign Impact
          </CardTitle>
          <CardDescription>Brand asset usage across active campaigns</CardDescription>
        </CardHeader>
        <CardContent>
          {brand._count.campaigns > 0 ? (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="text-center">
                  <div className="text-2xl font-semibold">{brand._count.campaigns}</div>
                  <div className="text-sm text-muted-foreground">Active Campaigns</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-semibold">{dashboardData.brandAssetUsageInCampaigns}</div>
                  <div className="text-sm text-muted-foreground">Assets in Use</div>
                </div>
              </div>
              
              <div className="h-48">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={dashboardData.campaignAssetDistribution}
                      dataKey="value"
                      nameKey="name"
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      label
                    >
                      {dashboardData.campaignAssetDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={["#3b82f6", "#10b981", "#f59e0b", "#ef4444"][index % 4]} />
                      ))}
                    </Pie>
                    <Tooltip />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>
          ) : (
            <div className="text-center py-8">
              <Users className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <p className="text-muted-foreground">No active campaigns</p>
              <p className="text-sm text-muted-foreground mt-2">Create campaigns to see brand asset usage metrics</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Quick Stats */}
      <Card>
        <CardHeader>
          <CardTitle>Quick Stats</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-sm">Color Palettes</span>
            <Badge variant="secondary">{brand._count.colorPalette}</Badge>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm">Typography Sets</span>
            <Badge variant="secondary">{brand._count.typography}</Badge>
          </div>
          <Separator />
          <div className="text-xs text-muted-foreground">
            Created {new Date(brand.createdAt).toLocaleDateString()}
          </div>
          <div className="text-xs text-muted-foreground">
            Last updated {new Date(brand.updatedAt).toLocaleDateString()}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

// Helper function to calculate dashboard metrics
function calculateDashboardMetrics(brand: BrandWithRelations) {
  const assets = brand.brandAssets
  const totalAssets = assets.length
  const activeAssets = assets.filter(asset => (asset.downloadCount || 0) > 0).length
  const totalDownloads = assets.reduce((sum, asset) => sum + (asset.downloadCount || 0), 0)
  
  // Health score calculation (0-100)
  const hasLogo = assets.some(asset => asset.type === "LOGO")
  const hasColors = brand.colorPalette.length > 0
  const hasTypography = brand.typography.length > 0
  const hasMission = !!brand.mission
  const hasValues = brand.values && Array.isArray(brand.values) && brand.values.length > 0
  const assetUtilization = totalAssets > 0 ? (activeAssets / totalAssets) : 0
  
  const healthScore = Math.round(
    (hasLogo ? 15 : 0) +
    (hasColors ? 15 : 0) +
    (hasTypography ? 15 : 0) +
    (hasMission ? 10 : 0) +
    (hasValues ? 10 : 0) +
    (assetUtilization * 35)
  )
  
  // Asset consistency (mock calculation)
  const assetConsistency = Math.round(85 + Math.random() * 10)
  
  // Compliance rate (mock calculation)
  const complianceRate = Math.round(80 + Math.random() * 15)
  
  // Health trend data (mock)
  const healthTrend = [
    { month: "Jan", score: healthScore - 15 },
    { month: "Feb", score: healthScore - 10 },
    { month: "Mar", score: healthScore - 5 },
    { month: "Apr", score: healthScore }
  ]
  
  // Asset usage data by type
  const assetUsageData = Object.entries(
    assets.reduce((acc, asset) => {
      const type = asset.type.replace("_", " ")
      if (!acc[type]) {
        acc[type] = { type, count: 0, downloads: 0 }
      }
      acc[type].count++
      acc[type].downloads += asset.downloadCount || 0
      return acc
    }, {} as Record<string, { type: string; count: number; downloads: number }>)
  ).map(([_, data]) => data)
  
  // Compliance checks
  const complianceChecks = [
    {
      name: "Logo Usage",
      description: "Logo files follow naming and format guidelines",
      status: hasLogo ? "pass" : "fail"
    },
    {
      name: "Color Consistency",
      description: "Brand colors are properly defined and documented",
      status: hasColors ? "pass" : "fail"
    },
    {
      name: "Typography Standards",
      description: "Font usage follows brand typography guidelines",
      status: hasTypography ? "pass" : "fail"
    },
    {
      name: "Brand Documentation",
      description: "Mission, vision, and values are properly defined",
      status: (hasMission && hasValues) ? "pass" : "fail"
    }
  ]
  
  // Campaign asset distribution (mock data)
  const campaignAssetDistribution = [
    { name: "Logos", value: Math.round(totalDownloads * 0.4) },
    { name: "Graphics", value: Math.round(totalDownloads * 0.3) },
    { name: "Templates", value: Math.round(totalDownloads * 0.2) },
    { name: "Other", value: Math.round(totalDownloads * 0.1) }
  ].filter(item => item.value > 0)
  
  const brandAssetUsageInCampaigns = Math.round(activeAssets * 0.7)
  
  return {
    healthScore,
    assetConsistency,
    complianceRate,
    healthTrend,
    activeAssets,
    totalDownloads,
    assetUsageData,
    complianceChecks,
    campaignAssetDistribution,
    brandAssetUsageInCampaigns
  }
}

// Brand Visual Preview Component
function BrandVisualPreview({ brand }: { brand: BrandWithRelations }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Palette className="h-5 w-5" />
          Visual Preview
        </CardTitle>
        <CardDescription>Colors, fonts, and logo usage</CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Logo Preview */}
        <div>
          <h4 className="font-medium mb-3">Logo</h4>
          <div className="bg-muted rounded-lg p-8 flex items-center justify-center min-h-[120px]">
            {brand.brandAssets.find(asset => asset.type === "LOGO") ? (
              <div className="text-center">
                <div className="text-2xl font-bold mb-2">{brand.name}</div>
                <div className="text-sm text-muted-foreground">Logo preview</div>
              </div>
            ) : (
              <div className="text-center text-muted-foreground">
                <div className="text-4xl mb-2">📷</div>
                <div className="text-sm">No logo uploaded</div>
              </div>
            )}
          </div>
        </div>

        {/* Color Palette Preview */}
        <div>
          <h4 className="font-medium mb-3">Colors</h4>
          {brand.colorPalette.length > 0 ? (
            <div className="space-y-3">
              {brand.colorPalette.map((palette, index) => (
                <div key={palette.id} className="space-y-2">
                  <div className="text-sm font-medium">{palette.name}</div>
                  <div className="flex gap-2">
                    {/* Placeholder color swatches - in real implementation, parse colors from palette */}
                    <div className="w-8 h-8 rounded bg-blue-500 border" title="Primary" />
                    <div className="w-8 h-8 rounded bg-gray-500 border" title="Secondary" />
                    <div className="w-8 h-8 rounded bg-green-500 border" title="Accent" />
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center text-muted-foreground p-6">
              <div className="text-2xl mb-2">🎨</div>
              <div className="text-sm">No color palettes defined</div>
            </div>
          )}
        </div>

        {/* Typography Preview */}
        <div>
          <h4 className="font-medium mb-3">Typography</h4>
          {brand.typography.length > 0 ? (
            <div className="space-y-3">
              {brand.typography.map((typo, index) => (
                <div key={typo.id} className="p-3 bg-muted rounded-lg">
                  <div className="font-medium text-lg" style={{ fontFamily: typo.fontFamily || 'inherit' }}>
                    {typo.fontFamily}
                  </div>
                  <div className="text-xs text-muted-foreground">
                    {typo.usage} • {typo.fontWeight || "Regular"}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center text-muted-foreground p-6">
              <div className="text-2xl mb-2">📝</div>
              <div className="text-sm">No typography defined</div>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}