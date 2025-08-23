"use client"

import * as React from "react"
import { useState } from "react"

import { Edit3, FileText, Globe, Palette, Save, Target, X } from "lucide-react"
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

        {/* Brand Visual Preview */}
        <div className="space-y-6">
          <BrandVisualPreview brand={brand} />
          
          {/* Quick Stats */}
          <Card>
            <CardHeader>
              <CardTitle>Brand Usage Stats</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm">Total Assets</span>
                <Badge variant="secondary">{brand._count.brandAssets}</Badge>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Active Campaigns</span>
                <Badge variant="secondary">{brand._count.campaigns}</Badge>
              </div>
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
      </div>
    </div>
  )
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