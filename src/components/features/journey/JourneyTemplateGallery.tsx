'use client'

import React, { useEffect, useState } from 'react'

import { Copy, Eye, Filter, Search, Settings, Sparkles, Star, Users } from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
// Import utility functions
import {
  getCategoryDisplayName,
  getIndustryDisplayName,
} from '@/lib/types/journey'

import type { JourneyTemplate } from '@/lib/types/journey'
// Import types separately to avoid issues
import type {
  JourneyCategoryValue,
  JourneyIndustryValue,
} from '@/lib/types/journey'

interface JourneyTemplateGalleryProps {
  onSelectTemplate: (template: JourneyTemplate) => void
  onPreviewTemplate?: (template: JourneyTemplate) => void
}

export function JourneyTemplateGallery({ onSelectTemplate, onPreviewTemplate }: JourneyTemplateGalleryProps): React.ReactElement {
  const [templates, setTemplates] = useState<JourneyTemplate[]>([])
  const [filteredTemplates, setFilteredTemplates] = useState<JourneyTemplate[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedIndustry, setSelectedIndustry] = useState<string>('')
  const [selectedCategory, setSelectedCategory] = useState<string>('')
  const [selectedDifficulty, setSelectedDifficulty] = useState<string>('')
  const [showFilters, setShowFilters] = useState(false)
  
  // Popular and recommended templates
  const [popularTemplates, setPopularTemplates] = useState<JourneyTemplate[]>([])
  const [recommendedTemplates, setRecommendedTemplates] = useState<JourneyTemplate[]>([])
  
  // Preview modal
  const [previewTemplate, setPreviewTemplate] = useState<JourneyTemplate | null>(null)
  const [showPreview, setShowPreview] = useState(false)
  
  // Customization modal
  const [customizationTemplate, setCustomizationTemplate] = useState<JourneyTemplate | null>(null)
  const [showCustomization, setShowCustomization] = useState(false)

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

  const difficulties = ['beginner', 'intermediate', 'advanced']

  // Fetch templates on mount
  useEffect(() => {
    fetchTemplates()
    fetchPopularTemplates()
    fetchRecommendedTemplates()
  }, [])

  // Filter templates when search or filters change
  useEffect(() => {
    filterTemplates()
  }, [templates, searchQuery, selectedIndustry, selectedCategory, selectedDifficulty])

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
    if (selectedIndustry && selectedIndustry !== 'all') {
      filtered = filtered.filter(template => template.industry === selectedIndustry)
    }

    // Category filter
    if (selectedCategory && selectedCategory !== 'all') {
      filtered = filtered.filter(template => template.category === selectedCategory)
    }

    // Difficulty filter
    if (selectedDifficulty && selectedDifficulty !== 'all') {
      filtered = filtered.filter(template => template.metadata?.difficulty === selectedDifficulty)
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

  const handleCustomize = (template: JourneyTemplate) => {
    setCustomizationTemplate(template)
    setShowCustomization(true)
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
    <Card 
      key={template.id} 
      className="group hover:shadow-lg transition-all duration-200 cursor-pointer focus-within:ring-2 focus-within:ring-ring focus-within:outline-none" 
      role="article"
      aria-labelledby={`template-title-${template.id}`}
      aria-describedby={`template-description-${template.id}`}
    >
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="flex-1 min-w-0">
            <CardTitle 
              id={`template-title-${template.id}`} 
              className="text-lg line-clamp-2 group-hover:text-blue-600 transition-colors"
            >
              {template.name}
            </CardTitle>
            {template.description && (
              <CardDescription 
                id={`template-description-${template.id}`}
                className="line-clamp-2 mt-1"
              >
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
          aria-label={`Preview ${template.name} template`}
        >
          <Eye className="w-4 h-4" />
        </Button>
        <Button 
          variant="outline" 
          size="sm"
          onClick={() => handleCustomize(template)}
          aria-label={`Customize ${template.name} template`}
        >
          <Settings className="w-4 h-4" />
        </Button>
        <Button 
          variant="outline" 
          size="sm"
          onClick={() => handleDuplicateTemplate(template)}
          aria-label={`Duplicate ${template.name} template`}
        >
          <Copy className="w-4 h-4" />
        </Button>
      </CardFooter>
    </Card>
  )

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {Array.from({ length: 8 }).map((_, i) => (
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
            aria-label={showFilters ? "Hide filters" : "Show filters"}
          >
            <Filter className="w-4 h-4 mr-2" />
            Filters
          </Button>
        </div>

        {/* Search and Filters */}
        <div className="space-y-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" aria-hidden="true" />
            <Input
              placeholder="Search templates by name, description, or tags..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
              aria-label="Search journey templates"
              role="searchbox"
              type="search"
            />
          </div>

          {showFilters && (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 p-4 bg-muted rounded-lg">
              <Select value={selectedIndustry} onValueChange={setSelectedIndustry}>
                <SelectTrigger className="w-full" aria-label="Filter by industry">
                  <SelectValue placeholder="Select industry" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Industries</SelectItem>
                  {industries.map(industry => (
                    <SelectItem key={industry} value={industry}>
                      {getIndustryDisplayName(industry)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Select value={selectedCategory} onValueChange={setSelectedCategory}>
                <SelectTrigger className="w-full" aria-label="Filter by category">
                  <SelectValue placeholder="Select category" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Categories</SelectItem>
                  {categories.map(category => (
                    <SelectItem key={category} value={category}>
                      {getCategoryDisplayName(category)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Select value={selectedDifficulty} onValueChange={setSelectedDifficulty}>
                <SelectTrigger className="w-full" aria-label="Filter by difficulty level">
                  <SelectValue placeholder="Select difficulty" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Difficulties</SelectItem>
                  {difficulties.map(difficulty => (
                    <SelectItem key={difficulty} value={difficulty}>
                      {difficulty.charAt(0).toUpperCase() + difficulty.slice(1)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              {(selectedIndustry && selectedIndustry !== 'all' || selectedCategory && selectedCategory !== 'all' || selectedDifficulty && selectedDifficulty !== 'all' || searchQuery) && (
                <div className="sm:col-span-2 lg:col-span-3 xl:col-span-4 flex justify-end">
                  <Button
                    variant="outline"
                    onClick={() => {
                      setSearchQuery('')
                      setSelectedIndustry('')
                      setSelectedCategory('')
                      setSelectedDifficulty('')
                    }}
                  >
                    Clear Filters
                  </Button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Recommended Templates */}
      {recommendedTemplates.length > 0 && !searchQuery && (!selectedIndustry || selectedIndustry === 'all') && (!selectedCategory || selectedCategory === 'all') && (!selectedDifficulty || selectedDifficulty === 'all') && (
        <div className="space-y-4">
          <div className="flex items-center gap-2">
            <Sparkles className="w-5 h-5 text-yellow-500" />
            <h3 className="text-lg font-semibold">Recommended for You</h3>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {recommendedTemplates.map(template => (
              <TemplateCard key={template.id} template={template} showUsageStats={false} />
            ))}
          </div>
        </div>
      )}

      {/* Popular Templates */}
      {popularTemplates.length > 0 && !searchQuery && (!selectedIndustry || selectedIndustry === 'all') && (!selectedCategory || selectedCategory === 'all') && (!selectedDifficulty || selectedDifficulty === 'all') && (
        <div className="space-y-4">
          <h3 className="text-lg font-semibold">Popular Templates</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {popularTemplates.map(template => (
              <TemplateCard key={template.id} template={template} />
            ))}
          </div>
        </div>
      )}

      {/* All Templates */}
      <section className="space-y-4" aria-labelledby="templates-heading">
        <div className="flex items-center justify-between">
          <h3 id="templates-heading" className="text-lg font-semibold">
            {searchQuery || (selectedIndustry && selectedIndustry !== 'all') || (selectedCategory && selectedCategory !== 'all') || (selectedDifficulty && selectedDifficulty !== 'all') ? 'Search Results' : 'All Templates'}
          </h3>
          <span 
            className="text-sm text-muted-foreground" 
            aria-live="polite"
            aria-atomic="true"
            role="status"
          >
            {filteredTemplates.length} template{filteredTemplates.length !== 1 ? 's' : ''} found
          </span>
        </div>

        {filteredTemplates.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            <p>No templates found matching your criteria.</p>
          </div>
        ) : (
          <div 
            className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4"
            aria-label="Journey templates grid"
          >
            {filteredTemplates.map(template => (
              <TemplateCard key={template.id} template={template} />
            ))}
          </div>
        )}
      </section>

      {/* Enhanced Preview Modal */}
      <Dialog open={showPreview} onOpenChange={setShowPreview}>
        <DialogContent className="max-w-5xl max-h-[85vh] overflow-y-auto">
          <DialogHeader className="space-y-3">
            <div className="flex items-start justify-between">
              <div className="space-y-2">
                <DialogTitle className="text-xl">{previewTemplate?.name}</DialogTitle>
                <DialogDescription className="text-base">{previewTemplate?.description}</DialogDescription>
              </div>
              {previewTemplate?.rating && (
                <div className="flex items-center gap-1">
                  <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                  <span className="font-medium">{previewTemplate.rating.toFixed(1)}</span>
                </div>
              )}
            </div>
          </DialogHeader>
          
          {previewTemplate && (
            <div className="space-y-6">
              {/* Template Metadata */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-muted rounded-lg">
                <div>
                  <h5 className="font-medium text-sm text-muted-foreground mb-1">Industry</h5>
                  <Badge variant="secondary" className="w-fit">
                    {getIndustryDisplayName(previewTemplate.industry)}
                  </Badge>
                </div>
                <div>
                  <h5 className="font-medium text-sm text-muted-foreground mb-1">Category</h5>
                  <Badge variant="outline" className="w-fit">
                    {getCategoryDisplayName(previewTemplate.category)}
                  </Badge>
                </div>
                <div>
                  <h5 className="font-medium text-sm text-muted-foreground mb-1">Difficulty</h5>
                  {previewTemplate.metadata?.difficulty && (
                    <Badge 
                      variant={previewTemplate.metadata.difficulty === 'beginner' ? 'default' : 
                             previewTemplate.metadata.difficulty === 'intermediate' ? 'secondary' : 'destructive'}
                      className="w-fit"
                    >
                      {previewTemplate.metadata.difficulty}
                    </Badge>
                  )}
                </div>
                <div>
                  <h5 className="font-medium text-sm text-muted-foreground mb-1">Duration</h5>
                  <span className="text-sm">
                    {previewTemplate.metadata?.estimatedDuration || 'Variable'} days
                  </span>
                </div>
              </div>

              {/* Template Stats */}
              <div className="grid grid-cols-3 gap-4 p-4 border rounded-lg">
                <div className="text-center">
                  <div className="flex items-center justify-center gap-1 mb-1">
                    <Users className="w-4 h-4" />
                    <span className="text-lg font-semibold">{previewTemplate.usageCount}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">Uses</p>
                </div>
                <div className="text-center">
                  <div className="flex items-center justify-center gap-1 mb-1">
                    <Eye className="w-4 h-4" />
                    <span className="text-lg font-semibold">{previewTemplate.stages.length}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">Stages</p>
                </div>
                <div className="text-center">
                  <div className="flex items-center justify-center gap-1 mb-1">
                    <Star className="w-4 h-4" />
                    <span className="text-lg font-semibold">{previewTemplate.rating?.toFixed(1) || 'N/A'}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">Rating</p>
                </div>
              </div>

              {/* Journey Stages */}
              <div className="space-y-4">
                <h4 className="font-semibold text-lg">Journey Stages</h4>
                <div className="grid gap-4">
                  {previewTemplate.stages.map((stage, index) => (
                    <div key={stage.id} className="p-4 border rounded-lg hover:shadow-sm transition-shadow">
                      <div className="flex items-start gap-3 mb-3">
                        <span className="w-8 h-8 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-semibold shrink-0">
                          {index + 1}
                        </span>
                        <div className="flex-1 min-w-0">
                          <h5 className="font-medium mb-1">{stage.title}</h5>
                          <p className="text-sm text-muted-foreground mb-3">{stage.description}</p>
                          
                          <div className="space-y-2">
                            <div>
                              <span className="text-xs font-medium text-muted-foreground">Content Types:</span>
                              <div className="flex flex-wrap gap-1 mt-1">
                                {stage.contentTypes.map((type, i) => (
                                  <Badge key={i} variant="outline" className="text-xs">
                                    {type}
                                  </Badge>
                                ))}
                              </div>
                            </div>
                            
                            {stage.messagingSuggestions && stage.messagingSuggestions.length > 0 && (
                              <div>
                                <span className="text-xs font-medium text-muted-foreground">Sample Messages:</span>
                                <ul className="mt-1 space-y-1">
                                  {stage.messagingSuggestions.slice(0, 2).map((message, i) => (
                                    <li key={i} className="text-xs text-muted-foreground italic">
                                      "{ message}"
                                    </li>
                                  ))}
                                </ul>
                              </div>
                            )}
                          </div>
                        </div>
                        <div className="text-right">
                          <span className="text-xs text-muted-foreground">{stage.duration} days</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Tags and Target Info */}
              {previewTemplate.metadata?.tags && (
                <div className="space-y-2">
                  <h5 className="font-medium">Tags</h5>
                  <div className="flex flex-wrap gap-1">
                    {previewTemplate.metadata.tags.map((tag, index) => (
                      <Badge key={index} variant="outline" className="text-xs">
                        #{tag}
                      </Badge>
                    ))}
                  </div>
                </div>
              )}

              {/* Action Buttons */}
              <div className="flex gap-3 pt-4 border-t">
                <Button 
                  onClick={() => previewTemplate && handleUseTemplate(previewTemplate)}
                  className="flex-1"
                >
                  Use This Template
                </Button>
                <Button 
                  variant="outline" 
                  onClick={() => previewTemplate && handleCustomize(previewTemplate)}
                >
                  <Settings className="w-4 h-4 mr-2" />
                  Customize
                </Button>
                <Button 
                  variant="outline" 
                  onClick={() => previewTemplate && handleDuplicateTemplate(previewTemplate)}
                >
                  <Copy className="w-4 h-4 mr-2" />
                  Duplicate
                </Button>
                <Button 
                  variant="outline"
                  onClick={() => setShowPreview(false)}
                >
                  Close
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* Customization Modal */}
      <Dialog open={showCustomization} onOpenChange={setShowCustomization}>
        <DialogContent className="max-w-4xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Customize Template: {customizationTemplate?.name}</DialogTitle>
            <DialogDescription>
              Preview and adjust template settings before using
            </DialogDescription>
          </DialogHeader>
          
          {customizationTemplate && (
            <div className="space-y-6">
              {/* Customization Options */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <h4 className="font-semibold">Template Information</h4>
                  <div className="space-y-3 p-4 border rounded-lg bg-muted/50">
                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <span className="font-medium">Industry:</span>
                        <p className="text-muted-foreground">{getIndustryDisplayName(customizationTemplate.industry)}</p>
                      </div>
                      <div>
                        <span className="font-medium">Category:</span>
                        <p className="text-muted-foreground">{getCategoryDisplayName(customizationTemplate.category)}</p>
                      </div>
                      <div>
                        <span className="font-medium">Difficulty:</span>
                        <p className="text-muted-foreground">{customizationTemplate.metadata?.difficulty || 'Not specified'}</p>
                      </div>
                      <div>
                        <span className="font-medium">Est. Duration:</span>
                        <p className="text-muted-foreground">{customizationTemplate.metadata?.estimatedDuration || 'Variable'} days</p>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <h4 className="font-semibold">Customization Options</h4>
                  <div className="space-y-3 p-4 border rounded-lg">
                    {customizationTemplate.customizationConfig ? (
                      <>
                        <div className="flex items-center justify-between">
                          <span className="text-sm">Stage Reordering:</span>
                          <Badge variant={customizationTemplate.customizationConfig.allowStageReordering ? "default" : "outline"}>
                            {customizationTemplate.customizationConfig.allowStageReordering ? "Allowed" : "Fixed Order"}
                          </Badge>
                        </div>
                        <div className="flex items-center justify-between">
                          <span className="text-sm">Add New Stages:</span>
                          <Badge variant={customizationTemplate.customizationConfig.allowStageAddition ? "default" : "outline"}>
                            {customizationTemplate.customizationConfig.allowStageAddition ? "Allowed" : "Not Allowed"}
                          </Badge>
                        </div>
                        <div className="flex items-center justify-between">
                          <span className="text-sm">Delete Stages:</span>
                          <Badge variant={customizationTemplate.customizationConfig.allowStageDeletion ? "default" : "outline"}>
                            {customizationTemplate.customizationConfig.allowStageDeletion ? "Allowed" : "Protected"}
                          </Badge>
                        </div>
                      </>
                    ) : (
                      <p className="text-sm text-muted-foreground">Standard customization options available</p>
                    )}
                  </div>
                </div>
              </div>

              {/* Stages Overview */}
              <div className="space-y-4">
                <h4 className="font-semibold">Template Stages ({customizationTemplate.stages.length})</h4>
                <div className="grid gap-3">
                  {customizationTemplate.stages.map((stage, index) => (
                    <div key={stage.id} className="flex items-center gap-3 p-3 border rounded-lg bg-muted/30">
                      <span className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-xs font-semibold">
                        {index + 1}
                      </span>
                      <div className="flex-1">
                        <h5 className="font-medium">{stage.title}</h5>
                        <p className="text-xs text-muted-foreground line-clamp-1">{stage.description}</p>
                      </div>
                      <div className="text-right">
                        <span className="text-xs text-muted-foreground">{stage.duration} days</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Required Channels & KPIs */}
              {customizationTemplate.metadata && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {customizationTemplate.metadata.requiredChannels && (
                    <div className="space-y-2">
                      <h5 className="font-medium">Required Channels</h5>
                      <div className="flex flex-wrap gap-1">
                        {customizationTemplate.metadata.requiredChannels.map((channel, index) => (
                          <Badge key={index} variant="secondary" className="text-xs">
                            {channel}
                          </Badge>
                        ))}
                      </div>
                    </div>
                  )}

                  {customizationTemplate.metadata.kpis && (
                    <div className="space-y-2">
                      <h5 className="font-medium">Key Performance Indicators</h5>
                      <div className="flex flex-wrap gap-1">
                        {customizationTemplate.metadata.kpis.map((kpi, index) => (
                          <Badge key={index} variant="outline" className="text-xs">
                            {kpi}
                          </Badge>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* Action Buttons */}
              <div className="flex gap-3 pt-4 border-t">
                <Button 
                  onClick={() => {
                    if (customizationTemplate) {
                      handleUseTemplate(customizationTemplate)
                      setShowCustomization(false)
                    }
                  }}
                  className="flex-1"
                >
                  <Settings className="w-4 h-4 mr-2" />
                  Use & Customize
                </Button>
                <Button 
                  variant="outline" 
                  onClick={() => customizationTemplate && handlePreview(customizationTemplate)}
                >
                  <Eye className="w-4 h-4 mr-2" />
                  Full Preview
                </Button>
                <Button 
                  variant="outline"
                  onClick={() => setShowCustomization(false)}
                >
                  Close
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}

export default JourneyTemplateGallery