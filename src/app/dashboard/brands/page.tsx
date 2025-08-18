"use client"

import * as React from "react"
import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { 
  BrandAssetLibrary, 
  BrandOverview, 
  BrandAnalytics, 
  BrandGuidelines, 
  BrandComparison 
} from "@/components/features/brand"
import { Plus, Search, Settings, BarChart3, FileText, Palette, Type, Image, Eye } from "lucide-react"
import { BrandWithRelations, BrandSummary } from "@/lib/types/brand"
import { BrandService } from "@/lib/api/brands"

export default function BrandDashboardPage() {
  const [brands, setBrands] = useState<BrandSummary[]>([])
  const [selectedBrand, setSelectedBrand] = useState<BrandWithRelations | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState("")
  const [selectedIndustry, setSelectedIndustry] = useState<string>("all")

  // Load brands on mount
  useEffect(() => {
    const loadBrands = async () => {
      try {
        const response = await BrandService.getBrands()
        setBrands(response.brands)
      } catch (error) {
        console.error("Failed to load brands:", error)
      } finally {
        setIsLoading(false)
      }
    }

    loadBrands()
  }, [])

  // Filter brands based on search and industry
  const filteredBrands = brands.filter(brand => {
    const matchesSearch = !searchQuery || 
      brand.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      brand.description?.toLowerCase().includes(searchQuery.toLowerCase())
    
    const matchesIndustry = selectedIndustry === "all" || brand.industry === selectedIndustry
    
    return matchesSearch && matchesIndustry
  })

  // Get unique industries
  const industries = Array.from(new Set(brands.map(b => b.industry).filter(Boolean)))

  const handleBrandSelect = async (brandId: string) => {
    try {
      setIsLoading(true)
      const brand = await BrandService.getBrand(brandId)
      setSelectedBrand(brand)
    } catch (error) {
      console.error("Failed to load brand details:", error)
    } finally {
      setIsLoading(false)
    }
  }

  const handleCreateBrand = () => {
    // TODO: Open create brand modal
    console.log("Create new brand")
  }

  if (isLoading && brands.length === 0) {
    return (
      <div className="container mx-auto p-6 space-y-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-1/3"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="h-48 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  if (selectedBrand) {
    return (
      <BrandManagementDashboard 
        brand={selectedBrand} 
        onBack={() => setSelectedBrand(null)}
      />
    )
  }

  return (
    <div className="container mx-auto p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Brand Management</h1>
          <p className="text-muted-foreground">
            Manage your brand profiles and assets
          </p>
        </div>
        <Button onClick={handleCreateBrand} className="gap-2">
          <Plus className="h-4 w-4" />
          Create Brand
        </Button>
      </div>

      {/* Search and Filters */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col gap-4 md:flex-row md:items-center">
            <div className="relative flex-1 max-w-sm">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search brands..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9"
              />
            </div>
            
            {industries.length > 0 && (
              <Select value={selectedIndustry} onValueChange={setSelectedIndustry}>
                <SelectTrigger className="w-40">
                  <SelectValue placeholder="All Industries" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Industries</SelectItem>
                  {industries.map((industry) => (
                    <SelectItem key={industry} value={industry!}>
                      {industry}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Brand Cards Grid */}
      {filteredBrands.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-16">
            <div className="text-4xl mb-4">🏷️</div>
            <h3 className="text-lg font-medium mb-2">No brands found</h3>
            <p className="text-muted-foreground text-center max-w-sm mb-4">
              {brands.length === 0 
                ? "Create your first brand to get started with brand management"
                : "Try adjusting your search or filter criteria"
              }
            </p>
            {brands.length === 0 && (
              <Button onClick={handleCreateBrand} className="gap-2">
                <Plus className="h-4 w-4" />
                Create Your First Brand
              </Button>
            )}
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredBrands.map((brand) => (
            <BrandCard
              key={brand.id}
              brand={brand}
              onSelect={handleBrandSelect}
            />
          ))}
        </div>
      )}
    </div>
  )
}

// Brand Card Component
function BrandCard({
  brand,
  onSelect,
}: {
  brand: BrandSummary
  onSelect: (brandId: string) => void
}) {
  return (
    <Card className="hover:shadow-md transition-shadow cursor-pointer" onClick={() => onSelect(brand.id)}>
      <CardContent className="p-6">
        <div className="space-y-4">
          {/* Brand Header */}
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <h3 className="font-semibold text-lg leading-none">{brand.name}</h3>
              {brand.tagline && (
                <p className="text-sm text-muted-foreground mt-1">{brand.tagline}</p>
              )}
            </div>
            <Button size="sm" variant="ghost" className="p-1 h-8 w-8">
              <Eye className="h-4 w-4" />
            </Button>
          </div>

          {/* Description */}
          {brand.description && (
            <p className="text-sm text-muted-foreground line-clamp-2">
              {brand.description}
            </p>
          )}

          {/* Industry Badge */}
          {brand.industry && (
            <Badge variant="secondary">{brand.industry}</Badge>
          )}

          {/* Stats */}
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <div className="font-medium">{brand._count.campaigns}</div>
              <div className="text-muted-foreground">Campaigns</div>
            </div>
            <div>
              <div className="font-medium">{brand._count.brandAssets}</div>
              <div className="text-muted-foreground">Assets</div>
            </div>
          </div>

          {/* Updated Date */}
          <div className="text-xs text-muted-foreground">
            Updated {new Date(brand.updatedAt).toLocaleDateString()}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

// Main Brand Dashboard Component
function BrandManagementDashboard({
  brand: initialBrand,
  onBack,
}: {
  brand: BrandWithRelations
  onBack: () => void
}) {
  const [activeTab, setActiveTab] = useState("overview")
  const [brand, setBrand] = useState(initialBrand)

  const setSelectedBrand = setBrand

  return (
    <div className="container mx-auto p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Button variant="ghost" onClick={onBack} className="gap-2">
          ← Back to Brands
        </Button>
        <div className="flex-1">
          <h1 className="text-3xl font-bold tracking-tight">{brand.name}</h1>
          <p className="text-muted-foreground">{brand.tagline || "Brand Management Dashboard"}</p>
        </div>
        <Button variant="outline" className="gap-2">
          <Settings className="h-4 w-4" />
          Settings
        </Button>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold">{brand._count.brandAssets}</div>
            <div className="text-sm text-muted-foreground">Total Assets</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold">{brand._count.campaigns}</div>
            <div className="text-sm text-muted-foreground">Active Campaigns</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold">{brand._count.colorPalette}</div>
            <div className="text-sm text-muted-foreground">Color Palettes</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold">{brand._count.typography}</div>
            <div className="text-sm text-muted-foreground">Typography Sets</div>
          </CardContent>
        </Card>
      </div>

      {/* Main Content Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
        <TabsList className="grid w-full grid-cols-5">
          <TabsTrigger value="overview" className="gap-2">
            <Eye className="h-4 w-4" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="assets" className="gap-2">
            <Image className="h-4 w-4" />
            Assets
          </TabsTrigger>
          <TabsTrigger value="guidelines" className="gap-2">
            <FileText className="h-4 w-4" />
            Guidelines
          </TabsTrigger>
          <TabsTrigger value="analytics" className="gap-2">
            <BarChart3 className="h-4 w-4" />
            Analytics
          </TabsTrigger>
          <TabsTrigger value="compare" className="gap-2">
            <Settings className="h-4 w-4" />
            Compare
          </TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-6">
          <BrandOverview 
            brand={brand}
            onUpdate={(updatedBrand) => {
              setSelectedBrand(updatedBrand)
            }}
          />
        </TabsContent>

        <TabsContent value="assets" className="space-y-6">
          <BrandAssetLibrary
            brandId={brand.id}
            assets={brand.brandAssets}
            onUpload={() => console.log("Upload assets")}
            onEdit={(asset) => console.log("Edit asset:", asset)}
            onDelete={(assetId) => console.log("Delete asset:", assetId)}
            onDownload={(asset) => console.log("Download asset:", asset)}
            onPreview={(asset) => console.log("Preview asset:", asset)}
          />
        </TabsContent>

        <TabsContent value="guidelines" className="space-y-6">
          <BrandGuidelines 
            brand={brand}
            onUploadGuidelines={() => console.log("Upload guidelines")}
            onParseDocument={(asset) => console.log("Parse document:", asset)}
          />
        </TabsContent>

        <TabsContent value="analytics" className="space-y-6">
          <BrandAnalytics brand={brand} />
        </TabsContent>

        <TabsContent value="compare" className="space-y-6">
          <BrandComparison currentBrand={brand} />
        </TabsContent>
      </Tabs>
    </div>
  )
}

