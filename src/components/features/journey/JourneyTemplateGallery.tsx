'use client'

import { useEffect,useState } from 'react'

import { Copy, Eye, Filter, Search, Sparkles,Star, Users } from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import {
  getCategoryDisplayName,
  getIndustryDisplayName,
  JourneyCategoryValue,
  JourneyIndustryValue,
  JourneyTemplate,
} from '@/lib/types/journey'

interface JourneyTemplateGalleryProps {
  onSelectTemplate: (template: JourneyTemplate) => void
  onPreviewTemplate?: (template: JourneyTemplate) => void
}

export function JourneyTemplateGallery({ onSelectTemplate, onPreviewTemplate }: JourneyTemplateGalleryProps) {
  const [templates, setTemplates] = useState<JourneyTemplate[]>([])
  const [filteredTemplates, setFilteredTemplates] = useState<JourneyTemplate[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedIndustry, setSelectedIndustry] = useState<string>('')
  const [selectedCategory, setSelectedCategory] = useState<string>('')
  const [showFilters, setShowFilters] = useState(false)
  
  // Popular and recommended templates
  const [popularTemplates, setPopularTemplates] = useState<JourneyTemplate[]>([])
  const [recommendedTemplates, setRecommendedTemplates] = useState<JourneyTemplate[]>([])
  
  // Preview modal
  const [previewTemplate, setPreviewTemplate] = useState<JourneyTemplate | null>(null)
  const [showPreview, setShowPreview] = useState(false)

  const industries: JourneyIndustryValue[] = [
    'TECHNOLOGY', 'HEALTHCARE', 'FINANCE', 'RETAIL', 'EDUCATION', 'REAL_ESTATE',
    'AUTOMOTIVE', 'HOSPITALITY', 'MANUFACTURING', 'CONSULTING', 'NONPROFIT',
    'ECOMMERCE', 'SAAS', 'MEDIA', 'FOOD_BEVERAGE', 'FITNESS', 'TRAVEL', 'FASHION', 'LEGAL', 'OTHER'
  ]

  const categories: JourneyCategoryValue[] = [
    'CUSTOMER_ACQUISITION', 'LEAD_NURTURING', 'CUSTOMER_ONBOARDING', 'RETENTION',
    'UPSELL_CROSS_SELL', 'WIN_BACK', 'REFERRAL', 'BRAND_AWARENESS', 'PRODUCT_LAUNCH',
    'EVENT_PROMOTION', 'SEASONAL_CAMPAIGN', 'CRISIS_COMMUNICATION'
  ]

  // Fetch templates on mount
  useEffect(() => {
    fetchTemplates()
    fetchPopularTemplates()
    fetchRecommendedTemplates()
  }, [])

  // Filter templates when search or filters change
  useEffect(() => {
    filterTemplates()
  }, [templates, searchQuery, selectedIndustry, selectedCategory])

  const fetchTemplates = async () => {
    try {
      setLoading(true)
      const response = await fetch('/api/journey-templates?pageSize=100')
      if (!response.ok) throw new Error('Failed to fetch templates')
      
      const data = await response.json()
      if (data.success) {
        setTemplates(data.data.templates)
      }
    } catch (error) {
      console.error('Error fetching templates:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchPopularTemplates = async () => {
    try {
      const response = await fetch('/api/journey-templates/popular?limit=5')
      if (!response.ok) throw new Error('Failed to fetch popular templates')
      
      const data = await response.json()
      if (data.success) {
        setPopularTemplates(data.data)
      }
    } catch (error) {
      console.error('Error fetching popular templates:', error)
    }
  }

  const fetchRecommendedTemplates = async () => {
    try {
      const response = await fetch('/api/journey-templates/recommended?limit=5')
      if (!response.ok) throw new Error('Failed to fetch recommended templates')
      
      const data = await response.json()
      if (data.success) {
        setRecommendedTemplates(data.data)
      }
    } catch (error) {
      console.error('Error fetching recommended templates:', error)
    }
  }

  const filterTemplates = () => {
    let filtered = templates

    // Search filter
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase()
      filtered = filtered.filter(template =>
        template.name.toLowerCase().includes(query) ||
        template.description?.toLowerCase().includes(query) ||
        template.metadata?.tags?.some(tag => tag.toLowerCase().includes(query))
      )
    }

    // Industry filter
    if (selectedIndustry) {
      filtered = filtered.filter(template => template.industry === selectedIndustry)
    }

    // Category filter
    if (selectedCategory) {
      filtered = filtered.filter(template => template.category === selectedCategory)
    }

    setFilteredTemplates(filtered)
  }

  const handleUseTemplate = async (template: JourneyTemplate) => {
    try {
      // Increment usage count
      await fetch(`/api/journey-templates/${template.id}/use`, { method: 'POST' })
      onSelectTemplate(template)
    } catch (error) {
      console.error('Error using template:', error)
      // Still proceed with template selection even if usage increment fails
      onSelectTemplate(template)
    }
  }

  const handlePreview = (template: JourneyTemplate) => {
    setPreviewTemplate(template)
    setShowPreview(true)
    onPreviewTemplate?.(template)
  }

  const handleDuplicateTemplate = async (template: JourneyTemplate) => {
    try {
      const name = `${template.name} (Copy)`
      const response = await fetch(`/api/journey-templates/${template.id}/duplicate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name }),
      })
      
      if (!response.ok) throw new Error('Failed to duplicate template')
      
      // Refresh templates
      fetchTemplates()
    } catch (error) {
      console.error('Error duplicating template:', error)
    }
  }

  const TemplateCard = ({ template, showUsageStats = true }: { template: JourneyTemplate; showUsageStats?: boolean }) => (
    <Card key={template.id} className="group hover:shadow-lg transition-all duration-200 cursor-pointer">
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="flex-1 min-w-0">
            <CardTitle className="text-lg line-clamp-2 group-hover:text-blue-600 transition-colors">
              {template.name}
            </CardTitle>
            {template.description && (
              <CardDescription className="line-clamp-2 mt-1">
                {template.description}
              </CardDescription>
            )}
          </div>
          {template.rating && (
            <div className="flex items-center gap-1 ml-2">
              <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
              <span className="text-sm font-medium">{template.rating.toFixed(1)}</span>
            </div>
          )}
        </div>
        
        <div className="flex flex-wrap gap-2 mt-2">
          <Badge variant="secondary" className="text-xs">
            {getIndustryDisplayName(template.industry)}
          </Badge>
          <Badge variant="outline" className="text-xs">
            {getCategoryDisplayName(template.category)}
          </Badge>
          {template.metadata?.difficulty && (
            <Badge 
              variant={template.metadata.difficulty === 'beginner' ? 'default' : 
                     template.metadata.difficulty === 'intermediate' ? 'secondary' : 'destructive'} 
              className="text-xs"
            >
              {template.metadata.difficulty}
            </Badge>
          )}
        </div>
      </CardHeader>

      <CardContent className="py-3">
        <div className="space-y-2">
          {template.metadata?.tags && template.metadata.tags.length > 0 && (
            <div className="flex flex-wrap gap-1">
              {template.metadata.tags.slice(0, 3).map((tag, index) => (
                <Badge key={index} variant="outline" className="text-xs px-2 py-0">
                  {tag}
                </Badge>
              ))}
              {template.metadata.tags.length > 3 && (
                <Badge variant="outline" className="text-xs px-2 py-0">
                  +{template.metadata.tags.length - 3}
                </Badge>
              )}
            </div>
          )}
          
          {showUsageStats && (
            <div className="flex items-center gap-4 text-sm text-muted-foreground">
              <div className="flex items-center gap-1">
                <Users className="w-3 h-3" />
                <span>{template.usageCount} uses</span>
              </div>
              <div className="flex items-center gap-1">
                <Eye className="w-3 h-3" />
                <span>{template.stages.length} stages</span>
              </div>
            </div>
          )}
        </div>
      </CardContent>

      <CardFooter className="pt-3 gap-2">
        <Button 
          onClick={() => handleUseTemplate(template)}
          className="flex-1"
        >
          Use Template
        </Button>
        <Button 
          variant="outline" 
          size="sm"
          onClick={() => handlePreview(template)}
        >
          <Eye className="w-4 h-4" />
        </Button>
        <Button 
          variant="outline" 
          size="sm"
          onClick={() => handleDuplicateTemplate(template)}
        >
          <Copy className="w-4 h-4" />
        </Button>
      </CardFooter>
    </Card>
  )

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <Card key={i}>
              <CardHeader>
                <Skeleton className="h-6 w-3/4" />
                <Skeleton className="h-4 w-full" />
                <div className="flex gap-2 mt-2">
                  <Skeleton className="h-6 w-16" />
                  <Skeleton className="h-6 w-20" />
                </div>
              </CardHeader>
              <CardContent>
                <Skeleton className="h-4 w-full" />
              </CardContent>
              <CardFooter>
                <Skeleton className="h-10 w-full" />
              </CardFooter>
            </Card>
          ))}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-bold">Journey Templates</h2>
          <Button
            variant="outline"
            onClick={() => setShowFilters(!showFilters)}
          >
            <Filter className="w-4 h-4 mr-2" />
            Filters
          </Button>
        </div>

        {/* Search and Filters */}
        <div className="space-y-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="Search templates..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />
          </div>

          {showFilters && (
            <div className="flex flex-wrap gap-4 p-4 bg-muted rounded-lg">
              <Select value={selectedIndustry} onValueChange={setSelectedIndustry}>
                <SelectTrigger className="w-48">
                  <SelectValue placeholder="Select industry" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All Industries</SelectItem>
                  {industries.map(industry => (
                    <SelectItem key={industry} value={industry}>
                      {getIndustryDisplayName(industry)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Select value={selectedCategory} onValueChange={setSelectedCategory}>
                <SelectTrigger className="w-48">
                  <SelectValue placeholder="Select category" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All Categories</SelectItem>
                  {categories.map(category => (
                    <SelectItem key={category} value={category}>
                      {getCategoryDisplayName(category)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              {(selectedIndustry || selectedCategory || searchQuery) && (
                <Button
                  variant="outline"
                  onClick={() => {
                    setSearchQuery('')
                    setSelectedIndustry('')
                    setSelectedCategory('')
                  }}
                >
                  Clear Filters
                </Button>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Recommended Templates */}
      {recommendedTemplates.length > 0 && !searchQuery && !selectedIndustry && !selectedCategory && (
        <div className="space-y-4">
          <div className="flex items-center gap-2">
            <Sparkles className="w-5 h-5 text-yellow-500" />
            <h3 className="text-lg font-semibold">Recommended for You</h3>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {recommendedTemplates.map(template => (
              <TemplateCard key={template.id} template={template} showUsageStats={false} />
            ))}
          </div>
        </div>
      )}

      {/* Popular Templates */}
      {popularTemplates.length > 0 && !searchQuery && !selectedIndustry && !selectedCategory && (
        <div className="space-y-4">
          <h3 className="text-lg font-semibold">Popular Templates</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {popularTemplates.map(template => (
              <TemplateCard key={template.id} template={template} />
            ))}
          </div>
        </div>
      )}

      {/* All Templates */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold">
            {searchQuery || selectedIndustry || selectedCategory ? 'Search Results' : 'All Templates'}
          </h3>
          <span className="text-sm text-muted-foreground">
            {filteredTemplates.length} template{filteredTemplates.length !== 1 ? 's' : ''}
          </span>
        </div>

        {filteredTemplates.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            <p>No templates found matching your criteria.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {filteredTemplates.map(template => (
              <TemplateCard key={template.id} template={template} />
            ))}
          </div>
        )}
      </div>

      {/* Preview Modal */}
      <Dialog open={showPreview} onOpenChange={setShowPreview}>
        <DialogContent className="max-w-4xl max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{previewTemplate?.name}</DialogTitle>
            <DialogDescription>{previewTemplate?.description}</DialogDescription>
          </DialogHeader>
          
          {previewTemplate && (
            <div className="space-y-6">
              <div className="flex flex-wrap gap-2">
                <Badge variant="secondary">
                  {getIndustryDisplayName(previewTemplate.industry)}
                </Badge>
                <Badge variant="outline">
                  {getCategoryDisplayName(previewTemplate.category)}
                </Badge>
                {previewTemplate.metadata?.difficulty && (
                  <Badge variant="default">{previewTemplate.metadata.difficulty}</Badge>
                )}
              </div>

              <div className="space-y-4">
                <h4 className="font-semibold">Journey Stages</h4>
                <div className="grid gap-3">
                  {previewTemplate.stages.map((stage, index) => (
                    <div key={stage.id} className="p-3 border rounded-lg">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-xs font-semibold">
                          {index + 1}
                        </span>
                        <h5 className="font-medium">{stage.title}</h5>
                      </div>
                      <p className="text-sm text-muted-foreground mb-2">{stage.description}</p>
                      <div className="flex flex-wrap gap-1">
                        {stage.contentTypes.map((type, i) => (
                          <Badge key={i} variant="outline" className="text-xs">
                            {type}
                          </Badge>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex gap-3 pt-4 border-t">
                <Button onClick={() => previewTemplate && handleUseTemplate(previewTemplate)}>
                  Use This Template
                </Button>
                <Button 
                  variant="outline" 
                  onClick={() => previewTemplate && handleDuplicateTemplate(previewTemplate)}
                >
                  <Copy className="w-4 h-4 mr-2" />
                  Duplicate
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}