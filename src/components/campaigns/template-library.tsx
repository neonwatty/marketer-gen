"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { 
  File,
  Star,
  Search,
  Filter,
  Plus,
  Edit,
  Trash2,
  Copy,
  Download,
  Share2,
  MoreHorizontal,
  Calendar,
  User,
  Users,
  Target,
  DollarSign,
  MessageCircle,
  BookOpen,
  Globe,
  TrendingUp,
  Heart,
  Gift,
  Zap,
  Award,
  Settings
} from "lucide-react"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

interface CampaignTemplate {
  id: string
  name: string
  description: string
  category: string
  author: string
  createdAt: string
  updatedAt: string
  usageCount: number
  rating: number
  isPublic: boolean
  isFavorite: boolean
  tags: string[]
  elements: {
    basicInfo: boolean
    targeting: boolean
    messaging: boolean
    content: boolean
    budget: boolean
    schedule: boolean
  }
  previewData: {
    estimatedBudget?: string
    duration?: string
    channels: string[]
    contentTypes: string[]
  }
}

interface TemplateLibraryProps {
  onUseTemplate?: (template: CampaignTemplate) => void
  onEditTemplate?: (template: CampaignTemplate) => void
  onDeleteTemplate?: (template: CampaignTemplate) => void
  className?: string
}

// Mock template data
const mockTemplates: CampaignTemplate[] = [
  {
    id: "template-1",
    name: "Product Launch Campaign",
    description: "Comprehensive template for launching new products with multi-channel approach",
    category: "product-launch",
    author: "Marketing Team",
    createdAt: "2024-01-15",
    updatedAt: "2024-02-10",
    usageCount: 12,
    rating: 4.8,
    isPublic: true,
    isFavorite: true,
    tags: ["product-launch", "multi-channel", "awareness"],
    elements: {
      basicInfo: true,
      targeting: true,
      messaging: true,
      content: true,
      budget: true,
      schedule: true
    },
    previewData: {
      estimatedBudget: "$15,000 - $30,000",
      duration: "6-8 weeks",
      channels: ["Email", "Social Media", "Blog", "Display Ads"],
      contentTypes: ["Blog Posts", "Social Posts", "Email Sequences", "Landing Pages"]
    }
  },
  {
    id: "template-2",
    name: "Holiday Sales Campaign",
    description: "Seasonal template optimized for holiday promotions and sales events",
    category: "seasonal",
    author: "Sales Team",
    createdAt: "2024-02-01",
    updatedAt: "2024-02-15",
    usageCount: 8,
    rating: 4.6,
    isPublic: true,
    isFavorite: false,
    tags: ["seasonal", "sales", "promotion", "urgency"],
    elements: {
      basicInfo: true,
      targeting: true,
      messaging: true,
      content: true,
      budget: false,
      schedule: true
    },
    previewData: {
      estimatedBudget: "$5,000 - $20,000",
      duration: "2-4 weeks",
      channels: ["Email", "Social Media", "Search Ads"],
      contentTypes: ["Email Campaigns", "Social Ads", "Landing Pages"]
    }
  },
  {
    id: "template-3",
    name: "Brand Awareness Builder",
    description: "Long-term brand building template focused on reach and recognition",
    category: "brand-awareness",
    author: "Brand Team",
    createdAt: "2024-01-20",
    updatedAt: "2024-02-05",
    usageCount: 15,
    rating: 4.9,
    isPublic: true,
    isFavorite: true,
    tags: ["brand-awareness", "reach", "long-term"],
    elements: {
      basicInfo: true,
      targeting: true,
      messaging: true,
      content: true,
      budget: true,
      schedule: false
    },
    previewData: {
      estimatedBudget: "$25,000 - $50,000",
      duration: "12-16 weeks",
      channels: ["Social Media", "Display Ads", "YouTube", "Influencer"],
      contentTypes: ["Video Content", "Display Creatives", "Social Posts", "Blog Content"]
    }
  },
  {
    id: "template-4",
    name: "Lead Generation Engine",
    description: "High-converting template designed for B2B lead generation campaigns",
    category: "lead-generation",
    author: "Growth Team",
    createdAt: "2024-02-10",
    updatedAt: "2024-02-20",
    usageCount: 6,
    rating: 4.7,
    isPublic: false,
    isFavorite: false,
    tags: ["lead-generation", "B2B", "conversion", "nurturing"],
    elements: {
      basicInfo: true,
      targeting: true,
      messaging: true,
      content: true,
      budget: true,
      schedule: true
    },
    previewData: {
      estimatedBudget: "$10,000 - $25,000",
      duration: "8-12 weeks",
      channels: ["Email", "LinkedIn", "Search Ads", "Content Marketing"],
      contentTypes: ["Whitepapers", "Email Sequences", "Landing Pages", "Webinars"]
    }
  },
  {
    id: "template-5",
    name: "Customer Retention Campaign",
    description: "Template for keeping existing customers engaged and loyal",
    category: "retention",
    author: "Customer Success",
    createdAt: "2024-01-25",
    updatedAt: "2024-02-12",
    usageCount: 9,
    rating: 4.5,
    isPublic: true,
    isFavorite: false,
    tags: ["retention", "loyalty", "engagement", "customer-success"],
    elements: {
      basicInfo: true,
      targeting: true,
      messaging: true,
      content: true,
      budget: false,
      schedule: true
    },
    previewData: {
      estimatedBudget: "$3,000 - $10,000",
      duration: "Ongoing",
      channels: ["Email", "In-app", "SMS"],
      contentTypes: ["Email Newsletters", "In-app Messages", "Surveys", "Rewards"]
    }
  }
]

const templateCategories = [
  { value: 'all', label: 'All Templates', icon: <File className="h-4 w-4" /> },
  { value: 'product-launch', label: 'Product Launch', icon: <Zap className="h-4 w-4" /> },
  { value: 'seasonal', label: 'Seasonal Campaigns', icon: <Gift className="h-4 w-4" /> },
  { value: 'brand-awareness', label: 'Brand Awareness', icon: <Globe className="h-4 w-4" /> },
  { value: 'lead-generation', label: 'Lead Generation', icon: <Target className="h-4 w-4" /> },
  { value: 'retention', label: 'Customer Retention', icon: <Heart className="h-4 w-4" /> },
  { value: 'custom', label: 'Custom Templates', icon: <Settings className="h-4 w-4" /> }
]

export function TemplateLibrary({ onUseTemplate, onEditTemplate, onDeleteTemplate, className }: TemplateLibraryProps) {
  const [searchQuery, setSearchQuery] = React.useState("")
  const [selectedCategory, setSelectedCategory] = React.useState("all")
  const [sortBy, setSortBy] = React.useState("recent")
  const [viewMode, setViewMode] = React.useState<"grid" | "list">("grid")
  const [showFavoritesOnly, setShowFavoritesOnly] = React.useState(false)

  const filteredTemplates = React.useMemo(() => {
    let filtered = mockTemplates

    // Filter by search query
    if (searchQuery) {
      filtered = filtered.filter(template => 
        template.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        template.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
        template.tags.some(tag => tag.toLowerCase().includes(searchQuery.toLowerCase()))
      )
    }

    // Filter by category
    if (selectedCategory !== "all") {
      filtered = filtered.filter(template => template.category === selectedCategory)
    }

    // Filter by favorites
    if (showFavoritesOnly) {
      filtered = filtered.filter(template => template.isFavorite)
    }

    // Sort
    switch (sortBy) {
      case "recent":
        filtered.sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime())
        break
      case "popular":
        filtered.sort((a, b) => b.usageCount - a.usageCount)
        break
      case "rating":
        filtered.sort((a, b) => b.rating - a.rating)
        break
      case "name":
        filtered.sort((a, b) => a.name.localeCompare(b.name))
        break
    }

    return filtered
  }, [searchQuery, selectedCategory, sortBy, showFavoritesOnly])

  const getCategoryIcon = (category: string) => {
    const categoryConfig = templateCategories.find(c => c.value === category)
    return categoryConfig?.icon || <File className="h-4 w-4" />
  }

  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <Star
        key={i}
        className={cn(
          "h-3 w-3",
          i < Math.floor(rating) ? "text-yellow-400 fill-current" : "text-gray-300"
        )}
      />
    ))
  }

  const toggleFavorite = (templateId: string) => {
    // In a real app, this would call an API
    console.log("Toggle favorite for template:", templateId)
  }

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Template Library</h2>
          <p className="text-muted-foreground">
            Browse and use pre-built campaign templates
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <Button variant="outline">
            <Plus className="h-4 w-4 mr-2" />
            New Template
          </Button>
          <Button variant="outline">
            <Download className="h-4 w-4 mr-2" />
            Import Template
          </Button>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-4">
        <div className="lg:col-span-2">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
            <Input
              placeholder="Search templates..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />
          </div>
        </div>
        
        <div>
          <Select value={selectedCategory} onValueChange={setSelectedCategory}>
            <SelectTrigger>
              <SelectValue placeholder="All Categories" />
            </SelectTrigger>
            <SelectContent>
              {templateCategories.map((category) => (
                <SelectItem key={category.value} value={category.value}>
                  <div className="flex items-center gap-2">
                    {category.icon}
                    <span>{category.label}</span>
                  </div>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div>
          <Select value={sortBy} onValueChange={setSortBy}>
            <SelectTrigger>
              <SelectValue placeholder="Sort by" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="recent">Most Recent</SelectItem>
              <SelectItem value="popular">Most Popular</SelectItem>
              <SelectItem value="rating">Highest Rated</SelectItem>
              <SelectItem value="name">Name (A-Z)</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Additional Filters */}
      <div className="flex items-center gap-4">
        <div className="flex items-center space-x-2">
          <input
            type="checkbox"
            id="favorites-only"
            checked={showFavoritesOnly}
            onChange={(e) => setShowFavoritesOnly(e.target.checked)}
            className="rounded"
          />
          <Label htmlFor="favorites-only" className="text-sm">
            Favorites only
          </Label>
        </div>

        <Separator orientation="vertical" className="h-4" />

        <div className="flex items-center gap-2">
          <Button
            variant={viewMode === "grid" ? "default" : "outline"}
            size="sm"
            onClick={() => setViewMode("grid")}
          >
            Grid
          </Button>
          <Button
            variant={viewMode === "list" ? "default" : "outline"}
            size="sm"
            onClick={() => setViewMode("list")}
          >
            List
          </Button>
        </div>

        <div className="text-sm text-gray-500">
          {filteredTemplates.length} template{filteredTemplates.length !== 1 ? 's' : ''}
        </div>
      </div>

      {/* Templates Grid/List */}
      {viewMode === "grid" ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredTemplates.map((template) => (
            <Card key={template.id} className="h-full flex flex-col hover:shadow-lg transition-shadow">
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-2">
                    {getCategoryIcon(template.category)}
                    <div>
                      <CardTitle className="text-lg">{template.name}</CardTitle>
                      <div className="flex items-center gap-2 mt-1">
                        <div className="flex">{renderStars(template.rating)}</div>
                        <span className="text-xs text-gray-500">({template.usageCount} uses)</span>
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex items-center gap-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => toggleFavorite(template.id)}
                    >
                      <Heart className={cn(
                        "h-4 w-4",
                        template.isFavorite ? "text-red-500 fill-current" : "text-gray-400"
                      )} />
                    </Button>
                    
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="sm">
                          <MoreHorizontal className="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onClick={() => onEditTemplate?.(template)}>
                          <Edit className="h-4 w-4 mr-2" />
                          Edit Template
                        </DropdownMenuItem>
                        <DropdownMenuItem>
                          <Copy className="h-4 w-4 mr-2" />
                          Duplicate
                        </DropdownMenuItem>
                        <DropdownMenuItem>
                          <Share2 className="h-4 w-4 mr-2" />
                          Share
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem 
                          onClick={() => onDeleteTemplate?.(template)}
                          className="text-red-600"
                        >
                          <Trash2 className="h-4 w-4 mr-2" />
                          Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>
                
                <CardDescription className="mt-2">
                  {template.description}
                </CardDescription>
              </CardHeader>

              <CardContent className="flex-1 flex flex-col">
                <div className="space-y-4 flex-1">
                  <div>
                    <div className="flex flex-wrap gap-1">
                      {template.tags.slice(0, 3).map((tag) => (
                        <Badge key={tag} variant="secondary" className="text-xs">
                          {tag}
                        </Badge>
                      ))}
                      {template.tags.length > 3 && (
                        <Badge variant="secondary" className="text-xs">
                          +{template.tags.length - 3}
                        </Badge>
                      )}
                    </div>
                  </div>

                  <div className="space-y-2 text-xs text-gray-600">
                    {template.previewData.estimatedBudget && (
                      <div className="flex items-center gap-2">
                        <DollarSign className="h-3 w-3" />
                        <span>{template.previewData.estimatedBudget}</span>
                      </div>
                    )}
                    {template.previewData.duration && (
                      <div className="flex items-center gap-2">
                        <Calendar className="h-3 w-3" />
                        <span>{template.previewData.duration}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-2">
                      <Globe className="h-3 w-3" />
                      <span>{template.previewData.channels.length} channels</span>
                    </div>
                  </div>

                  <div className="text-xs text-gray-500">
                    <div className="flex items-center gap-2">
                      <User className="h-3 w-3" />
                      <span>by {template.author}</span>
                    </div>
                    <div className="flex items-center gap-2 mt-1">
                      <Calendar className="h-3 w-3" />
                      <span>Updated {new Date(template.updatedAt).toLocaleDateString()}</span>
                    </div>
                  </div>
                </div>

                <div className="flex gap-2 mt-4">
                  <Button 
                    className="flex-1" 
                    onClick={() => onUseTemplate?.(template)}
                  >
                    <Copy className="h-4 w-4 mr-2" />
                    Use Template
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : (
        <div className="space-y-4">
          {filteredTemplates.map((template) => (
            <Card key={template.id}>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4 flex-1">
                    <div className="flex items-center gap-2">
                      {getCategoryIcon(template.category)}
                      <div>
                        <h3 className="font-medium text-lg">{template.name}</h3>
                        <div className="flex items-center gap-2 mt-1">
                          <div className="flex">{renderStars(template.rating)}</div>
                          <span className="text-xs text-gray-500">({template.usageCount} uses)</span>
                          <Separator orientation="vertical" className="h-3" />
                          <span className="text-xs text-gray-500">by {template.author}</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex-1 max-w-md">
                      <p className="text-sm text-gray-600">{template.description}</p>
                      <div className="flex flex-wrap gap-1 mt-2">
                        {template.tags.slice(0, 4).map((tag) => (
                          <Badge key={tag} variant="secondary" className="text-xs">
                            {tag}
                          </Badge>
                        ))}
                      </div>
                    </div>

                    <div className="text-right">
                      <div className="space-y-1 text-xs text-gray-600">
                        {template.previewData.estimatedBudget && (
                          <div>{template.previewData.estimatedBudget}</div>
                        )}
                        <div>{template.previewData.channels.length} channels</div>
                        <div>{template.previewData.duration}</div>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 ml-4">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => toggleFavorite(template.id)}
                    >
                      <Heart className={cn(
                        "h-4 w-4",
                        template.isFavorite ? "text-red-500 fill-current" : "text-gray-400"
                      )} />
                    </Button>
                    
                    <Button 
                      onClick={() => onUseTemplate?.(template)}
                    >
                      <Copy className="h-4 w-4 mr-2" />
                      Use Template
                    </Button>
                    
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="sm">
                          <MoreHorizontal className="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onClick={() => onEditTemplate?.(template)}>
                          <Edit className="h-4 w-4 mr-2" />
                          Edit Template
                        </DropdownMenuItem>
                        <DropdownMenuItem>
                          <Copy className="h-4 w-4 mr-2" />
                          Duplicate
                        </DropdownMenuItem>
                        <DropdownMenuItem>
                          <Share2 className="h-4 w-4 mr-2" />
                          Share
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem 
                          onClick={() => onDeleteTemplate?.(template)}
                          className="text-red-600"
                        >
                          <Trash2 className="h-4 w-4 mr-2" />
                          Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Empty State */}
      {filteredTemplates.length === 0 && (
        <Card>
          <CardContent className="p-12 text-center">
            <File className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">No templates found</h3>
            <p className="text-gray-600 mb-6">
              {searchQuery || selectedCategory !== "all" 
                ? "Try adjusting your search or filters to find templates."
                : "Create your first template to get started."
              }
            </p>
            <div className="flex justify-center gap-2">
              {(searchQuery || selectedCategory !== "all") && (
                <Button 
                  variant="outline" 
                  onClick={() => {
                    setSearchQuery("")
                    setSelectedCategory("all")
                    setShowFavoritesOnly(false)
                  }}
                >
                  Clear Filters
                </Button>
              )}
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Create Template
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}