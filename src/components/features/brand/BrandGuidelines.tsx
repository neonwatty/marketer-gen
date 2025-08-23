"use client"

import * as React from "react"
import { useState } from "react"

import { 
  BookOpen,
  Download, 
  Eye, 
  FileText,
  MessageSquare,
  Palette,
  Plus,
  Search, 
  Shield,
  Upload} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { BrandAsset, BrandWithRelations, PARSEABLE_ASSET_TYPES } from "@/lib/types/brand"

interface BrandGuidelinesProps {
  brand: BrandWithRelations
  onUploadGuidelines?: () => void
  onParseDocument?: (asset: BrandAsset) => void
}

export function BrandGuidelines({ 
  brand, 
  onUploadGuidelines,
  onParseDocument 
}: BrandGuidelinesProps) {
  const [searchQuery, setSearchQuery] = useState("")
  const [selectedCategory, setSelectedCategory] = useState<string>("all")

  // Filter guidelines assets
  const guidelineAssets = brand.brandAssets.filter(asset => 
    asset.type === "BRAND_GUIDELINES" || asset.type === "DOCUMENT"
  )

  const filteredAssets = guidelineAssets.filter(asset => {
    const matchesSearch = !searchQuery || 
      asset.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      asset.description?.toLowerCase().includes(searchQuery.toLowerCase())
    
    const matchesCategory = selectedCategory === "all" || asset.category === selectedCategory
    
    return matchesSearch && matchesCategory
  })

  // Get unique categories
  const categories = Array.from(new Set(
    guidelineAssets.map(asset => asset.category).filter((cat): cat is string => Boolean(cat))
  ))

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <FileText className="h-5 w-5" />
          <h2 className="text-2xl font-bold tracking-tight">Brand Guidelines</h2>
        </div>
        <Button onClick={onUploadGuidelines} className="gap-2">
          <Plus className="h-4 w-4" />
          Add Guidelines
        </Button>
      </div>

      <Tabs defaultValue="documents" className="space-y-6">
        <TabsList>
          <TabsTrigger value="documents">Documents</TabsTrigger>
          <TabsTrigger value="standards">Brand Standards</TabsTrigger>
          <TabsTrigger value="voice">Voice & Tone</TabsTrigger>
          <TabsTrigger value="compliance">Compliance</TabsTrigger>
        </TabsList>

        <TabsContent value="documents" className="space-y-6">
          <DocumentsSection 
            assets={filteredAssets}
            searchQuery={searchQuery}
            onSearchChange={setSearchQuery}
            selectedCategory={selectedCategory}
            onCategoryChange={setSelectedCategory}
            categories={categories}
            onParseDocument={onParseDocument}
          />
        </TabsContent>

        <TabsContent value="standards" className="space-y-6">
          <BrandStandardsSection brand={brand} />
        </TabsContent>

        <TabsContent value="voice" className="space-y-6">
          <VoiceAndToneSection brand={brand} />
        </TabsContent>

        <TabsContent value="compliance" className="space-y-6">
          <ComplianceSection brand={brand} />
        </TabsContent>
      </Tabs>
    </div>
  )
}

function DocumentsSection({
  assets,
  searchQuery,
  onSearchChange,
  selectedCategory,
  onCategoryChange,
  categories,
  onParseDocument
}: {
  assets: BrandAsset[]
  searchQuery: string
  onSearchChange: (query: string) => void
  selectedCategory: string
  onCategoryChange: (category: string) => void
  categories: string[]
  onParseDocument?: (asset: BrandAsset) => void
}) {
  return (
    <div className="space-y-6">
      {/* Search and Filter */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col gap-4 md:flex-row md:items-center">
            <div className="relative flex-1 max-w-sm">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search guidelines..."
                value={searchQuery}
                onChange={(e) => onSearchChange(e.target.value)}
                className="pl-9"
              />
            </div>
            
            {categories.length > 0 && (
              <select 
                value={selectedCategory}
                onChange={(e) => onCategoryChange(e.target.value)}
                className="px-3 py-2 border rounded-md"
              >
                <option value="all">All Categories</option>
                {categories.map(category => (
                  <option key={category} value={category}>{category}</option>
                ))}
              </select>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Documents Grid */}
      {assets.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-16">
            <BookOpen className="h-12 w-12 text-muted-foreground mb-4" />
            <h3 className="text-lg font-medium mb-2">No guidelines documents</h3>
            <p className="text-muted-foreground text-center max-w-sm">
              Upload your brand guidelines, style guides, and documentation to get started.
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {assets.map((asset) => (
            <GuidelineDocumentCard
              key={asset.id}
              asset={asset}
              onParseDocument={onParseDocument}
            />
          ))}
        </div>
      )}
    </div>
  )
}

function GuidelineDocumentCard({
  asset,
  onParseDocument
}: {
  asset: BrandAsset
  onParseDocument?: (asset: BrandAsset) => void
}) {
  const canParse = PARSEABLE_ASSET_TYPES.includes(asset.type as any)

  const formatFileSize = (bytes?: number) => {
    if (!bytes) return "Unknown"
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(1024))
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + " " + sizes[i]
  }

  return (
    <Card className="hover:shadow-md transition-shadow">
      <CardContent className="p-6">
        <div className="space-y-4">
          {/* Document Icon & Info */}
          <div className="flex items-start gap-3">
            <div className="w-12 h-12 bg-muted rounded-lg flex items-center justify-center">
              {asset.type === "BRAND_GUIDELINES" ? (
                <BookOpen className="h-6 w-6 text-muted-foreground" />
              ) : (
                <FileText className="h-6 w-6 text-muted-foreground" />
              )}
            </div>
            <div className="flex-1 min-w-0">
              <h3 className="font-medium truncate">{asset.name}</h3>
              <p className="text-sm text-muted-foreground truncate">
                {asset.fileName}
              </p>
            </div>
          </div>

          {/* Description */}
          {asset.description && (
            <p className="text-sm text-muted-foreground line-clamp-2">
              {asset.description}
            </p>
          )}

          {/* Metadata */}
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Badge variant="outline">{asset.type.replace("_", " ")}</Badge>
              {asset.category && (
                <Badge variant="secondary">{asset.category}</Badge>
              )}
            </div>
            
            <div className="text-xs text-muted-foreground space-y-1">
              <div>Size: {formatFileSize(asset.fileSize ?? undefined)}</div>
              <div>Updated: {new Date(asset.updatedAt).toLocaleDateString()}</div>
              {asset.downloadCount !== undefined && (
                <div>Downloads: {asset.downloadCount}</div>
              )}
            </div>
          </div>

          {/* Actions */}
          <div className="flex gap-2">
            <Button size="sm" variant="outline" className="flex-1 gap-2">
              <Eye className="h-4 w-4" />
              View
            </Button>
            <Button size="sm" variant="outline" className="flex-1 gap-2">
              <Download className="h-4 w-4" />
              Download
            </Button>
            {canParse && onParseDocument && (
              <Button 
                size="sm" 
                variant="default" 
                onClick={() => onParseDocument(asset)}
                className="flex-1 gap-2"
              >
                <Upload className="h-4 w-4" />
                Parse
              </Button>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function BrandStandardsSection({ brand }: { brand: BrandWithRelations }) {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Visual Standards */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Palette className="h-5 w-5" />
              Visual Standards
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <h4 className="font-medium mb-2">Color Usage</h4>
              <p className="text-sm text-muted-foreground">
                {brand.colorPalette.length > 0 
                  ? `${brand.colorPalette.length} color palette${brand.colorPalette.length === 1 ? '' : 's'} defined`
                  : "No color palettes defined"
                }
              </p>
            </div>
            
            <div>
              <h4 className="font-medium mb-2">Typography Rules</h4>
              <p className="text-sm text-muted-foreground">
                {brand.typography.length > 0
                  ? `${brand.typography.length} typography set${brand.typography.length === 1 ? '' : 's'} defined`
                  : "No typography guidelines defined"
                }
              </p>
            </div>

            <div>
              <h4 className="font-medium mb-2">Logo Guidelines</h4>
              <p className="text-sm text-muted-foreground">
                {brand.brandAssets.some(a => a.type === "LOGO")
                  ? "Logo assets available"
                  : "No logo assets uploaded"
                }
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Content Standards */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <MessageSquare className="h-5 w-5" />
              Content Standards
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <h4 className="font-medium mb-2">Voice Description</h4>
              <p className="text-sm text-muted-foreground">
                {brand.voiceDescription || "No voice description defined"}
              </p>
            </div>

            <div>
              <h4 className="font-medium mb-2">Communication Style</h4>
              <p className="text-sm text-muted-foreground">
                {brand.communicationStyle || "No communication style defined"}
              </p>
            </div>

            <div>
              <h4 className="font-medium mb-2">Brand Values</h4>
              {brand.values && Array.isArray(brand.values) && brand.values.length > 0 ? (
                <div className="flex flex-wrap gap-1">
                  {brand.values.slice(0, 3).map((value, index) => (
                    <Badge key={index} variant="outline">
                      {String(value)}
                    </Badge>
                  ))}
                  {brand.values.length > 3 && (
                    <Badge variant="outline">+{brand.values.length - 3} more</Badge>
                  )}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground">No brand values defined</p>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function VoiceAndToneSection({ brand }: { brand: BrandWithRelations }) {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Voice & Tone Guidelines</CardTitle>
          <CardDescription>
            Brand voice characteristics and communication guidelines
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div>
            <h4 className="font-medium mb-3">Voice Description</h4>
            <p className="text-sm">
              {brand.voiceDescription || "No voice description has been defined for this brand."}
            </p>
          </div>

          <div>
            <h4 className="font-medium mb-3">Communication Style</h4>
            <p className="text-sm">
              {brand.communicationStyle || "No communication style guidelines have been set."}
            </p>
          </div>

          <div>
            <h4 className="font-medium mb-3">Tone Attributes</h4>
            {brand.toneAttributes && typeof brand.toneAttributes === 'object' && 
             Object.keys(brand.toneAttributes).length > 0 ? (
              <div className="space-y-2">
                {Object.entries(brand.toneAttributes).map(([attribute, value]) => (
                  <div key={attribute} className="flex items-center gap-3">
                    <span className="text-sm capitalize min-w-[100px]">{attribute}</span>
                    <div className="flex-1 bg-muted rounded-full h-2">
                      <div 
                        className="bg-primary h-2 rounded-full" 
                        style={{ width: `${(Number(value) / 10) * 100}%` }}
                      />
                    </div>
                    <span className="text-sm text-muted-foreground min-w-[30px]">
                      {String(value)}/10
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">
                No tone attributes have been configured.
              </p>
            )}
          </div>

          <div>
            <h4 className="font-medium mb-3">Personality Traits</h4>
            {brand.personality && Array.isArray(brand.personality) && brand.personality.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {brand.personality.map((trait, index) => (
                  <Badge key={index} variant="secondary">
                    {String(trait)}
                  </Badge>
                ))}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">
                No personality traits have been defined.
              </p>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

function ComplianceSection({ brand }: { brand: BrandWithRelations }) {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5" />
            Brand Compliance
          </CardTitle>
          <CardDescription>
            Usage rules, restrictions, and approval processes
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div>
            <h4 className="font-medium mb-3">Usage Guidelines</h4>
            {brand.complianceRules && typeof brand.complianceRules === 'object' &&
             Object.keys(brand.complianceRules).length > 0 ? (
              <div className="space-y-2">
                {Object.entries(brand.complianceRules).map(([rule, description]) => (
                  <div key={rule} className="p-3 bg-muted rounded-lg">
                    <div className="font-medium text-sm capitalize">{rule.replace(/_/g, ' ')}</div>
                    <div className="text-sm text-muted-foreground">
                      {typeof description === 'string' ? description : JSON.stringify(description)}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">
                No compliance rules have been established.
              </p>
            )}
          </div>

          <div>
            <h4 className="font-medium mb-3">Brand Restrictions</h4>
            <p className="text-sm text-muted-foreground">
              Brand restriction guidelines will be displayed here once configured.
            </p>
          </div>

          <div>
            <h4 className="font-medium mb-3">Approval Process</h4>
            <p className="text-sm text-muted-foreground">
              Brand approval workflow information will be shown here.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}