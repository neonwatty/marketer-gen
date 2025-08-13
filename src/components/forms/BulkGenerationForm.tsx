"use client"

import * as React from "react"
import { useState } from "react"
import { UseFormReturn } from "react-hook-form"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { FormWrapper } from "./FormWrapper"
import { TextField, TextareaField, SelectField, FormActions } from "./FormFields"
import { bulkGenerationSchema, BulkGenerationFormData } from "./schemas"
import { JOURNEY_STAGE_DEFINITIONS, BulkGenerationUtils, STAGE_CONTENT_TYPE_MAPPING } from "@/lib/bulk-generation"
import { 
  Users, 
  FileText, 
  Target, 
  Mail, 
  Zap, 
  Info, 
  Settings,
  Calendar,
  Hash,
  ExternalLink,
  Plus,
  Minus,
  CheckCircle
} from "lucide-react"

interface BulkGenerationFormProps {
  onSubmit: (data: BulkGenerationFormData) => void | Promise<void>
  defaultValues?: Partial<BulkGenerationFormData>
  isSubmitting?: boolean
  cardWrapper?: boolean
  campaignId?: string
}

const toneOptions = [
  { value: 'professional', label: 'Professional' },
  { value: 'casual', label: 'Casual' },
  { value: 'friendly', label: 'Friendly' },
  { value: 'persuasive', label: 'Persuasive' },
  { value: 'informative', label: 'Informative' },
  { value: 'urgent', label: 'Urgent' },
  { value: 'humorous', label: 'Humorous' },
  { value: 'authoritative', label: 'Authoritative' },
  { value: 'empathetic', label: 'Empathetic' },
]

const contentLengthOptions = [
  { value: 'short', label: 'Short (< 500 words)' },
  { value: 'medium', label: 'Medium (500-1500 words)' },
  { value: 'long', label: 'Long (1500+ words)' },
]

const urgencyOptions = [
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
]

const priorityOptions = [
  { value: 'low', label: 'Low Priority' },
  { value: 'medium', label: 'Medium Priority' },
  { value: 'high', label: 'High Priority' },
]

const getStageIcon = (stageType: string) => {
  switch (stageType) {
    case 'awareness': return <Users className="h-4 w-4" />
    case 'consideration': return <FileText className="h-4 w-4" />
    case 'conversion': return <Target className="h-4 w-4" />
    case 'retention': return <Mail className="h-4 w-4" />
    default: return <Users className="h-4 w-4" />
  }
}

const getStageColor = (stageType: string) => {
  switch (stageType) {
    case 'awareness': return 'bg-blue-50 border-blue-200 text-blue-800'
    case 'consideration': return 'bg-green-50 border-green-200 text-green-800'
    case 'conversion': return 'bg-orange-50 border-orange-200 text-orange-800'
    case 'retention': return 'bg-purple-50 border-purple-200 text-purple-800'
    default: return 'bg-gray-50 border-gray-200 text-gray-800'
  }
}

function StageSelector({ 
  selectedStages, 
  onStagesChange,
  contentTypesPerStage,
  onContentTypesChange,
  channelsPerStage,
  onChannelsChange
}: {
  selectedStages: string[]
  onStagesChange: (stages: string[]) => void
  contentTypesPerStage: Record<string, string[]>
  onContentTypesChange: (stageId: string, contentTypes: string[]) => void
  channelsPerStage: Record<string, string[]>
  onChannelsChange: (stageId: string, channels: string[]) => void
}) {
  const handleStageToggle = (stageId: string, checked: boolean) => {
    if (checked) {
      onStagesChange([...selectedStages, stageId])
    } else {
      onStagesChange(selectedStages.filter(id => id !== stageId))
      // Clear content types and channels for deselected stage
      onContentTypesChange(stageId, [])
      onChannelsChange(stageId, [])
    }
  }

  const handleContentTypeToggle = (stageId: string, contentType: string, checked: boolean) => {
    const current = contentTypesPerStage[stageId] || []
    if (checked) {
      onContentTypesChange(stageId, [...current, contentType])
    } else {
      onContentTypesChange(stageId, current.filter(type => type !== contentType))
    }
  }

  const handleChannelToggle = (stageId: string, channel: string, checked: boolean) => {
    const current = channelsPerStage[stageId] || []
    if (checked) {
      onChannelsChange(stageId, [...current, channel])
    } else {
      onChannelsChange(stageId, current.filter(c => c !== channel))
    }
  }

  return (
    <div className="space-y-6">
      {Object.entries(JOURNEY_STAGE_DEFINITIONS).map(([stageId, stageDef]) => {
        const isSelected = selectedStages.includes(stageId)
        const stageContentTypes = contentTypesPerStage[stageId] || []
        const stageChannels = channelsPerStage[stageId] || []
        
        return (
          <Card key={stageId} className={isSelected ? 'ring-2 ring-primary' : ''}>
            <CardContent className="p-6">
              <div className="flex items-start gap-4">
                <Checkbox
                  id={`stage-${stageId}`}
                  checked={isSelected}
                  onCheckedChange={(checked) => handleStageToggle(stageId, !!checked)}
                />
                
                <div className="flex-1 space-y-4">
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded ${getStageColor(stageDef.type)}`}>
                      {getStageIcon(stageDef.type)}
                    </div>
                    <div>
                      <h3 className="font-semibold">{stageDef.name}</h3>
                      <p className="text-sm text-muted-foreground">{stageDef.description}</p>
                    </div>
                  </div>

                  {isSelected && (
                    <div className="space-y-4 ml-6 border-l border-gray-200 pl-4">
                      {/* Content Types */}
                      <div>
                        <Label className="text-sm font-medium mb-2 block">Content Types</Label>
                        <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                          {stageDef.recommendedContentTypes.map((contentType) => (
                            <div key={contentType} className="flex items-center space-x-2">
                              <Checkbox
                                id={`${stageId}-${contentType}`}
                                checked={stageContentTypes.includes(contentType)}
                                onCheckedChange={(checked) => 
                                  handleContentTypeToggle(stageId, contentType, !!checked)
                                }
                              />
                              <Label
                                htmlFor={`${stageId}-${contentType}`}
                                className="text-sm capitalize cursor-pointer"
                              >
                                {contentType.replace('-', ' ')}
                              </Label>
                            </div>
                          ))}
                        </div>
                      </div>

                      {/* Channels */}
                      <div>
                        <Label className="text-sm font-medium mb-2 block">Channels</Label>
                        <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                          {stageDef.recommendedChannels.map((channel) => (
                            <div key={channel} className="flex items-center space-x-2">
                              <Checkbox
                                id={`${stageId}-${channel}`}
                                checked={stageChannels.includes(channel)}
                                onCheckedChange={(checked) => 
                                  handleChannelToggle(stageId, channel, !!checked)
                                }
                              />
                              <Label
                                htmlFor={`${stageId}-${channel}`}
                                className="text-sm capitalize cursor-pointer"
                              >
                                {channel.replace('-', ' ')}
                              </Label>
                            </div>
                          ))}
                        </div>
                      </div>

                      {/* Stage Summary */}
                      <div className="bg-muted/50 rounded-lg p-3">
                        <div className="text-xs text-muted-foreground">
                          <strong>Customer Mindset:</strong> {stageDef.customerMindset}
                        </div>
                        <div className="flex flex-wrap gap-1 mt-2">
                          {stageDef.messagingFocus.map((focus, index) => (
                            <Badge key={index} variant="secondary" className="text-xs">
                              {focus}
                            </Badge>
                          ))}
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        )
      })}
    </div>
  )
}

function GenerationSummary({
  selectedStages,
  contentTypesPerStage,
  channelsPerStage,
  quantity
}: {
  selectedStages: string[]
  contentTypesPerStage: Record<string, string[]>
  channelsPerStage: Record<string, string[]>
  quantity: number
}) {
  const totalContentPieces = selectedStages.reduce((total, stageId) => {
    const contentTypes = contentTypesPerStage[stageId] || []
    const channels = channelsPerStage[stageId] || []
    return total + (contentTypes.length * channels.length * quantity)
  }, 0)

  const estimatedDuration = BulkGenerationUtils.formatEstimatedTime(
    BulkGenerationUtils.calculateEstimatedDuration(totalContentPieces)
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Info className="h-5 w-5" />
          Generation Summary
        </CardTitle>
        <CardDescription>
          Overview of your bulk generation request
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 text-center">
          <div className="bg-blue-50 rounded-lg p-4">
            <div className="text-2xl font-bold text-blue-600">{selectedStages.length}</div>
            <div className="text-sm text-gray-600">Journey Stages</div>
          </div>
          <div className="bg-green-50 rounded-lg p-4">
            <div className="text-2xl font-bold text-green-600">{totalContentPieces}</div>
            <div className="text-sm text-gray-600">Content Pieces</div>
          </div>
          <div className="bg-orange-50 rounded-lg p-4">
            <div className="text-2xl font-bold text-orange-600">{quantity}</div>
            <div className="text-sm text-gray-600">Per Type/Channel</div>
          </div>
          <div className="bg-purple-50 rounded-lg p-4">
            <div className="text-2xl font-bold text-purple-600">{estimatedDuration}</div>
            <div className="text-sm text-gray-600">Est. Duration</div>
          </div>
        </div>

        {/* Stage Breakdown */}
        {selectedStages.length > 0 && (
          <div className="space-y-2">
            <Label className="text-sm font-medium">Stage Breakdown:</Label>
            {selectedStages.map((stageId) => {
              const stageDef = JOURNEY_STAGE_DEFINITIONS[stageId]
              const contentTypes = contentTypesPerStage[stageId] || []
              const channels = channelsPerStage[stageId] || []
              const stageTotal = contentTypes.length * channels.length * quantity

              return (
                <div key={stageId} className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <div className={`w-3 h-3 rounded-full ${getStageColor(stageDef.type).split(' ')[0]}`} />
                    <span>{stageDef.name}</span>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-muted-foreground">
                      {contentTypes.length} types × {channels.length} channels × {quantity}
                    </span>
                    <Badge variant="secondary">{stageTotal} pieces</Badge>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

export function BulkGenerationForm({
  onSubmit,
  defaultValues,
  isSubmitting = false,
  cardWrapper = true,
  campaignId
}: BulkGenerationFormProps) {
  const [selectedStages, setSelectedStages] = useState<string[]>(defaultValues?.stages || [])
  const [contentTypesPerStage, setContentTypesPerStage] = useState<Record<string, string[]>>(
    defaultValues?.contentTypesPerStage || {}
  )
  const [channelsPerStage, setChannelsPerStage] = useState<Record<string, string[]>>(
    defaultValues?.channelsPerStage || {}
  )

  const handleContentTypesChange = (stageId: string, contentTypes: string[]) => {
    setContentTypesPerStage(prev => ({
      ...prev,
      [stageId]: contentTypes
    }))
  }

  const handleChannelsChange = (stageId: string, channels: string[]) => {
    setChannelsPerStage(prev => ({
      ...prev,
      [stageId]: channels
    }))
  }

  const handleFormSubmit = (data: BulkGenerationFormData) => {
    const formData = {
      ...data,
      stages: selectedStages,
      contentTypesPerStage,
      channelsPerStage,
      campaignId
    }
    onSubmit(formData)
  }

  return (
    <FormWrapper
      onSubmit={handleFormSubmit}
      schema={bulkGenerationSchema}
      defaultValues={{
        ...defaultValues,
        stages: selectedStages,
        contentTypesPerStage,
        channelsPerStage,
        campaignId,
        priority: defaultValues?.priority || 'medium'
      }}
      title="Bulk Content Generation"
      description="Generate multiple content pieces across different customer journey stages"
      cardWrapper={cardWrapper}
    >
      <div className="space-y-8">
        {/* Basic Information */}
        <Card>
          <CardHeader>
            <CardTitle>Basic Information</CardTitle>
            <CardDescription>
              Provide basic details about your bulk generation request
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <TextField
                name="name"
                label="Request Name"
                placeholder="Q1 2024 Content Generation"
                required
              />
              <SelectField
                name="priority"
                label="Priority"
                placeholder="Select priority"
                options={priorityOptions}
                defaultValue="medium"
              />
            </div>
            
            <TextareaField
              name="description"
              label="Description (Optional)"
              placeholder="Describe the purpose and goals of this bulk generation..."
              rows={3}
            />

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <Label htmlFor="quantity">Content Pieces per Stage/Type/Channel</Label>
                <Input
                  id="quantity"
                  name="quantity"
                  type="number"
                  min="1"
                  max="50"
                  defaultValue="3"
                  className="w-full"
                />
                <p className="text-xs text-muted-foreground">
                  How many content pieces to generate for each combination
                </p>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="scheduledFor">Schedule For (Optional)</Label>
                <Input
                  id="scheduledFor"
                  name="scheduledFor"
                  type="datetime-local"
                  className="w-full"
                />
                <p className="text-xs text-muted-foreground">
                  When to start generation (leave empty for immediate)
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Journey Stages */}
        <Card>
          <CardHeader>
            <CardTitle>Journey Stages & Content Types</CardTitle>
            <CardDescription>
              Select the customer journey stages and content types for bulk generation
            </CardDescription>
          </CardHeader>
          <CardContent>
            <StageSelector
              selectedStages={selectedStages}
              onStagesChange={setSelectedStages}
              contentTypesPerStage={contentTypesPerStage}
              onContentTypesChange={handleContentTypesChange}
              channelsPerStage={channelsPerStage}
              onChannelsChange={handleChannelsChange}
            />
          </CardContent>
        </Card>

        {/* Brand Context */}
        <Card>
          <CardHeader>
            <CardTitle>Brand Context</CardTitle>
            <CardDescription>
              Provide brand information to ensure consistent messaging
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <TextField
                name="brandContext.companyName"
                label="Company Name (Optional)"
                placeholder="Your Company Name"
              />
              <TextField
                name="brandContext.industry"
                label="Industry (Optional)"
                placeholder="Technology, Healthcare, Finance..."
              />
            </div>

            <TextField
              name="brandContext.targetAudience"
              label="Target Audience"
              placeholder="Small business owners, Marketing managers, Tech professionals..."
              required
            />

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <TextField
                name="brandContext.brandVoice"
                label="Brand Voice (Optional)"
                placeholder="Professional, Approachable, Innovative..."
              />
              <TextField
                name="brandContext.logoUrl"
                label="Logo URL (Optional)"
                placeholder="https://example.com/logo.png"
              />
            </div>

            <TextareaField
              name="brandContext.brandGuidelines"
              label="Brand Guidelines (Optional)"
              placeholder="Specific brand guidelines, messaging principles, or style preferences..."
              rows={3}
            />
          </CardContent>
        </Card>

        {/* Content Settings */}
        <Card>
          <CardHeader>
            <CardTitle>Content Settings</CardTitle>
            <CardDescription>
              Configure content generation parameters
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <SelectField
                name="contentSettings.tone"
                label="Tone of Voice"
                placeholder="Select tone"
                options={toneOptions}
                required
              />
              <SelectField
                name="contentSettings.contentLength"
                label="Content Length"
                placeholder="Select length"
                options={contentLengthOptions}
                required
              />
              <SelectField
                name="contentSettings.urgencyLevel"
                label="Urgency Level"
                placeholder="Select urgency"
                options={urgencyOptions}
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="includeHashtags"
                  name="contentSettings.includeHashtags"
                />
                <Label htmlFor="includeHashtags">Include hashtags when appropriate</Label>
              </div>
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="includeCTA"
                  name="contentSettings.includeCTA"
                />
                <Label htmlFor="includeCTA">Include calls-to-action</Label>
              </div>
            </div>

            <TextareaField
              name="contentSettings.customInstructions"
              label="Custom Instructions (Optional)"
              placeholder="Any specific instructions or requirements for content generation..."
              rows={3}
            />
          </CardContent>
        </Card>

        {/* Generation Summary */}
        <GenerationSummary
          selectedStages={selectedStages}
          contentTypesPerStage={contentTypesPerStage}
          channelsPerStage={channelsPerStage}
          quantity={3} // This should be bound to the form
        />

        <FormActions
          submitText="Start Bulk Generation"
          isSubmitting={isSubmitting}
          submitIcon={<Zap className="h-4 w-4" />}
        />
      </div>
    </FormWrapper>
  )
}