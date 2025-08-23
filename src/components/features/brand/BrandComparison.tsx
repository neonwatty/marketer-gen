"use client"

import * as React from "react"
import { useEffect,useState } from "react"

import { 
  BarChart3, 
  GitCompare, 
  Image as ImageIcon,
  Palette, 
  Plus, 
  Users,
  X} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { BrandService } from "@/lib/api/brands"
import { BrandSummary,BrandWithRelations } from "@/lib/types/brand"

interface BrandComparisonProps {
  currentBrand: BrandWithRelations
}

export function BrandComparison({ currentBrand }: BrandComparisonProps) {
  const [availableBrands, setAvailableBrands] = useState<BrandSummary[]>([])
  const [selectedBrands, setSelectedBrands] = useState<BrandWithRelations[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [comparisonMode, setComparisonMode] = useState<"overview" | "visual" | "metrics">("overview")

  useEffect(() => {
    loadAvailableBrands()
  }, [currentBrand.id])

  const loadAvailableBrands = async () => {
    try {
      const response = await BrandService.getBrands()
      const otherBrands = response.brands.filter(brand => brand.id !== currentBrand.id)
      setAvailableBrands(otherBrands)
    } catch (error) {
      console.error("Failed to load brands:", error)
    } finally {
      setIsLoading(false)
    }
  }

  const addBrandToComparison = async (brandId: string) => {
    if (selectedBrands.length >= 3) return // Limit to 3 comparisons
    
    try {
      const brand = await BrandService.getBrand(brandId)
      setSelectedBrands(prev => [...prev, brand])
    } catch (error) {
      console.error("Failed to load brand for comparison:", error)
    }
  }

  const removeBrandFromComparison = (brandId: string) => {
    setSelectedBrands(prev => prev.filter(brand => brand.id !== brandId))
  }

  const brands = [currentBrand, ...selectedBrands]

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <GitCompare className="h-5 w-5" />
          <h2 className="text-2xl font-bold tracking-tight">Brand Comparison</h2>
        </div>
        
        <div className="flex items-center gap-2">
          <Select value={comparisonMode} onValueChange={(value: any) => setComparisonMode(value)}>
            <SelectTrigger className="w-40" aria-label="Select comparison mode">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="overview">Overview</SelectItem>
              <SelectItem value="visual">Visual</SelectItem>
              <SelectItem value="metrics">Metrics</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Brand Selection */}
      <Card>
        <CardHeader>
          <CardTitle>Compare Brands</CardTitle>
          <CardDescription>
            Add up to 3 brands to compare against {currentBrand.name}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {/* Current Brand */}
            <div className="flex items-center justify-between p-3 bg-primary/10 rounded-lg">
              <div className="flex items-center gap-3">
                <div className="font-medium">{currentBrand.name}</div>
                <Badge>Current Brand</Badge>
              </div>
            </div>

            {/* Selected Brands */}
            {selectedBrands.map(brand => (
              <div key={brand.id} className="flex items-center justify-between p-3 border rounded-lg">
                <div className="flex items-center gap-3">
                  <div className="font-medium">{brand.name}</div>
                  <Badge variant="outline">{brand.industry}</Badge>
                </div>
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={() => removeBrandFromComparison(brand.id)}
                  className="gap-2"
                  aria-label={`Remove ${brand.name} from comparison`}
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ))}

            {/* Add Brand Selection */}
            {selectedBrands.length < 3 && (
              <div className="p-3 border-2 border-dashed rounded-lg">
                <div className="flex items-center gap-3">
                  <Select onValueChange={addBrandToComparison}>
                    <SelectTrigger className="flex-1" aria-label="Select a brand to compare">
                      <SelectValue placeholder="Select a brand to compare" />
                    </SelectTrigger>
                    <SelectContent>
                      {availableBrands
                        .filter(brand => !selectedBrands.find(selected => selected.id === brand.id))
                        .map(brand => (
                          <SelectItem key={brand.id} value={brand.id}>
                            {brand.name} {brand.industry && `(${brand.industry})`}
                          </SelectItem>
                        ))}
                    </SelectContent>
                  </Select>
                  <Button size="sm" variant="ghost" className="gap-2">
                    <Plus className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            )}

            {availableBrands.length === 0 && !isLoading && (
              <div className="text-center py-8 text-muted-foreground">
                <Users className="h-12 w-12 mx-auto mb-4" />
                <p>No other brands available for comparison</p>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Comparison Content */}
      {selectedBrands.length > 0 && (
        <>
          {comparisonMode === "overview" && <OverviewComparison brands={brands} />}
          {comparisonMode === "visual" && <VisualComparison brands={brands} />}
          {comparisonMode === "metrics" && <MetricsComparison brands={brands} />}
        </>
      )}

      {selectedBrands.length === 0 && (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-16">
            <GitCompare className="h-12 w-12 text-muted-foreground mb-4" />
            <h3 className="text-lg font-medium mb-2">No brands selected for comparison</h3>
            <p className="text-muted-foreground text-center max-w-sm">
              Select brands from the dropdown above to compare their attributes, assets, and performance.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

function OverviewComparison({ brands }: { brands: BrandWithRelations[] }) {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Brand Overview Comparison</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b">
                  <th className="text-left p-3">Attribute</th>
                  {brands.map(brand => (
                    <th key={brand.id} className="text-left p-3 min-w-[200px]">
                      {brand.name}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                <tr className="border-b">
                  <td className="p-3 font-medium">Industry</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3">
                      {brand.industry ? (
                        <Badge variant="outline">{brand.industry}</Badge>
                      ) : (
                        <span className="text-muted-foreground">Not specified</span>
                      )}
                    </td>
                  ))}
                </tr>
                
                <tr className="border-b">
                  <td className="p-3 font-medium">Tagline</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3 text-sm">
                      {brand.tagline || (
                        <span className="text-muted-foreground">No tagline</span>
                      )}
                    </td>
                  ))}
                </tr>

                <tr className="border-b">
                  <td className="p-3 font-medium">Description</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3 text-sm max-w-xs">
                      <div className="line-clamp-3">
                        {brand.description || (
                          <span className="text-muted-foreground">No description</span>
                        )}
                      </div>
                    </td>
                  ))}
                </tr>

                <tr className="border-b">
                  <td className="p-3 font-medium">Website</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3 text-sm">
                      {brand.website ? (
                        <a 
                          href={brand.website} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          className="text-primary hover:underline"
                        >
                          {brand.website.replace(/^https?:\/\//, '')}
                        </a>
                      ) : (
                        <span className="text-muted-foreground">Not provided</span>
                      )}
                    </td>
                  ))}
                </tr>

                <tr className="border-b">
                  <td className="p-3 font-medium">Brand Values</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3">
                      {brand.values && Array.isArray(brand.values) && brand.values.length > 0 ? (
                        <div className="flex flex-wrap gap-1">
                          {brand.values.slice(0, 2).map((value, index) => (
                            <Badge key={index} variant="outline" className="text-xs">
                              {String(value)}
                            </Badge>
                          ))}
                          {brand.values.length > 2 && (
                            <Badge variant="outline" className="text-xs">
                              +{brand.values.length - 2}
                            </Badge>
                          )}
                        </div>
                      ) : (
                        <span className="text-muted-foreground text-sm">None defined</span>
                      )}
                    </td>
                  ))}
                </tr>
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

function VisualComparison({ brands }: { brands: BrandWithRelations[] }) {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
        {brands.map(brand => (
          <Card key={brand.id}>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Palette className="h-5 w-5" />
                {brand.name}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Logo Section */}
              <div>
                <h4 className="font-medium mb-2">Logo</h4>
                <div className="bg-muted rounded-lg p-6 flex items-center justify-center min-h-[100px]">
                  {brand.brandAssets.find(asset => asset.type === "LOGO") ? (
                    <div className="text-center">
                      <div className="text-lg font-bold">{brand.name}</div>
                      <div className="text-xs text-muted-foreground">Logo preview</div>
                    </div>
                  ) : (
                    <div className="text-center text-muted-foreground">
                      <ImageIcon className="h-8 w-8 mx-auto mb-2" />
                      <div className="text-xs">No logo</div>
                    </div>
                  )}
                </div>
              </div>

              {/* Colors Section */}
              <div>
                <h4 className="font-medium mb-2">Colors</h4>
                {brand.colorPalette.length > 0 ? (
                  <div className="space-y-2">
                    {brand.colorPalette.slice(0, 2).map(palette => (
                      <div key={palette.id} className="space-y-1">
                        <div className="text-xs font-medium">{palette.name}</div>
                        <div className="flex gap-1">
                          <div className="w-6 h-6 rounded bg-blue-500 border" />
                          <div className="w-6 h-6 rounded bg-gray-500 border" />
                          <div className="w-6 h-6 rounded bg-green-500 border" />
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-xs text-muted-foreground">No color palettes</div>
                )}
              </div>

              {/* Typography Section */}
              <div>
                <h4 className="font-medium mb-2">Typography</h4>
                {brand.typography.length > 0 ? (
                  <div className="space-y-1">
                    {brand.typography.slice(0, 2).map(typo => (
                      <div key={typo.id} className="text-sm">
                        <span className="font-medium">{typo.fontFamily}</span>
                        <span className="text-muted-foreground text-xs ml-2">
                          {typo.usage}
                        </span>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-xs text-muted-foreground">No typography defined</div>
                )}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}

function MetricsComparison({ brands }: { brands: BrandWithRelations[] }) {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <BarChart3 className="h-5 w-5" />
            Brand Metrics Comparison
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b">
                  <th className="text-left p-3">Metric</th>
                  {brands.map(brand => (
                    <th key={brand.id} className="text-left p-3 min-w-[150px]">
                      {brand.name}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                <tr className="border-b">
                  <td className="p-3 font-medium">Total Assets</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3">
                      <Badge variant="secondary">{brand._count.brandAssets}</Badge>
                    </td>
                  ))}
                </tr>

                <tr className="border-b">
                  <td className="p-3 font-medium">Active Campaigns</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3">
                      <Badge variant="secondary">{brand._count.campaigns}</Badge>
                    </td>
                  ))}
                </tr>

                <tr className="border-b">
                  <td className="p-3 font-medium">Color Palettes</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3">
                      <Badge variant="secondary">{brand._count.colorPalette}</Badge>
                    </td>
                  ))}
                </tr>

                <tr className="border-b">
                  <td className="p-3 font-medium">Typography Sets</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3">
                      <Badge variant="secondary">{brand._count.typography}</Badge>
                    </td>
                  ))}
                </tr>

                <tr className="border-b">
                  <td className="p-3 font-medium">Total Downloads</td>
                  {brands.map(brand => {
                    const totalDownloads = brand.brandAssets.reduce(
                      (sum, asset) => sum + (asset.downloadCount || 0), 0
                    )
                    return (
                      <td key={brand.id} className="p-3">
                        <Badge variant="secondary">{totalDownloads}</Badge>
                      </td>
                    )
                  })}
                </tr>

                <tr>
                  <td className="p-3 font-medium">Created</td>
                  {brands.map(brand => (
                    <td key={brand.id} className="p-3 text-sm text-muted-foreground">
                      {new Date(brand.createdAt).toLocaleDateString()}
                    </td>
                  ))}
                </tr>
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* Asset Type Distribution */}
      <Card>
        <CardHeader>
          <CardTitle>Asset Type Distribution</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-6">
            {brands.map(brand => {
              const assetTypes = brand.brandAssets.reduce((acc, asset) => {
                acc[asset.type] = (acc[asset.type] || 0) + 1
                return acc
              }, {} as Record<string, number>)

              return (
                <div key={brand.id}>
                  <h4 className="font-medium mb-3">{brand.name}</h4>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                    {Object.entries(assetTypes).map(([type, count]) => (
                      <div key={type} className="text-center p-2 bg-muted rounded">
                        <div className="text-sm font-medium">{count}</div>
                        <div className="text-xs text-muted-foreground">
                          {type.replace('_', ' ')}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )
            })}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}