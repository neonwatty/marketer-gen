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
import { Checkbox } from "@/components/ui/checkbox"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { 
  Copy,
  File,
  Settings,
  CheckCircle2,
  Calendar,
  DollarSign,
  Target,
  Users,
  MessageCircle,
  Mail,
  Share2,
  Globe,
  ArrowRight,
  Save,
  Upload,
  Download,
  Star,
  BookOpen,
  Layers,
  Wand2,
  AlertCircle,
  Info
} from "lucide-react"

interface Campaign {
  id: string
  title: string
  description: string
  status: string
  startDate: string
  endDate: string
  budget: {
    total: number
    spent: number
    currency: string
  }
  objectives: string[]
  channels: string[]
  targetAudience: {
    demographics: {
      ageRange: string
      gender: string
      location: string
    }
    description: string
    interests: string[]
  }
  messaging: {
    primaryMessage: string
    callToAction: string
    valueProposition: string
  }
  contentStrategy: {
    contentTypes: string[]
    frequency: string
    tone: string
  }
  metrics: {
    impressions: number
    engagement: number
    conversions: number
    clickThroughRate: number
    conversionRate: number
    costPerConversion: number
  }
}

interface CloneableElement {
  id: string
  category: 'basic' | 'targeting' | 'content' | 'budget' | 'schedule'
  name: string
  description: string
  icon: React.ReactNode
  required?: boolean
  getValue: (campaign: Campaign) => any
  dependencies?: string[]
}

interface CloneOptions {
  name: string
  description: string
  selectedElements: string[]
  adjustments: {
    budget?: number
    startDate?: string
    endDate?: string
    channels?: string[]
  }
  saveAsTemplate: boolean
  templateName?: string
  templateDescription?: string
  templateCategory?: string
}

interface CampaignCloningProps {
  campaign: Campaign
  onClone?: (options: CloneOptions) => void
  onCancel?: () => void
  className?: string
}

const cloneableElements: CloneableElement[] = [
  {
    id: 'basic-info',
    category: 'basic',
    name: 'Basic Information',
    description: 'Campaign title and description',
    icon: <File className="h-4 w-4" />,
    required: true,
    getValue: (campaign) => ({ title: campaign.title, description: campaign.description })
  },
  {
    id: 'objectives',
    category: 'basic',
    name: 'Campaign Objectives',
    description: 'Goals and success metrics',
    icon: <Target className="h-4 w-4" />,
    getValue: (campaign) => campaign.objectives
  },
  {
    id: 'target-audience',
    category: 'targeting',
    name: 'Target Audience',
    description: 'Demographics and audience profile',
    icon: <Users className="h-4 w-4" />,
    getValue: (campaign) => campaign.targetAudience
  },
  {
    id: 'channels',
    category: 'targeting',
    name: 'Marketing Channels',
    description: 'Selected distribution channels',
    icon: <Share2 className="h-4 w-4" />,
    getValue: (campaign) => campaign.channels
  },
  {
    id: 'messaging',
    category: 'content',
    name: 'Messaging Strategy',
    description: 'Primary message and value proposition',
    icon: <MessageCircle className="h-4 w-4" />,
    getValue: (campaign) => campaign.messaging
  },
  {
    id: 'content-strategy',
    category: 'content',
    name: 'Content Strategy',
    description: 'Content types, frequency, and tone',
    icon: <BookOpen className="h-4 w-4" />,
    getValue: (campaign) => campaign.contentStrategy
  },
  {
    id: 'budget',
    category: 'budget',
    name: 'Budget Configuration',
    description: 'Total budget and allocation',
    icon: <DollarSign className="h-4 w-4" />,
    getValue: (campaign) => campaign.budget
  },
  {
    id: 'schedule',
    category: 'schedule',
    name: 'Campaign Schedule',
    description: 'Start and end dates',
    icon: <Calendar className="h-4 w-4" />,
    getValue: (campaign) => ({ startDate: campaign.startDate, endDate: campaign.endDate })
  }
]

const templateCategories = [
  { value: 'product-launch', label: 'Product Launch', description: 'Templates for new product introductions' },
  { value: 'seasonal', label: 'Seasonal Campaigns', description: 'Holiday and seasonal promotions' },
  { value: 'brand-awareness', label: 'Brand Awareness', description: 'Brand building and awareness campaigns' },
  { value: 'lead-generation', label: 'Lead Generation', description: 'Lead capture and nurturing campaigns' },
  { value: 'retention', label: 'Customer Retention', description: 'Customer loyalty and retention' },
  { value: 'custom', label: 'Custom Template', description: 'General purpose template' }
]

export function CampaignCloning({ campaign, onClone, onCancel, className }: CampaignCloningProps) {
  const [cloneOptions, setCloneOptions] = React.useState<CloneOptions>({
    name: `${campaign.title} (Copy)`,
    description: `Cloned from: ${campaign.title}`,
    selectedElements: ['basic-info', 'target-audience', 'messaging'], // Default selection
    adjustments: {},
    saveAsTemplate: false
  })

  const [currentStep, setCurrentStep] = React.useState(1)
  const [showAdvanced, setShowAdvanced] = React.useState(false)

  const updateCloneOptions = (updates: Partial<CloneOptions>) => {
    setCloneOptions(prev => ({ ...prev, ...updates }))
  }

  const toggleElement = (elementId: string) => {
    const element = cloneableElements.find(e => e.id === elementId)
    if (element?.required) return // Can't deselect required elements

    setCloneOptions(prev => ({
      ...prev,
      selectedElements: prev.selectedElements.includes(elementId)
        ? prev.selectedElements.filter(id => id !== elementId)
        : [...prev.selectedElements, elementId]
    }))
  }

  const getElementValue = (elementId: string) => {
    const element = cloneableElements.find(e => e.id === elementId)
    if (!element) return null
    return element.getValue(campaign)
  }

  const getSelectedElementsPreview = () => {
    return cloneableElements
      .filter(element => cloneOptions.selectedElements.includes(element.id))
      .map(element => ({
        ...element,
        value: getElementValue(element.id)
      }))
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: campaign.budget.currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const handleClone = () => {
    onClone?.(cloneOptions)
  }

  const isValidConfiguration = () => {
    return cloneOptions.name.trim().length > 0 && 
           cloneOptions.selectedElements.length > 0 &&
           (!cloneOptions.saveAsTemplate || cloneOptions.templateName?.trim())
  }

  const categorizedElements = React.useMemo(() => {
    const categories = ['basic', 'targeting', 'content', 'budget', 'schedule'] as const
    return categories.map(category => ({
      category,
      elements: cloneableElements.filter(element => element.category === category)
    }))
  }, [])

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Copy className="h-6 w-6 text-blue-600" />
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Clone Campaign</h2>
            <p className="text-muted-foreground">
              Create a new campaign based on "{campaign.title}"
            </p>
          </div>
        </div>
        
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={onCancel}>
            Cancel
          </Button>
          <Button onClick={handleClone} disabled={!isValidConfiguration()}>
            <Copy className="h-4 w-4 mr-2" />
            Clone Campaign
          </Button>
        </div>
      </div>

      {/* Step Progress */}
      <div className="flex items-center gap-4">
        {[1, 2, 3].map((step) => (
          <div key={step} className="flex items-center gap-2">
            <div className={cn(
              "w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium",
              currentStep >= step ? "bg-blue-600 text-white" : "bg-gray-200 text-gray-600"
            )}>
              {step}
            </div>
            <span className={cn(
              "text-sm",
              currentStep >= step ? "text-blue-600 font-medium" : "text-gray-600"
            )}>
              {step === 1 && "Select Elements"}
              {step === 2 && "Configure"}
              {step === 3 && "Review"}
            </span>
            {step < 3 && <ArrowRight className="h-4 w-4 text-gray-400" />}
          </div>
        ))}
      </div>

      {/* Step 1: Element Selection */}
      {currentStep === 1 && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Source Campaign</CardTitle>
                <CardDescription>
                  Overview of the campaign being cloned
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-start justify-between">
                  <div>
                    <h4 className="font-medium">{campaign.title}</h4>
                    <p className="text-sm text-gray-600 mt-1">{campaign.description}</p>
                  </div>
                  <Badge variant={campaign.status === 'active' ? 'default' : 'secondary'}>
                    {campaign.status}
                  </Badge>
                </div>

                <Separator />

                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-gray-500">Budget</p>
                    <p className="font-medium">{formatCurrency(campaign.budget.total)}</p>
                  </div>
                  <div>
                    <p className="text-gray-500">Channels</p>
                    <p className="font-medium">{campaign.channels.length} channels</p>
                  </div>
                  <div>
                    <p className="text-gray-500">Conversions</p>
                    <p className="font-medium">{campaign.metrics.conversions.toLocaleString()}</p>
                  </div>
                  <div>
                    <p className="text-gray-500">CTR</p>
                    <p className="font-medium">{campaign.metrics.clickThroughRate}%</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Quick Selection</CardTitle>
                <CardDescription>
                  Choose a preset combination of elements
                </CardDescription>
              </CardHeader>
              <CardContent>
                <RadioGroup
                  value="custom"
                  onValueChange={(value) => {
                    if (value === 'structure') {
                      updateCloneOptions({ selectedElements: ['basic-info', 'target-audience', 'channels'] })
                    } else if (value === 'content') {
                      updateCloneOptions({ selectedElements: ['basic-info', 'messaging', 'content-strategy'] })
                    } else if (value === 'full') {
                      updateCloneOptions({ selectedElements: cloneableElements.map(e => e.id) })
                    }
                  }}
                  className="space-y-3"
                >
                  <div className="flex items-center space-x-2">
                    <RadioGroupItem value="structure" id="structure" />
                    <Label htmlFor="structure" className="text-sm">
                      Structure Only (Audience + Channels)
                    </Label>
                  </div>
                  <div className="flex items-center space-x-2">
                    <RadioGroupItem value="content" id="content" />
                    <Label htmlFor="content" className="text-sm">
                      Content Strategy (Messaging + Content)
                    </Label>
                  </div>
                  <div className="flex items-center space-x-2">
                    <RadioGroupItem value="full" id="full" />
                    <Label htmlFor="full" className="text-sm">
                      Everything (Complete Clone)
                    </Label>
                  </div>
                  <div className="flex items-center space-x-2">
                    <RadioGroupItem value="custom" id="custom" />
                    <Label htmlFor="custom" className="text-sm">
                      Custom Selection
                    </Label>
                  </div>
                </RadioGroup>
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Select Elements to Clone</CardTitle>
              <CardDescription>
                Choose which parts of the campaign to include in the clone
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                {categorizedElements.map(({ category, elements }) => (
                  <div key={category}>
                    <h4 className="font-medium text-sm mb-3 capitalize flex items-center gap-2">
                      <Layers className="h-4 w-4" />
                      {category.replace('-', ' ')}
                    </h4>
                    <div className="space-y-3">
                      {elements.map((element) => {
                        const isSelected = cloneOptions.selectedElements.includes(element.id)
                        const isRequired = element.required

                        return (
                          <div 
                            key={element.id}
                            className={cn(
                              "flex items-start space-x-3 p-3 rounded-lg border transition-colors",
                              isSelected ? "bg-blue-50 border-blue-200" : "bg-gray-50 border-gray-200",
                              !isRequired && "cursor-pointer hover:border-gray-300"
                            )}
                            onClick={() => !isRequired && toggleElement(element.id)}
                          >
                            <Checkbox
                              checked={isSelected}
                              disabled={isRequired}
                              onChange={() => !isRequired && toggleElement(element.id)}
                              className="mt-0.5"
                            />
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2">
                                {element.icon}
                                <span className="font-medium text-sm">{element.name}</span>
                                {isRequired && (
                                  <Badge variant="secondary" className="text-xs">Required</Badge>
                                )}
                              </div>
                              <p className="text-xs text-gray-600 mt-1">{element.description}</p>
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Step 2: Configuration */}
      {currentStep === 2 && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle>Clone Configuration</CardTitle>
              <CardDescription>
                Configure the new campaign details
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div>
                <Label htmlFor="clone-name">Campaign Name *</Label>
                <Input
                  id="clone-name"
                  value={cloneOptions.name}
                  onChange={(e) => updateCloneOptions({ name: e.target.value })}
                  placeholder="Enter campaign name"
                />
              </div>

              <div>
                <Label htmlFor="clone-description">Description</Label>
                <Textarea
                  id="clone-description"
                  value={cloneOptions.description}
                  onChange={(e) => updateCloneOptions({ description: e.target.value })}
                  placeholder="Describe this campaign..."
                  className="min-h-[80px]"
                />
              </div>

              <Separator />

              <div>
                <div className="flex items-center justify-between mb-4">
                  <Label>Adjustments (Optional)</Label>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setShowAdvanced(!showAdvanced)}
                  >
                    <Settings className="h-4 w-4 mr-2" />
                    {showAdvanced ? 'Hide' : 'Show'} Advanced
                  </Button>
                </div>

                {showAdvanced && (
                  <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
                    {cloneOptions.selectedElements.includes('budget') && (
                      <div>
                        <Label htmlFor="budget-adjustment">Budget Adjustment</Label>
                        <Input
                          id="budget-adjustment"
                          type="number"
                          placeholder={formatCurrency(campaign.budget.total)}
                          onChange={(e) => updateCloneOptions({
                            adjustments: { ...cloneOptions.adjustments, budget: parseFloat(e.target.value) }
                          })}
                        />
                      </div>
                    )}

                    {cloneOptions.selectedElements.includes('schedule') && (
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <Label htmlFor="start-date">Start Date</Label>
                          <Input
                            id="start-date"
                            type="date"
                            onChange={(e) => updateCloneOptions({
                              adjustments: { ...cloneOptions.adjustments, startDate: e.target.value }
                            })}
                          />
                        </div>
                        <div>
                          <Label htmlFor="end-date">End Date</Label>
                          <Input
                            id="end-date"
                            type="date"
                            onChange={(e) => updateCloneOptions({
                              adjustments: { ...cloneOptions.adjustments, endDate: e.target.value }
                            })}
                          />
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>

              <Separator />

              <div className="space-y-4">
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="save-template"
                    checked={cloneOptions.saveAsTemplate}
                    onCheckedChange={(checked) => updateCloneOptions({ saveAsTemplate: !!checked })}
                  />
                  <Label htmlFor="save-template" className="text-sm font-medium">
                    Save as Template
                  </Label>
                </div>

                {cloneOptions.saveAsTemplate && (
                  <div className="space-y-4 p-4 bg-blue-50 rounded-lg border border-blue-200">
                    <div>
                      <Label htmlFor="template-name">Template Name *</Label>
                      <Input
                        id="template-name"
                        value={cloneOptions.templateName || ''}
                        onChange={(e) => updateCloneOptions({ templateName: e.target.value })}
                        placeholder="Enter template name"
                      />
                    </div>

                    <div>
                      <Label htmlFor="template-description">Template Description</Label>
                      <Textarea
                        id="template-description"
                        value={cloneOptions.templateDescription || ''}
                        onChange={(e) => updateCloneOptions({ templateDescription: e.target.value })}
                        placeholder="Describe when to use this template..."
                        className="min-h-[60px]"
                      />
                    </div>

                    <div>
                      <Label htmlFor="template-category">Category</Label>
                      <Select
                        value={cloneOptions.templateCategory || ''}
                        onValueChange={(value) => updateCloneOptions({ templateCategory: value })}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="Select template category" />
                        </SelectTrigger>
                        <SelectContent>
                          {templateCategories.map((category) => (
                            <SelectItem key={category.value} value={category.value}>
                              <div>
                                <div className="font-medium">{category.label}</div>
                                <div className="text-xs text-gray-500">{category.description}</div>
                              </div>
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Clone Preview</CardTitle>
              <CardDescription>
                Preview of what will be included in the clone
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Elements selected:</span>
                  <span className="font-medium">{cloneOptions.selectedElements.length} of {cloneableElements.length}</span>
                </div>

                <div className="space-y-3">
                  {getSelectedElementsPreview().map((element) => (
                    <div key={element.id} className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg">
                      <div className="text-green-600 mt-0.5">
                        <CheckCircle2 className="h-4 w-4" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          {element.icon}
                          <span className="font-medium text-sm">{element.name}</span>
                        </div>
                        <div className="text-xs text-gray-600 mt-1">
                          {element.id === 'target-audience' && `${element.value.demographics.ageRange}, ${element.value.demographics.location}`}
                          {element.id === 'channels' && `${element.value.length} channels`}
                          {element.id === 'objectives' && `${element.value.length} objectives`}
                          {element.id === 'budget' && formatCurrency(element.value.total)}
                          {element.id === 'messaging' && element.value.primaryMessage.slice(0, 50) + '...'}
                          {element.id === 'content-strategy' && `${element.value.contentTypes.length} content types`}
                          {element.id === 'schedule' && `${new Date(element.value.startDate).toLocaleDateString()} - ${new Date(element.value.endDate).toLocaleDateString()}`}
                          {element.id === 'basic-info' && element.value.description.slice(0, 50) + '...'}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>

                {cloneOptions.saveAsTemplate && (
                  <div className="mt-6 p-4 bg-blue-50 rounded-lg border border-blue-200">
                    <div className="flex items-center gap-2 mb-2">
                      <File className="h-4 w-4 text-blue-600" />
                      <span className="font-medium text-blue-900">Template</span>
                    </div>
                    <p className="text-sm text-blue-800">
                      This configuration will also be saved as a reusable template: "{cloneOptions.templateName}"
                    </p>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Step 3: Review */}
      {currentStep === 3 && (
        <Card>
          <CardHeader>
            <CardTitle>Review Clone Configuration</CardTitle>
            <CardDescription>
              Confirm your clone settings before proceeding
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h4 className="font-medium mb-3">New Campaign</h4>
                <div className="space-y-2 text-sm">
                  <div>
                    <span className="text-gray-500">Name:</span>
                    <span className="ml-2 font-medium">{cloneOptions.name}</span>
                  </div>
                  <div>
                    <span className="text-gray-500">Description:</span>
                    <p className="ml-2 text-gray-700">{cloneOptions.description}</p>
                  </div>
                </div>
              </div>

              <div>
                <h4 className="font-medium mb-3">Elements ({cloneOptions.selectedElements.length})</h4>
                <div className="flex flex-wrap gap-1">
                  {getSelectedElementsPreview().map((element) => (
                    <Badge key={element.id} variant="secondary" className="text-xs">
                      {element.name}
                    </Badge>
                  ))}
                </div>
              </div>
            </div>

            {Object.keys(cloneOptions.adjustments).length > 0 && (
              <div>
                <h4 className="font-medium mb-3">Adjustments</h4>
                <div className="space-y-2 text-sm">
                  {cloneOptions.adjustments.budget && (
                    <div>
                      <span className="text-gray-500">Budget:</span>
                      <span className="ml-2 font-medium">{formatCurrency(cloneOptions.adjustments.budget)}</span>
                    </div>
                  )}
                  {cloneOptions.adjustments.startDate && (
                    <div>
                      <span className="text-gray-500">Start Date:</span>
                      <span className="ml-2 font-medium">{new Date(cloneOptions.adjustments.startDate).toLocaleDateString()}</span>
                    </div>
                  )}
                  {cloneOptions.adjustments.endDate && (
                    <div>
                      <span className="text-gray-500">End Date:</span>
                      <span className="ml-2 font-medium">{new Date(cloneOptions.adjustments.endDate).toLocaleDateString()}</span>
                    </div>
                  )}
                </div>
              </div>
            )}

            {cloneOptions.saveAsTemplate && (
              <div className="p-4 bg-blue-50 rounded-lg border border-blue-200">
                <h4 className="font-medium text-blue-900 mb-2">Template Creation</h4>
                <div className="space-y-1 text-sm text-blue-800">
                  <div>
                    <span>Name:</span>
                    <span className="ml-2 font-medium">{cloneOptions.templateName}</span>
                  </div>
                  <div>
                    <span>Category:</span>
                    <span className="ml-2">{templateCategories.find(c => c.value === cloneOptions.templateCategory)?.label}</span>
                  </div>
                  {cloneOptions.templateDescription && (
                    <div>
                      <span>Description:</span>
                      <p className="ml-2">{cloneOptions.templateDescription}</p>
                    </div>
                  )}
                </div>
              </div>
            )}

            <div className="flex items-center gap-2 p-4 bg-green-50 rounded-lg border border-green-200">
              <Info className="h-4 w-4 text-green-600" />
              <p className="text-sm text-green-800">
                The cloned campaign will be created as a draft. You can make additional modifications before activating it.
              </p>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Navigation */}
      <div className="flex items-center justify-between pt-6 border-t">
        <Button
          variant="outline"
          onClick={() => setCurrentStep(Math.max(1, currentStep - 1))}
          disabled={currentStep === 1}
        >
          Previous
        </Button>
        
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-500">
            Step {currentStep} of 3
          </span>
        </div>

        {currentStep < 3 ? (
          <Button
            onClick={() => setCurrentStep(Math.min(3, currentStep + 1))}
            disabled={currentStep === 1 && cloneOptions.selectedElements.length === 0}
          >
            Next
          </Button>
        ) : (
          <Button onClick={handleClone} disabled={!isValidConfiguration()}>
            <Copy className="h-4 w-4 mr-2" />
            Create Clone
          </Button>
        )}
      </div>
    </div>
  )
}